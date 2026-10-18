"""Controllo dei sostegni della sala della torre: ogni pezzo della geometria (ogni parte staccata di ogni oggetto:
canali, tubi, travi, piattaforme, ringhiere, lampade...) deve essere retto, cioè collegato, toccando altri pezzi
a pochi centimetri, fino al pavimento del fondo, ai muri o al soffitto. Stampa i gruppi di pezzi che restano
sospesi nel vuoto (con dove sono e quanto sono grandi) e li scrive in un JSON; esce con 1 se ce n'è almeno uno.
Versione per le proposte dell'inseguimento: i limiti della sala vengono da inseguimento_<v>_luci.json (info.limiti).
Uso: /home/user/tools/blender-venv/bin/python tools/blender/inseguimento_sostegni.py <blend> <luci.json>"""
import bpy, bmesh, sys, os, json
from collections import defaultdict
from mathutils import Vector
from mathutils.bvhtree import BVHTree

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
args = [a for a in sys.argv[1:] if not a.startswith('-')]
blend, luci = args[-2], args[-1]
uscita = None
TOLL = 0.06            # due pezzi si toccano se sono a meno di 6 cm
CELLA = 2.0
bpy.ops.wm.open_mainfile(filepath=blend)
XI0, YI0, XI1, YI1, FONDO, H = json.load(open(luci))['info']['limiti']


def da_saltare(o):
    n = o.name
    # i prop (appoggiati, con la loro scatola di collisione), l'acqua, la Polaroid: non sono struttura
    return o.type != 'MESH' or n.startswith(('prop_', 'acqua', 'torre_polaroid')) or 'convcolonly' in n


# --- le parti staccate di ogni oggetto
isole = []        # (oggetto, vertici, bvh, min, max)
for o in bpy.data.objects:
    if da_saltare(o):
        continue
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    bm.verts.ensure_lookup_table()
    padre = list(range(len(bm.verts)))

    def trova(i):
        while padre[i] != i:
            padre[i] = padre[padre[i]]
            i = padre[i]
        return i
    for e in bm.edges:
        a, b = trova(e.verts[0].index), trova(e.verts[1].index)
        if a != b:
            padre[a] = b
    facce = defaultdict(list)
    for f in bm.faces:
        facce[trova(f.verts[0].index)].append([v.index for v in f.verts])
    for radice, ff in facce.items():
        idx = sorted({i for f in ff for i in f})
        mappa = {i: k for k, i in enumerate(idx)}
        vv = [bm.verts[i].co.copy() for i in idx]
        bvh = BVHTree.FromPolygons(vv, [[mappa[i] for i in f] for f in ff])
        lo = Vector((min(v.x for v in vv), min(v.y for v in vv), min(v.z for v in vv)))
        hi = Vector((max(v.x for v in vv), max(v.y for v in vv), max(v.z for v in vv)))
        isole.append((o.name, vv, bvh, lo, hi))
    bm.free()
print('parti:', len(isole))

# --- chi tocca chi
griglia = defaultdict(list)
for k, (_, _, _, lo, hi) in enumerate(isole):
    for i in range(int((lo.x - TOLL) // CELLA), int((hi.x + TOLL) // CELLA) + 1):
        for j in range(int((lo.y - TOLL) // CELLA), int((hi.y + TOLL) // CELLA) + 1):
            for m in range(int((lo.z - TOLL) // CELLA), int((hi.z + TOLL) // CELLA) + 1):
                griglia[(i, j, m)].append(k)
coppie = set()
for cella in griglia.values():
    for a in range(len(cella)):
        for b in range(a + 1, len(cella)):
            coppie.add((cella[a], cella[b]))


def vicini(a, b):
    _, va, ba, la, ha = isole[a]
    _, vb, bb, lb, hb = isole[b]
    lo = Vector((max(la.x, lb.x), max(la.y, lb.y), max(la.z, lb.z))) - Vector((TOLL,) * 3)
    hi = Vector((min(ha.x, hb.x), min(ha.y, hb.y), min(ha.z, hb.z))) + Vector((TOLL,) * 3)
    if lo.x > hi.x or lo.y > hi.y or lo.z > hi.z:
        return False
    dentro = lambda v: lo.x <= v.x <= hi.x and lo.y <= v.y <= hi.y and lo.z <= v.z <= hi.z
    for vs, bvh in ((va, bb), (vb, ba)):
        for v in vs:
            if dentro(v) and bvh.find_nearest(v, TOLL)[0] is not None:
                return True
    return bool(ba.overlap(bb))


lati = defaultdict(set)
for a, b in coppie:
    if vicini(a, b):
        lati[a].add(b)
        lati[b].add(a)

# --- da terra in su: il guscio della sala (fondo, muri, soffitto) è ciò che esce dall'interno; il resto
# deve toccarlo, direttamente o attraverso altri pezzi
M = 0.01
ancorate = [k for k, (_, _, _, lo, hi) in enumerate(isole)
            if lo.z < FONDO - M or hi.z > H + M or lo.x < XI0 - M or hi.x > XI1 + M or lo.y < YI0 - M or hi.y > YI1 + M]
retto = set(ancorate)
coda = list(ancorate)
while coda:
    k = coda.pop()
    for n in lati[k]:
        if n not in retto:
            retto.add(n)
            coda.append(n)

# --- i sospesi, a gruppi di pezzi che si toccano tra loro
visti = set()
sospesi = []
for k in range(len(isole)):
    if k in retto or k in visti:
        continue
    gruppo, coda = [], [k]
    visti.add(k)
    while coda:
        q = coda.pop()
        gruppo.append(q)
        for n in lati[q]:
            if n not in visti:
                visti.add(n)
                coda.append(n)
    lo = Vector((min(isole[q][3].x for q in gruppo), min(isole[q][3].y for q in gruppo), min(isole[q][3].z for q in gruppo)))
    hi = Vector((max(isole[q][4].x for q in gruppo), max(isole[q][4].y for q in gruppo), max(isole[q][4].z for q in gruppo)))
    nomi = sorted({isole[q][0] for q in gruppo})
    sospesi.append(dict(oggetti=nomi, parti=len(gruppo), centro=[round(v, 2) for v in (lo + hi) / 2],
                        misure=[round(v, 2) for v in hi - lo]))
sospesi.sort(key=lambda s: -s['misure'][0] * s['misure'][1] - s['misure'][2])
for s in sospesi:
    print('SOSPESO', s['oggetti'][:4], 'parti', s['parti'], 'centro', s['centro'], 'misure', s['misure'])
print(f'RISULTATO: {len(isole) - len(retto)} parti sospese in {len(sospesi)} gruppi, su {len(isole)}')
sys.exit(1 if sospesi else 0)
