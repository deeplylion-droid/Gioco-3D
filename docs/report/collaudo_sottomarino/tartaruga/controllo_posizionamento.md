# Controllo di posizionamento

Scritto da `godot/tests/controllo_posizionamento.gd` il 2026-10-24 19:46:51. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0.35 e 2.00 m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.

Nuovi: 6. Già noti (in `godot/tests/posizionamento_eccezioni.json`): 1. Eccezioni non più trovate: 42.

## Nuovi

### sottomarino

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| da assegnare | compenetra | `ArrediA1/Pesci/mensola_pesce_5` | -5.10, -27.79, 0.49 | passa dentro Luci/@Node3D@369/@MeshInstance3D@370 per 10 cm (nel pieno, per esempio, in (-5.13, -27.9, 0.57)) (stato: sottomarino_t0) |
| da assegnare | compenetra | `ArrediA1/Pesci/mensola_pesce_8` | -15.25, -27.79, -2.26 | passa dentro Luci/@Node3D@379/@MeshInstance3D@380 per 10 cm (nel pieno, per esempio, in (-15.2, -27.9, -2.15)) (stato: sottomarino_t0) |
| da assegnare | staccato | `ArrediA1/Pesci/pesce_0/Mesh_0` | -3.01, -27.05, 29.91 | la sua forma sfiora ArrediA1/Pesci/mensola_pesce_0, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) (stato: sottomarino_t0) |
| da assegnare | staccato | `ArrediA1/Pesci/pesce_1/Mesh_0` | -3.01, -27.05, 23.91 | la sua forma sfiora ArrediA1/Pesci/mensola_pesce_1, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) (stato: sottomarino_t0) |
| da assegnare | staccato | `ArrediA1/Pesci/pesce_2/Mesh_0` | -3.01, -27.05, 17.91 | la sua forma sfiora ArrediA1/Pesci/mensola_pesce_2, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) (stato: sottomarino_t0) |
| da assegnare | staccato | `ArrediA1/Pesci/pesce_3/Mesh_0` | -3.01, -27.05, 11.91 | la sua forma sfiora ArrediA1/Pesci/mensola_pesce_3, ma la mesh vera non lo tocca: fra i due più di 5 mm (distanza vera, vertice contro faccia; sotto, il primo appoggio è a 0.0 cm) (stato: sottomarino_t0) |

## Già noti

### sottomarino

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| da assegnare | compenetra | `Ostacolo_vetrina_484/corallo/Mesh_0` | -62.02, -29.16, 88.12 | il 100% dei suoi vertici è dentro Ostacolo_vetrina_484/@MeshInstance3D@800 (stato: sottomarino_t0) | voluto: il corallo del diorama sta dentro la teca di vetro della vetrina caduta, appoggiato sulla sabbia del fondo: il vetro è una scatola chiusa e lo contiene tutto (tunnel sottomarino, 24 ottobre) |

## Copertura

Per ogni giro, quanti oggetti di scena si sono controllati in ogni parte. Una parte con 0 è una zona che il controllo non ha guardato.

| Giro | Parte | Oggetti controllati |
|---|---|---|
| sala_sottomarino · sottomarino_t0 | `Approdo` | 18 |
| sala_sottomarino · sottomarino_t0 | `Approdo/PortelloPerno` | 12 |
| sala_sottomarino · sottomarino_t0 | `Approdo/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1` | 45 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/AbissoLampade` | 12 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/AbissoOblo` | 12 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Approdo` | 43 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/BucoVolta` | 8 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Pesci` | 138 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Reti` | 21 |
| sala_sottomarino · sottomarino_t0 | `ArrediA1/Tartaruga` | 15 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1006` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1019` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1060` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1074` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_1090` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_664` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_677` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_792` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_805` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_818` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_882` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_895` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_909` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_974` | 1 |
| sala_sottomarino · sottomarino_t0 | `Coralli/Corallo_988` | 1 |
| sala_sottomarino · sottomarino_t0 | `Galleria_205` | 16 |
| sala_sottomarino · sottomarino_t0 | `Galleria_205/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Galleria_425` | 16 |
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
| sala_sottomarino · sottomarino_t0 | `Luci` | 196 |
| sala_sottomarino · sottomarino_t0 | `Luci/Oblo` | 2 |
| sala_sottomarino · sottomarino_t0 | `Luci/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_cancello_268` | 7 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_cancello_268/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_carico_138` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_carico_138/ancora` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_carico_138/forziere` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_carico_138/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_74` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_crollo_74/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_macerie_348` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_macerie_348/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_vetrina_484` | 3 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_vetrina_484/corallo` | 1 |
| sala_sottomarino · sottomarino_t0 | `Ostacolo_vetrina_484/lampada_gabbia` | 2 |
| sala_sottomarino · sottomarino_t0 | `ParapettoPresa` | 32 |
| sala_sottomarino · sottomarino_t0 | `Relitto/Ancora` | 3 |
| sala_sottomarino · sottomarino_t0 | `Relitto/Forziere` | 1 |
| sala_sottomarino · sottomarino_t0 | `Relitto/Salvagente` | 1 |
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
| sala_sottomarino | `AcquaPresa/Surface` | 1 | no: effetto o acqua, esclusi |
| sala_sottomarino | `LeiTunnel/Lei` | 12 | no: creatura, si muove (la guarda il collaudo) |

## Eccezioni non più trovate (si possono togliere dal file)

- interni · ingombro · `Interni/Ambienti/Spogliatoi/tornello_telaio`
- interni · ingombro · `Interni/Ambienti/Spogliatoi/tornello_rotore`
- sala · ingombro · `Sala/AreaBimbi/sala_struttura_gioco`
- tecnici · ingombro · `Tecnici/Ambienti/SalaPompe/SALA_ringhiera`
- tecnici · ingombro · `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico`
- tecnici · ingombro · `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti`
- torre · ingombro · `SalaInseguimento/InseguimentoStruttura/ins_A_struttura`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_2`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1`
- torre · ingombro · `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0`
- torre · ingombro · `TorreScivoli/torre_tubo_inseguimento`
- sala · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_6`
- sala · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_4`
- sala · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_2`
- sala · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_5`
- sala · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_7`
- sala · ingombro · `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_3`
- tecnici · ingombro · `Tecnici/Ambienti/SalaPompe/ATTUATORE_stagno`
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
- risalita · compenetra · `Risalita/Fiume/paratia/Mesh_0`
- risalita · compenetra · `Risalita/Fiume/paratia4/Mesh_0`
- risalita · compenetra · `Risalita/Fiume/paratia5/Mesh_0`
