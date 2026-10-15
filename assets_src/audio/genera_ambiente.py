"""Suoni d'ambiente della sala principale: pioggia sulla cupola, vento, nave (ronzio, mare
contro lo scafo), tuoni vicini e lontani, gemiti e scricchiolii metallici, colpi lontani,
gocce, sirena d'allarme lontana, sott'acqua. Tutto sintetizzato (più qualche campione CC0
di Kenney rallentato). Uscita: godot/audio/ambiente/.
"""
import numpy as np
from scipy import signal

from comune import ir_nave, ir_sala, kenney, salva
from lib_audio import (SR, biquad, bp, brown, colored, comb, db, env_ad, env_points, eq, f32, fade, hp,
                       lp, make_loop, mix_into, mono, n_of, pan, pink, resample_ratio, resonator_bank,
                       reverb, reverb_loop, smooth_noise, stereo, t_axis, tv_biquad, varispeed, white)

CART = 'ambiente'
GAIN_MACCHINE = 0.05


# --- pioggia sulla cupola ---------------------------------------------------------------

def grana_vetro(rng, f_base):
    """Il 'tic' di una goccia sul vetro: impulso breve in pochi modi acuti e smorzati."""
    n = n_of(0.03)
    exc = np.zeros(n)
    exc[0] = 1.0
    exc[1:6] = rng.uniform(-0.5, 0.5, 5)
    fr = f_base * np.array([1.0, 1.62, 2.41, 3.37])
    return resonator_bank(exc, fr, rng.uniform(0.004, 0.014, 4), [1.0, 0.6, 0.35, 0.2])


def treno_impulsi(n, rate, rng, gust=None, alpha=3.0, cap=6.0):
    """Treno di impulsi di Poisson con ampiezze a coda lunga (qualche goccia grossa)."""
    k = rng.poisson(rate * n / SR)
    pos = rng.integers(0, n, k)
    amp = np.minimum(rng.pareto(alpha, k) + 0.3, cap) * rng.choice([-1, 1], k)
    if gust is not None:
        amp *= gust[pos]
    x = np.zeros(n)
    np.add.at(x, pos, amp)
    return x


def pioggia_cupola(rng, dur=40.0, xf=2.0):
    n = n_of(dur + xf)
    raffiche = 0.75 + 0.25 * smooth_noise(n, 0.06, rng, octaves=3)
    out = np.zeros((n, 2))
    # 1) ticchettio fitto sul vetro: tre colori di grana, canali scorrelati
    for f_base, rate, g in [(2300, 900, 1.0), (3600, 1100, 0.8), (5200, 700, 0.55)]:
        for ch in range(2):
            imp = treno_impulsi(n, rate, rng, raffiche)
            gr = grana_vetro(rng, f_base * rng.uniform(0.92, 1.08))
            out[:, ch] += g * signal.fftconvolve(imp, gr)[:n]
    out = hp(lp(out, 9000, 2), 350, 2)
    out *= 0.22
    # 2) gocce grosse vicine: 'tink' sul vetro e 'tok' sul telaio
    for _ in range(int(dur * 5)):
        t0 = rng.uniform(0, dur + xf - 0.2)
        if rng.random() < 0.6:
            g = grana_vetro(rng, rng.uniform(2800, 4800))
            g = resonator_bank(g, [rng.uniform(3000, 5000)], [rng.uniform(0.03, 0.08)], [0.6]) + g
        else:
            e = np.zeros(n_of(0.15))
            e[0] = 1
            g = resonator_bank(e, rng.uniform(700, 1500, 3), rng.uniform(0.02, 0.06, 3), [1, 0.5, 0.3])
        g = g * rng.uniform(0.15, 0.5)
        mix_into(out, pan(g, rng.uniform(-0.9, 0.9)), n_of(t0))
    # 3) rombo della pioggia battente (rumore rosa scuro) che segue le raffiche
    roar = np.stack([pink(n, rng), pink(n, rng)], axis=1)
    roar = hp(lp(roar, 1800, 2), 90, 2)
    out += roar * 0.09 * raffiche[:, None]
    # 4) la cupola che vibra: rumore marrone molto basso
    rumble = lp(brown(n, rng), 140, 2)
    out += (rumble * 0.06 * raffiche)[:, None]
    # 5) rivoli che scendono sul vetro e nelle grondaie: bollicine leggere
    rivoli = np.zeros((n, 2))
    for _ in range(int(dur * 30)):
        t0 = rng.uniform(0, dur + xf - 0.1)
        b = bollicina(rng, rng.uniform(700, 2200), rng.uniform(0.015, 0.04), rise=rng.uniform(0.6, 1.4))
        mix_into(rivoli, pan(b * rng.uniform(0.02, 0.08), rng.uniform(-1, 1)), n_of(t0))
    out += lp(rivoli, 5000)
    out = reverb(out, ir_sala(), wet=0.32, dry=0.85, tail=False)
    return make_loop(hp(out, 25, 2), dur, xf)


