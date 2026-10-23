# Collaudo: interni della v0.3.8 a confronto con 8371883e

Richiesta del coordinatore del 23 ottobre: nelle build v0.3.9 e v0.3.10 l'utente ha trovato due difetti negli interni, cioè lo stanzino in cui non si entra e le ante degli armadietti aperti che non si vedono. Qui si confrontano gli interni del tag **v0.3.8** con `lavoro/godot` **8371883e**, per trovare tutto quello che è sparito, si è spostato o è cambiato. Squadra collaudo.

Le posizioni sono in metri nel mondo della sala. Gli interni stanno in (-9,7, 0, 40,9), e le coordinate degli strumenti sono quelle della scena degli interni aperta da sola.

## Come è stato fatto

Le stesse misure sono state fatte sui due commit, negli stati `inizio` e `aperto` (`tests/collaudo/stati.gd`), con la scena degli interni da sola e dentro `sala_principale.tscn`:

- **Impronta dei nodi** (`godot/tests/collaudo/confronto_interni.gd`). Per ogni nodo:
  - posizione, rotazione, scala e visibilità;
  - triangoli, box e materiali (colore, texture, cull, trasparenza), più la parte di facce dritte;
  - collisioni: forma, misure, facce e livello;
  - luci e decal.

  Le differenze sono in `nodi_aperto.txt`.
- **Celle dove passa la capsula del giocatore**, prese ogni 10 cm: raggio 0,35 m, dal gradino di 32 cm fino a 1,75 m, gradini fino a 32 cm, maschera mondo + oggetti + barriere. Le celle si dividono poi in zone collegate, e per ogni checkpoint si vede in che zona sta.
- **Sonda della capsula** (`sonda_capsula.gd`): che cosa tocca la capsula nei punti persi, nei vani e sui punti di ripartenza. I risultati sono in `sonde_vecchio.txt` e `sonde_nuovo.txt`.
- **Geometria vera** (`geometria.gd`): i punti delle superfici a voxel di 2 cm, cercando quello che c'è solo in uno dei due commit. Il risultato è in `geometria_aperto.txt`.
- **Giro dagli occhi**: la stessa lista del collaudo degli interni del 22 ottobre (120 scatti fissi e 79 vedute ravvicinate), più 11 vedute dei vani e 27 vedute fisse delle ante, sui due commit. Gli scatti sono stati confrontati pixel per pixel. I fogli sono in `fogli/`: a sinistra la v0.3.8, a destra 8371883e.

## Difetti

