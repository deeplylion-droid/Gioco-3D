# Scarabocchi a pastelli a cera sui muri più vuoti

Richiesta dell'utente del 28 ottobre: "nei muri più vuoti, di aggiungermi degli scarabocchi a pastelli a cera, tratto
grosso". Scelte dell'utente, quelle consigliate: C, C, B.
- **Cosa.** Scarabocchi e disegnini da bambini mescolati, più qualcuno che mette a disagio. Mai lei che prende
  qualcuno, e niente che spieghi cosa è successo.
- **Colori.** I disegnini coi colori dei pastelli, sbiaditi dall'umidità; quelli a disagio in nero e rosso.
- **Altezza.** Quasi tutti fra 30 cm e 1,3 m; uno o due per zona a 2-2,5 m, dove un bambino non arriva.

Branch `lavoro/scarabocchi`. **Niente si unisce senza l'ok dell'utente.**

## Cosa guardare

- `fogli/<zona>.jpg`: per ogni muro, a sinistra lo scatto dagli occhi del giocatore e a destra quello da vicino.
  Sono scatti del motore, con gli scarabocchi veri.
- `scatti/<muro>_occhi.jpg` e `scatti/<muro>_vicino.jpg`: gli stessi scatti a grandezza piena.

| zona | muri | in basso | in alto (2-2,5 m) |
|---|---|---|---|
| torre | 3 | la nave col sole; i bambini per mano con Jilly sorridente | le manine che salgono |
| inseguimento | 3 | i pesci sotto le onde; Jilly coi pesci | l'occhio solo |
| tunnel | 5 | spirale, righe e scarabocchio; la nave; l'omino cancellato e il tondo verde | i bambini sott'acqua; le manine |
| sala | 3 | Jilly coi pesci (sulla fascia di piastrelle) | l'occhio solo; i bambini sott'acqua |
| risalita | 2 | spirale, righe e scarabocchio; l'omino cancellato | |
| tecnici | 1 | la nave col sole | |
| fiume | 1 | i pesci sotto le onde | |

**Interni e infermeria no**, come chiesto. In sala gli scarabocchi stanno a più di 3 m dagli acquari e dal loro disegno.

**Da sapere.**
- Nei corridoi rossi della risalita e nel fiume i disegni **si vedono appena**: la luce rossa e il buio si mangiano i
  colori dei pastelli. Si possono lasciare così (si scoprono avvicinandosi), toglierli, o farli più chiari solo lì.
- Ho tolto 4 muri dove non si vedeva niente: uno nella risalita, uno nei tecnici, uno nel fiume e uno nel tunnel.

## Le regole controllate

- Niente lettere, numeri o frecce.
- Niente cerchi gialli, rossi e blu in fila, che sembrerebbero l'enigma delle onde: un tondo è sempre da solo.
- I disegni a disagio sono solo in alto. Lei non prende mai nessuno: nei bambini sott'acqua sta in mezzo, staccata da
  loro.
- **Pipeline: nessuna nuova.** Per ognuna delle 36 viste lo scatto conta le pipeline compilate prima senza
  scarabocchi e poi con (`RenderingServer`, draw, specializzazione, superficie e mesh): **0 nuove in tutte**.
  - Le decal nel Forward+ sono già nello shader di ogni superficie.
  - Alla prima vista di due zone si compila ancora qualcosa con gli scarabocchi spenti (11 in sala, 23 nel fiume):
    è il caricamento della scena, non loro.
  - I totali di fine giro sono uguali senza e con:
    - torre [50, 95, 251, 134];
    - tunnel [18, 20, 153, 42];
    - sala a parti [118, 242, 466, 244].
- **Controllo di posizionamento verde**: `RISULTATO: 2 controlli ok, 0 falliti`, 0 da correggere, con il nodo
  Scarabocchi nella sala.
  - Le decal non sono oggetti: sono proiettate sul muro e seguono le piastrelle.
  - La loro scatola è profonda ±12 cm e davanti al muro non c'è niente per 50 cm, quindi non stanno sospese e non
    toccano altro.

## Come funziona

- **I muri** li trova `godot/tests/strumenti/cerca_muri.gd`, poi li ho scelti uno per uno dagli scatti dei candidati
  (`candidati/`, `candidati.json`).
  - Dove si cammina: da un muro piatto e libero, l'architettura vera.
  - Lontano almeno 1 m da porte, Polaroid, pulsanti e poster, e 3 m dagli acquari, anche da quelli nascosti.
  - Illuminato.
  - I muri scelti sono in `scelti.json`. La ricerca vecchia, fatta prima delle risposte, è in `vecchi/`.
- **Il tratto** è `assets_src/scarabocchi/pastello.py`.
  - Cera opaca, la grana del muro, bordi irregolari, ogni segno ripassato 2-3 volte, tratto da 12-17 mm.
  - Dove è bagnato (tunnel, fiume, inseguimento) è sbiadito a macchie.
- **I disegni** sono in `assets_src/scarabocchi/disegni.py`. Li mette `genera.py`, a turno per tutto il gioco, così
  non ce ne sono due uguali di fila. Le texture vanno in `godot/assets/ambiente/scarabocchi/`.
- **Nel gioco** c'è il nodo `Scarabocchi` (`godot/scripts/environment/scarabocchi.gd`) nella sala principale: una
  Decal per muro, nelle coordinate della sala, comprese torre e tunnel che si aggiungono lì.
- **Gli scatti** si rifanno con `godot/tests/strumenti/scatti_muri.gd`, con `MURI=…/scelti.json SCARABOCCHI=1`. La
  sala si monta a parti perché intera non ci sta in memoria.