def bollicina(rng, f0, tau, rise=1.0, dur=None):
    """Bolla che si forma in acqua (modello di Minnaert): sinusoide che sale di tono."""
    dur = dur or tau * 6
    t = t_axis(n_of(dur))
    f = f0 * (1 + rise * t / (tau * 4))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return f32(np.sin(ph) * np.exp(-t / tau) * np.clip(t / 0.0008, 0, 1))


# --- vento -------------------------------------------------------------------------------

def vento(rng, dur=45.0, xf=2.5):
    n = n_of(dur + xf)
    gust = 0.5 + 0.5 * smooth_noise(n, 0.07, rng, octaves=3)
    gust = np.clip(gust, 0, 1) ** 1.6
    out = np.zeros((n, 2))
    # soffio di fondo
    for ch in range(2):
        b = bp(pink(n, rng), 70, 900, 2) * (0.25 + 0.75 * gust)
        out[:, ch] += b * 0.5
    # ululati: rumore stretto con il centro che sale con le raffiche
    for f_base, span, q, side, g in [(330, 260, 14, -0.6, 0.35), (560, 340, 18, 0.55, 0.25),
                                     (880, 300, 22, 0.1, 0.12)]:
        wob = smooth_noise(n, 0.3, rng) * 0.04
        fc = f_base + span * gust + f_base * wob
        h = tv_biquad(white(n, rng), 'bandpass', fc, q)
        amp = np.clip(gust - 0.25, 0, 1) ** 1.5
        out += pan(h * amp * g * 3.0, side)
    # vetri che vibrano nelle raffiche forti
    tr = treno_impulsi(n, 40, rng) * np.clip(gust - 0.6, 0, 1) * 2
    rattle = resonator_bank(tr, [1900, 2650, 3400], [0.03, 0.02, 0.02], [1, 0.7, 0.5])
    out += pan(lp(rattle, 5000) * 0.05, 0.3)
    out = lp(out, 3200, 2)
    out = reverb(out, ir_sala(), wet=0.25, dry=0.9, tail=False)
    return make_loop(out, dur, xf)


# --- nave: ronzio, macchine lontane, mare contro lo scafo ----------------------------------

def nave(rng, dur=40.0, xf=2.0):
    n = n_of(dur + xf)
    t = t_axis(n)
    out = np.zeros((n, 2))
    # ronzio elettrico a 50 Hz (due sorgenti un po' scordate: battimenti lenti)
    hum = np.zeros(n)
    for f0, gg in [(50.0, 1.0), (50.15, 0.7)]:
        for k, a in [(1, 0.5), (2, 1.0), (3, 0.55), (4, 0.3), (5, 0.18), (6, 0.12), (8, 0.05)]:
            hum += gg * a * np.sin(2 * np.pi * f0 * k * t + rng.uniform(0, 6.28))
    hum *= 0.022 * (0.85 + 0.15 * smooth_noise(n, 0.2, rng))
    out += hum[:, None]
    # macchine lontane: rombo marrone che respira
    mac = lp(colored(n, rng, -6.0, fmin=25.0), 110, 3) * (0.7 + 0.3 * smooth_noise(n, 0.1, rng))
    mac2 = lp(colored(n, rng, -6.0, fmin=25.0), 110, 3)
    out += np.stack([mac, mac2], axis=1) * GAIN_MACCHINE
    # onde contro lo scafo: tonfi bassi che fanno risuonare il metallo
    tt = rng.uniform(0.5, 3.0)
    scafo = np.zeros(n)
    while tt < dur + xf - 1:
        k = n_of(rng.uniform(0.9, 1.8))
        e = env_points([(0, 0), (0.25, 1), (k / SR, 0)], k) ** 2
        burst = lp(white(k, rng), rng.uniform(90, 160), 2) * e * rng.uniform(0.6, 1.0)
        mix_into(scafo, burst, n_of(tt))
        tt += rng.uniform(5.5, 9.5)
    ris = resonator_bank(scafo, [38, 57, 83, 121, 167], [1.8, 1.5, 1.2, 0.9, 0.7], [1, 0.8, 0.6, 0.35, 0.2])
    sc = lp(scafo, 300) * 0.5 + ris * 0.012
    # risacca: fruscio basso che sale e scende con le onde
    risacca = lp(pink(n, rng), 600, 2) * (0.5 + 0.5 * smooth_noise(n, 0.12, rng)) * 0.05
    out += np.stack([sc + risacca, sc * 0.9 + lp(pink(n, rng), 600, 2) * 0.04], axis=1)
    out = reverb(out, ir_nave(), wet=0.3, dry=0.9, tail=False)
    return make_loop(hp(out, 25, 2), dur, xf)


