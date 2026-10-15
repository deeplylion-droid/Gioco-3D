"""Passo 3: occhio di vetro 3D al posto dell'occhio dipinto.

1. Texture dell'iride ricavata dall'occhio dipinto (vista frontale piatta del passo 1), in coordinate polari:
   - il settore coperto dalla frangia (anello e raggi) si ricostruisce clonando un altro settore, con lo
     sfasamento che distribuisce meglio i raggi;
   - il riflesso bianco dipinto si toglie (i riflessi veri li fa la cornea);
   - i raggi del bordo si separano dalla pelle con un'alfa (colore "smescolato"), cosi' la sclera e' libera.
   Scrive tex/occhio_iride_rgba.png (solo il disegno dell'occhio) e tex/occhio_bulbo_basecolor.png
   (disegno sopra il colore della sclera, quella usata dal materiale).
2. Orbita: si tolgono le facce dell'occhio dipinto; il bordo del buco si piega verso l'interno fin sotto
   la superficie del bulbo (un labbro sottile: niente fessure quando l'occhio gira).
3. Bulbo: calotta sferica concentrica alla sfera del viso (a filo con la pelle, come l'occhio dipinto),
   UV per proiezione frontale: da fermo l'occhio e' identico a quello approvato.
4. Cornea: calotta trasparente un po' bombata sopra l'iride.
Bulbo e cornea ruotano attorno al centro della sfera: l'osso "occhio" (passo 4) sta li'.

Scrive dati/occhio_3d.json e build/medusa_03_occhio.blend, anteprime in build/anteprime/occhio_*.png.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_03_occhio.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import cv2  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

S_TEX = 0.11              # la texture dell'occhio copre +-11 cm attorno al centro dell'occhio
N_TEX = 2048              # la statua e' alta 4,5 m: l'occhio (mezzo metro) si vede da vicino
SCLERA = (0.80, 0.82, 0.95)  # bianco porcellana-lavanda, vicino alla pelle: da fermo l'occhio resta come approvato
RIENTRO_BULBO = 0.0025    # il bulbo sta 2,5 mm sotto la pelle (piccolo gradino dell'orbita)
ALTEZZA_CORNEA = 0.003    # la cornea sporge 3 mm sopra l'iride
ROT_MAX = 15.0            # rotazione massima prevista dell'occhio (gradi): serve per la calotta
SPINTA_MAX = 0.0035       # la pelle vicino all'orbita si puo' spostare in fuori al massimo di 3,5 mm
LABBRO = 0.0015           # la pelle resta almeno 1,5 mm sopra il bulbo
OCCHIO_IDX = 4            # indice del materiale occhio_dipinto (passo 1)

IRIDE_RGBA = os.path.join(TEX, 'occhio_iride_rgba.png')
BULBO_BASE = os.path.join(TEX, 'occhio_bulbo_basecolor.png')


# ---------------------------------------------------------------- 1. texture dell'iride

def _hsv(p):
    h = cv2.cvtColor((np.clip(p, 0, 1) * 255).astype(np.uint8), cv2.COLOR_BGR2HSV).astype(np.float32)
    return h[..., 0] * 2, h[..., 1] / 255, h[..., 2] / 255


def texture_iride(occ, sclera=SCLERA):
    P = occ['pixel']
    src = cv2.imread(os.path.join(ASSET, P['immagine'])).astype(np.float32) / 255.
    k = P['scala_m_per_px']; cx, cy = P['cx'], P['cy']
    NT, NR = 1440, 512
    rho = (np.arange(NR) + 0.5) / NR * S_TEX
    th = np.arange(NT) / NT * 2 * np.pi
    RR, TT = np.meshgrid(rho, th, indexing='ij')
    pol = cv2.remap(src, (cx + RR * np.cos(TT) / k).astype(np.float32), (cy - RR * np.sin(TT) / k).astype(np.float32),
                    cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
    pol = np.clip(pol, 0, 1)
    row = lambda r: int(round(r / S_TEX * NR))  # noqa: E731
    ri, ro, rs = occ['raggio_anello_interno'], occ['raggio_anello_esterno'], occ['raggio_punte']
    H, Sa, V = _hsv(pol)
    B, R = pol[..., 0], pol[..., 2]
    magenta = ((H > 285) | (H < 15)) & (Sa > 0.35)

    # settore coperto dalla frangia
    band = slice(row(ri + 0.002), row(ro - 0.002))
    occ_ring = (magenta[band] & (V[band] < 0.75)).mean(0) < 0.85
    sb = slice(row(ro + 0.001), row(rs + 0.004))
    occ_spk = ((Sa < 0.22) & ((B - R) < 0.10))[sb].mean(0) > 0.25
    o = occ_ring | occ_spk
    d = np.diff(np.r_[0, o.astype(int), 0]); st = np.nonzero(d == 1)[0]; en = np.nonzero(d == -1)[0]
    settore = np.zeros(NT, bool)
    for a, b in zip(st, en):
        if b - a >= 40:
            settore[a:b] = True
    settore = cv2.dilate(settore.astype(np.uint8)[None], np.ones((1, 25), np.uint8))[0] > 0
    # raggi visibili e sfasamento migliore per clonare quelli nascosti
    srow = row(ro + 0.0035)
    sr = magenta[srow] & (V[srow] < 0.8)
    d = np.diff(np.r_[0, sr.astype(int), 0])
    spk = np.array([(a + b - 1) / 2 for a, b in zip(np.nonzero(d == 1)[0], np.nonzero(d == -1)[0])])
    vis = spk[~settore[spk.astype(int)]]
    cols = np.nonzero(settore)[0]
    migliore = None
    for off in range(100, NT - 100, 2):
        if settore[(cols + off) % NT].any():
            continue
        cl = [(s - off) % NT for s in vis if settore[int((s - off) % NT)]]
        tutti = np.sort(np.r_[vis, cl])
        gaps = np.diff(np.r_[tutti, tutti[0] + NT])
        punteggio = gaps.std() + 30 * (gaps.min() < 60)
        if migliore is None or punteggio < migliore[0]:
            migliore = (punteggio, off, len(tutti))
    off = migliore[1] if cols.size else 0
    log(f'iride: settore coperto {cols.min() * 360 / NT:.0f}-{cols.max() * 360 / NT:.0f} gradi, '
        f'clonato con sfasamento {off * 360 / NT:.0f} gradi, raggi totali {migliore[2]}')
    wcol = np.clip(cv2.GaussianBlur(settore.astype(np.float32)[None], (0, 0), 6)[0] * 1.6, 0, 1)
    wrow = np.clip((np.arange(NR) - (row(ri) - 8)) / 6.0, 0, 1)
    W = (wrow[:, None] * wcol[None, :])[..., None]
    pol = pol * (1 - W) + np.roll(pol, -off, axis=1) * W

    # riflesso bianco dipinto
    H, Sa, V = _hsv(pol)
    hl = (V > 0.8) & (Sa < 0.2); hl[row(ri):] = False
    n, lab, stt, _ = cv2.connectedComponentsWithStats(hl.astype(np.uint8))
    if n > 1:
        big = np.argmax(stt[1:, cv2.CC_STAT_AREA]) + 1
        pts = np.argwhere(lab == big)[:, ::-1].astype(np.int32)
        m = np.zeros(hl.shape, np.uint8); cv2.fillConvexPoly(m, cv2.convexHull(pts), 1)
        m = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31)))
        Wh = np.clip(cv2.GaussianBlur(m.astype(np.float32), (0, 0), 5) * 1.5, 0, 1)[..., None]
        pol = pol * (1 - Wh) + np.roll(pol, -260, axis=1) * Wh

    # alfa: disco pieno fino all'anello, poi raggi separati dalla pelle
    r_a, r_b = row(ro) - 3, row(rs) + 6
    pelle = np.median(pol[row(rs) + 3:row(rs) + 12], axis=0)             # colore pelle per colonna
    anello = np.median(pol[row(ro) - 7:row(ro) - 2], axis=0)             # colore anello per colonna
    dv = anello - pelle
    alpha = np.ones((NR, NT), np.float32)
    seg = pol[r_a:r_b] - pelle[None]
    a = np.clip((seg * dv[None]).sum(-1) / np.maximum((dv * dv).sum(-1), 1e-4)[None], 0, 1)
    alpha[r_a:r_b] = a
    alpha[r_b:] = 0
    rgb = pol.copy()
    smesc = (pol[r_a:r_b] - (1 - a[..., None]) * pelle[None]) / np.maximum(a[..., None], 0.05)
    smesc = np.clip(smesc, 0, 1)
    w = np.clip((a - 0.15) / 0.35, 0, 1)[..., None]
    rgb[r_a:r_b] = smesc * w + anello[None] * (1 - w)
    rgb[r_b:] = anello[None]

    # polari a risoluzione doppia, poi fibre dell'iride (striature radiali sottili) tra pupilla e anello:
    # la texture di Meshy e' morbida e la statua alta 4,5 m mostra l'occhio da vicino
    H, Sa, V = _hsv(rgb)
    prof = np.median(V, axis=1)
    lim = row(ri)
    meta = 0.5 * (prof[:lim].min() + prof[:lim].max())
    sopra = np.nonzero(prof[:lim] > meta)[0]
    r_pup = 2 * ((sopra[0] if sopra.size else lim // 3) + 1)
    NT, NR = 2 * NT, 2 * NR
    rgb = cv2.resize(rgb.astype(np.float32), (NT, NR), interpolation=cv2.INTER_CUBIC)
    alpha = cv2.resize(alpha.astype(np.float32), (NT, NR), interpolation=cv2.INTER_LINEAR)
    lim = 2 * lim
    rng = np.random.default_rng(4)
    fib = cv2.GaussianBlur(rng.normal(size=(NR, NT)).astype(np.float32), (0, 0), sigmaX=2.2, sigmaY=30)
    fib2 = cv2.GaussianBlur(rng.normal(size=(NR, NT)).astype(np.float32), (0, 0), sigmaX=6, sigmaY=8)
    fib = fib / (fib.std() + 1e-6) + 0.3 * fib2 / (fib2.std() + 1e-6)
    rr_i = np.arange(NR)[:, None]
    m_ir = np.clip((rr_i - r_pup) / 10.0, 0, 1) * np.clip((lim - 4 - rr_i) / 10.0, 0, 1)
    rgb = np.clip(rgb * (1 + 0.055 * fib * m_ir)[..., None], 0, 1)
    bordo_p = np.exp(-0.5 * ((rr_i - r_pup) / 3.0) ** 2) * 0.18          # bordo della pupilla piu' netto
    rgb = np.clip(rgb * (1 - bordo_p)[..., None], 0, 1)
    log(f'iride: pupilla a {r_pup / NR * S_TEX * 1000:.1f} mm, fibre aggiunte, polari {NT}x{NR}')

    # da polari a cartesiane (u verso +X, v verso +Z, vista da davanti)
    pad = 8
    polp = np.concatenate([rgb[:, -pad:], rgb, rgb[:, :pad]], 1)
    alp = np.concatenate([alpha[:, -pad:], alpha, alpha[:, :pad]], 1)
    jj, ii = np.meshgrid(np.arange(N_TEX), np.arange(N_TEX))
    x = (jj + 0.5 - N_TEX / 2) / N_TEX * 2 * S_TEX
    z = (N_TEX / 2 - ii - 0.5) / N_TEX * 2 * S_TEX
    rr = np.hypot(x, z); tt = np.mod(np.arctan2(z, x), 2 * np.pi)
    mx = (tt / (2 * np.pi) * NT + pad).astype(np.float32)
    my = (rr / S_TEX * NR - 0.5).astype(np.float32)
    car = cv2.remap(polp.astype(np.float32), mx, my, cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    ca = cv2.remap(alp.astype(np.float32), mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    ca[rr > S_TEX] = 0
    car = np.clip(car, 0, 1)
    # nitidezza leggera (la texture di Meshy e' a bassa risoluzione sull'occhio)
    blur = cv2.GaussianBlur(car, (0, 0), 2.5)
    car = np.clip(car + 0.35 * (car - blur), 0, 1)
    rgba = np.dstack([car, np.clip(ca, 0, 1)])
    cv2.imwrite(IRIDE_RGBA, (rgba * 255).astype(np.uint8))
    componi_bulbo(sclera)
    log('scritte', os.path.relpath(IRIDE_RGBA, REPO), os.path.relpath(BULBO_BASE, REPO))


def componi_bulbo(sclera=SCLERA, path=BULBO_BASE, vene=None):
    """Disegno dell'occhio sopra il colore della sclera (BGR su disco)."""
    rgba = cv2.imread(IRIDE_RGBA, cv2.IMREAD_UNCHANGED).astype(np.float32) / 255.
    fondo = np.ones_like(rgba[..., :3]) * np.array(sclera[::-1], np.float32)
    if vene is not None:
        fondo = vene
    a = rgba[..., 3:4]
    out = rgba[..., :3] * a + fondo * (1 - a)
    cv2.imwrite(path, (np.clip(out, 0, 1) * 255).astype(np.uint8))
    return path


