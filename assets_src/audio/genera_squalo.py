"""Suoni dell'inizio con il mostro-squalo (GDD, "L'inizio con il mostro-squalo"): il risveglio nel
corridoio con lo squalo addosso, il verso lontano di Jilly che lo chiama dalla porta tagliafuoco, lo
squalo che si gira, esita e scappa. I tempi sono quelli dell'animazione
(godot/assets/models/mascotte/mostro_squalo_A_rig.json, da assets_src/mascotte/mostro_anim.py).

- squalo_minaccia: dal risveglio al richiamo, attaccato alla bocca: il fiato pesante e umido a pochi
  centimetri dalla faccia, la gola che raschia e, a ogni scatto in avanti della testa, un ringhio corto
  con lo schiocco umido delle fauci (scatti a MINACCIA + 0,7, 1,6 e 2,5 s dell'animazione);
- jilly_richiamo: il verso di lei, lontano e profondo, che arriva da dietro la porta tagliafuoco: la
  stessa gola gutturale di lei (genera_lei: gola(), tratto()) ma lunga e lenta, un richiamo che sale e
  scende due volte, attutito dalla porta e dai corridoi di lamiera (riverbero della nave);
- squalo_sbuffo: lo sbuffo di gola quando si volta a guardarti prima di scappare;
- squalo_passo: i passi pesanti e bagnati sulle piastrelle, con il ticchettio degli artigli.
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
    mix_into(out, respiro(rng, dur, cicli, umido=1.4, rauco=0.5), 0)
    # sotto, la gola che brontola sempre
    mix_into(out, lp(ringhio(rng, dur, f0=(46.0, 52.0), sporco=2.0, rullo=18.0, sub=0.4), 900) * 0.35, 0)
    # i ringhi corti degli scatti
    for tc in SCATTI:
        r = ringhio(rng, 0.55, f0=(62.0, 48.0), sporco=3.5, rullo=26.0, bocca=1.3)
        r *= env_points([(0, 0), (0.04, 1), (0.3, 0.7), (0.55, 0)], len(r))
        mix_into(out, r * 0.9, n_of(tc - MINACCIA_INIZIO - 0.06))
        mix_into(out, schiocco(rng) * 0.8, n_of(tc - MINACCIA_INIZIO + 0.12))
    # da vicinissimo: un filo di stanza piccola, niente coda lunga
    return f32(fade(reverb(out, ir_piccola(), wet=0.12), 0.05, 0.3))


def jilly_richiamo(rng):
    """Il richiamo: due lunghi versi di gola che salgono e scendono, il secondo più corto."""
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
    """Un piede enorme e bagnato sulle piastrelle: il tonfo, lo splat e gli artigli che ticchettano."""
    out = np.zeros(n_of(0.6))
    k = n_of(0.3)
    tonfo = lp(white(k, rng), 260, 2) * env_points([(0, 0), (0.006, 1), (0.12, 0.25), (0.3, 0)], k)
    tonfo += np.sin(2 * np.pi * np.cumsum(np.linspace(75, 45, k)) / SR) * env_ad(k, 0.003, 0.18) * 0.8
    mix_into(out, tonfo * 1.2, 0)
    mix_into(out, pitch(tacco_piastrella(rng, i), -7) * 0.6, n_of(0.005))
    mix_into(out, strato_bagnato(rng, forza=1.4), n_of(0.01))
    # tre artigli che toccano la ceramica, appena dopo
    for j in range(3):
        c = resonator_bank(impulso(0.05), rng.uniform(0.9, 1.1) * np.array([2600, 4100, 6400]),
                           [0.012, 0.009, 0.006], [1, 0.6, 0.3])
        mix_into(out, c * 0.25, n_of(0.03 + 0.025 * j + rng.uniform(0, 0.01)))
    return f32(fade(out, 0.0, 0.08))


def main():
    rng = np.random.default_rng(2110)
    print('Squalo (inizio)')
    salva(CART, 'squalo_minaccia', mono(squalo_minaccia(rng)), loudness=-15, qualita=5,
          nota="fiato pesante e umido a pochi centimetri, ringhi corti agli scatti della testa (2,3 s, 3,2 s, 4,1 s dall'inizio del file)")
    salva(CART, 'jilly_richiamo', mono(jilly_richiamo(rng)), loudness=-20, qualita=5,
          nota='il verso lontano e profondo di Jilly che lo chiama, dietro la porta tagliafuoco')
    salva(CART, 'squalo_sbuffo', mono(squalo_sbuffo(rng)), loudness=-16, corto=True, qualita=4,
          nota='sbuffo di gola quando si volta a guardarti')
    for i in range(4):
        salva(CART, f'squalo_passo_{i + 1:02d}', squalo_passo(rng, i), loudness=-14, corto=True, qualita=4,
              fonte='sintesi + Kenney Impact Sounds (CC0)', nota='passo pesante e bagnato con gli artigli')


if __name__ == '__main__':
    main()
