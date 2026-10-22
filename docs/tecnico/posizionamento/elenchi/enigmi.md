# Controllo di posizionamento severo: casi di enigmi

Dal rapporto del 22 ottobre (`docs/tecnico/posizionamento/rapporto.md`), 14 casi da correggere. Ognuno è in `godot/tests/posizionamento_eccezioni.json` come "da correggere": quando è corretto, il controllo lo dà come "eccezione non più trovata" e la riga si toglie dal file. Se secondo voi è voluto, scrivetelo al coordinatore col motivo: i "voluto" li decide l'utente.

Come si rifà il controllo sul vostro ramo, dopo aver unito lavoro/godot: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd` (sotto il render.lock; un minuto o due). Il significato dei problemi è in `LEGGIMI.md`.

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| risalita | compenetra | `Risalita/@Node3D@841/Mesh_0` | -37.77, -3.20, 37.35 | passa dentro Risalita/@MeshInstance3D@764 per 20 cm |
| sala | compenetra | `Gioco/EnigmaAcquari/Valvola/Scarico` | 9.07, 0.00, -19.74 | passa dentro Gioco/EnigmaAcquari/Valvola/Modello/Mesh_0 per 16 cm |
| sala | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/GuidaDestra` | 19.50, 0.00, -11.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (5 celle da 25 cm), senza collisione (si attraversa) |
| sala | ingombro | `Gioco/EnigmaAcquari/LampadePortone/Spente/GuidaSinistra` | 19.50, 0.00, -18.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.35 e 2.00 m sopra il pavimento (5 celle da 25 cm), senza collisione (si attraversa) |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_staffa1` | -2.26, -7.02, 49.86 | passa dentro Tecnici/Ambienti/Raccordo/lampada_rc1 per 23 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/RACCORDO_scale` | 3.83, -6.20, 46.31 | passa dentro Tecnici/Ambienti/SalaPompe/SALA_tubi per 50 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1` | -2.31, -6.90, 49.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_0 per 34 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1` | -2.18, -6.94, 49.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_1 per 20 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1_vetro` | -2.29, -6.90, 49.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_0 per 26 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_rc1_vetro` | -2.18, -6.94, 49.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_r1_1 per 25 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b` | -15.92, 2.20, 34.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_0 per 34 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b` | -15.86, 2.16, 34.86 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_1 per 24 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b_vetro` | -15.89, 2.20, 34.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_0 per 27 cm |
| tecnici | compenetra | `Tecnici/Ambienti/Raccordo/lampada_t7_c3b_vetro` | -15.83, 2.16, 34.87 | passa dentro Tecnici/Ambienti/Raccordo/ArredoRisalita/G_tubi_c3_1 per 24 cm |
