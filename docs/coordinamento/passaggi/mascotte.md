# Passaggio: squadra "mascotte" (21 ottobre)

## Aggiornamento del 21 ottobre sera (sessione session_01YWTG1mGq714ESVViUmQhYw)

- **Statue e Jilly nel gioco** (v0.3.8, 2d32caf): nodo `Mascotte` della sala, `scripts/environment/mascotte_sala.gd`. Jilly stile B molto invecchiato da `assets_src/mascotte/jilly_gioco.py` (le grafiche originali si riscaricano da Meshy con i task_id del log, in `gen/jilly/`). Test in `test_sala` e `test_tappa7`.
- **Bordi neri delle texture**: le texture cotte di statue e mostro avevano lo sfondo nero tra le isole UV (triangolini neri con le mipmap). `tools/glb_bordi_texture.py` riempie i vuoti dentro i GLB; `riduci_cuoci.py` ora lo chiama da solo.
- **Inizio con il mostro-squalo**:
  - bocca: `assets_src/mascotte/mostro_bocca.py` (linea delle labbra, taglio, sacca della bocca, gengiva, seconda fila di denti);
  - scheletro e pesi: `mostro_rig.py`. Il calore di Blender fallisce su questa mesh: i pesi sono per distanza dalle ossa, lisciati sulla superficie. I doppioni del glTF vanno uniti a 0,8 mm, se no le cuciture UV si aprono in crepe nere quando si deforma;
  - animazione: `mostro_anim.py`, tutta a funzioni del tempo, con gambe e braccia in IK fatte a mano e la radice che porta la corsa. Esce `godot/assets/models/mascotte/mostro_squalo_A_rig.glb` più un `.json` con i tempi, che legge `scripts/interni/risveglio_squalo.gd`;
  - controlli in Blender: `mostro_rig.py anteprime <tempi> <cartella>` e `striscia <t0,t1,n> <cartella>`. Nel gioco: `godot/proposte/mascotte/video_risveglio.gd`;
  - suoni: `assets_src/audio/genera_squalo.py`;
  - il risveglio è a x 14,5, verso est (scelta a dell'utente). La porta tagliafuoco ora ha un cardine e una collisione: il vano era libero;
  - nei test la scena dello squalo parte solo con `fai_risveglio(p, true)`, perché dura più di 13 secondi;
  - test: `test_interni`.
- Gli scatti con Vulkan si bloccavano a 3 GB (deadlock dei worker di Godot): serve un `godot/override.cfg` locale con `[threading]` `worker_pool/max_threads=12`.


Branch `lavoro/mascotte` (base: main bd91d14, v0.3.6). Ultimo commit del lavoro: 38c2738.

## Scelte dell'utente da realizzare (lavori aperti)

- **Statue nel gioco**: squalo A nel posto S2 (bordo est della piscina, accanto alla sedia del bagnino), polpo A in A3 (ingresso dell'area bimbi), polpo B in B1 (area bimbi, muro ovest accanto al fungo). Coordinate e rotazioni in `docs/proposte/mascotte/posti/LEGGIMI.md`. Quando entrano nel gioco va tolto `assets/models/mascotte/*` dall'`exclude_filter` dei tre preset in `godot/export_presets.cfg`.
- **Jilly Jubilee, stile B "molto più invecchiato"**: targa, manifesto (LIVE SHOW e gli orari restano) e insegna **con le sue lampade** a collo d'oca. L'invecchiamento è in `assets_src/mascotte/jilly_oggetti.py` (funzioni `sbiadisci`, `macchie`, `scheggiature`; i parametri dello stile B vanno spinti). Posti: targa sul lato ovest della vasca centrale, manifesto e insegna sul muro ovest (vedi `docs/proposte/mascotte/jilly/LEGGIMI.md` e `godot/proposte/mascotte/giro_jilly.sh`).
- **Mostro-squalo A** nell'inizio del gioco: modello per il gioco già pronto, senza scheletro. Scheletro, animazioni e posto sono da proporre.

## Modelli

- Grezzi Meshy (4k, 300-770 mila triangoli): `assets_src/mascotte/*.glb`. Statue squalo A/B e polpo A/B, mostro A/B, più `statua_*_nuova.glb` (vernice fresca, retexture).
- Versioni per il gioco: `assets_src/mascotte/gioco/` (statue 50-55 mila triangoli, mostro 70 mila, texture 2048 cotte dal grezzo), copiate in `godot/assets/models/mascotte/`.
- Oggetti di Jilly (solo proposte): `godot/proposte/mascotte/jilly/*.glb`. Le texture invecchiate sono in `assets_src/mascotte/jilly_tex/`.
- Immagini generate (solo uso interno, mai all'utente): `assets_src/mascotte/gen/`, ignorata da git. Ogni task è in `meshy_log.json`. Crediti usati in tutto: circa 970.

## Script

- `meshy_mascotte.py`: catena immagine di riferimento → multi-view → 3D, più il retexture. `jilly_meshy.py`: loghi e manifesti, con controllo a occhio che il testo sia scritto giusto.
- `render_mascotte.py` e `render_tutti.sh`: render Cycles (studio e buio). `jilly_render.py`: render degli oggetti di Jilly.
- `riduci_cuoci.py`: decimazione e cottura dal grezzo. Tiene le UV di Meshy, che coprono il 67%; le UV automatiche coprivano al massimo il 39% e venivano sfocate.
- `jilly_oggetti.py`: targa, manifesto strappato, insegna, insegna con lampade.

## Scatti dal motore (`godot/proposte/mascotte/`, esclusa dall'export)

- `scatti_statue.gd` monta al volo statue (`modello@x,z@gradi`) e oggetti da parete (`muro=<res>@origine@direzione[@scostamento]`). Il raggio controlla appoggio e compenetrazioni, e gli empty `luce_*` diventano lampade. Ogni scatto dice quali oggetti mostrare.
- `scatti_statue.sh` lo lancia sotto `render.lock`: aspetta 13,5 GB liberi, uccide Godot oltre `LIMITE_MB` e lo chiude se resta appeso dopo l'ultimo scatto.
- **Usa `senza_torcia.sh`** (un solo scatto per processo, salta quelli già fatti): sulla v0.3.6 la sala con due inquadrature supera i 12,5 GB e **la macchina è ripartita due volte**. Un solo scatto per processo resta a 11,3-11,9 GB, ma solo togliendo i nodi che non si vedono: `Tecnici`, `Sala/TorreScivoli`, `Gioco/BambiniBalconata`, `Gioco/EnigmaAcquari`, `Gioco/MedusaFossa`, `Gioco/LeiSbuca`. Negli scatti al buio si toglie anche `Vasca/Medusa`, perché nella tappa 7 la vasca è vuota. Circa 5-6 minuti per scatto.
- `SCATTI_TORCIA=0`: la torcia non c'è più dal gioco (v0.3.6).

## Trappole note

- Le piastrelle visibili sporgono 2-3 cm dalla collisione: per un oggetto su piastrelle usa lo scostamento `@0.03`, altrimenti ci finisce dietro.
- Sul muro ovest ci sono oblò, tubi e neon che **non hanno collisione**: controlla a occhio, con un ritaglio schiarito.
- La pianta dall'alto (`pianta`) sulla v0.3.6 non entra nella memoria. Quella in `posti/` è valida, perché i posti non sono cambiati.
- Non modificare uno script `.sh` mentre gira: bash lo legge a pezzi.
- `pkill -f <nome>` può uccidere anche la tua shell: usa i PID.
- I GLB di Meshy arrivano a volte troncati: `_scarica` riprova.
