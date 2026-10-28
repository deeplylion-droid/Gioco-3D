"""Render di ogni giocattolo (Cycles su CPU, denoiser) per la pagina del mattino: il modello vero, su un fondo di
piastrelle grigie, luce di studio morbida, vista di tre quarti. Uso: blender-venv/bin/python render_giocattoli.py [nome ...]"""
import bpy, math, os, sys
from mathutils import Vector

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(QUI, '..', '..')
DIR = os.path.join(REPO, 'godot', 'assets', 'enigma_giocattoli')
OUT = os.path.join(REPO, 'docs', 'proposte', 'enigma_giocattoli')
nomi = [a for a in sys.argv[1:] if not a.startswith('-')] or ['paperella', 'palla_rossa', 'balena_blu']
GIRO = float(os.environ.get('GIRO', '0'))
for nome in nomi:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(DIR, nome + '.glb'))
    o = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    o.rotation_euler.z = math.radians(GIRO)
    alto = max((o.matrix_world @ Vector(c)).z for c in o.bound_box)
    bpy.ops.mesh.primitive_plane_add(size=8)
    pav = bpy.context.active_object
    m = bpy.data.materials.new('pavimento'); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (0.32, 0.33, 0.33, 1); b.inputs['Roughness'].default_value = 0.6
    pav.data.materials.append(m)
    w = bpy.data.worlds.new('m'); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.05, 0.055, 0.06, 1)
    for pos, en, size in (((-2.0, -2.5, 3.0), 400, 3.0), ((2.5, -1.0, 1.5), 120, 2.0), ((0.5, 3.0, 2.5), 200, 2.0)):
        bpy.ops.object.light_add(type='AREA', location=pos)
        l = bpy.context.active_object; l.data.energy = en; l.data.size = size
        l.rotation_euler = (Vector((0, 0, alto * 0.5)) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object; bpy.context.scene.camera = cam
    cam.data.lens = 50
    d = max(o.dimensions) * 2.6
    cam.location = Vector((d * 0.55, -d * 0.8, alto * 0.5 + d * 0.42))
    cam.rotation_euler = (Vector((0, 0, alto * 0.45)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 96; sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = 900
    sc.render.image_settings.file_format = 'JPEG'; sc.render.image_settings.quality = 90
    sc.view_settings.view_transform = 'AgX'
    sc.render.filepath = os.path.join(OUT, 'render_' + nome + '.jpg')
    bpy.ops.render.render(write_still=True)
    print('render ->', sc.render.filepath, flush=True)
