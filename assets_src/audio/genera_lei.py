"""Suoni della tappa 8: lei sbuca dalla fossa allagata nell'area bimbi, al buio. Niente versi:
lei non parla. Solo acqua, pelle bagnata, vinile che si tende e la fauce.

- fossa_ribolle_loop: l'acqua che risale dalla fossa e riempie le vasche basse: gorgoglio
  profondo dal condotto (sacche d'aria, glu-glu-glu), bolle grosse che scoppiano in superficie,
  l'acqua che si allarga e lambisce i bordi.
- lei_sbuca: una massa grande che emerge lenta: l'acqua che si gonfia e si apre, che le cola di
  dosso a cascata e ricade a lastre, le dita e i palmi che si appoggiano bagnati sulle piastrelle,
  il vinile che si tende sotto il peso, poi l'acqua che lambisce i bordi e le gocce (6,5 s).
- lei_scivola_sotto: le mani che scivolano dal bordo bagnato, il corpo che torna giù, il
  risucchio dell'acqua che si richiude sopra la testa, poche bolle e poi silenzio.
- morso: lo scatto fuori dall'acqua, la pelle che si tende e si strappa sotto l'occhio, la
  fauce che si apre e, al secondo MORSO_COLPO (il lampo rosso di DeathSequence), si chiude.
  Stereo, da vicino: suona sul bus Interfaccia, che durante la morte non si abbassa.
Uscita: godot/audio/lei/.
"""
import numpy as np

from comune import ir_piccola, kenney, salva
from genera_ambiente import bollicina, goccia_acqua, goccia_pavimento, treno_impulsi
from genera_effetti import cigolio_gomma, impulso
from genera_giocatore import norm
from lib_audio import (SR, bp, colored, env_ad, env_points, f32, fade, hp, lp, make_loop, mix_into,
                       n_of, pan, pitch, resonator_bank, reverb, smooth_noise, stereo, t_axis,
                       tv_biquad, white)

CART = 'lei'
# Secondi dall'inizio del morso a quando la fauce si chiude: è il lampo rosso della sequenza di
# morte (scripts/ui/death_sequence.gd, elapsed 1,0). Lo usa anche addons/audio/audio.gd.
MORSO_COLPO = 1.0


# --- acqua -----------------------------------------------------------------------------------

def bolla_grossa(rng, f0, scoppio=True):
    """Bolla grossa che sale e scoppia in superficie: 'blop' grave, poi lo schiocco e uno spruzzo."""
    tau = rng.uniform(0.035, 0.07) * (120.0 / f0) ** 0.5
    b = bollicina(rng, f0, tau, rise=rng.uniform(0.05, 0.25), dur=tau * 7)
    out = np.zeros(len(b) + n_of(0.3))
    mix_into(out, b, 0)
    if scoppio:
        k = n_of(0.04)
        plop = bp(white(k, rng), 350, 2800, 2) * env_ad(k, 0.001, 0.035)
        t0 = n_of(tau * rng.uniform(1.5, 3.0))
        mix_into(out, plop * 0.35, t0)
        for _ in range(rng.integers(0, 3)):
            d = bollicina(rng, rng.uniform(1500, 3800), rng.uniform(0.004, 0.01), rise=0.9)
            mix_into(out, d * rng.uniform(0.08, 0.2), t0 + n_of(rng.uniform(0.03, 0.15)))
    return f32(out)


def gorgoglio(rng, n_glug, f_cav, passo):
    """Una sacca d'aria che esce dal condotto: glu-glu-glu (una cavità risonante a colpi)."""
    out = np.zeros(n_of(n_glug * passo * 1.2 + 0.4))
    t0 = 0.0
    for k in range(n_glug):
        m = n_of(0.12)
        exc = lp(white(m, rng), 900, 2) * env_ad(m, 0.004, 0.08)
        f = f_cav * rng.uniform(0.92, 1.1) * (1 + 0.18 * k / max(n_glug - 1, 1))
        g = resonator_bank(exc, [f, f * 2.3, f * 3.9], [0.09, 0.05, 0.03], [1.0, 0.35, 0.12])
        mix_into(out, g * rng.uniform(0.6, 1.0), n_of(t0))
        if rng.random() < 0.6:
            b = bollicina(rng, f * rng.uniform(1.3, 2.0), rng.uniform(0.03, 0.06), rise=0.2)
            mix_into(out, b * 0.4, n_of(t0 + 0.01))
        t0 += passo * rng.uniform(0.85, 1.15)
    return f32(out)


