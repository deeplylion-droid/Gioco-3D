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
                f.loops[0][uv].uv = uvs[(i + 1) % len(anello)]
                f.loops[1][uv].uv = uvs[i]
                f.loops[2][uv].uv = uv_c
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


def curva(radice, par, rng, lunghezza, ampiezza, forma=None):
    """Linea centrale del tentacolo (punti ogni ~1,5 cm), che scende allargandosi dalla campana."""
    forma = forma or par['forma']
    radice = np.asarray(radice, float)
    fuori = np.array([radice[0], radice[1], 0.0])
    fuori = fuori / (np.linalg.norm(fuori) + 1e-9) if np.linalg.norm(fuori) > 0.02 else rng.normal(size=3) * [1, 1, 0]
    fuori /= np.linalg.norm(fuori)
    giu = np.array([0, 0, -1.0])
    ds = 0.015
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
        pts = curva(rad, p2, rng, L, 0.03, forma='ondulata')
        Ls = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
        rag = par['raggio_punta'] * 0.4 + (par['raggio_sottili'] - par['raggio_punta'] * 0.4) * (1 - Ls / Ls[-1])
        v, f, uv, _ = tubo(pts, rag, 6)
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
