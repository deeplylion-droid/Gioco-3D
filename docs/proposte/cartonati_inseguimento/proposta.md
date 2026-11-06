# Cartonati a pastello nelle condotte dell'inseguimento: proposte (enigmi, 6 novembre)

Richiesta dell'utente (6 novembre): «miglioriamo un po la zona delle vasche dove Jilly si affaccia mentre tu spruzzi
i bersagli. Sia le vasche che i bersagli sono troppo low quality. Dovrebbero sembrare giochi per bambini. Ci vorrebbe
qualche decorazione tipo cartonati fatti sempre in stile pastello a cera. Robe così, fatte dai bambini negli anni».

La zona è la sala macchine allagata delle condotte (`sala_inseguimento.gd`):
- tre vasche sospese di piastrelle verdi (5 x 6, 6 x 5,5 e 6 x 6 m), con l'acqua a 72 cm e il bordo 39 cm sopra il pelo;
- una lampada da lavoro calda sopra ogni vasca;
- le sei paratie col bersaglio, le bocche dei tubi, le passerelle con le ringhiere arancioni, i muri spogli;
- tre scarabocchi a pastello già approvati: i pesci sotto le onde, Jilly coi pesci e l'occhio.

Vasche e bersagli li propone grafica; qui ci sono solo le decorazioni. Sono proposte scritte: nel gioco non entra niente
finché l'utente non sceglie.

## Il motivo, uguale per tutte

Le condotte erano il "percorso avventura" del club dei bambini della nave: le tre vasche erano le tappe, i bersagli il
gioco "colpisci e apri". Ogni stagione il club faceva cartonati nuovi per decorarle, e lo staff li lasciava lì: i
vecchi sotto, i nuovi sopra. Poi la sala si è allagata.

Così ogni pezzo ha un motivo per stare dov'è. Ognuno è rovinato in modo diverso, secondo l'età e quanto sta in basso.
Al posto della firma c'è una manina colorata in un angolo, di un colore diverso per ogni bambino: niente nomi, date o
lettere.

## A. Sagome in piedi del club (consigliata)

- **Cosa**: animali del mare a figura intera, come li disegnano i bambini (pesce palla, granchio, tartaruga, polpo,
  stella marina, delfino, balena, cavalluccio). Quattro per vasca, 12 in tutto, alte da 60 cm a 1,3 m. Ogni vasca ha
  un tema: la prima la spiaggia, la seconda il mare aperto, la terza il fondo.
- **Come sono fatte**:
  - cartone ondulato spesso 5 mm, colorato a pastello a cera davanti e marrone dietro;
  - il contorno è tagliato a mano con le forbici: un po' storto, con l'onda del cartone che si vede sul taglio;
  - stanno legate con lo spago o il fil di ferro ai montanti delle ringhiere e ai pilastri, girate verso la vasca;
  - dove c'è un ripiano su cui non si passa, stanno in piedi col puntello di cartone dietro e un mattone sul piede.
- **Dove**:
  - attorno a ogni vasca, sul lato dove lei non sale e lontano dalle due paratie;
  - da dentro la vasca si vedono sopra il bordo, all'altezza degli occhi, sotto la lampada da lavoro;
  - mai sulle passerelle dove si cammina, davanti alle bocche, alle paratie o ai bersagli;
  - i punti precisi si scelgono dagli scatti dagli occhi, come per gli scarabocchi, e il coordinatore li vede prima.
- **Gli anni**, in tre età:
  - le più vecchie hanno i colori slavati, il cartone ingiallito e imbarcato, e il fondo scuro e gonfio d'acqua fino a
    una riga di marea, con qualche macchia di muffa;
  - le medie hanno colori pieni ma opachi e uno strappo riparato con lo scotch ingiallito;
  - una per vasca è nuova: colori vivi, scotch trasparente.
- **Come si fanno**:
  - i disegni col pastello che c'è già nel gioco (`assets_src/scarabocchi/pastello.py`), lo stesso degli scarabocchi,
    del cartello delle pozze e del disegno guida; una texture da 1024 per sagoma;
  - la sagoma si ricava dal contorno del disegno e si estrude a 5 mm col bordo di cartone, da codice, come il
    cartoncino coi fori del disegno guida (niente Blender);
  - l'età si fa con la texture (sbiadito, ingiallito, la riga dell'acqua) e con una leggera curvatura;
  - per leggerle al buio, un filo di luce propria come il disegno guida: i "pastelli fosforescenti", già approvati
    (0,1; a 0,3 sembrava uno schermo acceso);
  - le immagini fatte con l'IA, se servono, vanno solo dentro il gioco come texture, mai nelle pagine.
- **Tempo**: 6-8 ore. Comprende il collaudo dagli occhi in tutte e tre le vasche, con lei su e giù, e il controllo di
  posizionamento.
- **Rischi**:
  - poco spazio: niente sopra paratie, bersagli, bocche e salite di lei. Lo controlla il controllo di posizionamento,
    e ci sono gli scatti con lei su;
  - al buio una sagoma alta può far sobbalzare: va bene, purché non sembri lei. Nessuna è più alta di 1,3 m, e niente
    rosa;
  - 12 texture in più, circa 15 MB.

## B. La bacheca dei disegni e il festone

- **Cosa**:
  - disegni piatti su cartoncino, da 40 x 30 a 80 x 60 cm, sui muri della sala che si vedono da ogni vasca: quattro o
    cinque per vasca, sovrapposti come in una bacheca vecchia;
  - i soggetti sono il mare, i pesci, la nave, il sole e le vasche coi bersagli disegnate dai bambini;
  - sopra ogni vasca, un festone di 8-10 pesciolini di cartoncino legati a uno spago teso fra due montanti della
    ringhiera: lo spago parte e arriva a un montante, e pende appena.