def fossa_ribolle_loop(rng, dur=5.0, xf=1.0):
    tot = dur + xf
    n = n_of(tot)
    out = np.zeros(n)
    # la spinta dell'acqua che risale dal condotto: rombo cupo che respira piano
    out += lp(colored(n, rng, -6.0, fmin=25.0), 260, 2) * (0.75 + 0.25 * smooth_noise(n, 0.6, rng)) * 0.55
    # sacche d'aria dal condotto
    t = rng.uniform(0.0, 0.4)
    while t < tot - 0.6:
        g = gorgoglio(rng, int(rng.integers(3, 8)), rng.uniform(85, 170), rng.uniform(0.085, 0.13))
        mix_into(out, g * rng.uniform(0.5, 0.9), n_of(t))
        t += rng.uniform(0.7, 1.5)
    # bolle grosse che scoppiano in superficie e bollicine fitte
    for _ in range(int(tot * 3.2)):
        mix_into(out, bolla_grossa(rng, rng.uniform(85, 320)) * rng.uniform(0.25, 0.6),
                 n_of(rng.uniform(0, tot - 0.5)))
    for _ in range(int(tot * 14)):
        b = bollicina(rng, rng.uniform(280, 950), rng.uniform(0.01, 0.03), rise=0.2)
        mix_into(out, b * rng.uniform(0.04, 0.12), n_of(rng.uniform(0, tot - 0.2)))
    # l'acqua che si allarga nelle vasche basse e lambisce i bordi
    out += bp(white(n, rng), 400, 2600, 2) * (0.5 + 0.5 * np.clip(smooth_noise(n, 1.3, rng) + 0.2, 0, 1)) * 0.06
    return make_loop(hp(out, 25, 2), dur, xf)


def cascata(rng, dur, punti, fitta=1.0):
    """Acqua che cola a cascata da un corpo grande: getti, rivoli e bollicine, densità a punti."""
    k = n_of(dur)
    dens = env_points(punti, k)
    getti = bp(white(k, rng), 250, 4000, 2) * (0.35 + 0.65 * np.clip(smooth_noise(k, 28, rng, 2) + 0.2, 0, 1))
    out = getti * dens * 0.22
    for _ in range(int(140 * dur * fitta)):
        t0 = rng.uniform(0, dur - 0.05)
        if rng.random() > dens[n_of(t0)]:
            continue
        b = bollicina(rng, rng.uniform(300, 2600), rng.uniform(0.005, 0.02), rise=0.6)
        mix_into(out, b * rng.uniform(0.05, 0.18), n_of(t0))
    return f32(out)


def lastra(rng, forza=1.0):
    """Una lastra d'acqua che ricade: tonfo molle e spruzzo."""
    k = n_of(0.35)
    x = lp(white(k, rng), rng.uniform(500, 800), 2) * env_points([(0, 0), (0.01, 1), (0.12, 0.4), (0.35, 0)], k)
    x += bp(white(k, rng), 600, 3500, 2) * env_points([(0, 0), (0.008, 1), (0.08, 0.2), (0.35, 0)], k) * 0.35
    return f32(x * forza)


# --- pelle bagnata ------------------------------------------------------------------------------

def dito(rng, forza=1.0, palmo=False):
    """Un polpastrello (o il palmo) bagnato che si appoggia sulla piastrella, e l'acqua che esce
    da sotto."""
    out = np.zeros(n_of(0.35))
    tonfo = norm(kenney('impactSoft_medium_00%d.ogg' % rng.integers(0, 5)))
    tonfo = pitch(tonfo, rng.uniform(1.5, 3.5) if palmo else rng.uniform(7, 11))
    mix_into(out, lp(tonfo, 2500) * (1.0 if palmo else 0.5), 0)
    k = n_of(0.045 if palmo else 0.02)
    splat = bp(white(k, rng), 900, 5000, 2) * env_ad(k, 0.0008, k / SR)
    mix_into(out, splat * (0.6 if palmo else 0.4), 0)
    tick = resonator_bank(impulso(0.05), rng.uniform(0.95, 1.05) * np.array([2700, 4150]),
                          [0.015, 0.01], [1.0, 0.5])
    mix_into(out, tick * 0.08, 0)
    # l'acqua schiacciata che esce da sotto: risucchio corto e bollicine
    k = n_of(0.07)
    tt = t_axis(k)
    f = 300 + 500 * tt / tt[-1]
    suck = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_points([(0, 0), (0.01, 1), (0.07, 0)], k)
    mix_into(out, suck * (0.08 if palmo else 0.04), n_of(rng.uniform(0.03, 0.06)))
    for _ in range(rng.integers(2, 6) + (4 if palmo else 0)):
        b = bollicina(rng, rng.uniform(1500, 4200), rng.uniform(0.003, 0.009), rise=0.7)
        mix_into(out, b * rng.uniform(0.04, 0.12), n_of(rng.uniform(0.005, 0.12)))
    if palmo:
        sl = pitch(kenney('slime_000.ogg'), rng.uniform(-7, -4))[:n_of(0.25)]
        mix_into(out, lp(sl, 3000) * 0.12 * np.linspace(1, 0, len(sl)), n_of(0.02))
    return f32(out * forza)


