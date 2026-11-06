# La stanza delle pozze colorate: la logica e il cartello (enigmi, 31 ottobre)

**L'idea.** È dell'utente (31 ottobre), con tutte le scelte consigliate della pagina delle proposte. Le scelte sono nel GDD, alla sezione "La stanza delle pozze colorate".

**Chi fa cosa** (branch `lavoro/stanza-pozze`):
- **ambienti-1:** la stanza dopo l'infermeria, con la passerella, le vasche, la porta stagna, il lampeggiante, le luci, la scala spostata, il caricamento e il checkpoint d'ingresso;
- **enigmi:** l'acqua, la logica, il cartello e i test.

## Come funziona (`scripts/game/enigma_pozze.gd`, EnigmaPozze)

**Le pozze.** Sono 25, in 5x5, una attaccata all'altra:
- lato interno 1 m, 1,1 m da centro a centro, profonde 0,75 m;
- l'acqua arriva a 5 cm dal bordo;
- ci sono 5 colori, 5 pozze per colore: arancione, rosa, viola, turchese e bianco latte.

**La griglia.** Il colore della pozza è `(colonna + 2 riga) mod 5`:
- ogni riga e ogni colonna ha tutti i colori;
- due pozze dello stesso colore non si toccano, nemmeno in diagonale;
- ogni colore ha pozze sul bordo. Dalla passerella sud, quella da cui si entra, se ne vede una per colore.

**I colori giusti.** Quelli da togliere sono turchese, viola e arancione. Con il pastello sul bianco del cartello sono i tre più diversi fra loro; il bianco latte sul foglio bianco non si vedrebbe. Restano il rosa e il bianco latte.

**Togliere un colore.**
- Basta aspirare 2 litri da una pozza: tutte quelle del suo colore si svuotano insieme, col gorgo, in 3,5 s.
- Lo zaino prende il colore. Se dentro c'era acqua di un altro colore, la butta da sola (`WaterPack.scarta_altri_colori`). Le pozze hanno il meta `scarta_altri_colori`.
- Le pozze non prendono il getto: l'acqua sparata dentro trabocca e non cambia i colori.

**Il controllo**, al terzo colore tolto:
- **giusto:** `PortaStagna.apri()` apre la porta, la cui lampada passa da rossa a verde, e si raggiunge `CheckpointRisolto` (ordine 15);
- **sbagliato:** il lampeggiante `LampeggianteErrore` lampeggia e si sente lo scarico. Dopo 1,5 s le pozze vuote si riempiono di nuovo coi loro colori, in 4 s. Mentre si riempiono non si aspira.
- Un quarto colore non comincia mentre tre sono tolti o si stanno togliendo.

**Il salvataggio.** Lo stato si salva coi checkpoint e con Continua (gruppo "persist"). I livelli e i colori li salvano le pozze stesse (WaterTank). Quello che era a metà si finisce caricando:
- un colore che si stava svuotando riparte vuoto;
- uno sbaglio riparte già ricaricato;
- se era risolto, la porta si apre senza animazione.

**L'acqua.** Ogni pozza è un WaterTank senza muri, con l'acqua vera dell'addon (WaterTankLink) nello stile del suo colore (`assets/pozze_colorate/acqua_<colore>.tres`):
- il gorgo e i suoni (scarico, riempimento, vasca svuotata) sono quelli delle vasche: uno scarico per colore e un carico per tutte;
- niente simulazione delle increspature e niente cubemap: sono 25 pozze piccole;
- le pozze stanno fuori dalla tabella delle masse d'acqua dell'addon (`WaterManager`, al più 12). Altrimenti avrebbero preso il posto delle vasche e dei canali del resto del gioco: per questo sui fondi delle pozze non ci sono le caustiche;
- chi cade in una pozza ne esce saltando (il salto è 1 m).

## Il cartello (l'indizio)

- **Dove (dal 4 novembre, 0.3.21):** l'utente l'ha trovato troppo facile ("spostiamolo più lontano, così è troppo facile", scelta B). Ora sta nel **corridoio del personale** prima dell'infermeria, quello dopo l'approdo con l'oblò di lei: sul muro est (x -34), di fronte all'oblò, dalla parte del capannone, a 18 cm dall'angolo, cioè a circa 2,3 m dalla porta dell'infermeria. Chi arriva dall'approdo lo ha subito a destra. È all'altezza degli occhi (centro a 1,5 m) ed è a contatto col muro; sotto, per terra, c'è la Polaroid 15. Lo costruisce `CartelloPozze` (`scripts/risalita/cartello_pozze.gd`), messo da `RisalitaGioco._cartello_pozze`; il faretto è `FarettoSoffitto` (`scripts/risalita/faretto_soffitto.gd`), lo stesso dei faretti dell'infermeria. L'infermeria è tornata senza cartello e senza il suo faretto.
- **Prima (fino alla 0.3.20):** nell'infermeria, sul muro nord, a ovest della porta da cui si esce verso le pozze, fra lo stipite e l'angolo.
- **Com'è:** lamiera smaltata di 34 x 46 cm, con:
  - il disco rosso con la barra bianca;
  - la sagoma di un bambino con la mano alzata;
  - i tre quadratini a pastello dei bambini: viola, arancione e turchese.
  Nessuna scritta.
