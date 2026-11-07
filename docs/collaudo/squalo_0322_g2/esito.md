# Collaudo della scena dello squalo della 0.3.22 (grafica-2)

Base: `lavoro/squalo-paura` 86ab11f9, la scena di mascotte (il buio coi tre lampi, ti annusa con la goccia, i morsi imprevedibili).

Esito: **1 difetto** (la camera salta nel buio dopo il terzo lampo) e quattro cose da sapere; il resto passa.

## Come

- **Dagli occhi del giocatore** (`tests/collaudo/giro_squalo.gd`, interni con l'ambiente della sala, preset alto, 30 fps fissi):
  - uno scatto ogni 0,1 s dall'inizio fino a 4 s dopo il controllo restituito (17,33 s): `f_passo_01.jpg`…`07`;
  - gli istanti chiave con GIRO_ISTANTI=paura: `f_ist_01.jpg`, `02`;
  - il video dagli occhi: `squalo_occhi.mp4`, muto (senza schermo l'audio è il driver finto);
  - i dati di ogni fotogramma: `dati_ogni_0_1s.jsonl`.
- **Sonda** `tests/collaudo/sonda_squalo_g2.gd`, a ogni fotogramma:
  - distanza della camera dai muri e salti della camera;
  - ossa di piedi, mani, muso e coda dalle superfici;
  - altezza dei piedi;
  - lampade, goccia, suoni e bocca rispetto alla camera.

  Ha anche gli scatti ravvicinati fuori dalla camera del giocatore (`f_ravv_*.jpg`) e le interruzioni nel gioco vero (`interruzioni.txt`). I numeri sono in `misure.txt`.

## Difetto

**1. La camera salta di mezzo metro nel buio, fra il terzo lampo e la luce che resta accesa.**
- **Quanto:** fra 2,23 e 2,27 s la camera si sposta di 0,52 m in un solo fotogramma (in tutto 0,6 m fra 2,20 e 2,40 s), all'indietro e di lato. La rotazione quasi non cambia: al più 0,9° per fotogramma, misurata senza schermo.
- **Perché:** è la spinta fuori dalla pelle (`_fuori_dalla_pelle`). Lui al terzo lampo è a 0,9 m e la pelle arriva a 0,24 m dalla camera; la spinta sale in un fotogramma.
- **Come si vede:** succede al buio (lampade al 3%). Nel terzo lampo, a 2,0-2,1 s, la camera è sotto il suo mento; quando la luce torna, a 2,4 s, è da un'altra parte, più in basso e più indietro: si vede uno stacco, come un taglio di montaggio.
- **In più:** la camera arriva a 0,234 m dalla pelle a 2,33 s, 6 mm sotto il minimo di 0,24.

## Da sapere

1. **Primo lampo molto scuro.**
   - Primo lampo (0,55 s), lui a 2,8 m: è solo una sagoma nera sul viola, e lo scatto ha una luminosità media di 2,5 su 255 (`lampi13.jpg`, in alto). Su un monitor normale può non vedersi.
   - Terzo lampo, a 0,9 m: lo si vede da sotto, il mento e la gola scuri che riempiono lo schermo, non la faccia (in basso).
   - Il secondo lampo (1,3 s, 1,7 m) si legge bene.
2. **La camera si tira su a scatti.**
   - Da sdraiato (gli occhi a 0,30 m, la testa girata di 25°) a 2,5 s si tira su a sedere: in 0,5 s gli occhi salgono a 0,73 m e la testa si raddrizza (fino a 3,7° per fotogramma, fra 2,6 e 2,9 s).
   - Poi, mentre lui annusa, sale piano in ginocchio fino a 0,98 m (a 5,0 s).
   - Alla fine (15-17 s) si alza in piedi.
   - Non c'è tremolio né scosse ai passi, al richiamo o alla porta (`f_passo_01`-`02`, dati per fotogramma).
3. **Il fiuto non arriva a destra.** Il suono del fiuto è legato alla bocca. Rispetto alla camera la bocca parte 0,42 m a sinistra (2,40 s) e arriva al centro (2,7 s), poi resta al centro, perché la camera la segue girandosi a destra. In cuffia si sente da sinistra al centro, non fino a destra (`misure.txt`, righe FIUTO).
4. **Nella pausa resta il fiato, forte come prima.** Nel file della minaccia, nella pausa a bocca spalancata (6,65-7,45 s), tace il brontolio ma resta il fiato: a 6,9-7,3 s fa -13/-14 dB, forte come prima e dopo. Il silenzio è solo a 6,7-6,8 e a 7,4 s. È come lo vuole il generatore («resta solo il fiato»), ma la pausa non suona come un silenzio: da sentire.
5. **La goccia in pausa.** Se si mette in pausa durante la goccia, la goccia resta disegnata sotto il menu di pausa; ripresa la scena, finisce e sparisce come deve.

## Il resto passa

| cosa | esito |
|---|---|
| Camera dai muri | al minimo 0,31 m (a 0,14 s) |
| Bocca nei morsi | chiusa a 5,95, 6,35 e 7,70 s, i denti incastrati, senza fessura scura (dagli occhi e da tre lati, `f_ravv_01.jpg`) |
| Pausa | bocca spalancata e ferma da 6,65 a 7,45 s |
| Piedi | il piede a terra resta fermo (stessa x e z per tutto l'appoggio) a 0,22 m (l'osso della caviglia), l'altro si alza nel passo fino a 0,37 m; nel buio e nei lampi i piedi poggiano (`f_ravv_*`: le dita sul pavimento). Mani, muso e coda mai dentro i muri: le mani al più a 0,105 m dalla porta mentre ci passa |
| Buio e lampi | lampade al 3% nel buio, 1 nei lampi (0,55; 1,30; 2,00 s), 0 nello sfarfallio a 2,46 s, poi accese da 2,54 s; il relè scatta a 0,56, 1,30, 2,01 e 2,40 s |
| Goccia | compare a 4,41 s e sparisce a 7,10 s; poi più niente |
| Suoni | partono annusa (0,14 s), i tre relè e la luce, goccia (4,40), minaccia (5,00), denti (5,93, 6,33, 7,69), richiamo (8,41), ringhio, sbuffo, i passi, la porta (14,49 s); 2 s dopo la fine non suona niente |
| Fine scena | lampade del corridoio tutte a fattore 1 (16 nella sola zona, 38 nella sala) |
| Interruzioni (gioco vero) | in pausa nel buio le lampade restano al 3% e, ripresa la scena, tornano a 1. Tornando al titolo dal buio o durante la goccia non resta niente. Nuova partita: la scena riparte pulita. Continua: niente scena, lampade a 1, nessuna goccia |
| Compilazioni | all'inizio della scena (3 superfici, 6 disegni, 12 specializzazioni nel primo fotogramma, qualche specializzazione fino a 0,33 s); 4 specializzazioni a 0,83 s (dopo il primo lampo); 1 pipeline 2D alla goccia (4,43 s); niente alla bocca che si apre |
