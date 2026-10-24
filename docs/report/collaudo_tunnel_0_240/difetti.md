# Collaudo dell'ambiente del tunnel sottomarino, prima metà (0-240 m)

Squadra enigmi (collaudo, non ha costruito la zona), 24 ottobre sera. Base: `lavoro/sottomarino` **ee20554a**, import fresco. Il tratto comprende presa, coralli, relitto e palombaro, che sono di ambienti-2. I gommoni non sono collaudati qui: li guarda la squadra collaudo.

Il tunnel è stato caricato da solo: `SalaSottomarino` costruita tutta, gommoni fermi (t 0) e lei nascosta. Si vede con la luce del gioco, cioè l'ambiente della sala con SDFGI e nebbia come in `scatti_sottomarino.gd`, senza torcia. Le posizioni sono date come `s`, i metri lungo la strada. "Sinistra" e "destra" si intendono guardando verso l'approdo. Le altezze sono misurate sopra il piano delle banchine.

Nessun difetto è stato corretto: l'elenco è per chi ha costruito la zona.

## Come è stato fatto

- **Distanze vere** (`tools/collaudo/distanze.py` sulla geometria di `tests/collaudo/geometria.gd`). Sono stati misurati 193 oggetti del tratto, e tutti toccano il loro sostegno:
  - lampade: 0-1 mm;
  - oblò: 0,7 mm;
  - salvagente: 1,9 mm;
  - ancora e staffe: 1 mm;
  - fasce della galleria: 3,6 mm.

  Lo strumento dà le mensole "a 1,5 cm dal muro", ma il motivo è un altro: sono murate 1,5 cm dentro il muro (retro a 6,315 m dall'asse, muro a 6,30) e lo strumento misura la distanza del retro, che sta dentro. Gli scatti di fianco e da sotto confermano che sono attaccate (`fogli/mirati_*.jpg`).
- **Spazio libero**, sui vertici veri di ogni mesh. Si è guardato:
  - lo spazio sopra le banchine fino a 2 m;
  - il canale fino a 2 m sopra il fondo;
  - lo spazio di lei (entro 3,6 m dall'asse, fra -29,22 e -24,22).

  Le cose trovate sono nei difetti qui sotto.
- **Superfici sullo stesso piano che si sovrappongono** (sfarfallii), in tutte le mesh del tratto, struttura compresa: c'è un solo caso, le fasce della bocca d'uscita della galleria.
- **Facce dal retro**: le 120 viste della strada sono state rifatte con un materiale chiaro, con le facce viste dal retro in rosso. Muri, volta, mosaico, banchine, gradino, mensole, galleria e ostacoli non ne hanno nessuna. Il rosso compare solo sulle corde dei gommoni (punto 6).
- **Scatti** con la camera del giocatore, i materiali veri e la luce del gioco, senza torcia:
  - 120 lungo la strada (`fogli/strada_*.jpg`): ogni 8 m dal mezzo di ogni banchina guardando avanti, ogni 16 m verso il muro di fronte e la volta, ogni 24 m indietro, ogni 12 m dall'acqua (in piedi sul fondo), e 3 dalla porta del bacino;
  - 250 ravvicinati su 126 oggetti (`fogli/oggetti_*.jpg`): per ogni lampada, oblò, mensola, corallo, ancora, staffa, salvagente, forziere, palombaro, pezzo degli ostacoli, fascia e plafoniera della galleria e palo del parapetto, uno di fronte (un po' dal basso, come lo vede il giocatore) e uno di traverso lungo il muro, con una luce debole sulla camera per vedere i contatti;
  - 52 mirati sui difetti (`fogli/mirati_*.jpg`, `difetti/`).
- **Controllo di posizionamento della CI**, zona `sottomarino`, stati t0, t1 e t2 (`dati/controllo_posizionamento.log`). Fra 0 e 240 m **non c'è nessun caso**, e i casi "da correggere" sono 0. I 6 casi nuovi stanno tutti fra 243 e 296 m, cioè nella seconda metà, nei pesci di ambienti-1: 4 pesci staccati dalla loro mensola e 2 mensole dei pesci che entrano 10 cm in una lampada del tunnel, a s 277 e 296.
- **Cartelli**: nel tratto non ce ne sono. I due cartelli a disegni sono a 494 e 521.
- **Elenco degli oggetti** con altezza e sporgenza dal muro: `dati/oggetti.csv`.

## Difetti da correggere

| # | Cosa | Dove | Misura | Scatti |
|---|---|---|---|---|
| 1 | **Lampade a gabbia sopra le bocche della galleria di servizio all'altezza della faccia.** Stanno dove ci si ferma per entrare accovacciati e dove ci si rialza uscendo. Le altre lampade del tratto stanno con il fondo a 2,79 m. | s 204,3 e 217,7, muro sinistro (`Galleria_205/lampada_gabbia`, `Galleria_205/@Node3D@763`) | fondo della lampada a 1,79 m, globo a 1,96 m, sporge 55 cm dal muro (`_galleria`: `_lampada(nodo, sb, lato, y1 + 0.75, 3.0)`) | `difetti/g_s204.3_lampada_occhi.jpg`, `g_s204.3_lampada_di_lato.jpg`, `g_s217.7_lampada_occhi.jpg`; strada `s200_sx_avanti` |
| 2 | **Lastre del crollo a 74 sospese o senza appoggio.** Le lastre 1 e 3 sono sospese: toccano solo il muro con lo spigolo alto. Le lastre 2 e 4 entrano nel fondo e in alto non poggiano a niente. L'acqua lì è trasparente, quindi si vede. Per la coerenza: sono quattro lastre uguali in fila a passo regolare, come gradini, e non sembrano un crollo. | banchina sinistra, 74-82 (`Ostacolo_crollo_74`) | lastre 1 (74,2-75,8) e 3 (78,2-79,8): spigolo basso 6 cm sopra il fondo. Lastre 2 (76,2-77,8) e 4 (80,3-81,8): entrano 3,6 cm nel fondo, inclinate di 29°, spigolo alto a 27 cm dal muro | `difetti/crollo_lastre.jpg` (in alto: la lastra 1 da sotto e di profilo; in basso: la lastra 4 nel fondo e lontana dal muro); `oggetti_07.jpg` (o123-o126) |
| 3 | **Fasce gialle e nere delle bocche della galleria.** All'uscita i pezzi da 30 cm si sovrappongono sullo stesso piano, quindi le strisce sfarfallano e risultano tagliate. All'entrata fra due pezzi si vede una riga di muro e le strisce non continuano da un pezzo all'altro. La texture delle strisce è a bassa risoluzione, con i bordi a scalini, e la si guarda da 1 m quando ci si accovaccia. | uscita s 216,8-218,6; entrata s 203,4-205,2; muro sinistro (`Galleria_205/Fascia`, `@MeshInstance3D@751`…`@762`) | all'uscita 5 giunte sovrapposte, circa 48 cm² l'una | `difetti/fasce_galleria.jpg` (a sinistra l'entrata, a destra l'uscita); `oggetti_06.jpg` (o095-o107) |
| 4 | **Oblò sotto i 2 m.** Sono all'altezza della faccia di chi cammina lungo il muro; sono attaccati bene (0,7 mm). | tutti i 22 oblò del tratto, a 7, 16, 25… 232 (`Luci/Oblo`, `Luci/@Node3D@…`) | anello d'ottone da 1,44 a 2,36 m (centro a 1,9 m), sporge 9,6 cm dal muro | `difetti/b_s007.5_oblo_occhi.jpg`; strada `s024_sx_avanti`, `s168_sx_avanti`, `s240_sx_avanti` |
| 5 | **Carico del relitto.** Le quattro casse sono scatole lisce marroni, senza assi né spigoli: sembrano un segnaposto ("niente oggetti piatti al posto di quelli veri"). La colonna verso il canale sporge oltre il bordo della banchina, sopra l'acqua. L'ancora del carico sta per terra sulla banchina oltre la fine delle casse, fuori dall'ostacolo. | banchina destra, 138,5-141,1 (`Ostacolo_carico_138`) | casse fino a 6 cm oltre il bordo (in curva); ancora da 141,6 a 143,2, a 36 cm dal muro | `difetti/carico_s136_dx_avanti.jpg`; strada `s144_dx_indietro`; `oggetti_05/06.jpg` (o091-o093) |
| 6 | **Corde dei gommoni** (lavoro nostro, enigmi, fuori da questo collaudo). Il tubo della corda ha le facce girate verso dentro: dall'esterno si vede l'interno del lato lontano. Da lontano non si nota, da vicino la corda è più scura. | tutte le corde (`Gommoni/*/Corda*`, `_corda()` in `sala_sottomarino.gd`) | l'ordine dei vertici dei quattro lati è al contrario | `difetti/retro_corde_gommoni.jpg` (in rosso) |

## Da vedere (decide il coordinatore o l'utente)

| # | Cosa | Dove | Scatti |
|---|---|---|---|
| 7 | **La testa del tunnel e la presa sono nere senza torcia.** C'è una sola lampada, a s 3 sul muro destro. Lì riemerge lei, quando la camera guarda la presa. Va visto nel gioco vero: la porta del bacino aperta fa entrare luce dalla sala delle condotte, e lei forse ha la sua luce. | s -4,5 - 2 | `difetti/testa_buio_s000_sx_indietro.jpg`, strada `s000_dx_indietro` |
| 8 | **Palombaro e forziere sulle mensole si leggono poco al buio.** Stanno a 5-7 m dalla lampada più vicina sul loro muro. | 190 e 152,5, muro destro | strada `s184_dx_avanti`, `s192_dx_indietro`, `s152_dx_avanti` |
| 9 | **La banchina crollata davanti alla galleria finisce con un taglio dritto**, senza lastre né macerie, e non si capisce che è crollata. Il codice salta apposta l'ostacolo "crollo" sotto le gallerie. | banchina destra, 203,6-218,4 | `difetti/crollo_galleria_s200_dx_avanti.jpg` |
| 10 | **Le staffe dell'ancora del relitto non sembrano staffe.** Sono attaccate (1 mm), ma sono due blocchi neri lisci che attraversano il fusto, senza collare né bulloni. | 121,6, muro sinistro (`Relitto/Ancora/Staffa`) | `difetti/staffe_ancora.jpg` |
| 11 | **Il parapetto della presa sta sulla banchina.** Pali e due correnti alti 1,05 m, a 3-6 cm dal bordo del canale. È voluto (lì non si cade nella presa profonda); lo segnalo solo perché è l'unica cosa sulla banchina fuori dagli ostacoli. | s -4,4 - 6, tutte e due le banchine | `oggetti_07.jpg` (o111-o122) |

## Senza difetti

- **Lampade a gabbia** (27 del tunnel e 2 degli ostacoli): attaccate al muro (0-1 mm), con il fondo a 2,79 m (3,1 m quelle degli ostacoli).
- **Mensole** (17): murate 1,5 cm nel muro, sotto a 2,05 m. Quella del forziere a 152,5, in curva, sta a 1-2 mm dal muro.
- **Coralli** (15), **forziere** e **palombaro**: poggiano sulle mensole (0 mm), a 4 cm dal muro come voluto, e niente scende sotto i 2,2 m.
- **Ancora e salvagente del relitto**: fissati al muro (1 e 1,9 mm), con il bordo basso a 2,05 m.
- **Galleria di servizio**: plafoniere a filo del soffitto, bocche alte 1,25 m, dentro si passa accovacciati.
- **Muri, volta, mosaico, banchine e gradino**:
  - nessuna faccia rovesciata;
  - nessun buco negli scatti;
  - nessuna sovrapposizione sullo stesso piano, a parte le fasce del punto 3;
  - le curve del tratto hanno raggio di almeno 15 m, quindi il guscio non si piega su sé stesso. Le "onde" della volta negli scatti sono prospettiva.
- **Spazio di lei e canale**: liberi (a parte lo sbalzo delle casse del punto 5).
- **Ostacoli leggibili al buio**: sopra il crollo, il carico e le due bocche c'è una lampada sul muro.

Strumenti nuovi: `godot/tests/collaudo/giro_tunnel.gd` fa gli scatti della strada, i ravvicinati, le facce dal retro e una lista di punti. `geometria.gd` adesso costruisce il tunnel quando la scena è `sala_sottomarino.tscn`.
