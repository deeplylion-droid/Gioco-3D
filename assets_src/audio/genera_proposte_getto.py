"""Proposte per la lancia dello zaino (16 ottobre), NON nel gioco: l'aspirazione e il getto molto
più imponenti di quelli di oggi (godot/audio/giocatore/zaino_*). L'utente: "il getto aspirato e
sparato deve essere molto molto più imponente e soddisfacente da vedere e sentire. Pensa alla pompa
dei pompieri e potenzia ancora. Dobbiamo competere con il grab pack."

- A "manichetta dei pompieri": aspira come una pompa da vuoto potente (il motore che parte, il
  risucchio profondo che prende l'acqua, il gorgoglio nel tubo, il serbatoio che si riempie con un
  glu-glu e uno scatto quando è pieno); spara col colpo della valvola, il ruggito profondo del getto
  col sibilo dell'alta pressione, gli strattoni del tubo, lo schianto e lo scroscio dell'acqua
  contro il muro, e la tosse quando si chiude.
- B "potenziato": come A ma più eroico: una turbina che sale di giri nell'aspirazione, il
  caricamento di pressione prima del getto (un sibilo che sale), un attacco a pugno, bassi più
  profondi, scrosci più grossi.

Anteprime di 8 s con la scaletta dei video di grafica (0-0,5 fermo; 0,5-3 aspira da una pozza a
2 m; 3-3,5 pausa col serbatoio pieno; 3,5-7 spara contro un muro a 7 m girando piano; 7-8 stop e
gocce): godot/audio/anteprima/proposta_getto_a.ogg e proposta_getto_b.ogg.
I suoni sciolti, mono e con i nomi del gioco (zaino_*, più quelli nuovi), per montarli dopo:
assets_src/audio/proposte_getto/a/ e b/ (vedi FILE).
Solo sintesi, niente campioni; deterministico. Uso: genera_proposte_getto.py
"""
import os

import numpy as np

from comune import QUI
from genera_ambiente import goccia_acqua, goccia_pavimento, treno_impulsi
from genera_effetti import cigolio_gomma, impulso
from genera_lei import gorgoglio
from genera_proposte import Scena, _norm, a_rms, risucchio, vortice
from genera_tecnici import pompa_strati
from lib_audio import (SR, biquad, bp, colored, comb, env_ad, env_points, f32, fade, hp, lp, make_loop, mix_into,
                       n_of, normalize_lufs, resonator_bank, smooth_noise, t_axis, tv_biquad, white, write_ogg)

SCIOLTI = os.path.join(QUI, 'proposte_getto')

# La scaletta dei video di grafica (s)
ASPIRA_DA, ASPIRA_A = 0.5, 3.0
SPARA_DA, SPARA_A = 3.5, 7.0
DURATA = 8.0
VOLO = 0.28                     # il getto arriva al muro a 7 m

GIRI_POMPA = 52.0               # giri al secondo della pompa dello zaino
TURBINA = 1450.0                # passaggio pale della turbina (b), a regime


def _soft(x, k=1.6):
    """Saturazione morbida: rende il suono più denso e pieno senza picchi."""
    p = float(np.abs(x).max()) + 1e-9
    return f32(np.tanh(x / p * k) / np.tanh(k) * p)


# =============================================================================================
# Aspirazione
# =============================================================================================

def pompa(rng, n, giri, carico=1.0):
    """La pompa da vuoto dello zaino: motore, girante, rombo (genera_tecnici.pompa_strati), più
    cupa e senza il ronzio di rete troppo in vista."""
    x = pompa_strati(rng, n, np.maximum(np.broadcast_to(np.asarray(giri, dtype=np.float64), (n,)), 0.5), carico)
    return f32(lp(x, 2200, 2))


