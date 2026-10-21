# Passaggio: lavoro/ambienti-1 (21 ottobre)

Per chi riprende da zero. Leggi prima `CLAUDE.md` e `docs/GDD.md`.

**Branch** `lavoro/ambienti-1` (worktree `/home/user/wt/ambienti-1`). Ultimo lavoro: `5f95315`, a cui si aggiunge il commit di questo file. La copia di prova del geyser era nel worktree `/home/user/wt/geyser` (branch locale `locale/geyser`). I commit li ho portati qui con cherry-pick: lavora solo su `lavoro/ambienti-1`.

## File principali

- **Interni (inizio del capitolo 1: corridoio, spogliatoi, stanzino)**: `godot/scenes/interni/interni.tscn`, generata da `tools/godot_interni_scena.py`. I modelli sono `godot/assets/ambienti_interni/{corridoio,spogliatoi,stanzino}.gltf`, costruiti dagli script `tools/blender/ambienti1_*.py` (build, hq, lib, render, texture); i sorgenti stanno in `assets_src/ambienti_interni/`.
- **Tecnici e tappa 7**: `godot/scenes/tecnici/tecnici.tscn`. Il raccordo `godot/assets/ambienti_tecnici/raccordo.gltf` viene da `tools/blender/ambienti2_raccordo.py` (lancialo con `TECNICI_GODOT=1`). L'arredo `arredo_risalita.gltf` viene da `tools/blender/tappa7_arredo.py gioco`.
- **Agnellino della scala di C2** (v0.3.6, `3cf5f05`): `scripts/tecnici/agnellino_scala.gd`. Corre a 3 m/s e si infila nella grata sfondata del muro sud di C2, a z 4,9. Il buco e la cavità sono nel generatore del raccordo; le 4 casse tolte davanti al buco sono filtrate in `tappa7_arredo.py`. Il suono `zampette_condotto` è in `assets_src/audio/genera_tecnici.py`. Test: `tests/test_agnellino.gd`; scatti: `tests/scatti_agnellino_buco.gd`.
- **Geyser della fossa (tappa 8)**. È solo una proposta: `godot/proposte/geyser/`, fuori dall'export. **L'utente ha scelto la V1.**
  - **V1**: `geyser_mesh.gd` (`GeyserMesh`, estende `GeyserFossa`) con lo shader `acqua_schiuma.gdshader` e la sequenza `geyser_sequenza.glb` (78 mesh, 25 MB).
  - **V2**: `geyser_flipbook.gd`, `acqua_flipbook.gdshader`, `flipbook_*.png`.
  - Video e prove: `video_geyser.gd`, con gli argomenti `<v1|v2|oggi> angolo distanza fine foto|video cartella [orbita]` e le variabili di diagnosi `SONDA_PIXEL`, `SENZA_TORCIA`, `SENZA_PARTICELLE`, `SENZA_CARTELLONE`.
  - Sorgenti: `assets_src/geyser/` (`simula.py`, `anteprima.py`, `esporta_mesh.py`, `flipbook.py`, `flipbook_atlante.py`, `rumore.py`).
  - Video per l'utente: `docs/proposte/geyser/`.
  - Per metterla nel gioco: in `scripts/game/lei_sbuca.gd` creare `GeyserMesh` al posto di `GeyserFossa` (`_geyser` è tipizzato `GeyserFossa`: va bene, perché ne è una sottoclasse) e spostare i file da `proposte/` a un percorso esportato.

## Strumenti

- **Mantaflow** funziona solo col Blender completo (`/home/user/tools/blender-full/blender-5.2.2-linux-x64/blender -b`), non col modulo `bpy`.
  - Simulazione: `--python assets_src/geyser/simula.py -- 96 <cache>`, circa 7 minuti e 0,9 GB.
  - Esportazione: `-b <cache>/geyser.blend --python assets_src/geyser/esporta_mesh.py -- <glb> 18000`.
  - La cache non è nel repo: va rifatta.
- **Scatti e video nel gioco**: `xvfb-run ... godot --rendering-driver vulkan --fixed-fps 30|24 [--write-movie <cartella>/f.png] --script res://tests/run.gd -- res://proposte/geyser/video_geyser.gd ...`. Ogni giro sulla sala costa 10-25 minuti su llvmpipe. Usa sempre `flock /home/user/tools/render.lock`.
- **Memoria**: la sala da sola arriva a circa 12,7 GB, il limite è circa 13,4 GB. In `video_geyser.gd` tolgo Interni, Tecnici, angoli, balconata, Polaroid e `Vasca/Medusa`. Per misurare il picco uso uno script che campiona `ps` mentre gira (`/usr/bin/time` qui non c'è).
- **Suite**: le 10 del CI in `.github/workflows/build.yml`, più `test_agnellino`. Tutte headless, `--fixed-fps 60`.

## Trappole note

- **Disco**: restano circa 2 GB liberi. Le particelle FLIP a risoluzione 96 non compresse occupano 4,5 GB; la cache a risoluzione 112 con una sola particella per cella si sfilaccia in schizzi; la levigatura della mesh di Mantaflow erode l'acqua.
- **Rigenerare raccordo o arredo** ricodifica le texture JPG: riportale con `git checkout --`. Poi confronta i nodi del glTF nuovo con quelli vecchi.
- **Arredo**: `tappa7_arredo.py` usa un solo generatore casuale per tutto. Aggiungere `vuoti` sposta tutto quello che viene dopo, quindi per liberare spazio gli oggetti vanno tolti dopo averli creati.
- **Godot**: una sottoclasse non può ridichiarare costanti o variabili del padre (`SHADER` ecc.). Assegnare un tipo diverso a una variabile tipizzata con `set()` non dà errore ma non fa niente.
- **Comandi `rm` con variabili**: il controllo di sicurezza li blocca. Usa `"${X:?}"` oppure percorsi letterali.
- Il fotogramma d'inizio del geyser nel log (`GEYSER dal fotogramma`) non coincide con l'indice del fotogramma nel video. Per allinearli usa `griglia_prima.py`, che cerca il primo fotogramma con molta acqua chiara (lo script è nello scratchpad, va rifatto).

## Lavori aperti

1. **Punto bianco al centro del geyser**. Si vede fisso sullo schermo, vicino al centro, in V1 e V2; col `GeyserFossa` di oggi non c'è.
   - Cause escluse, provate una per una: l'atlante del flipbook; le particelle (`SENZA_PARTICELLE`, che nasconde anche la nebbiolina); la nebbia d'impatto e la macchia di bagnato del getto (l'acqua ora sta sul livello di render 20, escluso dalle Decal); la torcia (`SENZA_TORCIA`, ma non ho verificato che si sia davvero spenta); la retroilluminazione; il cartellone a 1,2 m e a 1,7 m verso la camera.
   - La sonda dice che il raggio di quel pixel passa a 2,14 m dal centro del geyser.
   - Prossima prova, interrotta per la pausa: `SENZA_CARTELLONE=1`. Se il punto resta senza colonna, è qualcosa della sala, dietro o dentro la fossa, che il geyser di oggi copriva.
   - Ora che l'utente ha scelto la V1, controllalo prima di tutto sulla V1.
2. **Geyser V1 nel gioco**: collegarlo in `lei_sbuca.gd` (vedi sopra), poi le suite tappa 8 e un video.
3. Nella mia lista erano ancora aperti, ma va verificato se li ha già fatti qualcun altro: lamiera vicino all'estintore e tubo bypass (B1e e B1v), turbina nuova del cancello da montare.
