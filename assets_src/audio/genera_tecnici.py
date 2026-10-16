"""Suoni degli ambienti tecnici (tappe 5-6: camera delle onde, sala pompe, risveglio).

- pompe_ruggito_loop: una pompa industriale a pieno regime (motore, girante, acqua che rugge,
  rombo basso). Tre pompe = tre loop sulle tre pompe, con toni un po' diversi.
- pompa_avvio: il contattore che scatta e la pompa che prende giri (prima del loop).
- corrente_salta: il blackout (interruttori che scattano, l'arco, il ronzio di tutta la nave che
  muore calando di tono, relè lontani).
- crt_neve_loop: la neve di un vecchio monitor a tubo (fruscio, sfarfallio a 50 Hz, fischio a 15,6 kHz).
- plastica_piega_lontano: una grande bambola di vinile che si piega a lungo, lontano (lei che si sveglia).
- tonfo_acqua_lontano: qualcosa di pesante che cade in acqua, lontano.
- paratia_scende_loop: una paratia d'acciaio che scende: motore, catene, guide che stridono.
- maniglione_bloccato: un maniglione antipanico che non si apre.
- porta_ponte_apre: il maniglione che si sblocca e la porta pesante che si apre.
Uscita: godot/audio/tecnici/.
"""
import numpy as np

from comune import ir_nave, kenney, salva
from genera_ambiente import MODI_LAMIERA, bollicina, gemito_attrito, treno_impulsi
from genera_effetti import cigolio_metallo, impulso, ronzio_rete
from genera_giocatore import motorino, norm
from lib_audio import (SR, biquad, bp, colored, comb, env_ad, env_points, f32, fade, hp, lp, make_loop,
                       mix_into, n_of, pitch, resonator_bank, reverb, smooth_noise, t_axis, tv_biquad, white)

CART = 'tecnici'
GIRI = 48.25          # giri al secondo del motore (2 poli a 50 Hz, con lo scorrimento)


# --- pompe ----------------------------------------------------------------------------------

def pompa_strati(rng, n, f_giri, carico=1.0):
    """Gli strati di una pompa centrifuga che gira a f_giri (curva o costante)."""
    f_giri = np.broadcast_to(np.asarray(f_giri, dtype=np.float64), (n,))
    ph = np.cumsum(f_giri) / SR
    t = t_axis(n)
    # ronzio magnetico a 100 Hz (fisso: è la rete) e righe del motore, solo le più basse
    hum = lp(ronzio_rete(rng, n, 100.0, 12, 1.0, 0.05), 450, 2) * 0.18
    # girante a 6 pale: tono di passaggio pale e sue armoniche, modulato dal giro
    pale = np.zeros(n)
    for k, a in [(6, 1.0), (12, 0.22), (18, 0.07), (1, 0.35), (2, 0.25)]:
        pale += a * np.sin(2 * np.pi * k * ph + rng.uniform(0, 6))
    pale *= 0.12 * (0.8 + 0.2 * np.sin(2 * np.pi * ph))
    # acqua turbolenta che rugge, cupa (i medi restano liberi per i suoni del risveglio): rumore
    # che pulsa col giro, con una risonanza di tubo
    acqua = bp(colored(n, rng, -4.0, fmin=30.0), 40, 700, 2)
    acqua = acqua * (0.75 + 0.25 * np.sin(2 * np.pi * 6 * ph)) * (0.85 + 0.15 * smooth_noise(n, 1.5, rng))
    acqua = acqua * 0.5 + comb(acqua, 1 / 71.0, 0.55) * 0.2
    # rombo basso (il "ruggito"): sub che respira con la cavitazione
    rombo = lp(colored(n, rng, -6.0, fmin=25.0), 140, 3) * (0.7 + 0.3 * smooth_noise(n, 0.8, rng)) * 0.9
    sub = np.sin(2 * np.pi * ph * 1.0) * 0.25 + np.sin(2 * np.pi * 37.0 * t) * 0.12
    # cuscinetti e lamiere che vibrano: piccoli colpi a ritmo di giro
    imp = (np.diff(np.floor(ph * 2), prepend=0) > 0) * rng.uniform(0.3, 1.0, n)
    vibra = resonator_bank(imp + treno_impulsi(n, 25, rng) * 0.3, np.array(MODI_LAMIERA[3:8]) * 1.1,
                           [0.06, 0.05, 0.04, 0.03, 0.02], [1, 0.8, 0.6, 0.4, 0.3]) * 0.05
    whine = motorino(rng, n, f_giri * 12.0) * 0.025
    out = hum + pale + acqua * carico + rombo * carico + sub * carico + vibra + whine
    return f32(out)


