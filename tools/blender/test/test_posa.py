"""Test di tools/blender/posa.py su una scena finta (pavimento, muro, soffitto).
Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python tools/blender/test/test_posa.py"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import posa  # noqa: E402

ok = falliti = 0


def check(c, cosa):
    global ok, falliti
    if c:
        ok += 1
        print('  ok   ', cosa)
    else:
        falliti += 1
        print('  FALLITO', cosa)


def scatola(nome, dove, misure):
    bpy.ops.mesh.primitive_cube_add(size=1, location=dove)
    o = bpy.context.active_object
    o.name = nome
    o.scale = misure
    bpy.ops.object.transform_apply(scale=True)
    return o


bpy.ops.wm.read_factory_settings(use_empty=True)
pav = scatola('Pavimento', (0, 0, -0.5), (20, 20, 1))      # cima a z 0
muro = scatola('Muro', (0, 5.5, 2), (20, 1, 4))           # faccia a y 5
scatola('Soffitto', (0, 0, 4.5), (20, 20, 1))             # sotto a z 4

sedia = scatola('Sedia', (1, 1, 1.3), (0.5, 0.5, 0.8))
check(posa.appoggia_a_terra(sedia, lega=True) == pav and abs(min((sedia.matrix_world @ Vector(c)).z for c in sedia.bound_box)) < 1e-4,
      'la sedia scende sul pavimento')
check(sedia.parent == pav, 'con lega diventa figlia del pavimento')
pav.location.z += 0.2
bpy.context.view_layer.update()
check(abs(min((sedia.matrix_world @ Vector(c)).z for c in sedia.bound_box) - 0.2) < 1e-4, 'il pavimento sale e la sedia lo segue')
pav.location.z -= 0.2
bpy.context.view_layer.update()

quadro = scatola('Quadro', (0, 4.0, 1.6), (0.6, 0.04, 0.4))
check(posa.fissa_al_muro(quadro, (0, -1, 0)) == muro and abs(max((quadro.matrix_world @ Vector(c)).y for c in quadro.bound_box) - 5.0) < 1e-4,
      'il retro del quadro sul muro (y 5)')
dentro = scatola('Dentro', (2, 5.1, 1.0), (0.3, 0.3, 0.3))
posa.fissa_al_muro(dentro, (0, -1, 0))
check(abs(max((dentro.matrix_world @ Vector(c)).y for c in dentro.bound_box) - 5.0) < 1e-4, 'un oggetto un po\' dentro il muro torna a filo')

plaf = scatola('Plafoniera', (-2, 0, 3.0), (0.5, 0.5, 0.1))
posa.fissa_al_soffitto(plaf)
check(abs(max((plaf.matrix_world @ Vector(c)).z for c in plaf.bound_box) - 4.0) < 1e-4, 'la plafoniera sale al soffitto')

bpy.ops.object.empty_add(location=(-3, 1, 3.5))
gancio = bpy.context.active_object
lampada = scatola('Lampada', (0, 0, 1), (0.2, 0.2, 0.3))
posa.appendi_a(lampada, gancio)
check(lampada.parent == gancio and abs(max((lampada.matrix_world @ Vector(c)).z for c in lampada.bound_box) - 3.5) < 1e-4,
      'la lampada è appesa al gancio, la cima sul gancio')

check(posa.tocca(sedia), 'tocca(): la sedia appoggiata tocca il pavimento')
volante = scatola('Volante', (5, -3, 2), (0.3, 0.3, 0.3))
check(not posa.tocca(volante), 'tocca(): una scatola a mezz\'aria no')
check(posa.appoggia_a_terra(scatola('Fuori', (30, 30, 1), (0.3, 0.3, 0.3))) is None, 'fuori dal pavimento: None, resta dov\'è')

print('RISULTATO: %d controlli ok, %d falliti' % (ok, falliti))
sys.exit(1 if falliti else 0)
