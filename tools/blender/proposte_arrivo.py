"""Proposte per la tappa 7: dove si sbuca nella sala grande, al buio del blackout (solo render, non nel gioco).
Carica i GLB della sala dal progetto Godot, accende solo le luci rosse d'emergenza (posizioni da sala_dati.json),
mette la torcia del giocatore e una scia rosa fosforescente (riscontro F5) che porta verso l'area bimbi.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/proposte_arrivo.py [--prova]
Uscita: docs/proposte/tappa7/a_arrivo_sala.jpg, b_arrivo_sala.jpg"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import ambienti2_comune as C

PROVA = '--prova' in sys.argv
RADICE = C.RADICE
SALA = os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'sala')
GLB = ['sala_architettura', 'sala_area_bimbi', 'sala_cupola', 'sala_oggetti', 'sala_piscina', 'sala_torre_scivoli',
       'sala_vasca_centrale', 'sala_acqua']
C.RENDER = os.path.join(RADICE, 'docs', 'proposte', 'tappa7')
dati = json.load(open(os.path.join(RADICE, 'assets_src', 'ambiente', 'glb', 'sala', 'sala_dati.json')))


def prepara():
    C.reset()
    for g in GLB:
        bpy.ops.import_scene.gltf(filepath=os.path.join(SALA, g + '.glb'))
    for o in list(bpy.context.scene.objects):
        if o.type == 'LIGHT' or 'col' in o.name.lower().split('-')[-1] or o.name.endswith('_col'):
            bpy.data.objects.remove(o)
    for l in dati['luci']:
        if l['nome'].startswith('luce_emergenza'):
            C.luce(l['nome'], 'POINT', l['blender'], 120, (1.0, 0.07, 0.04), raggio=0.08)
    rosa = C.mat_emissivo('scia_rosa', (1.0, 0.32, 0.72), 6.0)
    return rosa


def scia(rosa, punti):
    """Gocce fosforescenti a terra lungo una spezzata (coordinate Blender)."""
    import random
    rnd = random.Random(5)
    for a, b in zip(punti, punti[1:]):
        a, b = Vector(a), Vector(b)
        n = int((b - a).length / 0.55)
        for k in range(n):
            p = a + (b - a) * (k / max(n, 1)) + Vector((rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), 0.006))
            C.disco('goccia', p, rnd.uniform(0.05, 0.11), (0, 0, 1), rosa, seg=12)


def scatta(nome, cam, mira):
    C.camera(cam, mira, lente=18)
    C.luce('torcia', 'SPOT', Vector(cam) + Vector((0.15, 0, -0.25)), 400, (1.0, 0.9, 0.75), spot=50, mira=mira, raggio=0.03)
    C.mondo((0.002, 0.002, 0.003), 1.0)
    C.imposta_render(campioni=24 if PROVA else 200, w=800 if PROVA else 1600, h=450 if PROVA else 900, esposizione=0.8)
    C.renderizza(nome + ('_prova' if PROVA else '') + '.jpg')


# A: porta di servizio nell'angolo sud-est, a terra: davanti c'è la vasca della medusa, vuota
rosa = prepara()
scia(rosa, [(14.0, -18.5, 0), (8.0, -14.0, 0), (3.5, -12.5, 0), (-2.0, -7.5, 0), (-8.0, 1.0, 0)])
scatta('a_arrivo_sala', (15.0, -19.3, 1.62), (2.0, -10.0, 1.0))
# B: serranda nell'angolo sud-ovest: la scia va a nord lungo il muro ovest, verso l'area bimbi
rosa = prepara()
scia(rosa, [(-14.0, -18.8, 0), (-17.2, -14.0, 0), (-17.4, -4.0, 0), (-17.0, 4.0, 0), (-15.5, 6.5, 0)])
scatta('b_arrivo_sala', (-14.0, -19.3, 1.62), (-16.5, -2.0, 0.8))
