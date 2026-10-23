"""Suoni dell'inizio con il mostro-squalo (GDD, "L'inizio con il mostro-squalo"): il risveglio nel
corridoio con lo squalo addosso, il verso lontano di Jilly che lo chiama dalla porta tagliafuoco, lo
squalo che si gira, esita e scappa. I tempi sono quelli dell'animazione
(godot/assets/models/mascotte/mostro_squalo_A_rig.json, da assets_src/mascotte/mostro_anim.py).

- squalo_minaccia: dal risveglio al richiamo, attaccato alla bocca: il fiato pesante e umido a pochi
  centimetri dalla faccia, la gola che raschia e, a ogni scatto in avanti della testa, un ringhio corto
  con lo schiocco umido delle fauci (scatti a MINACCIA + 0,7, 1,6 e 2,5 s dell'animazione);
- jilly_richiamo: il verso di lei, lontano e profondo, che arriva da dietro la porta tagliafuoco. Dal 23 ottobre
  (l'utente: "il suono che si sente sotto è strano, corrotto e non si capisce cosa sia... doveva essere il
  richiamo di Jilly") è fatto con la sua voce B dell'inseguimento (genera_lei_inseguimento.grido(), con sopra
  piano la sua voce stridula): due chiamate lunghe che salgono e scendono, chiare (poco sporche) e lontane
  dietro la porta (il riverbero della nave, gli acuti appena tagliati). La prima versione (la gola a 30-47 Hz,
  sporcata e chiusa sotto 650 Hz: un brontolio che non si capiva) resta in jilly_richiamo_v1();
- squalo_sbuffo: lo sbuffo di gola quando si volta a guardarti prima di scappare;
- squalo_passo: i passi pesanti e bagnati sulle piastrelle, con il ticchettio degli artigli; dal 22 ottobre
  più pesanti (un tonfo grave lungo, sotto: la camera trema insieme);
- squalo_denti (22 ottobre): i denti che scattano a ogni morso nell'aria (i tre scatti della testa), secchi;
- squalo_ringhio (22 ottobre): il ringhio quando si gira verso la porta.
Riscontro dell'utente sulla v0.3.8 ("aggiungiamo anche i suoni"): il respiro nella minaccia è più presente
(più umido e più forte rispetto al brontolio). Ogni suono ha il suo seme: rifarne uno non cambia gli altri.
Uso: python genera_squalo.py [nomi dei suoni da rifare] (senza nomi, tutti).
La porta che sbatte usa il suono che c'è già (porta_chiusa, più grave). Tutti mono: nel gioco suonano
nello spazio (la bocca, la porta, i piedi).
Uscita: godot/audio/squalo/.
"""
import numpy as np

from comune import ir_nave, ir_piccola, salva
from genera_ambiente import bollicina, treno_impulsi
from genera_effetti import impulso
from genera_giocatore import tacco_piastrella, strato_bagnato
from genera_lei import gola, tratto, sporca, ringhio, respiro, rombo_sotto
from lib_audio import (SR, mono, bp, env_ad, env_points, f32, fade, hp, lp, mix_into, n_of, resonator_bank,
                       reverb, smooth_noise, white, pitch)

CART = 'squalo'
MINACCIA_INIZIO = 0.8          # quando parte nel gioco (secondi dell'animazione)
SCATTI = (2.4 + 0.7, 2.4 + 1.6, 2.4 + 2.5)   # MINACCIA + ... (mostro_anim.posa)
RICHIAMO = 5.4


def schiocco(rng):
    """Le fauci umide che si serrano a metà: saliva, uno schiocco sordo di denti."""
    k = n_of(0.25)
    out = np.zeros(k)
    sal = bp(white(k, rng), 900, 5000, 2) * env_points([(0, 0), (0.01, 1), (0.08, 0.3), (0.25, 0)], k)
    mix_into(out, sal * 0.25, 0)
    denti = resonator_bank(impulso(0.08), [420, 1150, 2300], [0.02, 0.012, 0.008], [1, 0.5, 0.3])
    mix_into(out, denti * 0.5, n_of(0.03))
    for _ in range(6):
        mix_into(out, bollicina(rng, rng.uniform(1200, 3200), rng.uniform(0.004, 0.01), rise=0.8)
                 * rng.uniform(0.05, 0.15), n_of(rng.uniform(0.0, 0.18)))
    return f32(out)


