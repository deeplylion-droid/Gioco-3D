"""Funzioni comuni per gli ambienti interni del capitolo 1 (corridoio, spogliatoi, stanzino).
Tutto in metri, Z in alto, pavimento a z=0. Le UV sono proiettate a scatola in coordinate di mondo,
cosi' le texture hanno la stessa scala su tutte le pareti."""
import math, os, random
import bpy, bmesh
from mathutils import Vector, Matrix, Euler, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
AI = os.path.join(ROOT, 'assets_src/ambienti_interni')
TEX = os.path.join(AI, 'texture')

# metri per ripetizione della texture
SCALA_UV = {
    'lamiera_crema': 2.0, 'lamiera_petrolio': 2.0, 'soffitto_lamiera': 2.5,
    'piastrelle_pavimento': 2.0, 'piastrelle_doccia': 1.5, 'piastrelle_verdi': 1.2,
    'armadietto_verde': 1.2, 'porta_lamiera': 1.5, 'ruggine': 1.0, 'metallo_grezzo': 1.0,
    'lamiera_grata': 1.0, 'vernice_rossa': 1.0, 'vernice_gialla': 1.0, 'legno_panca': 1.2, 'cemento': 2.0,
}

# ---------------------------------------------------------------- scena

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(7)

def collezione(nome):
    c = bpy.data.collections.get(nome)
    if c is None:
        c = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(c)
    return c

_COLL = [None]
def usa_collezione(nome):
    _COLL[0] = collezione(nome)

def _link(ob):
    (_COLL[0] or bpy.context.scene.collection).objects.link(ob)
    return ob

# ---------------------------------------------------------------- materiali

def _img(path, colore=True, lato=None):
    im = bpy.data.images.load(path, check_existing=True)
    if not colore:
        im.colorspace_settings.name = 'Non-Color'
    if lato and im.size[0] > lato:
        im.scale(lato, lato)
    return im

def mat_tex(nome):
    """Materiale PBR dalle texture in assets_src/ambienti_interni/texture/<nome>_*.jpg"""
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    def tex(suf, colore):
        p = os.path.join(TEX, f'{nome}_{suf}.jpg')
        if not os.path.exists(p):
            return None
        n = nt.nodes.new('ShaderNodeTexImage'); n.image = _img(p, colore, None if colore else 1024)
        return n
    c = tex('col', True); nt.links.new(c.outputs[0], b.inputs['Base Color'])
    r = tex('rgh', False); nt.links.new(r.outputs[0], b.inputs['Roughness'])
    mt = tex('met', False)
    if mt:
        nt.links.new(mt.outputs[0], b.inputs['Metallic'])
    n = tex('nrm', False)
    nm = nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = 1.0
    nt.links.new(n.outputs[0], nm.inputs['Color']); nt.links.new(nm.outputs[0], b.inputs['Normal'])
    return m

def mat_colore(nome, rgb, rough=0.5, metal=0.0, emiss=None, forza=0.0, alpha=1.0, trasm=0.0, ior=1.45):
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*rgb, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    b.inputs['IOR'].default_value = ior
    if trasm:
        b.inputs['Transmission Weight'].default_value = trasm
    if emiss:
        b.inputs['Emission Color'].default_value = (*emiss, 1)
        b.inputs['Emission Strength'].default_value = forza
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        m.blend_method = 'BLEND' if hasattr(m, 'blend_method') else None
    return m

def mat_immagine(nome, path, rough=0.6, emiss_forza=0.0, alpha=False):
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = _img(path)
    nt.links.new(t.outputs[0], b.inputs['Base Color'])
    if alpha:
        nt.links.new(t.outputs[1], b.inputs['Alpha'])
    b.inputs['Roughness'].default_value = rough
    if emiss_forza:
        nt.links.new(t.outputs[0], b.inputs['Emission Color'])
        b.inputs['Emission Strength'].default_value = emiss_forza
    return m

