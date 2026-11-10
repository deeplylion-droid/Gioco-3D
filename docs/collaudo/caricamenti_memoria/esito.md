# Ricontrollo caricamenti-thread 7bd2a5ec (0.3.25): caricamenti e memoria

Fatto da mascotte il 10 novembre. Il branch parte da 7bf1ed69 ed è 55 commit indietro rispetto a main. L'ho unito in locale a main 26f399fe (la 0.3.24) e l'unione (8231ba89) non ha dato conflitti. L'unione non è spinta: è come sarà nella candidata. Ogni prova è fatta sull'unione e su main, con la stessa sonda (`sonde/`). Senza schermo, perché la sala col Vulkan non ci sta nella memoria della macchina.

**Esito: SUPERATO, tranne un difetto che esce a volte (in fondo), girato ad ambienti-2.**

## 1. Sagome e load()

- **Le 12 sagome sono identiche a main** (`sagome_*.txt`): posizione, rotazione, file, dimensione e dati dei pixel dell'immagine, forma della mesh.
- **A gioco avviato nessun load() sopra 5 ms** sul thread principale (`sonda_load_controllo.txt`). È il passo della CI: codemod, test_attesa_zone e test_partenze_prova, cioè dal risveglio al tunnel. I load() sono 133, tutti sotto 5 ms.
- **Scatti delle sagome:** non si possono fare, perché la torre con l'inseguimento col Vulkan non ci sta in memoria. Il confronto dei dati sopra li sostituisce.

## 2. Suoni

- **I 140 suoni del Catalogo sono identici a main** (`suoni_*.txt`): stessi file, stessa durata, stesso ciclo. Lo stream è lo stesso, cambia solo da dove arriva, quindi l'attacco non cambia.
- **Al primo uso costano 2,0 ms in tutto sul thread principale**, contro 57,4 ms su main. Il più lento passa da 3,2 a 0,13 ms.
- **Partenze F9 inizio, inseguimento e tunnel, 15 s ciascuna:** i suoni fissi sono gli stessi. Gocce, tuoni e lei sono casuali e cambiano già fra due giri di main.
- **Memoria:** al titolo, 10 s dopo l'avvio, la memoria statica è 352,9 MB contro 307,2 su main: **+45,7 MB**, con 250 file in cache contro 13. Il commento nel codice dice 9 MB: **da correggere il numero o da sapere.** In gioco la differenza scende a circa +8 MB, perché su main i suoni arrivano comunque giocando.

## 3. Ripartenze e memoria (`memoria_e_ripartenze_*.txt`)

| | main 26f399fe | unione |
|---|---|---|
| ripartenza in torre, giocatore di nuovo in gioco | 2,5-2,6 s (la prima 3,1) | 2,0 s (la prima 2,5) |
| ripartenza nell'inseguimento | 2,6 s (la prima 3,0) | 2,0 s (la prima 2,3) |
| memoria statica in torre, 6 ripartenze | 1973,9 → 1974,0 MB | 1981,9 → 1981,9 MB |
| memoria statica nell'inseguimento, 6 ripartenze | 1974,0 → 1974,4 MB | 1981,9 → 1982,0 MB |
| tunnel, F9 dopo la torre | 1209,9 MB | 1217,6 MB (+7,7) |
| tunnel, 2 ripartenze | 1601,6 / 1602,0 MB | 1608,9 / 1608,9 MB (+7) |
| al titolo | 750,5 MB | 756,0 MB |
| partita nuova | 750,9 MB | 756,0 MB |

- **Ripartenze:** 0,6 s in meno, cioè −23%. In 6 ripartenze di fila la memoria non cresce.
- **Oggetti:** +1 oggetto a ogni morte, uguale su main.
- **Le risorse tenute (GameState._tenute):**
  - 53 in torre e nell'inseguimento;
  - **0 nel tunnel, al titolo e con una partita nuova**, con la scena della torre fuori dalla cache.
  - Nel tunnel la memoria è nei ±20 MB di main.

## 4. Errori nei log (`riassunto_prove.txt`)

- **Uguali a main:** sono gli stessi 11-16 ERROR di chiusura del motore (RID e risorse ancora in uso all'uscita) in avvio, suoni, sagome, morti, tunnel e titolo, partenze, ripartenze oltre il portone, memoria, Continua e forme tenute.
- **test_guado:** 0 SCRIPT ERROR, contro 4 su main.
- **Test verdi:** partenze 74/74, oltre il portone 53/53, memoria 2/2, Continua 127/127, guado 11/11, forme tenute 18/18.

## Il difetto (girato ad ambienti-2)

- **Dove:** in test_partenze_prova, nella partenza «tunnel» subito dopo «inseguimento» con la sua morte, mentre si costruisce la sala, compaiono 94-95 righe «ERROR: Parameter "material" is null». Vengono da `material_get_instance_shader_parameters` (renderer finto), backtrace `dettagli_sala.gd:107`, `_ready`, dove si liberano le scene sorgente dopo `UnificaMateriali.unifica`.
- **Quanto spesso:** sull'unione **1 lancio su 4**, su main 0 su 3.
- **Le copie in scena sono a posto:** dopo F9 inseguimento, una morte e F9 tunnel, le 213 superfici dei dettagli della sala hanno tutte un materiale valido. L'errore viene dai nodi sorgente che si liberano.
- **Cosa manca:** quando arriva la correzione, rifaccio test_partenze_prova sull'unione più volte, con 0 righe. Lo scatto ravvicinato dei dettagli col renderer vero dipende dalla memoria: la sala col Vulkan qui non ci sta.

## Correzione 0ee1311d (con 6b4a165b): rifatto

La correzione di ambienti-2 mette le forme tenute in `forme_tenute.gd`, senza dipendenze: GameState non compila più SalaSottomarino e il bambino agnello all'avvio. L'ho unita in locale a main 26f399fe (57953b61, nessun conflitto) e ho rifatto le due prove:
- test_partenze_prova 4 volte di fila: 74/74 ogni volta, **0 righe «material is null»** (prima 1 volta su 4);
- test_bambini_passi 2 volte: 24/24 ogni volta, **0 righe** (ambienti-2 le vedeva 4 volte su 4 prima della correzione).

Nel commento dei suoni ora c'è il numero vero (+45,7 MB al titolo, circa +8 MB in gioco).

**Esito finale: SUPERATO.**
