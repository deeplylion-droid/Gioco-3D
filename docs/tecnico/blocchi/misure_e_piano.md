# Blocchi al primo avvio (v0.3.14): misure e piano

Squadra grafica, 25 ottobre, branch `lavoro/blocchi` (da main).

Segnalazione dell'utente: su un PC nuovo e potente, la prima volta, il gioco si blocca per alcuni secondi in 2-3 punti mentre carica.
Obiettivo: nessun fotogramma sopra i 100 ms circa durante il gioco, anche con la cache vuota.

## Come ho misurato

- `tests/misura_blocchi.gd` fa girare `test_strada.gd`, cioè il giocatore che cammina dalla partenza all'ingresso della torre, con le stanze e la torre caricate nel thread come nel gioco. Intanto misura il tempo vero di ogni fotogramma e stampa quelli sopra i 50 ms, insieme al tratto della strada.
- `tests/misura_istanze.gd` misura `instantiate()` e `add_child()` delle zone grandi, già caricate.
- Senza disegno (`--headless`) si misura il lavoro della CPU: istanze, costruzioni e script. Shader e pipeline non si misurano così: per quelli serve il renderer vero (vedi "Da misurare ancora").
- Prima misura con `--fixed-fps 60`: lì il tempo del gioco corre più veloce di quello vero, e le attese del thread in tempo vero sembrano lunghe. Sto rifacendo la strada a tempo vero.

## Misure (CPU, senza disegno)

| Punto | Fotogramma più lungo | Causa |
|---|---|---|
| **Risalita**: si arriva nella zona delle stanze prima che il thread abbia finito | **17 s** | `risalita_gioco.gd` `_carica_subito`: aspetta il thread (`load_threaded_get` è bloccante), poi `instantiate` e `_ready` di fiume e infermeria tutti in un fotogramma (`_metti_stanze`) |
| Risalita, normale: l'infermeria entra in scena | **275 ms** | `infermeria_gioco.gd` `_ready` (`_negatoscopio`, `_pulsante_parco`, `sala_interattivi.glb` istanziato tutto) in un fotogramma (`risalita_gioco.gd:560`) |
| Risalita, scendendo al capannone | 1041 ms | da attribuire (probabilmente `UnificaMateriali` e `ripristina` delle stanze appena messe) |
| **Torre**: il portone è aperto e il thread non ha finito in 20 s | **20,3 s**, poi fotogrammi da 0,5 a 2,4 s | `sala_principale.gd:450` riserva: `ResourceLoader.load` sincrono e `_aggiungi_torre`, cioè tutta la torre in un fotogramma senza pezzi né riscaldamento |
| Sala: piscina a onde, sala pompe, porta del ponte, serranda, area bimbi | 107-341 ms | da attribuire uno per uno (cambio delle luci al risveglio e al blackout, scorciatoie del test) |
| Tunnel | non sulla strada del test | `sala_principale.gd:649` ha la stessa riserva sincrona: `load` e `costruisci()` interi |

Istanze già caricate: fiume 0 ms, torre 0 ms, tunnel 21 ms (si costruiscono a pezzi dopo); infermeria 275 ms (non è a pezzi).

**Il punto chiave:** i blocchi di secondi non sono le istanze ma le **riserve sincrone**. Quando il thread non ha finito, il gioco carica e costruisce tutto lì, in un fotogramma.
- Sulla strada del test è successo due volte: alla Risalita e alla torre.
- La torre comincia a caricarsi solo quando gli acquari sono risolti, quindi il portone si può aprire prima della fine.
- Su un PC nuovo la cache dei file del sistema è fredda, quindi i caricamenti nel thread sono più lenti. È probabile che sia proprio questo il "si blocca alcuni secondi mentre carica" dell'utente.

## Shader e pipeline con la cache vuota (dal codice; misura col renderer vero in corso)

- **La schermata di caricamento dell'avvio non prepara niente dei materiali.** La sala entra in scena dietro lo schermo nero e ha 8 fotogrammi di assestamento.
- I "materiali campione" della sala e della Risalita fanno solo `get_rid()`: creano lo shader, ma non compilano le pipeline.
- La Risalita non ha un disegno fuori vista: le pipeline delle stanze si compilano la prima volta che si vedono.
- La torre (`prepara_materiali`), il tunnel (`_riscalda`) e gli oblò hanno già il loro riscaldamento fuori vista, ma lo fanno durante il gioco.
- Con la cache vuota ogni shader nuovo si compila al primo uso, sul thread principale. Su un PC veloce costa decine di millisecondi l'uno.

## Piano

