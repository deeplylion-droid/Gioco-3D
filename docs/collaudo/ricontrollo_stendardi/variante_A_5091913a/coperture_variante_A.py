"""Fattibilità di due varianti degli stendardi (richiesta del coordinatore, 6 novembre), senza scatti:
A) 6 x 9 m appesi alle stesse travi; B) 3 x 10-12 m che scendono verso l'acqua.
Per ogni posto: coperture dagli occhi (bocche, paratie, bersagli, lampade, luci verdi e rosse), distanza dalla pelle di lei
(salite nelle vasche e negli scoli, dalla mesh in posa del gioco), 2 m liberi sopra tubi/vasche/scoli e ripiani, contatti con
la sala (cavi, catene, tiranti, portale: tutto quello che c'è nelle GLB, più cavi e paralumi delle lampade appese), quanto
prende dello schermo da dove si spara. Coordinate di Blender (z in su), come i JSON della sala.
Uso: blender-venv/bin/python varianti.py <cartella pelle>"""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

RADICE = '/home/user/Gioco-3D'
DIR = os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'inseguimento')
PELLE = sys.argv[1] if len(sys.argv) > 1 else ''
SOTTO_TRAVE = -6.6
PIEGHE = 0.15
FOV = 75.0

g = json.load(open(os.path.join(DIR, 'inseguimento_gioco.json')))
luci = json.load(open(os.path.join(DIR, 'inseguimento_luci.json')))

# --- la sala: GLB + lampade appese -------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
for f in ('inseguimento_struttura.glb', 'inseguimento_tubi.glb', 'inseguimento_prop.glb', 'inseguimento_mobili.glb'):
    bpy.ops.import_scene.gltf(filepath=os.path.join(DIR, f))
verts = []
polys = []
nomi_facce = []
su_facce = []          # (centro, normale z) per i ripiani
for o in bpy.data.objects:
    if o.type != 'MESH' or o.name.startswith('acqua') or o.name.endswith('-col'):
        continue
    m = o.matrix_world
    base = len(verts)
    for v in o.data.vertices:
        verts.append(tuple(m @ v.co))
    nm = m.to_3x3().inverted().transposed()
    for p in o.data.polygons:
        polys.append(tuple(base + i for i in p.vertices))
        nomi_facce.append(o.name)
# lampade appese: il cavo dal soffitto e il paralume (sfere, come il controllo di grafica)
for (lx, ly, lz, _c) in luci['appese']:
    bm = bmesh.new()
    for k in range(24):
        z = -6.0 + (lz + 0.3 + 6.0) * k / 23.0
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.05, matrix=__import__('mathutils').Matrix.Translation((lx, ly, z)))
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.4, matrix=__import__('mathutils').Matrix.Translation((lx, ly, lz)))
    base = len(verts)
    for v in bm.verts:
        verts.append(tuple(v.co))
    for f in bm.faces:
        polys.append(tuple(base + v.index for v in f.verts))
        nomi_facce.append('lampada_appesa(%.1f,%.1f)' % (lx, ly))
    bm.free()
sala = BVHTree.FromPolygons(verts, polys)
V = np.array(verts)
# i ripiani dove si può stare: facce rivolte in su (normale z > 0,9) della struttura/mobili, sopra il fondo allagato
ripiani = []
for i, p in enumerate(polys):
    if nomi_facce[i].startswith('lampada'):
        continue
    a, b, c = V[p[0]], V[p[1]], V[p[2]]
    n = np.cross(b - a, c - a)
    ln = np.linalg.norm(n)
    if ln < 1e-9:
        continue
    n /= ln
    if n[2] > 0.9 and a[2] > -33.0:
        pts = V[list(p)]
        ripiani.append((pts[:, 0].min(), pts[:, 1].min(), pts[:, 0].max(), pts[:, 1].max(), pts[:, 2].max(), nomi_facce[i]))
print('sala: %d facce, %d ripiani' % (len(polys), len(ripiani)))

# --- lei ---------------------------------------------------------------------------------------------------------------
pelle = {}
if PELLE and os.path.isdir(PELLE):
    for f in sorted(os.listdir(PELLE)):
        if f.startswith('pelle_') and f.endswith('.txt'):
            a = np.loadtxt(os.path.join(PELLE, f))
            pelle[f[6:-4]] = np.stack([a[:, 0], -a[:, 2], a[:, 1]], axis=1)    # Godot -> Blender