def turbina(rng, n, f):
    """La turbina (b): il fischio delle pale (passaggio pale f, curva) con le armoniche, il rotore
    sotto e l'aria che corre."""
    f = np.broadcast_to(np.asarray(f, dtype=np.float64), (n,))
    ph = np.cumsum(f) / SR
    x = (np.sin(2 * np.pi * ph) + 0.4 * np.sin(4 * np.pi * ph + 0.3) + 0.18 * np.sin(6 * np.pi * ph + 1.1)
         + 0.35 * np.sin(2 * np.pi * ph / 13.0))
    x *= 1 + 0.06 * smooth_noise(n, 7, rng)
    aria = a_rms(bp(white(n, rng), 1200, 7000, 2), 0.25) * np.clip(f / TURBINA, 0, 1.3)
    return f32(x * 0.5 + aria)


def risucchio_profondo(rng, n):
    """Il risucchio nel tubo: acqua e aria che corrono dentro, a sorsate, con la risonanza del tubo."""
    x = bp(colored(n, rng, -3.0), 70, 1600, 2)
    x = biquad(x, 'lowshelf', 160, 0.7, 6)
    x = x * 0.6 + comb(x, 1 / 190.0, 0.45) * 0.3
    sorsate = 0.55 + 0.45 * np.clip(smooth_noise(n, 9, rng, 2) * 1.6 + 0.3, 0, 1)
    return a_rms(x * sorsate, 1.0)


def glu_tubo(rng, n, densita=3.0, f_da=90, f_a=170):
    """Glu-glu grossi nel tubo (sacche d'aria)."""
    out = np.zeros(n)
    t = rng.uniform(0, 0.2)
    while t < n / SR - 0.4:
        g = gorgoglio(rng, int(rng.integers(2, 4)), rng.uniform(f_da, f_a), rng.uniform(0.07, 0.1))
        mix_into(out, g * rng.uniform(0.6, 1.0), n_of(t))
        t += rng.exponential(1.0 / densita) + 0.12
    return f32(out)


def aspira_loop(rng, versione, dur=2.4):
    tot = dur + 0.5
    n = n_of(tot)
    if versione == 'a':
        motore = a_rms(pompa(rng, n, GIRI_POMPA, 1.0), 0.16)
    else:
        motore = a_rms(pompa(rng, n, GIRI_POMPA, 1.0), 0.12) + a_rms(turbina(rng, n, TURBINA), 0.09)
    out = motore + risucchio_profondo(rng, n) * 0.2 + glu_tubo(rng, n, 3.5) * 0.55
    acqua = a_rms(bp(white(n, rng), 400, 3200, 2), 0.04) * (0.6 + 0.4 * smooth_noise(n, 11, rng))
    out = out + acqua
    if versione == 'b':
        out += a_rms(lp(colored(n, rng, -6.0, fmin=25.0), 90, 2), 0.08)
    return make_loop(hp(_soft(out, 1.4), 28, 2), dur, 0.5)


def aspira_inizio(rng, versione):
    """Lo scatto della valvola, il motore (b: la turbina) che parte, il risucchio che prende
    l'acqua con un colpo profondo."""
    dur = 0.9
    n = n_of(dur)
    out = np.zeros(n)
    clunk = _norm(resonator_bank(impulso(0.4), [120, 260, 540, 1100, 2400], [0.12, 0.09, 0.06, 0.035, 0.02],
                                 [1, 0.8, 0.5, 0.3, 0.15]))
    mix_into(out, clunk * 0.7, 0)
    mix_into(out, _norm(bp(white(n_of(0.008), rng), 1500, 8000, 2)) * 0.25, 0)
    tt = t_axis(n)
    giri = GIRI_POMPA * (1 - np.exp(-tt / 0.22))
    sale = env_points([(0, 0.0), (0.06, 0.6), (0.4, 1.0), (dur, 1.0)], n)
    mix_into(out, a_rms(pompa(rng, n, giri, 1.0), 0.16) * sale, 0)
    if versione == 'b':
        f = 150.0 + (TURBINA - 150.0) * (1 - np.exp(-tt / 0.25))
        mix_into(out, a_rms(turbina(rng, n, f), 0.11) * sale, 0)
    # il risucchio che prende l'acqua: un colpo profondo, come un respiro enorme
    k = n_of(0.45)
    whoomp = tv_biquad(colored(k, rng, -3.0), 'bandpass', env_points([(0, 140), (0.45, 650)], k), 1.6)
    whoomp = _norm(whoomp) * env_points([(0, 0), (0.04, 1.0), (0.2, 0.6), (0.45, 0)], k)
    mix_into(out, whoomp * (0.55 if versione == 'a' else 0.7), n_of(0.2))
    k = n_of(0.25)
    tonfo = np.sin(2 * np.pi * np.cumsum(env_points([(0, 75), (0.25, 42)], k)) / SR) * env_ad(k, 0.004, 0.22)
    mix_into(out, tonfo * (0.5 if versione == 'a' else 0.75), n_of(0.22))
    return fade(hp(_soft(out, 1.3), 25, 2), 0.0, 0.15)


