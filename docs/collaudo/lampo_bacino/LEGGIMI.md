# Lampo rosa sul bacino durante il riscaldamento del tunnel (#131)

Misura con `godot/tests/collaudo/misura_lampo_bacino.gd`: torre e condotte come nel gioco (blackout, ambiente della sala),
gli occhi del giocatore nel bacino verso la porta di servizio, poi il tunnel costruito a pezzi col suo riscaldamento.
Per ogni fotogramma conta i pixel (su 160x90) dove rosso e blu salgono più del verde rispetto allo scatto di prima del tunnel.

| | fotogrammi col riscaldamento | fotogrammi con più di 20 pixel rosa | il peggiore |
|---|---|---|---|
| prima (main 29f78c94) | 48 | 14 | 12994 su 14400 (+12,4) |
| solo strati della luce (5e40323f) | 48 | 13 | 11725 su 14400 (+9,7): restava il cono rosa nella nebbia |
| strati + nebbia a zero (3f6081ec) | 48 | 0 | 0 |

`prima_dopo.jpg`: in alto prima (riferimento, poi 1, 3 e 7 fotogrammi dopo l'accensione), in basso dopo, negli stessi momenti.

Sonda delle pipeline (`godot/tests/sonda_pipeline_sottomarino.gd`): stessi numeri di main
(`costruito, fuori vista [66, 83, 172, 49]`, `fine` uguale), nessuna compilazione al primo sguardo lungo il tunnel.
