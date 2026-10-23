# Collaudo: la Risalita caricata nel thread

Base: `lavoro/godot` al commit **7a47e606**: fiume e infermeria caricati nel thread dalla sala pompe (checkpoint 6) e scaricati oltre la serranda (16). Confronto con **12d9c79**, l'ultimo commit con le stanze sempre caricate. Squadra collaudo, 23 ottobre.

## Come è stato fatto

`godot/tests/collaudo/risalita_caricamento.gd` fa lo stesso copione sui due commit, da fuori, come un giocatore: teletrasporti lungo i percorsi veri, checkpoint presi, oggetti cambiati, morti e ripartenze. Scrive righe `RIGA` che si confrontano una per una (`registri/vecchio`, `registri/nuovo`). Gira headless a 60 fotogrammi al secondo a tempo vero (`Engine.max_fps = 60`, senza `--fixed-fps`), perché il thread lavora a tempo vero. I tempi sono di questa macchina (4 CPU, senza schermo): contano i confronti fra i due commit, non i valori assoluti.

| Scenario | Rischio di grafica | Su 12d9c79 | Su 7a47e606 |
|---|---|---|---|
| `impronta`: dopo flash e blackout, ogni nodo delle stanze (posizione, rotazione, scala, visibilità; luci accese, forza, colore, ombre, nebbia; triangoli e materiali) | 5, punto 1 | 1246 nodi | **identici**: 1246 nodi, 0 diversi |
| `corsa`: dal checkpoint 6 di corsa (5,8 m/s) per la sala pompe, la scala, la porta di servizio di C2 e il corridoio fino al capannone (`corsa.csv`) | 1, 6 | stanze sempre lì; fotogramma peggiore 24 ms | porta del capannone mai mancante: 0 fotogrammi con la porta in vista e le stanze assenti o nascoste. **Fermo di 503 ms a 1,9 s dal 6**, vedi sotto |
| `fermo`: in piedi nella sala pompe, 8 s dopo il 6 (`fermo.csv`) | 6 | peggiore 20 ms, 0 sopra 50 ms | stanze pronte in 1,9 s; peggiore **88 ms**, 3 fotogrammi sopra 50 ms |
| `serranda`: stanze cambiate (paratie 1 e 3 girate, cassaforte aperta, cassetti 11 e 23 aperti, radiografia sul negatoscopio, keycard e radiografia raccolte), poi 15, 16, lontano, e ritorno per C3 e la scala di servizio | 2 | uguale | uguale: tutto come lasciato, e i raccolti non ricompaiono |
| `morte`: una paratia girata dopo il 10, un cassetto aperto dopo il 12, poi si muore | 3 | si riparte con lo stato del checkpoint | **uguale** al vecchio, riga per riga |
| `costruzione`: stanze cambiate e scaricate; ripartenza dal 6; il 7 preso mentre il capannone si costruisce a pezzi; poi si muore e si rientra | 4 | (le stanze ci sono sempre) | lo stato messo da parte non si perde |
| `ripartenze`: istantanea con le stanze cambiate, ripartenza da ogni checkpoint dal 5 al 19 | punto 2 | 15 su 15 uguali | 15 su 15 uguali. Le stanze ci sono subito dal 7 al 14 e arrivano quando servono dagli altri |
| `polaroid`: P11 | 7, punto 3 | 10 in totale | 10 all'avvio, con l'infermeria mai caricata, e 10 a stanze caricate. Raccolta, non ricompare dopo scarico, ricarico e morte |
| `uscita`, `uscita2`: si esce durante il caricamento nel thread, o durante la costruzione a pezzi | 8 | chiusura pulita | chiusura pulita (codice 0, circa 2 s) in tutti e due i casi |

## Difetto (grafica)

**Fermo di mezzo secondo nella sala pompe correndo subito dopo il checkpoint 6.**

- Il thread finisce in circa 1,3 s, e la costruzione a pezzi del capannone comincia.
- A 1,9 s il giocatore, a (-2,3, -9,05, 42,1), entra in `_vicino`. `_carica_subito` chiama `finisci_subito`, e il resto del capannone si costruisce in un fotogramma solo: 503 ms su questa macchina, contro i 24 ms del commit vecchio.
- Succede così presto perché la terza zona delle stanze, il corridoio del fiume (AABB da (-5,9, -6,4, 46) a (7,1, 0,6, 68)), allargata di `VICINO` = 4 m arriva a y -10,4 e a z 42. Copre quindi la metà nord della sala pompe, a 10 m dal 6.
- Da fermi gli scatti durante la costruzione restano sotto i 100 ms (88 ms), come misurato da grafica.

Proposta: la zona del corridoio non deve contenere la sala pompe. Basta allargarla meno in basso o verso sud, così la costruzione a pezzi ha il tempo di finire prima che il giocatore ci arrivi.

## Quello che questo collaudo non vede

- Il disegno vero. Headless non si misura il primo disegno delle stanze (shader, ombre, GI) e non si vedono vuoti a schermo. La sala intera col renderer software non sta in memoria insieme al test, quindi gli scatti a schermo non ci sono. L'impronta identica e la porta mai mancante sono controlli di stato, non di immagine.
- Nello scenario `morte`, l'ultimo caso (paratia 2 girata e poi checkpoint 11) non prova niente: l'11 non conta più dopo il 12. È così su entrambi i commit.