def materiali_base():
    """Materiali senza texture usati ovunque."""
    return dict(
        acqua=mat_colore('acqua', (0.6, 0.66, 0.64), rough=0.02, trasm=1.0, ior=1.333),
        vetro=mat_colore('vetro', (0.8, 0.85, 0.85), rough=0.05, trasm=1.0, ior=1.5),
        vetro_sporco=mat_colore('vetro_sporco', (0.7, 0.75, 0.7), rough=0.12, trasm=0.95, ior=1.5),
        luce_rossa=mat_colore('luce_rossa_emissiva', (1, 0.1, 0.05), rough=0.3, emiss=(1, 0.05, 0.02), forza=40),
        neon=mat_colore('neon_emissivo', (0.9, 1, 0.95), rough=0.3, emiss=(0.82, 1.0, 0.92), forza=18),
        neon_spento=mat_colore('neon_spento', (0.75, 0.78, 0.76), rough=0.25),
        nero=mat_colore('fessura_nera', (0.01, 0.01, 0.01), rough=0.9),
        cromo=mat_colore('cromo_sporco', (0.55, 0.55, 0.53), rough=0.25, metal=1.0),
        gomma=mat_colore('gomma_nera', (0.03, 0.03, 0.03), rough=0.8),
        plastica_bianca=mat_colore('plastica_bianca', (0.42, 0.4, 0.34), rough=0.6),
        sughero=mat_colore('sughero', (0.42, 0.3, 0.18), rough=0.9),
        carta=mat_colore('carta_ingiallita', (0.75, 0.7, 0.58), rough=0.9),
    )

# ---------------------------------------------------------------- collisioni
# Scatole di collisione semplificate, raccolte per collezione e unite alla fine in un oggetto
# '<zona>_collisione-colonly' (Godot lo importa come StaticBody3D con forma trimesh, invisibile).
COL = {}
_RACCOGLI = [False]

def raccogli(attivo):
    _RACCOGLI[0] = attivo

def col_scatola(lo, hi, matrice=None):
    """Scatola di collisione della zona: lo e hi nel mondo, oppure, con matrice (4x4), nello spazio locale che la
    matrice porta nel mondo (scatola orientata come un oggetto ruotato)."""
    k = _COLL[0].name if _COLL[0] else 'scena'
    COL.setdefault(k, []).append((tuple(lo), tuple(hi), None if matrice is None else [list(r) for r in matrice]))

def crea_collisione(nome, zona):
    import bmesh as _bm
    bm = _bm.new()
    for lo, hi, mat in COL.get(zona, []):
        r = _bm.ops.create_cube(bm, size=1.0)
        m = Matrix(mat) if mat is not None else Matrix.Identity(4)
        for v in r['verts']:
            v.co = m @ Vector((lo[0] + (v.co.x + .5) * (hi[0] - lo[0]), lo[1] + (v.co.y + .5) * (hi[1] - lo[1]), lo[2] + (v.co.z + .5) * (hi[2] - lo[2])))
    ob = _ob_da_bm(nome + '_collisione-colonly', bm, None)
    ob.hide_render = True; ob.display_type = 'WIRE'
    return ob

# ---------------------------------------------------------------- geometria

def uv_scatola(ob, scala=None):
    """Proiezione a scatola in coordinate di mondo (scala = metri per ripetizione)."""
    bpy.context.view_layer.update()
    me = ob.data
    if scala is None:
        mn = me.materials[0].name if me.materials else ''
        scala = SCALA_UV.get(mn, 1.0)
    mw = ob.matrix_world
    bm = bmesh.new(); bm.from_mesh(me)
    uv = bm.loops.layers.uv.verify()
    rot = mw.to_3x3()
    for f in bm.faces:
        n = (rot @ f.normal); a = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = mw @ l.vert.co
            if a == 2: u, v = p.x, p.y * (1 if n.z > 0 else -1)
            elif a == 0: u, v = p.y * (1 if n.x > 0 else -1), p.z
            else: u, v = p.x * (-1 if n.y > 0 else 1), p.z
            l[uv].uv = (u / scala, v / scala)
    bm.to_mesh(me); bm.free()

def _ob_da_bm(nome, bm, mat):
    me = bpy.data.meshes.new(nome); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome, me); _link(ob)
    if mat is not None:
        me.materials.append(mat)
    return ob

