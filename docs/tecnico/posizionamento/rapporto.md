# Controllo di posizionamento

Scritto da `godot/tests/controllo_posizionamento.gd` il 2026-10-22 15:48:32. Problemi: **sospeso** (niente a meno di 5 cm: né sotto, né una parete, un soffitto o un altro oggetto a cui sia attaccato), **ingombro** (qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0.35 e 2.00 m sopra il pavimento), **compenetrato** e **coperto** (Polaroid, pulsanti, porte, cancelli, oggetti da raccogliere), **compenetra** (due oggetti di scena l'uno dentro l'altro), **estremita_libera** (un tubo o un cavo con un capo che non tocca niente). Come si usa: `LEGGIMI.md` qui accanto.

Nuovi: 398. Già noti (in `godot/tests/posizionamento_eccezioni.json`): 54. Eccezioni non più trovate: 0.

## Nuovi

### interni

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| ambienti-1 | compenetra | `Interni/Ambienti/Stanzino/stanzino_statico` | 2.37, 1.30, 32.50 | passa dentro Interni/Ambienti/Spogliatoi/spogliatoi_statico per 90 cm |
| ambienti-1 | compenetra | `Interni/Meccanismi/PernoTurbina/turbina_saracinesca` | -0.91, 2.35, 21.50 | passa dentro Interni/Ambienti/Spogliatoi/spogliatoi_statico per 8 cm |
| ambienti-1 | compenetra | `Interni/Meccanismi/Saracinesca/Graybox/Pannello/@MeshInstance3D@6856` | 0.00, 1.10, 20.30 | il 50% dei suoi vertici è dentro Interni/Ambienti/Spogliatoi/spogliatoi_statico (stato: tutto_visibile) |
| ambienti-1 | compenetra | `Interni/Meccanismi/Saracinesca/Graybox/Pannello/@MeshInstance3D@6858` | 0.00, 1.65, 20.30 | il 50% dei suoi vertici è dentro Interni/Ambienti/Spogliatoi/spogliatoi_statico (stato: tutto_visibile) |
| ambienti-1 | compenetrato | `Interni/Meccanismi/Saracinesca` | 0.17, 1.10, 20.35 | entra dentro Interni/Ambienti/Spogliatoi/spogliatoi_statico (stato: tutto_visibile) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/asciugamano_corridoio` | -1.30, 0.26, 40.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/cestino` | -4.40, 0.27, 38.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/estintore` | -0.10, 1.15, 40.69 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 84.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/pallone` | -7.50, 0.21, 40.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/sprinkler_corridoio_1` | -7.90, 2.29, 38.78 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 224.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/sprinkler_corridoio_2` | -4.50, 2.29, 38.78 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 174.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/sprinkler_corridoio_3` | -1.10, 2.29, 38.78 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 224.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/sprinkler_corridoio_4` | 2.40, 2.29, 38.78 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 224.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/sprinkler_corridoio_5` | 5.90, 2.29, 38.78 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 224.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Corridoio/sprinkler_corridoio_6` | 9.30, 2.29, 38.78 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 224.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietti_est2_02_anta` | 0.69, 0.96, 30.53 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 18.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietti_est_01_anta` | 0.64, 0.96, 36.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 18.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietti_est_07_anta` | 0.73, 0.96, 34.56 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 18.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietti_est_09_giallo_anta` | 0.63, 0.96, 33.59 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 18.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietti_ovest_05_anta` | -6.14, 0.96, 35.44 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 18.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietti_ovest_11_anta` | -6.03, 0.96, 33.24 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 18.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietti_ovest_15_anta` | -6.18, 0.96, 31.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 18.3 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/armadietto_sbatte_anta` | 0.81, 0.96, 35.77 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 5.2 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/asciugamano_2` | -3.30, 0.26, 36.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/pallone_spogliatoi` | 0.50, 0.20, 30.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/sprinkler_lavapiedi_1` | 0.70, 2.49, 28.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 244.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/sprinkler_lavapiedi_2` | 0.70, 2.49, 24.10 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 244.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Spogliatoi/sprinkler_lavapiedi_3` | 0.70, 2.49, 21.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 244.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Stanzino/braccioli_stanzino` | 5.20, 2.07, 31.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Stanzino/estintore_stanzino` | 4.90, 1.13, 34.49 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 82.0 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Stanzino/salvagente_rastrelliera_1` | 4.82, 1.00, 33.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 64.1 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Stanzino/salvagente_rastrelliera_2` | 4.82, 1.00, 31.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 64.1 cm) |
| ambienti-1 | staccato | `Interni/Ambienti/Stanzino/sprinkler_stanzino_1` | 2.20, 2.24, 34.45 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 141.0 cm) |
| ambienti-1 | staccato | `Interni/Meccanismi/Saracinesca/Graybox/Pannello/@MeshInstance3D@6858` | 0.00, 1.65, 20.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.9 cm) (stato: tutto_visibile) |
| ambienti-1 | staccato | `Interni/Meccanismi/Saracinesca/Graybox/Spia` | 0.85, 1.90, 20.41 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 62.0 cm) (stato: tutto_visibile) |
| ambienti-1 | staccato | `Interni/Zaino/Modello/Zaino` | 4.78, 1.03, 32.47 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 72.0 cm) |

### mascotte

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| mascotte | staccato | `Mascotte/InsegnaJilly/cornice_giu` | -19.83, 4.20, 5.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 417.0 cm) |
| mascotte | staccato | `Mascotte/InsegnaJilly/cornice_su` | -19.83, 5.20, 5.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 94.0 cm) |
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_dx_lampadina` | -19.53, 5.39, 4.86 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_dx_paralume` | -19.52, 5.42, 4.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_sx_lampadina` | -19.53, 5.39, 5.84 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_sx_paralume` | -19.52, 5.42, 5.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/ManifestoJilly/Plane_001` | -19.97, 1.93, 14.24 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 189.0 cm) |

