# Porta nord dell'infermeria: chiusa finché non colpisci il pulsantone

Richiesta dell'utente del 25 ottobre: "la porta dell'infermeria deve essere chiusa finché non premi il pulsantone. Ora è aperta da subito." La porta è quella nord, l'uscita verso la scala di servizio. La sud, da cui si entra, resta aperta.

## Com'è adesso

È tutto in `godot/scripts/risalita/infermeria_gioco.gd`, nelle funzioni `_telaio`, `_apri_porta_nord` e `_physics_process`.

- **All'inizio** l'anta nord è chiusa nel telaio:
  - fra gli stipiti, con 2 mm di gioco per lato;
  - 5 mm sotto la traversa e 1 cm sopra il pavimento;
  - con una collisione propria (AnimatableBody3D "AntaNord" sul cardine): non si passa.
- **Al colpo del getto sul pulsantone** si apre da sola in 2,6 s fino al muro, col suono `porta_ponte_apre`, quello della porta del ponte della sala pompe.
- **Se il giocatore è dove gira l'anta** (collaudo di ambienti-1, 25 ottobre: prima l'anta lo spingeva di 0,56-1,72 m e lo attraversava):
  - l'anta avanza a passi della fisica, solo se nella posizione nuova, allargata di 5 cm, non tocca il giocatore;
  - se lo toccherebbe si ferma lì, col suono in pausa, e riparte appena lui si sposta;
  - alla fine è sempre aperta contro il muro.
  - Il suono è un AudioStreamPlayer3D della porta, con lo stesso suono e la stessa taratura di Audio, così in pausa nessun altro suono lo prende.
- **Col pulsante già acceso** (checkpoint dopo la luce, Continua, partenze F9 dopo l'infermeria) è subito aperta e senza suono. Le partenze F9 hanno già lo stato del pulsante: spento prima dell'infermeria, acceso dopo.

## Prove

- `test_infermeria_gioco`, 56/56:
  - chiusa non si passa;
  - al colpo si apre da sola col suono, poi si passa;
  - dopo la ripartenza è già aperta, senza suono;
  - i 6 punti del collaudo di ambienti-1 dove gira l'anta: spostamento del giocatore 0, nessuna compenetrazione oltre 1 cm, l'anta a 180 gradi dopo che il giocatore se n'è andato.
- `test_risalita` 12/12: con la porta chiusa non si esce, col pulsantone colpito sì.
- `test_strada` 35/35 e `test_partenze_prova` 72/72.
- Controllo dei varchi: il varco nord è nel giro con le porte aperte.
- Posizionamento della Risalita: 0 da correggere, con l'anta chiusa nello stato iniziale e aperta in `risalita_dopo`.
