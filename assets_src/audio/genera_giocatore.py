"""Suoni del giocatore: passi (piastrelle asciutte e bagnate, acqua, metallo, scala a pioli),
atterraggi, salto, torcia, zaino-pompa (getto, aspirazione, serbatoio, pompa, sciabordio,
ricarica), tuffo e riemersione. Sintesi più campioni CC0 di Kenney (passi e metallo).
Uscita: godot/audio/giocatore/.
"""
import numpy as np

from comune import kenney, salva
from genera_ambiente import bollicina, treno_impulsi
from lib_audio import (SR, biquad, bp, brown, comb, env_ad, env_points, eq, f32, fade, hp, lp, make_loop,
                       mix_into, n_of, pink, pitch, resample_ratio, resonator_bank, smooth_noise, t_axis,
                       trim_silence, tv_biquad, white)

CART = 'giocatore'


def norm(x):
    p = np.abs(x).max()
    return x / p if p > 0 else x


# --- passi ----------------------------------------------------------------------------------

def tacco_piastrella(rng, i):
    """Il passo su piastrella: tacco e punta (passo su cemento di Kenney) più il 'tic' della ceramica."""
    base = norm(kenney('footstep_concrete_00%d.ogg' % (i % 5)))
    base = pitch(base, rng.uniform(-1.2, 1.2))
    punta = norm(kenney('footstep_concrete_00%d.ogg' % ((i + 3) % 5)))
    punta = hp(pitch(punta, rng.uniform(1.0, 3.0)), 400) * rng.uniform(0.25, 0.4)
    exc = hp(base, 1200) * 0.8
    tick = resonator_bank(exc, rng.uniform(0.92, 1.08) * np.array([2700, 4150, 6300, 8200]),
                          [0.03, 0.022, 0.015, 0.01], [0.9, 0.6, 0.35, 0.2])
    out = np.zeros(n_of(0.4))
    mix_into(out, base, 0)
    mix_into(out, tick, 0)
    mix_into(out, punta, n_of(rng.uniform(0.045, 0.07)))
    out = eq(out, [('lowshelf', 250, 0.7, -6), ('peak', 3400, 0.9, 5), ('highshelf', 6500, 0.7, 2)])
    return out


def strato_bagnato(rng, forza=1.0, goccioline=True):
    """Lo 'splat' della suola sull'acqua sottile e le goccioline che schizzano. goccioline=False:
    solo lo splat e il risucchio della suola (i numeri casuali si estraggono lo stesso, così il
    resto non cambia; per l'anteprima di confronto del 16 ottobre)."""
    n = n_of(0.35)
    out = np.zeros(n)
    k = n_of(0.05)
    splat = bp(white(k, rng), 700, 4500, 2) * env_ad(k, 0.001, 0.035)
    mix_into(out, splat * 0.8 * forza, 0)
    # risucchio della suola che si stacca (breve e un po' tonale)
    k = n_of(0.06)
    tt = t_axis(k)
    f = 350 + 600 * tt / tt[-1]
    suck = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_points([(0, 0), (0.01, 1), (0.06, 0)], k) * 0.12
    suck += bp(white(k, rng), 400, 1500, 2) * env_points([(0, 0), (0.015, 1), (0.06, 0)], k) * 0.2
    mix_into(out, suck * forza, n_of(rng.uniform(0.07, 0.12)))
    for _ in range(rng.integers(4, 9)):
        f0, tau = rng.uniform(1600, 4200), rng.uniform(0.004, 0.012)
        g, t0 = rng.uniform(0.05, 0.2), rng.uniform(0.005, 0.15)
        if goccioline:
            mix_into(out, bollicina(rng, f0, tau, rise=0.6) * g * forza, n_of(t0))
    return out


def passo_piastrelle(rng, i):
    return fade(trim_silence(tacco_piastrella(rng, i)), 0, 0.02)


def passo_bagnato(rng, i, goccioline=True):
    out = np.zeros(n_of(0.45))
    mix_into(out, tacco_piastrella(rng, i) * 0.6, 0)
    mix_into(out, strato_bagnato(rng, goccioline=goccioline), n_of(0.004))
    return fade(trim_silence(out), 0, 0.03)


