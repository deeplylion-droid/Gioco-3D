"""Rigenera tutti i suoni del gioco, il catalogo per Godot, le licenze e le anteprime della
scena. Le anteprime delle proposte per l'utente (proposta_*.ogg) restano com'erano quando le ha
ascoltate: si rifanno solo a mano (genera_anteprima.py proposte, genera_proposte.py), e con i
fondi di adesso non verrebbero uguali.

Uso (dalla radice del repository):
    /home/user/tools/blender-venv/bin/python assets_src/audio/genera_tutto.py
Serve ffmpeg con libvorbis. I file vanno in godot/audio/; poi Godot li importa da solo
(o con: godot --headless --path godot --import). Tutto è deterministico (semi fissi).
"""
import os
import time

import catalogo
import genera_ambiente
import genera_anteprima
import genera_effetti
import genera_giocatore
import genera_interfaccia
import genera_lei
import genera_musica
import genera_piscina
import genera_tecnici
import genera_torre
import licenze
from comune import REGISTRO

if __name__ == '__main__':
    t0 = time.time()
    if os.path.exists(REGISTRO):
        os.remove(REGISTRO)
    for m in (genera_ambiente, genera_giocatore, genera_effetti, genera_musica, genera_interfaccia,
              genera_tecnici, genera_lei, genera_piscina, genera_torre):
        m.main()
    catalogo.main()
    licenze.main()
    genera_anteprima.main(('sala', 'tecnici', 'lei', 'pioggia', 'passi'))
    print(f'Fatto in {time.time() - t0:.0f} s')
