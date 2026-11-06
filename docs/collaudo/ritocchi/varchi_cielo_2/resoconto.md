# Ricontrollo delle correzioni di varchi-cielo (ambienti-1): giunzione, soglia della torre, controllo del cielo

Squadra collaudo, 6 novembre. Ho controllato `lavoro/varchi-cielo` 081b4e9f (codice 2f5cc7ab) senza cambiare niente nel gioco. Il controllo di prima è in `docs/collaudo/ritocchi/varchi_cielo/`. I numeri sono in `numeri.txt`; gli strumenti nuovi (`soglia_giro.gd`, `soglia_scatti.gd`, `soglia_capi.gd`) in `godot/tests/collaudo/`.

## In breve
- **Angoli della giunzione: chiusi.** Con `cielo_angoli_onde.gd` vanno nel cielo 0 raggi su 6048; prima erano 100.
  - Dalla strada le due lastre dei lati non si vedono, e i passi sono identici a prima.
- **Controllo del cielo: ok**, anche sugli 11 checkpoint della torre.
  - Il raggio verso il basso dal portone non va più nel cielo.
  - Restano solo i raggi verso l'alto, messi a parte come previsto.
- **Soglia del portone: si cammina bene.** A piedi, di corsa e coi salti si passa in tutti e due i versi, e i piedi non scendono mai nella fessura. Al centro del vano la lastra chiude il cielo.
- **Difetto da girare ad ambienti-1: la fessura continua oltre i due capi della lastra.** È un buco vero, non un riflesso: con lo sfondo magenta di prova resta magenta. Si vede dagli occhi, in piedi sulla passerella della torre.
  - Verso z -13,5 è lunga 1,4 m (fino a z -12,1), larga 30 cm e aperta sopra.
  - Verso z -16,5 è di circa 8 cm.
- Test: 0 BUG e 0 SCRIPT ERROR in tutti i log.

## Test su 081b4e9f
| controllo | esito |
|---|---|
| controllo_cielo | ok: 228 posti, 0 col cielo; 18 vedono la cupola (voluto); 0 fessure sottili; 5 raggi verso l'alto nella torre (a parte) |
| cielo_angoli_onde (gioco vero, griglia attorno alla giunzione) | 0 raggi nel cielo su 6048 (su ea6f5f71 erano 100) |
| cielo_zone torre (110 posti) | 3 col cielo, tutti verso l'alto (portone, NEm3, NOm12); al portone il raggio verso il basso non c'è più |
| test_portone_torre | 20 ok |
| test_strada | 36 ok |
| controllo_varchi | ok |
| check_scripts | 0 errori |
| controllo_posizionamento | 0 da correggere, 0 nuovi, 64 già noti |

## 1. La giunzione camera delle onde - sala pompe
- **I raggi.** `cielo_angoli_onde.gd`, nel gioco vero con i corpi dalle mesh visibili: 0 raggi su 6048 vanno nel cielo.
- **I passi.** Ho usato `lastra_giro.gd` (x da -1 a +1, a piedi, di corsa e coi salti, nei due versi). I numeri sono identici al giro su ea6f5f71:
  - i piedi stanno fra -9,051 e -9,049;
  - a x -1 c'è un rialzo di 1,5-3,5 cm che c'era già (davanti alla giunzione il pavimento è a -9,037);
  - il rallentamento a x ±1 andando verso nord c'era già.
- **Gli scatti** (`fogli/giunzione_lati.jpg`, prima su ea6f5f71 e dopo):
  - visti dal vuoto fuori dal corridoio (x ±2), le lastre dei lati chiudono la fessura dove prima si vedeva il cielo;
  - dal corridoio, da sud e radenti, gli scatti sono uguali a prima: le lastre non si vedono;
  - guardando in giù da sopra il vuoto fuori dai muri si vede ancora il cielo, uguale a prima. Lì il giocatore non arriva.
- **Lo sfarfallio** della striscia al centro, spostando la camera di 1 cm: come prima (0,1-1 su 255; fino a 6,7 da 2 m a nord, per la lampada rossa che sfarfalla).

