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
- cancello_stagno_apre (2 varianti, stessi tempi): i cancelli stagni della camera delle onde che
  si aprono da soli al passaggio (prova della v0.3.1, 16 ottobre): la valvola pilota, quattro
  chiavistelli che si sfilano con colpi secchi, la guarnizione che si stacca e l'aria che si
  sfoga, la porta d'acciaio che parte con uno strappo a 0,55 s spinta dall'idraulica (centralina,
  cilindro), stride e gratta nelle guide e rimbomba nel corridoio, sbatte a fine corsa a 2,55 s;
  poi i fermi che scattano e l'ultimo sfiato. Solo sintesi.
Uscita: godot/audio/tecnici/.
"""
import numpy as np

from comune import ir_nave, kenney, salva
from genera_ambiente import MODI_LAMIERA, bollicina, gemito_attrito, treno_impulsi
from genera_effetti import cigolio_metallo, impulso, ronzio_rete
from genera_giocatore import motorino, norm
from lib_audio import (SR, biquad, bp, colored, comb, db, env_ad, env_points, f32, fade, hp, lp, lufs,
                       lufs_max, make_ir, make_loop, mix_into, n_of, pitch, resonator_bank, reverb, smooth_noise,
                       t_axis, tv_biquad, white)

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


# --- cancelli stagni della camera delle onde ------------------------------------------------------

# Tempi di cancello_stagno_apre (s dall'inizio del suono): la porta comincia a muoversi con uno
# strappo e sbatte a fine corsa. L'animazione deve seguirli (CANCELLO_STAGNO_PARTE e
# CANCELLO_STAGNO_ARRIVA in audio.gd).
CANCELLO_PARTE = 0.55
CANCELLO_ARRIVA = 2.55
CANCELLO_DURATA = 3.7
MODI_LASTRA = np.array(MODI_LAMIERA) * 0.6      # una porta stagna spessa: modi bassi

# Livelli dei pezzi in dB rispetto al colpo finale: LUFS massimi su 100 ms per i colpi, LUFS
# integrati durante la corsa per i pezzi continui (corsa, centralina, stridio).
LIVELLI_CANCELLO = {
    'valvola': -14.0,
    'chiavistelli': (-3.5, -4.5, -4.0, -2.5),
    'guarnizione': -9.0,
    'sfiato': -5.0,
    'strappo': -6.0,            # il primo scossone; i tre dopo calano di 2,5 dB l'uno
    'giunto': -11.0,
    'corsa': -9.0,              # rombo, lastra, cilindro e raschio
    'centralina': -14.0,
    'stridio': -13.0,
    'colpo': 0.0,
    'fermi': (-9.0, -10.0),
    'sfiato_fine': -15.0,
}


def _rms(x, r):
    """Valore efficace r."""
    return f32(x * (r / (float(np.sqrt(np.mean(np.square(x)))) + 1e-12)))


def _a_livello(x, l):
    """Porta x alla loudness massima l (LUFS su finestre di 100 ms): i pezzi del cancello si
    dosano fra loro in dB relativi (LIVELLI_CANCELLO), poi salva() normalizza il tutto."""
    return f32(x * db(l - lufs_max(x)))


def _a_livello_medio(x, l, dove):
    """Porta x alla loudness integrata l nel tratto dove (uno slice): per i pezzi continui,
    così le varianti restano uguali anche se gli scatti cadono in modo diverso."""
    return f32(x * db(l - lufs(x[dove])))


def _morbido(x, k):
    """Saturazione morbida a picco invariato: colpi più densi e pieni, con meno picchi."""
    p = float(np.abs(x).max()) + 1e-12
    return f32(np.tanh(x / p * k) / np.tanh(k) * p)


def _mezzo_seno(ms, n_s=0.4):
    """Eccitazione a mezzo seno lunga ms millisecondi: più è lunga, più il colpo è sordo."""
    e = np.zeros(n_of(n_s))
    k = max(2, int(ms * 1e-3 * SR))
    e[:k] = np.sin(np.pi * np.arange(k) / k)
    return e


def _tonfo(f_da, f_a, dur, decay):
    """Un botto basso che cala di tono."""
    k = n_of(dur)
    f = env_points([(0, f_da), (dur, f_a)], k)
    return f32(np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(k, 0.0015, decay))


def _schianto(rng, dur, lo, hi, decay):
    """Il rumore dell'urto: breve e a banda larga, dà corpo e forza a un colpo."""
    k = n_of(dur)
    return f32(norm(bp(white(k, rng), lo, hi, 2)) * env_ad(k, 0.0004, decay))


