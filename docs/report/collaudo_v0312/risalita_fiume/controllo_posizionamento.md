# Controllo di posizionamento

Scritto da `godot/tests/controllo_posizionamento.gd` il 2026-10-23 20:55:24. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0.35 e 2.00 m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.

Nuovi: 0. Già noti (in `godot/tests/posizionamento_eccezioni.json`): 16. Eccezioni non più trovate: 26.

## Già noti

### interni

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_rotore` | -0.25, 0.00, 25.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (4 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_telaio` | -0.75, 0.00, 25.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (12 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |

### risalita

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | compenetra | `Risalita/Fiume/paratia/Mesh_0` | -38.16, -5.40, 117.17 | dentro ci passa Risalita/Fiume/@MeshInstance3D@397, 5 cm sotto la sua superficie (per esempio in (-38.16, -5.4, 117.17), lo spigolo da (-38.2, -5.4, 117.4) a (-38.13, -5.4, 117.0)) (stato: risalita_arrivo) | voluto: il telaio della chiusa a saracinesca, di traverso alla bocca del ramo, poggia sul bordo delle due sponde e ci entra con le guide, come una paratia vera |
| enigmi | compenetra | `Risalita/Fiume/paratia4/Mesh_0` | -55.75, -5.40, 93.60 | dentro ci passa Risalita/Fiume/@MeshInstance3D@397, 3 cm sotto la sua superficie (per esempio in (-55.75, -5.4, 93.6), lo spigolo da (-56.0, -5.4, 93.6) a (-54.4, -5.4, 93.6)) (stato: risalita_arrivo) | voluto: il telaio della chiusa a saracinesca, di traverso alla bocca del ramo, poggia sul bordo delle due sponde e ci entra con le guide, come una paratia vera |
| enigmi | compenetra | `Risalita/Fiume/paratia5/Mesh_0` | -33.40, -5.40, 64.75 | dentro ci passa Risalita/Fiume/@MeshInstance3D@397, 3 cm sotto la sua superficie (per esempio in (-33.4, -5.4, 64.75), lo spigolo da (-33.4, -5.4, 65.0) a (-33.4, -5.4, 63.0)) (stato: risalita_arrivo) | voluto: il telaio della chiusa a saracinesca, di traverso alla bocca del ramo, poggia sul bordo delle due sponde e ci entra con le guide, come una paratia vera |

### sala

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_2` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.28 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_3` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.28 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_4` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.54 e 1.62 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_5` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.54 e 1.62 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_6` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.88 e 1.96 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_7` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.88 e 1.96 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| ambienti-1 | ingombro | `Sala/AreaBimbi/sala_struttura_gioco` | -12.25, 0.00, -19.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (85 celle da 25 cm) (pavimento a y -0.00), con la collisione (ci si sbatte contro) (stato: risalita_arrivo) | voluto: struttura per bambini: i tettucci e le sbarre stanno all'altezza della testa di un adulto, ci si urta come contro un muro e si passa accovacciati (scelta dell'utente, 22 ottobre) |

### tecnici

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/ATTUATORE_stagno` | -2.50, -9.05, 47.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.52 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -9.05), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: fissato al muro est della sala pompe accanto alla porta, a 1,2-1,52 m da terra: sporge 24,2 cm dal muro, staffa compresa (al più 25); non pende nel passaggio (staffa a muro); davanti, alla testa, 17,6 m liberi fino al muro ovest (almeno 80 cm). Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico` | -3.50, -9.05, 31.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.90 e 2.00 m sopra il pavimento (2 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) (stato: risalita_arrivo) | voluto: quadro elettrico appeso al muro sud della sala pompe, da 0,9 a 2,65 m: sporge 24 cm dal muro (era 56; profondità 0,24 m nel generatore), fissato al muro, non pende nel passaggio; davanti, alla testa, la sala libera per oltre 3 m. Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti` | -3.50, -9.05, 36.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.30 e 2.00 m sopra il pavimento (5 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) (stato: risalita_arrivo) | voluto: pannello degli strumenti appeso al muro sud della sala pompe, da 1,3 a 2,25 m: sporge 24 cm dal muro (era 36; profondità 0,24 m nel generatore), fissato al muro, non pende nel passaggio; davanti, alla testa, la sala libera per oltre 3 m. Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/SALA_ringhiera` | -2.75, -9.05, 36.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 1.10 m sopra il pavimento (6 celle da 25 cm) (pavimenti fra y -9.05 e -8.89), senza collisione (si attraversa) (stato: risalita_arrivo) | voluto: i montanti in cima alla scaletta della vasca di raccolta (escono 25 cm dal bordo, fino a 0,9 m): si esce dalla vasca passandoci in mezzo; la ringhiera vera ha le sue scatole di collisione |

## Copertura

Per ogni giro, quanti oggetti di scena si sono controllati in ogni parte. Una parte con 0 è una zona che il controllo non ha guardato.

| Giro | Parte | Oggetti controllati |
|---|---|---|
| sala_principale · risalita_arrivo | `Risalita` | 197 |
| sala_principale · risalita_arrivo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_arrivo | `Risalita/Fiume` | 664 |
| sala_principale · risalita_arrivo | `Risalita/Infermeria` | 154 |
| sala_principale · risalita_arrivo | `Risalita/lampada_emergenza` | 2 |
| sala_principale · risalita_dopo | `Risalita` | 197 |
| sala_principale · risalita_dopo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_dopo | `Risalita/Fiume` | 664 |
| sala_principale · risalita_dopo | `Risalita/Infermeria` | 210 |
| sala_principale · risalita_dopo | `Risalita/lampada_emergenza` | 2 |

### Parti nascoste all'inizio

Le parti nascoste nel giro iniziale (compaiono più avanti, o sono le versioni spente o accese di una luce, o effetti). "Controllata nello stato" vuol dire che un giro con stato le ha viste visibili; "mai controllata" va guardato.

| Scena | Parte nascosta | Mesh | Controllata |
|---|---|---|---|
| sala_principale | `Risalita/Infermeria/Cassetto11/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto12/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto13/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto14/Frontale/Radiografia` | 1 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto14/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto15/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto21/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto22/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto23/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto24/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Cassetto25/Frontale/Tirato` | 5 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Keycard` | 2 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/Negatoscopio/Lastra` | 2 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria/PolaroidPecora` | 1 | sì, in uno stato |

## Eccezioni non più trovate (si possono togliere dal file)

- torre · ingombro · `SalaInseguimento/InseguimentoStruttura/ins_A_struttura`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_2`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0`
- torre · ingombro · `TorreScivoli/torre_tubo_inseguimento`
- acquari · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_4`
- acquari · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_6`
- acquari · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_2`
- acquari · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_7`
- acquari · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_5`
- acquari · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_3`
- tecnici · compenetra · `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_0`
- tecnici · compenetra · `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3b_0`
- tecnici · compenetra · `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3b_1`
- tecnici · compenetra · `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3b_2`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_13`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_14`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_15`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_16`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_17`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_18`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_19`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_20`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_21`
- tecnici · compenetra · `Tecnici/Logica/SerrandaMagazzino/Lamelle_22`