def serbatoio_loop(rng, dur=2.0):
    """Il serbatoio che si riempie: glu-glu nella cavità del serbatoio (in gioco il tono sale col
    livello) e l'acqua che cade dentro."""
    tot = dur + 0.4
    n = n_of(tot)
    out = np.zeros(n)
    t = 0.0
    while t < tot - 0.2:
        g = gorgoglio(rng, 1, rng.uniform(150, 175), 0.08)
        mix_into(out, g * rng.uniform(0.7, 1.0), n_of(t))
        t += rng.uniform(0.15, 0.24)
    caduta = a_rms(bp(white(n, rng), 300, 2600, 2), 0.05) * (0.7 + 0.3 * smooth_noise(n, 8, rng))
    out = out + comb(caduta, 1 / 420.0, 0.35) * 0.6
    return make_loop(hp(out, 60, 2), dur, 0.4)


def risucchio_pozza_loop(rng, dur=2.4):
    """Alla pozza, dove si aspira: l'acqua tirata su che risucchia e gira, sorsate profonde."""
    tot = dur + 0.5
    n = n_of(tot)
    out = a_rms(lp(vortice(rng, n, 2.2, 520.0, 2.0, 0.3), 2500, 2), 0.05)
    t = rng.uniform(0, 0.15)
    while t < tot - 0.4:
        d = rng.uniform(0.18, 0.32)
        mix_into(out, risucchio(rng, d, rng.uniform(220, 320), rng.uniform(800, 1200), 4.0, (16.0, 26.0)) * 0.22,
                 n_of(t))
        t += rng.uniform(0.16, 0.34)
    out += glu_tubo(rng, n, 2.5, 80, 140) * 0.35
    return make_loop(hp(out, 40, 2), dur, 0.5)


def pieno(rng, versione):
    """Il serbatoio pieno: gli ultimi glu-glu, lo scatto del galleggiante, l'aria che sfiata.
    b: uno scatto doppio più pieno, con un piccolo squillo metallico."""
    dur = 0.8
    out = np.zeros(n_of(dur))
    for k, f in enumerate([175, 200]):
        mix_into(out, gorgoglio(rng, 1, f, 0.08) * 0.8, n_of(k * 0.1))
    T = 0.2
    clack = _norm(resonator_bank(impulso(0.3), [230, 560, 1350, 2800], [0.06, 0.04, 0.025, 0.012], [1, 0.7, 0.4, 0.2]))
    if versione == 'a':
        mix_into(out, clack * 0.9, n_of(T))
    else:
        chk = _norm(resonator_bank(impulso(0.2), [900, 2100, 4300], [0.02, 0.012, 0.008], [1, 0.6, 0.3]))
        mix_into(out, chk * 0.45, n_of(T - 0.05))
        mix_into(out, clack * 1.0, n_of(T))
        k = n_of(0.18)
        mix_into(out, np.sin(2 * np.pi * np.cumsum(np.full(k, 58.0)) / SR) * env_ad(k, 0.003, 0.15) * 0.7, n_of(T))
        anello = _norm(resonator_bank(impulso(0.6), [3150, 4720, 6100], [0.35, 0.25, 0.15], [1, 0.5, 0.3]))
        mix_into(out, anello * 0.12, n_of(T + 0.004))
    k = n_of(0.16)
    pff = bp(white(k, rng), 1000, 5500, 2) * env_points([(0, 0), (0.01, 1), (0.16, 0)], k) ** 2
    mix_into(out, _norm(pff) * 0.3, n_of(T + 0.05))
    return fade(hp(out, 30, 2), 0.0, 0.1)