def passo_acqua(rng, i, forza=1.0):
    """Si cammina nell'acqua (caviglie/polpacci): sciabordio, bolle e gocce che ricadono."""
    dur = 0.85
    n = n_of(dur)
    out = np.zeros(n)
    k = n_of(0.45)
    e = env_points([(0, 0), (0.02, 1), (0.12, 0.6), (0.45, 0)], k) ** 1.5
    spl = bp(white(k, rng), 250, 2600, 2) * e
    slosh = lp(white(k, rng), 600, 2) * env_points([(0, 0), (0.05, 1), (0.3, 0.3), (0.45, 0)], k)
    mix_into(out, spl * 0.7 * forza + slosh * 0.5, 0)
    for _ in range(int(rng.integers(14, 26) * forza)):
        b = bollicina(rng, rng.uniform(350, 1600), rng.uniform(0.008, 0.03), rise=0.4)
        mix_into(out, b * rng.uniform(0.04, 0.16), n_of(rng.uniform(0.0, 0.3)))
    for _ in range(rng.integers(3, 7)):
        b = bollicina(rng, rng.uniform(1500, 3500), rng.uniform(0.005, 0.012), rise=0.9)
        mix_into(out, b * rng.uniform(0.05, 0.15), n_of(rng.uniform(0.25, 0.6)))
    return fade(out, 0.002, 0.1)


def passo_metallo(rng, i):
    """Ballatoio di lamiera: suola + piastra (Kenney) + rimbombo vuoto sotto."""
    out = np.zeros(n_of(0.6))
    step = norm(kenney('footstep_concrete_00%d.ogg' % ((i + 2) % 5))) * 0.6
    plate = norm(kenney('impactPlate_light_00%d.ogg' % (i % 5)))
    plate = pitch(plate, rng.uniform(-3, -1)) * 0.5
    mix_into(out, step, 0)
    mix_into(out, plate, 0)
    hollow = resonator_bank(step, rng.uniform(0.9, 1.1) * np.array([180, 310, 470]), [0.18, 0.12, 0.08],
                            [0.5, 0.3, 0.2])
    mix_into(out, hollow, 0)
    return fade(trim_silence(lp(out, 9000)), 0, 0.05)


def passo_scala(rng, i):
    """Mano e piede su un piolo di metallo: colpo leggero e il tubo che suona un po'."""
    out = np.zeros(n_of(0.6))
    hit = norm(kenney('impactMetal_light_00%d.ogg' % (i % 5)))
    hit = pitch(hit, rng.uniform(-5, -3)) * 0.6
    mix_into(out, hit, 0)
    pipe = resonator_bank(hit * 0.3, rng.uniform(0.95, 1.05) * np.array([640, 1730, 3350]),
                          [0.3, 0.2, 0.12], [0.6, 0.3, 0.15])
    mix_into(out, pipe, 0)
    grip = bp(white(n_of(0.06), rng), 1500, 6000, 2) * env_ad(n_of(0.06), 0.003, 0.05) * 0.15
    mix_into(out, grip, n_of(0.01))
    return fade(trim_silence(out), 0, 0.05)


def atterraggio(rng, sup, i):
    out = np.zeros(n_of(1.0))
    thud = norm(kenney('impactSoft_medium_00%d.ogg' % (i % 5)))
    if sup == 'piastrelle':
        mix_into(out, tacco_piastrella(rng, i), 0)
        mix_into(out, tacco_piastrella(rng, i + 2) * 0.8, n_of(0.035))
        mix_into(out, thud * 0.8, 0)
    elif sup == 'bagnato':
        mix_into(out, tacco_piastrella(rng, i) * 0.7, 0)
        mix_into(out, tacco_piastrella(rng, i + 2) * 0.5, n_of(0.03))
        mix_into(out, strato_bagnato(rng, 1.6), 0)
        mix_into(out, strato_bagnato(rng, 1.2), n_of(0.03))
        mix_into(out, thud * 0.7, 0)
    elif sup == 'acqua':
        mix_into(out, passo_acqua(rng, i, 1.8), 0)
        mix_into(out, passo_acqua(rng, i + 1, 1.2) * 0.7, n_of(0.05))
    elif sup == 'metallo':
        mix_into(out, passo_metallo(rng, i), 0)
        mix_into(out, passo_metallo(rng, i + 1) * 0.8, n_of(0.03))
        big = norm(kenney('impactMetal_heavy_00%d.ogg' % (i % 5)))
        mix_into(out, pitch(big, -3) * 0.5, 0)
        mix_into(out, thud * 0.5, 0)
    return fade(trim_silence(out), 0, 0.06)