def chiavistello(rng, tono=1.0):
    """Un chiavistello d'acciaio che si sfila: lo scatto della leva, il catenaccio che corre nella
    guida e il colpo secco a fine corsa ("ka-ciunk"), che fa suonare un poco anche la porta."""
    out = np.zeros(n_of(0.45))
    ka = resonator_bank(_mezzo_seno(0.25, 0.1), tono * rng.uniform(0.95, 1.05) * np.array([1900, 3400, 5200]),
                        [0.02, 0.012, 0.008], [1, 0.6, 0.3])
    mix_into(out, norm(ka) * 0.2, 0)
    corsa = rng.uniform(0.024, 0.036)
    k = n_of(corsa)
    raschio = bp(white(k, rng), 1500, 6000, 2) * env_points([(0, 0.2), (corsa * 0.6, 1), (corsa, 0.6)], k)
    mix_into(out, norm(raschio) * 0.1, n_of(0.002))
    c0 = n_of(corsa)
    exc = _mezzo_seno(0.5, 0.4)
    bullone = resonator_bank(exc, tono * rng.uniform(0.93, 1.07) * np.array([820, 1370, 2240, 3310, 4630]),
                             [0.09, 0.07, 0.05, 0.035, 0.02], [1, 0.8, 0.6, 0.4, 0.25])
    corpo = resonator_bank(exc, tono * rng.uniform(0.95, 1.05) * np.array([168, 254, 392, 575]),
                           [0.14, 0.11, 0.08, 0.06], [1, 0.8, 0.55, 0.35])
    mix_into(out, norm(bullone) * 0.5, c0)
    mix_into(out, norm(corpo) * 0.7, c0)
    mix_into(out, _tonfo(95 * tono, 62 * tono, 0.14, 0.11) * 0.55, c0)
    mix_into(out, _schianto(rng, 0.03, 500, 6000, 0.012) * 0.6, c0)
    return _morbido(out, 2.2)


def valvola_pilota(rng):
    """La valvola pilota dell'idraulica che scatta: il clic del solenoide e il colpo sordo dell'olio."""
    out = np.zeros(n_of(0.3))
    clic = resonator_bank(impulso(0.1), np.array([2600, 4100, 6900]) * rng.uniform(0.95, 1.05),
                          [0.012, 0.008, 0.005], [1, 0.6, 0.3])
    mix_into(out, norm(clic) * 0.3, 0)
    sol = resonator_bank(_mezzo_seno(0.8, 0.2), [310, 520, 870], [0.06, 0.05, 0.03], [1, 0.6, 0.3])
    mix_into(out, norm(sol) * 0.35, n_of(0.012))
    k = n_of(0.2)
    mix_into(out, norm(lp(white(k, rng), 300, 2) * env_ad(k, 0.002, 0.12)) * 0.4, n_of(0.012))
    return f32(out)


def sfiato_aria(rng, dur=0.6, f_da=5200, f_a=2600):
    """L'aria in pressione che si sfoga: un pssshh forte che parte di colpo e cala, col fischio
    cavo del tubo."""
    n = n_of(dur)
    e = env_points([(0, 0), (0.005, 1.0), (0.07, 0.75), (dur * 0.4, 0.3), (dur, 0)], n) ** 1.3
    turb = 1 + 0.18 * smooth_noise(n, 35, rng) + 0.08 * smooth_noise(n, 90, rng)
    alto = tv_biquad(white(n, rng), 'bandpass', env_points([(0, f_da), (dur, f_a)], n), 0.9)
    lucc = hp(white(n, rng), 6000, 2)
    basso = bp(colored(n, rng, -3.0), 350, 1400, 2) * env_points([(0, 1), (0.2, 0.3), (dur, 0)], n)
    x = (_rms(alto, 1) + _rms(lucc, 0.35) + _rms(basso, 0.55)) * e * turb
    return f32(x + comb(x, 1 / 1750.0, 0.35) * 0.25)


