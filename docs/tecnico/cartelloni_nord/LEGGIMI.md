# I due cartelloni del muro nord, bruciati e scarabocchiati (enigmi, 31 ottobre)

La richiesta dell'utente, il 30 ottobre: «ci sono due poster rettangolari sul muro in fondo della sala centrale, vanno bruciati e scarabocchiati moltissimo». Il 31 ha precisato: «i teli che dicevo io non sono quelli, sono i due sul muro in fondo, uno ha una balena tipo».

Il muro in fondo è quello nord, di fronte all'ingresso dagli spogliatoi, e ci sono tre cartelloni da 3,2 x 1,8 m. Gli scatti dal gioco con le luci vere, numerati (`candidati_*.jpg`), mostrano cosa si vede:
- dal centro della piscina si vedono bene solo **1, il delfino con l'ombrellone** (`sala_cartellone_n0`) e **2, la balena** sotto il pesce al neon (`sala_cartellone_n1`);
- il 3, il polpo (`n2`), è in luce rossa, e da vicino si capisce appena che è un cartellone.

Il coordinatore ha confermato 1 e 2. Il polpo e il cartellone del muro sud (`s0`, con la stessa grafica del polpo) restano com'erano. Restano come sono anche i teli ai lati della statua, perché l'utente ha scelto «così».

## Come sono rovinati

Le texture le fa `assets_src/ambienti_interni/poster/rovina.py` (`cartellone_delfino`, `cartellone_balena`), lo strumento di grafica-2, al livello più forte. Sono diversi fra loro e diversi dai teli.

Rispetto ai teli c'è più vernice chiara, bianca e rossa, e meno fuliggine, così si leggono anche con la poca luce della sala. Restano bruciati sul serio: manca circa il 28-29% della carta, e intorno ai buchi c'è il bordo carbonizzato.

**Delfino**
- Scarabocchi:
  - l'occhio annerito a spirale con la croce rossa;
  - il ghigno coi denti bianchi;
  - l'ombrellone cancellato a righe nere fitte;
  - la barchetta crocettata;
  - zig-zag e graffi bianchi.
- A pastello: una croce bianca e denti rossi sulle onde.
- Tagli di coltello sul delfino.
- Bruciature: dall'angolo in alto a sinistra giù lungo il bordo e dal basso al centro, un buco tondo sull'ombrellone, buchi di sigaretta.
- L'angolo in basso a destra è ripiegato.

**Balena**
- Scarabocchi:
  - l'occhio a spirale con la croce bianca;
  - un ghigno enorme coi denti bianchi sulla bocca;
  - il cappellino annerito;
  - il sole cancellato a spirale, con gli occhi crocettati e i denti rossi;
  - zig-zag neri sul cielo;
  - le stelle con gli occhi crocettati.
- Una croce rossa a vernice sul corpo.
- Bruciature: dall'angolo in basso a destra fino alle stelle, una lingua dal bordo sinistro in basso, un buco tondo sulla pancia, buchi di sigaretta.
- Uno strappo che scende dal bordo in alto a sinistra.

Gli scarabocchi sono solo disegni, senza scritte. Su tutti e due ci sono anche macchie d'acqua, muffa e colature.

## Nel gioco

- **Texture.** PNG con l'alfa in `godot/assets/ambiente/sala/cartelloni_rovinati/`, VRAM Compressed con le mipmap.
- **Materiale.** `sala_principale.gd` (`metti_cartelloni_rovinati`, con la stessa funzione dei teli) mette sui due cartelloni una copia del materiale importato, con la texture rovinata e l'alpha scissor. Vale solo su quelle due mesh: il GLB della sala resta pulito per lo spot VHS, e il materiale del polpo, che è lo stesso del muro sud, non cambia.
- **Posizionamento.** La carta è incollata sulla lamiera della cornice appoggiata al muro: dove manca si vede la lamiera, e resta un pezzo solo di carta. La geometria non cambia.
- **Luci.** Intatte.
- **Test.** `test_sala` controlla che siano rovinati delfino e balena, e non il polpo né il cartellone del muro sud.

## Scatti

