"""Suoni della build 0.5.0, «La storia» (GDD del 15 novembre, Build 2): gli ostacoli dell'agnellino si sentono soltanto.
- fischietto: un fischietto da bagnino (col pallino), corto, sentito da lontano in una sala grande e buia;
- catena_tirata: una catena fatta passare fra le sbarre di una grata e tirata (l'agnellino che chiude la grata di C2);
- lucchetto_scatto: l'arco del lucchetto che scatta chiuso.
E la taratura di cancello_ruota (genera_effetti.py): lo stesso suono, al livello giusto per un volantino sotto il
pavimento delle pozze (enigmi), senza toccare l'originale: cancello_ruota resta com'è, la taratura è il livello a cui
salvarlo (CANCELLO_RUOTA_LUFS) e i numeri per il lettore 3D (LEGGIMI della storia).
Regole di sempre (errori_da_non_ripetere): volume basso, puliti, senza loop, niente code tagliate.
Uscita: godot/audio/effetti/. Uso: python3 genera_storia.py
"""
import numpy as np

from comune import ir_sala, kenney, salva
from genera_giocatore import norm
from lib_audio import (SR, bp, env_points, f32, fade, hp, lp, lufs, lufs_max, mix_into, n_of, pitch, resonator_bank,
                       reverb, smooth_noise, t_axis, trim_silence, white)

CART = 'effetti'


def impulso(n_s=0.1):
    e = np.zeros(n_of(n_s))
    e[0] = 1.0
    return e


def fischietto(rng):
    """Fischietto da bagnino: un tono acuto (circa 3,1 kHz) col pallino che lo fa vibrare (trillo a 34 Hz, in frequenza
    e in ampiezza), un colpo di fiato corto e deciso (0,55 s), un po' di soffio. Sentito da lontano: niente acuti
    secchi (passa basso), e la coda della sala grande."""
    dur = 0.55
    n = n_of(dur)
    t = t_axis(n)
    trillo = 34.0 + 3.0 * smooth_noise(n, 3, rng)
    fase_tr = 2 * np.pi * np.cumsum(trillo) / SR
    f = 3100.0 * (1.0 + 0.035 * np.sin(fase_tr)) * (1.0 + 0.01 * env_points([(0, -1), (0.08, 0), (dur, 0.3)], n))
    fase = 2 * np.pi * np.cumsum(f) / SR
    tono = np.sin(fase) + 0.25 * np.sin(2 * fase) + 0.08 * np.sin(3 * fase)
    am = 0.65 + 0.35 * (0.5 + 0.5 * np.sin(fase_tr + 0.6))
    soffio = bp(white(n, rng), 2500, 7000, 2) * 0.12
    inv = env_points([(0, 0), (0.025, 1), (0.42, 0.85), (dur, 0)], n)
    out = (tono * am + soffio) * inv
    # lontano: gli acuti si perdono, e la sala restituisce una coda lunga
    out = lp(out, 5200, 2)
    out = np.concatenate([out, np.zeros(n_of(2.6))])
    out = reverb(out, ir_sala(9), wet=0.55, dry=0.55, tail=False)
    return fade(f32(out if out.ndim == 1 else out.mean(axis=1)), 0.0, 0.6)


def _anello(rng, peso=1.0):
    """Un anello della catena che urta il ferro: un tic metallico corto con modi alti."""
    fr = np.array([2300, 3700, 5200, 7400]) * rng.uniform(0.85, 1.2) / (0.7 + 0.3 * peso)
    return resonator_bank(impulso(0.08), fr, [0.025, 0.018, 0.012, 0.008], [1, 0.7, 0.45, 0.3])


