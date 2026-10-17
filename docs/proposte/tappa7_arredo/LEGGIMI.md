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

**A, deposito della festa.** La roba della piscina messa via e dimenticata: lettini impilati, ombrelloni chiusi, carrelli di asciugamani, casse di tubi galleggianti, un coccodrillo gonfiabile sgonfio e la grande testa della mascotte, un delfino, appoggiata al muro del corridoio che guarda chi passa. Nella tromba delle scale e nel magazzino ci sono festoni di bandierine sbiadite, alcune cadute.

**B, manutenzione.** Il retro dell'acquapark: fusti blu di cloro, bancali di sacchi di sale, un transpallet lasciato davanti alla grata, il carrello rosso degli attrezzi con il retino. Frecce gialle dipinte a terra e nastro bianco e rosso sul corrimano.

**In tutte e due**, per non perdersi: cartelli verdi d'uscita accesi alle svolte (con la loro lucina) e un corrimano giallo sulla scala del corridoio C2. Gli oggetti stanno ai lati: la strada resta libera.

Tecnica: modelli Meshy (meshy-7.1) da `assets_src/tappa7_arredo/genera_arredo.py`, messi da `tools/blender/tappa7_arredo.py` in `godot/assets/ambienti_tecnici/proposte_tappa7/arredo_A.gltf` e `arredo_B.gltf` (solo gli oggetti aggiunti, nelle coordinate del raccordo; `raccordo.gltf` non cambia). Scene di prova: `godot/tests/scene/tappa7_arredo_A.tscn` e `_B.tscn`. Gli oggetti non hanno ancora collisioni: si aggiungono con la scelta.
