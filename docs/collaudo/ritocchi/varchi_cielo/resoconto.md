# Ricontrollo di lavoro/varchi-cielo (ambienti-1): il cielo, la lastra della fessura, torre, condotte e tunnel

Squadra collaudo, 6 novembre. Ho controllato `lavoro/varchi-cielo` allo sha ea6f5f71, partito da 412daf44. Nel gioco non ho cambiato niente. I numeri sono in `numeri_cielo.txt` e `numeri_lastra.txt`; gli strumenti in `godot/tests/collaudo/`.

## In breve
- **Il controllo del cielo funziona.**
  - Sulla strada del capitolo dà 0 posti col cielo.
  - Se tolgo per prova la lastra, prende proprio la fessura.
- **Dalla scala di servizio alla porta di C3 niente cielo**, nel gioco vero e anche da Continua.
- **La lastra regge.** Con la lastra i piedi restano piatti; senza, scendevano fino a 2,7 cm nella fessura. Il cammino, la corsa e i salti vanno.
- **Condotte e tunnel: niente cielo.**
- **Da guardare (2 cose):**
  1. agli angoli della giunzione della lastra c'è una fessura nel muro, vista dal vuoto sopra la fossa della sala pompe;
  2. al portone della torre due aperture dove nel gioco vero i raggi non toccano niente.
- Le altre tre aperture della torre negli scatti non mostrano il cielo.

## Test (0 BUG, 0 SCRIPT ERROR)
| controllo | esito |
|---|---|
| controllo_cielo | ok: 217 posti, 0 col cielo (18 lo vedono dalla cupola di vetro, voluto) |
| lo stesso con la lastra tolta (`cielo_buco.gd`, BUCO=1) | FALLITO come deve: 2 posti da correggere, dagli occhi in (0, -7,45, 25,5) e (0, -7,45, 26,5) verso il basso, uscendo da CAMERA_struttura in z 25,4-25,5 |
| test_strada | 36 ok |
| controllo_varchi | ok |
| controllo_posizionamento | 0 da correggere, 0 nuovi, 64 già noti |

## Dalla scala di servizio alla porta di C3, nel gioco vero
Ho usato `scala_c3_cielo.gd`, senza schermo.
- **Come ci arrivo.** Parto dal menu F9 dal fiume, risolvo l'enigma delle pozze e raggiungo il checkpoint a enigma risolto, che viene salvato su disco.
- **Cosa misuro.** Ogni 0,5 m dalla cima della scala alla porta, tiro 36 raggi verso il vano della porta e oltre. Conto solo le mesh visibili in quel momento.
- **Dal gioco così com'è.** 0 raggi nel cielo in tutte le 26 pose. Dietro la porta il raccordo C3 è visibile (155-164 mesh): RACCORDO_struttura, RACCORDO_dettagli, il mucchio dei gonfiabili, i tubi di C3.
- **Da Continua** (GameState.continue_from_disk, ripartendo dal checkpoint a enigma risolto) è lo stesso: 0 raggi nel cielo.

## La lastra della fessura (camera delle onde - sala pompe)
Ho usato `lastra_giro.gd`, con Tecnici messo come nella sala e il giocatore vero.
- **Il pavimento.** Collisioni a -9,051 su tutta la fessura, contro -9,050 del pavimento.
- **Cammino e corsa, x da -1 a +1, nei due versi.**
  - Al centro (x da -0,5 a +0,5) si passa a velocità piena (3,40 m/s a piedi, 5,71 di corsa).
  - I piedi restano fra -9,051 e -9,049 e non si perde mai il pavimento.
  - A x ±1, andando verso nord, si rallenta per un attimo: a piedi da 3,40 a 2,83 m/s, di corsa da 5,71 a 4,79.
  - **Senza la lastra il rallentamento è identico**, quindi c'era già e non dipende dalla lastra.
  - Senza la lastra, invece, i piedi scendono fino a -9,077 (2,7 cm nella fessura). Con la lastra no.
- **Salti.** Si passa sempre, nei due versi, alla stessa altezza.
- **Oltre x ±1,5.** Dal lato della sala pompe a x ±1,5 non c'è pavimento: c'è una fossa, nella quale il giocatore messo lì cade. La strada è più stretta della lastra, che è larga 4,6 m.
- **Gli scatti.**
  - Dagli occhi attraversando (`fogli/lastra_occhi.jpg`) niente di strano; è buio come nel blackout.
  - Da vicino con una lampadina tecnica (`fogli/lastra_vicino_luce.jpg`), al centro la lastra continua il pavimento senza righe.
  - Lo sfarfallio, misurato spostando la camera di 1 cm, non è misurabile al buio, perché la giunzione è nera. Le righe che cambiano sono la lampada rossa d'emergenza in fondo, che sfarfalla apposta.