# --- sott'acqua --------------------------------------------------------------------------

def sottacqua(rng, dur=16.0, xf=1.5):
    n = n_of(dur + xf)
    t = t_axis(n)
    base = lp(brown(n, rng), 320, 3) * (0.8 + 0.2 * smooth_noise(n, 0.15, rng))
    out = np.stack([base, lp(brown(n, rng), 320, 3)], axis=1) * 0.5
    press = (np.sin(2 * np.pi * 42 * t) * 0.6 + np.sin(2 * np.pi * 63 * t) * 0.3) * 0.05
    out += press[:, None]
    for _ in range(int(dur * 2.5)):
        t0 = rng.uniform(0, dur + xf - 0.3)
        b = bollicina(rng, rng.uniform(180, 700), rng.uniform(0.03, 0.08), rise=rng.uniform(0.08, 0.25))
        mix_into(out, pan(b * rng.uniform(0.03, 0.09), rng.uniform(-0.8, 0.8)), n_of(t0))
    # grappoli di bolle che salgono
    for _ in range(4):
        t0 = rng.uniform(0, dur)
        for k in range(rng.integers(6, 14)):
            b = bollicina(rng, rng.uniform(400, 1200), rng.uniform(0.01, 0.03), rise=0.3)
            mix_into(out, pan(b * 0.035, rng.uniform(-0.5, 0.5)), n_of(t0 + k * rng.uniform(0.02, 0.09)))
    out = hp(lp(out, 1400, 2), 25, 2)
    return make_loop(out, dur, xf)


# --- tuoni -------------------------------------------------------------------------------

def rombo(rng, n, t_start, durata, lp_hz, gobbe):
    """Rotolamento del tuono: rumore marrone con più 'gobbe' sovrapposte."""
    t = t_axis(n)
    envl = np.zeros(n)
    for _ in range(gobbe):
        c = t_start + rng.uniform(0.0, durata * 0.55)
        w = rng.uniform(0.35, 1.4)
        a = rng.uniform(0.4, 1.0) * np.exp(-(c - t_start) / (durata * 0.5))
        envl += a * np.exp(-0.5 * ((t - c) / w) ** 2) * (t > t_start - 3 * w)
    coda = np.exp(-np.maximum(t - t_start, 0) / (durata * 0.35)) * (t > t_start)
    envl = envl + 0.35 * coda * np.clip((t - t_start) / 0.3, 0, 1)
    out = np.zeros((n, 2))
    for ch in range(2):
        b = lp(brown(n, rng), lp_hz, 3) + 0.4 * lp(pink(n, rng), lp_hz * 2.2, 2)
        out[:, ch] = b * envl
    return out