def aspira_fine(rng, versione):
    """Smette di aspirare: la pompa (b: la turbina) che cala di giri, il risucchio che si stacca con
    uno schiocco, l'acqua che si assesta nel tubo."""
    dur = 0.9
    n = n_of(dur)
    out = np.zeros(n)
    tt = t_axis(n)
    giri = GIRI_POMPA * np.exp(-tt / 0.22) + 1.0
    cala = env_points([(0, 1.0), (0.5, 0.35), (dur, 0.0)], n)
    out += a_rms(pompa(rng, n, giri, 0.6), 0.14) * cala
    if versione == 'b':
        f = 120.0 + (TURBINA - 120.0) * np.exp(-tt / 0.14)
        out += a_rms(turbina(rng, n, f), 0.08) * cala * np.exp(-tt / 0.2)
    mix_into(out, risucchio(rng, 0.14, 500, 1300, 4.0, (20.0, 30.0)) * 0.35, 0)
    k = n_of(0.05)
    mix_into(out, _norm(bp(white(k, rng), 300, 2500, 2) * env_ad(k, 0.002, 0.04)) * 0.3, n_of(0.12))
    k = n_of(0.35)
    slosh = lp(white(k, rng), 700, 2) * env_points([(0, 0), (0.05, 1), (0.35, 0)], k)
    mix_into(out, _norm(slosh) * 0.15, n_of(0.18))
    return fade(hp(out, 25, 2), 0.0, 0.2)


# =============================================================================================
# Getto
# =============================================================================================

def carica(rng):
    """b: il caricamento di pressione prima del getto (0,35 s): un sibilo che sale, la turbina che
    fischia sempre più in alto, un rombo che cresce. Finisce dove parte il getto."""
    dur = 0.35
    n = n_of(dur)
    k = (t_axis(n) / dur) ** 2
    sibilo = tv_biquad(white(n, rng), 'bandpass', 900 + 6000 * k, 1.3)
    out = a_rms(sibilo, 0.2) * (0.1 + 0.9 * k)
    out += a_rms(turbina(rng, n, 500 + 1900 * k), 0.12) * (0.2 + 0.8 * k)
    out += a_rms(lp(colored(n, rng, -6.0, fmin=25.0), 120, 2), 0.12) * k
    return fade(hp(out, 25, 2), 0.03, 0.0)


