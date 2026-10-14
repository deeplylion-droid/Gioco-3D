"""Render di anteprima di un GLB: davanti, 3/4, lato, dietro (Cycles, luce da studio)."""
import bpy, sys, math
from mathutils import Vector

glb, out_prefix = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in scene.objects if o.type == 'MESH']
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
size = hi - lo
center = (lo + hi) / 2
print('objects', len(meshes), 'faces', sum(len(o.data.polygons) for o in meshes), 'size', tuple(round(v, 3) for v in size))
for o in meshes:
    for m in o.data.materials:
        if m: print('material', m.name, [n.type for n in m.node_tree.nodes])

pivot = bpy.data.objects.new('pivot', None); scene.collection.objects.link(pivot)
pivot.location = center
for o in scene.objects:
    if o.parent is None and o is not pivot:
        o.parent = pivot
        o.matrix_parent_inverse = pivot.matrix_world.inverted()

world = bpy.data.worlds.new('W'); scene.world = world
try: world.use_nodes = True
except Exception: pass
bg = world.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value = (0.035, 0.035, 0.045, 1); bg.inputs['Strength'].default_value = 1.0

H = size.z
def area(name, loc, energy, color=(1, 1, 1), sz=1.5):
    l = bpy.data.lights.new(name, 'AREA'); l.energy = energy; l.color = color; l.size = sz * H
    ob = bpy.data.objects.new(name, l); scene.collection.objects.link(ob)
    ob.location = center + Vector(loc) * H
    ob.rotation_euler = (center - ob.location).to_track_quat('-Z', 'Y').to_euler()
area('key', (-1.2, -1.6, 0.9), 110 * H * H)
area('fill', (1.4, -1.2, 0.2), 35 * H * H, (0.8, 0.85, 1.0))
area('rim', (0.6, 1.6, 1.2), 120 * H * H, (1.0, 0.75, 0.9))

cam_d = bpy.data.cameras.new('cam'); cam_d.lens = 70
cam = bpy.data.objects.new('cam', cam_d); scene.collection.objects.link(cam); scene.camera = cam
dist = H * 3.4
cam.location = center + Vector((0, -dist, 0.05 * H))
cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()

scene.render.engine = 'CYCLES'; scene.cycles.device = 'CPU'; scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 720, 960
scene.view_settings.view_transform = 'AgX'
scene.render.image_settings.file_format = 'PNG'
for name, ang in (('front', 0), ('tre_quarti', 35), ('lato', 90), ('dietro', 180)):
    pivot.rotation_euler = (0, 0, math.radians(ang))
    scene.render.filepath = f'{out_prefix}_{name}.png'
    bpy.ops.render.render(write_still=True)
# primo piano del viso
pivot.rotation_euler = (0, 0, 0)
cam_d.lens = 70
face = Vector((center.x, center.y, lo.z + 0.86 * H))
cam.location = face + Vector((0, -H * 1.1, 0.0))
cam.rotation_euler = (face - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.resolution_x, scene.render.resolution_y = 960, 960
scene.render.filepath = f'{out_prefix}_viso.png'
bpy.ops.render.render(write_still=True)
