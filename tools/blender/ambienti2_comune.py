"""Funzioni comuni agli script degli ambienti tecnici (sala pompe, camera delle onde, scivoli).

Convenzioni (vedi assets_src/ambienti_tecnici/README.md):
- unita' in metri, Z in alto in Blender (Y in alto in Godot dopo l'export glTF);
- materiali solo Principled BSDF con texture immagine collegate direttamente, cosi' l'export GLB
  porta in Godot lo stesso aspetto del render;
- UV "a scatola" in coordinate del mondo: 1 unita' UV = SCALA_UV metri, quindi le texture hanno la
  stessa scala su tutti i pezzi;
- oggetti che si muovono in Godot: un oggetto separato con l'origine sul perno (TURBINA_*, LEVA, PORTA_*, PARATIA_*, GRATA_*);
- segnaposto per Godot: Empty chiamati VAPORE_*, LUCE_*, PUNTO_*.
"""
import math, os, sys
import bpy, bmesh
from mathutils import Vector, Matrix, Euler

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.normpath(os.path.join(QUI, '..', '..'))
SRC = os.path.join(RADICE, 'assets_src', 'ambienti_tecnici')
TEX = os.path.join(SRC, 'texture')
RENDER = os.path.join(RADICE, 'docs', 'report', 'render_ambienti2')


# ---------------------------------------------------------------- scena

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.unit_settings.system = 'METRIC'
    return s


def collezione(nome):
    c = bpy.data.collections.get(nome)
    if c is None:
        c = bpy.data.collections.new(nome)
        bpy.context.scene.collection.children.link(c)
    return c


_coll_attiva = [None]


def usa_collezione(nome):
    _coll_attiva[0] = collezione(nome)


def _link(ob):
    (_coll_attiva[0] or bpy.context.scene.collection).objects.link(ob)
    return ob


# ---------------------------------------------------------------- materiali

_img_cache = {}


def immagine(path, colore=True):
    key = (path, colore)
    if key not in _img_cache:
        im = bpy.data.images.load(path, check_existing=True)
        im.colorspace_settings.name = 'sRGB' if colore else 'Non-Color'
        _img_cache[key] = im
    return _img_cache[key]


def _tex(nt, path, colore, x, y):
    n = nt.nodes.new('ShaderNodeTexImage')
    n.image = immagine(path, colore)
    n.location = (x, y)
    return n


def mat_pbr(nome, aid=None, color=None, normal=None, rough=None, metal=None, ao=None, opacity=None, orm=None,
            base=(0.5, 0.5, 0.5), roughness=0.6, metallic=0.0, normal_forza=1.0, emissione=None,
            emissione_forza=0.0, alpha=1.0, trasmissione=0.0, ior=1.45, doppia_faccia=True):
    """Materiale PBR. `aid` = cartella ambientCG in texture/ (prende le mappe standard).
    I singoli percorsi (relativi a texture/) sovrascrivono quelli di `aid`."""
    m = bpy.data.materials.get(nome)
    if m:
        return m
    m = bpy.data.materials.new(nome)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    p = nt.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*base, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    p.inputs['IOR'].default_value = ior
    if trasmissione:
        p.inputs['Transmission Weight'].default_value = trasmissione

    def trova(mappa):
        if aid is None:
            return None
        f = os.path.join(TEX, aid, f'{aid}_{mappa}.jpg')
        return f if os.path.exists(f) else None

    color = os.path.join(TEX, color) if color else trova('Color')
    normal = os.path.join(TEX, normal) if normal else trova('NormalGL')
    rough = os.path.join(TEX, rough) if rough else trova('Roughness')
    metal = os.path.join(TEX, metal) if metal else trova('Metalness')
    opacity = os.path.join(TEX, opacity) if opacity else trova('Opacity')
    if orm:
        # ORM del kit dell'ambiente: R occlusione, G rugosita', B metallo
        t = _tex(nt, os.path.join(TEX, orm), False, -900, 0)
        sep = nt.nodes.new('ShaderNodeSeparateColor'); sep.location = (-600, 0)
        nt.links.new(t.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs['Green'], p.inputs['Roughness'])
        nt.links.new(sep.outputs['Blue'], p.inputs['Metallic'])
        rough = metal = None
    if color:
        t = _tex(nt, color, True, -700, 300)
        nt.links.new(t.outputs['Color'], p.inputs['Base Color'])
    if rough:
        t = _tex(nt, rough, False, -700, 0)
        nt.links.new(t.outputs['Color'], p.inputs['Roughness'])
    if metal:
        t = _tex(nt, metal, False, -700, -250)
        nt.links.new(t.outputs['Color'], p.inputs['Metallic'])
    if normal:
        t = _tex(nt, normal, False, -900, -500)
        nm = nt.nodes.new('ShaderNodeNormalMap'); nm.location = (-400, -500)
        nm.inputs['Strength'].default_value = normal_forza
        nt.links.new(t.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], p.inputs['Normal'])
    if opacity:
        t = _tex(nt, opacity, False, -700, -750)
        nt.links.new(t.outputs['Color'], p.inputs['Alpha'])
        _alpha_clip(m)
    if alpha < 1.0:
        p.inputs['Alpha'].default_value = alpha
        _alpha_blend(m)
    if emissione is not None:
        p.inputs['Emission Color'].default_value = (*emissione, 1)
        p.inputs['Emission Strength'].default_value = emissione_forza
    m.use_backface_culling = not doppia_faccia
    return m


