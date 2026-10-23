# Effetti dello spot: filtro VHS e occhio ipnotico

Sono prove dal motore, su immagini vere del gioco.

## Filtro VHS e TV a tubo (`godot/shaders/spot/vhs.gdshader`)

È uno shader `canvas_item` a schermo intero, nato dallo schermo del monitor della sala pompe (`shaders/tecnici/crt.gdshader`). Funziona in due modi:
- **su un video o su un'immagine**: il materiale va sul `VideoStreamPlayer` o sul `TextureRect`, con `dallo_schermo` spento;
- **sopra una camera**: un `ColorRect` a tutto schermo in un `CanvasLayer`, con `dallo_schermo` acceso, che legge lo schermo. Se sotto c'è un altro effetto letto dallo schermo, prima ci va un `BackBufferCopy`.

Cosa fa:
- le righe del tubo, la curvatura e la vignetta;
- il colore largo e sbavato, rosso e blu sfasati, un poco di alone;
- la grana, i puntini bianchi del nastro, le righe che tremano;
- la banda del tracking che passa e il cambio testine in fondo allo schermo.

Parametri per il montaggio:
- `guasto` (0-1): il nastro si rovina, per l'inquadratura 7. Il tracking salta, i colori colano, blocchi di righe si strappano, l'immagine scorre e salta in verticale, il colore si perde;
- `schermo_blu` (0-1): il blu del videoregistratore senza segnale;
- `play` (0-1): la scritta "▶ PLAY", a quadretti come sui videoregistratori;
- `tempo_spostato`: per spostare il tempo del rumore.

Prove:
- `vhs_scatti.jpg`, su uno scatto della sala: normale, blu col PLAY, PLAY, guasto a metà, guasto pieno;
- `vhs_prova.mp4`, 9 s: blu col PLAY, poi l'immagine, poi il guasto che sale da 0 a 1;
- `vhs_fotogrammi_video.jpg`, fotogrammi presi dal video.

## Occhio ipnotico (`godot/shaders/spot/occhio_ipnotico.gdshader` e `godot/scripts/spot/occhio_ipnotico.gd`)

È per le inquadrature 8-9, sopra l'immagine dell'occhio: va su una camera o su un video, come il filtro. Lo script `OcchioIpnotico` (un `ColorRect`) lo muove tutto. Il montaggio fa salire solo `progresso` da 0 a 1, in circa 5 s; il resto lo fa lo script.

Seconda versione (coordinatore, 23 ottobre: "più forza"; l'utente aveva chiesto "ipnotico aggressivo crescente, molto horror"). La crescita deve vedersi:
- **all'inizio**: l'occhio dello spot allegro, quasi carino;
- **poi l'occhio si guasta**:
  - le vene compaiono sul bianco e si gonfiano a ogni colpo. Qui le disegna lo shader; nello spot, se mascotte aggiunge l'instance uniform `vene` al materiale dell'occhio, si usano quelle vere, col bulbo venato (`usa_vene`);
  - i colori virano a un viola e a un rosso cupi e saturi;
  - la vignetta si chiude verso il nero;
- **a ogni battito** (da 72 a 200 bpm, due colpi per battito):
  - la spirale nella pupilla (bande nette rosa acceso e nero) gira più veloce;
  - lo schermo trema, sempre di più;
  - i colori si separano molto, e la pupilla si allarga (anche quella vera, con `usa_pupilla`);
- **i fotogrammi saltati** sono sempre più frequenti e lunghi, da 2 a 5 fotogrammi. Ogni volta parte il segnale `fermo(acceso)` per il montaggio;
- **i lampi in negativo**:
  - quelli fissi di `lampi` (0,55, 0,7, 0,8, 0,86, 0,9 del progresso), sempre più fitti e lunghi, da 1 a 3 fotogrammi;
  - più qualcuno a caso verso la fine;
- **alla fine** lo scatto in avanti dentro la pupilla (da `scatto_da`, 0,93), pulito, senza salti né lampi, e il nero. Il ronzio (`godot/assets/spot/ronzio_spot.ogg`) ha lì un soffio che sale e il colpo forte.

Con `camera` e `bersaglio` (l'occhio) la pupilla resta al centro dell'effetto anche se la camera si muove; su un video si mette `centro` a mano.

Prove sul modello vero di Jilly, come nel menu, con la camera davanti all'occhio e col ronzio:
- `occhio_prova.mp4`, 6,7 s: 1 s fermo, poi progresso da 0 a 1;
- `occhio_vhs_prova.mp4`, lo stesso col filtro VHS sopra, come nello spot;
- `occhio_vhs_fotogrammi.jpg`, 8 fotogrammi lungo il tempo: l'occhio carino, la spirale, le vene e il rosso, un lampo in negativo, il buio che si chiude, lo scatto, la spirale a tutto schermo prima del nero.

La prima versione, rosa pastello e morbida, è in `docs/proposte/spot/scartati/`.

L'animazione dell'occhio, cioè la pupilla vera che si muove e la palpebra, è di mascotte. Qui l'occhio è fermo, e si muovono solo gli effetti.

Per rifarle: `godot/tests/spot/prova_vhs.gd` e `godot/tests/spot/prova_occhio.gd`. Come si lanciano è scritto in cima ai file.
