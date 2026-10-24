# Squalo all'inizio: luce viola e nebbia (grafica, 24 ottobre sera)

Richiesta dell'utente: "lo squalo all'inizio è ancora un po goofy. E se per dargli più atmosfera e nasconderlo un po' facessimo che da dietro di lui arriva una fortissima luce viola (il bagliore di Jilly) e magari nella stanza c'è pure una nebbia densa che si dirada appena inizi a entrare in controllo del personaggio?"

- `godot/scripts/interni/atmosfera_squalo.gd` (AtmosferaSqualo), figlio di RisveglioSqualo (4 righe nel suo `_ready`, animazioni e suoni di mascotte non toccati):
  - un faro viola (0,62; 0,36; 1,0, i fari viola della vasca di Jilly) fortissimo dietro la porta tagliafuoco, con l'ombra, puntato verso il giocatore; al boato di lei cresce del 35%; quando la porta si chiude si spegne di colpo;
  - la luce della corsa di mascotte (davanti allo squalo) al 35% mentre c'è il viola: lo squalo resta una sagoma leggibile;
  - una nebbia (FogVolume) nel corridoio, densità 0,05, che il viola illumina; quando torna il controllo si dirada in 4 s fino alla nebbia normale;
  - luce e nebbia nascono col livello, spente: shader e pipeline pronti prima della scena (niente scatti). Memoria video: niente texture nuove.
- Test in CI: `godot/tests/test_squalo_viola.gd` (12 controlli).
- Scatti interni (non per l'utente): `godot/tests/scatti_squalo_viola.gd`, stessi momenti prima e dopo: `prima_dopo.jpg`.
- Nota: se nelle impostazioni grafiche la nebbia volumetrica è spenta, resta solo la luce viola (niente nebbia).
