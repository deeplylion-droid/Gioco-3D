"""Versione per il gioco di un modello Meshy: riduzione, UV nuove e cottura dal modello grezzo.

Uso:
    flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python \
        assets_src/mascotte/riduci_cuoci.py <grezzo.glb> <uscita.glb> --triangoli 50000 --altezza 2.3

Il grezzo viene scalato all'altezza data, appoggiato a terra e centrato (davanti verso -Y in
Blender, cioè +Z in Godot). La copia ridotta (decimazione) tiene le UV di Meshy; dal grezzo si cuociono
in Cycles colore, rugosità e normali (che comprendono anche la mappa normali di Meshy) su texture
quadrate (--lato, 2048). Il GLB esce con le texture JPEG dentro; metallo a 0 (Meshy lo dà quasi nullo).
"""
import argparse, os, sys
import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument('grezzo'); ap.add_argument('uscita')
ap.add_argument('--triangoli', type=int, default=50000)
ap.add_argument('--altezza', type=float, default=2.3)
ap.add_argument('--lato', type=int, default=2048)
A = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
nome = os.path.splitext(os.path.basename(A.uscita))[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=A.grezzo)
mesh = [o for o in sc.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in mesh:
    o.select_set(True)
bpy.context.view_layer.objects.active = mesh[0]
if len(mesh) > 1:
    bpy.ops.object.join()
alto = bpy.context.view_layer.objects.active
for o in list(sc.objects):  # via i nodi vuoti del glTF, tenendo la trasformazione
    if o is not alto and o.type != 'MESH':
        bpy.data.objects.remove(o)
alto.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# scala, a terra e al centro
pts = [Vector(v.co) for v in alto.data.vertices]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
s = A.altezza / (hi.z - lo.z)
alto.scale = (s, s, s)
alto.location = (-(lo.x + hi.x) / 2 * s, -(lo.y + hi.y) / 2 * s, -lo.z * s)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
tri_alto = sum(len(p.vertices) - 2 for p in alto.data.polygons)

# copia ridotta
basso = alto.copy(); basso.data = alto.data.copy(); basso.name = nome
sc.collection.objects.link(basso)
dec = basso.modifiers.new('riduci', 'DECIMATE')
dec.ratio = min(1.0, A.triangoli / tri_alto)
bpy.ops.object.select_all(action='DESELECT')
basso.select_set(True); bpy.context.view_layer.objects.active = basso
bpy.ops.object.modifier_apply(modifier='riduci')
for p in basso.data.polygons:
    p.use_smooth = True
# si tengono le UV di Meshy (coprono circa due terzi della texture e la decimazione le conserva)
while len(basso.data.uv_layers) > 1:
    basso.data.uv_layers.remove(basso.data.uv_layers[-1])
tri_basso = sum(len(p.vertices) - 2 for p in basso.data.polygons)
print('TRIANGOLI', tri_alto, '->', tri_basso, flush=True)

# materiale nuovo con le tre immagini da cuocere
mat = bpy.data.materials.new(nome); mat.use_nodes = True
mat.use_backface_culling = True  # modelli chiusi: niente doppia faccia in Godot
nt, ln = mat.node_tree.nodes, mat.node_tree.links
bsdf = nt['Principled BSDF']
bsdf.inputs['Metallic'].default_value = 0.0
img = {}
for chiave, cs in (('colore', 'sRGB'), ('rugosita', 'Non-Color'), ('normali', 'Non-Color')):
    im = bpy.data.images.new(f'{nome}_{chiave}', A.lato, A.lato, alpha=False)
    im.colorspace_settings.name = cs
    n = nt.new('ShaderNodeTexImage'); n.image = im; n.name = chiave
    img[chiave] = (im, n)
ln.new(img['colore'][1].outputs['Color'], bsdf.inputs['Base Color'])
ln.new(img['rugosita'][1].outputs['Color'], bsdf.inputs['Roughness'])
nm = nt.new('ShaderNodeNormalMap')
ln.new(img['normali'][1].outputs['Color'], nm.inputs['Color'])
ln.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
basso.data.materials.clear(); basso.data.materials.append(mat)

sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 4
b = sc.render.bake
b.use_selected_to_active = True; b.use_cage = False
b.cage_extrusion = 0.005 * A.altezza; b.max_ray_distance = 0.012 * A.altezza
b.margin = 8
bpy.ops.object.select_all(action='DESELECT')
alto.select_set(True); basso.select_set(True); bpy.context.view_layer.objects.active = basso

for chiave, tipo, extra in (('colore', 'DIFFUSE', {'pass_filter': {'COLOR'}}),
                            ('rugosita', 'ROUGHNESS', {}), ('normali', 'NORMAL', {})):
    nt.active = img[chiave][1]
    for n in nt:
        n.select = False
    img[chiave][1].select = True
    bpy.ops.object.bake(type=tipo, **extra)
    print('COTTO', chiave, flush=True)

bpy.data.objects.remove(alto)
bpy.ops.export_scene.gltf(filepath=A.uscita, export_format='GLB', use_selection=False,
                          export_image_format='JPEG', export_jpeg_quality=90,
                          export_yup=True, export_apply=True)
print('ESPORTATO', A.uscita, tri_basso, flush=True)
