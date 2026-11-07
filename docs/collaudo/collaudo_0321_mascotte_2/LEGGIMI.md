# Collaudo finale 0.3.21, seconda parte: fiume lento e tunnel sottomarino (mascotte, 7 novembre)

Candidata `lavoro/candidata-0321` dc83169e (versione 0.3.21). Gli scatti sono dagli occhi del giocatore, con Vulkan
software a 1280x720, preset alto e le luci del gioco. Nei fogli sono **schiariti** (gamma 0,45-0,6), così si vedono
distacchi e buchi; nel gioco sono più bui. L'angolo degli scatoloni l'ha fatto enigmi.

Strumenti in `godot/tests/collaudo/`:
- `collaudo_0321_fiume.gd`: dalla ciambella, con gli occhi a +1,65 m (FiumeLento mette il giocatore a +5 cm e lui resta
  in piedi, 1,6 m). Percorre tutti i 7 TrattoFiume ogni 12 m, guardando avanti e a ±70°. Le luci sono quelle del
  blackout.
- `collaudo_0321_tunnel.gd`: dal bacino (s 0) alla camera stagna (s 552), ogni 15 m, dalle due banchine, avanti e
  ogni due punti anche indietro.
- `tests/scatti_gommoni.gd` (già nel repo): gli attraversamenti, i gommoni dal bordo, gli anelli e le maniglie delle
  corde.
- `sonda_0321_striscia_fiume.gd`: la striscia chiara sull'acqua (vedi sotto).

## Fiume lento: va (`fiume_1..3`)
- Ho controllato l'anello (Imbarco, Giusto1, Giusto2, Uscita) e i tre rami sbagliati con lo scivolo e il ritorno
  all'imbarco: 22 punti, 66 scatti.
- Non ho visto oggetti sospesi o staccati, compenetrazioni, buchi o cielo, né niente nei 2 m sopra la ciambella.
- Le paratie, i dischi, i portali coi cartelli verdi, le rocce delle sponde, la capanna tiki, le pile e le ciambelle
  a riva sono al loro posto.
- Texture più leggere: la roccia e il cemento si leggono bene anche da vicino, sulle sponde a 1-2 m dalla ciambella.
- **Osservazione, non bloccante:** in alcuni scatti, guardando di taglio, a pelo d'acqua c'è una riga chiara e sottile
  dritta attraverso il canale. Per esempio a Giusto1 a 37 m (sinistra), a Giusto2 a 1 m e nei rami sbagliati a 25 m.
  Con la sonda: a Giusto1/Giusto2 la riga è sul pelo (y -0,34) a z 27,5, da x -2,4 a +2,3, dove si attaccano due tratti
  d'acqua. Lì non c'è niente di solido, e vista dall'alto da vicino non si vede. Sembra un riflesso, o la giunta fra due
  acque, non un buco. Da far guardare a grafica se si vuole.

## Tunnel sottomarino: va (`tunnel_1..4`, `gommoni_1..3`)
- 37 punti dal bacino alla camera stagna, dalle due banchine.
- Non ho visto oggetti sospesi, buchi o cose nei 2 m sopra le banchine.
- Il crollo e le macerie, la vetrina, le lampade orientabili, i coralli, gli oblò e la scala dell'approdo sono
  appoggiati e fissati.
- I gommoni dei 5 attraversamenti stanno sull'acqua. Ogni corda parte dall'anello nel muro e arriva alla maniglia.
- Da vicino le piastrelle e il pavimento delle banchine si leggono bene.
- Alcuni scatti ravvicinati degli anelli sono troppo bui per giudicare: sono senza torcia, come nel gioco.
