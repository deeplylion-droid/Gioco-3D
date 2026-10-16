# Lance dello zaino: tre proposte (16 ottobre)

Solo proposte, nel gioco c'è ancora la lancia attuale (`scenes/player/lance/lancia_opzione2.tscn`). Lo zaino resta quello del giocattolo anni '90; cambia la lancia in mano, collegata allo zaino con un tubo.

| Proposta | In gioco (corridoio degli interni, luce normale) | Modello da 3 lati | Ugello |
|---|---|---|---|
| attuale | `0_attuale_gioco.jpg` | | |
| A lancia da pompiere (ottone, leva a staffa, impugnatura di gomma, manichetta rossa) | `a_pompiere_gioco.jpg` | `lancia_a_pompiere_3lati.jpg` | `lancia_a_pompiere_ugello.jpg` |
| B cannone ad acqua giocattolo gigante (colori dello zaino, manometro, ugello largo con le alette) | `b_cannone_gioco.jpg` | `lancia_b_cannone_3lati.jpg` | `lancia_b_cannone_ugello.jpg` |
| C lancia industriale (bande gialle e nere, manometro grande, impugnatura a pistola, maniglia sopra) | `c_industriale_gioco.jpg` | `lancia_c_industriale_3lati.jpg` | `lancia_c_industriale_ugello.jpg` |

- Scene da provare: `godot/scenes/player/lance/proposte/lancia_*.tscn` (LanceRig, stesse mani della lancia attuale). Nel gioco: `WaterPack.set_lance(load(...))`.
- Il nodo `Muzzle` è al centro dell'ugello, con il getto verso -Z: la sfera e la freccia ciano negli scatti `*_ugello.jpg` sono quel punto. Il getto di grafica parte da lì (`pack.muzzle`).
- Modelli: Meshy meshy-7.1 da `assets_src/zaino_lance/ambienti1/genera_lance.py` (riferimenti solo interni in `rif/`), sistemati da `tools/blender/lance_proposte.py` (scala, punta, tubo verso lo zaino, render). glTF in `godot/assets/models/zaino/proposte_lance/`.
- Gli screenshot si rifanno con `tests/scatti_liberi.gd` (quarto campo di ogni scatto = la scena della lancia).
