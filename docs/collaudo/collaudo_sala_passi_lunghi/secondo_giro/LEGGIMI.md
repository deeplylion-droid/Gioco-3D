# Ricontrollo dei passi lunghi della sala, #147, secondo giro (ambienti-1, 9 novembre)

- Base: `lavoro/sala-passi-lunghi` `3effd587` di ambienti-2 (41377210 + 3effd587), confrontato con `4e9551c8`, il
  primo giro (`../LEGGIMI.md`).
- Cosa cambia:
  - `Posa.mesh_vicine` con la torre come radice: le mesh della torre contano anche quando la torre è nascosta;
  - `fissa_al_muro` prende anche lui le mesh vicine;
  - `SalaTorre._raggio_fisica`: a torre ferma guarda anche le forme di collisione della torre;
  - la lampada 5 sta 50 cm più su, a y −16,0;
  - le TriangleMesh delle mesh vicine si preparano prima, nel pool di thread (`_prepara_triangoli_luci`);
  - i segnali degli imbocchi si fanno un passo per imbocco.

## Esito: superato

| Punto | Esito |
|---|---|
| 1. Torre uguale dal portone e da F9, morte, Continua | **sì**: 1303 nodi e 174 istanze di MultiMesh, uguali |
| 1. Da F9, cambia solo quello che doveva | **sì**: solo la lampada 5 e la sua luce |
| 2. Le 7 lampade nelle due strade | **0 mm dal muro, niente dentro**, identiche |
| 3. Lampada 5 | a filo del muro, il tubo 9-21 cm sotto senza contatto, nessuna passerella sotto |
| 4. Tempi | lampade **3,6-10,1 ms**, passo più lungo della torre 10,5 ms; test_attesa_zone **5 su 5** |
| 5. Thread interrotto | titolo, uscita, morte subito dopo il portone: **0 errori, 0 «Lambda capture», nessun crash** |
| 6. Test | tutti verdi; posizionamento **0 da correggere**, rapporto uguale |

### 1. La torre dalle due strade (`godot/tests/collaudo/dump_torre_strade.gd`)

Lo script scrive la posizione nel mondo di ogni Node3D della sala della torre e di ogni istanza dei suoi MultiMesh, al
decimo di millimetro. I nomi automatici sono tolti e le righe si confrontano come multinsiemi.

- **Le strade sono quelle del gioco:**
  - portone: acquari comparsi, enigma risolto, la torre preparata nascosta e il portone che si apre;
  - F9 torre;
  - una morte;
  - una morte con la cache dei varchi vuotata;
  - Continua dalla torre.
- **F9, morte, morte con la cache vuota e Continua** hanno lo stesso md5: 1303 righe, 174 istanze.
- **Dal portone contro F9, su 3effd587:**
  - fuori dalle collisioni restano 3 oggetti ruotati delle luci, con 0,1 mm di arrotondamento su una rotazione;
  - resta il bersaglio dell'occhio di lei (`SalaInseguimento/Lei/BersaglioOcchio`), che si muove con lei;
  - le lampade e tutte le istanze dei MultiMesh sono uguali;
  - con 4e9551c8, sulla stessa strada, le righe diverse erano 22 nelle luci: lampade 0, 4 e 5, le loro luci, pali,
    bracci e led.
- **I corpi di collisione** hanno nomi diversi nelle due strade. Dal portone sono `StaticBody3D_1..10`, uno per forma;
  da F9 un solo `StaticBody3D` con le forme. Succedeva uguale con 4e9551c8: è la riaccensione a pezzi della torre
  (AccensioneAPezzi) e non riguarda Posa.
- **Da F9, 4e9551c8 contro 3effd587:** cambiano solo la lampada 5 e la sua luce, da y −16,5 a −16,0 e a filo del muro.
  Il resto di quello che era già giusto non cambia.
- **Dal portone, 4e9551c8 contro 3effd587:** cambiano le 22 righe delle luci. Ora sono quelle di F9: lampade 0 e 4 a
  x 20,32 e appoggiate, pali, bracci e led come da F9.

### 2. Le 7 lampade (fogli 1-4)

Lo strumento è `godot/tests/collaudo/scatti_lampade_emergenza.gd`, con la sala della torre e l'ambiente della sala
grande. La torre si costruisce a pezzi in due modi:
- visibile, come da F9, morte e Continua (fogli 1 e 2);
- nascosta e ferma, poi mostrata, come dal portone (fogli 3 e 4).

Per ogni lampada:
- uno scatto dagli occhi e tre a 45 cm, di taglio lungo il muro e da sopra;
- 25 raggi dal retro della scatola verso il muro.

Risultato:
- tutte e 7 a **0,0 mm** dal muro, nessun raggio col muro dentro la scatola;
- le misure e le posizioni sono **identiche** nei due modi;
- negli scatti nessun distacco: lo spigolo fra scatola e muro è netto da tutti i lati.

### 3. La lampada 5 (x 39,92, y −16,0, z −15,0, muro est)