def mano(rng, out, t0, forza=1.0):
    """Quattro dita che si appoggiano una dopo l'altra, poi il palmo."""
    t = t0
    for _ in range(4):
        mix_into(out, dito(rng, forza * rng.uniform(0.7, 1.0)), n_of(t))
        t += rng.uniform(0.03, 0.06)
    mix_into(out, dito(rng, forza, palmo=True), n_of(t + rng.uniform(0.05, 0.09)))


def gocce(rng, out, da, a, rate_da, rate_a):
    """Gocce che le cadono di dosso: in acqua e sulle piastrelle, sempre più rade."""
    t = da
    while t < a:
        k = (t - da) / max(a - da, 1e-3)
        rate = rate_da * (1 - k) + rate_a * k
        g = goccia_acqua(rng) * 0.6 if rng.random() < 0.45 else goccia_pavimento(rng)
        mix_into(out, g * rng.uniform(0.04, 0.12), n_of(t))
        t += rng.exponential(1.0 / rate)


def lei_sbuca(rng):
    dur = 6.5
    n = n_of(dur)
    out = np.zeros(n)
    # l'acqua che si gonfia sopra di lei, prima di rompersi
    k = n_of(0.8)
    gonfia = lp(colored(k, rng, -6.0, fmin=30.0), 220, 2) * env_points([(0, 0), (0.45, 1.0), (0.8, 0.3)], k) ** 1.5
    mix_into(out, gonfia * 0.8, 0)
    # rompe la superficie: l'acqua si apre, lenta e pesante
    k = n_of(1.1)
    apre = tv_biquad(white(k, rng), 'bandpass', env_points([(0, 280), (0.35, 850), (1.1, 450)], k), 0.9)
    apre *= env_points([(0, 0), (0.12, 1.0), (0.45, 0.55), (1.1, 0)], k)
    mix_into(out, apre * 0.5, n_of(0.3))
    for _ in range(4):
        mix_into(out, bolla_grossa(rng, rng.uniform(90, 200)) * rng.uniform(0.2, 0.4), n_of(rng.uniform(0.3, 0.7)))
    # l'acqua che le cola di dosso a cascata e ricade a lastre
    mix_into(out, cascata(rng, 3.4, [(0, 0), (0.25, 1.0), (0.7, 0.8), (1.4, 0.35), (2.2, 0.2), (3.4, 0.0)]), n_of(0.4))
    for tl in sorted(rng.uniform(0.55, 2.3, 7)):
        mix_into(out, lastra(rng, rng.uniform(0.3, 0.7)), n_of(tl))
    # le mani sul bordo: dita, poi palmo; prima una mano, poi l'altra
    mano(rng, out, 1.1, 1.0)
    mano(rng, out, 1.62, 0.9)
    # il vinile che si tende sotto il peso
    for t0, d, fa, fb, g in [(2.0, 0.6, 140, 100, 0.07), (2.95, 0.45, 120, 95, 0.05)]:
        cr = lp(cigolio_gomma(rng, d, fa, fb), 1500)
        mix_into(out, cr * g, n_of(t0))
    # l'acqua mossa che lambisce i bordi e si calma
    k = n_of(4.6)
    lamb = lp(white(k, rng), 550, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.9 * t_axis(k)) ** 2)
    lamb *= env_points([(0, 0), (0.4, 1.0), (4.6, 0)], k)
    mix_into(out, lamb * 0.12, n_of(1.6))
    # rivoli e gocce, sempre più radi
    k = n_of(2.8)
    rivoli = bp(white(k, rng), 1000, 5000, 2) * (0.4 + 0.6 * np.clip(smooth_noise(k, 12, rng) + 0.3, 0, 1))
    mix_into(out, rivoli * env_points([(0, 0.0), (0.2, 1.0), (2.8, 0)], k) * 0.05, n_of(1.8))
    gocce(rng, out, 1.9, dur - 0.4, 8.0, 1.0)
    return fade(hp(out, 30, 2), 0.01, 0.6)