def pompe_ruggito_loop(rng, dur=4.0):
    n = n_of(dur + 0.5)
    x = pompa_strati(rng, n, GIRI, 1.0)
    x = hp(x, 22, 2)
    return make_loop(x, dur, 0.5)


def pompa_avvio(rng):
    """Contattore che scatta, motore che prende giri in 2,5 s, l'acqua che arriva."""
    dur = 3.4
    n = n_of(dur)
    t = t_axis(n)
    giri = GIRI * (1 - np.exp(-np.maximum(t - 0.05, 0) / 0.8)) ** 1.4
    carico = np.clip((t - 0.6) / 1.8, 0, 1) ** 1.5
    x = pompa_strati(rng, n, np.maximum(giri, 0.5), 1.0)
    x *= np.clip(t / 0.08, 0, 1) * (0.25 + 0.75 * carico) + 0.0
    clack = resonator_bank(impulso(0.3), [140, 330, 760, 1900], [0.12, 0.09, 0.05, 0.03], [1, 0.8, 0.5, 0.3])
    mix_into(x, clack * 1.4, 0)
    thump = lp(white(n_of(0.15), rng), 160) * env_ad(n_of(0.15), 0.004, 0.12) * 1.2
    mix_into(x, thump, n_of(0.01))
    return fade(hp(x, 22, 2), 0.0, 0.6)


# --- blackout -------------------------------------------------------------------------------

def corrente_salta(rng):
    dur = 5.5
    n = n_of(dur)
    t = t_axis(n)
    out = np.zeros(n)
    # gli interruttori del quadro generale che saltano (uno grosso, due piccoli dopo)
    for t0, g, f in [(0.0, 1.4, 1.0), (0.09, 0.6, 1.25), (0.21, 0.45, 0.85)]:
        cl = resonator_bank(impulso(0.4), np.array([120, 290, 640, 1500, 3200]) * f,
                            [0.15, 0.1, 0.07, 0.04, 0.02], [1, 0.8, 0.6, 0.35, 0.2])
        mix_into(out, cl * g, n_of(t0))
    # l'arco: un attimo di scarica sporca
    k = n_of(0.18)
    arco = np.tanh(ronzio_rete(rng, k, 100.0, 40, 0.5, 1.2) * 3) * env_ad(k, 0.001, 0.15) * 0.6
    mix_into(out, arco, 0)
    # il ronzio di tutta la nave (luci, trasformatori) che muore calando di tono
    k = n_of(3.2)
    tk = t_axis(k)
    f = 100.0 * np.exp(-tk / 1.1) + 28.0 * (1 - np.exp(-tk / 1.1))
    ph = np.cumsum(f) / SR
    ronz = np.zeros(k)
    for h, a in [(1, 1.0), (2, 0.6), (3, 0.4), (4, 0.25), (6, 0.12), (8, 0.06)]:
        ronz += a * np.sin(2 * np.pi * h * ph)
    ronz *= env_points([(0, 1.0), (0.4, 0.8), (2.0, 0.25), (3.2, 0.0)], k) * 0.35
    mix_into(out, ronz, n_of(0.02))
    # relè lontani che si aprono a catena
    for j in range(7):
        t0 = 0.35 + j * rng.uniform(0.12, 0.3)
        r = resonator_bank(impulso(0.08), rng.uniform(0.8, 1.3) * np.array([900, 2100, 3700]),
                           [0.03, 0.02, 0.01], [1, 0.6, 0.3])
        mix_into(out, lp(r, 3000) * 0.15 * (1 - j * 0.1), n_of(t0))
    st = reverb(out, ir_nave(seed=31), wet=0.45, dry=0.9, tail=False)
    return fade(hp(st, 25, 2), 0.0, 1.5)


