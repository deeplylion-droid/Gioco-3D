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
# il distacco dell'indice (dito 0) a ogni angolo, alle tre quote, e il punto del guanto colpito
for dy in (-0.002, 0.0, 0.002):
    riga = []
    for a in range(-25, 179, 3):
        c = contorno(Y_INDICE + dy, a)
        if c is None: continue
        d = distacco(*c)
        riga.append("%d:%s" % (a, "-" if d is None else "%.1f" % (d * 1000)))
    print("INDICE quota %+.0f mm: %s" % (dy * 1000, " ".join(riga)))
    # il punto dell'impugnatura dove il distacco supera 2 mm, in glTF
    for a in range(-25, 179, 3):
        c = contorno(Y_INDICE + dy, a)
        if c is None: continue
        d = distacco(*c)
        if d is not None and d > 0.002:
            print("   %d gradi: %.1f mm, impugnatura in glTF %s" % (a, d * 1000, tuple(round(x, 4) for x in b2g(c[0]))))
