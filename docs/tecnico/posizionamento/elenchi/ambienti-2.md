# Controllo di posizionamento severo: casi di ambienti-2

Dal rapporto del 22 ottobre (`docs/tecnico/posizionamento/rapporto.md`), 27 casi da correggere. Ognuno è in `godot/tests/posizionamento_eccezioni.json` come "da correggere": quando è corretto, il controllo lo dà come "eccezione non più trovata" e la riga si toglie dal file. Se secondo voi è voluto, scrivetelo al coordinatore col motivo: i "voluto" li decide l'utente.

Come si rifà il controllo sul vostro ramo, dopo aver unito lavoro/godot: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd` (sotto il render.lock; un minuto o due). Il significato dei problemi è in `LEGGIMI.md`.

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| tecnici | compenetra | `Tecnici/Ambienti/CameraOnde/CAMERA_pozzo` | 0.00, -2.32, 2.00 | passa dentro Sala/Piscina/sala_piscina_onde per 30 cm |
| torre | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_0` | 54.72, -21.91, -16.41 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_1 per 169 cm |
| torre | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_1` | 54.72, -21.89, -13.60 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_scolo_0 per 170 cm |
| torre | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_2` | 67.02, -24.90, -25.28 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_2 per 182 cm |
| torre | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_3` | 63.92, -24.90, -25.28 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_scolo_1 per 117 cm |
| torre | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_4` | 66.78, -27.92, -3.60 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_3 per 17 cm |
| torre | compenetra | `SalaInseguimento/InseguimentoMobili/ins_paratia_5` | 72.22, -27.93, -6.60 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_scolo_2 per 148 cm |
| torre | compenetra | `TorreScivoli/torre_tubo_inseguimento` | 40.82, -18.66, -17.40 | passa dentro SalaInseguimento/InseguimentoTubi/ins_A_tubo_0 per 11 cm |
| torre | estremita_libera | `SalaInseguimento/Luci/@Node3D@5264/det_tubo_verticale_3m` | 40.49, -25.00, -28.50 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| torre | estremita_libera | `SalaInseguimento/Luci/@Node3D@5264/det_tubo_verticale_3m` | 40.49, -22.00, -28.50 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| torre | staccato | `FondoPozzo` | 31.00, -25.00, -15.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 297.5 cm) |
| torre | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5156` | 40.55, -16.00, -25.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 333.5 cm) |
| torre | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5158` | 77.85, -22.00, -10.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| torre | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5160` | 60.00, -18.00, -31.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| torre | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5162` | 50.00, -26.00, 1.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| torre | staccato | `SalaInseguimento/Luci/@MeshInstance3D@5164` | 70.00, -14.00, 1.85 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5236/POMPA_2` | 54.40, -30.27, -23.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5242/det_griglia_caduta` | 73.60, -28.96, -21.80 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5244/SCRIVANIA` | 48.00, -19.61, -0.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5245/SEDIA` | 48.20, -19.52, -1.15 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5248/det_vetri_rotti_1` | 51.67, -20.00, -0.83 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5249/det_foglio_2` | 49.40, -19.98, -1.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5252/det_tubo_valvola_T` | 40.58, -29.42, -12.40 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 360.0 cm) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5270/det_corda_pendente_2` | 74.01, -21.70, 0.90 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@5271/det_corda_rotolo` | 41.00, -29.94, -6.20 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.9 cm) |
| torre | ingombro | `SalaInseguimento/Luci/@MeshInstance3D` (anello di led della paratia giusta, vasca 1) | 54.50, -22.58, -16.50 | stato inseguimento_dopo, paratia alzata: l'anello è figlio di Luci e non del pannello, quindi resta a mezz'aria nel passaggio verso il tubo (fra 0,60 e 1,05 m, dove si passa accovacciati). Va legato al pannello |
| torre | ingombro | `SalaInseguimento/Luci/@MeshInstance3D` (anello, vasca 2) | 67.00, -25.58, -25.25 | come sopra |
| torre | ingombro | `SalaInseguimento/Luci/@MeshInstance3D` (anello, vasca 3) | 67.00, -28.58, -4.00 | come sopra (fra 0,60 e 1,70 m) |

Dal 22 ottobre sera il controllo sa dove si sta accovacciati per forza (`SalaInseguimento.in_tubo`, la stessa funzione del gioco): lì lo spazio libero da controllare arriva a 1,05 m, l'altezza del giocatore accovacciato, e non a 2 m. Così i 9 ingombri di paratie e scoli nello stato `inseguimento_dopo` non ci sono più; restano solo i tre anelli qui sopra.

## Controllo del 22 ottobre sera: 96 casi in più

Dopo il collaudo il controllo guarda meglio: "staccato" misura le mesh vere e non più le collisioni del gioco (spesso più grandi); un gruppo di oggetti che si toccano solo fra loro (la lampada e il suo vetro, una pila di scatoloni) deve toccare un muro, il pavimento o un pezzo grande, e il caso è sull'oggetto più in basso del gruppo; i dettagli della sala in MultiMesh si controllano uno per uno. Tutti "da correggere".

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| sala | compenetra | `Sala/Dettagli/det_barchetta_0` | 13.10, 0.11, 18.27 | il 73% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_34 |
| sala | compenetra | `Sala/Dettagli/det_carta_accartocciata_1_3` | -18.00, 0.04, 19.38 | il 97% dei suoi vertici è dentro Sala/AngoloScatoloni/scat_2_0_0 |
| sala | compenetra | `Sala/Dettagli/det_carta_accartocciata_3_10` | -16.77, 0.06, 18.37 | il 63% dei suoi vertici è dentro Sala/AngoloScatoloni/scat_3_1_0 |
| sala | compenetra | `Sala/Dettagli/det_ciabatta_6` | -4.09, 0.03, 12.80 | il 100% dei suoi vertici è dentro Sala/VascaCentrale/sala_vasca_colonnina_7 |
| sala | compenetra | `Sala/Dettagli/det_foglio_1_13` | 13.03, 0.01, 17.73 | il 29% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_29 |
| sala | compenetra | `Sala/Dettagli/det_foglio_1_14` | 12.38, 0.01, 17.81 | passa dentro Sala/AngoloPalloni/pallone_29 per 3 cm |
| sala | compenetra | `Sala/Dettagli/det_foglio_1_19` | 5.95, -0.03, -12.77 | il 29% dei suoi vertici è dentro Sala/Piscina/sala_piscina_onde |
| sala | compenetra | `Sala/Dettagli/det_foglio_1_27` | 1.70, -0.71, -8.66 | il 42% dei suoi vertici è dentro Sala/Piscina/sala_piscina_onde |
| sala | compenetra | `Sala/Dettagli/det_foglio_1_28` | -4.56, -1.97, -1.13 | il 35% dei suoi vertici è dentro Sala/Piscina/sala_piscina_onde |
| sala | compenetra | `Sala/Dettagli/det_foglio_2_37` | -0.98, -0.33, -10.92 | il 23% dei suoi vertici è dentro Sala/Piscina/sala_piscina_onde |
| sala | compenetra | `Sala/Dettagli/det_foglio_2_7` | 14.88, 0.02, 18.67 | il 45% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_dentro_12 |
| sala | compenetra | `Sala/Dettagli/det_foglio_4_20` | 0.94, -1.97, -1.24 | il 23% dei suoi vertici è dentro Sala/Piscina/sala_piscina_onde |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_1_0` | -19.34, 0.02, 19.21 | passa dentro Sala/AngoloScatoloni/scat_0_0_0 per 5 cm |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_1_15` | 14.90, 0.02, 15.09 | passa dentro Sala/AngoloPalloni/pallone_65 per 6 cm |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_3_13` | 12.01, 0.02, 18.58 | il 60% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_116 |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_3_5` | 13.22, 0.02, 19.41 | passa dentro Sala/AngoloPalloni/pallone_26 per 7 cm |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_3_5` | 13.52, 0.02, 19.19 | passa dentro Sala/AngoloPalloni/pallone_91 per 6 cm |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_3_8` | -17.61, 0.02, 18.62 | passa dentro Sala/AngoloScatoloni/scat_2_1_0 per 5 cm |
| sala | compenetra | `Sala/Dettagli/det_paletta_1` | -18.63, 0.04, 18.67 | il 50% dei suoi vertici è dentro Sala/AngoloScatoloni/scat_1_1_0 |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_1_17` | -8.81, 0.01, 1.47 | il 21% dei suoi vertici è dentro Sala/TorreScivoli/arrivo_bordi |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_2_5` | 12.97, 0.01, 19.66 | il 100% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_26 |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_4_2` | 12.66, 0.01, 19.22 | il 36% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_26 |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_5_21` | 12.88, 0.01, 18.00 | il 100% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_29 |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_6_20` | -8.85, 0.01, -2.34 | il 21% dei suoi vertici è dentro Sala/TorreScivoli/arrivo_bordi |
| sala | compenetra | `Sala/Dettagli/det_secchiello_1` | 14.19, 0.08, 19.57 | il 33% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_dentro_6 |
| sala | compenetra | `Sala/Dettagli/det_vetri_rotti_3_3` | 18.49, 0.00, 16.15 | il 23% dei suoi vertici è dentro Sala/AngoloPalloni/pallone_28 |
| sala | estremita_libera | `Sala/Dettagli/det_tubi_paralleli_2m_0` | -19.88, 3.09, 1.19 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubi_paralleli_2m_10` | 14.85, 3.18, 19.88 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubi_paralleli_2m_10` | 16.85, 3.18, 19.88 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubi_paralleli_2m_4` | -19.88, 3.09, -8.81 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubi_paralleli_2m_5` | -19.87, 3.46, -17.88 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubi_paralleli_2m_7` | -19.87, 3.46, -23.88 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubi_paralleli_2m_8` | -14.32, 3.16, 19.88 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_10cm_2m_0` | 19.89, 3.59, 8.47 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_10cm_2m_0` | 19.89, 3.59, 10.47 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_10cm_2m_1` | 19.89, 3.24, 13.74 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_10cm_2m_12` | -12.58, 3.03, 19.90 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_10cm_2m_4` | -19.90, 3.07, -9.32 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_10cm_2m_7` | -19.89, 3.07, -17.32 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_10cm_2m_8` | -2.58, 3.03, 19.90 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_0` | -19.87, 3.05, 12.45 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_10` | 5.81, 3.00, 19.87 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_11` | 19.86, 3.07, 5.78 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_11` | 19.86, 3.07, 7.78 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_12` | -12.30, 3.36, -23.87 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_14` | -6.30, 3.36, -23.87 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_4` | -19.87, 3.05, 2.45 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_5` | 15.29, 3.59, -23.87 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_6` | 19.29, 3.59, -23.87 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | estremita_libera | `Sala/Dettagli/det_tubo_muro_16cm_2m_7` | 13.81, 3.00, 19.87 | un capo del tubo non è collegato a niente entro 1 cm (né muro, pavimento, soffitto, né un altro tubo o un macchinario) |
| sala | ingombro | `Sala/Dettagli/det_cassetta_aperta_0` | -1.50, 0.00, 19.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.72 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) |
| sala | ingombro | `Sala/Dettagli/det_cassetta_aperta_1` | 19.50, 0.00, 12.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.95 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) |
| sala | ingombro | `Sala/Dettagli/det_cassetta_aperta_3` | -13.25, 0.00, 19.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.89 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) |
| sala | ingombro | `Sala/Dettagli/det_cassetta_aperta_4` | -11.50, 0.00, -23.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.76 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) |
| sala | ingombro | `Sala/Dettagli/det_cassetta_aperta_5` | 19.50, 0.00, -5.50 | nello spazio di chi cammina, all'altezza della testa: a meno di 10 cm dal giocatore, fra 0.71 e 2.00 m sopra il pavimento (1 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) |
| sala | ingombro | `Sala/Dettagli/det_pannello_lamiera_7` | -3.50, 0.00, 16.75 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.36 m sopra il pavimento (2 celle da 25 cm) (pavimento a y 0.00), senza collisione (si attraversa) |
| sala | staccato | `Sala/Dettagli/det_alghe_secche_mucchio_1_11` | -1.87, -2.06, 2.26 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 8.0 cm) |
| sala | staccato | `Sala/Dettagli/det_alghe_secche_mucchio_2_8` | 0.35, -2.06, 3.56 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 10.1 cm) |
| sala | staccato | `Sala/Dettagli/det_barchetta_7` | 4.55, 0.11, 12.95 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| sala | staccato | `Sala/Dettagli/det_carta_accartocciata_3_11` | -15.80, 0.06, 18.65 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_carta_accartocciata_3_21` | 5.42, 0.06, 15.43 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_carta_accartocciata_3_24` | -9.58, 0.06, 17.98 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_foglio_1_10` | 4.50, 0.01, 12.70 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_foglio_2_10` | -12.48, 0.02, -22.56 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_foglio_3_28` | 5.43, 0.03, 17.25 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_griglia_caduta_6` | 11.13, 0.04, 14.35 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_maschera_sub_0` | -19.33, 0.08, 4.66 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.5 cm) |
| sala | staccato | `Sala/Dettagli/det_pannello_lamiera_7` | -3.14, 0.19, 17.17 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.1 cm) |
| sala | staccato | `Sala/Dettagli/det_pesce_gomma_9` | -17.67, 0.03, 4.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 0.6 cm) |
| sala | staccato | `Sala/Dettagli/det_pistola_acqua_11` | 8.89, 0.08, -21.26 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 2.1 cm) |
| tecnici | staccato | `Tecnici/Ambienti/CameraOnde/lampada_l2` | -2.06, -6.05, 9.36 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 288.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l2_vetro_spento. |
| tecnici | staccato | `Tecnici/Ambienti/CameraOnde/lampada_l3` | -2.06, -6.05, 13.36 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 288.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l3_vetro. |
| tecnici | staccato | `Tecnici/Ambienti/CameraOnde/lampada_l4` | 2.06, -6.05, 17.36 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 288.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l4_vetro. |
| tecnici | staccato | `Tecnici/Ambienti/CameraOnde/plafoniera_0` | -0.60, -4.92, 5.36 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 408.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_0_tubi. |
| tecnici | staccato | `Tecnici/Ambienti/CameraOnde/plafoniera_1` | -0.60, -4.92, 11.36 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 408.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: neon_1_tubo_sfarfalla. |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/LEVA` | 5.10, -5.04, 47.46 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 30.5 cm) |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/PORTA_ponte` | -1.40, -7.95, 47.61 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 1.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: PORTA_ponte_maniglione. |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/QUADRO_elettrico` | -3.51, -7.27, 32.46 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 90.0 cm) |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/QUADRO_strumenti` | -3.61, -7.27, 37.06 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 130.0 cm) |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/lampada_l1` | 3.20, -5.75, 29.80 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 318.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l1_vetro. |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/lampada_l2` | -1.40, -5.95, 47.52 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 298.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l2_vetro. |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/lampada_l3` | 8.06, -6.65, 35.46 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 229.3 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l3_vetro. |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/lampada_l4` | -3.66, -5.85, 39.86 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 308.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l4_vetro. |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/lampada_l5` | 8.06, -6.65, 44.46 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 228.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l5_vetro. |
| tecnici | staccato | `Tecnici/Ambienti/SalaPompe/lampada_l6` | -2.60, -6.05, 29.80 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 288.1 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: lampada_l6_vetro_spento. |
| tecnici | staccato | `Tecnici/LampeggianteParatia1/@MeshInstance3D@1115` | 2.12, -6.05, 17.76 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 289.0 cm. Con lui, staccati insieme, 1 oggetti che si reggono solo fra loro: @MeshInstance3D@1116. [modello: tecnici.tscn] |
| torre | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_0` | 54.72, -19.90, -16.40 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 77.0 cm) (stato: inseguimento_dopo) |
| torre | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_1` | 54.72, -19.90, -13.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 77.0 cm) (stato: inseguimento_dopo) |
| torre | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_2` | 67.00, -22.90, -25.28 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 77.0 cm) (stato: inseguimento_dopo) |
| torre | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_3` | 64.00, -22.90, -25.28 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 77.0 cm) (stato: inseguimento_dopo) |
| torre | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_4` | 66.78, -25.90, -3.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 77.0 cm) (stato: inseguimento_dopo) |
| torre | staccato | `SalaInseguimento/InseguimentoMobili/ins_paratia_5` | 72.22, -25.90, -6.60 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 77.0 cm) (stato: inseguimento_dopo) |
| torre | staccato | `SalaInseguimento/Luci/@Node3D@7198/TURBINA_1` | 75.40, -28.25, -19.00 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) [modello: sala_inseguimento.tscn] |
| torre | staccato | `TorreProp/prop_paperella_gigante_1` | 38.41, -14.73, -22.41 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| torre | staccato | `TorreProp/prop_paperella_gigante_2` | 38.41, -5.72, -7.59 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |
| torre | staccato | `TorreProp/prop_salvagente_nave_1` | 23.59, -8.92, -7.59 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 1.0 cm) |

## Acquari, 22 ottobre sera: 22 casi in più

Il controllo prendeva per acqua tutto quello che aveva "acqua" nel percorso, anche AcquarioGiallo, AcquarioBlu e AcquarioMisto: basi, coperchi, tiranti e vetri non si controllavano. Ora sì. Tutti "da correggere".

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| sala | compenetra | `Sala/Dettagli/det_barchetta_4` | 5.47, 0.10, -23.40 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| sala | compenetra | `Sala/Dettagli/det_carta_accartocciata_1_4` | 12.96, 0.04, -21.39 | il 67% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_carta_accartocciata_1_6` | 5.10, 0.04, -22.64 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| sala | compenetra | `Sala/Dettagli/det_carta_accartocciata_3_31` | 11.27, 0.06, -21.76 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_foglio_1_26` | 11.49, 0.01, -21.05 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_foglio_2_14` | 14.93, 0.02, -22.32 | il 94% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/Zoccolo |
| sala | compenetra | `Sala/Dettagli/det_foglio_2_15` | 13.74, 0.02, -21.94 | il 23% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_foglio_2_15` | 13.74, 0.02, -21.92 | il 68% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Allacci/FlangiaGamba |
| sala | compenetra | `Sala/Dettagli/det_foglio_2_33` | 16.54, 0.02, -21.33 | il 58% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base |
| sala | compenetra | `Sala/Dettagli/det_foglio_3_9` | 17.56, 0.02, -21.53 | il 84% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base |
| sala | compenetra | `Sala/Dettagli/det_foglio_4_7` | 11.35, 0.04, -22.01 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_griglia_caduta_4` | 3.84, 0.04, -22.40 | passa dentro Gioco/EnigmaAcquari/AcquarioBlu/Allacci/Zoccolo per 53 cm |
| sala | compenetra | `Sala/Dettagli/det_maschera_sub_13` | 6.17, 0.07, -21.46 | il 87% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_2_16` | 10.48, 0.02, -20.50 | il 55% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_mucchio_piastrelle_2_7` | 10.08, 0.01, -22.64 | il 29% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_pannello_lamiera_2_0` | 17.70, 0.06, -23.00 | il 55% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Base/cilindro_base |
| sala | compenetra | `Sala/Dettagli/det_pesce_gomma_1` | 11.00, 0.03, -23.16 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_1_20` | 10.17, 0.01, -21.11 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_1_6` | 12.30, 0.01, -22.64 | il 100% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioMisto/Base/cilindro_base_bassa |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_3_12` | 4.58, 0.01, -22.34 | il 50% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
| sala | compenetra | `Sala/Dettagli/det_piastrella_rotta_5_8` | 18.95, 0.01, -22.46 | il 40% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioGiallo/Allacci/FlangiaSpina |
| sala | compenetra | `Sala/Dettagli/det_vetri_rotti_1_6` | 4.89, 0.00, -22.05 | il 65% dei suoi vertici è dentro Gioco/EnigmaAcquari/AcquarioBlu/Base/cilindro_base |
