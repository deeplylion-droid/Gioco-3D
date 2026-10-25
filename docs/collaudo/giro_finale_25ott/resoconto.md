# Giro finale su lavoro/godot 4559b0c3 (25 ottobre, 07:00-10:00 UTC)

Squadra collaudo. La versione candidata, con dentro D1, D3 e D4 del collaudo del tunnel. Il percorso del giocatore dall'inizio alla fine, zona per zona.

Il gioco intero col renderer software non entra nei 15 GB della macchina: la compilazione delle pipeline di llvmpipe arriva a circa 14 GB e il processo viene chiuso. Per questo le zone sono state caricate una per volta, ognuna col renderer vero e con i materiali semplici (`tools/collaudo/giro_lotti.sh`, `COLLAUDO_SEMPLICE=1`). I passaggi fra le zone li copre la CI senza schermo.

**Esito:** **la candidata è a posto**:
- D1, D3 e D4 sono corretti;
- il tunnel si gioca tutto senza prese;
- nelle zone vecchie negli scatti non si vede niente di rotto;
- la CI è verde, compreso il controllo di posizionamento in tutti gli stati.

## CI di 4559b0c3 (run 40169274120): verde

69 passi in 79 minuti, tra cui:
- tutti i test delle zone;
- il controllo di posizionamento (sospesi, ingombri dove si cammina, interattivi coperti, compenetrazioni) e quello dei varchi, che bloccano la build;
- la strada del capitolo col controller vero, dal risveglio alla torre, porta per porta;
- il primo uso e l'ingresso nella torre;
- il menu F9;
- "finita la demo, il gioco torna da solo al titolo";
- tutti i test del tunnel (gommoni, gallerie, distanza di lei, scaletta, finale col portello);
- l'esportazione per Windows e Linux.

## Tunnel

| Cosa | Come | Esito |
|---|---|---|
| D1, bordi spezzati e macerie | ravvicinati degli ostacoli e giro di enigmi sugli oggetti a 70-84, 200-220, 342-354, 420-440 | i bordi delle lastre e le macerie hanno la texture del cemento del fiume, non sono più lisci (`fogli/tunnel_macerie_348_D1.jpg`, `fogli/tunnel_crolli_ravvicinati_D1.jpg`, `fogli/tunnel_ostacoli_D1.jpg`) |
| D3, facce dal retro all'approdo | giro "retro" 520-553, 23 viste | nessuna faccia vista dal retro (prima 434 punti rossi a 548) |
| D4, la fine | `test_fine_titolo` con `FINE_TUNNEL=1`, senza schermo | 14/14: dopo il tunnel solo «FINE DELLA DEMO», la scritta sopra il nero, in pausa non torna al titolo, finita la scritta torna da solo al titolo, una volta sola. Anche la fine dell'inseguimento passa: 12/12 |
| Partita intera (p14) | il giocatore vero, con la presa vera | SB1, scaletta in 1,3 s, 5 attraversamenti, gallerie 205 (10,9 s) e 425 (18,0 s) senza incastri, approdo, portello, schianto, nero: 0 prese, 6 getti e 6 respinte (`fogli/tunnel_partita.jpg`) |

Nota sul test: con `FINE_SCATTO` (lo scatto col renderer vero), `test_fine_titolo` passa per una strada ridotta che salta la torre e il tunnel e mostra la fine della torre. Per questo il suo controllo nuovo di D4 lì fallisce. È il test da sistemare, non il gioco: la fine vera passa senza schermo.

## Le zone col renderer vero

| Zona | Scena e stato | Scatti | Esito |
|---|---|---|---|
| interni | `interni.tscn`, inizio | 276 | stessi oggetti negli stessi posti del giro finale del 24. I 25 scatti che cambiano differiscono per la tinta della luce d'emergenza, che lampeggia, e per il pallone spostato accanto alla panca (`fogli/interni_confronto_col_24.jpg`) |
| sala, metà ovest | `sala_principale.tscn`, inizio, senza interni, risalita, tecnici, atmosfera, angolo dei palloni ed enigma degli acquari, ombre spente | 112 | vasche, statua di lei, area bimbi con lo scivolo, poster, lettini, cartelli a disegni: niente sospeso o compenetrato (`fogli/sala_ovest_*.jpg`) |
| sala, metà est | come sopra, senza angolo degli scatoloni, area bimbi e mascotte | 108 | angolo dei palloni, vasche, sedie del bagnino, porte (`fogli/sala_est_1.jpg`) |
| fiume | `risalita.tscn`, ritorno | 257 | scatole colorate nei muri, ciambelle in acqua, paratie, lampade, paperella (`fogli/fiume_*.jpg`) |
| risalita | `risalita.tscn`, ritorno | 214 | corridoi degli scatoloni coi pittogrammi, corridoi bui, paletti (`fogli/risalita_*.jpg`) |
| torre e inseguimento | `sala_torre.tscn`, inizio | 479 | confrontati col giro finale del 24: solo 11 cambiano, e di poco (luci). C'è di nuovo l'oblò con lei nel foro del muro della torre (tor038) e il suo telaio sul traliccio dietro (tor039): sembra montato bene, lo guarda la grafica (`fogli/torre_confronto_col_24.jpg`, `fogli/torre_1.jpg`) |
| tecnici | `sala_principale.tscn`, ritorno, solo i tecnici | 136 | stessi oggetti del giro del 24, luce più scura. A tec011 non c'è più la grossa forma bianca che prima stava davanti alla camera: ora si vede la sala pompe (`fogli/tecnici_confronto_col_24.jpg`) |

Gli scatti a muso contro un muro sono punti della lista vicini alle pareti e c'erano anche nel giro del 24.

Le parti nuove le guardano anche le squadre che le hanno fatte, e qui non le ho rifatte con le loro sonde: oblò con lei dietro (grafica), squalo (enigmi), infermeria (ambienti-1), scatole e poster (mascotte). Lei negli oblò compare solo con gli eventi, che i giri fermi non fanno partire: la copre il test della CI.
