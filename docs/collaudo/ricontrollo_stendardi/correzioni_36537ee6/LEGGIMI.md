# Terzo ricontrollo degli stendardi: piega continua, mollette a cavallo, stendardo 1 spostato (enigmi, 6 novembre)

- Branch ricontrollato: `lavoro/stendardi-inseguimento`, punta `36537ee6`. Le correzioni sono in `26e1b2b3` e
  `36b84ec7`.
- Lo strumento è `godot/tests/collaudo/ricontrollo_stendardi.gd`:
  - `vicino` e `fessura`, con `SCATTI_LUCE=1`;
  - `giro` e `lei`, con `SOLO_VASCA=1` e `SOLO_STATI=vasca_0,scolo_1`.
- Le misure le ho prese sulla GLB della punta (`misure_mollette_piega.py`, insieme alle intersezioni del secondo
  ricontrollo).

## Esito: passa

### Da vicino (fogli 4-7)

- **Piega e stoffa.**
  - La cima della stoffa è dritta, a y -15,571 per lo stendardo 1, e coincide col bordo della piega: distanza massima
    0 mm, sui 4 stendardi.
  - La piega avvolge il bastone per tutta la lunghezza. Ho tirato raggi dall'asse del bastone ogni 2 cm, in 11
    direzioni: 0 raggi senza stoffa su 1650 per ogni stendardo.
  - La stoffa non tocca il bastone (1,5 mm) e non si interseca con niente.
- **Sezione alla molletta.**
  - Le ganasce stanno ai fianchi della piega a 0,45 mm, senza compenetrazioni.
  - Il perno e la molla stanno sopra, a 4,9 mm dal bastone.
  - Nessuna molletta si interseca con il bastone, la stoffa o la piega.
- **Molletta 0 e codino.** La corda più vicina a una molletta è a 6,9 cm per la corda "a" e a 9,1 cm per la "b", su
  tutti e 4.
  - Il codino non entra più nella molletta.
  - Grafica scriveva «almeno 12 cm»: non è vero, ma il contatto non c'è.
- **Corde e golfari:** come nel secondo ricontrollo, a posto. Due giri e un nodo al bastone. I giri affondano 3,5 mm
  e sembrano legati stretti. Il gambo del golfare entra 1,2 cm nella trave, e il nodo gira attorno all'occhiello.

### Lo stendardo 1 nel posto nuovo, 5 m più a nord (foglio 8)

- Dalla vasca 1, da tre posti, la lampada appesa fredda resta visibile, a sinistra dello stendardo.
- Il calcolo delle coperture (`varianti_fattibilita.txt`, posto "dy +5"), coi raggi da 9 posti per vasca, non trova
  niente coperto: bocche, paratie, bersagli, luci verdi e rosse, lampade.
- Lo stendardo resta a 0,78 m dal cavo di quella lampada e non tocca niente.
- Sotto non ci sono passaggi: i 2 m liberi ci sono.
- Lei, nella vasca 1 e nello scolo 1, sta a più di 3 m e non lo copre.
- Da dove si spara prende il 21% dell'altezza dello schermo, a 16 m (prima era il 28%, a 12 m).

## Fogli

4. `4_mollette_e_piega.jpg`: mollette davanti, di lato (la sezione) e da dietro, sui 4 stendardi.
5. `5_capi_del_bastone.jpg`: i giri, il nodo e il codino.
6. `6_golfari.jpg` e 7. `7_golfari_da_vicinissimo.jpg`: i golfari.
8. `8_stendardo1_dalla_vasca1.jpg`: lo stendardo 1 dalla vasca 1, anche con lei su.
