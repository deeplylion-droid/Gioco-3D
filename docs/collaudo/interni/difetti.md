# Collaudo del posizionamento: interni

Risveglio e corridoio, spogliatoi, stanzino del bagnino. Base: `lavoro/godot` al commit 921d14f. Squadra collaudo, 22 ottobre.

Posizioni in metri, nel mondo di `sala_principale.tscn` (gli interni stanno in -9,7, 0, 40,9). Le distanze sono misurate fra le superfici vere delle mesh (`tools/collaudo/distanze.py`), non fra i box. Gli scatti sono in `scatti/`, i fogli del giro in `fogli/`.

## Come è stato fatto

- **Controllo della CI** (`controllo_posizionamento.gd`): 0 casi nuovi, 54 noti in tutto il gioco; negli interni 24 casi "da correggere" (4 fischietti e un'anta sospesi, 19 ingombri), più i 3 neon "voluti".
- **Distanze vere**: 185 oggetti degli interni, negli stati inizio, aperto (porte e serrande aperte) e ritorno (blackout della tappa 7). Fra uno stato e l'altro negli interni cambiano solo la porta della sala pompe e la saracinesca.
- **Giro dagli occhi**: 30 punti, uno ogni 2,5 m, 4 scatti per punto (120 scatti), in `fogli/int_giro_*.jpg`.
- **Oggetti piccoli**: 77 sotto i 40 cm, 66 non sul pavimento, tutti guardati da vicino (`fogli/int_mira_*.jpg`, elenco in `oggetti_piccoli.csv`).

## Difetti

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | `Interni/Zaino/Modello/Zaino` (da raccogliere) | 4,78, 1,03, 32,47 | Non è appeso a niente: sta a 4,9 cm dalla rastrelliera (`Stanzino/rastrelliera_zaino`), davanti al palo, senza un gancio. | `scatti/int_Zaino_b.jpg`, `int_Zaino_stacco_l.jpg` |
| 2 | `Stanzino/salvagente_rastrelliera_1` | 4,82, 1,00, 33,35 | Salvagente a 4,1 cm dal gancio della rastrelliera: appeso al nulla. | `int_salvagente_rastrelliera_1_a.jpg`, `_stacco_v.jpg` |
| 3 | `Stanzino/salvagente_rastrelliera_2` | 4,82, 1,00, 31,60 | Come il 2: 4,2 cm dal gancio. | `int_salvagente_rastrelliera_2_a.jpg` |
| 4 | `Stanzino/braccioli_stanzino` | 5,20, 2,07, 31,90 | Braccioli 4,4 cm sopra la griglia in cima alla rastrelliera: sospesi. | `int_braccioli_stanzino_a.jpg`, `_stacco_v.jpg` |
| 5 | `Stanzino/fischietto_1`, `_2`, `_4`, `_5` | 2,1-3,3, 1,10-1,26, 30,40 | Fischietti a 7,4 cm dal muro, sospesi in aria (già "da correggere" nelle eccezioni). | `int_fischietto_4_stacco_l.jpg`, `int_fischietto_1_stacco_v.jpg` |
| 6 | Ante aperte degli armadietti: `Spogliatoi/armadietti_ovest_11_anta`, `est_09_giallo_anta`, `ovest_02_anta`, `est_01_anta`, `est2_02_anta`, `est_07_anta`, `ovest_05_anta`, `ovest_15_anta`, `armadietto_sbatte_anta` | ovest x -6,0/-6,2, z 31,4-36,8; est x 0,6-0,8, z 33,6-36,9; est2_02 in 1,05, 0,96, 30,6 | L'anta aperta non tocca il suo armadietto: staccata dal corpo di 6,0 / 5,6 / 5,4 / 4,1 / 2,7 / 2,1 / 2,0 / 1,7 / 1,6 cm. `est2_02_anta` tocca solo il pallone. Il controllo della CI ne trova una sola (ovest_02). | `int_armadietti_*_anta_a.jpg`, `fogli/int_stacchi_01.jpg` |
| 7 | Luci d'emergenza staccate dal muro: `Corridoio/luce_emergenza_02`, `_03`, `_05`, `_06`; `Spogliatoi/luce_emergenza_spogliatoi_01`…`_06`; `Stanzino/luce_emergenza_stanzino_01` (con i loro `_vetro`) | corridoio y 2,2-2,4 a x 1,1 / 9,5 / 12,2 / -9,6; spogliatoi e stanzino y 2,3-2,55 | Lampada e vetro a 2,0 cm dal muro: nessuna tocca la parete (le 01, 04, 07 e 08 del corridoio invece sì). | `int_luce_emergenza_02_a.jpg`, `int_luce_emergenza_spogliatoi_05_stacco_l.jpg` |
| 8 | `Corridoio/luce_emergenza_01`, `_07`, `_08` | -6,7 / -2,2 / 7,8, 2,2-2,25, 38,4-40,8 | La lampada è infilata dietro il tubo grosso che corre lungo il muro: la gabbia tocca ed entra nel tubo, e dal corridoio si vede appena. | `int_luce_emergenza_07_a.jpg`, `_08_a.jpg`, `_01_a.jpg` |
| 9 | `Corridoio/luce_emergenza_04` | 7,80, 2,35, 40,77 | Un tubo sottile passa proprio davanti alla lampada. | `int_luce_emergenza_04_a.jpg` |
| 10 | `Corridoio/neon_corridoio_3` (e `_tubi`) | 5,80, 2,30, 39,60 | La plafoniera è 5,7 cm sotto la fine del suo cavo (`neon_corridoio_3_cavo`): il cavo non la regge. | `int_neon_corridoio_3_stacco_l.jpg`, `int_neon_corridoio_3_a.jpg` |
| 11 | `Corridoio/porta_sala_pompe`, aperta (stati aperto e ritorno, tappa 7) | 8,32, 1,02, 40,52 | Da valutare: aperta a 90 gradi sporge 1 m nel corridoio largo 2,6 m, all'altezza della testa, sulla strada del ritorno. Il controllo della CI guarda solo lo stato iniziale. | (posizione misurata) |
| 12 | `Spogliatoi/tornello_rotore` | 0,0, 1,1, 25,0 | Minore: il rotore non tocca il telaio, 1,1 cm. | `int_tornello_rotore_stacco_l.jpg` |

Restano aperti anche i 19 ingombri "da correggere" del controllo della CI negli interni (estintore, asciugamani, cestini, palloni, cartelli, ante, sedia, tornello, porta dello stanzino): nell'elenco delle eccezioni dal 22 ottobre, ancora da assegnare.

## Visti e a posto

Polaroid 01 e 03, radio, ricetrasmittente, sprinkler, rubinetti e soffioni delle docce, salvagente del ripiano e della parete, cassetta del pronto soccorso, bacheca, grata di aerazione, maniglione della porta: misurati a contatto con ciò che li regge. Nel giro non ci sono oggetti sospesi o compenetrati oltre a quelli sopra.

## Note sugli strumenti

- Il controllo della CI non vede i MultiMesh: i 1219 dettagli della sala (`Sala/Dettagli`) con 6 o più copie diventano MultiMesh e non entrano nel controllo. Negli interni non ce ne sono; contano per la sala.
- Le celle "raggiungibili" del controllo comprendono anche punti dentro i muri spessi a trimesh (il cilindro delle gambe non tocca nessuna superficie): nel corridoio, a z 41, fra x -9 e 11. Nel collaudo sono tolte con un raggio verso l'alto (spazio per la testa di 1,8 m).
