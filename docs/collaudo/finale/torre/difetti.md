# Passaggio finale: torre degli scivoli e inseguimento

Base: `lavoro/godot` al commit **7f24d91b**, con tutte le consegne di ambienti-2. Squadra collaudo, 23 ottobre. Scena `scenes/sala/torre/sala_torre.tscn`, stato inizio. Confronto con `docs/collaudo/torre/difetti.md` (604e519).

## Come è stato fatto

- **Controllo della CI** (tutto il gioco): 0 casi nuovi, 29 già noti, 3 "da correggere" fuori da questa zona (medusa della fossa, lettino 23).
- **Distanze vere**: 472 oggetti. Nessuno è staccato oltre 1 cm.
- **Spazio per la testa**: niente sopra i punti dove si cammina.
- **Giro dagli occhi**: gli stessi 55 punti di 604e519, 220 scatti, con i materiali veri (`fogli/torre_giro_*.jpg`).
- **Vedute ravvicinate**: 259, su fari, lampade, lampade d'emergenza, ganci, led degli imbocchi, cartelli e oggetti piccoli, con la vista libera verificata (`fogli/torre_vedute_*.jpg`). Le 165 cose senza un punto da cui si vedano sono led e lampade nascosti dietro la struttura.

## Da verificare (visto su 7f24d91b)

| # | Nodo | Posizione | Problema | Scatto |
|---|---|---|---|---|
| 1 | I pali rossi coi led verdi degli imbocchi, in `TorreStruttura/torre_A`: quelli di `Luci/LedImbocco`, `@MultiMeshInstance3D@276`, `@282`, `@288`, `@294`, `@300` | (28,41, -20,33), (36,33, -17,6), (33,61, -9,67), (25,65, -12,48), (22,8, -11,53), (28,48, -20,35), (36,35, -17,53) | Sotto la fila di led il palo si stringe a punta e finisce sopra l'apertura dell'imbocco, senza toccare la pedana. Il led più basso è a 25-30 cm dal piano. Va bene se è il montante della cornice voluto così, altrimenti va portato fino alla pedana. La misura non lo coglie, perché il palo fa parte della mesh grande. | `scatti/vgt_Luci_LedImbocco_10.jpg`, `vgt_Luci_@MultiMeshInstance3D@288_10.jpg`, `@294_11`, `@300_9`, `@276_9`, `@282_9`, `@288_0` |

## Superati da 604e519

Polaroid10 sul lettino, lettino e cartelli sul grigliato; i due fari della passerella non passano più davanti alla faccia; la lampada col braccio @128-132, le lampade d'emergenza @72 e @80 e il faro @233 toccano; le 6 lampade dell'inseguimento sono attaccate al gancio; `det_tubo_valvola_T` tocca il muro. La scia rosa sul bordo della vasca 1 e il tubo vicino alla scaletta non ci sono più.
