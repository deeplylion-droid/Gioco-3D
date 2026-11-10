# Ricontrollo della parte tunnel dei caricamenti nel thread (0.3.25, enigmi, 10 novembre)

Che cosa ho provato, sempre confrontandolo con la 0.3.24 (`main` 26f399fe), con le stesse sonde e sulla stessa macchina:

- `lavoro/caricamenti-thread` 7bd2a5ec, unito in locale con 26f399fe (8ad7e4bf, non pubblicato): punti 1-4;
- a9e6f0f4, la correzione dei coralli, unita in locale con 26f399fe (d5a79b7b, non pubblicato): punto 1 e posto degli arredi;
- `lavoro/torre-robusta` 774e9c46, la correzione delle staffe, che contiene già main, caricamenti-thread e coralli: punto 1, ripartenze e posto degli arredi.

Le prove dei tempi sono nel gioco vero senza schermo, cioè solo tempo di CPU. Pipeline e scatti sono col renderer (llvmpipe). Le righe dei log sono in `risultati.txt`.

## Esito

| | 1. Preparazione del tunnel | 2. Ripartenze | 3. Prima volta | 4. Occhi del giocatore |
|---|---|---|---|---|
| 7bd2a5ec | **no**: i passi con Posa fanno fotogrammi da 35-40 ms | sì | sì | sì |
| a9e6f0f4 | **no**: `_relitto_staffe` fa un fotogramma da 37,4 ms | – | – | arredi al loro posto |
| 774e9c46 | **quasi**: staffe a posto, ma 4 fotogrammi da 34,7-40,3 ms in 3 costruzioni su 20 (vedi sotto) | sì | – | arredi al loro posto |

In nessun log c'è «Invalid Task ID».

## 1. La preparazione del tunnel

Sonda `sonda_fotogrammi_tunnel.gd`. Per ogni versione ho fatto 4 partite: 2 da F9 Inseguimento e 2 dalla torre, cioè la strada vera, in cui il tunnel si carica mentre si è nella torre. Ogni partita ha due costruzioni: la prima, poi una morte e la seconda. Il fotogramma si misura per intero, da un `_process` della sonda al successivo. Con `TORRE_TEMPI` ogni fotogramma lungo porta i segni di quel momento, cioè quale passo del tunnel ci è caduto dentro.

In più, su a9e6f0f4 ho fatto altre 4 partite da F9 Inseguimento, e su 774e9c46 altre 6: 4 da F9 Inseguimento e 2 dalla torre. In queste la sonda dà anche il fotogramma più lungo di ogni fase, contando tutti i fotogrammi e non solo quelli sopra 33 ms.

Fotogrammi sopra 33 ms, il più lungo per fase:

| | Entrata del tunnel | Passi | Dopo i passi e fine |
|---|---|---|---|
| 0.3.24 26f399fe | 86-136 ms in tutte le 8 costruzioni | 33,0-37,3 ms in 5 su 8 | 34-57 ms in tutte le 8 |
| 7bd2a5ec | nessuno | 35,2-39,6 ms in 4 su 8: `_corallo` 23-30 ms, `_relitto_staffe` 28,7, `_relitto_forziere` 34,0, `_palombaro` 31,2 | nessuno |
| a9e6f0f4 | nessuno | 37,4 ms in 1 su 16: `_relitto_staffe` 31,7 ms | nessuno; al più 32,2 ms |
| 774e9c46 | nessuno; al più 20,6 ms | 34,7 ms in 1 su 20, in cui il tunnel lavora solo 14,4 ms (`_acqua_presa`) | 35,0, 35,0 e 40,3 ms in 3 su 20 |

