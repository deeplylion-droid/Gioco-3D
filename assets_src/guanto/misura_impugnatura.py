# Misura l'impugnatura della lancia C1 (sezioni a varie altezze) per costruirci attorno il guanto.
import bpy, bmesh, numpy as np, json, sys
GLTF = "/home/user/Gioco-3D/godot/assets/models/zaino/proposte_lance/lancia_c1_antincendio/lancia_c1_antincendio.gltf"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLTF)
ob = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('Lancia')][0]
dg = bpy.context.evaluated_depsgraph_get()
me = ob.evaluated_get(dg).to_mesh()
M = ob.matrix_world
# Blender: Z su, -Y avanti (glTF Y su, Z verso chi guarda): torna in coordinate glTF (x, y=Bz, z=-By)
V = np.array([tuple(M @ v.co) for v in me.vertices])
G = np.stack([V[:, 0], V[:, 2], -V[:, 1]], 1)
print("bbox", G.min(0), G.max(0))
sel = G[(G[:, 1] < -0.10) & (G[:, 2] > 0.40) & (G[:, 2] < 0.85)]
print("punti sotto la canna", len(sel))
for y in np.arange(-0.10, -0.33, -0.02):
    s = sel[np.abs(sel[:, 1] - y) < 0.006]
    if len(s) == 0:
        continue
    print("y %.2f  n %4d  x %.3f..%.3f  z %.3f..%.3f" % (y, len(s), s[:, 0].min(), s[:, 0].max(), s[:, 2].min(), s[:, 2].max()))
