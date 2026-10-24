# Collaudo della v0.3.12: torre degli scivoli e inseguimento

Squadra enigmi (collaudo, non ha costruito la zona), 24 ottobre notte. Base finale: `lavoro/cancelletti` **b8964240** (da `lavoro/godot` e0960137, con le ringhiere B di `lavoro/texture-calme` 7e37aaa9), unita in `lavoro/collaudo-enigmi`, import fresco. Scena `scenes/sala/torre/sala_torre.tscn` (torre e sala dell'inseguimento), stati `inizio` (portone chiuso, prima della discesa) e `aperto` (dopo la discesa: grata calata, paratie aperte). Posizioni in metri nel mondo della torre caricata da sola; i nomi `@MeshInstance3D@…` sono quelli di questa scena (nella sala grande cambiano).

## Come è stato fatto

- **Distanze vere** (`tools/collaudo/distanze.py`): 472 oggetti in tutti e due gli stati. Cinque non arrivano all'architettura, ma sono ciambelle, paperelle, un pallone e un salvagente che galleggiano sull'acqua (come nei collaudi di prima).
- **Spazio per la testa** (`testa.py`): 0 casi, in tutti e due gli stati.
- **Attacchi degli scivoli** (nuovo, `tools/collaudo/attacchi_scivoli.py`): dove i 21 scivoli e tubi toccano o sfiorano la struttura (entro 5 cm), campionati ogni 5 mm: 137 posti, ognuno con due ravvicinati; per i 14 dove resta più di 1 cm, anche uno stretto a 40 cm (`attacchi_stretti/`, `attacchi_non_a_contatto.jpg`). La compenetrazione la giudica il passo f) del controllo della CI e gli scatti: la stima "dentro" dello strumento non è affidabile sulla struttura intagliata.
- **Giro dagli occhi**: 55 punti lungo scale, passerelle, imbocchi, vasche d'arrivo e vasche dell'inseguimento, 4 scatti per punto (`fogli/torre_giro_*.jpg`).
- **Cancelletti delle bocche chiuse e lampade rosse**: ravvicinati di ogni pezzo su tre commit (`cancelli/`, `cancelli_15099922/`, `cancelli_b8964240/`).
- **Vedute ravvicinate**: 237, su fari, lampade, lampade d'emergenza, led degli imbocchi, cartelli e oggetti piccoli, dai punti dove si cammina con la vista libera verificata (`fogli/torre_vedute_*.jpg`).
- **Giro nello stato aperto** (dopo la discesa: grata calata, paratie aperte): 64 scatti nella sala dell'inseguimento (`fogli/torre_giro_aperto_*.jpg`).
- **Controllo di posizionamento della CI**, zona torre (stato iniziale e `inseguimento_dopo`): **0 casi nuovi, 0 da correggere**; a) sospesi 0, d) compenetrazioni 0, e) capi liberi 0, **f) scivoli dentro pedane, travi o sostegni 0**; restano i 6 ingombri all'altezza della testa nei tubi dell'inseguimento, già "voluto" (`controllo_posizionamento_torre.log`).

## Difetti trovati e corretti stanotte (verificati sul commit finale)

| # | Cosa | Visto su | Stato su b8964240 |
|---|---|---|---|
| 1 | Gli 8 cancelletti delle bocche chiuse: le sbarre finivano 5 cm sopra la grata e il corrimano 14 cm prima dei pali (pannello sospeso) | 7e37aaa9 | corretto: corrente in basso sulla grata, sbarre dal corrente, corrente e corrimano nei pali, pali dalla grata (`cancelli_c1_c3_c5_c7_ok.jpg`, `cancelli_corretti_ok.jpg`) |
| 2 | c3, c5, c7: corrente e piede delle sbarre dentro il labbro della testata del canale (in c7 si vedeva) | 15099922 | corretto: 9-11 cm dal canale; gli altri cancelletti 1,6-6 cm |
| 3 | Lampada d'emergenza `@82` a 8,3 mm dal tubo che le fa da muro | 7e37aaa9, 15099922 | corretta: poggia sul tubo (3,7 mm agli spigoli della scatola, che tocca il tubo tondo lungo la linea di mezzo); le altre 6 a 0-0,1 mm (`lampade_emergenza.jpg`) |