def lei_scivola_sotto(rng):
    dur = 4.5
    n = n_of(dur)
    out = np.zeros(n)
    # le mani che scivolano dal bordo bagnato (pelle sulla ceramica), poi entrano in acqua
    for t0, fa, fb in [(0.0, 520, 380), (0.11, 470, 330)]:
        sk = lp(cigolio_gomma(rng, 0.22, fa, fb), 2600) * 0.1
        k = len(sk)
        sk += bp(white(k, rng), 800, 4000, 2) * env_points([(0, 0), (0.02, 1), (0.22, 0)], k) * 0.07
        mix_into(out, sk, n_of(t0))
        k = n_of(0.3)
        spl = bp(white(k, rng), 300, 3000, 2) * env_points([(0, 0), (0.01, 1), (0.3, 0)], k) ** 2
        mix_into(out, spl * 0.3, n_of(t0 + 0.22))
    # il corpo che torna giù: l'acqua che le scorre intorno
    k = n_of(1.7)
    giu = lp(colored(k, rng, -4.0, fmin=40.0), 900, 2) * env_points([(0, 0), (0.4, 1.0), (1.2, 0.7), (1.7, 0)], k)
    mix_into(out, giu * 0.45, n_of(0.15))
    for _ in range(22):
        b = bollicina(rng, rng.uniform(200, 900), rng.uniform(0.01, 0.04), rise=0.4)
        mix_into(out, b * rng.uniform(0.05, 0.16), n_of(rng.uniform(0.35, 1.55)))
    # il risucchio: l'acqua che si richiude sopra la testa
    k = n_of(0.55)
    ris = tv_biquad(white(k, rng), 'bandpass', env_points([(0, 540), (0.35, 120), (0.55, 100)], k), 3.5)
    ris *= env_points([(0, 0), (0.05, 1), (0.3, 0.6), (0.55, 0)], k)
    mix_into(out, ris * 0.8, n_of(1.35))
    mix_into(out, bollicina(rng, 100, 0.09, rise=-0.25, dur=0.5) * 0.7, n_of(1.42))
    k = n_of(0.25)
    soffio = bp(white(k, rng), 1500, 5000, 2) * env_ad(k, 0.03, 0.2)
    mix_into(out, soffio * 0.06, n_of(1.38))
    # poche bolle che risalgono, sempre più piccole e rade; poi niente
    for t0, f, g in [(2.0, 140, 0.55), (2.45, 190, 0.4), (2.8, 230, 0.32), (3.35, 300, 0.22), (3.95, 380, 0.14)]:
        mix_into(out, bolla_grossa(rng, f * rng.uniform(0.95, 1.05)) * g, n_of(t0))
    return fade(hp(out, 30, 2), 0.0, 0.3)


# --- morso -----------------------------------------------------------------------------------

def strappo(rng, dur):
    """Pelle di vinile bagnata che si strappa: crepitio fitto e uno 'sguish' sotto."""
    k = n_of(dur)
    cr = treno_impulsi(k, 5000, rng, alpha=2.0)
    cr = bp(cr, 900, 6500, 2) * env_points([(0, 0), (0.005, 1), (dur * 0.6, 0.7), (dur, 0)], k)
    sl = kenney('slime_001.ogg')
    a = rng.integers(0, len(sl) - k * 2)
    sq = lp(pitch(sl[a:a + k * 2], -5), 2500)[:k] * env_points([(0, 0), (0.01, 1), (dur, 0)], k)
    return f32(cr * 0.5 + sq * 0.5)


