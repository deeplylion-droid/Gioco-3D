# Scarabocchi a pastelli a cera sui muri più vuoti

Richiesta dell'utente del 28 ottobre: "nei muri più vuoti, di aggiungermi degli scarabocchi a pastelli a cera, tratto
grosso". Il contenuto (cosa disegnano, i colori, l'altezza) lo sceglie l'utente; qui la parte tecnica, i muri e, dopo
le risposte, i disegni. **Niente entra nel gioco senza l'ok dell'utente** (branch `lavoro/scarabocchi`).

## I muri

Li trova `godot/tests/strumenti/cerca_muri.gd`:
- dove si cammina: dai checkpoint, una griglia di 0,5 m sul pavimento (gradini fino a 35 cm, 2 m d'aria sopra);
- dai punti della strada, all'altezza degli occhi, i muri fra 1,5 e 10 m;
- su ogni muro un rettangolo libero: piatto, architettura, senza oggetti davanti o vicino;
- lontano almeno 1 m da porte, Polaroid, pulsanti, interattivi, poster e indizi; lontano 0,6 m da cartelli e indizi
  dipinti sul muro (lo schema delle pompe è un materiale del muro);
- illuminato: il buio vero non serve, gli scarabocchi non si vedrebbero.

L'elenco completo, 37 muri, è in `muri.json`; gli scatti dal motore sono in `muri/`, dagli occhi del giocatore e da
vicino. I muri scelti, 21, sono in `scelti.json`, e i fogli per zona in `fogli/`. Ho scartato quelli al buio, quelli
coperti alla vista e quelli dietro le ringhiere della torre.

| zona | muri | dove |
|---|---|---|
| sala | 4 | la fascia di piastrelle sotto gli oblò, in basso (1,2-1,6 m di larghezza) |
| risalita | 3 | i corridoi rossi della zona del personale |
| tecnici | 1 | la sala pompe, il muro di piastrelle a nord (lontano dallo schema) |
| fiume | 1 | il muro di roccia sotto la lampada, fra le rive |
| inseguimento | 3 | le condotte, i muri sopra le vasche |
| torre | 4 | i muri chiari fra le scale |
| tunnel | 5 | il mosaico sopra le banchine, sotto le lampade |

**Interni e infermeria: nessun muro adatto.** Negli interni i muri liberi sono al buio o coperti dagli armadietti;
nell'infermeria i muri sono pieni (poster, armadietti, tende, negatoscopio, cassaforte). Se l'utente li vuole lì,
si sceglie a mano un punto.

## Il tratto e come si mettono

- `assets_src/scarabocchi/pastello.py`: il pastello a cera, nello stesso spirito del pannello dell'infermeria di
  grafica-2. Cera opaca che copre il muro, la grana che lascia vedere il muro sotto, i bordi irregolari, i segni
  ripassati 2-3 volte. Dove il posto è bagnato (fiume, tunnel, condotte) è sbiadito e staccato a macchie.
  Tratto grosso: 12-16 mm.
- `assets_src/scarabocchi/genera.py`: i disegni per muro (dopo le risposte dell'utente), le texture in
  `godot/assets/ambiente/scarabocchi/` e `scarabocchi.json`.
- Nel gioco, `godot/scripts/environment/scarabocchi.gd` (Scarabocchi): una **Decal** per scarabocchio, proiettata sul
  muro.
  - Segue le piastrelle e il loro rilievo, non sta sospesa e non tocca niente fuori dal muro: la scatola è profonda
    ±12 cm e davanti non ci sono oggetti per 50 cm.
  - Le texture le mette Godot nel suo atlante delle decal.
  - Le decal nel Forward+ sono già nello shader di ogni superficie, quindi niente pipeline nuove (da contare
    prima/dopo).
- Regole: niente lettere né numeri, niente frecce, niente cerchi colorati in fila, niente che sembri un indizio.