- **A filo del muro:** 0 mm, 25 raggi su 25.
- **Il tubo** che corre lungo il muro sta sotto la scatola:
  - fra il fondo della scatola (y −16,15) e il tubo ci sono **215 mm** sotto la scatola;
  - la sonda dà 9-21 cm a 10-30 cm dal muro (`sonda_sotto_lampada5.gd`);
  - **nessun contatto e niente dentro**; sopra la scatola niente entro 60 cm.
- **Dagli occhi** (foglio 2, prima casella) la lampada sta sul muro appena sopra il tubo, tutta in vista, e illumina il
  tubo e il muro. Si legge come la lampada d'emergenza montata sopra la condotta.
- **Sotto non c'è passerella:**
  - a 0,1-0,3 m dal muro c'è il tubo;
  - a 0,4 m, 0,9 m più in basso (y −17,05), c'è il fianco della discesa 5, con la normale quasi orizzontale;
  - poi il fondo della vasca, a y −19,98, con l'acqua a −19,52, cioè 3,8 m sotto;
  - dove si cammina non c'è niente entro 2 m;
  - il controllo di posizionamento, che guarda gli ingombri lungo la strada e le discese, dà 0.

### 4. Tempi (`TORRE_TEMPI=1`, test_attesa_zone 5 volte di fila)

| Giro | Lampade, fissa_al_muro + 9 raggi (ms) | Passo più lungo della torre | Peggior fotogramma |
|---|---|---|---|
| 1 | 7,8 6,2 4,1 3,9 3,8 3,9 3,9 | 7,9 ms | 40 ms |
| 2 | 8,7 10,1 8,6 8,5 6,9 7,9 5,0 | 10,4 ms | 42 ms |
| 3 | 7,9 6,4 5,2 5,0 4,9 4,9 5,0 | 8,2 ms | 41 ms |
| 4 | 7,6 5,5 3,7 3,6 3,6 3,6 3,7 | 7,8 ms | 41 ms |
| 5 | 8,3 6,2 4,6 4,5 4,8 4,8 4,8 | 10,5 ms (_luci) | 47 ms |

- Prima le lampade costavano 16,5-19,6 ms; ora sono **tutte sotto i 16 ms** (al massimo 10,1).
- I triangoli delle luci sono 88 mesh e forme, pronti nei thread in 217-235 ms, su 25-28 fotogrammi; rimetterli in
  cache costa 0,2 ms.
- Tutti e 5 i giri sono verdi.

### 5. Il thread nuovo (`godot/tests/collaudo/thread_triangoli_torre.gd`)

Dalla strada del portone, appena la torre nascosta arriva ai triangoli delle luci (i passi delle luci pronti, il nodo
Luci non ancora):
- **titolo**: `Game.return_to_title()`, poi 5 s nel titolo. Arriva al titolo, esce con codice 0;
- **esci**: `Game.esci(0)` subito. Esce con codice 0;
- **morte**: si aspetta il portone che si apre e si muore appena si muove (`GameState.respawn()`). Riparte, esce con
  codice 0. Dalla prova si riparte dall'inizio della sala, perché il checkpoint della torre non è stato raggiunto.

Nei tre log: **0 «Lambda capture ... was freed», 0 SCRIPT ERROR, nessun crash**. Restano solo i soliti avvisi di
chiusura di Godot headless (ObjectDB e RID ancora in uso all'uscita), come in tutti i test.

### 6. Test

Tutti verdi, con 0 «Lambda capture» e 0 errori di script:

| Test | Controlli |
|---|---|
| test_lampade_torre_strade | 22 |
| test_posa | 14 |
| test_sala | 107 |
| test_torre | 95 |
| test_torre_pezzi_uguali | 10 |
| test_partenze_prova | 72 |
| test_portone_torre | 20 |
| test_ripartenza_oltre_portone | 53 |
| test_continua | 127 |
| ripartenze_lampade (del primo giro) | 18 |

Il controllo di posizionamento dà 0 da correggere, e il rapporto è uguale a main tranne la data. Non l'ho salvato.

## File

- `fogli/1_lampade_0-3_visibile_f9.jpg` e `fogli/2_lampade_4-6_visibile_f9.jpg`: la torre costruita visibile.
- `fogli/3_lampade_0-3_nascosta_portone.jpg` e `fogli/4_lampade_4-6_nascosta_portone.jpg`: la torre costruita nascosta.
- `log/`: le uscite.
  - `catena.out.txt` è il riassunto. Le due righe degli scatti lì dentro sono di un primo lancio con un errore nello
    script del collaudo, poi corretto: gli scatti buoni sono in `scatti.out.txt`.
  - `sotto5.txt`: cosa c'è sotto e davanti alla lampada 5.
- Script nuovi in `godot/tests/collaudo/`:
  - `dump_torre_strade.gd`;
  - `thread_triangoli_torre.gd`;
  - `sonda_sotto_lampada5.gd`;
  - `scatti_lampade_emergenza.gd`, ora con la torre costruita nascosta e le misure sopra e sotto la scatola.
