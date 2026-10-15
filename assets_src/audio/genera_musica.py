"""La sigla della mascotte di Splash Lagoon e gli stinger.

- sigla_pulita: carillon e organetto da acquapark anni '90, allegra, 120 BPM (per il titolo).
- sigla_rovinata: la stessa musica dal vecchio altoparlante del piedistallo: rallentata
  a 0,8 (nastro: 96 BPM, circa 4 semitoni più grave), wow e flutter, denti del carillon
  storti o mancanti, accordi che scivolano nel minore, distorsione, fruscio e crepitii,
  riverbero della sala. Alla fine il meccanismo si scarica e si ferma.
  96 BPM = 1,6 battiti al secondo, come la pulsazione della campana (MedusaStatue.pulse_rate):
  il primo battito è a PRIMO_BATTITO secondi dall'inizio del file.
- stinger: morte, bambini sulla balconata, Polaroid raccolta.
Melodia e arrangiamento sono originali (scritti qui).
Uscita: godot/audio/musica/.
"""
import numpy as np

from comune import ir_piccola, ir_sala, salva
from genera_ambiente import bollicina
from genera_effetti import gemito_attrito
from lib_audio import (SR, biquad, bitcrush, bp, brown, env_ad, env_points, eq, f32, fade, hp, lp, mix_into,
                       mono, n_of, pan, pink, resonator_bank, reverb, smooth_noise, stereo, t_axis, varispeed,
                       white, widen)

CART = 'musica'
BPM = 120.0
BEAT = 60.0 / BPM
PRIMO_BATTITO = 0.05      # secondi di silenzio prima del primo battito nella versione rovinata

# --- spartito (battiti da 0; 4 battiti per battuta) ------------------------------------------

E5, G5, C6, B5, A5, C5, D5, F5, B4, D6, E6, F6, G6, C7 = 76, 79, 84, 83, 81, 72, 74, 77, 71, 86, 88, 89, 91, 96

FRASE_A_1_6 = [
    # battuta 1 (Do)
    (0, E5, .5), (.5, G5, .5), (1, C6, 1), (2, B5, .5), (2.5, A5, .5), (3, G5, 1),
    # battuta 2 (Lam, Sol)
    (4, A5, .5), (4.5, G5, .5), (5, E5, .5), (5.5, C5, .5), (6, D5, 1), (7, E5, 1),
    # battuta 3 (Fa)
    (8, F5, .5), (8.5, A5, .5), (9, C6, 1), (10, A5, .5), (10.5, G5, .5), (11, F5, 1),
    # battuta 4 (Do)
    (12, E5, 1), (13, G5, 1), (14, C5, 2),
    # battuta 5 (Rem)
    (16, D5, .5), (16.5, F5, .5), (17, A5, 1), (18, G5, .5), (18.5, F5, .5), (19, D5, 1),
    # battuta 6 (Sol7)
    (20, B4, .5), (20.5, D5, .5), (21, G5, 1), (22, F5, .5), (22.5, E5, .5), (23, D5, 1),
]
FINE_A = [  # battute 7-8: sospesa sulla dominante
    (24, E5, .5), (24.5, G5, .5), (25, C6, .5), (25.5, E6, .5), (26, D6, 1), (27, C6, 1),
    (28, B5, .5), (28.5, C6, .5), (29, D6, .5), (29.5, B5, .5), (30, G5, 2),
]
FINE_A2 = [  # battute 15-16: cadenza finale
    (24, E5, .5), (24.5, G5, .5), (25, C6, .5), (25.5, E6, .5), (26, F6, 1), (27, E6, .5), (27.5, D6, .5),
    (28, D6, .5), (28.5, B5, .5), (29, G5, .5), (29.5, B5, .5), (30, C6, 2),
]
# accordi: (battito, nome) ogni mezza battuta
ACC_A = ['C', 'C', 'Am', 'G', 'F', 'F', 'C', 'C', 'Dm', 'Dm', 'G7', 'G7', 'C', 'Am', 'G7', 'G7']
ACC_A2 = ACC_A[:12] + ['C', 'F', 'G7', 'C']
ACCORDI = {
    'C': [60, 64, 67], 'Am': [57, 60, 64], 'G': [55, 59, 62], 'G7': [55, 59, 62, 65], 'F': [57, 60, 65],
    'Dm': [57, 62, 65], 'Cm': [60, 63, 67], 'Fm': [56, 60, 65], 'Ab': [56, 60, 63], 'Ddim': [56, 62, 65],
}
# basso: fondamentale sul battito 1, quinta sul battito 3
BASSI = {'C': (36, 43), 'Am': (45, 40), 'G': (43, 38), 'G7': (43, 38), 'F': (41, 36), 'Dm': (38, 45),
         'Cm': (36, 43), 'Fm': (41, 36), 'Ab': (44, 39), 'Ddim': (38, 44)}