def getto_loop(rng, versione, dur=2.5):
    """Il getto della manichetta: ruggito profondo, sibilo dell'alta pressione, l'acqua che si
    rompe, la pompa che pulsa sotto, un fischio di ugello. b: bassi più profondi e un ronzio di
    potenza."""
    tot = dur + 0.5
    n = n_of(tot)
    rugg = bp(colored(n, rng, -3.0), 60, 2600, 2)
    rugg = biquad(rugg, 'lowshelf', 140, 0.7, 6 if versione == 'a' else 8)
    fiotti = np.clip(smooth_noise(n, 11, rng, 2) * 1.4 + 0.5, 0, 1)
    rugg = a_rms(rugg, 0.3) * (0.82 + 0.12 * smooth_noise(n, 2.5, rng) + 0.16 * fiotti)
    sib = biquad(bp(white(n, rng), 2500, 11000, 2), 'peak', 5200, 1.2, 4)
    sib = a_rms(sib, 0.08) * (1 + 0.15 * smooth_noise(n, 35, rng))
    rotto = resonator_bank(treno_impulsi(n, 3200, rng, alpha=2.2), [2600, 4100, 6200, 8300],
                           [0.003, 0.0025, 0.002, 0.0015], [1, 0.8, 0.5, 0.3])
    rotto = a_rms(hp(rotto, 1200), 0.06) * (0.7 + 0.3 * fiotti)
    t = t_axis(n)
    sub = a_rms(lp(colored(n, rng, -6.0, fmin=25.0), 80, 2), 0.12)
    pulsa = np.sin(2 * np.pi * 47 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 6.0 * t)) * 0.07
    fischio = tv_biquad(white(n, rng), 'bandpass', 1480 * (1 + 0.02 * smooth_noise(n, 3, rng)), 22)
    out = rugg + sib + rotto + sub + pulsa + a_rms(fischio, 0.012)
    if versione == 'b':
        ph = np.cumsum(np.full(n, 41.0) * (1 + 0.01 * smooth_noise(n, 1.5, rng))) / SR
        out += (np.sin(2 * np.pi * ph) + 0.5 * np.sin(4 * np.pi * ph + 0.4)) * 0.11
        out += a_rms(lp(colored(n, rng, -6.0, fmin=25.0), 60, 2), 0.1)
        out += a_rms(turbina(rng, n, TURBINA * 1.1), 0.035)
    return make_loop(hp(_soft(out, 1.5), 25, 2), dur, 0.5)


def getto_inizio(rng, versione):
    """Il colpo della valvola che si apre e l'acqua che parte: botta bassa e fronte d'acqua che
    esplode (poi c'è il loop). b: un attacco a pugno (schiocco, boom profondo, colpo più grosso)."""
    dur = 0.8
    n = n_of(dur)
    out = np.zeros(n)
    valvola = _norm(resonator_bank(impulso(0.5), [150, 330, 690, 1300, 2600, 4200],
                                   [0.14, 0.1, 0.07, 0.045, 0.025, 0.012], [1, 0.85, 0.6, 0.4, 0.25, 0.12]))
    mix_into(out, valvola * 0.8, 0)
    k = n_of(0.7)
    fronte = bp(colored(k, rng, -3.0), 60, 9000, 2)
    fronte = biquad(fronte, 'lowshelf', 150, 0.7, 6)
    e = env_points([(0, 0), (0.006, 1.0), (0.12, 0.75), (0.35, 0.45), (0.7, 0)], k)
    mix_into(out, _norm(fronte) * e * 0.9, n_of(0.015))
    k = n_of(0.35)
    whump = np.sin(2 * np.pi * np.cumsum(env_points([(0, 68), (0.35, 40)], k)) / SR) * env_ad(k, 0.003, 0.3)
    mix_into(out, whump * 0.8, n_of(0.01))
    if versione == 'b':
        k = n_of(0.006)
        mix_into(out, _norm(hp(white(k, rng), 2000)) * 0.6, n_of(0.012))
        k = n_of(0.5)
        boom = np.sin(2 * np.pi * np.cumsum(env_points([(0, 85), (0.5, 36)], k)) / SR) * env_ad(k, 0.002, 0.45)
        boom += _norm(lp(white(k, rng), 140, 2)) * env_ad(k, 0.002, 0.2) * 0.5
        mix_into(out, boom * 1.1, n_of(0.01))
    return fade(hp(_soft(out, 1.6 if versione == 'a' else 2.0), 22, 2), 0.0, 0.3)