Script: `godot/proposte/poster_sala/scatti_muro_nord.gd`.
- **Come.** Dagli occhi del giocatore, con le luci vere del gioco: all'arrivo e col lampione della statua acceso.
- **Prima e dopo.** Gli stessi punti, con lo stesso seme per i neon.
- **La sala a pezzi.** Si caricano solo le sue parti, come per i teli, con le mesh entro 22 m.

| Foglio | Cosa mostra |
|---|---|
| `candidati_*.jpg` | i tre cartelloni numerati, prima della scelta |
| `1_giro_arrivo_prima_dopo.jpg` | il giro all'arrivo: dall'ingresso, dal centro della piscina, da ovest, da est, sotto il muro |
| `2_giro_lampione_prima_dopo.jpg` | dal centro e sotto il muro, col lampione acceso |
| `3_da_vicino_prima_dopo.jpg` | da vicino, sotto il delfino e la balena, e il delfino di lato: come stanno sul muro; più il polpo, che non cambia |

**Cosa si vede**
- Da vicino si leggono le bruciature coi buchi sulla lamiera, i ghigni coi denti e gli occhi crocettati.
- Dal centro della piscina i due cartelloni sono piccoli e in penombra: si vede che sono rovinati, ma non i dettagli.
- L'appoggio al muro non cambia: la cornice e la lamiera sono le stesse, e cambia solo la carta.

**Controlli**
- 0 "ERROR: BUG," nei due giri.
- `test_sala` verde in locale.
- Il controllo di posizionamento in locale è in fondo al messaggio di consegna.

## La torre degli scivoli (31 ottobre)

Richiesta dell'utente: «gli stessi disegni ci sono anche nella torre degli scivoli, sostituiscili con questi rovinati».

Nella torre (`torre_prop.glb`) ci sono quattro cartelloni uguali a quelli della sala. Tre hanno ora le stesse texture rovinate della sala:
- `torre_cartellone_0`, delfino, in alto sul muro nord;
- `torre_cartellone_1`, balena, sul muro sud sopra la lampada rossa;
- `torre_cartellone_3`, delfino, in basso sul muro nord, vicino al fondo.

Il polpo (`torre_cartellone_2`) resta com'è.

**Altri posti.** Nel resto del gioco questi disegni non ci sono. Le altre copie stanno solo in `godot/proposte` (torre_A_prop, inseguimento_B) e nella texture dello spot VHS, che resta pulita.

**Nel codice**
- La sostituzione del materiale è la stessa della sala, in `scripts/game/poster_rovinati.gd` (`PosterRovinati`), comune a sala e torre.
- `SalaTorre` la fa in un passo subito dopo i tre GLB, prima di `prepara_materiali`, che compila già il materiale nuovo.
- Il GLB della torre non cambia, e le luci sono intatte.
- `test_torre` controlla che siano rovinati i tre cartelloni e non il polpo.

**Scatti** (`godot/proposte/poster_sala/scatti_cartelloni_torre.gd`, la torre costruita e preparata come nel gioco):

| Foglio | Cosa mostra |
|---|---|
| `4_torre_giocatore_prima_dopo.jpg` | dagli occhi del giocatore: dal checkpoint più vicino da cui ogni cartellone si vede, e dal pavimento davanti |
| `5_torre_da_vicino_prima_dopo.jpg` | ravvicinati a 1,5 m. Il delfino 0 è al buio: il suo ravvicinato è con una lampadina solo tecnica, che nel gioco non c'è |

**Cosa si vede**
- La balena e il delfino 3 si vedono bene dalle pedane e dal fondo, e si leggono bruciati e scarabocchiati.
- Il delfino 0 sta in alto dietro i tubi degli scivoli e al buio: anche prima dalle pedane si vedeva poco o niente.
- L'appoggio sulla cornice e sul muro non cambia, perché cambia solo la carta.

**Una macchia bianca.** In un primo scatto del delfino 3 c'era una macchia bianca sotto il cartellone. Rifacendo la stessa vista quattro volte non c'era più: era qualcosa di passaggio nella torre, non il cartellone.

**Pipeline.** In costruzione e preparazione la torre ne compila 2+4 in più, quelle del materiale nuovo, durante la preparazione e non mentre si gioca. 0 "ERROR: BUG,".
