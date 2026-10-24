# Collaudo della v0.3.12: torre degli scivoli e inseguimento

Squadra enigmi (collaudo, non ha costruito la zona), 24 ottobre notte. Base finale: `lavoro/cancelletti` **b8964240** (da `lavoro/godot` e0960137, con le ringhiere B di `lavoro/texture-calme` 7e37aaa9), unita in `lavoro/collaudo-enigmi`, import fresco. Scena `scenes/sala/torre/sala_torre.tscn` (torre e sala dell'inseguimento), stati `inizio` (portone chiuso, prima della discesa) e `aperto` (dopo la discesa: grata calata, paratie aperte). Posizioni in metri nel mondo della torre caricata da sola; i nomi `@MeshInstance3D@…` sono quelli di questa scena (nella sala grande cambiano).

## Come è stato fatto

- **Distanze vere** (`tools/collaudo/distanze.py`): 472 oggetti in tutti e due gli stati. Cinque non arrivano all'architettura, ma sono ciambelle, paperelle, un pallone e un salvagente che galleggiano sull'acqua (come nei collaudi di prima).
- **Spazio per la testa** (`testa.py`): 0 casi, in tutti e due gli stati.
- **Attacchi degli scivoli** (nuovo, `tools/collaudo/attacchi_scivoli.py`): dove i 21 scivoli e tubi toccano o sfiorano la struttura (entro 5 cm), campionati ogni 5 mm: 137 posti, ognuno con due ravvicinati; per i 14 dove resta più di 1 cm, anche uno stretto a 40 cm (`attacchi_stretti/`, `attacchi_non_a_contatto.jpg`). La compenetrazione la giudica il passo f) del controllo della CI e gli scatti: la stima "dentro" dello strumento non è affidabile sulla struttura intagliata.
- **Giro dagli occhi**: 55 punti lungo scale, passerelle, imbocchi, vasche d'arrivo e vasche dell'inseguimento, 4 scatti per punto (`fogli/torre_giro_*.jpg`).
- **Cancelletti delle bocche chiuse e lampade rosse**: ravvicinati di ogni pezzo su tre commit (`cancelli/`, `cancelli_15099922/`, `cancelli_b8964240/`).
- **Vedute ravvicinate degli oggetti piccoli**, **giro nello stato aperto** e **controllo di posizionamento**: vedi sotto.

## Difetti trovati e corretti stanotte (verificati sul commit finale)

| # | Cosa | Visto su | Stato su b8964240 |
|---|---|---|---|
| 1 | Gli 8 cancelletti delle bocche chiuse: le sbarre finivano 5 cm sopra la grata e il corrimano 14 cm prima dei pali (pannello sospeso) | 7e37aaa9 | corretto: corrente in basso sulla grata, sbarre dal corrente, corrente e corrimano nei pali, pali dalla grata (`cancelli_c1_c3_c5_c7_ok.jpg`, `cancelli_corretti_ok.jpg`) |
| 2 | c3, c5, c7: corrente e piede delle sbarre dentro il labbro della testata del canale (in c7 si vedeva) | 15099922 | corretto: 9-11 cm dal canale; gli altri cancelletti 1,6-6 cm |
| 3 | Lampada d'emergenza `@82` a 8,3 mm dal tubo che le fa da muro | 7e37aaa9, 15099922 | corretta: poggia sul tubo (3,7 mm agli spigoli della scatola, che tocca il tubo tondo lungo la linea di mezzo); le altre 6 a 0-0,1 mm (`lampade_emergenza.jpg`) |

Le 8 lampade rosse delle bocche chiuse (`@306`…`@324`) stanno sulla targa a strisce in cima ai cancelletti e toccano (gli 8 "staccati" di ambienti-1 su 1f140d67 erano un import vecchio).

## Da vedere (su b8964240)

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | `TorreScivoli/torre_scivolo_7` con `TorreStruttura/torre_A_sostegni` | 37,36, 6,46, -12,52 | Dove un'asta dei sostegni arriva al tubo rosso, nella superficie del tubo c'è un buco nero con dentro il moncone grigio dell'asta. Il tubo è uno di quelli chiusi dalla grata (non ci si entra) e il punto più vicino da cui lo si guarda è a 9 m. | `attacchi_stretti/a125_torre_scivolo_7_a.jpg`, `_b.jpg` |
| 2 | `TorreScivoli/torre_tubo_inseguimento` sopra `TorreStruttura/torre_A` | 39,58, -19,32, -17,4 e 38,67, -19,34, -17,4 | Il tubo dell'inseguimento passa 1,3-2,1 cm sopra la trave grigia, con la fessura scura in vista; il giocatore passa a 1,4 m. Va bene se la trave non lo regge lì, altrimenti va appoggiato. | `attacchi_stretti/a133_…`, `a134_…` |
| 3 | Noto dal collaudo di prima: il tubo lungo inclinato nella vasca dell'inseguimento | vicino a 43,5, -33,4, -3,5 | C'è ancora (scatti `ti052_e`, `ti052_s`): sta nell'acqua lungo il fondo. | `fogli/torre_giro_09.jpg` |

## Visti e a posto

- Il giro dagli occhi lungo tutta la strada non mostra altri oggetti sospesi o compenetrati.
- Gli scivoli poggiano sulle pedane e sulle grate (ravvicinati degli attacchi); dove restano a 1,6-4 cm dalla struttura è davanti alle testate, coi pali rossi dei cancelletti, che non devono toccarli.
- Le 8 bocche chiuse stanno su pedane dove il giocatore non arriva: le vede da altre pedane, coi pali rossi, la targa a strisce e la lampada rossa.
