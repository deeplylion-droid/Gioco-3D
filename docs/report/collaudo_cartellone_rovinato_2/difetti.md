# Collaudo del cartellone rifatto (lavoro/cartellone-a1 3061943d)

Il collaudo l'ha fatto la squadra enigmi. È la verifica di C1 (il cartellone a 1,6 cm dal muro) e di C3 (il battiscopa che lo attraversava), dal collaudo di f4a49ff0. Non ho corretto niente.

## Misure, triangolo per triangolo

Le misure vengono da `godot/tests/collaudo/misura_cartellone.gd` nel motore, e dal glTF letto direttamente, con tutte le mesh del corridoio e la collisione.

- **Carta**: un rettangolo da 1,20 × 1,60 m (x 14,00-15,20, y 0,35-1,95), con il piano a z -0,003.
- **Distacco dal muro: 3 mm.** Dentro il rettangolo della carta, dietro di lei ci sono `lamiera_petrolio` e `lamiera_crema` a 0,0030 m. La collisione del corridoio è anche lei a 0,0030 m.
- **Niente attraversa la carta e niente le sta davanti dentro il suo rettangolo**: 0 triangoli, in tutte le mesh.
- **Cornice gialla** (`vernice_gialla`): va da 0,30 a 2,00 m e gira intorno alla carta, sporgendo fino a 2,7 cm davanti. Non la attraversa.
- **Listello dello zoccolo** (`battiscopa`, y 1,08-1,12 m): si ferma ai lati della cornice e sporge fino a 1,5 cm, ma fuori dal rettangolo della carta. Non la attraversa più: C3 è risolto.
- **Canalina** (`metallo_grezzo`, y 2,05-2,10 m): sta sopra la cornice e sporge fino a 11,7 cm, fuori dal rettangolo. Non attraversa più la carta.

## Scatti

Gli scatti sono stati presi con la camera del giocatore (Player vero, senza zaino), con le luci dell'inizio del gioco e gli interni nell'ambiente della sala. Sono in `scatti/`, messi insieme in `foglio.jpg`:
- da dove passa il giocatore, dalle due parti;
- davanti;
- ravvicinato;
- i due bordi;
- di taglio da vicino;
- di taglio da lontano, dalle due parti (dove si vedrebbe lo sfarfallio col muro dietro);
- gli strappi da vicino, a sinistra e a destra.

| Cosa | Esito |
|---|---|
| La carta sta sul muro | ok: 3 mm. Negli scatti dei bordi e degli strappi non si vede distacco. |
| Niente sfarfallio col muro dietro | ok: negli scatti di taglio, da vicino e da lontano, non c'è rumore né righe sulla carta. Con 3 mm di distanza e il depth buffer di Godot (reverse-Z, in virgola mobile) non ci si aspetta sfarfallio. Ho guardato scatti singoli, non sequenze di fotogrammi. |
| Niente compenetra | ok: né la cornice gialla, né il listello, né la canalina. La riga scura a 1,1 m che attraversava la carta (il battiscopa) non c'è più. |
| Strappi e bordi | ok: attraverso gli strappi si vede il muro subito dietro, senza bordi neri. |

**Esito: nessun difetto.**