def scatola(nome, lo, hi, mat=None, uv=True, smussa=0.0):
    """Parallelepipedo tra gli angoli lo e hi (coordinate di mondo)."""
    lo = Vector(lo); hi = Vector(hi)
    if _RACCOGLI[0]:
        col_scatola(lo, hi)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((lo.x + (v.co.x + .5) * (hi.x - lo.x), lo.y + (v.co.y + .5) * (hi.y - lo.y), lo.z + (v.co.z + .5) * (hi.z - lo.z)))
    if smussa:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=smussa, segments=1, affect='EDGES')
    ob = _ob_da_bm(nome, bm, mat)
    if uv and mat is not None:
        uv_scatola(ob)
    return ob

def cilindro(nome, p0, p1, r, mat=None, seg=16, uv=True, tappi=True):
    p0 = Vector(p0); p1 = Vector(p1); d = p1 - p0; L = d.length
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=tappi, segments=seg, radius1=r, radius2=r, depth=L)
    q = d.normalized().to_track_quat('Z', 'Y')
    M = Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    ob = _ob_da_bm(nome, bm, mat)
    if uv and mat is not None:
        _uv_cilindro(ob, p0, d, r)
    return ob

def _uv_cilindro(ob, p0, d, r):
    me = ob.data; bm = bmesh.new(); bm.from_mesh(me); uv = bm.loops.layers.uv.verify()
    ax = d.normalized(); ref = ax.orthogonal().normalized(); ref2 = ax.cross(ref)
    for f in bm.faces:
        for l in f.loops:
            p = l.vert.co - p0
            t = p.dot(ax); ang = math.atan2(p.dot(ref2), p.dot(ref))
            l[uv].uv = (ang * max(r, 0.05) / 1.0, t / 1.0)
    bm.to_mesh(me); bm.free()

