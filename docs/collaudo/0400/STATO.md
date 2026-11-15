# Collaudo 0.4.0, stato (aggiornato 15 novembre, 22:50 UTC)

Squadra collaudo. Candidata in prova: `lavoro/candidata-0400c` 4b82e170 (la quarta, 5c46d3f0, ha gli stessi file di gioco).
Ordine del coordinatore: punti 1, 3, 2, 4; il punto 5 (giro di conferma) è tolto se 1-4 passano senza difetti.

## Chiuso
- **Gommoni (su 0c177214)**: col riscaldamento del gioco 0 surface, 0 draw, 0 specialization salendo sul 1° e sul 2° gommone.
  Le 26 erano della scena di prova. Numeri: `gommone_0c177214.txt`.
- **Punto 1, morte nelle pozze, 4 casi su 7** (sud intera, sud breve, angolo 4_4 lato sud, angolo 0_0 lato ovest): nessun difetto.
  Camera mai dentro il liquido, il bordo o lei. A 0,95 s è 24-28 cm sopra il pelo. Lei prende il 56 % dello schermo
  (braccio 36 %, tentacoli 28-29 %), nessun oggetto da solo oltre metà.
  Fogli: `fogli/morte_pozze_*.jpg`. Numeri: `morte_4b82e170.txt`, `morte_4b82e170_fotogrammi.txt`.

## In corso o da fare
- Punto 1, i tre bordi (ovest 0_2, nord 2_0, est 4_2): `pozze_morte.gd <cartella> bordo_ovest_0_2,bordo_nord_2_0,bordo_est_4_2`.
- Punto 3, pelo della fossa (ovest e spiaggia): `buio_fossa.gd ovest` e `spiaggia`, senza schermo. Stampa "il salto più grande del pelo in un fotogramma".
  Nel primo giro nessun salto sopra 1 cm; il pelo sale da 0,349 a 0,380 (ovest) e da 0,322 a 0,379 (spiaggia).
- Punto 2, prima uscita:
  - (a) `prima_uscita_b.gd con|senza`, renderer vero, stanza da sola col riscaldamento del gioco e della stanza;
  - (b) `prima_uscita.gd`, senza schermo, gioco vero: il riscaldamento della stanza parte dopo F9, presa e Continua?
  - La sala ridotta col renderer vero va fuori memoria.
- Punto 4, luce fra le pozze: `luce_pozze.gd <cartella>`, renderer vero.
  Nel primo giro (interrotto, troppo lento) la luce sotto il grigliato fra le pozze schiariva il grigliato in 0,1-0,5 % dei pixel (+0,05-0,08).

## Come si lanciano
Gli strumenti sono in `godot/tests/collaudo/` su questo branch (nel worktree in `godot/tests/cz/`).
Ogni processo passa da `flock /home/user/tools/render.lock`, e parte solo con MemAvailable ≥ 13,5 GB.
- Senza schermo: `godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/<script>.gd <argomenti>`
- Col renderer vero: `xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver vulkan --resolution 960x540 --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/<script>.gd <argomenti>`
- Le code sono script bash lanciati con `nohup setsid`. I log vanno in `/home/user/collaudo_log/c40c/`.
