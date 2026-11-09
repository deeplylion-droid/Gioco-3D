# Lente ortografica (Blender, raggi sui triangoli) su guanto e lancia: guanto bianco, lancia arancione, sfondo blu
# scuro; si vede se fra il guanto e la lancia passa la vista. Uso: lente_bvh.py guanto.glb lancia.gltf uscita.png
# x y z dx dy dz lato_mm (glTF; d = da dove si guarda)
import bpy, bmesh, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image
a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
Gp, Lp, out = a[0], a[1], a[2]
c = np.array([float(x) for x in a[3:6]]); d = np.array([float(x) for x in a[6:9]]); d /= np.linalg.norm(d); lato = float(a[9]) / 1000
def g2b(v): return Vector((v[0], -v[2], v[1]))
def bvh_di(path, salta=None):
    prima = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=path)
    bm = bmesh.new()
    for o in [o for o in bpy.data.objects if o not in prima and o.type == 'MESH']:
        if salta and o.name.lower().startswith(salta): continue
        t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world); tmp = bpy.data.meshes.new('t'); t.to_mesh(tmp); bm.from_mesh(tmp)
    return BVHTree.FromBMesh(bm)
bpy.ops.wm.read_factory_settings(use_empty=True)
BL = bvh_di(Lp, 'tubo'); BG = bvh_di(Gp)
up = np.array([0, 1.0, 0]) if abs(d[1]) < 0.9 else np.array([0, 0, 1.0])
u = np.cross(up, d); u /= np.linalg.norm(u); w = np.cross(d, u)
R = 400; img = np.zeros((R, R, 3), np.uint8); img[:] = (40, 50, 70)
dirb = g2b(-d)
for j in range(R):
    for i in range(R):
        o = c + u * ((i / R - 0.5) * lato) + w * ((0.5 - j / R) * lato) + d * 0.15
        ob = g2b(o)
        hg = BG.ray_cast(ob, dirb, 0.4); hl = BL.ray_cast(ob, dirb, 0.4)
        if hg[0] is not None and (hl[0] is None or hg[3] <= hl[3]):
            k = 0.35 + 0.65 * abs(hg[1].dot(dirb)); img[j, i] = (int(235 * k), int(235 * k), int(230 * k))
        elif hl[0] is not None:
            k = 0.35 + 0.65 * abs(hl[1].dot(dirb)); img[j, i] = (int(230 * k), int(95 * k), int(50 * k))
Image.fromarray(img).save(out); print('LENTE', out)