# versione rovinata: dalla quinta battuta la sigla scivola in Do minore
MINORE_ACC = {'C': 'Cm', 'F': 'Fm', 'Am': 'Ab', 'Dm': 'Ddim', 'G': 'G', 'G7': 'G7'}
INIZIO_MINORE = 4 + 16    # battito (con l'intro) da cui si passa al minore


def minore(m):
    """Mi -> Mi bemolle, La -> La bemolle (Do minore armonico: il Si resta naturale)."""
    return m - 1 if m % 12 in (4, 9) else m


def hz(m, cents=0.0):
    return 440.0 * 2 ** ((m - 69 + cents / 100.0) / 12.0)


# --- strumenti ---------------------------------------------------------------------------------

def carillon(rng, f, vel=1.0, rotto=0.0):
    """Nota di carillon: lamella pizzicata, poche parziali (una inarmonica) e lo scatto del perno."""
    dec = 2.4 * (523.0 / f) ** 0.6
    dur = min(dec * 1.2, 3.5)
    n = n_of(dur)
    t = t_axis(n)
    out = np.zeros(n)
    parz = [(1.0, 1.0, dec), (2.0, 0.28, dec * 0.45), (3.0, 0.08, dec * 0.25), (5.4, 0.22, 0.09),
            (8.93, 0.08, 0.04)]
    for r, a, d in parz:
        ff = f * r * (1 + rotto * rng.uniform(-0.02, 0.02) * (r > 1.5))
        if ff > SR * 0.45:
            continue
        out += a * np.sin(2 * np.pi * ff * t + rng.uniform(0, 6.28)) * 10 ** (-3 * t / d)
    out *= np.clip(t / 0.0015, 0, 1)
    k = n_of(0.004)
    pin = hp(white(k, rng), 3500) * env_ad(k, 0.0002, 0.003) * 0.25
    out[:k] += pin
    return f32(out * vel)


def organo(rng, f, dur, vel=1.0, vib_hz=6.2, vib=0.0025, sottile=False):
    """Organetto elettronico: tiranti 8', 4', 2 2/3', 2' con vibrato; attacco e rilascio brevi."""
    rel = 0.06
    n = n_of(dur + rel)
    t = t_axis(n)
    fm = f * (1 + vib * np.sin(2 * np.pi * vib_hz * t + rng.uniform(0, 6)))
    ph = 2 * np.pi * np.cumsum(fm) / SR
    regs = [(1, 1.0), (2, 0.55), (3, 0.3), (4, 0.25), (6, 0.1), (8, 0.06)] if not sottile else \
        [(1, 1.0), (2, 0.3), (4, 0.1)]
    out = np.zeros(n)
    for h, a in regs:
        if f * h < SR * 0.45:
            out += a * np.sin(h * ph)
    e = env_points([(0, 0), (0.008, 1), (dur, 0.85), (dur + rel, 0)], n)
    return f32(out * e * vel)


def basso(rng, f, dur, vel=1.0):
    n = n_of(dur + 0.05)
    t = t_axis(n)
    fm = f * (1 + 0.04 * np.exp(-t / 0.02))
    ph = 2 * np.pi * np.cumsum(fm) / SR
    out = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
    e = env_points([(0, 0), (0.006, 1), (dur * 0.5, 0.6), (dur, 0.3), (dur + 0.05, 0)], n)
    return f32(out * e * vel)


def cassa(rng, vel=1.0):
    n = n_of(0.3)
    t = t_axis(n)
    f = 50 + 90 * np.exp(-t / 0.03)
    return f32(np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(n, 0.002, 0.25) * vel)


def legnetto(rng, vel=1.0):
    e = np.zeros(n_of(0.15))
    e[0] = 1
    return resonator_bank(e, [880, 1980], [0.06, 0.03], [1, 0.4]) * vel


