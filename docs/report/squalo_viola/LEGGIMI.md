# Squalo all'inizio: luce viola e nebbia (grafica, 24 ottobre sera)

Richiesta dell'utente: "lo squalo all'inizio è ancora un po goofy. E se per dargli più atmosfera e nasconderlo un po' facessimo che da dietro di lui arriva una fortissima luce viola (il bagliore di Jilly) e magari nella stanza c'è pure una nebbia densa che si dirada appena inizi a entrare in controllo del personaggio?"

- `godot/scripts/interni/atmosfera_squalo.gd` (AtmosferaSqualo), figlio di RisveglioSqualo (4 righe nel suo `_ready`, animazioni e suoni di mascotte non toccati). Seconda versione (riscontro del coordinatore: "nasconderlo un po'", controluce vera, nebbia densa, l'inizio buio):
  - il bagliore dalla porta: un faro viola (0,62; 0,36; 1,0, i fari viola della vasca di Jilly) stretto, che si ferma prima del giocatore e non rimbalza (niente luce indiretta): il corridoio resta buio, il viola si vede dalla porta e nei raggi della nebbia; al boato cresce del 35%; a porta chiusa si spegne di colpo;
  - la controluce: un faro dietro lo squalo (dalla parte della porta) che illumina solo lui (il suo strato): il bordo viola acceso, la faccia verso di te al buio coi denti e il bordo che brillano;
  - durante la scena le lampade rosse del corridoio non illuminano lo squalo (tornano come prima col controllo), e la luce della corsa di mascotte è al 15%: lui è una sagoma, ma non sparisce;
  - la nebbia (FogVolume, densità 0,3) è fitta verso la porta e in basso (cala con l'altezza, sfuma verso il giocatore); quando torna il controllo si dirada in 4 s fino alla nebbia normale;
  - luce, controluce e nebbia nascono col livello, spente: shader e pipeline pronti prima della scena (niente scatti). Memoria video: niente texture nuove.
- Test in CI: `godot/tests/test_squalo_viola.gd` (13 controlli).
- Scatti interni (non per l'utente): `godot/tests/scatti_squalo_viola.gd`, stessi momenti prima e dopo: `prima_dopo.jpg`.
- Nota: se nelle impostazioni grafiche la nebbia volumetrica è spenta, resta solo la luce viola (niente nebbia).