# ---------------------------------------------------------------- 2-4. geometria

def sfera_adattata(P):
    A = np.c_[2 * P, np.ones(len(P))]
    s = np.linalg.lstsq(A, (P ** 2).sum(1), rcond=None)[0]
    c = s[:3]
    return c, float(np.sqrt(s[3] + c @ c))


def sfera_viso(me, occ):
    cen, nor = facce(me)
    mi = np.empty(len(me.polygons), dtype=np.int32); me.polygons.foreach_get('material_index', mi)
    d = np.hypot(cen[:, 0] - occ['centro_x'], cen[:, 2] - occ['centro_z'])
    # anello di pelle attorno all'orbita: e' li' che il bulbo deve stare a filo
    m = (d > occ['raggio_anello_esterno'] - 0.005) & (d < 0.125) & ((mi == 0) | (mi == OCCHIO_IDX)) \
        & (cen[:, 1] < -0.1) & (nor[:, 1] < -0.3)
    c, r = sfera_adattata(cen[m])
    res = np.linalg.norm(cen[m] - c, axis=1) - r
    log(f'sfera del viso: centro {np.round(c, 4)}, raggio {r:.4f}, scarto {res.std() * 1000:.1f} mm')
    return Vector(c), r


def apri_orbita(ob, C, Rb, asse, ang_orbita):
    """Toglie le facce dell'occhio dipinto, porta il bordo del buco su un cerchio esatto (attorno al centro
    del bulbo) e lo piega verso l'interno fin sotto la superficie del bulbo."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bvh0 = BVHTree.FromBMesh(bm)          # superficie prima del buco, per riproiettare i vertici
    bm.faces.ensure_lookup_table()
    via = [f for f in bm.faces if f.material_index == OCCHIO_IDX]
    bmesh.ops.delete(bm, geom=via, context='FACES')
    f_, r_, u_ = base_asse(asse)

    def angoli(co):
        d = (co - C).normalized()
        return math.acos(max(-1.0, min(1.0, d.dot(f_)))), math.atan2(d.dot(u_), d.dot(r_))

    def sulla_pelle(a, p):
        d = math.cos(a) * f_ + math.sin(a) * (math.cos(p) * r_ + math.sin(p) * u_)
        return bvh0.ray_cast(C, d, 1.0)[0]

    bordo = [e for e in bm.edges if e.is_boundary and (e.verts[0].co - C).length < Rb * 1.4]
    vb = {v for e in bordo for v in e.verts}
    agganciati = set()
    for v in vb:
        if any(f.material_index == 1 for f in v.link_faces):      # bordo lungo la frangia: resta com'e'
            continue
        a, p = angoli(v.co)
        if abs(a - ang_orbita) > math.radians(9):
            continue
        q = sulla_pelle(ang_orbita, p)
        if q is not None:
            v.co = q
            agganciati.add(v)
    # rilassa due anelli di vertici attorno al bordo, restando sulla superficie originale
    anello1 = {e.other_vert(v) for v in agganciati for e in v.link_edges} - vb
    anello2 = {e.other_vert(v) for v in anello1 for e in v.link_edges} - vb - anello1
    for _ in range(4):
        for v in list(anello1) + list(anello2):
            media = sum((e.other_vert(v).co for e in v.link_edges), Vector()) / len(v.link_edges)
            v.co = bvh0.find_nearest(media)[0]
        for v in anello1:
            a, p = angoli(v.co)
            if a < ang_orbita + math.radians(1.2):
                q = sulla_pelle(ang_orbita + math.radians(1.2), p)
                if q is not None:
                    v.co = q
    log(f'orbita: {len(agganciati)} di {len(vb)} vertici del bordo agganciati al cerchio')
    ret = bmesh.ops.extrude_edge_only(bm, edges=bordo)
    nuovi = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMVert)]
    for v in nuovi:
        dv = v.co - C
        v.co = C + dv.normalized() * (Rb - 0.004)
    nuove_f = {f for v in nuovi for f in v.link_faces}
    if len(ob.data.materials) <= 5 or ob.data.materials[5].name != 'M_orbita':
        base = ob.data.materials[0].copy(); base.name = 'M_orbita'
        ob.data.materials.append(base)
    idx_orbita = [m.name for m in ob.data.materials].index('M_orbita')
    for f in nuove_f:
        f.material_index = idx_orbita
        f.smooth = True
    bmesh.ops.triangulate(bm, faces=list(nuove_f))
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    me.update()
    log(f'orbita: tolte {len(via)} facce dipinte, labbro di {len(bordo)} lati')
    # il labbro e' un po' piu' scuro della pelle (ombra dell'orbita)
    mat = ob.data.materials['M_orbita']
    nt = mat.node_tree
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0
    mix.inputs['B'].default_value = (0.55, 0.45, 0.6, 1)
    bsdf = nt.nodes['BSDF']
    nt.links.new(nt.nodes['base'].outputs['Color'], mix.inputs['A'])
    nt.links.new(mix.outputs['Result'], bsdf.inputs['Base Color'])


def calotta(nome, C, R, asse, ang_max, n_seg=96, n_anelli=40, uv_fun=None):
    """Calotta sferica (centro C, raggio R) attorno all'asse, fino all'angolo ang_max (radianti)."""
    f, r, u = base_asse(asse)
    verts = [C + f * R]
    for i in range(1, n_anelli + 1):
        t = ang_max * i / n_anelli
        for j in range(n_seg):
            p = 2 * math.pi * j / n_seg
            verts.append(C + R * (math.cos(t) * f + math.sin(t) * (math.cos(p) * r + math.sin(p) * u)))
    facce_ = []
    for j in range(n_seg):
        facce_.append((0, 1 + (j + 1) % n_seg, 1 + j))
    for i in range(n_anelli - 1):
        a0 = 1 + i * n_seg; a1 = 1 + (i + 1) * n_seg
        for j in range(n_seg):
            jn = (j + 1) % n_seg
            facce_.append((a0 + j, a0 + jn, a1 + jn, a1 + j))
    me = bpy.data.meshes.new(nome)
    me.from_pydata([tuple(v) for v in verts], [], facce_)
    me.shade_smooth()
    if uv_fun:
        uvl = me.uv_layers.new(name='UVMap')
        lv = loop_vert(me)
        co = coords(me)
        uvl.data.foreach_set('uv', uv_fun(co[lv]).ravel())
    # normali verso l'esterno
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bm.faces[0].normal.dot(bm.faces[0].calc_center_median() - C) < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome, me)
    collega(ob)
    return ob


def base_asse(asse):
    f = Vector(asse).normalized()
    r = Vector((1, 0, 0)) - f * f.x
    r.normalize()
    u = f.cross(r).normalized()
    if u.z < 0:
        u = -u
    return f, r, u


def prepara_pelle(ob, C, Rb, asse, ang_orbita):
    """Sceglie l'angolo della calotta e sposta in fuori (poco e in modo morbido) la pelle che il bulbo,
    ruotando, toccherebbe. Ritorna (angolo calotta, rotazione massima utilizzabile) in radianti."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    f, r, u = base_asse(asse)
    n_az, angoli = 72, np.radians(np.arange(0, 101, 1.0))
    soglia = Rb + LABBRO
    deficit = np.full((n_az, len(angoli)), np.inf)
    for i in range(n_az):
        p = 2 * math.pi * i / n_az
        for j, t in enumerate(angoli):
            d = (math.cos(t) * f + math.sin(t) * (math.cos(p) * r + math.sin(p) * u)).normalized()
            hit = bvh.ray_cast(C, d, 1.0)
            if hit[0] is not None:
                deficit[i, j] = soglia - hit[3]
    j0 = int(np.searchsorted(angoli, ang_orbita + math.radians(3)))
    sicuro = []
    for i in range(n_az):
        bad = np.nonzero(deficit[i, j0:] > SPINTA_MAX)[0]
        sicuro.append(angoli[j0 + bad[0] - 1] if len(bad) else angoli[-1])
    ang_sicuro = float(min(sicuro))
    rot = math.radians(ROT_MAX)
    cal = ang_sicuro - rot
    if cal < ang_orbita + rot + math.radians(2):
        rot = (ang_sicuro - ang_orbita - math.radians(2)) / 2
        cal = ang_orbita + rot + math.radians(2)
        log(f'ATTENZIONE: la testa permette solo {math.degrees(rot):.1f} gradi di rotazione dell\'occhio')
    # spinta della pelle entro l'angolo coperto dal bulbo che ruota
    co = coords(me)
    dv = co - np.array(C)
    dist = np.linalg.norm(dv, axis=1)
    cosang = (dv @ np.array(f)) / np.maximum(dist, 1e-9)
    zona = cosang > math.cos(cal + rot + math.radians(4))
    spinta = np.where(zona, np.clip(soglia - dist, 0, SPINTA_MAX), 0.0)
    # ammorbidisce la spinta sui vicini (niente gradini nei riflessi del vinile)
    ev = adiacenza_vertici(me)
    for _ in range(6):
        somma = np.zeros(len(co)); cnt = np.zeros(len(co))
        np.add.at(somma, ev[:, 0], spinta[ev[:, 1]]); np.add.at(cnt, ev[:, 0], 1)
        np.add.at(somma, ev[:, 1], spinta[ev[:, 0]]); np.add.at(cnt, ev[:, 1], 1)
        spinta = np.maximum(spinta, 0.85 * somma / np.maximum(cnt, 1)) * zona
    n_sp = int((spinta > 1e-5).sum())
    co = co + dv / np.maximum(dist, 1e-9)[:, None] * spinta[:, None]
    set_coords(me, co)
    log(f'calotta {math.degrees(cal):.0f} gradi, rotazione max {math.degrees(rot):.0f} gradi, '
        f'pelle spostata: {n_sp} vertici, al massimo {spinta.max() * 1000:.1f} mm')
    return cal, rot


