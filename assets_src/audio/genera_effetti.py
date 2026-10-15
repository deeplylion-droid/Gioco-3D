"""Effetti del mondo: neon (ronzio, clic, scintille), luci d'emergenza, faro della statua,
pulsanti, turbina, gonfiabile, porte e saracinesca, portello, ruota a pale, secchio,
cancello, quadro elettrico in corto, scarichi e vasche, acqua negli scivoli, la medusa.
Uscita: godot/audio/effetti/.
"""
import numpy as np
from scipy import signal as sg

from comune import ir_nave, kenney, salva
from genera_ambiente import MODI_LAMIERA, bollicina, gemito_attrito, treno_impulsi
from genera_giocatore import bip_giocattolo, motorino, norm
from lib_audio import (SR, biquad, bp, brown, comb, env_ad, env_points, eq, f32, fade, hp, lp, make_loop,
                       mix_into, mono, n_of, pink, pitch, resample_ratio, resonator_bank, reverb,
                       smooth_noise, t_axis, trim_silence, tv_biquad, white)

CART = 'effetti'


def impulso(n_s=0.2):
    e = np.zeros(n_of(n_s))
    e[0] = 1.0
    return e


# --- luci ----------------------------------------------------------------------------------

def ronzio_rete(rng, n, f0=100.0, armoniche=24, pend=0.8, sfrigolio=0.3):
    """Ronzio da reattore: armoniche di f0 con fasi casuali + sfrigolio d'arco a ritmo di rete."""
    t = t_axis(n)
    out = np.zeros(n)
    for k in range(1, armoniche + 1):
        if f0 * k > 9000:
            break
        out += np.sin(2 * np.pi * f0 * k * t + rng.uniform(0, 6.28)) / k ** pend
    out /= np.abs(out).max()
    arc = hp(white(n, rng), 3000) * (np.abs(np.sin(2 * np.pi * (f0 / 2) * t)) ** 6)
    out = out + arc * sfrigolio
    return f32(out)


def neon_ronzio_loop(rng, dur=3.0, xf=0.5):
    n = n_of(dur + xf)
    out = ronzio_rete(rng, n, 100.0, 30, 0.75, 0.35)
    out *= (0.9 + 0.1 * smooth_noise(n, 5, rng))
    # qualche crepitio leggero
    cr = treno_impulsi(n, 6, rng) * 0.4
    out += resonator_bank(cr, [2600, 4100], [0.004, 0.003], [1, 0.6])
    out = eq(out, [('peak', 1200, 1.0, 3), ('highshelf', 6000, 0.7, -4)])
    return make_loop(out, dur, xf)


def neon_clic(rng, i):
    out = np.zeros(n_of(0.45))
    tink = resonator_bank(impulso(0.1), rng.uniform(0.9, 1.1) * np.array([2400, 3900, 6100]),
                          [0.03, 0.02, 0.012], [1, 0.6, 0.35])
    mix_into(out, tink * 0.5, 0)
    k = n_of(rng.uniform(0.04, 0.09))
    bz = ronzio_rete(rng, k, 100.0, 20, 0.7, 0.6) * env_points([(0, 0), (0.003, 1), (k / SR, 0)], k)
    mix_into(out, bz * 0.6, n_of(0.01))
    thunk = resonator_bank(impulso(0.15), [210, 370], [0.05, 0.04], [1, 0.5])
    mix_into(out, thunk * 0.4, n_of(rng.uniform(0.005, 0.02)))
    return fade(trim_silence(out), 0, 0.03)


