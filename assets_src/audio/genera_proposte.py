"""Proposte di suoni per l'utente (16 ottobre). NON sono nel gioco finché l'utente non sceglie:
per ognuna ci sono due versioni, a e b, da ascoltare nelle anteprime
godot/audio/anteprima/proposta_<nome>_<a|b>.ogg (cartella con .gdignore). Ogni anteprima mette i
suoni nuovi nella scena, con lo zaino del gioco e i fondi della sala (pioggia sulla cupola, vento,
nave: 6 dB sotto il gioco, così i suoni nuovi si sentono bene), col riverbero della sala.

- piscina: la piscina a onde che si svuota mentre aspiri con lo zaino (tappa 5).
  piscina_svuota_loop suona dove aspiri finché l'acqua scende (in gioco il tono può salire col
  livello che cala), piscina_vuota quando non ne resta.
  a "gorgo": un gorgo vero, l'acqua che gira e scende con glu-glu profondi e bolle; alla fine
  l'ultimo risucchio, un sorso grave e la piscina vuota che rimbomba di gocce.
  b "respiro": lo stesso gorgo, ma a ondate lente come un respiro (il risucchio sale come chi
  beve, poi gorgoglia giù) col tubo che brontola sotto; alla fine un ultimo sorso, il tubo vuoto
  che rimbomba e un sospiro lungo dal fondo.
- pulsante_botola: il pulsante della botola (fungo rosso su cassetta gialla) che si attiva a
  piscina vuota, col lampeggiante giallo.
  pulsante_botola_attiva suona una volta; con lui parte lampeggiante_loop (in gioco un AudioLoop
  col tono che sale da 0,35 a 1: il motorino prende giri) e, nella b, richiamo_loop.
  a "relè": il contattore che scatta nella cassetta, la corrente che arriva, il lampeggiante che
  prende a girare (motorino, ingranaggi, un tic a ogni giro).
  b "richiamo": lo stesso scatto e un jingle giocattolo con l'ultima nota che cala, come a pile
  scariche; poi un bi-bu da giocattolo ogni due giri del lampeggiante (1,6 s), che rimbomba nella
  sala e fa capire dov'è.
- medusine: le micro medusine luminose aspirate dallo zaino e sparate via, appena percettibili.
  medusina_aspirata (più varianti) per ogni medusina che entra nel tubo, medusine_sparate quando
  escono col getto. Nell'anteprima prima si sentono nel gioco, sotto lo zaino, poi da sole e
  12 dB più forti, per sentirle bene.
  a "vetro": grappoli di tintinnii di vetro minuscoli, un po' stonati (un gemello scordato di un
  quarto di tono), che scendono di tono nel tubo; sparate via, una cascata di tintinnii su una
  scala a toni interi che si allontana.
  b "vive": vocine minuscole e acutissime ("ih?") che, risucchiate, scendono e si spengono nel
  tubo ("ih-uu"); sparate via, le vocine che scivolano giù ("wiii-uu") mentre volano lontano, con
  un coro sottilissimo di vocine a un semitono l'una dall'altra.
- portone_torre: il portone scorrevole della sala della torre che si apre (dopo la tappa 8).
  portone_torre_apre è un suono solo (mono, sul portone), di 8,5 s (a) o 10 s (b).
  a "motore": la serratura che scatta, il motore che parte, il portone pesante che scorre liscio
  sui rulli (giunti della rotaia, lamiera che rimbomba) e sbatte a fine corsa.
  b "ruggine": la serratura dura, il motore che si sforza, il portone che si blocca e strappa tre
  volte stridendo, poi si libera e scorre grattando, e sbatte; cadono pezzetti di ruggine.

Solo sintesi: niente campioni (né Kenney né altro). Tutto deterministico (semi fissi).
Uso: genera_proposte.py [piscina|pulsante|medusine|portone] (senza argomenti, tutte).
Quando l'utente sceglie, la versione scelta va nel generatore della sua cartella (con salva()).
"""
import os
import sys

import numpy as np

from comune import AUDIO, ir_sala
from genera_ambiente import MODI_LAMIERA, bollicina, gemito_attrito, goccia_acqua, goccia_pavimento
from genera_anteprima import curva_loop, distanza_db, leggi, tile
from genera_effetti import impulso, ronzio_rete
from genera_giocatore import motorino
from genera_lei import bolla_grossa, gorgoglio
from lib_audio import (SR, biquad, bp, colored, comb, db, env_ad, env_points, f32, fade, hp, limiter, lp,
                       lufs, make_loop, mix_into, n_of, normalize_lufs, pan, resonator_bank, reverb,
                       smooth_noise, stereo, t_axis, tv_biquad, varispeed, white, write_ogg)

ANTEPRIMA = os.path.join(AUDIO, 'anteprima')


def _norm(x):
    """Picco a 1: per dosare i suoni a colpi (modali, bolle) con guadagni espliciti."""
    return f32(x / (float(np.abs(x).max()) + 1e-9))


def a_rms(x, r):
    """Valore efficace r: per dosare i rumori di fondo (fruscii, rombi) con guadagni espliciti."""
    return f32(x * (r / (float(np.sqrt(np.mean(np.square(x)))) + 1e-12)))


# =============================================================================================
# Piscina a onde che si svuota (tappa 5)
# =============================================================================================

def vortice(rng, n, giri, centro, q=2.5, prof=0.35):
    """Il gorgo dove l'acqua scende: fruscio d'acqua che gira. giri (al secondo) e centro (Hz)
    possono essere curve; a ogni giro il centro sale e scende e il fruscio si gonfia."""
    giri = np.broadcast_to(np.asarray(giri, dtype=np.float64), (n,)) * (1 + 0.08 * smooth_noise(n, 0.5, rng))
    fase = 2 * np.pi * np.cumsum(giri) / SR
    c = np.broadcast_to(np.asarray(centro, dtype=np.float64), (n,))
    c = c * (1 + prof * np.sin(fase) + 0.1 * smooth_noise(n, 2.0, rng))
    x = tv_biquad(white(n, rng), 'bandpass', c, q)
    am = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(fase + 1.2)) ** 2
    return f32(x * am)


def onde_bordi(rng, n, passo=1.7, forza=1.0):
    """Le onde piccole che sbattono piano sui bordi della vasca grande, lontane."""
    out = np.zeros(n)
    t = rng.uniform(0, passo)
    while t < n / SR - 0.1:
        k = n_of(0.9)
        s = bp(white(k, rng), 220, 1600, 2) * env_points([(0, 0), (0.05, 1), (0.3, 0.35), (0.9, 0)], k) ** 1.6
        mix_into(out, s * rng.uniform(0.5, 1.0), n_of(t))
        t += passo * rng.uniform(0.75, 1.25)
    return a_rms(lp(out, 1800, 2), 0.01 * forza)


def risucchio(rng, dur, f_da, f_a, q=4.0, scatti=(14.0, 22.0)):
    """Un risucchio d'acqua e aria (shlurp): fruscio stretto che sale di tono, a scatti."""
    k = n_of(dur)
    x = tv_biquad(colored(k, rng, -3.0), 'bandpass', env_points([(0, f_da), (dur, f_a)], k), q)
    sc = np.sin(2 * np.pi * np.cumsum(env_points([(0, scatti[0]), (dur, scatti[1])], k)) / SR)
    x *= (0.3 + 0.7 * lp(f32(sc > 0), 250, 2)) * env_points([(0, 0), (dur * 0.12, 1), (dur * 0.75, 0.8), (dur, 0)], k)
    return _norm(lp(x, 3000, 2))