def materiali_occhio(bulbo, cornea):
    mb = materiale_pbr('M_occhio_bulbo', base=BULBO_BASE, roughness=0.35)
    bulbo.data.materials.append(mb)
    mc = bpy.data.materials.new('M_occhio_cornea')
    mc.use_nodes = True
    b = mc.node_tree.nodes['Principled BSDF']
    b.name = 'BSDF'
    b.inputs['Base Color'].default_value = (1, 1, 1, 1)
    b.inputs['Roughness'].default_value = 0.02
    b.inputs['Transmission Weight'].default_value = 1.0
    b.inputs['IOR'].default_value = 1.45
    cornea.data.materials.append(mc)
    try:
        mc.surface_render_method = 'BLENDED'
    except Exception:
        pass


def main():
    t0 = time.time()
    occ = leggi_json('occhio.json')
    texture_iride(occ)
    ridotta = os.path.join(BUILD, 'medusa_02b_ridotta.blend')       # versione da gioco (passo 2b), se c'e'
    apri(ridotta if os.path.exists(ridotta) else os.path.join(BUILD, 'medusa_02_texture.blend'))
    ob = bpy.data.objects['Medusa']
    me = ob.data
    C, Rf = sfera_viso(me, occ)
    Rb = Rf - RIENTRO_BULBO
    ex, ez = occ['centro_x'], occ['centro_z']
    # centro dell'iride sul bulbo (proiezione frontale)
    dy = math.sqrt(max(Rb ** 2 - (ex - C.x) ** 2 - (ez - C.z) ** 2, 1e-6))
    P_iride = Vector((ex, C.y - dy, ez))
    asse = (P_iride - C).normalized()
    ang_orbita = math.asin(min(occ['raggio_orbita'] / Rb, 0.99))
    ang_cal, rot = prepara_pelle(ob, C, Rb, asse, ang_orbita)
    apri_orbita(ob, C, Rb, asse, ang_orbita)

    def uv_frontale(co):
        return np.stack([0.5 + (co[:, 0] - ex) / (2 * S_TEX), 0.5 + (co[:, 2] - ez) / (2 * S_TEX)], 1)

    bulbo = calotta('Medusa_Occhio', C, Rb, asse, ang_cal, n_seg=64, n_anelli=28, uv_fun=uv_frontale)
    # cornea: calotta bombata che tocca il bulbo sul bordo esterno dell'anello
    phi = math.asin(min(occ['raggio_anello_esterno'] / Rb, 0.99)) + math.radians(1.5)
    a = Rb * math.sin(phi); t = Rb * math.cos(phi)
    D = Rb + ALTEZZA_CORNEA - t
    Rc = (a * a + D * D) / (2 * D)
    dc = Rb + ALTEZZA_CORNEA - Rc
    Cc = C + asse * dc
    ang_c = math.asin(min(a / Rc, 0.999))
    cornea = calotta('Medusa_Cornea', Cc, Rc, asse, ang_c, n_seg=64, n_anelli=16)
    materiali_occhio(bulbo, cornea)
    dati = {
        'centro_rotazione': [round(v, 5) for v in C], 'raggio_bulbo': round(Rb, 5), 'raggio_viso': round(Rf, 5),
        'asse_riposo': [round(v, 5) for v in asse], 'angolo_orbita_gradi': round(math.degrees(ang_orbita), 2),
        'angolo_calotta_gradi': round(math.degrees(ang_cal), 2), 'rotazione_max_gradi': round(math.degrees(rot), 1),
        'cornea': {'centro': [round(v, 5) for v in Cc], 'raggio': round(Rc, 5), 'altezza_mm': ALTEZZA_CORNEA * 1000,
                   'angolo_gradi': round(math.degrees(ang_c), 2)},
        'texture': {'mezzo_lato_m': S_TEX, 'centro_x': ex, 'centro_z': ez, 'sclera': SCLERA},
    }
    scrivi_json('occhio_3d.json', dati)
    log(f'bulbo: raggio {Rb:.4f}, calotta {math.degrees(ang_cal):.0f} gradi, orbita {math.degrees(ang_orbita):.0f} gradi')
    salva(os.path.join(BUILD, 'medusa_03_occhio.blend'))
    if os.environ.get('MEDUSA_ANTEPRIME', '1') != '0':
        anteprima(C, asse, rot)
    log(f'fatto in {time.time() - t0:.0f} s')


