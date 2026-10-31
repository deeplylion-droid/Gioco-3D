# Ricontrollo di grafica-2: SB1 scende (lavoro/sb1-scende 0598633e)

Superato.
- Codice: cambia solo _scendi (scende_sb1 a SB1, regola comune _salto_discesa che abbassa il nodo solo se la prima posa è più in alto); scende da incombe e dalla grata invariate (test: +0,006 / +0,007 m).
- Le 26 animazioni vecchie identiche chiave per chiave (`godot/tests/collaudo/confronta_anim_g2.gd`), più scende_sb1 (1,2 s).
- test_lei_discese 21/21 a 60 e 30 fps; morbidezza sb1_scende 8/8 a 60 e 30 fps.
- Scatti dagli occhi (scatti_sb1_scende.gd, `foglio_sb1.jpg`): occhio di lei 0 fino a 5,33 s, poi solo giù (-0,04 / -0,18 / -0,44 / -0,83 / -1,36 m), testa per ultima, tentacoli senza scatti; 0 ERROR: BUG.
- Nota (cera già prima): a 6,00 s, quando lei sparisce, la luce rosa sul muro si spegne in un fotogramma.
