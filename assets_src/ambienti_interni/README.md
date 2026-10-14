# Ambienti interni del capitolo 1 (inizio)

Corridoio del ponte inferiore, spogliatoi con docce e corridoio lava-piedi, stanzino dei bagnini. Tutto è generato da script ripetibili; i file per Godot sono in `gltf/`.

Quando il branch `lavoro/ambiente` (sala principale) avrà un suo `KIT.md`, queste convenzioni vanno allineate alle sue. Per ora seguono il concept A.

## File

| Percorso | Cosa contiene |
|---|---|
| `gltf/corridoio.gltf` | Corridoio di servizio del ponte inferiore, con la scala che scende verso la sala pompe |
| `gltf/spogliatoi.gltf` | Spogliatoi, docce, condotto della grata, corridoio lava-piedi, gabbiotto del tornello, saracinesca |
| `gltf/stanzino.gltf` | Stanzino dei bagnini |
| `gltf/texture/` | Texture condivise dai tre file (JPG, 2K i colori, 1K le altre mappe) |
| `meshy/*.glb` | Oggetti grezzi di Meshy (text-to-3d, meshy-7 + refine PBR); i prompt sono nei `.json` accanto |
| `poster/` | Cartelloni (Meshy image-to-image, solo come texture) e loro versione invecchiata `*_vecchio.jpg` |

I tre glTF hanno lo stesso sistema di coordinate: si importano nella stessa scena **senza spostarli** e combaciano.

## Script (in `tools/blender/`)

```bash
PY=/home/user/tools/blender-venv/bin/python
$PY tools/blender/ambienti1_texture.py    # scarica le texture CC0 e crea le varianti sporche/bagnate in texture/
$PY tools/blender/ambienti1_build.py      # costruisce tutto, salva ambienti1.blend ed esporta gltf/
$PY tools/blender/ambienti1_render.py     # render Cycles in docs/report/render_ambienti1/ (--prova per le bozze)
python3 assets_src/ambienti_interni/meshy/genera_oggetti.py   # rigenera solo gli oggetti Meshy che mancano
python3 assets_src/ambienti_interni/poster/genera_poster.py <nome>
$PY assets_src/ambienti_interni/poster/invecchia.py
```

`texture/` e `ambienti1.blend` non sono nel repository: si rigenerano con i primi due script.

## Misure e coordinate

- Metri. In Blender Z è in alto; in Godot diventa Y (Blender `(x, y, z)` → Godot `(x, z, -y)`). Pavimento a quota 0.
- Il giocatore è alto 1,75 m; i render hanno gli occhi a 1,62 m.
- Porte 0,9-1,2 × 2,05-2,1 m. Soffitti: corridoio 2,7 m, spogliatoi e docce 2,9 m, stanzino 2,6 m.

Pianta (coordinate Blender, x verso est, y verso nord):

| Zona | x | y |
|---|---|---|
| Corridoio ponte inferiore | 0 … 22 | 0 … 2,6 |
| Tratto oltre la porta tagliafuoco | 22,2 … 25 | 0,4 … 2,2 |
| Scala verso la sala pompe (scende a -1,8 m) | 16,2 … 18,8 | -3,9 … -0,2 |
| Spogliatoi (ingresso dal corridoio a x 6-7,6) | 3 … 11 | 3 … 11 |
| Docce | 3 … 8,2 | 11,2 … 14,6 |
| Condotto dietro la grata d'aerazione | 0,6 … 2,8 | 12 … 12,6 |
| Corridoio lava-piedi (vasca a y 12,4-14,4, tornello a y 16,4) | 8,6 … 10,8 | 11,2 … 20,5 |
| Gabbiotto con il pulsante del tornello | 11 … 13,2 | 14,6 … 17,4 |
| Saracinesca (verso la sala grande, a nord) | 8,6 … 10,8 | 20,6 |
| Stanzino dei bagnini (porta a y 8-8,9) | 11,2 … 15,2 | 6,2 … 10,6 |

Il percorso: risveglio a est del corridoio, si va verso ovest, a destra si entra negli spogliatoi, poi docce o stanzino, poi a nord nel corridoio lava-piedi, tornello, saracinesca e sala grande.

## Nomi degli oggetti

