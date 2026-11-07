# Varchi verso il cielo nella torre (6 novembre)

## Toppe di torre_A

L'intaglio col booleano di `tools/blender/torre_a.py` toglie dei triangoli da `torre_A` (torre_struttura.glb): pareti, tetto
(7,3 e 3,6 m²) e fondo del pozzo, 100 triangoli in tutto, 36 m². Il gioco li rimette costruendo la torre
(`SalaTorre._toppe_torre_A`, con la collisione) da `godot/assets/ambiente/torre/torre_toppe.json`, che si rifà con
`godot/tests/aggiorna_toppe_torre.gd` quando cambia il modello; la CI controlla che il file corrisponda alla mesh.
Quando ambienti-2 corregge il generatore, le toppe vanno via.

## Anelli aperti lasciati come sono

`godot/tests/collaudo/bordi_torre.gd` cerca gli altri bordi aperti (tolte le giunzioni a T, anelli chiusi sopra 0,01 m²)
e se il loro centro si vede dagli occhi dei checkpoint e dalla discesa. Ne restano 14 "visti dai raggi", ma negli scatti
da vicino (`anelli_visibili_da_vicino.jpg`, nell'ordine sotto) nessuno si vede: sono facce mancanti dal lato nascosto,
a contatto con lo scivolo o coperte dalla staffa. Non si chiudono (decisione del coordinatore, 6 novembre): una toppa
sullo scivolo sfarfallerebbe. Da sistemare nel modello quando si rifà.

| scatto | mesh | centro (x, y, z) | area m² | fuori piano m | cos'è |
|---|---|---|---|---|---|
| buco_00 | torre_A | 23.92, -9.25, -6.53 | 0.389 | 0.027 | striscia lunga 6 m dietro il giunto del tubo |
| buco_01 | torre_A | 25.28, 8.80, -17.84 | 0.030 | 0.985 | bordo sotto la staffa dello scivolo viola |
| buco_02 | torre_A | 27.39, -11.04, -22.76 | 0.018 | 0.012 | bordo dietro la testa dello scivolo giallo |
| buco_03 | sostegni | 36.09, -8.83, -22.87 | 0.128 | 0.194 | fondo di una staffa |
| buco_04 | sostegni | 34.26, 3.23, -20.13 | 0.113 | 0.331 | fascetta contro lo scivolo rosa |
| buco_05 | sostegni | 25.98, 3.25, -11.88 | 0.109 | 0.321 | fascetta contro lo scivolo rosa |
| buco_06 | sostegni | 36.46, 3.27, -17.94 | 0.030 | 0.033 | staffa contro lo scivolo rosso |
| buco_07 | sostegni | 32.28, -5.55, -9.12 | 0.016 | 0.041 | staffa contro lo scivolo azzurro |
| buco_08 | sostegni | 38.14, -3.61, -16.67 | 0.014 | 0.024 | piede della staffa sotto lo scivolo giallo |
| buco_09 | sostegni | 24.86, -8.98, -13.89 | 0.013 | 0.020 | fascetta contro lo scivolo azzurro |
| buco_10 | sostegni | 29.85, -8.97, -8.55 | 0.013 | 0.000 | triangolo mancante della fascetta, sotto lo scivolo blu |
| buco_11 | sostegni | 29.08, -12.36, -21.34 | 0.013 | 0.000 | triangolo mancante della fascetta, contro lo scivolo arancio |
| buco_12 | sostegni | 31.14, 4.93, -9.09 | 0.012 | 0.034 | fascetta contro lo scivolo giallo |
| buco_13 | sostegni | 29.62, -12.95, -21.46 | 0.012 | 0.012 | piede della staffa sotto lo scivolo arancio |

Lo scatto con lo sfondo magenta (`scatti_portone_torre.gd`, `MAGENTA=1 CUBO=1`) dagli 11 checkpoint e lungo la discesa,
in 6 direzioni (240 scatti), non ha magenta nella torre.

## La porta di servizio del bacino delle condotte

Nel cubo magenta, da Checkpoint_bacino verso ovest, il vano della porta in cima alla scaletta era magenta (716 pixel,
anche al far vero della camera): nello scatto a parti mancava il tunnel del viaggio sottomarino, che sta dietro la
porta. Nel gioco la sala lo mette nel livello e lo costruisce mentre si è nella torre (`SalaPrincipale._completa_torre`,
`_precarica_sottomarino`). Con il tunnel costruito (`TUNNEL=1`) il vano mostra il mosaico del tunnel: 0 pixel magenta
(`bacino_porta_senza_e_con_tunnel.jpg`, a sinistra senza, a destra con). `controllo_cielo.gd` ora aspetta il tunnel
costruito e tira 81 raggi dal bacino verso il vano: non ne esce nessuno.