def strattone(rng, versione):
    """Uno strattone del tubo sotto pressione: la botta, la gomma che si flette, il getto che
    sobbalza."""
    dur = 0.6
    n = n_of(dur)
    out = np.zeros(n)
    k = n_of(0.3)
    botta = np.sin(2 * np.pi * np.cumsum(env_points([(0, 55), (0.3, 38)], k)) / SR) * env_ad(k, 0.004, 0.25)
    mix_into(out, botta * (0.8 if versione == 'a' else 1.1), 0)
    gomma = lp(cigolio_gomma(rng, 0.32, rng.uniform(140, 170), rng.uniform(90, 110)), 1500)
    mix_into(out, _norm(gomma) * 0.35, n_of(0.02))
    k = n_of(0.4)
    sobbalzo = bp(colored(k, rng, -3.0), 80, 3000, 2) * env_points([(0, 0), (0.05, 1), (0.4, 0)], k)
    mix_into(out, _norm(sobbalzo) * 0.4, 0)
    return fade(hp(out, 25, 2), 0.0, 0.1)


def impatto_loop(rng, versione, dur=2.5):
    """L'acqua che si schianta contro il muro e scroscia giù: miriadi di gocce che battono, il peso
    dell'acqua a fiotti, la cascata sul pavimento. b: scrosci più grossi."""
    tot = dur + 0.5
    n = n_of(tot)
    imp = treno_impulsi(n, 6500 if versione == 'a' else 8000, rng, alpha=2.0)
    gr = resonator_bank(np.r_[1.0, np.zeros(n_of(0.01))], [1900, 3300, 5200, 7100], [0.004, 0.003, 0.002, 0.0015],
                        [1, 0.7, 0.45, 0.25])
    from scipy import signal as sg
    batte = a_rms(hp(sg.fftconvolve(imp, gr)[:n], 400), 0.12)
    fiotti = bp(colored(n, rng, -3.0), 90, 900, 2)
    fiotti = a_rms(fiotti, 0.16 if versione == 'a' else 0.24) * (0.65 + 0.35 * np.clip(smooth_noise(n, 9, rng) + 0.3, 0, 1))
    cascata = a_rms(bp(white(n, rng), 250, 3800, 2), 0.09 if versione == 'a' else 0.12) * \
        (0.75 + 0.25 * smooth_noise(n, 1.5, rng))
    out = batte + fiotti + cascata
    if versione == 'b':
        out += a_rms(lp(colored(n, rng, -6.0, fmin=25.0), 140, 2), 0.1) * (0.7 + 0.3 * smooth_noise(n, 5, rng))
    return make_loop(hp(_soft(out, 1.3), 30, 2), dur, 0.5)


def getto_fine(rng, versione):
    """La valvola si chiude: il getto che si strozza, la tosse (sbuffi d'aria e acqua sempre più
    deboli), la pressione che sfiata, la valvola che batte."""
    dur = 1.1
    n = n_of(dur)
    out = np.zeros(n)
    k = n_of(0.18)
    strozza = bp(colored(k, rng, -3.0), 80, 6000, 2) * env_points([(0, 1.0), (0.18, 0)], k) ** 1.5
    mix_into(out, _norm(strozza) * 0.8, 0)
    valvola = _norm(resonator_bank(impulso(0.3), [180, 420, 900, 2000], [0.08, 0.06, 0.04, 0.02], [1, 0.7, 0.4, 0.2]))
    mix_into(out, valvola * 0.6, n_of(0.05))
    t, g = 0.17, 1.0
    for _ in range(int(rng.integers(4, 6))):
        k = n_of(rng.uniform(0.03, 0.06))
        sbuffo = bp(white(k, rng), 250, 5000, 2) * env_points([(0, 0), (0.004, 1), (k / SR, 0)], k)
        mix_into(out, _norm(sbuffo) * 0.55 * g, n_of(t))
        k2 = n_of(0.12)
        tossito = np.sin(2 * np.pi * np.cumsum(env_points([(0, 95), (0.12, 60)], k2)) / SR) * env_ad(k2, 0.003, 0.1)
        mix_into(out, tossito * 0.4 * g, n_of(t))
        t += rng.uniform(0.07, 0.15)
        g *= rng.uniform(0.6, 0.75)
    k = n_of(0.45)
    sfiata = bp(white(k, rng), 1200, 6500, 2) * env_points([(0, 0), (0.02, 1), (0.45, 0)], k) ** 2
    mix_into(out, _norm(sfiata) * 0.22, n_of(t))
    if versione == 'b':
        k = n_of(0.3)
        mix_into(out, np.sin(2 * np.pi * np.cumsum(env_points([(0, 70), (0.3, 40)], k)) / SR) * env_ad(k, 0.003, 0.25) * 0.6, 0)
    return fade(hp(out, 25, 2), 0.0, 0.15)


