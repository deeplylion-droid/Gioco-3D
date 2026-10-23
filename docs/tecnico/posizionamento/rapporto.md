# Controllo di posizionamento

Scritto da `godot/tests/controllo_posizionamento.gd` il 2026-10-23 04:09:33. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0.35 e 2.00 m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.

Nuovi: 0. Già noti (in `godot/tests/posizionamento_eccezioni.json`): 25. Eccezioni non più trovate: 0.

## Già noti

### acquari

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_2` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.28 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: acquari_comparsi) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_3` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.28 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) (stato: acquari_comparsi) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_4` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.54 e 1.62 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: acquari_comparsi) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_5` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.54 e 1.62 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) (stato: acquari_comparsi) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_6` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.88 e 1.96 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: acquari_comparsi) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_7` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.88 e 1.96 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) (stato: acquari_comparsi) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |

### interni

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_rotore` | -0.25, 0.00, 25.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (4 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_telaio` | -0.75, 0.00, 25.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (12 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |

### sala

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_2` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.28 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_3` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.28 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_4` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.54 e 1.62 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_5` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.54 e 1.62 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_6` | 19.25, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.88 e 1.96 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_7` | 19.25, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.88 e 1.96 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) | voluto: a uno stipite (regola del coordinatore del 23 ottobre): la lampadina sta sul montante della cornice di lampadine del portone (a terra, con la sua collisione, x 19,58-19,63), sporge 14 cm dal montante (fronte a x 19,44); passaggio libero 6,8 m all'altezza della testa (il varco del portone fra i due montanti); non pende nel passaggio (enigmi) |
| ambienti-1 | ingombro | `Sala/AreaBimbi/sala_struttura_gioco` | -12.25, 0.00, -19.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (85 celle da 25 cm) (pavimento a y -0.00), con la collisione (ci si sbatte contro) | voluto: struttura per bambini: i tettucci e le sbarre stanno all'altezza della testa di un adulto, ci si urta come contro un muro e si passa accovacciati (scelta dell'utente, 22 ottobre) |

