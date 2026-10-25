# Collaudo "Jilly dietro gli oblò": cornice tonda (lavoro/oblo-tondo 1a3a6727)

Squadra grafica, 25 ottobre. Solo documentazione: niente è stato corretto.

Oblò controllati: ObloFiume, ObloPersonale e ObloServizio (Risalita) e quello della torre (vetro 0,6).
Gli scatti ravvicinati sono fatti con una luce bianca sulla camera, perché al buio non si vedrebbe niente. Lo script è `godot/tests/collaudo/ravvicinati_oblo.gd`.

Fogli dei ravvicinati, uno per oblò: `fogli/foglio_ravv_*.jpg`.
Gli scatti dei difetti sono in `difetti/`.

## Esito per punto

1. **Niente quadrato scuro, né bordi neri:** ok in tutti e quattro. La piastra scura non c'è più, e intorno al vetro c'è solo il bordo d'ottone con la flangia.
2. **Il muro continua fino alla cornice:** NO in due oblò su quattro, forse tre (vedi D1, D2 e D3).
3. **La flangia aderisce al muro, coi rivetti sopra:** ok in tutti e quattro. Negli scatti di sbieco (o, p, q) e da vicino (h, i, j, k) la flangia sta sul muro senza distacco, e i rivetti poggiano sulla flangia.
4. **Lei dietro il vetro:** ok, ferma di fronte e di sbieco in tutti e quattro (m, n). Gli altri stati sono più sotto, negli scatti dagli occhi del giocatore.

## Difetti

- **D1. Torre: riquadro più chiaro attorno all'oblò.** La faccia nuova del muro (il quadrato di 1,9 m) è più chiara delle piastrelle vere intorno, con i bordi netti, anche se le piastrelle combaciano. Forse la faccia nuova non riceve l'ombra o ha un'altra normale.
  - Scatto: `difetti/1_torre_riquadro_chiaro.jpg`.
- **D2. ObloServizio: giunta verticale netta sul bordo del quadrato,** in alto a destra. A sinistra la lamiera è più scura e ha un altro disegno, a destra è più chiara, con una riga chiara in mezzo. Va confermato se è il bordo della faccia nuova o una giunta delle lamiere vere: cade dove dovrebbe stare il bordo del quadrato.
  - Scatto: `difetti/2_servizio_giunta.jpg`.
- **D3. ObloFiume: probabile giunta** nello stesso punto, in alto a destra: una riga chiara di sbieco, con la lamiera diversa ai due lati.
  - Scatto: `difetti/3_fiume_giunta.jpg`.

ObloPersonale: nessun difetto visto.
