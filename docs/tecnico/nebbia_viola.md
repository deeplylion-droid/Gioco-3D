# Nebbia viola nel gioco

La nebbia viola di NotHuman (dell'utente), valori B scelti il 29 ottobre (forza 1,2, fino a 4,5 m, si dirada da 1,8 m).
È nella 0.3.16 nell'infermeria, nella sala principale e nel tunnel dell'inseguimento.

- `godot/addons/grafica/nebbia_viola/nebbia_viola.gd` (`NebbiaViola`): una sola, la crea Grafica (`Grafica.nebbia_viola`).
  Il quad a schermo intero (nebbia_viola.gdshader) e il colore sullo schermo (colore_viola.gdshader).
  `quanto` sale e scende in 3 s; a 0 non si disegna.
- `zona_nebbia_viola.gd` (`ZonaNebbiaViola`): un'Area3D sul giocatore (strato 2), con i bordi sulle porte.
  Le zone sono queste:
  - infermeria: `InfermeriaGioco._nebbia_viola`;
  - sala principale: `SalaPrincipale._nebbia_viola`, dentro `NEBBIA_SALA`;
  - tunnel: `SalaSottomarino._nebbia_viola`, a tratti di 2 m dalla testa al portello.
- Ripartenza da un checkpoint o caricamento: se la camera salta oltre 3 m, la zona nuova vale subito. Una zona che nasce col giocatore dentro è subito piena.
- L'alone usa fino a 4 luci:
  - prima le luci del gruppo `nebbia_viola_alone` (la luce rosa di lei nel tunnel);
  - poi le lampade della zona più vicine davanti alla camera, entro 16 m;
  - quando le luci cambiano, l'alone passa dall'una all'altra in 0,5 s.
- Opzione "Nebbia viola" (in inglese "Purple fog"): accesa di serie e salvata con le altre impostazioni. Cambiata dentro una zona, la nebbia sale o scende piano.
- Qualità: con la nebbia "Semplice" (preset basso) 10 passi, altrimenti 20.
- Riscaldamento: `RiscaldamentoShader` compila il materiale e disegna il quad e il colore veri all'avvio. Accendendola non si compila niente (`test_riscaldamento_pipeline`, parte 5).
- Test: `tests/test_zona_nebbia.gd`, più la voce nelle opzioni in `test_menu` e `test_lingua`.
- Prove e scatti fuori dal gioco: `godot/proposte/nebbia_viola/` sul branch `lavoro/nebbia-viola`.
