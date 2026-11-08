# Viste ravvicinate di due punti del guanto (per il collaudo): la punta dell'indice e lo spiraglio fra anulare e mignolo.
import bpy, sys
from mathutils import Vector
BLEND = [a for a in sys.argv if a.endswith(".blend")][0]
OUT = sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 24; sc.cycles.use_denoising = True
sc.render.resolution_x = 500; sc.render.resolution_y = 500
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.62, 0.66, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 60
cam.data.clip_start = 0.005
g = lambda v: Vector((v[0], -v[2], v[1]))
punti = {"punta_indice": ((-0.044, -0.197, 0.424), [(-1, 0.3, -0.6), (-0.4, 0.8, -1), (-1, -0.6, -0.2)]),
         "anulare_mignolo": ((0.034, -0.262, 0.463), [(1, 0.1, -0.3), (1, -0.4, -0.6), (0.8, 0.5, 0.2)])}
for nome, (p, dirs) in punti.items():
    c = g(p)
    for k, d in enumerate(dirs):
        cam.location = c + g(Vector(d).normalized()) * 0.12
        cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Z').to_euler()
        sc.render.filepath = "%s_%s_%d.png" % (OUT, nome, k)
        bpy.ops.render.render(write_still=True)
