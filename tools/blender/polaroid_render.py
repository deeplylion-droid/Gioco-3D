"""Polaroid del capitolo 1: render di come appaiono in gioco (Cycles).

Uso (dalla radice del repository):
    PY=/home/user/tools/blender-venv/bin/python
    nice -n 10 $PY tools/blender/polaroid_render.py scena      # 3 Polaroid sulla panca bagnata
    nice -n 10 $PY tools/blender/polaroid_render.py raccolta   # primo piano: il giocatore ne raccoglie una
    aggiungere --prova per un'anteprima piccola e veloce

Le Polaroid sono importate da assets_src/polaroid/polaroid.glb, cioè l'asset vero del gioco:
ogni copia prende uno dei 10 materiali (varianti P01-P10) sulla superficie della foto.
L'ambiente è uno spogliatoio dell'acquapark al buio: piastrelle bagnate, panca di assi bagnata con
gocce d'acqua, armadietti di metallo arrugginito, luce rossa d'emergenza e un neon freddo.
Le texture CC0 (ambientCG) si scaricano da sole nella cache $POLAROID_CACHE (default: cartella
temporanea di sistema), fuori dal repository.
Uscita: docs/proposte/polaroid/render_in_gioco.jpg e render_raccolta.jpg (1600 x 900).
"""
import math, os, random, sys, tempfile, urllib.request, zipfile
import bpy
from mathutils import Vector, Euler

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
GLB = os.path.join(RADICE, 'assets_src', 'polaroid', 'polaroid.glb')
OUT = os.path.join(RADICE, 'docs', 'proposte', 'polaroid')
CACHE = os.environ.get('POLAROID_CACHE') or os.path.join(tempfile.gettempdir(), 'polaroid_cache')
PROVA = '--prova' in sys.argv


# ------------------------------------------------------------------ texture CC0
def scarica(asset):
    """Scarica (una volta) il set 2K-JPG di ambientCG e ritorna la cartella con le mappe."""
    cart = os.path.join(CACHE, asset)
    if not os.path.isdir(cart):
        os.makedirs(CACHE, exist_ok=True)
        z = os.path.join(CACHE, asset + '.zip')
        req = urllib.request.Request(f'https://ambientcg.com/get?file={asset}_2K-JPG.zip',
                                     headers={'User-Agent': 'gioco-3d-polaroid/1.0'})
        with urllib.request.urlopen(req, timeout=300) as r, open(z, 'wb') as f:
            f.write(r.read())
        zipfile.ZipFile(z).extractall(cart)
    return cart


def mappa(asset, tipo):
    cart = scarica(asset)
    for f in os.listdir(cart):
        if f.endswith(f'_{tipo}.jpg'):
            return os.path.join(cart, f)
    return None