### tecnici

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/ATTUATORE_stagno` | -2.50, -9.05, 47.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.52 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -9.05), senza collisione (si attraversa) | voluto: fissato al muro est della sala pompe accanto alla porta, a 1,2-1,52 m da terra: sporge 24,2 cm dal muro, staffa compresa (al più 25); non pende nel passaggio (staffa a muro); davanti, alla testa, 17,6 m liberi fino al muro ovest (almeno 80 cm). Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico` | -3.50, -9.05, 31.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.90 e 2.00 m sopra il pavimento (2 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: quadro elettrico appeso al muro sud della sala pompe, da 0,9 a 2,65 m: sporge 24 cm dal muro (era 56; profondità 0,24 m nel generatore), fissato al muro, non pende nel passaggio; davanti, alla testa, la sala libera per oltre 3 m. Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti` | -3.50, -9.05, 36.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.30 e 2.00 m sopra il pavimento (5 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: pannello degli strumenti appeso al muro sud della sala pompe, da 1,3 a 2,25 m: sporge 24 cm dal muro (era 36; profondità 0,24 m nel generatore), fissato al muro, non pende nel passaggio; davanti, alla testa, la sala libera per oltre 3 m. Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/SALA_ringhiera` | -2.75, -9.05, 36.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 1.10 m sopra il pavimento (6 celle da 25 cm) (pavimenti fra y -9.05 e -8.89), senza collisione (si attraversa) | voluto: i montanti in cima alla scaletta della vasca di raccolta (escono 25 cm dal bordo, fino a 0,9 m): si esce dalla vasca passandoci in mezzo; la ringhiera vera ha le sue scatole di collisione |

### torre

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoStruttura/ins_A_struttura` | 44.00, -34.00, -4.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (9 celle da 25 cm) (pavimenti fra y -34.00 e -25.58), con la collisione (ci si sbatte contro) | voluto: le celle sono dentro i tubi chiusi (sopra il tubo ci sono i suoi attacchi) e sulla scaletta di pioli del bacino, da dove si sale (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0` | 50.75, -22.58, -15.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (8 celle da 25 cm) (pavimento a y -22.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1` | 63.25, -25.58, -28.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (9 celle da 25 cm) (pavimento a y -25.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_2` | 69.50, -28.58, -7.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -28.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3` | 50.50, -34.00, -6.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (4 celle da 25 cm) (pavimento a y -34.00), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreScivoli/torre_tubo_inseguimento` | 38.00, -19.98, -16.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.40 e 2.00 m sopra il pavimento (6 celle da 25 cm) (pavimento a y -19.98), senza collisione (si attraversa) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |

## Copertura

Per ogni giro, quanti oggetti di scena si sono controllati in ogni parte. Una parte con 0 è una zona che il controllo non ha guardato.

| Giro | Parte | Oggetti controllati |
|---|---|---|
| sala_principale · inizio | `Gioco/EnigmaAcquari` | 195 |
| sala_principale · inizio | `Interni/Ambienti` | 180 |
| sala_principale · inizio | `Interni/LampadaTornelli` | 2 |
| sala_principale · inizio | `Interni/Meccanismi` | 1 |
| sala_principale · inizio | `Interni/Polaroid` | 3 |
| sala_principale · inizio | `Interni/Zaino` | 1 |
| sala_principale · inizio | `LuciSala/LuciAreaBimbi` | 92 |
| sala_principale · inizio | `Mascotte/InsegnaJilly` | 23 |
| sala_principale · inizio | `Mascotte/ManifestoJilly` | 4 |
| sala_principale · inizio | `Mascotte/StatuaPolpoA` | 1 |
| sala_principale · inizio | `Mascotte/StatuaPolpoB` | 1 |
| sala_principale · inizio | `Mascotte/StatuaSqualo` | 1 |
| sala_principale · inizio | `Mascotte/TargaJilly` | 1 |
| sala_principale · inizio | `Piscina/LucePortellone` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid04` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid05` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid06` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid07` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid08` | 1 |
| sala_principale · inizio | `Polaroid/Polaroid09` | 1 |
| sala_principale · inizio | `Risalita` | 197 |
| sala_principale · inizio | `Risalita/Corrimano` | 7 |
| sala_principale · inizio | `Risalita/lampada_emergenza` | 2 |
| sala_principale · inizio | `Sala/AngoloPalloni` | 129 |
| sala_principale · inizio | `Sala/AngoloScatoloni` | 148 |
| sala_principale · inizio | `Sala/AreaBimbi` | 4 |
| sala_principale · inizio | `Sala/Dettagli` | 852 |
| sala_principale · inizio | `Sala/Interattivi` | 8 |
| sala_principale · inizio | `Sala/Oggetti` | 68 |
| sala_principale · inizio | `Sala/Piscina` | 6 |
| sala_principale · inizio | `Sala/TorreScivoli` | 2 |
| sala_principale · inizio | `Sala/VascaCentrale` | 33 |
| sala_principale · inizio | `Tecnici/Ambienti` | 467 |
| sala_principale · inizio | `Tecnici/LampeggianteParatia1` | 2 |
| sala_principale · inizio | `Tecnici/Logica` | 38 |
| sala_principale · inizio | `Vasca/Medusa` | 9 |
| sala_torre · inizio | `FondoPozzo` | 1 |
| sala_torre · inizio | `Luci` | 358 |
| sala_torre · inizio | `Polaroid10/Modello` | 1 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoMobili` | 10 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoProp` | 4 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoTubi` | 7 |
| sala_torre · inizio | `SalaInseguimento/Luci` | 71 |
| sala_torre · inizio | `TorreProp` | 23 |
| sala_torre · inizio | `TorreScivoli` | 20 |
| sala_principale · interni_dopo | `Interni/Ambienti` | 180 |
| sala_principale · interni_dopo | `Interni/LampadaTornelli` | 2 |
| sala_principale · interni_dopo | `Interni/Meccanismi` | 1 |
| sala_principale · interni_dopo | `Interni/Polaroid` | 3 |
| sala_principale · interni_dopo | `Interni/Zaino` | 1 |
| sala_principale · lei_fossa | `Gioco/LeiSbuca` | 9 |
| sala_principale · risalita_arrivo | `Risalita` | 197 |
| sala_principale · risalita_arrivo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_arrivo | `Risalita/Fiume` | 259 |
| sala_principale · risalita_arrivo | `Risalita/Infermeria` | 121 |
| sala_principale · risalita_arrivo | `Risalita/lampada_emergenza` | 2 |
| sala_principale · risalita_dopo | `Risalita` | 197 |
| sala_principale · risalita_dopo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_dopo | `Risalita/Fiume` | 259 |
| sala_principale · risalita_dopo | `Risalita/Infermeria` | 177 |
| sala_principale · risalita_dopo | `Risalita/lampada_emergenza` | 2 |
| sala_principale · tappa7 | `Interni/Ambienti` | 2 |
| sala_principale · tappa7 | `Sala/Interattivi` | 1 |
| sala_principale · tappa7 | `Tecnici/Ambienti` | 2 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoMobili` | 10 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoProp` | 4 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoTubi` | 7 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/Luci` | 71 |
| sala_principale · acquari_comparsi | `Gioco/EnigmaAcquari` | 197 |
| sala_principale · acquari_comparsi | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_comparsi | `Sala/Interattivi` | 1 |
| sala_principale · acquari_risolti | `Gioco/EnigmaAcquari` | 197 |
| sala_principale · acquari_risolti | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_risolti | `Sala/Interattivi` | 1 |

### Parti nascoste all'inizio

Le parti nascoste nel giro iniziale (compaiono più avanti, o sono le versioni spente o accese di una luce, o effetti). "Controllata nello stato" vuol dire che un giro con stato le ha viste visibili; "mai controllata" va guardato.

| Scena | Parte nascosta | Mesh | Controllata |
|---|---|---|---|
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1345` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1346` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1347` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1348` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1349` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1350` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Acqua/Surface` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Graybox/Superficie` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Vetro/Volume` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Acqua/Surface` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Graybox/Superficie` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Vetro/Volume` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Acqua/Surface` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Graybox/Superficie` | 1 | no: segnaposto graybox, al suo posto si vede il modello vero |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Vetro/Volume` | 1 | no: variante nello stesso posto di una parte controllata |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa` | 12 | sì, in uno stato |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Gioco/LeiSbuca/SchizzoCoda/Corona` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/LeiSbuca/SchizzoCoda/Schiuma` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/LeiSbuca/SchizzoTesta/Corona` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/LeiSbuca/SchizzoTesta/Schiuma` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Corridoio/acqua_pozze_corridoio` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Spogliatoi/acqua_lavapiedi` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Spogliatoi/acqua_pozze_spogliatoi` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Interni/Ambienti/Stanzino/acqua_pozza_stanzino` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `LuciSala/@Node3D@1392/@MeshInstance3D@1393` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1392/@MeshInstance3D@1394` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1392/@MeshInstance3D@1395` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1392/@MeshInstance3D@1396` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1398/@MeshInstance3D@1399` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1398/@MeshInstance3D@1400` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1398/@MeshInstance3D@1401` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1398/@MeshInstance3D@1402` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1404/@MeshInstance3D@1405` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1404/@MeshInstance3D@1406` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1404/@MeshInstance3D@1407` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1404/@MeshInstance3D@1408` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1410/@MeshInstance3D@1411` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1410/@MeshInstance3D@1412` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1410/@MeshInstance3D@1413` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1410/@MeshInstance3D@1414` | 1 | **mai controllata** |
| sala_principale | `Player/Head/Camera3D/EffettoSottacqua/UnderwaterQuad` | 1 | **mai controllata** |
| sala_principale | `Player/Head/Camera3D/ViewModel` | 13 | **mai controllata** |
| sala_principale | `Player/WaterPack/Aspirazione` | 2 | **mai controllata** |
| sala_principale | `Player/WaterPack/GettoPotente/@MeshInstance3D@1682` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Risalita/Fiume` | 378 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria` | 177 | sì, in uno stato |
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
| sala_principale | `Tecnici/Ambienti/SalaPompe/ACQUA_vasca_raccolta` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@103` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@104` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@105` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@106` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@107` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@102/@MeshInstance3D@108` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@111` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@112` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@113` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@114` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@115` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@110/@MeshInstance3D@116` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@119` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@120` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@121` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@122` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@123` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@118/@MeshInstance3D@124` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@127` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@128` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@129` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@130` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@131` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@126/@MeshInstance3D@132` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@87` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@88` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@89` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@90` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@91` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@86/@MeshInstance3D@92` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@100` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@95` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@96` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@97` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@98` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/@Node3D@94/@MeshInstance3D@99` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@79` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@80` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@81` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@82` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@83` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Gocce/@MeshInstance3D@84` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata0` | 2 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata1` | 3 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata2` | 2 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `BambinoBalconata3` | 3 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `SalaInseguimento/Lei` | 12 | no: creatura, si muove (la guarda il collaudo) |