def _alpha_clip(m):
    for attr, val in (('surface_render_method', 'DITHERED'), ('blend_method', 'CLIP')):
        try:
            setattr(m, attr, val)
        except Exception:
            pass


def _alpha_blend(m):
    for attr, val in (('surface_render_method', 'BLENDED'), ('blend_method', 'BLEND')):
        try:
            setattr(m, attr, val)
        except Exception:
            pass


def mat_emissivo(nome, colore, forza, base=None):
    return mat_pbr(nome, base=base or colore, roughness=0.4, emissione=colore, emissione_forza=forza)


def mat_acqua_nera(nome='ACQUA_nera'):
    """Segnaposto: acqua scura e lucida. Lo shader vero lo fa l'agente dell'acqua (oggetti ACQUA_*)."""
    return mat_pbr(nome, base=(0.004, 0.006, 0.006), roughness=0.03, ior=1.33, metallic=0.0)


def mat_acqua_corrente(nome='ACQUA_corrente'):
    return mat_pbr(nome, base=(0.03, 0.05, 0.05), roughness=0.1, ior=1.33,
                   normal='Plastic006/Plastic006_NormalGL.jpg', normal_forza=1.5)


def mat_vetro(nome='vetro_sporco', base=(0.75, 0.82, 0.8), alpha=0.25, roughness=0.12):
    return mat_pbr(nome, base=base, roughness=roughness, alpha=alpha, ior=1.5)


def assegna(ob, m):
    ob.data.materials.clear()
    ob.data.materials.append(m)
    return ob


# ---------------------------------------------------------------- UV e shading

SCALA_UV = 2.0  # metri per ripetizione della texture