def nodo(nt, tipo, x, y, **kw):
    n = nt.nodes.new(tipo)
    n.location = (x, y)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def materiale_pbr(nome, asset, lato, tinta=(1, 1, 1), bagnato=0.0, pozze=0.0, scala_pozze=1.0,
                  rug_mul=1.0, box=False, seme=0.0):
    """Materiale PBR da un set ambientCG, ripetuto ogni 'lato' metri (coordinate oggetto).

    bagnato (0-1): quanto è bagnato dappertutto (più scuro, più lucido).
    pozze (0-1): pozzanghere sparse, lucide come specchi (rumore a scala 'scala_pozze' metri)."""
    m = bpy.data.materials.new(nome)
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tc = nodo(nt, 'ShaderNodeTexCoord', -1500, 0)
    mp = nodo(nt, 'ShaderNodeMapping', -1300, 0)
    mp.inputs['Scale'].default_value = (1 / lato, 1 / lato, 1 / lato)
    mp.inputs['Location'].default_value = (seme * 0.37, seme * 0.71, 0)
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])

    def img(tipo, colore):
        p = mappa(asset, tipo)
        if not p:
            return None
        t = nodo(nt, 'ShaderNodeTexImage', -1000, {'Color': 300, 'Roughness': 0, 'NormalGL': -300,
                                                   'AmbientOcclusion': 500}[tipo])
        t.image = bpy.data.images.load(p, check_existing=True)
        if not colore:
            t.image.colorspace_settings.name = 'Non-Color'
        if box:
            t.projection = 'BOX'
            t.projection_blend = 0.2
        nt.links.new(mp.outputs['Vector'], t.inputs['Vector'])
        return t

    col, rug, nor, ao = img('Color', True), img('Roughness', False), img('NormalGL', False), \
        img('AmbientOcclusion', False)
    # maschera dell'acqua: bagnato dappertutto + pozze (rumore)
    acqua = nodo(nt, 'ShaderNodeValue', -800, -600)
    acqua.outputs[0].default_value = bagnato
    if pozze > 0:
        nz = nodo(nt, 'ShaderNodeTexNoise', -1000, -700)
        nz.inputs['Scale'].default_value = 1 / scala_pozze
        nz.inputs['Detail'].default_value = 6
        nz.inputs['Roughness'].default_value = 0.6
        nt.links.new(tc.outputs['Object'], nz.inputs['Vector'])
        rmp = nodo(nt, 'ShaderNodeMapRange', -800, -700)
        rmp.inputs['From Min'].default_value = 0.62 - 0.2 * pozze
        rmp.inputs['From Max'].default_value = 0.66 - 0.2 * pozze
        nt.links.new(nz.outputs['Fac'], rmp.inputs['Value'])
        mx = nodo(nt, 'ShaderNodeMath', -600, -650, operation='MAXIMUM')
        nt.links.new(acqua.outputs[0], mx.inputs[0])
        nt.links.new(rmp.outputs['Result'], mx.inputs[1])
        acqua_out = mx.outputs[0]
    else:
        acqua_out = acqua.outputs[0]
    # colore: tinta, occlusione, più scuro dove è bagnato
    c = col.outputs['Color']
    tm = nodo(nt, 'ShaderNodeMix', -700, 300, data_type='RGBA', blend_type='MULTIPLY')
    tm.inputs['Factor'].default_value = 1.0
    nt.links.new(c, tm.inputs['A'])
    tm.inputs['B'].default_value = (*tinta, 1)
    c = tm.outputs['Result']
    if ao:
        am = nodo(nt, 'ShaderNodeMix', -500, 400, data_type='RGBA', blend_type='MULTIPLY')
        am.inputs['Factor'].default_value = 1.0
        nt.links.new(c, am.inputs['A'])
        nt.links.new(ao.outputs['Color'], am.inputs['B'])
        c = am.outputs['Result']
    scuro = nodo(nt, 'ShaderNodeMix', -300, 300, data_type='RGBA', blend_type='MULTIPLY')
    nt.links.new(acqua_out, scuro.inputs['Factor'])
    nt.links.new(c, scuro.inputs['A'])
    scuro.inputs['B'].default_value = (0.55, 0.55, 0.55, 1)
    nt.links.new(scuro.outputs['Result'], bsdf.inputs['Base Color'])
    # rugosità: quella della texture, poi quasi a zero dove c'è acqua
    r = rug.outputs['Color']
    rm = nodo(nt, 'ShaderNodeMath', -700, 0, operation='MULTIPLY')
    nt.links.new(r, rm.inputs[0])
    rm.inputs[1].default_value = rug_mul
    lr = nodo(nt, 'ShaderNodeMix', -300, 0, data_type='FLOAT')
    nt.links.new(acqua_out, lr.inputs['Factor'])
    nt.links.new(rm.outputs[0], lr.inputs['A'])
    lr.inputs['B'].default_value = 0.04
    nt.links.new(lr.outputs['Result'], bsdf.inputs['Roughness'])
    if nor:
        nm = nodo(nt, 'ShaderNodeNormalMap', -500, -300)
        nt.links.new(nor.outputs['Color'], nm.inputs['Color'])
        # dove c'è una pozza l'acqua spiana il rilievo
        inv = nodo(nt, 'ShaderNodeMath', -700, -400, operation='SUBTRACT')
        inv.inputs[0].default_value = 1.0
        nt.links.new(acqua_out, inv.inputs[1])
        nt.links.new(inv.outputs[0], nm.inputs['Strength'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    bsdf.inputs['Metallic'].default_value = 0.0
    return m


def materiale_semplice(nome, colore, rug=0.5, emissione=None, forza=0.0, trasmissione=0.0, ior=1.45):
    m = bpy.data.materials.new(nome)
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*colore, 1)
    b.inputs['Roughness'].default_value = rug
    if emissione:
        b.inputs['Emission Color'].default_value = (*emissione, 1)
        b.inputs['Emission Strength'].default_value = forza
    if trasmissione:
        b.inputs['Transmission Weight'].default_value = trasmissione
        b.inputs['IOR'].default_value = ior
    return m


# ------------------------------------------------------------------ geometria
def scatola(nome, centro, dim, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centro, rotation=rot)
    ob = bpy.context.object
    ob.name = nome
    ob.scale = dim
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    return ob


def piano(nome, centro, dim, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=centro, rotation=rot)
    ob = bpy.context.object
    ob.name = nome
    ob.scale = (dim[0], dim[1], 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    return ob


SEDUTA = 0.45           # altezza del piano della panca
MURO_SX = -1.2          # parete di sinistra, con la panca
MURO_DX = 1.2           # parete di destra, con gli armadietti
FONDO = 4.0             # parete di fondo, con la porta sul corridoio rosso
PANCA_Y = (-1.9, 0.5)   # la panca corre lungo la parete di sinistra
ASSI_X = (-1.115, -0.99, -0.865)


def ambiente():
    rnd = random.Random(5)
    rx90 = math.radians(90)
    pav = materiale_pbr('pavimento', 'Tiles133B', 1.5, tinta=(0.5, 0.53, 0.53), bagnato=0.3, pozze=0.85,
                        scala_pozze=0.8, rug_mul=1.1)
    piano('pavimento', (0, 1.5, 0), (2.4, 9), pav)
    par = materiale_pbr('parete_piastrelle', 'Tiles132B', 1.5, tinta=(0.28, 0.42, 0.44), bagnato=0.15,
                        pozze=0.5, scala_pozze=0.5)
    sop = materiale_pbr('parete_metallo', 'PaintedMetal010', 2.0, tinta=(0.33, 0.37, 0.38))
    soff = materiale_semplice('soffitto', (0.04, 0.04, 0.045), 0.8)
    # pareti lunghe: piastrelle fino a 1,2 m, sopra metallo verniciato
    for x, rz in ((MURO_SX, rx90), (MURO_DX, -rx90)):
        piano(f'piastrelle_{x}', (x, 0.75, 0.6), (6.5, 1.2), par, rot=(rx90, 0, rz))
        piano(f'metallo_{x}', (x, 0.75, 1.9), (6.5, 1.4), sop, rot=(rx90, 0, rz))
    piano('dietro', (0, -2.5, 1.3), (2.4, 2.6), sop, rot=(rx90, 0, math.radians(180)))
    piano('soffitto', (0, 0.75, 2.6), (2.4, 6.5), soff, rot=(math.radians(180), 0, 0))
    # parete di fondo con la porta (0,9 x 2,1 m) e il corridoio rosso dietro
    piano('fondo_sx', (-0.825, FONDO, 1.3), (0.75, 2.6), sop, rot=(rx90, 0, 0))
    piano('fondo_dx', (0.825, FONDO, 1.3), (0.75, 2.6), sop, rot=(rx90, 0, 0))
    piano('fondo_su', (0, FONDO, 2.35), (0.9, 0.5), sop, rot=(rx90, 0, 0))
    scuro = materiale_pbr('corridoio', 'PaintedMetal010', 1.5, tinta=(0.2, 0.2, 0.2))
    for x, rz in ((-0.7, rx90), (0.7, -rx90)):
        piano(f'corr_{x}', (x, FONDO + 1.5, 1.2), (3, 2.4), scuro, rot=(rx90, 0, rz))
    piano('corr_fine', (0, FONDO + 3, 1.2), (1.4, 2.4), scuro, rot=(rx90, 0, 0))
    piano('corr_soff', (0, FONDO + 1.5, 2.4), (1.4, 3), soff, rot=(math.radians(180), 0, 0))

    # armadietti di metallo arrugginito lungo la parete di destra, uno aperto
    arm = materiale_pbr('armadietti', 'PaintedMetal010', 1.2, tinta=(0.16, 0.24, 0.26), box=True, seme=2)
    fessura = materiale_semplice('fessura', (0.01, 0.01, 0.01), 0.9)
    for k in range(12):
        y = -2.2 + k * 0.42
        if k == 5:
            scatola('sportello', (0.62, y - 0.12, 0.95), (0.012, 0.4, 1.7), arm, rot=(0, 0, math.radians(35)))
            scatola(f'interno_{k}', (1.15, y, 0.95), (0.1, 0.4, 1.8), fessura)
            continue
        scatola(f'armadietto_{k}', (0.99, y, 0.95), (0.42, 0.4, 1.8), arm)
        scatola(f'fessura_{k}', (0.777, y - 0.205, 0.95), (0.01, 0.01, 1.8), fessura)
        for s in range(4):
            scatola(f'griglia_{k}_{s}', (0.777, y, 1.62 + s * 0.035), (0.005, 0.22, 0.012), fessura)

    # panca lungo la parete di sinistra: tre assi bagnate su telai di metallo
    legno = materiale_pbr('assi', 'Planks023A', 1.0, tinta=(0.8, 0.77, 0.72), bagnato=0.35, pozze=1.0,
                          scala_pozze=0.12, box=True, seme=1)
    ferro = materiale_pbr('telaio', 'PaintedMetal010', 0.6, tinta=(0.22, 0.24, 0.25), box=True, seme=3)
    y0, y1 = PANCA_Y
    for k, x in enumerate(ASSI_X):
        scatola(f'asse_{k}', (x, (y0 + y1) / 2, SEDUTA - 0.0125), (0.11, y1 - y0, 0.025), legno)
    for y in (y0 + 0.2, (y0 + y1) / 2, y1 - 0.2):
        for x in (-1.15, -0.83):
            scatola(f'gamba_{x}_{y}', (x, y, SEDUTA / 2), (0.04, 0.04, SEDUTA - 0.025), ferro)
        scatola(f'traverso_{y}', (-0.99, y, SEDUTA - 0.045), (0.36, 0.05, 0.04), ferro)
    # attaccapanni sopra la panca
    gancio = materiale_pbr('ganci', 'PaintedMetal010', 0.3, tinta=(0.25, 0.22, 0.2), box=True, seme=4)
    scatola('listello', (MURO_SX + 0.012, (y0 + y1) / 2, 1.55), (0.024, y1 - y0, 0.09), legno)
    for k in range(7):
        y = y0 + 0.2 + k * (y1 - y0 - 0.4) / 6
        scatola(f'gancio_{k}', (MURO_SX + 0.06, y, 1.53), (0.08, 0.012, 0.012), gancio,
                rot=(0, math.radians(-30), 0))
    # gocce d'acqua sulle assi
    acqua = materiale_semplice('acqua', (0.9, 0.95, 1.0), 0.02, trasmissione=1.0, ior=1.33)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1)
    goccia = bpy.context.object
    goccia.data.materials.append(acqua)
    for i in range(260):
        r = rnd.uniform(0.0015, 0.005)
        ob = bpy.data.objects.new(f'goccia_{i}', goccia.data)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = (rnd.choice(ASSI_X) + rnd.uniform(-0.05, 0.05), rnd.uniform(y0, y1), SEDUTA + r * 0.12)
        ob.scale = (r * rnd.uniform(0.9, 1.5), r * rnd.uniform(0.9, 1.5), r * 0.45)
    bpy.data.objects.remove(goccia)
    # pozza d'acqua sul pavimento davanti alla panca
    pozza = materiale_semplice('pozza', (0.015, 0.018, 0.02), 0.015)
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=0.35, fill_type='NGON', location=(-0.6, -1.25, 0.0008))
    p = bpy.context.object
    p.name = 'pozza'
    for v in p.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        f = 0.8 + 0.22 * math.sin(3 * a + 1) + 0.1 * math.sin(7 * a + 2) + 0.05 * math.sin(13 * a)
        v.co.x *= f * 0.9
        v.co.y *= f * 1.4
    p.data.materials.append(pozza)

    # salvagente sgonfio per terra, a strisce rosse e bianche
    sal = bpy.data.materials.new('salvagente')
    nt = sal.node_tree
    b = nt.nodes['Principled BSDF']
    tc = nodo(nt, 'ShaderNodeTexCoord', -1100, 0)
    gr = nodo(nt, 'ShaderNodeTexGradient', -900, 0, gradient_type='RADIAL')
    nt.links.new(tc.outputs['Object'], gr.inputs['Vector'])
    mm = nodo(nt, 'ShaderNodeMath', -700, 0, operation='MULTIPLY')
    nt.links.new(gr.outputs['Fac'], mm.inputs[0])
    mm.inputs[1].default_value = 4
    fr = nodo(nt, 'ShaderNodeMath', -550, 0, operation='FRACT')
    nt.links.new(mm.outputs[0], fr.inputs[0])
    gt = nodo(nt, 'ShaderNodeMath', -400, 0, operation='GREATER_THAN')
    nt.links.new(fr.outputs[0], gt.inputs[0])
    gt.inputs[1].default_value = 0.5
    mx = nodo(nt, 'ShaderNodeMix', -250, 0, data_type='RGBA')
    nt.links.new(gt.outputs[0], mx.inputs['Factor'])
    mx.inputs['A'].default_value = (0.45, 0.025, 0.02, 1)
    mx.inputs['B'].default_value = (0.6, 0.58, 0.52, 1)
    nt.links.new(mx.outputs['Result'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.3
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.055, location=(0.35, 0.9, 0.03),
                                     rotation=(math.radians(4), math.radians(-6), 0.4))
    t = bpy.context.object
    t.name = 'salvagente'
    t.scale = (1.0, 0.85, 0.45)
    t.data.materials.append(sal)
    bpy.ops.object.shade_smooth()


def lampada_rossa(nome, pos, rot, forza_luce, direzione=None):
    """Plafoniera d'emergenza: cassa scura, lente rossa accesa e una luce rossa vera."""
    cassa = bpy.data.materials.get('cassa_lampada') or materiale_semplice('cassa_lampada', (0.03, 0.03, 0.03), 0.6)
    lente = bpy.data.materials.get('lente_rossa') or materiale_semplice(
        'lente_rossa', (0.5, 0.02, 0.01), 0.2, emissione=(1.0, 0.03, 0.015), forza=80)
    sc = scatola(nome + '_cassa', pos, (0.24, 0.1, 0.13), cassa, rot=rot)
    ln = scatola(nome + '_lente', pos, (0.19, 0.11, 0.09), lente, rot=rot)
    ln.location = sc.matrix_world @ Vector((0, -0.006, 0))
    if direzione is None:
        l = bpy.data.lights.new(nome, 'POINT')
    else:
        l = bpy.data.lights.new(nome, 'SPOT')
        l.spot_size = math.radians(130)
        l.spot_blend = 0.7
    l.energy = forza_luce
    l.color = (1.0, 0.06, 0.03)
    l.shadow_soft_size = 0.06
    ob = bpy.data.objects.new(nome, l)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = sc.matrix_world @ Vector((0, -0.12, 0))
    if direzione is not None:
        ob.rotation_euler = Vector(direzione).to_track_quat('-Z', 'Y').to_euler()
    return ob


def luci():
    scene = bpy.context.scene
    w = bpy.data.worlds.new('mondo')
    scene.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.003, 0.004, 0.006, 1)
    # luce rossa d'emergenza sulla parete sopra la panca, puntata in giù lungo la panca
    lampada_rossa('rossa_panca', (MURO_SX + 0.05, -0.55, 1.85), (0, 0, math.radians(90)), 120,
                  direzione=(0.25, -0.6, -1.0))
    # due plafoniere rosse nel corridoio dietro la porta
    for k, y in enumerate((FONDO + 1.0, FONDO + 2.3)):
        lampada_rossa(f'rossa_corr_{k}', (0, y, 2.33), (math.radians(90), 0, 0), 60)
    # neon freddo sul soffitto, sopra la panca
    tubo = materiale_semplice('tubo_neon', (0.8, 0.9, 1.0), 0.3, emissione=(0.75, 0.9, 1.0), forza=10)
    scatola('neon', (-0.55, -1.0, 2.56), (0.035, 1.2, 0.035), tubo)
    a = bpy.data.lights.new('neon', 'AREA')
    a.shape = 'RECTANGLE'
    a.size, a.size_y = 0.05, 1.2
    a.energy = 22
    a.color = (0.72, 0.88, 1.0)
    oa = bpy.data.objects.new('neon_luce', a)
    scene.collection.objects.link(oa)
    oa.location = (-0.55, -1.0, 2.53)
    # neon spento più avanti (solo il tubo)
    spento = materiale_semplice('neon_spento', (0.5, 0.52, 0.55), 0.3)
    scatola('neon2', (-0.55, 1.6, 2.56), (0.035, 1.2, 0.035), spento)


