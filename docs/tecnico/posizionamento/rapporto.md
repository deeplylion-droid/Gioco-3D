# Controllo di posizionamento

Scritto da `godot/tests/controllo_posizionamento.gd` il 2026-10-22 21:40:26. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0.35 e 2.00 m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.

Nuovi: 53. Già noti (in `godot/tests/posizionamento_eccezioni.json`): 54. Eccezioni non più trovate: 9.

## Nuovi

### acquari

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_0` | 19.48, 0.90, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_0 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_1` | 19.48, 0.90, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_1 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_10` | 19.48, 2.60, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_10 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_11` | 19.48, 2.60, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_11 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_12` | 19.48, 2.94, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_12 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_13` | 19.48, 2.94, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_13 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_14` | 19.48, 3.28, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_14 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_15` | 19.48, 3.28, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_15 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_16` | 19.48, 3.62, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_16 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_17` | 19.48, 3.62, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_17 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_18` | 19.48, 3.96, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_18 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_19` | 19.48, 3.96, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_19 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_2` | 19.48, 1.24, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_2 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_20` | 19.48, 4.30, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_20 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_21` | 19.48, 4.30, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_21 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_22` | 19.48, 4.64, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_22 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_23` | 19.48, 4.64, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_23 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_24` | 19.48, 4.98, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_24 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_25` | 19.48, 4.98, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_25 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_26` | 19.48, 5.32, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_26 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_27` | 19.48, 5.32, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_27 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_28` | 19.48, 5.50, -18.11 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_28 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_29` | 19.48, 5.50, -17.77 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_29 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_3` | 19.48, 1.24, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_3 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_30` | 19.48, 5.50, -17.43 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_30 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_31` | 19.48, 5.50, -17.09 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_31 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_32` | 19.48, 5.50, -16.75 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_32 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_33` | 19.48, 5.50, -16.41 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_33 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_34` | 19.48, 5.50, -16.07 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_34 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_35` | 19.48, 5.50, -15.73 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_35 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_36` | 19.48, 5.50, -15.39 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_36 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_37` | 19.48, 5.50, -15.05 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_37 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_38` | 19.48, 5.50, -14.71 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_38 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_39` | 19.48, 5.50, -14.37 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_39 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_4` | 19.48, 1.58, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_4 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_40` | 19.48, 5.50, -14.03 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_40 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_41` | 19.48, 5.50, -13.69 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_41 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_42` | 19.48, 5.50, -13.35 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_42 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_43` | 19.48, 5.50, -13.01 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_43 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_44` | 19.48, 5.50, -12.67 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_44 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_45` | 19.48, 5.50, -12.33 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_45 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_46` | 19.48, 5.50, -11.99 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_46 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_5` | 19.48, 1.58, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_5 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_6` | 19.48, 1.92, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_6 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_7` | 19.48, 1.92, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_7 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_8` | 19.48, 2.26, -18.45 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_8 (stato: acquari_comparsi) |
| enigmi | compenetra | `Gioco/EnigmaAcquari/LampadePortone/Spente/Lampadine_9` | 19.48, 2.26, -11.55 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/LampadePortone/Accese/Lampada1/Modello_9 (stato: acquari_comparsi) |

