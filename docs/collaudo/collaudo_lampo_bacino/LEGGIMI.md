# Ricontrollo del lampo rosa sul bacino (#131), enigmi, 8 novembre

- Correzione di ambienti-2: `lavoro/lampo-bacino`, codice `3f6081ec`, provato su `2c1b053f`, che aggiunge solo il foglio.
- Mentre il tunnel si riscalda:
  - la luce rosa degli effetti dell'inseguimento si posa solo sulle mesh del tunnel (strato 13, `1 << 12`);
  - la luce non colora la nebbia volumetrica (0).

  Finito il riscaldamento, la luce torna come in gioco: maschera senza la lancia in mano e nebbia a 0,5.
- Per confronto, la base senza correzione: `56ce3652`. È main `29f78c94` più la sola misura di ambienti-2.
- Strumenti, in `godot/tests/collaudo/`:
  - `scatti_lampo_bacino.gd`:
    - la sala della torre con le condotte, come nel gioco (blackout, ambiente della sala), e il fondo nero nel vano;
    - da ciascun punto del bacino, il tunnel entra come lo mette la sala: costruito a pezzi, col suo riscaldamento, poi
      pronto;
    - per ogni fotogramma conta i pixel rosa rispetto allo scatto di prima del tunnel (rosso e blu salgono più del
      verde) e scrive lo stato della luce rosa;
    - tutta la sala con llvmpipe non sta nella memoria;
  - `sonda_lampo_casi.gd`: i cinque casi del collaudo del fondo nero nel gioco vero, senza schermo. In più della sonda
    del fondo, quando il tunnel è costruito controlla quali mesh sono sullo strato 13, dentro e fuori dal tunnel, e lo
    stato della luce rosa;
  - `misura_rosa.py`: la stessa misura del rosa fuori dal motore, sui fotogrammi salvati in piccolo.
- Poi `tests/video_effetti_inseguimento.gd` (l'inseguimento col giocatore vero, stessa partita) e
  `tests/sonda_pipeline_sottomarino.gd`, tutti e due sulla base e sulla correzione.

## Esito: superato

### 1. Nessun fotogramma rosa sul muro, sulla scaletta e sulla ringhiera (fogli 1 e 2)

| | Punto | Fotogrammi | Riscaldamento | Fotogrammi rosa | Il peggiore |
|---|---|---|---|---|---|
| senza correzione | mezzo del bacino | 448 | 48 | **15** (90-104) | 51727 pixel su 57600 |
| correzione | dove si riparte | 451 | 48 | **0** | 0 |
| correzione | mezzo del bacino | 458 | 48 | **0** | 0 |
| correzione | in cima alla scaletta | 451 | 48 | **0** | 0 |

- "Rosa" = più di 80 pixel su 320x180 (lo stesso 20 su 160x90 della misura di ambienti-2), contati su tutti i
  fotogrammi, dall'entrata del tunnel finché è costruito.
- Fra due fotogrammi senza tunnel il rumore è 0 pixel.
- La base conferma che la misura vede il lampo: 15 fotogrammi di fila al riscaldamento della prima vista del tunnel.
  Ambienti-2 ne contava 14.
- Con la correzione, in tutti e 48 i fotogrammi del riscaldamento la luce ha maschera 4096 (solo strato 13), nebbia 0,
  cono 70°. Subito dopo è spenta, con maschera 1048573 (gioco), nebbia 0,5, cono 26°.
- Fuori dal riscaldamento non c'è rosa, neanche nella base, anche mentre il tunnel prepara lei.

### 2. I cinque casi del fondo nero, nel gioco vero (senza schermo)

| Caso | Tunnel costruiti | Strato 13 giusto | Vuoto | Nero sopra il tunnel pronto | Fondi al massimo |
|---|---|---|---|---|---|
| F9 Inseguimento | 1 | 1 | 0 | 1 fotogramma | 1 |
| Morte nelle condotte | 2 | 2 | 0 | 16 (0,27 s) | 1 |
| Due morti di fila | 3 | 3 | 0 | 2 | 1 |
| Continua dal bacino | 2 | 2 | 0 | 3 | 1 |
| Dalla torre al bacino | 1 | 1 | 0 | 7 | 1 |

- "Strato 13 giusto":
  - ogni volta che il tunnel è costruito, le sue 1036 mesh sullo strato 1 hanno anche il 13, nessuna esclusa;
  - nessun'altra mesh del gioco ce l'ha, quindi nemmeno il bacino, la scaletta e la ringhiera.
- La luce rosa nasce spenta con la maschera e la nebbia del gioco.
- Senza schermo il riscaldamento non accende la luce. Il rosa si misura negli scatti del punto 1, dagli stessi punti in
  cui si riparte o si arriva in questi casi.
- Il fondo nero resta come nel collaudo della 0.3.21: mai il vuoto, mai due fondi, e il nero va via entro 0,27 s dal
  tunnel pronto. Il controllo è ogni 0,2 s.
- Nessun altro strato usa il 13. I cambi di strato e di maschera passano da `Strati`, come vuole la CI per il crash
  delle ripartenze della 0.3.17.

### 3. La luce rosa di lei nell'inseguimento, come prima, con la nebbia rosa (foglio 3)

- Video dell'inseguimento col giocatore vero, sulla base e sulla correzione, stessa partita:
  - lo stesso andamento, con le fasi e gli scatti negli stessi istanti;
  - la luce rosa sui muri, sull'acqua e su di lei, e il rosa nella nebbia, uguali.
- Negli scatti:

  | Scatto | Rosa medio, correzione | Rosa medio, base | Differenza media |
  |---|---|---|---|
  | La luce avanti | 5,748 | 5,747 | 0,10 su 255 |
  | Il morso | 21,190 | 21,212 | 0,28 |
  | Lei si ritrae | 14,728 | 14,726 | 0,21 |

  Le poche differenze sono sui tentacoli di lei e sul salvagente spruzzato: animazioni un po' sfasate, non luce.
- La nebbia volumetrica è accesa (preset medio). La luce, finito il riscaldamento, ha di nuovo nebbia 0,5.

### 4. Niente compilazioni al primo sguardo nel tunnel

- `sonda_pipeline_sottomarino.gd`, uguale sulla base e sulla correzione:
  - prima del tunnel `[0, 0, 4, 33]`;
  - tunnel costruito fuori vista `[66, 83, 172, 49]`;
  - alla fine del giro lungo tutto il tunnel `[66, 83, 172, 49]`.

  Nessuna compilazione al primo sguardo.
- **Osservazione, non della correzione:** nel video dell'inseguimento si compilano 2 pipeline, una all'inizio della corsa
  e una quando il giocatore si gira verso di lei. Sono uguali sulla base: c'erano già prima e la correzione non le
  cambia. Non ho cercato da dove vengano: il giro della sonda lungo il tunnel non ne trova.

## Fogli

1. `1_lampo_prima_dopo.jpg`: dal mezzo del bacino, prima del tunnel e ai fotogrammi 90, 92 e 96 del riscaldamento.
   Sopra senza correzione (il muro, la scaletta e la ringhiera rosa), sotto con la correzione (uguale a prima del
   tunnel).
2. `2_correzione_tre_punti.jpg`: con la correzione, da dove si riparte, dal mezzo del bacino e dalla cima della
   scaletta. Prima del tunnel, durante il riscaldamento e col tunnel pronto.
3. `3_inseguimento_prima_dopo.jpg`: l'inseguimento senza e con la correzione negli stessi istanti: la luce rosa avanti,
   il morso, lei che si ritrae.
