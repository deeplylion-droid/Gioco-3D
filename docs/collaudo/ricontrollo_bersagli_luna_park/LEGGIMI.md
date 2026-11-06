# Bersagli da luna park: ricontrollo iniziato da ambienti-1 e passato al collaudo (6 novembre)

Stato provato: lavoro/candidata-0321 46768c5d più l'unione di fc93f763 (bersagli) e di lavoro/bocche-ombre-g2 4e4679ec. Le unioni sono andate senza conflitti.

## Fatto

`godot/tests/collaudo/sonda_paratie_bersagli.gd` gira nella sala dell'inseguimento vera, con le sagome. Per ogni paratia, chiusa e aperta, prova la forma convessa del pannello, rimpicciolita del 5 per mille, contro tutto il resto (collisioni e mesh). Poi fa il getto vero sul sole.

- **Aperte**: nelle sei paratie non entra niente nel pannello.
- **Chiuse**: tutte e sei toccano ins_A_struttura.
  - Il pannello scende 43 cm sotto il pavimento del vano (il fondo a -22,80 col pavimento a -22,37 nella vasca 1; lo stesso nelle altre) e ai lati sta a filo dei montanti (0,0-0,3 mm).
  - **C'era già prima dei bersagli**: la candidata senza bersagli (46768c5d) dà gli stessi identici numeri (`sonda_paratie_senza_bersagli.txt`). Non viene dai bersagli; è sotto il pavimento e non si vede.
- **Getto**: la paratia comincia ad aprirsi dopo 1,52 s di getto. È alzata del tutto a 2,00 s nelle vasche 1 e 3 e a 3,02 s nella vasca 2 (la giusta lenta). La corsa è 1,95 m.

## Non fatto (passa al collaudo)

- Gli scatti dalle pose del foglio approvato (`scatti_bersagli_g2.gd` di grafica-2) e il confronto con `foglio_bersagli.jpg` di lavoro/bersagli-luna-park 90756a37.
- Gli scatti ravvicinati di pannelli e montanti: lo script è pronto, `godot/tests/collaudo/scatti_paratie_vicino.gd <cartella>`, ma non è stato lanciato.
- I test sull'unione: inseguimento, occhio_sopra_acque, posizionamento e check_scripts.