def scintille(rng, dur, densita=500, zap=True):
    n = n_of(dur)
    t = t_axis(n)
    bursty = np.clip(smooth_noise(n, 18, rng) + 0.3, 0, 1) ** 2 * env_points([(0, 1), (dur * 0.6, 0.7), (dur, 0)], n)
    imp = treno_impulsi(n, densita, rng, alpha=2.0) * bursty
    cr = resonator_bank(imp, [1800, 3100, 5200, 7900], [0.003, 0.003, 0.002, 0.0015], [1, 0.8, 0.6, 0.4])
    cr += hp(imp, 1500) * 0.4
    out = cr
    if zap:
        k = n_of(0.25)
        z = ronzio_rete(rng, k, 100.0, 40, 0.5, 1.0) * env_ad(k, 0.001, 0.22)
        z = np.tanh(z * 3)
        mix_into(out, z * 0.8, 0)
        snap = hp(white(n_of(0.01), rng), 800) * env_ad(n_of(0.01), 0.0002, 0.008)
        mix_into(out, snap * 1.2, 0)
    return f32(out)


def neon_scintilla(rng, i):
    return fade(scintille(rng, rng.uniform(0.35, 0.7), rng.uniform(300, 700)), 0, 0.05)


def emergenza_ronzio_loop(rng, dur=4.0, xf=0.5):
    n = n_of(dur + xf)
    out = ronzio_rete(rng, n, 50.0, 14, 1.1, 0.08)
    out = lp(out, 1500, 2)
    out *= 0.85 + 0.15 * smooth_noise(n, 0.7, rng)
    return make_loop(out, dur, xf)


def emergenza_rotante_loop(rng, dur=1.8182, xf=0.3):
    """Lampeggiante rotante: motorino e ingranaggi, con un 'tic' a ogni giro (0,55 giri/s)."""
    n = n_of(dur * 2 + xf)
    t = t_axis(n)
    mot = motorino(rng, n, np.full(n, 118.0)) * 0.3
    giro = 0.55
    tic = np.zeros(n)
    for k in range(int((dur * 2 + xf) * giro) + 1):
        mix_into(tic, resonator_bank(impulso(0.05), [1400, 2900], [0.02, 0.01], [1, 0.5]),
                 n_of(k / giro + 0.1))
    ingr = bp(white(n, rng), 800, 3000, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 37 * t)) * 0.05
    out = mot + tic * 0.3 + ingr
    return make_loop(out, dur * 2, xf)


def faro_acceso(rng):
    """Il faro sulla statua che si accende: relè pesante, colpo del reattore, ronzio che sale."""
    n = n_of(3.0)
    out = np.zeros(n)
    clack = resonator_bank(impulso(0.4), [130, 245, 410, 900, 2100], [0.12, 0.1, 0.08, 0.05, 0.03],
                           [1, 0.8, 0.5, 0.3, 0.2])
    mix_into(out, clack * 0.9, 0)
    click = bp(white(n_of(0.01), rng), 1500, 9000, 2) * env_ad(n_of(0.01), 0.0002, 0.008)
    mix_into(out, click * 0.8, 0)
    k = n_of(2.9)
    f = env_points([(0, 92), (0.8, 100), (2.9, 100)], k)
    t = t_axis(k)
    ph = np.cumsum(f) / SR
    hum = np.zeros(k)
    for h in range(1, 18):
        hum += np.sin(2 * np.pi * h * ph + rng.uniform(0, 6)) / h ** 0.9
    hum = hum / np.abs(hum).max() * env_points([(0, 0), (0.05, 0.9), (0.4, 0.5), (1.2, 0.35), (2.9, 0)], k)
    mix_into(out, hum * 0.35, n_of(0.04))
    return fade(out, 0, 0.3)


def faro_ronzio_loop(rng, dur=3.0, xf=0.5):
    n = n_of(dur + xf)
    out = ronzio_rete(rng, n, 100.0, 18, 0.9, 0.12)
    out = lp(out, 4000, 2) * (0.92 + 0.08 * smooth_noise(n, 3, rng))
    return make_loop(out, dur, xf)


# --- pulsanti ------------------------------------------------------------------------------

def pulsante_premuto(rng):
    """Pulsantone da giocattolo: 'ciunk' di plastica, microinterruttore e il campanello."""
    out = np.zeros(n_of(1.0))
    chunk = resonator_bank(impulso(0.2), [190, 430, 960, 1900], [0.08, 0.06, 0.04, 0.02], [1, 0.7, 0.4, 0.2])
    mix_into(out, chunk * 0.8, 0)
    micro = resonator_bank(impulso(0.05), [3200, 5400], [0.008, 0.005], [1, 0.6])
    mix_into(out, micro * 0.5, n_of(0.012))
    din = bip_giocattolo(rng, [784, 1047], 0.12, 0.03, detune=0.004)
    mix_into(out, din * 0.4, n_of(0.08))
    return fade(out, 0, 0.1)


