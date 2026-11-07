# Collaudo finale 0.3.21, parte di enigmi (6-7 novembre)

- Candidata collaudata: `lavoro/candidata-0321` `080ec07e`. Confronti con la 0.3.20 (`main` `ca6a3c19`).
- Le correzioni degli stendardi e dei varchi-cielo non ci sono ancora: toccano solo stendardi e torre, fuori da questa
  parte.
- Ogni processo Godot è passato dal `render.lock`.
- Ho fatto la sala per parti: la Risalita della scena di prova (`tests/scene/risalita_prova.tscn`), più il fiume della
  sua scena di prova per le pile, con le luci del blackout. Le sonde dei tempi girano senza schermo, con le partenze del
  menu di prova.
- Gli strumenti usati sono in `godot/tests/collaudo/` (elenco in fondo).
- Il collaudo del fondo nero dietro la porta di servizio del bacino, sulla candidata finale `c6187286`, è in
  `fondo_porta/LEGGIMI.md`.

## Esito: passa, con D1 corretto da grafica e ricontrollato (sezione 5)

**D1. Scala di servizio: la lampada rossa del pianerottolo in basso non è stata alzata.**
- È in `risalita_gioco.gd:431`, `_lampada_rossa(Vector3(xs + 0.6, Y + 2.2, z0 + 0.05), ...)`, davanti alla porta
  stagna, sul muro nord del pianerottolo dove si cammina. Sporge circa 50 cm dal muro.
- Il suo fondo è a **1,98 m** dal pavimento (raggio verso il basso sulle collisioni).
- Il GDD (riga 649) dice "lampade rosse della scala di servizio alzate di 5 cm, fondo a 2,03 m (A)". `5967d8a9` ha
  alzato solo le due in cima (righe 429-430, y 2,25).
- Correzione proposta: anche questa a `Y + 2.25`.
- **Corretto** da grafica su `lavoro/lampade-2m` `9aecffa8` (correzione `aa10bd3f`, base `dc83169e`), e ricontrollato
  qui: passa (sezione 5).
- L'attacco è giusto: piastra sul muro (0,0 mm), staffa a 1 mm dalla piastra (foglio 1b).

Fuori dalla scala di servizio, alla stessa altezza `Y + 2.2` (fondo a 1,98 m) c'erano
- la lampada del corridoio del personale (`risalita_gioco.gd:361`), misurata;
- le tre della scala del fiume (righe 480-482), dal codice, perché sono lo stesso modello alla stessa altezza.

Grafica le ha alzate tutte nella stessa correzione.

### 1. Scala di servizio: lampade rosse (fogli 1a e 1b)

Strumento `collaudo_lampade_scala.gd`. Trova i modelli della LampadaMuro entro 18 m dalla cima della scala. Per
ognuno misura:
- lo spazio sotto fino al pavimento o al gradino, con un raggio in giù dal fondo della lampada, al centro e fino a
  50 cm davanti;
- il distacco dal muro, con un raggio dal centro verso il muro, confrontato con la faccia di dietro della piastra e il
  punto della staffa più verso il muro.

| Lampada | Fondo sopra dove si cammina | Piastra-muro | Staffa-piastra |
|---|---|---|---|
| Cima, muro nord del tratto verso sud | 2,030 m | 0,0 mm | 1,0 mm |
| Cima, fondo del tratto verso C3 | 2,030 m | 0,0 mm | 1,0 mm |
| Pianerottolo in basso | **1,980 m (D1)** | 0,0 mm | 1,0 mm |

- Il millimetro fra staffa e piastra è voluto: LampadaMuro la appoggia 1 mm davanti.
- Ravvicinati, con una luce di servizio sulla camera (`SCATTI_LUCE=1`): davanti, di lato, radente all'attacco, da sotto,
  e dagli occhi a 1 m e passando sotto. La piastra è sul muro e la staffa sulla piastra, senza fessure.
- La lampada dell'infermeria (vicina, ma fuori dalla scala) col raggio risultava staccata di 31 cm dal muro.
  Probabilmente lì la collisione del muro è più indietro della faccia che si vede: negli scatti la piastra è contro il
  muro.

### 2. Angolo degli scatoloni all'ingresso del capannone (fogli 2a-2e)