def piscina_svuota_loop_a(rng, dur=6.0, xf=1.0):
    """a, il gorgo: l'acqua che gira e scende verso la bocca dello zaino."""
    tot = dur + xf
    n = n_of(tot)
    out = np.zeros(n)
    # il gorgo: l'acqua che gira (e un velo di schiuma più chiaro, a un giro e mezzo)
    out += a_rms(lp(vortice(rng, n, 1.3, 560.0, 2.2, 0.35), 2000, 2), 0.05)
    out += a_rms(lp(vortice(rng, n, 1.95, 1350.0, 3.0, 0.25), 3500, 2), 0.012)
    # la massa d'acqua che si muove verso il gorgo: rombo cupo che respira piano
    out += a_rms(lp(colored(n, rng, -6.0, fmin=25.0), 200, 2), 0.025) * (0.7 + 0.3 * smooth_noise(n, 0.4, rng))
    # il gorgo che ogni tanto tira giù l'aria: risucchi corti a scatti
    t = rng.uniform(0.2, 0.8)
    while t < tot - 0.5:
        mix_into(out, risucchio(rng, rng.uniform(0.22, 0.4), rng.uniform(260, 380), rng.uniform(700, 1000)) * 0.15,
                 n_of(t))
        t += rng.uniform(0.9, 1.7)
    # sacche d'aria risucchiate giù: glu-glu-glu profondi
    t = rng.uniform(0.0, 0.3)
    while t < tot - 0.7:
        g = gorgoglio(rng, int(rng.integers(3, 7)), rng.uniform(75, 150), rng.uniform(0.08, 0.12))
        mix_into(out, g * rng.uniform(0.5, 0.9), n_of(t))
        t += rng.uniform(0.55, 1.2)
    # bolle grosse che scoppiano nel gorgo e bollicine fitte
    for _ in range(int(tot * 2.2)):
        mix_into(out, bolla_grossa(rng, rng.uniform(95, 280)) * rng.uniform(0.15, 0.3),
                 n_of(rng.uniform(0, tot - 0.5)))
    for _ in range(int(tot * 22)):
        b = bollicina(rng, rng.uniform(300, 1300), rng.uniform(0.008, 0.03), rise=0.25)
        mix_into(out, b * rng.uniform(0.03, 0.1), n_of(rng.uniform(0, tot - 0.2)))
    out += onde_bordi(rng, n, 1.7)
    return make_loop(hp(out, 28, 2), dur, xf)


def piscina_vuota_a(rng):
    """a: l'ultima acqua che gira sempre più veloce, il risucchio finale con l'aria, un sorso
    grave, l'aria che fischia nella bocca; poi la piscina vuota, qualche goccia che rimbomba."""
    dur = 6.5
    n = n_of(dur)
    out = np.zeros(n)
    # l'ultima acqua che gira sempre più veloce e sale di tono
    k = n_of(1.9)
    v = vortice(rng, k, env_points([(0, 1.3), (1.9, 3.4)], k), env_points([(0, 560), (1.9, 950)], k), 2.4, 0.4)
    mix_into(out, a_rms(lp(v, 2500, 2), 0.06) * env_points([(0, 0.7), (1.2, 1.0), (1.9, 0.0)], k), 0)
    k = n_of(1.6)
    massa = a_rms(lp(colored(k, rng, -6.0, fmin=25.0), 200, 2), 0.03) * env_points([(0, 1.0), (1.6, 0.0)], k)
    mix_into(out, massa, 0)
    t, f = 0.0, 110.0
    while t < 1.55:
        g = gorgoglio(rng, int(rng.integers(2, 5)), f * rng.uniform(0.9, 1.1), 0.07)
        mix_into(out, g * 0.75, n_of(t))
        t += rng.uniform(0.18, 0.32)
        f *= 1.07
    # il risucchio finale: aria e acqua insieme nella bocca, a scatti sempre più fitti
    mix_into(out, risucchio(rng, 0.95, 280, 1500, 5.0, (13.0, 27.0)) * 0.45, n_of(1.35))
    # l'ultimo sorso: un 'glub' grave
    mix_into(out, bollicina(rng, 72, 0.07, rise=0.18, dur=0.4) * 0.5, n_of(2.2))
    k = n_of(0.1)
    mix_into(out, _norm(lp(white(k, rng), 180, 2) * env_ad(k, 0.004, 0.08)) * 0.3, n_of(2.2))
    # l'aria che fischia un attimo nella bocca, poi niente
    k = n_of(0.5)
    aria = bp(white(k, rng), 900, 4500, 2) * env_points([(0, 0), (0.03, 1), (0.5, 0)], k) ** 2
    mix_into(out, comb(aria, 1 / 180.0, 0.5) * 0.15, n_of(2.3))
    # la piscina vuota: un rivolo sulle pareti che si ferma, qualche goccia che rimbomba
    k = n_of(2.5)
    rivolo = bp(white(k, rng), 1200, 5000, 2) * (0.4 + 0.6 * np.clip(smooth_noise(k, 10, rng) + 0.3, 0, 1))
    mix_into(out, rivolo * env_points([(0, 0), (0.2, 1), (2.5, 0)], k) * 0.03, n_of(2.4))
    for t0, acqua in [(2.95, True), (3.75, False), (4.35, True), (5.4, True)]:
        g = goccia_acqua(rng) if acqua else goccia_pavimento(rng)
        mix_into(out, g * rng.uniform(0.15, 0.22), n_of(t0))
    return fade(hp(out, 28, 2), 0.01, 0.4)


RESPIRO = 3.4      # secondi di un "respiro" della versione b


def fasi_respiro(n, periodo=RESPIRO, sfasa=0.0):
    """Le due metà di un respiro lento, periodiche: (inspira, espira), da 0 a 1."""
    ph = ((t_axis(n) + sfasa) % periodo) / periodo
    insp = np.where(ph < 0.56, np.sin(np.pi * np.clip(ph / 0.56, 0, 1) * 0.5) ** 1.3 *
                    np.clip((0.56 - ph) / 0.06, 0, 1), 0.0)
    esp = np.where(ph >= 0.58, np.sin(np.pi * np.clip((ph - 0.58) / 0.42, 0, 1)) ** 1.2, 0.0)
    return f32(insp), f32(esp), ph


def gola_acqua(rng, n, centro, q=2.5, scatti=16.0):
    """Il risucchio dell'acqua come in una gola enorme che beve: fruscio con due risonanze basse
    (nessuna vocale) e un gorgoglio a scatti."""
    nz = colored(n, rng, -3.0)
    x = tv_biquad(nz, 'bandpass', centro, q) + tv_biquad(nz, 'bandpass', np.asarray(centro) * 2.15, q + 1.5) * 0.5
    sc = np.sin(2 * np.pi * np.cumsum(np.broadcast_to(scatti, (n,)) * (1 + 0.2 * smooth_noise(n, 3, rng))) / SR)
    return f32(lp(x * (0.45 + 0.55 * lp(f32(sc > 0), 200, 2)), 2200, 2))


