# Come montare in Godot l'inizio del capitolo 1

Corridoio del risveglio, spogliatoi e stanzino dei bagnini. Convenzioni e materiali in [README.md](README.md).

## 1. File da copiare

Copiare **tutta** la cartella `assets_src/ambienti_interni/gltf/` in `godot/` (per esempio `godot/assets/ambienti_interni/`), compresa `texture/`: i tre `.gltf` usano le stesse texture.

| File | Zona | Peso |
|---|---|---|
| `corridoio.gltf` + `.bin` | corridoio del ponte inferiore, scala verso la sala pompe | 1,8 MB |
| `spogliatoi.gltf` + `.bin` | spogliatoi, docce, corridoio lava-piedi, gabbiotto, saracinesca | 10 MB |
| `stanzino.gltf` + `.bin` | stanzino dei bagnini | 2,4 MB |
| `texture/` | 120 JPG condivisi | 22 MB |

## 2. Posizione

**I tre file vanno messi tutti a `Transform3D.IDENTITY`**, nella stessa scena: le coordinate sono già quelle giuste e le stanze combaciano. Scala in metri, pavimento a y = 0.

Sotto, tutte le coordinate sono **in Godot** (x, y, z), con y in alto. Il nord della pianta è -Z.

**Uscita verso la sala principale**: `marker_uscita_sala_principale` in **(9,70; 0; -20,70)**. Il vano è largo 1,2 m (x da 9,1 a 10,3) e alto 2,2 m, con il pavimento a quota 0; la sala principale continua verso -Z. Per attaccarla basta far coincidere la sua porta d'ingresso con questo punto: oppure spostare il nodo che contiene i tre glTF in modo che il marker cada sulla porta della sala.

## 3. Collisioni

Già nei file, importate da sole grazie al suffisso `-colonly` (StaticBody3D con forma concava, invisibili):

- `corridoio_collisione`, `spogliatoi_collisione`, `stanzino_collisione`: pavimenti, pareti, soffitti, file di armadietti, panche, divisori delle docce, vasca lava-piedi, grate fisse del tornello, banco del gabbiotto, rastrelliera, scrivania.
- `scala_pompe_rampa`: la scala verso la sala pompe è una rampa di 36° (salire i gradini veri non serve).
- `vetro_rotto_blocco`: chiude il buco del vetro del gabbiotto. **Va messo su un livello che ferma il giocatore ma non il getto d'acqua**, altrimenti il getto non arriva al pulsante.

Attenzione: i suffissi valgono solo con l'import normale dell'editor. Se i file si caricano a runtime con `GLTFDocument` (come in `labs/ambienti1`), le mesh `-colonly` compaiono bianche e vanno nascoste o convertite a mano.

Senza collisione nei file (si muovono: vanno date dal codice): porte, saracinesca, rotore del tornello, anta dell'armadietto che sbatte, grata d'aerazione. Misure sotto.

## 4. Oggetti che si muovono

Ogni oggetto ha l'origine sul suo perno ed è nella posizione di riposo.

| Nodo | Perno (Godot) | Movimento | Collisione da aggiungere |
|---|---|---|---|
| `porta_tagliafuoco` | (21,97; 0; -0,72) | ruota su Y. Nel file è chiusa: all'inizio va messa aperta (`rotation.y` ≈ +100°) e si chiude alle spalle del giocatore | Box 0,07 × 2,07 × 1,16 |
| `porta_sala_pompe` | (17,02; 0; 0,10) | ruota su Y. Chiusa a chiave dal corridoio; si apre dalla sala pompe col maniglione (tappa 6) | Box 0,96 × 2,02 × 0,06 |
| `porta_stanzino` | (11,05; 0; -8,88) | ruota su Y, è aperta di 75° | Box 0,05 × 2,02 × 0,86 |
| `armadietto_sbatte_anta` | (10,50; 0; -5,29) | ruota su Y: sbatte (falso spavento). Dentro c'è `salvagente_giocattolo` | Box 0,02 × 1,76 × 0,38 |
| `grata_aerazione` | (3,00; 0,50; -12,30) | ruota sul suo asse orizzontale (asse Z), cardine in alto; ora socchiusa di 8° (momento B1) | Box 0,03 × 0,46 × 0,6 |
| `tornello_rotore` | (9,50; 0; -16,40) | ruota su Y di 120° a ogni passaggio, quando il pulsante è acceso | Cilindro r 0,6, h 2,25 |
| `saracinesca` | (9,70; 0; -20,60), in basso al centro del vano | sale lungo Y di 2,2 m. L'origine è come vuole `PoweredDoor` (`open_offset = (0, 2.2, 0)`) | Box 1,2 × 2,2 × 0,08 |
| `turbina_saracinesca` | (8,79; 2,05; -19,40) | ruota sul suo asse X | - |
| `pulsante_tornello` | (13,17; 1,30; -16,00) | si preme verso +X | - |
| `doccia_0N_rubinetto` | sul rubinetto | ruota sul suo asse Z | - |

Collegamento con gli script di `lavoro/godot` (`godot/scripts/mechanisms/`):