### risalita

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| enigmi | compenetra | `Risalita/@Node3D@841/Mesh_0` | -37.77, -3.20, 37.35 | passa dentro Risalita/@MeshInstance3D@764 per 20 cm |
| enigmi | staccato | `Risalita/@MeshInstance3D@692` | -35.00, -2.70, 49.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 260.0 cm) |
| enigmi | staccato | `Risalita/@MeshInstance3D@757` | -35.84, -3.01, 39.38 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 110.9 cm) |
| enigmi | staccato | `Risalita/@MeshInstance3D@813` | -30.14, -0.31, 39.38 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 110.9 cm) |
| enigmi | staccato | `Risalita/@MeshInstance3D@899` | 1.16, -2.56, 50.13 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 110.9 cm) |
| enigmi | staccato | `Risalita/@Node3D@839/Mesh_0` | -27.40, 2.20, 39.40 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 198.0 cm) |
| enigmi | staccato | `Risalita/@Node3D@841/Mesh_0` | -37.90, -3.20, 37.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 198.0 cm) |
| enigmi | staccato | `Risalita/@Node3D@953/Mesh_0` | 6.05, 0.40, 49.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 198.0 cm) |
| enigmi | staccato | `Risalita/@Node3D@955/Mesh_0` | -3.95, -3.20, 51.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 198.0 cm) |
| enigmi | staccato | `Risalita/@Node3D@957/Mesh_0` | -3.95, -3.20, 62.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 198.0 cm) |
| enigmi | staccato | `Risalita/lampada_emergenza/Mesh_0` | -34.05, -3.20, 49.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 198.0 cm) |

