# Riscontri della 0.3.16: agnellini e squalo (30 ottobre)

Branch `lavoro/bambini-squalo-0317`.

1. **Agnellino del tunnel** (BambinoGalleria).
   - Prima spariva a metà della galleria di servizio, che è dritta e illuminata: chi gli correva dietro e ci entrava vedeva che non c'era più.
   - Ora corre per tutta la galleria ed esce dalla bocca in fondo. Sparisce solo dopo, dietro la testa della bocca, fuori dall'inquadratura e coperto dal muro.
   - Se lo si guarda sempre, corre via sulla banchina dopo il crollo e lì resta finché non lo si perde di vista (come gli altri bambini).
   - Fogli dal motore, dagli occhi di chi gli corre dietro allo sprint e si ferma alla bocca a guardare dentro:
     - `1_tunnel_corsa_in_galleria.jpg`: un fotogramma ogni 10;
     - `1_tunnel_sparisce_fotogrammi.jpg`: tutti i fotogrammi intorno a quando sparisce, al 283. Gira dietro lo spigolo al 277-278.
   - Test in CI: `test_bambini_sfuggita`, due inseguimenti.
2. **Agnellino della scala di C2** (AgnellinoScala). Torna la girata della 0.3.15: si volta di scatto mentre parte di corsa.
   - Foglio `2_agnellino_c2_girata_prima_dopo.jpg`, fotogrammi ogni 0,1 s da quando scappa. La 0.3.16 a 1,1 s si girava ancora sul posto; ora a 0,6 s corre già via.
3. **Squalo all'inizio**, la girata verso la porta.
   - Prima le braccia si raccoglievano in un nodo fermo davanti al petto e la pinna dell'avambraccio spuntava sotto.
   - Ora il braccio alzato resta accanto al muso, con lo spazio fra braccio e testa della scelta A. L'altro pende piegato. Dondolano a ogni passo e restano un po' indietro rispetto al corpo che gira.
   - Vicino al muro nord la mano si ritira: `test_interni` controlla i polsi, che arrivano a 18 cm dal muro.
   - Render del modello vero (Blender, Cycles), da sopra e dagli occhi del giocatore: `3_squalo_girata_prima_dopo.jpg`. Di lato: `3_squalo_girata_lato_prima.jpg` e `3_squalo_girata_lato_dopo.jpg`.