def tuono(rng, vicino: bool):
    dur = rng.uniform(7.5, 9.5) if vicino else rng.uniform(9.0, 12.0)
    n = n_of(dur)
    t = t_axis(n)
    out = np.zeros((n, 2))
    if vicino:
        p = rng.uniform(-0.5, 0.5)
        # schiocco iniziale
        k = n_of(0.25)
        crack = hp(white(k, rng), 250, 2) * env_ad(k, 0.002, 0.18) * 1.4
        crack = np.tanh(crack * 2.0)
        mix_into(out, pan(crack, p), n_of(0.05))
        # lacerazione: impulsi sempre più radi
        tt = 0.06
        while tt < rng.uniform(0.6, 1.1):
            m = n_of(0.012)
            imp = bp(white(m, rng), 400, 5000, 2) * env_ad(m, 0.0005, 0.01) * rng.uniform(0.3, 1.0) * \
                np.exp(-tt * 3)
            mix_into(out, pan(imp * 2.0, p + rng.uniform(-0.3, 0.3)), n_of(tt))
            tt += rng.exponential(0.025) + 0.004
        # botto basso
        k = n_of(0.9)
        boom = lp(white(k, rng), 110, 3) * env_ad(k, 0.01, 0.8) * 2.5
        mix_into(out, stereo(boom), n_of(0.07))
        out += rombo(rng, n, 0.3, dur * 0.8, 230, 7) * 1.1
    else:
        out += rombo(rng, n, rng.uniform(0.3, 0.8), dur * 0.85, 140, 6) * 1.2
    # sub (Kenney, esplosione a bassa frequenza) sotto al primo rombo
    sub = kenney('lowFrequency_explosion_00%d.ogg' % rng.integers(0, 2))
    sub = lp(sub, 90, 2) * (0.5 if vicino else 0.35)
    mix_into(out, stereo(sub), n_of(0.08 if vicino else 0.6))
    # vetri della cupola che vibrano col rombo
    envl = lp(np.abs(mono(out)), 8)
    buzz = bp(white(n, rng), 1600, 3800, 2) * envl * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 37 * t)))
    out += pan(buzz * (0.2 if vicino else 0.12), rng.uniform(-0.4, 0.4))
    out = reverb(out, ir_sala(), wet=0.45 if vicino else 0.35, dry=0.85, tail=False)
    out = hp(out, 22, 2)
    return fade(out, 0.0, 1.5)


# --- gemiti, scricchiolii e colpi della nave -------------------------------------------------

MODI_LAMIERA = [87, 139, 226, 361, 517, 744, 1031, 1388, 1820, 2390]


def gemito_attrito(rng, dur):
    """Scafo sotto sforzo: attrito a scatti (stick-slip) che eccita i modi di una lamiera."""
    n = n_of(dur)
    t = t_axis(n)
    rate = 18 + 22 * (0.5 + 0.5 * smooth_noise(n, 0.4, rng, 2))
    ph = np.cumsum(rate / SR)
    jit = ph + 0.15 * smooth_noise(n, 30, rng)
    imp = np.diff(np.floor(jit), prepend=0) > 0
    exc = imp.astype(float) * rng.uniform(0.4, 1.0, n)
    exc += white(n, rng) * 0.02
    envl = env_points([(0, 0), (dur * rng.uniform(0.2, 0.4), 1), (dur * 0.75, 0.6), (dur, 0)], n) ** 1.3
    exc *= envl
    fr = np.array(MODI_LAMIERA) * rng.uniform(0.75, 1.3)
    out = resonator_bank(exc, fr, rng.uniform(0.25, 0.9, len(fr)), 1 / (1 + np.arange(len(fr)) * 0.35))
    return f32(out)


def gemito(rng, i):
    dur = rng.uniform(3.5, 6.0)
    n = n_of(dur)
    a = gemito_attrito(rng, dur)
    # porta che cigola (Kenney) rallentata 3-4 volte: un cigolio enorme e grave
    c = kenney('creak%d.ogg' % (1 + i % 3))
    c = resample_ratio(c, rng.uniform(2.6, 3.8))
    c = lp(c, 2500, 2)
    c = c + 0.4 * resonator_bank(c, np.array(MODI_LAMIERA[:6]) * rng.uniform(0.8, 1.2), [0.6] * 6,
                                 [1, 0.8, 0.6, 0.5, 0.4, 0.3])
    out = np.zeros(n + n_of(3))
    mix_into(out, a / (np.abs(a).max() + 1e-9), 0)
    mix_into(out, c / (np.abs(c).max() + 1e-9) * 0.8, n_of(rng.uniform(0.2, 1.0)))
    out = lp(hp(out, 45, 2), 3500, 2)
    out = mono(reverb(out, ir_nave(), wet=0.55, dry=0.7, tail=False))
    return fade(out, 0.05, 1.2)


