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
| `ARRIVA` | la luce rosa sott'acqua parte (da `partenza_luce`, o 8 m dietro l'uscita) e arriva sotto il punto, 0,6 m sotto il pelo, in `avviso - silenzio` s |
| `SILENZIO` | gli ultimi `silenzio` s dell'avviso: la luce è ferma lì e pulsa, e **il canto tace** |
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
| `modo` | `INTERA` | `MANO` (mano e tentacoli, per le pozze) arriva nella prossima tappa |
| `punti_uscita` | | i marker d'uscita |
| `pelo` | `NAN` | quota del pelo dell'acqua |
| `profondita` | `5` | spazio libero sotto i punti |
| `partenza_luce` | | da dove arriva la luce |
| `avviso` | `3` | in s |
| `silenzio` | `1` | in s |
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

`fase_cambiata(fase)`, `arriva(punto)`, `uscita`, `presa`, `respinta`, `tornata_sotto`.

## Per il canto (ambienti-1)

Ogni istanza sta nel gruppo `lei_nell_acqua` (`AcquaDiLei.GRUPPO`) e dà:
- `vicinanza`: 0 lontana, sale con la luce che arriva fino a 0,9, poi 1 nel silenzio e quando è fuori, poi scende mentre torna sotto;
- `punto_luce`: dove sta la luce rosa, nel mondo;
- `fase`: nel `SILENZIO` il canto tace; in `ESCE`, `SU` e `PRESA` restano i suoni di lei.

## Lei e la luce

- **Lei:** è una `MedusaAffacciata` col modello, i materiali bagnati e le animazioni dell'inseguimento, come negli oblò e nelle condotte. È già nel riscaldamento (`RiscaldamentoShader`, i materiali `medusa_*`). Si crea nascosta alla prima istanza (`_ready`) e passa da un'istanza all'altra.
- **La luce:** è una sola. Sotto l'acqua è la LuceSottacqua di LeiSbuca (rosa, 2,6, portata 4,5, senza ombre); fuori le sta addosso come nelle condotte (6, portata 9, con le ombre).

## Ancora da fare

- `modo = MANO`, cioè mano e tentacoli dagli specchi stretti (per le pozze);
- `carica` e `scatto` per il tunnel;
- la sala al buio;
- un controllo d'ingombro per ogni punto d'uscita (lei che non entra nei bordi).
