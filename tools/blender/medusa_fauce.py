"""Fauce nascosta della medusa: strappo orizzontale sotto l'occhio, da guancia a guancia, con file di
denti da squalo. Da chiusa non si vede nulla.

Come funziona (pensato per Godot):
  - la pelle del viso si taglia lungo una curva sotto l'orbita (piano inclinato: un "sorriso");
    i due bordi coincidono a bocca chiusa, gli angoli restano uniti;
  - il mento (sotto il taglio) e' pesato sull'osso "mascella", con pesi che sfumano verso gli angoli
    e verso il collo: aprire = ruotare la mascella e abbassarla (valori in APERTURA);
  - la gola (carne) e i denti sono mesh a parte con geometria "collassata" a riposo (area zero,
    invisibile) e una shape key "fauce_aperta" che li apre nella forma finale;
  - denti da squalo che si incastrano: una fila scende dall'arcata di sopra e una sale da quella di sotto,
    una di fronte all'altra e sfalsate di mezzo dente, tutte e due inclinate verso l'interno della bocca e con
    la punta ricurva all'indietro; le file interne sono piu' piccole, piu' indietro e piu' coricate;
  - la shape key "fauce_strappo" del corpo rende frastagliati i bordi dello strappo.
In Godot l'animazione "fauce_apre" muove insieme l'osso e le tre blend shape (0 = chiusa, 1 = aperta).
"""
import math

import numpy as np
import bpy
import bmesh
from mathutils import Matrix, Vector

from medusa_comune import log, collega, coords, set_coords, materiale_pbr

# piano del taglio: passa per il centro (0, -0.19, 0.488) e sale verso gli angoli (y=-0.155, z=0.505)
CENTRO_TAGLIO = Vector((0.0, -0.19, 0.488))
ANGOLO_X = 0.095
CERNIERA = Vector((0.0, -0.10, 0.49))       # testa dell'osso mascella
APERTURA = {'rotazione_x_gradi': 15.0, 'spostamento': (0.0, -0.01, -0.095)}
N_FILE = 3                                    # file di denti per arcata
SCALA_FILE = (1.0, 0.72, 0.52)                # grandezza delle file, dalla prima (sul labbro) verso la gola
PASSO_FILE = (2, 3, 4)                        # ogni quante colonne del bordo c'e' un dente
DENTRO_FILE = (0.3, 0.55, 0.85)               # inclinazione verso l'interno della bocca (le file dietro sono coricate)


def piano_taglio():
    a = Vector((ANGOLO_X, -0.155, 0.505)) - CENTRO_TAGLIO
    b = Vector((-ANGOLO_X, -0.155, 0.505)) - CENTRO_TAGLIO
    n = a.cross(b).normalized()
    if n.z < 0:
        n = -n
    return CENTRO_TAGLIO.copy(), n


def matrice_apertura(f=1.0):
    """Trasformazione (spazio armatura) della mascella aperta di una frazione f."""
    R = Matrix.Rotation(math.radians(APERTURA['rotazione_x_gradi'] * f), 4, 'X')
    T = Matrix.Translation(Vector(APERTURA['spostamento']) * f)
    H = Matrix.Translation(CERNIERA)
    return T @ H @ R @ H.inverted()


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- taglio e pesi del viso