def scricchiolio(rng, i):
    c = kenney('creak%d.ogg' % (1 + i % 3))
    c = resample_ratio(c, rng.uniform(1.4, 2.0))
    c = c + 0.5 * resonator_bank(c, np.array(MODI_LAMIERA[3:9]) * rng.uniform(0.9, 1.1), [0.35] * 6,
                                 [1, 0.8, 0.6, 0.5, 0.4, 0.3])
    out = np.concatenate([c, np.zeros(n_of(2.5))])
    out = mono(reverb(lp(out, 5000), ir_nave(), wet=0.45, dry=0.8, tail=False))
    return fade(out, 0.0, 0.8)


def tic_metallo(rng):
    """Lamiera che si assesta col freddo: un 'ping' metallico secco e lungo."""
    n = n_of(2.6)
    e = np.zeros(n)
    e[0] = 1.0
    f0 = rng.uniform(900, 1500)
    fr = f0 * np.array([1.0, 2.32, 4.25, 6.63, 9.38])
    out = resonator_bank(e, fr, [1.6, 1.0, 0.7, 0.5, 0.35], [1, 0.7, 0.45, 0.3, 0.2])
    out += resonator_bank(e, [f0 * 0.31], [0.8], [0.4])
    out = mono(reverb(out, ir_nave(), wet=0.5, dry=0.8, tail=False))
    return fade(out, 0.0, 0.6)


def colpo_lontano(rng, i):
    """Una porta stagna che sbatte lontano, nella pancia della nave."""
    a = kenney('impactMetal_heavy_00%d.ogg' % (i % 5))
    b = kenney('doorClose_%d.ogg' % (1 + i % 4))
    x = np.zeros(n_of(1.5))
    mix_into(x, resample_ratio(a, 1.6), 0)
    mix_into(x, resample_ratio(b, 1.9) * 0.8, n_of(0.01))
    x = x + 0.6 * resonator_bank(x, [61, 97, 140, 233], [1.2, 1.0, 0.8, 0.6], [1, 0.7, 0.5, 0.3])
    x = lp(x, 1500, 2)
    x = np.concatenate([x, np.zeros(n_of(4))])
    out = mono(reverb(x, ir_nave(), wet=0.85, dry=0.25, tail=False))
    return fade(out, 0.0, 1.5)


# --- gocce ----------------------------------------------------------------------------------

def goccia_acqua(rng):
    n = n_of(0.45)
    out = np.zeros(n)
    k = n_of(0.004)
    click = bp(white(k, rng), 2500, 9000, 2) * env_ad(k, 0.0002, 0.003) * 0.25
    mix_into(out, click, 0)
    b = bollicina(rng, rng.uniform(900, 2400), rng.uniform(0.012, 0.035), rise=rng.uniform(0.6, 1.5))
    mix_into(out, b, n_of(rng.uniform(0.001, 0.004)))
    if rng.random() < 0.7:   # gocciolina che ricade (getto di Worthington)
        b2 = bollicina(rng, rng.uniform(2500, 4200), rng.uniform(0.006, 0.014), rise=1.0)
        mix_into(out, b2 * rng.uniform(0.2, 0.45), n_of(rng.uniform(0.06, 0.14)))
    return fade(out, 0.0, 0.05)


def goccia_pavimento(rng):
    n = n_of(0.3)
    out = np.zeros(n)
    k = n_of(0.03)
    splat = bp(white(k, rng), 900, 6000, 2) * env_ad(k, 0.0004, 0.025)
    mix_into(out, splat * 0.6, 0)
    for _ in range(rng.integers(1, 4)):
        b = bollicina(rng, rng.uniform(2500, 5000), rng.uniform(0.004, 0.01), rise=0.8)
        mix_into(out, b * rng.uniform(0.15, 0.4), n_of(rng.uniform(0.002, 0.03)))
    return fade(out, 0.0, 0.05)


# --- sirena d'allarme lontana -----------------------------------------------------------------