def guarnizione(rng):
    """La guarnizione di gomma che si stacca dal telaio: uno schiocco sordo, risucchiato."""
    k = n_of(0.1)
    x = tv_biquad(colored(k, rng, -3.0), 'bandpass', env_points([(0, 140), (0.1, 560)], k), 3.0)
    x = norm(x) * env_points([(0, 0), (0.008, 1), (0.1, 0)], k)
    out = np.zeros(n_of(0.12))
    mix_into(out, x * 0.7, 0)
    mix_into(out, _tonfo(80, 170, 0.07, 0.05) * 0.5, 0)
    return f32(out)


def centralina_idraulica(rng, n, giri, carico):
    """La centralina che spinge la porta: il motore elettrico che ronza, il fischio della pompa a
    ingranaggi (11 denti), l'olio che pulsa nei tubi. giri e carico da 0 a 1 (curve)."""
    giri = np.broadcast_to(np.asarray(giri, dtype=np.float64), (n,))
    carico = np.broadcast_to(np.asarray(carico, dtype=np.float64), (n,))
    f = 47.5 * giri * (1 - 0.07 * carico) * (1 + 0.004 * smooth_noise(n, 6, rng))
    ph = np.cumsum(f) / SR
    mot = np.zeros(n)
    for k, a in [(1, 0.3), (2, 0.6), (3, 0.45), (4, 0.4), (6, 0.25), (8, 0.15), (10, 0.08)]:
        mot += a * np.sin(2 * np.pi * k * ph + rng.uniform(0, 6))
    denti = np.sin(2 * np.pi * 11 * ph) + 0.35 * np.sin(2 * np.pi * 22 * ph + 0.7)
    denti *= 1 + 0.3 * np.sin(2 * np.pi * ph)
    olio = bp(white(n, rng), 300, 1800, 2) * (0.6 + 0.4 * smooth_noise(n, 13, rng))
    x = _rms(mot, 0.35) + _rms(denti, 0.2) * (0.5 + 0.5 * carico) + _rms(olio, 0.15) * (0.4 + 0.6 * carico)
    return f32(x * np.clip(giri * 1.5, 0, 1))


def _scatti(rng, n, rate):
    """Scatti d'attrito irregolari, circa rate al secondo."""
    ph = np.cumsum(np.full(n, rate) * (1 + 0.3 * smooth_noise(n, 3, rng)) / SR) + 0.05 * smooth_noise(n, 40, rng)
    return (np.diff(np.floor(ph), prepend=0) > 0) * rng.uniform(0.3, 1.0, n)


def stridio_guide(rng, n, forza, alto=1.0):
    """Acciaio che striscia nelle guide e stride: un modo della lastra che l'attrito innesca (un
    fischio metallico che trema e scivola un poco di tono), a tratti un altro più acuto, col
    raschio a scatti sotto. forza da 0 a 1 (curva)."""
    forza = np.broadcast_to(np.asarray(forza, dtype=np.float64), (n,))
    out = np.zeros(n)
    for f_m, g, primo in [(1240.0, 1.0, True), (1870.0, 0.55, False), (2630.0, 0.3, False)]:
        f = f_m * alto * rng.uniform(0.96, 1.04) * (1 + 0.012 * smooth_noise(n, 9, rng)
                                                     + 0.004 * smooth_noise(n, 55, rng))
        s = np.sin(2 * np.pi * np.cumsum(f) / SR)
        # il modo si innesca a tratti: chi prende il sopravvento cambia nel tempo
        quando = np.clip(smooth_noise(n, 2.4, rng) * 1.8 - 0.2 + (0.25 if primo else 0.0), 0, 1) ** 1.3
        trema = 0.65 + 0.35 * np.clip(smooth_noise(n, 17, rng) + 0.3, 0, 1)
        out += np.tanh(s * 1.8) * quando * trema * g
    raschio = resonator_bank(_scatti(rng, n, 150.0), np.array([610, 930, 1420, 2050]) * alto,
                             [0.03, 0.025, 0.02, 0.015], [1, 0.8, 0.6, 0.4])
    return f32((_rms(out, 1.0) + _rms(raschio, 0.5)) * forza)