def salto(rng, i):
    c = norm(kenney('cloth%d.ogg' % (1 + i % 2)))
    c = trim_silence(c)
    return fade(c[:n_of(0.35)], 0, 0.08) * 0.7


# --- torcia ---------------------------------------------------------------------------------

def clic_torcia(rng, acceso):
    """Interruttore a scatto di una torcia di plastica: pressione e scatto della molla."""
    n = n_of(0.16)
    out = np.zeros(n)
    modi = np.array([1350, 2900, 4700, 7600]) * (1.08 if acceso else 0.9)
    for k, (t0, g) in enumerate([(0.0, 0.6), (0.018 if acceso else 0.026, 1.0)]):
        e = np.zeros(n_of(0.06))
        e[:n_of(0.0006)] = white(n_of(0.0006), rng)
        r = resonator_bank(e, modi * rng.uniform(0.97, 1.03), [0.012, 0.02, 0.012, 0.008], [0.7, 1.0, 0.6, 0.35])
        mix_into(out, r * g, n_of(t0))
    out = hp(out, 300)
    return fade(out, 0, 0.02)


# --- zaino-pompa ------------------------------------------------------------------------------

def motorino(rng, n, f_curve, carico=0.0):
    """Motorino a corrente continua di un giocattolo: dente di sega ricco, un po' instabile."""
    f = f_curve * (1 + 0.01 * smooth_noise(n, 8, rng) - 0.03 * carico * (0.5 + 0.5 * smooth_noise(n, 2, rng)))
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1) - 1
    sq = np.sign(np.sin(2 * np.pi * ph * 2))
    x = 0.7 * saw + 0.15 * sq
    x = bp(x, 150, 2500, 2)
    x = eq(x, [('peak', 900, 2, 5), ('peak', 1800, 3, 3)])
    return f32(x)


def getto_loop(rng, dur=2.0, xf=0.4):
    n = n_of(dur + xf)
    sib = bp(white(n, rng), 1200, 9000, 2)
    sib = biquad(sib, 'peak', 3800, 1.2, 6)
    turb = bp(white(n, rng), 350, 1300, 2) * (0.6 + 0.4 * smooth_noise(n, 30, rng))
    fischio = tv_biquad(white(n, rng), 'bandpass', 1850 * (1 + 0.01 * smooth_noise(n, 3, rng)), 40) * 0.5
    mot = motorino(rng, n, np.full(n, 165.0)) * 0.12
    out = sib * 0.5 + turb * 0.35 + fischio + mot
    out *= (0.92 + 0.08 * smooth_noise(n, 12, rng))
    return make_loop(out, dur, xf)


def getto_inizio(rng):
    n = n_of(0.45)
    out = np.zeros(n)
    out[:n_of(0.12)] += clic_torcia(rng, True)[:n_of(0.12)] * 0.7
    k = n_of(0.4)
    pss = bp(white(k, rng), 900, 9000, 2) * env_points([(0, 0), (0.006, 1), (0.1, 0.55), (0.4, 0)], k)
    mix_into(out, pss * 0.6, n_of(0.02))
    for _ in range(5):
        b = bollicina(rng, rng.uniform(1500, 3500), rng.uniform(0.004, 0.01), rise=0.8)
        mix_into(out, b * 0.12, n_of(rng.uniform(0.02, 0.1)))
    return fade(out, 0, 0.05)


