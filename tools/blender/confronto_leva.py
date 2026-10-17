"""Render di confronto della leva della sala pompe, vecchia e nuova, con la stessa camera e la stessa luce
neutra, a circa 1 m, senza la grata davanti (solo per lo scatto). Uscita: docs/proposte/leva/leva_<vecchia|nuova>_vicino.jpg
Uso: /home/user/tools/blender-venv/bin/python tools/blender/confronto_leva.py [--prova]"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
from ambienti2_comune import *
import ambienti2_comune as C
import ambienti1_hq as HQ
HQ.LINK[0] = C._link
C.RENDER = os.path.join(C.RADICE, 'docs', 'proposte', 'leva')
PROVA = '--prova' in sys.argv
R_ = math.radians


def allinea_occhio(base, braccio):
    """Sposta il braccio della leva in modo che l'occhio del perno stia sul centro del perno della base."""
    bpy.context.view_layer.update()
    vs = [base.matrix_world @ v.co for v in base.data.vertices]
    xmin = min(v.x for v in vs)
    boss = [v for v in vs if v.x < xmin + 0.02]
    c = Vector(((min(v.x for v in boss) + max(v.x for v in boss)) / 2, (min(v.y for v in boss) + max(v.y for v in boss)) / 2,
                (min(v.z for v in boss) + max(v.z for v in boss)) / 2))
    occhio = braccio.matrix_world @ Vector((-0.84, 0.0, 0.148))   # occhio nel GLB, origine al centro della base
    d = c - occhio
    braccio.matrix_world = Matrix.Translation((0, d.y, d.z)) @ braccio.matrix_world
    return braccio


def scena(nuova):
    reset(); HQ._base.clear(); HQ._dim.clear(); C._img_cache.clear()
    C.SMUSSO[0] = 0.012
    muro = mat_pbr('piastrelle_muro', 'Tiles133D', color='derivate/piastrelle_sporche_Color.jpg', rough='derivate/piastrelle_sporche_Roughness.jpg')
    box('muro', (0.05, 0, 0), (0.1, 8, 4), muro, uv=2.0)   # muro est: faccia a x = 0, la stanza verso -X
    if nuova:
        db = HQ.dimensioni('leva_base'); kb = 0.55 / max(db.x, db.z)
        base = HQ.metti('LEVA_base', 'leva_base', (-db.y * kb / 2, 0, -0.464 * db.z * kb), tuple(db * kb), rot_z=R_(-90))
        dm = HQ.dimensioni('leva_maniglia'); km = 0.7 / 2.26
        lv = HQ.metti('LEVA', 'leva_maniglia', (-db.y * kb - 0.045, 0, 0), tuple(dm * km), rot=(0, R_(-25), 0),
                 rot_z=R_(90), perno=(-0.84 * km, 0, 0.148 * km))
        allinea_occhio(base, lv)
    else:
        # come in main prima del 15 ottobre: piastra e perno procedurali, braccio Meshy leva_braccio
        box('leva_piastra', (-0.02 - 0.05, 0, 0), (0.04, 0.42, 0.42), mat_pbr('ferro_arrugginito', 'Metal021'), uv=1.0)
        cilindro('leva_perno_base', (-0.08 - 0.05, 0, 0), 0.07, 0.1, mat_pbr('ruggine', 'Rust004'), asse=(1, 0, 0), seg=16)
        dl = HQ.dimensioni('leva_braccio'); kl = 1.0 / max(dl)
        HQ.metti('LEVA', 'leva_braccio', (-0.05 - 0.14, 0, 0), tuple(dl * kl), rot_z=math.pi / 2,
                 perno=(-0.41 * dl.x * kl, 0, 0.17 * dl.z * kl))
    luce('chiave', 'AREA', (-1.2, -0.8, 1.2), 120, (1, 1, 1), size=1.2, mira=(0, 0.1, 0.1))
    luce('riempimento', 'AREA', (-1.0, 1.0, 0.2), 40, (1, 1, 1), size=1.0, mira=(0, 0.1, 0.1))
    mondo((0.35, 0.35, 0.36), 0.6)
    camera((-1.3, -0.55, 0.3), (-0.08, 0.2, 0.12), lente=28)
    imposta_render(campioni=24 if PROVA else 160, w=800 if PROVA else 1600, h=450 if PROVA else 900, esposizione=0.0,
                   look='AgX - Base Contrast')
    renderizza(('leva_nuova_vicino' if nuova else 'leva_vecchia_vicino') + ('_prova' if PROVA else '') + '.jpg')


scena(False)
scena(True)
