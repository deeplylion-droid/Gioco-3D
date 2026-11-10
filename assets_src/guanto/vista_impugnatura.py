# Viste ortografiche dell'impugnatura della lancia C1 (di lato, di fronte, da sotto), per costruire il guanto.
import bpy, sys, math
from mathutils import Vector
GLTF = "/home/user/Gioco-3D/godot/assets/models/zaino/proposte_lance/lancia_c1_antincendio/lancia_c1_antincendio.gltf"
OUT = sys.argv[-1]
extra = sys.argv[-2] if len(sys.argv) > 2 and sys.argv[-2].endswith(".glb") else None
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLTF)
if extra:
    bpy.ops.import_scene.gltf(filepath=extra)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 16
sc.cycles.use_denoising = True
sc.render.resolution_x = 700
sc.render.resolution_y = 700
w = bpy.data.worlds.new("w"); sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.8, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 0.32
# centro in glTF (0, -0.24, 0.55) -> Blender (0, -0.55, -0.24)
c = Vector((0.0, -0.55, -0.24))
viste = {"lato_destro": Vector((1, 0, 0)), "lato_sinistro": Vector((-1, 0, 0)), "dietro": Vector((0, -1, 0)),
         "davanti": Vector((0, 1, 0)), "sotto": Vector((0, 0, -1)), "sopra": Vector((0, 0, 1))}
for nome, d in viste.items():
    cam.location = c + d * 2.0
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y' if abs(d.z) < 0.9 else 'Y').to_euler()
    if abs(d.z) > 0.9:
        cam.rotation_euler = (0, 0, 0) if d.z > 0 else (math.pi, 0, 0)
    sc.render.filepath = OUT + "_" + nome + ".png"
    bpy.ops.render.render(write_still=True)
