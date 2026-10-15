"""Struttura interna della campana, come nelle meduse vere (Halitrephes maasi): si vede attraverso la gelatina
trasparente e da' profondita' alla campana.

  - canali radiali luminosi dentro la gelatina, sotto le creste della campana (dove ci sono i canali
    disegnati sulla superficie), dalla cima fino al bordo;
  - canali secondari, piu' sottili, tra un canale e l'altro (partono a meta' altezza);
  - canale ad anello lungo il bordo;
  - quattro gonadi increspate (anelli a ferro di cavallo) intorno al centro, sopra la sottombrella.

Un solo oggetto (Medusa_Interno) con il materiale M_campana_interno (emissivo, gradiente giallo -> rosa come i
canali della superficie: v della UV = 0 in cima, 1 al bordo), pesi sull'osso 'campana' e la stessa shape key
'campana_contrai' del corpo (si stringe con la campana).
Uso come modulo (passo 7): crea_interno(arm, corpo) dopo maschera_canali.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

Z_VITA = -0.155
Z_CIMA = -0.24          # i canali partono qui (sotto la vita)
Z_BORDO = -0.645        # canale ad anello
RIENTRO = 0.028         # i canali stanno 2,8 cm dentro la superficie
GRADIENTE = [(0.0, (1.0, 0.78, 0.18)), (0.45, (1.0, 0.42, 0.24)), (1.0, (1.0, 0.16, 0.56))]


def profilo_campana(corpo):
    """Raggio esterno della campana su una griglia quota x angolo (massimo per cella)."""
    me = corpo.data
    co = coords(me)
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    idx_c = [m.name for m in me.materials].index('M_campana')
    me.calc_loop_triangles()
    lt = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
    me.loop_triangles.foreach_get('vertices', lt)
    tp = np.empty(len(me.loop_triangles), dtype=np.int64)
    me.loop_triangles.foreach_get('polygon_index', tp)
    v = np.unique(lt.reshape(-1, 3)[mi[tp] == idx_c].ravel())
    x, y, z = co[v].T
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    zb = np.arange(-0.72, -0.13, 0.01)
    tb = np.radians(np.arange(-180, 180, 5.0))
    iz = np.clip(np.round((z - zb[0]) / 0.01).astype(int), 0, len(zb) - 1)
    it = np.round((th + math.pi) / math.radians(5.0)).astype(int) % len(tb)
    R = np.full((len(zb), len(tb)), np.nan)
    for a, b, rr in zip(iz, it, r):
        if np.isnan(R[a, b]) or rr > R[a, b]:
            R[a, b] = rr
    # buchi: media della riga (stessa quota)
    for a in range(len(zb)):
        riga = R[a]
        if np.all(np.isnan(riga)):
            continue
        ok = ~np.isnan(riga)
        R[a] = np.interp(np.arange(len(tb)), np.nonzero(ok)[0], riga[ok], period=len(tb))
    for b in range(len(tb)):
        col = R[:, b]
        ok = ~np.isnan(col)
        R[:, b] = np.interp(np.arange(len(zb)), np.nonzero(ok)[0], col[ok])
    return zb, tb, R


def raggio_esterno(prof, z, th):
    zb, tb, R = prof
    fz = np.clip((z - zb[0]) / 0.01, 0, len(zb) - 1.001)
    ft = ((th + math.pi) / math.radians(5.0)) % len(tb)
    z0, t0 = int(fz), int(ft)
    dz, dt = fz - z0, ft - t0
    t1 = (t0 + 1) % len(tb)
    return ((R[z0, t0] * (1 - dt) + R[z0, t1] * dt) * (1 - dz) + (R[z0 + 1, t0] * (1 - dt) + R[z0 + 1, t1] * dt) * dz)


def angoli_canali(corpo):
    """Angoli delle creste (canali disegnati) dalla maschera 'canali' del passo 7."""
    me = corpo.data
    att = me.color_attributes.get('canali')
    co = coords(me)
    if att is None:
        return np.radians(np.arange(0, 360, 22.5))
    d = np.empty(len(co) * 4, np.float32)
    att.data.foreach_get('color', d)
    d = d.reshape(-1, 4)
    sel = (d[:, 0] > 0.4) & (d[:, 2] > 0.25) & (d[:, 2] < 0.8)
    th = np.degrees(np.arctan2(co[sel, 1], co[sel, 0])) % 360
    h = np.bincount(th.astype(int) % 360, minlength=360).astype(float)
    k = np.exp(-0.5 * (np.arange(-6, 7) / 2.0) ** 2)
    h = np.convolve(np.r_[h[-6:], h, h[:6]], k / k.sum(), mode='same')[6:-6]
    picchi = [i for i in range(360) if h[i] >= h[(i - 1) % 360] and h[i] >= h[(i + 1) % 360] and h[i] > 0.25 * h.max()]
    picchi.sort(key=lambda i: -h[i])
    scelti = []
    for p in picchi:
        if all(min(abs(p - q), 360 - abs(p - q)) >= 11 for q in scelti):
            scelti.append(p)
    if len(scelti) < 8:
        return np.radians(np.arange(0, 360, 22.5))
    return np.radians(np.sort(scelti))


def _tubo(pts, raggi, lati, v0=0.0, v1=1.0, chiuso=False):
    """Tubo lungo la polilinea (riferimento a trasporto parallelo). Ritorna vertici, facce, uv per faccia."""
    pts = np.asarray(pts, float)
    n = len(pts)
    T = np.gradient(pts, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True) + 1e-12
    a = np.array([0, 0, 1.0]) if abs(T[0][2]) < 0.9 else np.array([1.0, 0, 0])
    U = np.zeros_like(T)
    u = np.cross(T[0], a)
    U[0] = u / np.linalg.norm(u)
    for i in range(1, n):
        u = U[i - 1] - T[i] * (U[i - 1] @ T[i])
        U[i] = u / (np.linalg.norm(u) + 1e-12)
    V = np.cross(T, U)
    ang = 2 * math.pi * np.arange(lati) / lati
    verts = (pts[:, None, :] + raggi[:, None, None] * (np.cos(ang)[None, :, None] * U[:, None, :]
                                                       + np.sin(ang)[None, :, None] * V[:, None, :])).reshape(-1, 3)
    facce, uvf = [], []
    vv = np.linspace(v0, v1, n)
    m = n if chiuso else n - 1
    for i in range(m):
        i2 = (i + 1) % n
        for j in range(lati):
            jn = (j + 1) % lati
            facce.append((i * lati + j, i * lati + jn, i2 * lati + jn, i2 * lati + j))
            uvf.append([(j / lati, vv[i]), ((j + 1) / lati, vv[i]), ((j + 1) / lati, vv[i2]), (j / lati, vv[i2])])
    if not chiuso:
        for estremo, verso in ((0, 1), (n - 1, -1)):
            c = len(verts)
            verts = np.vstack([verts, pts[estremo] - T[estremo] * raggi[estremo] * 0.5 * verso])
            for j in range(lati):
                jn = (j + 1) % lati
                a_, b_ = estremo * lati + j, estremo * lati + jn
                facce.append((b_, a_, c) if verso == 1 else (a_, b_, c))
                uvf.append([(j / lati, vv[estremo])] * 3)
    return verts, facce, uvf


def crea_interno(arm, corpo, n_lati=5):
    prof = profilo_campana(corpo)
    angoli = angoli_canali(corpo)
    rng = np.random.default_rng(9)
    V, F, UV = [], [], []

    def aggiungi(v, f, uv):
        off = sum(len(x) for x in V)
        V.append(v)
        F.extend(tuple(k + off for k in ff) for ff in f)
        UV.extend(uv)

    def linea(th, z0, z1, n, rientro):
        zz = np.linspace(z0, z1, n)
        pts = []
        for z in zz:
            r = raggio_esterno(prof, z, th) - rientro
            pts.append((r * math.cos(th), r * math.sin(th), z))
        return np.array(pts)

    t_bordo = lambda z: np.clip((Z_CIMA - z) / (Z_CIMA - Z_BORDO), 0, 1)  # noqa: E731
    # canali principali: dalla cima al bordo, si allargano un po' verso il basso
    for th in angoli:
        pts = linea(th, Z_CIMA, Z_BORDO, 24, RIENTRO)
        t = t_bordo(pts[:, 2])
        rag = 0.0045 + 0.0035 * t
        v, f, uv = _tubo(pts, rag, n_lati, 0.0, 1.0)
        aggiungi(v, f, uv)
    # secondari: a meta' tra due principali, da meta' altezza al bordo, con una biforcazione in basso
    ang = np.sort(angoli)
    for a, b in zip(ang, np.r_[ang[1:], ang[0] + 2 * math.pi]):
        th = 0.5 * (a + b)
        z0 = rng.uniform(-0.42, -0.36)
        pts = linea(th, z0, Z_BORDO, 14, RIENTRO + 0.004)
        t = t_bordo(pts[:, 2])
        v, f, uv = _tubo(pts, 0.0026 + 0.0014 * t, 4, float(t[0]), 1.0)
        aggiungi(v, f, uv)
        zb = rng.uniform(-0.56, -0.52)
        for s in (-1, 1):
            th2 = th + s * 0.22 * (b - a)
            p0 = linea(th, zb, zb, 1, RIENTRO + 0.004)[0]
            p1 = linea(th2, Z_BORDO + 0.004, Z_BORDO + 0.004, 1, RIENTRO + 0.004)[0]
            mid = 0.5 * (p0 + p1) + np.array([0, 0, -0.01])
            pts = np.array([p0, mid, p1])
            pts = np.stack([np.interp(np.linspace(0, 2, 6), [0, 1, 2], pts[:, k]) for k in range(3)], 1)
            aggiungi(*_tubo(pts, np.full(len(pts), 0.0018), 4, float(t_bordo(zb)), 1.0))
    # canale ad anello lungo il bordo
    nth = 120
    ths = np.linspace(-math.pi, math.pi, nth, endpoint=False)
    pts = np.array([(lambda r: (r * math.cos(th), r * math.sin(th), Z_BORDO))(raggio_esterno(prof, Z_BORDO, th) - RIENTRO)
                    for th in ths])
    v, f, uv = _tubo(pts, np.full(nth, 0.0075), n_lati, 1.0, 1.0, chiuso=True)
    aggiungi(v, f, uv)
    # gonadi: quattro anelli increspati intorno al centro, sopra la sottombrella
    for k in range(4):
        a0 = math.radians(45 + 90 * k)
        c = np.array([0.17 * math.cos(a0), 0.17 * math.sin(a0), -0.41])
        n = 40
        s = np.linspace(0, 2 * math.pi, n, endpoint=False)
        # ferro di cavallo: anello schiacciato verso il centro, increspato su e giu'
        rr = 0.075 * (1 + 0.25 * np.cos(s))
        pts = np.stack([c[0] + rr * np.cos(s + a0) * 1.0, c[1] + rr * np.sin(s + a0) * 1.0,
                        c[2] + 0.012 * np.sin(6 * s) + 0.03 * np.cos(s)], 1)
        v, f, uv = _tubo(pts, 0.013 + 0.005 * np.sin(9 * s) ** 2, 6, 0.3, 0.3, chiuso=True)
        aggiungi(v, f, uv)
    verts = np.vstack(V)
    mat = materiale_interno()
    me = bpy.data.meshes.new('Medusa_Interno')
    me.from_pydata([tuple(x) for x in verts], [], F)
    uvl = me.uv_layers.new(name='UVMap')
    for poly, uvs in zip(me.polygons, UV):
        for li, u in zip(poly.loop_indices, uvs):
            uvl.data[li].uv = u
    me.shade_smooth()
    me.materials.append(mat)
    ob = bpy.data.objects.new('Medusa_Interno', me)
    collega(ob)
    ob.parent = arm
    vg = ob.vertex_groups.new(name='campana')
    vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
    mod = ob.modifiers.new('Scheletro', 'ARMATURE')
    mod.object = arm
    # stessa contrazione della campana (medusa_04_scheletro.shape_key_campana)
    ob.shape_key_add(name='Basis', from_mix=False)
    sk = ob.shape_key_add(name='campana_contrai', from_mix=False)
    co = coords(me)
    z = co[:, 2]
    t = np.clip((Z_VITA - z) / (Z_VITA + 0.72), 0, 1)
    t = t * t * (3 - 2 * t)
    k = 1 - 0.16 * t
    nuovo = co.copy()
    nuovo[:, 0] *= k
    nuovo[:, 1] *= k
    nuovo[:, 2] = z - 0.05 * t
    sk.data.foreach_set('co', nuovo.ravel())
    sk.value = 0.0
    ntri = sum(len(p.vertices) - 2 for p in me.polygons)
    log(f'campana interna: {len(angoli)} canali principali, {len(angoli)} secondari, anello, 4 gonadi; {ntri} triangoli')
    return ob


def materiale_interno(nome='M_campana_interno'):
    """Emissivo, gradiente lungo v (cima gialla -> bordo rosa); le gonadi (v = 0.35) arancio."""
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nodo(nt, 'ShaderNodeOutputMaterial', (600, 0))
    b = nodo(nt, 'ShaderNodeBsdfPrincipled', (300, 0))
    b.name = 'BSDF'
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    tex = nodo(nt, 'ShaderNodeTexImage', (-200, 0))
    tex.name = 'base'
    tex.image = immagine(texture_interno())
    tex.extension = 'EXTEND'
    nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(tex.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 4.0
    b.inputs['Roughness'].default_value = 0.3
    return m


def texture_interno():
    """Gradiente 8 x 256 (v = 0 in cima, 1 al bordo) per colore ed emissione dei canali interni."""
    import cv2
    p = os.path.join(TEX, 'campana_interno.png')
    v = np.linspace(0, 1, 256)
    pos = np.array([g[0] for g in GRADIENTE])
    col = np.array([g[1] for g in GRADIENTE])
    lin = np.stack([np.interp(v, pos, col[:, i]) for i in range(3)], -1)
    srgb = np.clip(lin, 0, 1)
    img = np.repeat(srgb[::-1][:, None, :], 8, axis=1)          # riga 0 = v alto
    cv2.imwrite(p, (img * 255).astype(np.uint8)[..., ::-1])
    return p


# ---------------------------------------------------------------- bordo: frangia e puntini luminosi

def _contrai(ob):
    """Shape key 'campana_contrai' come quella del corpo (medusa_04_scheletro.shape_key_campana)."""
    me = ob.data
    ob.shape_key_add(name='Basis', from_mix=False)
    sk = ob.shape_key_add(name='campana_contrai', from_mix=False)
    co = coords(me)
    z = co[:, 2]
    t = np.clip((Z_VITA - z) / (Z_VITA + 0.72), 0, 1)
    t = t * t * (3 - 2 * t)
    k = 1 - 0.16 * t
    nuovo = co.copy()
    nuovo[:, 0] *= k
    nuovo[:, 1] *= k
    nuovo[:, 2] = z - 0.05 * t
    sk.data.foreach_set('co', nuovo.ravel())
    sk.value = 0.0


def _oggetto(nome, verts, facce, uvf, mat, arm, colori=None):
    me = bpy.data.meshes.new(nome)
    me.from_pydata([tuple(x) for x in verts], [], facce)
    uvl = me.uv_layers.new(name='UVMap')
    for poly, uvs in zip(me.polygons, uvf):
        for li, u in zip(poly.loop_indices, uvs):
            uvl.data[li].uv = u
    me.shade_smooth()
    for m in (mat if isinstance(mat, (list, tuple)) else [mat]):
        me.materials.append(m)
    ob = bpy.data.objects.new(nome, me)
    collega(ob)
    ob.parent = arm
    vg = ob.vertex_groups.new(name='campana')
    vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
    mod = ob.modifiers.new('Scheletro', 'ARMATURE')
    mod.object = arm
    return ob


def crea_bordo(arm, corpo, n_frange=44):
    """Bordo della campana come nel concept: una frangia di linguette carnose (stesso materiale dei tentacoli,
    nella parte chiara della texture) che pende dal bordo, e tra una linguetta e l'altra un puntino
    bioluminescente (materiale dell'interno). Stessa shape key della campana."""
    prof = profilo_campana(corpo)
    rng = np.random.default_rng(21)
    z_att = -0.668
    V, F, UV, MI = [], [], [], []

    def aggiungi(v, f, uv, mi):
        off = sum(len(x) for x in V)
        V.append(v)
        F.extend(tuple(k + off for k in ff) for ff in f)
        UV.extend(uv)
        MI.extend([mi] * len(f))

    for i in range(n_frange):
        th = 2 * math.pi * (i + rng.uniform(-0.15, 0.15)) / n_frange
        r0 = raggio_esterno(prof, z_att, th) - 0.006
        fuori = np.array([math.cos(th), math.sin(th), 0.0])
        lato = np.array([-math.sin(th), math.cos(th), 0.0])
        L = rng.uniform(0.035, 0.06)
        n = 7
        pts, larg = [], []
        for k in range(n):
            t = k / (n - 1)
            p = fuori * (r0 + 0.012 * t + 0.006 * math.sin(math.pi * t)) + np.array([0, 0, z_att - L * t])
            p += lato * 0.004 * math.sin(2.5 * math.pi * t + i)
            pts.append(p)
            larg.append(0.042 * (1 - 0.75 * t ** 1.3) * (0.85 + 0.3 * rng.uniform()))
        pts = np.array(pts)
        larg = np.array(larg)
        # linguetta: nastro a lente con la larghezza lungo il bordo
        lati = 6
        ang = 2 * math.pi * np.arange(lati) / lati
        verts = (pts[:, None, :] + (larg / 2)[:, None, None] * np.cos(ang)[None, :, None] * lato[None, None, :]
                 + (0.004 * (1 - 0.6 * np.linspace(0, 1, n)))[:, None, None] * np.sin(ang)[None, :, None]
                 * fuori[None, None, :]).reshape(-1, 3)
        f, uv = [], []
        for k in range(n - 1):
            for j in range(lati):
                jn = (j + 1) % lati
                f.append((k * lati + j, k * lati + jn, (k + 1) * lati + jn, (k + 1) * lati + j))
                v0, v1 = 0.55 + 0.4 * k / (n - 1), 0.55 + 0.4 * (k + 1) / (n - 1)
                uv.append([(0.5 + 0.5 * j / lati, v0), (0.5 + 0.5 * (j + 1) / lati, v0),
                           (0.5 + 0.5 * (j + 1) / lati, v1), (0.5 + 0.5 * j / lati, v1)])
        c = len(verts)
        verts = np.vstack([verts, pts[-1] + np.array([0, 0, -0.003])])
        for j in range(lati):
            f.append(((n - 1) * lati + j, (n - 1) * lati + (j + 1) % lati, c))
            uv.append([(0.75, 0.95)] * 3)
        aggiungi(verts, f, uv, 0)
        # puntino luminoso a meta' tra questa linguetta e la prossima
        th2 = th + math.pi / n_frange
        c2 = np.array([math.cos(th2), math.sin(th2), 0.0]) * (raggio_esterno(prof, z_att - 0.008, th2) + 0.002) \
            + np.array([0, 0, z_att - 0.008])
        rr = 0.0065
        sv, sf = [], []
        for a in range(5):
            for b in range(6):
                el = -math.pi / 2 + math.pi * a / 4
                az = 2 * math.pi * b / 6
                sv.append(c2 + rr * np.array([math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)]))
        for a in range(4):
            for b in range(6):
                bn = (b + 1) % 6
                sf.append((a * 6 + b, a * 6 + bn, (a + 1) * 6 + bn, (a + 1) * 6 + b))
        aggiungi(np.array(sv), sf, [[(0.5, 0.92)] * 4] * len(sf), 1)
    verts = np.vstack(V)
    mats = [bpy.data.materials['M_tentacoli'], bpy.data.materials.get('M_campana_interno') or materiale_interno()]
    ob = _oggetto('Medusa_Bordo', verts, F, UV, mats, arm)
    ob.data.polygons.foreach_set('material_index', np.array(MI, dtype=np.int32))
    ob.data.update()
    _contrai(ob)
    ntri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    log(f'bordo della campana: {n_frange} linguette e {n_frange} puntini luminosi, {ntri} triangoli')
    return ob
