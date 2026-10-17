# Correzioni dopo la prova della v0.3.4 (ambienti-1)

- `agnellino/agnellino_corsa.mp4`: l'agnellino della scala di C2 visto dal giocatore che lo insegue correndo. Il giocatore è quello vero, con la fisica. L'agnellino corre a 9 m/s, mentre il giocatore corre a 5,8. Sparisce solo quando nessun punto del corpo è in vista, cioè dietro l'angolo di C3. `agnellino_corsa_fotogrammi.jpg` contiene 8 fotogrammi dello stesso video.
- `pila/`: la pila di palloni a piramide, senza rete. Larga 7,5 m lungo il muro sud e 4,4 m lungo il muro est, dove più in là c'è la panca; alta circa 5,3 m. È fatta di palloni gonfi, mezzi sgonfi e sgonfi, posati con la fisica sopra i palloni di dentro e poi fissati.
  - 1: dall'entrata, verso est;
  - 2: da metà sala;
  - 3: da vicino;
  - 4: da vicino con la torcia.

Prove: `tests/test_agnellino.gd` (non lo si raggiunge e non lo si vede sparire) e `tests/percorri_risalita.gd`. Tutte le suite della CI passano.
