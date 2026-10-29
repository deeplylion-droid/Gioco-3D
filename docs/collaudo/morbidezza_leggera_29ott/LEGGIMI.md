# Collaudo della morbidezza leggera (lavoro/morbidezza-leggera 88355cee), 29 ottobre

I tentacoli di lei calcolati in parallelo (WorkerThreadPool, 8 "aiuti" fuori dall'albero, le ossa scritte dopo sul
thread principale). Prima: `lavoro/godot` 1d9ecf41, con lo stesso `morbidezza_lei.gd` della base del branch (0b2c2564).
Prove in locale (4 CPU, llvmpipe), scambiando solo `morbidezza_lei.gd`.

**Esito: va bene.** Nessuna differenza dove i test sono deterministici, niente crash né errori nelle prove dei thread,
costo molto più basso. Tre cose da sapere sotto (il tunnel non deterministico già da prima, qualche fotogramma
massimo più alto, lo scatto di lei che sbuca a 60 fps che c'è anche nella base).

## 1. Aspetto: identico al bit

Ogni punto di ogni tentacolo in ogni fotogramma registrato dai test (MORB_DUMP in `tests/misura_morbidezza.gd`),
confrontato prima e dopo (`tests/collaudo/confronta_dump_morbidezza.gd`):

| prova | 30 fps | 60 fps |
|---|---|---|
| inseguimento (3 vasche, 3 scoli, grata, SB1) | identico | identico |
| le 5 posizioni del giocatore nella vasca 3 + quella del test (`tests/prova_vasca2_giocatore.sh`) | identiche, pelle 0 vertici dentro in tutte | |
| tuffo e affacciata (`test_morbidezza`) | identico | |
| lei che sbuca (`test_morbidezza_sbuca`) | identico | identico |
| tunnel sottomarino (`test_morbidezza_tunnel`) | diverso, fino a 48 cm | diverso |

Il tunnel **non è deterministico già da solo**: due giri della versione vecchia differiscono fra loro negli stessi
fotogrammi (dal 332 della strada, 66 nella curva a 140 m, tutta la curva a 291 m) e di quanto differiscono vecchia e
nuova (fino a 23-38 cm); così due giri della nuova. Non viene dalla morbidezza leggera. Curve a 442 m e schianto:
identici in tutti i giri.

## 2. Thread: niente crash, niente errori, niente orfani

`tests/collaudo/stress_morbidezza_thread.gd`: nel gioco vero, Continua dalla partenza dell'inseguimento, lei sale in
una vasca coi tentacoli morbidi e intanto: lei ti prende (morte, la sala si ricarica e lei si libera), `respawn()` a
metà salita, pausa di 1,5 s e ripresa, al titolo a metà salita e di nuovo Continua; dopo ogni giro, al titolo, si
contano nodi orfani e oggetti. In più, la chiusura del gioco (`Game.esci`) a metà salita.

- senza schermo, gioco vero, 3 giri: 12 controlli verdi; orfani al titolo sempre 0; gli oggetti al titolo crescono di
  9-17 a giro, **uguali con la versione vecchia** (11 e 9): non sono gli aiuti;
- chiusura a metà salita, 3 volte: uscita pulita; una volta un errore dell'audio (sotto), che non è della morbidezza;
- col renderer vero (Vulkan, `tools/ci/senza_bug.sh`), nella sala dell'inseguimento da sola (la sala intera col
  renderer vero supera la memoria del sandbox: ucciso a 12 GB, anche senza la morbidezza): 2 giri con morte,
  respawn, pausa, titolo, poi chiusura a metà salita: 8 controlli verdi, **nessun "ERROR: BUG,"**, nessun altro
  errore, oggetti al titolo fermi (2609 e 2609).

Il codice: gli aiuti scrivono solo nei loro conti; forme, griglia, sezioni e mobili si leggono e basta, preparati
prima sul thread principale, che aspetta la fine del gruppo prima di scrivere le ossa: nessun lavoro resta in corso
fra un fotogramma e l'altro, quindi la ripartenza non può liberare lei a metà lavoro. `tunnel` sono dati, non nodi.

Fuori dalla morbidezza, da passare a chi tiene l'audio: alla chiusura del gioco durante l'inseguimento, una volta su
tre, `ERROR: Lambda capture at index 4 was freed` in `addons/audio/audio.gd:1291` (`Funzione.aggiorna`: il nodo è
ancora valido, ma una cosa catturata dalla lambda è già liberata).

## 3. Costo (ms; medio, 95%; CPU del sandbox)