- **La causa su 7bd2a5ec.** Nel gioco vero c'è la sala con la torre e le condotte. Lì Posa, senza un elenco di mesh, guardava tutte le mesh visibili dell'albero, e ogni raggio costava 4-5 ms. a9e6f0f4 le limita alle mesh del tunnel lungo il raggio. Dopo, `_corallo`, `_relitto_forziere`, `_palombaro` e `_salvagente` stanno sotto i 20 ms.
- **`_relitto_staffe` su a9e6f0f4.** Questo passo non usa Posa. `_staffa` prendeva tutti i triangoli dell'ancora con `get_faces()`, due volte, una per staffa, e così arrivava a 20-32 ms. 774e9c46 trasforma i triangoli una volta sola e mette ogni staffa in un passo suo.
- **Il secondo fotogramma dopo il caricamento e dopo la morte.** Nel branch dura 34-53 ms; una volta 170 ms, nella prima partita della giornata a disco freddo. Il tunnel in quel fotogramma non c'è ancora: il branch ne rimanda apposta l'entrata a un fotogramma meno pieno. I segni sono quelli della torre (`EnigmaGiocattoli` disegnato fuori vista). Nella 0.3.24 quello stesso fotogramma era l'entrata del tunnel, da 86-136 ms. Cade mentre lo schermo esce dal nero: la dissolvenza dura circa 1,7 s dopo F9 e 0,4 s dopo una morte. Il primo fotogramma, cioè il caricamento o la morte, non conta.
- **774e9c46: le staffe.** Sono a posto. In 20 costruzioni nessun passo delle staffe supera i 20 ms. I passi più lunghi sono `_tartaruga`, 24,5 ms una volta, e `_pesce_mensola_gap`, 20,2 ms.
- **774e9c46: i fotogrammi sopra 33 ms che restano.** Vengono tutti da F9 Inseguimento:
  - 40,3 ms: il fotogramma in cui finiscono i passi. Dentro ci sono l'ultimo passo `_nebbia_viola` (5,5 ms), `strati_riscaldamento()`, il contesto delle forme e il loro primo pezzo.
  - 35,0 ms due volte, durante le forme dei tentacoli a pezzi (`FormeTunnel.prepara_a_pezzi`). In una di queste è 0,78 s dopo la fine dei passi, con le forme ancora da finire.
  - 34,7 ms nei passi, con 14,4 ms di tunnel.
- **Non c'è un passo colpevole: è il margine.** Nelle partite in più, il fotogramma più lungo delle fasi in cui il tunnel non fa niente vale 10-22 ms: è il gioco nelle condotte e nella torre. Il tunnel ci aggiunge il suo lavoro:
  - nei passi, al più 20-25 ms per passo;
  - dopo i passi, le forme a pezzi.
  
  Nella scena di prova (`sonda_dopo_passi.gd`, su 774e9c46) le forme hanno un budget di 4 ms per fotogramma, ma lavorano 6-14 ms, perché un pezzo da 64 triangoli lo supera. `strati_riscaldamento()` costa 3-4 ms e il contesto delle forme 1-2 ms, tutti nel fotogramma in cui finiscono i passi. Così la fase dopo i passi va da 19 a 40 ms. Su a9e6f0f4 è arrivata a 32,2 ms, quindi non è una cosa nuova di 774e9c46.
- **Proposte per stare sotto i 33 ms:**
  - pezzi più piccoli nelle forme (16-32 triangoli invece di 64), così il lavoro resta vicino ai 4 ms;
  - `strati_riscaldamento()` e il contesto delle forme in un fotogramma loro, non in quello dell'ultimo passo;
  - dividere i passi che superano i 20 ms (`_tartaruga`, `_pesce_mensola_gap`).

## 2. Le ripartenze dal primo checkpoint del tunnel

Sonda `sonda_ripartenze_tunnel.gd`, nel gioco vero. I casi sono tre:

- F9 Tunnel;
- F9 Tunnel e poi due morti di fila al checkpoint 6;
- Continua dopo una chiusura: F9 Tunnel, il salvataggio scritto su disco come quando si arriva al checkpoint 6, l'uscita dal gioco, poi in un processo nuovo il titolo e Continua.

Per ogni ripartenza: i 5 s dopo che lo schermo è libero, l'istante in cui lei riemerge e le forme dei tentacoli. Le forme del tunnel sono confrontate, con un md5 del contenuto, con quelle calcolate da capo sullo stesso tunnel.