- `Turbine` nel punto di `turbina_saracinesca`, con `rotation_degrees.y = 90` (lo script guarda verso +Z, la turbina guarda verso +X, cioè verso il corridoio). Il modello della ruota va come figlio e ruota con lei.
- `WaterButton` nel punto di `pulsante_tornello`, con `rotation_degrees.y = -90` (guarda verso -X, verso il vetro rotto), modalità `LATCH`: sblocca il `tornello_rotore`.
- `PoweredDoor` sulla `saracinesca` con `sources = [Turbine]`, `open_offset = (0, 2.2, 0)`.
- `PackPickup`: lo zaino sul `marker_zaino_pompa` in **(14,94; 1,25; -8,43)**, appeso ai due ganci centrali della rastrelliera, schiena verso il muro (+X). La rastrelliera ha il posto libero apposta.
- Acqua da aspirare: `acqua_lavapiedi` (vasca x 8,6…10,8, z -12,4…-14,4; superficie a y -0,05, fondo a -0,20). Un `WaterTank`/`WaterVolume` con quella forma; quando lo zaino aspira, il livello scende fino a -0,2 (la mesh si può scalare in Y o spostare).

## 5. Luci

Nei file ci sono le **luci rosse d'emergenza** come `OmniLight3D` (`luce_emergenza_*_luce`, già con colore rosso); le luci ad area dei neon invece non vengono esportate. Consiglio di sostituirle con i nodi dell'addon `grafica`:

- `LuceEmergenza` (rossa, FISSA; una o due PULSANTI) al posto di ogni `luce_emergenza_*_luce`. Corridoio: (3,00; 2,20; -2,38), (10,80; 2,20; -2,38), (19,20; 2,20; -2,38), (17,50; 2,35; -0,22) sopra la porta della sala pompe, (17,50; 2,25; -2,38) di fronte, (21,78; 2,40; -1,30) sopra la porta tagliafuoco, (0,22; 2,35; -1,30) in fondo, (7,50; 2,20; -0,22). Spogliatoi: (6,80; 2,45; -3,22), (3,22; 2,40; -7,00), (5,60; 2,55; -14,38) docce, (9,70; 2,50; -11,42), (10,58; 2,30; -18,20), (12,98; 2,30; -16,00) gabbiotto. Stanzino: (11,42; 2,30; -9,60), (14,98; 2,30; -7,60).
- `Neon` ai nodi `neon_*`: quelli con `_tubo_sfarfalla` sono accesi (modalità SFARFALLA, fanno da tubo emissivo): `neon_corridoio_2` (10,00; 2,59; -1,30), `neon_spogliatoi_1` (7,00; 2,79; -5,00), `neon_stanzino` (13,20; 2,49; -8,40). Gli altri (`_tubi`) sono spenti; `neon_corridoio_3` pende storto da un cavo.
- `luce_pulsante_tornello`: piccola luce rossa sul pulsante, per farlo vedere attraverso il vetro.
- Il vetro delle lampade (`*_vetro`) e i tubi dei neon hanno un materiale emissivo: per lo sfarfallio basta cambiare `emission_energy` insieme alla luce.

## 6. Acqua, vapore, gocce

- Pozze: `acqua_pozze_corridoio`, `acqua_pozze_spogliatoi`, `acqua_pozza_stanzino` sono mesh piatte 4 mm sopra il pavimento: assegnare lo shader dell'acqua (o uno scuro molto lucido, roughness 0,02). Anche i pavimenti hanno già le chiazze bagnate nella mappa di ruvidità: con SSR attivo riflettono le luci rosse.
- Docce (tappa 2, si aprono da sole e al ritorno scorrono senza fermarsi): getti dagli empty `emit_doccia_01…05` (y 2,10; z -14,22; x 3,70 / 4,65 / 5,60 / 6,55 / 7,50), spruzzo verso il basso. Vapore: `Vapore` in `emit_vapore_docce` (5,60; 1,50; -13,60), volume circa 5 × 3 × 3,4 m.
- Docce lava-piedi: `emit_lavapiedi_1/2` (9,20 e 10,20; 2,20; -13,40).
- `Gocce` in `emit_goccia_corridoio_1` (13,20; 2,29; -2,32) e `_2` (19,40; 2,29; -2,32), sopra le pozze del corridoio.

## 7. Punti per il gioco

| Marker | Posizione (Godot) | Uso |
|---|---|---|
| `marker_risveglio` | (20,40; 0; -1,25) | il giocatore è a terra e guarda verso ovest (-X), verso il cartellone e il corridoio |
| `marker_polaroid_P1` | (20,90; 0; -0,55) | Polaroid a terra vicino al risveglio (proposta) |
| `marker_polaroid_P2` | (3,25; 1,60; -7,90) | sul ripiano di un armadietto aperto |
| `marker_polaroid_P3` | (12,65; 1,30; -6,24) | sulla bacheca dello stanzino |
| `marker_armadietto_sbatte` | (10,75; 1,00; -5,10) | trigger dell'armadietto che sbatte |
| `marker_zaino_pompa` | (14,94; 1,25; -8,43) | lo zaino-pompa |
| `marker_uscita_sala_principale` | (9,70; 0; -20,70) | attacco con la sala principale |

Checkpoint consigliati: al risveglio, all'ingresso degli spogliatoi (6,80; 0; -3,40), dopo aver preso lo zaino, davanti al tornello (9,70; 0; -15,50).

## 8. Ambiente

`AmbienteHorror.crea()` dell'addon `grafica` va bene. Valori che ho usato per lo screenshot di prova: luce ambiente (0,35; 0,6; 0,7) a 0,3, nebbia volumetrica 0,035, AgX. Consigliati un `VoxelGI` e una `ReflectionProbe` (interno) per ciascuna delle tre zone. Scena di prova senza addon: `labs/ambienti1/` (carica i glTF a runtime e salva gli screenshot).