Strumento `collaudo_angolo.gd`, con le pile prese dal FILE (come nel gioco).

- **Appoggiata e stabile.**
  - 37 istanze nell'angolo, da x -29,70 a -28,70, da z -28,598 a -27,39, alte 5,40 m.
  - I bancali sono a terra.
  - Nessuna istanza specchiata.
  - La pila sta a 2 mm dal muro nord a ogni altezza.
  - Ravvicinati della base e del contatto col muro nord, dall'est e dalla nicchia a 0,4, 1,4 e 2,4 m: niente fessure.
  - Il controllo automatico "una sopra l'altra" segna 8 scatole "14,7 cm sopra": sono appoggiate sul bancale dell'unità
    sopra, che fa parte della scatola dell'unità. Negli scatti appoggiano.
- **Senza buchi dalla soglia e dai primi 2 m.** Raggi sulle collisioni dagli occhi verso 48 punti della nicchia (3
  altezze, 4x4 posizioni):

| Da dove | Punti visibili su 48 |
|---|---|
| Soglia | 0 |
| 40 cm dentro | 0 |
| 1 m dentro | 0 |
| Accovacciato a 1 m | 0 |
| 2 m dentro | 9 |
| 2 m dentro, 80 cm a ovest | 9 |

  I punti visibili da 2 m sono solo la bocca della nicchia (z -27,4), non il fondo dove sparisce il bambino.
- **Il bambino sparisce dietro la pila, guardato due volte.**
  - Video dagli occhi `fermati` e `vicino` (strumento `video_bambino_cubo.gd`, fogli 2c e 2d): sparisce sempre fuori
    vista.
  - Due inseguimenti dalla porta alla pila (strumento `bambino_pila.gd`, foglio 2e):
    - `soglia`: corri dietro di lui e ti fermi sulla soglia guardando la pila;
    - `dentro_2m`: entri di 2 m e guardi la bocca della nicchia.
  - Ogni 5 fotogrammi registro dov'è, se il giocatore lo vede (`Bambino.visibile_da`, lo stesso controllo del gioco) e,
    quando sparisce, dov'era.
  - In tutti e due i casi il bambino entra nella nicchia fra la pila e il muro dell'approdo e sparisce in fondo, in
    (-29,99, -28,22) del fiume, fuori vista, dopo 0,4 s che non lo si vede.
    - `soglia`: il giocatore lo vede correre lungo il passaggio a sud della pila fino a 3,8 s. A 4,0 s gira nella
      nicchia e non lo vede più. Sparisce a 4,8 s.
    - `dentro_2m`: lo vede fino alla bocca della nicchia (z -27,67, 4,2 s) e lo perde a 4,3 s, mentre va in fondo.
      Sparisce a 4,8 s.
  - La regia, una camera in fondo al passaggio che guarda giù nella nicchia, mostra il bambino che entra, arriva in
    fondo e sparisce.

### 3. Pile del fiume dal file (PILE_FILE) contro la 0.3.20 (foglio 3)

- **Istanze nella scena, confrontate una per una.** Le ho prese dai MultiMesh del fiume, col renderer vero, in
  coordinate del fiume. Strumenti `pile_scena_vulkan.gd` e `confronta_pile.py`.
  - Ognuna delle 3664 istanze della 0.3.20 ha nella candidata un'istanza identica: posizione e rotazione entro 0,1 mm,
    stessa tinta.
  - 0 mancanti, 0 spostate, 0 specchiate.
  - Le 37 in più sono tutte nella pila nuova dell'angolo.

| Gruppo | 0.3.20 | Candidata | Nuove nell'angolo |
|---|---|---|---|
| PileCasse | 104 | 105 | 1 |
| PileCartone | 222 | 224 | 2 |
| PileCartoneAperte | 45 | 46 | 1 |
| PileScatole | 2466 | 2488 | 22 |
| PileScatoleColorate | 783 | 794 | 11 |
| PileCasseSciolte | 44 | 44 | 0 |

- **Il file contro il generatore** (copia di `tools/salva_pile_fiume.gd` che non riscrive il file). Le pile costruite
  col generatore della candidata e quelle lette dal file sono uguali riga per riga, 7114 righe:
  - trasformazioni e tinte;
  - le 118 collisioni;
  - le 3 lampade.
