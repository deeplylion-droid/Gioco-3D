"""Rigenera la medusa da zero, nell'ordine giusto, partendo da assets_src/medusa/meshy_base.glb.

  1 medusa_01_parti       saldatura, parti separate, misure dell'occhio, radici dei moncherini
  2 medusa_02_texture     base color e normal map pulite dai puntini di sporco
  2b medusa_02b_riduci    versione da gioco: ~60k triangoli, UV nuove, texture 4K cotte dalla mesh alta
  3 medusa_03_occhio      texture dell'iride, orbita, bulbo e cornea
  4 medusa_04_scheletro   ossa, pesi, shape key della campana, pose di prova
  7 medusa_07_finale      versione finita: tentacoli, ciocche, campana interna, fauce, materiali, azioni,
                          scala vera (statua alta 4,5 m)
  8 medusa_08_dettagli    texture finali 4K del corpo (ciocche, giunture, clavicole, unghie, usura leggera)
  6 medusa_06_export      assets_src/medusa/medusa.glb (+ controllo in Godot)
  R medusa_render_finale  render in luce "acquapark di notte" (lunghi: solo con --render)

Uso: flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python \
     tools/blender/medusa_tutto.py [--render] [--da PASSO]
"""
import os
import subprocess
import sys
import time

QUI = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable
PASSI = ['medusa_01_parti.py', 'medusa_02_texture.py', 'medusa_02b_riduci.py', 'medusa_03_occhio.py',
         'medusa_04_scheletro.py',
         'medusa_07_finale.py', 'medusa_08_dettagli.py', 'medusa_06_export.py']

if __name__ == '__main__':
    env = dict(os.environ, MEDUSA_ANTEPRIME='0')
    passi = PASSI + (['medusa_render_finale.py'] if '--render' in sys.argv else [])
    if '--da' in sys.argv:                       # riparte da un passo: --da medusa_02b_riduci.py
        passi = passi[passi.index(sys.argv[sys.argv.index('--da') + 1]):]
    for p in passi:
        t0 = time.time()
        print(f'== {p}', flush=True)
        r = subprocess.run([PY, os.path.join(QUI, p)], env=env)
        if r.returncode:
            sys.exit(f'{p} fallito ({r.returncode})')
        print(f'== {p}: {time.time() - t0:.0f} s', flush=True)