| posto | 30 fps prima | 30 fps dopo | 60 fps prima | 60 fps dopo |
|---|---|---|---|---|
| grata | 9,38 / 21,0 | 4,78 / 10,4 | 5,44 / 10,6 | 3,13 / 6,1 |
| scolo_1 | 4,35 / 7,7 | 3,44 / 7,7 | 3,71 / 6,4 | 2,73 / 4,0 |
| vasca_2 | 2,78 / 4,5 | 1,91 / 2,4 | 2,72 / 3,9 | 1,86 / 2,8 |
| lei che sbuca | 6,25 / 12,8 | 3,53 / 5,4 | 5,32 / 10,4 | 2,96 / 4,0 |
| tunnel, strada | 2,61 / 3,9 | 1,91 / 2,6 | 2,23 / 3,2 | 1,84 / 2,5 |
| tunnel, schianto | 3,70 / 8,7 | 2,77 / 5,6 | 3,15 / 5,7 | 2,45 / 4,6 |

Il fotogramma peggiore a volte è più alto con la nuova, in pochi fotogrammi isolati: tunnel strada 22 ms a 30 fps
(prima 16), curva a 291 m a 60 fps 25,7 ms (prima 7), lei che sbuca a 60 fps 17,6 (prima 11,9). Forse il pool di
thread occupato in quell'istante (caricamenti). Non si ripete negli altri giri dello stesso posto; da guardare se
ricapita in gioco.

## 4. I 2 KO a 60 fps (anche nella base)

- **grata, "salto" 35,3 m/s**: dalla camera del giocatore (dietro la grata, 3,5 m) non si vede. Il tentacolo
  scavalca in basso accanto alla radice, dietro il bordo del pozzetto e la base della grata. Nei fotogrammi con lei in
  vista (96-108, 129-159 a 60 fps: `grata_60fps_fotogrammi_96-159.jpg`) nessun tentacolo salta. (Fra 109 e 127 la
  camera guarda il bordo perché il video punta gli occhi di lei, che è sotto.)
- **scolo_2, pelle 4 cm per 1-2 fotogrammi**: col giocatore dentro la vasca di scolo non si nota
  (`scolo2_60fps_foglio.jpg`, `scolo_2_60fps_dopo.mp4`): la parte bassa dei tentacoli resta dietro il bordo.
- In più, trovato qui: **lei che sbuca (tappa 8) a 60 fps ha anche lei uno scatto di 35,0 e 34,3 m/s** (KO "niente
  scatti" di `test_morbidezza_sbuca` a 60 fps), uguale nella base: a 30 fps non c'è. Da guardare con le correzioni.

## File

- `grata_60fps_dopo.mp4`, `scolo_2_60fps_dopo.mp4`: dal motore, dalla camera del giocatore, a 60 fps, versione nuova.
- `grata_60fps_foglio.jpg` (un fotogramma ogni 12), `grata_60fps_fotogrammi_96-159.jpg` (uno per uno, la parte di
  lei), `scolo2_60fps_foglio.jpg` (uno ogni 10).
- Script: `tests/collaudo/stress_morbidezza_thread.gd` (PROVA=1: la sala dell'inseguimento da sola),
  `tests/collaudo/confronta_dump_morbidezza.gd`, MORB_DUMP in `tests/misura_morbidezza.gd`;
  `tests/video_inseguimento_lei.gd` ora va a tempo anche a 60 fps (contava i secondi a 30 fotogrammi) e ha "scolo_N".

## Le correzioni di grafica (lavoro/morbidezza-correzioni 7accf064): lei che sbuca a 60 fps

Prima = 88355cee, dopo = 7accf064 (per lei che sbuca cambia solo `morbidezza_lei.gd`).

- `test_morbidezza_sbuca` a 60 fps: lo scatto da 35,0 e 34,3 m/s scende a 19,1 e 15,5 m/s (il limite è 25), pelle 0
  vertici dentro in tutte e due, test verde (prima 3 KO).
- Dalla camera del giocatore, 7 m davanti alla fossa, a 60 fps (`tests/collaudo/scatti_lei_sbuca.gd`, la sala per
  parti come gli scatti della nebbia: solo sala, luci, vasche e lei, e le mesh entro 22 m; memoria 12,2 GB): il punto
  dei tentacoli più veloce va da 34 m/s (fotogrammi 118, 138, 158: il tentacolo che pende dal bordo cambia posto di
  colpo) a 15,8 m/s. `lei_sbuca_60fps_prima_dopo.jpg` (i fotogrammi intorno agli scatti, ritagliati su di lei) e
  `lei_sbuca_60fps_prima_dopo.mp4` (affiancati, a 60 fps); `lei_sbuca_60fps_prima_138.jpg` e `..._dopo_138.jpg`
  interi.
- Grata e scolo_2: gli scatti di grafica (`docs/tecnico/morbidezza_leggera/` sul suo branch) prima e dopo coincidono;
  nessun tentacolo che salta o entra nella struttura.
