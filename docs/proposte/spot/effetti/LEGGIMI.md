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

È per le inquadrature 8-9, sopra l'immagine dell'occhio: va su una camera o su un video, come il filtro. Lo script `OcchioIpnotico` (un `ColorRect`) lo muove tutto. Il montaggio fa salire solo `progresso` da 0 a 1, in circa 5 s; il resto lo fa lo script:
- il battito che accelera da `bpm_inizio` (72) a `bpm_fine` (200), con due colpi per battito;
- a ogni colpo la pupilla si allarga, l'immagine fa un balzo verso chi guarda, i colori si separano e c'è una scia verso il centro;
- spirali e anelli rosa e viola girano nella pupilla e nell'iride, sempre più forti e più larghi;
- fuori dall'iride l'immagine si scurisce e pulsa di viola;
- i fotogrammi saltano: l'effetto si ferma 2-4 fotogrammi e poi riparte avanti. Lo script manda il segnale `fermo(acceso)`, così il montaggio ferma anche l'animazione dell'occhio di mascotte;
- il lampo in negativo (a `negativo_a`, 0,72), più qualche lampo corto verso la fine;
- alla fine lo scatto in avanti dentro la pupilla (da `scatto_da`, 0,93) e il nero;
- con `camera` e `bersaglio` (l'occhio) la pupilla resta al centro dell'effetto anche se la camera si muove; su un video si mette `centro` a mano.

Prove sul modello vero di Jilly, come nel menu, con la camera davanti all'occhio:
- `occhio_scatti.jpg`, a progresso 0, 0,3, 0,6, 0,72 (il negativo), 0,9 e 0,96;
- `occhio_prova.mp4`, 6,7 s: 1 s fermo, poi progresso da 0 a 1;
- `occhio_vhs_prova.mp4`, lo stesso col filtro VHS sopra, come sarà nello spot;
- `occhio_vhs_fotogrammi.jpg`, fotogrammi presi dal video col filtro.

L'animazione dell'occhio, cioè la pupilla vera che si muove e la palpebra, è di mascotte. Qui l'occhio è fermo, e si muovono solo gli effetti.

Per rifarle: `godot/tests/spot/prova_vhs.gd` e `godot/tests/spot/prova_occhio.gd`. Come si lanciano è scritto in cima ai file.
