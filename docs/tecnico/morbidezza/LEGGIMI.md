# Tentacoli morbidi di lei (MorbidezzaLei)

`godot/scripts/environment/morbidezza_lei.gd` è un `SkeletonModifier3D` che sta in fondo allo scheletro della medusa. Sopra la posa che arriva (animazione, tentacoli contro i muri, tuffo) aggiunge il movimento secondario: i tentacoli molli con l'onda, la campana che pulsa e le collisioni col mondo.

## Come si accende

- `LeiSbuca` lo accende tutto e subito quando lei compare (sbuca o è già affacciata). Fa mezzo secondo di assestamento prima del primo fotogramma visibile, così i tentacoli poggiano già sul bordo.
- Il tuffo continua la stessa simulazione. Ripartendo (checkpoint) riparte dalla posa.
- `quanto` a 0 lascia la posa identica, senza nessuno spostamento.

## Le scene di lei

| Scena | Dove si accende | Collisioni | Test |
|---|---|---|---|
| Statua (menu e sala) | `MedusaStatue` la mette su ogni medusa, a `quanto` 0 (la proprietà `morbidezza`): ferma davvero, costo zero | — | `test_morbidezza_statua.gd` |
| Affacciata e tuffo (fossa) | `LeiSbuca`: tutta e subito quando compare già affacciata | forme convesse della fossa (sotto) | `test_morbidezza.gd` |
| Lei che sbuca (fossa) | `LeiSbuca`: spenta mentre sale, piano (0,4 s) quando è su | come sopra | `test_morbidezza_sbuca.gd` |
| Inseguimento (vasche, scolo, grata, SB1) | `SalaInseguimento._morbidezza_qui()`: tutta e subito quando lei sale, con l'acqua del posto | nessuna forma: la sala è una mesh sola e le animazioni tengono già i tentacoli fuori; il test controlla coi raggi sulla collisione vera | `test_morbidezza_inseguimento.gd` |

Le misure comuni dei test (punti dentro le forme, tratti attraverso la collisione vera, scatti, tratti, costo) sono in `tests/misura_morbidezza.gd`.

**Lei che sbuca:** la salita sposta tutta la posa affacciata 2,3 m sotto e la porta su. I tentacoli che nella posa stanno sul pavimento salgono quindi attraverso il pavimento: circa 8.000 punti e 1.250 tratti dentro il mondo in 1,8 s, già senza morbidezza. Per questo la morbidezza lì si accende solo quando lei è su. Per toglierli serve cambiare la salita.

## Collisioni

Non usa i raggi. Usa forme convesse (piani verso fuori) e una lastra di pavimento col buco della fossa, date da `LeiSbuca._forme_morbidezza()`:

- le collisioni della fossa e della VascaBimbi1, senza il coperchio;
- la griglia divelta: non ha collisione, la scatola è presa dalle misure in `tools/blender/ambiente_sala.py`;
- la parete est col buco del condotto e il condotto come canale quadrato.

Il risolutore, a ogni passo:

1. **Molla e catena.** La molla tira verso la posa, e la catena tiene le lunghezze di riposo delle ossa.
2. **Giri dove tocca il mondo** (fino a due):
   - lunghezze, con i due capi che si vengono incontro;
   - tratti fuori dalle forme, tagliati contro la forma allargata del raggio;
   - punti fuori, dalla faccia da cui sono entrati.
3. **Bersagli della molla.** Sono anche loro fuori dal mondo. Dove la posa passa sotto il bordo, salgono sopra il bordo.

## Test

```
godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://tests/test_morbidezza.gd
```

Il test controlla, con lei affacciata e nel tuffo, due volte (la seconda dopo il checkpoint), con 1 cm di tolleranza sull'asse:

- nessun punto dentro pavimento, pareti, fondo, bordo o griglia;
- nessun tratto che attraversa la collisione vera;
- niente scatti;
- tratti vicini alla lunghezza di riposo;
- `quanto` 0 identico;
- il costo.

## Costo

Limiti decisi dal coordinatore il 23 ottobre:

| Fase | Media | Massimo |
|---|---|---|
| Lei affacciata | 2 ms | 4 ms |
| Tuffo (2 s, una volta) | 3 ms | 8 ms |

Misurati a 30 fps senza schermo: affacciata circa 1,7-1,8 ms, tuffo circa 2,6 ms di media, con picchi di 6-8 ms nello strappo iniziale.

**Idea per dopo:** portare il cuore della simulazione (passi, forme, tratti) in C++ con una GDExtension, per 10-20 volte di meno. È un lavoro di un giorno, con la build da sistemare in CI.
