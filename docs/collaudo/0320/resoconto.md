# Giro finale della 0.3.20 (2 novembre)

Squadra collaudo. Ho controllato la candidata `lavoro/candidata-0320` **e4ee1a34**: lavoro/godot 49099d4f più tre unioni:
- vasche-sotto bea845ae;
- corridoio-20 07dabc0c;
- bambino-cubo 11e926bf.

Ho guardato solo le zone cambiate, dagli occhi del giocatore, col giocatore vero:
- col renderer vero, a parti: la torre da sola con l'inseguimento, e la Risalita della scena di prova;
- senza schermo, nel gioco intero, i test, le ripartenze e i Continua.

**Esito: superato, nessun difetto. 0 righe "ERROR: BUG," in tutti i log.**

L'angolo vuoto a sinistra dell'ingresso degli scatoloni, dove sparisce il bambino, non lo conto: lo decide l'utente.

## Inseguimento

| Prova | Esito |
|---|---|
| test_occhio_sopra_acque | 64 ok: in ogni acqua e in ogni tubo e scolo l'occhio resta sopra il pelo, e ci sono le 6 pareti d'acqua nelle bocche |
| Bocche dei 6 tubi che partono dalle vasche, dagli occhi (`scatti_occhio_acque.gd`, `fogli/tubi_bocche.jpg`) | dalla vasca la bocca sotto il pelo è scura, coperta dall'acqua. Da dentro il tubo, guardando indietro, si vede la parete d'acqua scura in basso e la sala sopra: niente acqua trasparente né tubo asciutto |
| Ogni acqua, accovacciati (`fogli/acque_accovacciati.jpg`) | vasche dei bivi, scoli, raccolte, fondo, bacino: si legge come acqua |
| Entrando a piedi nei tubi, scivolando fino in fondo (`fogli/tubi_entrando.jpg`; scolo_0 e tubo_3 dagli occhi, e una sonda per tutti i tubi) | dalle vasche dei bivi si entra in tubo_1, scolo_0, tubo_2, scolo_1 e tubo_3 e si scivola fino in fondo; nello scolo_2 la sonda in 20 s arriva a 25 punti su 33 (gli scoli sono le trappole dove lei prende). L'occhio sopra il pelo, al più basso, è 0,107-0,314 m. Nel primo tubo (tubo_0, dal fondo della torre) la mia sonda in piedi si ferma dopo 2 m: test_inseguimento ci passa accovacciato, come vuole il gioco ("il primo tubo: ci si accovaccia") |
| SB1 nel bacino a 74 cm (`scatti_sb1_scende.gd`, `fogli/sb1.jpg`) | lei sbuca dal pozzo, guarda e scende senza salire: la testa va sempre giù, da 0 a -3,84 m. La luce rosa sfuma in 0,4 s. Il bordo arancione del pozzo si vede appena sotto il pelo |
| Paperella del bacino (`fogli/bacino_paperella_scaletta.jpg`) | galleggia: 5 cm sotto il pelo e 50 cm sopra, dagli occhi da tre parti e da vicino al pelo |
| test_inseguimento 43, test_morbidezza_inseguimento 72, test_lei_discese 21 | ok |

## Fiume