| # | Che cosa | Dove | Da quando | Foglio |
|---|---|---|---|---|
| 1 | **Nello stanzino non si entra.** `Stanzino/stanzino_collisione` comprende la porta aperta (il bordo ovest va da x 1,30 a 0,51, le facce da 192 a 240). La capsula al centro del vano tocca la collisione a z 32,3. Partendo dal risveglio, lo stanzino e il suo checkpoint sono una zona a parte. Sulla v0.3.8 erano collegati. Siccome la porta è sempre aperta, succede dall'inizio della partita, e lo zaino sta nello stanzino. | vano x 0,5…1,4, z 31,96…32,94 | correzioni del 22 ottobre (e2a7d7d2, 085321be) | `varie1.jpg` (la porta si vede uguale) |
| 2 | **Ripartenza del Lavapiedi dentro una collisione.** La capsula su `CheckpointLavapiedi/Ripartenza` tocca la collisione nuova del `cartello_bagnato`, a (0,19, 0,62, 29,2), 19 cm dal centro. Sulla v0.3.8 era libera. | (0,0, 0, 29,2) | collisioni nuove degli oggetti | `varie2.jpg`, in basso |
| 3 | **La porta della sala pompe aperta finisce dentro il muro.** `angolo_apertura` è passato da -95 a -172 (280b23f). Il cardine (8,28, 0, 41,0) sta a metà del muro, che va da z 40,9 a 41,1. Girata di 172 gradi, la porta resta dentro il muro (AABB x 8,27…9,24, z 40,79…41,07) con l'estremo libero che sporge di circa 10 cm nel corridoio. Si vede negli stati aperto e ritorno, dopo la tappa 7. Per stare contro il muro senza entrarci, il cardine va sulla faccia del muro dalla parte verso cui la porta si apre. | x 8,3…9,2, z 40,8…41,1 | dopo la v0.3.8 | (posizioni misurate nella sala) |
| 4 | **Le ante degli armadietti aperti non hanno il pannello.** Le 9 ante usano `hq_armadietto_sportello` (4543 triangoli), che ha 0,23 m² di superficie: griglie, cerniera e maniglia. Il pannello (0,42 × 1,53 m, almeno 0,64 m² per faccia) manca, il cull è spento. A schermo si vedono solo le griglie, sospese. Causa probabile: `sportello_da_chiuso()` in `tools/blender/ambienti1_hq.py` taglia solo il 7% anteriore del modello chiuso, e il pannello sta più indietro. **C'era già sulla v0.3.8**: la mesh è identica nei gltf dal 17 ottobre (a94b49d). Le correzioni del 22 ottobre hanno solo spostato le ante di 1-7 cm verso il vano. | spogliatoi, ovest x -6,2…-5,9; est x 0,5…0,8 | dal 17 ottobre | `fis1.jpg`, `fis2.jpg`, `ante1.jpg` |

Correzione al collaudo degli interni del 22 ottobre (difetto 6): gli scatti di allora mostrano già le griglie senza pannello. Le avevo segnate solo come ante staccate dal corpo.

## Cambiati: da confermare che siano voluti

- `Stanzino/cassetta_pronto_soccorso`: rimpicciolita al 70% (box da 0,52 × 0,60 × 0,34 a 0,36 × 0,42 × 0,24 m) e spostata di 15 cm (`giro1.jpg`, al centro).
- Collisioni nuove degli oggetti, messe nelle trimesh degli ambienti (corridoio da 1092 a 1152 facce, spogliatoi da 1452 a 1608):
  - asciugamani, secchio del mocio, cartelli, sedia, cestini, palloni ed estintori;
  - ante aperte e cassetta del pronto soccorso.

  Fra i due commit si perdono 12 m² dove si cammina (da 12.199 a 10.931 celle). Non chiudono passaggi oltre allo stanzino: risveglio, spogliatoi, lavapiedi e tornello restano collegati.

## Uguali, o correzioni giuste

- Nel giro dagli occhi non manca nessun oggetto.
- Le differenze di luce negli scatti vengono dal tremolio dei neon: due giri della stessa v0.3.8 danno energie diverse, e le luci hanno posizione ed energia uguali.
- Turbina della saracinesca e valvole del corridoio: scelte dell'utente.
- Correzioni del collaudo:
  - luci d'emergenza a contatto del muro e fuori dai tubi, con la `luce_emergenza_01` passata al muro di fronte (`varie1.jpg`);
  - cavo del neon;
  - fischietti, braccioli, salvagente e zaino;
  - corrimano della scala della sala pompe;
  - `asciugamano_corridoio`, spostato verso il muro.
- Dalla mesh dello stanzino sono state tolte le facce che stavano dentro il muro degli spogliatoi: il muro (28 cm, con le due facce) resta uguale.
- Graybox della saracinesca e lampadine delle luci d'emergenza nascoste: tolti, non si vedevano.
- Dentro la sala gli interni danno le stesse differenze che da soli, più la porta del difetto 3.

## Strumenti

Sono in `godot/tests/collaudo/` (`confronto_interni.gd`, `sonda_capsula.gd`, `sonda_ante.gd`) e in `tools/collaudo/confronto_*.py`. Gli script Python leggono le cartelle `ci/vecchio` e `ci/nuovo` sotto la cartella che ricevono come primo argomento.
