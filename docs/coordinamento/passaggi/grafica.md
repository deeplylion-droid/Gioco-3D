# Passaggio: grafica

**Branch** `lavoro/grafica`. L'ultimo lavoro è d39dced, già in main. Il branch riparte da `origin/main` 96d0437.

Il lavoro arriva dal coordinatore. Quando un compito è finito, gli si manda l'hash con i numeri dei test, e il push si fa solo con tutte le suite verdi.

## File principali

- `godot/scripts/game/sala_principale.gd`: la sala grande.
  - Precarica la torre in un thread quando compaiono gli acquari (`_precarica_torre`).
  - Poi la costruisce nascosta (`_prepara_torre`) e la mostra all'apertura del portone (`_mostra_torre`).
  - Se il caricamento in thread fallisce, ripiega su `load()`.
  - Negli scatti si spegne con `Engine.set_meta(&"precarica_torre_spento", true)`.
- `godot/scripts/game/sala_torre.gd`, scena `scenes/sala/torre/sala_torre.tscn`: la torre degli scivoli.
  - `costruisci_a_pezzi()` lavora a passi con un budget di ms per fotogramma.
  - `prepara_materiali()` compila le pipeline fuori vista, con una SubViewport sullo strato `1<<19`.
- `godot/assets/ambiente/torre/torre_post_import.gd`: rende le collisioni a doppia faccia e divide le forme oltre le 8000 facce.
  - Se lo cambi, cancella `.godot/imported/torre_*` per forzare il reimport.
- Effetti dello zaino:
  - `water_pack.gd`, `slide_fx.gd`;
  - `prepara_effetti.gd`, che fa il warmup del primo spruzzo; si spegne con `Engine.set_meta(&"prepara_effetti_spento", true)`.
- `addons/grafica/look_*.gd`: luci e look di sala, interni e tecnici.
- Build:
  - `addons/esportazione/` (EsportaSenzaDoppioni): toglie le texture doppie all'esportazione;
  - `tools/verifica_pck.py`: controlla un .pck o l'exe unico;
  - `tools/godot_vram_textures.py`: imposta la compressione VRAM e i limiti di risoluzione;
  - `docs/tecnico/peso_build.md`: misure e proposte A-D, da riprendere quando l'exe arriva verso 1,8 GB.

## Strumenti

- **flock**: ogni Godot o Blender gira dentro `flock /home/user/tools/render.lock …`, prima controllando `MemAvailable`. La sala intera occupa 12-13 GB di memoria e due processi pesanti insieme fanno riavviare la macchina.
- **Test headless**: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_X.gd`.
  - Suite nella CI: mechanics, sala, audio, menu, bambini, interni, tecnici, tappe56, tappa7, tappa8, torre, scivoli, acquari, esportazione, più `tests/check_scripts.gd`.
- **Test col renderer vero** (Vulkan llvmpipe): `test_primo_uso` e `test_torre_ingresso`.
  - Comando: `xvfb-run -a -s "-screen 0 320x180x24" godot --path godot --rendering-driver vulkan --resolution 320x180 --script res://tests/run.gd -- res://tests/test_X.gd`.
  - Il parametro `senza_preparazione` dimostra che il test se ne accorge.
  - Contano i monitor `PIPELINE_COMPILATIONS_SURFACE/DRAW`: devono restare a zero.
- **Scatti**: script `tests/scatti_*.gd`, lanciati col comando xvfb di CLAUDE.md.
- **Prove fuori dalla CI**: `tests/prova_*`, `misura_*`, `sonda_*`.
- **Peso del pacchetto**:
  - `git worktree add` in `/home/user/wt/…`, non `git clone`: la copia di `.git` (5,7 GB) è lentissima;
  - poi i passi della CI e `godot --export-pack "Windows Desktop" x.pck`;
  - infine `python3 tools/verifica_pck.py x.pck 20`.

## Trappole note

- `pkill -f …` può colpire la propria shell (exit 144): usa i PID.
- Il caricamento in thread della torre qui dura 9-15 s. Le attese nei test vanno a tempo, non a fotogrammi, se no il test esce a metà e Godot stampa un "Parse Error" falso.
- In headless `RenderingServer.frame_post_draw` non arriva mai: usa `get_tree().process_frame`.
- Creare istanze nel WorkerThreadPool si blocca, come per i bambini della balconata.
- Su llvmpipe la durata dei fotogrammi oscilla molto: misura i ms dei passi, non dei fotogrammi.
- Dopo la scena del risveglio la camera è girata: aspetta `player.input_enabled`.
- Disco: la quota è fissa. Un worktree con l'import completo occupa circa 4 GB; poi va tolto con `git worktree remove`.
- Le texture estratte dai GLB della sala non sono nel repository (sono in `.gitignore`) e si rigenerano all'import. Le impostazioni VRAM vengono da `godot_vram_textures.py`, nella CI.

## Lavori aperti

- Risposte dell'utente sui punti bui: la pagina del giro al buio è ferma, in attesa.
- Forse una risposta sulla carica del getto in aria.
- Peso della build, proposte A (torre a 1024) e B (oggetti piccoli a 1024): il coordinatore le ha rimandate. Prima di applicarle servono gli scatti prima/dopo.