def toro(nome, centro, R, r, mat=None, rot=(0, 0, 0), seg=32, seg2=12):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        anello = []
        for j in range(seg2):
            b = 2 * math.pi * j / seg2
            x = (R + r * math.cos(b)) * math.cos(a); y = (R + r * math.cos(b)) * math.sin(a); z = r * math.sin(b)
            anello.append(bm.verts.new((x, y, z)))
        verts.append(anello)
    uvdata = []
    for i in range(seg):
        for j in range(seg2):
            a, b, c, d = verts[i][j], verts[(i + 1) % seg][j], verts[(i + 1) % seg][(j + 1) % seg2], verts[i][(j + 1) % seg2]
            f = bm.faces.new((a, b, c, d)); uvdata.append((f, i, j))
    uvl = bm.loops.layers.uv.verify()
    for f, i, j in uvdata:
        cs = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
        for l, (ii, jj) in zip(f.loops, cs):
            l[uvl].uv = (ii / seg, jj / seg2)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    M = Matrix.Translation(centro) @ Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    ob = _ob_da_bm(nome, bm, mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob

def piano(nome, centro, sx, sy, mat=None, rot=(0, 0, 0), uv_piena=True):
    """Rettangolo sx*sy; con uv_piena l'immagine copre tutto il rettangolo (per cartelloni)."""
    bm = bmesh.new()
    vs = [bm.verts.new((x * sx / 2, y * sy / 2, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(vs); uvl = bm.loops.layers.uv.verify()
    for l, c in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        l[uvl].uv = c
    M = Matrix.Translation(centro) @ Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    ob = _ob_da_bm(nome, bm, mat)
    if not uv_piena and mat is not None:
        uv_scatola(ob)
    return ob

def unisci(nome, obs):
    obs = [o for o in obs if o is not None]
    if not obs:
        return None
    if len(obs) == 1:
        obs[0].name = nome; obs[0].data.name = nome
        return obs[0]
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nome; ob.data.name = nome
    return ob

def origine(ob, punto):
    """Sposta l'origine dell'oggetto nel punto dato (cardine di una porta, perno di una ruota...)."""
    punto = Vector(punto)
    d = punto - ob.matrix_world.translation
    ob.data.transform(Matrix.Translation(-d))
    ob.location = ob.location + d
    bpy.context.view_layer.update()
    return ob

def ammacca(ob, forza=0.015, scala=3.0, seme=0.0, suddividi=6):
    """Ammaccature: suddivide e sposta i vertici lungo la normale con del rumore."""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=suddividi, use_grid_fill=True)
    bm.normal_update()
    off = Vector((seme, seme * 1.7, seme * 0.3))
    for v in bm.verts:
        n = noise.noise(v.co * scala + off)
        bozza = max(0.0, noise.noise(v.co * scala * 0.5 + off * 2) - 0.2)
        v.co -= v.normal * (n * forza * 0.4 + bozza * forza * 2.0)
    bm.to_mesh(ob.data); bm.free()
    return ob

def vuoto(nome, loc, rot=(0, 0, 0), tipo='PLAIN_AXES', dim=0.2):
    e = bpy.data.objects.new(nome, None); e.empty_display_type = tipo; e.empty_display_size = dim
    e.location = loc; e.rotation_euler = rot
    return _link(e)

def figlio(ob, padre):
    bpy.context.view_layer.update()
    mw = ob.matrix_world.copy(); ob.parent = padre; ob.matrix_world = mw
    return ob

# ---------------------------------------------------------------- stanze

def stanza(nome, x0, y0, x1, y1, h, mats, aperture=None, t=0.2, soffitto=True, pavimento=True, zoccolo=1.1, attaccata=''):
    """Pavimento, soffitto e 4 pareti attorno al rettangolo interno.
    aperture: {'N'|'S'|'E'|'W': [(da, a, z_basso, z_alto), ...]} lungo la parete (coordinate x per N/S, y per E/W).
    mats: dict con 'pav', 'sof', 'muro', 'muro_basso' (zoccolo).
    attaccata: i lati ('N', 'S', 'E', 'W') addossati a un'altra stanza: lì pavimento, soffitto e pareti non vanno
    oltre il rettangolo interno (lo spessore lo dà la parete dell'altra stanza; prima ci entravano)."""
    aperture = aperture or {}
    parti = []
    prima = _RACCOGLI[0]; raccogli(True)
    try:
        return _stanza(nome, x0, y0, x1, y1, h, mats, aperture, t, soffitto, pavimento, zoccolo, parti, attaccata)
    finally:
        raccogli(prima)

def _stanza(nome, x0, y0, x1, y1, h, mats, aperture, t, soffitto, pavimento, zoccolo, parti, attaccata=''):
    tw, te, ts, tn = (0 if l in attaccata else t for l in 'WESN')
    if pavimento:
        parti.append(scatola(nome + '_pav', (x0 - tw, y0 - ts, -0.2), (x1 + te, y1 + tn, 0), mats['pav']))
    if soffitto:
        parti.append(scatola(nome + '_sof', (x0 - tw, y0 - ts, h), (x1 + te, y1 + tn, h + 0.2), mats['sof']))
    lati = {
        'S': ('x', x0, x1, lambda a, b: ((a, y0 - t), (b, y0))),
        'N': ('x', x0, x1, lambda a, b: ((a, y1), (b, y1 + t))),
        'W': ('y', y0, y1, lambda a, b: ((x0 - t, a), (x0, b))),
        'E': ('y', y0, y1, lambda a, b: ((x1, a), (x1 + t, b))),
    }
    for lato, (asse, a0, a1, rett) in lati.items():
        ap = sorted(aperture.get(lato, []))
        # segmenti pieni tra le aperture, e sopra/sotto ogni apertura
        if lato in attaccata:
            continue
        inizio, fine = (a0 - (tw if asse == 'x' else ts)), (a1 + (te if asse == 'x' else tn))
        tagli = [inizio] + [v for (da, a, zb, za) in ap for v in (da, a)] + [fine]
        segmenti = [(tagli[i], tagli[i + 1]) for i in range(0, len(tagli), 2)]
        for (da, a) in segmenti:
            if a - da > 1e-4:
                parti += _muro(nome, lato, rett(da, a), 0, h, mats, zoccolo)
        for (da, a, zb, za) in ap:
            if za < h:
                parti += _muro(nome, lato, rett(da, a), za, h, mats, zoccolo)
            if zb > 0:
                parti += _muro(nome, lato, rett(da, a), 0, zb, mats, zoccolo)
    return parti

def _muro(nome, lato, rett, z0, z1, mats, zoccolo):
    (ax, ay), (bx, by) = rett
    out = []
    # battiscopa e listello sul lato interno della parete (lato = dove guarda la stanza)
    if 'battiscopa' in mats:
        def fascia(za, zb, sp, mat, sm):
            if lato == 'S':
                return scatola(f'{nome}_fascia', (ax, by, za), (bx, by + sp, zb), mat, smussa=sm)
            if lato == 'N':
                return scatola(f'{nome}_fascia', (ax, ay - sp, za), (bx, ay, zb), mat, smussa=sm)
            if lato == 'W':
                return scatola(f'{nome}_fascia', (bx, ay, za), (bx + sp, by, zb), mat, smussa=sm)
            return scatola(f'{nome}_fascia', (ax - sp, ay, za), (ax, by, zb), mat, smussa=sm)
        lung = max(abs(bx - ax), abs(by - ay))
        if lung > 0.05:
            if z0 <= 0.0:
                out.append(fascia(0.0, 0.13, 0.025, mats['battiscopa'], 0.008))
            if z0 < zoccolo < z1 and 'muro_basso' in mats:
                out.append(fascia(zoccolo - 0.02, zoccolo + 0.02, 0.018, mats['battiscopa'], 0.008))
    if z0 < zoccolo and 'muro_basso' in mats:
        out.append(scatola(f'{nome}_muro{lato}', (ax, ay, z0), (bx, by, min(z1, zoccolo)), mats['muro_basso']))
        if z1 > zoccolo:
            out.append(scatola(f'{nome}_muro{lato}', (ax, ay, zoccolo), (bx, by, z1), mats['muro']))
    else:
        out.append(scatola(f'{nome}_muro{lato}', (ax, ay, z0), (bx, by, z1), mats['muro']))
    return out

def tubo_percorso(nome, punti, r, mat, flange=True, passo_flange=2.0):
    """Tubo a spezzata con gomiti (sfere) e flange."""
    parti = []
    for i in range(len(punti) - 1):
        p0, p1 = Vector(punti[i]), Vector(punti[i + 1])
        parti.append(cilindro(f'{nome}_{i}', p0, p1, r, mat, seg=28, tappi=False))
        if flange:
            L = (p1 - p0).length; d = (p1 - p0).normalized()
            k = 1
            while k * passo_flange < L - 0.2:
                c = p0 + d * k * passo_flange
                parti.append(cilindro(f'{nome}_fl', c - d * 0.03, c + d * 0.03, r * 1.35, mat, seg=28))
                k += 1
    for p in punti[1:-1]:
        bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=14, radius=r * 1.02)
        bmesh.ops.translate(bm, vec=Vector(p), verts=bm.verts)
        o = _ob_da_bm(f'{nome}_gomito', bm, mat); uv_scatola(o, 1.0); parti.append(o)
    ob = unisci(nome, parti)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob

# ---------------------------------------------------------------- luci

def luce_punto(nome, loc, colore, watt, raggio=0.05):
    l = bpy.data.lights.new(nome, 'POINT'); l.color = colore; l.energy = watt
    l.shadow_soft_size = raggio
    ob = bpy.data.objects.new(nome, l); ob.location = loc
    return _link(ob)

def luce_area(nome, loc, colore, watt, sx, sy, rot=(0, 0, 0)):
    l = bpy.data.lights.new(nome, 'AREA'); l.shape = 'RECTANGLE'; l.size = sx; l.size_y = sy
    l.color = colore; l.energy = watt
    ob = bpy.data.objects.new(nome, l); ob.location = loc; ob.rotation_euler = rot
    return _link(ob)

def luce_spot(nome, loc, rot, colore, watt, angolo=70, raggio=0.05):
    l = bpy.data.lights.new(nome, 'SPOT'); l.color = colore; l.energy = watt
    l.spot_size = math.radians(angolo); l.spot_blend = 0.6; l.shadow_soft_size = raggio
    ob = bpy.data.objects.new(nome, l); ob.location = loc; ob.rotation_euler = rot
    return _link(ob)

ROSSO = (1.0, 0.025, 0.012)
NEON = (0.78, 1.0, 0.9)

def lampada_emergenza(nome, loc, normale, M, watt=40, accesa=True):
    """Plafoniera stagna con gabbia (come S01/S03): corpo, vetro emissivo, gabbia, luce rossa.
    normale: direzione in cui guarda la parete ((1,0,0), (0,-1,0), (0,0,-1) ...).
    Con il modello Meshy di qualità alta (meshy_hq/lampada_muro.glb) usa quello."""
    import ambienti1_hq as HQ
    n = Vector(normale).normalized(); p = Vector(loc)
    if HQ.disponibile('lampada_muro'):
        rosso = lambda c, nrm: c[0] > 0.25 and c[0] > c[1] * 2.2 and c[0] > c[2] * 2.0
        HQ.dividi('lampada_muro', 'lampada_muro_vetro', rosso, (1, 0.05, 0.02), 14.0)
        R = n.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        corpo = HQ.metti(nome, 'lampada_muro', (0, 0, 0), (0.3, None, None))
        vetro = HQ.metti(nome + '_vetro', 'lampada_muro', (0, 0, 0), (0.3, None, None), parte='lampada_muro_vetro')
        for o in (corpo, vetro):
            o.matrix_world = Matrix.Translation(p) @ R @ o.matrix_world
        luce = luce_punto(nome + '_luce', p + n * 0.22, ROSSO, watt, 0.06) if accesa else None
        return corpo, vetro, luce
    q = n.to_track_quat('Z', 'Y'); R = q.to_matrix().to_4x4()
    parti = []
    base = scatola(nome + '_base', (-0.14, -0.08, 0), (0.14, 0.08, 0.04), M['metallo_grezzo'], uv=False)
    vetro = scatola(nome + '_vetro', (-0.11, -0.06, 0.04), (0.11, 0.06, 0.1), M['luce_rossa'] if accesa else M['vetro_sporco'], uv=False, smussa=0.02)
    gab = []
    for x in (-0.07, 0, 0.07):
        gab.append(scatola(nome + '_g', (x - 0.006, -0.07, 0.04), (x + 0.006, 0.07, 0.115), M['metallo_grezzo'], uv=False))
    gab.append(scatola(nome + '_g', (-0.125, -0.006, 0.04), (0.125, 0.006, 0.118), M['metallo_grezzo'], uv=False))
    corpo = unisci(nome, [base] + gab)
    for o in (corpo, vetro):
        o.matrix_world = Matrix.Translation(p) @ R
        uv_scatola(o, 0.5)
    vetro.name = nome + '_vetro'
    luce = None
    if accesa:
        luce = luce_punto(nome + '_luce', p + n * 0.2, ROSSO, watt, 0.06)
    return corpo, vetro, luce

def neon_soffitto(nome, centro, lung, M, h_soffitto, stato='acceso', watt=60, appeso=0.0, rot_z=0.0):
    """Plafoniera a due tubi. stato: acceso | spento | sfarfalla (tubo separato da animare in Godot)."""
    import ambienti1_hq as HQ
    x, y, _ = centro; z = h_soffitto - 0.06 - appeso
    if HQ.disponibile('plafoniera_neon'):
        giu = lambda c, nrm: nrm.z < -0.6 and (c[0] + c[1] + c[2]) > 1.6
        HQ.dividi('plafoniera_neon', 'plafoniera_neon_diffusore', giu, (0.82, 1.0, 0.92), 10.0)
        T = Matrix.Translation((x, y, h_soffitto - 0.1 - appeso)) @ Matrix.Rotation(rot_z, 4, 'Z')
        if appeso:
            T = T @ Matrix.Rotation(math.radians(18), 4, 'X')
        corpo = HQ.metti(nome, 'plafoniera_neon', (0, 0, 0), (lung, 0.3, 0.1))
        suff = '_tubo_sfarfalla' if stato == 'sfarfalla' else ('_tubi_accesi' if stato == 'acceso' else '_tubi')
        tubo = HQ.metti(nome + suff, 'plafoniera_neon', (0, 0, 0), (lung, 0.3, 0.1), parte='plafoniera_neon_diffusore')
        if stato == 'spento':
            tubo.data = tubo.data  # stessa mesh: il materiale spento lo mette Godot (vedi interni.gd)
        for o in (corpo, tubo):
            o.matrix_world = T @ o.matrix_world
        if appeso:
            # il cavo scende fino al dorso della plafoniera (inclinata): prima finiva 5-6 cm sopra e non la reggeva
            bpy.context.view_layer.update()
            ws = [corpo.matrix_world @ v.co for v in corpo.data.vertices]
            dorso = max((p.z for p in ws if abs(p.x - x) < 0.08 and abs(p.y - y) < 0.08), default=z + 0.05)
            cilindro(nome + '_cavo', (x, y, h_soffitto), (x, y, dorso - 0.004), 0.004, M['gomma'], seg=6)
        luce = luce_area(nome + '_luce', (x, y, z - 0.05), NEON, watt, lung, 0.12, (0, 0, rot_z)) if stato != 'spento' else None
        return corpo, tubo, luce
    parti = [scatola(nome + '_corpo', (-lung / 2, -0.09, 0.0), (lung / 2, 0.09, 0.06), M['metallo_grezzo'], uv=False)]
    tubi = []
    for dy in (-0.045, 0.045):
        tm = M['neon'] if stato != 'spento' else M['neon_spento']
        tubi.append(cilindro(nome + '_tubo', (-lung / 2 + 0.04, dy, -0.02), (lung / 2 - 0.04, dy, -0.02), 0.014, tm, seg=10))
    corpo = unisci(nome, parti)
    tubo = unisci(nome + ('_tubo_sfarfalla' if stato == 'sfarfalla' else '_tubi'), tubi)
    T = Matrix.Translation((x, y, z)) @ Matrix.Rotation(rot_z, 4, 'Z')
    if appeso:
        # appesa storta a un cavo: inclinata
        T = T @ Matrix.Rotation(math.radians(18), 4, 'X')
        cav = cilindro(nome + '_cavo', (x, y, h_soffitto), (x, y, z + 0.05), 0.004, M['gomma'], seg=6)
    for o in (corpo, tubo):
        o.matrix_world = T
    uv_scatola(corpo, 0.6)
    luce = None
    if stato != 'spento':
        luce = luce_area(nome + '_luce', (x, y, z - 0.05), NEON, watt, lung, 0.12, (0, 0, rot_z))
    return corpo, tubo, luce

# ---------------------------------------------------------------- oggetti Meshy

def importa_prop(nome, file, loc, rot_z=0.0, dim=None, asse='max', rot=(0, 0, 0)):
    """Importa un GLB di Meshy, unisce le mesh, scala alla misura 'dim' (metri) lungo 'asse'
    (max | x | y | z) e appoggia la base a terra nel punto loc."""
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=file)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    for o in nuovi:
        for c in o.users_collection:
            c.objects.unlink(o)
        _link(o)
    meshes = [o for o in nuovi if o.type == 'MESH']
    for o in meshes:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    for o in nuovi:
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    ob = unisci(nome, meshes) if len(meshes) > 1 else meshes[0]
    ob.name = nome
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.data.transform(Euler(rot).to_matrix().to_4x4())
    bb = [Vector(v.co) for v in ob.data.vertices]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    size = hi - lo
    if dim:
        s = dim / (max(size) if asse == 'max' else size['xyz'.index(asse)])
        ob.data.transform(Matrix.Scale(s, 4))
        lo *= s; hi *= s
    c = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    ob.data.transform(Matrix.Translation(-c))
    ob.location = loc; ob.rotation_euler = (0, 0, rot_z)
    for m in ob.data.materials:
        m.name = 'meshy_' + nome
        for k, n in enumerate(x for x in m.node_tree.nodes if x.type == 'TEX_IMAGE' and x.image):
            if not n.image.name.startswith('meshy_'):
                n.image.name = f'meshy_{nome}_{k}'
                if n.image.size[0] > 1024:
                    n.image.scale(1024, 1024)
    return ob

# ---------------------------------------------------------------- render ed export

def imposta_render(campioni=128, w=1600, h=900):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
    sc.cycles.samples = campioni; sc.cycles.use_denoising = True
    sc.cycles.use_adaptive_sampling = True; sc.cycles.adaptive_threshold = 0.02
    sc.cycles.max_bounces = 6; sc.cycles.diffuse_bounces = 3; sc.cycles.glossy_bounces = 3
    sc.cycles.transmission_bounces = 4; sc.cycles.volume_bounces = 1
    sc.cycles.volume_step_rate = 4.0
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Punchy'
    sc.view_settings.exposure = float(os.environ.get('ESPOSIZIONE', '0.6'))
    sc.render.image_settings.file_format = 'JPEG'; sc.render.image_settings.quality = 92
    w_ = bpy.data.worlds.new('mondo'); sc.world = w_
    w_.use_nodes = True
    bg = w_.node_tree.nodes['Background']; bg.inputs['Color'].default_value = (0.002, 0.002, 0.003, 1)
    bg.inputs['Strength'].default_value = 1.0

def nebbia(nome, lo, hi, densita=0.02, colore=(0.8, 0.8, 0.8), bassa=False, anisotropia=0.3):
    """Volume di nebbia per i render Cycles (non va esportato: in Godot si usa la nebbia volumetrica)."""
    ob = scatola(nome, lo, hi, None, uv=False)
    m = bpy.data.materials.new(nome); m.use_nodes = True
    nt = m.node_tree; nt.nodes.remove(nt.nodes['Principled BSDF'])
    v = nt.nodes.new('ShaderNodeVolumePrincipled')
    v.inputs['Color'].default_value = (*colore, 1); v.inputs['Density'].default_value = densita
    v.inputs['Anisotropy'].default_value = anisotropia
    if bassa:
        # piu' densa vicino al pavimento: densita' * (1 - z/altezza)^2
        tc = nt.nodes.new('ShaderNodeTexCoord'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
        nt.links.new(tc.outputs['Object'], sep.inputs[0])
        mr = nt.nodes.new('ShaderNodeMapRange')
        mr.inputs['From Min'].default_value = -0.5; mr.inputs['From Max'].default_value = 0.5
        mr.inputs['To Min'].default_value = 1.0; mr.inputs['To Max'].default_value = 0.0
        nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
        pw = nt.nodes.new('ShaderNodeMath'); pw.operation = 'POWER'; pw.inputs[1].default_value = 2.0
        nt.links.new(mr.outputs[0], pw.inputs[0])
        mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = densita
        nt.links.new(pw.outputs[0], mul.inputs[0]); nt.links.new(mul.outputs[0], v.inputs['Density'])
    nt.links.new(v.outputs[0], nt.nodes['Material Output'].inputs['Volume'])
    ob.data.materials.append(m)
    ob['solo_render'] = True
    ob.visible_shadow = False
    return ob

def camera(nome, loc, guarda, lente=20, inclina=0.0):
    c = bpy.data.cameras.new(nome); c.lens = lente; c.sensor_width = 36
    c.clip_start = 0.05
    ob = bpy.data.objects.new(nome, c); ob.location = loc
    d = Vector(guarda) - Vector(loc)
    ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    ob.rotation_euler.rotate_axis('Z', math.radians(inclina))
    bpy.context.scene.collection.objects.link(ob)
    ob['solo_render'] = True
    return ob

def render(cam, path):
    sc = bpy.context.scene; sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

def esporta_glb(path, collezioni):
    """Esporta in GLB gli oggetti delle collezioni date (senza camere e volumi di nebbia)."""
    bpy.ops.object.select_all(action='DESELECT')
    n = 0
    for cn in collezioni:
        for o in bpy.data.collections[cn].all_objects:
            if o.get('solo_render') or o.type == 'CAMERA':
                continue
            o.hide_set(False); o.select_set(True); n += 1
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', export_texture_dir='texture', use_selection=True,
                              export_lights=True, export_extras=True, export_apply=True,
                              export_image_format='JPEG', export_jpeg_quality=85, export_yup=True)
    b = path[:-5] + '.bin'
    print('esportato', path, n, 'oggetti', (os.path.getsize(path) + os.path.getsize(b)) // 1024, 'KB')
