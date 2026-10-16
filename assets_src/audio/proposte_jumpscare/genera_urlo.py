"""PROPOSTA (riscontro 3 della v0.3.2): l'urlo del jumpscare di lei, forte e distorto "alla FNAF",
tutto di sintesi (niente audio da internet). Due versioni, una per video:
- A (glitch): urlo stridulo che si inceppa come un file rotto: pezzetti ripetuti, buchi, salti di
  tono, bitcrush pesante. I glitch cadono negli stessi istanti dei glitch dello schermo
  (GLITCH qui sotto = proposte/medusa/jumpscare.gd).
- B (urlo): un urlo unico che sale, rauco e saturato, con meno inceppamenti: più "voce".
Tempi: l'urlo parte a 0,08 s dall'inizio del morso, è al massimo al lampo rosso (1,0 s) e si
tronca a 2,0 s, quando lo schermo è nero.
Uso: /home/user/tools/blender-venv/bin/python genera_urlo.py
Uscita: assets_src/audio/proposte_jumpscare/{a,b}/lei_urlo.ogg (non va nel gioco finché l'utente
non sceglie).
"""
import os
import sys

import numpy as np

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(QUI))
from lib_audio import (SR, bitcrush, bp, env_points, f32, fade, hp, limiter, lp, mix_into, n_of,  # noqa: E402
                       normalize_lufs, smooth_noise, t_axis, white, write_ogg)

DUR = 2.0
INIZIO = 0.08
# Istanti dei glitch (s dall'inizio del morso), uguali a quelli dello schermo nella versione A.
GLITCH = [0.14, 0.33, 0.52, 0.66, 0.8, 1.0, 1.12, 1.31, 1.5, 1.68]


def voce(rng, n, f0, ruvidita):
    """Sorgente: denti di sega stonati sulla curva di tono f0, con jitter e vibrato veloce."""
    tt = t_axis(n)
    jitter = smooth_noise(n, 90.0, rng) * 0.035 * ruvidita
    vib = np.sin(2 * np.pi * 17.0 * tt) * 0.045
    out = np.zeros(n)
    for mul, g in [(1.0, 1.0), (0.991, 0.8), (1.012, 0.7), (1.5, 0.35), (2.02, 0.25), (0.5, 0.4)]:
        f = f0 * mul * (1 + jitter + vib)
        fase = np.cumsum(f) / SR
        out += (2.0 * (fase % 1.0) - 1.0) * g
    return out


def formanti(x, vocale):
    """Bocca spalancata: bande di una "A" urlata (o di una "I" stridula) sommate."""
    bande = {'a': [(700, 1100, 1.0), (1100, 1600, 0.9), (2400, 3000, 0.6), (3300, 4200, 0.4)],
             'i': [(250, 400, 0.5), (2200, 3000, 1.0), (3000, 3800, 0.8), (4200, 5200, 0.4)]}[vocale]
    return sum(bp(x, lo, hi, 2) * g for lo, hi, g in bande)


def urlo(rng, versione):
    n = n_of(DUR)
    tt = t_axis(n)
    k = np.clip((tt - INIZIO) / 0.9, 0, 1)
    if versione == 'a':
        f0 = 420 + 380 * k ** 0.6
    else:
        f0 = 330 + 520 * k ** 0.8
    # Rauco: il tono "si rompe" a tratti verso l'ottava sotto.
    rotture = (smooth_noise(n, 6.0, rng) > 0.55).astype(float)
    f0 = f0 * (1 - 0.35 * lp(rotture, 30, 1))
    src = voce(rng, n, f0, 1.4 if versione == 'a' else 1.0)
    x = formanti(src, 'a') * 0.7 + formanti(src, 'i') * 0.5
    # Fiato strozzato e graffiante sopra la voce.
    x += bp(white(n, rng), 1800, 7500, 2) * 0.5 * (0.6 + 0.4 * smooth_noise(n, 25.0, rng))
    # Modulazione ad anello lenta e saturazione forte: il suono "robotico" e rotto.
    x *= 1.0 + 0.6 * np.sin(2 * np.pi * (55 if versione == 'a' else 38) * tt)
    x = np.tanh(x / (np.abs(x).max() + 1e-9) * (9.0 if versione == 'a' else 6.0))
    x = bitcrush(x, 5 if versione == 'a' else 7, 4 if versione == 'a' else 2)
    x = hp(lp(x, 9000, 2), 140, 2)
    e = env_points([(0, 0), (INIZIO, 0), (INIZIO + 0.015, 1.0), (0.95, 1.0), (1.0, 1.15), (1.6, 0.95),
                    (1.92, 0.8), (DUR, 0.0)], n)
    x = x * e
    if versione == 'a':
        x = _inceppa(rng, x)
    # Un colpo sordo all'attacco: lo spavento parte con una botta.
    kb = n_of(0.35)
    tb = t_axis(kb)
    botta = np.sin(2 * np.pi * np.cumsum(55 + 90 * np.exp(-tb / 0.05)) / SR) * np.exp(-tb / 0.12)
    botta += lp(white(kb, rng), 900, 2) * np.exp(-tb / 0.04) * 0.8
    out = np.stack([x, x], axis=1)
    # Stereo largo: lato destro un filo in ritardo e con il tono spostato.
    out[:, 1] = np.roll(x, n_of(0.011)) * 0.9 + x * 0.1
    mix_into(out, np.stack([botta, botta], axis=1) * 1.2, n_of(INIZIO))
    return out


def _inceppa(rng, x):
    """Versione A: a ogni glitch un pezzetto si ripete (buffer inceppato), poi un buco o un salto
    di tono, come un file audio rotto."""
    y = x.copy()
    for g in GLITCH:
        a = n_of(g)
        pezzo = n_of(rng.uniform(0.018, 0.04))
        volte = int(rng.integers(3, 6))
        sorg = x[a:a + pezzo].copy()
        if rng.random() < 0.5:
            # salto di tono: lo stesso pezzo letto più veloce
            idx = np.clip((np.arange(pezzo) * rng.uniform(1.4, 2.2)).astype(int), 0, pezzo - 1)
            sorg = sorg[idx]
        for i in range(volte):
            s = a + i * pezzo
            if s + pezzo < len(y):
                y[s:s + pezzo] = sorg * (1.15 if i % 2 == 0 else 0.8)
        # buco di 15-30 ms dopo la raffica
        b = a + volte * pezzo
        y[b:b + n_of(rng.uniform(0.015, 0.03))] *= 0.05
    return y


def main():
    for v, seme in [('a', 316), ('b', 3162)]:
        rng = np.random.default_rng(seme)
        x = urlo(rng, v)
        x = fade(x, 0.0, 0.03)
        # Molto forte: è il jumpscare (picco -0,5 dB, loudness massima alta).
        x = normalize_lufs(f32(x), -8.0, -0.5, short=True)
        x = limiter(x, -0.5)
        path = os.path.join(QUI, v, 'lei_urlo.ogg')
        write_ogg(path, x, 5)
        print(path, f'{len(x) / SR:.2f}s')


if __name__ == '__main__':
    main()
