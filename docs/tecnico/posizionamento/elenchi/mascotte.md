# Controllo di posizionamento severo: casi di mascotte

Dal rapporto del 22 ottobre (`docs/tecnico/posizionamento/rapporto.md`), 3 casi da correggere. Ognuno è in `godot/tests/posizionamento_eccezioni.json` come "da correggere": quando è corretto, il controllo lo dà come "eccezione non più trovata" e la riga si toglie dal file. Se secondo voi è voluto, scrivetelo al coordinatore col motivo: i "voluto" li decide l'utente.

Come si rifà il controllo sul vostro ramo, dopo aver unito lavoro/godot: `godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd` (sotto il render.lock; un minuto o due). Il significato dei problemi è in `LEGGIMI.md`.

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_dx_lampadina` | -19.53, 5.39, 4.86 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/InsegnaJilly/lampada_sx_lampadina` | -19.53, 5.39, 5.84 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a più di 5 m) |
| mascotte | staccato | `Mascotte/ManifestoJilly/Plane_001` | -19.97, 1.93, 14.24 | non tocca niente entro 5 mm (è a meno di 5 cm da qualcosa, ma non appoggia; sotto, il primo appoggio è a 189.0 cm) |

## Controllo del 22 ottobre sera: 2 casi in più

Dopo il collaudo il controllo guarda meglio: "staccato" misura le mesh vere e non più le collisioni del gioco (spesso più grandi); un gruppo di oggetti che si toccano solo fra loro (la lampada e il suo vetro, una pila di scatoloni) deve toccare un muro, il pavimento o un pezzo grande, e il caso è sull'oggetto più in basso del gruppo; i dettagli della sala in MultiMesh si controllano uno per uno. Tutti "da correggere".

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| mascotte | staccato | `Mascotte/ManifestoJilly/manifesto` | -19.93, 1.39, 13.95 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 89.3 cm. Con lui, staccati insieme, 2 oggetti che si reggono solo fra loro: manifesto_001, Plane. |
| mascotte | staccato | `Mascotte/TargaJilly/targa` | -3.01, 0.62, 10.00 | tocca solo altri oggetti che non toccano un muro, il pavimento o un sostegno fisso: sotto, il primo appoggio fuori dal gruppo è a 42.5 cm. |

## La medusa in posa, 22 ottobre sera

Le mesh con lo scheletro ora si misurano nella posa del momento (prima in quella di riposo). Da correggere, o da proporre all'utente come voluti se lei deve stare così:

| Zona | Problema | Nodo | Posizione | Dettaglio |
|---|---|---|---|---|
| sala | compenetra | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa` | 0.00, 0.50, 11.26 | il 35% dei suoi vertici è dentro Sala/VascaCentrale/sala_vasca_centrale |
| sala | compenetra | `Vasca/Medusa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Interno` | 0.00, 0.15, 11.19 | il 77% dei suoi vertici è dentro Sala/VascaCentrale/sala_vasca_centrale |
| sala | ingombro | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | -15.50, 0.00, -7.75 | nello spazio di chi cammina, all'altezza delle gambe: a meno di 10 cm dal giocatore, fra 0.35 e 0.59 m sopra il pavimento (10 celle da 25 cm) (pavimento a y -0.00), senza collisione (si attraversa) (stato: lei_fossa) |
| sala | compenetra | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa_Tentacoli` | -13.24, -0.06, -6.85 | passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 116 cm (stato: lei_fossa) |
| sala | compenetra | `Gioco/LeiSbuca/MedusaFossa/Modello/Medusa_Scheletro/Skeleton3D/Medusa` | -13.82, -0.28, -6.90 | passa dentro Sala/AreaBimbi/sala_fossa_bimbi per 41 cm (stato: lei_fossa) |
