"""Suoni della sala della torre (dopo la tappa 8), scelti dall'utente il 16 ottobre fra le proposte
di genera_proposte.py: gli stessi suoni delle anteprime approvate (stesso seme, stessa
normalizzazione; le funzioni stanno in genera_proposte.py, con le versioni scartate).

- portone_torre_apre (motore, proposta A): la serratura che scatta (0 s), il motore che parte, il
  portone pesante che scorre liscio sui rulli da 0,7 s (giunti della rotaia, la lastra che
  rimbomba), sbatte a fine corsa a 6,4 s e il motore si spegne (8,5 s in tutto). Mono, sul portone:
  l'animazione deve seguire questi tempi (vedi PORTONE_PARTE e PORTONE_ARRIVA in audio.gd).
- scivolo_loop: il giocatore che scivola sull'acquascivolo bagnato. Il velo d'acqua che fruscia
  sotto di te, il corpo che sfrega sulla plastica cava (il tubo che rimbomba basso), gorgoglii e
  goccioline. Nel gioco volume e tono salgono con la velocità (audio.gd).
- atterraggio_scivolo_01..02: atterri su uno scivolo, il tonfo sordo della plastica cava e lo
  schiaffo dell'acqua.
Uscita: godot/audio/torre/.
"""
import numpy as np

import genera_proposte as gp
from comune import salva
from genera_ambiente import bollicina
from genera_giocatore import strato_bagnato
from lib_audio import (bp, brown, comb, env_ad, env_points, eq, fade, hp, lp, make_loop, mix_into, n_of,
                       resonator_bank, smooth_noise, white)

CART = 'torre'


def scivolo_loop(rng, dur=3.0, xf=0.6):
    """Scivolare sull'acqua: velo d'acqua, sfregamento sulla plastica cava, gorgoglii, goccioline."""
    n = n_of(dur + xf)
    velo = bp(white(n, rng), 1400, 7500, 2) * (0.7 + 0.3 * smooth_noise(n, 9, rng))
    velo = eq(velo, [('peak', 3200, 0.8, 3)])
    # il corpo sulla plastica: rombo basso che il tubo fa risuonare
    rombo = lp(brown(n, rng), 320, 2) * (0.75 + 0.25 * smooth_noise(n, 4, rng))
    rombo = comb(rombo, 1 / 145, 0.55, 0.3) * 0.9
    gorgo = bp(white(n, rng), 280, 1100, 2) * np.clip(smooth_noise(n, 14, rng), 0, None) * 0.9
    out = velo * 0.45 + rombo + gorgo * 0.5
    for _ in range(int((dur + xf) * 16)):
        f0, tau = rng.uniform(900, 3600), rng.uniform(0.005, 0.016)
        mix_into(out, bollicina(rng, f0, tau, rise=0.8) * rng.uniform(0.04, 0.14), n_of(rng.uniform(0, dur + xf - 0.05)))
    return make_loop(hp(out, 45), dur, xf)


def atterraggio_scivolo(rng, i):
    """Atterri sullo scivolo: la plastica cava che rimbomba e l'acqua che schiaffeggia."""
    out = np.zeros(n_of(0.9))
    k = n_of(0.01)
    e = np.zeros(n_of(0.6))
    e[:k] = white(k, rng) * env_points([(0, 1), (0.01, 0)], k)
    modi = np.array([118, 205, 330, 470, 690]) * rng.uniform(0.94, 1.06)
    tonfo = resonator_bank(lp(e, 1800), modi, [0.22, 0.16, 0.1, 0.07, 0.05], [1.0, 0.7, 0.45, 0.3, 0.2])
    mix_into(out, tonfo / max(np.abs(tonfo).max(), 1e-9), 0)
    mix_into(out, lp(brown(n_of(0.25), rng), 200) * env_ad(n_of(0.25), 0.002, 0.2) * 0.8, 0)
    mix_into(out, strato_bagnato(rng, 2.2, goccioline=True) * 1.4, 0)
    mix_into(out, strato_bagnato(rng, 1.4, goccioline=True), n_of(0.04 + 0.02 * i))
    return fade(out, 0, 0.1)


def main():
    print('Sala della torre')
    # come in proposta_portone_torre_a.ogg (seme 1608)
    rng = np.random.default_rng(1608)
    salva(CART, 'portone_torre_apre', gp.portone_torre_apre_a(rng), loudness=-14, corto=True, qualita=4,
          nota='motore (A, scelto il 16 ottobre): il portone si muove da 0,7 s e sbatte a 6,4 s')
    rng = np.random.default_rng(1810)
    salva(CART, 'scivolo_loop', scivolo_loop(rng), loudness=-20, qualita=4,
          nota="scivolare sull'acquascivolo bagnato; volume e tono seguono la velocità")
    for i in range(2):
        salva(CART, f'atterraggio_scivolo_{i + 1:02d}', atterraggio_scivolo(rng, i), loudness=-16, corto=True,
              qualita=3)


if __name__ == '__main__':
    main()
