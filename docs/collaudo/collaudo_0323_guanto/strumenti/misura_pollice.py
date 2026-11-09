# Collaudo del guanto (enigmi): il pollice appoggia sull'indice? Lungo l'asse del pollice (i punti del generatore,
# genera_guanto.py dalla 0.3.23), dal centro del pollice verso il basso (-y glTF) e di lato: dove esce dal guanto e cosa
# c'è dopo (di nuovo il guanto, cioè l'indice, o la lancia) e a quanti mm.
import bpy, bmesh, sys, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
G, L = sys.argv[-2], sys.argv[-1]
def g2b(v): return Vector((v[0], -v[2], v[1]))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=L)
bm_l = bmesh.new()
for o in [o for o in bpy.data.objects if o.type == 'MESH' and not o.name.lower().startswith('tubo')]:
    t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world); tmp = bpy.data.meshes.new('t'); t.to_mesh(tmp); bm_l.from_mesh(tmp)
bvh_l = BVHTree.FromBMesh(bm_l)
prima = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=G)
bm = bmesh.new()
for o in [o for o in bpy.data.objects if o not in prima and o.type == 'MESH']:
    t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world); tmp = bpy.data.meshes.new('g'); t.to_mesh(tmp); bm.from_mesh(tmp)
bvh_g = BVHTree.FromBMesh(bm)
import os
yt = float(os.environ.get("Y_INDICE", "-0.202")) + 0.0135 + 0.0145 - 0.003
P = [(0.050, -0.196, 0.552), (0.022, yt + 0.006, 0.566), (-0.012, yt + 0.003, 0.556), (-0.040, yt, 0.522), (-0.047, yt, 0.488), (-0.047, yt - 0.002, 0.462)]
def segui(o, d):
    # dal centro: la prima uscita dal guanto, poi il primo colpo dopo (guanto o lancia)
    h = bvh_g.ray_cast(o, d, 0.1)
    if h[0] is None: return None
    uscita = h[3]; q = h[0] + d * 1e-5
    hg = bvh_g.ray_cast(q, d, 0.1); hl = bvh_l.ray_cast(o, d, 0.2)
    cosa, dist = None, None
    if hg[0] is not None: cosa, dist = 'guanto', hg[3]
    if hl[0] is not None and (dist is None or hl[3] - uscita < dist):
        cosa, dist = 'lancia', hl[3] - uscita
    return uscita, cosa, dist
righe = []
for k in range(len(P) - 1):
    a, b = np.array(P[k]), np.array(P[k + 1])
    for s in np.linspace(0, 1, 6, endpoint=False):
        c = a + (b - a) * s
        for nome, dg in [('sotto', (0, -1, 0)), ('sotto-dentro', None)]:
            if dg is None:
                # verso l'asse dell'impugnatura (x 0,002, z 0,49), in orizzontale
                v = np.array([0.002 - c[0], 0, 0.49 - c[2]]); dg = tuple(v / np.linalg.norm(v))
            r = segui(g2b(c), g2b(dg).normalized())
            if r: righe.append((tuple(np.round(c, 3)), nome, r))
mx = 0
for c, nome, (u, cosa, dist) in righe:
    if cosa == 'guanto' and dist is not None and dist < 0.03: mx = max(mx, dist)
    print('POLLICE %s %-12s esce dopo %.1f mm, poi %s a %s mm' % (c, nome, u * 1000, cosa, '-' if dist is None else '%.1f' % (dist * 1000)))