def pulsante_rilasciato(rng):
    out = np.zeros(n_of(0.2))
    mix_into(out, resonator_bank(impulso(0.15), [260, 610, 2900], [0.04, 0.03, 0.006], [0.7, 0.5, 0.4]), 0)
    return fade(out, 0, 0.05)


# --- turbina e gonfiabile ------------------------------------------------------------------

def turbina_loop(rng, dur=2.0, xf=0.0):
    """Turbina alla velocità nominale: pale che fendono il getto (13,5 Hz), cuscinetti, spruzzi.
    Tutto periodico su 2 s: il loop è esatto. In gioco il tono segue la velocità."""
    n = n_of(dur)
    t = t_axis(n)
    pale = 13.5
    nz = white(n, rng)
    whoosh = bp(nz, 400, 3000, 2) * (0.5 + 0.5 * np.cos(2 * np.pi * pale * t)) ** 3
    whine = np.zeros(n)
    for k, a in [(30, 1.0), (60, 0.4), (90, 0.25), (45, 0.3)]:
        whine += a * np.sin(2 * np.pi * pale * k * t)
    whine *= 0.05
    spruzzi = hp(white(n, rng), 2000) * (0.6 + 0.4 * np.cos(2 * np.pi * pale * t + 1.0)) * 0.12
    rattle = resonator_bank(treno_impulsi(n, 60, rng), [720, 1500], [0.01, 0.008], [1, 0.6]) * 0.15
    out = whoosh * 0.35 + whine + spruzzi + rattle
    # loop esatto: i rumori si chiudono con una dissolvenza incrociata breve sul ciclo
    out2 = np.concatenate([out, out[:n_of(0.2)]])
    return make_loop(out2, dur, 0.2)


def turbina_bloccata(rng):
    out = np.zeros(n_of(0.6))
    thump = lp(white(n_of(0.08), rng), 400) * env_ad(n_of(0.08), 0.003, 0.07)
    mix_into(out, thump * 0.8, 0)
    clat = resonator_bank(impulso(0.3), [520, 1130, 1960, 3100], [0.08, 0.06, 0.04, 0.03], [1, 0.7, 0.5, 0.3])
    mix_into(out, clat * 0.4, n_of(0.01))
    mix_into(out, clat * 0.2, n_of(0.09))
    return fade(out, 0, 0.05)


def cigolio_gomma(rng, dur, f_da, f_a):
    """Gomma che striscia: attrito a scatti con il passo che va da f_da a f_a Hz."""
    n = n_of(dur)
    f = env_points([(0, f_da), (dur, f_a)], n) * (1 + 0.03 * smooth_noise(n, 25, rng))
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1) - 1
    x = bp(saw, 400, 4000, 2)
    x = eq(x, [('peak', 1100, 3, 8), ('peak', 2600, 4, 5)])
    x *= env_points([(0, 0), (0.02, 1), (dur * 0.7, 0.8), (dur, 0)], n)
    return f32(x)


def gonfiabile_colpito(rng):
    out = np.zeros(n_of(0.35))
    mix_into(out, cigolio_gomma(rng, 0.18, rng.uniform(600, 800), rng.uniform(900, 1200)) * 0.5, 0)
    thud = lp(white(n_of(0.06), rng), 350) * env_ad(n_of(0.06), 0.002, 0.05)
    mix_into(out, thud * 0.6, 0)
    return fade(out, 0, 0.05)