def piscina_svuota_loop_b(rng, dur=2 * RESPIRO, xf=0.8):
    """b, il respiro: il gorgo che tira su a ondate lente, come chi beve, poi gorgoglia giù; il
    tubo che brontola sotto. Periodico: due respiri esatti."""
    tot = dur + xf
    n = n_of(tot)
    insp, esp, ph = fasi_respiro(n)
    out = np.zeros(n)
    # inspira: il risucchio che sale come in una gola che beve
    centro = 330 + 420 * np.clip(ph / 0.56, 0, 1)
    out += a_rms(gola_acqua(rng, n, centro, 2.4, 15.0), 0.06) * insp
    out += a_rms(lp(vortice(rng, n, 1.1, 600.0, 2.2, 0.3), 2000, 2), 0.025) * (0.35 + 0.65 * insp)
    # espira: glu-glu profondi e bolle grosse che risalgono, un brontolio umido
    for r in range(int(np.ceil(tot / RESPIRO))):
        t0 = r * RESPIRO + 0.58 * RESPIRO
        t = t0 + rng.uniform(0.02, 0.1)
        while t < t0 + 0.36 * RESPIRO and t < tot - 0.7:
            g = gorgoglio(rng, int(rng.integers(3, 6)), rng.uniform(58, 95), rng.uniform(0.11, 0.15))
            mix_into(out, g * rng.uniform(0.6, 0.9), n_of(t))
            t += rng.uniform(0.35, 0.6)
        for _ in range(3):
            tb = t0 + rng.uniform(0.0, 0.3 * RESPIRO)
            if tb < tot - 0.5:
                mix_into(out, bolla_grossa(rng, rng.uniform(85, 200)) * rng.uniform(0.2, 0.35), n_of(tb))
    bro = lp(colored(n, rng, -6.0, fmin=30.0), 420, 2)
    bro = biquad(bro, 'peak', 190, 2.5, 6) + biquad(bro, 'peak', 430, 3.5, 4) * 0.5
    out += a_rms(bro, 0.035) * esp
    # il tubo sotto che brontola quando tira
    t = t_axis(n)
    tubo = np.sin(2 * np.pi * 41 * t) + 0.5 * np.sin(2 * np.pi * 82 * t + 0.7) + 0.2 * np.sin(2 * np.pi * 123 * t)
    out += tubo * (0.25 + 0.75 * lp(insp, 8, 2)) * (0.85 + 0.15 * smooth_noise(n, 1.5, rng)) * 0.05
    for _ in range(int(tot * 14)):
        tb = rng.uniform(0, tot - 0.2)
        b = bollicina(rng, rng.uniform(300, 1100), rng.uniform(0.008, 0.03), rise=0.25)
        mix_into(out, b * rng.uniform(0.03, 0.09), n_of(tb))
    out += onde_bordi(rng, n, 1.7)
    return make_loop(hp(out, 28, 2), dur, xf)


def piscina_vuota_b(rng):
    """b: l'ultimo respiro lungo che tira su l'ultima acqua, un sorso come chi deglutisce, il tubo
    vuoto che rimbomba e un sospiro lungo dal fondo; poi gocce."""
    dur = 7.5
    n = n_of(dur)
    out = np.zeros(n)
    # l'ultimo respiro lungo: sale di tono e si stringe, scatti sempre più fitti
    k = n_of(2.2)
    centro = env_points([(0, 320), (1.5, 760), (2.2, 1150)], k)
    g = gola_acqua(rng, k, centro, 3.2, env_points([(0, 10), (2.2, 24)], k))
    mix_into(out, a_rms(g, 0.08) * env_points([(0, 0), (0.7, 0.7), (1.9, 1.0), (2.2, 0)], k) ** 1.2, 0)
    v = vortice(rng, k, env_points([(0, 1.1), (2.2, 3.0)], k), env_points([(0, 600), (2.2, 1000)], k), 2.4, 0.4)
    mix_into(out, a_rms(lp(v, 2500, 2), 0.03) * env_points([(0, 0.4), (1.6, 1.0), (2.2, 0)], k), 0)
    t = t_axis(k)
    tubo = np.sin(2 * np.pi * 41 * t) + 0.5 * np.sin(2 * np.pi * 82 * t + 0.7)
    mix_into(out, tubo * env_points([(0, 0.3), (2.0, 1.0), (2.2, 0)], k) * 0.07, 0)
    # il sorso: la colonna d'acqua che si chiude, come chi deglutisce
    T = 2.2
    mix_into(out, bollicina(rng, 64, 0.08, rise=0.15, dur=0.45) * 0.5, n_of(T))
    colpo = resonator_bank(impulso(0.3), [110, 260, 520], [0.15, 0.1, 0.05], [1, 0.6, 0.3])
    mix_into(out, _norm(colpo) * 0.3, n_of(T))
    k = n_of(0.09)
    ck = tv_biquad(white(k, rng), 'bandpass', env_points([(0, 220), (0.09, 950)], k), 4.0) * env_ad(k, 0.003, 0.08)
    mix_into(out, ck * 0.5, n_of(T + 0.01))
    # il tubo vuoto che rimbomba
    ecc = lp(white(n_of(0.05), rng), 300, 2) * env_ad(n_of(0.05), 0.002, 0.04)
    rimb = resonator_bank(np.concatenate([ecc, np.zeros(n_of(3.0))]), [43, 87, 139, 226, 361],
                          [2.6, 2.1, 1.7, 1.2, 0.8], [1.0, 0.8, 0.5, 0.3, 0.15])
    mix_into(out, _norm(rimb) * 0.2, n_of(T + 0.02))
    # il sospiro lungo dal fondo: aria che esce piano dal tubo, sempre più grave
    k = n_of(2.8)
    src = colored(k, rng, -4.5, fmin=80.0)
    f1 = env_points([(0, 240), (2.8, 175)], k)
    sos = tv_biquad(src, 'bandpass', f1, 2.2) + tv_biquad(src, 'bandpass', f1 * 2.4, 3.0) * 0.45 + \
        biquad(src, 'bandpass', 1500, 5.0) * 0.05
    sos = lp(sos, 1400, 2)
    sos *= env_points([(0, 0), (0.35, 1.0), (1.2, 0.75), (2.8, 0)], k) ** 1.3
    mix_into(out, _norm(sos) * 0.3, n_of(T + 0.55))
    for t0 in [3.1, 3.9, 4.6]:
        mix_into(out, bollicina(rng, rng.uniform(150, 260), 0.05, rise=0.2) * 0.12, n_of(t0))
    # gocce nella piscina vuota
    for t0, acqua in [(5.4, True), (6.1, False), (6.8, True)]:
        gg = goccia_acqua(rng) if acqua else goccia_pavimento(rng)
        mix_into(out, gg * rng.uniform(0.14, 0.2), n_of(t0))
    return fade(hp(out, 25, 2), 0.01, 0.4)


# =============================================================================================
# Pulsante della botola: fungo rosso su cassetta gialla, col lampeggiante giallo
# =============================================================================================

GIRI_LAMPEGGIANTE = 1.25     # giri al secondo del lampeggiante (un lampo verso chi guarda a giro)


def contattore(rng, forza=1.0):
    """Il contattore nella cassetta gialla: scatto secco, rimbalzo, la cassetta che risuona."""
    out = np.zeros(n_of(0.6))
    clack = _norm(resonator_bank(impulso(0.5), [150, 330, 720, 1550, 3300], [0.09, 0.07, 0.05, 0.03, 0.015],
                                 [1, 0.8, 0.55, 0.35, 0.2]))
    mix_into(out, clack, 0)
    mix_into(out, clack * 0.3, n_of(0.018))
    k = n_of(0.01)
    mix_into(out, _norm(bp(white(k, rng), 1500, 9000, 2) * env_ad(k, 0.0002, 0.008)) * 0.35, 0)
    cassetta = resonator_bank(impulso(0.5), [410, 980, 1720, 2650], [0.12, 0.09, 0.06, 0.04], [1, 0.6, 0.4, 0.25])
    mix_into(out, _norm(cassetta) * 0.4, n_of(0.002))
    return f32(out * forza)


