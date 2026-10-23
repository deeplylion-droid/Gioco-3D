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
| Lei che sbuca (fossa) | `LeiSbuca`: accesa anche mentre sale, con `trattieni` (tentacoli tenuti nella fossa finché lei non è su) | come sopra, più `fossa_pianta` | `test_morbidezza_sbuca.gd` |
| Inseguimento (vasche, scolo, grata, SB1) | `SalaInseguimento._morbidezza_qui()`: tutta e subito quando lei sale, con l'acqua del posto | nessuna forma: la sala è una mesh sola e le animazioni tengono già i tentacoli fuori; il test controlla coi raggi sulla collisione vera | `test_morbidezza_inseguimento.gd` |

Le misure comuni dei test (punti dentro le forme, tratti attraverso la collisione vera, scatti, tratti, costo) sono in `tests/misura_morbidezza.gd`.

**Lei che sbuca:** la salita sposta tutta la posa affacciata 2,3 m sotto e la porta su, quindi i tentacoli della posa che stanno sul pavimento salirebbero attraverso il pavimento (circa 8.000 punti dentro il mondo in 1,8 s, già senza morbidezza). Con `trattieni` acceso, i bersagli dei punti della posa che sono sotto il pavimento e fuori dalla fossa si spostano dentro la pianta della fossa (`fossa_pianta`, ristretta del raggio), in modo graduale negli ultimi 50 cm. Così i tentacoli salgono dentro la fossa e passano oltre il bordo mentre lei emerge. Alla fine della salita `trattieni` si spegne in 0,5 s e i tentacoli si stendono sul pavimento. Quando lei compare, la partenza fa tre giri come in un passo (lunghezze, tratti, punti fuori dalla parte dov'erano), così già il primo fotogramma è pulito anche con due punti trattenuti sullo stesso bordo. La griglia appoggiata al muro nord è un cuneo pieno fino dentro il muro, anche verso il muro ovest: una lastra di 5 cm di sbieco si passava, e dietro i tentacoli si infilavano. Il costo ha lo stesso limite del tuffo (3 ms in media e 8 nel 95%), perché la salita dura 2 s come il tuffo: misurati 2,6-2,8 e 4,3-4,5.

## Collisioni

Non usa i raggi. Usa forme convesse (piani verso fuori) e una lastra di pavimento col buco della fossa, date da `LeiSbuca._forme_morbidezza()`:

- le collisioni della fossa e della VascaBimbi1, senza il coperchio;
- la griglia divelta: non ha collisione, la scatola è presa dalle misure in `tools/blender/ambiente_sala.py`;
- la parete est col buco del condotto e il condotto come canale quadrato.

Il risolutore, a ogni passo:

1. **Molla e catena.** La molla tira verso la posa, e la catena tiene le lunghezze di riposo delle ossa.
2. **Giri dove tocca il mondo** (fino a due):
   - lunghezze, con i due capi che si vengono incontro;
   - tratti fuori dalle forme, tagliati contro la forma allargata del raggio; anche con tutti e due i capi a meno del raggio, se il mezzo è più dentro di tutti e due (la punta fra la cima del bordo e la fossa taglierebbe lo spigolo);
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
