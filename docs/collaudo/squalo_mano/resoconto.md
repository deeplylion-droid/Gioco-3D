# Ricontrollo dello squalo all'inizio: gomito, mano destra e minaccia (31 ottobre)

Squadra collaudo. Ho controllato `lavoro/squalo-gomito` **cafbf584** contro la 0.3.17 (main 9eec9510), negli stessi istanti. La scena è vista dagli occhi del giocatore, col preset alto e il renderer vero, con gli interni come nella sala (`tests/collaudo/squalo_fitto.tscn`).

Uno scatto ogni 0,5 s, da 0 a 13,5 s. Nelle finestre 5,5-6,5 s, 8,8-9,2 s e 10,6-10,8 s, uno scatto a ogni fotogramma (30 al secondo). Le misure delle ossa sono prese a ogni fotogramma.

**Esito: OK, nessun difetto. 0 righe "ERROR: BUG,".**

## Che cosa va

| Controllo | 0.3.17 | cafbf584 |
|---|---|---|
| 5,5-6,5 s, ogni fotogramma (`fogli/fitto_5.5_6.5_*.jpg`, `fogli/6s_grande.jpg`) | da 5,7 a 6,2 s il dito lungo della mano destra si stira a striscia davanti al muso; a 6,0-6,2 s si apre un buco dal bordo chiaro e si vede il soffitto attraverso | nessuna striscia e nessun buco: la mano e gli artigli restano mano, e il soffitto si vede solo attorno al corpo |
| Gomito sinistro a 10,6-10,8 s (seconda differenza della posizione, cioè il salto) | 8,2 cm a 10,77 s (la mano 7,9 cm) | 3,0 cm, come il resto del corpo nella corsa; ogni fotogramma si sposta di 14-15 cm, in modo regolare |
| Gomito sinistro, salto più grande in tutta la scena | 11,1 cm a 9,87 s | 4,9 cm a 9,27 s |
| Verso 9 s (`fogli/fitto_8.8_9.2.jpg`) | — | niente dita stirate |
| Minaccia, 2,6-5,3 s: bocca dalla camera, al più vicino | 0,487 m | 0,481 m: la bocca addosso come prima |
| Minaccia: mano destra dalla camera / dalla testa, al più vicino | 0,377 m / 0,685 m | 0,390 m / 0,734 m: più di lato, non entra nella testa né nella camera |
| Camera dalla pelle, in tutta la scena, al più vicino | 0,209 m | 0,222 m: mai dentro |
| Tutta la scena ogni 0,5 s (`fogli/ogni_0.5s_*.jpg`) | — | petto, testa, spina, braccia e pinna come nella 0.3.17; porta e corsa uguali |

## Da sapere

- **La mano destra alzata, a 7,5-8,5 s** (`fogli/mano_8s.jpg`). Nella 0.3.17 c'era un dito lungo dritto verso l'alto: era lo stiramento. Ora le dita stanno raccolte ad artiglio. È l'effetto dei pesi nuovi; non vedo deformazioni.

## Come

`godot/tests/collaudo/squalo_fitto.gd` e `.tscn` sono una copia di `giro_squalo` con:
- le finestre fitte (`FITTO`);
- in `dati.jsonl` la distanza bocca-camera, la mano destra dalla camera e dalla testa, e mani e gomiti (testa dell'osso `avambraccio.*`).

Senza "scatti" gira anche senza schermo, per le misure.
