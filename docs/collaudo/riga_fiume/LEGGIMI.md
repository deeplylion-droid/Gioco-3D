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
