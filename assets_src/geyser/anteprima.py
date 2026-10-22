"""Anteprima della simulazione: alcuni fotogrammi resi in fretta (Cycles, pochi campioni, acqua bianca piena).
Uso: blender -b <cache>/geyser.blend --python assets_src/geyser/anteprima.py -- <uscita> <fotogrammi separati da virgola>"""
import sys, bpy
from mathutils import Vector
ARG = sys.argv[sys.argv.index('--') + 1:]
OUT, FR = ARG[0], [int(f) for f in ARG[1].split(',')]
sc = bpy.context.scene
dom = bpy.data.objects['Dominio']
mat = bpy.data.materials.new('acqua'); mat.use_nodes = True
b = mat.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value = (0.9, 0.93, 0.95, 1); b.inputs['Roughness'].default_value = 0.35
dom.data.materials.clear(); dom.data.materials.append(mat)
for n in ('Getto', 'Pozza'):
    bpy.data.objects[n].hide_render = True
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.location = (7.5, -7.5, 2.4)
cam.rotation_euler = (Vector((0, 0, 2.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sun = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN')); sc.collection.objects.link(sun)
sun.rotation_euler = (0.7, 0.2, 0.8); sun.data.energy = 3
sc.world = bpy.data.worlds.new('m'); sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.3, 0.32, 0.35, 1)
sc.render.engine = 'CYCLES'; sc.cycles.samples = 12; sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 480, 480
for f in FR:
    sc.frame_set(f)
    sc.render.filepath = f'{OUT}/f{f:03d}.png'
    bpy.ops.render.render(write_still=True)
