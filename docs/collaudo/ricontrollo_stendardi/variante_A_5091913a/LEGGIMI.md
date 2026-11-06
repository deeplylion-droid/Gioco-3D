# Ricontrollo degli stendardi A (6 x 9 m, pieghe smorzate) (enigmi, 6 novembre)

- Branch ricontrollato: `lavoro/stendardi-inseguimento`, punta `5091913a`. Le pieghe smorzate sono in `a065a2f2`, la
  variante in `3f8f7cc9`.
- Le misure da vicino (`misure_da_vicino.txt`) le ho prese sulla GLB della punta, con `misure_da_vicino.py`.
- Le coperture (`coperture_variante_A.txt`) le ho calcolate con `coperture_variante_A.py`, sulla GLB vera.
- Gli scatti sono di `godot/tests/collaudo/ricontrollo_stendardi.gd`, gruppi `vicino` e `fessura`, con
  `SCATTI_LUCE=1`. In più ci sono i giri di ogni corda attorno al bastone.

## Esito: un difetto da correggere, il resto passa

### Da correggere

**Le corde in mezzo alla stoffa girano attorno al bastone dentro la piega.** Sono 6 corde: le due dello stendardo 1
(x 44 e 48), le due dello stendardo 4 (x 68 e 72) e la terza corda degli stendardi 2 e 3.
- I giri hanno il centro a 1,24 cm dall'asse del bastone e la piega gira a 1,25 cm, quindi la stoffa passa in mezzo
  alla corda: 910-920 coppie di triangoli che si intersecano per corda.
- Da vicino i giri sembrano affondati per metà nella stoffa (foglio 5: "st2 giri m" contro "st2 giri a", che sta sul
  bastone nudo).
- Le corde ai capi degli stendardi 2 e 3 sono fuori dalla stoffa, e lì va bene.
- Correzione possibile: dove c'è la piega, i giri vanno attorno alla piega, col centro della corda a circa 1,8 cm
  dall'asse (piega 1,25 + corda).

### Passa

- **Piega sul bastone.**
  - La cima della stoffa coincide col bordo della piega (0 mm) su tutti e 4, con 144 vertici per stendardo.
  - La piega avvolge il bastone per tutta la lunghezza: 0 raggi su 3300 senza stoffa.
  - Le 24 coppie stoffa-piega sono la cucitura stessa, cioè triangoli con un vertice in comune.
  - Niente fessure (fogli 4 e 5).
- **Mollette** (11 per stendardo).
  - Nessuna intersezione con il bastone, la stoffa o la piega.
  - Le ganasce stanno a 0,45 mm dalla piega.
  - La corda più vicina è a 6,9 cm.
- **Corde dalle travi e capi del bastone.**
  - Stendardi 1 e 4: le corde scendono dritte dalle travi (44 e 48, 68 e 72), e il bastone sporge 1,1 m oltre ogni
    corda.
  - Stendardi 2 e 3: tre corde dalla trave, due ai capi e una in mezzo.
- **Golfari**, su tutte le 10 corde: il gambo entra 1,2 cm nella trave, e il nodo gira attorno all'occhiello (fogli 6 e
  7).
- **Cuciture fra i lenzuoli e orli:** si vedono sulla stoffa come cuciture tratteggiate. Non sono pezzi a parte, quindi
  non hanno niente da compenetrare.
- **Coperture, lei, 2 m e schermo** (ricalcolati su `5091913a`).

  | Stendardo | Fondo | Coperture | Lei | 2 m liberi | Schermo |
  |---|---|---|---|---|---|
  | 1 | -22,31 | nessuna | oltre 3 m | niente sotto; la cosa più vicina della sala è il paralume della lampada fredda, a 0,70 m | 40-41% a 16 m |
  | 2 | -22,81 | nessuna | 1,34 m nella vasca 2 | niente sotto | 55-60% a 9-10 m |
  | 3 | -22,66 | nessuna | oltre 3 m | +5,88 m | 38-40% a 10-11 m |
  | 4 | -22,16 | nessuna | oltre 3 m | +2,07 m | 38% a 12 m |

## Fogli

4. `4_piega_e_mollette.jpg`: la piega e le mollette, davanti, di lato e da dietro.
5. `5_corde_al_bastone.jpg`: i giri delle corde. Quelle in mezzo alla stoffa sono affondate; quella al capo dello
   stendardo 2 sta sul bastone nudo.
6. `6_golfari.jpg` e 7. `7_golfari_da_vicinissimo.jpg`: i golfari.