def raschio_lastra(rng, n, vel):
    """La lastra che gratta nelle guide: fruscio ruvido sui medi (si sente anche dagli
    altoparlanti piccoli, dove il rombo non arriva)."""
    x = bp(white(n, rng), 280, 1600, 2)
    ruvido = 0.45 + 0.55 * np.clip(smooth_noise(n, 11, rng, 2) * 1.4 + 0.3, 0, 1)
    return f32(x * ruvido * vel)


def gemito_cilindro(rng, n, forza, tono=1.0):
    """Il cilindro idraulico e la porta sotto sforzo: attrito lento (30-50 scatti al secondo) sui
    modi bassi della lastra, un brontolio d'acciaio. forza da 0 a 1 (curva)."""
    rate = 38 + 14 * smooth_noise(n, 0.9, rng)
    ph = np.cumsum(rate / SR) + 0.1 * smooth_noise(n, 25, rng)
    exc = (np.diff(np.floor(ph), prepend=0) > 0) * rng.uniform(0.4, 1.0, n) * forza
    exc = exc + white(n, rng) * 0.015 * forza
    fr = MODI_LASTRA[:7] * tono * rng.uniform(0.92, 1.08)
    return resonator_bank(exc, fr, [0.5, 0.45, 0.4, 0.3, 0.25, 0.2, 0.15], 1 / (1 + np.arange(7) * 0.35))


def colpo_guida(rng):
    """La porta che passa su un giunto della guida, o lo strappo alla partenza: un colpo sordo."""
    out = np.zeros(n_of(0.5))
    c = resonator_bank(_mezzo_seno(1.5, 0.5), rng.uniform(0.9, 1.1) * np.array([120, 260, 480, 830, 1400]),
                       [0.14, 0.1, 0.07, 0.045, 0.025], [1, 0.75, 0.5, 0.3, 0.15])
    mix_into(out, norm(c) * 0.8, 0)
    mix_into(out, _tonfo(70, 50, 0.2, 0.16) * 0.6, 0)
    mix_into(out, _schianto(rng, 0.03, 200, 2500, 0.015) * 0.3, 0)
    return _morbido(out, 1.8)


def colpo_fine_corsa(rng, tono=1.0):
    """La porta che sbatte a fine corsa: il botto basso, lo schianto, la lastra spessa che suona,
    il clangore; due piccoli rimbalzi."""
    out = np.zeros(n_of(2.0))
    mix_into(out, _tonfo(62 * tono, 41 * tono, 0.6, 0.5) * 0.9, 0)
    k = n_of(0.3)
    mix_into(out, norm(lp(white(k, rng), 170, 3) * env_ad(k, 0.001, 0.2)) * 0.6, 0)
    mix_into(out, _schianto(rng, 0.08, 250, 5000, 0.03) * 0.8, 0)
    lastra = resonator_bank(_mezzo_seno(1.0, 2.0), MODI_LASTRA * tono * rng.uniform(0.97, 1.03),
                            np.linspace(1.5, 0.4, len(MODI_LASTRA)), 1 / (1 + np.arange(len(MODI_LASTRA)) * 0.25))
    mix_into(out, norm(lastra) * 0.75, 0)
    clang = resonator_bank(_mezzo_seno(0.35, 1.0),
                           tono * rng.uniform(0.96, 1.04) * np.array([690, 1130, 1720, 2480, 3350, 4620]),
                           [0.55, 0.45, 0.35, 0.25, 0.16, 0.1], [1, 0.8, 0.6, 0.45, 0.3, 0.2])
    mix_into(out, norm(clang) * 0.5, 0)
    for dt, g in [(0.085, 0.3), (0.15, 0.12)]:
        r = resonator_bank(_mezzo_seno(1.2, 0.8), MODI_LASTRA[2:8] * tono * rng.uniform(0.97, 1.03),
                           [0.5, 0.4, 0.3, 0.25, 0.2, 0.15], [1, 0.8, 0.6, 0.4, 0.3, 0.2])
        mix_into(out, norm(r) * g, n_of(dt))
        mix_into(out, _tonfo(55 * tono, 45 * tono, 0.2, 0.15) * g * 1.2, n_of(dt))
        mix_into(out, _schianto(rng, 0.03, 300, 4000, 0.012) * g * 0.8, n_of(dt))
    return _morbido(out, 2.5)


