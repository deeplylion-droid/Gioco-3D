# Collaudo finale della 0.3.21 sulla candidata c6187286 (7 novembre)

Squadra collaudo. Lo stato provato è `lavoro/candidata-0321` c6187286, senza cambiare niente nel gioco. La prima parte, le condotte su 080ec07e, l'ho mandata prima al coordinatore. Stendardi, sagome e paratie da vicino li ha fatti mascotte; il bacino enigmi.

**Esito: va bene, nessun difetto da girare.**

## Test (0 BUG)
| test | esito |
|---|---|
| check_scripts | 0 errori |
| controllo_cielo | ok: 228 posti, 0 col cielo; spariti i raggi verso l'alto della torre; dal bacino verso la porta 81 raggi, 0 escono |
| test_fondo_porta_bacino | 20 ok |
| test_passi_orfani | 10 ok |
| test_sagome_club | 13 ok |
| test_inseguimento, occhio_sopra_acque, morbidezza_inseguimento, inseguimento_suoni, scaletta_bacino | 43, 106, 72, 24, 13 ok |
| test_portone_torre, ripartenza_oltre_portone, torre, scivoli | 20, 53, 95, 26 ok |
| test_strada, continua, partenze_prova, tecnici, avvio_sicuro, controllo_varchi | 36, 127, 72, 87, 26, 1 ok |
| controllo_posizionamento | 0 da correggere, 0 nuovi, 64 già noti, nei 15 stati |

test_torre_ingresso senza schermo non vale perché vuole il renderer vero: lo guarda il coordinatore nella CI (Vulkan).

## Ricontrollo di varchi-cielo
### La soglia del portone e l'intercapedine
- **La lastra.** Va da z -18,25 a -7,15 e da x 19,94 a 20,24, 1,5 cm sotto il pavimento (`numeri.txt`).
  - Ai due capi del vano, dove sulla 081b4e9f c'erano le strisce vuote, ora c'è la lastra.
  - Coi raggi in giù contro le collisioni e le mesh vere restano libere solo due fasce:
    - x 20,25-20,30 fra z -13,3 e -11, già dentro lo spessore della parete della torre;
    - una colonna di 2,5 cm a x 20,225 fra z -18,3 e -18,6.
  - Negli scatti magenta nessuna delle due si vede.