def maracas(rng, vel=1.0):
    k = n_of(0.06)
    return f32(hp(white(k, rng), 5000) * env_points([(0, 0), (0.01, 1), (0.06, 0)], k) * vel)


def bloop(rng, f0, f1, dur=0.12, vel=1.0):
    """Bolla da cartone animato: sinusoide che scivola (sale nella pulita, scende nella rovinata)."""
    n = n_of(dur)
    f = np.geomspace(f0, f1, n)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_points([(0, 0), (0.005, 1), (dur, 0)], n)
    return f32(x * vel)


# --- arrangiamento ------------------------------------------------------------------------------

def spartito(rovinata=False, rng=None):
    """Note della melodia (battito, midi, durata) e accordi per mezza battuta, con l'intro."""
    intro = 4.0
    mel = []
    acc = ['C', 'C']   # intro
    sezioni = [(FRASE_A_1_6 + FINE_A, ACC_A)]
    if not rovinata:
        sezioni.append((FRASE_A_1_6 + FINE_A2, ACC_A2))
    else:
        # seconda volta solo per metà: il meccanismo si scarica a metà frase
        sezioni.append((FRASE_A_1_6[:12], ['C', 'C', 'Am', 'G']))
    off = intro
    for note, accs in sezioni:
        for b, m, d in note:
            mel.append((off + b, m, d))
        acc += accs
        off += 32 if len(accs) == 16 else 8
    return mel, acc, off


