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
| Inseguimento (vasche, scolo, grata, SB1) | `SalaInseguimento._morbidezza_qui()`: tutta e subito quando lei sale, con l'acqua del posto | scatole prese dalla collisione vera intorno a ogni posto (`inseguimento_forme_lei.json`, sotto); nei pozzi (SB1, grata) e dove sale attraverso il pavimento allagato (scolo 3) con `trattieni` | `test_morbidezza_inseguimento.gd` |

Le misure comuni dei test (punti dentro le forme, tratti attraverso la collisione vera, scatti, tratti, costo) sono in `tests/misura_morbidezza.gd`.

**Lei che sbuca:** la salita sposta tutta la posa affacciata 2,3 m sotto e la porta su, quindi i tentacoli della posa che stanno sul pavimento salirebbero attraverso il pavimento (circa 8.000 punti dentro il mondo in 1,8 s, già senza morbidezza). Con `trattieni` acceso, i bersagli dei punti della posa che sono sotto il pavimento e fuori dalla fossa si spostano dentro la pianta della fossa (`fossa_pianta`, ristretta del raggio), in modo graduale negli ultimi 50 cm. Così i tentacoli salgono dentro la fossa e passano oltre il bordo mentre lei emerge. Alla fine della salita `trattieni` si spegne in 0,5 s e i tentacoli si stendono sul pavimento. Quando lei compare, la partenza fa tre giri come in un passo (lunghezze, tratti, punti fuori dalla parte dov'erano), così già il primo fotogramma è pulito anche con due punti trattenuti sullo stesso bordo. La griglia appoggiata al muro nord è un cuneo pieno fino dentro il muro, anche verso il muro ovest: una lastra di 5 cm di sbieco si passava, e dietro i tentacoli si infilavano. Il costo ha lo stesso limite del tuffo (3 ms in media e 8 nel 95%), perché la salita dura 2 s come il tuffo: misurati 2,6-2,8 e 4,3-4,5.

## La pelle vera (24 ottobre)

Il collaudo ha misurato la pelle deformata contro le mesh vere: i tentacoli tenevano fuori dal mondo l'asse, ma la pelle entrava fino a 7-13 cm. I tentacoli sono nastri piatti: mezza larghezza 5-10 cm (fino a 17), mezzo spessore 2-7 cm (fino a 13).

- **Sezione di ogni osso:** `assets/models/medusa/medusa_sezioni_tentacoli.json`, fatto da `tests/genera_sezioni_tentacoli.gd` dalla pelle di `medusa.glb` (da rifare se cambia la pelle). Per osso: un'ellisse nel piano X-Z dell'osso, [angolo, mezza larghezza, mezzo spessore], il massimo dei vertici.
- **Collisione:** ogni fotogramma l'ellisse si gira come l'osso. Contro ogni faccia vale la sua misura in quella direzione più 1 cm (`MARGINE`), e verso l'alto 1,5 cm in più (`SOPRA`): le strisce di bava (`BavaRosa`) stanno 1,2 cm sopra il pavimento e i tentacoli ci passano sopra. Così un nastro di piatto sta a filo del pavimento, uno di taglio sta fuori di tutta la larghezza.
- **Test della pelle vera** (`misura_morbidezza.gd`, `pelle()`): rifà la deformazione della scheda sulla CPU (ossa × bind × vertice, un vertice su tre, circa 6000 per fotogramma) e manda un raggio dall'asse dell'osso al vertice contro la collisione vera, con 1 cm di tolleranza. Conta anche i vertici sotto le strisce di bava (che non hanno collisione). Fuori dal conto: le collisioni che non si vedono (il coperchio della fossa, la parete est che chiude il condotto) e, a parte come la radice, il foro dove lei stessa passa col corpo attraverso il pavimento. È nei test di fossa e tuffo, di lei che sbuca e dell'inseguimento, bloccante.

**Inseguimento:** la sala è un trimesh unico e aperto (dentro e fuori non si sanno). `tests/genera_forme_inseguimento.gd` fa una volta le scatole intorno a ogni posto dove lei sale, guardando solo le facce con raggi: muri dritti (raggi orizzontali corti su una griglia di 10 cm, raggruppati per piano, 30 cm di spessore dietro la faccia) e pavimenti e cime (la prima faccia in su dall'alto, unite in lastre di 30 cm). I tubi tondi non ci sono. Le scatole sono in `assets/ambiente/inseguimento/inseguimento_forme_lei.json` (da rifare se cambia la struttura), da 30 a 170 per posto; con più di 24 forme la morbidezza le mette in una griglia di celle di 1 m. Nei pozzi (SB1 e la grata) lei sale da 5 m sotto e la posa allarga i tentacoli più del pozzo: con `trattieni` e `trattieni_y` al bordo, quello che sta sotto il bordo resta nella pianta del pozzo. Allo scolo 3 sale attraverso il pavimento allagato: lì il generatore lascia un foro di 75 cm nelle lastre e i tentacoli sotto il pavimento restano nel foro finché escono.

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

Il test controlla, con lei affacciata e nel tuffo, due volte (la seconda dopo il checkpoint), con 1 cm di tolleranza sull'asse e sulla pelle vera:

- nessun punto dentro pavimento, pareti, fondo, bordo o griglia;
- nessun tratto che attraversa la collisione vera;
- niente scatti;
- tratti vicini alla lunghezza di riposo;
- `quanto` 0 identico;
- il costo.

## Costo

Limiti alzati di circa il 50% il 24 ottobre, con la pelle vera (decisione del coordinatore). **Sono numeri della CPU del sandbox, lenta e condivisa, a 30 fps senza schermo: su un PC vero sono frazioni di ms.** In CI si stampano e basta.

| Fase | Media | 95% |
|---|---|---|
| Lei affacciata | 3,5 ms | 7 ms |
| Tuffo, lei che sbuca (2 s, una volta) | 4,5 ms | 12 ms |
| Inseguimento | 3 ms | 6 ms |
| Quando lei compare | 7,5 ms (un fotogramma) | |

Misurati: affacciata 3,0-3,3 ms, tuffo 3,8-4,3, lei che sbuca 4,1-4,7, inseguimento 2-3 ms, SB1 3,4 e la grata 5-7 ms (la più cara: 170 scatole e tanti contatti mentre colpisce la grata).

**Idea per dopo:** portare il cuore della simulazione (passi, forme, tratti) in C++ con una GDExtension, per 10-20 volte di meno. È un lavoro di un giorno, con la build da sistemare in CI.
