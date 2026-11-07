"""Suoni dei ritocchi degli enigmi per la 0.3.21 (scelte dell'utente del 4 novembre sulla pagina "Ritocchi del
capitolo 1", proposte enigmi-2, -3 e -4, tutte A; GDD, "Dopo la 0.3.20"):

- cassaforte_clic_a, _b, _c: il clic metallico secco di una cifra, uno per rotella (testa, corpo, coda), un po'
  diversi fra loro (tono del dente e della molla). Col codice sbagliato non succede altro.
- cassaforte_apre: col codice giusto il colpo pesante del chiavistello che si ritira (0 s), poi il cigolio dello
  sportello sui cardini (da CASSAFORTE_CIGOLIO_DA a _A) e il colpetto quando arriva aperto. Lo sportello segue
  questi tempi (CassaforteRotelle).
- disco_lamiera_colpo: il getto che prende il disco a strisce del fiume: un colpo di lamiera come un gong, che
  ronza a lungo (2,5 s). Poi le chiuse si muovono con i suoni delle paratie della camera delle onde
  (paratia_scende_loop e il colpo sordo in fondo): nessun suono nuovo per quelle.
- giusto: il "fatto giusto" di ogni enigma risolto (acquari, giocattoli, pozze, cassaforte). È il jingle del
  pulsante della botola (pulsante_botola_attiva, scelto il 16 ottobre) accorciato: le stesse tre note da giocattolo
  (sol, si, re) dall'altoparlantino, senza lo scatto del contattore, un po' stonate (le prime due calanti, la
  terza che cala di più, come a pile scariche) e più corte (0,75 s).

Solo sintesi, più i campioni CC0 di Kenney già usati (metalLatch, impactMetal, creak). Deterministico (semi fissi).
Uscita: godot/audio/enigmi/.
"""
import numpy as np

import genera_proposte as gp
from comune import kenney, salva
from genera_ambiente import MODI_LAMIERA
from genera_effetti import cigolio_metallo, impulso
from genera_giocatore import norm
from lib_audio import (bp, env_ad, env_points, f32, fade, hp, lp, mix_into, n_of, pitch, resonator_bank,
                       trim_silence, white)

CART = 'enigmi'

## Da quando parte cassaforte_apre: il cigolio dello sportello (s) e quando arriva aperto. Uguali in
## addons/audio/audio.gd (CASSAFORTE_CIGOLIO_DA, CASSAFORTE_CIGOLIO_A).
CIGOLIO_DA = 0.38
CIGOLIO_A = 1.75


def clic_rotella(rng, i):
    """Il clic di una cifra: il dente che scavalca la molla (scatto secco e corto), la rotella di metallo che
    risuona appena, poi il tic del dente che si assesta. i (0, 1, 2) cambia il tono: tre rotelle, tre clic."""
    out = np.zeros(n_of(0.22))
    tono = [1.0, 0.86, 1.17][i]
    scatto = norm(kenney('metalLatch.ogg'))
    scatto = hp(pitch(scatto, 7.0 + 2.5 * (tono - 1.0) * 4), 900)[:n_of(0.06)]
    mix_into(out, fade(scatto, 0.0, 0.02) * 0.5, 0)
    e = impulso(0.2)
    modi = np.array([1850.0, 3120.0, 4630.0, 6900.0]) * tono
    dente = resonator_bank(e, modi, [0.025, 0.018, 0.012, 0.008], [1.0, 0.6, 0.4, 0.2])
    mix_into(out, norm(dente) * 0.8, 0)
    k = n_of(0.006)
    mix_into(out, norm(bp(white(k, rng), 2500, 10000, 2) * env_ad(k, 0.0002, 0.004)) * 0.5, 0)
    # il tic del dente che si assesta, 20-30 ms dopo e più piano
    tic = resonator_bank(impulso(0.1), modi * 1.12, [0.012, 0.009, 0.006, 0.004], [1.0, 0.5, 0.3, 0.15])
    mix_into(out, norm(tic) * 0.3, n_of(0.022 + 0.004 * i))
    # il corpo della cassaforte, un tono basso e corto
    corpo = resonator_bank(e, np.array([310.0, 540.0, 980.0]) * (0.95 + 0.05 * tono), [0.05, 0.035, 0.02], [1.0, 0.5, 0.3])
    mix_into(out, norm(corpo) * 0.18, 0)
    return fade(hp(out, 150, 2), 0.0, 0.04)


def cassaforte_apre(rng):
    """Il chiavistello pesante che si ritira (il colpo, la barra che scorre, il fermo), poi lo sportello d'acciaio
    che gira sui cardini cigolando e arriva aperto con un colpetto."""
    dur = CIGOLIO_A + 0.6
    out = np.zeros(n_of(dur))
    # il chiavistello: colpo pesante e sordo, con la barra che scorre nel suo foro
    colpo = norm(kenney('impactMetal_heavy_002.ogg'))
    colpo = lp(pitch(colpo, -4.0), 3500)
    mix_into(out, colpo * 0.9, 0)
    barra = norm(kenney('metalLatch.ogg'))
    mix_into(out, lp(pitch(barra, -5.0), 4000) * 0.6, n_of(0.01))
    cassa = resonator_bank(impulso(0.8), np.array([118.0, 205.0, 347.0, 590.0]), [0.35, 0.25, 0.18, 0.1],
                           [1.0, 0.7, 0.45, 0.25])
    mix_into(out, norm(cassa) * 0.45, 0)
    fermo = resonator_bank(impulso(0.2), np.array([1400.0, 2350.0, 3900.0]), [0.03, 0.02, 0.012], [1.0, 0.5, 0.25])
    mix_into(out, norm(fermo) * 0.35, n_of(0.17))
    # il cigolio dello sportello sui cardini
    cig = norm(cigolio_metallo(rng, CIGOLIO_A - CIGOLIO_DA + 0.1, 1, 2.6))
    cig = fade(hp(cig, 300, 2), 0.06, 0.25)
    mix_into(out, cig * 0.55, n_of(CIGOLIO_DA))
    # arrivato aperto: il colpetto del fermo dello sportello
    stop = norm(kenney('impactMetal_light_003.ogg'))
    mix_into(out, lp(pitch(stop, -3.0), 5000) * 0.35, n_of(CIGOLIO_A))
    return fade(trim_silence(hp(out, 40, 2)), 0.0, 0.12)


