# Passaggio: grafica

**Branch** `lavoro/grafica`. L'ultimo lavoro è d39dced, già in main. Il branch riparte da `origin/main` 96d0437.

Il lavoro arriva dal coordinatore. Quando un compito è finito, gli si manda l'hash con i numeri dei test, e il push si fa solo con tutte le suite verdi.

## File principali

- `godot/scripts/game/sala_principale.gd`: la sala grande.
  - Precarica la torre in un thread quando compaiono gli acquari (`_precarica_torre`).
  - Poi la costruisce nascosta (`_prepara_torre`) e la mostra all'apertura del portone (`_mostra_torre`).
  - Se il caricamento in thread fallisce, ripiega su `load()`.
  - Negli scatti si spegne con `Engine.set_meta(&"precarica_torre_spento", true)`.
  - Riserva: se il portone è aperto da più di 20 s (`ATTESA_TORRE`) e il thread non ha finito, la torre si carica sul thread principale con `CACHE_MODE_IGNORE_DEEP`; la copia del thread, quando arriva, si lascia andare.
- `godot/scripts/risalita/risalita_gioco.gd`: le stanze della Risalita (fiume e infermeria) non stanno più sempre in sala (23 ottobre, memoria).
  - Si caricano nel thread dal checkpoint della sala pompe (6) al magazzino (15), o col giocatore vicino; oltre la serranda (16), lontane più di 14 m, si scaricano.
  - Il thread carica anche i file che le stanze usano con `load()` (`scenes/risalita/risorse_stanze.json`); poi il capannone si costruisce a pezzi (`costruisci_a_pezzi` di `fiume_gioco.gd`, 12 ms per fotogramma).
  - Il fiume a pezzi rimette il generatore comune com'era a ogni ripresa (`_tiri`): rocce, palme e transenne vengono identiche.
  - La sala tiene da subito un materiale per ogni shader delle stanze che non ha (`scenes/risalita/materiali_campione.tres`).
  - Elenco e campioni si rifanno con `tests/aggiorna_risorse_risalita.gd`; `test_risalita_tardi` dice quando servono.
  - Lo stato degli oggetti delle stanze scaricate lo tiene GameState (`parcheggia`, `ripristina`, `in_costruzione`) ed entra nelle istantanee.
  - Le stanze si mostrano entro 4 m dalle loro zone (`VICINO`, come prima); la costruzione accelera (pezzi da 40 ms, mai tutto in un fotogramma) solo col giocatore dentro le zone con 1 m di margine (`DENTRO`): la metà nord della sala pompe sta nel margine di 4 m ma non lì (collaudo del 23 ottobre, fermo di 503 ms). Misura: `tests/sonda_risalita_corsa.gd [dentro]`.
  - Ripartendo da un checkpoint vicino alle stanze si caricano subito, in `_ready`. Strumenti e test che le vogliono sempre: `Engine.set_meta(&"risalita_subito", true)` o `carica_subito()`.
- `godot/scripts/game/sala_torre.gd`, scena `scenes/sala/torre/sala_torre.tscn`: la torre degli scivoli.
  - `costruisci_a_pezzi()` lavora a passi con un budget di ms per fotogramma.
  - `prepara_materiali()` compila le pipeline fuori vista, con una SubViewport sullo strato `1<<19`.
- `godot/assets/ambiente/torre/torre_post_import.gd`: rende le collisioni a doppia faccia e divide le forme oltre le 8000 facce.
  - Se lo cambi, cancella `.godot/imported/torre_*` per forzare il reimport.
- Effetti dello zaino:
  - `water_pack.gd`, `slide_fx.gd`;
  - `getto_potente.gd`: l'impatto si riduce da vicino (`vicino_da` 4 m, `vicino_pieno` 1,2 m, `VICINO`); gocce e nebbia dell'impatto hanno materiali loro che spariscono davanti alla camera (`vicino_camera` in `goccia_chiara`, `near_camera` in `water_mist`);
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
- **Controllo di posizionamento** (`tests/controllo_posizionamento.gd`, nella CI, con `--fixed-fps 60`): rapporto in `docs/tecnico/posizionamento/rapporto.md`, eccezioni e casi assegnati in `tests/posizionamento_eccezioni.json`. Le zone nuove vanno nella lista `ZONE`.
- **Prove fuori dalla CI**: `tests/prova_*`, `misura_*`, `sonda_*`. `misura_impatto.gd` misura il costo dello spruzzo contro un muro a 0,8-6 m (ms, GPU, overdraw a schermo, particelle vive). `sonda_risalita_memoria.gd prima|dopo` misura la sala nei punti di passaggio (RSS, memoria statica, texture e mesh in scena) e il fotogramma più lungo mentre la Risalita entra; `sonda_fiume_impronta.gd <file> [pezzi]` scrive le posizioni di tutti i nodi delle stanze, per confrontare due versioni del codice che le costruisce.
- **Peso del pacchetto**:
  - `git worktree add` in `/home/user/wt/…`, non `git clone`: la copia di `.git` (5,7 GB) è lentissima;
  - poi i passi della CI e `godot --export-pack "Windows Desktop" x.pck`;
  - infine `python3 tools/verifica_pck.py x.pck 20`.

## Trappole note

- `pkill -f …` può colpire la propria shell (exit 144): usa i PID. Anche `while pgrep -f X` trova sé stesso e non finisce mai: usa `pgrep -x godot`.
- Luci e blackout: alla ripartenza da un checkpoint `LuciRisveglio` rimette il blackout a tutte le luci della scena senza la meta `risveglio_ignora`. Le luci che devono restare accese dopo la tappa 6 vanno segnate (la torre lo fa in `_fuori_dal_blackout`, v0.3.8): al primo passaggio non si vede, perché arrivano dopo il blackout.
- Le coroutine della torre a pezzi (`costruisci_a_pezzi`, `prepara_materiali`) si fermano se la torre esce dall'albero (una morte ricarica la sala).
- Blocco del pool di thread (v0.3.8): in Godot 4.7 l'attivazione del gruppo di shader avanzato con la coda del pool piena di pipeline blocca tutto con 4 worker (solo a cache degli shader vuota). Lo evita `Grafica._attiva_shader_avanzati` all'avvio; test `test_pool_sala.gd` nella CI con override.cfg a 4 worker (esce da solo dopo il RISULTATO: le pipeline in coda su llvmpipe superano i 12 GB). La prova a mano è `tests/prova_blocco_pool.gd`; per riprodurre serve la cache vuota (`user://shader_cache`).
- Ogni shader nuovo costa 100-190 ms sul thread principale col gruppo avanzato acceso: i materiali creati da codice dentro passi a budget vanno preparati prima (`SalaTorre.materiali_campione`, tenuti dalla sala).
- Sala intera più torre disegnata non stanno nella memoria di llvmpipe (OOM, processo ucciso): gli scatti della torre si fanno con la torre da sola (`tests/scatti_torre_morte.gd`).
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
