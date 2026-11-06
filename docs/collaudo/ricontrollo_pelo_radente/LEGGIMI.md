# Ricontrollo del pelo radente (grafica-2, lavoro/fascia-pelo-radente ad24c07b; ambienti-1, 6 novembre)

Collaudo: `godot/tests/collaudo/collaudo_pelo_radente.gd`. Usa la torre con le condotte e il giocatore vero, che si muove da solo (camminata, salti, accucciati), a 60 fotogrammi al secondo.

## Esito: superato

- **Nelle vasche** l'acqua non cambia, perché l'occhio non scende mai sotto i 18 cm sopra il pelo, dove comincia il cambio.
  - Accucciati, camminando avanti e indietro e saltando, l'occhio scende al minimo a 0,203 m in tutte e tre le vasche.
  - Il margine è di 2,3 cm: se un giorno l'occhio accucciato si abbassa, va ricontrollato.
- **Entrando nelle 6 bocche** accucciati, l'occhio passa da 0,18 a 0,12 m in 2-4 fotogrammi.
  - Guardando dentro il tubo, come si entra, il pelo non è nell'inquadratura.
  - Fra due fotogrammi la luminosità media cambia al più di 0,006 (tubo 1, tubo 3).
- **Uscire da una bocca verso la vasca non si può**: nei tubi si scivola in giù, e il giocatore non ne esce mai da quella parte.
- **Chi entra voltandosi a guardare la vasca** (`scolo_0_entrando_guardando_indietro.jpg`, scolo 0, fotogrammi 076-083):
  - il pelo passa dal nero col riflesso della lampada al colore chiaro dell'acqua in 3 fotogrammi (50 ms), sfumando;
  - prima, fino a 0,183 m, resta la fascia nera di prima; dopo è chiaro e fermo.
  - È un cambio rapido ma non uno scatto, e si vede solo voltandosi proprio entrando.
- **Scoli e bacino**: l'acqua è profonda 72-74 cm come nelle vasche, e anche alla scaletta del bacino l'occhio resta alto. Fra 0 e 18 cm sopra il pelo ci si passa solo nelle bocche.

## Test

Tutti sul branch ad24c07b:
- test_occhio_sopra_acque 106/106
- test_inseguimento 43/43
- test_scaletta_bacino 13/13
- test_riscaldamento_pipeline 11/11 (col renderer vero)
- check_scripts 0 errori
