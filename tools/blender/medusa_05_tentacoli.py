"""Passo 5: generatore procedurale dei tentacoli (parametrico) con una catena di ossa per tentacolo.

Tentacoli "grossi": tubi (o nastri piatti) che partono dai punti d'attacco sotto la campana (le radici
dei moncherini di Meshy, dati/attacchi_tentacoli.json), con una catena di ossa ciascuno, pensata per la
fisica in Godot (per esempio SpringBoneSimulator3D: catena tentacolo_NN_01 ... tentacolo_NN_KK, figlia
dell'osso "campana"). Pesi calcolati lungo la lunghezza (niente pesi automatici).
Tentacoli "sottili": filamenti senza ossa, rigidi con la campana; in Godot li muove uno shader
(UV.y = 0 alla radice, 1 in punta: ampiezza del movimento).

Forme: "spezzata" (segmenti dritti con pieghe secche, come nel disegno della statua), "ondulata"
(onda morbida), "nastro" (sezione piatta, ondulata e attorcigliata, come nel concept sott'acqua).
I moncherini di Meshy si tolgono e i buchi nella sottombrella si richiudono.

Uso come script (scrive build/medusa_05_tentacoli_<preset>.blend):
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_05_tentacoli.py --preset spezzati
Uso come modulo: crea_tentacoli(arm, PRESET['spezzati']) su una scena gia' aperta.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

BASE = dict(
    n_grossi=12,            # tentacoli grossi (con ossa)
    lunghezza=1.6,          # lunghezza media (m)
    var_lunghezza=0.2,      # variazione casuale (+-, frazione)
    raggio_base=0.026,      # raggio alla radice (m)
    raggio_punta=0.004,
    forma='spezzata',       # 'spezzata' | 'ondulata' | 'nastro'
    apertura=0.35,          # quanto si allargano verso l'esterno all'inizio (0 = giu' dritti)
    ampiezza=0.07,          # ampiezza laterale delle pieghe/onde (m)
    passo=0.16,             # lunghezza dei tratti dritti / lunghezza d'onda (m)
    angolo_pieghe=32,       # gradi (forma spezzata)
    piattezza=1.0,          # 1 = tondo; 3 = nastro largo il triplo dello spessore
    torsione=1.5,           # giri di torsione lungo il nastro
    n_ossa=10,              # ossa per tentacolo grosso
    n_sottili=16,           # filamenti senza ossa
    lunghezza_sottili=1.3,
    raggio_sottili=0.006,
    anello_sottili=0.30,    # raggio dell'anello d'attacco dei filamenti (m)
    lati=12,                # vertici per anello (tentacoli grossi)
    passo_anelli=0.015,     # distanza tra gli anelli lungo il tentacolo (m)
    lati_sottili=6,
    passo_anelli_sottili=0.015,
    colore=(0.75, 0.08, 0.32),
    seme=7,
)

PRESET = {
    'spezzati': dict(BASE, n_grossi=12, lunghezza=1.55, forma='spezzata', apertura=0.55, ampiezza=0.08,
                     passo=0.17, angolo_pieghe=34, raggio_base=0.028, n_sottili=14, lunghezza_sottili=1.2),
    'nastri': dict(BASE, n_grossi=10, lunghezza=2.0, forma='nastro', apertura=0.3, ampiezza=0.09, passo=0.45,
                   raggio_base=0.03, raggio_punta=0.008, piattezza=3.2, torsione=2.0, n_sottili=20,
                   lunghezza_sottili=1.6, var_lunghezza=0.25),
    'filamenti': dict(BASE, n_grossi=8, lunghezza=1.35, forma='ondulata', apertura=0.25, ampiezza=0.05,
                      passo=0.5, raggio_base=0.022, n_sottili=40, lunghezza_sottili=1.9, raggio_sottili=0.0045,
                      anello_sottili=0.33),
}

MONCHERINI = 3      # indice del materiale dei moncherini (passo 1)
Z_SOTTOMBRELLA = -0.532


# ---------------------------------------------------------------- moncherini

def togli_moncherini(ob):
    """Toglie le facce dei moncherini e richiude i buchi della sottombrella."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    nomi = [m.name for m in me.materials]
    k = nomi.index('M_moncherini') if 'M_moncherini' in nomi else MONCHERINI
    via = [f for f in bm.faces if f.material_index == k]
    if not via:
        bm.free()
        return 0
    bmesh.ops.delete(bm, geom=via, context='FACES')
    idx_c = nomi.index('M_campana')
    uv = bm.loops.layers.uv.active
    # buchi lasciati dai moncherini: ogni anello di bordo si chiude a ventaglio attorno al suo centro
    bordi = {e for e in bm.edges if e.is_boundary and e.verts[0].co.z < -0.45}
    nuove = []
    while bordi:
        e0 = bordi.pop()
        anello = [e0.verts[0], e0.verts[1]]
        prec = e0
        while True:
            v = anello[-1]
            succ = [e for e in v.link_edges if e in bordi and e is not prec]
            if not succ:
                break
            prec = succ[0]
            bordi.discard(prec)
            w = prec.other_vert(v)
            if w is anello[0]:
                break
            anello.append(w)
        if len(anello) < 3:
            continue
        centro = sum((v.co for v in anello), Vector()) / len(anello)
        vc = bm.verts.new(centro)
        # il nuovo vertice eredita shape key e pesi dall'anello (altrimenti resterebbe fermo o andrebbe all'origine)
        for sl in bm.verts.layers.shape.values():
            vc[sl] = sum((v[sl] for v in anello), Vector()) / len(anello)
        dl = bm.verts.layers.deform.active
        if dl:
            for g, w in anello[0][dl].items():
                vc[dl][g] = w
        uv_c = Vector((0.0, 0.0))
        uvs = []
        for v in anello:
            l0 = v.link_loops[0] if v.link_loops else None
            uvs.append(l0[uv].uv.copy() if (l0 and uv) else Vector((0, 0)))
            uv_c += uvs[-1]
        uv_c /= len(anello)
        for i in range(len(anello)):
            a, b = anello[i], anello[(i + 1) % len(anello)]
            try:
                f = bm.faces.new((b, a, vc))
            except ValueError:
                continue
            f.material_index = idx_c
            f.smooth = True
            if uv:
                # toppa nascosta sotto la campana: UV ridotte a un punto (i vertici dell'anello possono stare in
                # isole diverse dell'atlante: un triangolo UV enorme sporcherebbe le texture cotte)
                for lp in f.loops:
                    lp[uv].uv = uvs[0]
            nuove.append(f)
    bmesh.ops.recalc_face_normals(bm, faces=nuove)
    # normali delle toppe verso il basso (fuori dalla campana)
    for f in nuove:
        if f.normal.z > 0:
            f.normal_flip()
    bm.to_mesh(me); bm.free()
    me.update()
    log(f'moncherini tolti: {len(via)} facce, buchi chiusi con {len(nuove)} triangoli')
    return len(via)