def rendi(rng, rovinata=False):
    mel, acc, fine_b = spartito(rovinata, rng)
    coda_b = 4.0 if not rovinata else 6.0
    tot = (fine_b + coda_b) * BEAT + 4.0
    n = n_of(tot)
    box = np.zeros((n, 2))
    org = np.zeros((n, 2))
    bas = np.zeros(n)
    perc = np.zeros((n, 2))
    fx = np.zeros((n, 2))

    def at(b):
        return n_of(b * BEAT)

    # carillon (melodia), con un'eco all'ottava sopra nella seconda strofa pulita
    for b, m, d in mel:
        cents = rng.uniform(-3, 3)
        vel = rng.uniform(0.85, 1.0) * (1.1 if d >= 1 else 1.0)
        if rovinata and b >= INIZIO_MINORE:
            m = minore(m)
        if rovinata:
            if rng.random() < 0.08:
                continue          # dente rotto: la nota non suona
            if rng.random() < 0.35:
                cents += rng.choice([-1, 1]) * rng.uniform(25, 55)
        x = carillon(rng, hz(m, cents), vel, rotto=1.0 if rovinata else 0.0)
        mix_into(box, pan(x, 0.15), at(b))
        if rovinata and rng.random() < 0.12:   # nota fantasma un semitono sotto
            mix_into(box, pan(carillon(rng, hz(m - 1, rng.uniform(-20, 20)), 0.35, 1.0), -0.3), at(b) + n_of(0.03))
        if not rovinata and b >= 36 and d <= 0.5 and rng.random() < 0.5:
            mix_into(box, pan(carillon(rng, hz(m + 12), 0.25), 0.5), at(b))
    # organetto: basso "um" sui battiti 1 e 3, accordo "pa" sui 2 e 4
    for k, nome in enumerate(acc):
        b0 = k * 2.0
        if rovinata and b0 >= INIZIO_MINORE:
            nome = MINORE_ACC.get(nome, nome)
        r, q = BASSI[nome]
        # "um": basso sul primo battito di ogni mezza battuta (fondamentale e quinta alternate)
        mix_into(bas, basso(rng, hz(r if k % 2 == 0 else q), BEAT * 0.8, 0.9 if k % 2 == 0 else 0.75), at(b0))
        # "pa": accordo sul secondo battito, più un controtempo leggero
        vib = 0.0025 if not rovinata else 0.006
        vhz = 6.2 if not rovinata else 4.3
        for nn in ACCORDI[nome]:
            for bb, vv in ((b0 + 1.0, 0.22), (b0 + 1.5, 0.12)):
                x = organo(rng, hz(nn, rng.uniform(-4, 4) if rovinata else 0.0), BEAT * 0.35, vv, vhz, vib)
                mix_into(org, pan(x, -0.35), at(bb))
                mix_into(org, pan(x, 0.35) * 0.8, at(bb) + n_of(0.012))
    # raddoppio della melodia all'organo nella seconda strofa (pulita)
    if not rovinata:
        for b, m, d in mel:
            if b >= 36:
                mix_into(org, pan(organo(rng, hz(m - 12), d * BEAT * 0.9, 0.18, sottile=True), 0.0), at(b))
    # percussioni
    beats = int(fine_b)
    for b in range(4, beats):
        if not rovinata:
            if b % 2 == 0:
                mix_into(perc, stereo(cassa(rng, 0.5)), at(b))
            else:
                mix_into(perc, pan(legnetto(rng, 0.35), -0.4), at(b))
            for h in (0, 0.5):
                mix_into(perc, pan(maracas(rng, 0.12 if h else 0.07), 0.45), at(b + h))
        elif b % 4 == 0:
            mix_into(perc, stereo(lp(cassa(rng, 0.45), 150)), at(b))   # solo un tonfo sordo
    # bolle d'acqua a fine frase
    for b in [4 + 14, 4 + 30, 4 + 32 + 14]:
        if b < beats:
            for j in range(3):
                f0, f1 = (500 + j * 150, 1400 + j * 300) if not rovinata else (900 - j * 120, 260 - j * 40)
                mix_into(fx, pan(bloop(rng, f0, f1, 0.11, 0.35), rng.uniform(-0.6, 0.6)), at(b + 1 + j * 0.25))
    # intro: arpeggio di carillon in levare
    for j, m in enumerate([C5 + 12, E5 + 12, G5 + 12]):
        mix_into(box, pan(carillon(rng, hz(m), 0.5), 0.4), at(1.5 + j * 0.5))
    # finale pulito: "ta-da" e scintillio
    if not rovinata:
        b = fine_b
        for nn in [60, 64, 67, 72]:
            mix_into(org, stereo(organo(rng, hz(nn), BEAT * 1.5, 0.3)), at(b))
        mix_into(bas, basso(rng, hz(36), BEAT * 1.5, 1.0), at(b))
        mix_into(perc, stereo(cassa(rng, 0.6)), at(b))
        for j, m in enumerate([G6, C7, G6 + 12]):
            mix_into(box, pan(carillon(rng, hz(m), 0.5), 0.2 * j), at(b + 0.25 * j))
        for j in range(4):
            mix_into(fx, pan(bloop(rng, 600 + 200 * j, 1800 + 300 * j, 0.1, 0.3), 0.5 - 0.3 * j), at(b + 0.5 + 0.2 * j))
    # mix
    box = eq(box, [('highpass', 220, 0.7, 0), ('peak', 1300, 0.8, 3)])
    org = lp(org, 5000, 2)
    mixl = box * 0.85 + org * 0.55 + stereo(lp(bas, 900)) * 0.4 + perc * 0.6 + fx * 0.5
    return f32(mixl), fine_b


def sigla_pulita(rng):
    x, _ = rendi(rng, False)
    x = reverb(x, ir_piccola(), wet=0.22, dry=1.0, tail=False)
    x = reverb(x, ir_sala(), wet=0.08, dry=1.0, tail=False)
    x = fade(x, 0, 1.5)
    # taglia il silenzio in fondo
    m = np.abs(mono(x))
    last = np.nonzero(m > 1e-3 * m.max())[0][-1]
    return fade(x[:last + n_of(0.3)], 0, 0.3)