def polaroid(variante, posizione, rot_z, appoggio=None, rot_extra=(0, 0, 0)):
    """Importa il GLB (l'asset del gioco) e gli dà il materiale della variante scelta."""
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=GLB)
    ob = [o for o in bpy.data.objects if o not in prima and o.type == 'MESH'][0]
    ob.name = f'Polaroid_{variante}'
    ob.material_slots[0].link = 'OBJECT'
    ob.material_slots[0].material = bpy.data.materials[f'Polaroid_{variante}']
    ob.rotation_euler = Euler((rot_extra[0], rot_extra[1], rot_z + rot_extra[2]), 'XYZ')
    ob.location = posizione
    if appoggio is not None:
        bpy.context.view_layer.update()
        zmin = min((ob.matrix_world @ v.co).z for v in ob.data.vertices)
        ob.location.z += appoggio - zmin + 0.0002
    return ob


def impostazioni(campioni):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = campioni
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 8
    scene.cycles.transmission_bounces = 8
    scene.render.resolution_x, scene.render.resolution_y = (640, 360) if PROVA else (1600, 900)
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'AgX'
    try:
        scene.view_settings.look = 'AgX - Medium High Contrast'
    except TypeError:
        pass
    scene.render.image_settings.file_format = 'JPEG'
    scene.render.image_settings.quality = 92


