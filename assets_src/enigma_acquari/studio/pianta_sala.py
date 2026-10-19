"""Pianta dall'alto della sala principale (Cycles veloce, ortografica) con la griglia in coordinate di
Godot, per scegliere dove mettere gli acquari. Uso: blender-venv python pianta_sala.py <godot> <out.png>"""
import sys, bpy
from mathutils import Vector
godot, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
for f in ['sala_architettura', 'sala_piscina', 'sala_area_bimbi', 'sala_oggetti', 'sala_vasca_centrale',
          'sala_torre_scivoli', 'sala_interattivi']:
    bpy.ops.import_scene.gltf(filepath=f'{godot}/assets/ambiente/sala/{f}.glb')
# via il soffitto e tutto quello sopra i 5 m (Godot y = Blender z)
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        continue
    zs = [(o.matrix_world @ Vector(c)).z for c in o.bound_box]
    if min(zs) > 4.5 or (max(zs) - min(zs) < 1.0 and min(zs) > 3.0):
        bpy.data.objects.remove(o)
cam = bpy.data.cameras.new('c'); cam.type = 'ORTHO'; cam.ortho_scale = 46
co = bpy.data.objects.new('c', cam); bpy.context.scene.collection.objects.link(co)
co.location = (0, 0, 4.4); co.rotation_euler = (0, 0, 0)
cam.clip_start = 0.1; cam.clip_end = 30
sc = bpy.context.scene; sc.camera = co
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 12
sc.cycles.use_denoising = True; sc.cycles.max_bounces = 2
sun = bpy.data.lights.new('s', 'SUN'); sun.energy = 4; sun.angle = 0.3
so = bpy.data.objects.new('s', sun); sc.collection.objects.link(so); so.rotation_euler = (0.25, 0.15, 0)
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[1].default_value = 0.6
sc.render.resolution_x = sc.render.resolution_y = 1400
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
