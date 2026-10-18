"""Render delle mascotte (GLB di Meshy) in Cycles su CPU con denoiser.

Uso:
    flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python \
        assets_src/mascotte/render_mascotte.py <modello.glb> <prefisso> [opzioni]

Opzioni:
    --altezza 2.3        altezza in metri (il modello viene scalato, appoggiato a terra, centrato)
    --ruota 0            gradi attorno a Z se Meshy lo esporta girato (davanti = verso -Y)
    --viste tre_quarti,davanti,lato,dettaglio,buio   (anche: dietro)
    --campioni 96 --res 1080x1440
    --dettaglio 0.85     altezza relativa del centro del dettaglio (0 = piedi, 1 = cima)
    --bagnato 0          0..1: rende la superficie più lucida e bagnata (pelle viva)
    --anteprima          campioni bassi, risoluzione piccola, un'unica tavola con tutte le viste

Escono <prefisso>_<vista>.jpg (o <prefisso>_anteprima.jpg).
Studio: fondale grigio neutro curvo, luce morbida. Buio: pavimento di piastrelle bagnate, nebbia
leggera, un rosso d'emergenza lontano e il cono della torcia (40°) che parte dalla camera.
"""
import argparse, math, os, sys
import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument('glb'); ap.add_argument('out')
ap.add_argument('--altezza', type=float, default=2.3)
ap.add_argument('--ruota', type=float, default=0.0)
ap.add_argument('--viste', default='tre_quarti,davanti,lato,dettaglio,buio')
ap.add_argument('--campioni', type=int, default=64)
ap.add_argument('--res', default='960x1280')
ap.add_argument('--dettaglio', type=float, default=0.85)
ap.add_argument('--bagnato', type=float, default=0.0)
ap.add_argument('--anteprima', action='store_true')
A = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])

if A.anteprima:
    A.campioni, A.res, A.viste = 24, '480x640', 'davanti,tre_quarti,lato,dietro'
RX, RY = (int(v) for v in A.res.split('x'))
ANGOLI = {'davanti': 0, 'tre_quarti': 35, 'lato': 90, 'dietro': 180, 'dettaglio': 20, 'buio': 25}

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ---------------------------------------------------------------- modello
bpy.ops.import_scene.gltf(filepath=A.glb)
mesh = [o for o in sc.objects if o.type == 'MESH']
radice = bpy.data.objects.new('radice', None); sc.collection.objects.link(radice)
for o in sc.objects:
    if o.parent is None and o is not radice:
        o.parent = radice
bpy.context.view_layer.update()
pts = [o.matrix_world @ Vector(c) for o in mesh for c in o.bound_box]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
s = A.altezza / (hi.z - lo.z)
c = (lo + hi) / 2
radice.scale = (s, s, s)
radice.location = (-c.x * s, -c.y * s, -lo.z * s)
bpy.context.view_layer.update()
H = A.altezza
tri = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in mesh)
tex = sorted({f'{i.size[0]}x{i.size[1]}' for i in bpy.data.images if i.size[0]})
print('MODELLO', os.path.basename(A.glb), 'triangoli', tri, 'texture', tex, flush=True)

# la superficie bagnata: meno rugosità, un velo di clearcoat
if A.bagnato > 0:
    for m in bpy.data.materials:
        if not m.node_tree:
            continue
        for n in m.node_tree.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                r = n.inputs['Roughness']
                if r.is_linked:
                    mul = m.node_tree.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
                    mul.inputs[1].default_value = 1 - 0.6 * A.bagnato
                    m.node_tree.links.new(r.links[0].from_socket, mul.inputs[0])
                    m.node_tree.links.new(mul.outputs[0], r)
                else:
                    r.default_value *= 1 - 0.6 * A.bagnato
                n.inputs['Coat Weight'].default_value = 0.5 * A.bagnato
                n.inputs['Coat Roughness'].default_value = 0.08


# ---------------------------------------------------------------- utilità
def collega(ob):
    sc.collection.objects.link(ob)
    return ob