| | Fotogrammi sopra 50 ms nei 5 s | Lei riemerge (dall'entrata del tunnel) | Forme |
|---|---|---|---|
| 0.3.24 | 1 per ripartenza: 1070-1272 ms, che comincia a 1,80-1,82 s | 2,86-3,04 s, dopo il blocco | 613, uguali a quelle da capo, ricalcolate ogni volta |
| 7bd2a5ec | **nessuno**; il più lungo 18-22 ms | 1,76-1,82 s | 613, uguali; dalla seconda volta sono quelle tenute |
| 774e9c46 | **nessuno**; il più lungo 18-28 ms | 1,78-1,81 s | 613, uguali, tenute |

- **Lei riemerge nello stesso istante.** Nella 0.3.24 il timer di 2 s fa partire `riemergi` a 1,80-1,82 s dall'entrata. Lì si calcolano le forme, con un fotogramma bloccato di 1,1-1,3 s, e lei esce dopo. Nel branch le forme sono già pronte a schermo nero, e lei esce in quel momento, a 1,76-1,82 s. Il momento di gioco è lo stesso: manca solo il blocco.
- `test_forme_tenute` del branch: 18 controlli su 18, sia su 7bd2a5ec sia su 774e9c46.

## 3. La prima volta nel tunnel

Sonda `sonda_pipeline_prima_volta.gd`, col renderer.

- **Pipeline.** Prima ho fatto il riscaldamento dell'avvio, poi ho costruito il tunnel fuori vista a pezzi, col suo riscaldamento. Poi ho portato il giocatore vero, con la lancia e il campo visivo a 62°, lungo tutti i 356 punti della strada, 4 fotogrammi per punto. Risultato: **0 compilazioni lungo il tunnel**, nella 0.3.24 come nel branch. In tutte e due ci sono 4 surface, 1 draw e 1 specialization solo nei primi 2 fotogrammi del primo punto, quando la sonda aggiunge il giocatore. Sono i materiali del giocatore, che nel gioco c'è già da prima.
- **I materiali campione nell'ordine del gioco.** Prima il riscaldamento dell'avvio, che tiene per tutta la partita anche i campioni del tunnel; poi, a gioco avviato, i campioni come li prende ciascuna versione.
  - 0.3.24, `load` e shader insieme: 2,8 ms sul thread principale.
  - Branch, file dal thread e poi `CampioniTunnel.carica`: 0,1 ms (2,0 ms se fatto come la 0.3.24).
  - In tutti i casi sono gli stessi 23 materiali tenuti dal riscaldamento, e **0 pipeline nuove**.
  - Senza riscaldamento prima, cioè a freddo, che nel gioco non succede, costano 2856 ms con la `load` e 1498 ms dal thread.
- Con llvmpipe i fotogrammi col renderer durano 150-500 ms per il disegno sulla CPU: per i tempi contano le prove senza schermo del punto 1.

## 4. Dagli occhi del giocatore

- **7bd2a5ec.** 12 scatti negli stessi punti della 0.3.24: partenza, rettilineo, curva a U, crollo e gommoni, bocca e interno della galleria, coralli, ancora, forziere, palombaro, approdo, cerniere del portello. Sono uguali: la differenza media è al più 0,18 su 255. Cambiano solo i gommoni, che l'onda sposta di poco. Foglio: `fogli/occhi_0324_7bd2a5ec.jpg`.
- **Arredi su a9e6f0f4.** 11 scatti ravvicinati: coralli a destra, a sinistra e sulla mensola; ancora, staffa e staffe dell'ancora; salvagente da lontano e da vicino; forziere da lontano e da vicino; palombaro. Sono uguali alla 0.3.24: la differenza media è al più 0,11 su 255, e nessun pixel supera 24. Foglio: `fogli/arredi_0324_a9.jpg`.
- **Arredi su 774e9c46.** 6 scatti ravvicinati (coralli, ancora, staffa, staffe, salvagente, forziere), uguali alla 0.3.24: media al più 0,08 su 255.
- Restano attaccati al muro o appoggiati come nella 0.3.24 perché sono proprio gli stessi nodi. Vedi sotto.

## I nodi

- **md5 del tunnel**, con `sonda_tunnel_identico` del gioco: tutte e quattro le versioni danno 2812 nodi. A pezzi `a7dadeed…`, tutto subito `279953ba…`.
- **Tutte le proprietà di ogni nodo**, con `sonda_nodi_tunnel.gd`. Le risorse si confrontano per contenuto. Per il rumore conta solo quello che cambia anche fra due giri della stessa versione: gommoni, ossa di lei e mesh delle onde.

| | Scena di prova, a pezzi | Gioco vero, F9 Inseguimento | Gioco vero, dalla torre |
|---|---|---|---|
| 7bd2a5ec | 2844 nodi, 0 differenze | tunnel 2844, 0; torre 1132, 0 | – |
| a9e6f0f4 | 2844, 0 | tunnel 2844, 0; torre 1132, 0 | tunnel 2844, 0; torre 1140, 0 |
| 774e9c46 | 2844, 1 | tunnel 2844, 1; torre 1132, 0 | tunnel 2844, 1; torre 1140, 0 |

- **La differenza su 774e9c46** è solo `BambinoGalleria.scena`: la scena del bambino agnello, il cui script cambia con dcb33cc2 di torre-robusta. Il file `.tscn` è lo stesso.
- **Gli arredi su a9e6f0f4.** Nel gioco vero le 133 righe di coralli, relitto (ancora, staffe, salvagente, forziere) e sala del palombaro sono uguali byte per byte alla 0.3.24, senza nessun rumore tolto.
- **Le 6 luci rosse delle condotte.** Una sola delle liste di 7bd2a5ec le dà spente. Sono le lampade guaste che si spengono e riaccendono a scatti (`_sfarfalla`). La lista presa 95 s dopo le dà accese, come la 0.3.24.

## Due errori miei, corretti durante il ricontrollo

- **Continua.** La prima sonda faceva F9 Tunnel e usciva. Ma F9 mette l'istantanea del checkpoint 6 solo in memoria: si parte già lì, e `reach_checkpoint` non la riscrive. Su disco restava quindi il salvataggio del Risveglio. Ora la sonda scrive l'istantanea come quando si arriva al checkpoint 6, e prima di premere Continua controlla che il salvataggio sia quello.
- **Le morti.** La finestra dei 5 s partiva col tunnel di prima ancora in scena, quindi prendeva dentro il ricaricamento della sala: fotogrammi da 2,2-2,7 s, sia nella 0.3.24 sia nel branch. Ora la sonda aspetta il tunnel nuovo. I numeri qui sopra sono tutti quelli rifatti.

## Strumenti

Tutti passano da `flock /home/user/tools/render.lock`, con `godot/tests/run.gd`:

- `godot/tests/collaudo/sonda_fotogrammi_tunnel.gd <inseguimento|torre>` (con `TORRE_TEMPI=1`): i fotogrammi lunghi durante la preparazione del tunnel, per fase.
- `godot/tests/collaudo/sonda_ripartenze_tunnel.gd <f9|due_morti|continua_salva|continua>`: le ripartenze. Per `continua_salva` e poi `continua` serve lo stesso `XDG_DATA_HOME`, nuovo.
- `godot/tests/collaudo/sonda_pipeline_prima_volta.gd <diretto|thread> [dopo]` (col renderer): le pipeline lungo la strada. Con `dopo`, i campioni nell'ordine del gioco.
- `godot/tests/collaudo/sonda_nodi_tunnel.gd prova <pezzi|subito> <file>` o `gioco <inseguimento|torre> <prefisso>`: tutte le proprietà dei nodi del tunnel e della torre. Si confrontano con `strumenti/confronta_nodi.py A B [rumore1 rumore2 …]`.
- `godot/tests/collaudo/sonda_dopo_passi.gd [giri]`: nella scena di prova, quanto costano `strati_riscaldamento()`, il contesto delle forme e le forme a pezzi, fotogramma per fotogramma.
- `godot/tests/collaudo/scatti_tunnel_pezzi.gd <cartella> <scatti>` (con `SCATTI_PEZZI=1`, col renderer): gli scatti di `scatti_sottomarino.gd` col tunnel costruito a pezzi.
