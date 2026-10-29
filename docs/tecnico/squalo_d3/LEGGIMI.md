# Squalo: l'apertura nella sagoma a 6 s (D3 del collaudo del 25 ottobre)

Scatti dal motore (preset alto, interni nella posizione della sala, `tests/collaudo/giro_squalo.gd` di enigmi), 28-29 ottobre.

- `occhi_giocatore_6s.jpg`: dagli occhi del giocatore a 6,03 s, come nel collaudo: in alto a sinistra si vede il soffitto in uno spazio contornato dalla sagoma.
- `1_8m_indietro_6s.jpg`: lo stesso istante con la camera 1,8 m più indietro.
- `sequenza_5_6s.jpg`: 5,0 / 5,5 / 6,0 / 6,5 s.

Cosa ho controllato:

1. **Buchi nel modello**: `mostro_squalo_A_rig.glb`, unendo i vertici doppi, è chiuso. Gli unici bordi aperti sono minuscoli (le basi dei denti, 4 bordi l'uno, e due di 4-5 bordi sul corpo, di 1 cm). La gola (`gola_buio`) è chiusa e opaca.
2. **Facce viste dal rovescio** (una spalla che si piega): con la pelle disegnata da tutte e due le parti lo scatto è identico, pixel per pixel. Non è questo, e la modifica l'ho tolta.

Conclusione: non è un buco. È lo spazio fra il braccio alzato, che si piega sopra la testa, e la testa stessa, visto da sotto e da 23 cm mentre lo squalo si gira. Fa parte della posa. Per toglierlo bisogna cambiare la posa o il movimento di quel momento (per esempio il braccio meno alto), oppure la camera: è una scelta da chiedere all'utente.
