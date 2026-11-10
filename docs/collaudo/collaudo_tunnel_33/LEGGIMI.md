# Ricontrollo di `lavoro/tunnel-fotogrammi-33` 90504558 (0.3.26, enigmi, 10 novembre)

Le correzioni di ambienti-2 partono da 774e9c46 (torre-robusta, nella 0.3.25):

- forme dei tentacoli a pezzi da 16 triangoli, con le facce copiate una volta sola;
- il contesto delle forme e `strati_riscaldamento()` in un fotogramma loro;
- la prima `get_faces()` di pesce, tartaruga, ancora e salvagente nel thread, all'inizio della costruzione;
- i triangoli di tartaruga e pesci a passi;
- la griglia dell'acqua della presa fatta una volta sola.

Ho confrontato tutto con 774e9c46, con le sonde del ricontrollo precedente (`lavoro/collaudo-caricamenti-tunnel`, che resta il riferimento per i metodi) e qualcosa in più. Le prove dei tempi sono nel gioco vero, senza schermo; gli scatti sono col renderer. Le righe dei log sono in `risultati.txt`.

## Esito

| | Esito |
|---|---|
| 1. 20 costruzioni senza fotogrammi sopra i 33 ms | **quasi**: 1 fotogramma da 34,1 ms, e non è rumore: lavorava il tunnel (`_pesce_mensola_piede`, 15,5 ms). Già passato ad ambienti-2 |
| 2. md5, nodi, forme e arredi uguali a 774e9c46 | **sì** |
| 3. Ripartenze | **sì** |

In nessun log c'è «Invalid Task ID».

## 1. Le 20 costruzioni

10 partite, 6 da F9 Inseguimento e 4 dalla torre, con la sonda `sonda_fotogrammi_tunnel.gd` e `TORRE_TEMPI`. Ogni partita ha due costruzioni: la prima, poi una morte e la seconda. Dopo che il tunnel è pronto la sonda resta 10 s a tunnel fermo (non 3 come prima), per avere il rumore della macchina.

Per ogni fotogramma sopra i 33 ms la sonda scrive il lavoro del tunnel segnato in quel fotogramma e in quello prima. Sono i segni di `RiscaldamentoShader`: i passi sopra 3 ms e, ora, anche i pezzi delle forme sopra 3 ms. Senza segni, il tunnel in quel fotogramma lavora al più il suo budget (6 ms nei passi, 4 ms nelle forme) più un passo da meno di 3 ms.

Il fotogramma più lungo per fase. Il primo fotogramma dopo il caricamento o la morte non conta:

| | Entrata | Passi | Dopo i passi | Tunnel fermo, 10 s |
|---|---|---|---|---|
| 774e9c46 (20 costruzioni) | ≤ 20,6 ms | ≤ 26,2; **34,7** una volta | 18,7-31,4; **35,0, 35,0, 40,3** | (3 s) ≤ 22,4 |
| 90504558 (20 costruzioni) | 7,4-18,5 ms | 16,7-24,6; **34,1** una volta | 12,9-27,0 | 14,6-27,5; **39,3** una volta |

**Il fotogramma da 34,1 ms** (partita 1 da F9 Inseguimento, seconda costruzione, nei passi) non è rumore.

- In quel fotogramma è segnato un passo solo, `_triangoli_poi` da 15,6 ms; dentro c'è `_pesce_mensola_piede`, 15,5 ms. Nel fotogramma prima non è segnato niente.
- Adesso i triangoli del pesce arrivano a passi. Ma il passo finale, quello che trova il piede del palo, gira ancora in una volta su tutti i vertici del pesce: per ogni vertice 2 prodotti scalari e 3 confronti.
- In un fotogramma in cui il tunnel lavora 15-16 ms basta un gioco un poco più lento del solito per passare i 33.
- L'ho mandato al coordinatore. Proposta: il punto più basso calcolato insieme ai triangoli, o quel giro a pezzi.

**Il rumore, misurato.** A tunnel fermo, in 20 × 10 s (28 928 fotogrammi):

- un solo fotogramma sopra i 33 ms: 39,3 ms, senza nessun segno del tunnel né in quel fotogramma né in quello prima;
- tutti gli altri fotogrammi stanno sotto i 27,5 ms.

