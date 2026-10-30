# Più luminoso nella 0.3.16? (riscontro dell'utente, 30 ottobre)

**Sì, ma solo nelle zone con la nebbia viola** (sala, piscina, infermeria, tunnel): la media resta uguale o cala, ma i neri si alzano (mediana e 10° percentile), e il buio diventa grigio-viola. Con la nebbia spenta la 0.3.16 è uguale alla 0.3.15.

## Luci e ambiente (sonda headless, `godot/tests/sonda_luminosita.gd`; `sonda_*.txt`)
Partenze F9 fiume, tunnel, risalita, torre, inseguimento, anche dopo una morte, luci bianche applicate come al disegno.
- Ambiente, esposizione, tonemap e opzioni identici nelle 3 versioni.
- Luci entro 30 m identiche fra 0.3.15 e 0.3.16, tranne RossoFaccia (rossa 2,5, dell'oblò: inseguimento +10% agli occhi) e la luce rosa del tunnel durante la fuga.
- Candidata (lavoro/godot ca58515f): fiume -15% agli occhi (lampade del corridoio al 60%).

## Scatti (media / mediana / 10° percentile, 0-255)
"0.3.15" = nebbia spenta (le luci sono le stesse). Candidata = shader e valori di lavoro/nebbia-0317.

| punto | 0.3.15 | 0.3.16 | candidata |
|---|---|---|---|
| sala ingresso | 18,2 / 14,6 / 3,2 | 12,9 / 10,2 / 4,9 | - |
| sala acquari | 14,2 / 5,9 / 0,4 | 14,3 / 10,2 / 5,1 | - |
| sala pavimento | 22,2 / 19,2 / 2,4 | 9,1 / 7,2 / 3,1 | 9,0 / 7,2 / 3,1 |
| piscina dal bordo sud | 11,4 / 2,7 / 0,6 | 11,1 / 9,2 / 2,7 | 9,0 / 6,0 / 2,4 |
| piscina dal bordo est | 9,0 / 3,6 / 0,6 | 9,8 / 8,4 / 3,5 | 8,0 / 6,3 / 2,7 |
| piscina piena | 13,2 / 5,6 / 0,6 | 11,5 / 9,7 / 2,6 | 10,9 / 9,2 / 2,6 |
| piscina, sul fondo | 9,4 / 2,7 / 0,4 | 17,0 / 17,6 / 11,2 | 10,3 / 8,1 / 4,4 |
| infermeria ingresso | 18,7 / 11,9 / 0,4 | 24,2 / 21,5 / 7,4 | 24,2 / 21,5 / 7,4 |
| infermeria lettino | 39,7 / 19,7 / 0,0 | 37,6 / 24,7 / 3,9 | 36,8 / 22,9 / 3,4 |
| infermeria lavandino | 15,2 / 4,4 / 0,1 | 11,9 / 6,9 / 2,2 | 11,7 / 6,3 / 2,1 |
| infermeria pavimento | 23,0 / 16,0 / 1,1 | 21,5 / 18,6 / 6,4 | 25,8 / 22,5 / 6,7 |
| tunnel, lei lontana | 57,6 / 45,9 / 18,3 | 43,9 / 34,2 / 18,8 | 38,2 / 27,4 / 12,8 |
| tunnel, buio con lei vicina | 8,1 / 3,1 / 0,6 | 9,0 / 6,4 / 2,7 | 5,7 / 2,1 / 0,6 |
| tunnel, guardando lei | 45,1 / 40,9 / 14,7 | 27,7 / 24,2 / 7,7 | 24,5 / 19,9 / 5,6 |

Fiume, risalita, torre, inseguimento e interni non hanno la nebbia viola: lì le luci sono uguali (sonda).
Foglio: `foglio_luminosita.jpg`.