print('pelle di lei:', {k: len(v) for k, v in pelle.items()})

# --- bersagli e cose da non coprire ------------------------------------------------------------------------------------
cose = []
for i, b in enumerate(luci['bersagli']):
    cose.append(('bersaglio_%d' % i, Vector(b), i // 2))
for i, p in enumerate(g['paratie']):
    c = Vector(p['pannello'])
    n = Vector(p['verso'])
    lato = Vector((-n.y, n.x, 0))
    for su in (-0.9, 0.0, 0.9):
        for dl in (-0.9, 0.0, 0.9):
            cose.append(('paratia_%d' % i, c + lato * dl + Vector((0, 0, su)), p['vasca']))
for i, l in enumerate(luci['paratie']):
    cose.append(('luce_%s_%d' % (l[1], i), Vector(l[0]), i // 2))
for i, l in enumerate(luci['appese']):
    cose.append(('lampada_appesa_%d' % i, Vector(l[:3]), -1))
for i, l in enumerate(luci['lavoro']):
    cose.append(('lampada_lavoro_%d' % i, Vector(l[:3]), -1))
BOCCHE = {'ins_A_tubo_0': (None, 0), 'ins_A_tubo_1': (0, 1), 'ins_A_scolo_0': (0, None), 'ins_A_tubo_2': (1, 2),
          'ins_A_scolo_1': (1, None), 'ins_A_tubo_3': (2, None), 'ins_A_scolo_2': (2, None)}
for nome, linea in g['tubi'].items():
    da, a = BOCCHE[nome]
    for k, q, vv in (('inizio', linea[0], da), ('fine', linea[-1], a)):
        if vv is None:
            continue
        for dz in (0.0, 0.8):
            cose.append(('bocca_%s_%s' % (nome, k), Vector(q) + Vector((0, 0, dz)), vv))


def occhi_vasca(v):
    r = v['rett']
    out = []
    # le facce interne sono a 0,18 dal rettangolo; 0,6 m dentro
    for fx in (0.0, 0.5, 1.0):
        for fy in (0.0, 0.5, 1.0):
            x = r[0] + 0.78 + (r[2] - r[0] - 1.56) * fx
            y = r[1] + 0.78 + (r[3] - r[1] - 1.56) * fy
            out.append(Vector((x, y, v['fondo'] + 1.65)))
    return out


OCCHI = [occhi_vasca(v) for v in g['vasche']]
# dove si spara: davanti al bersaglio giusto (come nel ricontrollo), più il mezzo
SPARO = []
for k, v in enumerate(g['vasche']):
    r = v['rett']
    c = Vector(((r[0] + r[2]) / 2, (r[1] + r[3]) / 2, v['fondo'] + 1.65))
    b = Vector(g['paratie'][k * 2]['bersaglio'])
    d = Vector((b.x - c.x, b.y - c.y, 0))
    SPARO.append([('mezzo', c), ('davanti_al_bersaglio', c + d * 0.55)])



# --- gli stendardi veri della variante A (stendardi.glb di fb65ad3d), in coordinate di Blender ---------------------
sys.path.insert(0, '/tmp/claude-0/-home-user-Gioco-3D/bf16885c-6f33-5efb-8329-4dc8709ca165/scratchpad/sag')
from glbn import nodi
GLB = sys.argv[2] if len(sys.argv) > 2 else 'st_A.glb'
NN = nodi(GLB)
def b(T):
    V = T.reshape(-1, 3)
    return np.stack([V[:, 0], -V[:, 2], V[:, 1]], axis=1)
VISTO = {1: [1], 2: [2], 3: [3], 4: [3]}
for s in (1, 2, 3, 4):
    pezzi = {k: b(T) for k, T in NN.items() if k.startswith('stendardo_%d' % s)}
    tutti = np.concatenate(list(pezzi.values()))
    stoffa = pezzi['stendardo_%d' % s]
    # contatti con la sala: ogni vertice (le corde vicino alla trave escluse: lì toccano apposta)
    dmin, chi, dove = 9.0, '', None
    for k, P in pezzi.items():
        legato = '_corda_' in k
        for p in P[::2]:
            if legato and p[2] > SOTTO_TRAVE - 0.8:
                continue
            h = sala.find_nearest(Vector(p), 1.0)
            if h[0] is not None and h[3] < dmin:
                dmin, chi, dove = h[3], nomi_facce[h[2]], p
    # 2 m liberi sotto l'impronta della stoffa
    x0, y0 = stoffa[:, 0].min() - 0.5, stoffa[:, 1].min() - 0.5
    x1, y1 = stoffa[:, 0].max() + 0.5, stoffa[:, 1].max() + 0.5
    fondo = tutti[:, 2].min()
    sotto = []
    for nt, linea in g['tubi'].items():
        for q in linea:
            if x0 <= q[0] <= x1 and y0 <= q[1] <= y1:
                sotto.append((q[2] + 0.8 + 2.0, nt))
    for k, vv in enumerate(g['vasche']):
        rr = vv['rett']
        if rr[0] <= x1 and x0 <= rr[2] and rr[1] <= y1 and y0 <= rr[3]:
            sotto.append((vv['fondo'] + 2.0, 'vasca_%d' % (k + 1)))
    for k, vv in enumerate(g['scolo']):
        rr = vv['rett']
        if rr[0] <= x1 and x0 <= rr[2] and rr[1] <= y1 and y0 <= rr[3]:
            sotto.append((vv['fondo'] + 2.0, 'scolo_%d' % k))
    for (a0, b0, a1, b1, z, n) in ripiani:
        if a0 <= x1 and x0 <= a1 and b0 <= y1 and y0 <= b1 and z < fondo + 0.01:
            sotto.append((z + 2.0, 'ripiano ' + n))
    peggio = max(sotto) if sotto else (-99.0, '')
    # coperture: raggi dagli occhi alle cose della stessa vasca (e a tutte le lampade), contro tutti i triangoli
    T = np.concatenate([NN[k] for k in NN if k.startswith('stendardo_%d' % s)])
    TV = b(T)
    tb = BVHTree.FromPolygons([tuple(v) for v in TV], [(3 * i, 3 * i + 1, 3 * i + 2) for i in range(len(T))])
    cop = set()
    for k, occhi in enumerate(OCCHI):
        for e in occhi:
            for (nc, p, vv) in cose:
                if vv not in (-1, k):
                    continue
                d = p - e
                h = tb.ray_cast(e, d.normalized(), d.length - 0.05)
                if h[0] is not None:
                    cop.add('vasca %d: %s' % (k + 1, nc))
    # lei: distanza della pelle da ogni pezzo
    lei = {}
    for st_, P in pelle.items():
        dd = 9.0
        lo = tutti.min(0) - 3.0
        hi = tutti.max(0) + 3.0
        Q = P[np.all((P >= lo) & (P <= hi), axis=1)]
        for q in Q:
            h = tb.find_nearest(Vector(q), 3.0)
            if h[0] is not None:
                dd = min(dd, h[3])
        lei[st_] = dd
    # schermo da dove si spara: l'angolo fra la cima e il fondo della stoffa al centro
    c = stoffa.mean(0)
    cima = np.array([c[0], c[1], stoffa[:, 2].max()])
    fon = np.array([c[0], c[1], stoffa[:, 2].min()])
    sch = []
    for k in VISTO[s]:
        for (nome_, e) in SPARO[k - 1]:
            ee = np.array(e)
            a = (cima - ee) / np.linalg.norm(cima - ee)
            bb = (fon - ee) / np.linalg.norm(fon - ee)
            ang = math.degrees(math.acos(max(-1, min(1, float(a @ bb)))))
            sch.append('vasca %d %s %d%% a %.0f m' % (k, nome_, round(ang / FOV * 100), np.linalg.norm(c - ee)))
    print('stendardo %d: fondo %.2f, cima %.2f' % (s, fondo, tutti[:, 2].max()))
    print('   sala: %.2f m (%s, in %s)' % (dmin, chi, np.round(dove, 2) if dove is not None else '-'))
    print('   2 m liberi: %+.2f (%s)' % (fondo - peggio[0], peggio[1]))
    print('   coperture: %s' % ('; '.join(sorted(cop)) or 'nessuna'))
    print('   lei: %s' % ', '.join('%s %.2f' % (k, v) for k, v in sorted(lei.items())))
    print('   schermo: %s' % '; '.join(sch))