Le 8 lampade rosse delle bocche chiuse (`@306`…`@324`) stanno sulla targa a strisce in cima ai cancelletti e toccano (gli 8 "staccati" di ambienti-1 su 1f140d67 erano un import vecchio).

## Da vedere (su b8964240)

Su 45db14db i punti 1, 2 e 4 sono corretti (sezione "Ricontrollo" qui sotto). Il 3 non è un palo ma l'inizio degli scivoli aperti (sezione "Secondo ricontrollo").

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | `TorreScivoli/torre_scivolo_7` con `TorreStruttura/torre_A_sostegni` | 37,36, 6,46, -12,52 | Dove un'asta dei sostegni arriva al tubo rosso, nella superficie del tubo c'è un buco nero con dentro il moncone grigio dell'asta. Il tubo è uno di quelli chiusi dalla grata (non ci si entra) e il punto più vicino da cui lo si guarda è a 9 m. | `attacchi_stretti/a125_torre_scivolo_7_a.jpg`, `_b.jpg` |
| 2 | `TorreScivoli/torre_tubo_inseguimento` sopra `TorreStruttura/torre_A` | 39,58, -19,32, -17,4 e 38,67, -19,34, -17,4 | Il tubo dell'inseguimento passa 1,3-2,1 cm sopra la trave grigia, con la fessura scura in vista; il giocatore passa a 1,4 m. Va bene se la trave non lo regge lì, altrimenti va appoggiato. | `attacchi_stretti/a133_…`, `a134_…` |
| 3 | Ancora aperto dal collaudo di prima: i pali rossi coi led verdi degli imbocchi (`Luci/LedImbocco`, `Luci/@MultiMeshInstance3D@276`…`@300`) | per esempio `LedImbocco_1`, `_10`, `_11`, `@300_9`…`11`, `@288_0`…`2` | Sotto la fila di led il palo si stringe a punta e finisce 25-30 cm sopra la grata, accanto al palo rosso che invece arriva alla grata. Si vede dove il giocatore entra negli scivoli. Va bene se è voluto, altrimenti va portato fino alla grata. | `fogli/torre_vedute_04.jpg`, `_06.jpg`, `_09.jpg` |
| 4 | Noto dal collaudo di prima: il tubo lungo inclinato nella vasca dell'inseguimento | vicino a 43,5, -33,4, -3,5 | C'è ancora (scatti `ti052_e`, `ti052_s`): sta nell'acqua lungo il fondo. | `fogli/torre_giro_09.jpg` |

## Secondo ricontrollo (`lavoro/torre-attacchi` a31f5cbe)

Unita in `lavoro/collaudo-enigmi` (d1e7c25f), import fresco. Scatti in `ricontrollo_a31f5cbe/`. Rispetto a 45db14db cambia solo `torre_A_sostegni`: 19 pezzi nuovi e 13 tolti (gli 11 collari dei tubi chiusi ora sono pezzi interi, più selle, puntoni e i due braccetti); `torre_A`, grate e inseguimento sono identici (`pezzi_cambiati.log`).

| # | Su a31f5cbe | Scatti |
|---|---|---|
| N1 puntone del tubo 7 | arriva al tubo: nei quattro ravvicinati a 30 cm non c'è fessura (la misura dà 4-10 mm, nel campionamento) | `n1_puntone_tubo7_4_viste.jpg`, `n1_puntone_tubo7.jpg` |
| Braccetto di `discesa_5_0` | arriva allo scivolo a 4 mm | `braccetto_discesa_5_0.jpg` |
| N2 e N3 collari degli scivoli 5 e 9 | fasce intere, senza denti né buchi | `n2_n3_collari_scivoli_5_9.jpg` |
| Giro degli 11 collari dei tubi chiusi | fasce intere, a 2,4-5,1 mm dal tubo; 10 su 11 toccano la loro staffa | `giro_collari_tubi_chiusi.jpg` |
| **N4 (nuovo)** collare dello scivolo 2 a 25,26, 4,56, -13,6 | **non tocca niente**: sta a 4 mm dal tubo e **4,3 cm sopra la mensola rossa** che dovrebbe reggerlo, e da sotto si vede lo spazio | `n4_collare_scivolo2_dal_basso.jpg`, `n4_collare_scivolo2_staccato.jpg` |