| Prova | Esito |
|---|---|
| Strada dall'ingresso del capannone alla fine della fila e al salvagente, e ritorno, col giocatore vero (`tests/collaudo/fiume_giro.gd`, `fogli/fiume_strada.jpg`) | mai fermi, niente fra 0,1 e 2 m sopra i piedi (collisioni) |
| Pile lungo la strada, avanti, a sinistra e a destra, e pianta (`scatti_pile_fiume.gd`, `fogli/pile_*.jpg`) | col 20% è buio, ma le colonne si leggono: sfalsate, di traverso, a gradini. Nessun buco nella strada, e la strada è libera. Posizionamento: tutto appoggiato |
| Cime aperte vicino all'ingresso (29 nei primi 22 m; le 8 più vicine di fronte, dall'alto e di lato, con una lampadina tecnica: `fogli/cime_ravvicinati.jpg`) | scatoloni tolti, girati e di traverso sullo strato sotto. Nei ravvicinati non vedo scatoloni sospesi o staccati, e il controllo di posizionamento le dà tutte appoggiate (0 casi nuovi). Dagli occhi, dalla strada, le cime sono sopra la testa e al buio (`fogli/cime_dagli_occhi.jpg`) |
| Anello, dagli occhi di chi sta sulla ciambella, ogni 10 gradi (`fogli/fiume_anello.jpg`) | buio con le lampade al 20%; le rive e la roccia si leggono vicino alle lampade |
| Paratia del primo bivio, da 30, 20 e 10 gradi prima (`fogli/fiume_paratie.jpg`) | si vede: il telaio con la luce verde e il cartello sopra si staccano dal buio anche da 12 m. Anche la seconda e la terza si vedono, con la loro luce verde |
| test_fiume_gioco 31, test_risalita 18, test_strada 36 | ok |

## Bambino col cubo del corridoio

| Prova | Esito |
|---|---|
| Ti fermi e ti giri (`video_bambino_cubo.gd fermati`, `fogli/bambino_fermati*.jpg`) | in fondo al corridoio, in piedi, vivo; poi parte e svolta nella porta del capannone |
| Polaroid 13 (`fogli/bambino_polaroid13.jpg`) | accovacciato alla P13; ti giri e lo vedi correre via |
| Torni dal capannone (`fogli/bambino_indietro.jpg`) | compare alle spalle, in fondo, e se ne va |
| Da vicino (`fogli/bambino_vicino.jpg`) | corsa con le ginocchia alzate e svolta nella porta |
| sonda_bambino_cubo (fermati e vicino) | nessun vertice della pelle dentro il mondo. Da fermo i piedi scivolano al più di 0,01 m/s; in corsa di 0,18 m/s per un fotogramma (in media 0,01). Da fermo testa e anche si muovono di 1-3 cm: vivo, non statua. La punta va al più 0,5 cm sotto il pavimento |
| test_bambini_sfuggita 53, test_polaroid 5 | ok |

## Ripartenze e Continua

| Prova | Esito |
|---|---|
| Inseguimento, partenza F9 e morte | arrivo in 9,5 s; ripartenza in 5,7 s dal checkpoint del fondo; mesh, forme e checkpoint come prima della morte |
| Fiume, partenza F9 e morte | arrivo in 14,2 s; ripartenza in 8,0 s dal checkpoint d'ingresso |
| Continua dall'inseguimento, dopo un crash vero | checkpoint della vasca 1, a 0,02 m dal posto salvato; zaino, acqua, inventario e Polaroid uguali. Dopo la morte riparte in 8,2 s, in piedi |
| Continua dal fiume, dopo un crash vero | checkpoint dell'approdo, a 0,00 m; tutto uguale. Dopo la morte riparte in 9,8 s |
| test_continua 127, test_partenze_prova 72, test_audio 116 | ok |
| Posizionamento della CI col blocco | 0 nuovi, 64 noti, 0 da correggere |

## Da sapere

- **La scaletta del bacino** comincia sopra il bordo di piastrelle, che sta 26 cm sopra il pelo (a 1,2 m dal fondo). Con l'acqua più bassa, dal bacino si vede il bordo e la scaletta sopra (`fogli/bacino_paperella_scaletta.jpg`). Nel gioco la scaletta serve solo per SB1, che chiude il capitolo. Non ho visto altro da segnalare.
- **Lo strumento dei tubi** (`scatti_acque_inseguimento.gd`) parte nell'acqua a 2 m dalla bocca e, nel tubo_0, resta fermo davanti alla bocca. È il primo tubo, quello che si fa accovacciati. Non è del gioco.
- **Le pile al 20%** sono molto scure dagli occhi; è la scelta dell'utente.