def lampeggiante(rng, n, giri):
    """Il lampeggiante rotante: motorino col riduttore (30:1), ingranaggi, lo specchio che gira
    (il carico cambia a ogni giro) e un tic del contatto strisciante a ogni giro. giri: curva."""
    giri = np.broadcast_to(np.asarray(giri, dtype=np.float64), (n,))
    f_mot = giri * 30.0
    fase = np.cumsum(giri) / SR
    mot = motorino(rng, n, np.maximum(f_mot, 1.0), 0.2)
    mot = lp(mot, 900, 2) * (0.85 + 0.15 * np.sin(2 * np.pi * fase)) * 0.3
    mot += a_rms(bp(white(n, rng), 300, 1500, 2), 0.02) * (0.6 + 0.4 * np.sin(2 * np.pi * fase + 0.8) ** 2)
    ph_i = np.cumsum(f_mot * 12.0) / SR
    ingr = (np.sin(2 * np.pi * ph_i) * 0.5 + np.sin(4 * np.pi * ph_i + 0.4) * 0.2) * 0.035
    ingr += bp(white(n, rng), 1800, 5000, 2) * 0.012
    vel = np.clip(giri / GIRI_LAMPEGGIANTE, 0, 1)
    tic = np.zeros(n)
    giro = np.floor(fase)
    for i in np.nonzero(np.diff(giro, prepend=giro[0]) > 0)[0]:
        r = resonator_bank(impulso(0.06), [2100, 3900, 5600], [0.012, 0.008, 0.005], [1, 0.5, 0.3])
        mix_into(tic, _norm(r) * 0.1, int(i))
    return f32((mot + ingr) * vel + tic)


def pulsante_botola_attiva_a(rng):
    """a: il contattore che scatta nella cassetta e il colpo della corrente che arriva (un ronzio
    che si gonfia e cala). Insieme parte lampeggiante_loop, che prende giri (in gioco: AudioLoop
    con il tono che sale da 0,35 a 1)."""
    dur = 1.6
    n = n_of(dur)
    out = np.zeros(n)
    mix_into(out, contattore(rng, 1.0), 0)
    k = n_of(1.4)
    rz = ronzio_rete(rng, k, 100.0, 16, 0.9, 0.15)
    rz = lp(rz, 2500, 2) * env_points([(0, 0), (0.02, 1.0), (0.3, 0.45), (1.4, 0.0)], k)
    mix_into(out, rz * 0.35, n_of(0.012))
    k = n_of(0.25)
    mix_into(out, _norm(lp(white(k, rng), 160, 2) * env_ad(k, 0.004, 0.2)) * 0.45, n_of(0.01))
    return fade(hp(out, 30, 2), 0.0, 0.1)


def lampeggiante_loop(rng, giri_n=4):
    """Il lampeggiante che gira (in tutte e due le versioni): giri_n giri esatti."""
    dur = giri_n / GIRI_LAMPEGGIANTE
    n = n_of(dur + 0.4)
    x = lampeggiante(rng, n, np.full(n, GIRI_LAMPEGGIANTE))
    x += ronzio_rete(rng, n, 100.0, 10, 1.1, 0.05) * 0.015
    return make_loop(hp(x, 30, 2), dur, 0.4)


def onda_giocattolo(rng, f, dur, cala=0.0, tremolo=0.0):
    """Una nota dell'elettronica giocattolo: quadra più seno da un altoparlantino. cala: semitoni
    che perde nella coda (pile scariche); tremolo: profondità del tremolio."""
    m = n_of(dur)
    tt = t_axis(m)
    giu = 2 ** (-cala * np.clip((tt - dur * 0.35) / (dur * 0.65), 0, 1) ** 1.5 / 12)
    fr = f * giu * (1 + 0.004 * np.sin(2 * np.pi * 9 * tt) + tremolo * 0.01 * np.sin(2 * np.pi * 6.5 * tt))
    ph = np.cumsum(fr) / SR
    x = np.sign(np.sin(2 * np.pi * ph)) * 0.6 + np.sin(2 * np.pi * ph) * 0.4
    return f32(x * env_points([(0, 0), (0.003, 1), (dur - 0.012, 0.8), (dur, 0)], m))


def altoparlantino(x):
    """Il suono che esce dall'altoparlante piccolo e un po' rotto della cassetta."""
    x = bp(x, 520, 4800, 2)
    x = biquad(x, 'peak', 1700, 2.0, 5)
    return f32(np.tanh(x * 2.0) * 0.5)


def pulsante_botola_attiva_b(rng):
    """b: lo scatto del contattore e un jingle giocattolo che sale (sol, si, re) con l'ultima nota
    che cala come a pile scariche. Insieme parte lampeggiante_loop (come in a); finito il jingle,
    richiamo_loop."""
    dur = 1.4
    n = n_of(dur)
    out = np.zeros(n)
    mix_into(out, contattore(rng, 0.8), 0)
    jingle = np.zeros(n_of(1.2))
    for k, (f, d, cala) in enumerate([(784.0, 0.11, 0.0), (988.0, 0.11, 0.0), (1175.0, 0.55, 1.1)]):
        mix_into(jingle, onda_giocattolo(rng, f, d, cala, tremolo=1.0 if k == 2 else 0.0), n_of(k * 0.13))
    mix_into(out, altoparlantino(jingle) * 0.55, n_of(0.09))
    return fade(hp(out, 30, 2), 0.0, 0.1)