# --- monitor --------------------------------------------------------------------------------

def crt_neve_loop(rng, dur=3.0):
    n = n_of(dur + 0.4)
    t = t_axis(n)
    neve = bp(white(n, rng), 250, 11000, 2)
    neve = biquad(neve, 'peak', 4200, 0.8, 4)
    # sfarfallio del quadro (50 semiquadri al secondo) e righe sporche
    neve *= 0.9 + 0.1 * np.sign(np.sin(2 * np.pi * 50.0 * t))
    neve *= 0.85 + 0.15 * smooth_noise(n, 9, rng)
    # crepitii del tubo
    cr = resonator_bank(treno_impulsi(n, 18, rng), [2400, 5300], [0.003, 0.002], [1, 0.6]) * 0.25
    # fischio del trasformatore di riga (15 625 Hz) e ronzio della deflessione
    fischio = np.sin(2 * np.pi * 15625.0 * t) * 0.02
    hum = (np.sin(2 * np.pi * 50.0 * t) * 0.6 + np.sin(2 * np.pi * 100.0 * t) * 0.4) * 0.03
    out = neve * 0.3 + cr + fischio + hum
    return make_loop(out, dur, 0.4)


# --- lontano: plastica e tonfo ------------------------------------------------------------------

def scricchiolio_plastica(rng, dur, f_scala=1.0):
    """Plastica grande sotto sforzo: cigolii ad attrito che scivolano di tono (modi molto
    smorzati: la plastica non suona come il metallo) e il crepitio fitto delle microfratture."""
    n = n_of(dur)
    sforzo = np.clip(smooth_noise(n, 0.7, rng, 2) * 0.6 + 0.5, 0, 1) ** 1.3
    sforzo *= env_points([(0, 0), (dur * 0.15, 1), (dur * 0.8, 0.9), (dur, 0)], n)
    # cigolio: attrito a scatti da 70 a 420 Hz, a raffiche
    raffiche = np.clip(smooth_noise(n, 2.2, rng) + 0.2, 0, 1) ** 0.7
    rate = (70 + 350 * sforzo * (0.6 + 0.4 * smooth_noise(n, 1.5, rng))) * f_scala
    ph = np.cumsum(rate / SR) + 0.08 * smooth_noise(n, 40, rng)
    exc = (np.diff(np.floor(ph), prepend=0) > 0) * rng.uniform(0.5, 1.0, n) * sforzo * raffiche
    modi = np.array([310, 620, 1050, 1700, 2600]) * f_scala * rng.uniform(0.9, 1.1)
    cig = resonator_bank(exc, modi, [0.03, 0.025, 0.02, 0.015, 0.01], [1, 0.8, 0.55, 0.35, 0.2])
    # crepitio: impulsi fitti dove lo sforzo è alto
    crep = treno_impulsi(n, 260, rng, alpha=2.0) * sforzo ** 2.5
    crep = resonator_bank(crep, [1500, 2600, 4200], [0.004, 0.003, 0.002], [1, 0.7, 0.4]) * 0.5
    return f32(cig + crep)


def plastica_piega_lontano(rng):
    dur = 9.0
    n = n_of(dur + 3.0)
    out = np.zeros(n)
    # tre ondate di piegatura, sempre più grandi
    for t0, d, g, fs in [(0.0, 2.6, 0.5, 1.15), (2.2, 3.0, 0.8, 1.0), (5.0, 3.6, 1.0, 0.85)]:
        mix_into(out, scricchiolio_plastica(rng, d, fs) * g, n_of(t0))
    # schiocchi del guscio che si imbozza (bassi, di plastica)
    for t0 in [1.7, 4.6, 7.9]:
        po = resonator_bank(impulso(0.6), np.array([58, 96, 151, 240]) * rng.uniform(0.9, 1.1),
                            [0.35, 0.28, 0.2, 0.12], [1, 0.7, 0.45, 0.25])
        mix_into(out, po * 0.9, n_of(t0 + rng.uniform(-0.1, 0.1)))
    # un gemito sotto: la stessa bambola che si tende tutta
    mix_into(out, norm(gemito_attrito(rng, 6.0)) * 0.12, n_of(2.5))
    out = lp(hp(out, 35, 2), 2600, 2)
    st = reverb(out, ir_nave(seed=37), wet=0.85, dry=0.35, tail=False)
    return fade(st, 0.05, 2.0)


