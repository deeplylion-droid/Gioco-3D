# Controllo di posizionamento

Scritto da `godot/tests/controllo_posizionamento.gd` il 2026-10-25 17:23:28. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0.35 e 2.00 m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.

Nuovi: 0. Già noti (in `godot/tests/posizionamento_eccezioni.json`): 63. Eccezioni non più trovate: 12.

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
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_telaio` | -0.75, 0.00, 25.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (12 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |

### risalita

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | compenetra | `Risalita/Fiume/paratia/Mesh_0` | -38.16, -5.40, 117.17 | dentro ci passa Risalita/Fiume/@MeshInstance3D@28046, 5 cm sotto la sua superficie (per esempio in (-38.16, -5.4, 117.17), lo spigolo da (-38.2, -5.4, 117.4) a (-38.13, -5.4, 117.0)) (stato: risalita_arrivo) | voluto: il telaio della chiusa a saracinesca, di traverso alla bocca del ramo, poggia sul bordo delle due sponde e ci entra con le guide, come una paratia vera |
| enigmi | compenetra | `Risalita/Fiume/paratia4/Mesh_0` | -55.75, -5.40, 93.60 | dentro ci passa Risalita/Fiume/@MeshInstance3D@28046, 3 cm sotto la sua superficie (per esempio in (-55.75, -5.4, 93.6), lo spigolo da (-56.0, -5.4, 93.6) a (-54.4, -5.4, 93.6)) (stato: risalita_arrivo) | voluto: il telaio della chiusa a saracinesca, di traverso alla bocca del ramo, poggia sul bordo delle due sponde e ci entra con le guide, come una paratia vera |
| enigmi | compenetra | `Risalita/Fiume/paratia5/Mesh_0` | -33.40, -5.40, 64.75 | dentro ci passa Risalita/Fiume/@MeshInstance3D@28046, 3 cm sotto la sua superficie (per esempio in (-33.4, -5.4, 64.75), lo spigolo da (-33.4, -5.4, 65.0) a (-33.4, -5.4, 63.0)) (stato: risalita_arrivo) | voluto: il telaio della chiusa a saracinesca, di traverso alla bocca del ramo, poggia sul bordo delle due sponde e ci entra con le guide, come una paratia vera |

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

### sottomarino

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| da assegnare | compenetra | `Ostacolo_vetrina_484/corallo/Mesh_0` | -62.02, -29.16, 88.12 | il 100% dei suoi vertici è dentro Ostacolo_vetrina_484/@MeshInstance3D@113918 (stato: sottomarino_t0) | voluto: il corallo del diorama sta dentro la teca di vetro della vetrina caduta, appoggiato sulla sabbia del fondo: il vetro è una scatola chiusa e lo contiene tutto (tunnel sottomarino, 24 ottobre) |
| da assegnare | ingombro | `Approdo/@MeshInstance3D@113205` | -62.00, -27.20, 23.00 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.18 e 1.22 m sopra il pavimento (15 celle da 25 cm) (pavimento a y -27.20), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: il corrimano della scala dell'approdo, a fianco di chi sale, all'altezza della mano |
| da assegnare | ingombro | `Approdo/PortelloPerno/@MeshInstance3D@113224` | -57.50, -27.00, 21.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.03 e 1.57 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -27.00), senza collisione (si attraversa) (stato: sottomarino_t0) | voluto: il battente del portello aperto dentro la camera stagna (è la porta stessa): il giocatore entra e lo chiude col volantino, poi la fine (24 ottobre, scelta 11A) |
| da assegnare | ingombro | `Galleria_205/@MeshInstance3D@113822` | -0.50, -30.00, 65.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (5 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_205/@MeshInstance3D@113824` | 1.75, -30.00, 55.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (4 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_205/@MeshInstance3D@113825` | 1.75, -30.00, 55.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (4 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_205/@MeshInstance3D@113828` | 0.00, -30.00, 60.75 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.21 e 1.25 m sopra il pavimento (8 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Galleria_205/@MeshInstance3D@113830` | 0.50, -30.00, 58.00 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.21 e 1.25 m sopra il pavimento (11 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Galleria_205/Fascia` | -0.50, -30.00, 65.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (5 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_205/struttura_mosaico` | 1.75, -30.00, 55.25 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 1.25 m sopra il pavimento (173 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Galleria_425/@MeshInstance3D@113893` | -22.75, -30.00, 117.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (11 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_425/@MeshInstance3D@113895` | -37.00, -30.00, 128.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (9 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_425/@MeshInstance3D@113896` | -37.00, -30.00, 128.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_425/@MeshInstance3D@113899` | -26.00, -30.00, 123.75 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.21 e 1.25 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Galleria_425/@MeshInstance3D@113901` | -30.75, -30.00, 127.25 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.21 e 1.25 m sopra il pavimento (9 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Galleria_425/Fascia` | -22.75, -30.00, 117.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.27 e 1.57 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la fascia gialla e nera sopra la bocca della galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati |
| da assegnare | ingombro | `Galleria_425/struttura_mosaico` | -37.00, -30.00, 128.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 1.25 m sopra il pavimento (367 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Tunnel_192/struttura_mosaico` | -1.00, -30.00, 64.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Tunnel_216/struttura_mosaico` | 1.75, -30.00, 55.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (7 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Tunnel_408/struttura_mosaico` | -22.75, -30.00, 118.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (21 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |
| da assegnare | ingombro | `Tunnel_432/struttura_mosaico` | -37.00, -30.00, 128.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (20 celle da 25 cm) (pavimento a y -30.00), con la collisione (ci si sbatte contro) (stato: sottomarino_t0) | voluto: la galleria di servizio bassa (1,25 m), passaggio basso voluto dall'utente (24 ottobre, scelta 4C): ci si passa accovacciati; i casi sono il soffitto basso, la fascia gialla e nera e le plafoniere sopra le bocche e dentro |

### tecnici

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3b_0` | -16.00, 2.35, 31.30 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 4 cm sotto la sua superficie (per esempio in (-16.0, 2.35, 31.3), lo spigolo da (-16.0, 0.01, 31.45) a (-16.0, 2.79, 31.27)) | voluto: i tubi lungo il muro passano nelle costole d'acciaio del corridoio come nei fori delle ordinate di una nave, con un collare di passaggio su ogni faccia della costola (scelta del coordinatore, 23 ottobre); le staffe sono fuori dalle costole |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3b_1` | -16.00, 2.34, 34.30 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 3 cm sotto la sua superficie (per esempio in (-16.0, 2.34, 34.3), lo spigolo da (-16.0, 0.01, 34.45) a (-16.0, 2.79, 34.27)) | voluto: i tubi lungo il muro passano nelle costole d'acciaio del corridoio come nei fori delle ordinate di una nave, con un collare di passaggio su ogni faccia della costola (scelta del coordinatore, 23 ottobre); le staffe sono fuori dalle costole |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3b_2` | -15.99, 2.33, 34.46 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 3 cm sotto la sua superficie (per esempio in (-15.99, 2.33, 34.46), lo spigolo da (-15.99, 2.79, 34.46) a (-15.99, 0.01, 34.46)) | voluto: i tubi lungo il muro passano nelle costole d'acciaio del corridoio come nei fori delle ordinate di una nave, con un collare di passaggio su ogni faccia della costola (scelta del coordinatore, 23 ottobre); le staffe sono fuori dalle costole |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_0` | -2.28, -6.90, 48.86 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 2 cm sotto la sua superficie (per esempio in (-2.28, -6.9, 48.86), lo spigolo da (-2.39, -9.04, 48.86) a (-2.25, -6.26, 48.86)) | voluto: i tubi lungo il muro passano nelle costole d'acciaio del corridoio come nei fori delle ordinate di una nave, con un collare di passaggio su ogni faccia della costola (scelta del coordinatore, 23 ottobre); le staffe sono fuori dalle costole |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_13` | -15.90, 0.95, 20.34 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 1 cm sotto la sua superficie (per esempio in (-15.9, 0.95, 20.34), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_14` | -15.90, 1.01, 20.34 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 1 cm sotto la sua superficie (per esempio in (-15.9, 1.01, 20.34), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_15` | -15.90, 1.08, 20.35 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 2 cm sotto la sua superficie (per esempio in (-15.9, 1.08, 20.35), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_16` | -15.90, 1.15, 20.35 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 2 cm sotto la sua superficie (per esempio in (-15.9, 1.15, 20.35), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_17` | -15.90, 1.22, 20.35 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 2 cm sotto la sua superficie (per esempio in (-15.9, 1.22, 20.35), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_18` | -15.90, 1.29, 20.35 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 2 cm sotto la sua superficie (per esempio in (-15.9, 1.29, 20.35), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_19` | -15.90, 1.37, 20.35 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 2 cm sotto la sua superficie (per esempio in (-15.9, 1.37, 20.35), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_20` | -15.90, 1.43, 20.35 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 2 cm sotto la sua superficie (per esempio in (-15.9, 1.43, 20.35), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_21` | -15.90, 1.50, 20.36 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 1 cm sotto la sua superficie (per esempio in (-15.9, 1.5, 20.36), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Lamelle_22` | -15.90, 1.57, 20.36 | dentro ci passa Tecnici/Ambienti/Raccordo/RACCORDO_dettagli, 1 cm sotto la sua superficie (per esempio in (-15.9, 1.57, 20.36), lo spigolo da (-15.9, 0.01, 20.32) a (-15.9, 2.49, 20.38)) | voluto: le lamelle della serranda alzata scorrono dentro le sue guide laterali, come in una serranda vera |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/ATTUATORE_stagno` | -2.50, -9.05, 47.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.20 e 1.52 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -9.05), senza collisione (si attraversa) | voluto: fissato al muro est della sala pompe accanto alla porta, a 1,2-1,52 m da terra: sporge 24,2 cm dal muro, staffa compresa (al più 25); non pende nel passaggio (staffa a muro); davanti, alla testa, 17,6 m liberi fino al muro ovest (almeno 80 cm). Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico` | -3.50, -9.05, 31.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.90 e 2.00 m sopra il pavimento (2 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: quadro elettrico appeso al muro sud della sala pompe, da 0,9 a 2,65 m: sporge 24 cm dal muro (era 56; profondità 0,24 m nel generatore), fissato al muro, non pende nel passaggio; davanti, alla testa, la sala libera per oltre 3 m. Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti` | -3.50, -9.05, 36.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 1.30 e 2.00 m sopra il pavimento (5 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: pannello degli strumenti appeso al muro sud della sala pompe, da 1,3 a 2,25 m: sporge 24 cm dal muro (era 36; profondità 0,24 m nel generatore), fissato al muro, non pende nel passaggio; davanti, alla testa, la sala libera per oltre 3 m. Regola del coordinatore per le cose a muro, 23 ottobre (ambienti-2) |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/SALA_ringhiera` | -2.75, -9.05, 36.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 1.10 m sopra il pavimento (6 celle da 25 cm) (pavimenti fra y -9.05 e -8.89), senza collisione (si attraversa) | voluto: i montanti in cima alla scaletta della vasca di raccolta (escono 25 cm dal bordo, fino a 0,9 m): si esce dalla vasca passandoci in mezzo; la ringhiera vera ha le sue scatole di collisione |

### torre

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoStruttura/ins_A_struttura` | 64.00, -25.58, -30.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (8 celle da 25 cm) (pavimento a y -25.58), senza collisione (si attraversa) | voluto: le celle sono dentro i tubi chiusi (sopra il tubo ci sono i suoi attacchi) e sulla scaletta di pioli del bacino, da dove si sale (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0` | 50.75, -22.58, -15.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (8 celle da 25 cm) (pavimento a y -22.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1` | 63.25, -25.58, -28.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (9 celle da 25 cm) (pavimento a y -25.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_2` | 69.50, -28.58, -7.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -28.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3` | 50.50, -34.00, -6.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dall'asse del giocatore (20 cm sopra 1,2 m), fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -34.00), senza collisione (si attraversa) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
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
| sala_principale · inizio | `Risalita` | 420 |
| sala_principale · inizio | `Risalita/Corrimano` | 7 |
| sala_principale · inizio | `Risalita/ObloFiume` | 3 |
| sala_principale · inizio | `Risalita/ObloPersonale` | 3 |
| sala_principale · inizio | `Risalita/ObloServizio` | 3 |
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
| sala_principale · inizio | `Tecnici/Ambienti` | 465 |
| sala_principale · inizio | `Tecnici/LampeggianteParatia1` | 2 |
| sala_principale · inizio | `Tecnici/Logica` | 38 |
| sala_principale · inizio | `Vasca/Medusa` | 9 |
| sala_torre · inizio | `FondoPozzo` | 1 |
| sala_torre · inizio | `Luci` | 358 |
| sala_torre · inizio | `ObloLei` | 4 |
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
| sala_principale · risalita_arrivo | `Risalita` | 420 |
| sala_principale · risalita_arrivo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_arrivo | `Risalita/Fiume` | 3890 |
| sala_principale · risalita_arrivo | `Risalita/Infermeria` | 166 |
| sala_principale · risalita_arrivo | `Risalita/ObloFiume` | 3 |
| sala_principale · risalita_arrivo | `Risalita/ObloPersonale` | 3 |
| sala_principale · risalita_arrivo | `Risalita/ObloServizio` | 3 |
| sala_principale · risalita_arrivo | `Risalita/lampada_emergenza` | 2 |
| sala_principale · risalita_dopo | `Risalita` | 420 |
| sala_principale · risalita_dopo | `Risalita/Corrimano` | 7 |
| sala_principale · risalita_dopo | `Risalita/Fiume` | 3890 |
| sala_principale · risalita_dopo | `Risalita/Infermeria` | 222 |
| sala_principale · risalita_dopo | `Risalita/ObloFiume` | 3 |
| sala_principale · risalita_dopo | `Risalita/ObloPersonale` | 3 |
| sala_principale · risalita_dopo | `Risalita/ObloServizio` | 3 |
| sala_principale · risalita_dopo | `Risalita/lampada_emergenza` | 2 |
| sala_principale · risalita_oblo | `Risalita/ObloFiume` | 12 |
| sala_principale · risalita_oblo | `Risalita/ObloPersonale` | 12 |
| sala_principale · risalita_oblo | `Risalita/ObloServizio` | 12 |
| sala_principale · tappa7 | `Interni/Ambienti` | 2 |
| sala_principale · tappa7 | `Sala/Interattivi` | 1 |
| sala_principale · tappa7 | `Tecnici/Ambienti` | 2 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoMobili` | 10 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoProp` | 4 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoTubi` | 7 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/Luci` | 71 |
| sala_torre · torre_oblo | `ObloLei` | 4 |
| sala_torre · torre_oblo | `ObloLei/Lei` | 9 |
| sala_principale · acquari_comparsi | `Gioco/EnigmaAcquari` | 197 |
| sala_principale · acquari_comparsi | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_comparsi | `Sala/Interattivi` | 1 |
| sala_principale · acquari_risolti | `Gioco/EnigmaAcquari` | 197 |
| sala_principale · acquari_risolti | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_risolti | `Sala/Interattivi` | 1 |
| sala_sottomarino · sottomarino_t0 | `Approdo` | 17 |
| sala_sottomarino · sottomarino_t0 | `Approdo/PortelloPerno` | 12 |
| sala_sottomarino · sottomarino_t0 | `Approdo/Telaio` | 5 |
| sala_sottomarino · sottomarino_t0 | `Approdo/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1` | 45 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/AbissoLampade` | 12 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/AbissoOblo` | 12 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Approdo` | 35 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/BucoVolta` | 8 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Pesci` | 132 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Reti` | 39 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Tartaruga` | 15 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1006` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1019` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1060` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1074` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1090` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_664` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_677` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_792` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_818` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_882` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_895` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_909` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_974` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_988` | 1 |
| sala_sottomarino · sottomarino_t0 | `Galleria_205` | 14 |
| sala_sottomarino · sottomarino_t0 | `Galleria_205/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Galleria_425` | 14 |
| sala_sottomarino · sottomarino_t0 | `Galleria_425/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_130` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_135` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_255` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_259` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_264` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_334` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_339` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_344` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_464` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_470` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_475` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_480` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_66` | 20 |
| sala_sottomarino · sottomarino_t0 | `Gommoni/Gommone_70` | 20 |
| sala_sottomarino · sottomarino_t0 | `Luci` | 198 |
| sala_sottomarino · sottomarino_t0 | `Luci/Oblo` | 2 |
| sala_sottomarino · sottomarino_t0 | `Luci/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_cancello_268` | 7 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_cancello_268/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_carico_138` | 3 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_carico_138/forziere` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_carico_138/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_203` | 6 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_203/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_423` | 6 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_423/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_74` | 6 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_74/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_macerie_348` | 9 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_macerie_348/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_vetrina_484` | 3 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_vetrina_484/corallo` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_vetrina_484/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `ParapettoPresa` | 32 |
| sala_sottomarino · sottomarino_t0 | `Relitto` | 1 |
| sala_sottomarino · sottomarino_t0 | `Relitto/Ancora` | 3 |
| sala_sottomarino · sottomarino_t0 | `Relitto/Forziere` | 1 |
| sala_sottomarino · sottomarino_t0 | `Relitto/Salvagente` | 1 |
| sala_sottomarino · sottomarino_t0 | `SalaPalombaro` | 1 |
| sala_sottomarino · sottomarino_t0 | `SalaPalombaro/Palombaro` | 1 |
| sala_sottomarino · sottomarino_t0 | `Testa` | 1 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_130` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_135` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_255` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_259` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_264` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_334` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_339` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_344` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_464` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_470` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_475` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_480` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_66` | 20 |
| sala_sottomarino · sottomarino_t1 | `Gommoni/Gommone_70` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_130` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_135` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_255` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_259` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_264` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_334` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_339` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_344` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_464` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_470` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_475` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_480` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_66` | 20 |
| sala_sottomarino · sottomarino_t2 | `Gommoni/Gommone_70` | 20 |

### Parti nascoste all'inizio

Le parti nascoste nel giro iniziale (compaiono più avanti, o sono le versioni spente o accese di una luce, o effetti). "Controllata nello stato" vuol dire che un giro con stato le ha viste visibili; "mai controllata" va guardato.

| Scena | Parte nascosta | Mesh | Controllata |
|---|---|---|---|
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@2115` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@2116` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@2117` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@2118` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@2119` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@2120` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Acqua/Surface` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Graybox/Superficie` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioBlu/Vetro/Volume` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Acqua/Surface` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Graybox/Superficie` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioGiallo/Vetro/Volume` | 1 | sì, in uno stato |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Acqua/Surface` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Graybox/Superficie` | 1 | no: segnaposto graybox, al suo posto si vede il modello vero |
| sala_principale | `Gioco/EnigmaAcquari/AcquarioMisto/Vetro/Volume` | 1 | no: variante nello stesso posto di una parte controllata |
| sala_principale | `Gioco/EnigmaAcquari/Valvola/GocceValvola` | 6 | no: effetto o acqua, esclusi |
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
| sala_principale | `LuciSala/@Node3D@2170/@MeshInstance3D@2171` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2170/@MeshInstance3D@2172` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2170/@MeshInstance3D@2173` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2170/@MeshInstance3D@2174` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2176/@MeshInstance3D@2177` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2176/@MeshInstance3D@2178` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2176/@MeshInstance3D@2179` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2176/@MeshInstance3D@2180` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2182/@MeshInstance3D@2183` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2182/@MeshInstance3D@2184` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2182/@MeshInstance3D@2185` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2182/@MeshInstance3D@2186` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2188/@MeshInstance3D@2189` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2188/@MeshInstance3D@2190` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2188/@MeshInstance3D@2191` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@2188/@MeshInstance3D@2192` | 1 | **mai controllata** |
| sala_principale | `Player/Head/Camera3D/EffettoSottacqua/UnderwaterQuad` | 1 | **mai controllata** |
| sala_principale | `Player/Head/Camera3D/ViewModel` | 13 | **mai controllata** |
| sala_principale | `Player/WaterPack/Aspirazione` | 2 | **mai controllata** |
| sala_principale | `Player/WaterPack/GettoPotente/@MeshInstance3D@2466` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Risalita/Fiume` | 568 | sì, in uno stato |
| sala_principale | `Risalita/Infermeria` | 234 | sì, in uno stato |
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
| sala_principale | `Risalita/ObloFiume/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloFiume/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloFiume/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloPersonale/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloPersonale/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloPersonale/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloServizio/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloServizio/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_principale | `Risalita/ObloServizio/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
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
| sala_torre | `ObloLei/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Denti` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `ObloLei/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Gola` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `ObloLei/Lei/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Strappo` | 1 | no: creatura, si muove (la guarda il collaudo) |
| sala_torre | `SalaInseguimento/Lei` | 12 | no: creatura, si muove (la guarda il collaudo) |
| sala_sottomarino | `AcquaPresa/Surface` | 1 | no: effetto o acqua, esclusi |
| sala_sottomarino | `LeiTunnel/Lei` | 12 | no: creatura, si muove (la guarda il collaudo) |

### MultiMesh non controllati

Senza le trasformazioni nel meta "trasformazioni" del nodo o della risorsa MultiMesh (vedi `_espandi_multimesh`):

- `sala_principale · SalaSottomarino/Approdo/Telaio/Rivetti`
- `sala_principale · SalaSottomarino/Approdo/Telaio/@MultiMeshInstance3D@102818`
- `sala_principale · SalaSottomarino/Approdo/PortelloPerno/Rivetti`
- `sala_sottomarino · Approdo/Telaio/Rivetti`
- `sala_sottomarino · Approdo/Telaio/@MultiMeshInstance3D@113219`
- `sala_sottomarino · Approdo/PortelloPerno/Rivetti`
- `sala_sottomarino · Approdo/Telaio/Rivetti`
- `sala_sottomarino · Approdo/Telaio/@MultiMeshInstance3D@116623`
- `sala_sottomarino · Approdo/PortelloPerno/Rivetti`
- `sala_sottomarino · Approdo/Telaio/Rivetti`
- `sala_sottomarino · Approdo/Telaio/@MultiMeshInstance3D@120027`
- `sala_sottomarino · Approdo/PortelloPerno/Rivetti`

## Eccezioni non più trovate (si possono togliere dal file)

- sottomarino · ingombro · `Approdo/PortelloPerno/@MeshInstance3D@241`
- sottomarino · ingombro · `Approdo/PortelloPerno/Battente/Lastra`
- sottomarino · ingombro · `Galleria_425/@MeshInstance3D@836`
- sottomarino · ingombro · `Galleria_425/@MeshInstance3D@837`
- sottomarino · ingombro · `Galleria_425/@MeshInstance3D@835`
- sottomarino · ingombro · `Galleria_425/@MeshInstance3D@830`
- sottomarino · ingombro · `Galleria_425/@MeshInstance3D@828`
- sottomarino · ingombro · `Galleria_425/@MeshInstance3D@831`
- sottomarino · ingombro · `Galleria_425/@MeshInstance3D@838`
- sottomarino · ingombro · `Galleria_205/@MeshInstance3D@805`
- sottomarino · ingombro · `Galleria_205/@MeshInstance3D@798`
- sottomarino · ingombro · `Galleria_205/@MeshInstance3D@800`