## 2. La soglia del portone della torre
### Il pavimento e i passi (gioco vero, `soglia_giro.gd`)
- **Le collisioni.** Il pavimento della sala è a 0,000 fino a x 20,0, la lastra a -0,015 fra x 20,05 e 20,15, il grigliato a -0,010 da x 20,2.
- **I passi.** A piedi, di corsa e coi salti, a z -16,1, -15,6, -15, -14,4 e -13,9, verso la torre fino a x 20,8 (prima dell'entrata) e indietro verso la sala:
  - si arriva sempre e non si perde mai il pavimento;
  - i piedi stanno fra -0,010 e +0,027;
  - salendo dal grigliato al pavimento della sala c'è un gradino di 1 cm, che c'era già: senza la lastra il cammino dà gli stessi numeri;
  - la velocità non cala: a piedi resta fra 2,75 e 3,33 m/s, di corsa fra 4,05 e 5,41 m/s.
- **La fessura è stretta** (16 cm): il giocatore non ci scende nemmeno senza la lastra. La lastra serve solo per la vista.
- **L'entrata vera.** Entrando a piedi si entra (x 21,12) e il portone si chiude del tutto. La lastra resta, con la torre.

### Dagli occhi e da vicino
Gli scatti sono di Vulkan a parti: la sala e la torre col guscio tolto, come lo strumento di ambienti-1.
- **Senza il giocatore vero.** Con lui il processo superava la memoria, quindi la camera segue la strada degli occhi a 1,6 m, ogni 34 cm.
- **Lo sfondo magenta.** Per distinguere un buco da un riflesso ho rifatto gli stessi scatti con lo sfondo magenta pieno, tenendo luce e riflessi dal cielo. Quello che è magenta è un buco vero.

I fogli:
- `fogli/soglia_occhi.jpg`: dagli occhi, prima, dopo, dopo schiarito e magenta;
- `fogli/soglia_capi.jpg`: i due capi del vano;
- `fogli/soglia_vicino_luce.jpg`: da vicino con la lampadina tecnica.

Cosa si vede:
- **Al centro del vano la lastra chiude il cielo.** Prima, lungo il grigliato, si vedeva la striscia di nuvole; ora c'è il pavimento.
- **Ai due capi la fessura continua oltre la lastra**, lungo la base del muro, fuori dal vano. Negli scatti magenta è magenta, quindi è un buco vero.
  - Si vede dagli occhi sulla passerella della torre, nel punto del checkpoint del portone (x 21,6, z -15) e a z -13,9 (x 21,26), guardando verso la sala.
  - Si vede anche fermi sulla soglia, guardando in basso. Nel gioco è il cielo scuro con le nuvole: a luminosità normale è debole, schiarito si vede bene.
- **Fin dove arriva**, coi raggi in giù fra x 19,95 e 20,30 contro le collisioni e le mesh vere (`numeri.txt`, "lungo il muro"):
  - verso z -13,5 non c'è niente, né sotto né sopra fino a 2,5 m, da z -13,48 (fine della lastra) a z -12,1, per tutta la larghezza da x 20,0 a 20,3; da z -12,0 a -11 resta aperta la parte da x 20,2 a 20,3;
  - verso z -16,5 la striscia vuota va da z -16,52 a circa -16,6, fra x 20,0 e 20,2; più in là resta solo la colonna a x 20,025, coperta sopra a 1,02 m.
- **Proposta (decide ambienti-1).** Allungare la lastra, o chiudere sotto, quanto la fessura: almeno da z -16,62 a -12,0, con la larghezza fino a x 20,3 sul lato verso z -13. Poi rifare `soglia_capi.gd` e `soglia_scatti.gd` con `MAGENTA=1`: non deve restare magenta.

### Una nota sull'aspetto (non è un difetto, la giro per decidere)
Con la lampadina tecnica, e schiarendo, la lastra si vede come una striscia grigio chiaro, più chiara del pavimento bagnato della sala accanto (`soglia_vicino_luce.jpg`, "da torre" e "dall'alto"). A luminosità normale, al buio del blackout, è poco visibile.

## 3. Il controllo del cielo sulla torre
- controllo_cielo carica la torre come nel gioco: guscio tolto e costruita del tutto. Poi tira i raggi dagli 11 checkpoint, e tutti sono ok.
- **I 5 raggi verso l'alto messi a parte.** Escono quasi tutti dalle pareti di torre_A, a 6-13 m dagli occhi e in basso (y da -7,5 a 6,1), non dalla cima aperta; solo quello di NOm12 verso (0,13, 0,90, 0,41) esce in alto, a y 14:
  - portone verso (0,43, 0,34, 0,84): esce a y 6,1;
  - NEm3: due raggi, escono a y 3,8 e 4,1;
  - NOm12 verso (0,69, 0,39, -0,62): esce a y -7,5.
- **Cosa dicono gli scatti di prima.** Per NEm3 e l'apertura di lato di NOm12, gli scatti del giro precedente non mostravano il cielo. Per il portone verso l'alto lo mostravano, ma era la torre da sola.
- **Quindi** non sono tutti "la cima aperta", e lo stampato "cielo verso l'alto" li mette insieme. Conviene che ambienti-1 li guardi uno per uno prima di girarli all'utente come domanda sulla cima.
- **La soglia nel controllo.** I raggi del controllo, 240 per posto, non prendono la fessura ai capi della soglia: è stretta e sta di lato rispetto al checkpoint. L'hanno presa solo gli scatti.
