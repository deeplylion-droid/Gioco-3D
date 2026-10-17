"""PROPOSTA (riscontro 4 della v0.3.2): il boato dell'esplosione d'acqua quando lei sparisce nella
fossa dell'area bimbi, tutto di sintesi. Due versioni, coi tempi di proposte/medusa/esplosione.gd:
- A (geyser): colpo sordo dal fondo, ruggito dell'acqua che spara in alto, poi a 0,75 s crolla:
  scroscio pesante di pioggia sull'acqua e sulle piastrelle, che si dirada.
- B (cupola): colpo, l'acqua che sale e scorre a velo (più sibilante), a 0,95 s scoppia verso fuori:
  scroscio largo, schizzi sul pavimento, poi gocce.
Riverbero della sala (enorme, piastrellata). Uso: /home/user/tools/blender-venv/bin/python genera_boato.py
Uscita: assets_src/audio/proposte_esplosione/{a,b}/lei_esplosione.ogg (non nel gioco).
"""
import os
import sys

import numpy as np

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(QUI))
from comune import ir_sala  # noqa: E402
from genera_ambiente import bollicina, goccia_pavimento  # noqa: E402
from genera_lei import cascata, lastra  # noqa: E402
from lib_audio import (SR, bp, colored, env_points, f32, fade, hp, limiter, lp, mix_into, n_of,  # noqa: E402
                       normalize_lufs, pan, reverb, smooth_noise, t_axis, tv_biquad, white, write_ogg)

DUR = 3.5
TEMPI = {'a': {'crolla': 0.75, 'crollo': 1.2}, 'b': {'crolla': 0.95, 'crollo': 1.0}}


def boato(rng, v):
    n = n_of(DUR)
    out = np.zeros((n, 2))
    c = TEMPI[v]['crolla']
    # 1) il colpo sordo dal fondo della fossa
    k = n_of(0.6)
    tt = t_axis(k)
    colpo = np.sin(2 * np.pi * np.cumsum(38 + 70 * np.exp(-tt / 0.07)) / SR) * np.exp(-tt / 0.25)
    colpo += lp(white(k, rng), 300, 2) * np.exp(-tt / 0.08) * 0.9
    mix_into(out, np.stack([colpo, colpo], axis=1) * 1.1, 0)
    # 2) l'acqua che esplode verso l'alto: ruggito di rumore che si apre (filtro che sale)
    k = n_of(c + 0.3)
    rug = colored(k, rng, -2.0, fmin=40.0)
    taglio = np.linspace(600, 7000 if v == 'a' else 9000, k) ** 1.0
    rug = tv_biquad(rug, 'lowpass', taglio, np.full(k, 0.7))
    e = env_points([(0, 0), (0.02, 1.0), (c * 0.6, 0.8), (c, 0.6), (c + 0.3, 0.0)], k)
    rug = rug * e * (0.75 + 0.25 * smooth_noise(k, 20, rng))
    if v == 'b':
        # il velo che scorre sulla cupola: sibilo d'acqua
        rug += bp(white(k, rng), 2500, 9000, 2) * e * 0.35
    mix_into(out, np.stack([rug, np.roll(rug, n_of(0.009))], axis=1) * 0.8, 0)
    # spruzzi e lastre d'acqua mentre sale
    for i in range(10 if v == 'a' else 7):
        mix_into(out, pan(lastra(rng, rng.uniform(0.5, 1.0)), rng.uniform(-0.6, 0.6)) * 0.35, n_of(rng.uniform(0.02, c)))
    # 3) il crollo: scroscio pesante sull'acqua della fossa e sulle piastrelle
    dc = TEMPI[v]['crollo'] + 0.8
    sc = cascata(rng, dc, [(0, 0.2), (0.08, 1.0), (dc * 0.45, 0.6), (dc, 0.0)], fitta=3.0 if v == 'a' else 2.0)
    pioggia = bp(white(n_of(dc), rng), 900, 8000, 2) * env_points([(0, 0), (0.1, 1), (dc * 0.5, 0.4), (dc, 0)], n_of(dc))
    pioggia *= 0.6 + 0.4 * np.clip(smooth_noise(n_of(dc), 60, rng), 0, 1)
    mix_into(out, np.stack([sc + pioggia * 0.35, np.roll(sc, n_of(0.013)) + pioggia * 0.3], axis=1) * 1.2, n_of(c))
    for _ in range(14 if v == 'a' else 10):
        mix_into(out, pan(lastra(rng, rng.uniform(0.4, 1.0)), rng.uniform(-0.8, 0.8)) * 0.3,
                 n_of(c + rng.uniform(0.05, TEMPI[v]['crollo'])))
    # schizzi sul pavimento intorno (B li spara più lontano: più a lato)
    for _ in range(40):
        g = goccia_pavimento(rng) * rng.uniform(0.08, 0.2)
        mix_into(out, pan(g, rng.uniform(-0.9, 0.9) if v == 'b' else rng.uniform(-0.5, 0.5)),
                 n_of(c + rng.uniform(0.15, TEMPI[v]['crollo'] + 0.6)))
    # 4) coda: bollicine e gocce rade
    for _ in range(30):
        b = bollicina(rng, rng.uniform(400, 2400), rng.uniform(0.006, 0.02), rise=0.5)
        mix_into(out, pan(b * rng.uniform(0.04, 0.1), rng.uniform(-0.5, 0.5)), n_of(rng.uniform(c + 0.8, DUR - 0.3)))
    out = reverb(out, ir_sala(), wet=0.35, dry=1.0, tail=False)
    return fade(hp(out, 25, 2), 0.0, 0.4)


def main():
    for v, seme in [('a', 41), ('b', 42)]:
        rng = np.random.default_rng(seme)
        x = normalize_lufs(f32(boato(rng, v)), -11.0, -1.0, short=True)
        x = limiter(x, -1.0)
        path = os.path.join(QUI, v, 'lei_esplosione.ogg')
        write_ogg(path, x, 5)
        print(path, f'{len(x) / SR:.2f}s')


if __name__ == '__main__':
    main()
