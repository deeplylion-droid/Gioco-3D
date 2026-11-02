# Corridoio delle pile al 20% (riscontro dell'utente sulla 0.3.19: "ERANO AL 20 QUELLE")

LUCE_CORRIDOIO da 0,6 a 0,2: le 5 lampade del corridoio (3 appese alle pile, 2 sul muro nord) al 20% di com'erano nella 0.3.16, luce e globo (globo a 0,6 invece di 3,0). Al disegno le calde scendono ancora al 40% (LuciBianche).

Scatti del fiume (scatti_fiume_gioco, 1280x720), media / mediana / 10%:

| punto | prima (60%, globo pieno) | dopo (20%) |
|---|---|---|
| porta d'ingresso | 29,5 / 19,8 / 8,6 | 20,5 / 11,1 / 4,6 |
| corridoio 1 | 28,9 / 24,2 / 13,7 | 12,6 / 9,2 / 2,4 |
| corridoio 2 | 19,8 / 16,3 / 4,8 | 8,2 / 4,6 / 0,1 |
| corridoio 3 | 16,3 / 11,6 / 1,5 | 8,7 / 3,6 / 0,1 |
| corridoio 4 | 21,6 / 18,5 / 7,0 | 20,6 / 17,6 / 5,8 |
| imbarco | 14,3 / 13,8 / 3,3 | 13,9 / 12,9 / 3,3 |

Le altre lampade a gabbia col globo fuori dal tunnel (gioco vero, `godot/tests/collaudo/elenco_gabbie_g2.gd`), valori scritti (al disegno le calde al 40%):
- fiume, sulla roccia lungo l'anello: 16, luce 3,0, globo 3,0;
- fiume, all'approdo: 1, luce 3,0, globo 3,0;
- fiume, sul muro della piazza: 1, luce 2,5, globo 3,0;
- fiume, rotte (spente): 5;
- sala, lampada della valvola dell'enigma degli acquari: 1, luce 6,0 (ffdba8), globo 8,0.

## Le altre 18 lampade a gabbia del fiume al 20% ("A 20 anche quelle")

LAMPADE_TONDE = 0,2 in _lampada_calda (16 sull'anello, approdo, piazza), globo comune a 0,6. Gioco vero: 21 lampade a 0,60 e 2 a 0,50, tutte col globo 0,60; le 5 rotte e la valvola degli acquari (6,0, globo 8,0) com'erano. Media / mediana / 10%:

| punto | prima | dopo |
|---|---|---|
| piazza | 20.0 / 16.0 / 5.9 | 19.9 / 16.0 / 5.9 |
| tiki | 16.8 / 16.4 / 4.2 | 8.9 / 8.3 / 3.2 |
| bivio1 | 17.2 / 13.1 / 4.7 | 4.2 / 1.9 / 0.1 |
| ramo | 29.5 / 25.9 / 11.8 | 14.5 / 11.5 / 5.5 |
| bivio3 | 24.4 / 18.9 / 3.9 | 10.8 / 5.1 / 0.1 |
| sponda_colonna | 25.5 / 24.7 / 10.9 | 11.3 / 9.8 / 2.2 |
| approdo | 14.8 / 9.9 / 1.4 | 8.6 / 5.9 / 1.1 |
| porta_approdo | 27.3 / 17.4 / 7.3 | 16.4 / 7.8 / 3.2 |

Foglio: foglio_anello_20.jpg.

## Con le pile sfalsate (unione di 79a367e5)

| punto | 0.3.19 (60%) | 20%, pile vecchie | 20%, pile sfalsate |
|---|---|---|---|
| porta d ingresso | 29,5 / 19,8 / 8,6 | 20,5 / 11,1 / 4,6 | 20,3 / 10,9 / 4,5 |
| corridoio 1 | 28,9 / 24,2 / 13,7 | 12,6 / 9,2 / 2,4 | 12,1 / 8,9 / 2,2 |
| corridoio 2 | 19,8 / 16,3 / 4,8 | 8,2 / 4,6 / 0,1 | 8,3 / 4,1 / 0,1 |
| corridoio 3 | 16,3 / 11,6 / 1,5 | 8,7 / 3,6 / 0,1 | 7,8 / 4,5 / 0,1 |
| corridoio 4 | 21,6 / 18,5 / 7,0 | 20,6 / 17,6 / 5,8 | 19,5 / 17,2 / 5,8 |
| imbarco | 14,3 / 13,8 / 3,3 | 13,9 / 12,9 / 3,3 | 11,6 / 10,3 / 2,7 |

Sonda: 21 lampade a 0,60 e 2 a 0,50, globo 0,60; 5 rotte; valvola 6,0 / 8,0. Foglio: foglio_pile_sfalsate_20.jpg.