def catena_tirata(rng):
    """Una catena che passa fra le sbarre di una grata e si tira: prima gli anelli che scivolano e urtano a
    grappoli (sempre più fitti), lo strofinio del ferro sul ferro, due strattoni, e alla fine la catena tesa che
    vibra contro le sbarre. Circa 2 s."""
    dur = 2.1
    out = np.zeros(n_of(dur + 0.6))
    tt = 0.05
    # gli anelli che scivolano: grappoli di tic, più fitti mentre si tira
    while tt < 1.55:
        quanti = rng.integers(2, 6)
        for k in range(quanti):
            a = _anello(rng, rng.uniform(0.7, 1.3)) * rng.uniform(0.25, 0.7)
            mix_into(out, a, n_of(tt + k * rng.uniform(0.012, 0.03)))
        tt += rng.uniform(0.06, 0.14) * (1.0 - 0.4 * tt / 1.55)
    # lo strofinio del ferro sulle sbarre
    m = n_of(1.5)
    sfrega = bp(white(m, rng), 1800, 6000, 2) * (0.5 + 0.5 * smooth_noise(m, 18, rng)) ** 2
    sfrega *= env_points([(0, 0), (0.1, 0.6), (1.2, 1), (1.5, 0)], m)
    mix_into(out, sfrega * 0.12, n_of(0.05))
    # due strattoni: un grappolo stretto e un colpo sordo del ferro
    for t0 in (1.05, 1.6):
        for k in range(6):
            mix_into(out, _anello(rng, 1.2) * 0.8, n_of(t0 + k * 0.008))
        colpo = norm(kenney('impactMetal_light_00%d.ogg' % rng.integers(0, 5)))
        mix_into(out, pitch(colpo, -5) * 0.35, n_of(t0))
    # la catena tesa che vibra contro le sbarre e si ferma
    for k in range(9):
        mix_into(out, _anello(rng, 0.9) * 0.4 * (1 - k / 9), n_of(1.7 + k * 0.035))
    out = hp(out, 120, 2)
    return fade(trim_silence(f32(out)), 0.0, 0.15)


def lucchetto_scatto(rng):
    """L'arco del lucchetto che scatta chiuso: lo scatto secco della molla, il clic del fermo e un piccolo suono di
    ferro del lucchetto che dondola. Circa 0,5 s."""
    out = np.zeros(n_of(0.7))
    latch = norm(kenney('metalLatch.ogg'))
    mix_into(out, pitch(latch, 3)[:n_of(0.35)] * 0.6, 0)
    scatto = resonator_bank(impulso(0.08), [3400, 5600, 8100], [0.01, 0.007, 0.005], [1, 0.6, 0.4])
    mix_into(out, scatto * 1.0, n_of(0.004))
    clic = resonator_bank(impulso(0.06), [2600, 4300], [0.012, 0.008], [1, 0.5])
    mix_into(out, clic * 0.6, n_of(0.045))
    # il lucchetto che dondola e urta la catena due volte, piano
    for k, t0 in enumerate((0.16, 0.31)):
        mix_into(out, _anello(rng, 1.0) * (0.35 - 0.12 * k), n_of(t0))
    out = hp(out, 200, 2)
    return fade(trim_silence(f32(out)), 0.0, 0.08)


## La taratura del volantino sotto il pavimento delle pozze (enigmi): cancello_ruota è salvato a -18 LUFS (massimo su
## 100 ms) da genera_effetti.py. Per un volantino che gira sotto un grigliato, a 1-3 m dal giocatore, va bene così com'è
## col lettore 3D a unit_size 3 e volume_db -6 (misurato qui sotto); i numeri sono nel LEGGIMI della storia.
CANCELLO_RUOTA_LUFS = -18.0


def main():
    rng = np.random.default_rng(515)
    print('Storia (0.5.0)')
    salva(CART, 'fischietto', fischietto(rng), loudness=-17, corto=True, qualita=4)
    salva(CART, 'catena_tirata', catena_tirata(rng), loudness=-19, corto=True, qualita=4,
          fonte='sintesi + Kenney Impact Sounds (CC0)')
    salva(CART, 'lucchetto_scatto', lucchetto_scatto(rng), loudness=-18, corto=True, qualita=4,
          fonte='sintesi + Kenney RPG Audio (CC0)')


if __name__ == '__main__':
    main()
