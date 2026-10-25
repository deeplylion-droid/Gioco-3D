# Collaudo del crash dopo il primo spavento (25 ottobre, sera)

Squadra collaudo. Correzione: `lavoro/crash-spavento` **879e705f** (enigmi), CI verde. Il caso dell'utente: alla tappa 8 lei ti prende nella fossa dell'area bimbi, non si tiene premuto per saltare la sequenza di morte, e il gioco crasha alla ripartenza.

**Esito: con la correzione la ripartenza regge.**
- **Prese:** 15 prese vere nella sala intera (10 con la sequenza intera, 5 saltate tenendo premuto Spazio) e 2 col renderer vero nella sala ridotta.
- **Ripartenza:** si riparte sempre dal checkpoint giusto, nel posto salvato, in piedi e coi comandi, con la sala intera.
- **Errori:** 0 errori del gioco (script e motore). Nel log senza schermo ci sono errori del renderer finto in due ripartenze su 15, probabilmente solo dei test (sotto).
- **Memoria video alla ripartenza:** +98 MB invece di +638 MB.

## Come

- **Sala intera, senza schermo** (`godot/tests/collaudo/sonda_spavento.gd`, estende `test_presa_vera`). È la strada vera dal risveglio alla serranda: zaino, tornello, pozzo, sala pompe, raccordo, Risalita col fiume, infermeria, C3, keycard, serranda. Le scorciatoie sono quelle di `test_strada`, così Risalita e torre si caricano nel thread come nel gioco. Poi, più volte di fila:
  - lungo la scia fino alla fossa, dove lei prende davvero il giocatore;
  - la sequenza di morte fino in fondo, oppure saltata tenendo premuto Spazio (l'azione "skip", come chi gioca);
  - la ripartenza e 10 s di gioco.
- **Controlli a ogni presa:**
  - il checkpoint e la distanza dal posto salvato;
  - in piedi coi comandi;
  - le parti della sala (Interni, Tecnici, Risalita, Sala, enigma degli acquari, Piscina, Mascotte, Polaroid);
  - la sala che si ricarica solo a caricamenti finiti;
  - gli errori del motore e degli script dalla presa a 10 s dopo (il `ContaErrori` di `test_presa_vera`);
  - lo stato della torre e la memoria.
- **Renderer vero (llvmpipe), sala ridotta.** La sala intera col renderer vero non entra nei 15 GB della macchina, quindi si è fatta per parti, come nel giro dello squalo:
  - `presa_ridotta.gd`, la presa intera e quella saltata;
  - `memoria_ripartenza.gd`, la memoria a ogni fotogramma, con la ricarica di prima (un tempo) e quella nuova (due tempi);
  - `tests/collaudo/scatti_presa.gd`, la presa col renderer vero e uno scatto ogni mezzo secondo per i fogli.

## Risultati: sala intera

| Giro | Prese | Torre alla presa | Ripartenza | Errori |
|---|---|---|---|---|
| 1 | intera, intera, intera, saltata, saltata, torre | 1ª **in caricamento nel thread** (come l'utente): la ripartenza aspetta 18,8 s che finisca. Dalla 2ª in poi è già preparata | 6 su 6 dal checkpoint dell'area bimbi, in piedi, sala intera | 0 |
| 2 | intera, intera, intera, saltata, saltata, torre | già preparata in tutte (la cache era calda) | 6 su 6, a 0,00 m dal posto salvato | 0 del gioco, 1 del renderer finto |
| 3 | preparazione, intera, saltata | alla serranda in preparazione nascosta; alla presa, 3,5 s dopo, già preparata | 3 su 3, a 0,00 m dal posto salvato | 0 del gioco, 2 del renderer finto |

- **Le sequenze:**
  - intera: 303 fotogrammi (5 s) e poi la ricarica;
  - saltata: 63 fotogrammi (1 s tenendo premuto).
- **La 1ª presa del giro 1 è il caso dell'utente:** prima partita, torre ancora nel thread dalla serranda, sequenza intera. Finita la sequenza, la sala aspetta che la torre finisca di caricarsi e solo dopo si ricarica.
- **Il checkpoint:** lungo la scia, prima della fossa, il giocatore passa il checkpoint dell'area bimbi. Si riparte sempre da lì, a (-18,3; 0; -0,5), cioè a 0,00 m dal posto salvato e a 1,5 m dal nodo del checkpoint.
  - Nel giro 1 la sonda confrontava il checkpoint con quello di prima di partire (la serranda) e segnava "fallito". Era un errore della sonda: nei giri 2 e 3 il confronto è con quello della presa e passa.
- **Non provato: la presa con la torre in preparazione.** Dopo una ripartenza la torre si prepara in meno di un secondo, e alla prima preparazione in meno di 3,5 s. Senza schermo non si arriva alla fossa in tempo; restano "falliti" i controlli "torre" dei giri 1 e 2 e "preparazione" del giro 3. La torre in caricamento nel thread, cioè il caso dell'utente, è provata alla 1ª presa del giro 1.

## Risultati: renderer vero, sala ridotta

| Prova | Esito |
|---|---|
| presa, sequenza intera | 3 su 3: lei ti prende, nessun valore non finito in camera, lei e luci, 0 errori fino a 5 s dopo; sala ricaricata a 26,8 s |
| presa, sequenza saltata | 3 su 3, sala ricaricata a 8,1 s |
| memoria video, ricarica di prima (un tempo) | da 1789 a **2427 MB (+638)**, poi la macchina finisce la memoria e il processo viene chiuso |
| memoria video, ricarica nuova (due tempi) | 1789, scena vuota **1250**, picco **1887 (+98)**, poi di nuovo 1789. Memoria statica +6 MB |

- **Fogli:**
  - `fogli/presa_sequenza_intera_renderer_vero.jpg`: l'arrivo col disturbo, lei nella fossa, la presa, il glitch, il nero con "Tieni premuto Spazio per saltare", il cambio di scena e la ripartenza;
  - `fogli/presa_saltata_renderer_vero.jpg`: lo stesso, saltando.
- **I log** (filtrati degli avvisi) sono in `log/`.

## Da segnalare

1. **Errori del renderer finto dopo due ripartenze, mentre la torre si ricarica nel thread.**
   - Giro 3, 3ª presa (saltata), nei 10 s dopo la ripartenza:
     - `Initializing already initialized RID` e `Parameter "mem" is null` (`rid_owner.h`);
     - 5 `Parameter "m" is null` in `servers/rendering/dummy/.../mesh_storage.h`;
     - tutti da `acquario_vetro.gd:193` (`_disco`, `SurfaceTool.commit()`).
   - Giro 2, 6ª presa: `Parameter "t" is null` (`dummy/.../texture_storage.h`), da `water_particles.gd:84`, la nebbiolina dello spruzzo di lei; e all'uscita "1 RID allocations ... DummyTexture were leaked".
   - **Da cosa viene, secondo me:** dopo ogni ripartenza la sala nuova ricarica la torre nel thread (l'enigma è già comparso, `_precarica_torre`). Il thread crea mesh e texture mentre il thread principale ne crea altre.
     - Il renderer finto dei test senza schermo tiene mesh e texture in liste senza protezione fra i thread. Due creazioni allo stesso momento si pestano: sono gli errori qui sopra.
     - Il renderer vero, credo, ha queste liste protette.
   - **Quindi non credo che sia il crash dell'utente**, ma non l'ho potuto vedere col renderer vero: la sala ridotta non ha la torre.
   - **Cosa ne guardi enigmi:** col renderer vero, una ripartenza nella sala intera con la torre che si ricarica nel thread, se c'è un modo di farla stare in memoria. Oppure tenere la torre caricata (il PackedScene) fra una ripartenza e l'altra, come già si fa con la sala.
2. **La memoria cresce di poco a ogni ripartenza** (sala intera, senza schermo): da una ripartenza alla successiva +4-5 MB di memoria statica e +100-140 oggetti. Dopo 6 morti sono +28 MB e +700 oggetti. I nodi (6792) e gli orfani (304) restano uguali. Non è il crash, ma dopo molte morti si somma.

## Non verificato

- **Il crash vero** (Windows, scheda video vera, cache degli shader vuota): qui non si può riprodurre. La condizione che lo provocava, la sala liberata e ricaricata mentre la torre era in caricamento, ora non c'è più: la ripartenza aspetta.
- **La sala intera col renderer vero:** non entra in memoria. È stata fatta per parti.
- **Il ritorno al titolo in due tempi** (menu di pausa, fine della demo): fa parte della correzione, ma il collaudo non l'ha provato.