def getto_fine(rng):
    n = n_of(0.7)
    out = np.zeros(n)
    out[:n_of(0.12)] += clic_torcia(rng, False)[:n_of(0.12)] * 0.6
    k = n_of(0.15)
    mix_into(out, bp(white(k, rng), 1500, 8000, 2) * env_ad(k, 0.001, 0.12) * 0.35, 0)
    sputo = bp(white(n_of(0.05), rng), 600, 3000, 2) * env_ad(n_of(0.05), 0.002, 0.04) * 0.3
    mix_into(out, sputo, n_of(0.08))
    for t0 in [0.32, 0.55]:
        b = bollicina(rng, rng.uniform(1800, 3000), 0.01, rise=1.0)
        mix_into(out, b * 0.15, n_of(t0 + rng.uniform(-0.03, 0.03)))
    return fade(out, 0, 0.05)


def impatto_loop(rng, dur=2.0, xf=0.4):
    """Il getto che si spiaccica su piastrelle e muri: miriadi di goccioline."""
    n = n_of(dur + xf)
    imp = treno_impulsi(n, 1800, rng, alpha=2.5)
    gr = resonator_bank(np.r_[1.0, np.zeros(n_of(0.01))], [1900, 3300, 5200], [0.004, 0.003, 0.002], [1, 0.6, 0.3])
    from scipy import signal as sg
    spl = sg.fftconvolve(imp, gr)[:n]
    body = lp(white(n, rng), 1600, 2) * (0.6 + 0.4 * smooth_noise(n, 25, rng))
    out = hp(spl * 0.25 + body * 0.25, 250)
    return make_loop(out, dur, xf)


def impatto_acqua_loop(rng, dur=2.0, xf=0.4):
    """Il getto che entra in una vasca: ribollio e schiuma."""
    n = n_of(dur + xf)
    out = lp(white(n, rng), 2200, 2) * 0.12 * (0.7 + 0.3 * smooth_noise(n, 15, rng))
    for _ in range(int((dur + xf) * 260)):
        b = bollicina(rng, rng.uniform(300, 2500), rng.uniform(0.004, 0.02), rise=0.3)
        mix_into(out, b * rng.uniform(0.03, 0.12), n_of(rng.uniform(0, dur + xf - 0.1)))
    return make_loop(hp(out, 120), dur, xf)


def aspira_loop(rng, dur=3.0, xf=0.5):
    """Aspirazione: motorino sotto sforzo, aria che fischia nel tubo, acqua che gorgoglia."""
    n = n_of(dur + xf)
    mot = motorino(rng, n, np.full(n, 236.0), carico=1.0) * 0.35
    aria = bp(white(n, rng), 300, 3000, 2)
    aria = comb(aria, 1 / 285.0, 0.55) * 0.12
    gorg = np.zeros(n)
    tt = 0.0
    while tt < dur + xf - 0.1:
        # grappoli di bolle: l'acqua sale nel tubo a sorsate
        for _ in range(rng.integers(3, 8)):
            b = bollicina(rng, rng.uniform(160, 750), rng.uniform(0.01, 0.04), rise=0.25)
            mix_into(gorg, b * rng.uniform(0.15, 0.4), n_of(tt + rng.uniform(0, 0.08)))
        tt += rng.exponential(0.07) + 0.02
    slurp = bp(white(n, rng), 500, 2500, 2) * np.clip(smooth_noise(n, 6, rng), 0, 1) * 0.25
    out = mot + aria + lp(gorg, 2500) * 0.6 + slurp
    return make_loop(hp(out, 80), dur, xf)


def aspira_inizio(rng):
    n = n_of(0.55)
    f = env_points([(0, 50), (0.3, 236), (0.55, 236)], n)
    out = motorino(rng, n, f, 0.5) * env_points([(0, 0), (0.05, 0.6), (0.3, 1), (0.55, 1)], n) * 0.35
    k = n_of(0.25)
    sl = bp(white(k, rng), 400, 2200, 2) * env_points([(0, 0), (0.05, 1), (0.25, 0)], k) * 0.3
    mix_into(out, sl, n_of(0.25))
    return fade(out, 0.005, 0.04)