def gonfiabile_libero(rng):
    out = np.zeros(n_of(2.2))
    mix_into(out, cigolio_gomma(rng, 0.45, 500, 1300) * 0.6, 0)
    pop = bp(white(n_of(0.03), rng), 300, 3000, 2) * env_ad(n_of(0.03), 0.001, 0.025)
    mix_into(out, pop * 0.9, n_of(0.45))
    # cade nella pozza
    k = n_of(0.6)
    spl = bp(white(k, rng), 250, 3500, 2) * env_points([(0, 0), (0.01, 1), (0.12, 0.4), (0.6, 0)], k)
    mix_into(out, spl * 0.7, n_of(0.95))
    for _ in range(18):
        b = bollicina(rng, rng.uniform(300, 1500), rng.uniform(0.01, 0.03), rise=0.4)
        mix_into(out, b * rng.uniform(0.05, 0.15), n_of(0.95 + rng.uniform(0, 0.5)))
    return fade(out, 0, 0.2)


# --- porte e meccanismi --------------------------------------------------------------------

def porta_motore_loop(rng, dur=2.0, xf=0.4):
    n = n_of(dur + xf)
    t = t_axis(n)
    mot = motorino(rng, n, np.full(n, 120.0), 0.4) * 0.25
    denti = np.zeros(n)
    for k in range(int((dur + xf) * 42)):
        mix_into(denti, resonator_bank(impulso(0.03), [1300, 2700], [0.01, 0.006], [1, 0.5]) * rng.uniform(0.5, 1),
                 n_of(k / 42.0))
    rum = lp(brown(n, rng), 200, 2) * 0.4
    out = mot + denti * 0.12 + rum + bp(white(n, rng), 2000, 6000, 2) * 0.02
    return make_loop(hp(out, 30, 2), dur, xf)


def colpo_metallico(rng, peso=1.0, i=0):
    a = norm(kenney('impactMetal_heavy_00%d.ogg' % (i % 5)))
    b = norm(kenney('doorClose_%d.ogg' % (1 + i % 4)))
    out = np.zeros(n_of(1.4))
    mix_into(out, pitch(a, -2 - 3 * peso), 0)
    mix_into(out, pitch(b, -3 - 3 * peso) * 0.6, n_of(0.005))
    out += 0.3 * resonator_bank(out, np.array([97, 163, 251, 389]) * (1.2 - 0.3 * peso), [0.5, 0.4, 0.3, 0.2],
                                [1, 0.7, 0.5, 0.3])
    return fade(trim_silence(lp(out, 7000)), 0, 0.1)


def saracinesca_loop(rng, dur=2.0, xf=0.4):
    """Serranda che si avvolge: doghe di lamiera che sbattono (circa 24 al secondo) e rombo."""
    n = n_of(dur + xf)
    out = np.zeros(n)
    tt = 0.0
    while tt < dur + xf - 0.05:
        fr = np.array(MODI_LAMIERA[4:9]) * rng.uniform(0.85, 1.2)
        d = resonator_bank(impulso(0.08), fr, [0.05, 0.04, 0.03, 0.025, 0.02], [1, 0.8, 0.6, 0.4, 0.3])
        mix_into(out, d * rng.uniform(0.3, 1.0), n_of(tt))
        tt += 1 / 24.0 + rng.uniform(-0.008, 0.008)
    out = out * 0.25 + lp(brown(n, rng), 160, 2) * 0.35
    return make_loop(hp(out, 30, 2), dur, xf)


def saracinesca_fine(rng):
    out = colpo_metallico(rng, 0.6, 2)
    tail = np.zeros(n_of(0.6))
    for k in range(6):
        fr = np.array(MODI_LAMIERA[4:8]) * rng.uniform(0.9, 1.1)
        mix_into(tail, resonator_bank(impulso(0.08), fr, [0.04] * 4, [1, 0.7, 0.5, 0.3]) * (0.5 - k * 0.07),
                 n_of(k * 0.06 + rng.uniform(0, 0.02)))
    res = np.zeros(max(len(out), len(tail) + n_of(0.05)))
    mix_into(res, out, 0)
    mix_into(res, tail * 0.5, n_of(0.05))
    return fade(res, 0, 0.1)


