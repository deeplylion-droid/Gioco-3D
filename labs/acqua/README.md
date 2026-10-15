# Laboratorio dell'acqua

Progetto Godot 4.7.2 (Forward+) separato dal gioco, per sviluppare e provare l'acqua di Splash
Lagoon. Il codice riutilizzabile sta in `addons/acqua/` ed e' copiato cosi' com'e' in
`godot/addons/acqua/` (istruzioni d'integrazione: `addons/acqua/README.md`).

## Aprire e provare

- Editor: apri `labs/acqua/project.godot`. Scena principale: `demo/demo_piscina.tscn`, una sala di
  prova notturna con la piscina a onde vuota (pozza torbida con lo scarico), la vasca bimbi rialzata
  che si riempie e la vasca profonda d'arrivo dello scivolo.
- Tasti: `0` aspetto predefinito, `1`/`2`/`3` le tre opzioni d'aspetto, `R`/`F` riempi/svuota la
  vasca d'arrivo, `V` svuota la pozza (gorgo), `B` riempie la vasca bimbi, `L` lampo, `T` qualita',
  `Spazio` lancia una palla (schizzo e galleggiamento), `C` cambia inquadratura, `P` screenshot,
  tasto destro + WASD/QE per muoversi.
- Screenshot senza schermo: `tools/scatta.sh <file.jpg> 960x540 --shots=finale,pozza --quality=2`
  (usa `flock /home/user/tools/render.lock`: un solo render pesante alla volta sulla macchina).
- Sequenza animata: `godot --path labs/acqua --write-movie /tmp/f/frame.png --fixed-fps 24
  --quit-after 432 -- --sequence=main`, poi ffmpeg.
- Prova nella sala vera: `bash labs/acqua/tools/prepara_sala_vera.sh` copia da main i GLB della
  sala (`assets_src/ambiente/glb/sala/`) in `sala_main/` (non versionata); poi la scena e'
  `tests/sala_vera/test_sala_vera.tscn` (acqua con le quote di `assets_src/ambiente/INTEGRAZIONE.md`).
  Argomenti dopo `--`: `--out=file.jpg --shots=pozza,bimbi,medusa,arrivo_scie,sotto` (screenshot),
  `--sequence` (sequenza di 20 s per Movie Maker), `--measure` (costo dell'acqua alle tre qualita'),
  `--style=1|2|3`, `--quality=0|1|2`, `--drain`.

## Struttura

| Cartella | Contenuto |
|---|---|
| `addons/acqua/shaders/` | superficie dell'acqua, superfici bagnabili (+ include con caustiche, umidita', luce), sott'acqua, gocce, spruzzo, bollicine, acqua che scorre |
| `addons/acqua/compute/` | simulazione delle increspature (compute shader) |
| `addons/acqua/scripts/` | WaterManager (autoload), WaterBody, WaterTankLink, WetSurfaceConverter, WaterPackFX, effetti e particelle |
| `addons/acqua/textures/` | texture generate dagli script di `tools/` (normal map, caustiche 3D, schiuma, rumori) e piastrelle CC0 |
| `addons/acqua/presets/` | i tre aspetti dell'acqua (WaterStyle) |
| `demo/` | sala di prova, camera libera, sequenze |
| `tools/` | generatori di texture, impostazioni d'import, screenshot, copia dell'addon nel gioco |

## Texture e licenze

- `addons/acqua/textures/water_normal_*.png`, `caustics_3d.png`, `foam.png`, `noise_rgba.png`:
  generate da `tools/genera_texture_acqua.py` (create da zero, CC0). Le caustiche sono calcolate
  fisicamente: luce rifratta da una superficie ondulata periodica (ripetibile nello spazio e nel
  tempo), 64 fotogrammi 256x256 in una Texture3D.
- Piastrelle, intonaco e metallo: ambientCG (CC0, https://ambientcg.com): Tiles132B, Tiles132C,
  Tiles141, Tiles133B, PaintedPlaster012, Metal021 (texture 1K, rielaborate in albedo / normal /
  ORH). La texture a scacchi della vasca bimbi e' Tiles133B ricolorata da
  `tools/genera_piastrelle_scacchi.py`.

## Rigenerare

- Texture: `/home/user/tools/blender-venv/bin/python labs/acqua/tools/genera_texture_acqua.py`
- Opzioni d'import (mipmap, Texture3D, compressione): `python3 labs/acqua/tools/imposta_import.py`
  e poi `godot --headless --path labs/acqua --import`.
- Copia dell'addon nel gioco: `bash labs/acqua/tools/copia_addon.sh`.
