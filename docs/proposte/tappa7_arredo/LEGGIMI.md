# Strada di risalita (tappa 7 B): due proposte di arredamento

Punto 12 della prova della v0.3.1: "il percorso di risalita è molto vuoto e brutto". Solo proposte: nel gioco non è cambiato niente.

Scatti dal motore con la luce vera di quel momento (blackout dopo il risveglio: rosse d'emergenza, luce rossa che guida sulla serranda, torcia accesa), dagli stessi otto punti della strada:

| # | Punto | `senza/` (com'è oggi) | `A/` | `B/` |
|---|---|---|---|---|
| 1 | corridoio appena fuori dalla porta col maniglione | | | |
| 2 | prima rampa di scale | | | |
| 3 | pianerottolo tra le due rampe | | | |
| 4 | in cima, davanti alla grata, verso la scala del corridoio C2 | | | |
| 5 | corridoio C2 | | | |
| 6 | corridoio C3 | | | |
| 7 | magazzino dei gonfiabili | | | |
| 8 | la serranda vista dalla sala | | | |

**Versione piena (16 ottobre, sera).** Dopo la prima versione, che restava quasi vuota, ogni tratto di muro è pieno sui due lati: gruppi di oggetti appoggiati, cataste, cose cadute, roba appesa ai muri e, sulle scale, oggetti piccoli sui gradini. Il magazzino è stracolmo. Al centro resta sempre una corsia libera di almeno un metro. Niente ripetizioni vicine e sempre la stessa lancia (la C1) in tutti gli scatti, anche in `senza/`.

**Correzione (17 ottobre).** La roba appesa (bacheche, cartelli, quadri, salvagenti, rulli) ora sta a filo del muro, senza rotazioni a caso, col centro a circa 1,55 m dal pavimento o dal gradino; i salvagenti sono infilati su un piolo d'acciaio; dove toccherebbe la roba a terra non si appende niente; niente roba appesa vicino all'ingresso della scala F1. Lo scatto 8 di B è rifatto con la stessa luce degli altri.

**A, deposito della festa.** La roba della piscina messa via e dimenticata: lettini impilati, ombrelloni chiusi, materassini arrotolati, carrelli di asciugamani, casse di tubi galleggianti, scatoloni colorati, palloni, braccioli, un coccodrillo gonfiabile sgonfio; ai muri salvagenti, bacheche e cartelli e la grande testa della mascotte, un delfino, appoggiata al muro del corridoio che guarda chi passa. Nella tromba delle scale e nel magazzino ci sono festoni di bandierine sbiadite, alcune cadute.

**B, manutenzione.** Il retro dell'acquapark: fusti blu di cloro, bancali di sacchi di sale, casse di plastica impilate, scatoloni, transpallet, carrelli degli attrezzi, secchi; ai muri rulli col tubo, quadri elettrici, estintori, cartelli e un fascio di tubi sotto il soffitto. Frecce gialle dipinte a terra e nastro bianco e rosso sul corrimano.

**In tutte e due**, per non perdersi: cartelli verdi d'uscita accesi alle svolte (con la loro lucina) e un corrimano giallo sulla scala del corridoio C2. Gli oggetti stanno ai lati: la strada resta libera.

Tecnica: modelli Meshy (meshy-7.1) da `assets_src/tappa7_arredo/genera_arredo.py`, messi da `tools/blender/tappa7_arredo.py` in `godot/assets/ambienti_tecnici/proposte_tappa7/arredo_A.gltf` e `arredo_B.gltf` (solo gli oggetti aggiunti, nelle coordinate del raccordo; `raccordo.gltf` non cambia). Scene di prova: `godot/tests/scene/tappa7_arredo_A.tscn` e `_B.tscn`. Gli oggetti non hanno ancora collisioni: si aggiungono con la scelta.
