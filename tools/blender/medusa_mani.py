"""Mani nuove da bambola in vinile (modello base: valgono per tutte le pose e tutte le animazioni).

Le mani di Meshy non si potevano salvare (dita fuse come cera sciolta, niente nocche, pollice quasi sparito):
si tolgono dal corpo e al loro posto c'e' un oggetto nuovo, Medusa_Mani, costruito qui intorno alle ossa della
mano nella posa di riposo del passo 4, quando la mano e' aperta:
  - palmo a scatola arrotondata, eminenza del pollice, polso a sfera che entra nell'avambraccio come nelle
    bambole (la giuntura e' il solco del polso; il buco dell'avambraccio si chiude con un tappo rientrato);
  - cinque dita separate, ognuna lungo le sue tre ossa: si assottigliano verso la punta, hanno le nocche in
    rilievo sul dorso (anche quelle grandi alla base) e le unghie appena accennate sull'ultima falange;
  - i pezzi si uniscono con un remesh a voxel, poi la superficie si liscia e si riduce;
  - pesi puliti: al massimo due ossa per vertice (le due falangi di una piega, oppure palmo e prima falange),
    niente influenze da un dito all'altro, il polso segue solo la mano: in Godot (4 influenze al massimo) si
    deformano come in Blender.
Anche lo scheletro della mano e' nuovo (quello vecchio era adattato alla mano rovinata): nocche in fila, dita a
ventaglio con tre falangi proporzionate, pollice opponibile; la mano e' lunga circa quanto il viso.
Materiale M_mani: la tinta della pelle presa dalla texture dell'avambraccio vicino al polso, vinile laccato come
la pelle; nei colori dei vertici le unghie appena piu' chiare e l'occlusione nelle pieghe tra le dita.

Uso dal passo 7, prima della posa statua: rifai_ossa_mano(arm), togli_mani_vecchie(arm, corpo),
crea_mani(arm, corpo).
"""
import math
import os
import sys

import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

DITA = ('pollice', 'indice', 'medio', 'anulare', 'mignolo')
# Scheletro nuovo della mano (quello del passo 4 era adattato alla mano rovinata di Meshy: dita una sopra
# l'altra, lunghezze a caso). Misure in frazioni della lunghezza della mano H (dal polso alla punta del medio),
# nel riferimento della mano: x verso il pollice, y lungo la mano, z sul dorso.
OSSA_MANO = dict(
    lunghezza=0.28,             # H in unita' del modello (0,47 m sulla statua vera: circa quanto il viso)
    palmo=0.46,                 # dal polso alle nocche
    piega=7.0,                  # piega naturale a ogni articolazione (gradi): mano rilassata
    # nocca (x, y, z), apertura (gradi, positiva verso il mignolo), falangi
    indice=((0.125, 0.44, 0.0), -7.0, (0.20, 0.12, 0.09)),
    medio=((0.035, 0.46, 0.0), 0.0, (0.22, 0.135, 0.095)),
    anulare=((-0.055, 0.44, 0.0), 7.0, (0.20, 0.125, 0.09)),
    mignolo=((-0.14, 0.40, -0.005), 14.0, (0.155, 0.095, 0.08)),
    pollice=((0.11, 0.13, -0.035), None, (0.19, 0.15, 0.11)),
)
MANI = dict(
    spessore=dict(pollice=1.2, indice=1.0, medio=1.04, anulare=0.97, mignolo=0.86),
    raggio=0.05,                # raggio di base delle dita (frazione di H): dita da bambola, piene
    rastremazione=(1.0, 0.93, 0.85, 0.76),   # raggio alle articolazioni: base, PIP, DIP, punta
    voxel=0.0018,               # remesh (unita' del modello: circa 3 mm sulla statua vera)
    facce=6000,                 # facce per mano dopo la riduzione
)
TEX_COLORE = os.path.join(TEX, 'medusa_colore_4k.jpg')


def _catena(arm, d, suf):
    nomi = [f'{d}_{f}{suf}' for f in (1, 2, 3)]
    B = arm.data.bones
    J = [np.array(B[nomi[0]].head_local)] + [np.array(B[n].tail_local) for n in nomi]
    return nomi, J


