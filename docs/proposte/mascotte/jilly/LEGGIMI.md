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
| `targa_a/b.jpg` (+ `_dettaglio`) | targa smaltata 70 × 39 cm avvitata sul lato ovest della vasca della medusa, accanto al cordone |
| `manifesto_a/b.jpg` (+ `_dettaglio`) | manifesto dello spettacolo, 70 × 105 cm, sbiadito, piegato e strappato, col nastro adesivo, sul muro ovest vicino all'ingresso, tra il cartello giallo e l'oblò |
| `insegna_a/b.jpg` (+ `_dettaglio`) | insegna di lamiera dipinta 2 × 1,1 m in una cornice d'acciaio su quattro staffe, sul muro ovest sopra la vasca d'arrivo, tra due oblò e sopra il tubo e la lampada rossa |

Scatti dal motore (Godot, preset Alto, luce della prima visita, torcia accesa), dagli occhi del
giocatore; i `_dettaglio` sono ritagli ingranditi degli stessi scatti. Testi in inglese (i cartelli già
nel gioco sono solo pittogrammi; il manifesto dice "LIVE SHOW" e "EVERY DAY 11 AM & 4 PM").
Le grafiche sono texture generate (`assets_src/mascotte/jilly_meshy.py`), invecchiate e messe sui modelli
da `assets_src/mascotte/jilly_oggetti.py`.
