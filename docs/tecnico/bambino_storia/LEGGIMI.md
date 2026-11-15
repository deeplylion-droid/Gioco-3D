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
| `porge` | 1,2 s | alza le braccia e tiene il foglio davanti al petto |
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

**Nel gioco (enigmi):** lo mette `EnigmaAcquari._bambino_col_cubo` (`godot/scripts/game/enigma_acquari.gd`, nodo `Gioco/EnigmaAcquari/BambinoAcquari`) con `BambinoSfuggita` in modalità `guarda_il_disegno`:
- a 1,2 m dal vetro, sotto il disegno, girato verso il vetro;
- compare una volta sola, quando gli acquari ci sono e funzionano (lei andata via, tappa 8 finita) e non sono risolti; mai sotto gli occhi del giocatore, mai con lei fuori dall'acqua (`aspetta_lei`); se nessuno lo vede resta lì (`tempo_max` 0);
- la fuga la decide Bambino; scappa nel varco fra il cilindro e il muro est fino all'angolo dietro il cilindro e sparisce fuori vista;
- il pastello che gli cade lo appoggia BambinoSfuggita (`pastello_a_terra`, con Posa, lontano dalla Polaroid 14) e resta coi checkpoint.
Test: `godot/tests/test_bambino_acquari.gd` (in CI).

### Porge

`modalita = PORGE` con `percorso` (di solito un punto, 0,7-0,8 m davanti: due passi), oppure `porge(punti)`.
- Cammina fin lì, poi porge il foglio con le due mani (segnale `porge_il_foglio`) e lo tiene.
- Non scappa.
- Senza punti lo porge subito.

**Dove attaccare il foglio:** `punto_foglio()` restituisce un nodo (`Foglio`) che segue le mani. Il disegno va messo
come suo figlio, con il centro nell'origine:
- la faccia del disegno guarda dove guarda il bambino (+Z del nodo);
- il lato lungo è in su (+Y);
- la scala è 1.

È pensato per un A4 (21 x 29,7 cm) tenuto per i lati della metà alta. Fuori da `porge` e `porge_tiene` il punto sta
davanti al petto, quindi il disegno si mostra solo quando arriva `porge_il_foglio`.

La matita è nascosta in tutte le modalità tranne DISEGNA, e resta in mano mentre scappa.

## Test

`godot/tests/test_bambino_storia.gd` (nella CI) controlla:
- le animazioni, la matita e l'osso del foglio nei due modelli;
- che disegna e, se non lo guardi, continua a disegnare;
- che alza la testa quando lo guardi e ti guarda;
- che dopo 1,6 s scappa;
- che fa i passi e porge il foglio, e che il punto del foglio sta fra le mani, davanti al petto e dritto.