# ---------------------------------------------------------------- curve

def scegli_attacchi(n, rng):
    dati = leggi_json('attacchi_tentacoli.json')['moncherini']
    P = np.array([d['radice'] for d in dati])
    if n <= len(P):
        # campionamento del punto piu' lontano: attacchi ben distribuiti
        scelti = [int(np.argmax(np.hypot(P[:, 0], P[:, 1])))]
        while len(scelti) < n:
            d = np.min(np.linalg.norm(P[:, None, :2] - P[scelti][None, :, :2], axis=2), axis=1)
            scelti.append(int(np.argmax(d)))
        return P[scelti]
    extra = []
    for i in range(n - len(P)):
        a = 2 * math.pi * (i + 0.5) / (n - len(P))
        extra.append((0.26 * math.cos(a), 0.26 * math.sin(a), Z_SOTTOMBRELLA))
    return np.vstack([P, extra])


def base_perpendicolare(t):
    a = np.array([1.0, 0, 0]) if abs(t[0]) < 0.9 else np.array([0, 1.0, 0])
    u = np.cross(t, a); u /= np.linalg.norm(u)
    return u, np.cross(t, u)


def curva(radice, par, rng, lunghezza, ampiezza, forma=None, ds=None):
    """Linea centrale del tentacolo (punti ogni ds, di default 1,5 cm), che scende allargandosi dalla campana."""
    forma = forma or par['forma']
    radice = np.asarray(radice, float)
    fuori = np.array([radice[0], radice[1], 0.0])
    fuori = fuori / (np.linalg.norm(fuori) + 1e-9) if np.linalg.norm(fuori) > 0.02 else rng.normal(size=3) * [1, 1, 0]
    fuori /= np.linalg.norm(fuori)
    giu = np.array([0, 0, -1.0])
    ds = ds or par.get('passo_anelli', 0.015)
    n = max(int(lunghezza / ds), 8)
    pts = [radice.copy()]
    if forma == 'spezzata':
        # tratti dritti con pieghe secche, alternate destra/sinistra, il primo verso l'esterno
        d = giu + fuori * par['apertura'] * 1.6
        d /= np.linalg.norm(d)
        lato = np.cross(giu, fuori)
        lunghezza_fatta, segno = 0.0, rng.choice([-1, 1])
        while lunghezza_fatta < lunghezza:
            tratto = par['passo'] * rng.uniform(0.6, 1.4)
            k = max(int(tratto / ds), 2)
            for _ in range(k):
                pts.append(pts[-1] + d * ds)
            lunghezza_fatta += k * ds
            # nuova direzione: verso il basso, con una piega laterale e un po' di ritorno verso l'esterno
            ang = math.radians(par['angolo_pieghe'] * rng.uniform(0.6, 1.3))
            base = giu * (1 - min(lunghezza_fatta / lunghezza, 1) * 0.0) + fuori * par['apertura'] * 0.5
            base /= np.linalg.norm(base)
            asse_l = lato * segno + rng.normal(scale=0.35, size=3)
            asse_l -= base * (asse_l @ base); asse_l /= np.linalg.norm(asse_l) + 1e-9
            d = base * math.cos(ang) + asse_l * math.sin(ang)
            d /= np.linalg.norm(d)
            segno = -segno
        pts = np.array(pts)
        # taglia alla lunghezza giusta
        L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
        return pts[L <= lunghezza + 1e-6]
    # ondulata / nastro: asse che scende piegando verso l'esterno, piu' un'onda laterale crescente
    lato = np.cross(giu, fuori); lato /= np.linalg.norm(lato)
    fase = rng.uniform(0, 2 * math.pi)
    lam = par['passo'] * rng.uniform(0.8, 1.25)
    out = []
    p = radice.copy()
    d0 = giu + fuori * par['apertura'] * 1.5
    d0 /= np.linalg.norm(d0)
    for i in range(n + 1):
        s = i * ds
        t = s / lunghezza
        # direzione di base: dall'esterno verso il basso
        dbase = d0 * (1 - t) + giu * t
        dbase /= np.linalg.norm(dbase)
        if i:
            p = p + dbase * ds
        amp = ampiezza * (0.25 + 0.75 * t)
        off = lato * math.sin(2 * math.pi * s / lam + fase) * amp + fuori * math.sin(math.pi * s / lam + fase) * amp * 0.5
        out.append(p + off)
    return np.array(out)


def frame_lungo(pts):
    """Tangenti e normali a trasporto parallelo."""
    T = np.gradient(pts, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True) + 1e-12
    U = np.zeros_like(T)
    u, _ = base_perpendicolare(T[0])
    U[0] = u
    for i in range(1, len(T)):
        u = U[i - 1] - T[i] * (U[i - 1] @ T[i])
        n = np.linalg.norm(u)
        U[i] = u / n if n > 1e-9 else base_perpendicolare(T[i])[0]
    V = np.cross(T, U)
    return T, U, V


