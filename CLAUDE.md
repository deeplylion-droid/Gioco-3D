# Note per Claude

Gioco horror 3D in prima persona fatto con Claude per deeplylion-droid. L'utente scrive in italiano e usa spesso il telefono: rispondi in italiano, in modo breve. Tutte le decisioni prese finora sono in `docs/GDD.md`: leggilo prima di lavorare.

## Regole

- **Stile, trama e design li decide l'utente.** Soprattutto all'inizio, non andare avanti su queste scelte senza un suo riscontro. Il lavoro tecnico (pipeline, codice, ottimizzazione, strumenti) si può fare liberamente.
- **All'utente si mostrano solo asset del gioco finiti**: render di modelli 3D veri e screenshot presi dal motore. Non vuole più vedere immagini generate dall'IA (concept o storyboard): non lo aiutano a immaginare il gioco. Le immagini generate si possono usare solo internamente, come input per i modelli 3D o come texture. Anche le proposte vanno fatte su asset veri: per esempio lo stesso modello renderizzato con due materiali diversi.
- **Ogni scelta di design, di estetica o di funzionalità di gioco si discute con l'utente prima di farla** (regola dell'utente, 15 ottobre). Non decidere da soli e non mettere niente nel gioco senza la sua approvazione esplicita. Quando c'è da scegliere tra due o tre possibilità, **prima si descrivono le opzioni per iscritto** e gli si chiede se ha bisogno di vederle (regola dell'utente, 21 ottobre, per non sprecare crediti): prove, render e scatti si fanno solo se li vuole, e sempre su asset veri. Nelle pagine per lui le immagini già fatte si mettono sempre, perché gli piacciono: si evitano solo render o scatti nuovi fatti apposta per la pagina (regola dell'utente, 22 ottobre). Il lavoro puramente tecnico (bug, prestazioni, strumenti, pipeline) si può fare liberamente.
- **Le cose grosse si fanno giuste alla prima** (regola dell'utente, 21 ottobre): troppi dettagli sono stati rifatti per incoerenze. Prima di consegnare, ogni squadra controlla la coerenza con il GDD, con le scelte già fatte e con il resto del gioco (scala, luci, stile, posizione degli oggetti, scritte solo a disegni).
- **Posizionamento degli oggetti concreto e coerente** (regola dell'utente, 21 ottobre: "non possiamo tornarci troppe volte"). Ogni oggetto messo in scena deve rispettare tutte queste regole, e chi lo mette le controlla prima di consegnare:
  - poggia su qualcosa o è fissato a qualcosa: niente oggetti sospesi o compenetrati;
  - i tubi, i cavi e le condotte partono e arrivano da qualche parte;
  - niente passa davanti alla faccia del giocatore, sulle strade, sulle scale o nelle discese: lo spazio fino a 2 m d'altezza sopra dove si cammina resta libero;
  - niente copre o blocca porte, cancelli, Polaroid, pulsanti e oggetti da raccogliere;
  - le pile e i mucchi stanno come starebbero davvero (il pesante sotto, appoggiati al muro, con un perché), e ogni oggetto ha un motivo per stare lì;
  - alla fine si fa il giro dagli occhi del giocatore lungo tutta la strada della zona, e il controllo automatico di posizionamento della CI deve passare (`godot/tests/controllo_posizionamento.gd`; come si lancia e come si segna un caso "voluto" è in `docs/tecnico/posizionamento/LEGGIMI.md`).
- **Quando serve una risposta dall'utente si fa un questionario** (sua richiesta, 15 ottobre): una pagina con le immagini e, per ogni voce, i pulsanti per approvare o far cambiare, più una nota. Gli agenti non chiedono direttamente all'utente: mandano al coordinatore le domande e le immagini.
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
- **Memoria: 15 GB.** Un Godot con la sala principale arriva a 12-13 GB, e due processi pesanti insieme fanno riavviare la macchina: è successo due volte il 16 ottobre. Ogni processo Godot o Blender passa da `flock /home/user/tools/render.lock`, uno alla volta, compresi import, test, `check_scripts` e build. Lo scatto parte solo con almeno 13,5 GB di `MemAvailable` (`/proc/meminfo`). Mentre gira, niente elaborazioni pesanti di immagini.

## Git

- `main` deve restare stabile. Ogni area si sviluppa su un branch `lavoro/<area>`, in un worktree `/home/user/wt/<area>`.
- Il coordinatore unisce i branch in `main` dopo averli controllati.
- Se il push fallisce con 429 ("Too many concurrent git operations"), aspetta 10-30 secondi e riprova. Fai pochi push, solo alle tappe importanti.
- I messaggi di commit sono in italiano e descrivono cosa è cambiato.
