# Bambini (creature minori)

Due scene pronte da mettere nei livelli:

- `bambino_cubo.tscn`: la testa a cubo. È un bambino magro in una muta da sub; quando si rivela, il cubo di piastrelle si spacca e da dentro esce la massa di tentacoli con gli occhi gialli.
- `bambino_agnello.tscn`: l'agnellino di peluche. Quando si rivela, il muso si apre su un unico occhio rosa, come quello della madre.

Ogni scena ha due modelli con lo stesso scheletro e le stesse animazioni: `Calmo` (travestito) e `Rivelato`. Lo script è `scripts/creature/bambino.gd` (classe `Bambino`). Ogni bambino entra nel gruppo `bambini`.

## Animazioni

Stanno nei GLB di `assets/models/bambini/bambino_*.glb`. Sono fatte con lo scheletro di Meshy e lo script `tools/blender/bambini_animazioni.py`.

| nome | cosa fa | durata |
| --- | --- | --- |
| `fermo` | curvo, respira lento e ondeggia appena | 8 s, in ciclo |
| `inclina_testa` | piega piano la testa da una parte, resta lì e torna | 6 s, in ciclo |
| `cammina` | camminata lenta e un po' storta: testa piegata, una spalla più bassa, braccia molli | 1,9 s, in ciclo |
| `corsa` | corsa curva, a testa bassa, per scappare | 0,7 s, in ciclo |
| `si_gira` | di spalle: gira prima la testa oltre la spalla, poi tutto il corpo | 3,5 s, una volta |

Niente scatti: i bambini fanno paura con la postura e la lentezza.

## Modalità

Si sceglie la modalità con `modalita` nell'Inspector. Durante il gioco la si cambia con i metodi.

- **STATUA** (`statua()`): il bambino è immobile. Quando il giocatore lo guarda per `tempo_per_vederlo` secondi (entro `distanza_vista` e a meno di `angolo_vista` gradi dal centro dello sguardo, senza muri in mezzo), reagisce secondo `reazione`. Con `SI_GIRA` all'inizio dà le spalle a dove punta il suo asse +Z, quindi va girato verso il punto da cui arriverà il giocatore. Con `INCLINA_TESTA` piega la testa. Con `NESSUNA` non fa niente. Dopo la reazione passa a OSSERVA.
- **OSSERVA** (`osserva()`): respira fermo e segue il giocatore con la testa. La testa copre solo una parte dell'angolo (`quota_testa`, limite `limite_testa`). L'agnellino rivelato copre il resto con l'occhio, spostando le UV dell'iride, quindi ti fissa anche se la testa resta storta. Con `gira_il_corpo` si gira piano verso di te. Ogni `inclina_ogni` secondi piega la testa.
- **CAMMINA** (`cammina(punti)`): cammina piano lungo `percorso`. Alla fine osserva, oppure sparisce se `sparisce_a_fine_percorso` è attivo (per esempio dietro un angolo).
- **SCAPPA** (`scappa_ora()`): corre lungo `punti_fuga`, poi sparisce. L'ultimo punto va messo dietro un angolo. Senza punti corre via dal giocatore per `distanza_fuga_libera` metri.

Da STATUA (dopo la reazione), da OSSERVA e da CAMMINA il bambino scappa da solo:
- quando il fascio della torcia accesa lo prende in pieno (`scappa_con_la_torcia`);
- quando il giocatore arriva più vicino di `distanza_fuga` metri.

Altri metodi:
- `rivela()` apre il travestimento, senza interrompere l'animazione;
- `richiudi()` lo richiude;
- `rivela_quando_scappa` lo apre nel momento in cui scappa.

Quando sparisce, con `libera_quando_sparisce` il nodo si toglie dalla scena; senza, resta nascosto e si può riusare.

## Segnali (per l'audio)

| segnale | quando |
| --- | --- |
| `visto` | il giocatore lo ha guardato abbastanza (fine della statua) |
| `si_gira` | comincia a girarsi verso il giocatore |
| `rivelato` | il travestimento si apre |
| `scappa` | comincia a scappare |
| `sparito` | è sparito alla fine della fuga o del percorso |

## Esempi per le apparizioni B1-B5

Spunti, da montare nei livelli. `sala_principale.tscn` non è stata toccata.

- **B1, spogliatoi.** Un `bambino_cubo` in CAMMINA verso la grata, con `sparisce_a_fine_percorso`. Se il giocatore gli punta la torcia addosso, scappa.
- **B3, sala pompe (monitor).** Un `bambino_agnello` in CAMMINA verso il piedistallo, con `percorso` di due punti e `sparisce_a_fine_percorso`.
- **B4, spogliatoi al buio.** Un `bambino_agnello` in STATUA con `reazione = INCLINA_TESTA`, `distanza_fuga` di 3 m e un punto di fuga dietro gli armadietti.
- **B5, balconata.** Più istanze in STATUA con `reazione = NESSUNA`, girate verso la torre, e `segue_con_la_testa` attivo. Quando passano a OSSERVA ti guardano tutte. Il `KidSighting` esistente può usare queste scene al posto dei GLB statici.

## Prove

```
godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/test_bambini.gd
```

Il test controlla che le scene si carichino, che i modelli abbiano scheletro e animazioni e che le modalità funzionino nel livello di prova: statua, sguardo, rivelazione, torcia, vicinanza, occhio, fuga e sparizione.

Gli screenshot nella sala si fanno con `tests/screenshots_bambini.gd`; il comando è scritto nello script. Lanciali sotto `flock /home/user/tools/render.lock`.