def squalo_minaccia(rng):
    dur = RICHIAMO - MINACCIA_INIZIO + 0.4
    out = np.zeros(n_of(dur))
    # il fiato: lento e profondo all'inizio, poi più corto e rabbioso con la bocca spalancata
    cicli = []
    t = 0.05
    while t < dur - 0.6:
        lungo = 1.2 if t < 1.4 else 0.85
        cicli.append((t, lungo * 0.45, 'insp', 0.55))
        cicli.append((t + lungo * 0.45, lungo * 0.55, 'esp', 1.0))
        t += lungo + rng.uniform(0.02, 0.12)
    # il respiro davanti a tutto: è la prima cosa che si sente svegliandosi (riscontro del 22 ottobre)
    mix_into(out, respiro(rng, dur, cicli, umido=2.2, rauco=0.6) * 1.5, 0)
    # sotto, la gola che brontola sempre
    mix_into(out, lp(ringhio(rng, dur, f0=(46.0, 52.0), sporco=2.0, rullo=18.0, sub=0.4), 900) * 0.28, 0)
    # i ringhi corti degli scatti
    for tc in SCATTI:
        r = ringhio(rng, 0.55, f0=(62.0, 48.0), sporco=3.5, rullo=26.0, bocca=1.3)
        r *= env_points([(0, 0), (0.04, 1), (0.3, 0.7), (0.55, 0)], len(r))
        mix_into(out, r * 0.9, n_of(tc - MINACCIA_INIZIO - 0.06))
        mix_into(out, schiocco(rng) * 0.8, n_of(tc - MINACCIA_INIZIO + 0.12))
    # da vicinissimo: un filo di stanza piccola, niente coda lunga
    return f32(fade(reverb(out, ir_piccola(), wet=0.12), 0.05, 0.3))


def jilly_richiamo(rng):
    """Il richiamo con la voce B di lei (l'inseguimento): due chiamate lunghe, la prima che sale e scende, la seconda
    più corta che ricade; sotto il petto (la subarmonica), sopra piano la sua voce stridula; lontana dietro la porta."""
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from genera_lei_inseguimento import grido, formanti, voce, _norm
    dur = 6.0
    n = n_of(dur)
    out = np.zeros(n)
    for t0, d, curva, forza in ((0.0, 2.7, [(0, 82), (0.5, 128), (1.3, 150), (2.0, 120), (2.7, 78)], 1.0),
                                (3.0, 1.9, [(0, 88), (0.4, 136), (1.1, 112), (1.9, 70)], 0.8)):
        k = n_of(d)
        g = grido(rng, d, curva, bocca=1.05, sporco=1.4, rullo=9.0)
        e = env_points([(0, 0), (d * 0.18, 1.0), (d * 0.7, 0.85), (d, 0)], k) ** 1.1
        mix_into(out, _norm(g) * e * forza, n_of(t0))
        # sopra, piano, la sua voce stridula (la stessa del suo urlo): la si riconosce
        f0 = env_points([(t, f * 2.6) for t, f in curva], k)
        st = formanti(voce(rng, k, f0, 1.0), 'a') * 0.7 + formanti(voce(rng, k, f0 * 1.01, 1.0), 'i') * 0.3
        mix_into(out, hp(lp(np.tanh(_norm(st) * 2.0), 5000, 2), 250, 2) * e * 0.16 * forza, n_of(t0))
    out += _norm(rombo_sotto(rng, dur, 0.25)) * 0.05
    # lontana: dietro la porta d'acciaio e lungo i corridoi di lamiera (acuti appena tagliati, non chiusi)
    out = lp(hp(out, 85, 4), 2400, 2)
    out = f32(reverb(out, ir_nave(), wet=0.6, dry=0.75))
    return f32(fade(out, 0.1, 1.2))


