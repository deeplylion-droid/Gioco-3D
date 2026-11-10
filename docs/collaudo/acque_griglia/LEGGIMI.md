# Collaudo: una griglia sola per ogni acqua (10 novembre)

Ho controllato `lavoro/tunnel-fotogrammi-33` 90504558 contro main 26f399fe (0.3.24). Lo ha fatto la squadra grafica come collaudo, senza cambiare niente nel gioco.

**Esito: superato su tutti e quattro i punti.**

Dal codice di `water_body.gd`:
- l'acqua prende subito la qualità di WaterManager;
- `_on_quality_changed` in `_ready` rifà comunque la griglia, i riflessi e le increspature;
- le griglie sono in una cache per misura e suddivisioni.

Quindi lo stato finale non può cambiare. Le prove qui sotto lo confermano.

## 1. Le griglie e gli scatti
**Le griglie.** Lo strumento è `godot/tests/collaudo/acque_griglie.gd`, i risultati sono in `dati/griglie_*.txt`.
- Cosa misura, per ogni WaterBody del gioco:
  - la griglia del pelo: misura, suddivisioni, numero dei vertici e un'impronta dei vertici;
  - `ssr_steps`, `reflection_mode` e la risoluzione delle increspature.
- Dove misura:
  - nella sala con la risalita accesa e gli acquari pieni: 35 acque (vasche, piscina a onde, vasca centrale, lavapiedi, vasca di raccolta dei tecnici, 3 acquari, 25 pozze);
  - partendo da F9 nella torre, nell'inseguimento e nel tunnel: 9 acque per zona, compresa `SalaSottomarino/AcquaPresa`.
- Ai preset basso e alto, sul branch e su main.

**Risultato: tutto identico**, vertici e impronte comprese.

L'unica differenza è il livello di `AcquaVascaBimbi1` e `AcquaVascaBimbi2` nelle zone della torre e dell'inseguimento, di 3-6 mm. Non viene dalla griglia: cambia anche fra due giri dello stesso commit (main 0,320 e poi 0,319; ramo 0,326 e poi 0,323). Dipende da quanto tempo passa prima della misura.

Il fiume lento e le acque della torre, dell'inseguimento e del bacino che non sono WaterBody hanno mesh loro. Questa modifica non le tocca.

**Gli scatti.** Lo strumento è `acque_scatti.gd`:
- tempo dell'acqua fermo a 0, luci del blackout;
- per ogni acqua uno scatto «sopra» (occhi a 1,6 m) e uno «pelo» (occhi 2 cm sopra il pelo);
- 30 scatti per preset, ai preset basso e alto.

| zona | differenza main-ramo | come leggerla |
|---|---|---|
| risalita (pozze) | 0 al preset alto; al basso al più 0,6 in media su un solo scatto | identici |
| sala ridotta (piscina, vasche, acquari) | 5,4-5,9 in media | due giri dello stesso ramo differiscono già di 5,7: è il rumore del rendering della sala (nebbia volumetrica) |

Gli scatti affiancati sono in `foglio_acque.jpg`, compresi quelli col pelo all'altezza degli occhi.

## 2. Vista subacquea e occhio sopra le acque
Sul branch e su main (`dati/test_*`):
- test_vista_subacquea: 10 su 10;
- test_occhio_sopra_acque: 106 su 106.

## 3. Cambio di qualità a metà partita
Nella sala ho cambiato preset dalle opzioni (`Grafica.applica_preset`) e poi sono tornato a quello di partenza.
- Dopo il cambio, ogni acqua è identica a com'è partendo da subito con quel preset, da basso ad alto e da alto a basso.
- Al ritorno, ogni acqua è identica a prima.
- È così sul branch e su main.

## 4. ERROR
Nei log del branch nessun ERROR nuovo.
- Sul branch c'era «squalo_annusa.ogg» non caricato, ma era la mia cache locale senza l'import: il branch carica tutti i suoni all'avvio. Dopo `--import` sparisce.
- Il branch ha meno ERROR di main: manca «Parameter "material" is null», corretto dal branch.
