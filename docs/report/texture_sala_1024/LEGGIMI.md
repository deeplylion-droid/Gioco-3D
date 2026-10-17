# Normal e ORM della sala a 1024: verifica a occhio (17 ottobre)

Scatti dal motore (`godot/tests/scatti_sala.gd`, preset alto_smaa, 1600x900, torcia accesa con
`SCATTI_TORCIA=1`), OGGI con le normal map e le ORM della sala a 2048, DOPO a 1024 (regola in
`tools/godot_vram_textures.py`). Il colore è a 2048 in tutti e due.

| File | Inquadratura | Differenza media per pixel (0-255) |
|---|---|---|
| `confronto_vicino_pavimento.jpg` | Da vicino (1,5-2 m): bordo della vasca, piastrelle sott'acqua, pavimento bagnato | 0,6 |
| `confronto_vicino_muro.jpg` | Da vicino (1,8 m): il muro ovest piastrellato con la torcia | 1,4 |
| `confronto_bimbi_arrivo.jpg` | L'area bimbi da dove si arriva | 10,3 (vedi sotto) |
| `confronto_sala_da_terra.jpg` | La sala da terra | 0,5 |
| `ritaglio_vicino_*.jpg` | Ritagli a piena risoluzione, OGGI a sinistra e DOPO a destra | |

Da vicino, nei ritagli a piena risoluzione, i bordi delle piastrelle sotto la torcia brillano appena meno nel
DOPO; a dimensione normale non si distingue. In `bimbi_arrivo` la differenza viene dalla luce del momento
(nel DOPO un riflesso forte nell'acqua e il lato sinistro più illuminato), non dalle texture: piastrelle e
muri sono uguali.
