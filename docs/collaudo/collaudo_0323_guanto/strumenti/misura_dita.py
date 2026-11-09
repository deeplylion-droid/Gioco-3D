# Collaudo del guanto (enigmi): il distacco delle dita dall'impugnatura, misurato in modo indipendente dal generatore.
# Per ogni dito (le quote del generatore: indice a y -0,196, passo 2,55 cm), lungo il contorno dell'impugnatura ogni 3
# gradi, alla quota del centro del dito e 2 mm sopra e sotto: dalla superficie dell'impugnatura verso fuori, quanto
# c'è prima del guanto. Poi il palmo (lato destro) e il pollice (sopra l'indice).
import bpy, bmesh, sys, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
G, L = sys.argv[-2], sys.argv[-1]
def g2b(v): return Vector((v[0], -v[2], v[1]))
def b2g(v): return Vector((v[0], v[2], -v[1]))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=L)
lan = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('Lancia')][0]
bm_l = bmesh.new(); bm_l.from_mesh(lan.data); bm_l.transform(lan.matrix_world)
bvh_l = BVHTree.FromBMesh(bm_l)
prima = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=G)
gl = [o for o in bpy.data.objects if o not in prima and o.type == 'MESH'][0]
bm_g = bmesh.new(); bm_g.from_mesh(gl.data); bm_g.transform(gl.matrix_world)
bvh_g = BVHTree.FromBMesh(bm_g)
def contorno(gy, a, centro_xz=(0.002, 0.49)):
    c = g2b((centro_xz[0], gy, centro_xz[1]))
    d = Vector((math.cos(math.radians(a)), 0.0, -math.sin(math.radians(a))))
    db = g2b(d)
    hit = bvh_l.ray_cast(c + db * 0.2, -db, 0.25)
    if hit[0] is None: return None
    p, n = hit[0], hit[1]
    if n.dot(db) < 0: n = -n
    return p, n
def distacco(p, n):
    hit = bvh_g.ray_cast(p - n * 0.0003, n, 0.05)
    return (hit[3] - 0.0003) if hit[0] is not None else None
Y_INDICE, PASSO = -0.196, 0.0255
# le quote dei centri delle dita: DITA_Y="-0.202,-0.2272,-0.2508,-0.2727" (genera_guanto.py dalla 0.3.23: raggi che calano
# e dita che si toccano); senza, quelle della 0.3.22 (indice a -0,196, passo 2,55 cm)
import os
QUOTE = [float(x) for x in os.environ.get("DITA_Y", "").split(",") if x] or [Y_INDICE - i * PASSO for i in range(4)]
Y_INDICE = QUOTE[0]
tot = []
for i in range(4):
    gy0 = QUOTE[i]
    fine = 178 - i * 6
    for dy in (-0.002, 0.0, 0.002):
        ds = []; buchi = 0; peggio = (0, None)
        for a in range(-25, fine + 1, 3):
            c = contorno(gy0 + dy, a)
            if c is None: continue
            d = distacco(*c)
            if d is None:
                buchi += 1; continue
            ds.append(d)
            if d > peggio[0]: peggio = (d, a)
            if d > 0.001 and os.environ.get("DETTAGLI"):
                q = b2g(c[0])
                print("   dito %d, quota %+.0f mm, %d gradi: %.2f mm, impugnatura in glTF (%.4f, %.4f, %.4f)" % (i, dy * 1000, a, d * 1000, q[0], q[1], q[2]))
        ds = np.array(ds); tot += list(ds)
        print("dito %d, quota %+.0f mm: %d punti, distacco medio %.2f mm, massimo %.2f mm (a %s gradi), sopra 1 mm %d, sopra 2 mm %d, senza guanto sopra %d" % (
            i, dy * 1000, len(ds), ds.mean() * 1000, peggio[0] * 1000, peggio[1], (ds > 0.001).sum(), (ds > 0.002).sum(), buchi))
tot = np.array(tot)
print("DITA: %d punti, massimo %.2f mm, sopra 0,8 mm %d, sopra 1 mm %d, sopra 2 mm %d" % (len(tot), tot.max() * 1000, (tot > 0.0008).sum(), (tot > 0.001).sum(), (tot > 0.002).sum()))
# il palmo, sul lato destro dell'impugnatura (angoli -40..20) fra l'indice e il mignolo
pal = []
for gy in np.arange(-0.27, -0.19, 0.005):
    for a in range(-40, 21, 5):
        c = contorno(gy, a)
        if c is None: continue
        d = distacco(*c)
        if d is not None: pal.append(d)
pal = np.array(pal)
print("PALMO (lato destro, y -0,27..-0,19): %d punti, distacco medio %.2f mm, massimo %.2f mm, sopra 2 mm %d, sopra 10 mm %d" % (len(pal), pal.mean() * 1000, pal.max() * 1000, (pal > 0.002).sum(), (pal > 0.01).sum()))
# il dorso dell'impugnatura sotto il pollice (angoli 60..120 = davanti?) e sopra l'indice
print("PALMO, i punti sopra 5 mm (y, angolo, mm):")
for gy in np.arange(-0.27, -0.19, 0.005):
    riga = []
    for a in range(-40, 21, 5):
        c = contorno(gy, a)
        if c is None: continue
        d = distacco(*c)
        if d is not None and d > 0.005: riga.append((a, round(d * 1000, 1)))
    if riga: print("   y %.3f: %s" % (gy, riga))