def tubo(pts, raggi, lati, piattezza=1.0, torsione=0.0):
    T, U, V = frame_lungo(pts)
    n = len(pts)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    verts, uvs = [], []
    for i in range(n):
        tw = 2 * math.pi * torsione * L[i] / max(L[-1], 1e-6)
        for j in range(lati):
            a = 2 * math.pi * j / lati + tw
            # sezione ellittica: larga "piattezza" volte lo spessore
            x = math.cos(a) * raggi[i] * math.sqrt(piattezza)
            y = math.sin(a) * raggi[i] / math.sqrt(piattezza)
            verts.append(pts[i] + U[i] * x + V[i] * y)
    facce = []
    for i in range(n - 1):
        for j in range(lati):
            jn = (j + 1) % lati
            facce.append((i * lati + j, i * lati + jn, (i + 1) * lati + jn, (i + 1) * lati + j))
    # punta chiusa
    tip = len(verts)
    verts.append(pts[-1] + T[-1] * raggi[-1])
    for j in range(lati):
        facce.append(((n - 1) * lati + j, (n - 1) * lati + (j + 1) % lati, tip))
    # UV: u intorno, v lungo (0 alla radice, 1 in punta)
    uv_facce = []
    for i in range(n - 1):
        for j in range(lati):
            v0, v1 = L[i] / L[-1], L[i + 1] / L[-1]
            u0, u1 = j / lati, (j + 1) / lati
            uv_facce.append([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
    for j in range(lati):
        uv_facce.append([(j / lati, 0.999), ((j + 1) / lati, 0.999), ((j + 0.5) / lati, 1.0)])
    return np.array(verts), facce, uv_facce, L


def raggi_lungo(L, par, r0, r1):
    t = L / L[-1]
    r = r1 + (r0 - r1) * (1 - t) ** 0.8
    r *= 1 + 0.35 * np.exp(-L / 0.035)      # attaccatura un po' svasata
    return r


# ---------------------------------------------------------------- oggetti, ossa, pesi

def oggetto_mesh(nome, verts, facce, uv_facce, mat):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([tuple(v) for v in verts], [], facce)
    uvl = me.uv_layers.new(name='UVMap')
    k = 0
    for f, uvs in zip(me.polygons, uv_facce):
        for li, uv in zip(f.loop_indices, uvs):
            uvl.data[li].uv = uv
    me.shade_smooth()
    me.materials.append(mat)
    ob = bpy.data.objects.new(nome, me)
    collega(ob)
    return ob


def materiale_tentacoli(nome, colore, ruvidita=0.25):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.name = 'BSDF'
    b.inputs['Base Color'].default_value = (*colore, 1)
    b.inputs['Roughness'].default_value = ruvidita
    b.inputs['Subsurface Weight'].default_value = 0.35
    b.inputs['Subsurface Radius'].default_value = (0.6, 0.15, 0.25)
    b.inputs['Coat Weight'].default_value = 0.4
    return m


def crea_tentacoli(arm, par, togli=True):
    """Crea tentacoli grossi (con ossa) e sottili (senza) e li lega allo scheletro. Ritorna gli oggetti."""
    rng = np.random.default_rng(par['seme'])
    corpo = bpy.data.objects['Medusa']
    if togli:
        togli_moncherini(corpo)
    radici = scegli_attacchi(par['n_grossi'], rng)
    mat = materiale_tentacoli('M_tentacoli', par['colore'])
    mat_f = materiale_tentacoli('M_filamenti', tuple(min(1, c * 1.15) for c in par['colore']), 0.3)
    tutti_v, tutte_f, tutti_uv, info = [], [], [], []
    for i, r in enumerate(radici):
        L = par['lunghezza'] * (1 + rng.uniform(-par['var_lunghezza'], par['var_lunghezza']))
        r = np.array(r) + np.array([0, 0, 0.012])                  # radice un po' dentro la campana
        pts = curva(r, par, rng, L, par['ampiezza'])
        rag = raggi_lungo(np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))], par,
                          par['raggio_base'], par['raggio_punta'])
        v, f, uv, Ls = tubo(pts, rag, par['lati'], par['piattezza'] if par['forma'] == 'nastro' else 1.0,
                            par['torsione'] if par['forma'] == 'nastro' else 0.0)
        off = sum(len(x) for x in tutti_v)
        tutti_v.append(v); tutte_f += [tuple(k + off for k in ff) for ff in f]; tutti_uv += uv
        info.append((pts, Ls, off, len(v)))
    grossi = oggetto_mesh('Medusa_Tentacoli', np.vstack(tutti_v), tutte_f, tutti_uv, mat)
    # filamenti sottili su un anello vicino al bordo interno
    fv, ff, fuv = [], [], []
    n_s = par['n_sottili']
    for i in range(n_s):
        a = 2 * math.pi * (i + rng.uniform(-0.3, 0.3)) / max(n_s, 1)
        rr = par['anello_sottili'] * rng.uniform(0.85, 1.0)
        rad = np.array([rr * math.cos(a), rr * math.sin(a), Z_SOTTOMBRELLA - 0.01 + 0.02])
        L = par['lunghezza_sottili'] * rng.uniform(0.75, 1.1)
        p2 = dict(par, apertura=par['apertura'] * 0.7, passo=0.35)
        pts = curva(rad, p2, rng, L, 0.03, forma='ondulata', ds=par.get('passo_anelli_sottili', 0.015))
        Ls = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
        rag = par['raggio_punta'] * 0.4 + (par['raggio_sottili'] - par['raggio_punta'] * 0.4) * (1 - Ls / Ls[-1])
        v, f, uv, _ = tubo(pts, rag, par.get('lati_sottili', 6))
        off = sum(len(x) for x in fv)
        fv.append(v); ff += [tuple(k + off for k in x) for x in f]; fuv += uv
    sottili = oggetto_mesh('Medusa_Filamenti', np.vstack(fv), ff, fuv, mat_f) if n_s else None
    lega_allo_scheletro(arm, grossi, info, par['n_ossa'])
    if sottili:
        sottili.parent = arm
        vg = sottili.vertex_groups.new(name='campana')
        vg.add(list(range(len(sottili.data.vertices))), 1.0, 'REPLACE')
        mod = sottili.modifiers.new('Scheletro', 'ARMATURE'); mod.object = arm
    log(f'tentacoli: {len(radici)} grossi ({par["forma"]}, {par["n_ossa"]} ossa ciascuno), {n_s} sottili; '
        f'{len(grossi.data.vertices) + (len(sottili.data.vertices) if sottili else 0)} vertici')
    return grossi, sottili


def lega_allo_scheletro(arm, ob, info, n_ossa):
    attiva(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    catene = []
    for i, (pts, Ls, off, nv) in enumerate(info):
        L = Ls[-1]
        nodi = [pts[np.searchsorted(Ls, min(k * L / n_ossa, L - 1e-6))] for k in range(n_ossa + 1)]
        nomi = []
        padre = eb['campana']
        for k in range(n_ossa):
            b = eb.new(f'tentacolo_{i + 1:02d}_{k + 1:02d}')
            b.head = Vector(nodi[k]); b.tail = Vector(nodi[k + 1])
            if (b.tail - b.head).length < 1e-4:
                b.tail = b.head + Vector((0, 0, -0.01))
            b.parent = padre
            b.use_connect = k > 0
            fuori = Vector((pts[0][0], pts[0][1], 0)).normalized()
            b.align_roll(fuori if fuori.length > 0 else Vector((1, 0, 0)))
            padre = b
            nomi.append(b.name)
        catene.append(nomi)
    bpy.ops.object.mode_set(mode='OBJECT')
    # pesi lungo la lunghezza: ogni vertice tra due ossa vicine (interpolazione lineare sui giunti)
    ob.parent = arm
    for i, (pts, Ls, off, nv) in enumerate(info):
        L = Ls[-1]
        lati = (nv - 1) // len(pts)
        s = np.repeat(Ls, lati)
        s = np.r_[s, L]
        x = np.clip(s / L * n_ossa - 0.5, 0, n_ossa - 1)
        k0 = np.floor(x).astype(int); k1 = np.minimum(k0 + 1, n_ossa - 1); f = x - k0
        gruppi = [ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n) for n in catene[i]]
        for j in range(nv):
            gruppi[k0[j]].add([off + j], float(1 - f[j]), 'ADD')
            if f[j] > 1e-4 and k1[j] != k0[j]:
                gruppi[k1[j]].add([off + j], float(f[j]), 'ADD')
    mod = ob.modifiers.new('Scheletro', 'ARMATURE'); mod.object = arm


