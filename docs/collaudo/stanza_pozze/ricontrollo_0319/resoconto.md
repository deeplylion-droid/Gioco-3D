# Ricontrollo della stanza delle pozze e giro finale della 0.3.19 (1 novembre)

Squadra collaudo. Ho controllato la candidata `lavoro/candidata-0319` **101f7d4c**: è 445aff40 più un commit che cambia solo il GDD.

Come ho lavorato:
- col giocatore vero e i tasti veri;
- senza schermo, nel gioco intero, per i test, la partenza F9, i Continua e le morti;
- col renderer vero solo nella Risalita della scena di prova (niente sala intera), con l'ambiente della sala senza GI e nebbia volumetrica e le luci del blackout.

Il confronto dell'infermeria l'ho fatto anche su `lavoro/godot` **1a2be00d**, negli stessi punti di vista.

**Esito: collaudo superato, nessun difetto bloccante. Una nota lieve sul faretto, per enigmi. 0 righe "ERROR: BUG," in tutti i log.**

## Parte 1: i difetti del 1 novembre

| Difetto | Ora |
|---|---|
| 1. Cartello coi colori sbagliati (enigmi) | **Corretto.** Dagli occhi, a 0,8 m: viola 248° (pozza 256°), arancione 20° (pozza 26°), turchese 183° (pozza 176°). La lamiera è grigio chiaro (210°, saturazione 0,11, luminosità 0,73), non più verde. A 1,5 m, in diagonale e a 0,45 m viene uguale, entro 7°. Con la luce dell'infermeria accesa i numeri non cambiano (`fogli/colori_cartello_pozze.jpg`, `colori_luce_spenta.jpg`, `colori_luce_accesa.jpg`) |
| 2. Porta stagna aperta dentro il telaio (ambienti-1) | **Corretta.** Il controllo della CI ora guarda la stanza risolta: 0 nuovi, 64 noti, 0 da correggere. Il mio controllo con le pozze risolte (`posiz_pozze_risolte.gd`, solo la Risalita) dà 0 nuovi, mentre il 1 novembre i casi erano 8. La porta si passa avanti e indietro. Cerniere da vicino, con una luce tecnica accanto alla camera: i perni sono sul bordo del battente e le ali sono avvitate al battente. L'anta aperta a 100° resta fuori dal telaio, con lo spigolo staccato (`fogli/cerniere.jpg`) |
| 3. Scala buia in cima alla seconda rampa (ambienti-1) | **Corretta.** C'è la lampada rossa nuova in cima alla seconda rampa, attaccata al muro con la staffa (`fogli/cerniere.jpg`, lampada 1). Salendo dalla porta stagna a C3, la luminosità media più bassa è 3,4 su 255 (prima 0,0). Nel tratto che prima era nero (scatti 018-029) va da 3,4 a 14, e il 99° percentile non scende sotto 48: i gradini si vedono (`fogli/scala_su.jpg`, `scala_luminosita.txt`) |
| 4. Muro sud coi colori dell'infermeria (ambienti-1) | **Corretto.** Dal lato delle pozze è grigio come il resto della stanza, con la giunta pulita. Dal lato dell'infermeria è rosa e verde come prima (`fogli/dettagli.jpg`, scatti 012-014) |
| Grigliato quasi nero | **Corretto.** Il grigliato è grigio e si legge come pavimento anche lontano dalle plafoniere e dall'alto (`fogli/dettagli.jpg`, scatti 015-016, e `fogli/giro.jpg`) |

**Faretto, ravvicinato.** Attaccato al soffitto (0,0 cm), col cavo lungo il soffitto fino alla scatoletta sul muro (`fogli/dettagli.jpg`, 000-003).

**Nota lieve (enigmi): il faretto illumina anche attorno al cartello.** L'infermeria nel complesso resta buia, come prima: la media dello schermo cambia di +5-10% da lontano e di +3-4% con la luce accesa. Il cono però è più largo del cartello, e prende il muro attorno e il pavimento davanti (luminosità dagli occhi, dalle viste a 1,5 m, in diagonale e dalla porta, luce spenta; con la luce accesa è uguale, `fogli/infermeria_prima_dopo.jpg`):

| punto | prima (1a2be00d) | 0.3.19 |
|---|---|---|
| muro 25 cm sopra il cartello | 0,12-0,14 | 0,27-0,29 |
| muro 20 cm sotto il cartello | 0,11-0,15 | 0,36-0,39 |
| pavimento 40 cm davanti | 0,12 | 0,22-0,24 |
| pavimento 1 m davanti | 0,11 | 0,18 |
| muro 70 cm sopra | 0,09-0,16 | 0,13-0,20 |

Si vede un alone chiaro sul muro, attorno al cartello. Se si vuole solo il cartello, bisogna stringere il cono o usare una maschera. Se l'alone va bene, lo decide l'utente.

