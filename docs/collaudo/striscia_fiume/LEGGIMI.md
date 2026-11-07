# La riga chiara a pelo d'acqua nel fiume lento: 0.3.20 contro 0.3.21 (grafica, 7 novembre)

La riga l'ha vista mascotte nel collaudo finale (`lavoro/collaudo-0321-mascotte-2` 40fe3475).

**Risultato: c'era già nella 0.3.20, uguale.** Non è nuova della 0.3.21.

Come ho fatto il confronto:
- Stessi punti e stesse camere del collaudo di mascotte (`godot/tests/collaudo/scatti_striscia_fiume.gd`, preso da
  `collaudo_0321_fiume.gd`), con luci del blackout, preset alto, Vulkan software 1280x720.
- I punti: Giusto1 a 37 m, Giusto2 a 1 m, i tre rami sbagliati a 25 m; avanti, a sinistra e a destra.
- Le due versioni: main ca6a3c19 (0.3.20) e la candidata dc83169e (0.3.21).
- Nel foglio gli scatti sono schiariti (gamma 1,9).

Cosa si vede in `confronto_0320_0321.jpg`:
- La riga è nello stesso posto e con la stessa forma in tutte e due le versioni.
- Fra le due versioni i 15 scatti differiscono di 0,1-1 % RMSE, che è il rumore della nebbia e dei riflessi.