### sala

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| enigmi | compenetra | `Gioco/EnigmaAcquari/Valvola/Scarico` | 9.07, 0.00, -19.74 | passa dentro Gioco/EnigmaAcquari/Valvola/Modello/Mesh_0 per 16 cm |
| ambienti-1 | compenetra | `Gioco/LeiSbuca/SchizzoCoda/Schiuma` | 0.00, 0.01, 0.00 | passa dentro Gioco/LeiSbuca/SchizzoTesta/Corona per 131 cm (stato: tutto_visibile) |
| ambienti-1 | compenetra | `Gioco/LeiSbuca/SchizzoTesta/Corona` | 0.00, 0.00, 0.00 | il 43% dei suoi vertici è dentro Gioco/LeiSbuca/SchizzoCoda/Corona (stato: tutto_visibile) |
| ambienti-1 | compenetra | `Gioco/LeiSbuca/SchizzoTesta/Schiuma` | 0.00, 0.01, 0.00 | passa dentro Gioco/LeiSbuca/SchizzoCoda/Corona per 131 cm (stato: tutto_visibile) |
| ambienti-1 | compenetra | `Piscina/LucePortellone/Anello` | 0.00, -2.18, 2.02 | passa dentro Tecnici/Ambienti/CameraOnde/CAMERA_pozzo per 119 cm |
| ambienti-1 | compenetra | `Piscina/LucePortellone/Anello` | 0.00, -2.17, 2.02 | passa dentro Sala/Interattivi/sala_portello_scarico per 83 cm |
| ambienti-1 | compenetra | `Sala/Interattivi/sala_portello_scarico` | 0.00, -2.20, 2.02 | passa dentro Tecnici/Ambienti/CameraOnde/CAMERA_pozzo per 130 cm |
| ambienti-1 | compenetra | `Sala/Interattivi/sala_portello_scarico` | 0.00, -2.19, 2.02 | passa dentro Sala/Piscina/sala_piscina_onde per 38 cm |
| ambienti-1 | compenetrato | `Polaroid/Polaroid05` | 1.20, -2.17, 2.90 | entra dentro Sala/Piscina/sala_piscina_onde |
| ambienti-1 | estremita_libera | `Sala/Dettagli/det_tubo_muro_7cm_2m` | -2.18, 3.56, -23.92 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| ambienti-1 | ingombro | `Gioco/LeiSbuca/SchizzoCoda/Corona` | 0.50, -2.17, 0.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.60 e 2.00 m sopra il pavimento (22 celle da 25 cm), senza collisione (si attraversa) (stato: tutto_visibile) |
| ambienti-1 | ingombro | `Gioco/LeiSbuca/SchizzoCoda/Schiuma` | 1.50, -1.94, -1.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.91 e 1.98 m sopra il pavimento (30 celle da 25 cm), senza collisione (si attraversa) (stato: tutto_visibile) |
| ambienti-1 | ingombro | `Gioco/LeiSbuca/SchizzoTesta/Corona` | 0.50, -2.17, 0.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.45 e 2.00 m sopra il pavimento (248 celle da 25 cm), senza collisione (si attraversa) (stato: tutto_visibile) |
| ambienti-1 | ingombro | `Gioco/LeiSbuca/SchizzoTesta/Schiuma` | 1.50, -1.94, -1.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.91 e 1.98 m sopra il pavimento (30 celle da 25 cm), senza collisione (si attraversa) (stato: tutto_visibile) |
| enigmi | staccato | `Gioco/EnigmaAcquari/LampadaValvola/Modello/lampada` | 6.84, 2.25, -21.32 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 204.0 cm) |
| ambienti-1 | staccato | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` | -13.03, 4.34, -7.78 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 368.5 cm) (stato: tutto_visibile) |
| ambienti-1 | staccato | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | -12.95, 3.41, -7.82 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 207.2 cm) (stato: tutto_visibile) |
| grafica | staccato | `LuciSala/LuciAreaBimbi/PlafonieraBimbi/@MeshInstance3D@1533` | -11.92, 9.17, -14.74 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `LuciSala/LuciAreaBimbi/PlafonieraBimbi/@MeshInstance3D@1534` | -11.97, 9.07, -14.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_1` | 17.98, 1.25, 16.80 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 3.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_101` | 15.13, 1.35, 18.31 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 75.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_19` | 12.38, 0.43, 18.92 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_23` | 18.30, 0.38, 15.47 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_3` | 14.73, 0.74, 17.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 23.9 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_30` | 14.37, 0.36, 15.05 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_31` | 10.43, 0.44, 19.39 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_34` | 13.28, 0.46, 18.29 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_38` | 19.01, 1.49, 16.93 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 100.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_39` | 19.60, 0.11, 15.44 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_47` | 19.46, 0.82, 15.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 10.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_48` | 14.05, 0.35, 15.81 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_54` | 14.87, 1.76, 19.13 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 50.9 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_62` | 19.41, 4.35, 19.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 33.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_67` | 17.56, 0.47, 14.49 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_69` | 18.73, 0.82, 16.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 11.9 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_70` | 18.69, 0.25, 16.49 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_71` | 13.66, 0.47, 16.46 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_72` | 17.09, 0.85, 16.49 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 20.8 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_80` | 16.17, 1.62, 17.75 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 109.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_83` | 13.99, 1.01, 17.41 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 40.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_93` | 18.39, 0.40, 14.69 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_96` | 15.09, 1.59, 17.44 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_0` | 19.43, 0.40, 19.46 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_11` | 16.34, 0.40, 18.69 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_12` | 14.75, 0.40, 18.66 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_17` | 19.45, 0.40, 17.11 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_20` | 19.07, 1.04, 19.04 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 47.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_21` | 18.25, 1.04, 19.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 37.0 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_27` | 18.27, 1.04, 18.29 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 47.0 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_28` | 17.47, 1.04, 18.24 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 43.9 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_30` | 15.91, 1.04, 18.29 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 34.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_31` | 19.08, 1.04, 17.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 45.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_34` | 16.68, 1.04, 17.52 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 43.8 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_35` | 19.45, 1.68, 19.47 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 23.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_36` | 18.68, 1.68, 19.48 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 128.8 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_37` | 16.34, 1.68, 19.45 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 37.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_38` | 15.58, 1.68, 19.42 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 28.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_39` | 18.64, 1.68, 18.66 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.1 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_40` | 17.86, 1.68, 18.69 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 38.9 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_47` | 19.07, 2.32, 19.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 29.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_48` | 18.24, 2.32, 19.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_49` | 17.52, 2.32, 19.05 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 39.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_50` | 16.70, 2.32, 19.08 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 41.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_51` | 19.09, 2.32, 18.29 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 23.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_52` | 18.27, 2.32, 18.31 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 31.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_53` | 17.50, 2.32, 18.28 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 27.1 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_54` | 17.10, 2.96, 19.44 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 146.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_55` | 19.45, 2.96, 18.69 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 155.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_56` | 18.66, 2.96, 18.64 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 23.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_58` | 19.08, 3.60, 19.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 38.0 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_59` | 18.26, 3.60, 19.02 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 31.9 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_60` | 18.70, 4.24, 19.47 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 162.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloPalloni/pallone_dentro_7` | 19.43, 0.40, 18.67 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_0` | -19.52, 0.30, 19.36 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_10` | -19.43, 3.75, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_11` | -19.43, 4.28, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_12` | -19.43, 4.80, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_13` | -19.43, 5.33, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_14` | -19.43, 5.87, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_15` | -19.43, 6.41, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_16` | -19.43, 6.94, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_17` | -19.43, 7.48, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_20` | -19.43, 8.57, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_21` | -19.43, 9.10, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_3` | -19.43, 1.22, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_4` | -19.43, 1.55, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_6` | -19.43, 2.35, 19.42 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_0_7` | -19.43, 2.66, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_0` | -19.46, 0.27, 18.68 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_1` | -19.43, 0.59, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_10` | -19.43, 4.20, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_11` | -19.43, 4.75, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_12` | -19.43, 5.29, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_13` | -19.43, 5.83, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_15` | -19.43, 6.84, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_18` | -19.43, 7.93, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_19` | -19.43, 8.45, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_2` | -19.43, 0.91, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_3` | -19.43, 1.46, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_4` | -19.43, 1.99, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_7` | -19.43, 2.87, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_1_8` | -19.43, 3.19, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_0` | -19.40, 0.33, 17.69 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_1` | -19.42, 0.70, 17.68 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_10` | -19.43, 4.36, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_11` | -19.43, 4.91, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_2` | -19.43, 1.03, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_3` | -19.43, 1.35, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_4` | -19.43, 1.68, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_6` | -19.43, 2.71, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_8` | -19.43, 3.34, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_2_9` | -19.43, 3.85, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_3_0` | -19.51, 0.30, 16.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_3_1` | -19.43, 0.88, 16.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_3_2` | -19.43, 1.42, 16.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_3_3` | -19.41, 1.94, 16.89 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_0_3_4` | -19.43, 2.46, 16.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_1` | -18.58, 0.85, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_11` | -18.58, 5.51, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_16` | -18.58, 7.48, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_2` | -18.52, 1.39, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_4` | -18.58, 2.38, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_5` | -18.58, 2.91, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_7` | -18.58, 3.91, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_8` | -18.58, 4.22, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_0_9` | -18.58, 4.52, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_0` | -18.46, 0.28, 18.49 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_1` | -18.58, 0.82, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_12` | -18.58, 5.00, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_15` | -18.58, 6.08, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_16` | -18.58, 6.62, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_7` | -18.58, 2.70, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_8` | -18.58, 3.01, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_1_9` | -18.58, 3.55, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_0` | -18.64, 0.29, 17.63 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_1` | -18.58, 0.87, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_3` | -18.58, 1.91, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_4` | -18.58, 2.45, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_5` | -18.58, 3.02, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_6` | -18.58, 3.59, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.7 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_7` | -18.58, 3.93, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_8` | -18.58, 4.03, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_2_9` | -18.58, 4.37, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_3_0` | -18.56, 0.29, 16.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_3_2` | -18.58, 1.35, 16.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_1_3_3` | -18.58, 1.90, 16.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_1` | -17.73, 0.38, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_10` | -17.73, 4.57, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_12` | -17.73, 5.57, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_2` | -17.73, 0.94, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_5` | -17.73, 2.42, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_6` | -17.73, 2.96, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_7` | -17.73, 3.49, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_0_9` | -17.72, 4.26, 19.42 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_0` | -17.77, 0.31, 18.53 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_1` | -17.73, 0.93, 18.57 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.8 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_2` | -17.71, 1.52, 18.59 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.2 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_3` | -17.73, 2.10, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.1 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_5` | -17.73, 3.16, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_6` | -17.73, 3.73, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_7` | -17.73, 4.29, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_1_8` | -17.73, 4.80, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_2_0` | -17.67, 0.30, 17.76 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_2_1` | -17.73, 0.85, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_2_2` | -17.73, 1.39, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_2_4` | -17.73, 2.44, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_2_2_5` | -17.73, 2.99, 17.73 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_3_0_0` | -16.88, 0.32, 19.38 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_3_0_1` | -16.88, 0.90, 19.47 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_3_0_2` | -16.87, 1.45, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_3_0_4` | -16.87, 2.09, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_3_0_5` | -16.87, 2.63, 19.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_3_1_1` | -16.87, 0.88, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.3 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_3_1_2` | -16.88, 1.44, 18.58 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| ambienti-1 | staccato | `Sala/AngoloScatoloni/scat_caduto_2` | -16.80, 0.27, 17.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-1 | staccato | `Sala/AreaBimbi/sala_secchio_gigante` | -15.20, 6.28, -19.76 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 140.3 cm) |
| ambienti-1 | staccato | `Sala/Dettagli/@MeshInstance3D@40` | -17.43, 0.06, 3.24 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.1 cm) |
| ambienti-1 | staccato | `Sala/Dettagli/@MeshInstance3D@50` | 7.24, 2.81, -23.83 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 266.8 cm) |
| ambienti-1 | staccato | `Sala/Dettagli/@MeshInstance3D@51` | 19.81, 3.42, -3.40 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 327.2 cm) |
| ambienti-1 | staccato | `Sala/Dettagli/@MeshInstance3D@52` | -18.19, 3.42, -23.81 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 328.9 cm) |
| ambienti-1 | staccato | `Sala/Dettagli/det_faro` | -3.75, 3.33, -23.81 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 319.6 cm) |
| ambienti-1 | staccato | `Sala/Dettagli/det_faro_spento` | 5.38, 3.31, 19.83 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 276.6 cm) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_cestino_pesce_88` | -19.30, 0.51, 9.03 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_delfino_gonfiabile_sgonfio_8` | -4.20, -0.63, -6.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 10.7 cm) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_salvagente_nave_6` | 2.90, -1.94, 1.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.1 cm) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_tubi_galleggianti_52` | -8.21, 0.24, 5.51 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_tubi_galleggianti_58` | 8.93, 0.28, 5.75 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_tubi_galleggianti_64` | -4.90, -0.40, -8.87 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.3 cm) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_tubi_galleggianti_7` | -2.60, -1.87, 0.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 4.5 cm) |
| ambienti-1 | staccato | `Sala/Oggetti/ogg_tubi_galleggianti_70` | 5.65, 0.25, 17.02 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Sala/Piscina/sala_piscina_rosa_venti` | 0.00, -1.58, -3.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-1 | staccato | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` | 0.00, 4.89, 10.14 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 364.5 cm) |
| ambienti-1 | staccato | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | 0.02, 3.96, 10.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 203.1 cm) |

### tecnici

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/CAMERA_pozzo` | 0.00, -2.32, 2.00 | passa dentro Sala/Piscina/sala_piscina_onde per 30 cm |
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/PORTELLO` | 0.00, -2.32, 2.74 | il 70% dei suoi vertici è dentro Sala/Piscina/sala_piscina_onde (stato: tutto_visibile) |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_staffa1` | -2.26, -7.02, 49.86 | passa dentro Tecnici/Ambienti/Raccordo/lampada_rc1 per 23 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/RACCORDO_scale` | 3.83, -6.20, 46.31 | passa dentro Tecnici/Ambienti/SalaPompe/SALA_tubi per 50 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1` | -2.18, -6.94, 49.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_1 per 20 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1` | -2.31, -6.90, 49.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_0 per 34 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1_vetro` | -2.18, -6.94, 49.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_1 per 25 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1_vetro` | -2.29, -6.90, 49.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_0 per 26 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b` | -15.86, 2.16, 34.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_1 per 24 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b` | -15.92, 2.20, 34.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_0 per 34 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b_vetro` | -15.83, 2.16, 34.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_1 per 24 cm |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b_vetro` | -15.89, 2.20, 34.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_0 per 27 cm |
| ambienti-2 | compenetra | `Tecnici/Logica/SerrandaMagazzino/Barra` | -15.00, 0.02, 20.35 | passa dentro Tecnici/Logica/SerrandaMagazzino/Graybox/Pannello/@MeshInstance3D@7030 per 180 cm (stato: tutto_visibile) |
| ambienti-2 | staccato | `Tecnici/Ambienti/CameraOnde/ALBERO_pale` | 3.00, -5.60, 11.36 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 321.3 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/CameraOnde/BIELLA_3` | 2.90, -6.80, 15.36 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 175.9 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/CameraOnde/CAMERA_pale_supporti` | 2.95, -5.23, 11.66 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 5.2 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c2oa_3` | 4.48, -1.52, 45.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c2ob_10` | -4.39, 0.33, 45.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c2ob_17` | -9.38, 0.28, 45.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c3n_5` | -14.23, 0.27, 41.80 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c3n_9` | -14.23, 0.27, 35.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c3s_14` | -15.77, 0.27, 33.88 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c3s_7` | -15.77, 0.27, 41.05 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_festone_c2_filo` | -0.25, 2.42, 45.91 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 224.7 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_festone_mag_filo` | -15.00, 2.80, 25.45 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 249.3 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_festone_s1_filo` | 2.25, -4.10, 52.96 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 150.5 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_festone_s2_filo` | 7.80, -1.15, 51.41 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 239.4 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_l1e_2` | 6.11, -4.99, 53.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_l1e_7` | 8.68, -4.99, 53.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_mag_12` | -13.69, 0.28, 29.51 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_mag_14` | -13.69, 1.48, 29.51 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 70.6 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_mag_18` | -13.51, 0.35, 22.56 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_mag_4` | -16.49, 0.63, 24.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_mag_5` | -16.21, 0.41, 23.12 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_r1n_2` | -0.66, -8.75, 51.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_t_1` | 8.89, -0.76, 45.37 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.4 cm) |
| enigmi | staccato | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_staffa5` | -15.81, 2.08, 38.56 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 206.3 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/FILTRO_1_modello` | 6.60, -7.33, 31.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.0 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/FILTRO_2_modello` | 4.00, -7.33, 31.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.0 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/Foglio_det_carta_accartocciata_2` | -3.42, -8.22, 43.48 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/LEVA` | 5.10, -5.04, 47.46 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.5 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/POMPA_3_modello` | 5.05, -7.79, 42.16 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/PORTA_ponte` | -1.40, -7.95, 47.61 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| ambienti-2 | staccato | `Tecnici/Ambienti/SalaPompe/SCHEMA_pompe` | 2.60, -7.05, 47.63 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 135.0 cm) |
| ambienti-2 | staccato | `Tecnici/Logica/SerrandaMagazzino/Graybox/Pannello/@MeshInstance3D@7032` | -15.00, 1.88, 20.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 177.5 cm) (stato: tutto_visibile) |
| ambienti-2 | staccato | `Tecnici/Logica/SerrandaMagazzino/Graybox/Spia` | -13.85, 2.20, 20.51 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 214.0 cm) (stato: tutto_visibile) |