def sigla_rovinata(rng):
    x, fine_b = rendi(rng, True)
    n = len(x)
    # nastro: 0,8 con wow e flutter; alla fine il meccanismo si scarica e si ferma
    t_src_fine = fine_b * BEAT                       # secondi nel tempo "pulito"
    n_out = int(n / 0.8) + n_of(4)
    t = t_axis(n_out)
    wow = 0.006 * np.sin(2 * np.pi * 0.55 * t) + 0.003 * smooth_noise(n_out, 0.9, rng)
    flutter = 0.0015 * np.sin(2 * np.pi * 7.3 * t)
    speed = 0.8 * (1 + wow + flutter)
    pos = np.cumsum(speed) / SR
    k = int(np.searchsorted(pos, t_src_fine - 0.6 * BEAT))
    tt = np.arange(n_out - k) / SR
    speed[k:] *= np.clip(1 - tt / 3.2, 0, 1) ** 1.6
    stop = k + n_of(3.2)
    y = varispeed(x, speed[:stop])
    y = y[:stop]
    m = len(y)
    # altoparlante rotto: banda stretta, saturazione, un po' di bitcrush
    y = bp(y, 260, 4800, 2)
    y = eq(y, [('peak', 1500, 1.0, 4), ('peak', 650, 2.0, -3)])
    y = np.tanh(y * 2.2) * 0.55
    y = bitcrush(y, 11, 2) * 0.6 + y * 0.4
    # vuoti di segnale (contatto difettoso)
    dip = 1 - 0.75 * np.clip(smooth_noise(m, 0.35, rng) - 0.55, 0, 1) * 3
    y *= np.clip(dip, 0.15, 1)[:, None]
    # crepitii, fruscio e ronzio dell'amplificatore, che si spegne col meccanismo
    rumori = np.zeros(m)
    idx = rng.integers(0, m, int(m / SR * 9))
    rumori[idx] = rng.uniform(-1, 1, len(idx))
    rumori = hp(rumori, 1200) * 0.35
    rumori += hp(white(m, rng), 2500) * 0.004
    rumori += np.sin(2 * np.pi * 100 * t_axis(m)) * 0.004
    rumori *= env_points([(0, 1), (m / SR - 0.6, 1), (m / SR, 0)], m)
    y += stereo(rumori)
    # l'altoparlante si spegne: un colpetto
    tunk = resonator_bank(np.r_[1.0, np.zeros(n_of(0.15))], [180, 420], [0.06, 0.04], [1, 0.5]) * 0.08
    y = np.concatenate([y, np.zeros((n_of(0.3), 2), dtype=np.float32)])
    mix_into(y, stereo(tunk), m)
    y = lp(y, 6000, 2)
    # nella sala: riverbero lungo
    y = reverb(y, ir_sala(seed=3), wet=0.55, dry=0.85, tail=True)
    # silenzio iniziale fisso: il primo battito cade a PRIMO_BATTITO
    y = np.concatenate([np.zeros((n_of(PRIMO_BATTITO), 2), dtype=np.float32), y])
    mm = np.abs(mono(y))
    last = np.nonzero(mm > 3e-3 * mm.max())[0][-1]
    return fade(y[:last + n_of(0.3)], 0, 1.0)


# --- stinger ---------------------------------------------------------------------------------

def stinger_morte(rng):
    dur = 7.5
    n = n_of(dur)
    out = np.zeros((n, 2))
    t = t_axis(n)
    # botto: sub che crolla e rumore saturato
    k = n_of(2.0)
    tk = t_axis(k)
    f = 38 + 70 * np.exp(-tk / 0.12)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(k, 0.003, 1.8)
    mix_into(out, stereo(boom * 0.9), 0)
    k = n_of(0.6)
    nz = np.tanh(bp(white(k, rng), 120, 6000, 2) * env_ad(k, 0.001, 0.5) * 4) * 0.35
    mix_into(out, widen(nz), 0)
    # stridio di lamiera che scende
    k = n_of(1.6)
    scr = gemito_attrito(rng, 1.6)
    scr = resonator_bank(scr, [1700, 2450, 3900, 5600], [0.4, 0.3, 0.2, 0.15], [1, 0.8, 0.5, 0.3]) * 0.3 + scr * 0.2
    scr = hp(scr, 600)
    mix_into(out, widen(scr / (np.abs(scr).max() + 1e-9) * 0.45, 17, 0.8), n_of(0.02))
    # il carillon della sigla che muore
    mel = [(0, E5), (0.5, G5), (1.0, C6), (2.0, B5), (2.5, A5), (3.0, G5)]
    k = n_of(4.5)
    box = np.zeros(k)
    for b, m in mel:
        mix_into(box, carillon(rng, hz(m, rng.uniform(-30, 30)), 0.8, 1.0), n_of(b * BEAT))
    sp = np.clip(0.8 * (1 - t_axis(n_of(5.0)) / 4.0), 0.05, 1) ** 1.3
    box = varispeed(box, sp)
    box = np.tanh(bp(box, 300, 4000, 2) * 2) * 0.4
    mix_into(out, pan(box, 0.2), n_of(0.6))
    # bordone dissonante che resta
    k = n_of(6.0)
    dr = organo(rng, hz(36), 5.5, 0.4, 3.0, 0.01) + organo(rng, hz(37), 5.5, 0.35, 3.3, 0.01)
    dr = lp(dr, 500) * env_points([(0, 0), (0.6, 1), (4.0, 0.7), (6.0, 0)], len(dr))
    mix_into(out, widen(dr * 0.5, 23, 0.7), n_of(0.5))
    out = reverb(out, ir_sala(seed=5), wet=0.5, dry=0.9, tail=False)
    return fade(out, 0, 1.5)