def tonfo_acqua_lontano(rng):
    dur = 6.0
    n = n_of(dur)
    out = np.zeros(n)
    k = n_of(1.2)
    whump = lp(white(k, rng), 220, 3) * env_ad(k, 0.008, 1.0) * 2.0
    mix_into(out, whump, 0)
    k = n_of(0.9)
    spl = bp(white(k, rng), 200, 3500, 2) * env_points([(0, 0), (0.015, 1), (0.25, 0.4), (0.9, 0)], k)
    mix_into(out, spl * 0.8, n_of(0.01))
    # la cavità d'aria che si richiude: una bolla grossa e grave
    mix_into(out, bollicina(rng, 75, 0.25, rise=0.15, dur=1.0) * 0.9, n_of(0.18))
    for _ in range(25):
        b = bollicina(rng, rng.uniform(150, 900), rng.uniform(0.02, 0.07), rise=0.3)
        mix_into(out, b * rng.uniform(0.05, 0.2), n_of(rng.uniform(0.2, 1.6)))
    # l'acqua che ricade e l'onda che sbatte contro i bordi
    k = n_of(2.5)
    onda = lp(white(k, rng), 900, 2) * env_points([(0, 0), (0.6, 1), (2.5, 0)], k) * 0.35
    mix_into(out, onda, n_of(0.9))
    out = lp(hp(out, 25, 2), 2200, 2)
    st = reverb(out, ir_nave(seed=41), wet=0.8, dry=0.45, tail=False)
    return fade(st, 0.0, 1.5)


# --- paratia ---------------------------------------------------------------------------------

def paratia_scende_loop(rng, dur=3.0):
    n = n_of(dur + 0.5)
    t = t_axis(n)
    mot = motorino(rng, n, np.full(n, 96.0), 0.6) * 0.3
    mot += ronzio_rete(rng, n, 100.0, 10, 1.0, 0.02) * 0.08
    # catena sulla ruota dentata: maglie a 9 al secondo, ogni 4 una più pesante
    catena = np.zeros(n)
    k = 0
    tt = 0.0
    while tt < dur + 0.5:
        fr = np.array([1250, 2300, 3600, 5200]) * rng.uniform(0.9, 1.15)
        g = 1.0 if k % 4 == 0 else rng.uniform(0.35, 0.6)
        m = resonator_bank(impulso(0.15), fr, [0.03, 0.025, 0.018, 0.012], [1, 0.7, 0.5, 0.3]) * g
        if k % 4 == 0:
            m = m + resonator_bank(impulso(0.15), [210, 380], [0.08, 0.06], [1, 0.6]) * 0.6
        mix_into(catena, m, n_of(tt))
        tt += 1 / 9.0 + rng.uniform(-0.008, 0.008)
        k += 1
    # la lastra che striscia nelle guide
    stride = tv_biquad(white(n, rng), 'bandpass', 900 + 400 * smooth_noise(n, 1.2, rng), 3)
    stride *= (0.5 + 0.5 * np.clip(smooth_noise(n, 3, rng) + 0.3, 0, 1)) * 0.12
    rombo = lp(colored(n, rng, -6.0, fmin=25.0), 130, 2) * 0.35
    out = mot * 0.6 + catena * 0.8 + stride + rombo
    return make_loop(hp(out, 25, 2), dur, 0.5)


# --- porta del ponte --------------------------------------------------------------------------