- **La texture:** è procedurale, da `assets_src/pozze_colorate/cartello.py`, col pastello degli scarabocchi sui muri (`assets_src/scarabocchi/pastello.py`), così i colori sono proprio quelli delle pozze. È VRAM compressa, con le mipmap.
- **La luce:** un faretto a soffitto con una lampadina bianca, puntato sul cartello, 1,2 m davanti al muro. Nel corridoio è più stretto (11° invece di 15°) e **ha l'ombra**: senza, la sua luce passerebbe il muro e accenderebbe quello che c'è dietro. Così cambia la luce del corridoio solo sul cartello e in un alone stretto attorno (scatti prima e dopo: `tests/collaudo/scatti_corridoio_personale.gd`, `docs/collaudo/ritocchi_0321/`).
- **Le luci colorate vicine (6 novembre).** Nel corridoio la prima misura dava il viola a 319°, quasi come la pozza rosa (330°), e il turchese verde: la lampada rossa del corridoio è a 70 cm, e le luci del capannone (una rossa e una calda vicino alla porta del personale), che non hanno ombre, passavano il muro. Ora il cartello (lastra e faccia) sta nel suo strato di rendering, `CartelloPozze.STRATO` (1 << 13), e non lo prendono: la lampada rossa del corridoio (`RisalitaGioco._lampada_rossa`, parametro `esclusi`), le luci del fiume e dell'infermeria (i loro `_luce`) e la luce rosa di lei negli oblò (`LeiOblo`). Lo prendono il faretto bianco, l'ambiente e le altre luci. Gli strati e le maschere si cambiano solo con `Strati` (controllo `tools/ci/strati_luci.py`).
  Misura nel corridoio da 0,8 m (tinta, saturazione, luminosità), luci del blackout:

  | | prima della correzione | ora | pozza |
  |---|---|---|---|
  | viola | 319°, 0,48, 0,56 | 264°, 0,45, 0,47 | 257°, 0,63, 0,58 |
  | arancione | 19°, 0,64, 0,83 | 25°, 0,70, 0,64 | 27°, 0,89, 0,63 |
  | turchese | 161°, 0,38, 0,49 | 167°, 0,55, 0,48 | 176°, 0,63, 0,53 |
  | smalto | 10°, 0,16, 0,87 (rosa) | 36°, 0,03, 0,75 (grigio) | |

  Il faretto più forte non bastava: a 8 e a 12 il viola restava a 287-290°.
- **I colori nel gioco** (collaudo del 1 novembre): col faretto di prima, debole (0,9), caldo e radente, i quadratini venivano scuri e spenti. L'arancione sembrava marrone, il viola blu, e lo smalto prendeva il verde dell'uscita. Ora:
  - il faretto è bianco neutro, forte 5 e stretto 15°;
  - sta a 1,2 m dal muro (come quello del negatoscopio), così la luce arriva di fronte;
  - lo smalto è opaco (roughness 0,7);
  - i quadratini sono a pastello più fitto, col turchese della cera più verde e l'arancione più acceso: la luce fredda della stanza sposta le tinte verso il blu.
- **La misura:** `tests/collaudo/colori_cartello_pozze.gd` misura cartello e pozze dagli occhi del giocatore, anche con varianti di faretto, materiale e texture provate in un giro solo. A 0,8 m, in tinta, saturazione e luminosità, il cartello viene come le pozze; la saturazione è un po' più bassa perché fra i tratti di cera resta un po' di bianco:

  | | cartello | pozza |
  |---|---|---|
  | viola | 248°, 0,62, 0,54 | 247°, 0,79, 0,60 |
  | arancione | 21°, 0,62, 0,50 | 17°, 0,75, 0,50 |
  | turchese | 183°, 0,58, 0,45 | 185°, 0,68, 0,49 |
  | smalto | 211°, 0,11, 0,73 (grigio chiaro, non più verde) | |

  Viene uguale con GI e nebbia accese. Il foglio prima/dopo è `docs/collaudo/stanza_pozze/colori_cartello_prima_dopo.jpg`.

## Test

- `tests/test_pozze.gd`, in CI, col giocatore vero che guarda una pozza dalla passerella e tiene il tasto destro. Per ora gira nella stanza grigia di prova (`tests/pozze/stanza_prova.gd`). Controlla:
  - la griglia;
  - risolto nei due ordini;
  - sbagliato e poi giusto;
  - un quarto colore no;
  - lo stato salvato a metà e da risolto;
  - si esce saltando da una pozza.
- `tests/test_pozze_strada.gd`: il cartello nel corridoio del personale (posto lontano dalla porta dell'infermeria, a contatto col muro est, altezza, texture, smalto opaco, faretto bianco neutro e forte che lo illumina di fronte, con l'ombra) e niente cartello nell'infermeria; `tests/test_infermeria_gioco.gd`: nell'infermeria non c'è più.
- **Da fare con la stanza vera:**
  - la strada da F9 Fiume attraverso le pozze;
  - Continua a metà e da risolto;
  - `test_strada` attraverso la stanza;
  - le partenze F9 rigenerate, con le pozze risolte per quelle dopo.
