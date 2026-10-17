# Lance dello zaino: proposte (16 ottobre)

Solo proposte: nel gioco c'è ancora la lancia attuale (`scenes/player/lance/lancia_opzione2.tscn`). Lo zaino resta quello del giocattolo anni '90; cambia la lancia in mano, collegata allo zaino con un tubo.

**In gioco**, dallo stesso punto del corridoio degli interni e con le stesse mani, lancia attuale compresa (`0_attuale`):
- `gioco_fisse/`: la luce di oggi (neon e rosse d'emergenza, senza sfarfallio);
- `gioco_neon/`: luce normale, neon accesi e rosse spente, per leggere i colori.

| Proposta | In gioco | Modello da 3 lati (luce neutra) | Ugello |
|---|---|---|---|
| A pompiere: ottone, canna e ugello grossi, leva a staffa, manichetta rossa | `a_pompiere`, `a_pompiere_2mani` (sinistra sulla leva) | `lancia_a_pompiere_3lati.jpg` | `lancia_a_pompiere_ugello.jpg` |
| B cannone giocattolo: colori accesi e più scuri, un po' di ruggine | `b_cannone` | `lancia_b_cannone_3lati.jpg` | `lancia_b_cannone_ugello.jpg` |
| C industriale: bande gialle e nere, manometro, maniglia sopra | `c_industriale`, `c_industriale_2mani` (sinistra sulla maniglia) | `lancia_c_industriale_3lati.jpg` | `lancia_c_industriale_ugello.jpg` |
| C1: la C col rosso-arancio antincendio al posto del nero | `c1_antincendio` | `lancia_c1_antincendio_3lati.jpg` | come la C |
| C2: la C col turchese dello zaino al posto del nero | `c2_turchese` | `lancia_c2_turchese_3lati.jpg` | come la C |

- Misure in gioco: A 85 cm, B 95 cm, C 90 cm (circa 1,4 volte le prime proposte).
- Scene da provare: `godot/scenes/player/lance/proposte/*.tscn` (LanceRig). Nel gioco: `WaterPack.set_lance(load(...))`.
- Il nodo `Muzzle` è al centro dell'ugello, con il getto verso -Z: negli scatti `*_ugello.jpg` è la sfera con la freccia ciano. Il getto di grafica parte da lì (`pack.muzzle`).
- Perché l'ugello punti di più verso il centro dello schermo serve una `converge_distance` più corta nel `WaterPack` (oggi 6 m, per esempio 3 m). È un'impostazione del gioco e vale per tutte le lance: qui non l'ho toccata.
- Modelli: Meshy meshy-7.1 da `assets_src/zaino_lance/ambienti1/genera_lance.py` (i riferimenti in `rif/` sono solo interni), sistemati da `tools/blender/lance_proposte.py` (scala, punta, canna della A, colori della B e delle C, tubo verso lo zaino, render). glTF in `godot/assets/models/zaino/proposte_lance/`.
- Gli scatti si rifanno con `tests/scatti_liberi.gd` (quarto campo di ogni scatto = la scena della lancia; ultima opzione `fisse` o `neon`).
