"""Funzioni comuni della pipeline della medusa (Blender 5.2 usato come modulo bpy).

Gli script tools/blender/medusa_*.py si lanciano cosi':
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_<passo>.py

Convenzioni del modello (dopo l'import glTF): asse Z in alto, la medusa guarda verso -Y,
alta circa 1.9 unita' (metri). +X e' la sinistra della medusa (la destra per chi la guarda).
"""
import json
import math
import os
import sys

import numpy as np
import bpy
import bmesh
from mathutils import Matrix, Vector

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
ASSET = os.path.join(REPO, 'assets_src', 'medusa')
TEX = os.path.join(ASSET, 'tex')
BUILD = os.path.join(ASSET, 'build')          # file intermedi rigenerabili (ignorati da git)
EXPORT = os.path.join(ASSET, 'export')
PROPOSTE = os.path.join(REPO, 'docs', 'proposte', 'medusa')
BASE_GLB = os.path.join(ASSET, 'meshy_base.glb')
DATI = os.path.join(ASSET, 'dati')             # json con misure ricavate (occhio, attacchi, ...)

FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

for _d in (TEX, BUILD, EXPORT, DATI):
    os.makedirs(_d, exist_ok=True)
_gi = os.path.join(BUILD, '.gitignore')
if not os.path.exists(_gi):
    with open(_gi, 'w') as f:
        f.write('# file rigenerati dagli script tools/blender/medusa_*.py\n*\n!.gitignore\n')


def log(*a):
    print('[medusa]', *a, flush=True)


# ---------------------------------------------------------------- scena e file

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def apri(path):
    bpy.ops.wm.open_mainfile(filepath=path)


def salva(path):
    """Salva il .blend compresso, con le texture come file esterni (percorsi relativi)."""
    for img in bpy.data.images:
        if img.packed_file and img.filepath:
            pass
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True, relative_remap=True)
    log('salvato', os.path.relpath(path, REPO), f'{os.path.getsize(path) / 1e6:.1f} MB')


def leggi_json(nome):
    with open(os.path.join(DATI, nome)) as f:
        return json.load(f)


def scrivi_json(nome, dati):
    with open(os.path.join(DATI, nome), 'w') as f:
        json.dump(dati, f, indent=1, ensure_ascii=False)
    log('scritto', os.path.relpath(os.path.join(DATI, nome), REPO))


def oggetto(nome):
    return bpy.data.objects.get(nome)


def collega(ob, coll=None):
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob


def attiva(ob, solo=True):
    if solo:
        for o in bpy.context.view_layer.objects:
            if o:
                o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


# ---------------------------------------------------------------- mesh <-> numpy

def coords(me):
    a = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get('co', a)
    return a.reshape(-1, 3)


def set_coords(me, a):
    me.vertices.foreach_set('co', np.asarray(a, dtype=np.float64).ravel())
    me.update()


def facce(me):
    """Indici dei vertici per faccia (lista di array) + centri + normali."""
    n = len(me.polygons)
    cen = np.empty(n * 3); me.polygons.foreach_get('center', cen)
    nor = np.empty(n * 3); me.polygons.foreach_get('normal', nor)
    return cen.reshape(-1, 3), nor.reshape(-1, 3)


def loop_uv(me, layer=None):
    uvl = me.uv_layers[layer] if layer else me.uv_layers.active
    a = np.empty(len(me.loops) * 2)
    uvl.data.foreach_get('uv', a)
    return a.reshape(-1, 2)


def loop_vert(me):
    a = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get('vertex_index', a)
    return a


def poly_loops(me):
    st = np.empty(len(me.polygons), dtype=np.int64); me.polygons.foreach_get('loop_start', st)
    tot = np.empty(len(me.polygons), dtype=np.int64); me.polygons.foreach_get('loop_total', tot)
    return st, tot


def adiacenza_facce(me):
    """Coppie di facce che condividono un lato (array Nx2)."""
    bm = bmesh.new(); bm.from_mesh(me)
    coppie = []
    for e in bm.edges:
        lf = e.link_faces
        if len(lf) == 2:
            coppie.append((lf[0].index, lf[1].index))
    bm.free()
    return np.array(coppie, dtype=np.int64)


def adiacenza_vertici(me):
    ev = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get('vertices', ev)
    return ev.reshape(-1, 2)


# ---------------------------------------------------------------- texture

