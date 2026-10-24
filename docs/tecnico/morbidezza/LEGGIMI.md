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
| Tunnel sottomarino (dopo SB1) | `LeiTunnel` di mascotte (la crea nel suo `_ready`, `riemergi` la accende); le forme: `FormeTunnel.prepara_a_pezzi(sala)` mentre il tunnel si costruisce, poi `FormeTunnel.aggiungi(lei_tunnel.morbidezza, sala)` | prismi dai triangoli della collisione del tunnel vicini allo spazio di lei (`forme_tunnel.gd`, sotto), gommoni come forme che si muovono | `test_morbidezza_tunnel.gd` |
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

Limiti del 24 ottobre, con la pelle vera: circa il doppio di quelli di prima (decisione del coordinatore). **Sono numeri della CPU del sandbox, lenta e condivisa, a 30 fps senza schermo, e cambiano anche del 30% secondo quanto è carica: non sono il costo nel gioco vero, dove sono frazioni di ms.** In CI si stampano e basta.

| Fase | Media | 95% |
|---|---|---|
| Lei affacciata | 4 ms | 8 ms |
| Tuffo, lei che sbuca (2 s, una volta) | 6 ms | 16 ms |
| Inseguimento | 4 ms | 8 ms |
| Quando lei compare | 10 ms (un fotogramma) | |

Misurati (con la macchina scarica e carica): affacciata 3,0-4,4 ms, tuffo 3,8-6,2, lei che sbuca 4,1-6,3, inseguimento 2-3 ms, SB1 3,2-3,4. La grata è la più cara: 5-7 ms (95% fino a 14), con circa 170 scatole e tanti contatti mentre lei colpisce la grata; lì anche il limite nuovo può non bastare.

## Casi noti

