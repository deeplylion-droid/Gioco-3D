# Riga del fiume (#130), prima e dopo

Causa: in `fiume_gioco.gd`, `_parete` girava il quad al contrario, così le pareti del canale avevano la faccia
davanti verso la banchina. Dall'acqua o di sbieco si vedeva attraverso la parete: la riga chiara lungo il bordo.
Ora la faccia davanti guarda l'acqua.

- `punti_in_piedi.jpg`, `punti_accovacciato.jpg`: 5 punti di prova in 3 direzioni, a 1,65 e 0,97 m, più 3 viste da
  lontano. A sinistra prima, a destra dopo.
- `sette_tratti.jpg`: tutti i 7 tratti ogni 12 m, in 3 direzioni (prima | dopo).
- `ciambella_prima_dopo.jpg`: l'unico cambio d'aspetto: vicino alla ciambella si vedono le piastrelle della vasca
  sulle pareti del canale, che prima erano nere (si vedeva il loro retro).

Controlli: test_fiume 35/0, test_fiume_gioco 34/0, controllo_posizionamento 0 da correggere.

## Le fessure vicino all'imbarco e sotto la valvola dell'approdo (9 novembre)
`fessure_risalita_intera.jpg`: nel fiume da solo i pixel magenta di quegli scatti escono dalla porta d'ingresso
(x −26, z −28,6) e dalla porta di servizio dell'approdo (x −41, z 0), viste fra la capanna e la parete e sotto la valvola
(`godot/tests/collaudo/fiume_fessure.gd`). Con la risalita intera (fiume, corridoi, infermeria) gli stessi scatti hanno
0 pixel magenta (`fessure_risalita_scatti.gd`), e nel gioco vero i raggi verso le due porte arrivano al corridoio e
all'infermeria, mai al cielo (`fessure_fiume_gioco.gd`). Non sono buchi del guscio.