def disco_lamiera_colpo(rng):
    """Il getto che prende il disco di lamiera sul palo: lo schiaffo dell'acqua e il colpo, poi il disco che
    ronza come un gong (modi non armonici di un disco sottile, battimenti lenti), che si spegne in 2,5 s."""
    dur = 2.6
    out = np.zeros(n_of(dur))
    e = impulso(dur)
    # i modi di un disco sottile appoggiato al centro (rapporti dei modi di una piastra circolare)
    f0 = 196.0
    rapporti = np.array([1.0, 1.53, 2.08, 2.66, 3.27, 3.92, 4.6, 5.32])
    decad = np.array([2.2, 1.7, 1.4, 1.1, 0.8, 0.6, 0.45, 0.35])
    guad = np.array([1.0, 0.75, 0.6, 0.45, 0.35, 0.25, 0.18, 0.12])
    gong = resonator_bank(e, f0 * rapporti, decad, guad)
    # un gemello scordato di poco: il disco che "batte" piano
    gong += resonator_bank(e, f0 * 1.006 * rapporti[:3], decad[:3] * 0.9, guad[:3] * 0.5)
    mix_into(out, norm(gong) * 0.75, 0)
    # il colpo: la lamiera presa di piatto
    colpo = norm(kenney('impactPlate_light_001.ogg'))
    mix_into(out, lp(pitch(colpo, -6.0), 6000) * 0.6, 0)
    lam = resonator_bank(impulso(0.6), np.array(MODI_LAMIERA[3:9]) * 0.9, [0.25, 0.2, 0.15, 0.12, 0.1, 0.08],
                         [1.0, 0.8, 0.6, 0.45, 0.3, 0.2])
    mix_into(out, norm(lam) * 0.35, 0)
    # lo schiaffo dell'acqua del getto
    k = n_of(0.12)
    acqua = bp(white(k, rng), 600, 6000, 2) * env_points([(0, 0), (0.004, 1), (0.03, 0.4), (0.12, 0)], k)
    mix_into(out, norm(acqua) * 0.3, 0)
    return fade(hp(out, 60, 2), 0.0, 0.3)


def giusto(rng):
    """Il jingle della botola accorciato: sol, si, re dall'altoparlantino giocattolo, un po' stonati (le prime due
    calano di un ottavo e di un sesto di tono, la terza cala di più nella coda, come a pile scariche)."""
    dur = 0.75
    jingle = np.zeros(n_of(dur))
    note = [(784.0 * 2 ** (-0.25 / 12), 0.1, 0.0), (988.0 * 2 ** (-0.33 / 12), 0.1, 0.0),
            (1175.0 * 2 ** (-0.2 / 12), 0.42, 1.6)]
    for k, (f, d, cala) in enumerate(note):
        mix_into(jingle, gp.onda_giocattolo(rng, f, d, cala, tremolo=1.0 if k == 2 else 0.0), n_of(k * 0.12))
    out = gp.altoparlantino(jingle) * 0.55
    return fade(hp(out, 30, 2), 0.0, 0.08)


def main():
    print('Enigmi (ritocchi 0.3.21)')
    rng = np.random.default_rng(321)
    for i, lettera in enumerate('abc'):
        salva(CART, f'cassaforte_clic_{lettera}', clic_rotella(rng, i), loudness=-19, corto=True, qualita=4,
              fonte='Kenney RPG Audio (CC0), rielaborati + sintesi', nota=f'il clic di una cifra della rotella {["testa", "corpo", "coda"][i]} (enigmi-2 A, 4 novembre)')
    salva(CART, 'cassaforte_apre', cassaforte_apre(rng), loudness=-15, corto=True, qualita=4,
          fonte='Kenney Impact Sounds e RPG Audio (CC0), rielaborati + sintesi', nota='chiavistello, poi il cigolio dello sportello (enigmi-2 A, 4 novembre)')
    salva(CART, 'disco_lamiera_colpo', disco_lamiera_colpo(rng), loudness=-14, corto=True, qualita=4,
          fonte='Kenney Impact Sounds (CC0), rielaborati + sintesi', nota='il getto che prende il disco del fiume: colpo di lamiera come un gong (enigmi-3 A, 4 novembre)')
    salva(CART, 'giusto', giusto(np.random.default_rng(2606)), loudness=-16, corto=True, qualita=4,
          nota='il jingle della botola accorciato e stonato, a ogni enigma risolto (enigmi-4 A, 4 novembre)')


if __name__ == '__main__':
    main()
