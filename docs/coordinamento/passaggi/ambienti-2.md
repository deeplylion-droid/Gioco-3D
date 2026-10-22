# Passaggio di consegne: ambienti-2

Per chi riprende da zero il lavoro dell'agente "ambienti-2".

## Branch

- `lavoro/ambienti-2`, worktree `/home/user/wt/ambienti-2`. L'ultimo commit di lavoro prima di questo file è `8a3b141`.
- Il coordinatore prende i commit uno per uno su `lavoro/godot`, che poi va in `main`.
- **Attenzione:** la torre è stata ritoccata da grafica su `lavoro/godot` (c2c9afd). Prima di toccare la torre, unisci da lì.

## File principali

- **Sala della torre** (discesa a scivoli):
  - generatore `tools/blender/torre_proposte.py A --gioco --blend …`, con `torre_a.py` (scivoli, tralicci, getti, imbuti) e `torre_sostegni.py` (controlla che niente resti sospeso);
  - nel gioco: `godot/scenes/sala/torre/sala_torre.tscn` + `godot/scripts/game/sala_torre.gd` (luci, rampe d'imbocco, guida agli imbocchi) + `torre_gioco.json` (pedane, ostacoli, checkpoint);
  - test: `tests/test_torre.gd`, `tests/camminatore.gd` (A*).
- **Scivoli:** `tests/test_scivoli.gd`, `tests/video_scivoli.gd`.
- **Sala pompe e monitor:**
  - `scripts/tecnici/tecnici.gd` (materiali, fogli veri del kit sulla scrivania);
  - `scripts/tecnici/monitor_crt.gd` + `shaders/tecnici/crt.gdshader`. Lo schermo appoggiato sul vetro, con gli angoli tondi passati allo shader, si rigenera con `tools/rigenera_schermo_crt.gd`;
  - `scripts/tecnici/risveglio_sala_pompe.gd` (la leva sblocca la porta in 0,9 s);
  - test: `tests/test_tappe56.gd`, `test_tecnici.gd`; scatti: `tests/screenshots_tecnici.gd`.
- **Inseguimento**, proposta scelta dall'utente: **A "Le condotte"**:
  - generatore `tools/blender/inseguimento_proposte.py A|B --blend …`, con `inseguimento_sostegni.py`, `inseguimento_viste.py` (pianta e lato) e `inseguimento_insegne.py` (cartelli della B);
  - GLB e JSON in `godot/proposte/inseguimento/`. Il JSON contiene luci, paratie, pose di lei, "arredi" (oggetti veri di `sala_pompe.gltf` e del kit di dettagli) e percorso;
  - scatti e video: `godot/proposte/inseguimento/scatti_inseguimento.gd`;
  - documento: `docs/proposte/inseguimento/inseguimento.md`.
  - Nel gioco non c'è ancora niente.

## Strumenti

- **Blender:** `/home/user/tools/blender-venv/bin/python script.py`. Non lanciarlo mentre gira un render di Godot: con tutti e due la memoria non basta e il processo viene ucciso.
- **Scatti e video Godot:**
  - si lanciano sotto il lock: `flock /home/user/tools/render.lock xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 --script res://tests/run.gd -- res://proposte/inseguimento/scatti_inseguimento.gd A <cartella> [scatti|video]`;
  - per i video aggiungi `--fixed-fps 24 --write-movie x.avi` e poi converti con ffmpeg in mp4;
  - gli script che usano la medusa o GameState vanno lanciati con `tests/run.gd`.
- **Dipendenze dell'export:** `godot --headless --path godot --script res://tools/dipendenze_export.gd` elenca le cartelle che il gioco non usa mai.
- **Memoria:** la sala principale intera fa chiudere Godot per memoria (Killed). Per gli scatti carica solo le sotto-scene. Per i tecnici imposta `giocatore_proprio=false`.

## Trappole note

- I tre GLB della torre hanno `import_script = torre_post_import.gd` nel `.import`: mette le collisioni a due facce e divide quella della struttura in 11 forme. Se rigeneri i GLB, lascia lo script, altrimenti tornano i blocchi all'ingresso.
- `sala_torre.tscn` tiene i GLB nella proprietà `modelli`, non come nodi figli.
- Dopo un render, `xvfb-run` può lasciare vivo un `Xvfb` che tiene il `render.lock` e blocca tutti gli altri render. Chiudilo con `kill <pid>`.
- Non usare `pkill -f` o `pgrep -f` con parti del comando: trovano anche la shell che li ha lanciati e la uccidono.
- Nel kit di dettagli (`assets/ambiente/dettagli/gltf`) i nodi sono messi in fila: copiandoli conta solo l'origine.
- Nel GLB i pannelli con texture (`insegna()`) si vedono specchiati se la faccia è girata: il verso giusto è `lat = (-n.y, n.x)`.
- Coordinate: Blender (x, y, z) diventa Godot (x, z, -y).

## Lavori aperti

- Portare l'inseguimento A nel gioco: movimento nei tubi, paratie col bersaglio, lei che insegue e si respinge col getto, grata, SB1 dal pozzo, checkpoint, test. Stima 2-3 giorni.
- Difetti noti della proposta A: le vasche sono un po' scure, e nel video l'inizio della spirale resta scuro per circa un secondo.
- Lei usa solo le pose del modello (insegue, affacciata): le animazioni dell'inseguimento sono da fare.