# ---------------------------------------------------------------- ossa e corpo

def _riferimento_mano(arm, suf):
    """Riferimento della mano (polso, x verso il pollice, y lungo la mano, z sul dorso) dalle ossa di riposo."""
    B = arm.data.bones
    w = np.array(B['mano' + suf].head_local)
    M = B['mano' + suf].matrix_local.to_3x3()
    y = np.array(M.col[1])
    z = np.array(M.col[2])
    z = z - (z @ y) * y
    z /= np.linalg.norm(z)
    x = np.cross(y, z)
    # il pollice: da che parte stava quello vecchio
    pol = np.array(B['pollice_2' + suf].head_local) - w
    if pol @ x < 0:
        x = -x
    return w, x, y, z


def rifai_ossa_mano(arm):
    """Scheletro della mano nuovo e pulito (stessi nomi delle ossa): nocche in fila, dita aperte a ventaglio con
    tre falangi proporzionate, pollice opponibile; asse Z di ogni osso sul dorso, piega intorno all'asse X."""
    O = OSSA_MANO
    H = O['lunghezza']
    rif = {s: _riferimento_mano(arm, s) for s in ('.L', '.R')}
    attiva(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    for suf in ('.L', '.R'):
        w, x, y, z = rif[suf]
        V = lambda q: Vector(w + x * q[0] * H + y * q[1] * H + z * q[2] * H)
        D = lambda q: Vector(x * q[0] + y * q[1] + z * q[2]).normalized()
        b = eb['mano' + suf]
        b.tail = V((0.0, O['palmo'], 0.0))
        b.align_roll(Vector(z))
        for d in DITA:
            base, apertura, falangi = O[d]
            if d == 'pollice':
                dirc = np.array([0.42, 0.82, -0.40])
                dorso = np.array([0.62, 0.1, 0.78])
            else:
                a = math.radians(apertura)
                dirc = np.array([-math.sin(a), math.cos(a), 0.0])
                dorso = np.array([0.0, 0.0, 1.0])
            dirc /= np.linalg.norm(dirc)
            lat = np.cross(dirc, dorso)
            lat /= np.linalg.norm(lat)
            p = np.array(base, float)
            for f, L in enumerate(falangi, 1):
                ang = math.radians(O['piega']) * f
                # piega naturale verso il palmo (intorno all'asse laterale del dito)
                dk = dirc * math.cos(ang) - np.cross(lat, dirc) * math.sin(ang)
                zk = np.cross(lat, dk)
                q = p + dk * L
                bb = eb[f'{d}_{f}{suf}']
                bb.head, bb.tail = V(p), V(q)
                bb.align_roll(D(zk))
                p = q
    bpy.ops.object.mode_set(mode='OBJECT')
    log(f'mani: scheletro nuovo (mano lunga {H:.3f}, {H * 1.668:.2f} m sulla statua vera)')


def _raggio_avambraccio(arm, corpo, suf):
    """Raggio medio dell'avambraccio negli ultimi 3 cm (modello) prima del polso."""
    me = corpo.data
    co = coords(me)
    B = arm.data.bones['avambraccio' + suf]
    h, t = np.array(B.head_local), np.array(B.tail_local)
    a = t - h
    L = np.linalg.norm(a)
    a /= L
    u = (co - h) @ a
    vicino = (u > L - 0.03) & (u < L - 0.004)
    rad = np.linalg.norm((co - h) - u[:, None] * a, axis=1)
    sel = vicino & (rad < 0.06)
    return float(np.median(rad[sel])) if sel.any() else 0.025


def _anelli(edges):
    """Vertici dei bordi in ordine, anello per anello."""
    adj = {}
    for e in edges:
        a, b = e.verts
        adj.setdefault(a, []).append(b)
        adj.setdefault(b, []).append(a)
    visti, anelli = set(), []
    for v0 in adj:
        if v0 in visti:
            continue
        anello, prev, cur = [v0], None, v0
        visti.add(v0)
        while True:
            nxt = [w for w in adj[cur] if w is not prev and w not in visti]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
            anello.append(cur)
            visti.add(cur)
        anelli.append(anello)
    return anelli


def togli_mani_vecchie(arm, corpo):
    """Toglie dal corpo le facce delle mani vecchie (peso di mano e dita > 0,5), chiude il polso con un tappo
    rientrato e passa all'avambraccio i pesi di mano rimasti (l'avambraccio non segue piu' la mano)."""
    me = corpo.data
    gruppi = {vg.index: vg.name for vg in corpo.vertex_groups}
    di_mano = {i for i, n in gruppi.items() if n.rsplit('.', 1)[0].split('_')[0] in ('mano',) + DITA}
    av = {s: corpo.vertex_groups['avambraccio' + s].index for s in ('.L', '.R')}
    frac = np.zeros(len(me.vertices))
    tot = np.zeros(len(me.vertices))
    for v in me.vertices:
        for g in v.groups:
            tot[v.index] += g.weight
            if g.group in di_mano:
                frac[v.index] += g.weight
    frac /= np.maximum(tot, 1e-9)
    polsi = {s: np.array(arm.data.bones['mano' + s].head_local) for s in ('.L', '.R')}
    raggi = {s: _raggio_avambraccio(arm, corpo, s) for s in ('.L', '.R')}
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    fl = bm.faces.layers.int.get('_mano') or bm.faces.layers.int.new('_mano')
    for f in bm.faces:
        f[fl] = 1 if np.mean([frac[v.index] for v in f.verts]) > 0.5 else 0
    # taglio netto: un piano perpendicolare all'avambraccio poco prima del polso (la sfera del polso della mano
    # nuova esce dal taglio come in una bambola); si taglia solo vicino al polso
    n_via = 0
    for s in ('.L', '.R'):
        p = np.array(polsi[s])
        ax = np.array(arm.data.bones['avambraccio' + s].tail_local) - np.array(arm.data.bones['avambraccio' + s].head_local)
        ax /= np.linalg.norm(ax)
        piano = p - ax * 0.6 * raggi[s]
        vicine = [f for f in bm.faces if np.linalg.norm(np.array(f.calc_center_median()) - p) < 0.25]
        geom = list({e for f in vicine for e in f.edges}) + vicine + list({v for f in vicine for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=Vector(piano), plane_no=Vector(ax))
        via = [f for f in bm.faces if np.linalg.norm(np.array(f.calc_center_median()) - p) < 0.3 and
               (np.array(f.calc_center_median()) - piano) @ ax > 0]
        via += [f for f in bm.faces if f[fl] == 1 and (f.calc_center_median().x > 0) == (s == '.L') and f not in via]
        n_via += len(via)
        bmesh.ops.delete(bm, geom=via, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.verts.ensure_lookup_table()
    dl = bm.verts.layers.deform.active
    uvl = bm.loops.layers.uv.active
    shape = list(bm.verts.layers.shape.values())
    # pesi: quello che resta della mano va all'avambraccio
    for v in bm.verts:
        dv = v[dl]
        dentro = [g for g in dv.keys() if g in di_mano]
        if dentro:
            s = '.L' if v.co.x > 0 else '.R'
            w = sum(dv[g] for g in dentro)
            for g in dentro:
                del dv[g]
            dv[av[s]] = dv.get(av[s], 0.0) + w
    # tappi ai polsi: un ventaglio di triangoli intorno a un vertice rientrato verso il gomito
    tappi = 0
    raggi_taglio = dict(raggi)
    for s in ('.L', '.R'):
        p = Vector(polsi[s])
        bordo = [e for e in bm.edges if e.is_boundary and (e.verts[0].co - p).length < 4.0 * raggi[s]]
        ax = Vector(np.array(arm.data.bones['avambraccio' + s].tail_local) -
                    np.array(arm.data.bones['avambraccio' + s].head_local)).normalized()
        for anello in _anelli(bordo):
            if len(anello) < 5:
                continue
            P = np.array([v.co for v in anello])
            q = P - p
            raggi_taglio[s] = float(np.median(np.linalg.norm(q - (q @ np.array(ax))[:, None] * np.array(ax), axis=1)))
            uv0 = None
            for lp in anello[0].link_loops:
                uv0 = lp[uvl].uv.copy()
                break
            c = sum((v.co for v in anello), Vector()) / len(anello)
            centro = bm.verts.new(c - ax * 0.35 * raggi[s])
            centro[dl][av[s]] = 1.0
            for sl in shape:
                centro[sl] = centro.co.copy()
            nuove = []
            chiuso = anello[-1] in [e.other_vert(anello[0]) for e in anello[0].link_edges if e.is_boundary]
            coppie = list(zip(anello, anello[1:] + ([anello[0]] if chiuso else [])))
            for a, b in coppie:
                try:
                    f = bm.faces.new((a, b, centro))
                except ValueError:
                    continue
                f.material_index = 0
                f.smooth = True
                for lp in f.loops:
                    if uv0 is not None:
                        lp[uvl].uv = uv0
                nuove.append(f)
            bmesh.ops.recalc_face_normals(bm, faces=nuove)
            # verso giusto: il tappo guarda verso la mano
            if nuove and nuove[0].normal.dot(ax) < 0:
                for f in nuove:
                    f.normal_flip()
            tappi += 1
    bm.to_mesh(me)
    bm.free()
    me.update()
    log(f'mani vecchie tolte: {n_via} facce, {tappi} tappi ai polsi (raggio avambraccio '
        f'{raggi_taglio[".L"]:.3f}/{raggi_taglio[".R"]:.3f} al taglio)')
    return raggi_taglio


# ---------------------------------------------------------------- mano nuova

def _sfera(bm, c, r, assi=None, semi=(1.0, 1.0, 1.0), seg=(14, 9), esp=None):
    """Sfera (o ellissoide con semiassi semi*r negli assi dati, o superellissoide con esponente esp)."""
    ret = bmesh.ops.create_uvsphere(bm, u_segments=seg[0], v_segments=seg[1], radius=1.0)
    M = np.eye(3) if assi is None else np.array(assi).T
    for v in ret['verts']:
        q = np.array(v.co)
        if esp is not None:
            q = np.sign(q) * np.abs(q) ** esp
        q = q * np.array(semi) * r
        v.co = Vector(np.asarray(c) + M @ q)


def _tubo(bm, a, b, ra, rb, fine=False):
    """Catena di sfere da a a b (raggio da ra a rb): dopo il remesh e' un tubo liscio con le punte tonde."""
    a, b = np.asarray(a), np.asarray(b)
    d = b - a
    L = np.linalg.norm(d)
    if fine:                                # la superficie arriva circa alla coda dell'osso
        L2 = max(L - 0.55 * rb, 1e-4)
        b = a + d / L * L2
        L = L2
    n = max(int(math.ceil(L / (0.4 * min(ra, rb)))) + 1, 2)
    for t in np.linspace(0.0, 1.0, n):
        _sfera(bm, a + (b - a) * t, ra + (rb - ra) * t, seg=(12, 8))


def _assi_osso(arm, nome):
    M = arm.data.bones[nome].matrix_local.to_3x3()
    return np.array(M.col[0]), np.array(M.col[1]), np.array(M.col[2])


def _raggi_dita(arm, suf):
    """Raggio di base delle dita (frazione della lunghezza della mano)."""
    return MANI['raggio'] * OSSA_MANO['lunghezza']


def _pezzi_mano(arm, suf, r_polso):
    """Bmesh con tutti i pezzi (sovrapposti) di una mano, nella posa di riposo delle ossa."""
    bm = bmesh.new()
    B = arm.data.bones
    polso = np.array(B['mano' + suf].head_local)
    r0 = _raggi_dita(arm, suf)
    tap = MANI['rastremazione']
    info = {'r0': r0, 'unghie': []}
    mcp = np.array([_catena(arm, d, suf)[1][0] for d in DITA[1:]])
    yh = mcp.mean(0) - polso
    lung = np.linalg.norm(yh)
    yh /= lung
    zm = _assi_osso(arm, 'mano' + suf)[2]
    zh = zm - (zm @ yh) * yh
    zh /= np.linalg.norm(zh)
    xh = np.cross(yh, zh)
    assi_mano = (xh, yh, zh)
    # palmo: scatola arrotondata dal polso alle nocche
    lat = (mcp - polso) @ xh
    larg = (lat.max() - lat.min()) / 2 + 0.95 * r0
    centro_lat = (lat.max() + lat.min()) / 2
    c_palmo = polso + yh * (0.62 * lung) + xh * centro_lat - zh * 0.1 * r0
    _sfera(bm, c_palmo, 1.0, assi_mano, semi=(larg, 0.42 * lung, 1.42 * r0), seg=(28, 18), esp=0.72)
    c_palmo2 = polso + yh * (0.32 * lung) + xh * centro_lat * 0.75 - zh * 0.1 * r0
    _sfera(bm, c_palmo2, 1.0, assi_mano, semi=(0.84 * larg, 0.34 * lung, 1.32 * r0), seg=(24, 16), esp=0.72)
    # polso: continua l'avambraccio con la stessa misura dell'apertura (la parte tonda resta dentro
    # l'avambraccio, oltre il taglio) e si allarga piano nel palmo: da dritto non si vede la giuntura
    _sfera(bm, polso, r_polso * 0.985, seg=(18, 12))
    base = polso + yh * 0.34 * lung + xh * centro_lat * 0.5
    for t in np.linspace(0.0, 1.0, 10):
        sx = r_polso * 0.985 + (0.78 * larg - r_polso * 0.985) * t       # piu' largo...
        sz = r_polso * 0.985 + (1.28 * r0 - r_polso * 0.985) * t         # ...e piu' sottile verso il palmo
        _sfera(bm, polso + (base - polso) * t, 1.0, assi_mano, semi=(sx, 0.7 * min(sx, sz), sz), seg=(16, 10))
    for d in DITA:
        nomi, J = _catena(arm, d, suf)
        r = r0 * MANI['spessore'][d]
        x1, y1, z1 = _assi_osso(arm, nomi[0])
        for i in range(3):
            a = J[0] - (J[1] - J[0]) * 0.3 if (i == 0 and d != 'pollice') else J[i]
            _tubo(bm, a, J[i + 1], r * tap[i], r * tap[i + 1], fine=(i == 2))
        # nocche: appena in rilievo sul dorso alle due pieghe del dito (il palmo del dito resta liscio)
        for i in (1, 2):
            zi = _assi_osso(arm, nomi[i - 1])[2]
            _sfera(bm, J[i] + zi * 0.24 * r * tap[i], 0.92 * r * tap[i], seg=(12, 8))
        x3, y3, z3 = _assi_osso(arm, nomi[2])
        L3 = np.linalg.norm(J[3] - J[2])
        rd = r * 0.5 * (tap[2] + tap[3])
        cu = J[2] + (J[3] - J[2]) * 0.58 + z3 * 0.86 * rd
        _sfera(bm, cu, 1.0, (x3, y3, z3), semi=(0.62 * rd, 0.38 * L3, 0.2 * rd), seg=(14, 8))
        info['unghie'].append((cu, (x3, y3, z3), (0.62 * rd, 0.38 * L3, 0.2 * rd)))
        if d == 'pollice':
            # eminenza del pollice: dal polso alla base del pollice, verso il palmo
            lp = np.linalg.norm(J[1] - J[0])
            ct = J[0] + (J[1] - J[0]) * 0.25 - zh * 0.45 * r + (c_palmo - J[0]) * 0.25
            _sfera(bm, ct, 1.0, (x1, y1, z1), semi=(1.1 * r, 0.8 * lp + 0.4 * r, 0.9 * r), seg=(16, 10))
        else:
            # nocca grande alla base del dito, sul dorso
            _sfera(bm, J[0] + z1 * 0.55 * r - y1 * 0.1 * r, 0.82 * r, seg=(12, 8))
    return bm, info


def _remesh(bm, nome):
    """Unisce i pezzi con un remesh a voxel, liscia e riduce: ritorna una mesh nuova."""
    me = bpy.data.meshes.new(nome + '_pezzi')
    bm.to_mesh(me)
    ob = bpy.data.objects.new(nome + '_pezzi', me)
    collega(ob)
    mr = ob.modifiers.new('remesh', 'REMESH')
    mr.mode = 'VOXEL'
    mr.voxel_size = MANI['voxel']
    mr.use_smooth_shade = True
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bm2 = bmesh.new()
    bm2.from_mesh(me2)
    for _ in range(4):
        bmesh.ops.smooth_vert(bm2, verts=bm2.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm2.to_mesh(me2)
    bm2.free()
    ob = bpy.data.objects.new(nome + '_liscia', me2)
    collega(ob)
    dec = ob.modifiers.new('riduci', 'DECIMATE')
    dec.ratio = min(1.0, MANI['facce'] / max(len(me2.polygons), 1))
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me3 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me2)
    return me3


def _pesi(arm, suf, co, r0):
    """Due ossa al massimo per vertice: dito piu' vicino (distanza dall'asse rispetto al suo raggio) con la piega
    tra le due falangi, oppure il palmo (osso mano) con la base del dito."""
    tap = MANI['rastremazione']
    n = len(co)
    pesi = {}
    migliore = np.full(n, np.inf)
    scelta = [None] * n
    for d in DITA:
        nomi, J = _catena(arm, d, suf)
        r = r0 * MANI['spessore'][d]
        dist = np.full(n, np.inf)
        idx = np.zeros(n, np.int32)
        tpar = np.zeros(n)
        for i in range(3):
            a, b = J[i], J[i + 1]
            ab = b - a
            L2 = ab @ ab
            t = np.clip(((co - a) @ ab) / L2, -0.6 if i == 0 else 0.0, 1.0)
            dd = np.linalg.norm(co - (a + t[:, None] * ab), axis=1) / (r * tap[i])
            m = dd < dist
            dist[m], idx[m], tpar[m] = dd[m], i, t[m]
        m = (dist < 1.9) & (dist < migliore)
        migliore[m] = dist[m]
        for j in np.where(m)[0]:
            scelta[j] = (d, nomi, J, idx[j], tpar[j], r)
    W = {}
    for j in range(n):
        s = scelta[j]
        if s is None:
            W[j] = {'mano' + suf: 1.0}
            continue
        d, nomi, J, i, t, r = s
        L = np.linalg.norm(J[i + 1] - J[i])
        h = 0.45 * r / L                        # meta' della zona di piega, in frazione dell'osso
        if i == 0 and t < h:                    # base del dito: palmo e prima falange
            hb = 0.6 * r / L
            w = np.clip((t + hb) / (2 * hb), 0, 1)
            w = w * w * (3 - 2 * w)
            W[j] = {'mano' + suf: 1 - w, nomi[0]: w}
        elif t > 1 - h and i < 2:               # piega verso la falange dopo
            w = np.clip((t - (1 - h)) / (2 * h), 0, 1) * 0.5 + 0.0
            w = w * w * (3 - 2 * w)
            W[j] = {nomi[i]: 1 - w, nomi[i + 1]: w}
        elif t < h and i > 0:                   # piega dalla falange prima
            w = 0.5 + np.clip(t / h, 0, 1) * 0.5
            w = w * w * (3 - 2 * w)
            W[j] = {nomi[i - 1]: 1 - w, nomi[i]: w}
        else:
            W[j] = {nomi[i]: 1.0}
    return W


def colore_pelle(arm, corpo):
    """Tinta della pelle (sRGB, 0-1) dalla texture del corpo vicino ai polsi."""
    from PIL import Image
    me = corpo.data
    co = coords(me)
    uv = loop_uv(me)
    lv = loop_vert(me)
    img = np.asarray(Image.open(TEX_COLORE).convert('RGB')).astype(np.float32) / 255.0
    H, Wd = img.shape[:2]
    campioni = []
    for s in ('.L', '.R'):
        p = np.array(arm.data.bones['mano' + s].head_local)
        vicini = np.where(np.linalg.norm(co - p, axis=1) < 0.06)[0]
        sel = np.isin(lv, vicini)
        for u, v in uv[sel]:
            x, y = int(np.clip(u * Wd, 0, Wd - 1)), int(np.clip((1 - v) * H, 0, H - 1))
            campioni.append(img[y, x])
    c = np.median(np.array(campioni), 0) if campioni else np.array([0.78, 0.78, 0.9])
    return c


def materiale_mani(colore_srgb):
    m = bpy.data.materials.get('M_mani') or bpy.data.materials.new('M_mani')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nodo(nt, 'ShaderNodeOutputMaterial', (600, 0))
    b = nodo(nt, 'ShaderNodeBsdfPrincipled', (300, 0))
    b.name = 'BSDF'
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in colore_srgb]
    va = nodo(nt, 'ShaderNodeVertexColor', (-300, 100))
    va.layer_name = 'Col'
    mix = nodo(nt, 'ShaderNodeMix', (0, 100))
    mix.data_type = 'RGBA'
    mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0
    mix.inputs['B'].default_value = (*lin, 1.0)
    nt.links.new(va.outputs['Color'], mix.inputs['A'])
    nt.links.new(mix.outputs['Result'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.13
    b.inputs['Coat Weight'].default_value = 1.0
    b.inputs['Coat Roughness'].default_value = 0.04
    b.inputs['Specular IOR Level'].default_value = 0.5
    b.inputs['Subsurface Weight'].default_value = 0.04
    b.inputs['Subsurface Radius'].default_value = (0.9, 0.6, 0.5)
    b.inputs['Subsurface Scale'].default_value = 0.02
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    m['colore_srgb'] = list(map(float, colore_srgb))
    return m


def crea_mani(arm, corpo, raggi_polso=None):
    """Oggetto Medusa_Mani (tutte e due le mani) con pesi, colori dei vertici e materiale M_mani."""
    from medusa_08_dettagli import occlusione
    raggi_polso = raggi_polso or {s: _raggio_avambraccio(arm, corpo, s) for s in ('.L', '.R')}
    mesh_lati = []
    for suf in ('.L', '.R'):
        bm, info = _pezzi_mano(arm, suf, raggi_polso[suf])
        me = _remesh(bm, 'mano' + suf)
        bm.free()
        mesh_lati.append((suf, me, info))
    # una sola mesh
    bm = bmesh.new()
    lati = []
    for suf, me, info in mesh_lati:
        n0 = len(bm.verts)
        bm.from_mesh(me)
        lati.append((suf, n0, len(bm.verts), info))
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new('Medusa_Mani')
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new('Medusa_Mani', me)
    collega(ob)
    ob.parent = arm
    co = coords(me)
    # pesi
    gruppi = {}
    for suf, a, b, info in lati:
        W = _pesi(arm, suf, co[a:b], info['r0'])
        for j, wd in W.items():
            for nome, w in wd.items():
                if w <= 1e-4:
                    continue
                g = gruppi.get(nome) or ob.vertex_groups.new(name=nome)
                gruppi[nome] = g
                g.add([a + j], float(w), 'REPLACE')
    mod = ob.modifiers.new('Scheletro', 'ARMATURE')
    mod.object = arm
    # colori dei vertici: unghie un po' piu' chiare, pieghe un po' piu' scure
    ao = occlusione(ob, raggi=16, dist=0.03)
    col = np.ones((len(co), 4), np.float32)
    base = 0.88
    col[:, :3] = base
    for suf, a, b, info in lati:
        for cu, (x3, y3, z3), semi in info['unghie']:
            q = co[a:b] - cu
            e = np.sqrt(((q @ x3) / (semi[0] * 1.15)) ** 2 + ((q @ y3) / (semi[1] * 1.15)) ** 2 +
                        ((q @ z3) / (semi[2] * 3.0)) ** 2)
            dentro = np.clip((1.25 - e) / 0.35, 0, 1)
            col[a:b, 0] += dentro * (1.0 - base)
            col[a:b, 1] += dentro * (0.9 - base)
            col[a:b, 2] += dentro * (0.96 - base)
    col[:, :3] *= (0.72 + 0.28 * ao)[:, None]
    attr = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    attr.data.foreach_set('color', col.ravel())
    me.color_attributes.active_color = attr
    m = materiale_mani(colore_pelle(arm, corpo))
    me.materials.append(m)
    log(f'mani nuove: {len(me.polygons)} facce, {len(ob.vertex_groups)} ossa, raggio dita '
        f'{lati[0][3]["r0"]:.4f}, tinta pelle {tuple(round(float(c), 3) for c in m["colore_srgb"])}')
    return ob