def aspira_fine(rng):
    n = n_of(0.7)
    f = env_points([(0, 236), (0.5, 40), (0.7, 30)], n)
    out = motorino(rng, n, f, 0.3) * env_points([(0, 1), (0.4, 0.5), (0.7, 0)], n) * 0.35
    for k in range(2):
        b = bollicina(rng, rng.uniform(140, 260), 0.05, rise=0.2)
        mix_into(out, b * 0.4, n_of(0.08 + k * 0.13))
    k = n_of(0.08)
    pop = bp(white(k, rng), 300, 2000, 2) * env_ad(k, 0.002, 0.06) * 0.3
    mix_into(out, pop, n_of(0.35))
    return fade(out, 0, 0.05)


def bip_giocattolo(rng, note, durata=0.085, gap=0.02, detune=0.0):
    """Bip dell'elettronica giocattolo anni '90: onda quadra da altoparlantino gracchiante."""
    out = np.zeros(n_of(len(note) * (durata + gap) + 0.1))
    for k, f in enumerate(note):
        m = n_of(durata)
        tt = t_axis(m)
        ph = np.cumsum(f * (1 + detune * rng.uniform(-1, 1)) * (1 + 0.004 * np.sin(2 * np.pi * 9 * tt))) / SR
        sq = np.sign(np.sin(2 * np.pi * ph)) * 0.6 + np.sin(2 * np.pi * ph) * 0.4
        sq *= env_points([(0, 0), (0.003, 1), (durata - 0.01, 0.8), (durata, 0)], m)
        mix_into(out, sq, n_of(k * (durata + gap)))
    out = bp(out, 500, 5000, 2)
    out = np.tanh(out * 1.8) * 0.5
    return f32(out)


def serbatoio_pieno(rng):
    out = np.zeros(n_of(1.1))
    for k in range(2):
        b = bollicina(rng, rng.uniform(160, 230), 0.06, rise=0.25)
        mix_into(out, b * 0.6, n_of(k * 0.14))
    tok = resonator_bank(np.r_[1.0, np.zeros(n_of(0.1))], [420, 980, 1700], [0.05, 0.04, 0.03], [1, 0.5, 0.3])
    mix_into(out, tok * 0.5, n_of(0.3))
    mix_into(out, bip_giocattolo(rng, [1047, 1319, 1568]) * 0.45, n_of(0.38))
    return fade(out, 0, 0.05)


def serbatoio_vuoto(rng):
    out = np.zeros(n_of(0.9))
    out[:n_of(0.12)] += clic_torcia(rng, False)[:n_of(0.12)] * 0.8
    for k in range(3):
        m = n_of(0.07)
        pf = bp(white(m, rng), 500, 4000, 2) * env_ad(m, 0.002, 0.06) * (0.5 - k * 0.12)
        mix_into(out, pf, n_of(0.05 + k * 0.09 + rng.uniform(-0.01, 0.01)))
    mix_into(out, bip_giocattolo(rng, [784, 523], 0.11) * 0.35, n_of(0.4))
    return fade(out, 0, 0.05)


def pompata(rng, n_colpi=2):
    """Pompata a mano tipo Super Soaker: slitta di plastica e aria compressa."""
    out = np.zeros(n_of(0.45 * n_colpi + 0.2))
    for k in range(n_colpi):
        t0 = k * 0.42
        m = n_of(0.22)
        tt = t_axis(m)
        sl = tv_biquad(white(m, rng), 'bandpass', 900 + 1800 * tt / tt[-1], 3) * \
            env_points([(0, 0), (0.03, 1), (0.18, 0.7), (0.22, 0)], m) * 0.4
        mix_into(out, sl, n_of(t0))
        e = np.zeros(n_of(0.08))
        e[0] = 1
        chk = resonator_bank(e, [950, 2300, 4100], [0.03, 0.02, 0.012], [1, 0.6, 0.3])
        mix_into(out, chk * 0.6, n_of(t0 + 0.2))
        m = n_of(0.18)
        air = bp(white(m, rng), 600, 3000, 2) * env_points([(0, 0), (0.02, 1), (0.18, 0)], m) * 0.25
        mix_into(out, air, n_of(t0 + 0.24))
    return out


