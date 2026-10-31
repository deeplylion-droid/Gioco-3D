# Collaudo della correttiva 0.3.18 (31 ottobre)

Squadra collaudo. `lavoro/crash-ripartenza` **cb4ad9c3** contro la 0.3.17 (main 9eec9510). Giocatore vero coi tasti veri, senza schermo, e salvataggi in una cartella dei dati a parte.

**Esito: collaudo superato. 0 righe "ERROR: BUG," e 0 errori di script in tutti i log.**

| Controllo | Esito |
|---|---|
| Diff contro 9eec9510 | descrittori D3D12 a 524288 e versione 0.3.18 in `project.godot`; note; `sala_principale.gd` (`_libera_ambienti_subito`, niente torre nascosta nel tunnel); `porta_maniglione.gd`; `impostazioni_grafiche.gd` (`_applica_luce` per id); `test_ripartenza_oltre_portone.gd`, nuovo, e il suo passo in `build.yml` |
| `test_ripartenza_oltre_portone`, `test_continua`, `test_partenze_prova`, `test_memoria_morti` | 47, 127, 72, 2: tutti ok |
| Partenze F9 col giocatore vero, con una morte e la ripartenza (`sonda_blocchi.gd`) | torre: arriva in 7,9 s, riparte in 5,4 s. Inseguimento: 7,4 s e 5,1 s. Tunnel: 7,6 s e 3,9 s. Risalita e fiume: arrivano e ripartono. Ogni volta lo stesso checkpoint e niente errori |
| Pezzi di interni e tecnici rimasti | nelle tre partenze oltre il portone 0 luci, mesh, forme o porte sotto `Interni` e `Tecnici`. Inventari uguali alla 0.3.17, a parte i neon che sfarfallano e gli oggetti che si muovono. Nel tunnel non ci sono più gli 11 checkpoint della torre nascosta, che nella 0.3.17 c'erano |
| Continua dopo un crash vero (SIGKILL), poi morte (`sonda_continua.gd`) | torre `Checkpoint_NEm3` a 0,01 m; inseguimento `Checkpoint_vasca_1`, la vasca dopo lo scivolo, a 0,02 m; tunnel `Checkpoint_160` a 0,00 m. Zaino, acqua, inventario, luci e Polaroid uguali. Dopo la morte si riparte in piedi in 7,9, 8,1 e 9,0 s |
| Altri test | torre 94, portone_torre 20, inseguimento 43, sottomarino_gioco 13, luci_bianche_gioco 13 (luci al 40% dopo partenza e morte), interni 57, strada 35, risalita 15, fiume_gioco 31, tappa7 50, tappa8 69, fine del tunnel 14 |

Non ho fatto scatti col renderer: la correzione toglie solo cose che a quel punto non si vedono, e gli inventari di luci, mesh e porte sono uguali alla 0.3.17.

Righe principali dei log in `log/`, gli inventari in `inv_dopo/` e `inv_prima/`.
