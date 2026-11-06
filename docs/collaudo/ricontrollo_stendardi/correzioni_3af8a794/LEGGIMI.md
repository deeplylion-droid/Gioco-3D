# Ricontrollo da vicino delle correzioni degli stendardi (enigmi, 6 novembre)

- Branch ricontrollato: `lavoro/stendardi-inseguimento`, punta `3af8a794`. Le correzioni sono nel commit `28cb5a9a`.
- Lo strumento è `godot/tests/collaudo/ricontrollo_stendardi.gd`, coi gruppi `vicino`, `fessura` e `giro`. Con le
  correzioni i nodi alle travi sono diventati golfari, quindi le viste puntano all'occhiello.
- Le misure le ho prese sulla GLB della punta (`stendardi.glb`), separando le mesh in pezzi collegati e cercando i
  triangoli che si intersecano.

## Esito: non passa

### Difetto nuovo, sui 4 stendardi: la stoffa è staccata dalla piega

- La piega sopra il bastone (`stendardo_N_risvolto`) finisce con un bordo dritto e orizzontale, a 7 cm sotto la cima
  del bastone.
- La cima della stoffa invece si affloscia fra una molletta e l'altra, come prima della correzione. Tocca il bordo della
  piega solo ai due angoli e scende fino a 8 cm più in basso.
- La cima della stoffa sta anche davanti al piano del bastone: 2,5 cm sullo stendardo 1, 0,7 sul 2, 2,2 sul 3, 1,3 sul 4.
- Risultato: fra la piega e la stoffa c'è una fessura dove si vede il buio dietro (fogli 4 e 5).
- Le mollette stringono solo la piega. Sullo stendardo 1 la stoffa passa a 1 cm dalle mollette: la stoffa non è
  attaccata a niente.
- Dagli occhi, nelle vasche, non si nota (foglio 8, ritaglio ingrandito 2 volte). Da vicino si vede benissimo.
- Correzione possibile: la stoffa deve continuare dalla piega, con la cima dritta che parte dal bordo della piega,
  oppure la piega deve seguire la cima della stoffa. Le mollette devono stringere i due strati.

### Difetti piccoli, sui 4 stendardi

- **Codino nella molletta.** Il codino della corda "a" (5 cm) scende dentro la prima molletta (`molletta0`) per 1,3 cm.
  Quella molletta è proprio dove finiscono i giri attorno al bastone (foglio 5, "st1 molletta0 di lato").
- **Piega dentro le ganasce.** Le due falde della piega passano dentro le ganasce delle mollette, a ±0,7 cm dal centro,
  invece che nella bocca, che sta a ±0,25 cm. Anche la molla di ferro attraversa le falde. Da fuori quasi non si vede,
  ma è una compenetrazione.

### Va bene

- **Giri al bastone e nodo** (foglio 5).
  - Ci sono due giri, un nodo e un codino, e tutti i pezzi della corda sono attaccati fra loro: nessun pezzo resta
    staccato di più di 2 mm.
  - I giri sono stretti e affondano 3,5 mm nel bastone. Da vicino sembrano legati stretti, quindi per me vanno bene.
- **Golfari** (fogli 6 e 7).
  - Il gambo entra nella trave per 1,2 cm.
  - L'occhiello sta sotto la trave, e il nodo della corda gira attorno all'occhiello.
  - La corda che scende entra nel nodo.
- **Mollette**: hanno la forma vera, con bracci, bocca, manico e molla.

## Fogli

4. `4_mollette_e_stoffa.jpg`: la fessura fra la piega e la stoffa, sui quattro stendardi.
5. `5_capi_del_bastone.jpg`: i giri, il nodo, il codino che entra nella molletta 0, e la fessura.
6. `6_golfari.jpg`: i golfari da sotto, di traverso e lungo la trave.
7. `7_golfari_da_vicinissimo.jpg`: il gambo nella trave, l'occhiello e il nodo.
8. `8_dagli_occhi_ritaglio.jpg`: dalle vasche 1 e 2, ritaglio ingrandito 2 volte: la fessura non si nota.
