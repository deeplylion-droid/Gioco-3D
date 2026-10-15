"""Due zampe incrociate sul petto quando la medusa e' sveglia (regola del GDD: il seno resta sempre coperto).

Nelle pose da sveglia (sveglia, insegue, fluttua, fauce_apre) le braccia sono aperte e il busto si vedrebbe:
due zampe davanti escono da sotto la campana, salgono lungo la campana e attraversano il petto in diagonale,
incrociandosi (ognuna copre il seno dell'altra parte), passano sopra la spalla e ricadono lungo la schiena.
Il percorso si calcola sulla posa di riposo (la statua), appoggiato alla superficie del busto e della campana
(raggi contro quelle sole facce, piu' lo spessore del nastro), poi segue le ossa del busto nella posa attuale.
Il nastro si gira con il lato piatto sul corpo. Uso dal passo 7: zampe_sul_petto(arm, corpo) dopo la posa dei
tentacoli che pendono.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_pose as POSE  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

BUSTO = ('colonna_1', 'colonna_2', 'petto', 'collo', 'clavicola.L', 'clavicola.R', 'campana')
# percorso della zampa che parte dalla sinistra della campana (+X) e sale alla spalla destra (-X):
# (x, z) sul davanti, poi sopra la spalla e giu' per la schiena (unita' del modello, posa statua)
DAVANTI = [(0.15, -0.52), (0.13, -0.36), (0.11, -0.2), (0.11, -0.08), (0.08, 0.0), (0.035, 0.07), (-0.015, 0.13),
           (-0.06, 0.18), (-0.105, 0.225), (-0.145, 0.265)]
SPALLA = [(-0.17, 0.0), (-0.165, 0.06)]                  # (x, y) visti dall'alto, sopra la clavicola
DIETRO = [(-0.15, 0.2), (-0.13, 0.05), (-0.12, -0.12)]   # (x, z) sulla schiena
SPESSORE = 0.03                                          # meta' spessore del nastro + aria (modello)
_cache = {}


def _bvh_busto(arm, corpo):
    """BVH delle facce del busto e della campana (niente braccia, mani, testa) nella posa di riposo."""
    if 'bvh' in _cache:
        return _cache['bvh']
    me = corpo.data
    co = coords(me)
    nomi = {vg.index: vg.name for vg in corpo.vertex_groups}
    osso = np.full(len(co), -1, np.int64)
    peso = np.zeros(len(co))
    for v in me.vertices:
        for g in v.groups:
            if g.weight > peso[v.index]:
                peso[v.index] = g.weight
                osso[v.index] = g.group
    buoni = {i for i, n in nomi.items() if n in BUSTO}
    facce = [tuple(p.vertices) for p in me.polygons if all(osso[i] in buoni for i in p.vertices)]
    bvh = BVHTree.FromPolygons([tuple(v) for v in co], facce)
    _cache['bvh'] = (bvh, co, osso, nomi)
    return _cache['bvh']


def _raggio(bvh, origine, direzione):
    hit = bvh.ray_cast(Vector(origine), Vector(direzione), 3.0)
    if hit[0] is None:
        return None, None
    return np.array(hit[0]), np.array(hit[1])


def _normale_nastro(arm, nomi):
    """Asse locale delle ossa (X o Z) perpendicolare al lato piatto del nastro, dalla mesh dei tentacoli a riposo."""
    if ('asse', nomi[0]) in _cache:
        return _cache[('asse', nomi[0])]
    ob = bpy.data.objects['Medusa_Tentacoli']
    co = coords(ob.data)
    voti = []
    for n in nomi[1:6]:
        vg = ob.vertex_groups.get(n)
        if vg is None:
            continue
        idx = [v.index for v in ob.data.vertices for g in v.groups if g.group == vg.index and g.weight > 0.6]
        if len(idx) < 12:
            continue
        P = co[idx] - co[idx].mean(0)
        w, V = np.linalg.eigh(P.T @ P)
        nrm = V[:, 0]                                    # meno varianza: lo spessore del nastro
        loc = np.array(arm.data.bones[n].matrix_local.to_3x3().inverted() @ Vector(nrm))
        voti.append(abs(loc[2]) - abs(loc[0]))
    asse = 'Z' if (np.mean(voti) if voti else 1) >= 0 else 'X'
    _cache[('asse', nomi[0])] = asse
    return asse


def _percorso_riposo(arm, corpo, s):
    """Punti (posa di riposo) del percorso sul corpo, per il lato s (+1: parte da +X e sale alla spalla -X)."""
    bvh, co, osso, nomi = _bvh_busto(arm, corpo)
    punti = []        # (punto, normale, faccia-osso)
    for x, z in DAVANTI:
        p, n = _raggio(bvh, (s * x, -1.5, z), (0, 1, 0))
        if p is not None:
            punti.append((p + n * SPESSORE, n))
    for x, y in SPALLA:
        p, n = _raggio(bvh, (s * x, y, 1.0), (0, 0, -1))
        if p is not None:
            punti.append((p + n * SPESSORE, n))
    for x, z in DIETRO:
        p, n = _raggio(bvh, (s * x, 1.5, z), (0, -1, 0))
        if p is not None:
            punti.append((p + n * SPESSORE, n))
    return punti


def _osso_piu_vicino(arm, p):
    """Osso del busto piu' vicino al punto (posa di riposo, spazio armatura)."""
    migliore, dmin = 'petto', 1e9
    for n in BUSTO:
        b = arm.data.bones[n]
        h, t = np.array(b.head_local), np.array(b.tail_local)
        ab = t - h
        u = np.clip(((p - h) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(p - (h + u * ab))
        if d < dmin:
            migliore, dmin = n, d
    return migliore


def zampe_sul_petto(arm, corpo):
    """Le due zampe piu' davanti (una per lato) incrociate sul petto, nella posa attuale dello scheletro."""
    import medusa_affacciata as AFF
    POSE.aggiorna()
    cat = AFF._catene(arm)
    zampe = []
    for i, nomi in cat.items():
        if len(nomi) < 10:
            continue
        h = np.array(arm.data.bones[nomi[0]].head_local)
        zampe.append((h[1], h[0], nomi))           # piu' davanti = y piu' piccola
    zampe.sort()
    sinistra = next((z for z in zampe if z[1] > 0), None)
    destra = next((z for z in zampe if z[1] < 0), None)
    for z, s in ((sinistra, 1.0), (destra, -1.0)):
        if z is None:
            continue
        nomi = z[2]
        rip = _percorso_riposo(arm, corpo, s)
        if len(rip) < 4:
            continue
        # dalla posa di riposo alla posa attuale con l'osso del busto piu' vicino
        pts, nrm = [], []
        for p, n in rip:
            b = _osso_piu_vicino(arm, p)
            D = arm.pose.bones[b].matrix @ arm.data.bones[b].matrix_local.inverted()
            pts.append(np.array(D @ Vector(p)))
            nrm.append(np.array(D.to_3x3() @ Vector(n)).astype(float))
        radice = np.array(arm.pose.bones[nomi[0]].head)
        percorso = [radice] + pts
        giunti = AFF.giunti_catena(percorso, [arm.data.bones[n].length for n in nomi])
        asse = _normale_nastro(arm, nomi)
        P = np.array(pts)
        for k, n in enumerate(nomi):
            a, b = giunti[k], giunti[k + 1]
            d = b - a
            m = (a + b) / 2
            j = int(np.argmin(np.linalg.norm(P - m, axis=1)))
            nn = nrm[j] / (np.linalg.norm(nrm[j]) + 1e-9)
            if asse == 'Z':
                zv = nn
            else:
                zv = np.cross(d / (np.linalg.norm(d) + 1e-9), nn)
            POSE.orienta(arm, n, Vector(a), Vector(d), Vector(zv))