### torre

| Squadra | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| ambienti-2 | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_0` | 54.72, -21.91, -16.41 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_1 per 169 cm |
| ambienti-2 | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_1` | 54.72, -21.89, -13.60 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_scolo_0 per 170 cm |
| ambienti-2 | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_2` | 67.02, -24.90, -25.28 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_2 per 182 cm |
| ambienti-2 | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_3` | 63.92, -24.90, -25.28 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_scolo_1 per 117 cm |
| ambienti-2 | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_4` | 66.78, -27.92, -3.60 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_3 per 17 cm |
| ambienti-2 | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_5` | 72.22, -27.93, -6.60 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_scolo_2 per 148 cm |
| ambienti-2 | compenetra | `TorreScivoli/torre_tubo_inseguimento` | 40.82, -18.66, -17.40 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_0 per 11 cm |
| grafica | estremita_libera | `SalaInseguimento/Luci/@Node3D@5256/det_tubo_verticale_3m` | 40.49, -25.00, -28.50 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| grafica | estremita_libera | `SalaInseguimento/Luci/@Node3D@5256/det_tubo_verticale_3m` | 40.49, -22.00, -28.50 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| ambienti-2 | staccato | `FondoPozzo` | 31.00, -25.00, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 297.5 cm) |
| grafica | staccato | `Luci/@MeshInstance3D@4885` | 20.30, 6.00, -20.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 191.3 cm) |
| grafica | staccato | `Luci/@MeshInstance3D@4887` | 39.90, 1.50, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@4889` | 31.00, -2.50, -4.10 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@4891` | 31.00, -8.00, -25.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@4893` | 20.30, -12.00, -10.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@4895` | 39.90, -16.50, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 335.0 cm) |
| grafica | staccato | `Luci/@MeshInstance3D@4897` | 27.00, 9.00, -25.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@4934` | 31.00, 0.95, -25.65 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 5.0 cm) |
| grafica | staccato | `Luci/@MeshInstance3D@4937` | 31.00, 1.13, -25.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 260.5 cm) |
| grafica | staccato | `Luci/@MeshInstance3D@5027` | 26.65, -10.62, -10.55 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5035` | 32.55, 9.00, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5036` | 32.38, 9.00, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5037` | 32.03, 8.90, -14.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5038` | 32.11, 8.90, -14.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5039` | 32.03, 8.80, -15.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5040` | 32.11, 8.80, -15.15 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5042` | 32.55, -3.00, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5043` | 32.38, -3.00, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5044` | 32.03, -3.10, -14.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5045` | 32.11, -3.10, -14.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5046` | 32.03, -3.20, -15.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5047` | 32.11, -3.20, -15.15 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5049` | 32.55, -14.00, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5051` | 32.03, -14.10, -14.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5052` | 32.11, -14.10, -14.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5053` | 32.03, -14.20, -15.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@MeshInstance3D@5054` | 32.11, -14.20, -15.15 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@Node3D@4939/@MeshInstance3D@4940` | 26.95, 13.40, -19.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.0 cm) |
| grafica | staccato | `Luci/@Node3D@4939/@MeshInstance3D@4941` | 27.07, 13.31, -19.31 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 412.9 cm) |
| grafica | staccato | `Luci/@Node3D@4948/@MeshInstance3D@4949` | 26.71, 1.50, -19.08 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 126.3 cm) |
| grafica | staccato | `Luci/@Node3D@4948/@MeshInstance3D@4950` | 26.78, 1.43, -18.96 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 123.3 cm) |
| grafica | staccato | `Luci/@Node3D@4957/@MeshInstance3D@4958` | 26.66, -10.50, -19.05 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 126.4 cm) |
| grafica | staccato | `Luci/@Node3D@4957/@MeshInstance3D@4959` | 26.71, -10.57, -18.93 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 123.5 cm) |
| grafica | staccato | `Luci/@Node3D@4966/@MeshInstance3D@4967` | 35.06, 13.40, -19.33 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.1 cm) |
| grafica | staccato | `Luci/@Node3D@4966/@MeshInstance3D@4968` | 34.95, 13.31, -19.28 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@Node3D@4975/@MeshInstance3D@4976` | 35.05, 1.50, -19.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 426.4 cm) |
| grafica | staccato | `Luci/@Node3D@4975/@MeshInstance3D@4977` | 34.92, 1.43, -19.30 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 423.5 cm) |
| grafica | staccato | `Luci/@Node3D@4984/@MeshInstance3D@4985` | 35.34, 13.40, -10.95 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.1 cm) |
| grafica | staccato | `Luci/@Node3D@4984/@MeshInstance3D@4986` | 35.30, 13.31, -11.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 412.9 cm) |
| grafica | staccato | `Luci/@Node3D@4993/@MeshInstance3D@4994` | 35.39, 1.50, -10.97 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 126.2 cm) |
| grafica | staccato | `Luci/@Node3D@4993/@MeshInstance3D@4995` | 35.35, 1.42, -11.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 123.2 cm) |
| grafica | staccato | `Luci/@Node3D@5002/@MeshInstance3D@5003` | 26.62, 13.40, -10.96 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@Node3D@5002/@MeshInstance3D@5004` | 26.66, 13.32, -11.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@Node3D@5011/@MeshInstance3D@5012` | 26.98, 1.50, -10.57 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 426.3 cm) |
| grafica | staccato | `Luci/@Node3D@5011/@MeshInstance3D@5013` | 27.11, 1.43, -10.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 423.3 cm) |
| grafica | staccato | `Luci/@Node3D@5020/@MeshInstance3D@5021` | 26.93, -10.50, -10.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `Luci/@Node3D@5020/@MeshInstance3D@5022` | 27.05, -10.55, -10.77 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-2 | staccato | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0` | 45.55, -20.23, -16.19 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-2 | staccato | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1` | 58.64, -23.37, -22.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-2 | staccato | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3` | 58.80, -30.56, -4.44 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| ambienti-2 | staccato | `SalaInseguimento/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Bordo` | 0.00, 4.89, -0.01 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) (stato: tutto_visibile) |
| ambienti-2 | staccato | `SalaInseguimento/Lei/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | 0.02, 3.96, -0.09 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) (stato: tutto_visibile) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5148` | 40.55, -16.00, -25.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 333.5 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5150` | 77.85, -22.00, -10.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5152` | 60.00, -18.00, -31.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5154` | 50.00, -26.00, 1.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5156` | 70.00, -14.00, 1.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5169` | 54.61, -21.43, -16.40 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 59.8 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5177` | 67.00, -24.43, -25.39 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 59.8 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5185` | 66.89, -27.43, -3.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 59.8 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5190` | 40.64, -27.35, -5.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 254.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5193` | 51.50, -16.50, -7.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5197` | 61.50, -17.50, -17.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5201` | 70.50, -18.50, -24.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5205` | 45.00, -19.00, -22.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5209` | 43.80, -17.00, -28.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5213` | 61.00, -23.50, -9.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 6.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5227/POMPA_1` | 50.00, -30.27, -23.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5228/POMPA_2` | 54.40, -30.27, -23.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5229/POMPA_3` | 67.00, -30.27, -14.50 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5229/POMPA_3_modello` | 67.20, -31.24, -14.77 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5230/det_pannello_lamiera` | 48.60, -32.63, -22.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5231/FILTRO_1_modello` | 52.80, -31.37, -0.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5232/QUADRO_elettrico` | 77.72, -28.12, -22.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5233/TURBINA_1` | 75.40, -28.25, -19.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5234/det_griglia_caduta` | 73.60, -28.96, -21.80 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5236/SCRIVANIA` | 48.00, -19.61, -0.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5237/SEDIA` | 48.20, -19.52, -1.15 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5240/det_vetri_rotti_1` | 51.67, -20.00, -0.83 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5241/det_foglio_2` | 49.40, -19.98, -1.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5242/det_tubo_valvola_T` | 55.60, -23.22, -31.82 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5243/det_tubo_curva_su` | 60.47, -19.18, 1.92 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5244/det_tubo_valvola_T` | 40.58, -29.42, -12.40 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 360.0 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5258/det_fascio_cavi_4m` | 48.00, -20.65, 0.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5259/det_cavo_festone_3` | 61.00, -20.66, 0.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5261/det_cavo_festone_3` | 61.50, -24.66, -30.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5262/det_corda_pendente_2` | 74.01, -21.70, 0.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5263/det_corda_rotolo` | 41.00, -29.94, -6.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.9 cm) |
| grafica | staccato | `SalaInseguimento/Luci/@Node3D@5264/det_catena_a_terra` | 42.31, -29.98, -2.61 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-2 | staccato | `TorreProp/prop_salvagente_nave_1` | 23.59, -8.92, -7.59 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| ambienti-2 | staccato | `TorreProp/prop_secchio_gigante_1` | 32.60, -19.20, -9.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.0 cm) |
| ambienti-2 | staccato | `TorreProp/prop_tubi_galleggianti_1` | 38.41, -2.83, -22.41 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| ambienti-2 | staccato | `TorreScivoli/discesa_0_1` | 32.64, -2.14, -21.97 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 76.4 cm) |
| ambienti-2 | staccato | `TorreScivoli/discesa_2_0` | 32.99, -5.86, -8.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 16.6 cm) |
| ambienti-2 | staccato | `TorreScivoli/discesa_5_0` | 38.11, -15.44, -16.98 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 31.4 cm) |