Controllo di posizionamento della CI, zona torre: 0 nuovi, 0 da correggere, f) 0. Testa 0, celle uguali.

**I "pali a punta" dei led degli imbocchi (punto 3 da vedere) non sono pali.** Sono l'inizio degli scivoli aperti `TorreScivoli/discesa_0_0`, `discesa_2_0` e `discesa_5_0`: visto dall'alto, il fondo arrotondato della vasca dello scivolo sembra un palo colorato (rosso, blu e viola come lo scivolo) che finisce a punta accanto al palo rosso coi led. Il punto più basso vicino al palo sta sopra la grata di:

- `discesa_0_0`: 12,6 cm, a 27,90, 0,12, -21,21;
- `discesa_2_0`: 12,4 cm, a 34,10, -5,89, -8,79;
- `discesa_5_0`: 19,7 cm, a 37,06, -14,81, -17,82.

Scatti: `led_*.jpg` (vedute di prima, per esempio `@282_10` dalla camera 34,5, -4,41, -10,0, yaw 114,3, pitch -61) e `inizio_scivoli_aperti.jpg`. Non è il cono della luce verde. Va deciso se l'inizio dello scivolo può stare sollevato sopra la grata o se va appoggiato.

## Ricontrollo sulle correzioni di ambienti-2 (`lavoro/torre-attacchi` 45db14db)

Unita in `lavoro/collaudo-enigmi` (86be2b80), import fresco, stati `inizio` e `aperto`. Scatti e misure in `ricontrollo_45db14db/`.

**I tre punti sono corretti:**

| Punto | Su 45db14db | Scatti |
|---|---|---|
| Buco nel tubo 7 col moncone dell'asta (37,36, 6,46, -12,52) | sparito: superficie liscia, l'attacco non c'è più | `tubo7_punto_corretto.jpg` (`buco_*`) |
| Tubo dell'inseguimento 1,3-2,1 cm sopra la trave | le culle salgono sui fianchi: distanza 0,3 cm | `culle_tubo_inseguimento.jpg` |
| Tubo inclinato nella vasca dell'inseguimento | tolto (era una delle 12 staffe del tubo di servizio a x 44, lunghe 5,6 m attraverso il bacino) | `vasca_inseguimento.jpg` |

**Cosa è cambiato davvero** (pezzi connessi delle mesh confrontati con la base di prima, `pezzi_nuovi.log`):

- `torre_A`: le due culle (2 pezzi).
- `torre_A_sostegni`: **42 pezzi nuovi e 35 tolti, non solo al tubo 7**. Togliere il tirante ha fatto rigenerare anche i sostegni degli scivoli 2, 5, 9 e 12 (collari, mensole rosse, tiranti e un palo, fra x 24 e 36).
- `ins_A_struttura`: le staffe dei 5 tubi di servizio del muro sud (x 44, 51, 58, 65, 72) ora vanno al muro accanto (40 cm) invece che verso i muri della torre (prima a x 44 attraversavano il bacino, e dagli altri tubi correvano lungo il muro fino a x 40). Le catene e i cavi appesi si sono spostati di poco, perché la sequenza casuale è cambiata.
- **Tutti i pezzi nuovi toccano qualcosa**, al massimo a 1 mm (misura esatta sui triangoli). Le staffe dei tubi di servizio arrivano al muro a 0,1-0,4 mm (`staffe_muro_sud.jpg`).
- Controllo di posizionamento della CI, zona torre: 0 nuovi, 0 da correggere; a) 0, a2) 0, d) 0, e) 0, f) 0 (`controllo_posizionamento_torre.log`).
- Spazio per la testa: 0 casi. Celle raggiungibili 1190 in `inizio` e 1187 in `aperto`: una in più per stato, dove c'era la staffa nel bacino.

**Difetti nuovi, nati dalla rigenerazione** (da correggere prima che il collaudo passi):

