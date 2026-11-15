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
| `modo` | `INTERA` | `MANO` (mano e tentacoli, per le pozze) arriva dopo |
| `punti_uscita` | | i marker d'uscita |
| `pelo` | `NAN` | quota del pelo dell'acqua |
| `profondita` | `5` | spazio libero sotto i punti |
| `partenza_luce` | | da dove arriva la luce |
| `avviso` | `3,5` | in s: 2 arrivo + 1 spegnimento + 0,5 silenzio |
| `spegnimento` | `1` | in s: il canto sfuma |
| `silenzio` | `0,5` | in s: silenzio vero prima che esca |
| `portata` | `3` | in m |
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
- lei non è già in un altro specchio (una sola, condivisa da tutte le istanze: `AcquaDiLei.chi_la_usa()`);
- nessun'altra lei è in vista (ogni `MedusaAffacciata` visibile in scena: oblò, fossa, condotte, tunnel);
- nessun bambino è nell'inquadratura (gruppo `bambini` e `BambinoSfuggita`).

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

## Ancora da fare

- `modo = MANO` (mano e tentacoli dalle pozze, scelta C: di fianco, braccio e mano che sbatte sul grigliato, poi tre o quattro tentacoli lungo la passerella fino a 2 m; la presa la fa la mano, alla caviglia): in lavoro, sulle misure di Pozza_2_4.