def sirena(rng, i):
    """Allarme generale della nave (suoni brevi e uno lungo), lontano e un po' guasto."""
    blasts = [(0.0, 0.55), (0.9, 0.55), (1.8, 0.55), (2.7, 0.55), (3.6, 0.55), (4.6, 2.2)]
    if i == 1:
        blasts = [(0.0, 0.6), (1.0, 0.6), (2.0, 0.6), (3.2, 2.6)]
    dur = blasts[-1][0] + blasts[-1][1] + 0.5
    n = n_of(dur)
    t = t_axis(n)
    f = np.full(n, 0.0)
    g = np.zeros(n)
    for k, (s, d) in enumerate(blasts):
        a, b = n_of(s), n_of(s + d)
        f[a:b] = 1.0
        ramp = env_points([(0, 0), (0.04, 1), (d - 0.08, 1), (d, 0)], b - a)
        g[a:b] = ramp
    # il suono lungo finale cala di tono: l'impianto ha poca corrente
    drop = np.ones(n)
    s_last = blasts[-1][0]
    drop[t > s_last] = 1 - 0.18 * np.clip((t[t > s_last] - s_last) / blasts[-1][1], 0, 1) ** 2
    out = np.zeros(n)
    for f0, amp in [(415.0, 1.0), (523.0, 0.6)]:
        ph = 2 * np.pi * np.cumsum(f0 * drop * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t))) / SR
        saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
        out += amp * saw
    out *= g
    out = np.tanh(out * 2.5)
    out = bp(out, 300, 2200, 2)
    out = eq(out, [('peak', 900, 2.0, 6), ('peak', 1600, 3.0, 4)])
    out = lp(out, 1300, 2)
    out = np.concatenate([out, np.zeros(n_of(3.5))])
    st = reverb(out, ir_nave(seed=21), wet=1.0, dry=0.12, tail=False)
    return fade(st, 0.0, 1.5)


def main():
    rng = np.random.default_rng(2026)
    print('Ambiente')
    salva(CART, 'pioggia_cupola_loop', pioggia_cupola(rng), loudness=-24, qualita=4,
          nota='pioggia battente sulla cupola di vetro sentita dalla sala')
    salva(CART, 'vento_loop', vento(rng), loudness=-27, qualita=4, nota='vento e ululati fuori dalla cupola')
    salva(CART, 'nave_loop', nave(rng), loudness=-28, qualita=4,
          nota='ronzio elettrico a 50 Hz, macchine lontane, onde contro lo scafo')
    salva(CART, 'sottacqua_loop', sottacqua(rng), loudness=-24, qualita=4, nota='fondo ovattato sott\'acqua')
    for i in range(3):
        salva(CART, f'tuono_vicino_{i + 1:02d}', tuono(rng, True), loudness=-16, qualita=4,
              fonte='sintesi + Kenney Sci-Fi Sounds (CC0)', nota='lowFrequency_explosion come sub')
    for i in range(3):
        salva(CART, f'tuono_lontano_{i + 1:02d}', tuono(rng, False), loudness=-22, qualita=4,
              fonte='sintesi + Kenney Sci-Fi Sounds (CC0)', nota='lowFrequency_explosion come sub')
    for i in range(4):
        salva(CART, f'nave_gemito_{i + 1:02d}', gemito(rng, i), loudness=-20, qualita=3,
              fonte='sintesi + Kenney RPG Audio (CC0)', nota='creak rallentato e lamiera sintetica')
    for i in range(3):
        salva(CART, f'nave_scricchiolio_{i + 1:02d}', scricchiolio(rng, i), loudness=-20, qualita=3,
              fonte='Kenney RPG Audio (CC0), rielaborato')
    for i in range(3):
        salva(CART, f'nave_tic_{i + 1:02d}', tic_metallo(rng), loudness=-16, corto=True, qualita=3)
    for i in range(3):
        salva(CART, f'nave_colpo_lontano_{i + 1:02d}', colpo_lontano(rng, i), loudness=-20, qualita=3,
              fonte='Kenney Impact Sounds + RPG Audio (CC0), rielaborati')
    for i in range(6):
        salva(CART, f'goccia_acqua_{i + 1:02d}', goccia_acqua(rng), loudness=-18, corto=True, qualita=3)
    for i in range(4):
        salva(CART, f'goccia_pavimento_{i + 1:02d}', goccia_pavimento(rng), loudness=-18, corto=True, qualita=3)
    for i in range(2):
        salva(CART, f'sirena_lontana_{i + 1:02d}', sirena(rng, i), loudness=-26, qualita=3)


if __name__ == '__main__':
    main()
