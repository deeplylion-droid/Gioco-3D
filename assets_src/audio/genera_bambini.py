"""Passi dei bambini visti di sfuggita (0.3.21, scelta A dell'utente "passi dei bambini"): passetti di corsa
leggeri, che nel gioco suonano nello spazio dal piede del bambino (anche alle spalle), piano come i passi del
giocatore.
- passo_bambino_muta: il bambino col cubo, scalzo nella muta bagnata: lo schiaffo leggero del piede nudo sulle
  piastrelle bagnate, lo sciac dell'acqua sotto la pianta e la gomma della muta che si piega (un cigolio morbido);
- passo_agnellino: l'agnellino, un peluche zuppo d'acqua: un tonfo sordo e morbido (nessun tacco, nessuno
  schiocco) e l'acqua strizzata fuori dalla stoffa a ogni passo.
Senza goccioline che schizzano (come i passi bagnati del giocatore: scelta dell'utente del 16 ottobre, le sentiva
come bollicine). Sei varianti per tipo; ogni tipo ha il suo seme. Tutti mono.
Uso: python genera_bambini.py
Uscita: godot/audio/bambini/.
"""
import numpy as np

from comune import kenney, salva
from genera_giocatore import strato_bagnato
from lib_audio import (bp, env_ad, env_points, eq, fade, hp, lp, mix_into, n_of, pitch, resonator_bank,
                       smooth_noise, t_axis, trim_silence, white)

CART = 'bambini'


def norm(x):
    p = np.abs(x).max()
    return x / p if p > 0 else x


def schiaffo_piede(rng, forza=1.0):
    """Il piede nudo e piccolo che batte di piatto: un colpo di rumore corto e chiaro, poco corpo sotto."""
    k = n_of(0.06)
    s = bp(white(k, rng), 500, rng.uniform(3600, 4600), 2) * env_ad(k, 0.0008, rng.uniform(0.03, 0.045))
    corpo = lp(white(k, rng), 260, 2) * env_ad(k, 0.002, 0.05) * 0.9
    tt = t_axis(k)
    tonfo = np.sin(2 * np.pi * rng.uniform(140, 175) * tt) * env_ad(k, 0.001, 0.04) * 0.25
    return (s + corpo + tonfo) * forza


def gomma_muta(rng, forza=1.0):
    """La gomma della muta che si piega alla caviglia e al ginocchio: un cigolio morbido e smorzato."""
    k = n_of(rng.uniform(0.05, 0.08))
    tt = t_axis(k)
    f = rng.uniform(520, 760) * (1 + 0.25 * tt / tt[-1]) + 30 * smooth_noise(k, 60, rng)
    tono = np.sin(2 * np.pi * np.cumsum(f) / 48000.0)
    env = env_points([(0, 0), (0.012, 1), (k / 48000.0, 0)], k)
    attrito = bp(white(k, rng), 900, 2600, 2) * env * 0.35
    return lp(tono * env * 0.18 + attrito, 3200) * forza


def passo_bambino_muta(rng, i):
    out = np.zeros(n_of(0.35))
    mix_into(out, schiaffo_piede(rng), 0)
    mix_into(out, strato_bagnato(rng, forza=0.55, goccioline=False), n_of(0.003))
    mix_into(out, gomma_muta(rng, rng.uniform(0.6, 1.0)), n_of(rng.uniform(0.02, 0.05)))
    out = eq(out, [('lowshelf', 200, 0.7, -4), ('peak', 2400, 0.9, 2)])
    return fade(trim_silence(out), 0, 0.03)


def strizzata(rng, forza=1.0):
    """L'acqua strizzata fuori dalla stoffa: un risucchio gorgogliante e ovattato, mezzo decimo di secondo."""
    k = n_of(rng.uniform(0.11, 0.16))
    rumore = white(k, rng)
    # il gorgoglio: il rumore filtrato in una banda che si muove a scatti morbidi
    mod = 0.5 + 0.5 * smooth_noise(k, rng.uniform(35, 55), rng)
    acqua = bp(rumore, 350, 1900, 2) * (0.35 + 0.65 * mod)
    env = env_points([(0, 0), (0.01, 1), (0.05, 0.6), (k / 48000.0, 0)], k)
    melma = norm(kenney('slime_%03d.ogg' % rng.integers(0, 2)))
    melma = lp(pitch(melma, rng.uniform(-2.0, 1.0)), 1800)[:k]
    melma = np.pad(melma, (0, k - len(melma)))
    return lp(acqua * env * 0.7 + melma * env * 0.5, 2400) * forza


def tonfo_peluche(rng, forza=1.0):
    """La zampa di stoffa piena d'acqua che tocca terra: sordo e morbido, senza attacco secco."""
    k = n_of(0.09)
    tt = t_axis(k)
    sordo = lp(white(k, rng), rng.uniform(380, 520), 2) * env_points([(0, 0), (0.006, 1), (0.09, 0)], k)
    tono = np.sin(2 * np.pi * rng.uniform(95, 125) * tt) * env_ad(k, 0.004, 0.07) * 0.35
    return (sordo + tono) * forza


def passo_agnellino(rng, i):
    out = np.zeros(n_of(0.4))
    mix_into(out, tonfo_peluche(rng), 0)
    mix_into(out, strizzata(rng, rng.uniform(0.75, 1.0)), n_of(rng.uniform(0.008, 0.02)))
    out = eq(out, [('highshelf', 4000, 0.7, -8)])
    return fade(trim_silence(out), 0, 0.04)


def main():
    print('Bambini')
    rng = np.random.default_rng(2111)
    for i in range(6):
        salva(CART, f'passo_bambino_muta_{i + 1:02d}', passo_bambino_muta(rng, i), loudness=-21, corto=True,
              qualita=3, fonte='sintesi', nota='piede nudo sul bagnato e la gomma della muta (0.3.21)')
    rng = np.random.default_rng(2112)
    for i in range(6):
        salva(CART, f'passo_agnellino_{i + 1:02d}', passo_agnellino(rng, i), loudness=-22, corto=True,
              qualita=3, fonte='sintesi + Kenney Sci-Fi Sounds (CC0)',
              nota='peluche zuppo: tonfo sordo e acqua strizzata (slime filtrato, 0.3.21)')


if __name__ == '__main__':
    main()
