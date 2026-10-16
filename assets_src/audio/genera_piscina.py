"""Suoni della tappa 5 (la piscina a onde), scelti dall'utente il 16 ottobre fra le proposte di
genera_proposte.py. Sono gli stessi suoni delle anteprime approvate: stessi semi, stesso ordine e
stessa normalizzazione (le funzioni stanno in genera_proposte.py, con le versioni scartate).

- piscina_svuota_loop (gorgo, proposta A): l'acqua che gira e scende con glu-glu profondi e bolle,
  mentre il livello scende (aspirata con lo zaino). In gioco il tono sale un po' col livello.
- piscina_vuota (A): l'ultima acqua che gira sempre più veloce, il risucchio finale, un sorso
  grave (a 2,2 s), l'aria che fischia nella bocca, poi gocce nella piscina vuota (6,5 s).
- pulsante_botola_attiva (richiamo, proposta B): lo scatto del contattore nella cassetta gialla e
  il jingle giocattolo (sol, si, re) con l'ultima nota che cala, come a pile scariche (1,4 s).
- pulsante_botola_lampeggiante_loop: il lampeggiante che gira (motorino, ingranaggi, un tic a
  giro). In gioco prende giri quando si accende (tono da 0,35 a 1) e si ferma quando lo colpisci.
- pulsante_botola_bibu: il bi-bu da giocattolo, uno a ogni lampo (ogni 1,6 s) finché non lo
  colpisci. È il primo bi-bu del loop dell'anteprima, allo stesso livello.
- medusina_aspirata (vetro, proposta A; 6 varianti): un grappolo di tintinnii di vetro minuscoli,
  un po' stonati, che scende di tono nel tubo, con un plic all'imbocco.
- medusine_sparate (A; 2 varianti): la cascata di tintinnii su una scala a toni interi che si
  allontana, mono (le due dell'anteprima: la prima manciata e la seconda).
Uscita: godot/audio/piscina/.
"""
import numpy as np

import genera_proposte as gp
from comune import salva
from lib_audio import fade, lufs_max, n_of, normalize_lufs

CART = 'piscina'


def main():
    print('Piscina (tappa 5)')
    # il gorgo e la piscina vuota: come in proposta_piscina_a.ogg (seme 1605)
    rng = np.random.default_rng(1605)
    salva(CART, 'piscina_svuota_loop', gp.piscina_svuota_loop_a(rng), loudness=-20, qualita=4,
          nota='gorgo (A, scelto il 16 ottobre): suona dove aspiri finché il livello scende')
    salva(CART, 'piscina_vuota', gp.piscina_vuota_a(rng), loudness=-14, corto=True, qualita=4,
          nota='A: ultimo risucchio, sorso grave a 2,2 s, gocce nella piscina vuota')
    # il pulsante della botola: come in proposta_pulsante_botola_b.ogg (seme 2606)
    rng = np.random.default_rng(2606)
    salva(CART, 'pulsante_botola_attiva', gp.pulsante_botola_attiva_b(rng), loudness=-15, corto=True, qualita=4,
          nota='richiamo (B, scelto il 16 ottobre): scatto del contattore e jingle che cala')
    salva(CART, 'pulsante_botola_lampeggiante_loop', gp.lampeggiante_loop(rng), loudness=-24, qualita=4,
          nota='il lampeggiante giallo che gira')
    for _ in range(4):                         # i numeri delle gocce di quell'anteprima
        rng.integers(1, 7)
        rng.uniform(-0.6, 0.6)
    bip = normalize_lufs(gp.richiamo_loop(rng), -20.0, -1.0)
    uno = fade(bip[n_of(0.46):n_of(0.9)], 0.005, 0.05)      # il primo bi-bu del loop (a 0,5 s)
    salva(CART, 'pulsante_botola_bibu', uno, loudness=round(lufs_max(uno), 2), corto=True, qualita=4,
          nota='un bi-bu a ogni lampo del lampeggiante (ogni 1,6 s)')
    # le micro medusine: come in proposta_medusine_a.ogg (seme 1607; la seconda manciata seme 17)
    rng = np.random.default_rng(1607)
    for i in range(6):
        salva(CART, f'medusina_aspirata_{i + 1:02d}', gp.medusina_aspirata_a(rng), loudness=-24, corto=True,
              qualita=4, nota='vetro (A, scelto il 16 ottobre): tintinnii che scendono nel tubo')
    salva(CART, 'medusine_sparate_01', gp.medusine_sparate_a(rng, mono=True), loudness=-21, corto=True, qualita=4,
          nota='A: cascata di tintinnii che si allontana')
    salva(CART, 'medusine_sparate_02', gp.medusine_sparate_a(np.random.default_rng(17), mono=True), loudness=-21,
          corto=True, qualita=4, nota='A: cascata di tintinnii che si allontana')


if __name__ == '__main__':
    main()