Qui quindi il rumore sopra i 33 ms c'è, ma è raro: uno su circa 29 000. Non ho visto i 33-89 ms a tunnel fermo di cui parla ambienti-2.

**Il resto della preparazione è migliorato rispetto a 774e9c46:**

- nessun passo supera i 20 ms; su 774e9c46 c'erano `_tartaruga` a 24,5 e `_pesce_mensola_gap` a 20-22;
- la fase dopo i passi arriva al più a 27,0 ms, contro i 40,3 di prima;
- nei segni ci sono anche i pezzi delle forme sopra 3 ms, e nessuno compare nei fotogrammi lunghi.

**Subito dopo il caricamento o la morte** (fuori dalla preparazione, il tunnel non c'è ancora):

- il secondo fotogramma fa 21-50 ms; una volta 124 ms, nella prima partita, con il disco freddo dopo l'import;
- in quei fotogrammi non c'è nessun segno del tunnel, solo quelli della torre (`EnigmaGiocattoli` disegnato fuori vista);
- come nella 0.3.25, cadono mentre lo schermo esce dal nero.

## 2. md5, nodi, forme e arredi

- **md5 del tunnel** (`sonda_tunnel_identico`): a pezzi `a7dadeed…`, tutto subito `279953ba…`, 2812 nodi. Uguali a 774e9c46.
- **Nodi**, con tutte le proprietà (`sonda_nodi_tunnel.gd`, `confronta_nodi.py`), confrontati con 774e9c46. Per il rumore conta solo quello che cambia anche fra due giri della stessa versione:
  - scena di prova, a pezzi: 2844 nodi, 0 differenze;
  - gioco vero da F9 Inseguimento: tunnel 2844, torre 1132, 0 differenze;
  - gioco vero dalla torre: tunnel 2844, torre 1140, 0 differenze.
  - Le 686 righe di arredi, pesci, tartaruga e acqua della presa sono uguali byte per byte, nella scena di prova e nel gioco vero.
- **Forme dei tentacoli.** In tutte le 20 costruzioni le forme fatte a pezzi da 16 triangoli sono 613, con la stessa impronta delle forme calcolate da capo sullo stesso tunnel e di quelle di 774e9c46 (`425c3e1fcdbd`). Lo conferma anche `sonda_forme_pezzi` del branch: a pezzi 613, subito 613, uguali.
- **Scatti ravvicinati**, 18 negli stessi punti su 774e9c46 e su 90504558:
  - coralli (tre), ancora, staffa e staffe dell'ancora, salvagente (due), forziere (due), palombaro, vetrina;
  - e, nuovi, la tartaruga e 5 pesci (0, 7, 10, 15, 21): la camera va a 2 m dal centro delle loro mesh, dalla parte del canale.
  - Sono tutti uguali: la differenza media è al più 0,4 su 255 e quasi nessun pixel supera 24.
  - Nella tartaruga la media sale a 1,2 solo per il cielo che si muove sullo sfondo (`fogli/tartaruga_confronto.jpg`): la tartaruga, le catene e i faretti sono identici.
  - Foglio: `fogli/arredi_774e9c46_90504558.jpg`.

## 3. Le ripartenze dal primo checkpoint del tunnel

Sonda `sonda_ripartenze_tunnel.gd`, come nel ricontrollo precedente:

| | Fotogrammi sopra 50 ms nei 5 s | Il più lungo | Lei riemerge (dall'entrata) | Forme |
|---|---|---|---|---|
| F9 Tunnel | 0 | 23,2 ms | 1,78 s | 613, uguali, tenute |
| Due morti di fila (F9, morte 1, morte 2) | 0, 0, 0 | 23,9, 27,5, 25,4 ms | 1,78, 1,77, 1,77 s | uguali |
| Continua dopo una chiusura | 0 | 18,5 ms | 1,79 s | uguali |

Lei riemerge nello stesso istante che su 774e9c46 (1,78-1,81 s). `test_forme_tenute`: 18 controlli su 18.

## Strumenti

Le sonde sono in `godot/tests/collaudo/`. Le uso come nel ricontrollo precedente, con queste aggiunte:

- `sonda_fotogrammi_tunnel.gd`:
  - per ogni fotogramma lungo, il lavoro del tunnel segnato in quel fotogramma e in quello prima;
  - il fotogramma più lungo di ogni fase;
  - `FERMO_S=10`: i secondi a tunnel fermo dopo il tunnel pronto;
  - `CONFRONTA_FORME=1`: dopo ogni costruzione, le forme fatte a pezzi confrontate con quelle calcolate da capo, fuori dalla misura.
- `scatti_tunnel_pezzi.gd`: gli scatti `nodo:<nome>`, ravvicinati di un nodo del tunnel per nome.

## Ricontrollo della correzione del pesce: 268a13b4

`lavoro/tunnel-fotogrammi-33` 268a13b4 ha tre correzioni nuove:

- il punto più basso del piede del pesce si calcola nello stesso giro dei triangoli (c6d2071b), e così sparisce il passo `_pesce_mensola_piede` da 15,5 ms;
- la porta tagliafuoco del Risveglio (a13e3ea6);
- `sonda_tunnel_entrata` (268a13b4).

Come chiesto, ho rifatto le costruzioni da F9 Inseguimento: 6 partite, 12 costruzioni, con la stessa sonda, 10 s a tunnel fermo e le forme confrontate. In più ho controllato md5, nodi e gli scatti ravvicinati di pesci e tartaruga.

**Esito: superato.**

- **Nei passi nessun fotogramma supera i 33 ms.**
  - Il più lungo per costruzione va da 18,8 a 32,8 ms.
  - `_pesce_mensola_piede` non compare più.
  - C'è un solo passo sopra i 20 ms, `_buco_anello` da 27,6 ms, una volta (partita 4, seconda costruzione). Il suo fotogramma resta sotto i 33 ms, ma di poco: il fotogramma più lungo dei passi di quella costruzione è 32,8 ms. Il margine qui è stretto.
- **Un fotogramma da 33,3 ms dopo i passi, ed è rumore dimostrato.**
  - Cade 2,72 s dopo la fine dei passi, mentre si fanno le forme a pezzi (seconda costruzione della partita 3).
  - Nei segni di quel fotogramma e dei due prima non c'è niente: nessun pezzo delle forme sopra 3 ms.
  - Il tunnel quindi ci ha lavorato al più il suo budget di 4 ms più un pezzo sotto i 3 ms. Il resto, almeno 26 ms, è il gioco.
  - Lo stesso succede a tunnel fermo: in 17 278 fotogrammi a tunnel fermo ce n'è uno da 52,5 ms senza nessun segno del tunnel, e gli altri arrivano fino a 19,9 ms.
  - Altrove la fase dopo i passi resta fra 17,1 e 25,4 ms.
- **Entrata:** al più 22,3 ms.
- **Subito dopo il caricamento o la morte:** il secondo fotogramma, quando il tunnel non c'è ancora, fa 30,7-55,1 ms (104,9 ms nella prima partita, a disco freddo). Ci sono solo segni della torre.
- **Forme:** in tutte le 12 costruzioni sono 613 e uguali a quelle calcolate da capo (`425c3e1fcdbd`).
- **md5 del tunnel:** uguali (`a7dadeed…`, `279953ba…`).
- **Nodi:** uguali a 90504558, con 0 differenze.
  - Scena di prova: 2844 nodi. Le 585 righe di arredi, pesci e tartaruga sono uguali byte per byte, quindi i pesci stanno esattamente dove stavano.
  - Gioco vero da F9 Inseguimento: tunnel 2844 nodi, torre 1132.
- **Scatti ravvicinati:** i 5 pesci sono uguali a 90504558. Anche la tartaruga è identica: tutte le differenze sono nelle prime 160 righe dell'immagine, cioè nel cielo che si muove (`fogli/tartaruga_268a13b4.jpg`).
- In nessun log c'è «Invalid Task ID».

Le righe dei log sono in `risultati_268a13b4.txt`.

Una correzione alla sonda: nella prima serie di questa versione, per i fotogrammi lunghi dopo i passi, la riga del lavoro segnato veniva sovrascritta. I segni grezzi sulla stessa riga erano però completi, e per il 33,3 ms dicono «nessuno». Dalla partita 4 la riga è completa.