def guarda(ob, bersaglio):
    ob.rotation_euler = (Vector(bersaglio) - ob.location).to_track_quat('-Z', 'Y').to_euler()


def luce(nome, tipo, pos, energia, colore=(1, 1, 1), dim=1.0, bersaglio=None):
    ld = bpy.data.lights.new(nome, tipo); ld.energy = energia; ld.color = colore
    if tipo == 'AREA':
        ld.size = dim
    ob = collega(bpy.data.objects.new(nome, ld)); ob.location = pos
    guarda(ob, bersaglio or (0, 0, H * 0.5))
    return ob


def mat(nome, colore, rug=0.5):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*colore, 1); b.inputs['Roughness'].default_value = rug
    return m


studio, buio = [], []

# ---------------------------------------------------------------- studio
fondale = collega(bpy.data.objects.new('fondale', bpy.data.meshes.new('fondale')))
me = fondale.data
prof = [(-12 + 16 * i / 8, 0.0) for i in range(8)]  # pavimento fino a y=4, poi curva e parete
prof += [(4 + 3 * math.sin(a), 3 - 3 * math.cos(a)) for a in (k * math.pi / 32 for k in range(17))]
prof += [(7, 14)]
vs, fs = [], []
for y, z in prof:
    vs += [(-12, y, z), (12, y, z)]
for i in range(len(prof) - 1):
    fs.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
me.from_pydata(vs, [], fs); me.update()
for p in me.polygons:
    p.use_smooth = True
fondale.data.materials.append(mat('grigio', (0.32, 0.32, 0.32), 0.8))
studio.append(fondale)
studio.append(luce('chiave', 'AREA', (-2.5, -3.5, H * 1.4), 320, dim=3.0))
studio.append(luce('riempi', 'AREA', (3.2, -2.5, H * 0.7), 110, (0.92, 0.95, 1.0), dim=3.0))
studio.append(luce('contro', 'AREA', (1.0, 3.0, H * 1.6), 260, dim=2.0))

# ---------------------------------------------------------------- buio
pav = mat('piastrelle', (0.5, 0.5, 0.5), 0.15)
nt, ln = pav.node_tree.nodes, pav.node_tree.links
b = nt['Principled BSDF']
co = nt.new('ShaderNodeTexCoord'); mp = nt.new('ShaderNodeMapping')
mp.inputs['Scale'].default_value = (4, 4, 4)
br = nt.new('ShaderNodeTexBrick')
br.inputs['Color1'].default_value = (0.2, 0.27, 0.28, 1); br.inputs['Color2'].default_value = (0.16, 0.22, 0.23, 1)
br.inputs['Mortar'].default_value = (0.08, 0.08, 0.07, 1)
br.inputs['Mortar Size'].default_value = 0.015; br.inputs['Brick Width'].default_value = 0.5
br.inputs['Row Height'].default_value = 0.5; br.offset = 0.0
ns = nt.new('ShaderNodeTexNoise'); ns.inputs['Scale'].default_value = 1.5
rmp = nt.new('ShaderNodeMapRange'); rmp.inputs['To Min'].default_value = 0.04; rmp.inputs['To Max'].default_value = 0.45
ln.new(co.outputs['Object'], mp.inputs['Vector']); ln.new(mp.outputs['Vector'], br.inputs['Vector'])
ln.new(br.outputs['Color'], b.inputs['Base Color'])
ln.new(ns.outputs['Fac'], rmp.inputs['Value']); ln.new(rmp.outputs['Result'], b.inputs['Roughness'])
bpy.ops.mesh.primitive_plane_add(size=30)
terra = bpy.context.active_object; terra.data.materials.append(pav); buio.append(terra)
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 7, 0), rotation=(math.pi / 2, 0, 0))
muro = bpy.context.active_object; muro.data.materials.append(mat('muro', (0.15, 0.17, 0.18), 0.6)); buio.append(muro)
buio.append(luce('emergenza', 'POINT', (-4.5, 5.5, 3.2), 120, (1.0, 0.08, 0.04)))
buio.append(luce('emergenza2', 'POINT', (5, 6, 2.8), 60, (1.0, 0.1, 0.05)))
buio.append(luce('neon', 'AREA', (3.5, 2.0, 4.5), 40, (0.6, 0.8, 1.0), dim=1.2))
nebbia = bpy.data.materials.new('nebbia'); nebbia.use_nodes = True
nn = nebbia.node_tree.nodes; nn.remove(nn['Principled BSDF'])
vol = nn.new('ShaderNodeVolumePrincipled'); vol.inputs['Density'].default_value = 0.012
nebbia.node_tree.links.new(vol.outputs['Volume'], nn['Material Output'].inputs['Volume'])
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 3.05))  # staccato dal pavimento
cubo = bpy.context.active_object; cubo.scale = (30, 30, 6); cubo.data.materials.append(nebbia); buio.append(cubo)

