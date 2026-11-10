# Sezioni dell'impugnatura della lancia C1 (contorni veri, con bisect) in coordinate glTF della lancia.
import bpy, bmesh, numpy as np
from mathutils import Vector
GLTF = "/home/user/Gioco-3D/godot/assets/models/zaino/proposte_lance/lancia_c1_antincendio/lancia_c1_antincendio.gltf"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLTF)
ob = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('Lancia')][0]
bm0 = bmesh.new(); bm0.from_mesh(ob.data); bm0.transform(ob.matrix_world)
for gy in np.arange(-0.14, -0.335, -0.015):
    bm = bm0.copy()
    # piano orizzontale glTF y = gy -> Blender z = gy
    res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, gy), plane_no=(0, 0, 1))
    pts = np.array([tuple(e.co) for e in res["geom_cut"] if isinstance(e, bmesh.types.BMVert)])
    bm.free()
    if len(pts) == 0:
        continue
    G = np.stack([pts[:, 0], -pts[:, 1]], 1)   # (x, z glTF)
    G = G[(G[:, 1] > 0.38) & (G[:, 1] < 0.66)]
    if len(G) == 0:
        continue
    print("y %.3f  x %.3f..%.3f  z %.3f..%.3f  centro (%.3f, %.3f)" % (gy, G[:, 0].min(), G[:, 0].max(), G[:, 1].min(), G[:, 1].max(),
          (G[:, 0].min() + G[:, 0].max()) / 2, (G[:, 1].min() + G[:, 1].max()) / 2))