### sala

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/AnelloVetro` | 5.70, 4.31, -22.30 | passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Coperchio/cilindro_coperchio per 4 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/BasamentoVetro` | 5.70, 1.55, -22.30 | passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base per 9 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/AnelloVetro` | 16.90, 4.31, -22.30 | passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Coperchio/cilindro_coperchio per 4 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/BasamentoVetro` | 16.90, 1.55, -22.30 | passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base per 9 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/Disegno/Modello` | 17.40, 2.90, -21.36 | passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Vetro/Vetri per 3 cm |
| ambienti-2 | compenetra | `Sala/Dettagli/det_foglio_2_7` | 14.00, 0.02, 18.06 | il 23% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_9 |

## Già noti

### interni

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-1 | compenetra | `Interni/Ambienti/Corridoio/neon_corridoio_2_neon/neon_corridoio_2_tubo_sfarfalla` | 0.30, 2.48, 39.60 | il 87% dei suoi vertici è dentro Interni/Ambienti/Corridoio/neon_corridoio_2 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-1 | compenetra | `Interni/Ambienti/Spogliatoi/neon_spogliatoi_1_neon/neon_spogliatoi_1_tubo_sfarfalla` | -2.70, 2.85, 35.90 | il 68% dei suoi vertici è dentro Interni/Ambienti/Spogliatoi/neon_spogliatoi_1 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-1 | compenetra | `Interni/Ambienti/Stanzino/neon_stanzino_neon/neon_stanzino_tubo_sfarfalla` | 3.50, 2.39, 32.50 | il 68% dei suoi vertici è dentro Interni/Ambienti/Stanzino/neon_stanzino | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_rotore` | 0.00, 0.00, 25.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (2 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_telaio` | -0.75, 0.00, 25.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (6 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) | voluto: si passa dal tornello: il rotore gira quando lo spingi, come una porta |

### sala

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/Allacci/BeccoCorpo` | 7.75, 1.15, -22.47 | il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/Allacci/Gamba` | 7.33, 0.24, -22.37 | passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base per 3 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base per 3 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/Allacci/PompaSerbatoio` | 4.34, 0.94, -22.38 | il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/Allacci/PompaSerbatoioCollare` | 4.49, 0.94, -22.38 | il 22% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 22% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/Allacci/Spina` | 7.75, 0.26, -22.45 | passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base per 4 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base per 4 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioBlu/Allacci/Zoccolo` | 3.79, 0.21, -22.33 | il 25% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 25% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/BeccoCorpo` | 18.95, 1.15, -22.47 | il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/Gamba` | 18.53, 0.24, -22.37 | passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base per 3 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base per 3 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/PompaSerbatoio` | 15.54, 0.94, -22.38 | il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 45% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/PompaSerbatoioCollare` | 15.69, 0.94, -22.38 | il 22% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 22% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/Spina` | 18.95, 0.26, -22.45 | passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base per 4 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base per 4 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/Zoccolo` | 14.99, 0.21, -22.33 | il 25% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 25% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/FlangiaGamba` | 13.76, 0.01, -21.81 | il 41% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 41% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/FlangiaSpina` | 14.38, 0.01, -21.93 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/Gamba` | 13.76, 0.24, -21.81 | passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 3 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 3 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/PompaSerbatoioCollare` | 9.65, 0.60, -21.81 | passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 5 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 5 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/Spina` | 14.38, 0.26, -21.93 | passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 4 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 4 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/TuboSerbatoio` | 13.31, 0.60, -21.81 | passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 16 cm | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): passa dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa per 16 cm |
| enigmi | compenetra | `Gioco/EnigmaAcquari/AcquarioMisto/Allacci/Zoccolo` | 8.63, 0.21, -21.75 | il 25% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 25% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| enigmi | compenetra | `Gioco/EnigmaAcquari/Cavo/Fascetta1` | 6.57, 1.72, -21.44 | il 50% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Tirante1 | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 50% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Tirante1 |
| enigmi | compenetra | `Gioco/EnigmaAcquari/Cavo/Fascetta2` | 6.57, 1.95, -21.44 | il 50% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Tirante1 | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): il 50% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Tirante1 |
| mascotte | compenetra | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa` | -13.82, -0.28, -6.90 | passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 41 cm (stato: lei_fossa) | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 41 cm (stato: lei_fossa) |
| mascotte | compenetra | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | -13.24, -0.06, -6.85 | passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 116 cm (stato: lei_fossa) | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 116 cm (stato: lei_fossa) |
| mascotte | compenetra | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa` | 0.00, 0.50, 11.26 | il 35% dei suoi vertici è dentro Sala/VascaCentrale/sala_vasca_centrale | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): il 35% dei suoi vertici è dentro Sala/VascaCentrale/sala_vasca_centrale |
| mascotte | compenetra | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Interno` | 0.00, 0.15, 11.19 | il 77% dei suoi vertici è dentro Sala/VascaCentrale/sala_vasca_centrale | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): il 77% dei suoi vertici è dentro Sala/VascaCentrale/sala_vasca_centrale |
| enigmi | ingombro | `Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base` | 6.75, 0.00, -21.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.70 m sopra il pavimento (7 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.70 m sopra il pavimento (9 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/AcquarioBlu/Tirante3` | 4.75, 0.00, -23.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.50 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.50 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) |
| enigmi | ingombro | `Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base` | 16.75, 0.00, -21.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.70 m sopra il pavimento (7 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) | da correggere: controllo del 22 ottobre sera (gli acquari prima erano presi per acqua e non si controllavano): nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.70 m sopra il pavimento (9 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) |
| mascotte | ingombro | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | -13.00, 0.00, -5.25 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.59 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: lei_fossa) | da correggere: controllo del 22 ottobre sera (mesh con scheletro misurate nella posa del momento, non in quella di riposo): nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.59 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: lei_fossa) |
| ambienti-1 | ingombro | `Sala/AreaBimbi/sala_struttura_gioco` | -15.50, 0.00, -19.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (74 celle da 25 cm) (pavimento a y -0.00), con la collisione (ci si sbatte contro) | voluto: struttura per bambini: i tettucci e le sbarre stanno all'altezza della testa di un adulto, ci si urta come contro un muro e si passa accovacciati (scelta dell'utente, 22 ottobre) |

### tecnici

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/neon_0_neon/neon_0_tubi` | -0.60, -4.90, 5.36 | il 90% dei suoi vertici è dentro Tecnici/Ambienti/CameraOnde/plafoniera_0 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/neon_1_neon/neon_1_tubo_sfarfalla` | -0.60, -4.90, 11.36 | il 87% dei suoi vertici è dentro Tecnici/Ambienti/CameraOnde/plafoniera_1 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/neon_2_neon/neon_2_tubi` | -0.60, -4.90, 21.21 | il 87% dei suoi vertici è dentro Tecnici/Ambienti/CameraOnde/plafoniera_2 | voluto: il tubo del neon sta dentro la sua plafoniera |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/neon_rc_neon/neon_rc_tubo_sfarfalla` | -0.90, -6.30, 49.86 | il 81% dei suoi vertici è dentro Tecnici/Ambienti/Raccordo/plafoniera_rc | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_0_neon/neon_0_tubi` | 1.20, -4.22, 34.16 | il 77% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_0 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_1_neon/neon_1_tubo_sfarfalla` | 1.20, -4.22, 39.16 | il 77% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_1 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_2_neon/neon_2_tubi` | 1.20, -4.22, 43.66 | il 77% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_2 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_3_neon/neon_3_tubi` | 5.70, -4.22, 39.16 | il 68% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_3 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | ingombro | `Tecnici/Ambienti/CameraOnde/CAMERA_bocchette` | -1.75, -9.05, 15.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.58 e 2.00 m sopra il pavimento (12 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: bocchette dell'aria sul muro sud della camera delle onde (da 1,65 m), ora con la collisione: ci si ferma contro come contro il muro. Se non va bene: alzarle di 40 cm in ambienti2_camera_onde.py |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico` | -3.25, -9.05, 33.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.90 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: quadro elettrico appeso al muro sud della sala pompe, ora con la collisione: ci si ferma contro come contro il muro; non è su una strada o una scala |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti` | -3.50, -9.05, 36.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.30 e 2.00 m sopra il pavimento (4 celle da 25 cm) (pavimento a y -9.05), con la collisione (ci si sbatte contro) | voluto: pannello degli strumenti appeso al muro sud della sala pompe, ora con la collisione: ci si ferma contro come contro il muro; non è su una strada o una scala |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/SALA_ringhiera` | -2.75, -9.05, 36.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dal giocatore, fra 0.35 e 1.10 m sopra il pavimento (6 celle da 25 cm) (pavimenti fra y -9.05 e -8.89), senza collisione (si attraversa) | voluto: i montanti in cima alla scaletta della vasca di raccolta (escono 25 cm dal bordo, fino a 0,9 m): si esce dalla vasca passandoci in mezzo; la ringhiera vera ha le sue scatole di collisione |

### torre

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoStruttura/ins_A_struttura` | 44.00, -34.00, -4.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -34.00), con la collisione (ci si sbatte contro) | voluto: le celle sono dentro i tubi chiusi (sopra il tubo ci sono i suoi attacchi) e sulla scaletta di pioli del bacino, da dove si sale (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0` | 50.50, -22.58, -14.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -22.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1` | 63.00, -25.58, -27.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (6 celle da 25 cm) (pavimento a y -25.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_2` | 69.50, -28.58, -7.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -28.58), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3` | 50.75, -34.00, -6.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm) (pavimento a y -34.00), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreScivoli/torre_tubo_inseguimento` | 38.00, -19.98, -16.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.40 e 2.00 m sopra il pavimento (5 celle da 25 cm) (pavimento a y -19.98), senza collisione (si attraversa) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreStruttura/torre_A_sostegni` | 38.00, -19.98, -16.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.68 e 2.00 m sopra il pavimento (6 celle da 25 cm) (pavimento a y -19.98), senza collisione (si attraversa) | voluto: celle dentro il tubo dell'inseguimento, e il collare sotto la coda del tratto 5, 1,93 m sopra il terzo gradino della bocca, sul bordo est della salita (ambienti-2, 22 ottobre) |

## Copertura

Per ogni giro, quanti oggetti di scena si sono controllati in ogni parte. Una parte con 0 è una zona che il controllo non ha guardato.

| Giro | Parte | Oggetti controllati |
|---|---|---|
| sala_principale · inizio | `Gioco/EnigmaAcquari` | 199 |
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
| sala_principale · inizio | `Sala/Dettagli` | 854 |
| sala_principale · inizio | `Sala/Interattivi` | 8 |
| sala_principale · inizio | `Sala/Piscina` | 6 |
| sala_principale · inizio | `Sala/TorreScivoli` | 2 |
| sala_principale · inizio | `Sala/VascaCentrale` | 33 |
| sala_principale · inizio | `Tecnici/Ambienti` | 441 |
| sala_principale · inizio | `Tecnici/LampeggianteParatia1` | 2 |
| sala_principale · inizio | `Tecnici/Logica` | 38 |
| sala_principale · inizio | `Vasca/Medusa` | 9 |
| sala_torre · inizio | `FondoPozzo` | 1 |
| sala_torre · inizio | `Luci` | 358 |
| sala_torre · inizio | `Polaroid10/Modello` | 1 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoMobili` | 10 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoProp` | 4 |
| sala_torre · inizio | `SalaInseguimento/InseguimentoTubi` | 7 |
| sala_torre · inizio | `SalaInseguimento/Luci` | 76 |
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
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoMobili` | 10 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoProp` | 4 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/InseguimentoTubi` | 7 |
| sala_torre · inseguimento_dopo | `SalaInseguimento/Luci` | 76 |
| sala_principale · acquari_comparsi | `Gioco/EnigmaAcquari` | 248 |
| sala_principale · acquari_comparsi | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_comparsi | `Sala/Interattivi` | 1 |
| sala_principale · acquari_risolti | `Gioco/EnigmaAcquari` | 248 |
| sala_principale · acquari_risolti | `Gioco/PortoneTorre` | nessuna mesh (solo logica) |
| sala_principale · acquari_risolti | `Sala/Interattivi` | 1 |

### Parti nascoste all'inizio

Le parti nascoste nel giro iniziale (compaiono più avanti, o sono le versioni spente o accese di una luce, o effetti). "Controllata nello stato" vuol dire che un giro con stato le ha viste visibili; "mai controllata" va guardato.

| Scena | Parte nascosta | Mesh | Controllata |
|---|---|---|---|
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1341` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1342` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1343` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1344` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1345` | 1 | no: effetto o acqua, esclusi |
| sala_principale | `Atmosfera/GocceNellaPozza/@MeshInstance3D@1346` | 1 | no: effetto o acqua, esclusi |
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
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1389` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1390` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1391` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1388/@MeshInstance3D@1392` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1395` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1396` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1397` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1394/@MeshInstance3D@1398` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1401` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1402` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1403` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1400/@MeshInstance3D@1404` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1407` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1408` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1409` | 1 | **mai controllata** |
| sala_principale | `LuciSala/@Node3D@1406/@MeshInstance3D@1410` | 1 | **mai controllata** |
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

## Eccezioni non più trovate (si possono togliere dal file)

- sala · staccato · `Gioco/EnigmaAcquari/AcquarioGiallo/Tirante2`
- sala · staccato · `Gioco/EnigmaAcquari/AcquarioGiallo/Tirante4`
- sala · staccato · `Gioco/EnigmaAcquari/AcquarioBlu/Tirante2`
- sala · staccato · `Gioco/EnigmaAcquari/AcquarioBlu/Tirante4`
- sala · compenetra · `Gioco/EnigmaAcquari/AcquarioGiallo/Tirante1`
- sala · compenetra · `Gioco/EnigmaAcquari/AcquarioBlu/Tirante1`
- risalita · staccato · `Risalita/@MeshInstance3D@703`
- sala · compenetra · `Sala/AngoloScatoloni/scat_3_0_0`
- sala · compenetra · `Sala/VascaCentrale/ogg_salvagente_nave_36`