- `*_statico`: tutta l'architettura fissa di una zona, in un solo oggetto (per la collisione usare `-col` / trimesh in Godot).
- **Oggetti che si muovono**: origine già sul perno, posizione di riposo.
  - `porta_tagliafuoco`: cardine verticale in (21,965; 0,72). Esportata chiusa: nel gioco parte aperta (circa 100° verso l'interno) e si chiude.
  - `porta_sala_pompe`: cardine in (17,02; -0,1). Lato corridoio solo una piastra; il maniglione antipanico è sul lato della sala pompe.
  - `porta_stanzino`: cardine in (11,05; 8,88), aperta di 75°.
  - `armadietto_sbatte_anta`: anta separata, cardine verticale; dentro c'è `salvagente_giocattolo`.
  - `grata_aerazione`: cardine orizzontale in alto (asse lungo y), socchiusa di 8°.
  - `tornello_rotore`: ruota attorno all'asse verticale in (9,5; 16,4).
  - `pulsante_tornello`: si preme lungo +x (verso il muro del gabbiotto).
  - `vetro_rotto`: vetro del gabbiotto con il buco; `schegge_vetro` a terra.
  - `saracinesca`: origine in alto al centro (9,7; 20,6; 2,3): si alza scalando o traslando in z.
  - `turbina_saracinesca`: ruota a pale, asse lungo x, sulla parete ovest a 2,05 m.
  - `doccia_0N_soffione` e `doccia_0N_rubinetto` (N = 1…5): separati, il rubinetto ruota attorno al proprio asse.
- **Acqua**: `acqua_pozze_*`, `acqua_pozza_stanzino`, `acqua_lavapiedi` sono oggetti separati, pensati per lo shader dell'acqua di Godot. L'acqua della vasca lava-piedi è un blocco alto 15 cm: il livello (`marker_acqua_lavapiedi_livello`) può scendere quando lo zaino aspira.
- **Punti d'emissione** (empty): `emit_doccia_0N` (spruzzo verso il basso), `emit_vapore_docce`, `emit_lavapiedi_1/2`, `emit_goccia_corridoio_1/2`.
- **Marker** (empty): `marker_risveglio` (dove il giocatore è a terra, guarda verso ovest), `marker_zaino_pompa` (posto libero sulla rastrelliera dello stanzino, gancio a 1,25 m, schiena verso il muro est), `marker_polaroid_P1/P2/P3`, `marker_armadietto_sbatte`, cardini e perni.
- **Luci**: `luce_emergenza_*` (corpo), `*_vetro` (emissivo rosso), `*_luce` (luce puntiforme rossa). `neon_*` con `*_tubi` (spenti) o `*_tubo_sfarfalla` (acceso, da far sfarfallare in Godot cambiando l'emissione). Le luci ad area dei neon nei glTF non vengono esportate: in Godot vanno sostituite con una `OmniLight3D` o `SpotLight3D`.
- `impronte_bagnate_B1`: impronte verso la grata d'aerazione (momento B1 delle proposte, da approvare).

## Materiali e texture

Tutte le texture di base sono **CC0 di [ambientCG](https://ambientcg.com)** (licenza CC0 1.0, nessun obbligo di attribuzione), scaricate a 2K e poi sporcate, tinte e bagnate dallo script. Le UV sono proiettate a scatola in coordinate di mondo: ogni materiale ha la stessa scala ovunque (tabella `SCALA_UV` in `ambienti1_lib.py`).

| Materiale | Sorgente ambientCG | Uso |
|---|---|---|
| `lamiera_crema` | PaintedMetal013 | pareti sopra 1,1-1,2 m |
| `lamiera_petrolio` | PaintedMetal006 | zoccolo scuro delle pareti |
| `soffitto_lamiera` | PaintedMetal011 | soffitti |
| `piastrelle_pavimento` | Tiles040 | pavimenti, con chiazze bagnate nella mappa di ruvidità |
| `piastrelle_doccia` | Tiles036 | pareti e pavimento delle docce |
| `piastrelle_verdi` | Tiles032 | zoccolo delle docce, vasca lava-piedi, divisori |
| `armadietto_verde` | PaintedMetal006 | armadietti |
| `vernice_gialla` / `vernice_rossa` | PaintedMetal009 / PaintedMetal004 | ante colorate, rastrelliera, telai, turbina, tubo antincendio |
| `porta_lamiera` | MetalPlates013 | porte, saracinesca |
| `ruggine` / `metallo_grezzo` / `lamiera_grata` | Rust007 / Metal063 / MetalPlates006 | tubi, staffe, gradini, scarichi |
| `legno_panca` | Wood051 | panche, scrivania, bacheca |
| `cemento` | Concrete034 | pianerottolo della scala |
| `salvagente` | generata dallo script | salvagenti bianchi e rossi |

Oggetti Meshy (texture PBR ridotte a 1K): ciabatta, braccioli, fischietto, radio, ricetrasmittente, sedia, asciugamano, salvagente giocattolo a papera, secchio con mocio, estintore, cassetta del pronto soccorso, paperella, pallone, cestino.

Cartelloni: `cartellone_medusa` (corridoio, 1,5 × 2 m), `cartello_regole` (solo pittogrammi), `poster_bagnino` (la mascotte con il cappellino da bagnino). Nessuna scritta, nessun nome.