Come i "voluto" del controllo di posizionamento: in `test_morbidezza_inseguimento.gd`, `NOTI` (posto, quanti tratti dell'asse ammessi, motivo, data). Si stampano a ogni giro. Valgono solo per il controllo dell'asse: la pelle vera resta bloccante dappertutto. Oggi è vuoto: vasca_2 (24 ottobre, la punta della posa in un muro sottile) è stato tolto quando le forme dalle mesh vere e la partenza sul tratto l'hanno sistemato.

## Inseguimento, 24 ottobre (collaudo con le mesh vere)

- **Le mesh vere, non solo le collisioni.** Le pompe dell'inseguimento non avevano collisione (ambienti-2 l'ha aggiunta). Il generatore delle forme (`genera_forme_inseguimento.gd`) e il test della pelle guardano anche le mesh vere: `tests/corpi_dalle_mesh.gd` fa corpi temporanei trimesh dalle mesh visibili (tranne l'acqua e lei) su uno strato che il gioco non usa.
- **Oggetti tondi** (pompe, tubi): i loro triangoli si ritagliano in celle di 75 cm, e ogni cella diventa un poliedro di 26 facce spinte fino al vertice più fuori, coi piani già fatti nel JSON (`convessi`; la morbidezza li aggiunge con `aggiungi_piani()`, senza calcoli quando lei compare).
- **Pavimenti sotto altre cose:** fino a 3 facce in su per colonna (il pavimento sotto una staffa o un tubo).
- **Partenza sul tratto** (`partenza_sul_tratto`, acceso solo nell'inseguimento): quando lei compare, un punto della posa dentro il mondo si ferma sul tratto dal punto prima, all'ultimo posto fuori, invece di uscire dalla faccia più vicina (che sotto una grata o in un muro sottile è quella sbagliata).
- **Prove di vasca_2 col giocatore nella vasca 3** (dove sta nel gioco: lei si gira verso di lui): `bash godot/tests/prova_vasca2_giocatore.sh` (di mascotte, con `GIOCATORE=x,y,z` nel test). I 5 punti nella vasca 3 danno 0; il punto del test, da solo (`SOLO=vasca_2`), ha un fotogramma con 2 vertici fino a 4 cm sotto una sporgenza di 10 cm; nel giro completo (come in CI) 0.
- `SOLO=posto1,posto2` lancia solo quei posti.

## Tunnel sottomarino, 24 ottobre

- **Lo spazio di lei** (JSON della strada di ambienti-2, `lei`): sull'asse del canale, fino a 3,6 m dall'asse, fra 1,2 e 6,2 m sopra l'acqua, e lì non c'è niente. Le forme si prendono solo vicino a quello spazio (0,6 m in più), più giù nella presa (lei sale da lì) e dal fondo in su negli ultimi 14 m (lo schianto sul portello).
- **Le forme** (`scripts/environment/forme_tunnel.gd`, `FormeTunnel`): ogni triangolo della collisione vicino allo spazio di lei diventa un prisma convesso spesso 30 cm verso il pieno (1 m sotto i pavimenti: la rampa della presa); le forme convesse degli ostacoli intere. Circa 460 forme, che si preparano una volta per sala, a pezzi (`prepara_a_pezzi`, 4 ms per fotogramma, circa 1 s in tutto) mentre il tunnel si costruisce; `aggiungi` le dà alla morbidezza in 30-60 ms.
- **Forme che si muovono** (`aggiungi_mobile`, `aggiungi_scatola_mobile`, `togli_mobili`): legate a un nodo, rifatte dal nodo a ogni fotogramma, fuori dalla griglia; vicino a una di loro il tentacolo si simula a ogni fotogramma e i bersagli si rifanno sempre. I gommoni del tunnel sono prismi di 12 lati attorno al cilindro della loro collisione. Test: `test_morbidezza_mobili.gd`.
- **La presa:** il fondo è una rampa da -36 (s = 0) a -30,92 (s = 6). Lei deve salire a s = 0: partendo a s = 3 i tentacoli di `sale_dall_acqua` (5 m sotto) nascono dentro la rampa.
- **Il test** (`test_morbidezza_tunnel.gd`), coi pezzi veri: la logica della sala (`SalaSottomarino`) e `LeiTunnel` di mascotte, con un bersaglio finto al posto del giocatore. La riemersione dalla presa (s = -1), la strada intera di corsa (5,8 m/s) con un getto in faccia ogni 120 m (ritrae), le tre curve a U a guado (2 m/s: morsi e presa), lo schianto sul portello. Il 24 ottobre tutto pulito tranne lo schianto (caso noto, sotto); costo medio 1,9-2,4 ms e 3,5 nel 95% (CPU del sandbox): **il C++ per ora non serve**. `SOLO=presa,strada,curve,schianto`.
- **Gommoni:** una scatola sola per gommone (tutta la sua collisione, nel sistema del corpo che dondola). Le forme che si muovono contano solo vicino a lei (8 m): con 434 forme di spicchi per tutto il tunnel la presa costava 6,6 ms, così 1,9.
- **Caso noto, schianto** (24 ottobre): il corpo di lei passa nel ballatoio davanti al portello (il piano a -27,0, profondo 1 m; lei a 0,95 m dal portello con l'origine a -30,32): le radici dei tentacoli sono dentro (la morbidezza non le può spostare). Da decidere fra ambienti-2 e mascotte; nel test la pelle e il costo dello schianto si stampano soltanto finché non è corretto.
- **Attenzione:** la medusa nasce statua, con `quanto` a 0. Chi la fa muovere lo deve alzare a 1.

## Da fare dopo la v0.3.12

- **Radici del tuffo nel condotto** (collaudo, 24 ottobre): alla fine del tuffo, quando lei entra nel condotto, la pelle del primo tratto di 3 tentacoli (_01) entra fino a 7,4 cm nella fossa. La radice segue il corpo, che entra lui stesso nel condotto: la morbidezza non la può spostare senza staccare il tentacolo. Si vede appena (lei è in acqua e scappa veloce). Va corretto nell'animazione del tuffo (il corpo più al centro del condotto), che è approvata dall'utente: si fa dopo la v0.3.12, con lui.

**Dopo la v0.3.12:** portare il cuore della simulazione in C++, vedi `CPP.md`.
