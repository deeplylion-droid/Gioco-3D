# L'acqua di lei (AcquaDiLei, build 0.4.0)

Il motore comune della regola «L'acqua è sua». Lei passa solo dove c'è acqua vera e, da quando si riaccendono le pompe, può prendere il giocatore. La regola è nel GDD, sezione «Analisi del capitolo 1 e direzione nuova (15 novembre)».

Script: `godot/scripts/creature/acqua_di_lei.gd` (`class_name AcquaDiLei`). Test: `godot/tests/test_acqua_di_lei.gd`, in CI.

## Come si attacca

Un nodo `AcquaDiLei` figlio della zona, con uno o più `Marker3D` come punti d'uscita:

```gdscript
var acqua := AcquaDiLei.new()
acqua.name = "AcquaDiLei"
acqua.pelo = 0.43                       # quota del pelo dell'acqua, nel mondo (NAN: quella del punto)
acqua.profondita = 2.5                  # spazio libero sotto i punti (m, al più 5)
var uscita := Marker3D.new()
uscita.name = "Uscita"
acqua.add_child(uscita)
uscita.position = Vector3(0, 0.43, 0)   # la posa «su» di lei: il suo nodo quando è fuori
acqua.punti_uscita = [uscita]
add_child(acqua)
acqua.chiama()                          # oppure acqua.automatica = true
```

Nella scena (.tscn) si mettono il nodo con lo script e i marker figli, poi si sceglie `punti_uscita` nell'ispettore.

**Il punto d'uscita** è dove sta il nodo di lei quando è fuori, cioè la posa «incombe» delle condotte. Si gira da sola verso il giocatore. Le animazioni salgono da 5 m sotto: con meno spazio si mette `profondita`, e la salita parte già a metà, nascosta sott'acqua. Il punto va solo in acqua vera (vasca, pozza profonda, canale): vetri e grate la fermano, quindi lì non si mette. Chi mette un punto controlla che lei, uscendo, incombendo e prendendo, non entri in muri, bordi e passerelle: **non attraversa niente**.

## Le fasi (`fase`, segnale `fase_cambiata`)

| Fase | Cosa succede |
|---|---|
| `LONTANA` | niente |
| `ARRIVA` | la luce rosa sott'acqua parte (da `partenza_luce`, o 8 m dietro l'uscita, o da dove sta se è già accesa) e arriva sotto il punto, 0,6 m sotto il pelo, in `avviso - spegnimento - silenzio` s (2 s) |
| `SPEGNE` | la luce è ferma lì e pulsa; **il canto sfuma** in `spegnimento` s (1 s): non si tronca mai di netto |
| `SILENZIO` | gli ultimi `silenzio` s (0,5 s) dell'avviso: **silenzio vero**, poi esce |
| `ESCE` | sale dall'acqua (`inseguimento/sale_dall_acqua`) |
| `SU` | incombe e ti segue con la testa. Se sei entro `portata` (in pianta) ti prende dopo `tempo_presa`; se no, dopo `tempo_su`, torna sotto |
| `PRESA` | `GameState.kill_player(&"medusa")`, la scena di morte di sempre |
| `SCENDE` | torna sotto (`respinta` o `scende`); la luce si spegne con lei |
| `CALMA` | `pausa_respinta` s dopo una respinta, `pausa_dopo` s se no; poi `LONTANA` |