## Parte 2: stati e strada sulla candidata

| Prova | Esito |
|---|---|
| Test senza schermo | test_pozze 142, test_pozze_strada 20, test_infermeria_gioco 77, test_risalita 18, test_strada 36, test_continua 127, test_partenze_prova 72, controllo_varchi 1, test_presa_vera 32: tutti ok |
| F9 Fiume fino a C3 (`tests/collaudo/pozze_continua.gd`, 28 ok) | sulla passerella sud, a terra, girati verso le pozze, pozze piene e porta chiusa; poi su per la scala fino alla porta di C3 |
| Continua dal 14 | sulla passerella sud (0,0; 3,4 nella stanza), pozze piene, porta chiusa. Il colore tolto prima della chiusura torna pieno |
| Continua dal 15 | davanti alla porta stagna aperta (-1,7; -3,3), girati verso la scala; tre colori vuoti, rosa e bianco latte pieni |
| Morte nella stanza | a enigma aperto e a enigma risolto, la ripartenza arriva in 5,3 s e 5,0 s, nello stesso punto del checkpoint 14 o 15, con le pozze e la porta come prima della morte |
| Porta nord dell'infermeria senza il colpo | il giocatore lasciato fermo 3 s non si sposta: al più 8 mm all'arrivo dalla F9 e 0 mm dopo i due Continua e le due ripartenze |
| Pozze piene e porta chiusa, dagli occhi (`fogli/giro.jpg`) | dall'infermeria alla passerella e giro nei due versi: mai fermi, niente fra 0,1 e 2 m sopra i piedi |
| Sbagliato al terzo (turchese, viola, rosa) (`fogli/sbagliato.jpg`) | gorgo, lampada rossa a lampi (164 fotogrammi accesa), scarico e riempimento, poi di nuovo tutte piene |
| Risolta (`fogli/risolta.jpg`) | porta aperta in 2,6 s con la lampada verde, tre colori vuoti; da una pozza vuota e da una piena si esce saltando |

## Parte 3: giro finale delle altre cose cambiate

| Cosa | Esito |
|---|---|
| SB1 (`tests/collaudo/scatti_sb1_scende.gd`, `fogli/sb1.jpg`) | lei se ne va scendendo senza salire. L'occhio sta fermo a 0 fino a 5,33 s, poi scende sempre (-0,005, -0,04, ... -3,84 m) e non sale mai. La luce rosa sfuma da 6 a 0 in 0,4 s (5,53-5,93 s), senza sparire di colpo |
| Squalo all'inizio, scelta A (`tests/collaudo/giro_squalo.tscn`, `fogli/squalo.jpg`) | come nel collaudo di cafbf584: niente apertura a 6 s, la mano destra di lato nella minaccia, poi porta e corsa. La camera non va mai sotto la pelle: al più vicino è a 0,222 m. Nei dati c'è un fotogramma "dentro" a 10,3 s, ma lì la pelle è a 3,9 m: lo stesso caso c'era nella misura di cafbf584, ed è della misura, non dello squalo |
| Cartelloni rovinati del muro in fondo della sala (`tests/collaudo/cartelloni_giro.gd`, `fogli/cartelloni_sala.jpg`) | il delfino (n0) e la balena (n1) bruciati e scarabocchiati, a filo del muro anche di taglio; dal centro, all'arrivo e col lampione, si vedono come nel ricontrollo del 31 ottobre |
| Cartelloni della torre (`proposte/poster_sala/scatti_cartelloni_torre.gd`, `fogli/cartelloni_torre.jpg`, `cartellone_torre_3.jpg`) | la balena (1) e il delfino (3) rovinati, dagli occhi e da vicino; il polpo (2) è come prima. Il delfino 0 resta al buio dietro un tubo, a 0,85 m, come aveva già scritto enigmi: dagli occhi non si vede |

## Da sapere

- **Il profilo nuovo e la calibrazione.** Lo squalo, lanciato come scena con un profilo appena creato, si ferma sulla calibrazione della luminosità del primo avvio. È voluto (`Game._show_calibration`), e l'ho rifatto col profilo già calibrato.
- **La lampada rossa nuova** in cima alla seconda rampa sta a 1,98-2,42 m e sporge 50 cm dal muro, come le altre lampade rosse della scala. Il controllo della CI la accetta.

## Strumenti

In `godot/tests/collaudo/`:
- `pozze_giro.gd`: le fasi nuove sono `infermeria` (luminosità attorno al cartello, anche senza la stanza), `dettagli` e `cerniere` (con `LUCE_TECNICA=1`). `LUCE_INF=0/1` sceglie la luce dell'infermeria. I punti sullo schermo sono scalati dalla finestra di base all'immagine, come nello strumento di enigmi;
- `pozze_continua.gd`: ora fa anche le morti nella stanza e misura la spinta della porta nord (il giocatore fermo 3 s).
