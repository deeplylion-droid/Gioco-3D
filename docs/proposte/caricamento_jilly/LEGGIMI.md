# Schermata di caricamento con Jilly (grafica-2)

Richiesta dell'utente del 7 novembre: «Mettiamo un loading screen personalizzato, con Jilly che ti guarda e sbatte l'occhio inclinando la testa.»

Branch `lavoro/caricamento-jilly`, da main 14a03fc2.

## Cosa c'è

Jilly è quella vera del gioco: lo stesso modello e i materiali bagnati, affacciata alla vasca della sala, con le luci, i muri e l'ambiente della sala come all'inizio del gioco. Niente immagini generate.
- La vista è quella di chi le sta davanti.
- L'occhio e la testa guardano te.
- In un ciclo di 8 secondi la testa si inclina di lato e torna dritta, e la palpebra si chiude due volte, una con la testa inclinata.

La sequenza è registrata dal motore (`scenes/ui/caricamento/registra_jilly.gd`, Movie Maker a 24 fotogrammi al secondo). La fine si fonde con l'inizio, così il ciclo non ha giunte (`tools/caricamento/jilly_video.py`). Il risultato è un video Theora di 1,76 MB (`assets/ui/caricamento/jilly_caricamento.ogv`).

La schermata (`scripts/ui/menu/caricamento.gd`) lo fa girare in ciclo dietro i testi:
- il video è a tutto schermo, tagliato ai lati se lo schermo non è 16:9;
- a sinistra c'è un velo scuro, dietro comandi, consiglio, stato e barra; il consiglio è passato sotto i comandi;
- la destra resta a Jilly.

È la stessa schermata per tutte le entrate: Nuova partita (dopo lo spot), Continua e le ripartenze da disco, le partenze F9.

Perché un video e non il 3D: durante il caricamento non si disegna e non si compila niente di più (niente shader di Jilly da compilare mentre il thread carica la sala), e in memoria c'è un fotogramma solo.

- Video: `caricamento_jilly.mp4`, registrato dalla schermata vera.
- Fotogrammi: `fotogramma_1.jpg`, `fotogramma_2.jpg`, `fotogramma_3.jpg`.

## Misure, prima e dopo

Schermata vera col renderer vero (llvmpipe, 1280x720, `tests/misura_caricamento_jilly.gd`); «senza» vuol dire col file del video tolto, cioè la schermata di prima.

| | senza video (3 prove) | con video (3 prove) |
|---|---|---|
| sala arrivata nel thread | 48,7 / 48,7 / 49,1 s | 47,6 / 47,4 / 47,6 s |
| riscaldamento degli shader finito | 122,8 / 114,6 / 115,5 s | 120,0 / 123,0 / 125,2 s |
| fotogramma medio | 194,7 / 182,4 ms | 191,0 / 195,8 ms |
| fotogramma peggiore | 3194 / 2743 ms | 3006 / 3081 ms |
| memoria del processo, picco | 13,95 GB | 13,95 GB (+0,6 MB) |
| memoria statica di Godot | 229 MB | 234 MB |

- **Tempi d'arrivo:** non peggiorano. La sala arriva anche un po' prima (rumore), il riscaldamento resta nella stessa forbice.
- **Scatti:** il peggiore e la media restano uguali.
  - I fotogrammi oltre 50 ms passano da circa 500 a circa 610 su 626.
  - Sul renderer software ridisegnare il video a tutto schermo costa a ogni fotogramma, mentre senza video quei fotogrammi erano quasi vuoti.
  - Su una scheda vera è un solo rettangolo con una texture.
- **Memoria:** il picco del processo è lo stesso (lo decide la compilazione delle pipeline). La memoria di Godot cresce di 5 MB, solo mentre la schermata è aperta.

Test nella CI: `tests/test_caricamento_jilly.gd` (17 controlli).
- Il video c'è, è piccolo e dura un ciclo; la schermata lo fa andare in ciclo, e ricomincia.
- Le tre entrate passano dalla schermata.
- Comandi e consigli a sinistra, ogni consiglio in italiano e in inglese sopra lo stato.
- La memoria non cresce mentre gira né aprendo e chiudendo la schermata; nessun nodo orfano.

## Scelte di stile (per l'utente)

1. **Inquadratura**
   - A (com'è): Jilly a mezzo busto, con le mani sul bordo della vasca e la sala dietro, nella parte destra.
   - B: più vicina, solo la testa e l'occhio, quasi a riempire la destra: più inquietante, ma si vede meno la sala.
2. **Sfondo e testi**
   - A (com'è): il video a tutto schermo, con un velo scuro a sinistra dietro i testi.
   - B: lo schermo nero di prima, e Jilly in un riquadro a destra, come un oblò o un monitor; più pulito, meno «dentro il gioco».
3. **Scritta «Caricamento» e barra**
   - A (com'è): la lucina rossa, «Caricamento della sala…», la percentuale e la barra sottile azzurra.
   - B: solo la barra, rossa come le luci d'emergenza, senza scritta né percentuale; lascia tutta l'attenzione a Jilly.