def zaino_preso(rng):
    out = np.zeros(n_of(2.0))
    mix_into(out, norm(kenney('cloth1.ogg')) * 0.5, 0)
    mix_into(out, norm(kenney('clothBelt.ogg')) * 0.35, n_of(0.25))
    latch = norm(kenney('metalLatch.ogg'))
    latch = lp(pitch(latch, -4), 4000) * 0.35   # fibbia di plastica
    mix_into(out, latch, n_of(0.55))
    mix_into(out, pompata(rng, 2), n_of(0.8))
    return fade(trim_silence(out), 0, 0.1)


def sciabordio(rng, i):
    n = n_of(0.8)
    tt = t_axis(n)
    out = bp(white(n, rng), 200, 1300, 2) * env_points([(0, 0), (0.06, 1), (0.25, 0.4), (0.4, 0.7), (0.8, 0)], n)
    out *= (0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(5, 8) * tt))
    out *= 0.4
    for _ in range(rng.integers(3, 7)):
        b = bollicina(rng, rng.uniform(300, 900), rng.uniform(0.01, 0.03), rise=0.3)
        mix_into(out, b * rng.uniform(0.08, 0.2), n_of(rng.uniform(0.03, 0.5)))
    thump = lp(white(n_of(0.05), rng), 300) * env_ad(n_of(0.05), 0.003, 0.04) * 0.3
    mix_into(out, thump, 0)
    return fade(out, 0.003, 0.1)


def ricarica_loop(rng, dur=2.5, xf=0.4):
    """Acqua che entra nel serbatoio: gorgoglio continuo (in gioco il tono sale col livello)."""
    n = n_of(dur + xf)
    out = lp(white(n, rng), 1800, 2) * 0.1 * (0.6 + 0.4 * smooth_noise(n, 9, rng))
    for _ in range(int((dur + xf) * 70)):
        b = bollicina(rng, rng.uniform(250, 900), rng.uniform(0.01, 0.035), rise=0.2)
        mix_into(out, b * rng.uniform(0.08, 0.25), n_of(rng.uniform(0, dur + xf - 0.1)))
    out = comb(out, 1 / 520.0, 0.35)
    return make_loop(hp(out, 100), dur, xf)


# --- acqua: tuffo e riemersione --------------------------------------------------------------

def tuffo(rng):
    n = n_of(1.6)
    out = np.zeros(n)
    k = n_of(0.5)
    spl = bp(white(k, rng), 200, 5000, 2) * env_points([(0, 0), (0.01, 1), (0.15, 0.5), (0.5, 0)], k)
    mix_into(out, spl * 0.8, 0)
    k = n_of(1.4)
    rush = lp(white(k, rng), 900, 2) * env_points([(0, 0), (0.08, 1), (1.4, 0)], k) * 0.6
    mix_into(out, rush, n_of(0.06))
    for _ in range(40):
        b = bollicina(rng, rng.uniform(250, 1400), rng.uniform(0.01, 0.04), rise=0.3)
        mix_into(out, b * rng.uniform(0.05, 0.2), n_of(rng.uniform(0.05, 1.1)))
    return fade(out, 0, 0.2)


def riemersione(rng):
    n = n_of(1.4)
    out = np.zeros(n)
    k = n_of(0.35)
    spl = bp(white(k, rng), 300, 6000, 2) * env_points([(0, 0), (0.015, 1), (0.1, 0.4), (0.35, 0)], k)
    mix_into(out, spl * 0.6, 0)
    k = n_of(1.2)
    trickle = bp(white(k, rng), 800, 5000, 2) * env_points([(0, 0), (0.05, 1), (1.2, 0)], k) * 0.15
    mix_into(out, trickle, n_of(0.08))
    for _ in range(25):
        b = bollicina(rng, rng.uniform(1500, 4000), rng.uniform(0.004, 0.012), rise=0.9)
        mix_into(out, b * rng.uniform(0.05, 0.15), n_of(rng.uniform(0.1, 1.2) ** 1.5))
    return fade(out, 0, 0.15)


