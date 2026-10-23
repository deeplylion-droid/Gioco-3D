# Collaudo: lo squalo nuovo della scena del risveglio

Base: `lavoro/squalo-bocca` **2903de31**, con il giro C, i morsi veri, 5 file di denti in più e la bava. Il confronto è con lo squalo di **b8baac74**, la v0.3.11. Squadra collaudo, 23 ottobre. Le posizioni sono nella scena degli interni aperta da sola. Per passare al mondo della sala si aggiungono (-9,7, 0, 40,9).

**Verdetto: non superato.** Due difetti sono nuovi (la bava e i piedi che scivolano). Gli altri c'erano già o sono peggiorati, ma la richiesta li comprende.

## Come è stato fatto

- `sonda_squalo_scena.gd` registra la scena a 60 fotogrammi al secondo, uno su due. Salva le pose delle ossa nel mondo, la camera, la bava (nastri e capi) e la porta tagliafuoco. La pelle a riposo (vertici, ossa, pesi, indici) si salva una volta sola.
- `tools/collaudo/analisi_squalo.py` rifà la pelle deformata come la scena stessa (scheletro × posa dell'osso × matrice di bind). Su questa misura camera, piedi, bava, denti, muri, cartello e porta. Sulle superfici campionate ogni 3-6 mm lavorano `dettagli_squalo.py`, `denti_squalo.py`, `bava_squalo.py` e `parti_squalo.py`.
- Scatti dagli occhi del giocatore: `scatti_squalo.gd`, uno ogni 6 fotogrammi a 640×360 (153) e uno ogni 30 a 1280×720.

## Difetti

| # | Che cosa | Quando | Prima (b8baac74) | Foglio |
|---|---|---|---|---|
| S1 | **La bava non parte e non arriva sulle labbra.** Dei tre fili, il primo ha i capi a 2,5-4,8 cm (sopra) e 5,8 cm (sotto) dalla pelle, il secondo a 0,6-2,2 cm e 3,7 cm. Solo il terzo è sulle labbra (0,8-8 mm). Nell'alta risoluzione si vedono archetti rossi sospesi nel buio della bocca e un filo fuori dall'angolo destro. | tutta la scena, finché la bava è accesa | non c'era | `sq_ritagli.jpg` in basso, `sq_hd.jpg` |
| S2 | **I piedi scivolano mentre toccano terra**: 30 fotogrammi con più di 1 cm di scivolamento (a 6,80 s il sinistro 5,6 cm, a 7,20 il destro 4,9, a 8,73 il sinistro 5,4). Nella corsa, a 10,27 e 10,93, il piede passa a meno di 1 cm dal pavimento facendo 20 cm a fotogramma. | arretra e corsa | 7 fotogrammi | `sq2.jpg` |
| S3 | **Gambe e piedi dentro il pavimento**: da fermo 1,2-1,4 cm (stinchi e piede sinistro, come prima); nel giro, a 8,53-8,67 s, lo stinco sinistro fino a 5,8 cm. | 0-6 s, 8,5-8,7 s | 1,4 cm da fermo, 8,4 cm in altri momenti | |
| S4 | **La mano e l'avambraccio sinistri entrano nel muro nord** fino a 14,9 cm (x 18,56…18,81, y 0,58…0,90). | 8,60-8,77 s | a 6,2 s, in un altro punto del muro nord | `sq_muro.jpg` |
| S5 | **Alla porta tagliafuoco il corpo passa negli stipiti e nell'anta aperta.** Il vano va da z -1,90 a -0,68 nel muro x 22,0…22,2. Le braccia entrano negli stipiti fino a 35 cm (sud, braccio sinistro) e 25 cm (nord, avambraccio destro), la schiena 23 cm, la coda 8 cm. La mano, il braccio destro e la schiena entrano nell'anta aperta (rot 10) fino a 15,5 cm. Sotto l'architrave (y 2,08) invece passa: arriva al massimo a 2,04. | 9,8-10,67 s | stipiti fino a 38 cm, anta 7,5 cm | `sq_porta.jpg` |
| S6 | **Il piede destro sta dentro il cartello del corridoio**: circa 350 vertici dentro la mesh del cartello (x 16,27…16,48, y 0,01…0,12). Dagli occhi del giocatore la gamba sembra attraversare il cartello. | 0-6,7 s | uguale (stessa posa di partenza) | `sq_ritagli.jpg` in alto a destra |

## A posto

- **La camera non entra mai nello squalo.** La distanza minima dalla pelle è 19,5 cm a 6,17 s (prima 22,5). Nessun fotogramma ha la camera dentro, al test degli incroci.
- **I denti** (65 pezzi): nessuno nel vuoto, tutti entro 4 mm da gengiva, bocca o corpo, nei morsi e a bocca aperta. Le file nuove sono piantate nel palato (`bocca_interno`): 39 denti lo attraversano e 14-20 entrano nella gola. Dagli occhi sembrano radicati. Non lo segno come difetto, ma è da sapere.
- **Dopo la scena** il giocatore è come col vecchio squalo:
  - comandi attivi e torcia spenta (com'è voluto all'inizio del gioco);
  - stessa posizione e sguardo a -90 gradi;
  - stesse righe dell'HUD e stesso checkpoint.

  La scena dura 13,87 s invece di 11,95. Il ringhio ora parte quando comincia ad arretrare (6,15 s).
