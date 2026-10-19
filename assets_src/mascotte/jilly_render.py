"""Render Cycles degli oggetti JILLY JUBILEE di uno stile (targa, manifesto, insegna) affiancati.

Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python \
        assets_src/mascotte/jilly_render.py <a|b> <uscita.jpg>
"""
import math, os, sys
import bpy
from mathutils import Vector

stile, uscita = sys.argv[-2], sys.argv[-1]
QUI = os.path.dirname(os.path.abspath(__file__))
J = os.path.join(QUI, '..', '..', 'godot', 'proposte', 'mascotte', 'jilly')
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
# parete grigia, gli oggetti appoggiati come nel gioco (il glTF ha il davanti verso -Y in Blender)
bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0.0, 1.5), rotation=(math.pi / 2, 0, 0))
muro = bpy.context.active_object
m = bpy.data.materials.new('muro'); m.use_nodes = True
m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.3, 0.3, 0.3, 1)
muro.data.materials.append(m)
for nome, x, z in (('targa', -2.45, 1.45), ('manifesto', -1.15, 1.5), ('insegna', 1.0, 1.5)):
    bpy.ops.import_scene.gltf(filepath=os.path.join(J, f'{nome}_{stile}.glb'))
    for o in bpy.context.selected_objects:
        if o.parent is None:
            o.location = (x + o.location.x, o.location.y, z + o.location.z)
def luce(nome, pos, e, dim):
    l = bpy.data.lights.new(nome, 'AREA'); l.energy = e; l.size = dim
    o = bpy.data.objects.new(nome, l); sc.collection.objects.link(o); o.location = pos
    o.rotation_euler = (Vector((0, 0, 1.5)) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
luce('chiave', (-2.5, -4, 3.2), 160, 3); luce('riempi', (3, -3.5, 1.5), 60, 3)
cd = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cd); sc.collection.objects.link(cam)
sc.camera = cam; cd.lens = 40; cam.location = (-0.3, -5.6, 1.5); cam.rotation_euler = (math.pi / 2, 0, 0)
w = bpy.data.worlds.new('W'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.3
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 48; sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1600, 800
sc.view_settings.view_transform = 'AgX'
sc.render.image_settings.file_format = 'JPEG'; sc.render.image_settings.quality = 90
sc.render.filepath = uscita
bpy.ops.render.render(write_still=True)