### Da guardare 1: la fessura agli angoli della giunzione
Negli scatti ravvicinati, alle due estremità (x ±2, al pavimento) si vede il cielo (`fogli/lastra_vicino_luce.jpg`, vicino_x±2_da_nord e x±2_dall_alto). L'ho controllato **nel gioco vero** con `cielo_angoli_onde.gd`: la sala principale intera, le porte aperte e i corpi dalle mesh visibili.
- **I raggi.** Dagli occhi su una griglia attorno alla giunzione (x da -1,5 a 1,5; z 24,5-26,5; a 0,3, 0,8 e 1,6 m) verso gli angoli: **100 raggi su 6048 vanno nel cielo**.
- **Dove passano.** Tutti nel muro, alla giunzione: x ±2,3, z da 25,6 a 25,8, dal pavimento (-9,05) a circa 50 cm sopra (-8,5). Poi proseguono sotto il pavimento, oltre x ±3,5.
- **La causa probabile.** I due modelli lasciano la fessura anche nei muri, ai due lati, e la lastra chiude solo il pavimento.
- **Da dove si vede.** Solo dagli occhi in x ±1,5, z 26-26,5, cioè sopra la fossa della sala pompe, dove il giocatore non sta in piedi. Da x -1 a +1 nessun raggio esce. Si vedrebbe forse solo cadendo nella fossa, o affacciandosi al bordo.
- **Il controllo del cielo non la prende** perché la sua strada passa al centro.
- **Proposta (decide ambienti-1).** Chiudere anche i due lati con una lastra verticale, come quella del pavimento.

## Torre, condotte e tunnel (non coperti da controllo_cielo)
Ho usato `cielo_zone.gd`, nel gioco vero, con le partenze F9, 240 raggi dagli occhi in ogni posto e senza contare la cupola di vetro.

| zona | posti | col cielo |
|---|---|---|
| condotte e vasche (griglia nel fondo di ogni vasca, tubi, bacino, checkpoint della torre) | 110 (2 saltati perché lì il giocatore muore: tubo 2 e bacino) | solo 3 checkpoint della torre |
| tunnel (lungo la banchina ogni 3 m, seguendo l'asse del canale) | 185 | 0 |

Ho guardato le aperture della torre una per una con un ventaglio fitto (`cielo_fessure.gd`: 41x41 raggi in ±3 gradi) e con gli scatti veri della torre (`vista_fessure_torre.gd`, `fogli/torre_aperture.jpg`):

| apertura | quanto è grande | scatto dagli occhi |
|---|---|---|
| NEm3, verso l'alto | 58x58 cm a 5,4 m (torre_A) | niente cielo: si vedono le travi e gli scivoli della torre |
| NOm12, verso l'alto | 2,3x2,9 m a 27 m (fra torre_A_sostegni) | niente cielo: dentro la torre, fino in cima |
| NOm12, di lato | 14x77 cm a 7,4 m (torre_A) | niente cielo |
| **portone, verso il basso** | **23x26 cm a 2,4 m**, fra torre_A_grigliati e il pavimento della sala (il raggio esce vicino a sala_piastrelle_mancanti) | **si vede il cielo sotto il grigliato** |
| **portone, verso l'alto** | 59x49 cm a 6,6 m (torre_A) | **si vede il cielo**, a destra della struttura |

Per le tre aperture interne, gli scatti dicono che dagli occhi non si vede il cielo. I raggi che escono lì sono probabilmente fessure strette fra pezzi della struttura, oltre le quali il renderer mostra altri pezzi della torre.

Per le due del portone, lo scatto è della torre da sola e lì intorno manca la sala. Quindi lo scatto non basta. Però i raggi nel gioco vero, con la sala caricata, non toccano niente per 150 m. Quella verso il basso sembra una fessura vera fra il grigliato della torre e il pavimento della sala, sulla soglia del portone, come quella della lastra. **Da guardare nel gioco vero con la sala**: io la sala intera col renderer qui non la posso fare, mentre lo strumento a parti di ambienti-1 (scatti_porta_c3.gd) sì.