def jilly_richiamo_v1(rng):
    """(Scartata il 23 ottobre.) Il richiamo: due lunghi versi di gola che salgono e scendono, il secondo più corto."""
    dur = 5.2
    n = n_of(dur)
    voce = np.zeros(n)
    for t0, d, (fa, fb, fc), forza in ((0.0, 2.6, (30.0, 47.0, 33.0), 1.0), (2.9, 1.7, (34.0, 44.0, 28.0), 0.75)):
        k = n_of(d)
        f0 = env_points([(0, fa), (d * 0.4, fb), (d, fc)], k) * (1 + 0.02 * smooth_noise(k, 3, rng))
        g = gola(rng, d, f0, jitter=0.06, shimmer=0.18, sotto=0.25, aspira=0.25)
        v = tratto(rng, g, [(240, 2.0, 1.0), (620, 3.0, 0.7), (1500, 4.5, 0.25)], moto=0.12, velocita=0.4)
        v = sporca(v, 1.6)
        e = env_points([(0, 0), (d * 0.25, 1), (d * 0.7, 0.85), (d, 0)], k) ** 1.2
        # la subarmonica: il petto enorme che risuona
        ph = np.cumsum(f0 * 0.5) / SR
        v = v * e + np.sin(2 * np.pi * ph) * e * 0.5
        mix_into(voce, v * forza, n_of(t0))
    voce += rombo_sotto(rng, dur, 0.25)
    # lontana: dietro una porta d'acciaio e lungo corridoi di lamiera
    voce = lp(voce, 650, 2)
    voce = f32(reverb(voce, ir_nave(), wet=0.85, dry=0.45))
    return f32(fade(voce, 0.2, 1.2))


def squalo_sbuffo(rng):
    d = 0.9
    r = ringhio(rng, d, f0=(58.0, 44.0), sporco=3.0, rullo=22.0, bocca=1.1, aspira=0.9)
    r *= env_points([(0, 0), (0.03, 1), (0.25, 0.5), (d, 0)], len(r))
    soffio = bp(white(n_of(d), rng), 300, 2500, 2) * env_points([(0, 0), (0.02, 1), (0.4, 0)], n_of(d))
    return f32(fade(reverb(r * 0.8 + soffio * 0.6, ir_piccola(), wet=0.15), 0.0, 0.15))


def squalo_passo(rng, i):
    """Un piede enorme e bagnato sulle piastrelle: il tonfo, lo splat e gli artigli che ticchettano. Sotto, un
    colpo grave e lungo che fa tremare il pavimento (e la camera)."""
    out = np.zeros(n_of(0.8))
    k = n_of(0.3)
    tonfo = lp(white(k, rng), 260, 2) * env_points([(0, 0), (0.006, 1), (0.12, 0.25), (0.3, 0)], k)
    tonfo += np.sin(2 * np.pi * np.cumsum(np.linspace(75, 45, k)) / SR) * env_ad(k, 0.003, 0.18) * 0.8
    mix_into(out, tonfo * 1.2, 0)
    kg = n_of(0.55)
    grave = np.sin(2 * np.pi * np.cumsum(np.linspace(58, 34, kg)) / SR) * env_ad(kg, 0.004, 0.42)
    grave += lp(white(kg, rng), 90, 2) * env_ad(kg, 0.002, 0.25) * 2.5
    mix_into(out, grave * 1.6, 0)
    # il pavimento di lamiera sotto le piastrelle che vibra un attimo
    lam = resonator_bank(impulso(0.3), rng.uniform(0.95, 1.05) * np.array([110, 173, 260]), [0.35, 0.25, 0.18], [1, 0.6, 0.4])
    mix_into(out, lp(lam, 600) * 0.25, n_of(0.004))
    mix_into(out, pitch(tacco_piastrella(rng, i), -7) * 0.6, n_of(0.005))
    mix_into(out, strato_bagnato(rng, forza=1.4), n_of(0.01))
    # tre artigli che toccano la ceramica, appena dopo
    for j in range(3):
        c = resonator_bank(impulso(0.05), rng.uniform(0.9, 1.1) * np.array([2600, 4100, 6400]),
                           [0.012, 0.009, 0.006], [1, 0.6, 0.3])
        mix_into(out, c * 0.25, n_of(0.03 + 0.025 * j + rng.uniform(0, 0.01)))
    return f32(fade(out, 0.0, 0.08))