## Già noti

### interni

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-1 | compenetra | `Interni/Ambienti/Corridoio/neon_corridoio_2_neon/neon_corridoio_2_tubo_sfarfalla` | 0.30, 2.48, 39.60 | il 87% dei suoi vertici è dentro Interni/Ambienti/Corridoio/neon_corridoio_2 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-1 | compenetra | `Interni/Ambienti/Spogliatoi/neon_spogliatoi_1_neon/neon_spogliatoi_1_tubo_sfarfalla` | -2.70, 2.85, 35.90 | il 68% dei suoi vertici è dentro Interni/Ambienti/Spogliatoi/neon_spogliatoi_1 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-1 | compenetra | `Interni/Ambienti/Stanzino/neon_stanzino_neon/neon_stanzino_tubo_sfarfalla` | 3.50, 2.39, 32.50 | il 68% dei suoi vertici è dentro Interni/Ambienti/Stanzino/neon_stanzino | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-1 | ingombro | `Interni/Ambienti/Corridoio/asciugamano_corridoio` | -1.25, 0.00, 40.00 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.52 m sopra il pavimento (125 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Corridoio/cartello_corridoio` | 6.50, 0.00, 39.00 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.62 m sopra il pavimento (32 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Corridoio/cestino` | -4.25, 0.00, 38.75 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.55 m sopra il pavimento (56 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Corridoio/estintore` | 0.00, 0.00, 40.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.84 e 1.46 m sopra il pavimento (16 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Corridoio/pallone` | -7.25, 0.00, 40.25 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.42 m sopra il pavimento (47 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/armadietti_est_01_anta` | 0.50, 0.00, 37.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.73 m sopra il pavimento (16 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/armadietti_est_09_giallo_anta` | 0.50, 0.00, 33.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.73 m sopra il pavimento (16 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/armadietti_ovest_02_anta` | -6.00, 0.00, 36.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.73 m sopra il pavimento (16 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/armadietti_ovest_11_anta` | -6.00, 0.00, 33.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 1.73 m sopra il pavimento (16 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/asciugamano_2` | -3.00, 0.00, 36.50 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.52 m sopra il pavimento (82 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/cartello_bagnato` | 0.50, 0.00, 29.25 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.62 m sopra il pavimento (48 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/cestino_spogliatoi` | -6.00, 0.00, 30.50 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.50 m sopra il pavimento (32 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/pallone_spogliatoi` | 0.50, 0.00, 30.75 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.40 m sopra il pavimento (16 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/secchio_mocio` | -2.25, 0.00, 29.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dal giocatore, fra 0.35 e 0.95 m sopra il pavimento (132 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_rotore` | 0.00, 0.00, 25.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (32 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Spogliatoi/tornello_telaio` | 0.50, 0.00, 25.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (96 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Stanzino/estintore_stanzino` | 5.00, 0.00, 34.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.82 e 1.44 m sopra il pavimento (16 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Stanzino/porta_stanzino` | 0.50, 0.00, 32.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (64 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Interni/Ambienti/Stanzino/sedia` | 2.75, 0.00, 33.50 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.88 m sopra il pavimento (96 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | sospeso | `Interni/Ambienti/Spogliatoi/armadietti_ovest_02_anta` | -6.03, 0.96, 36.80 | niente a meno di 5 cm (sotto, il primo appoggio è a 0.18 m) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | sospeso | `Interni/Ambienti/Stanzino/fischietto_1` | 2.10, 1.26, 30.40 | niente a meno di 5 cm (sotto, il primo appoggio è a 0.50 m) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | sospeso | `Interni/Ambienti/Stanzino/fischietto_2` | 2.40, 1.22, 30.40 | niente a meno di 5 cm (sotto, il primo appoggio è a 0.46 m) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | sospeso | `Interni/Ambienti/Stanzino/fischietto_4` | 3.00, 1.14, 30.40 | niente a meno di 5 cm (sotto, il primo appoggio è a 0.96 m) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | sospeso | `Interni/Ambienti/Stanzino/fischietto_5` | 3.30, 1.10, 30.40 | niente a meno di 5 cm (sotto, il primo appoggio è a 0.34 m) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |

### sala

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/GuidaDestra` | 19.50, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (5 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| enigmi | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/GuidaSinistra` | 19.50, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (5 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Sala/AngoloScatoloni/scat_caduto_0` | -19.00, 0.00, 16.00 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.56 m sopra il pavimento (112 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Sala/AngoloScatoloni/scat_caduto_6` | -18.50, 0.00, 16.00 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.48 m sopra il pavimento (64 celle da 25 cm), senza collisione (si attraversa) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |
| ambienti-1 | ingombro | `Sala/AreaBimbi/sala_struttura_gioco` | -15.50, 0.00, -19.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (902 celle da 25 cm), con la collisione (ci si sbatte contro) | da correggere: rapporto del 22 ottobre sulla v0.3.8 in preparazione, da assegnare |

### tecnici

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/neon_0_neon/neon_0_tubi` | -0.60, -4.92, 5.36 | il 90% dei suoi vertici è dentro Tecnici/Ambienti/CameraOnde/plafoniera_0 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/neon_1_neon/neon_1_tubo_sfarfalla` | -0.60, -4.92, 11.36 | il 87% dei suoi vertici è dentro Tecnici/Ambienti/CameraOnde/plafoniera_1 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/CameraOnde/neon_2_neon/neon_2_tubi` | -0.60, -4.92, 21.21 | il 87% dei suoi vertici è dentro Tecnici/Ambienti/CameraOnde/plafoniera_2 | voluto: il tubo del neon sta dentro la sua plafoniera |
| enigmi | compenetra | `Tecnici/Ambienti/Raccordo/neon_rc_neon/neon_rc_tubo_sfarfalla` | -0.90, -6.32, 49.86 | il 81% dei suoi vertici è dentro Tecnici/Ambienti/Raccordo/plafoniera_rc | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_0_neon/neon_0_tubi` | 1.20, -4.22, 34.16 | il 77% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_0 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_1_neon/neon_1_tubo_sfarfalla` | 1.20, -4.22, 39.16 | il 77% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_1 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_2_neon/neon_2_tubi` | 1.20, -4.22, 43.66 | il 77% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_2 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | compenetra | `Tecnici/Ambienti/SalaPompe/neon_3_neon/neon_3_tubi` | 5.70, -4.22, 39.16 | il 68% dei suoi vertici è dentro Tecnici/Ambienti/SalaPompe/plafoniera_3 | voluto: il tubo del neon sta dentro la sua plafoniera |
| ambienti-2 | ingombro | `Tecnici/Ambienti/CameraOnde/CAMERA_bocchette` | -1.75, -9.05, 15.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.58 e 2.00 m sopra il pavimento (192 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: bocchette dell'aria sul muro sud della camera delle onde (da 1,65 m), ora con la collisione: ci si ferma contro come contro il muro. Se non va bene: alzarle di 40 cm in ambienti2_camera_onde.py |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico` | -3.25, -9.05, 33.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.90 e 2.00 m sopra il pavimento (48 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: quadro elettrico appeso al muro sud della sala pompe, ora con la collisione: ci si ferma contro come contro il muro; non è su una strada o una scala |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti` | -3.50, -9.05, 36.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 1.30 e 2.00 m sopra il pavimento (64 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: pannello degli strumenti appeso al muro sud della sala pompe, ora con la collisione: ci si ferma contro come contro il muro; non è su una strada o una scala |
| ambienti-2 | ingombro | `Tecnici/Ambienti/SalaPompe/SALA_ringhiera` | -2.75, -9.05, 36.50 | nello spazio di chi cammina, all'altezza del busto: a meno di 10 cm dal giocatore, fra 0.35 e 1.10 m sopra il pavimento (68 celle da 25 cm), senza collisione (si attraversa) | voluto: i montanti in cima alla scaletta della vasca di raccolta (escono 25 cm dal bordo, fino a 0,9 m): si esce dalla vasca passandoci in mezzo; la ringhiera vera ha le sue scatole di collisione |

### torre

| Squadra | Problema | Nodo | Posizione | Dettaglio | Stato |
|---|---|---|---|---|---|
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoStruttura/ins_A_collare` | 40.50, -19.32, -17.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (12 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: il collare attorno al tubo dove passa il muro: le celle sono dentro il tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoStruttura/ins_A_struttura` | 44.00, -34.00, -4.00 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (393 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: le celle sono dentro i tubi chiusi (sopra il tubo ci sono i suoi attacchi) e sulla scaletta di pioli del bacino, da dove si sale (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_0` | 50.50, -22.58, -14.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (1679 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_1` | 63.00, -25.58, -27.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (2647 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_2` | 69.50, -28.58, -7.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3746 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `SalaInseguimento/InseguimentoTubi/ins_A_tubo_3` | 50.75, -34.00, -6.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (2537 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreScivoli/torre_collare_inseguimento` | 40.00, -19.19, -17.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (12 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: il collare attorno al tubo dove passa il muro: le celle sono dentro il tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreScivoli/torre_tubo_inseguimento` | 41.00, -19.46, -17.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (186 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: dentro i tubi chiusi dell'inseguimento si scivola accovacciati: il tubo stesso (1,5 m) è il soffitto, e fuori ci sono i suoi attacchi; il controllo conta le celle del fondo del tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreStruttura/torre_A` | 40.00, -19.19, -17.75 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (3 celle da 25 cm), con la collisione (ci si sbatte contro) | voluto: il bordo del foro nel muro est dove passa il tubo dell'inseguimento: le celle sono dentro il tubo (ambienti-2, 22 ottobre) |
| ambienti-2 | ingombro | `TorreStruttura/torre_A_sostegni` | 38.00, -19.98, -16.25 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.68 e 2.00 m sopra il pavimento (83 celle da 25 cm), senza collisione (si attraversa) | voluto: celle dentro il tubo dell'inseguimento, e il collare sotto la coda del tratto 5, 1,93 m sopra il terzo gradino della bocca, sul bordo est della salita (ambienti-2, 22 ottobre) |

