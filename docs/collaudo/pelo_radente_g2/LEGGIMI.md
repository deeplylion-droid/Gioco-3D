# La fascia scura nelle bocche: il pelo visto di taglio (grafica-2, 0.3.21)

Branch `lavoro/fascia-pelo-radente`, partito da `lavoro/bocche-ombre-g2` 3f225256.

## Il difetto
Nei primi 0,3-0,8 m dentro i tubi che partono sotto il pelo c'era una fascia nera fra la sala e l'acqua.
- La camera lì sta 6,5-8,5 cm sopra il pelo.
- La fascia è l'acqua delle vasche vista quasi di taglio. Lo mostrano le prove in `docs/collaudo/bocche_ombre_g2/fascia_scura_prove.jpg`: senza la parete della bocca la fascia resta, senza le acque delle vasche sparisce.
- L'acqua è trasparente, quindi senza riflessi SSR. A raso rifletteva l'ambiente buio.

## La correzione (`godot/shaders/water_inseguimento.gdshader`)
- Il pelo, visto da sopra, prende il colore chiaro dell'acqua al posto del nero quando l'occhio sta a meno di 12 cm sopra il pelo, sfumando fino a 18 cm. In quel tratto prende `water_color`, il riflesso a specchio si spegne e la luce propria è bassa (0,12).
- Conta l'altezza dell'occhio, non l'angolo. Il criterio dei 5 gradi schiariva solo l'ultimo filo all'orizzonte: dalla bocca il pelo vicino si vede fino a 16 gradi, come quello lontano dalla vasca. La prima prova è nel commit 128b9531.
- Dalla vasca l'occhio sta a 0,9 m sopra il pelo in piedi e a 0,22 m accucciati: lì niente cambia.
- Lo shader serve solo l'acqua delle vasche, degli scoli e del bacino dell'inseguimento (`acqua_inseguimento.tres`). Le pareti delle bocche hanno il loro shader, `water_inseguimento_velo.gdshader`, che non cambia.

## Scatti prima e dopo
Sono gli stessi strumenti e le stesse pose, prima su 3f225256 e dopo sulla correzione. Il foglio è `pelo_radente_prima_dopo.jpg`.

| pose | differenza |
|---|---|
| vasche 1, 2 e 3 da dove si spara, giusta e sbagliata da vicino, lei su, accucciati (occhio a 0,221 m sopra il pelo) e accucciati guardando il pelo | identici: 0 su 255 |
| getto che colpisce | cambiano solo gli spruzzi, che sono casuali a ogni giro |
| scivolata nel tubo 3 (12 fotogrammi) | identici; nell'ultimo cambiano 0,08% dei pixel, gocce |
| tubo_1 e scolo_0 a 0,3, 0,5 e 0,8 m dentro | la fascia nera ora è il pelo color acqua (21%, 9% e 3,5% dei pixel) |

## Test
- test_occhio_sopra_acque 106, test_inseguimento 43, test_riscaldamento_pipeline 11: tutti ok.
- check_scripts 0.
- strati_luci, morbidezza_operatori e texture_compresse a 0.
