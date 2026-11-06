# Ricontrollo dei ritocchi di grafica: ripartenze, collisioni, qualità automatica, avvio sicuro, effetti

Squadra collaudo, 6 novembre. Ho controllato `lavoro/ritocchi-grafica` allo sha 3c4d9092. Nel gioco non ho cambiato niente.

Non ho ricontrollato due cose, come chiesto dal coordinatore:
- le pile del fiume, che vengono da `pile_fiume.res` e sono di ambienti-1: le guarda grafica-2;
- il peso delle texture, che l'utente non ha ancora approvato.

## In breve
- **Ripartenze più svelte in tutte e 5 le zone**, nelle stesse misure del "prima" sulla 0.3.20:
  - nella risalita e nel fiume la ricarica passa da circa 6 s a circa 3 s;
  - si riparte sempre dallo stesso checkpoint e nello stesso punto.
- **Collisioni della struttura dell'area bimbi e delle statue**:
  - dopo una e due morti sono identiche a prima, cioè la stessa forma con la stessa impronta dei raggi;
  - camminandoci contro, il giocatore si ferma e non passa.
- **Avvio sicuro** col gioco vero:
  - dopo il processo ucciso la domanda compare, in italiano e in inglese;
  - all'uscita normale con Esci il segno si cancella;
  - all'avvio dopo, la domanda non c'è.
- **Qualità automatica**: test_qualita_automatica, 26 ok. Il primo avvio vero dentro la sala non l'ho fatto (vedi sotto).
- **Effetti al primo uso**: 0 compilazioni che bloccano per gorgo, bava, vapore, medusine e Polaroid.
- Nessun difetto da girare a grafica. **0 BUG** in tutti i log.

## Test
| test | esito |
|---|---|
| test_avvio_sicuro | 17 ok |
| test_qualita_automatica | 26 ok (fra questi: «scelto in automatico: Medio», in inglese «chosen automatically: High», una scelta a mano resta del giocatore, la nebbia resta volumetrica) |
| test_effetti_primo_uso (Vulkan) | 5 ok: gorgo, bava rosa, vapore, medusine, Polaroid, ognuno con 0 compilazioni "surface" e "draw" |
| test_riscaldamento_pipeline (Vulkan) | 11 ok |

Nel test degli effetti il fotogramma più lungo è di 92-294 ms (294 ms per il vapore). Ma su llvmpipe ogni fotogramma ne fa già circa 100, e le compilazioni sono 0: quindi non è uno scatto.

## Ripartenze, prima e dopo
Ho usato `sonda_ripartenze.gd` come per il "prima": senza schermo, tre morti di fila.
- La "scena" è in fotogrammi di gioco.
- La "ricarica" è in secondi veri: va dal cambio di scena al giocatore che si può muovere, compresa la dissolvenza.

| zona | ricarica 0.3.20 | ricarica ora | totale con la scena saltata | scena 1 / 2 / saltata |
|---|---|---|---|---|
| risalita | 5,8-6,7 s | **2,8-3,0 s** | 3,3 s | 5,05 / 5,05 / 1,03 |
| fiume | 5,9-6,3 s | **2,7-2,9 s** | 3,3 s | 5,05 / 5,05 / 1,03 |
| torre | 2,2-2,5 s | **1,8-1,9 s** | 2,3 s | 5,05 / 5,05 / 1,03 |
| tunnel | 3,2-3,3 s | **2,6-2,8 s** | 3,0 s | 4,80 / 4,37 / 1,03 |
| inseguimento | 2,3 s | **1,8-1,9 s** | 2,3 s | 5,05 / 5,05 / 1,03 |

- Si riparte sempre dallo stesso checkpoint, a 0-1 cm da dove si era.
- La scena dalla seconda morte dura ancora 5,05 s. È giusto: la scena da 1 s è di mascotte e non sta in questo branch.
- Grafica, sulla CI, misura il tunnel a 0,9-1,1 s. La mia misura arriva fino al giocatore che si muove, compresa la dissolvenza, quindi viene più lunga.
- Le righe complete sono in `ripartenze_collisioni.txt`.

## Collisioni dopo le ripartenze
Ho usato `sonda_collisioni_ripartenza.gd`, partendo dalla risalita e poi dal fiume. Per la struttura dell'area bimbi e per le tre statue misuro:
- un fascio di raggi verso il pezzo: orizzontali da fuori verso l'asse a 6 altezze, dall'alto in giù e, per la struttura, anche da dentro verso fuori;
- il giocatore vero che cammina contro ogni statua da 4 lati.

Poi faccio due morti, con la ricarica, e rifaccio le stesse misure.

| pezzo | raggi che colpiscono | forma | il giocatore si ferma a | dopo la morte 1 e 2 |
|---|---|---|---|---|
| struttura area bimbi | 66 su 217 | la stessa (739236 facce, colpita anche da dietro) | — | uguale |
| statua squalo | 119 su 121 | la stessa | 1,07 m dall'asse | uguale |
| statua polpo A | 103 su 121 | la stessa | 1,25 m | uguale |
| statua polpo B | 103 su 121 | la stessa | 1,08 m | uguale |

Le impronte dei raggi sono identiche prima e dopo, e anche fra la partenza dalla risalita e quella dal fiume.

## Avvio sicuro, col gioco vero
Il gioco è partito senza `--script`, su Vulkan con Xvfb, con tasti veri mandati da XTEST. Il foglio è `fogli/avvio_sicuro.jpg`.

Cosa ho fatto e cosa è successo:
1. **Avvio, poi processo ucciso** (`kill -9`): il segno `user://sessione_aperta` resta.
2. **Riavvio**: «Safe start?» in inglese (la lingua del sistema della macchina è l'inglese), oppure «Avvio sicuro?» con `LINGUA=it`. Sotto c'è la frase che spiega, e il focus è su «Avvio sicuro».
3. **«Avvio normale»**: si torna al titolo come sempre.
4. **«Esci» dal titolo**: il gioco si chiude in 2-4 s e il segno si cancella.
5. **Riavvio dopo l'uscita normale**: niente domanda, il titolo è normale.

Due note sullo strumento, non sul gioco:
- Il messaggio di chiusura della finestra mandato da fuori (la X, senza window manager) il gioco non lo riceve. Per questo l'uscita normale l'ho fatta da Esci.
- Al primissimo avvio, dopo 60 s, lo schermo era ancora nero: su llvmpipe si compilano gli shader per la prima volta. Gli avvii dopo mostrano il titolo.

Il cambio di driver (Vulkan e DirectX 12) vale solo su Windows, e qui non si può provare: lo copre test_avvio_sicuro.

## Qualità automatica: cosa non ho potuto fare
Il primo avvio vero va dentro la sala principale col renderer, e qui non si può fare: la sala intera arriva a 12-13 GB, e la regola è di lavorare solo a parti.

Il resto è coperto da test_qualita_automatica (26 ok), che controlla:
- la scelta fra Medio, Alto e Ultra;
- la scritta «scelto in automatico: …» in italiano e in inglese;
- la scelta a mano che resta del giocatore.

Da guardare sul PC dell'utente:
- i 2-3 s di nero al primo avvio;
- quale qualità sceglie.
