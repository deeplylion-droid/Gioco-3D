"""Passo 4: scheletro, pesi automatici + pulizia, pose di prova.

Le articolazioni si ricavano dalla mesh:
  - braccia e dita con "fasce geodetiche": partendo dalle punte delle dita, gli anelli di vertici alla
    stessa distanza (lungo la superficie) hanno il centro sull'asse dell'arto; le nocche sono dove
    l'anello di un dito si allarga nel palmo, il polso dove il palmo si stringe nell'avambraccio;
  - busto, collo e testa dalle sezioni orizzontali della pelle.
Ossa: radice, campana, colonna_1, colonna_2, petto, collo, testa, occhio, mascella, clavicola,
braccio, avambraccio, mano, 5 dita x 3 falangi per lato (.L = sinistra della medusa, verso +X).

Pesi: "Automatic Weights" di Blender sulla mesh, poi pulizia per parti:
  capelli, labbro dell'orbita e viso sopra il collo -> testa; campana e moncherini -> campana
  (con passaggio morbido alla vita); bulbo e cornea -> occhio; ogni dito pesa solo sui vertici del suo dito;
  massimo 4 ossa per vertice (glTF/Godot), pesi normalizzati.
Shape key: "campana_contrai" (la campana si stringe e si allunga un po', per la pulsazione).

Scrive build/medusa_04_scheletro.blend, dati/scheletro.json e build/anteprime/pose_prova.jpg.
Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_04_scheletro.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
from scipy.sparse import coo_matrix  # noqa: E402
from scipy.sparse.csgraph import dijkstra, connected_components  # noqa: E402

PELLE, CAPELLI, CAMPANA, MONCHERINI = 0, 1, 2, 3
Z_VITA = -0.155
DITA = ['pollice', 'indice', 'medio', 'anulare', 'mignolo']
FRAZ_FALANGI = (0.45, 0.30, 0.25)
MAX_INFLUENZE = 4


# ---------------------------------------------------------------- grafo della mesh

class Grafo:
    def __init__(self, me):
        self.co = coords(me)
        me.calc_loop_triangles()
        lt = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
        me.loop_triangles.foreach_get('vertices', lt)
        tp = np.empty(len(me.loop_triangles), dtype=np.int64)
        me.loop_triangles.foreach_get('polygon_index', tp)
        mi = np.empty(len(me.polygons), dtype=np.int32)
        me.polygons.foreach_get('material_index', mi)
        self.tri = lt.reshape(-1, 3)
        self.mat_tri = mi[tp]
        nomi = [m.name for m in me.materials]
        self.nomi_mat = nomi
        V = len(self.co)
        # parte di ogni vertice: la piu' "forte" tra le facce vicine (pelle vince sul resto al confine)
        self.parte_v = np.full(V, -1)
        for k in (MONCHERINI, CAMPANA, CAPELLI, PELLE):
            self.parte_v[self.tri[self.mat_tri == k].ravel()] = k
        idx_orb = nomi.index('M_orbita') if 'M_orbita' in nomi else -1
        self.orbita_v = np.zeros(V, bool)
        if idx_orb >= 0:
            self.orbita_v[self.tri[self.mat_tri == idx_orb].ravel()] = True
        E = np.concatenate([self.tri[:, [0, 1]], self.tri[:, [1, 2]], self.tri[:, [2, 0]]])
        self.E = np.unique(np.sort(E, 1), axis=0)
        self.w = np.linalg.norm(self.co[self.E[:, 0]] - self.co[self.E[:, 1]], axis=1)

    def sottografo(self, sel):
        idx = np.nonzero(sel)[0]
        loc = -np.ones(len(self.co), int); loc[idx] = np.arange(len(idx))
        m = sel[self.E[:, 0]] & sel[self.E[:, 1]]
        G = coo_matrix((self.w[m], (loc[self.E[m, 0]], loc[self.E[m, 1]])), shape=(len(idx), len(idx))).tocsr()
        return G, idx


# ---------------------------------------------------------------- misure

def punte_dita(g, lato):
    """5 punte delle dita di una mano: massimi locali della distanza geodetica dalla spalla."""
    sel = (g.parte_v == PELLE) & (lato * g.co[:, 0] > 0.30)
    G, idx = g.sottografo(sel)
    n, lab = connected_components(G, directed=False)
    big = lab == np.argmax(np.bincount(lab))
    P = g.co[idx]
    start = np.nonzero(big & (lato * P[:, 0] < 0.31))[0]
    d = dijkstra(G, directed=False, indices=start, min_only=True)
    d[~big] = -1
    punte = []
    for i in np.argsort(-d)[:6000]:
        if d[i] < 0.4:
            break
        p = P[i]
        if all(np.linalg.norm(p - P[t]) > 0.012 for t in punte):
            vicini = np.linalg.norm(P - p, axis=1) < 0.012
            if d[vicini].max() <= d[i] + 1e-9:
                punte.append(i)
        if len(punte) == 5:
            break
    assert len(punte) == 5, f'trovate {len(punte)} punte sul lato {lato}'
    # pollice: la punta piu' "corta"; le altre dall'avanti (-Y) all'indietro
    punte = sorted(punte, key=lambda i: d[i])
    pollice, altre = punte[0], sorted(punte[1:], key=lambda i: P[i, 1])
    return [idx[pollice]] + [idx[i] for i in altre]


def asse_dito(g, punta, lato):
    """Centri delle fasce geodetiche dalla punta verso il palmo; si ferma alla nocca."""
    sel = (g.parte_v == PELLE) & (lato * g.co[:, 0] > 0.55)
    G, idx = g.sottografo(sel)
    P = g.co[idx]
    ti = int(np.nonzero(idx == punta)[0][0])
    d = dijkstra(G, directed=False, indices=ti)
    punti, raggi, ss = [], [], []
    for s in np.arange(0.004, 0.20, 0.004):
        band = np.abs(d - s) < 0.003
        if band.sum() < 3:
            continue
        c = P[band].mean(0)
        punti.append(c); raggi.append(np.linalg.norm(P[band] - c, axis=1).max()); ss.append(s)
    punti, raggi, ss = np.array(punti), np.array(raggi), np.array(ss)
    # nocca: primo punto dopo 8 cm in cui l'anello si allarga (> 2,4 cm) per due passi di fila
    k_nocca = len(ss) - 1
    for k in range(len(ss) - 1):
        if ss[k] > 0.08 and raggi[k] > 0.024 and raggi[k + 1] > 0.024:
            k_nocca = k
            break
    punti = punti[:k_nocca + 1]
    # punta vera e liscia: media mobile corta sul percorso
    liscio = punti.copy()
    for k in range(1, len(punti) - 1):
        liscio[k] = (punti[k - 1] + 2 * punti[k] + punti[k + 1]) / 4
    tip = g.co[punta] * 0.6 + liscio[0] * 0.4
    return np.vstack([tip, liscio])     # dalla punta alla nocca


def lungo_percorso(pts, frazioni):
    """Punti a frazioni della lunghezza di una polilinea."""
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    cum = np.r_[0, np.cumsum(seg)]
    out = []
    for f in frazioni:
        t = f * cum[-1]
        k = min(np.searchsorted(cum, t) - 1, len(seg) - 1)
        k = max(k, 0)
        a = (t - cum[k]) / max(seg[k], 1e-9)
        out.append(pts[k] * (1 - a) + pts[k + 1] * a)
    return np.array(out)


def asse_braccio(g, punte, lato):
    """Centri delle fasce geodetiche dalle punte delle dita fino alla spalla."""
    sel = (g.parte_v == PELLE) & (g.co[:, 2] > -0.5) & (g.co[:, 2] < 0.45)
    G, idx = g.sottografo(sel)
    P = g.co[idx]
    src = [int(np.nonzero(idx == p)[0][0]) for p in punte]
    d = dijkstra(G, directed=False, indices=src, min_only=True)
    ss, cc, rr = [], [], []
    for s in np.arange(0.08, 0.95, 0.01):
        band = np.abs(d - s) < 0.006
        if band.sum() < 3:
            continue
        c = P[band].mean(0)
        ss.append(s); cc.append(c); rr.append(np.median(np.linalg.norm(P[band] - c, axis=1)))
    return np.array(ss), np.array(cc), np.array(rr)


def misure(me):
    g = Grafo(me)
    occ3 = leggi_json('occhio_3d.json')
    M = {'lati': {}}
    # busto: centri delle sezioni di pelle
    pelle = g.parte_v == PELLE

    def sezione(z, larg=0.16):
        m = pelle & (np.abs(g.co[:, 2] - z) < 0.008) & (np.abs(g.co[:, 0]) < larg)
        return g.co[m].mean(0)

    M['vita'] = sezione(Z_VITA + 0.01)
    M['vita'][2] = Z_VITA
    M['colonna'] = [sezione(z) for z in (0.0, 0.15, 0.31)]
    M['collo'] = [sezione(0.335, 0.1), sezione(0.44, 0.06)]
    M['collo'][1][1] = M['collo'][0][1]
    for lato, suf in ((1, '.L'), (-1, '.R')):
        punte = punte_dita(g, lato)
        ss, cc, rr = asse_braccio(g, punte, lato)
        # polso: dove il palmo (largo) si stringe nell'avambraccio
        kp = int(np.argmax(rr[ss < 0.2]))
        k_polso = kp + int(np.nonzero(rr[kp:] < 0.75 * rr[kp])[0][0])
        # spalla: dove l'anello del braccio si allarga sul busto (ascella), poi 3,5 cm piu' su lungo l'asse
        s_w = ss[k_polso]
        ref = np.median(rr[(ss > s_w + 0.30) & (ss < s_w + 0.55)])
        k_sp = int(np.nonzero((ss > s_w + 0.45) & (rr > 1.25 * ref))[0][0])
        tratto = cc[(ss > s_w + 0.32) & (ss < ss[k_sp])]
        asse = np.linalg.svd(tratto - tratto.mean(0), full_matrices=False)[2][0]
        if asse @ (cc[k_sp] - cc[k_polso]) < 0:
            asse = -asse
        spalla = cc[k_sp] + asse * 0.035
        polso = cc[k_polso]
        braccio = np.vstack([cc[k_polso:k_sp + 1], spalla])
        gomito = lungo_percorso(braccio, [0.5])[0]
        dita = {}
        for nome, p in zip(DITA, punte):
            ax = asse_dito(g, p, lato)          # punta -> nocca
            nocca, punta = ax[-1], ax[0]
            j1, j2 = lungo_percorso(ax[::-1], [FRAZ_FALANGI[0], FRAZ_FALANGI[0] + FRAZ_FALANGI[1]])
            dita[nome] = [nocca, j1, j2, punta]
        nocche = np.mean([dita[n][0] for n in DITA[1:]], axis=0)
        # normale del dorso della mano (verso l'esterno del corpo)
        mano_v = pelle & (lato * g.co[:, 0] > lato * polso[0] - 0.01) & \
            (np.linalg.norm(g.co - (polso + nocche) / 2, axis=1) < 0.06)
        Q = g.co[mano_v] - g.co[mano_v].mean(0)
        nrm = np.linalg.svd(Q, full_matrices=False)[2][2]
        if nrm[0] * lato < 0:
            nrm = -nrm
        M['lati'][suf] = {'spalla': spalla, 'gomito': gomito, 'polso': polso, 'nocche': nocche,
                          'dita': dita, 'dorso': nrm}
        log(f'braccio {suf}: spalla {np.round(spalla, 3)} gomito {np.round(gomito, 3)} polso {np.round(polso, 3)}')
    M['occhio'] = occ3
    return M, g


# ---------------------------------------------------------------- armatura

def crea_armatura(M):
    arm = bpy.data.armatures.new('Medusa_Scheletro')
    arm.display_type = 'STICK'
    ob = bpy.data.objects.new('Medusa_Scheletro', arm)
    collega(ob)
    attiva(ob)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    avanti = Vector((0, -1, 0))

    def osso(nome, testa, coda, padre=None, connesso=False, roll_verso=avanti, deform=True):
        b = eb.new(nome)
        b.head = Vector(testa); b.tail = Vector(coda)
        if padre:
            b.parent = eb[padre]
            b.use_connect = connesso
        b.align_roll(Vector(roll_verso))
        b.use_deform = deform
        return b

    V = lambda a: Vector(tuple(float(x) for x in a))  # noqa: E731
    vita = V(M['vita'])
    c0, c1, c2 = (V(p) for p in M['colonna'])
    n0, n1 = (V(p) for p in M['collo'])
    osso('radice', (0, 0, 0), (0, 0, 0.12), roll_verso=avanti, deform=False)
    osso('campana', vita, vita + Vector((0, 0, -0.30)), 'radice')
    osso('colonna_1', vita, c0, 'campana')
    osso('colonna_2', c0, c1, 'colonna_1', True)
    osso('petto', c1, c2, 'colonna_2', True)
    osso('collo', n0, n1, 'petto')
    osso('testa', n1, n1 + Vector((0, 0, 0.36)), 'collo', True)
    o = M['occhio']
    C = V(o['centro_rotazione']); ax = V(o['asse_riposo'])
    osso('occhio', C, C + ax * 0.09, 'testa', roll_verso=(0, 0, 1))
    osso('mascella', V((0, -0.03, 0.565)), V((0, -0.175, 0.47)), 'testa', roll_verso=(0, 0, 1))
    for suf, L in M['lati'].items():
        lato = 1 if suf == '.L' else -1
        sp, go, po, no = V(L['spalla']), V(L['gomito']), V(L['polso']), V(L['nocche'])
        radice_clav = V((lato * 0.022, n0.y - 0.005, n0.z - 0.02))
        osso('clavicola' + suf, radice_clav, sp, 'petto')
        osso('braccio' + suf, sp, go, 'clavicola' + suf, True)
        osso('avambraccio' + suf, go, po, 'braccio' + suf, True)
        dorso = V(L['dorso'])
        osso('mano' + suf, po, no, 'avambraccio' + suf, True, roll_verso=dorso)
        for nome in DITA:
            pts = [V(p) for p in L['dita'][nome]]
            prec = 'mano' + suf
            for k in range(3):
                n = f'{nome}_{k + 1}{suf}'
                osso(n, pts[k], pts[k + 1], prec, k > 0, roll_verso=dorso)
                prec = n
    bpy.ops.object.mode_set(mode='OBJECT')
    return ob


# ---------------------------------------------------------------- pesi

def leggi_pesi(ob):
    me = ob.data
    nomi = [vg.name for vg in ob.vertex_groups]
    W = np.zeros((len(me.vertices), len(nomi)), np.float32)
    for v in me.vertices:
        for gr in v.groups:
            W[v.index, gr.group] = gr.weight
    return W, nomi


def scrivi_pesi(ob, W, nomi):
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    for j, n in enumerate(nomi):
        vg = ob.vertex_groups.new(name=n)
        nz = np.nonzero(W[:, j] > 1e-4)[0]
        if len(nz) == 0:
            continue
        # raggruppa per valore (molti vertici hanno peso 1)
        uno = nz[W[nz, j] > 0.9999]
        if len(uno):
            vg.add(uno.tolist(), 1.0, 'REPLACE')
        for i in nz[W[nz, j] <= 0.9999]:
            vg.add([int(i)], float(W[i, j]), 'REPLACE')


def limita(W, k=MAX_INFLUENZE):
    if W.shape[1] > k:
        part = np.argpartition(-W, k, axis=1)[:, k:]
        np.put_along_axis(W, part, 0, axis=1)
    s = W.sum(1, keepdims=True)
    return np.where(s > 0, W / np.maximum(s, 1e-9), W)


def liscia(W, g, sel, giri=3, forza=0.5):
    """Media coi vicini (solo sui vertici selezionati)."""
    E = g.E
    for _ in range(giri):
        somma = np.zeros_like(W); cnt = np.zeros((len(W), 1), np.float32)
        np.add.at(somma, E[:, 0], W[E[:, 1]]); np.add.at(cnt, E[:, 0], 1)
        np.add.at(somma, E[:, 1], W[E[:, 0]]); np.add.at(cnt, E[:, 1], 1)
        media = somma / np.maximum(cnt, 1)
        W[sel] = W[sel] * (1 - forza) + media[sel] * forza
    return W


def pulisci_pesi(ob, g, M):
    W, nomi = leggi_pesi(ob)
    col = {n: j for j, n in enumerate(nomi)}
    for n in [b.name for b in bpy.data.objects['Medusa_Scheletro'].data.bones if b.use_deform]:
        if n not in col:
            col[n] = len(nomi); nomi.append(n)
            W = np.hstack([W, np.zeros((len(W), 1), np.float32)])
    co = g.co
    V = len(co)

    def solo(mask, osso):
        W[mask] = 0
        W[mask, col[osso]] = 1

    # testa rigida: capelli, labbro dell'orbita, viso sopra il collo
    testa_z = M['collo'][1][2]
    viso = (g.parte_v == PELLE) & (co[:, 2] > testa_z + 0.02)
    solo((g.parte_v == CAPELLI) | g.orbita_v | viso, 'testa')
    # campana e moncherini
    campana = (g.parte_v == CAMPANA) | (g.parte_v == MONCHERINI)
    solo(campana & (co[:, 2] < Z_VITA - 0.06), 'campana')
    # fascia della vita: passaggio morbido campana -> colonna_1
    # (solo busto e campana: gli avambracci passano alla stessa altezza ma piu' in fuori, r > 0.4)
    fascia = (co[:, 2] >= Z_VITA - 0.06) & (co[:, 2] <= Z_VITA + 0.05) & (np.hypot(co[:, 0], co[:, 1]) < 0.32)
    t = np.clip((co[fascia, 2] - (Z_VITA - 0.06)) / 0.11, 0, 1)
    t = t * t * (3 - 2 * t)
    W[fascia] = 0
    W[fascia, col['campana']] = 1 - t
    W[fascia, col['colonna_1']] = t
    # niente ossa delle braccia/dita sul busto e sulla testa (e viceversa nessuna colonna sulle mani)
    braccia = [n for n in col if any(n.startswith(p) for p in ('braccio', 'avambraccio', 'mano') + tuple(DITA))]
    busto = np.abs(co[:, 0]) < 0.13
    for n in braccia:
        W[busto, col[n]] = 0
    # dita: ogni falange solo sul suo dito (vertici piu' vicini all'asse di quel dito)
    for suf, L in M['lati'].items():
        lato = 1 if suf == '.L' else -1
        mano = (g.parte_v == PELLE) & (np.linalg.norm(co - L['nocche'], axis=1) < 0.20) & (lato * co[:, 0] > 0.5)
        idx = np.nonzero(mano)[0]
        dist = []
        for nome in DITA:
            pts = np.array(L['dita'][nome])
            # distanza dalla polilinea del dito
            dmin = np.full(len(idx), np.inf)
            for a, b in zip(pts[:-1], pts[1:]):
                ab = b - a
                tt = np.clip(((co[idx] - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
                dmin = np.minimum(dmin, np.linalg.norm(co[idx] - (a + tt[:, None] * ab), axis=1))
            dist.append(dmin)
        dist = np.array(dist)
        vicino = np.argmin(dist, axis=0)
        for k, nome in enumerate(DITA):
            altro = idx[vicino != k]
            for f in range(1, 4):
                W[altro, col[f'{nome}_{f}{suf}']] = 0
        # i vertici della mano lontani da ogni dito non usano le dita
        palmo = idx[dist.min(0) > 0.03]
        for nome in DITA:
            for f in range(1, 4):
                W[palmo, col[f'{nome}_{f}{suf}']] = 0
    # vertici rimasti senza peso: prendono quelli dei vicini
    for _ in range(20):
        vuoti = W.sum(1) < 1e-6
        if not vuoti.any():
            break
        W = liscia(W, g, vuoti, giri=1, forza=1.0)
    # ammorbidisce sulla pelle del corpo (non sulle parti rigide), poi limita a 4 influenze
    morbido = (g.parte_v == PELLE) & ~viso & ~g.orbita_v
    W = limita(W, 8)
    W = liscia(W, g, morbido, giri=2, forza=0.4)
    W = limita(W)
    scrivi_pesi(ob, W, nomi)
    log(f'pesi: {V} vertici, {len(nomi)} gruppi, max {MAX_INFLUENZE} ossa per vertice')


def collega_scheletro(arm, M):
    me_ob = bpy.data.objects['Medusa']
    attiva(arm, solo=True)
    me_ob.select_set(True)
    bpy.context.view_layer.objects.active = arm
    t = time.time()
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    log(f'pesi automatici in {time.time() - t:.0f} s')
    for nome in ('Medusa_Occhio', 'Medusa_Cornea'):
        o = bpy.data.objects[nome]
        o.parent = arm
        o.matrix_parent_inverse = arm.matrix_world.inverted()
        vg = o.vertex_groups.new(name='occhio')
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        mod = o.modifiers.new('Scheletro', 'ARMATURE')
        mod.object = arm


# ---------------------------------------------------------------- shape key della campana

def shape_key_campana(ob, g):
    me = ob.data
    if me.shape_keys is None:
        ob.shape_key_add(name='Basis', from_mix=False)
    sk = ob.shape_key_add(name='campana_contrai', from_mix=False)
    co = coords(me)
    campana = (g.parte_v == CAMPANA) | (g.parte_v == MONCHERINI)
    z = co[:, 2]
    # piu' forte in basso (bordo), nulla alla vita
    t = np.clip((Z_VITA - z) / (Z_VITA + 0.72), 0, 1)
    t = np.where(campana, t * t * (3 - 2 * t), 0)
    r = np.hypot(co[:, 0], co[:, 1])
    k = 1 - 0.16 * t                       # si stringe del 16% al bordo
    nuovo = co.copy()
    nuovo[:, 0] *= np.where(r > 0, k, 1)
    nuovo[:, 1] *= np.where(r > 0, k, 1)
    nuovo[:, 2] = z - 0.05 * t * (g.parte_v == CAMPANA) - 0.07 * t * (g.parte_v == MONCHERINI)
    sk.data.foreach_set('co', nuovo.ravel())
    sk.value = 0.0
    log('shape key: campana_contrai')


# ---------------------------------------------------------------- pose di prova

def ruota(arm, osso, asse, gradi):
    """Ruota un osso in posa attorno a un asse del mondo passante per la sua testa."""
    pb = arm.pose.bones[osso]
    bpy.context.view_layer.update()
    M = pb.matrix.copy()
    R = Matrix.Rotation(math.radians(gradi), 4, Vector(asse).normalized())
    T = Matrix.Translation(M.translation)
    pb.matrix = T @ R @ T.inverted() @ M
    bpy.context.view_layer.update()


def piega_dita(arm, suf, gradi, pollice=0.6):
    """Chiude le dita verso il palmo (rotazione attorno all'asse X locale delle falangi)."""
    for nome in DITA:
        for f in (1, 2, 3):
            pb = arm.pose.bones[f'{nome}_{f}{suf}']
            k = pollice if nome == 'pollice' else 1.0
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler = (-math.radians(gradi * k), 0, 0)
    bpy.context.view_layer.update()


def lato_di(suf):
    return 1 if suf == '.L' else -1


def alza_braccio(arm, suf, gradi):
    ruota(arm, 'braccio' + suf, (0, -lato_di(suf), 0), gradi)


def avanti_braccio(arm, suf, gradi):
    ruota(arm, 'braccio' + suf, (1, 0, 0), -gradi)


def dentro_braccio(arm, suf, gradi):
    ruota(arm, 'braccio' + suf, (0, 0, 1), -lato_di(suf) * gradi)


def piega_gomito(arm, suf, gradi):
    pb = arm.pose.bones['avambraccio' + suf]
    bpy.context.view_layer.update()
    d = (arm.matrix_world @ pb.tail - arm.matrix_world @ pb.head).normalized()
    k = d.cross(Vector((0, 1, 0))).normalized()
    ruota(arm, 'avambraccio' + suf, k, -gradi)


def azzera(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()


def _posa_alzate(a):
    for s_ in ('.L', '.R'):
        alza_braccio(a, s_, 115)
        piega_gomito(a, s_, 25)
    ruota(a, 'testa', (1, 0, 0), -15)


def _posa_inseguimento(a):
    ruota(a, 'colonna_1', (1, 0, 0), 14)
    ruota(a, 'colonna_2', (1, 0, 0), 12)
    for s_ in ('.L', '.R'):
        avanti_braccio(a, s_, 85)
        dentro_braccio(a, s_, 25)
        piega_dita(a, s_, 30)
    ruota(a, 'testa', (1, 0, 0), -24)


def _posa_torsione(a):
    ruota(a, 'colonna_2', (0, 0, 1), 15)
    ruota(a, 'petto', (0, 0, 1), 12)
    ruota(a, 'colonna_1', (0, 1, 0), 12)
    ruota(a, 'collo', (0, 0, 1), 25)
    ruota(a, 'testa', (0, 0, 1), 30)
    ruota(a, 'testa', (0, 1, 0), -15)
    avanti_braccio(a, '.L', 70)
    dentro_braccio(a, '.L', 20)
    piega_gomito(a, '.L', 80)
    alza_braccio(a, '.R', 30)
    ruota(a, 'occhio', (0, 0, 1), 14)


def _posa_pugni(a):
    for s_ in ('.L', '.R'):
        piega_gomito(a, s_, 125)
        piega_dita(a, s_, 75)
    ruota(a, 'testa', (1, 0, 0), 12)


POSE = {'braccia_alzate': _posa_alzate, 'inseguimento': _posa_inseguimento,
        'torsione': _posa_torsione, 'gomiti_pugni': _posa_pugni}


# camera per ogni posa: (posizione, bersaglio, obiettivo)
CAMERE = {
    'braccia_alzate': ((0.9, -3.4, 0.5), (0, 0, 0.15), 50),
    'inseguimento': ((2.6, -2.2, 0.6), (0, -0.2, 0.15), 50),
    'torsione': ((1.0, -3.3, 0.5), (0, 0, 0.15), 50),
    'gomiti_pugni': ((0.9, -3.4, 0.5), (0, 0, 0.15), 50),
}
PRIMI_PIANI = [  # (posa, nome, osso inquadrato, spostamento della camera, obiettivo)
    ('braccia_alzate', 'spalla', 'braccio.L', (0.55, -1.0, 0.1), 60),
    ('gomiti_pugni', 'mano chiusa', 'medio_1.L', (0.25, -0.75, 0.25), 70),
]


def pose_prova(arm):
    ant = os.path.join(BUILD, 'anteprime'); os.makedirs(ant, exist_ok=True)
    imposta_render(samples=24, res=(640, 800))
    mondo((0.05, 0.05, 0.06), 1)
    luci_studio((0, 0, 0.1), 1.9)
    cam = camera((0, -3, 0), (0, 0, 0), lens=50)
    celle = []
    attiva(arm)
    bpy.ops.object.mode_set(mode='POSE')
    # (posa, nome, posizione camera, bersaglio, obiettivo); nei primi piani il bersaglio e' un osso
    # in posa e la posizione e' uno spostamento da quell'osso
    lavori = [(n, n.replace('_', ' '), *CAMERE[n]) for n in POSE]
    lavori += [(posa, nome, sposta, osso, lens) for posa, nome, osso, sposta, lens in PRIMI_PIANI]
    for posa, nome, loc, tgt, lens in lavori:
        azzera(arm)
        POSE[posa](arm)
        bpy.ops.object.mode_set(mode='OBJECT')
        if isinstance(tgt, str):
            bpy.context.view_layer.update()
            tgt = arm.matrix_world @ arm.pose.bones[tgt].head
            loc = tgt + Vector(loc)
        cam.location = Vector(loc); guarda(cam, tgt); cam.data.lens = lens
        celle.append((render(os.path.join(ant, f'posa_{nome.replace(" ", "_")}.png')), nome))
        attiva(arm)
        bpy.ops.object.mode_set(mode='POSE')
    azzera(arm)
    bpy.ops.object.mode_set(mode='OBJECT')
    tavola(celle, os.path.join(ant, 'pose_prova.jpg'), colonne=3)


def mesh_alta():
    """La mesh ad alta risoluzione del passo 2 (stesse coordinate): le articolazioni si misurano li',
    anche quando lo scheletro si costruisce sulla mesh da gioco ridotta."""
    path = os.path.join(BUILD, 'medusa_02_texture.blend')
    if not os.path.exists(path):
        return None
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.meshes = ['Medusa']
    return dst.meshes[0]


def main():
    t0 = time.time()
    apri(os.path.join(BUILD, 'medusa_03_occhio.blend'))
    ob = bpy.data.objects['Medusa']
    alta = mesh_alta()
    M, _ = misure(alta if alta is not None else ob.data)
    g = Grafo(ob.data)
    if alta is not None:
        mats = [m for m in alta.materials if m]
        bpy.data.meshes.remove(alta)
        for m in mats:
            if m.users == 0:
                bpy.data.materials.remove(m)
    arm = crea_armatura(M)
    collega_scheletro(arm, M)
    pulisci_pesi(ob, g, M)
    shape_key_campana(ob, g)
    dati = {'ossa': {b.name: {'testa': [round(v, 4) for v in b.head_local], 'coda': [round(v, 4) for v in b.tail_local],
                              'padre': b.parent.name if b.parent else None} for b in arm.data.bones}}
    scrivi_json('scheletro.json', dati)
    salva(os.path.join(BUILD, 'medusa_04_scheletro.blend'))
    if os.environ.get('MEDUSA_ANTEPRIME', '1') != '0':
        pose_prova(arm)
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
