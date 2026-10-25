# Collaudo "Jilly dietro gli oblò": cornice tonda (lavoro/oblo-tondo 1a3a6727)

Squadra grafica, 25 ottobre. Solo documentazione: niente è stato corretto.

Oblò controllati: ObloFiume, ObloPersonale e ObloServizio (Risalita) e quello della torre (vetro 0,6).
Gli scatti ravvicinati sono fatti con una luce bianca sulla camera, perché al buio non si vedrebbe niente. Lo script è `godot/tests/collaudo/ravvicinati_oblo.gd`.

Fogli dei ravvicinati, uno per oblò: `fogli/foglio_ravv_*.jpg`.
Gli scatti dei difetti sono in `difetti/`.

## Esito per punto

1. **Niente quadrato scuro, né bordi neri:** ok in tutti e quattro. La piastra scura non c'è più, e intorno al vetro c'è solo il bordo d'ottone con la flangia.
2. **Il muro continua fino alla cornice:** NO in due oblò su quattro, forse tre (vedi D1, D2 e D3).
3. **La flangia aderisce al muro, coi rivetti sopra:** ok in tutti e quattro. Negli scatti di sbieco (o, p, q) e da vicino (h, i, j, k) la flangia sta sul muro senza distacco, e i rivetti poggiano sulla flangia.
4. **Lei dietro il vetro:** ok, ferma di fronte e di sbieco in tutti e quattro (m, n). Gli altri stati sono più sotto, negli scatti dagli occhi del giocatore.

## Difetti

- **D1. Torre: riquadro più chiaro attorno all'oblò.** La faccia nuova del muro (il quadrato di 1,9 m) è più chiara delle piastrelle vere intorno, con i bordi netti, anche se le piastrelle combaciano. Forse la faccia nuova non riceve l'ombra o ha un'altra normale.
  - Scatto: `difetti/1_torre_riquadro_chiaro.jpg`.
- **D2. ObloServizio: giunta verticale netta sul bordo del quadrato,** in alto a destra. A sinistra la lamiera è più scura e ha un altro disegno, a destra è più chiara, con una riga chiara in mezzo. Va confermato se è il bordo della faccia nuova o una giunta delle lamiere vere: cade dove dovrebbe stare il bordo del quadrato.
  - Scatto: `difetti/2_servizio_giunta.jpg`.
- **D3. ObloFiume: probabile giunta** nello stesso punto, in alto a destra: una riga chiara di sbieco, con la lamiera diversa ai due lati.
  - Scatto: `difetti/3_fiume_giunta.jpg`.

ObloPersonale: nessun difetto visto.

## Scatti dagli occhi del giocatore, Risalita

Foglio: `fogli/foglio_giocatore_risalita.jpg`, fatto con `tests/scatti_oblo_lei.gd` e i materiali veri, al buio.
Per ogni oblò ci sono cinque scatti:
- da lontano, quando lei arriva;
- da vicino, quando è ferma;
- due mentre si stacca;
- uno ravvicinato.

Lei sta dietro il vetro in tutti gli stati e in tutti e tre gli oblò. La cornice tonda si legge bene anche al buio, e non c'è nessun quadrato scuro.

- **D4. ObloServizio, posa capovolta, al 60% del distacco: la macchia giallo-rosa c'è ancora.** Ingrandita, è la gonna di lei (capovolta, quindi in alto) che si avvicina al vetro. È così vicina alla sua luce rosa che si brucia: diventa gialla e mostra righe verticali. Il bordo del vetro la taglia di netto, quindi sta dietro il vetro e non lo attraversa.
  - Non è un problema di posizione ma di aspetto (luce troppo vicina alla gonna in quel momento).
  - Scatto: `difetti/4_servizio_macchia_gonna.jpg`.

## Scatti dagli occhi del giocatore, torre (vetro 0,6)

Foglio: `fogli/foglio_giocatore_torre.jpg`, fatto con `tests/scatti_oblo_torre.gd`. Ci sono tre scatti: da lontano, da vicino e ravvicinato.
Lei sta dietro il vetro e la cornice è a posto.