def cigolio_metallo(rng, dur, i=0, lento=3.0):
    c = kenney('creak%d.ogg' % (1 + i % 3))
    c = resample_ratio(c, lento)
    if len(c) < n_of(dur):
        c = np.concatenate([c, resample_ratio(kenney('creak%d.ogg' % (1 + (i + 1) % 3)), lento)])
    c = c[:n_of(dur)]
    c = c + 0.5 * resonator_bank(c, np.array(MODI_LAMIERA[2:8]) * rng.uniform(0.85, 1.15), [0.4] * 6,
                                 [1, 0.8, 0.6, 0.5, 0.4, 0.3])
    return fade(lp(c, 5000), 0.02, 0.2)


def portello_apre(rng):
    """Portello d'acciaio sulla cerniera: cigolio per 1,5 s e colpo quando sbatte (in 1,6 s)."""
    out = np.zeros(n_of(3.2))
    mix_into(out, norm(cigolio_metallo(rng, 1.5, 0, 2.2)) * 0.6, 0)
    mix_into(out, norm(gemito_attrito(rng, 1.4)) * 0.3, n_of(0.05))
    mix_into(out, colpo_metallico(rng, 1.0, 1) * 0.9, n_of(1.55))
    return fade(out, 0.01, 0.3)


def cancello_ruota(rng):
    """La grande ruota che apre il cancello: cricchetto che rallenta e cigolio lungo."""
    dur = 4.5
    out = np.zeros(n_of(dur + 0.5))
    mix_into(out, norm(cigolio_metallo(rng, dur, 2, 3.2)) * 0.5, 0)
    tt, rate = 0.0, 14.0
    while tt < dur and rate > 1.5:
        r = resonator_bank(impulso(0.05), [1700, 3300], [0.015, 0.01], [1, 0.5])
        mix_into(out, r * 0.25 * min(1.0, rate / 8), n_of(tt))
        tt += 1.0 / rate
        rate *= 0.965
    return fade(out, 0.02, 0.4)


def cancello_fine(rng):
    return colpo_metallico(rng, 0.8, 3)


def ruota_pale_loop(rng, dur=2.4, xf=0.0):
    """Ruota a pale nell'acqua (alla velocità massima): schiaffi d'acqua a ritmo e un perno che cigola."""
    n = n_of(dur)
    out = np.zeros(n)
    per = 0.2
    for k in range(int(dur / per)):
        m = n_of(0.18)
        s = bp(white(m, rng), 300, 3500, 2) * env_points([(0, 0), (0.01, 1), (0.18, 0)], m) ** 1.5
        mix_into(out, s * rng.uniform(0.5, 0.8), n_of(k * per))
        for _ in range(3):
            b = bollicina(rng, rng.uniform(500, 1600), rng.uniform(0.006, 0.02), rise=0.4)
            mix_into(out, b * 0.08, n_of(k * per + rng.uniform(0.01, 0.12)))
    sq = cigolio_gomma(rng, 0.35, 380, 520) * 0.15
    mix_into(out, sq, n_of(0.6))
    mix_into(out, cigolio_gomma(rng, 0.3, 420, 560) * 0.12, n_of(1.8))
    out2 = np.concatenate([out, out[:n_of(0.2)]])
    return make_loop(out2, dur, 0.2)


def secchio_ribalta(rng):
    """Il secchio gigante si ribalta: cigolio del perno e la cascata che si rovescia."""
    dur = 4.5
    n = n_of(dur)
    out = np.zeros(n)
    mix_into(out, norm(cigolio_metallo(rng, 0.9, 1, 2.0)) * 0.5, 0)
    k = n_of(3.6)
    e = env_points([(0, 0), (0.15, 1), (1.6, 0.8), (2.6, 0.4), (3.6, 0)], k)
    cascata = (bp(white(k, rng), 150, 6000, 2) * 0.6 + lp(brown(k, rng), 300, 2) * 0.8) * e
    mix_into(out, cascata, n_of(0.55))
    k = n_of(0.8)
    whomp = lp(white(k, rng), 140, 3) * env_ad(k, 0.01, 0.7) * 2.0
    mix_into(out, whomp, n_of(0.85))
    for _ in range(60):
        b = bollicina(rng, rng.uniform(250, 1800), rng.uniform(0.008, 0.035), rise=0.4)
        mix_into(out, b * rng.uniform(0.05, 0.2), n_of(rng.uniform(0.8, 3.8)))
    return fade(hp(out, 25, 2), 0.01, 0.6)