def main():
    t0 = time.time()
    nome = sys.argv[sys.argv.index('--preset') + 1] if '--preset' in sys.argv else 'spezzati'
    apri(os.path.join(BUILD, 'medusa_04_scheletro.blend'))
    arm = bpy.data.objects['Medusa_Scheletro']
    crea_tentacoli(arm, PRESET[nome])
    salva(os.path.join(BUILD, f'medusa_05_tentacoli_{nome}.blend'))
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()


# ================================================================ tentacoli da statua (qualita' alta)
# La medusa sta IN PIEDI sui tentacoli (docs/concept/medusa_statua.jpg): le zampe escono da sotto la campana,
# si allargano come zampe di ragno, scendono a pieghe spezzate fino al piano del piedistallo, ci si appoggiano
# piatte e finiscono con un ricciolo che si alza. I medi e i sottili scendono sotto la campana e si piegano sul
# piano (qualche sottile resta sospeso). Ogni tentacolo e' un nastro carnoso (docs/concept/medusa_sottacqua.jpg):
# sezione piatta a lente, larghezza e spessore variabili, si assottiglia verso la punta, si attorciglia tra una
# piega e l'altra e alle pieghe si piega "di piatto", come un nastro vero; bordi increspati.
# Tutti hanno una catena di ossa (le azioni fluttua/insegue li fanno pendere).
# Un solo oggetto (Medusa_Tentacoli) e un solo materiale (M_tentacoli) con texture generate qui:
# UV u intorno alla sezione (zampe nella meta' sinistra della texture, medi e sottili in quella destra),
# v lungo il tentacolo (0 alla radice, 1 in punta).

STATUA = dict(
    z_pavimento=-1.75,      # piano del piedistallo (coordinate del modello): ~1,05 m sotto il bordo della campana
    raggio_max=0.93,        # i tentacoli restano dentro questo raggio (piedistallo di raggio >= 1,05 m)
    seme=5,
    classi=(
        # angolo = gradi massimi tra due anelli nelle curve strette (ricciolo, pieghe)
        dict(nome='zampe', n=6, larghezza=0.125, spessore=0.048, lati=10, passo=0.024, ossa=10,
             crespe=0.26, onda=0.14, liscia=0.032, torsione=0.9, angolo=15, u0=0.0),
        dict(nome='medi', n=7, larghezza=0.062, spessore=0.022, lati=8, passo=0.028, ossa=7,
             crespe=0.26, onda=0.13, liscia=0.026, torsione=1.1, angolo=20, u0=0.5),
        dict(nome='sottili', n=12, larghezza=0.034, spessore=0.012, lati=6, passo=0.034, ossa=4,
             crespe=0.2, onda=0.15, liscia=0.02, torsione=1.4, angolo=28, u0=0.5),
    ),
)
Z_RADICI = -0.515           # radici appena sopra la sottombrella (z = -0.53): nascoste nel corpo
TEX_TENT_BASE = os.path.join(TEX, 'tentacoli_base.jpg')
TEX_TENT_EMIS = os.path.join(TEX, 'tentacoli_emissione.jpg')
TEX_TENT_NORMAL = os.path.join(TEX, 'tentacoli_normal.png')
ZETA = np.array([0, 0, 1.0])


# ---------------------------------------------------------------- percorsi (linee centrali grezze)

def _assi(az):
    return np.array([math.cos(az), math.sin(az), 0.0]), np.array([-math.sin(az), math.cos(az), 0.0])


def _discesa(p, az, z_fine, rng, passo, deriva, zig):
    """Tratti dritti verso il basso con pieghe secche alternate, fino alla quota z_fine (ultimo tratto tagliato)."""
    fuori, lato = _assi(az)
    pts, segno, d = [], rng.choice([-1, 1]), np.array([0, 0, -1.0])
    for _ in range(40):
        d = np.array([0, 0, -1.0]) + fuori * rng.uniform(*deriva) + lato * segno * zig * rng.uniform(0.45, 1.0)
        d /= np.linalg.norm(d)
        q = p + d * rng.uniform(*passo)
        segno = -segno
        if q[2] <= z_fine:
            q = p + (q - p) * (p[2] - z_fine) / (p[2] - q[2])
            pts.append(q)
            return pts, d
        pts.append(q)
        p = q
    return pts, d


def _piede(p, d_arrivo, rng, lungo, rho0, giri, ds=0.004):
    """Dal contatto col piano: striscia piatta sul piano, poi un ricciolo che si alza arrotolandosi in avanti
    (il nastro si arrotola di piatto, come un nastro da pacchi). Ritorna punti, direzione del piede e l'indice
    (nella lista) del primo punto del ricciolo."""
    d = np.array([d_arrivo[0], d_arrivo[1], 0.0])
    if np.linalg.norm(d) < 1e-3:
        d = np.array([1.0, 0, 0])
    d /= np.linalg.norm(d)
    a = rng.uniform(-0.6, 0.6)
    d = np.array([d[0] * math.cos(a) - d[1] * math.sin(a), d[0] * math.sin(a) + d[1] * math.cos(a), 0.0])
    n = max(int(lungo / ds), 2)
    pts = [p + d * lungo * i / n for i in range(1, n + 1)]
    inizio = len(pts)
    C = pts[-1] + ZETA * rho0
    tot = 2 * math.pi * giri
    m = max(int(tot * rho0 / ds), 8)
    for i in range(1, m + 1):
        f = i / m
        th = -math.pi / 2 + tot * f
        pts.append(C + (d * math.cos(th) + ZETA * math.sin(th)) * rho0 * (1 - 0.62 * f))
    return pts, d, inizio


def _caviglia(p, az, zc, rng, piatto):
    """Ultimo tratto prima del piano: inclinato in fuori (piu' o meno di lato), arriva sul piano a zc."""
    fuori, lato = _assi(az)
    h = fuori + lato * rng.uniform(-0.6, 0.6)
    h /= np.linalg.norm(h)
    d = h * rng.uniform(*piatto) + np.array([0, 0, -1.0])
    return p + d * (p[2] - zc) / -d[2]