def carica_immagine_np(path):
    """Immagine -> array float32 HxWxC (riga 0 = in alto, come in PIL)."""
    from PIL import Image
    im = Image.open(path)
    return np.asarray(im).astype(np.float32) / 255.0


def campiona_uv(img, uv):
    """Campiona (bilineare) un'immagine HxWxC alle coordinate uv (Nx2, origine in basso a sinistra)."""
    h, w = img.shape[:2]
    x = np.clip(uv[:, 0] % 1.0 * w - 0.5, 0, w - 1.001)
    y = np.clip((1.0 - uv[:, 1] % 1.0) * h - 0.5, 0, h - 1.001)
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    a = img[y0, x0]; b = img[y0, x0 + 1]; c = img[y0 + 1, x0]; d = img[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def rasterizza_uv(me, mask_facce, size, layer=None, dilata=0):
    """Maschera (size x size, uint8) dei triangoli UV delle facce selezionate. Riga 0 = v alto."""
    import cv2
    uv = loop_uv(me, layer)
    st, tot = poly_loops(me)
    m = np.zeros((size, size), np.uint8)
    for fi in np.nonzero(mask_facce)[0]:
        p = uv[st[fi]:st[fi] + tot[fi]]
        pts = np.stack([p[:, 0] * size, (1 - p[:, 1]) * size], 1)
        cv2.fillPoly(m, [np.round(pts * 4).astype(np.int32)], 255, lineType=cv2.LINE_8, shift=2)
    if dilata:
        m = cv2.dilate(m, np.ones((2 * dilata + 1, 2 * dilata + 1), np.uint8))
    return m


# ---------------------------------------------------------------- materiali

def nodo(nt, tipo, loc=(0, 0), **kw):
    n = nt.nodes.new(tipo)
    n.location = loc
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def immagine(path, non_color=False):
    nome = os.path.basename(path)
    img = bpy.data.images.get(nome)
    if img is None or os.path.abspath(bpy.path.abspath(img.filepath)) != os.path.abspath(path):
        img = bpy.data.images.load(path, check_existing=True)
    if non_color:
        img.colorspace_settings.name = 'Non-Color'
    return img


def materiale_pbr(nome, base=None, mr=None, normal=None, colore=(0.8, 0.8, 0.8, 1), roughness=0.5,
                  metallic=0.0, normal_strength=1.0, uv=None):
    """Materiale Principled leggibile dall'export glTF (base color, metallic/roughness, normal)."""
    mat = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nodo(nt, 'ShaderNodeOutputMaterial', (600, 0))
    bsdf = nodo(nt, 'ShaderNodeBsdfPrincipled', (300, 0))
    bsdf.name = 'BSDF'
    nt.links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    bsdf.inputs['Base Color'].default_value = colore
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    uvn = None
    if uv:
        uvn = nodo(nt, 'ShaderNodeUVMap', (-900, 0)); uvn.uv_map = uv
    if base:
        t = nodo(nt, 'ShaderNodeTexImage', (-400, 300)); t.image = immagine(base); t.name = 'base'
        nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
        if uvn: nt.links.new(uvn.outputs['UV'], t.inputs['Vector'])
    if mr:
        t = nodo(nt, 'ShaderNodeTexImage', (-600, 0)); t.image = immagine(mr, True); t.name = 'mr'
        sep = nodo(nt, 'ShaderNodeSeparateColor', (-250, 0))
        nt.links.new(t.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
        nt.links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
        if uvn: nt.links.new(uvn.outputs['UV'], t.inputs['Vector'])
    if normal:
        t = nodo(nt, 'ShaderNodeTexImage', (-600, -300)); t.image = immagine(normal, True); t.name = 'normal'
        nm = nodo(nt, 'ShaderNodeNormalMap', (-250, -300))
        nm.inputs['Strength'].default_value = normal_strength
        nt.links.new(t.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
        if uvn: nt.links.new(uvn.outputs['UV'], t.inputs['Vector'])
    return mat


# ---------------------------------------------------------------- render

def imposta_render(samples=32, res=(960, 960), denoise=True, trasparente=False, vista='AgX', look='None',
                   esposizione=0.0, bounces=None):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.use_denoising = denoise
    try:
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    if bounces:
        sc.cycles.max_bounces = bounces
    sc.cycles.transmission_bounces = 8
    sc.cycles.transparent_max_bounces = 16
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = trasparente
    sc.view_settings.view_transform = vista
    try:
        sc.view_settings.look = look
    except Exception:
        pass
    sc.view_settings.exposure = esposizione
    sc.render.image_settings.file_format = 'PNG'
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = 4
    return sc


def mondo(colore=(0.035, 0.035, 0.045), forza=1.0):
    sc = bpy.context.scene
    w = bpy.data.worlds.new('Mondo')
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = (*colore, 1)
    bg.inputs['Strength'].default_value = forza
    return w


def guarda(ob, target, up='Y'):
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat('-Z', up).to_euler()


def camera(loc, target, lens=50.0, ortho=None, nome='Camera'):
    cd = bpy.data.cameras.new(nome)
    cd.lens = lens
    cd.clip_start = 0.01
    cd.clip_end = 200
    if ortho:
        cd.type = 'ORTHO'
        cd.ortho_scale = ortho
    cam = bpy.data.objects.new(nome, cd)
    collega(cam)
    cam.location = Vector(loc)
    guarda(cam, target)
    bpy.context.scene.camera = cam
    return cam


def luce_area(nome, loc, target, energia, colore=(1, 1, 1), size=1.0, forma='SQUARE'):
    ld = bpy.data.lights.new(nome, 'AREA')
    ld.energy = energia
    ld.color = colore
    ld.size = size
    ld.shape = forma
    ob = bpy.data.objects.new(nome, ld)
    collega(ob)
    ob.location = Vector(loc)
    guarda(ob, target)
    return ob


def luce_punto(nome, loc, energia, colore=(1, 1, 1), raggio=0.1):
    ld = bpy.data.lights.new(nome, 'POINT')
    ld.energy = energia
    ld.color = colore
    ld.shadow_soft_size = raggio
    ob = bpy.data.objects.new(nome, ld)
    collega(ob)
    ob.location = Vector(loc)
    return ob


def luce_spot(nome, loc, target, energia, colore=(1, 1, 1), angolo=45, raggio=0.1, blend=0.5):
    ld = bpy.data.lights.new(nome, 'SPOT')
    ld.energy = energia
    ld.color = colore
    ld.spot_size = math.radians(angolo)
    ld.spot_blend = blend
    ld.shadow_soft_size = raggio
    ob = bpy.data.objects.new(nome, ld)
    collega(ob)
    ob.location = Vector(loc)
    guarda(ob, target)
    return ob


def luci_studio(centro=(0, 0, 0), H=1.9, forza=1.0):
    """Tre luci area morbide (chiave, riempimento, controluce), come render_glb.py."""
    c = Vector(centro)
    k = forza
    luce_area('studio_chiave', c + Vector((-1.2, -1.6, 0.9)) * H, c, 110 * H * H * k, size=1.5 * H)
    luce_area('studio_riempimento', c + Vector((1.4, -1.2, 0.2)) * H, c, 35 * H * H * k, (0.8, 0.85, 1.0), 1.5 * H)
    luce_area('studio_controluce', c + Vector((0.6, 1.6, 1.2)) * H, c, 120 * H * H * k, (1.0, 0.75, 0.9), 1.5 * H)


def luci_acquapark(centro=(0, 0, 0), H=1.9, nebbia=0.06, forza=1.0, pavimento=True):
    """Acquapark di notte: luce d'emergenza rossa, riflesso azzurro della piscina, nebbia leggera."""
    c = Vector(centro)
    k = forza
    # luce d'emergenza rossa in alto a destra (dietro-lato), dura
    luce_spot('rossa_emergenza', c + Vector((1.5, 0.9, 1.6)) * H, c + Vector((0, 0, 0.1 * H)), 2600 * k,
              (1.0, 0.06, 0.03), angolo=55, raggio=0.08, blend=0.4)
    # rossa di riempimento da sinistra davanti, debole
    luce_area('rossa_riempimento', c + Vector((-1.6, -0.8, 0.6)) * H, c, 60 * H * H * k, (1.0, 0.1, 0.06), 0.8 * H)
    # azzurro dal basso: riflesso della piscina
    luce_area('azzurra_piscina', c + Vector((0.2, -1.3, -1.0)) * H, c + Vector((0, 0, 0.2 * H)), 90 * H * H * k,
              (0.15, 0.55, 1.0), 1.4 * H)
    # controluce azzurro freddo
    luce_area('azzurra_controluce', c + Vector((-0.8, 1.6, 1.0)) * H, c, 70 * H * H * k, (0.35, 0.7, 1.0), 0.8 * H)
    if pavimento:
        bpy.ops.mesh.primitive_plane_add(size=40, location=(c.x, c.y, c.z - 0.62 * H))
        pav = bpy.context.active_object
        pav.name = 'pavimento_bagnato'
        m = bpy.data.materials.new('pavimento_bagnato')
        m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (0.02, 0.03, 0.04, 1)
        b.inputs['Roughness'].default_value = 0.08
        pav.data.materials.append(m)
    if nebbia > 0:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(c.x, c.y, c.z))
        vol = bpy.context.active_object
        vol.name = 'nebbia'
        vol.scale = (12, 12, 6)
        m = bpy.data.materials.new('nebbia')
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        o = nt.nodes.new('ShaderNodeOutputMaterial')
        v = nt.nodes.new('ShaderNodeVolumePrincipled')
        v.inputs['Density'].default_value = nebbia
        v.inputs['Color'].default_value = (0.7, 0.75, 0.85, 1)
        nt.links.new(v.outputs['Volume'], o.inputs['Volume'])
        vol.data.materials.append(m)
        vol.visible_shadow = False


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    log('render', os.path.relpath(path, REPO) if path.startswith(REPO) else path)
    return path


# ---------------------------------------------------------------- tavole delle proposte (JPG)

def tavola(celle, path, titolo=None, colonne=None, etichetta_h=None, sottotitolo=None, larghezza=None,
           qualita=90, sfondo=(18, 18, 22)):
    """Compone immagini in una griglia con etichette grandi, leggibili sul telefono.

    celle: lista di (percorso_png_o_PIL, testo_etichetta) oppure None per lasciare vuoto.
    """
    from PIL import Image, ImageDraw, ImageFont
    ims = []
    for c in celle:
        if c is None:
            ims.append((None, ''))
            continue
        p, t = c
        im = p if hasattr(p, 'size') else Image.open(p)
        ims.append((im.convert('RGB'), t))
    colonne = colonne or len(ims)
    righe = (len(ims) + colonne - 1) // colonne
    w0, h0 = next(im.size for im, _ in ims if im is not None)
    eh = etichetta_h or max(56, int(w0 * 0.085))
    gap = max(6, w0 // 80)
    th = 0
    if titolo:
        th = int(eh * 1.25)
    if sottotitolo:
        th += int(eh * 0.7)
    W = colonne * w0 + (colonne + 1) * gap
    H = th + righe * (h0 + eh) + (righe + 1) * gap
    out = Image.new('RGB', (W, H), sfondo)
    d = ImageDraw.Draw(out)
    fb = ImageFont.truetype(FONT_BOLD, int(eh * 0.58))
    fs = ImageFont.truetype(FONT, int(eh * 0.42))
    y = gap
    if titolo:
        ft = ImageFont.truetype(FONT_BOLD, int(eh * 0.7))
        d.text((W // 2, y + int(eh * 0.55)), titolo, fill=(255, 255, 255), font=ft, anchor='mm')
        y += int(eh * 1.25)
    if sottotitolo:
        d.text((W // 2, y + int(eh * 0.3)), sottotitolo, fill=(200, 200, 210), font=fs, anchor='mm')
        y += int(eh * 0.7)
    # stessa dimensione del testo in tutte le etichette: la piu' grande che ci sta in ogni cella
    size = int(eh * 0.58)
    font_celle = fb
    while size > 14 and max(d.textlength(t, font=font_celle) for _, t in ims) > w0 - 16:
        size -= 2
        font_celle = ImageFont.truetype(FONT_BOLD, size)
    for i, (im, t) in enumerate(ims):
        r, cidx = divmod(i, colonne)
        x0 = gap + cidx * (w0 + gap)
        y0 = y + r * (h0 + eh + gap)
        if im is None:
            continue
        if im.size != (w0, h0):
            im = im.resize((w0, h0), Image.LANCZOS)
        out.paste(im, (x0, y0 + eh))
        d.rectangle((x0, y0, x0 + w0, y0 + eh - 2), fill=(250, 250, 250))
        d.text((x0 + w0 // 2, y0 + eh // 2), t, fill=(15, 15, 20), font=font_celle, anchor='mm')
    if larghezza and out.size[0] > larghezza:
        out = out.resize((larghezza, int(out.size[1] * larghezza / out.size[0])), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, quality=qualita)
    log('tavola', os.path.relpath(path, REPO), out.size)
    return path