- **Camminabile** (gioco vero, `soglia_giro.gd`). A piedi, di corsa e coi salti, in 5 punti della larghezza e nei due versi, i numeri sono identici al giro prima della lastra lunga:
  - si arriva sempre e non si perde mai il pavimento;
  - i piedi stanno fra -0,010 e +0,027 (il gradino di 1 cm dal grigliato alla sala c'era già);
  - l'entrata vera chiude il portone.
- **A occhio** (`fogli/soglia_prima_e_finale.jpg`: a sinistra 081b4e9f, al centro la finale, a destra la finale a sfondo magenta).
  - Ora la lastra ha la texture del pavimento bagnato, con le bolle e le macchie. La striscia grigio chiaro di prima non c'è più, dagli occhi e da vicino con la lampadina.
  - A sfondo magenta, dagli occhi, sulla soglia e da vicino: 0 magenta.
- **I capi e l'intercapedine** (`fogli/soglia_capi_magenta.jpg`, `soglia_capi.gd`). A z -17,5, -16,56, -13,44 e -12,5, da sala, da torre, dall'alto, radenti e dagli occhi, con e senza lampadina: 0 magenta.

### La giunzione camera delle onde - sala pompe
`cielo_angoli_onde.gd`: 0 raggi nel cielo su 6048.

## La torre con le toppe di torre_A
Gli strumenti:
- `scatti_portone_torre.gd` di ambienti-1;
- la sua copia `cubo_torre.gd`, con la sola torre, senza la sala: con la sala il renderer software andava oltre la memoria e la macchina si è riavviata.

**Gli 11 checkpoint a sfondo magenta, con la sala caricata** (`fogli/torre_checkpoint_magenta.jpg`, 65 scatti su 66: manca quello verso il basso dal checkpoint del bacino):
- 0 magenta, anche verso il tetto, dove sulla 081b4e9f si vedeva il cielo;
- dalla vasca del bacino verso ovest, la porta della cabina mostra il fondo nero anche senza il tunnel.

**Gli 11 checkpoint con le luci della sala** (`fogli/torre_checkpoint_luci.jpg`; blackout, senza lampadina e senza la sala):
- niente di strano;
- dal checkpoint del portone verso nord, ovest e sud si vede il cielo perché in questa corsa manca la sala (con la sala caricata, nella corsa magenta, lì non c'è niente).

**La discesa a sfondo magenta** (174 scatti, un punto ogni tre della discesa, 6 direzioni, senza la sala):
- Il magenta c'è in 45 scatti. Riportato sul piano del muro ovest della torre (x 20,2), cade tutto in un solo rettangolo: y da 0 a 5,05 e z da -17,86 a -11,98 (`magenta_piano.txt`). È l'apertura della parete della torre verso la sala, più grande del vano del portone (5,9 x 5 m). Nel gioco la chiude il muro della sala col portone, e con la sala caricata il magenta è 0.
- Il box del vano che avevo usato prima era stretto, quindi l'ho allargato:
  - prima: x 19,9-20,3, y -0,5..4,5, z -16,8..-13,2, più 4 px;
  - dopo: x 19,5-20,6, y -1..5, z -18,5..-11,5, più 10 px.
- In 42 scatti c'è magenta nella fascia aggiunta (`magenta_fascia.txt`). Viene tutto dalla stessa apertura: non è un buco fra stipiti o battenti, ma il resto dello stesso rettangolo, sopra e ai lati del vano della sala. Fuori dal box nuovo: 0 pixel. Il foglio `fogli/discesa_magenta_fascia.jpg` ha i tre scatti con più magenta nella fascia, col box vecchio (verde) e quello nuovo (giallo).

**Le toppe da vicino.**
- Con le luci della sala più una lampadina sulla camera (`fogli/toppe_torre.jpg`, 19 pose):
  - il tetto è buio e uniforme;
  - il fondo del pozzo continua senza giunte;
  - la parete sud a (38; -16,6; -4) è uniforme come il "dopo" di ambienti-1;
  - le altre toppe sud ed est sono lisce;
  - in 4 pose della parete est la toppa sta dietro uno scivolo;
  - una posa sud era fuori dalla torre e non conta.
- Il coordinatore ha fatto notare che la lampadina nel gioco non c'è, e che vicino potrebbe schiarire proprio la differenza cercata. Ho rifatto le pose entro 6 m senza lampadina, con le sole luci della sala (`fogli/toppe_senza_lampadina.jpg`, 9 pose, normale e schiarita x3):
  - il fondo del pozzo e la parete sud a (38; -16,6; -4) sono al buio, neri anche schiariti;
  - la parete sud a 27,5;5,7 e la parete est (7,0;-22,8, 3,8;-19,7, 6,9;-19,0, 3,7;-12,2) mostrano il muro uniforme, con le ombre morbide delle strutture;
  - niente triangoli più chiari e niente texture tirate;
  - **le toppe non si leggono.**
- **Gli scivoli:** test_scivoli (26 ok) e test_torre (95 ok) passano. Negli scatti della discesa non vedo ostacoli nuovi sugli scivoli.

## Note sullo strumento
- La macchina si è riavviata tre volte (02:10, 03:59 e verso le 06:30) mentre giravano scatti della torre col renderer: le prime due con la sala caricata, la terza con la sola torre, mentre la corsa era ferma. Le corse sono ripartite da dove si erano fermate, con una guardia della memoria (ferma Godot sopra 11,3-12,6 GB).
- Gli scatti magenta degli 11 checkpoint con la sala sono della prima corsa (RAGGIO 45, senza tunnel); tutti gli altri scatti della torre sono senza la sala.
- Gli strumenti sono in `godot/tests/collaudo/` (`soglia_giro.gd`, `soglia_scatti.gd`, `soglia_capi.gd`, `cubo_torre.gd`), le analisi qui accanto (`magenta_*.py`).
