# Collaudo della voce Continua (25 ottobre, pomeriggio)

Squadra collaudo. Base: `lavoro/continua` **f3cdb753** (mascotte). Il collaudo è fatto come un giocatore, con un processo Godot per ogni volta che si apre il gioco: si gioca fino a un checkpoint, si chiude (o si uccide il processo), si riapre e si preme Continua col tasto vero (Invio sulla voce che ha il focus). Strumento: `godot/tests/collaudo/sonda_continua.gd`, nei modi `titolo`, `gioca <id> [kill]`, `continua <id>` e `nuova`.

**Esito: Continua funziona**:
- è la prima voce, solo quando c'è un salvataggio;
- riporta all'ultimo checkpoint con tutto com'era, da tre zone, anche dopo un crash vero.

C'è una cosa da decidere: **"Nuova partita" sovrascrive subito il salvataggio vecchio**, appena si entra nella sala e prima del primo checkpoint.

Le prove sono state fatte con una cartella dei dati tutta loro (`XDG_DATA_HOME`), come su un PC nuovo. La cartella `user://` normale di questa macchina la usano anche le altre squadre: alle 15:57 un altro processo ci ha riscritto un salvataggio "inizio" del 23 ottobre, e la prima prova del titolo "senza salvataggio" l'aveva letto.

## 1. Il titolo

| Caso | Voci | Focus | Menu F9 | Scatto |
|---|---|---|---|---|
| senza salvataggio | NUOVA PARTITA, OPZIONI, COMANDI, ESCI | Nuova partita | nascosto | `fogli/titolo_senza_salvataggio.jpg` |
| con un salvataggio (raccordo della risalita) | **CONTINUA**, NUOVA PARTITA, OPZIONI, COMANDI, ESCI | **Continua**, con la barra rossa come le altre | nascosto | `fogli/titolo_con_salvataggio.jpg` |

Continua ha lo stesso carattere, la stessa grandezza e lo stesso stile delle altre voci (scatto col renderer vero, 1280×720). Sopra il menu c'è ancora "demo 0.3.14", come deve essere prima della build della 0.3.15.

## 2. Continua da tre zone (chiudendo e riaprendo il gioco)

Per ogni zona: dal titolo, F9 e la partenza di prova; il giocatore entra nel checkpoint successivo della zona, il salvataggio su disco viene riscritto e il gioco si chiude. Poi in un processo nuovo: il titolo, Continua, la schermata di caricamento, l'arrivo.

| Zona | Checkpoint salvato | Arrivo dopo Continua | Distanza dal posto salvato | Luci, zaino, acqua, inventario, Polaroid |
|---|---|---|---|---|
| risalita | `Tecnici/Logica/Checkpoint/CheckpointRaccordo` | 9,1 s | 0,00 m | uguali (blackout, zaino, 20 l, 9 Polaroid) |
| torre | `SalaTorre/Checkpoint_NEm3` | 8,0 s | 0,01 m | uguali (anche la Polaroid della pecora) |
| tunnel, dopo un crash | `SalaSottomarino/Checkpoint_160` | 11,8 s | 0,00 m | uguali (11 Polaroid) |

In tutti e tre i casi il giocatore ha i comandi e sta in piedi sul pavimento: dopo un secondo non è sceso. I tempi sono senza schermo; la prima volta, con le cache vuote, il caricamento ha richiesto 117 s.

## 3. Crash vero

Nel tunnel il processo si è ucciso da solo con SIGKILL (uscita 137) subito dopo aver raggiunto il checkpoint a 160 m. Il file `salvataggio.json` è rimasto intero (3107 byte, JSON valido) e, al riavvio, Continua è ripartito da quel checkpoint con tutto uguale.

## 4. Nuova partita

Dal titolo con un salvataggio (il tunnel a 160 m): giù da Continua a Nuova partita e invio, si salta lo spot tenendo premuto. Il gioco riparte dal risveglio: la memoria viene azzerata (`reset_progress`) e i comandi tornano dopo il risveglio. Il salvataggio vecchio viene sovrascritto, ma **subito**:

- appena la sala si apre, prima di qualunque checkpoint, su disco c'è già `inizio`, dalla cattura del punto di partenza di un livello nuovo, `capture_snapshot("inizio")` in `game_state.gd`;
- al primo checkpoint (`Gioco/CheckpointIngresso`, ordine 0) viene riscritto di nuovo.

**Da decidere:** chi preme Nuova partita per sbaglio, o per guardare lo spot, perde i progressi subito e senza conferma: tornando al titolo, Continua lo riporta all'inizio. La richiesta era che il salvataggio vecchio venisse sovrascritto al primo checkpoint. Ci sono due strade: scrivere su disco solo dal primo checkpoint vero, oppure chiedere una conferma quando c'è un salvataggio.

## Non verificato qui

- **L'arrivo col renderer vero e i blocchi durante il caricamento**: la sala intera col renderer software non entra nei 15 GB della macchina. L'arrivo è stato verificato senza schermo; col renderer vero c'è solo lo scatto della schermata di caricamento (`fogli/continua_caricamento.jpg`). I blocchi li sta correggendo la grafica.
- Mouse e joypad: provati solo i tasti (Invio e freccia giù).