def percorso_zampa(az, cl, zp, rng):
    """Zampa: esce da sotto il bordo della campana, va in fuori quasi orizzontale (ginocchio), scende a pieghe
    rientrando un po' verso il centro, si appoggia sul piano e finisce col ricciolo."""
    fuori, lato = _assi(az)

    def P(r, z, l=0.0):
        return fuori * r + lato * l + np.array([0, 0, z])

    j = lambda s: rng.uniform(-s, s)  # noqa: E731
    zc = zp + cl['spessore'] * 0.3
    pts = [P(rng.uniform(0.24, 0.28), Z_RADICI),
           P(0.33 + j(0.008), -0.77 + j(0.012), j(0.02)),
           P(rng.uniform(0.52, 0.64), rng.uniform(-0.78, -0.68), j(0.08)),         # gomito
           P(rng.uniform(0.76, 0.94), rng.uniform(-0.74, -0.56), j(0.12))]          # ginocchio, come un ragno
    # discesa a pieghe fino a poco sopra il piano, poi la caviglia: l'ultimo tratto arriva inclinato (in fuori)
    # e il piede si stende sul piano, come una zampa che regge il peso
    disc, d = _discesa(pts[-1], az, zc + rng.uniform(0.16, 0.26), rng, passo=(0.17, 0.27), deriva=(-0.55, 0.05),
                       zig=0.5)
    pts += disc
    pts.append(_caviglia(pts[-1], az, zc, rng, (0.35, 0.8)))
    d = pts[-1] - pts[-2]
    pieghe, contatto = list(range(1, len(pts) - 1)), len(pts) - 1
    piede, dp, ir = _piede(pts[-1], d, rng, rng.uniform(0.12, 0.2), rng.uniform(0.05, 0.066), rng.uniform(1.0, 1.4))
    ricciolo = len(pts) + ir
    pts += piede
    return dict(pts=np.array(pts), pieghe=pieghe, contatto=contatto, ricciolo=ricciolo, d_piede=dp, az=az)


def percorso_pendente(az, r0, cl, zp, rng, a_terra=True, piccolo=False):
    """Medi e sottili: scendono sotto la campana a pieghe, allargandosi un po'; se a_terra si appoggiano sul
    piano col piede e il ricciolo, altrimenti finiscono sospesi."""
    fuori, lato = _assi(az)

    def P(r, z, l=0.0):
        return fuori * r + lato * l + np.array([0, 0, z])

    zc = zp + cl['spessore'] * 0.3
    pts = [P(r0, Z_RADICI), P(r0 + rng.uniform(0.0, 0.04), rng.uniform(-0.82, -0.74), rng.uniform(-0.03, 0.03))]
    passo = (0.12, 0.22) if piccolo else (0.15, 0.27)
    deriva = (0.0, 0.32) if piccolo else (0.05, 0.45)
    if not a_terra:
        disc, d = _discesa(pts[-1], az, rng.uniform(-1.6, -1.25), rng, passo=passo, deriva=deriva, zig=0.5)
        pts += disc
        return dict(pts=np.array(pts), pieghe=list(range(1, len(pts) - 1)), contatto=None, ricciolo=None,
                    d_piede=None, az=az)
    disc, d = _discesa(pts[-1], az, zc + rng.uniform(0.08, 0.18), rng, passo=passo, deriva=deriva, zig=0.5)
    pts += disc
    pts.append(_caviglia(pts[-1], az, zc, rng, (0.6, 1.2)))
    d = pts[-1] - pts[-2]
    pieghe, contatto = list(range(1, len(pts) - 1)), len(pts) - 1
    if piccolo:
        piede, dp, ir = _piede(pts[-1], d, rng, rng.uniform(0.05, 0.12), rng.uniform(0.016, 0.024), rng.uniform(0.5, 1.0))
    else:
        piede, dp, ir = _piede(pts[-1], d, rng, rng.uniform(0.08, 0.16), rng.uniform(0.028, 0.04), rng.uniform(0.8, 1.2))
    ricciolo = len(pts) + ir
    pts += piede
    return dict(pts=np.array(pts), pieghe=pieghe, contatto=contatto, ricciolo=ricciolo, d_piede=dp, az=az)


# ---------------------------------------------------------------- nastro

def _rmf(P, T, U0):
    """Riferimento a rotazione minima (doppia riflessione): niente giri spuri lungo la curva."""
    U = np.zeros_like(P)
    U[0] = U0
    for i in range(len(P) - 1):
        v1 = P[i + 1] - P[i]
        c1 = v1 @ v1
        if c1 < 1e-14:
            U[i + 1] = U[i]
            continue
        rL = U[i] - (2 / c1) * (v1 @ U[i]) * v1
        tL = T[i] - (2 / c1) * (v1 @ T[i]) * v1
        v2 = T[i + 1] - tL
        c2 = v2 @ v2
        r = rL - (2 / c2) * (v2 @ rL) * v2 if c2 > 1e-14 else rL
        r = r - T[i + 1] * (r @ T[i + 1])
        U[i + 1] = r / np.linalg.norm(r)
    return U


def _angolo(Ur, Ud, t):
    Ud = Ud - t * (Ud @ t)
    nd = np.linalg.norm(Ud)
    if nd < 1e-6:
        return None
    Ud = Ud / nd
    return math.atan2(np.cross(Ur, Ud) @ t, Ur @ Ud)