def squalo_denti(rng, i):
    """I denti che scattano nell'aria: due file di denti che si chiudono di colpo (due scatti a 12 ms), osso
    secco e duro, poi la saliva."""
    out = np.zeros(n_of(0.35))
    for j, ritardo in enumerate((0.0, 0.012 + rng.uniform(0, 0.006))):
        f = rng.uniform(0.92, 1.08) * np.array([1900, 3100, 4700, 7200])
        c = resonator_bank(impulso(0.06), f, [0.018, 0.012, 0.008, 0.005], [1, 0.8, 0.5, 0.3])
        c += hp(white(n_of(0.06), rng), 2500) * env_ad(n_of(0.06), 0.0005, 0.012) * 0.8
        mix_into(out, c * (1.0 if j == 0 else 0.7), n_of(ritardo))
    # il colpo sordo della mascella
    k = n_of(0.12)
    mix_into(out, np.sin(2 * np.pi * np.cumsum(np.linspace(160, 90, k)) / SR) * env_ad(k, 0.001, 0.06) * 0.6, 0)
    sal = bp(white(n_of(0.3), rng), 1200, 5000, 2) * env_points([(0, 0), (0.02, 0.5), (0.3, 0)], n_of(0.3))
    mix_into(out, sal * 0.15, n_of(0.02))
    return f32(fade(reverb(out, ir_piccola(), wet=0.1), 0.0, 0.06))


def squalo_ringhio(rng):
    """Si gira verso la porta: un ringhio che monta e si chiude, la gola enorme che rulla."""
    d = 1.3
    r = ringhio(rng, d, f0=(50.0, 64.0), sporco=3.2, rullo=24.0, bocca=1.2, aspira=0.7, sub=0.5)
    r *= env_points([(0, 0), (0.12, 0.8), (0.55, 1.0), (1.0, 0.6), (d, 0)], len(r))
    return f32(fade(reverb(r, ir_piccola(), wet=0.15), 0.02, 0.2))


SUONI = {
    'squalo_minaccia': lambda: salva(CART, 'squalo_minaccia', mono(squalo_minaccia(np.random.default_rng(2110))),
                                     loudness=-15, qualita=5,
                                     nota="fiato pesante e umido a pochi centimetri, ringhi corti agli scatti della testa (2,3 s, 3,2 s, 4,1 s dall'inizio del file)"),
    'jilly_richiamo': lambda: salva(CART, 'jilly_richiamo', mono(jilly_richiamo(np.random.default_rng(2111))), loudness=-20,
                                    qualita=5, nota='il verso lontano e profondo di Jilly che lo chiama, dietro la porta tagliafuoco'),
    'squalo_sbuffo': lambda: salva(CART, 'squalo_sbuffo', mono(squalo_sbuffo(np.random.default_rng(2112))), loudness=-16,
                                   corto=True, qualita=4, nota='sbuffo di gola quando si volta a guardarti'),
    'squalo_passo': lambda: [salva(CART, f'squalo_passo_{i + 1:02d}', squalo_passo(np.random.default_rng(2113 + i), i),
                                   loudness=-12, corto=True, qualita=4, fonte='sintesi + Kenney Impact Sounds (CC0)',
                                   nota='passo pesante e bagnato con gli artigli, con il colpo grave sotto') for i in range(4)],
    'squalo_denti': lambda: [salva(CART, f'squalo_denti_{i + 1:02d}', mono(squalo_denti(np.random.default_rng(2120 + i), i)),
                                   loudness=-11, corto=True, qualita=5, nota='i denti che scattano a ogni morso nell\'aria')
                             for i in range(3)],
    'squalo_ringhio': lambda: salva(CART, 'squalo_ringhio', mono(squalo_ringhio(np.random.default_rng(2130))), loudness=-14,
                                    corto=True, qualita=5, nota='il ringhio quando si gira verso la porta'),
}


def main():
    import sys
    print('Squalo (inizio)')
    scelti = [a for a in sys.argv[1:] if a in SUONI] or list(SUONI)
    for nome in scelti:
        SUONI[nome]()


if __name__ == '__main__':
    main()
