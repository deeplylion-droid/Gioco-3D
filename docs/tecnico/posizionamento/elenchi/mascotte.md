# Controllo di posizionamento severo: casi di mascotte

Dal rapporto del 22 ottobre (`docs/tecnico/posizionamento/rapporto.md`), 3 casi da correggere. Ognuno è in `godot/tests/posizionamento_eccezioni.json` come "da correggere": quando è corretto, il controllo lo dà come "eccezione non più trovata" e la riga si toglie dal file. Se secondo voi è voluto, scrivetelo al coordinatore col motivo: i "voluto" li decide l'utente.

Come si rifà il controllo sul vostro ramo, dopo aver unito lavoro/godot: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd` (sotto il render.lock; un minuto o due). Il significato dei problemi è in `LEGGIMI.md`.

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_dx_lampadina` | -19.53, 5.39, 4.86 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_sx_lampadina` | -19.53, 5.39, 5.84 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/ManifestoJilly/Plane_001` | -19.97, 1.93, 14.24 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 189.0 cm) |