def richiamo_loop(rng, giri_n=4):
    """b: il bi-bu da giocattolo ogni due giri del lampeggiante (1,6 s, quando la luce guarda verso
    di te), un po' stonato. Va insieme a lampeggiante_loop."""
    per = 2.0 / GIRI_LAMPEGGIANTE
    dur = giri_n / GIRI_LAMPEGGIANTE
    n = n_of(dur + 0.4)
    bip = np.zeros(n)
    for i in range(giri_n // 2):            # i bi-bu stanno fuori dalla dissolvenza del loop
        b = np.zeros(n_of(0.32))
        mix_into(b, onda_giocattolo(rng, 880.0 * (1 + rng.uniform(-0.003, 0.003)), 0.12), 0)
        mix_into(b, onda_giocattolo(rng, 698.0 * (1 + rng.uniform(-0.003, 0.003)), 0.14, cala=0.15), n_of(0.14))
        mix_into(bip, b, n_of(i * per + 0.5))
    return make_loop(hp(altoparlantino(bip), 30, 2), dur, 0.4)


# =============================================================================================
# Micro medusine luminose: aspirate dallo zaino e sparate via
# =============================================================================================

SCALA_TONI_INTERI = np.array([2093.0, 2349.3, 2637.0, 2960.0, 3322.4, 3729.3, 4186.0])


def campanellino(rng, f0, dur=0.6, smorza=1.0):
    """Un tintinnio di vetro minuscolo: modi di una campanella (non armonici), con un gemello
    scordato di un quarto di tono che batte piano: magico ma un po' storto."""
    e = impulso(dur)
    rapporti = np.array([1.0, 2.32, 4.25, 6.63])
    x = resonator_bank(e, f0 * rapporti, np.array([0.28, 0.16, 0.09, 0.05]) * smorza, [1.0, 0.45, 0.22, 0.1])
    x += resonator_bank(e, f0 * 1.0293 * rapporti[:2], np.array([0.22, 0.12]) * smorza, [0.35, 0.15])
    return _norm(x)


def medusina_aspirata_a(rng):
    """a, vetro: un tintinnio minuscolo che, risucchiato nel tubo, scende di tono e si spegne,
    con un plic d'acqua all'imbocco."""
    x = np.zeros(n_of(0.8))
    t, g = 0.0, 1.0
    for _ in range(int(rng.integers(2, 4))):
        f0 = rng.choice(SCALA_TONI_INTERI) * rng.uniform(0.99, 1.01)
        mix_into(x, campanellino(rng, f0, 0.7, rng.uniform(0.8, 1.2)) * g, n_of(t))
        t += rng.uniform(0.025, 0.045)
        g *= rng.uniform(0.45, 0.65)
    k = len(x)
    giu = env_points([(0, 1.0), (0.09, 1.0), (0.35, 0.76), (0.8, 0.7)], k)
    x = varispeed(x, giu)
    x = tv_biquad(x, 'lowpass', env_points([(0, 9000), (0.1, 7000), (0.4, 2200)], len(x)), 0.8)
    out = np.zeros(len(x) + n_of(0.05))
    mix_into(out, x, 0)
    mix_into(out, bollicina(rng, rng.uniform(1700, 2600), rng.uniform(0.006, 0.012), rise=0.6) * 0.25,
             n_of(rng.uniform(0.03, 0.08)))
    return fade(out, 0.0, 0.08)


def medusine_sparate_a(rng):
    """a, vetro: sparate via col getto, una cascata di tintinnii sulla scala a toni interi che si
    allontanano (più bassi, più ovattati) e un soffio leggero. Stereo."""
    dur = 1.8
    n = n_of(dur)
    out = np.zeros((n, 2))
    k = n_of(0.6)
    soffio = tv_biquad(white(k, rng), 'bandpass', env_points([(0, 5200), (0.6, 2400)], k), 1.5)
    mix_into(out, stereo(soffio * env_points([(0, 0), (0.04, 1), (0.6, 0)], k) ** 2 * 0.05), 0)
    t = 0.0
    for i in range(9):
        lontano = i / 8.0
        f0 = rng.choice(SCALA_TONI_INTERI) * rng.uniform(0.99, 1.01)
        x = campanellino(rng, f0, 0.6, 0.7)
        x = varispeed(x, env_points([(0, 1.0), (0.6, 0.93)], len(x)))
        x = lp(x, 9000 - 6000 * lontano, 2) * (1.0 - 0.75 * lontano)
        mix_into(out, pan(x, rng.uniform(-0.5, 0.5) * (1 - 0.5 * lontano)), n_of(t))
        t += rng.uniform(0.04, 0.09) * (1 + 1.5 * lontano)
    return fade(out, 0.0, 0.3)


def vocina(rng, f0, dur, f2_da, f2_a, f1=1300.0, scivola=0.0):
    """Una vocina minuscola e acutissima (f0 900-1600 Hz): un'onda ricca di armoniche filtrata da
    due risonanze, la seconda che si sposta (da "i" a "u" quando f2 scende). Sembra una voce, ma
    piccolissima. scivola: semitoni di cui cala il tono (negativo: sale). Picco a 1, senza
    inviluppo."""
    m = n_of(dur)
    tt = t_axis(m)
    fr = f0 * 2 ** (-scivola * (tt / dur) ** 1.2 / 12) * (1 + 0.012 * np.sin(2 * np.pi * 7.5 * tt + rng.uniform(0, 6)))
    ph = np.cumsum(fr) / SR
    src = np.zeros(m)
    for h in range(1, 10):
        if f0 * h > 9000:
            break
        src += np.sin(2 * np.pi * h * ph + rng.uniform(0, 0.3)) / h ** 0.8
    f2 = env_points([(0, f2_da), (dur, f2_a)], m)
    x = tv_biquad(src, 'bandpass', np.full(m, f1), 3.0) + tv_biquad(src, 'bandpass', f2, 5.0) * 1.2
    x += a_rms(bp(white(m, rng), 2500, 7000, 2), 0.05 * float(np.sqrt(np.mean(np.square(x)))))
    return _norm(x)


def medusina_aspirata_b(rng):
    """b, vive: una vocina minuscola che fa "ih?" (il tono sale) e, risucchiata nel tubo, scende e
    si ovatta ("ih-uu"), con un plic d'acqua all'imbocco."""
    d = rng.uniform(0.2, 0.28)
    x = vocina(rng, rng.uniform(1100, 1500), d, 3300, 2500, scivola=-rng.uniform(1.0, 2.5))
    x *= env_points([(0, 0), (0.015, 1.0), (d * 0.6, 0.9), (d, 0)], len(x))
    x = np.concatenate([x, np.zeros(n_of(0.15))])
    x = varispeed(x, env_points([(0, 1.0), (0.1, 1.0), (0.4, 0.75)], len(x)))
    x = tv_biquad(x, 'lowpass', env_points([(0, 9000), (0.12, 6000), (0.35, 1500)], len(x)), 0.8)
    out = np.zeros(len(x) + n_of(0.08))
    mix_into(out, x, 0)
    mix_into(out, bollicina(rng, rng.uniform(1700, 2600), rng.uniform(0.006, 0.012), rise=0.6) * 0.25,
             n_of(rng.uniform(0.02, 0.07)))
    return fade(out, 0.0, 0.08)


def medusine_sparate_b(rng):
    """b, vive: sparate via, le vocine scivolano giù mentre volano lontano ("wiii-uu"), con un coro
    di vocine sottilissimo, a un semitono l'una dall'altra, che cala e si spegne. Stereo."""
    dur = 2.2
    n = n_of(dur)
    out = np.zeros((n, 2))
    k = n_of(0.6)
    soffio = tv_biquad(white(k, rng), 'bandpass', env_points([(0, 5200), (0.6, 2400)], k), 1.5)
    mix_into(out, stereo(a_rms(soffio, 0.05) * env_points([(0, 0), (0.04, 1), (0.6, 0)], k) ** 2), 0)
    t = 0.0
    for i in range(6):
        lontano = i / 5.0
        d = rng.uniform(0.45, 0.6)
        x = vocina(rng, rng.uniform(1200, 1650), d, 3300, 1000, scivola=rng.uniform(5.0, 8.0))
        x *= env_points([(0, 0), (0.02, 1.0), (d * 0.5, 0.7), (d, 0)], len(x))
        x = lp(x, 8000 - 5000 * lontano, 2) * (1.0 - 0.7 * lontano)
        mix_into(out, pan(x, rng.uniform(-0.5, 0.5)), n_of(t))
        t += rng.uniform(0.07, 0.14)
    # il coro sottilissimo: tre vocine su "u", a un semitono l'una dall'altra, che calano insieme
    k = n_of(1.7)
    coro = np.zeros(k)
    for f in (1046.5, 1108.7, 1174.7):
        coro += vocina(rng, f, 1.7, 1100, 900, f1=1150.0, scivola=1.0)
    coro = _norm(coro) * env_points([(0, 0), (0.3, 1.0), (1.7, 0)], k) * 0.18
    mix_into(out, np.stack([coro, np.roll(coro, n_of(0.011))], axis=1), n_of(0.12))
    return fade(out, 0.0, 0.3)


# =============================================================================================
# Portone scorrevole della sala della torre
# =============================================================================================

MODI_PORTONE = np.array(MODI_LAMIERA) * 0.62      # una lastra d'acciaio grande: modi più bassi


def colpo_acciaio(rng, forza=1.0, basso=1.0, coda=1.0):
    """Un colpo pesante d'acciaio: botto basso, la lastra che rimbomba, il clangore."""
    out = np.zeros(n_of(3.0))
    k = n_of(0.35)
    mix_into(out, _norm(lp(white(k, rng), 150, 2) * env_ad(k, 0.003, 0.3)) * 0.7 * basso, 0)
    mix_into(out, np.sin(2 * np.pi * np.cumsum(np.full(k, 52.0)) / SR) * env_ad(k, 0.002, 0.3) * 0.8 * basso, 0)
    fr = MODI_PORTONE * rng.uniform(0.95, 1.05)
    lastra = resonator_bank(impulso(3.0), fr, np.linspace(2.2, 0.6, len(fr)) * coda, 1 / (1 + np.arange(len(fr)) * 0.3))
    mix_into(out, _norm(lastra) * 0.5, 0)
    clang = resonator_bank(impulso(1.0), rng.uniform(0.95, 1.05) * np.array([690, 1130, 1720, 2480, 3350]),
                           [0.6, 0.45, 0.35, 0.25, 0.15], [1, 0.8, 0.6, 0.4, 0.25])
    mix_into(out, _norm(clang) * 0.3, 0)
    k = n_of(0.03)
    mix_into(out, bp(white(k, rng), 800, 6000, 2) * env_ad(k, 0.0005, 0.025) * 0.5, 0)
    return f32(out * forza)


def serratura(rng, dura=False):
    """Il chiavistello della serratura elettrica: lo scatto del solenoide e il catenaccio che
    sbatte in apertura. dura: prima gratta (ruggine)."""
    out = np.zeros(n_of(1.2))
    t0 = 0.0
    if dura:
        k = n_of(0.3)
        gr = bp(white(k, rng), 600, 3200, 2) * (0.4 + 0.6 * np.abs(np.sin(2 * np.pi * 23 * t_axis(k))) ** 3)
        mix_into(out, gr * env_points([(0, 0), (0.05, 1), (0.3, 0.6)], k) * 0.35, 0)
        t0 = 0.28
    sol = resonator_bank(impulso(0.2), [480, 1150, 2600], [0.03, 0.02, 0.01], [1, 0.6, 0.3])
    mix_into(out, _norm(sol) * 0.4, 0)
    cat = resonator_bank(impulso(0.8), [95, 180, 340, 620, 1150, 2200], [0.4, 0.3, 0.2, 0.12, 0.08, 0.04],
                         [1, 0.9, 0.7, 0.5, 0.3, 0.2])
    mix_into(out, _norm(cat) * 0.9, n_of(t0 + 0.06))
    k = n_of(0.08)
    mix_into(out, _norm(lp(white(k, rng), 300, 2) * env_ad(k, 0.002, 0.06)) * 0.6, n_of(t0 + 0.06))
    return f32(out)


def motore_portone(rng, n, giri, sforzo=None):
    """Il motore del portone: ronzio di rete, il motore e il riduttore che fischia; giri da 0 a 1
    (curva), sforzo da 0 a 1 (il motore che fatica: più grave, più sporco)."""
    giri = np.broadcast_to(np.asarray(giri, dtype=np.float64), (n,))
    sf = np.zeros(n) if sforzo is None else np.broadcast_to(np.asarray(sforzo, dtype=np.float64), (n,))
    f = np.maximum(105.0 * giri * (1 - 0.3 * sf), 1.0)
    mot = lp(motorino(rng, n, f, 0.5 + sf), 900, 2) * 0.15
    ph = np.cumsum(f * 7.0) / SR
    fischio = np.sin(2 * np.pi * ph) * 0.03 * giri
    rz = lp(ronzio_rete(rng, n, 100.0, 12, 1.0, 0.05), 700, 2) * (0.05 + 0.08 * sf)
    acceso = np.clip(giri * 6, 0, 1)
    return f32((mot * giri + fischio + rz * acceso) * (1 + 0.6 * sf))


def rotolamento(rng, n, vel, ruvido=0.0):
    """Il portone che scorre sui rulli: rombo, il rullo che batte a ogni giro, i giunti della
    rotaia (due rulli, uno dopo l'altro), la lastra che rimbomba. vel: curva 0..1 (1 = 0,8 m/s).
    ruvido: rulli arrugginiti (grattano, battono a caso)."""
    vel = np.broadcast_to(np.asarray(vel, dtype=np.float64), (n,))
    rombo = a_rms(lp(colored(n, rng, -6.0, fmin=25.0), 240, 2), 0.2) * vel
    giri_rullo = np.cumsum(vel * 4.2) / SR
    battito = (0.6 + 0.4 * np.abs(np.sin(np.pi * giri_rullo)) ** 4)
    out = rombo * battito * 0.5
    stride = bp(white(n, rng), 1200, 4500, 2) * vel * (0.3 + 0.7 * np.clip(smooth_noise(n, 2.0, rng) + 0.2, 0, 1))
    out += stride * (0.02 + 0.06 * ruvido)
    if ruvido > 0:
        gratta = bp(white(n, rng), 500, 2500, 2) * vel * np.clip(smooth_noise(n, 9.0, rng, 2) * 1.5, 0, 1) ** 2
        out += gratta * 0.12 * ruvido
    # i giunti della rotaia: ogni 0,9 m, prima il rullo davanti e poi quello dietro (1,6 m dopo)
    pos = np.cumsum(vel * 0.8) / SR
    for passo, ritardo, g in [(0.9, 0.0, 1.0), (0.9, 1.6, 0.8)]:
        giunto = np.floor((pos - ritardo) / passo)
        for i in np.nonzero((np.diff(giunto, prepend=giunto[0]) > 0) & (pos > ritardo))[0]:
            fr = np.array([120, 260, 480, 830, 1400]) * rng.uniform(0.9, 1.1)
            c = lp(resonator_bank(impulso(0.4), fr, [0.12, 0.09, 0.06, 0.04, 0.02], [1, 0.7, 0.45, 0.3, 0.15]), 2500, 2)
            mix_into(out, _norm(c) * g * float(vel[i]) * rng.uniform(0.6, 1.0) * (1.0 + ruvido * rng.uniform(-0.4, 0.6)) * 0.7,
                     int(i))
    # la lastra grande eccitata dal rotolamento: il rimbombo cavo del portone
    ecc = lp(white(n, rng), 600, 2) * vel * 0.3 + out * 0.3
    lastra = resonator_bank(ecc, MODI_PORTONE[:7], [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4],
                            [1, 0.8, 0.6, 0.45, 0.3, 0.2, 0.12])
    return f32(out + _norm(lastra) * 0.35 * np.clip(vel * 2, 0, 1))


def portone_torre_apre_a(rng):
    """a, motore: la serratura che scatta, il motore che parte, il portone che scorre liscio (5 s)
    e sbatte a fine corsa; il motore si ferma. Mono, 8,5 s."""
    dur = 8.5
    n = n_of(dur)
    out = np.zeros(n)
    mix_into(out, serratura(rng, False), 0)
    # la lastra che trema quando il catenaccio si sblocca
    mix_into(out, colpo_acciaio(rng, 0.4, basso=0.4, coda=0.6), n_of(0.07))
    T0, T1 = 0.45, 6.4                          # motore acceso, fine corsa
    k = n - n_of(T0)
    tt = t_axis(k)
    giri = np.clip(tt / 0.7, 0, 1) ** 1.5 * np.clip(1 - (tt - (T1 - T0 + 0.05)) / 0.6, 0, 1)
    mix_into(out, motore_portone(rng, k, giri), n_of(T0))
    vel = np.clip((tt - 0.25) / 1.1, 0, 1) ** 1.6 * np.clip((T1 - T0 - tt) / 0.9, 0, 1) ** 0.8
    vel = np.maximum(vel, 0) * (tt < T1 - T0)
    mix_into(out, rotolamento(rng, k, vel, 0.0), n_of(T0))
    mix_into(out, colpo_acciaio(rng, 1.0, basso=1.0, coda=1.0), n_of(T1))
    # il contattore del motore che si apre, la lastra che vibra ancora
    rel = resonator_bank(impulso(0.2), [300, 780, 1900], [0.05, 0.03, 0.015], [1, 0.6, 0.3])
    mix_into(out, rel * 0.15, n_of(T1 + 0.5))
    return fade(hp(out, 25, 2), 0.0, 0.6)


def stridio(rng, dur, forza=1.0, alto=1.0):
    """Acciaio che striscia sull'acciaio e stride (attrito a scatti sui modi di una lamiera)."""
    g = gemito_attrito(rng, dur)
    k = len(g)
    s = resonator_bank(g, np.array([380, 610, 930, 1420, 2050]) * alto * rng.uniform(0.95, 1.05),
                       [0.25, 0.2, 0.15, 0.1, 0.07], [1, 0.8, 0.6, 0.35, 0.2])
    s = _norm(s) * 0.7 + _norm(g) * 0.3
    return f32(s * env_points([(0, 0), (0.03, 1), (dur * 0.7, 0.9), (dur, 0)], k) * forza)


def portone_torre_apre_b(rng):
    """b, ruggine: la serratura dura, il motore che si sforza, il portone che si blocca e strappa
    tre volte stridendo; poi si libera, scorre grattando, sbatte. Pezzetti di ruggine. Mono, 10 s."""
    dur = 10.0
    n = n_of(dur)
    out = np.zeros(n)
    mix_into(out, serratura(rng, True), 0)
    mix_into(out, colpo_acciaio(rng, 0.3, basso=0.4, coda=0.7), n_of(0.36))
    T0 = 0.75
    k = n - n_of(T0)
    tt = t_axis(k)
    STRAPPI = [0.55, 1.25, 1.9]                 # dall'accensione del motore
    LIBERO = 2.55
    T1 = 7.2 - T0                               # fine corsa
    sforzo = np.clip(tt / 0.4, 0, 1) * np.clip(1 - (tt - LIBERO) / 0.4, 0, 1) * 0.9
    giri = np.clip(tt / 0.6, 0, 1) * (1 - 0.45 * sforzo) * np.clip(1 - (tt - (T1 + 0.05)) / 0.6, 0, 1)
    giri = giri * (1 + 0.08 * sforzo * smooth_noise(k, 3.0, rng))
    mix_into(out, motore_portone(rng, k, giri, sforzo), n_of(T0))
    for i, ts in enumerate(STRAPPI):
        d = rng.uniform(0.3, 0.45)
        mix_into(out, stridio(rng, d, 0.55 + 0.15 * i, rng.uniform(0.9, 1.15)), n_of(T0 + ts))
        mix_into(out, colpo_acciaio(rng, 0.35 + 0.1 * i, basso=0.8, coda=0.6), n_of(T0 + ts + d * 0.8))
    # si libera: un colpo secco, poi scorre grattando, con uno stridio lungo a metà corsa
    mix_into(out, colpo_acciaio(rng, 0.55, basso=0.9, coda=0.8), n_of(T0 + LIBERO))
    vel = np.clip((tt - LIBERO) / 0.5, 0, 1) * np.clip((T1 - tt) / 0.7, 0, 1) ** 0.8
    vel = vel * (0.85 + 0.15 * smooth_noise(k, 2.5, rng))
    mix_into(out, rotolamento(rng, k, np.maximum(vel, 0), 1.0), n_of(T0))
    mix_into(out, stridio(rng, 1.9, 0.45, 0.8), n_of(T0 + LIBERO + 1.0))
    mix_into(out, colpo_acciaio(rng, 1.15, basso=1.1, coda=1.1), n_of(T0 + T1))
    # pezzetti di ruggine e di vernice che cadono, e un bullone che rimbalza
    for _ in range(14):
        tp = T0 + T1 + rng.uniform(0.05, 1.2)
        k2 = n_of(0.02)
        mix_into(out, bp(white(k2, rng), 2500, 8000, 2) * env_ad(k2, 0.0005, 0.015) * rng.uniform(0.04, 0.1), n_of(tp))
    tb, g = T0 + T1 + 0.35, 0.3
    for _ in range(6):
        r = resonator_bank(impulso(0.3), rng.uniform(0.97, 1.03) * np.array([2300, 5100, 7900]), [0.08, 0.05, 0.03],
                           [1, 0.5, 0.25])
        mix_into(out, _norm(r) * g, n_of(tb))
        tb += 0.16 * (0.7 ** _)
        g *= 0.7
    return fade(hp(out, 25, 2), 0.0, 0.6)


# =============================================================================================
# Anteprime: i suoni nella scena
# =============================================================================================

class Scena:
    """Una scena da ascoltare: fondi della sala (bus Ambiente), effetti col riverbero della sala
    (bus Effetti), suoni da vicino senza riverbero (lo zaino di chi gioca). I fondi (pioggia sulla
    cupola, vento, nave) sono 6 dB sotto il gioco, così i suoni proposti si sentono bene."""

    def __init__(self, dur, fondi=-6.0):
        self.dur = dur
        self.n = n_of(dur)
        self.amb = np.zeros((self.n, 2), dtype=np.float32)
        self.eff = np.zeros((self.n, 2), dtype=np.float32)
        self.vicino = np.zeros((self.n, 2), dtype=np.float32)
        if fondi is None:                      # una scena vuota, per comporre un gruppo di suoni
            return
        for rel, g, off in [('ambiente/pioggia_cupola_loop.ogg', 0.0, 5.0), ('ambiente/vento_loop.ogg', -2.0, 9.0),
                            ('ambiente/nave_loop.ogg', 0.0, 2.0)]:
            mix_into(self.amb, fade(tile(leggi(rel), dur, off), 1.0, 0.0) * db(g + fondi), 0)

    def metti(self, x, t, g_db=0.0, p=0.0, dove='eff'):
        dest = getattr(self, dove)
        mix_into(dest, pan(x * db(g_db), p) if x.ndim == 1 else x * db(g_db), n_of(t))

    def loop(self, x, eventi, g_db=0.0, p=0.0, offset=0.0, dove='eff'):
        """Un loop come AudioLoop nel gioco: eventi [(t, volume, tono)] con le rampe di volume e
        tono di audio_loop.gd."""
        vol, ton = curva_loop(eventi, self.dur)
        src = tile(x, self.dur * 1.6 + 1.0, offset)
        y = varispeed(src, ton)[:self.n]
        y = np.pad(y, (0, self.n - len(y))) * vol[:self.n]
        self.metti(y, 0.0, g_db, p, dove)

    def zaino_aspira(self, t0, t1, g_db=-3.0):
        mix_into(self.vicino, stereo(leggi('giocatore/zaino_aspira_inizio.ogg', 1) * db(g_db)), n_of(t0))
        asp = tile(leggi('giocatore/zaino_aspira_loop.ogg', 1), t1 - t0 - 0.45 + 0.2)
        mix_into(self.vicino, stereo(fade(asp, 0.1, 0.12) * db(g_db)), n_of(t0 + 0.45))
        mix_into(self.vicino, stereo(leggi('giocatore/zaino_aspira_fine.ogg', 1) * db(g_db)), n_of(t1))

    def zaino_getto(self, t0, t1, impatto_db=-12.0, g_db=-3.0):
        mix_into(self.vicino, stereo(leggi('giocatore/zaino_getto_inizio.ogg', 1) * db(g_db + 1)), n_of(t0))
        get = tile(leggi('giocatore/zaino_getto_loop.ogg', 1), t1 - t0 - 0.12 + 0.1)
        mix_into(self.vicino, stereo(fade(get, 0.08, 0.1) * db(g_db)), n_of(t0 + 0.12))
        imp = tile(leggi('giocatore/zaino_impatto_loop.ogg', 1), t1 - t0 - 0.3)
        self.metti(lp(fade(imp, 0.1, 0.2), 5000), t0 + 0.3, impatto_db, 0.15)
        mix_into(self.vicino, stereo(leggi('giocatore/zaino_getto_fine.ogg', 1) * db(g_db - 1)), n_of(t1))

    def scrivi(self, nome, wet=0.26):
        eff = reverb(self.eff, ir_sala(), wet=wet, dry=1.0, tail=False)
        out = hp(self.amb + eff + self.vicino, 20, 2)
        out = fade(out, 0.3, 2.0)
        out = limiter(out * db(-16.0 - lufs(out)), -1.0)
        path = os.path.join(ANTEPRIMA, nome)
        write_ogg(path, out, 5)
        print(f'anteprima: {path}  {self.dur:.1f}s  LUFS {lufs(out):.1f}  picco {np.abs(out).max():.2f}')
        return out


def anteprima_piscina(versione):
    """Dal bordo della parte profonda: la prima zainata (piscina piena) e l'acqua sparata fuori
    sulle piastrelle; poi l'ultima zainata, quando l'acqua finisce, e la piscina vuota."""
    rng = np.random.default_rng(1605 if versione == 'a' else 2605)
    loop_f, vuota_f = ((piscina_svuota_loop_a, piscina_vuota_a) if versione == 'a'
                       else (piscina_svuota_loop_b, piscina_vuota_b))
    gorgo = loop_f(rng)
    gorgo = normalize_lufs(gorgo, -20.0, -1.0)
    vuota = normalize_lufs(vuota_f(rng), -14.0, -1.0, short=True)
    s = Scena(23.0)
    G = distanza_db(3.0, 4.0) + 3.0            # il gorgo è dove aspiri, a 3 m (un po' in avanti)
    # prima zainata: la piscina è piena
    s.zaino_aspira(1.0, 5.6)
    s.loop(gorgo, [(1.15, 1.0, 1.0), (5.6, 0.0, 1.0)], G, 0.1)
    mix_into(s.vicino, stereo(leggi('giocatore/zaino_pieno.ogg', 1) * db(-2)), n_of(5.35))
    s.zaino_getto(6.5, 9.2)
    # (la seconda e la terza zainata non ci sono) l'ultima: poca acqua, il gorgo è più alto
    s.zaino_aspira(11.0, 15.7)
    s.loop(gorgo, [(11.15, 0.9, 1.12), (14.6, 0.0, 1.12)], G, 0.1, offset=2.3)
    s.metti(vuota, 14.2, G, 0.1)
    return s.scrivi(f'proposta_piscina_{versione}.ogg')


def anteprima_pulsante(versione):
    """A piscina vuota il pulsante si attiva sulla parete sud, a 9 m: lo scatto e il lampeggiante
    che prende giri (b: il jingle, poi il bi-bu); poi ci si avvicina fino a 3 m."""
    rng = np.random.default_rng(1606 if versione == 'a' else 2606)
    attiva = pulsante_botola_attiva_a(rng) if versione == 'a' else pulsante_botola_attiva_b(rng)
    attiva = normalize_lufs(attiva, -15.0, -1.0, short=True)
    giro = normalize_lufs(lampeggiante_loop(rng), -21.0 if versione == 'a' else -24.0, -1.0)
    s = Scena(17.0)
    for tc in [0.6, 4.3, 9.6, 13.8]:
        s.metti(leggi('ambiente/goccia_acqua_0%d.ogg' % rng.integers(1, 7), 1), tc, -16, rng.uniform(-0.6, 0.6))
    T = 1.5
    # chi ascolta resta a 9 m, poi si avvicina fino a 3 m (il pulsante è un po' a sinistra)
    t = np.arange(s.n) / SR
    dist = np.interp(t, [0, 7.0, 13.0, 17.0], [9.0, 9.0, 3.0, 3.0])
    g = (10 ** (np.minimum(0.0, 20 * np.log10(5.0 / dist)) / 20))[:, None]
    pul = Scena(17.0, fondi=None)
    pul.metti(attiva, T, 0.0, -0.25)
    # il lampeggiante prende giri: AudioLoop con il tono che sale da 0,35 a 1
    pul.loop(giro, [(T + 0.1, 1.0, 0.35), (T + 0.12, 1.0, 1.0)], 0.0, -0.25)
    if versione == 'b':
        bip = normalize_lufs(richiamo_loop(rng), -20.0, -1.0)
        pul.loop(bip, [(T + 1.3, 1.0, 1.0)], 0.0, -0.25)
    s.eff += pul.eff * g
    return s.scrivi(f'proposta_pulsante_botola_{versione}.ogg')


def anteprima_medusine(versione):
    """Si aspira dalla piscina con le medusine nell'acqua (si sentono appena, sotto lo zaino),
    poi si sparano fuori. Dopo una pausa, le stesse medusine da sole e più forti, per sentirle bene."""
    rng = np.random.default_rng(1607 if versione == 'a' else 2607)
    asp_f, spa_f = ((medusina_aspirata_a, medusine_sparate_a) if versione == 'a'
                    else (medusina_aspirata_b, medusine_sparate_b))
    aspirate = [normalize_lufs(asp_f(rng), -24.0, -1.0, short=True) for _ in range(6)]
    sparate = normalize_lufs(spa_f(rng), -21.0, -1.0, short=True)
    s = Scena(21.5)
    # in gioco: aspiri (con le medusine che entrano nel tubo), poi spari fuori
    s.zaino_aspira(1.0, 6.2)
    t = 1.6
    for i, x in enumerate(aspirate):
        s.metti(x, t, 0.0, rng.uniform(-0.15, 0.15), dove='vicino')
        t += rng.uniform(0.55, 0.95)
    mix_into(s.vicino, stereo(leggi('giocatore/zaino_pieno.ogg', 1) * db(-2)), n_of(5.95))
    s.zaino_getto(7.2, 8.5)
    s.metti(sparate, 7.4, 0.0, 0.0)
    seconda = normalize_lufs(spa_f(np.random.default_rng(17 if versione == 'a' else 27)), -21.0, -1.0, short=True)
    s.metti(seconda, 8.1, -6.0, 0.1)            # una seconda manciata, più lontana
    # da sole, più forti (+12 dB)
    t = 12.6
    for i, x in enumerate(aspirate[:4]):
        s.metti(x, t, 12.0, (-0.2, 0.1, -0.05, 0.2)[i], dove='vicino')
        t += 0.62
    s.metti(sparate, 16.0, 12.0, 0.0)
    return s.scrivi(f'proposta_medusine_{versione}.ogg')


def anteprima_portone(versione):
    """Dopo la tappa 8, nella sala al buio: il portone della sala della torre, a 7 m, si apre."""
    rng = np.random.default_rng(1608 if versione == 'a' else 2608)
    x = portone_torre_apre_a(rng) if versione == 'a' else portone_torre_apre_b(rng)
    x = normalize_lufs(x, -14.0, -1.0, short=True)
    s = Scena(len(x) / SR + 4.5)
    for tc in [0.7, 2.6]:
        s.metti(leggi('ambiente/goccia_acqua_0%d.ogg' % rng.integers(1, 7), 1), tc, -17, rng.uniform(-0.6, 0.6))
    s.metti(x, 1.5, distanza_db(7.0, 6.0), 0.3)
    return s.scrivi(f'proposta_portone_torre_{versione}.ogg', wet=0.3)


def main(quali=('piscina', 'pulsante', 'medusine', 'portone')):
    for v in ('a', 'b'):
        if 'piscina' in quali:
            anteprima_piscina(v)
        if 'pulsante' in quali:
            anteprima_pulsante(v)
        if 'medusine' in quali:
            anteprima_medusine(v)
        if 'portone' in quali:
            anteprima_portone(v)


if __name__ == '__main__':
    main(sys.argv[1:] or ('piscina', 'pulsante', 'medusine', 'portone'))
