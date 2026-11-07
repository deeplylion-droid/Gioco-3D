# Collaudo del guanto (enigmi): il guanto contro l'impugnatura vera, nelle coordinate glTF della lancia (come nella scena,
# posizione e rotazione zero). Per ogni vertice del guanto: il punto più vicino della lancia, la distanza e il lato
# (dentro = compenetrazione). I vertici "dal lato dell'impugnatura" (normale del guanto verso la lancia, entro 3 cm) dicono
# i distacchi. Poi i bordi aperti del guanto (il polsino vuoto da dietro).
import bpy, bmesh, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
G, L = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=L)
lan = [o for o in bpy.data.objects if o.type == 'MESH']
print("lancia:", [(o.name, len(o.data.vertices)) for o in lan])
bm_l = bmesh.new()
for o in lan:
    if o.name.lower().startswith("tubo"):
        continue
    t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
    tmp = bpy.data.meshes.new("t"); t.to_mesh(tmp); bm_l.from_mesh(tmp)
bvh = BVHTree.FromBMesh(bm_l)
prima = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=G)
gl = [o for o in bpy.data.objects if o not in prima and o.type == 'MESH']
print("guanto:", [(o.name, len(o.data.vertices), len(o.data.polygons)) for o in gl])
bm = bmesh.new()
for o in gl:
    t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
    tmp = bpy.data.meshes.new("g"); t.to_mesh(tmp); bm.from_mesh(tmp)
bm.verts.ensure_lookup_table(); bm.normal_update()
dist = []; dentro = []; lato = []
for v in bm.verts:
    p, n, i, d = bvh.find_nearest(v.co, 0.2)
    if p is None:
        continue
    s = (v.co - p).dot(n)
    if s < 0:
        dentro.append(-s)
    dist.append(d)
    # dal lato dell'impugnatura: la normale del guanto va verso la lancia
    if d < 0.03 and d > 1e-7 and v.normal.dot((p - v.co).normalized()) > 0.5:
        lato.append(d if s >= 0 else -d)
dist = np.array(dist); lato = np.array(lato); dentro = np.array(dentro) if dentro else np.zeros(0)
print("vertici del guanto %d; a meno di 3 cm dalla lancia %d" % (len(bm.verts), (dist < 0.03).sum()))
print("dentro la lancia: %d vertici, al più %.2f mm" % (len(dentro), dentro.max() * 1000 if len(dentro) else 0))
if len(lato):
    fuori = lato[lato >= 0]
    print("dal lato dell'impugnatura: %d vertici; distacco: mediana %.2f mm, 95%% %.2f mm, massimo %.2f mm" % (len(lato), np.median(fuori) * 1000, np.percentile(fuori, 95) * 1000, fuori.max() * 1000))
    for soglia in [0.0008, 0.001, 0.002, 0.005, 0.01]:
        print("   sopra %.1f mm: %d" % (soglia * 1000, (fuori > soglia).sum()))
# i vertici più staccati dal lato dell'impugnatura: dove sono
pts = []
for v in bm.verts:
    p, n, i, d = bvh.find_nearest(v.co, 0.2)
    if p is not None and 0.0008 < d < 0.03 and v.normal.dot((p - v.co).normalized()) > 0.5:
        pts.append((d, tuple(round(c, 4) for c in (v.co.x, v.co.z, -v.co.y))))
pts.sort(reverse=True)
print("i 8 più staccati (mm, glTF x y z):", [(round(d * 1000, 2), c) for d, c in pts[:8]])
# bordi aperti (un solo poligono): il polsino o buchi
aperti = [e for e in bm.edges if len(e.link_faces) == 1]
print("bordi aperti: %d" % len(aperti))
if aperti:
    zs = [((e.verts[0].co + e.verts[1].co) / 2) for e in aperti]
    print("   dove (glTF): x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % (min(c.x for c in zs), max(c.x for c in zs), min(c.z for c in zs), max(c.z for c in zs), min(-c.y for c in zs), max(-c.y for c in zs)))
# misure: scatola del guanto e spessore delle dita
co = np.array([(v.co.x, v.co.z, -v.co.y) for v in bm.verts])
print("scatola del guanto (glTF): da %s a %s" % (np.round(co.min(0), 3), np.round(co.max(0), 3)))
