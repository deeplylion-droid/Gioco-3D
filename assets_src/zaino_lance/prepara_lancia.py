"""Prepara un GLB di Meshy come lancia in prima persona per Godot (proposte zaino):
- toglie, se indicata, una zona di pezzi staccati (per esempio una bobina vicina);
- gira il modello con la punta verso +Y di Blender (= avanti, -Z, in Godot) e lo porta alla
  lunghezza vera; la punta (centro dell'uscita) va nell'origine;
- esporta un GLB con texture JPEG e stampa dove stanno impugnatura e canna, per le mani.
Uso: blender-venv/bin/python prepara_lancia.py -- <in.glb> <out.glb> <avanti: +X|-X> <lunghezza m> [xmin,xmax,zmin,zmax da togliere]"""
import bpy, bmesh, sys, mathutils
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
src, dst, avanti, lunghezza = args[0], args[1], args[2], float(args[3])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Pezzi da togliere (per esempio una bobina staccata): facce con il centro dentro una scatola,
# nelle coordinate del GLB importato: "xmin,xmax,zmin,zmax".
if len(args) > 4:
    x0, x1, z0, z1 = [float(v) for v in args[4].split(",")]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    via = [f for f in bm.faces if x0 <= f.calc_center_median().x <= x1 and z0 <= f.calc_center_median().z <= z1]
    print("tolte facce", len(via))
    bmesh.ops.delete(bm, geom=via, context='FACES')
    bm.to_mesh(ob.data)
    bm.free()
# Avanti = +Y di Blender.
# (direttamente sui dati della mesh: gli operatori di Blender senza interfaccia non sono affidabili)
ob.data.transform(mathutils.Matrix.Rotation(-1.5708 if avanti == "+X" else 1.5708, 4, 'Z'))
vs = [v.co for v in ob.data.vertices]
ymin = min(v.y for v in vs); ymax = max(v.y for v in vs)
ob.data.transform(mathutils.Matrix.Scale(lunghezza / (ymax - ymin), 4))
vs = [v.co.copy() for v in ob.data.vertices]
ymax = max(v.y for v in vs)
punta = [v for v in vs if v.y > ymax - 0.02]
tip = sum(punta, mathutils.Vector()) / len(punta)
tip.y = ymax
for v in ob.data.vertices:
    v.co -= tip
vs = [v.co.copy() for v in ob.data.vertices]
zmin = min(v.z for v in vs)
# Impugnatura: i vertici più bassi (sotto la canna). Canna: la zona alla quota della punta.
basso = [v for v in vs if v.z < zmin + 0.06]
grip = sum(basso, mathutils.Vector()) / len(basso)
print("LANCIA lunghezza %.3f punta=0 impugnatura(Blender) %s zmin %.3f zmax %.3f" % (
    lunghezza, tuple(round(x, 3) for x in grip), zmin, max(v.z for v in vs)))
# In Godot: x = x, y = z, z = -y.
print("GODOT impugnatura (%.3f, %.3f, %.3f)" % (grip.x, grip.z, -grip.y))
ob.name = "lancia"
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_image_format='JPEG',
                          export_jpeg_quality=88, use_selection=False)
print("scritto", dst)
