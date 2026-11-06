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


# --- uno stendardo -----------------------------------------------------------------------------------------------------
class Telo:
    def __init__(self, x, y, cima, giro, largo, alto):
        a = math.radians(giro)
        self.verso = Vector((-math.cos(a), -math.sin(a), 0))
        self.lato = Vector((-self.verso.y, self.verso.x, 0)) * -1.0
        self.c = Vector((x, y, cima))
        self.largo, self.alto, self.cima, self.giro = largo, alto, cima, giro
        self.fondo = cima - alto

    def punti(self, passo=0.15):
        out = []
        nu = max(2, int(self.largo / passo) + 1)
        nv = max(2, int(self.alto / passo) + 1)
        for i in range(nu):
            u = -self.largo / 2 + self.largo * i / (nu - 1)
            for j in range(nv):
                v = self.alto * j / (nv - 1)
                for f in (-PIEGHE, 0.0, PIEGHE):
                    out.append(self.c + self.lato * u - Vector((0, 0, v)) + self.verso * f)
        # il bastone e le corde fino a 0,8 m sotto la trave
        for i in range(30):
            u = -(self.largo / 2 + 0.1) + (self.largo + 0.2) * i / 29
            out.append(self.c + self.lato * u)
        for capo in (self.c - self.lato * (self.largo / 2 + 0.1), self.c + self.lato * (self.largo / 2 + 0.1)):
            sopra = Vector((self.c.x, capo.y, SOTTO_TRAVE))
            if abs(self.lato.x) > 0.5:
                sopra = Vector((round((capo.x - 44.0) / 4.0) * 4.0 + 44.0, capo.y, SOTTO_TRAVE))
            for k in range(40):
                p = capo.lerp(sopra, k / 39)
                if p.z < SOTTO_TRAVE - 0.8:
                    out.append(p)
        return out

    def taglia(self, p0, p1):
        """Il segmento p0-p1 passa attraverso il telo?"""
        n = self.verso
        d = p1 - p0
        den = d.dot(n)
        if abs(den) < 1e-9:
            return False
        t = (self.c - p0).dot(n) / den
        if t <= 0.02 or t >= 0.98:
            return False
        q = p0 + d * t
        u = (q - self.c).dot(self.lato)
        return abs(u) <= self.largo / 2 and self.fondo <= q.z <= self.cima

    def distanza(self, P):
        """Distanza dei punti P (N x 3) dal rettangolo del telo (meno le pieghe)."""
        c = np.array(self.c)
        L = np.array(self.lato)
        N = np.array(self.verso)
        d = P - c
        u = np.clip(d @ L, -self.largo / 2, self.largo / 2)
        z = np.clip(P[:, 2], self.fondo, self.cima)
        q = c + np.outer(u, L) + np.outer(z - c[2], [0, 0, 1])
        q[:, 2] = z
        # la proiezione sul piano: q ha la stessa componente lungo N del centro
        dd = np.linalg.norm(P - q, axis=1)
        return float(dd.min())

    def impronta(self, m=0.5):
        xs = [(self.c + self.lato * s * self.largo / 2).x for s in (-1, 1)] + [(self.c + self.verso * s * PIEGHE).x for s in (-1, 1)]
        ys = [(self.c + self.lato * s * self.largo / 2).y for s in (-1, 1)] + [(self.c + self.verso * s * PIEGHE).y for s in (-1, 1)]
        return min(xs) - m, min(ys) - m, max(xs) + m, max(ys) + m


def valuta(t, nome):
    r = {}
    # contatti con la sala
    dmin, chi = 9.0, ''
    for p in t.punti():
        h = sala.find_nearest(p, 1.0)
        if h[0] is not None and h[3] < dmin:
            dmin, chi = h[3], nomi_facce[h[2]]
    r['sala'] = (dmin, chi)
    # 2 m liberi: tubi, vasche, scoli, bacino, piattaforma della porta, scale, ripiani
    x0, y0, x1, y1 = t.impronta()
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
    rr = g['bacino']['rett']
    if rr[0] <= x1 and x0 <= rr[2] and rr[1] <= y1 and y0 <= rr[3]:
        sotto.append((g['bacino']['fondo'] + 2.0, 'bacino'))
    for (a0, b0, a1, b1, z, n) in ripiani:
        if a0 <= x1 and x0 <= a1 and b0 <= y1 and y0 <= b1 and z < t.fondo + 0.01:
            sotto.append((z + 2.0, 'ripiano ' + n))
    peggio = max(sotto) if sotto else (-99.0, '')
    r['2m'] = (t.fondo - peggio[0], peggio[1])
    # coperture dagli occhi
    cop = set()
    for k, occhi in enumerate(OCCHI):
        for e in occhi:
            for (nc, p, vv) in cose:
                if vv not in (-1, k):
                    continue
                if t.taglia(e, p):
                    cop.add('vasca %d: %s' % (k + 1, nc))
    r['coperture'] = sorted(cop)
    # lei
    lei = {}
    for st, P in pelle.items():
        lei[st] = t.distanza(P)
    r['lei'] = lei
    # quanto prende dello schermo in altezza da dove si spara
    sch = {}
    for k in range(3):
        for (np_, e) in SPARO[k]:
            a = (t.c - e).normalized()
            b = (t.c - Vector((0, 0, t.alto)) - e).normalized()
            ang = math.degrees(a.angle(b))
            dist = (t.c - Vector((0, 0, t.alto / 2)) - e).length
            sch['vasca %d %s' % (k + 1, np_)] = (ang / FOV, dist)
    r['schermo'] = sch
    return r


