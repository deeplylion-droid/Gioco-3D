"""Viste ortografiche dei GLB grezzi di Meshy (davanti, lato, sopra), per capire assi e misure."""
import sys, bpy, math
from mathutils import Vector
src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = 8; sc.cycles.use_denoising = True
w = bpy.data.worlds.new('w'); sc.world = w
w.node_tree.nodes['Background'].inputs[1].default_value = 1.5
sc.render.resolution_x = 1200; sc.render.resolution_y = 400
cam = bpy.data.cameras.new('c'); cam.type = 'ORTHO'; cam.ortho_scale = 2.2
co = bpy.data.objects.new('c', cam); sc.collection.objects.link(co); sc.camera = co
from PIL import Image
tiles = []
for i, (loc, rot) in enumerate([((0, -5, 0), (math.pi/2, 0, 0)), ((5, 0, 0), (math.pi/2, 0, math.pi/2)), ((0, 0, 5), (0, 0, 0))]):
    co.location = loc; co.rotation_euler = rot
    sc.render.resolution_x = 400
    sc.render.filepath = f'/tmp/_v{i}.png'
    bpy.ops.render.render(write_still=True)
    tiles.append(Image.open(f'/tmp/_v{i}.png').convert('RGB'))
o = Image.new('RGB', (1200, 400))
for i, t in enumerate(tiles):
    o.paste(t, (i * 400, 0))
o.save(out)
