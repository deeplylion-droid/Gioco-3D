# Ricontrollo di grafica-2: luce rosa di lei che sfuma (lavoro/sb1-luce 88e7ecbd)

Superato. A SB1 la luce va 6 → 5 → 4 → 3 → 2 → 1 → 0 da 5,53 a 5,93 s mentre lei va sotto, ed è a 0 quando sparisce (6,00 s): il rosa sul muro sfuma con lei (`foglio_luce.jpg`). In vasca_0 (`godot/tests/collaudo/sonda_luce_lei_g2.gd`): piena (6) alla comparsa e in salita, si spegne negli ultimi 0,4 s, torna piena alla comparsa dopo, anche se lei ricompare a metà spegnimento. test_lei_discese 21/21; 0 ERROR: BUG.