def uv_box(ob, scala=SCALA_UV, offset=(0, 0, 0)):
    """UV a scatola in coordinate del mondo (con offset per evitare ripetizioni identiche)."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    uvl = bm.loops.layers.uv.verify()
    M = ob.matrix_basis; N = M.to_3x3().inverted().transposed()
    o = Vector(offset)
    for f in bm.faces:
        n = N @ f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = M @ l.vert.co + o
            if ax == 0:
                u, v = (p.y if n.x > 0 else -p.y), p.z
            elif ax == 1:
                u, v = (-p.x if n.y > 0 else p.x), p.z
            else:
                u, v = p.x, (p.y if n.z > 0 else -p.y)
            l[uvl].uv = (u / scala, v / scala)
    bm.to_mesh(me); bm.free()
    return ob


def liscio(ob, angolo=35):
    me = ob.data
    for pl in me.polygons:
        pl.use_smooth = True
    try:
        me.set_sharp_from_angle(angle=math.radians(angolo))
    except Exception:
        pass
    return ob


def applica_trasf(ob):
    me = ob.data
    me.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    return ob


# ---------------------------------------------------------------- primitive (bmesh, senza bpy.ops)

def _ob_da_bm(nome, bm, mat=None):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome, me)
    _link(ob)
    if mat:
        assegna(ob, mat)
    return ob


def box(nome, centro, dim, mat=None, uv=SCALA_UV, rot=(0, 0, 0), matrice=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(dim), verts=bm.verts)
    ob = _ob_da_bm(nome, bm, mat)
    if matrice is not None:
        ob.matrix_basis = matrice
    else:
        ob.location = centro; ob.rotation_euler = rot
    if uv:
        uv_box(ob, uv)
    return ob


def orienta(asse):
    """Matrice che porta l'asse Z sull'asse dato."""
    a = Vector(asse).normalized()
    return a.to_track_quat('Z', 'Y').to_matrix().to_4x4()


def cilindro(nome, centro, r, h, mat=None, asse=(0, 0, 1), seg=24, uv=SCALA_UV, tappi=True, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=tappi, cap_tris=False, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    bmesh.ops.transform(bm, matrix=orienta(asse), verts=bm.verts)
    ob = _ob_da_bm(nome, bm, mat)
    ob.location = centro
    if uv:
        uv_box(ob, uv)
    return liscio(ob)


def toro(nome, centro, R, r, mat=None, asse=(0, 0, 1), seg=32, seg2=12, uv=SCALA_UV):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        row = []
        for j in range(seg2):
            b = 2 * math.pi * j / seg2
            p = Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
            row.append(bm.verts.new(p))
        verts.append(row)
    for i in range(seg):
        for j in range(seg2):
            bm.faces.new((verts[i][j], verts[(i + 1) % seg][j], verts[(i + 1) % seg][(j + 1) % seg2], verts[i][(j + 1) % seg2]))
    bmesh.ops.transform(bm, matrix=orienta(asse), verts=bm.verts)
    ob = _ob_da_bm(nome, bm, mat)
    ob.location = centro
    if uv:
        uv_box(ob, uv)
    return liscio(ob, 60)


def sfera(nome, centro, r, mat=None, scala=(1, 1, 1), seg=24, uv=SCALA_UV, emisfero=False):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    if emisfero:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context='VERTS')
    bmesh.ops.scale(bm, vec=Vector(scala), verts=bm.verts)
    ob = _ob_da_bm(nome, bm, mat)
    ob.location = centro
    if uv:
        uv_box(ob, uv)
    return liscio(ob, 60)


def quad(nome, centro, w, h, normale=(0, -1, 0), mat=None, su=(0, 0, 1)):
    """Rettangolo con UV 0..1 (per pannelli dipinti, quadranti, schermi)."""
    n = Vector(normale).normalized(); up = Vector(su)
    dx = up.cross(n).normalized() if abs(n.dot(up)) < 0.99 else Vector((1, 0, 0))
    dy = n.cross(dx).normalized()
    c = Vector(centro)
    bm = bmesh.new()
    vs = [bm.verts.new(c + dx * (sx * w / 2) + dy * (sy * h / 2)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(vs)
    uvl = bm.loops.layers.uv.verify()
    for l, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        l[uvl].uv = uv
    return _ob_da_bm(nome, bm, mat)


def disco(nome, centro, r, normale=(0, -1, 0), mat=None, seg=32):
    """Disco con UV 0..1 (quadranti dei manometri)."""
    n = Vector(normale).normalized()
    M = orienta(n).to_3x3()
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(centro) + M @ Vector((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), 0))) for i in range(seg)]
    f = bm.faces.new(vs)
    uvl = bm.loops.layers.uv.verify()
    for i, l in enumerate(f.loops):
        a = 2 * math.pi * i / seg
        l[uvl].uv = (0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a))
    return _ob_da_bm(nome, bm, mat)


def empty(nome, loc, tipo='PLAIN_AXES', dim=0.3, rot=(0, 0, 0)):
    e = bpy.data.objects.new(nome, None)
    e.empty_display_type = tipo; e.empty_display_size = dim
    e.location = loc; e.rotation_euler = rot
    return _link(e)


# ---------------------------------------------------------------- tubi

def _arrotonda(punti, rc, passi=6):
    """Polilinea con gli spigoli raccordati da archi di raggio rc."""
    P = [Vector(p) for p in punti]
    out = [P[0]]
    for i in range(1, len(P) - 1):
        a, b, c = P[i - 1], P[i], P[i + 1]
        d1 = (b - a).normalized(); d2 = (c - b).normalized()
        ang = d1.angle(d2) if d1.length and d2.length else 0
        if ang < 1e-3:
            out.append(b); continue
        t = min(rc * math.tan(ang / 2), (b - a).length * 0.49, (c - b).length * 0.49)
        p1 = b - d1 * t; p2 = b + d2 * t
        for k in range(passi + 1):
            s = k / passi  # bezier quadratica: vicina a un arco
            out.append(p1 * (1 - s) ** 2 + b * 2 * s * (1 - s) + p2 * s * s)
    out.append(P[-1])
    return out


def tubo(nome, punti, r, mat=None, rc=None, seg=16, uv=SCALA_UV, tappi=False):
    """Tubo lungo una polilinea, con curve raccordate (raggio di curvatura rc, default 2r)."""
    pts = _arrotonda(punti, rc if rc is not None else 2 * r)
    bm = bmesh.new()
    anelli = []
    prev_n = None
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - p).normalized()
        elif i == len(pts) - 1:
            t = (p - pts[i - 1]).normalized()
        else:
            t = ((pts[i + 1] - p).normalized() + (p - pts[i - 1]).normalized()).normalized()
        if prev_n is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = t.cross(ref).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            off = n * math.cos(a) + b * math.sin(a)
            ring.append(bm.verts.new(p + off * r))
        anelli.append(ring)
    for i in range(len(anelli) - 1):
        A, B = anelli[i], anelli[i + 1]
        for j in range(seg):
            bm.faces.new((A[j], A[(j + 1) % seg], B[(j + 1) % seg], B[j]))
    if tappi:
        bm.faces.new(list(reversed(anelli[0]))); bm.faces.new(anelli[-1])
    ob = _ob_da_bm(nome, bm, mat)
    if uv:
        uv_box(ob, uv)
    return liscio(ob, 50)


def flangia(nome, centro, asse, r, mat=None, spessore=0.05, bulloni=8, mat_bulloni=None):
    """Flangia con corona di bulloni (restituisce lista di oggetti)."""
    obs = [cilindro(nome, centro, r, spessore, mat, asse=asse, seg=24)]
    if bulloni:
        a = Vector(asse).normalized()
        M = orienta(a).to_3x3()
        for k in range(bulloni):
            ang = 2 * math.pi * k / bulloni
            p = Vector(centro) + M @ Vector((math.cos(ang) * r * 0.82, math.sin(ang) * r * 0.82, 0))
            obs.append(cilindro(f'{nome}_b{k}', p, r * 0.07, spessore + 0.04, mat_bulloni or mat, asse=asse, seg=6))
    return obs


def unisci(nome, obs):
    obs = [o for o in obs if o is not None and o.type == 'MESH']
    if not obs:
        return None
    if len(obs) == 1:
        obs[0].name = nome
        return obs[0]
    ctx = {'active_object': obs[0], 'selected_editable_objects': obs, 'selected_objects': obs}
    with bpy.context.temp_override(**ctx):
        bpy.ops.object.join()
    obs[0].name = nome
    obs[0].data.name = nome
    return obs[0]


def imposta_origine(ob, punto):
    """Sposta l'origine dell'oggetto su `punto` (coordinate mondo) senza muovere la geometria."""
    applica_trasf(ob)
    p = Vector(punto)
    ob.data.transform(Matrix.Translation(-p))
    ob.location = p
    return ob


# ---------------------------------------------------------------- luci, volumi, camera, render

def luce(nome, tipo, loc, energia, colore=(1, 1, 1), size=0.1, rot=None, mira=None, spot=None, raggio=None):
    l = bpy.data.lights.new(nome, tipo)
    l.energy = energia; l.color = colore
    if tipo == 'AREA':
        l.size = size
    elif raggio is not None or tipo in ('POINT', 'SPOT'):
        l.shadow_soft_size = raggio if raggio is not None else size
    if tipo == 'SPOT' and spot:
        l.spot_size = math.radians(spot); l.spot_blend = 0.5
    ob = bpy.data.objects.new(nome, l)
    _link(ob)
    ob.location = loc
    if mira is not None:
        ob.rotation_euler = (Vector(mira) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    elif rot is not None:
        ob.rotation_euler = rot
    return ob


def volume(nome, centro, dim, densita, colore=(0.8, 0.85, 0.9), anisotropia=0.3, rumore=None, forma='box'):
    """Volume di nebbia/vapore (solo per i render in Blender: in Godot c'e' la nebbia volumetrica)."""
    m = bpy.data.materials.new(nome + '_mat')
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
    pv = nt.nodes.new('ShaderNodeVolumePrincipled')
    pv.inputs['Color'].default_value = (*colore, 1)
    pv.inputs['Anisotropy'].default_value = anisotropia
    pv.inputs['Density'].default_value = densita
    if rumore:
        # densita' a sbuffi: noise * gradiente sferico
        tc = nt.nodes.new('ShaderNodeTexCoord')
        no = nt.nodes.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = rumore
        no.inputs['Detail'].default_value = 6
        nt.links.new(tc.outputs['Object'], no.inputs['Vector'])
        grad = nt.nodes.new('ShaderNodeTexGradient'); grad.gradient_type = 'SPHERICAL'
        nt.links.new(tc.outputs['Object'], grad.inputs['Vector'])
        cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].position = 0.45
        cr.color_ramp.elements[1].position = 0.75
        nt.links.new(no.outputs['Fac'], cr.inputs['Fac'])
        m1 = nt.nodes.new('ShaderNodeMath'); m1.operation = 'MULTIPLY'
        nt.links.new(cr.outputs['Color'], m1.inputs[0]); nt.links.new(grad.outputs['Fac'], m1.inputs[1])
        m2 = nt.nodes.new('ShaderNodeMath'); m2.operation = 'MULTIPLY'; m2.inputs[1].default_value = densita
        nt.links.new(m1.outputs[0], m2.inputs[0])
        nt.links.new(m2.outputs[0], pv.inputs['Density'])
    nt.links.new(pv.outputs['Volume'], out.inputs['Volume'])
    if forma == 'sfera':
        ob = sfera(nome, centro, 1.0, m, scala=dim, uv=None)
    else:
        ob = box(nome, centro, dim, m, uv=None)
    ob['solo_render'] = True
    return ob


def camera(loc, mira, lente=22, nome='Camera'):
    """Camera all'altezza degli occhi del giocatore. lente 22 mm su 36 mm = circa 78 gradi orizzontali."""
    cd = bpy.data.cameras.new(nome); cd.lens = lente; cd.clip_start = 0.05; cd.clip_end = 200
    cam = bpy.data.objects.new(nome, cd)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (Vector(mira) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    cam['solo_render'] = True
    return cam


def mondo(colore=(0.004, 0.005, 0.006), forza=1.0):
    s = bpy.context.scene
    w = bpy.data.worlds.new('Mondo'); s.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (*colore, 1); bg.inputs['Strength'].default_value = forza


def imposta_render(campioni=128, w=1600, h=900, esposizione=0.0, look='AgX - Medium High Contrast'):
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = campioni
    s.cycles.use_adaptive_sampling = True
    s.cycles.adaptive_threshold = 0.02
    s.cycles.use_denoising = True
    try:
        s.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    s.cycles.max_bounces = 6; s.cycles.diffuse_bounces = 3; s.cycles.glossy_bounces = 3
    s.cycles.transmission_bounces = 4; s.cycles.volume_bounces = 1; s.cycles.transparent_max_bounces = 8
    s.cycles.volume_step_rate = 4.0
    s.cycles.sample_clamp_indirect = 8.0
    s.render.resolution_x = w; s.render.resolution_y = h; s.render.resolution_percentage = 100
    s.render.threads_mode = 'FIXED'; s.render.threads = 4
    s.view_settings.view_transform = 'AgX'
    try:
        s.view_settings.look = look
    except Exception:
        pass
    s.view_settings.exposure = esposizione
    s.render.image_settings.file_format = 'JPEG'
    s.render.image_settings.quality = 92


def renderizza(nome_file):
    os.makedirs(RENDER, exist_ok=True)
    s = bpy.context.scene
    s.render.filepath = os.path.join(RENDER, nome_file)
    bpy.ops.render.render(write_still=True)
    print('render ->', s.render.filepath, flush=True)


# ---------------------------------------------------------------- export

# Con AMBIENTI2_GLTF=1 l'export scrive .gltf + .bin in assets_src/ambienti_tecnici/gltf_2k/ con le texture
# 2K condivise in gltf_2k/texture/ (una sola copia per tutte le stanze). Senza, scrive i GLB autonomi in glb/.
GLTF_2K = os.environ.get('AMBIENTI2_GLTF') == '1'


def esporta_glb(path, obs=None, luci=True, max_tex=1024):
    """Esporta in GLB gli oggetti (default: tutti tranne volumi e camera)."""
    if GLTF_2K and os.sep + 'ambienti_tecnici' + os.sep in path:
        return _esporta_gltf(os.path.join(SRC, 'gltf_2k', os.path.basename(path).replace('.glb', '.gltf')), obs, luci)
    if obs is None:
        obs = [o for o in bpy.context.scene.objects if not o.get('solo_render')]
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # nei GLB autonomi le texture vanno a 1K (a 2K supererebbero i 50 MB): le riduco solo per l'export
    ridotte = [im for im in bpy.data.images if max_tex and im.size[0] > max_tex and im.filepath]
    for im in ridotte:
        im.scale(max_tex, max_tex)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_lights=luci, export_cameras=False,
                              export_extras=True, export_yup=True, export_image_format='JPEG', export_jpeg_quality=88)
    for im in ridotte:
        im.reload()
    mb = os.path.getsize(path) / 1e6
    print(f'GLB {path}: {mb:.1f} MB', flush=True)
    assert mb < 50, 'GLB oltre i 50 MB'
    return path


