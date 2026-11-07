# Ricontrollo di grafica-2: menu 0.3.22 (lavoro/menu-0322 7838523e)

Esito: **superato**. Il crash «andando dal menu su audio» non l'ho riprodotto.

## Gioco vero (Xvfb, cartella utente nuova, tasti e clic con xdotool)

| prova | esito |
|---|---|
| Primo avvio senza settings.cfg | niente calibrazione; il titolo col focus su «Nuova partita»; settings scritto con `calibrato=false` |
| Opzioni dal titolo con la tastiera | dal Chiudi su fino alla barra delle schede, poi la freccia destra cambia scheda fino ad Audio |
| Cursori dell'audio con la tastiera | si muovono (generale 97%, ambiente 98%) |
| Opzioni e Audio col mouse | clic sulla voce, sulla scheda e sui cursori (musica 69%, effetti 78%) |
| Calibrazione dalle opzioni | Luminosità, «Calibra la luminosità…»: si apre (con la seconda prova del corridoio), confermata salva luminosità 1,04 e `calibrato=true`; si torna alle opzioni |
| Avvio sicuro dopo kill -9 | la domanda, col focus su «Avvio sicuro», senza calibrazione; «Avvio normale» lascia la qualità alta |
| Volumi dopo il riavvio | tenuti (97, 69, 98, 78) |
| Stress, con l'audio vero | ALSA con un dispositivo nullo (non il driver finto): 4 volte opzioni aperte e chiuse col mouse, schede avanti e indietro, cursori con tastiera e mouse, poi 3 giri di tutte le schede con la tastiera; il gioco resta vivo, 0 errori nel log |

Foglio: `foglio_gioco_vero.jpg`.

## Joypad e pausa (sonda `tests/collaudo/sonda_menu_joypad_g2.gd`, eventi veri del joypad)

| prova | esito |
|---|---|
| Titolo: croce giù e A su Opzioni | le opzioni si aprono col focus su Chiudi |
| Croce su fino alla barra, poi destra 6 volte | scheda Audio |
| Croce su un cursore e sinistra | il volume scende (musica 0,80 → 0,78) |
| Schede indietro e avanti con la croce | si torna su Audio |
| B | le opzioni si chiudono, il focus torna su Opzioni del titolo |
| Pausa (in una scena vuota): croce giù 2 e A | le opzioni si aprono dalla pausa |
| Come sopra, fino ad Audio e i cursori | uguale (musica 0,78 → 0,76) |
| B | si torna al menu di pausa, focus su Riprendi |

Passi in `sonda_joypad.txt`; 0 errori nel log.

Da sapere (minore): dalla barra delle schede, il primo «giù» del joypad nella scheda Audio non porta sul cursore del volume generale: le tre «sinistra» dopo non l'hanno mosso. Con la tastiera, la stessa sequenza lo muove (97%). Il secondo «giù» è sul cursore della musica e lo muove. Non è un blocco: col joypad si arriva a tutti i cursori.

Senza la sala in memoria non ho potuto fare la pausa nel gioco vero: la pausa è provata con la sonda, in una scena vuota.
