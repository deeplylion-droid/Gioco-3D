# Collaudo finale 0.3.21, ultimo pezzo: stendardi, sagome e paratie (mascotte, 7 novembre)

Candidata finale `lavoro/candidata-0321` c6187286. Gli scatti sono con Vulkan software a 1280x720. Da vicino c'è la
luce di servizio sulla camera (SCATTI_LUCE=1), come nei ricontrolli di enigmi.

Strumenti in `godot/tests/collaudo/`:
- `ricontrollo_stendardi.gd` di enigmi, preso da 9ab04586 (lavoro/ricontrollo-stendardi), gruppi «giro» e «vicino»
  (anche con SOLO_GIRI=1);
- `scatti_sagome_club.gd vicino`;
- `collaudo_0321_bersagli.gd` (mio): i 6 bersagli chiusi e aperti, cioè il bersaglio, l'anello, i montanti e i piedi;
- `sonda_0321_stendardi_sagome.gd` (mio): il gioco vero, partenza «inseguimento» e poi una morte (GameState.respawn).
  Conta gli stendardi pezzo per pezzo contro la GLB e controlla le sagome. Il risultato è in `inventario.txt`;
- `sonda_0321_paratie_aperte.gd` (mio): con le paratie chiuse e aperte, nessun pezzo piccolo della sala (lampade,
  staffe, led) entra nei pannelli.

## 1. Stendardi: vanno (`1_..`, `2_..`, `3_..`, `inventario.txt`)
- **Interi anche costruiti a pezzi, e dopo una ripartenza nelle condotte.** Ho confrontato i 4 stendardi pezzo per
  pezzo con la GLB, sia alla partenza sia dopo la morte: lenzuolo, risvolto, bastone, corde, nodi e mollette.
  - Ogni pezzo ha le stesse mesh e gli stessi vertici della GLB (lenzuolo 3528, bastone 60, corde 3316-3332, mollette
    192...) ed è visibile.
  - I lenzuoli hanno le loro texture (stendardo_1..4.png), e i materiali sono gli stessi dopo la morte.
  - 276 controlli su 276.
- **Come nel ricontrollo di enigmi su fac852af.**
  - Dalle vasche si vedono i 4 lenzuoli coi disegni.
  - Da vicino i giri delle corde girano attorno alla piega, sopra l'asola (la finestrella scura col bastone dentro,
    come aveva notato enigmi).
  - I codini sono corti e aderenti, i nodi stanno agli anelli sotto le travi e le mollette sono a cavallo del bastone.
  - Si vedono le cuciture. I colori sono uguali al suo foglio 5.

## 2. Sagome: vanno (`4_..`, `5_..`)
- Le 12 sagome ci sono tutte, con 16 puntelli, 8 mattoni e 8 legature, e sono visibili. Alla partenza e dopo la morte
  sono uguali, negli stessi posti, al millimetro.
- Da vicino:
  - le basi stanno sul bordo;
  - i puntelli toccano la schiena del cartone e il piede;
  - i mattoni stanno sul piede;
  - lo spago gira attorno al corrimano;
  - i piedi poggiano sul grigliato.
  Non vedo distacchi.

## 3. Paratie: vanno (`6_bersagli_chiuse.jpg`, `7_bersagli_aperte.jpg`)
- Tutte e 6 le paratie, chiuse e aperte:
  - il bersaglio è dipinto: il sole con l'anello di led sulle giuste, il pesce sulle sbagliate;
  - i montanti a strisce caramella sono interi;
  - i piedi poggiano sul bordo.
- Aperte, i pannelli salgono interi col bersaglio e l'anello.
- Nessun pezzo piccolo della sala entra nei pannelli, né chiusi né aperti (sonda).
- Nota sulla luce, non un difetto: con la paratia sbagliata della vasca 3 aperta, sul pannello si vede una grande ombra
  scura di sbieco (la fa qualcosa davanti, con la luce della sala).