def argomenti():
    return sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]


# ---------------------------------------------------------------- collisioni (convenzione dell'importer di Godot)

def _segna_collisione(ob):
    ob['collisione'] = True
    ob.hide_render = True
    ob.display_type = 'WIRE'
    return ob


def collisione_box(nome, lo, hi, padre=None):
    """Scatola di collisione convessa (suffisso -convcolonly) tra gli angoli lo e hi (coordinate mondo)."""
    lo, hi = Vector(lo), Vector(hi)
    ob = box(f'{nome}-convcolonly', (lo + hi) / 2, hi - lo, None, uv=None)
    if padre is not None:
        applica_trasf(ob)
        ob.parent = padre
        ob.matrix_parent_inverse = padre.matrix_basis.inverted()
    return _segna_collisione(ob)


def collisione_da_bbox(ob, nome=None, margine=0.0, padre=None):
    """Collisione convessa = scatola che contiene l'oggetto (allineata agli assi del mondo)."""
    vs = [ob.matrix_basis @ v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))) - Vector((margine,) * 3)
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))) + Vector((margine,) * 3)
    return collisione_box(nome or ob.name + '_col', lo, hi, padre)


def collisione_copia(ob, convessa=True, nome=None):
    """Copia della mesh (gia' semplice) come collisione: -convcolonly o -colonly (trimesh)."""
    me = ob.data.copy(); me.materials.clear()
    c = bpy.data.objects.new(f'{nome or ob.name + "_col"}-{"convcolonly" if convessa else "colonly"}', me)
    c.matrix_basis = ob.matrix_basis.copy()
    _link(c)
    return _segna_collisione(c)


def _esporta_gltf(path, obs, luci):
    if obs is None:
        obs = [o for o in bpy.context.scene.objects if not o.get('solo_render')]
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', export_texture_dir='texture', use_selection=True,
                              export_apply=True, export_lights=luci, export_cameras=False, export_extras=True,
                              export_yup=True, export_image_format='JPEG', export_jpeg_quality=90)
    bin_ = path.replace('.gltf', '.bin')
    for f in (path, bin_):
        mb = os.path.getsize(f) / 1e6
        print(f'GLTF {f}: {mb:.1f} MB', flush=True)
        assert mb < 50
    return path