def maniglione(rng, sblocca: bool):
    """Spinta sul maniglione: la barra che corre, lo scrocco che sbatte (o rientra)."""
    out = np.zeros(n_of(0.9))
    barra = resonator_bank(impulso(0.1), [700, 1650, 3100], [0.03, 0.02, 0.012], [1, 0.6, 0.35])
    mix_into(out, barra * 0.6, 0)
    k = n_of(0.07)
    scorre = bp(white(k, rng), 1200, 6000, 2) * env_points([(0, 0), (0.01, 1), (0.07, 0)], k) * 0.25
    mix_into(out, scorre, n_of(0.01))
    latch = norm(kenney('metalLatch.ogg'))
    latch = lp(pitch(latch, -3 if sblocca else -6), 6000)
    mix_into(out, latch * (0.7 if sblocca else 0.5), n_of(0.06))
    if not sblocca:
        # la porta sbatte contro la battuta, due volte, e la barra torna su
        colpo = norm(kenney('impactMetal_heavy_00%d.ogg' % rng.integers(0, 5)))
        colpo = lp(pitch(colpo, -4), 3000)
        mix_into(out, colpo * 0.8, n_of(0.08))
        mix_into(out, colpo * 0.35, n_of(0.21))
        rit = resonator_bank(impulso(0.08), [820, 1900], [0.02, 0.012], [1, 0.5]) * 0.4
        mix_into(out, rit, n_of(0.42))
    return out


def maniglione_bloccato(rng):
    out = maniglione(rng, False)
    out = out + 0.3 * resonator_bank(out, [97, 163, 251], [0.4, 0.3, 0.2], [1, 0.7, 0.5])
    return fade(lp(out, 8000), 0.0, 0.1)


def porta_ponte_apre(rng):
    """Si sblocca e la porta d'acciaio si apre in 1,4 s: cardini che cigolano, aria, fermo."""
    dur = 3.4
    out = np.zeros(n_of(dur))
    mix_into(out, maniglione(rng, True)[:n_of(0.5)], 0)
    cig = norm(cigolio_metallo(rng, 1.6, 1, 2.4))
    mix_into(out, cig * 0.45, n_of(0.3))
    k = n_of(1.5)
    aria = lp(white(k, rng), 500, 2) * env_points([(0, 0), (0.5, 1), (1.5, 0)], k) * 0.25
    mix_into(out, aria, n_of(0.35))
    fermo = norm(kenney('doorClose_%d.ogg' % (1 + rng.integers(0, 4))))
    fermo = lp(pitch(fermo, -5), 2500) * 0.35
    mix_into(out, fermo, n_of(1.8))
    out = out + 0.25 * resonator_bank(out, [88, 141, 230], [0.5, 0.4, 0.3], [1, 0.7, 0.5])
    return fade(out, 0.0, 0.4)


def main():
    rng = np.random.default_rng(2006)
    print('Tecnici')
    salva(CART, 'pompe_ruggito_loop', pompe_ruggito_loop(rng), loudness=-18, qualita=4,
          nota='una pompa a pieno regime, ruggito basso; tre pompe = tre loop')
    salva(CART, 'pompa_avvio', pompa_avvio(rng), loudness=-16, corto=True, qualita=4)
    salva(CART, 'corrente_salta', corrente_salta(rng), loudness=-15, corto=True, qualita=4)
    salva(CART, 'crt_neve_loop', crt_neve_loop(rng), loudness=-22, qualita=4,
          nota='la neve di un televisore senza segnale: si sente anche col ruggito delle pompe')
    salva(CART, 'plastica_piega_lontano', plastica_piega_lontano(rng), loudness=-18, qualita=4,
          nota='si deve sentire sotto il ruggito delle pompe (che lascia liberi i medi)')
    salva(CART, 'tonfo_acqua_lontano', tonfo_acqua_lontano(rng), loudness=-16, corto=True, qualita=4)
    salva(CART, 'paratia_scende_loop', paratia_scende_loop(rng), loudness=-19, qualita=4)
    salva(CART, 'maniglione_bloccato', maniglione_bloccato(rng), loudness=-16, corto=True, qualita=3,
          fonte='Kenney RPG Audio + Impact Sounds (CC0) + sintesi', nota='metalLatch, impactMetal_heavy')
    salva(CART, 'porta_ponte_apre', porta_ponte_apre(rng), loudness=-16, corto=True, qualita=3,
          fonte='Kenney RPG Audio (CC0) + sintesi', nota='metalLatch, creak, doorClose')


if __name__ == '__main__':
    main()