def passa(r):
    return r['sala'][0] >= 0.25 and r['2m'][0] >= 0.0 and not r['coperture'] and (min(r['lei'].values()) if r['lei'] else 9) >= 1.0


ORIG = {'1': (46.0, 24.6, -15.5, 90.0), '2': (72.0, 21.8, -16.0, 0.0), '3': (60.0, 12.2, -18.0, 180.0), '4': (70.0, 12.0, -17.5, 90.0)}
VISTO = {'1': [1], '2': [2], '3': [3], '4': [3]}


def prova(nome, largo, alto, cime, spost):
    x, y, cima0, giro = ORIG[nome]
    risultati = []
    for (dx, dy) in spost:
        for dc in cime:
            cima = min(cima0 + dc, SOTTO_TRAVE - 1.0)
            t = Telo(x + dx, y + dy, cima, giro, largo, alto)
            r = valuta(t, nome)
            risultati.append(((dx, dy, round(cima, 2)), r))
            if passa(r):
                return risultati, ((dx, dy, round(cima, 2)), r)
    return risultati, None


def riga(pos, r):
    lei = ', '.join('%s %.2f' % (k, v) for k, v in sorted(r['lei'].items()) if v < 3.0) or 'tutte oltre 3 m'
    sch = ', '.join('%s %d%% (%.0f m)' % (k, round(v[0] * 100), v[1]) for k, v in r['schermo'].items() if int(k[6]) in VISTO.get(NOME, []))
    return ('  posto dx %+.0f dy %+.0f cima %.2f fondo %.2f | sala %.2f m (%s) | 2 m: %+.2f (%s) | lei: %s | coperture: %s | schermo: %s' %
            (pos[0], pos[1], pos[2], pos[2] - ALTO, r['sala'][0], r['sala'][1], r['2m'][0], r['2m'][1], lei,
             '; '.join(r['coperture'][:8]) or 'nessuna', sch))


VARIANTI = {
    # come sono oggi, per tarare il controllo
    'OGGI': (3.0, 4.65, [0.0]),
    # A: 6 x 9; prima col centro dove sta oggi (cima +2,2), poi col fondo dove sta oggi (cima +4,35), poi la cima di oggi
    'A': (6.0, 9.0, [2.2, 4.35, 0.0, 1.0, 3.3]),
    # B: 3 x 11; prima con la cima di oggi, poi più su
    'B': (3.0, 11.0, [0.0, 1.0, 2.0, 3.0]),
}
SPOST_LATO_X = [(0, 0)] + [(dx, dy) for dx in (0, -4, 4, -8, 8) for dy in (0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5) if (dx, dy) != (0, 0)]
_X = [(0, 0), (0, 1), (0, -1), (0, 2), (0, -2), (0, 3), (0, -3), (4, 0), (-4, 0), (4, 2), (-4, 2), (4, -2), (-4, -2)]
SPOST_LATO_Y = [(0, 0)] + [(dx, dy) for dx in (0, -4, 4, -8, 8) for dy in (0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6) if (dx, dy) != (0, 0)]
_Y = [(0, 0), (0, 1), (0, -1), (0, 2), (0, -2), (0, 3), (0, -3), (4, 0), (-4, 0), (4, 2), (-4, 2), (4, -2), (-4, -2)]

for var, (LARGO, ALTO, cime) in VARIANTI.items():
    print('\n===== VARIANTE %s: %.0f x %.0f m =====' % (var, LARGO, ALTO))
    for NOME in ('1', '2', '3', '4'):
        giro = ORIG[NOME][3]
        spost = SPOST_LATO_X if giro == 90.0 else SPOST_LATO_Y
        tutti, buono = prova(NOME, LARGO, ALTO, cime, spost)
        print('stendardo %s:' % NOME)
        # il posto di oggi, con le cime provate
        for pos, r in tutti[:len(cime)]:
            print(riga(pos, r))
        if buono:
            print(' -> PASSA in', buono[0])
            if buono[0][:2] != (0, 0):
                print(riga(*buono))
        else:
            print(' -> NESSUN POSTO PROVATO PASSA')
