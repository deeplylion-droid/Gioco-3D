# Controllo di posizionamento severo: casi di ambienti-2

Dal rapporto del 22 ottobre (`docs/tecnico/posizionamento/rapporto.md`), 27 casi da correggere. Ognuno è in `godot/tests/posizionamento_eccezioni.json` come "da correggere": quando è corretto, il controllo lo dà come "eccezione non più trovata" e la riga si toglie dal file. Se secondo voi è voluto, scrivetelo al coordinatore col motivo: i "voluto" li decide l'utente.

Come si rifà il controllo sul vostro ramo, dopo aver unito lavoro/godot: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd` (sotto il render.lock; un minuto o due). Il significato dei problemi è in `LEGGIMI.md`.

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| tecnici | compenetra | `Tecnici/Ambienti/CameraOnde/CAMERA_pozzo` | 0.00, -2.32, 2.00 | passa dentro Sala/Piscina/sala_piscina_onde per 30 cm |
| tecnici | compenetra | `Tecnici/Ambienti/CameraOnde/PORTELLO` | 0.00, -2.32, 2.74 | il 70% dei suoi vertici è dentro Sala/Piscina/sala_piscina_onde (stato: tutto_visibile) |
| tecnici | compenetra | `Tecnici/Logica/SerrandaMagazzino/Barra` | -15.00, 0.02, 20.35 | passa dentro Tecnici/Logica/SerrandaMagazzino/Graybox/Pannello/@MeshInstance3D@7054 per 180 cm (stato: tutto_visibile) |
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