def secchio_ritorno(rng):
    out = np.zeros(n_of(3.0))
    mix_into(out, norm(cigolio_metallo(rng, 2.3, 2, 2.6)) * 0.5, 0)
    for t0 in [0.4, 0.9, 1.6, 2.2]:
        b = bollicina(rng, rng.uniform(900, 2200), 0.02, rise=0.8)
        mix_into(out, b * 0.25, n_of(t0))
    return fade(out, 0.02, 0.3)


def quadro_scintille(rng):
    """Quadro elettrico bagnato dall'ondata: botto, scariche, ronzio che muore, salvavita."""
    out = np.zeros(n_of(2.2))
    sc = scintille(rng, 1.4, 900, zap=True)
    mix_into(out, sc, 0)
    k = n_of(1.3)
    bz = ronzio_rete(rng, k, 100.0, 30, 0.6, 0.8) * env_points([(0, 1), (1.0, 0.5), (1.3, 0)], k)
    bz *= (0.6 + 0.4 * smooth_noise(k, 12, rng))
    mix_into(out, np.tanh(bz * 2) * 0.35, n_of(0.05))
    clack = resonator_bank(impulso(0.2), [380, 900, 2300], [0.06, 0.04, 0.02], [1, 0.6, 0.3])
    mix_into(out, clack * 0.6, n_of(1.35))
    return fade(out, 0, 0.2)


# --- acqua: scarichi, vasche, scivoli ---------------------------------------------------------

def scarico_loop(rng, dur=4.0, xf=0.6):
    """Scarico aperto: gorgoglio profondo, acqua che gira e sorsi d'aria."""
    n = n_of(dur + xf)
    out = bp(pink(n, rng), 150, 1400, 2) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.5 * t_axis(n))) * 0.25
    for _ in range(int((dur + xf) * 25)):
        b = bollicina(rng, rng.uniform(90, 420), rng.uniform(0.02, 0.07), rise=0.15)
        mix_into(out, b * rng.uniform(0.15, 0.45), n_of(rng.uniform(0, dur + xf - 0.2)))
    for _ in range(int(dur)):
        m = n_of(0.25)
        g = bp(white(m, rng), 200, 900, 2) * env_points([(0, 0), (0.04, 1), (0.25, 0)], m)
        mix_into(out, g * 0.4, n_of(rng.uniform(0, dur + xf - 0.3)))
    return make_loop(lp(out, 2500), dur, xf)


def vasca_svuotata(rng):
    out = np.zeros(n_of(2.8))
    tt = 0.0
    for k in range(7):
        b = bollicina(rng, 260 - k * 22, 0.06, rise=0.1)
        mix_into(out, b * (0.7 - k * 0.05), n_of(tt))
        tt += rng.uniform(0.12, 0.2)
    k = n_of(1.0)
    sl = tv_biquad(white(k, rng), 'bandpass', env_points([(0, 400), (1.0, 1400)], k), 4)
    sl *= env_points([(0, 0), (0.3, 1), (0.95, 1), (1.0, 0)], k) * 0.4
    mix_into(out, sl, n_of(tt))
    return fade(out, 0, 0.1)


def riempie_loop(rng, dur=3.0, xf=0.5):
    """Bocchetta che versa acqua in una vasca: getto, schiuma e bolle."""
    n = n_of(dur + xf)
    out = bp(white(n, rng), 250, 5000, 2) * (0.7 + 0.3 * smooth_noise(n, 20, rng)) * 0.25
    for _ in range(int((dur + xf) * 120)):
        b = bollicina(rng, rng.uniform(300, 2000), rng.uniform(0.006, 0.025), rise=0.3)
        mix_into(out, b * rng.uniform(0.04, 0.12), n_of(rng.uniform(0, dur + xf - 0.1)))
    return make_loop(out, dur, xf)