1. **Mai più riserve sincrone durante il gioco.**
   - `_carica_subito` (Risalita), la riserva della torre e quella del tunnel non caricano e non costruiscono più in un fotogramma.
   - Si aspetta il thread senza bloccare, e la costruzione resta a pezzi: accelerata, ma sempre sotto i 50 ms per fotogramma.
   - Il passaggio (la porta del raccordo, il portone della torre, il portello del tunnel) resta chiuso finché la zona non è pronta. La porta fa un rumore di meccanismo che lavora, e per chi gioca dura al più qualche secondo, solo su un PC lento.
   - Questa è una scelta che si vede: va chiesta all'utente. In alternativa si continua a camminare con la zona che compare a pezzi.
2. **I caricamenti cominciano prima e vanno più svelti.**
   - La torre parte dall'inizio della tappa 8, non dagli acquari risolti.
   - Le stanze della Risalita partono dal checkpoint della sala pompe, come adesso, ma con `use_sub_threads` nel thread.
   - Il tunnel parte dall'ingresso nella torre.
3. **Infermeria a pezzi**, come il fiume: il suo `_ready` diviso in passi da pochi ms (275 ms oggi).
4. **Riscaldamento degli shader dietro la schermata di caricamento dell'avvio.**
   - Mentre la barra si muove, una SubViewport fuori vista disegna, a gruppi su più fotogrammi, tutti i materiali campione: sala, Risalita, torre, inseguimento e tunnel.
   - Le luci e l'ambiente sono quelli del gioco (ombre, nebbia), così shader e pipeline finiscono nella cache la prima volta.
   - I riscaldamenti di torre e tunnel durante il gioco restano: con la cache piena costano poco.
   - Da coordinare con enigmi: la SubViewport si ferma e si toglie prima che la sala entri in scena e prima di ogni ricarica.
5. **I blocchi della sala da 100-340 ms**: li attribuisco uno per uno con un timer per sistema e li spezzo.
6. **In CI:**
   - `misura_blocchi.gd` su `test_strada`, a tempo vero e senza disegno, con il limite di 100 ms tranne l'avvio;
   - un test col renderer software e la cache vuota (la CI parte sempre senza cache) che conta le pipeline compilate al primo fotogramma visibile di Risalita, torre e tunnel, come fa già `test_torre_ingresso.gd`.

## Da misurare ancora

- La strada a tempo vero (gira adesso).
- Il tunnel e l'inseguimento.
- Shader e pipeline col renderer vero e la cache vuota (`user://shader_cache` spostata, non cancellata), all'ingresso nella sala, nella Risalita, nella torre e nel tunnel.

## Stato alla consegna delle 19:00 (25 ottobre)

Fatto (scelta A dell'utente: la porta aspetta la zona):
- niente più riserve sincrone: Risalita, torre e tunnel aspettano il thread senza bloccare; la porta del maniglione, il portone della torre e la scaletta di SB1 restano chiusi finché la zona non è pronta (`AttesaZone`);
- infermeria, torre e tunnel costruiti a pezzi; la torre si riaccende un nodo per volta (`AccensioneAPezzi`, ≤12 ms per passo), interni e tecnici si liberano dalle foglie a pochi ms per fotogramma;
- riscaldamento degli shader dietro la schermata di caricamento (`RiscaldamentoShader`, un materiale per fotogramma, poi le ombre una luce per volta e lei dietro l'oblò un pezzo per volta);
- in CI: `test_attesa_zone.gd` (thread rallentato a 6 s, nessun fotogramma sopra 100 ms oltre i casi noti) e `test_riscaldamento_pipeline.gd` (renderer software).

Casi noti ancora sopra 100 ms (misure headless a tempo vero, macchina del sandbox):

| Dove | Passo | Misura | Correzione (seconda tappa, entro le 21:00) |
|---|---|---|---|
| Inseguimento | `_modello(struttura)` | 50-95 ms | GLB diviso a pezzi, con ambienti |
| Inseguimento | `_lei_crea` | 100-275 ms | lei creata prima, con mascotte |
| Tunnel | relitto | ~280 ms | a pezzi |
| Tunnel | palombaro | ~210 ms | a pezzi |
| Tunnel | buco nella volta | ~230 ms | a pezzi |
| Tunnel | oblò dell'abisso | ~300 ms | a pezzi |
| Tunnel | primo corallo | ~170 ms | forme convesse salvate in `.res` e caricate col thread |
| Tunnel | pesci | divisi uno per passo, da rimisurare | — |

Il tunnel si costruisce mentre si è nella torre, prima di SB1: questi blocchi cadono lì.
