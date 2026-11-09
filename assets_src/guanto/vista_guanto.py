# Viste del guanto sulla lancia (Cycles, solo per controllo interno): apre il .blend del generatore.
import bpy, sys, math
from mathutils import Vector
BLEND = [a for a in sys.argv if a.endswith(".blend")][0]
OUT = sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 24; sc.cycles.use_denoising = True
sc.render.resolution_x = 640; sc.render.resolution_y = 640
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.62, 0.66, 1)
bianco = bpy.data.materials.new("bianco"); bianco.use_nodes = True
bsdf = bianco.node_tree.nodes["Principled BSDF"]; bsdf.inputs["Base Color"].default_value = (0.9, 0.9, 0.88, 1); bsdf.inputs["Roughness"].default_value = 0.6
for o in bpy.data.objects:
    if o.name in ("Guanto", "Polsino", "GuantoDestro") and False:
        o.data.materials.clear(); o.data.materials.append(bianco)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
c = Vector((0.0, -0.53, -0.24))
viste = {"destra": Vector((1, 0.15, 0.2)), "sinistra": Vector((-1, 0.15, 0.25)), "dietro": Vector((0.2, -1, 0.3)),
         "davanti": Vector((-0.2, 1, 0.1)), "sotto": Vector((0.2, -0.2, -1)), "gioco": Vector((-0.24, -0.66, 0.54))}
for nome, d in viste.items():
    cam.location = c + d.normalized() * 0.42
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Z').to_euler()
    sc.render.filepath = OUT + "_" + nome + ".png"
    bpy.ops.render.render(write_still=True)
