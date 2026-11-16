# Collaudo 0.4.0, stato (aggiornato 16 novembre, notte)

Squadra collaudo. Candidata provata: `lavoro/candidata-0400c` 4b82e170. La quarta, 5c46d3f0, ha gli stessi file di gioco.
Il coordinatore ha chiesto i punti 1, 3, 2 e 4. Il punto 5 (giro di conferma) è tolto perché 1-4 sono passati senza difetti.
**Tutto chiuso, 0 difetti. Collaudo fermo per ordine dell'utente, finché non dice di ripartire.**

## Chiuso
- **Gommoni (su 0c177214)**: col riscaldamento del gioco, salendo sul 1° e sul 2° gommone, 0 surface, 0 draw e 0 specialization.
  Le 26 compilazioni erano della scena di prova. Numeri in `gommone_0c177214.txt`.
- **Punto 1, morte nelle pozze, 7 casi** (sud intera e breve, angoli 4_4 e 0_0, bordi ovest 0_2, nord 2_0 ed est 4_2). 0 difetti.
  - La camera non entra mai nel liquido, nel bordino, nel grigliato o in lei.
  - A 0,95 s è 28 cm sopra il pelo (22 cm sopra il grigliato).
  - Lei prende il 56 % dello schermo: braccio 36 %, tentacoli 28 %.
  - Fogli `fogli/morte_pozze_*.jpg`, numeri `morte_4b82e170*.txt`.
- **Punto 3, pelo della fossa**: il salto più grande è 2,6 mm per fotogramma, sia a ovest camminando che sulla spiaggia.
  Numeri in `pelo_fossa_4b82e170.txt`.
- **Punto 2, prima uscita**. Numeri in `prima_uscita_4b82e170.txt`.
  - Col renderer vero e la stanza riscaldata, nel fotogramma in cui lei esce: 0/0/0 dall'ingresso, nella presa e dopo la presa.
  - Il controllo senza riscaldamento della stanza dà 0/8/8.
  - Nessun lampo durante il riscaldamento.
  - Nel gioco vero il riscaldamento della stanza parte dopo F9, dopo la presa e dopo Continua.
- **Punto 4, luce fra le pozze**: sotto il grigliato si spegne; il grigliato e la passerella restano scuri.
  - Nota, non difetto per i criteri del punto 8: un chiarore rosa sfumato sulle pareti interne delle pozze e sul muro sud.
  - Fogli `fogli/luce_pozze_*.jpg`, numeri `luce_pozze_4b82e170.txt`.

## Strumenti
Gli strumenti sono in `godot/tests/collaudo/`: `pozze_morte`, `buio_fossa`, `prima_uscita`, `prima_uscita_b`, `luce_pozze` e `gommone_pipeline`.
Ognuno ha l'uso scritto in testa.
Ogni processo passa da `flock /home/user/tools/render.lock` e parte solo con MemAvailable ≥ 13,5 GB.
- Senza schermo: `godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/<script>.gd <argomenti>`
- Col renderer vero: `xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/<script>.gd <argomenti>`

Attenzione col renderer vero: l'immagine della vista può avere una scala diversa dalla finestra (qualità automatica). I pixel si campionano sull'immagine.