- **Come sono fatti**: cartoncino da 2 mm, attaccato con lo scotch e le puntine; gli angoli si staccano e si piegano.
- **Dove**:
  - sui muri, all'altezza degli occhi da dentro la vasca, sopra la fascia di piastrelle, mai sopra paratie o bocche;
  - vicino ai tre scarabocchi della zona, come se fossero dello stesso club.
- **Gli anni**: come in A, più gli strati:
  - i nuovi coprono in parte i vecchi;
  - restano i buchi delle puntine e i rettangoli più chiari dove ce n'era uno tolto;
  - quelli in basso hanno tutti la stessa riga dell'acqua.
- **Come si fanno**: gli stessi disegni a pastello, in pannelli sottili come il cartello delle pozze. Il festone è un
  filo vero, coi capi fissati, così il controllo delle estremità lo guarda.
- **Tempo**: 3-4 ore, collaudo compreso.
- **Rischi**:
  - bassi;
  - i muri lontani dalle lampade possono restare bui: basta il filo di luce, oppure una lampadina in più, da decidere;
  - fa meno "giostra" di A.

## C. Le bocche dei tubi come bocche di animali

- **Cosa**: attorno a ogni bocca di tubo, un grande cartonato ad arco che la trasforma nella bocca di un animale
  (balena, squalo buffo, rana, polpo), largo 2-2,5 m, come l'ingresso di una giostra. Sono sei bocche delle paratie più
  quelle d'ingresso.
- **Come sono fatti**: cartone spesso avvitato al muro della vasca intorno alla bocca, senza entrare nel tubo. Gli
  occhi stanno sopra, i denti sono tondi di cartone.
- **Gli anni**: come in A.
- **Tempo**: 6-8 ore, più l'accordo con grafica, che rifà paratie e bersagli.
- **Rischi**:
  - alti per il gioco: le bocche colorate fanno concorrenza alla luce verde e alla rossa che dicono quale paratia è
    quella giusta;
  - va decisa insieme alle paratie nuove di grafica, meglio dopo.

## D, a parte, col tocco horror (si somma ad A o B; decide l'utente)

- Fra i disegni più nuovi, quelli degli ultimi bambini, c'è lei:
  - nei vecchi è la mascotte sorridente del parco, coi pesci;
  - nei più recenti è com'è adesso, alta sopra la vasca coi tentacoli, e i bambini sotto piccoli piccoli;
  - nell'ultimo, coi colori ancora vivi, c'è solo il suo occhio.

  Va col filo degli scarabocchi della zona (Jilly coi pesci, l'occhio).
- **Variante più forte**: una sagoma di lei alta 1,5 m, in piedi in un angolo buio della terza vasca, che si vede solo
  quando la lampada la prende. Rischio: il giocatore la scambia per lei vera e le spara. Può anche essere voluto, ma lo
  decide l'utente.
- **Tempo**: 1-2 ore in più.

## Vincoli, per tutte

- Scritte solo a disegni: niente parole, nomi o date. La firma è la manina.
- Lo stile è lo stesso pastello del gioco, col tratto e la carta degli scarabocchi e del cartello.
- Si leggono sotto le lampade da lavoro. Dove non arrivano, c'è il filo di luce già approvato per il disegno guida.
- Posizionamento:
  - tutto è legato, avvitato, appoggiato o attaccato con lo scotch, niente sospeso;
  - 2 m liberi sopra dove si cammina e si scivola, niente nei tubi né sulle bocche;
  - niente sopra paratie, bersagli o salite di lei;
  - ogni pezzo ha il motivo del club;
  - si mette con lo strumento comune e si collauda dagli occhi in tutti gli stati: lei su e giù, paratie aperte e
    chiuse, grata.
- Coerenza col GDD: «riprendere il tema giocoso ogni tanto, per fare contrasto con l'horror» (utente, 24 ottobre); lo
  stile C anni '90 coi pastelli sbiaditi.

## Immagini già fatte (niente scatti nuovi)

- La zona com'è oggi, coi tre scarabocchi della sala, le vasche, le ringhiere e i muri: `docs/proposte/scarabocchi/fogli/inseguimento.jpg` (lavoro/godot).
- Le vasche da dentro, dall'acqua: `docs/collaudo/vasche_sotto/foglio_acque_1.jpg` (lavoro/godot).
- Il pastello sul cartone, da vicino, e come sta legato:
  - `docs/collaudo/ritocchi_0321/disegno_giocattoli_struttura.jpg`;
  - `docs/collaudo/ritocchi_0321/disegno_dal_percorso.jpg`;
  - `docs/collaudo/ritocchi_0321/fascette_davanti_dietro.jpg`.

  Sono tutte su lavoro/ritocchi-enigmi-0321, già nella candidata 0321.
- Il cartello delle pozze, coi quadratini a pastello su lamiera: `docs/collaudo/ritocchi_0321/cartello_corridoio_prima_dopo.jpg` (lavoro/ritocchi-enigmi-0321).
- Il disegno degli acquari: `docs/proposte/acquari/B1_disegno_B.jpg` (lavoro/godot).
- Il filo di luce dei "pastelli fosforescenti", con e senza: `docs/proposte/enigma_giocattoli/scatto_1_disegno.jpg` e `disegno_senza_luce.jpg` (lavoro/godot; senza luce, al buio, da 4 m il disegno è un rettangolo scuro).
