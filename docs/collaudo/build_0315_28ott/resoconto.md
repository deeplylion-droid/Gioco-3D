# Collaudo della build 0.3.15 (28 ottobre)

Squadra collaudo. Build unita `lavoro/godot` **efc7352f** (versione 0.3.15). Contiene: blocchi con gli oblò, Continua con la domanda di Nuova partita, acqua senza salto, porta e lampade dell'infermeria, roccia, buco del tunnel, canto A, FINE DEL CAPITOLO 1. Salvataggi in una cartella dei dati tutta loro, come su un PC nuovo.

**Esito: la build è a posto.** Tutte le prove passano. 0 righe "ERROR: BUG," in tutti i log, senza schermo e col renderer vero.

| Prova | Esito |
|---|---|
| Continua dalla risalita: si gioca fino al checkpoint, si chiude, si riapre, Continua col tasto | Continua è la prima voce, col focus. Riporta a CheckpointRaccordo, a 0,00 m dal posto salvato, con zaino, acqua, inventario, Polaroid e luci uguali. Dopo una morte si riparte da lì (4,6 s), in piedi |
| Continua dalla torre | Checkpoint_NEm3, a 0,01 m, tutto uguale. Morte e ripartenza da lì (7,8 s) |
| Continua dal tunnel dopo un crash vero (SIGKILL) | Checkpoint_160, a 0,00 m, tutto uguale. Morte e ripartenza da lì (9,6 s) |
| Partenze F9: risalita, fiume, torre, inseguimento, tunnel | Tutte arrivano in 7-8 s al loro checkpoint, senza errori. Elenco dei pezzi come nel collaudo dei blocchi, più una forma e una luce nella risalita (porta e lampade dell'infermeria) |
| Menu F9 dal titolo, col renderer vero | Si apre, Esc lo chiude, F9 lo riapre (`fogli/menu_0_titolo.jpg` e seguenti) |
| test_continua | 127/127 |
| test_infermeria_gioco | 56/56 |
| test_infermeria | 22/22 |
| test_menu | 72/72 |
| test_partenze_prova | 72/72 |
| test_scaletta_bacino | 13/13 |
| test_fiume_gioco | 31/31 |
| test_canto_tunnel | 24/24 |
| test_guado | 11/11 |
| test_strati | 5/5 |
| test_oblo_leggeri, col renderer vero | 30/30 |
| test_luci_accese, col renderer vero | 1/1 (per ora stampa le misure, senza un limite) |
| test_fine_titolo con FINE_TUNNEL=1 | 14/14: dopo il tunnel solo «FINE DEL CAPITOLO 1»; in pausa non torna al titolo; finita la scritta torna da solo al titolo |
| Partita intera del tunnel col renderer vero (`fogli/tunnel_partita_intera.jpg`) | SB1, scaletta in 1,3 s, 5 attraversamenti, gallerie 205 (10,9 s) e 425 (18,2 s) accovacciati, approdo, portello, schianto, nero. 6 getti, 6 respinte, 0 prese |

## Non verificato

- **La scritta finale col renderer vero.** Nella scena di prova del tunnel c'è solo il nero. La scritta la prova `test_fine_titolo`, senza schermo, nella sala.
- **La domanda di Nuova partita.** L'ha collaudata ambienti-1.
- **La sala intera col renderer vero:** non entra nella memoria della macchina.