- **Dagli stessi punti.** I 46 scatti della strada del giocatore, dall'ingresso del capannone all'imbarco
  (`scatti_pile_fiume.gd`, a 960x540), sono identici pixel per pixel fra 0.3.20 e candidata. Le uniche differenze (sotto
  lo 0,05% dei pixel, scatti 12-14) sono i riflessi dell'acqua che si muove.
- **Attenzione allo strumento.** `tools/salva_pile_fiume.gd` in modalità "scena" va lanciato col renderer vero
  (`xvfb-run ... --rendering-driver vulkan`). Senza schermo il server di rendering finto non tiene le trasformazioni dei
  MultiMesh: scrive 3701 identità, e il confronto sembra buono anche se non lo è.

### 4. Ripartenze, scena breve, Continua, arrivi dal menu

Sonda `tests/sonda_tempi_ripartenza.gd` senza schermo, 2 morti di fila, sequenza di morte chiusa subito. "Giocatore"
vuol dire quando ricompare il giocatore; "tutto" quando sono finiti anche thread e lavori della sala.

| Checkpoint | Candidata: giocatore | Candidata: tutto | 0.3.20: giocatore | 0.3.20: tutto |
|---|---|---|---|---|
| Risalita | 2,3-2,4 s | 2,7 s | 5,3 s | 5,7 s |
| Fiume | 2,3 s | 2,8 s | 4,7-5,5 s | 5,1-5,8 s |
| Torre | 1,8-2,0 s | 4,2-4,6 s | 2,4-4,6 s | 5,2-7,3 s |
| Condotte | 1,6 s (4,5 alla prima) | 4,6 s (7,5 alla prima) | 1,9 s (4,4 alla prima) | 4,1 s (6,5 alla prima) |

- Nelle condotte e nella torre la prima morte cade subito dopo l'arrivo, con caricamenti ancora in corso. Succede lo
  stesso nella 0.3.20.
