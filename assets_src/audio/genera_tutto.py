"""Rigenera tutti i suoni del gioco, il catalogo per Godot, le licenze e le anteprime della
scena. Le anteprime delle proposte per l'utente (proposta_*.ogg) restano com'erano quando le ha
ascoltate: si rifanno solo a mano (genera_anteprima.py proposte, genera_proposte.py), e con i
fondi di adesso non verrebbero uguali.

Uso (dalla radice del repository):
    /home/user/tools/blender-venv/bin/python assets_src/audio/genera_tutto.py
Serve ffmpeg con libvorbis. I file vanno in godot/audio/; poi Godot li importa da solo
(o con: godot --headless --path godot --import). Tutto è deterministico (semi fissi).
"""
import json
import os
import sys
import time

import catalogo
import genera_ambiente
import genera_bambini
import genera_anteprima
import genera_effetti
import genera_enigmi
import genera_giocatore
import genera_interfaccia
import genera_lei
import genera_musica
import genera_piscina
import genera_tecnici
import genera_squalo
import genera_torre
import licenze
from comune import AUDIO, REGISTRO

# i passi del giocatore (scarpe di gomma, scelta A del 30 ottobre) li fa assets_src/passi/genera_passi.py
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'passi'))
import genera_passi  # noqa: E402

if __name__ == '__main__':
    t0 = time.time()
    # (il registro non si cancella: dentro ci sono anche i suoni dei generatori che qui non si lanciano, come quelli
    # dell'inseguimento, del tunnel, della voce dello squalo e del getto B dello zaino, e senza le loro voci LICENZE.md
    # perdeva 40 file; ogni generatore lanciato riscrive le voci dei suoi file)
    for m in (genera_ambiente, genera_giocatore, genera_effetti, genera_musica, genera_interfaccia,
              genera_tecnici, genera_lei, genera_piscina, genera_torre, genera_squalo, genera_bambini,
              genera_enigmi):
        m.main()
        if m is genera_giocatore:
            genera_passi.nel_gioco()
    # le voci dei file che non ci sono più
    with open(REGISTRO, encoding='utf-8') as f:
        reg = json.load(f)
    via = [k for k in reg if not os.path.exists(os.path.join(AUDIO, k + '.ogg'))]
    if via:
        print('Tolti dal registro (file che non ci sono più):', ', '.join(via))
        with open(REGISTRO, 'w', encoding='utf-8') as f:
            json.dump({k: v for k, v in reg.items() if k not in via}, f, indent=1, ensure_ascii=False)
    catalogo.main()
    licenze.main()
    genera_anteprima.main(('sala', 'tecnici', 'lei', 'pioggia', 'passi', 'cancello'))
    print(f'Fatto in {time.time() - t0:.0f} s')