- **D1 si vede anche dal punto dove passa il giocatore,** e non solo con la luce sulla camera: attorno all'oblò c'è un quadrato di piastrelle più chiare. Si nota già da lontano.
  - Scatto: `difetti/1b_torre_riquadro_dal_giocatore.jpg`.
- Manca lo scatto mentre lei si stacca nella torre: la prova è finita fuori tempo, su llvmpipe, prima di quello scatto.

## Non fatto in tempo

Su questa versione non ho rifatto due prove:
- la luce rosa dietro i muri (`tests/collaudo/luce_oblo.gd`);
- gli stati prima del blackout e dopo che lei se n'è andata (`tests/collaudo/stati_oblo.gd`).
Con la cornice tonda non dovrebbero cambiare.

## Torre: il distacco (aggiunto dopo, su richiesta del coordinatore)

Foglio: `fogli/foglio_distacco_torre.jpg`, fatto con `tests/collaudo/distacco_oblo.gd`. Lo scatto è dagli occhi del giocatore, da vicino. C'è uno scatto ogni 8 fotogrammi dall'inizio del distacco.

- **D5 (vecchio, sbagliato: lo script girava senza `--fixed-fps`, vedi sotto). Nella torre lei sparisce di colpo.** Dopo 8 fotogrammi stacca le mani dal vetro, a 16 si è appena allontanata, e già a 24 non c'è più niente: né lei né la sua luce rosa. Non si vede la discesa lenta nel buio dell'acqua, che invece nella Risalita c'è (lì a 72 fotogrammi lei si vede ancora). Su llvmpipe i fotogrammi sono lenti, quindi in tempo vero sono pochi decimi di secondo o poco più. Ma la sparizione avviene tutta fra due scatti di fila.

## Ricontrollo su lavoro/oblo-tondo 4943e409 (torre)

Fogli in `fogli_4943/`. Tutti gli scatti sono a `--fixed-fps 60`.

- **D1 corretto.** Negli scatti ravvicinati (g e gli altri angoli) non si vede più il riquadro chiaro: le piastrelle della faccia nuova hanno lo stesso colore di quelle vere.
- **Flangia e rivetti:** come prima, ok.
- **Lei:** ok, ferma dietro il vetro.
- **D5, distacco rifatto bene** (passo 8 fino a 160 fotogrammi, cioè 2,7 s): lei stacca le mani e si allontana piano. La zona di lei si scurisce poco a poco: la luminosità media scende da 51,8 a 43,0 fra il fotogramma 24 e il 152.
  - Tra il fotogramma 152 e il 160 sparisce invece tutta in una volta (da 43,0 a 30,6), lei e la sua luce, mentre si vedeva ancora bene.
  - Resta da decidere se va bene così o se deve finire di sparire nel buio prima di togliere il modello.

### Torre dagli occhi del giocatore e luce rosa (4943e409)

- **Dagli occhi del giocatore** (`fogli_4943/foglio_giocatore_torre.jpg`): il riquadro chiaro non si vede più, né da lontano né da vicino. Lei sta dietro il vetro in tutti e quattro gli scatti, compreso quello mentre si stacca.
- **Luce rosa dietro i muri** (`tests/collaudo/luce_oblo.gd`, `fogli_4943/foglio_luce_torre.jpg`, con le colonne con / senza / differenza): da 8 punti, con lei accesa e spenta.
  - In tre punti dalla parte della torre il rosa in più è solo lei vista dal vetro. È giusto: lo script ha preso il vetro per un muro.
  - **D6. Dalla sala delle condotte,** dal punto (41,95, -19,9, -16,7), dietro il muro della torre, la luce rosa disegna sottili righe rosa lungo i bordi di un rettangolo. È il fuori della cisterna (o il buco del muro) visto dalle condotte. Al massimo il rosa vale 0,22, ma è tutto su quelle righe: la luce passa dalle fessure fra la vasca e il muro.
    - Scatto: `difetti/6_torre_luce_rosa_condotte.jpg`.