def anteprima(C, asse, rot):
    """Primo piano del viso: occhio fermo, poi girato a sinistra, a destra e in alto (controllo)."""
    ant = os.path.join(BUILD, 'anteprime'); os.makedirs(ant, exist_ok=True)
    imposta_render(samples=32, res=(640, 640))
    mondo((0.05, 0.05, 0.06), 1)
    luci_studio((0, 0, 0.62), 0.9)
    cam = camera((0.0, -1.25, 0.66), (0, 0, 0.62), lens=85)
    occhio = [bpy.data.objects['Medusa_Occhio'], bpy.data.objects['Medusa_Cornea']]
    perno = bpy.data.objects.new('perno_occhio', None); collega(perno)
    perno.location = C
    bpy.context.view_layer.update()
    for o in occhio:
        o.parent = perno
        o.matrix_parent_inverse = perno.matrix_world.inverted()
    pose = [('fermo', 0, 0), ('sinistra', 0, rot), ('destra', 0, -rot), ('alto', -rot * 0.8, 0)]
    celle = []
    for nome, rx, rz in pose:
        perno.rotation_euler = (rx, 0, rz)
        bpy.context.view_layer.update()
        p = render(os.path.join(ant, f'occhio_{nome}.png'))
        celle.append((p, nome))
    tavola(celle, os.path.join(ant, 'occhio_controllo.jpg'), colonne=4)


if __name__ == '__main__':
    main()