def taglia_viso(corpo):
    """Taglia la pelle lungo il piano e separa i due bordi. Ritorna (indici bordo sopra, bordo sotto)
    ordinati da un angolo all'altro (stessa posizione a riposo)."""
    me = corpo.data
    idx_pelle = [m.name for m in me.materials].index('M_pelle')
    c, n = piano_taglio()
    bm = bmesh.new(); bm.from_mesh(me)
    sel = [f for f in bm.faces if f.material_index == idx_pelle and abs(f.calc_center_median().x) < ANGOLO_X
           and f.calc_center_median().y < -0.12 and 0.46 < f.calc_center_median().z < 0.53]
    ev = list({e for f in sel for e in f.edges}); vv = list({v for f in sel for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=vv + ev + sel, plane_co=c, plane_no=n, dist=1e-5)
    bm.faces.ensure_lookup_table(); bm.verts.ensure_lookup_table()
    sul_piano = lambda v: abs((v.co - c).dot(n)) < 2e-5  # noqa: E731
    taglio = [e for e in bm.edges if sul_piano(e.verts[0]) and sul_piano(e.verts[1])
              and all(abs(v.co.x) < ANGOLO_X + 0.01 and v.co.y < -0.1 for v in e.verts)
              and len(e.link_faces) == 2
              and all(f.material_index == idx_pelle for f in e.link_faces)]
    # triangola le facce tagliate
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    taglio = [e for e in bm.edges if sul_piano(e.verts[0]) and sul_piano(e.verts[1])
              and all(abs(v.co.x) < ANGOLO_X + 0.01 and v.co.y < -0.1 for v in e.verts)
              and len(e.link_faces) == 2 and all(f.material_index == idx_pelle for f in e.link_faces)]
    # catena ordinata da x negativa a x positiva
    vcount = {}
    for e in taglio:
        for v in e.verts:
            vcount[v] = vcount.get(v, 0) + 1
    estremi = sorted([v for v, k in vcount.items() if k == 1], key=lambda v: v.co.x)
    log(f'fauce: taglio di {len(taglio)} lati, estremi {[tuple(round(x, 3) for x in v.co) for v in estremi]}')
    bmesh.ops.split_edges(bm, edges=taglio)
    bm.verts.ensure_lookup_table()
    # dopo lo split: bordo aperto sul piano. Gli angoli (non separati) sono i due estremi in x;
    # gli altri vertici sono doppi: uno attaccato alle facce sopra il piano, uno a quelle sotto
    bm.verts.ensure_lookup_table()
    bordo = [v for v in bm.verts if v.is_boundary and sul_piano(v) and abs(v.co.x) < ANGOLO_X + 0.01
             and v.co.y < -0.1]
    angoli = [min(bordo, key=lambda v: v.co.x), max(bordo, key=lambda v: v.co.x)]
    sopra, sotto = [], []
    for v in bordo:
        if v in angoli:
            continue
        lato = sum((f.calc_center_median() - c).dot(n) for f in v.link_faces)
        (sopra if lato > 0 else sotto).append(v)
    sopra = [angoli[0]] + sorted(sopra, key=lambda v: v.co.x) + [angoli[1]]
    sotto = [angoli[0]] + sorted(sotto, key=lambda v: v.co.x) + [angoli[1]]
    sopra = [v.index for v in sopra]; sotto = [v.index for v in sotto]
    bm.to_mesh(me); bm.free()
    me.update()
    log(f'fauce: bordo sopra {len(sopra)} vertici, sotto {len(sotto)} (angoli in comune)')
    assert len(sopra) == len(sotto), 'i due bordi dello strappo devono avere gli stessi vertici'
    return sopra, sotto


def pesi_mascella(corpo, bordo_sotto):
    """Peso della mascella sul mento (sotto il taglio, compreso il bordo di sotto dello strappo),
    sfumato verso gli angoli, il collo e la nuca."""
    me = corpo.data
    co = coords(me)
    c, n = piano_taglio()
    sotto = ((co - np.array(c)) @ np.array(n)) < -1e-6
    sotto[np.array(bordo_sotto)] = True
    x, y, z = co.T
    w = (1 - _smooth(0.055, ANGOLO_X + 0.004, np.abs(x))) ** 0.6
    # il mento resta rigido fino all'attaccatura del collo: niente pelle stirata dentro la bocca aperta
    w *= 1 - _smooth(-0.075, -0.045, y)
    w *= _smooth(0.412, 0.442, z)
    w *= sotto & (z < 0.53) & (np.abs(x) < 0.13)
    vg_m = corpo.vertex_groups.get('mascella') or corpo.vertex_groups.new(name='mascella')
    vg_t = corpo.vertex_groups['testa']
    nz = np.nonzero(w > 1e-3)[0]
    for i in nz:
        vg_m.add([int(i)], float(w[i]), 'REPLACE')
        # il resto del peso resta alla testa (o al collo, dove c'era)
        v = me.vertices[int(i)]
        altri = [(g.group, g.weight) for g in v.groups if g.group != vg_m.index]
        tot = sum(p for _, p in altri)
        for g, p in altri:
            corpo.vertex_groups[g].add([int(i)], float(p / max(tot, 1e-9) * (1 - w[i])), 'REPLACE')
    log(f'fauce: {len(nz)} vertici del mento sulla mascella')
    return w


# ---------------------------------------------------------------- gola e denti

def _profilo_aperto(P_sopra, P_sotto, k_frac):
    """Punti (aperti, spazio mondo) della gola per una colonna k: dal labbro di sopra, sotto il bulbo,
    fino in fondo alla gola, e di nuovo fuori fino al labbro di sotto."""
    xs = P_sopra[0]
    larg = 0.35 + 0.65 * (1 - (2 * k_frac - 1) ** 2)   # anche agli angoli la gola ha un po' di fondo
    fondo = Vector((xs * 0.35, -0.075, 0.432 - 0.006 * larg))
    tetto = [P_sopra,
             Vector((xs * 0.95, P_sopra[1] + 0.016 * larg, P_sopra[2] - 0.012 * larg)),
             Vector((xs * 0.85, -0.158 + 0.02 * (1 - larg), 0.462 + 0.01 * (1 - larg))),
             Vector((xs * 0.65, -0.125, 0.447)),
             fondo]
    pavimento = [P_sotto,
                 Vector((P_sotto[0] * 0.95, P_sotto[1] + 0.02 * larg, P_sotto[2] + 0.006 * larg)),
                 Vector((P_sotto[0] * 0.85, P_sotto[1] + 0.045 * larg, P_sotto[2] + 0.012 * larg)),
                 Vector((P_sotto[0] * 0.65, (P_sotto[1] + fondo[1]) / 2 + 0.01, (P_sotto[2] + fondo[2]) / 2 + 0.004)),
                 fondo]
    # verso gli angoli il pavimento si richiude sul tetto: la gola e' chiusa ai lati (niente buchi)
    b = min(min(k_frac, 1 - k_frac) / 0.05, 1.0)          # solo gli ultimi vertici verso l'angolo
    b = b * b * (3 - 2 * b)
    pavimento = [pavimento[0]] + [t + (p - t) * b for t, p in zip(tetto[1:], pavimento[1:])]
    return tetto, pavimento


def costruisci_gola_e_denti(corpo, arm, sopra, sotto, w_mascella):
    me = corpo.data
    co = coords(me)
    K = min(len(sopra), len(sotto))
    sopra, sotto = sopra[:K], sotto[:K]
    M = matrice_apertura(1.0)
    # bordi aperti (mondo): sopra fermo, sotto mosso dalla mascella con il suo peso
    U = [Vector(co[i]) for i in sopra]
    L = []
    for i in sotto:
        w = float(w_mascella[i])
        p = Vector(co[i])
        L.append(p * (1 - w) + (M @ p) * w)
    J = 4                                           # righe per meta' gola
    verts_aperti, pesi = [], []
    for k in range(K):
        tetto, pav = _profilo_aperto(U[k], L[k], k / max(K - 1, 1))
        col = tetto + pav[:-1][::-1]                # tetto (labbro -> fondo) poi pavimento (fondo -> labbro)
        verts_aperti.append(col)
        wk = float(w_mascella[sotto[k]])
        # tetto e fondo fermi con la testa; il pavimento segue la mascella (piena sul labbro, meno in fondo)
        pesi.append([0.0] * (J + 1) + [wk * (1 - 0.8 * p / J) for p in range(J - 1, -1, -1)])
    R = 2 * J + 1
    # a riposo la gola e' collassata sul bordo (area zero, invisibile)
    base = []
    for k in range(K):
        for j in range(R):
            base.append(Vector(co[sopra[k]]))
    facce = []
    for k in range(K - 1):
        for j in range(R - 1):
            a, b = k * R + j, (k + 1) * R + j
            facce.append((a, b, b + 1, a + 1))
    gme = bpy.data.meshes.new('Medusa_Gola')
    gme.from_pydata([tuple(v) for v in base], [], facce)
    uvl = gme.uv_layers.new(name='UVMap')
    for f in gme.polygons:
        for li in f.loop_indices:
            vi = gme.loops[li].vertex_index
            k, j = divmod(vi, R)
            uvl.data[li].uv = (k / max(K - 1, 1), 1 - abs(j - J) / J)   # v = 1 sul labbro, 0 in fondo
    gme.shade_smooth()
    gola = bpy.data.objects.new('Medusa_Gola', gme)
    collega(gola)
    # pesi e shape key (posizioni aperte riportate a riposo invertendo la mascella pesata)
    vg_t = gola.vertex_groups.new(name='testa'); vg_m = gola.vertex_groups.new(name='mascella')
    gola.shape_key_add(name='Basis', from_mix=False)
    sk = gola.shape_key_add(name='fauce_aperta', from_mix=False)
    I4 = Matrix.Identity(4)
    for k in range(K):
        for j in range(R):
            vi = k * R + j
            w = pesi[k][j]
            Mw = Matrix([[I4[r][c] * (1 - w) + M[r][c] * w for c in range(4)] for r in range(4)])
            p_riposo = Mw.inverted() @ verts_aperti[k][j]
            sk.data[vi].co = p_riposo
            if w > 1e-4:
                vg_m.add([vi], w, 'REPLACE')
            if w < 1 - 1e-4:
                vg_t.add([vi], 1 - w, 'REPLACE')
    # normali verso l'interno della bocca (si vede da davanti): controllo sulla forma aperta
    _orienta_normali(gola, sk, verso=Vector((0, -1, 0)))
    gola.parent = arm
    mod = gola.modifiers.new('Scheletro', 'ARMATURE'); mod.object = arm
    denti = crea_denti(arm, verts_aperti, pesi, K, J, M)
    return gola, denti


def _orienta_normali(ob, sk, verso):
    """Gira le facce in modo che, nella forma aperta, guardino verso 'verso' (fuori dalla bocca)."""
    me = ob.data
    aperto = np.array([d.co[:] for d in sk.data])
    girare = 0
    for f in me.polygons:
        vs = [aperto[i] for i in f.vertices]
        nrm = np.cross(vs[1] - vs[0], vs[2] - vs[0])
        cen = np.mean(vs, axis=0)
        # verso il centro della bocca aperta (davanti e un po' sotto)
        dentro = np.array([0, -0.16, 0.45]) - cen
        if nrm @ dentro < 0:
            girare += 1
    if girare > len(me.polygons) / 2:
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(me); bm.free()


def dente(base, asse, larghezza, lunghezza, lato, piega, rng):
    """Dente da squalo: lama triangolare piatta con il bordo seghettato, la punta ricurva verso 'piega'.
    Ritorna vertici e facce."""
    asse = asse.normalized()
    lato = (lato - asse * lato.dot(asse)).normalized()
    spess = asse.cross(lato).normalized()
    piega = (piega - asse * piega.dot(asse)).normalized()
    curva = rng.uniform(0.08, 0.18)
    pts = []
    n_seg = 3
    for s in range(n_seg + 1):
        t = s / n_seg
        w = larghezza * 0.5 * (1 - t) ** 0.9
        if 0 < s < n_seg and s % 2 == 1:
            w *= 1.15                                 # seghettatura
        c = base + asse * lunghezza * t + piega * curva * lunghezza * t * t
        pts.append((c + lato * w, c - lato * w, c + spess * larghezza * 0.18 * (1 - t), c - spess * larghezza * 0.18 * (1 - t)))
    verts, facce = [], []
    for s, (a, b, f, r) in enumerate(pts):
        verts += [a, f, b, r]
    for s in range(n_seg):
        o, p = s * 4, (s + 1) * 4
        for q in range(4):
            facce.append((o + q, o + (q + 1) % 4, p + (q + 1) % 4, p + q))
    facce.append((0, 3, 2, 1))
    return verts, facce


def crea_denti(arm, verts_aperti, pesi, K, J, M):
    rng = np.random.default_rng(3)
    tutti_v, tutte_f, pesi_v, basi = [], [], [], []
    dentro = Vector((0, 1, 0))                      # verso la gola
    for meta in ('tetto', 'pavimento'):
        for fila in range(N_FILE):
            j = 1 + fila if meta == 'tetto' else 2 * J - 1 - fila
            scala = SCALA_FILE[fila]
            passo = PASSO_FILE[fila]
            # le due arcate sfalsate di una colonna: i denti di sotto cadono tra quelli di sopra (si incastrano)
            inizio = 1 + fila % 2 + (1 if meta == 'pavimento' else 0)
            for k in range(inizio, K - 1, passo):
                frac = k / max(K - 1, 1)
                centro = 1 - (2 * frac - 1) ** 2
                if centro < 0.12:
                    continue
                p = verts_aperti[k][j]
                pk = verts_aperti[min(k + 1, K - 1)][j] - verts_aperti[max(k - 1, 0)][j]
                # asse: verso l'altra arcata (giu' per il tetto, su per il pavimento) e verso l'interno della bocca;
                # niente pendenza di lato: le due file sono una lo specchio dell'altra
                verticale = Vector((0, 0, -1)) if meta == 'tetto' else Vector((0, 0, 1))
                asse = (verticale + dentro * DENTRO_FILE[fila]).normalized()
                lung = (0.012 + 0.014 * centro) * scala * rng.uniform(0.9, 1.1)
                larg = lung * rng.uniform(0.62, 0.75)
                v, f = dente(p, asse, larg, lung, pk, dentro, rng)
                off = len(tutti_v)
                tutti_v += v
                tutte_f += [tuple(x + off for x in ff) for ff in f]
                w = pesi[k][j]
                pesi_v += [w] * len(v)
                basi += [p] * len(v)
    dme = bpy.data.meshes.new('Medusa_Denti')
    # a riposo ogni dente e' collassato nel suo punto di base (invisibile)
    I4 = Matrix.Identity(4)
    base_riposo = []
    aperto_riposo = []
    for v, b, w in zip(tutti_v, basi, pesi_v):
        Mw = Matrix([[I4[r][c] * (1 - w) + M[r][c] * w for c in range(4)] for r in range(4)])
        Mi = Mw.inverted()
        base_riposo.append(Mi @ b)
        aperto_riposo.append(Mi @ v)
    dme.from_pydata([tuple(v) for v in base_riposo], [], tutte_f)
    dme.shade_smooth()
    denti = bpy.data.objects.new('Medusa_Denti', dme)
    collega(denti)
    denti.shape_key_add(name='Basis', from_mix=False)
    sk = denti.shape_key_add(name='fauce_aperta', from_mix=False)
    for i, p in enumerate(aperto_riposo):
        sk.data[i].co = p
    vg_t = denti.vertex_groups.new(name='testa'); vg_m = denti.vertex_groups.new(name='mascella')
    for i, w in enumerate(pesi_v):
        if w > 1e-4:
            vg_m.add([i], w, 'REPLACE')
        if w < 1 - 1e-4:
            vg_t.add([i], 1 - w, 'REPLACE')
    denti.parent = arm
    mod = denti.modifiers.new('Scheletro', 'ARMATURE'); mod.object = arm
    log(f'fauce: {len(tutte_f) // 13} denti in {N_FILE} file per arcata')
    return denti


def strappo_bordi(corpo, sopra, sotto):
    """Shape key 'fauce_strappo': quando la bocca si apre i bordi diventano uno strappo vero, a lembi di pelle
    irregolari (2-4 vertici l'uno, alcuni ritirati e altri che pendono nella bocca), un po' arrovesciati in fuori;
    la pelle intorno segue un poco (due anelli di vertici). A bocca chiusa non cambia nulla."""
    from medusa_comune import adiacenza_vertici
    me = corpo.data
    if me.shape_keys is None:
        corpo.shape_key_add(name='Basis', from_mix=False)
    sk = corpo.shape_key_add(name='fauce_strappo', from_mix=False)
    co = coords(me)
    rng = np.random.default_rng(11)
    delta = np.zeros_like(co)
    c, n = piano_taglio()
    n = np.array(n)
    bordo = set()
    for catena, segno in ((sopra, 1), (sotto, -1)):
        nc = len(catena)
        prof = np.zeros(nc)
        t = 0
        while t < nc:
            w = int(rng.integers(2, 5))
            alto = rng.uniform(0.004, 0.017) * (1.0 if rng.random() < 0.55 else -0.4)
            for j in range(w):
                if t + j < nc:
                    forma = 1 - abs((j + 0.5) / w * 2 - 1)            # lembo a punta
                    prof[t + j] = alto * (0.3 + 0.7 * forma) + rng.normal(scale=0.0012)
            t += w
        for idx, i in enumerate(catena):
            frac = idx / max(nc - 1, 1)
            centro = 1 - (2 * frac - 1) ** 2
            delta[i] += n * segno * prof[idx] * (0.25 + 0.75 * centro)
            delta[i] += np.array([0.0, -0.007, 0.0]) * centro         # labbra arrovesciate in fuori
            bordo.add(i)
    # la pelle vicina segue un poco (pelle che si arriccia)
    ev = adiacenza_vertici(me)
    vicini = {}
    for a, b in ev:
        vicini.setdefault(a, []).append(b)
        vicini.setdefault(b, []).append(a)
    anello, visti = set(bordo), set(bordo)
    for peso in (0.45, 0.33):              # primo anello 45% del bordo, secondo un terzo del primo
        nuovo_anello = set()
        add = {}
        for i in anello:
            for j in vicini.get(i, []):
                if j in visti:
                    continue
                add.setdefault(j, []).append(delta[i])
                nuovo_anello.add(j)
        for j, ds in add.items():
            delta[j] += np.mean(ds, axis=0) * peso
        visti |= nuovo_anello
        anello = nuovo_anello
    sk.data.foreach_set('co', (co + delta).ravel())
    sk.value = 0.0
    return sk


def materiali_fauce(gola, denti):
    mg = bpy.data.materials.new('M_fauce_carne')
    mg.use_nodes = True
    nt = mg.node_tree
    b = nt.nodes['Principled BSDF']; b.name = 'BSDF'
    uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.035, 0.002, 0.006, 1)   # fondo della gola, quasi nero
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (0.42, 0.03, 0.06, 1)      # carne rosso scuro
    e = ramp.color_ramp.elements.new(1.0); e.color = (0.62, 0.12, 0.16, 1)
    nt.links.new(uv.outputs['UV'], sep.inputs['Vector'])
    nt.links.new(sep.outputs['Y'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.18
    b.inputs['Subsurface Weight'].default_value = 0.25
    b.inputs['Subsurface Radius'].default_value = (0.8, 0.1, 0.1)
    b.inputs['Coat Weight'].default_value = 0.6
    gola.data.materials.append(mg)
    md = bpy.data.materials.new('M_denti')
    md.use_nodes = True
    b = md.node_tree.nodes['Principled BSDF']; b.name = 'BSDF'
    b.inputs['Base Color'].default_value = (0.86, 0.82, 0.72, 1)
    b.inputs['Roughness'].default_value = 0.22
    b.inputs['Subsurface Weight'].default_value = 0.15
    b.inputs['Coat Weight'].default_value = 0.4
    denti.data.materials.append(md)


def sposta_osso_mascella(arm):
    from medusa_comune import attiva
    attiva(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    b = arm.data.edit_bones['mascella']
    b.head = CERNIERA
    b.tail = Vector((0.0, -0.19, 0.45))
    b.align_roll(Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode='OBJECT')


def costruisci_fauce(arm):
    corpo = bpy.data.objects['Medusa']
    sposta_osso_mascella(arm)
    sopra, sotto = taglia_viso(corpo)
    w = pesi_mascella(corpo, sotto)
    gola, denti = costruisci_gola_e_denti(corpo, arm, sopra, sotto, w)
    strappo_bordi(corpo, sopra, sotto)
    materiali_fauce(gola, denti)
    return gola, denti


def apri_fauce(arm, f=1.0):
    """Posa della mascella aperta (frazione f) + shape key: per i render e per l'animazione."""
    pb = arm.pose.bones['mascella']
    rest = arm.data.bones['mascella'].matrix_local
    # l'apertura e' definita a riposo: se la testa e' in posa (busto in avanti, corpo sollevato) la mascella
    # la segue, altrimenti resterebbe indietro staccata dalla testa
    bpy.context.view_layer.update()
    pt = arm.pose.bones[arm.data.bones['mascella'].parent.name]
    D = pt.matrix @ arm.data.bones[pt.name].matrix_local.inverted()
    pb.matrix = D @ matrice_apertura(f) @ rest
    bpy.context.view_layer.update()
    for nome, key in (('Medusa', 'fauce_strappo'), ('Medusa_Gola', 'fauce_aperta'), ('Medusa_Denti', 'fauce_aperta')):
        ob = bpy.data.objects.get(nome)
        if ob and ob.data.shape_keys and key in ob.data.shape_keys.key_blocks:
            ob.data.shape_keys.key_blocks[key].value = f