**Respinta:** `getto_per_respingere` s di getto in faccia (di fila, a meno di 0,2 s fra un colpo e l'altro) mentre esce o incombe. Il viso è un WaterHitbox che segue l'occhio. Da codice c'è anche `respingi()`.

## Parametri esportati

| Parametro | Valore | Cosa fa |
|---|---|---|
| `abilitata` | `true` | spento, la zona è sicura |
| `modo` | `INTERA` | `MANO`: mano e tentacoli, per le pozze (sotto) |
| `punti_uscita` | | i marker d'uscita |
| `pelo` | `NAN` | quota del pelo dell'acqua |
| `profondita` | `5` | spazio libero sotto i punti |
| `partenza_luce` | | da dove arriva la luce |
| `avviso` | `3,5` | in s: 2 arrivo + 1 spegnimento + 0,5 silenzio |
| `spegnimento` | `1` | in s: il canto sfuma |
| `silenzio` | `0,5` | in s: silenzio vero prima che esca |
| `portata` | `3` | in m |
| `portata_mano` | `1,2` | nel modo MANO: in m dal marker |
| `tempo_su` | `2,2` | in s |
| `tempo_presa` | `0,35` | in s |
| `getto_per_respingere` | `0,5` | in s |
| `pausa_respinta` | `20` | in s |
| `pausa_dopo` | `4` | in s |
| `letale` | `true` | spento, non prende mai («solo paura»): esce, incombe e torna sotto |
| `prima_volta_dimostrativa` | `false` | la prima uscita, una volta per partita, è dal punto più lontano dal giocatore e non prende |
| `automatica` | `false` | viene da sola quando il giocatore è entro `distanza_richiamo` (10 m) da un punto, ogni `intervallo` s (14-26, a caso) |

## Le regole che il motore fa da solo

`puo_venire()` è vera solo se valgono tutte queste:
- le pompe sono riaccese (`GameState.luci == BLACKOUT`) e il giocatore non sta morendo;
- il giocatore è nella zona dello specchio (`giocatore_nella_zona()`): entro `zona_raggio` (25 m) in pianta da un punto d'uscita e a non più di `zona_dislivello` (3 m) dal pelo. Fuori dalla zona lei non viene e, se la luce gira o aspetta lì, se ne va subito (`lascia()`): nessuno specchio la tiene da lontano;
- lei non è da un'altra parte (`lei_altrove()`, vedi sotto);
- nessun bambino è nell'inquadratura (gruppo `bambini` e `BambinoSfuggita`).

**Dov'è lei adesso** (`lei_altrove()`, usata da `puo_venire()` e da `fase_canto`). Lei è da un'altra parte se vale una di queste:
- un altro specchio la usa (`AcquaDiLei.chi_la_usa()`);
- una scena la sta usando: la sua lei è nel gruppo `AcquaDiLei.LEI_IN_SCENA` (`lei_in_scena`). LeiSbuca ce la mette mentre la scena della fossa è in corso; condotte e tunnel ce la mettono mentre lei insegue;
- un'altra lei (MedusaAffacciata, gruppo `lei_affacciata`) è visibile e il giocatore la può vedere da dove sta: entro `vista_lontano` (40 m) e nell'inquadratura, oppure entro `vista_dietro` (12 m), perché girandosi la vedrebbe.

Perché così: il giocatore non ne vede mai due insieme, e una lei lontana, in un'altra zona o dietro i muri (la fossa lasciata visibile, un oblò pronto dietro il vetro) non ferma la regola dove si trova lui. Quando lei è da un'altra parte, o il giocatore è fuori dalla zona, `fase_canto` dà `ferma`: il canto lontano di quello specchio tace (lei non è in due posti).

**Lei e la luce condivise.** Lei, la luce e il viso sono uno solo per tutto il gioco, ma possono stare sotto specchi diversi. Si controllano uno per uno e si ricrea solo quello che manca. Uno specchio liberato si porta via quelli che ha sotto, senza lasciare riferimenti.

**La prima volta dimostrativa** si ricorda in `scripts/game/stato_lei.gd`, con la chiave `chiave_zona` (o, se vuota, il percorso del nodo). `GameState.reset_progress()` la azzera: con la partita nuova la prima uscita è di nuovo dimostrativa. Dall'esterno usa `prossima_dimostrativa()`.

**Riscaldamento:** `posa_per_il_riscaldamento(acceso, animazione = "")`. Si chiama intorno al disegno fuori vista della zona (`RiscaldamentoShader.disegna_fuori_vista`). Con `true` mette lei fuori dal primo punto d'uscita, con la luce di quando è fuori e l'animazione dell'uscita a metà; con `false` la rimette via. Così la prima uscita vera non compila shader.

`chiama()` restituisce falso se non può. Se un bambino entra in vista durante l'avviso, lei non esce e la luce se ne va.

## Segnali

`fase_cambiata(fase)`, `arriva(punto)`, `uscita`, `presa`, `respinta`, `tornata_sotto`, `percorso_finito`.

Altre domande: `prossima_dimostrativa()` (vero se la prossima uscita da qui sarà quella dimostrativa), `in_giro()`, `chi_la_usa()`.

## Per il canto (ambienti-1)

Ogni istanza sta nel gruppo `lei_nell_acqua` (`AcquaDiLei.GRUPPO`) e dà:
- `vicinanza`: 0 lontana, sale con la luce che arriva fino a 0,9, poi 1 nel silenzio e quando è fuori, poi scende mentre torna sotto;
- `punto_luce`: dove sta la luce rosa, nel mondo;
- `fase`: in `SPEGNE` il canto sfuma, nel `SILENZIO` tace; in `ESCE`, `SU` e `PRESA` restano i suoni di lei;
- `fase_canto` (StringName), già pronta per il canto: `ferma`, `lontana`, `arriva`, `spegne`, `silenzio`, `fuori`, `respinta`, `va_via`. «`LONTANA` + `in_giro()`» vuol dire che la luce passa.

## Lei e la luce

- **Lei:** è una `MedusaAffacciata` col modello, i materiali bagnati e le animazioni dell'inseguimento, come negli oblò e nelle condotte. È già nel riscaldamento (`RiscaldamentoShader`, i materiali `medusa_*`). Si crea nascosta alla prima istanza (`_ready`) e passa da un'istanza all'altra.
- **La luce:** è una sola. Sotto l'acqua è la LuceSottacqua di LeiSbuca (rosa, 2,6, portata 4,5, senza ombre); fuori le sta addosso come nelle condotte (6, portata 9, con le ombre).

## Il giro della luce (la sala al buio)

`gira(punti, velocita)` fa girare la luce rosa sott'acqua lungo dei punti, in ciclo, mentre lei è lontana. Lei è lì: in nessun altro posto. Con `punto_vicino_alla_luce(raggio)` la zona sa quando la luce passa sopra un punto d'uscita e la chiama da lì (`chiama(punto)` parte da dove sta la luce). `smetti_giro(verso, secondi)` manda la luce verso un punto, la spegne e libera lei.

Per una luce che va da un punto all'altro una volta sola, senza che lei esca: `percorri(punti, velocita, alla_fine = null, spegni = 1.5)`. Alla fine si spegne in `spegni` s (con `spegni = 0` resta accesa e ferma lì: poi `chiama()` o `manda_via(secondi)`) ed emette `percorso_finito`. Se `alla_fine` è un punto d'uscita, alla fine lei esce da lì. Per il canto, durante il giro `vicinanza` va da 0 a 0,8 secondo la distanza fra il giocatore e la luce.

La sala al buio usa tutto questo: `godot/scripts/game/lei_sala_al_buio.gd` (LeiSalaAlBuio, nodo `Gioco/LeiSalaAlBuio` della sala).
- La luce gira nella VascaArrivo e nelle vasche dei bimbi.
- Se il giocatore è entro 3 m da un punto d'uscita della VascaArrivo (uno a metà di ogni lato, `rientro` 2,4 m dentro: più vicino al bordo i tentacoli entrano nelle griglie e nel pavimento) quando la luce ci passa, lei esce.
- Quando lei arriva, i giocattoli che galleggiano nella vasca si scostano a `spazio_galleggianti` (3,6 m) dal punto (`prepara_uscita`), così uscendo non li attraversa.
- L'acqua della VascaArrivo è torbida e bassa (0,88 m): la salita parte sotto il fondo e non si vede. È un limite noto.
- Arrivato a 9 m dalla fossa (`distanza_fossa`), se non è sul bordo vicino a un punto d'uscita (lì lei può ancora uscire: il bordo nord della vasca è a 4,8 m dalla fossa), la luce va nella fossa in `tempo_alla_fossa` (1,5 s) e LeiSbuca fa la scena di oggi. `LeiSbuca.aspetta_il_giro` e `vai_alla_fossa()`: se la fossa è inquadrata sbuca, se no è già affacciata.

## Carica e scatto (tunnel)

Nella libreria dell'inseguimento ci sono anche:
- `inseguimento/carica` (2 s): parte dalla posa di `insegue_aperta` al tempo 0, si tira indietro di circa 0,6 m e si raccoglie, con la bocca spalancata e un tremito, e finisce ferma;
- `inseguimento/scatto` (0,8 s): parte dalla fine di `carica`, si allunga in avanti e finisce nella posa di `insegue_aperta` al tempo 0.

Lo spostamento in avanti lo fa il gioco. Mentre suonano, lei non è in `insegue_aperta` né in `insegue_morde`.

## Controllo d'ingombro

`godot/tests/sonda_ingombro_acqua_di_lei.gd <scena.tscn>`: per ogni AcquaDiLei della scena, ogni punto d'uscita e 8 direzioni, controlla le ossa di lei mentre esce, incombe, prende, è respinta e scende, contro le collisioni. Stampa cosa attraversa sopra il pelo, che è un difetto da correggere, e sotto il pelo, nell'acqua torbida. Gli oggetti mobili si contano a parte. Se il genitore dell'AcquaDiLei ha `prepara_uscita(punto, 0)`, la chiama prima. Con `Classe.proprieta=valore` si prova un valore prima di entrare nella scena (per esempio `LeiSalaAlBuio.rientro=2.4`).

## Il modo MANO (le pozze della Risalita)

Scelta C dell'utente: esce prima il braccio e la mano sbatte sul grigliato, poi dal bordo salgono quattro tentacoli che strisciano lungo la passerella; la presa la fa la mano, alla caviglia. Con `modo = MANO`:

- **Il marker** (`punti_uscita`): l'origine è dove sbatte la mano, sul grigliato a filo del bordo della pozza; il +Z del marker va verso la passerella (fuori dalla pozza). Lei prende il transform del marker e non si gira. Una pozza d'angolo ha un marker per lato: esce dal più vicino al giocatore. `pelo` è il pelo della pozza piena.
- **Le misure** (Pozza_2_4 di enigmi): pozza 1 m × 1 m, interno da z −1,10 a −0,10 del marker, acqua profonda 0,70 m; pelo a −0,0525; fondo chiuso da −0,75 a −0,95; bordino di 10 cm a filo del grigliato; grigliato pieno fino a −0,23; passerella larga 1,2 m. Pozze contigue a passo 1,1 m. Con un'altra geometria le animazioni vanno rifatte.
- **Le animazioni** (`inseguimento/pozza_*`, in `tools/blender/medusa_inseguimento.py`):
  - `pozza_esce` (2,2 s): sale da sotto il fondo col braccio alzato, la mano esce dall'acqua, si alza sopra il bordo e sbatte sul grigliato a 0,62 s (`MANO_SBATTE`); poi i tentacoli salgono dritti oltre il bordo e strisciano a scatti sulla passerella. Le punte arrivano a circa 1,9 m e 1,5 m dal marker, in diagonale, lontane dalla porta in fondo alla passerella;
  - `pozza_attesa` (ciclo, 2,4 s): la mano premuta sul grigliato, le dita che battono, le punte dei tentacoli che si muovono di pochi centimetri;
  - `pozza_presa` (0,8 s): la mano scatta alla caviglia del giocatore (0,6 m davanti al marker) e tira;
  - `pozza_respinta` (1 s) e `pozza_scende` (1,2 s): la mano rientra sopra il bordo e lei torna sotto il fondo, i tentacoli scivolano nella pozza.
- **Cosa si vede:** il corpo resta sott'acqua (la testa circa 28 cm sotto il pelo) e sotto il fondo. Braccio e tentacoli passano dal fondo della pozza. Il primo osso di ogni tentacolo che striscia si allunga sotto il fondo, dove non si vede: così il pezzo visibile ha la sua lunghezza vera e arriva fino a 2 m. Il controllo delle zone nello script Blender (`--pozza`) e la sonda d'ingombro non trovano niente che attraversa il grigliato, i bordini o le pozze vicine.
- **La presa:** se il giocatore è entro `portata_mano` (1,2 m in pianta) dal marker quando lei è su, la mano lo prende. Segue la scena di morte della medusa: la camera scende fino al pelo della pozza e guarda il suo viso sott'acqua.
- **La respinta:** il getto sulla mano (bersaglio di 0,4 m che segue la mano) per `getto_per_respingere` s la ricaccia sotto.
- **La luce rosa** resta nell'acqua della pozza (0,6 m sotto il pelo), più forte: la pozza si accende di rosa da sotto.
- **Suoni:** un tonfo nell'acqua quando la mano esce e quando sbatte, e uno quando rientra.

Test: `godot/tests/test_acqua_di_lei_mano.gd` (in CI). Per i marker veri: `sonda_ingombro_acqua_di_lei.gd <scena.tscn>` (nel modo MANO prova le animazioni `pozza_*` col marker).
