# I due teli di Jilly nella sala principale, bruciati e scarabocchiati (enigmi, 30 ottobre)

La richiesta dell'utente, il 30 ottobre: «ci sono due poster rettangolari sul muro in fondo della sala centrale, vanno bruciati e scarabocchiati moltissimo».

Il coordinatore ha confermato che sono i due teli da 2 x 3 m appesi ai lati della statua, che dall'ingresso si vedono in fondo:
- `sala_cartellone_mascotte_0`: Jilly con l'arcobaleno, lo stesso disegno del cartellone A del corridoio;
- `sala_cartellone_mascotte_1`: Jilly bagnina.

I tre cartelloni piccoli del muro nord (delfino, balena, polpo) restano come sono.

## Come sono rovinati

Le texture le fa `assets_src/ambienti_interni/poster/rovina.py` (`telo_arcobaleno`, `telo_bagnina`), lo strumento di grafica-2, al livello più forte. Sono più rovinati del cartellone A.

**Telo dell'arcobaleno**
- Scarabocchi:
  - la faccia annerita tutta;
  - l'occhio a spirale con una croce bianca;
  - il ghigno coi denti bianchi;
  - l'arcobaleno cancellato a zig-zag neri;
  - la manina annerita;
  - graffi bianchi lunghi;
  - gli occhi dei pesci e delle stelle crocettati.
- A pastello rosso e viola: una croce, un secondo ghigno coi denti sulla campana, righe sui tentacoli, lacrime viola.
- Bruciature:
  - due grandi coi buchi, dal basso a sinistra e dal bordo destro;
  - un buco tondo bruciato sul petto e uno nell'arcobaleno;
  - sette buchi di sigaretta.
- Strappi e sporco: uno strappo grosso in diagonale con lo scotch, fuliggine che cola, acqua e muffa.

**Telo della bagnina**
- Scarabocchi:
  - la faccia annerita sotto il cappellino cancellato;
  - l'occhio a spirale con una croce rossa;
  - il ghigno coi denti;
  - il rosso che cola dall'occhio;
  - il delfino col ghigno e l'occhio annerito;
  - il salvagente con gli occhi crocettati e la bocca cucita.
- A pastello: croci nere, un ghigno rosso sulla campana, righe viola sui tentacoli.
- Tagli di coltello in croce.
- Bruciature:
  - due grandi coi buchi, dal basso a destra e dal bordo sinistro sul salvagente;
  - un buco tondo bruciato sulla campana;
  - sette buchi di sigaretta.
- Strappi e sporco: uno strappo grosso, l'angolo in basso a sinistra ripiegato, fuliggine, acqua e muffa.

Gli scarabocchi sono solo disegni, senza scritte. Manca circa il 28% della carta.

## Nel gioco

**Texture e materiale**
- Le texture sono PNG con l'alfa, in `godot/assets/ambiente/sala/cartelloni_rovinati/`, VRAM Compressed con le mipmap.
- Il GLB della sala non cambia, perché lo usa anche lo spot VHS, dove il parco è ancora nuovo.
- `sala_principale.gd` (`metti_teli_rovinati`) mette sui due teli una copia del materiale importato, con la texture rovinata e l'alpha scissor come i `M_amb_alfa_*`.

**Posizionamento**
- La carta è incollata sulla lamiera della cornice: dove brucia o si strappa si vede la lamiera, e niente resta sospeso.
- Resta un pezzo solo di carta, senza frammenti staccati.
- La geometria, la cornice e le catene non cambiano.

**Test.** `test_sala` controlla che i due teli abbiano la texture rovinata con l'alfa.

## Scatti

Script: `godot/proposte/poster_sala/scatti_teli.gd`.
- **Come.** Dagli occhi del giocatore, con le luci vere del gioco (nel gioco la torcia non c'è più).
- **Quando.** All'arrivo nella sala e col lampione della statua acceso.
- **Prima e dopo.** Gli stessi punti, con lo stesso seme per i neon che sfarfallano.
- **La sala a pezzi.** La sala intera, renderizzata, non sta nella memoria della macchina di prova. Si caricano solo le sue parti, nella loro posizione, con l'ambiente della sala, e a ogni vista si accendono solo le mesh entro 16 m.

| Foglio | Cosa mostra |
|---|---|
| `1_arrivo_prima_dopo.jpg` | dall'ingresso, i due teli, i due teli col campo stretto |
| `2_lampione_prima_dopo.jpg` | lo stesso col lampione acceso (sui teli cambia poco) |
| `3_tecnico_torcia_prima_dopo.jpg` | **solo tecnico**: una torcia che nel gioco non c'è, per vedere i buchi e i bordi sulla lamiera |
| `4_texture_prima_dopo.jpg` | le texture piatte, prima e dopo, coi buchi sul grigio |

**Cosa si vede nel gioco.** La sala all'inizio è buia, e anche prima i teli erano scuri. Il faretto caldo di ognuno illumina il centro, e lì ora si vedono il buco bruciato sul petto e la croce coi denti rossi. Il resto del telo si intravede appena.

**Avvisi.** 0 "ERROR: BUG," nei due giri.
