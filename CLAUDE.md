# Note per Claude

Gioco horror 3D in prima persona fatto con Claude per deeplylion-droid. L'utente scrive in italiano e usa spesso il telefono: rispondi in italiano, in modo breve. Tutte le decisioni prese finora sono in `docs/GDD.md`: leggilo prima di lavorare.

## Regole

- **Stile, trama e design li decide l'utente.** Soprattutto all'inizio, non andare avanti su queste scelte senza un suo riscontro. Prepara 2-3 proposte con immagini o render, poi fermati e chiedi. Il lavoro tecnico (pipeline, codice, ottimizzazione, strumenti) si può fare liberamente.
- **Non cancellare niente** di quello che l'utente ha approvato: concept, modelli, Release, tag. Per le cose scartate, spostale in una cartella a parte senza eliminarle.
- Il repository è **pubblico**, e l'utente è d'accordo. Non metterci mai chiavi o segreti: la chiave di Meshy sta nella variabile d'ambiente `MESHY_API_KEY`.
- Nessun file sopra i 50 MB. Per le immagini concept usa JPG di buona qualità.

## Struttura

- `docs/`: `GDD.md` con le decisioni, `concept/` con le immagini approvate, `proposte/` con le proposte in attesa di risposta.
- `godot/`: il progetto del gioco (Godot 4.7.2, Forward+).
- `labs/`: progetti Godot di prova separati, per esempio `labs/acqua/`. Il codice buono si sposta poi in `godot/`.
- `assets_src/`: sorgenti degli asset, cioè GLB grezzi di Meshy, file `.blend` e texture originali. Per ogni asset ci sono gli script che lo generano.
- `tools/`: script comuni. `meshy.py` è il client dell'API di Meshy, `blender/` contiene gli script Blender, `setup_ambiente.sh` prepara una sessione nuova.

## Strumenti nel sandbox

- **Prepara l'ambiente** in una sessione nuova con `bash tools/setup_ambiente.sh`. Installa Vulkan software, Xvfb, Godot e il venv di Blender.
- **Godot**: il comando `godot` è la 4.7.2. Per gli screenshot senza schermo usa `xvfb-run -a -s "-screen 0 1280x720x24" godot --path <progetto> --rendering-driver vulkan --resolution 1280x720 ...`. Gira su llvmpipe, Vulkan software sulla CPU: lento ma funziona anche con nebbia volumetrica, SSR e ombre. Gli errori ALSA sull'audio sono normali.
- **Blender**: `/home/user/tools/blender-venv/bin/python script.py` (Blender 5.2 come modulo `bpy`, con numpy, pillow, opencv e scipy). Per i render usa Cycles su CPU e il denoiser.
- **Meshy**: `tools/meshy.py`, con le funzioni `create`, `wait`, `download` e `balance`. Prima di cambiarli, leggi i parametri in `https://docs.meshy.ai/llms.txt`.
- La rete permette Poly Haven, ambientCG, Kenney, Quaternius, Meshy, Hugging Face e `downloads.godotengine.org`. I download di Release da GitHub sono bloccati.
- Le macchine hanno 4 CPU: render lunghi e build possono rallentare gli altri agenti.

## Git

- `main` deve restare stabile. Ogni area si sviluppa su un branch `lavoro/<area>`, in un worktree `/home/user/wt/<area>`.
- Il coordinatore unisce i branch in `main` dopo averli controllati.
- Se il push fallisce con 429 ("Too many concurrent git operations"), aspetta 10-30 secondi e riprova. Fai pochi push, solo alle tappe importanti.
- I messaggi di commit sono in italiano e descrivono cosa è cambiato.
