# Collaudo del guanto (enigmi): i vertici del guanto dentro la lancia, senza fidarsi delle normali della lancia (nel
# modello ci sono triangoli rovesciati): per ogni vertice vicino alla lancia (entro 2 cm) si contano gli attraversamenti
# della lancia lungo 6 direzioni; dentro se nella maggioranza delle direzioni sono dispari. Profondità = distanza dalla
# superficie più vicina.
import bpy, bmesh, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
G, L = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=L)
bm_l = bmesh.new()
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    if o.name.lower().startswith("tubo"):
        continue
    t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
    tmp = bpy.data.meshes.new("t"); t.to_mesh(tmp); bm_l.from_mesh(tmp)
bvh = BVHTree.FromBMesh(bm_l)
prima = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=G)
gl = [o for o in bpy.data.objects if o not in prima and o.type == 'MESH']
bm = bmesh.new()
for o in gl:
    t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
    tmp = bpy.data.meshes.new("g"); t.to_mesh(tmp); bm.from_mesh(tmp)
DIR = [Vector(d) for d in ((1, 0.013, 0.007), (-1, 0.011, -0.005), (0.009, 1, 0.012), (-0.006, -1, 0.01), (0.008, 0.014, 1), (0.012, -0.007, -1))]
def attraversa(p, d):
    n = 0; o = p.copy()
    for _ in range(60):
        h = bvh.ray_cast(o, d, 2.0)
        if h[0] is None:
            break
        n += 1; o = h[0] + d * 1e-6
    return n
vicini = 0; dentro = []
for v in bm.verts:
    q = bvh.find_nearest(v.co, 0.02)
    if q[0] is None:
        continue
    vicini += 1
    dispari = sum(attraversa(v.co, d.normalized()) % 2 for d in DIR)
    if dispari >= 4:
        dentro.append((q[3], tuple(round(x, 4) for x in v.co)))
dentro.sort(reverse=True)
print("DENTRO: vertici del guanto entro 2 cm dalla lancia %d; dentro la lancia (attraversamenti dispari in almeno 4 direzioni su 6) %d, al più %.2f mm" % (
    vicini, len(dentro), dentro[0][0] * 1000 if dentro else 0.0))
for d, p in dentro[:8]:
    print("   %.2f mm in (Blender) %s" % (d * 1000, p))