def gocce(rng):
    """Le gocce dall'ugello dopo lo stop."""
    out = np.zeros(n_of(1.2))
    for t0 in [0.05, 0.31, 0.62, 0.95]:
        g = goccia_acqua(rng) if rng.random() < 0.5 else goccia_pavimento(rng)
        mix_into(out, g * rng.uniform(0.6, 1.0), n_of(t0 + rng.uniform(-0.03, 0.03)))
    return fade(out, 0.0, 0.1)


# =============================================================================================
# I suoni sciolti e le anteprime
# =============================================================================================

## nome -> (funzione, normalizzazione): ('lufs', valore) per i loop, ('corto', valore) per i colpi
def suoni(versione):
    rng = np.random.default_rng(1711 if versione == 'a' else 2711)
    s = {
        'zaino_aspira_inizio': (aspira_inizio(rng, versione), ('corto', -15.0)),
        'zaino_aspira_loop': (aspira_loop(rng, versione), ('lufs', -22.5)),
        'zaino_serbatoio_loop': (serbatoio_loop(rng), ('lufs', -24.5)),
        'zaino_risucchio_loop': (risucchio_pozza_loop(rng), ('lufs', -23.5)),
        'zaino_pieno': (pieno(rng, versione), ('corto', -15.0)),
        'zaino_aspira_fine': (aspira_fine(rng, versione), ('corto', -17.0)),
        'zaino_getto_inizio': (getto_inizio(rng, versione), ('corto', -12.0)),
        'zaino_getto_loop': (getto_loop(rng, versione), ('lufs', -16.0)),
        'zaino_impatto_loop': (impatto_loop(rng, versione), ('lufs', -17.0)),
        'zaino_getto_fine': (getto_fine(rng, versione), ('corto', -15.0)),
        'zaino_gocce': (gocce(rng), ('corto', -22.0)),
    }
    for i in range(3):
        s[f'zaino_strattone_{i + 1:02d}'] = (strattone(rng, versione), ('corto', -16.0))
    if versione == 'b':
        s['zaino_carica'] = (carica(rng), ('corto', -15.0))
    pronti = {}
    for nome, (x, (tipo, v)) in s.items():
        pronti[nome] = normalize_lufs(x, v, -1.0, short=(tipo == 'corto'))
    return pronti


def strato(scena, x, t0, t1, fin=0.08, fout=0.12, tono=None, g_db=0.0, p=0.0, dove='vicino'):
    """Un loop suonato da t0 a t1 con brevi rampe (come gli AudioLoop dello zaino), tono come curva
    (inizio, fine) se serve."""
    from genera_anteprima import tile
    from lib_audio import varispeed
    k = n_of(t1 - t0 + fout)
    src = tile(x, (t1 - t0 + fout) * 1.6 + 0.5, 0.0)
    if tono is not None:
        y = varispeed(src, np.linspace(tono[0], tono[1], k))[:k]
    else:
        y = src[:k]
    y = np.pad(y, (0, k - len(y)))
    e = np.clip(t_axis(k) / fin, 0, 1) * np.clip((t1 - t0 + fout - t_axis(k)) / fout, 0, 1)
    scena.metti(f32(y * e), t0, g_db, p, dove)