def scivolo_loop(rng, dur=3.0, xf=0.5):
    """Acqua che scorre in un tubo dello scivolo: scroscio e risonanza del tubo."""
    n = n_of(dur + xf)
    out = bp(pink(n, rng), 150, 4000, 2) * (0.75 + 0.25 * smooth_noise(n, 3, rng))
    out = out * 0.5 + comb(out, 1 / 155.0, 0.5) * 0.15
    for _ in range(int((dur + xf) * 40)):
        b = bollicina(rng, rng.uniform(400, 1500), rng.uniform(0.008, 0.02), rise=0.3)
        mix_into(out, b * 0.05, n_of(rng.uniform(0, dur + xf - 0.1)))
    return make_loop(out, dur, xf)


# --- la medusa ------------------------------------------------------------------------------

def medusa_presenza_loop(rng, dur=8.0, xf=1.0):
    """Appena udibile vicino alla statua: un respiro umido e lento, la campana che pulsa piano."""
    n = n_of(dur + xf)
    t = t_axis(n)
    resp = (0.5 - 0.5 * np.cos(2 * np.pi * t / 4.0)) ** 2
    nz = white(n, rng)
    form = (biquad(nz, 'bandpass', 380, 4) * 1.0 + biquad(nz, 'bandpass', 950, 6) * 0.6 +
            biquad(nz, 'bandpass', 2300, 8) * 0.25)
    out = lp(form, 3000) * resp * 0.5
    # tonfo sordo della campana, due volte per respiro
    for k in range(int((dur + xf) / 2.0) + 1):
        m = n_of(0.5)
        th = np.sin(2 * np.pi * 42 * t_axis(m)) * env_ad(m, 0.03, 0.45)
        mix_into(out, th * 0.4, n_of(k * 2.0 + 0.3))
    # piccoli schiocchi gelatinosi
    for _ in range(int((dur + xf) * 3)):
        sl = kenney('slime_000.ogg')
        sl = pitch(sl, rng.uniform(-14, -8))[:n_of(0.3)]
        mix_into(out, lp(sl, 2500) * rng.uniform(0.03, 0.08), n_of(rng.uniform(0, dur + xf - 0.4)))
    return make_loop(out, dur, xf)


def medusa_risveglio(rng):
    """Si stacca dal piedistallo: strappi umidi, un gemito profondo che sale, la campana che si gonfia."""
    dur = 4.5
    n = n_of(dur)
    t = t_axis(n)
    out = np.zeros(n)
    sl = kenney('slime_001.ogg')
    sl = pitch(sl, -7)[:n]
    mix_into(out, lp(sl, 3000) * 0.4, 0)
    f = env_points([(0, 55), (2.0, 48), (4.5, 70)], n)
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1) - 1
    groan = (biquad(saw, 'bandpass', 300, 3) + biquad(saw, 'bandpass', 700, 5) * 0.5)
    groan *= env_points([(0, 0), (0.6, 0.6), (3.0, 1), (4.5, 0)], n)
    mix_into(out, groan * 0.5, 0)
    k = n_of(2.5)
    swell = lp(brown(k, rng), 120, 2) * env_points([(0, 0), (2.2, 1), (2.5, 0)], k)
    mix_into(out, swell * 0.8, n_of(1.8))
    st = reverb(out, ir_nave(), wet=0.4, dry=0.8, tail=False)
    return fade(hp(mono(st), 25, 2), 0.02, 0.5)