# ---------------------------------------------------------------- camera e mondo
cd = bpy.data.cameras.new('cam'); cam = collega(bpy.data.objects.new('cam', cd)); sc.camera = cam
torcia = luce('torcia', 'SPOT', (0, 0, 0), 260, (1.0, 0.93, 0.82))
torcia.data.spot_size = math.radians(40); torcia.data.spot_blend = 0.45; torcia.data.shadow_soft_size = 0.03
torcia.parent = cam; torcia.location = (0.12, -0.15, 0); torcia.rotation_euler = (0, 0, 0)
buio.append(torcia)

world = bpy.data.worlds.new('W'); sc.world = world; world.use_nodes = True
sfondo = world.node_tree.nodes['Background']

sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = A.campioni; sc.cycles.use_denoising = True
sc.cycles.max_bounces = 8; sc.cycles.volume_bounces = 0
sc.render.resolution_x, sc.render.resolution_y = RX, RY
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'
sc.render.image_settings.file_format = 'JPEG'; sc.render.image_settings.quality = 90


def nascondi(lista, v):
    for o in lista:
        o.hide_render = v


def inquadra(vista):
    ang = math.radians(ANGOLI[vista] + A.ruota)
    radice.rotation_euler = (0, 0, ang)
    if vista == 'dettaglio':
        cd.lens = 85
        f = Vector((0, 0, H * A.dettaglio))
        d = H * 1.45
        cam.location = f + Vector((0, -d, H * 0.04))
        guarda(cam, f)
    elif vista == 'buio':
        cd.lens = 22  # inquadratura orizzontale come nel gioco, occhi a 1,65 m
        cam.location = Vector((0.4, -3.3, 1.65))
        guarda(cam, (0, 0, H * 0.5))
    else:
        cd.lens = 50 if vista == 'lato' else 68
        f = Vector((0, 0, H * 0.5))
        cam.location = f + Vector((0, -H * 2.55, H * 0.12))
        guarda(cam, f)


def scena(vista):
    is_buio = vista == 'buio'
    nascondi(studio, is_buio); nascondi(buio, not is_buio)
    if is_buio:
        sfondo.inputs['Color'].default_value = (0.002, 0.002, 0.003, 1)
        sc.view_settings.exposure = 0.0
    else:
        sfondo.inputs['Color'].default_value = (0.3, 0.3, 0.3, 1)
        sfondo.inputs['Strength'].default_value = 0.35
        sc.view_settings.exposure = 0.0


viste = A.viste.split(',')
fatti = []
for v in viste:
    scena(v); inquadra(v)
    if v == 'buio' and not A.anteprima:
        sc.render.resolution_x, sc.render.resolution_y = RY, RX * RX // RY  # orizzontale
    else:
        sc.render.resolution_x, sc.render.resolution_y = RX, RY
    p = f'{A.out}_{v}.jpg'
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    fatti.append(p)
    print('RENDER', p, flush=True)

if A.anteprima:
    from PIL import Image
    ims = [Image.open(p) for p in fatti]
    t = Image.new('RGB', (RX * len(ims), RY))
    for i, im in enumerate(ims):
        t.paste(im, (i * RX, 0))
    t.save(f'{A.out}_anteprima.jpg', quality=85)
    for p in fatti:
        os.remove(p)