def nastro_statua(perc, cl, zp, rng):
    """Superficie del nastro lungo il percorso. Ritorna un dict con vertici, facce, UV per faccia, lunghezza
    lungo il tentacolo per ogni vertice (per i pesi), linea centrale e larghezze."""
    raw = perc['pts']
    Lr = np.r_[0, np.cumsum(np.linalg.norm(np.diff(raw, axis=0), axis=1))]
    Ltot = Lr[-1]
    # 1) campionamento fine + smussatura gaussiana delle pieghe (non nel ricciolo, che e' gia' liscio)
    hf = 0.003
    nf = max(int(Ltot / hf), 16)
    sf = np.linspace(0, Ltot, nf + 1)
    Pf = np.stack([np.interp(sf, Lr, raw[:, k]) for k in range(3)], 1)
    sig = cl['liscia'] / (Ltot / nf)
    rad = int(3 * sig) + 1
    k = np.arange(-rad, rad + 1)
    g = np.exp(-0.5 * (k / sig) ** 2)
    g /= g.sum()
    pad = np.vstack([np.repeat(Pf[:1], rad, 0), Pf, np.repeat(Pf[-1:], rad, 0)])
    Ps = np.stack([np.convolve(pad[:, c], g, mode='valid') for c in range(3)], 1)
    s_ric = Lr[perc['ricciolo']] if perc['ricciolo'] is not None else Ltot + 1
    m = np.clip((sf - (s_ric - 0.04)) / 0.04, 0, 1)
    Pf = Ps * (1 - m)[:, None] + Pf * m[:, None]
    Pf[0] = raw[0]
    # 2) anelli: passo base, piu' fitti dove la curva gira (al massimo cl['angolo'] gradi tra due anelli)
    Tf = np.diff(Pf, axis=0)
    Tf /= np.linalg.norm(Tf, axis=1, keepdims=True) + 1e-12
    ang = np.arccos(np.clip((Tf[1:] * Tf[:-1]).sum(1), -1, 1)) / hf
    kap = np.r_[ang[0], ang, ang[-1]]
    kap = np.convolve(np.pad(kap, 4, mode='edge'), np.ones(9) / 9, mode='valid')
    dens = np.maximum(1 / cl['passo'], kap / math.radians(cl['angolo']))
    N = np.r_[0, np.cumsum((dens[1:] + dens[:-1]) / 2 * np.diff(sf))]
    ns = max(int(math.ceil(N[-1])), 8)
    s = np.interp(np.linspace(0, N[-1], ns + 1), N, sf)
    P = np.stack([np.interp(s, sf, Pf[:, c]) for c in range(3)], 1)
    n = len(P)
    # 3) larghezza e spessore: tengono fino al piano (reggono il peso), poi si assottigliano nel piede e nel ricciolo
    w0, t0 = cl['larghezza'], cl['spessore']
    f1, f2, f3, f4 = rng.uniform(0, 2 * math.pi, 4)
    s_c = Lr[perc['contatto']] if perc['contatto'] is not None else None
    if s_c is not None:
        a = np.clip(s / s_c, 0, 1)
        b = np.clip((s - s_c) / max(Ltot - s_c, 1e-6), 0, 1)
        prof = np.where(s <= s_c, 1 - 0.42 * a ** 1.4, 0.58 - 0.47 * b ** 0.9)
    else:
        prof = 1 - 0.86 * (s / Ltot) ** 1.2
    prof = prof * (1 + 0.3 * np.exp(-s / 0.04))
    var = (1 + 0.14 * np.sin(2 * math.pi * s / 0.33 + f1)) * (1 + 0.07 * np.sin(2 * math.pi * s / 0.12 + f2))
    W = w0 * prof * var
    Tk = t0 * prof * (1 + 0.12 * np.sin(2 * math.pi * s / 0.27 + f3))
    # sul piano: il nastro poggia (centro a meta' spessore sopra il piano); nessun punto sotto il piano
    terra = np.zeros(n) if s_c is None else np.clip((s - (s_c - 0.05)) / 0.05, 0, 1)
    z_min = zp + Tk / 2 + 0.0015
    if s_c is not None:
        piede = (s >= s_c + 0.015) & (s <= s_ric)
        P[piede, 2] = z_min[piede]
    P[:, 2] = np.maximum(P[:, 2], z_min)
    # 4) orientamento del nastro: riferimento a rotazione minima + torsione; alle pieghe il nastro si piega di
    #    piatto (larghezza perpendicolare al piano della piega), sul piano sta disteso
    T = np.gradient(P, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True) + 1e-12
    fuori, lato = _assi(perc['az'])
    U0 = np.cross(T[0], ZETA)
    U0 = U0 / np.linalg.norm(U0) if np.linalg.norm(U0) > 1e-3 else lato
    Ur = _rmf(P, T, U0)
    anc = [(0, U0)]
    for q in perc['pieghe']:
        din, dout = raw[q] - raw[q - 1], raw[q + 1] - raw[q]
        bn = np.cross(din, dout)
        if np.linalg.norm(bn) < 0.12 * np.linalg.norm(din) * np.linalg.norm(dout):
            continue
        i = int(np.argmin(np.abs(s - Lr[q])))
        if i > anc[-1][0]:
            anc.append((i, bn / np.linalg.norm(bn)))
    if s_c is not None:
        u_terra = np.cross(ZETA, perc['d_piede'])
        u_terra /= np.linalg.norm(u_terra)
        for i in np.nonzero(s >= s_c + 0.02)[0]:
            if i > anc[-1][0]:
                anc.append((int(i), u_terra))
    sgn = rng.choice([-1, 1])
    rate = cl['torsione'] * 2 * math.pi / Ltot
    idx, phis = [], []
    for i, Ud in anc:
        ph = _angolo(Ur[i], Ud, T[i])
        if ph is None:
            continue
        if phis:
            want = phis[-1] + sgn * rate * (s[i] - s[idx[-1]]) * rng.uniform(0.4, 1.6)
            ph += round((want - ph) / math.pi) * math.pi
        idx.append(i)
        phis.append(ph)
    if idx[-1] < n - 1:                     # ultimo tratto libero (tentacoli sospesi): continua a girare
        idx.append(n - 1)
        phis.append(phis[-1] + sgn * rate * (s[-1] - s[idx[-2]]))
    phi = np.empty(n)
    phi[:idx[0] + 1] = phis[0]
    for kk in range(1, len(idx)):
        i0, i1 = idx[kk - 1], idx[kk]
        t = (s[i0:i1 + 1] - s[i0]) / max(s[i1] - s[i0], 1e-9)
        w = t * t * t * (t * (6 * t - 15) + 10)          # la torsione sta a meta' tratto, piatta alle pieghe
        phi[i0:i1 + 1] = phis[kk - 1] + (phis[kk] - phis[kk - 1]) * w
    phi[idx[-1]:] = phis[-1]
    Vr = np.cross(T, Ur)
    U = Ur * np.cos(phi)[:, None] + Vr * np.sin(phi)[:, None]
    V = np.cross(T, U)
    # 5) bordi increspati (onda piu' corta dove il nastro e' stretto) e un filo di coppa (bordi piegati da un lato)
    lam = cl['onda'] * (0.65 + 0.35 * np.clip(W / w0, 0, 1.3))
    fase = 2 * math.pi * np.r_[0, np.cumsum(np.diff(s) / ((lam[1:] + lam[:-1]) / 2))]
    radice = np.clip((s - 0.12) / 0.2, 0, 1)
    f5, f6 = rng.uniform(0, 2 * math.pi, 2)
    A = cl['crespe'] * W * radice * (1 - terra) * (0.6 + 0.4 * np.sin(2 * math.pi * s / 0.43 + f5)
                                                   * np.sin(2 * math.pi * s / 0.17 + f6))
    coppa = 0.16 * W * np.sin(2 * math.pi * s / 0.5 + f4) * radice * (1 - terra)
    lati = cl['lati']
    a = 2 * math.pi * np.arange(lati) / lati
    ca, sa = np.cos(a), np.sin(a)
    bordo = np.abs(ca) ** 3
    sfas = np.where(ca >= 0, 0.0, 2.2) + rng.uniform(0, 1)
    x = (W / 2)[:, None] * ca[None, :]
    y = ((Tk / 2)[:, None] * sa[None, :] + A[:, None] * np.sin(fase[:, None] + sfas[None, :]) * bordo[None, :]
         + coppa[:, None] * (ca ** 2)[None, :])
    verts = P[:, None, :] + U[:, None, :] * x[..., None] + V[:, None, :] * y[..., None]
    verts = verts.reshape(-1, 3)
    # 6) facce, tappo alla radice e punta
    facce, uvf = [], []
    u0 = cl['u0']
    v = s / Ltot
    for i in range(n - 1):
        for jj in range(lati):
            jn = (jj + 1) % lati
            facce.append((i * lati + jj, i * lati + jn, (i + 1) * lati + jn, (i + 1) * lati + jj))
            uvf.append([(u0 + 0.5 * jj / lati, v[i]), (u0 + 0.5 * (jj + 1) / lati, v[i]),
                        (u0 + 0.5 * (jj + 1) / lati, v[i + 1]), (u0 + 0.5 * jj / lati, v[i + 1])])
    c_rad = len(verts)
    c_tip = c_rad + 1
    verts = np.vstack([verts, P[0] - T[0] * 0.003, P[-1] + T[-1] * Tk[-1] * 0.6])
    for jj in range(lati):
        jn = (jj + 1) % lati
        facce.append((jn, jj, c_rad))
        uvf.append([(u0 + 0.5 * (jj + 1) / lati, 0.0), (u0 + 0.5 * jj / lati, 0.0), (u0 + 0.5 * (jj + 0.5) / lati, 0.0)])
        facce.append(((n - 1) * lati + jj, (n - 1) * lati + jn, c_tip))
        uvf.append([(u0 + 0.5 * jj / lati, 0.999), (u0 + 0.5 * (jj + 1) / lati, 0.999),
                    (u0 + 0.5 * (jj + 0.5) / lati, 1.0)])
    s_vert = np.r_[np.repeat(s, lati), 0.0, Ltot]
    return dict(verts=verts, facce=facce, uv=uvf, s_vert=s_vert, P=P, s=s, W=W + 2 * A, Ltot=Ltot)