- **Quando tornano i comandi** (stessa sonda, con l'ora in cui il giocatore può muoversi, `input_enabled`):
  - torre 1,8 s;
  - condotte 1,5 s;
  - fiume 2,4-2,5 s.

  Alla prima morte subito dopo l'arrivo: torre 4,4 s e condotte 3,8 s, perché c'erano caricamenti in corso. Il
  giocatore si muove al massimo 0,1 s dopo che è ricomparso; il resto, nella torre e nelle condotte, è caricamento di
  sfondo mentre si gioca.
- **Dalla seconda morte nello stesso punto la scena della presa dura 1 s.** `tests/test_morte_breve.gd`: 9 controlli
  su 9.
  - La prima morte ha la scena intera, 5,0 s.
  - Dalla seconda la scena breve dura 1,10 s e finisce sul nero, senza la scritta per saltarla.
  - Con un checkpoint nuovo e con una partita nuova torna la scena intera.
- **Continua giusto.** `tests/test_continua.gd`: 127 controlli su 127. Ripartenza dall'ultimo checkpoint scritto in
  risalita, fiume, torre, condotte, tunnel e interni, con luci, zaino e Polaroid.
- **Arrivi dal menu** (sonda `sonda_arrivo.gd`, ogni partenza due volte di fila: "freddo" = cache dei file del sistema
  svuotata subito prima). Il tempo è quello in cui il giocatore può muoversi. In tutti i lanci, in quel momento thread
  e lavori sono già finiti, e dopo non c'è nessun fotogramma sopra 100 ms.

| Partenza | Candidata | 0.3.20 |
|---|---|---|
| Fiume | 7,3 s a freddo, 7,1 a caldo | 9,6 s a freddo, 8,7 a caldo |
| Torre | 6,7 s a freddo, 5,8 a caldo | 7,1 s a freddo, 6,3 a caldo |
| Risalita | 6,8 e 6,8 s | 9,5 e 8,9 s |
| Condotte | 6,2 e 6,2 s | 5,9 e 5,8 s |

  I 119 s (fiume) e 46 s (torre) della prima misura erano i primi lanci a 10 minuti da un riavvio della macchina.
  Svuotare la cache non li riproduce, quindi con ogni probabilità era il disco del sandbox che si riscaldava dopo il
  riavvio, non il gioco.

### 5. Ricontrollo delle lampade alzate (`lavoro/lampade-2m` `9aecffa8`; fogli 4a e 4b)

Strumento `ricontrollo_lampade_2m.gd`: tutte le lampade messe da `_lampada_rossa` nella Risalita (7), con le stesse
misure della sezione 1. Il raggio in giù prende il primo appoggio sotto la lampada e fino a 50 cm davanti. Se sotto ci
fosse una pedana o una passerella, misurerebbe da lì: non ce ne sono.

| Lampada | Centro | Fondo sopra dove si cammina | Piastra-muro | Staffa-piastra |
|---|---|---|---|---|
| Cima scala di servizio, muro nord | (-28,6, 2,25, 39,22) | 2,030 m | 0,0 mm | 1,0 mm |
| Cima scala di servizio, verso C3 | (-28,6, 2,25, 31,33) | 2,030 m | 0,0 mm | 1,0 mm |
| Pianerottolo della scala di servizio | (-39,9, -3,15, 31,33) | 2,030 m | 0,0 mm | 1,0 mm |
| Corridoio del personale | (-34,23, -3,15, 49,5) | 2,030 m | 0,0 mm | 1,0 mm |
| Corridoio della scala del fiume, sud | (-4,13, -3,15, 51,2) | 2,030 m | 0,0 mm | 1,0 mm |
| Corridoio della scala del fiume, nord | (-4,13, -3,15, 62,3) | 2,030 m | 0,0 mm | 1,0 mm |
| Cima della scala del fiume | (5,87, 0,45, 49,2) | 2,030 m | 0,0 mm | 1,0 mm |

- Ravvicinati delle cinque spostate (attacco radente, di lato, da sotto) e tre scatti dagli occhi avvicinandosi (3, 1,5
  e 0,6 m). Piastra contro il muro e staffa sulla piastra in tutte. Sul pianerottolo, passandoci sotto, la lampada
  resta sopra la testa.
- Su per la scala del fiume, dalla porta del capannone alla porta di C2, un passo ogni metro (30 passi): raggio dal
  pavimento in su, libero fino a 2 m in tutti; scatti dagli occhi.
  - Le lampade si vedono sui muri, in alto.
  - Il cielo in cima è la porta di C2: nella scena di prova la sala non c'è.

## Fogli

1. `1a_lampade_cima.jpg`: le due lampade in cima, ravvicinati e dagli occhi.
2. `1b_lampada_pianerottolo.jpg`: la lampada del pianerottolo in basso (D1).
3. `2a_angolo_occhi.jpg`: l'angolo dagli occhi, dalla soglia a 2 m (luci del gioco).
4. `2b_angolo_ravvicinati.jpg`: base, contatto col muro nord e cima (con la luce di servizio).
5. `2c_bambino_fermati.jpg` e `2d_bambino_vicino.jpg`: i due video dagli occhi.
6. `2e_bambino_inseguito.jpg`: i due inseguimenti fino alla pila, dagli occhi e dalla regia.
7. `3_pile_0320_candidata.jpg`: la strada del fiume dagli stessi punti, 0.3.20 a sinistra e candidata a destra.
8. `4a_lampade_alzate.jpg`: le cinque lampade alzate da grafica, da vicino e dagli occhi.
9. `4b_scala_fiume_occhi.jpg`: su per la scala del fiume dagli occhi, con le lampade alzate.

## Strumenti (in `godot/tests/collaudo/`)

- `collaudo_lampade_scala.gd`: misure e ravvicinati delle lampade vicino alla scala (`SOLO=i,j` per scegliere quali
  scattare).
- `ricontrollo_lampade_2m.gd`: tutte le lampade rosse della Risalita e il giro su per la scala del fiume
  (`SOLO_GIRO=1` per fare solo il giro).
- `collaudo_angolo.gd`: raggi verso la nicchia, istanze dell'angolo, distacco dal muro, scatti.
- `bambino_pila.gd`: inseguimento del bambino fino alla pila, coi casi `soglia` e `dentro_2m`.
- `pile_scena_vulkan.gd`: istanze delle pile nella scena col renderer vero. `confronta_pile.py`, in questa cartella,
  le confronta (`python3 confronta_pile.py <0.3.20> <candidata>`, con numpy e scipy).
- `sonda_arrivo.gd`: arrivo da una partenza del menu, secondo per secondo, con quello che carica il thread.
