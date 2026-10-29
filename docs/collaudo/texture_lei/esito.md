# Lei da vicino, prima e dopo la compressione delle texture (ambienti-1, 29 ottobre)

**Contesto.** Grafica-2, su `lavoro/controllo-texture` c7a4c5a3, ha trovato che le 14 texture estratte della medusa
(`assets/models/medusa/medusa_*.import`, non in git) uscivano Lossless e senza mipmap in tutte le build fino alla 0.3.15.

**Come ho fatto il confronto.**
- Lei sola, in pose fisse del gioco, con la stessa camera e la stessa luce nei due giri: buio blu e la torcia sulla
  camera. Lo script è `godot/tests/collaudo/scatti_texture_lei.gd`.
- **Prima:** le 14 texture rimesse come nelle build fino alla 0.3.15 (`compress/mode=0`, `mipmaps/generate=false`) e
  reimportate. Con il `godot_importa.sh` di lavoro/godot restano davvero così: la seconda conversione di c7a4c5a3
  serve.
- **Dopo:** compresse per la scheda video con le mipmap, come in c7a4c5a3.
- Le pose:
  - all'oblò (oblo_sbircia, 0,9 m);
  - nella presa (presa, 0,8 m);
  - nel tunnel quando insegue (insegue_aperta, 2,6 m);
  - tre dettagli da vicino: capelli, pelle del petto, tentacoli.

**Esito: a occhio non cambia niente.** Faccia, occhio, pelle, fiocco e tentacoli sono uguali. La differenza media è 0,4-1,5 livelli su 255, e 0,2-2% dei pixel cambiano di più di 10.

**L'unica differenza: le ciocche dei capelli da vicino, ed è un miglioramento.**
- Prima, senza mipmap, le righe fini della texture delle ciocche facevano un moiré a scalini (`capelli_ingrandimento.jpg`, a sinistra), che in movimento sfarfalla.
- Dopo sono lisce.
- Si vede soprattutto nella presa e all'oblò, cioè quando lei è più vicina.

**Fogli.**
- `foglio_prima_dopo.jpg`: per ogni posa, prima, dopo e la differenza moltiplicata per 4.
- `capelli_ingrandimento.jpg`: le ciocche della presa e dell'oblò ingrandite. Prima a sinistra, dopo a destra.