def main():
    rng = np.random.default_rng(1990)
    print('Giocatore')
    K_PASSI = 'Kenney Impact Sounds (CC0), rielaborati'
    for i in range(6):
        salva(CART, f'passo_piastrelle_{i + 1:02d}', passo_piastrelle(rng, i), loudness=-20, corto=True,
              qualita=3, fonte=K_PASSI, nota='footstep_concrete + risonanza della ceramica')
    for i in range(6):
        salva(CART, f'passo_bagnato_{i + 1:02d}', passo_bagnato(rng, i), loudness=-20, corto=True, qualita=3,
              fonte=K_PASSI + ' + sintesi')
    for i in range(6):
        salva(CART, f'passo_acqua_{i + 1:02d}', passo_acqua(rng, i), loudness=-19, corto=True, qualita=3)
    for i in range(6):
        salva(CART, f'passo_metallo_{i + 1:02d}', passo_metallo(rng, i), loudness=-19, corto=True, qualita=3,
              fonte=K_PASSI, nota='footstep_concrete + impactPlate_light')
    for i in range(4):
        salva(CART, f'passo_scala_{i + 1:02d}', passo_scala(rng, i), loudness=-20, corto=True, qualita=3,
              fonte=K_PASSI, nota='impactMetal_light')
    for sup in ['piastrelle', 'bagnato', 'acqua', 'metallo']:
        for i in range(2):
            salva(CART, f'atterraggio_{sup}_{i + 1:02d}', atterraggio(rng, sup, i), loudness=-16, corto=True,
                  qualita=3, fonte=K_PASSI + ' + sintesi')
    for i in range(2):
        salva(CART, f'salto_{i + 1:02d}', salto(rng, i), loudness=-24, corto=True, qualita=3,
              fonte='Kenney RPG Audio (CC0)', nota='cloth')
    salva(CART, 'torcia_accesa', clic_torcia(rng, True), loudness=-20, corto=True, qualita=3)
    salva(CART, 'torcia_spenta', clic_torcia(rng, False), loudness=-21, corto=True, qualita=3)
    salva(CART, 'zaino_getto_loop', getto_loop(rng), loudness=-21, qualita=4)
    salva(CART, 'zaino_getto_inizio', getto_inizio(rng), loudness=-18, corto=True, qualita=3)
    salva(CART, 'zaino_getto_fine', getto_fine(rng), loudness=-21, corto=True, qualita=3)
    salva(CART, 'zaino_impatto_loop', impatto_loop(rng), loudness=-22, qualita=3)
    salva(CART, 'zaino_impatto_acqua_loop', impatto_acqua_loop(rng), loudness=-22, qualita=3)
    salva(CART, 'zaino_aspira_loop', aspira_loop(rng), loudness=-21, qualita=4)
    salva(CART, 'zaino_aspira_inizio', aspira_inizio(rng), loudness=-20, corto=True, qualita=3)
    salva(CART, 'zaino_aspira_fine', aspira_fine(rng), loudness=-21, corto=True, qualita=3)
    salva(CART, 'zaino_pieno', serbatoio_pieno(rng), loudness=-19, corto=True, qualita=3)
    salva(CART, 'zaino_vuoto', serbatoio_vuoto(rng), loudness=-19, corto=True, qualita=3)
    salva(CART, 'zaino_preso', zaino_preso(rng), loudness=-17, corto=True, qualita=3,
          fonte='Kenney RPG Audio (CC0) + sintesi', nota='cloth, clothBelt, metalLatch e pompate sintetiche')
    salva(CART, 'zaino_pompata', pompata(rng, 1), loudness=-20, corto=True, qualita=3)
    for i in range(3):
        salva(CART, f'zaino_sciabordio_{i + 1:02d}', sciabordio(rng, i), loudness=-22, corto=True, qualita=3)
    salva(CART, 'zaino_ricarica_loop', ricarica_loop(rng), loudness=-23, qualita=3)
    salva(CART, 'tuffo', tuffo(rng), loudness=-15, corto=True, qualita=3)
    salva(CART, 'riemersione', riemersione(rng), loudness=-17, corto=True, qualita=3)


if __name__ == '__main__':
    main()
