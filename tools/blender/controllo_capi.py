"""Controllo dei capi dei tubi (squadra ambienti-2): rifà la scena di un generatore (torre_proposte.py o
inseguimento_proposte.py, nel gioco) registrando ogni tubo, condotta e cilindro grosso che costruisce, poi per
ogni capo guarda se subito oltre (lungo il tubo) c'è una superficie che gli viene incontro (un muro, il
pavimento, il fianco di un altro tubo, una macchina) a meno di 10 cm, senza contare il tappo del tubo stesso. Se
non c'è, il tubo finisce nel vuoto ("non arriva da nessuna parte"). Gli scivoli invece possono finire aperti: basta
che sotto il capo, entro un metro, ci sia dove si arriva (una pedana, una vasca).
Il generatore riscrive i suoi GLB del gioco come sempre (identici, è deterministico): il blend va in una
cartella temporanea.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/controllo_capi.py torre|inseguimento [raggio_minimo]"""
import os
import runpy
import sys
import tempfile

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import ambiente_kit as K        # noqa: E402
from mathutils import Vector    # noqa: E402
from mathutils.bvhtree import BVHTree   # noqa: E402

quale = sys.argv[1] if len(sys.argv) > 1 else 'torre'
R_MIN = float(sys.argv[2]) if len(sys.argv) > 2 else 0.1
OLTRE, TOLL = 0.02, 0.10

registro = []        # (tipo, punti, raggio)
_tubo = K.Costruttore.tubo
_cilindro = K.Costruttore.cilindro
_tubo_scivolo = K.tubo_scivolo


def tubo(self, punti, r, mat, *a, **k):
    registro.append(('tubo', [Vector(p) for p in punti], r))
    return _tubo(self, punti, r, mat, *a, **k)


def cilindro(self, a, b, r, mat, *x, **k):
    if r >= R_MIN:
        registro.append(('cilindro', [Vector(a), Vector(b)], r))
    return _cilindro(self, a, b, r, mat, *x, **k)


def tubo_scivolo(mats, pts, *a, **k):
    registro.append(('scivolo', [Vector(p) for p in pts], k.get('r', 0.45)))
    return _tubo_scivolo(mats, pts, *a, **k)


K.Costruttore.tubo = tubo
K.Costruttore.cilindro = cilindro
K.tubo_scivolo = tubo_scivolo

cartella = tempfile.mkdtemp(prefix='capi_')
script = os.path.join(QUI, 'torre_proposte.py' if quale == 'torre' else 'inseguimento_proposte.py')
blend = os.path.join(cartella, 'scena.blend')
sys.argv = [script, 'A', '--gioco', '--blend', blend]
import bpy  # noqa: E402

runpy.run_path(script, run_name='__main__')

def _vicini(t, q, raggio):
    # i punti più vicini nei dintorni (find_nearest_range non dà le normali: si guarda il più vicino per cubetto)
    out = []
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                h = t.find_nearest(q + Vector((dx, dy, dz)) * raggio * 0.5, raggio)
                if h[0] is not None and (h[0] - q).length < raggio:
                    out.append(h)
    return out


alberi = []
for o in bpy.data.objects:
    if o.type != 'MESH' or len(o.data.polygons) == 0:
        continue
    if o.name.startswith('acqua') or 'convcolonly' in o.name:
        continue
    m = o.matrix_world
    vs = [m @ v.co for v in o.data.vertices]
    alberi.append((o.name, BVHTree.FromPolygons(vs, [list(p.vertices) for p in o.data.polygons])))

liberi = []
for (tipo, punti, r) in registro:
    if len(punti) < 2:
        continue
    for capo, prima in ((punti[0], punti[1]), (punti[-1], punti[-2])):
        d = capo - prima
        if d.length < 1e-6:
            continue
        d.normalize()
        q = capo + d * OLTRE
        tocca = False
        for (_, t) in alberi:
            for hit in _vicini(t, q, TOLL):
                # una superficie che viene incontro al tubo (non il suo tappo, che guarda nello stesso verso)
                if hit[1].dot(d) < -0.3:
                    tocca = True
                    break
            if tocca:
                break
        if not tocca:
            # il capo dentro un muro o un altro pezzo: andando avanti si esce da una superficie
            for (_, t) in alberi:
                h = t.ray_cast(q, d, 1.0)
                if h[0] is not None and h[1].dot(d) > 0.3:
                    tocca = True
                    break
        if not tocca and tipo == 'scivolo':
            # uno scivolo può finire aperto, sopra dove si arriva
            for (_, t) in alberi:
                h = t.ray_cast(capo + Vector((0, 0, -0.1)) * 0 + d * 0.3, Vector((0, 0, -1)), 1.5 + r)
                if h[0] is not None:
                    tocca = True
                    break
        if not tocca:
            liberi.append((tipo, r, capo, d, 0.0))


# si guardano i tubi veri: quelli di servizio (tubo, da 10 cm di raggio), gli scivoli e le condotte (cilindri
# orizzontali da 50 cm); gambe, montanti e travi si innestano nella struttura e li conta torre_sostegni.py
liberi = [x for x in liberi if (x[0] == 'tubo' and x[1] >= 0.1) or x[0] == 'scivolo'
          or (x[0] == 'cilindro' and x[1] >= 0.5 and abs(x[3].z) < 0.5)]
print(f'capi controllati: {2 * len(registro)}, liberi: {len(liberi)}')
for (tipo, r, capo, d, vicino) in sorted(liberi, key=lambda x: (x[0], x[2].z)):
    print(f'  {tipo:9s} r {r:.2f} capo ({capo.x:.2f}, {capo.y:.2f}, {capo.z:.2f}) verso ({d.x:.2f}, {d.y:.2f}, {d.z:.2f})')
