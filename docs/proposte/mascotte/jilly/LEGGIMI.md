# JILLY JUBILEE: il nome nel parco (19 ottobre)

Due stili di logo, ognuno su tre oggetti, e per ogni oggetto un posto nella sala. Tutto è montato al
volo per gli scatti (`godot/proposte/mascotte/scatti_statue.gd`, `giro_jilly.sh`): nel gioco non c'è
niente e `proposte/` è esclusa dall'export.

**Stile A, "a bolle"**: lettere gonfie e lucide come un gonfiabile, dal rosa al lilla, contorno bianco,
ombra viola, bollicine e un'onda sotto. Il puntino delle due i è l'occhio di Jilly.
**Stile B, "varietà della nave"**: "Jilly" in corsivo corallo con contorno blu, "JUBILEE" in oro su un
nastro blu, stelle e una piccola medusa.

| File | Cosa |
| --- | --- |
| `oggetti_stile_a.jpg`, `oggetti_stile_b.jpg` | render Cycles dei tre oggetti di uno stile, su fondo grigio |
| `targa_a/b.jpg` (+ `_dettaglio`) | targa smaltata 70 × 39 cm avvitata sul lato ovest della vasca della medusa, ripresa da vicino, appena fuori dal cordone |
| `manifesto_a/b.jpg` (+ `_dettaglio`) | manifesto dello spettacolo, 70 × 105 cm, sbiadito, piegato e strappato, col nastro adesivo, sul muro ovest vicino all'ingresso, tra il cartello giallo e l'oblò |
| `insegna_a/b_luce.jpg` (+ `_dettaglio`) | alternativa da scegliere: la stessa insegna con due lampade a collo d'oca sopra (smalto verde consumato), luce calda e debole che illumina solo il pannello; luci montate solo per lo scatto |
| `insegna_a/b.jpg` (+ `_dettaglio`) | insegna di lamiera dipinta 1,8 × 1 m in una cornice d'acciaio su quattro staffe, sul muro ovest sopra la vasca d'arrivo, tra due oblò, con un margine sopra il neon a parete |

Scatti dal motore (Godot, preset Alto, luce della prima visita, **senza torcia**, sulla v0.3.6), dagli occhi del giocatore; quelli con la torcia sono in `con_torcia/`; i `_dettaglio` sono ritagli ingranditi degli stessi scatti. Testi in inglese (i cartelli già
nel gioco sono solo pittogrammi; il manifesto dice "LIVE SHOW" e "EVERY DAY 11 AM & 4 PM").
Le grafiche sono texture generate (`assets_src/mascotte/jilly_meshy.py`), invecchiate e messe sui modelli
da `assets_src/mascotte/jilly_oggetti.py`.

Senza torcia (v0.3.6): la targa da vicino si legge; il manifesto si vede ma è scuro, nella luce rossa
della lampada accanto; l'insegna, in alto tra due oblò, resta quasi al buio e non si legge; con le due lampade a collo d'oca
(`insegna_*_luce`) si legge, e la parete intorno resta com'è.
Il manifesto B ha l'angolo strappato in alto a destra, così la riga degli orari resta tutta dentro.