| # | Dove | Problema | Scatti |
|---|---|---|---|
| N1 | Tubo 7, puntone dalla colonna (x 40) a 38,03, 5,10, -15,0 | Il puntone orizzontale col suo cappuccio finisce **a 2,2 cm dal tubo rosso**, senza collare. Prima arrivava al collare tolto insieme al tirante. Si vede la fessura scura. | `difetto_tubo7_asta_da_sotto.jpg`, `_da_sopra.jpg`, `difetto_tubo7_asta_4_viste.jpg` |
| N2 | Scivolo 5, collare nuovo a 29,2, 5,8, -20,6 | Il collare sta sull'anello di giunzione del tubo: la fascia ha il bordo **seghettato a denti, con buchi neri** fra i denti. | `difetto_collare_scivolo5.jpg`, `_vicino.jpg`, `collari_nuovi.jpg` (cn150) |
| N3 | Scivolo 9, collare nuovo a 32,8, -0,2, -9,4 | Stesso difetto, sulla giunzione fra il tratto bianco e il rosso: un buco nero triangolare nella fascia e il bordo staccato. | `difetto_collare_scivolo9.jpg`, `collari_nuovi.jpg` (cn184) |

Gli altri collari nuovi (per esempio quello dello scivolo 2, cn139) e quelli rimasti come prima (cv127) hanno la fascia liscia (`collari_vecchi.jpg`). Dagli occhi del giocatore i tre difetti stanno 4-7 m sopra le pedane e si notano poco (`difetti_dagli_occhi.jpg`), ma sono del tipo che le regole contano come difetti.

## Collisioni nuove degli arredi dell'inseguimento (su `lavoro/godot` ba041c61)

Base unita in `lavoro/collaudo-enigmi` (3bce3987), import fresco, stati `inizio` e `aperto`. Gli arredi copiati dalla sala pompe in `SalaInseguimento/Luci` sono 34 gruppi, con 41 corpi: le tre pompe e la turbina hanno i pezzi convessi copiati dal glTF (corpo, aspirazione, mandata, disco), scrivania e sedia i loro `_col`, gli altri 25 la scatola nuova sull'ingombro della mesh.

- **Celle dove si cammina** (passo 50 cm, con la fisica): 1189 in `inizio` e 1186 in `aperto`, **le stesse di b8964240, nessuna persa**.
- **Le scatole non escono dalla mesh**: ognuna coincide con l'ingombro del suo arredo (0 cm in più); i pezzi convessi stanno dentro quello delle pompe.
- **Distanza dalla cella raggiungibile più vicina** (in pianta, con il pavimento fino a 2,2 m sotto): il più vicino è il festone di cavi `det_cavo_festone_3` a 0,9 m, una scatola di 2 cm stesa sul muro; poi `FILTRO_1` a 2,1 m (sul bacino), il cartello della profondità a 3,9 m, `POMPA_3` a 5,6 m, `POMPA_1` e `POMPA_2` a 12 m; gli altri da 5 a 27 m, o su pavimenti dove il giocatore non arriva (griglia caduta, corda, catena, lamiera a terra, turbina).
- Due doppioni senza effetto per chi cammina: `POMPA_3` ha sia i pezzi convessi sia una scatola su `POMPA_3_modello` (sta nell'ingombro della pompa); il disco di `TURBINA_1` è copiato due volte.
- **Controllo di posizionamento della CI**, zona torre su questa base: 0 nuovi, 0 da correggere, f) 0.
- L'elenco dei corpi, con la forma e l'ingombro nel mondo: `collisioni_arredi_inseguimento.log`.

**Niente sporge dove si cammina.**

## Visti e a posto

- Il giro dagli occhi lungo tutta la strada non mostra altri oggetti sospesi o compenetrati.
- Gli scivoli poggiano sulle pedane e sulle grate (ravvicinati degli attacchi); dove restano a 1,6-4 cm dalla struttura è davanti alle testate, coi pali rossi dei cancelletti, che non devono toccarli.
- Le 8 bocche chiuse stanno su pedane dove il giocatore non arriva: le vede da altre pedane, coi pali rossi, la targa a strisce e la lampada rossa.
