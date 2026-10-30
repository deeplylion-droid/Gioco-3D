# Ricontrollo di grafica-2 su lavoro/luci-0317 (cb250418)

**Superato, nessun difetto.**

1. Squalo, riflesso viola al ruggito (`godot/tests/collaudo/verifica_ruggito_g2.gd`, occhi del giocatore, 4 preset; `foglio_ruggito.jpg`: senza riflesso, con riflesso, cosa illumina x8):
   - faccia e denti si leggono in tutti e 4 i preset; restano il controllo viola dalla porta e l'ombra nei raggi;
   - bocca (luma) senza riflesso 1,5 / 1,7 / 3,5, con riflesso 3,8-4,4 / 4,5-5,1 / 22-23 (ruggito 1, 2, 3); la gola resta scura;
   - illumina solo lo squalo: maschera 65536, nessun nodo del giocatore su quello strato, la differenza x8 è solo sulla sagoma;
   - energia massima 0,30; dopo arretra + 0,65 s al più 0,006 (spenta, arretra_09 senza differenza);
   - pipeline al ruggito: alto +7/+12 uguali con il riflesso a 0 (non sono sue); ultra +0/+14, basso +5/+9, medio +7/+12.
2. Fiume, corridoio delle pile (`foglio_fiume.jpg`, 4 punti dagli occhi, 8 m avanti): la strada fra le transenne e la ciambella verde si leggono.
3. `test_luci_bianche_gioco`: 13 ok, 0 falliti.

0 "ERROR: BUG," in tutti i log (4 preset, controllo, fiume, test).