def morso(rng):
    dur = 1.8
    c = MORSO_COLPO
    n = n_of(dur)
    out = np.zeros((n, 2))
    # 1) lo scatto fuori dall'acqua: l'acqua che esplode, il corpo che fende l'aria, gli spruzzi
    k = n_of(0.45)
    e = env_points([(0, 0), (0.004, 1), (0.08, 0.5), (0.45, 0)], k) ** 1.5
    spl = np.stack([bp(white(k, rng), 180, 6500, 2) * e, bp(white(k, rng), 180, 6500, 2) * e], axis=1)
    mix_into(out, spl * 0.8, 0)
    k = n_of(0.5)
    sp = lp(colored(k, rng, -3.0, fmin=60.0), 700, 2) * env_points([(0, 0), (0.1, 1), (0.5, 0)], k)
    mix_into(out, stereo(sp * 0.5), 0)
    for _ in range(40):
        b = bollicina(rng, rng.uniform(1500, 5000), rng.uniform(0.003, 0.01), rise=0.8)
        mix_into(out, pan(b * rng.uniform(0.05, 0.15), rng.uniform(-0.8, 0.8)), n_of(rng.uniform(0.03, 0.55)))
    # 2) la pelle che si tende e si strappa sotto l'occhio; la fauce che si apre, filamenti
    tende = lp(cigolio_gomma(rng, 0.65, 70, 260), 2500) * env_points([(0, 0.2), (0.5, 1.0), (0.65, 0.6)], n_of(0.65))
    mix_into(out, stereo(tende * 0.22), n_of(0.2))
    for t0, d, g in [(0.38, 0.09, 0.7), (0.6, 0.12, 0.85), (0.82, 0.1, 1.0)]:
        mix_into(out, pan(strappo(rng, d) * g, rng.uniform(-0.2, 0.2)), n_of(t0))
    cerniera = lp(cigolio_gomma(rng, 0.45, 55, 40), 900)
    mix_into(out, stereo(cerniera * 0.18), n_of(0.45))
    for _ in range(7):
        fil = pitch(kenney('slime_000.ogg'), rng.uniform(3, 8))[:n_of(0.08)]
        fil = fil * np.linspace(1, 0, len(fil))
        mix_into(out, pan(lp(fil, 5000) * rng.uniform(0.08, 0.16), rng.uniform(-0.4, 0.4)), n_of(rng.uniform(0.45, 0.93)))
    # 3) un attimo di vuoto, poi la fauce si chiude (al lampo rosso)
    vuoto = env_points([(0, 1.0), (c - 0.05, 1.0), (c - 0.02, 0.25), (c, 0.25), (c + 0.001, 1.0), (dur, 1.0)], n)
    out *= vuoto[:, None]
    clack = np.zeros(n_of(0.2))
    for dt, g in [(0.0, 1.0), (0.009, 0.6)]:
        cl = resonator_bank(impulso(0.2), rng.uniform(0.95, 1.05) * np.array([1900, 3100, 4700, 6800]),
                            [0.02, 0.015, 0.01, 0.007], [1.0, 0.8, 0.5, 0.3])
        mix_into(clack, cl * g, n_of(dt))
    mix_into(out, stereo(clack * 2.2), n_of(c))
    k = n_of(0.45)
    tt = t_axis(k)
    f = 42 + 80 * np.exp(-tt / 0.06)
    tonfo = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(k, 0.002, 0.35)
    tonfo += lp(white(k, rng), 450, 2) * env_ad(k, 0.001, 0.12) * 0.6
    mix_into(out, stereo(tonfo * 0.9), n_of(c))
    k = n_of(0.16)
    e = env_ad(k, 0.001, 0.14)
    sch = np.stack([np.tanh(bp(treno_impulsi(k, 9000, rng, alpha=2.0), 500, 5000, 2) * 3.0) * e for _ in range(2)], axis=1)
    mix_into(out, sch * 0.45, n_of(c + 0.004))
    sl = kenney('slime_001.ogg')
    a = rng.integers(0, len(sl) - n_of(0.6))
    sq = lp(pitch(sl[a:a + n_of(0.6)], -9), 1800)[:n_of(0.32)]
    sq = sq * env_points([(0, 0), (0.01, 1), (0.32, 0)], len(sq))
    mix_into(out, stereo(sq * 0.55), n_of(c + 0.02))
    # 4) coda: due gocce, poi niente (il nero arriva a 2 s)
    for t0 in [c + 0.3, c + 0.52]:
        mix_into(out, stereo(goccia_pavimento(rng) * 0.12), n_of(t0))
    out = reverb(out, ir_piccola(), wet=0.12, dry=1.0, tail=False)
    return fade(hp(out, 30, 2), 0.0, 0.25)


def main():
    rng = np.random.default_rng(2008)
    print('Lei (tappa 8)')
    salva(CART, 'fossa_ribolle_loop', fossa_ribolle_loop(rng), loudness=-19, qualita=4,
          nota='gorgoglio profondo e bolle grosse: la fossa che riempie le vasche basse')
    salva(CART, 'lei_sbuca', lei_sbuca(rng), loudness=-14, corto=True, qualita=4,
          fonte='sintesi + Kenney Impact Sounds e Sci-Fi Sounds (CC0)', nota='impactSoft_medium, slime_000')
    salva(CART, 'lei_scivola_sotto', lei_scivola_sotto(rng), loudness=-16, corto=True, qualita=4)
    salva(CART, 'morso', morso(rng), loudness=-12, corto=True, qualita=5,
          fonte='sintesi + Kenney Sci-Fi Sounds (CC0)', nota='slime_000, slime_001; la fauce si chiude a 1,0 s')


if __name__ == '__main__':
    main()