def anteprima(versione, x):
    """Gli 8 s della scaletta dei video: fermo, aspira dalla pozza a 2 m, pausa col serbatoio pieno,
    spara contro il muro a 7 m girando piano, stop e gocce. Lo zaino da vicino, la pozza e il muro
    col riverbero della sala; i fondi della sala 10 dB sotto il gioco."""
    s = Scena(DURATA, fondi=-10.0)
    # aspira
    s.metti(x['zaino_aspira_inizio'], ASPIRA_DA, 0.0, 0.0, 'vicino')
    strato(s, x['zaino_aspira_loop'], ASPIRA_DA + 0.05, ASPIRA_A, fin=0.1)
    strato(s, x['zaino_serbatoio_loop'], ASPIRA_DA + 0.35, ASPIRA_A - 0.05, fin=0.2, tono=(0.9, 1.35), g_db=-2.0)
    strato(s, x['zaino_risucchio_loop'], ASPIRA_DA + 0.15, ASPIRA_A, fin=0.15, fout=0.25, g_db=-1.0, p=-0.15,
           dove='eff')
    s.metti(x['zaino_pieno'], ASPIRA_A - 0.2, 0.0, 0.0, 'vicino')
    s.metti(x['zaino_aspira_fine'], ASPIRA_A, 0.0, 0.0, 'vicino')
    # spara
    if versione == 'b':
        s.metti(x['zaino_carica'], SPARA_DA - 0.35, 0.0, 0.0, 'vicino')
    s.metti(x['zaino_getto_inizio'], SPARA_DA, 0.0, 0.0, 'vicino')
    strato(s, x['zaino_getto_loop'], SPARA_DA + 0.04, SPARA_A, fin=0.06, fout=0.1)
    # il muro a 7 m: l'acqua arriva dopo VOLO, il punto si sposta piano (si gira)
    k = n_of(SPARA_A - SPARA_DA + 0.4)
    imp = np.zeros((k, 2), dtype=np.float32)
    tmp = Scena(SPARA_A - SPARA_DA + 0.4, fondi=None)
    strato(tmp, x['zaino_impatto_loop'], 0.0, SPARA_A - SPARA_DA, fin=0.05, fout=0.3, g_db=-5.0, dove='eff')
    lato = np.linspace(-0.3, 0.3, k)
    a = (lato + 1) * np.pi / 4
    m = tmp.eff.mean(axis=1)
    imp[:, 0] = m * np.cos(a) * np.sqrt(2)
    imp[:, 1] = m * np.sin(a) * np.sqrt(2)
    mix_into(s.eff, imp, n_of(SPARA_DA + VOLO))
    for t0, i in ([(4.4, 1), (5.55, 2), (6.4, 3)] if versione == 'a' else [(4.6, 1), (5.9, 2)]):
        s.metti(x[f'zaino_strattone_{i:02d}'], t0, -2.0, 0.0, 'vicino')
    # stop
    s.metti(x['zaino_getto_fine'], SPARA_A, 0.0, 0.0, 'vicino')
    s.metti(x['zaino_gocce'], SPARA_A + 0.25, 0.0, 0.05, 'vicino')
    rng = np.random.default_rng(31)
    for t0 in [7.45, 7.8]:
        s.metti(goccia_pavimento(rng) * 0.5, t0, -14.0, 0.25)
    return s.scrivi(f'proposta_getto_{versione}.ogg', wet=0.3, fin=0.05, fout=0.15, wet_vicino=0.1)


def main():
    for versione in ('a', 'b'):
        x = suoni(versione)
        cartella = os.path.join(SCIOLTI, versione)
        os.makedirs(cartella, exist_ok=True)
        for nome, y in x.items():
            write_ogg(os.path.join(cartella, nome + '.ogg'), y, 5)
        print(f'{versione}: {len(x)} suoni in {cartella}')
        anteprima(versione, x)


if __name__ == '__main__':
    main()