def _libero(nas, accettati, salta=0.28, margine=0.006):
    """Il nuovo tentacolo non deve compenetrare quelli gia' fatti (fuori dalla campana)."""
    from scipy.spatial import cKDTree
    sel = nas['s'] > salta
    if not accettati or not sel.any():
        return True
    Pn, Rn = nas['P'][sel], nas['W'][sel] / 2
    for albero, R in accettati:
        d, j = albero.query(Pn)
        if np.any(d < (Rn + R[j]) * 0.85 + margine):
            return False
    return True


def _dentro(nas, rmax):
    """Tutto il tentacolo (bordi compresi) sta sul piedistallo."""
    return bool(np.all(np.hypot(nas['P'][:, 0], nas['P'][:, 1]) + nas['W'] / 2 < rmax))


def _accetta(nas, accettati, salta=0.28):
    from scipy.spatial import cKDTree
    sel = nas['s'] > salta
    accettati.append((cKDTree(nas['P'][sel]), nas['W'][sel] / 2))


# ---------------------------------------------------------------- texture e materiale

def texture_tentacoli(lato=2048):
    """Texture dei tentacoli (u intorno alla sezione, v lungo): colore, emissione e normal map.
    Meta' sinistra: zampe; meta' destra: medi e sottili (piu' chiari)."""
    import cv2
    rng = np.random.default_rng(3)
    H, Wt = lato, lato // 2
    v = 1 - (np.arange(H) + 0.5) / H                     # riga 0 = v alto (punta)
    u = (np.arange(Wt) + 0.5) / Wt
    V, Uu = np.meshgrid(v, u, indexing='ij')
    sx = Uu >= 0.5
    ul = np.where(sx, (Uu - 0.5) / 0.5, Uu / 0.5)         # 0..1 intorno alla sezione; bordi a 0 e 0.5
    a = 2 * math.pi * ul
    ca = np.abs(np.cos(a))

    def rumore(gy, gx, scala=1.0):
        r = rng.normal(size=(gy, gx)).astype(np.float32)
        r = cv2.resize(r, (Wt, H), interpolation=cv2.INTER_CUBIC)
        return r / (r.std() + 1e-6) * scala

    def gradiente(stop):
        pos = np.array([p for p, _ in stop]); col = np.array([c for _, c in stop])
        return np.stack([np.interp(V, pos, col[:, i]) for i in range(3)], -1)

    zampe = gradiente([(0.0, (0.26, 0.02, 0.17)), (0.12, (0.40, 0.03, 0.26)), (0.55, (0.58, 0.05, 0.38)),
                       (0.85, (0.72, 0.12, 0.48)), (1.0, (0.85, 0.30, 0.60))])
    altri = gradiente([(0.0, (0.36, 0.03, 0.24)), (0.5, (0.66, 0.10, 0.46)), (1.0, (0.88, 0.38, 0.66))])
    col = np.where(sx[..., None], altri, zampe)
    vena = np.exp(-0.5 * (np.cos(a) / 0.07) ** 2)          # linea al centro delle due facce piatte
    vena2 = np.exp(-0.5 * ((ca - 0.62) / 0.05) ** 2) * 0.5  # due venature laterali piu' deboli
    bordo = ca ** 8
    fibre = 0.5 + 0.5 * np.sin(2 * math.pi * 11 * ul + 1.3 * np.sin(2 * math.pi * 2.5 * V) + rumore(8, 4, 0.8))
    macchie = rumore(24, 6, 1.0)
    col = col * (1 - 0.07 * fibre[..., None]) * (1 + 0.035 * macchie[..., None])
    col = col + (np.array([0.95, 0.32, 0.66]) - col) * (0.25 * vena + 0.12 * vena2)[..., None] * (1 - 0.5 * V)[..., None]
    col = col + (np.array([0.95, 0.50, 0.78]) - col) * (0.35 * bordo)[..., None]
    col = np.clip(col, 0, 1)
    cv2.imwrite(TEX_TENT_BASE, (col * 255).astype(np.uint8)[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, 93])
    # emissione (sRGB): vena luminosa (piu' forte verso la radice), bordi appena accesi, bagliore di fondo
    em = (np.array([1.0, 0.18, 0.70]) * (0.42 * vena + 0.2 * vena2)[..., None] * (1 - 0.45 * V)[..., None]
          + np.array([1.0, 0.40, 0.80]) * (0.16 * ca ** 12)[..., None]
          + np.array([0.11, 0.006, 0.07]))
    em = em * (1 + 0.15 * macchie[..., None])
    cv2.imwrite(TEX_TENT_EMIS, (np.clip(em, 0, 1) * 255).astype(np.uint8)[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, 93])
    # normal map: fibre lungo il tentacolo, grinze di traverso, granulosita' leggera
    grinze = np.sin(2 * math.pi * (55 * V + 0.6 * np.sin(2 * math.pi * 2 * ul) + rumore(16, 4, 0.25))) ** 2
    h = 0.6 * fibre + 0.35 * grinze * (0.4 + 0.6 * ca) + 0.15 * rumore(256, 128, 1.0)
    gu = np.gradient(h, axis=1)
    gr = np.gradient(h, axis=0)
    forza = 3.0
    nrm = np.stack([-gu * forza, gr * forza, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    cv2.imwrite(TEX_TENT_NORMAL, ((nrm * 0.5 + 0.5) * 255).astype(np.uint8)[..., ::-1])
    log('texture tentacoli:', os.path.relpath(TEX_TENT_BASE, REPO), os.path.relpath(TEX_TENT_EMIS, REPO),
        os.path.relpath(TEX_TENT_NORMAL, REPO))


def materiale_tentacoli_statua(nome='M_tentacoli'):
    """Carne traslucida e laccata: texture (colore, emissione, normal), subsurface, coat."""
    texture_tentacoli()
    m = materiale_pbr(nome, base=TEX_TENT_BASE, normal=TEX_TENT_NORMAL, roughness=0.26, normal_strength=0.8)
    nt = m.node_tree
    b = nt.nodes['BSDF']
    te = nodo(nt, 'ShaderNodeTexImage', (-400, -650))
    te.image = immagine(TEX_TENT_EMIS)
    te.name = 'emissione'
    nt.links.new(te.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 1.5          # leggero bagliore interno (vena)
    b.inputs['Subsurface Weight'].default_value = 0.45
    b.inputs['Subsurface Radius'].default_value = (1.0, 0.12, 0.55)
    b.inputs['Subsurface Scale'].default_value = 0.035
    b.inputs['Coat Weight'].default_value = 0.35
    b.inputs['Coat Roughness'].default_value = 0.06
    b.inputs['Transmission Weight'].default_value = 0.05
    b.inputs['IOR'].default_value = 1.4
    return m


# ---------------------------------------------------------------- creazione, ossa e pesi

def lega_catene(arm, ob, catene):
    """Una catena di ossa per tentacolo (tentacolo_NN_01 ... figlie di 'campana'), lungo la linea centrale;
    pesi lineari lungo la lunghezza tra due ossa vicine."""
    attiva(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    for c in catene:
        L = c['s'][-1]
        nodi = [np.array([np.interp(k * L / c['ossa'], c['s'], c['P'][:, q]) for q in range(3)])
                for k in range(c['ossa'] + 1)]
        padre, nomi = eb['campana'], []
        fuori = Vector((c['P'][0][0], c['P'][0][1], 0))
        fuori = fuori.normalized() if fuori.length > 1e-4 else Vector((1, 0, 0))
        for k in range(c['ossa']):
            b = eb.new(f'{c["nome"]}_{k + 1:02d}')
            b.head = Vector(nodi[k])
            b.tail = Vector(nodi[k + 1])
            if (b.tail - b.head).length < 1e-4:
                b.tail = b.head + Vector((0, 0, -0.01))
            b.parent = padre
            b.use_connect = k > 0
            b.align_roll(fuori)
            padre = b
            nomi.append(b.name)
        c['nomi_ossa'] = nomi
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.parent = arm
    for c in catene:
        n, L = c['ossa'], c['s'][-1]
        x = np.clip(c['s_vert'] / L * n - 0.5, 0, n - 1)
        k0 = np.floor(x).astype(int)
        k1 = np.minimum(k0 + 1, n - 1)
        f = x - k0
        gruppi = [ob.vertex_groups.new(name=nm) for nm in c['nomi_ossa']]
        for jv in range(len(x)):
            gruppi[k0[jv]].add([c['off'] + jv], float(1 - f[jv]), 'REPLACE')
            if f[jv] > 1e-4 and k1[jv] != k0[jv]:
                gruppi[k1[jv]].add([c['off'] + jv], float(f[jv]), 'REPLACE')
    mod = ob.modifiers.new('Scheletro', 'ARMATURE')
    mod.object = arm


def genera_tentacoli_statua(par=STATUA):
    """Solo geometria (senza Blender): lista di (classe, percorso, nastro)."""
    rng = np.random.default_rng(par['seme'])
    zp = par['z_pavimento']
    cz, cm, cs = par['classi']
    fatti, accettati = [], []
    # zampe: distribuite intorno, la prima a 30 gradi dal davanti (-Y), cosi' il davanti resta aperto
    for i in range(cz['n']):
        for prova in range(40):
            az = math.radians(-90 + 30 + 360 * i / cz['n']) + rng.uniform(-0.17, 0.17)
            perc = percorso_zampa(az, cz, zp, rng)
            nas = nastro_statua(perc, cz, zp, rng)
            if _libero(nas, accettati) and _dentro(nas, par['raggio_max']):
                break
        else:
            log(f'zampa {i}: nessuna posizione libera, la tengo comunque')
        _accetta(nas, accettati)
        fatti.append((cz, perc, nas))
    for cl, piccolo in ((cm, False), (cs, True)):
        for i in range(cl['n']):
            a_terra = (not piccolo) or rng.uniform() < 0.72
            for prova in range(60):
                az = 2 * math.pi * (i + rng.uniform(-0.4, 0.4)) / cl['n'] + (0.4 if piccolo else 0.0)
                r0 = rng.uniform(0.07, 0.24) if not piccolo else rng.uniform(0.1, 0.31)
                perc = percorso_pendente(az, r0, cl, zp, rng, a_terra=a_terra, piccolo=piccolo)
                nas = nastro_statua(perc, cl, zp, rng)
                if _libero(nas, accettati) and _dentro(nas, par['raggio_max']):
                    break
            else:
                log(f'tentacolo {cl["nome"]} {i}: nessuna posizione libera, lo tengo comunque')
            _accetta(nas, accettati)
            fatti.append((cl, perc, nas))
    return fatti


def crea_tentacoli_statua(arm, par=STATUA, togli=True):
    """Crea i tentacoli da statua (un oggetto, un materiale) con le catene di ossa. Ritorna l'oggetto."""
    corpo = bpy.data.objects['Medusa']
    if togli:
        togli_moncherini(corpo)
    fatti = genera_tentacoli_statua(par)
    mat = materiale_tentacoli_statua('M_tentacoli')
    tv, tf, tuv, catene = [], [], [], []
    off = 0
    for i, (cl, perc, nas) in enumerate(fatti):
        tv.append(nas['verts'])
        tf += [tuple(k + off for k in f) for f in nas['facce']]
        tuv += nas['uv']
        catene.append(dict(nome=f'tentacolo_{i + 1:02d}', P=nas['P'], s=nas['s'], s_vert=nas['s_vert'],
                           ossa=cl['ossa'], off=off))
        off += len(nas['verts'])
    ob = oggetto_mesh('Medusa_Tentacoli', np.vstack(tv), tf, tuv, mat)
    lega_catene(arm, ob, catene)
    ntri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    conta = {}
    for cl, _, _ in fatti:
        conta[cl['nome']] = conta.get(cl['nome'], 0) + 1
    log(f'tentacoli da statua: {conta}, {ntri} triangoli, {sum(c["ossa"] for c in catene)} ossa; '
        f'piano del piedistallo a z = {par["z_pavimento"]}')
    return ob