def stinger_bambini(rng):
    """I bambini sulla balconata: grappolo di carillon dissonante e un soffio che sale al contrario."""
    dur = 6.0
    n = n_of(dur)
    out = np.zeros((n, 2))
    # risucchio al contrario (riverbero rovesciato) che porta al colpo
    k = n_of(1.2)
    sw = bp(pink(k, rng), 300, 6000, 2) * env_points([(0, 0), (1.15, 1), (1.2, 0)], k) ** 2
    mix_into(out, widen(sw * 0.4), 0)
    for j, m in enumerate([C6, C6 + 1, G6, G6 + 1, E6 + 12]):
        x = carillon(rng, hz(m, rng.uniform(-20, 20)), 0.6, 1.0)
        mix_into(out, pan(x, -0.6 + 0.3 * j), n_of(1.2 + j * 0.035))
    k = n_of(4.5)
    dr = organo(rng, hz(84), 4.0, 0.12, 0.7, 0.012, sottile=True) + organo(rng, hz(85), 4.0, 0.1, 0.9, 0.012,
                                                                            sottile=True)
    mix_into(out, widen(hp(dr, 500) * env_points([(0, 0), (1.0, 1), (4.5, 0)], len(dr)) * 0.3), n_of(1.2))
    out = reverb(out, ir_sala(seed=9), wet=0.6, dry=0.8, tail=False)
    return fade(out, 0.02, 1.5)


def polaroid_raccolta(rng):
    """Foto presa in mano: il cartoncino che striscia e tre note storte del carillon."""
    dur = 2.6
    n = n_of(dur)
    out = np.zeros((n, 2))
    k = n_of(0.25)
    carta = bp(white(k, rng), 1800, 7000, 2) * env_points([(0, 0), (0.03, 1), (0.12, 0.5), (0.25, 0)], k)
    carta *= (0.5 + 0.5 * (rng.random(k) > 0.7))
    mix_into(out, stereo(carta * 0.35), 0)
    for j, m in enumerate([E5 + 12, G5 + 12, C6 + 12]):
        x = carillon(rng, hz(m, rng.uniform(-25, 25) - 30), 0.55, 1.0)
        mix_into(out, pan(x, -0.2 + 0.2 * j), n_of(0.12 + j * 0.32))
    out = reverb(out, ir_sala(seed=13), wet=0.35, dry=0.9, tail=False)
    return fade(out, 0, 0.6)


def polaroid_chiudi(rng):
    k = n_of(0.3)
    carta = bp(white(k, rng), 1500, 6500, 2) * env_points([(0, 0), (0.05, 1), (0.3, 0)], k)
    carta *= (0.4 + 0.6 * (rng.random(k) > 0.6))
    return fade(f32(carta), 0, 0.05)


def main():
    rng = np.random.default_rng(1994)
    print('Musica')
    salva(CART, 'sigla_pulita', sigla_pulita(rng), loudness=-16, qualita=6,
          nota='melodia e arrangiamento originali; carillon, organetto, percussioni giocattolo')
    salva(CART, 'sigla_rovinata', sigla_rovinata(rng), loudness=-17, qualita=5,
          nota=f'96 BPM, primo battito a {PRIMO_BATTITO} s')
    salva(CART, 'stinger_morte', stinger_morte(rng), loudness=-14, qualita=5)
    salva(CART, 'stinger_bambini', stinger_bambini(rng), loudness=-20, qualita=5)
    salva(CART, 'polaroid_raccolta', polaroid_raccolta(rng), loudness=-20, corto=True, qualita=4)
    salva(CART, 'polaroid_chiudi', polaroid_chiudi(rng), loudness=-26, corto=True, qualita=3)


if __name__ == '__main__':
    main()