def camera(pos, guarda, lente):
    scene = bpy.context.scene
    cd = bpy.data.cameras.new('cam')
    cd.lens = lente
    cam = bpy.data.objects.new('cam', cd)
    scene.collection.objects.link(cam)
    cam.location = pos
    cam.rotation_euler = (Vector(guarda) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    return cam


def base():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.addons['io_scene_gltf2'].preferences.KHR_materials_variants_ui = True
    ambiente()
    luci()


def scena():
    base()
    # tre Polaroid: due sulla panca, una caduta per terra nella pozza
    polaroid('P07', (-0.985, -1.27, 0), math.radians(-78), appoggio=SEDUTA)
    polaroid('P02', (-1.0, -1.02, 0), math.radians(-104), appoggio=SEDUTA)
    polaroid('P09', (-0.62, -1.33, 0), math.radians(-62), appoggio=0.0009)
    camera((-0.38, -1.5, 0.98), (-0.9, -1.16, 0.36), 34)
    impostazioni(16 if PROVA else 64)
    bpy.context.scene.render.filepath = os.path.join(CACHE, 'prova_scena.jpg') if PROVA else os.path.join(OUT, 'render_in_gioco.jpg')
    bpy.ops.render.render(write_still=True)


def raccolta():
    base()
    polaroid('P02', (-1.0, -1.02, 0), math.radians(-104), appoggio=SEDUTA)
    polaroid('P09', (-0.62, -1.33, 0), math.radians(-62), appoggio=0.0009)
    # il giocatore ha raccolto P07 e la tiene davanti agli occhi, guardando verso il fondo
    cam = camera((0.05, -1.7, 1.55), (-0.1, 2.5, 1.2), 40)
    cam.data.dof.use_dof = True
    cam.data.dof.aperture_fstop = 2.0
    davanti = cam.matrix_world @ Vector((0.012, -0.012, -0.235))
    ob = polaroid('P07', davanti, 0)
    ob.rotation_mode = 'QUATERNION'
    # rivolta verso la camera, appena girata e inclinata come se fosse in mano
    q = cam.matrix_world.to_quaternion() @ Euler((math.radians(-10), math.radians(12), math.radians(4))).to_quaternion()
    ob.rotation_quaternion = q
    cam.data.dof.focus_object = ob
    # luce d'ispezione: morbida e calda, da sopra la spalla
    l = bpy.data.lights.new('ispezione', 'AREA')
    l.size = 0.3
    l.energy = 2.5
    l.color = (1.0, 0.92, 0.82)
    ol = bpy.data.objects.new('ispezione', l)
    bpy.context.scene.collection.objects.link(ol)
    ol.location = cam.matrix_world @ Vector((0.22, 0.25, 0.1))
    ol.rotation_euler = (davanti - ol.location).to_track_quat('-Z', 'Y').to_euler()
    impostazioni(16 if PROVA else 64)
    bpy.context.scene.render.filepath = os.path.join(CACHE, 'prova_raccolta.jpg') if PROVA else os.path.join(OUT, 'render_raccolta.jpg')
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    if 'scena' in sys.argv:
        scena()
    if 'raccolta' in sys.argv:
        raccolta()