def cancello_stagno_apre(rng, tono=1.0):
    """Un cancello stagno d'acciaio, pesante, che si apre da solo: la valvola pilota, quattro
    chiavistelli che si sfilano, la guarnizione che si stacca e l'aria che si sfoga; la porta parte
    con uno strappo a CANCELLO_PARTE, spinta dall'idraulica, stride e gratta nelle guide e
    rimbomba nel corridoio, sbatte a fine corsa a CANCELLO_ARRIVA; i fermi che scattano, l'ultimo
    sfiato. tono < 1: una porta un po' più grave (la seconda variante). Mono, 3,7 s."""
    L = LIVELLI_CANCELLO
    dur = CANCELLO_DURATA
    n = n_of(dur)
    t = t_axis(n)
    out = np.zeros(n)
    # 1) la valvola pilota e i chiavistelli che si sfilano uno dopo l'altro
    mix_into(out, _a_livello(valvola_pilota(rng), L['valvola']), 0)
    tempi = [0.04, 0.13, 0.21, 0.32]
    tempi = [tempi[0]] + [x + rng.uniform(-0.01, 0.01) for x in tempi[1:]]
    for t0, l in zip(tempi, L['chiavistelli']):
        mix_into(out, _a_livello(chiavistello(rng, tono * rng.uniform(0.92, 1.08)), l), n_of(t0))
    # 2) la guarnizione che si stacca e l'aria che si sfoga
    T_SF = 0.37
    mix_into(out, _a_livello(guarnizione(rng), L['guarnizione']), n_of(T_SF - 0.01))
    mix_into(out, _a_livello(sfiato_aria(rng, 0.6), L['sfiato']), n_of(T_SF))
    # 3) la corsa: la velocità (0..1) parte con uno strappo, è piena da circa 0,4 s, cala del 20%
    # nell'ultimo quarto di secondo; il carico è massimo allo strappo
    tt = t - CANCELLO_PARTE
    D = CANCELLO_ARRIVA - CANCELLO_PARTE
    vel = np.clip(tt / 0.05, 0, 1) * 0.35 + np.clip((tt - 0.12) / 0.3, 0, 1) * 0.65
    vel *= 1 - 0.2 * np.clip((tt - (D - 0.25)) / 0.25, 0, 1)
    vel *= (tt >= 0) & (tt < D)
    vel = vel * (1 + 0.06 * smooth_noise(n, 4, rng))
    carico = np.clip(np.clip(1 - tt / 0.5, 0, 1) * (tt >= -0.05) + 0.35 * (tt >= 0) * (tt < D), 0, 1)
    giri = np.clip((t - 0.2) / 0.35, 0, 1) ** 1.5 * np.clip(1 - (t - CANCELLO_ARRIVA) / 0.45, 0, 1)
    in_corsa = slice(n_of(CANCELLO_PARTE), n_of(CANCELLO_ARRIVA))
    cent = centralina_idraulica(rng, n, giri, carico)
    mix_into(out, _a_livello_medio(cent, L['centralina'], in_corsa), 0)
    rombo = lp(colored(n, rng, -6.0, fmin=25.0), 200, 3) * vel * (0.75 + 0.25 * smooth_noise(n, 3, rng))
    ecc = lp(white(n, rng), 800, 2) * vel * 0.3 + rombo * 0.3
    lastra = resonator_bank(ecc, MODI_LASTRA[:8] * tono, [0.6, 0.6, 0.55, 0.5, 0.45, 0.4, 0.35, 0.3],
                            [1, 0.8, 0.6, 0.45, 0.3, 0.2, 0.12, 0.08])
    gem = gemito_cilindro(rng, n, vel * (0.5 + 0.8 * carico), tono)
    corsa = _rms(rombo, 1.0) + _rms(lastra, 0.7) + _rms(gem, 0.8) + _rms(raschio_lastra(rng, n, vel), 0.35)
    # sotto i 45 Hz non si sente quasi niente, ma toglierebbe spazio al colpo finale
    mix_into(out, _a_livello_medio(hp(corsa, 45, 2), L['corsa'], in_corsa), 0)
    forza = np.clip(smooth_noise(n, 2.2, rng) * 1.3 + 0.1, 0, 1) ** 1.5 * 0.35
    forza = forza + env_points([(0, 0), (CANCELLO_PARTE, 0), (CANCELLO_PARTE + 0.05, 1.0),
                                (CANCELLO_PARTE + 0.45, 0.5), (CANCELLO_PARTE + 0.9, 0.12), (dur, 0.12)], n)
    strid = stridio_guide(rng, n, vel * np.clip(forza, 0, 1), tono * tono)
    mix_into(out, _a_livello_medio(strid, L['stridio'], in_corsa), 0)
    # lo strappo alla partenza (quattro scossoni) e i giunti delle guide
    for j, dt in enumerate([0.0, 0.055, 0.105, 0.15]):
        mix_into(out, _a_livello(colpo_guida(rng), L['strappo'] - j * 2.5), n_of(CANCELLO_PARTE + dt))
    for tb in [1.05, 1.6, 2.12]:
        mix_into(out, _a_livello(colpo_guida(rng), L['giunto']), n_of(tb + rng.uniform(-0.04, 0.04)))
    # 4) il colpo a fine corsa, i fermi che scattano, lo sfiato della pressione
    mix_into(out, _a_livello(colpo_fine_corsa(rng, tono), L['colpo']), n_of(CANCELLO_ARRIVA))
    mix_into(out, _a_livello(chiavistello(rng, tono * 1.12), L['fermi'][0]), n_of(CANCELLO_ARRIVA + 0.2))
    mix_into(out, _a_livello(chiavistello(rng, tono * 1.05), L['fermi'][1]), n_of(CANCELLO_ARRIVA + 0.26))
    mix_into(out, _a_livello(sfiato_aria(rng, 0.35, 4200, 3000), L['sfiato_fine']), n_of(CANCELLO_ARRIVA + 0.33))
    # il corridoio: l'eco a pettine fra le pareti di metallo, una coda corta e scura, i modi bassi
    # che rimbombano (il riverbero lungo della sala lo aggiunge il bus Effetti)
    alti = hp(out, 300, 2)
    x = out + (comb(alti, 0.0125, 0.3) - alti) * 0.35
    ir = make_ir(rt60=1.3, predelay=0.006, hf_damp=0.45, early=18, early_span=0.05, brightness=6500,
                 lf_rt_mul=1.5, seed=61)
    x = reverb(x, ir, wet=0.28, dry=1.0, tail=False).mean(axis=1)
    bassi = lp(x, 200, 2)
    modi = resonator_bank(bassi, [43, 66, 91, 122], [1.1, 0.9, 0.7, 0.5], [1, 0.8, 0.6, 0.4])
    x = x + _rms(modi, float(np.sqrt(np.mean(np.square(bassi))))) * 0.5
    return fade(hp(f32(x), 25, 2), 0.0, 0.5)


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
    # i cancelli stagni della camera delle onde (16 ottobre): semi propri, così gli altri suoni
    # non cambiano; due varianti con gli stessi tempi (la seconda un po' più grave)
    for i, (seme, tono) in enumerate([(1610, 1.0), (2610, 0.94)]):
        salva(CART, f'cancello_stagno_apre_{i + 1:02d}', cancello_stagno_apre(np.random.default_rng(seme), tono),
              loudness=-12, corto=True, qualita=4,
              nota='cancello stagno che si apre da solo: si muove da 0,55 s e sbatte a 2,55 s')


if __name__ == '__main__':
    main()
