# Ricontrollo di grafica-2: avvio sicuro e luminosità (lavoro/avvio-sicuro-luminosita 23f236d2)

Esito: **superato**. Il difetto del collaudo finale (focus sul «Sì» della domanda sotto la calibrazione, Invio che metteva il preset basso con la luminosità ancora aperta) non c'è più.

## Gioco vero (Xvfb, cartella utente nuova, kill -9 e riavvio; `gioco_vero.sh`, tasti con xdotool)

| passo | cosa si vede | focus | preset | calibrato | segno |
|---|---|---|---|---|---|
| A primo avvio, kill -9 | luminosità | - | alto | no | sì |
| B riavvio | solo la luminosità, niente domanda | Conferma | alto | no | sì |
| B Invio | la luminosità si chiude, poi la domanda | Avvio sicuro | alto | sì | sì |
| B kill -9 con la domanda aperta, riavvio (C) | la domanda subito, niente luminosità | Avvio sicuro | alto | sì | sì |
| C giù + Invio (Avvio normale) | il titolo | Nuova partita | alto | sì | sì |

Foglio: `foglio_avvio_vero.jpg`.

## Sonda (`godot/tests/collaudo/sonda_avvio_sicuro_g2.gd`, due pressioni del tasto)

| caso | aperto | 1° tasto | 2° tasto |
|---|---|---|---|
| luminosità da confermare, Invio | luminosità, focus Conferma | luminosità chiusa, calibrato sì, domanda con focus Sì (Avvio sicuro), preset alto | domanda chiusa, preset basso, focus Nuova partita |
| luminosità da confermare, joypad A | uguale | uguale | uguale |
| luminosità confermata, Invio | domanda, focus Sì | preset basso, titolo con focus Nuova partita | - |
| luminosità confermata, joypad A | uguale | uguale | - |

Il segno della sessione nella sonda è sempre «no» perché sotto `--script` `AvvioSicuro.all_avvio` non gira: il segno si guarda nel gioco vero, dove c'è in tutti i passi.

test_avvio_sicuro: 26/0.
