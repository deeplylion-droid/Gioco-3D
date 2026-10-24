# Poster di Jilly rovinati (24 ottobre)

Richiesta dell'utente: "provare a bruciare e scarabocchiare e rovinare molto i poster di Jilly che ci sono appesi alle pareti, tipo nella stanza del bagnino". Ognuno è rovinato in modo diverso, e gli scarabocchi sono solo disegni, senza scritte. Le parti bruciate, strappate o tagliate hanno l'alfa vero: si vede il muro, il sughero o il pannello sotto. I poster restano attaccati come prima: la cornice gialla, le puntine della bacheca, lo scotch del manifesto e il pannello rosa.

| Poster | Dove | Com'è rovinato | File |
|---|---|---|---|
| Cartellone dell'arcobaleno | corridoio dove ti svegli (interni) | bruciato dal basso a destra, con il bordo carbonizzato, la fuliggine e i buchi di sigaretta; l'occhio crocettato e i denti a punta a pennarello | `godot/assets/ambienti_interni/texture/cartellone_medusa_rovinato.png` in `corridoio.gltf` |
| Poster del bagnino | bacheca dello stanzino dei bagnini | scarabocchiato con rabbia: l'occhio annerito a spirale, i denti, le linee rosse, i tagli di coltello, un angolo strappato e uno ripiegato | `poster_bagnino_rovinato.png` in `stanzino.gltf` |
| Pannello rosa | infermeria della risalita | pastelli a cera: l'occhio cancellato a giri neri, i denti rossi, le lacrime viola, la campana scarabocchiata, le nuvole nere; un solo buco di sigaretta, un angolo strappato e lo scotch | `cartellone_medusa_infermeria.png` in `infermeria_gioco.gd` |
| Manifesto dello spettacolo | sala principale, muro ovest | fradicio e strappato: strisce e un morso mancanti, l'occhio strappato via con i graffi, i denti a penna, le colature e la muffa; "LIVE SHOW" e gli orari restano | `manifesto_rovinato.glb` (copia: il menu usa ancora `manifesto.glb`, invariato) |

Le texture le fa `assets_src/ambienti_interni/poster/rovina.py`, partendo da quelle invecchiate di prima (che restano), e `applica_rovinati.py` le mette nei modelli.

Scatti dal motore, con i materiali veri: `prima/` (su origin/lavoro/godot) e `dopo/` sono fatti dagli stessi punti e con le stesse luci, perché i neon usano lo stesso seme. Per ogni poster ci sono tre scatti: `_giocatore` dagli occhi del giocatore, `_vicino` e `_bordo` per vedere come sta attaccato. Gli scatti `_luce` hanno una lampadina neutra accanto alla camera solo per vedere i dettagli: nel gioco quella lampadina non c'è. I fogli `confronto_*.jpg` mettono prima e dopo affiancati. Lo script degli scatti è `godot/proposte/poster_rovinati/scatti_poster.gd`.
