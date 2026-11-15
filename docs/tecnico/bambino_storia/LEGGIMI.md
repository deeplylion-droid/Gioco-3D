# Il bambino col cubo che disegna e porge il foglio (build 0.5.0)

Le animazioni nuove sono nei due modelli del bambino col cubo (`bambino_cubo_calmo.glb`, `bambino_cubo_rivelato.glb`).
Le fa `tools/blender/bambini_animazioni.py <nome> <uscita> --vivo --storia --foglio-altezza <m>`, che esegue
`tools/blender/bambini_storia.py`. Con `--controlla` misura le pose sulla pelle vera senza esportare:
- niente sotto il pavimento;
- la punta della matita sempre sul foglio;
- il cubo lontano dalle mani e dal foglio.

| Animazione | Durata | Cosa fa |
|---|---|---|
| `disegna` | 6 s, ciclo | in ginocchio, chino sul foglio: la destra disegna con la matita, la sinistra tiene fermo il foglio |
| `alza_testa` | 1 s | si raddrizza un po' e alza la testa; la matita si stacca |
| `si_alza` | 0,6 s | si tira su; finisce nella posa da cui parte `parte` (poi la corsa) |
| `tiene_foglio` | 8 s, ciclo | in piedi, tiene il foglio basso davanti alle cosce con due mani (la stessa presa di `porge_tiene`) e lo guarda |
| `porge` | 1,2 s | dal foglio basso (`tiene_foglio`) lo alza e lo allunga fino alla posa davanti al petto, alzando la testa |
| `porge_tiene` | 4 s, ciclo | lo tiene lì: respiro, un piccolo tremito |
| `guarda_su` | 6 s, ciclo | in piedi davanti al vetro, la testa in su verso il disegno, il pastello in mano a mezz'aria (agli acquari) |

## Nel gioco (Bambino, `godot/scripts/creature/bambino.gd`)

La scena è la solita `scenes/creature/bambino_cubo.tscn`. Conviene mettere `fermo_vivo = true` e
`partenza_continua = true`, come il bambino del corridoio del fiume.

### Disegna

`modalita = DISEGNA` (o `disegna()`): il bambino è in ginocchio a disegnare, con la matita in mano.
- Quando il giocatore lo guarda (come la statua: `tempo_per_vederlo`, `distanza_vista`, `angolo_vista`) o arriva
  entro `distanza_alza_testa` (6 m), alza la testa verso di lui (segnale `alza_la_testa`).
- Resta così `tempo_testa_alzata` (1 s): la testa segue il giocatore.
- Poi si tira su e scappa lungo `punti_fuga`, come le altre fughe (segnali `scappa`, `sparito`).
- `alza_testa_ora()` lo fa partire subito.

Il foglio su cui disegna lo mette chi fa la scena. Il suo centro va a 0,27 m davanti all'origine del bambino (+Z), al
centro, all'altezza scritta in `bambino_cubo_calmo_storia.json` (`foglio_disegna`). Adesso è 15 cm: un appoggio basso. La
misura vera degli acquari la dà enigmi; se cambia, si rifà il GLB con `--foglio-altezza`.

### Agli acquari: guarda il disegno

`guarda_il_disegno = true` e `modalita = DISEGNA` (scelta A del coordinatore: il disegno sul vetro del cilindro giallo è a
2,45-3,35 m, il bambino non ci arriva). È in piedi e guarda in su il disegno col pastello in mano. Quando lo vedi o arrivi a
6 m gira la testa verso di te, aspetta `tempo_testa_alzata` (1 s) e scappa. Scappando il pastello gli cade: sparisce dalla
mano e parte `lascia_il_pastello(dove)`, col punto del pavimento sotto la mano, dove chi fa la scena mette il pastello
appoggiato. Va messo a circa 1,2 m dal vetro, girato verso il vetro.

Il pastello in mano è quello di ambienti-1 (`godot/assets/storia_disegni/pastello.glb`, opzione `--pastello`), chiamato
`pastello` nel GLB. Prende il posto della matita anche in ginocchio.

### Porge (il finale, scelta R del coordinatore)

`modalita = PORGE` **senza** `percorso` (o `porge([])`):
- da subito tiene il foglio basso con due mani e lo guarda (`tiene_foglio`), ed emette `tiene_il_foglio`: il foglio
  si mostra da qui, attaccato a `punto_foglio()`;
- quando la scena chiama `porgi()` lo alza e lo porge (`porge`, sfumato in 0,35 s; segnale `porge_il_foglio`), poi lo
  tiene (`porge_tiene`);
- non scappa.

Il vecchio modo con i passi resta (sotto), ma nel finale non si usa: il foglio comparirebbe dal nulla.

### Porge con i passi

`modalita = PORGE` con `percorso` (di solito un punto, 0,7-0,8 m davanti: due passi), oppure `porge(punti)`.
- Cammina fin lì, poi porge il foglio con le due mani (segnale `porge_il_foglio`) e lo tiene.
- Non scappa.
- Senza punti lo porge subito.

**Dove attaccare il foglio:** `punto_foglio()` restituisce un nodo (`Foglio`) che segue le mani. Il disegno va messo
come suo figlio, con il centro nell'origine:
- la faccia del disegno guarda dove guarda il bambino (+Z del nodo);
- il lato lungo è in su (+Y);
- la scala è 1.

È pensato per un A4 (21 x 29,7 cm) tenuto per i lati della metà alta. In `tiene_foglio`, `porge` e `porge_tiene` sta
fra le mani; nelle altre animazioni sta davanti al petto, quindi il disegno si mostra solo da `tiene_il_foglio` (o da
`porge_il_foglio`, col vecchio modo dei passi).

Controlli in Blender (`--controlla`), su ogni fotogramma di `tiene_foglio`, `porge` e `porge_tiene` e nella sfumatura
`tiene_foglio` → `porge` (0,35 s, da 8 punti del ciclo, come la fa Godot):
- la punta della mano più vicina sta dietro il foglio a non più di 5 mm;
- nessuna punta passa il foglio;
- cosce, pancia e braccia stanno dietro il foglio.

Il foglio basso sta 0,17 m avanti, uguale per i due modelli: il rivelato, col vestito aperto, sporge di più.

La matita è nascosta in tutte le modalità tranne DISEGNA, e resta in mano mentre scappa.

## Test

`godot/tests/test_bambino_storia.gd` (nella CI) controlla:
- le animazioni, la matita e l'osso del foglio nei due modelli;
- che disegna e, se non lo guardi, continua a disegnare;
- che alza la testa quando lo guardi e ti guarda;
- che dopo 1,6 s scappa;
- che fa i passi e porge il foglio, e che il punto del foglio sta fra le mani, davanti al petto e dritto;
- il finale senza passi: il foglio basso fra le mani da subito (`tiene_il_foglio`), nessun porge finché non si chiama
  `porgi()`, poi porge senza salti del foglio e lo tiene davanti al petto.