def main():
    rng = np.random.default_rng(1997)
    print('Effetti')
    salva(CART, 'neon_ronzio_loop', neon_ronzio_loop(rng), loudness=-24, qualita=3)
    for i in range(3):
        salva(CART, f'neon_clic_{i + 1:02d}', neon_clic(rng, i), loudness=-18, corto=True, qualita=3)
    for i in range(3):
        salva(CART, f'neon_scintilla_{i + 1:02d}', neon_scintilla(rng, i), loudness=-16, corto=True, qualita=3)
    salva(CART, 'emergenza_ronzio_loop', emergenza_ronzio_loop(rng), loudness=-26, qualita=3)
    salva(CART, 'emergenza_rotante_loop', emergenza_rotante_loop(rng), loudness=-24, qualita=3)
    salva(CART, 'faro_acceso', faro_acceso(rng), loudness=-14, corto=True, qualita=3)
    salva(CART, 'faro_ronzio_loop', faro_ronzio_loop(rng), loudness=-27, qualita=3)
    salva(CART, 'pulsante_premuto', pulsante_premuto(rng), loudness=-15, corto=True, qualita=3)
    salva(CART, 'pulsante_rilasciato', pulsante_rilasciato(rng), loudness=-20, corto=True, qualita=3)
    salva(CART, 'turbina_loop', turbina_loop(rng), loudness=-20, qualita=3)
    salva(CART, 'turbina_bloccata', turbina_bloccata(rng), loudness=-17, corto=True, qualita=3)
    salva(CART, 'gonfiabile_colpito', gonfiabile_colpito(rng), loudness=-19, corto=True, qualita=3)
    salva(CART, 'gonfiabile_libero', gonfiabile_libero(rng), loudness=-15, corto=True, qualita=3)
    salva(CART, 'porta_motore_loop', porta_motore_loop(rng), loudness=-21, qualita=3)
    for i, nome in enumerate(['porta_aperta', 'porta_chiusa']):
        salva(CART, nome, colpo_metallico(rng, 0.5 + 0.4 * i, i), loudness=-14, corto=True, qualita=3,
              fonte='Kenney Impact Sounds + RPG Audio (CC0), rielaborati')
    salva(CART, 'saracinesca_loop', saracinesca_loop(rng), loudness=-20, qualita=3)
    salva(CART, 'saracinesca_fine', saracinesca_fine(rng), loudness=-14, corto=True, qualita=3,
          fonte='Kenney Impact Sounds + RPG Audio (CC0), rielaborati')
    salva(CART, 'portello_apre', portello_apre(rng), loudness=-15, corto=True, qualita=3,
          fonte='Kenney RPG Audio + Impact Sounds (CC0), rielaborati')
    salva(CART, 'cancello_ruota', cancello_ruota(rng), loudness=-18, corto=True, qualita=3,
          fonte='Kenney RPG Audio (CC0), rielaborato')
    salva(CART, 'cancello_fine', cancello_fine(rng), loudness=-14, corto=True, qualita=3,
          fonte='Kenney Impact Sounds + RPG Audio (CC0), rielaborati')
    salva(CART, 'ruota_pale_loop', ruota_pale_loop(rng), loudness=-20, qualita=3)
    salva(CART, 'secchio_ribalta', secchio_ribalta(rng), loudness=-14, corto=True, qualita=3,
          fonte='sintesi + Kenney RPG Audio (CC0)')
    salva(CART, 'secchio_ritorno', secchio_ritorno(rng), loudness=-19, corto=True, qualita=3,
          fonte='Kenney RPG Audio (CC0), rielaborato')
    salva(CART, 'quadro_scintille', quadro_scintille(rng), loudness=-13, corto=True, qualita=3)
    salva(CART, 'scarico_loop', scarico_loop(rng), loudness=-21, qualita=3)
    salva(CART, 'vasca_svuotata', vasca_svuotata(rng), loudness=-17, corto=True, qualita=3)
    salva(CART, 'riempie_loop', riempie_loop(rng), loudness=-21, qualita=3)
    salva(CART, 'scivolo_loop', scivolo_loop(rng), loudness=-20, qualita=3)
    salva(CART, 'medusa_presenza_loop', medusa_presenza_loop(rng), loudness=-30, qualita=3,
          fonte='sintesi + Kenney Sci-Fi Sounds (CC0)', nota='slime rallentato')
    salva(CART, 'medusa_risveglio', medusa_risveglio(rng), loudness=-16, qualita=4,
          fonte='sintesi + Kenney Sci-Fi Sounds (CC0)', nota='slime rallentato')


if __name__ == '__main__':
    main()
