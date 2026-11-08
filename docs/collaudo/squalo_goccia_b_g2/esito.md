# Ricontrollo della goccia B dello squalo (grafica-2)

Base: `lavoro/squalo-goccia-b` 7ef6ed5b, la goccia B di mascotte, scelta A dell'utente. Scatti approvati: `lavoro/squalo-goccia-b-scatti` 4da5b8c3.

Esito: **superato**, nessun difetto.

## Come

- **Dagli occhi del giocatore**, con `tests/collaudo/giro_squalo.gd` (interni con l'ambiente della sala, 30 fps fissi):
  - con GIRO_ISTANTI=goccia: uno scatto ogni fotogramma da 4,37 a 5,5 s, poi ogni 0,1 s fino a 7,3 s;
  - preset alto in italiano e preset basso in inglese (LINGUA=en).
- **Riscaldamento.** Questo giro salta la schermata di caricamento, quindi con GIRO_RISCALDA=goccia la goccia si disegna prima come la disegna il riscaldamento vero: `RiscaldamentoShader.riscalda_goccia` in un SubViewport 64x64 copiato dalla finestra.
- **Sonda** `tests/collaudo/sonda_squalo_g2.gd`:
  - misure senza schermo a 30 e a 60 fps;
  - interruzioni nel gioco vero.

## Risultati

| cosa | esito |
|---|---|
| Uguale agli scatti approvati | a 4,50, 4,67, 4,83, 5,07 e 6,43 s la differenza media è 0,35-1,0 su 255, cioè gli stessi scatti (`1_confronto_con_approvati.jpg`) |
| Arriva e resta appesa | compare a 4,40 s, schiacciata e tenuta al muso dal filo curvo che pende e ondeggia fino a 4,93 s (circa 0,55 s), con l'attacco sul mento (`2_filo_ogni_fotogramma_alto.jpg`) |
| Il filo si spezza | a 4,97 s si spezza; il capo basso torna nella goccia e quello alto verso il mento; da 5,13 s il filo non c'è più |
| Scivola | ricade un poco e scivola giù sempre più svelta con la scia bagnata (debole nel buio, come negli scatti approvati); sparisce a 7,1 s (`3_scivola_e_scia_alto.jpg`) |
| Preset basso, inglese | stessa sequenza e stessa camera dell'alto (`4_basso_inglese.jpg`) |
| Pipeline | **0** compilate quando compare, con l'alto e col basso. Il riscaldamento della goccia ne compila 3 (2D), prima. Senza riscaldamento se ne compila 1 a 4,43 s, come la goccia A della 0.3.22: nel gioco la toglie il riscaldamento della schermata di caricamento |
| Resto della scena | uguale alla 0.3.22 approvata: camera dai muri al minimo 0,307 m; salto più grande 3,9 cm a 60 fps e 7,7 cm a 30 fps; mano destra a 0,256 m dalle superfici, la sinistra a 0,105 m dalla porta; piedi fra 0,22 e 0,58 m; goccia da 4,45 a 7,15 s; tutti i suoni (goccia 4,42 s); 2 s dopo la fine non suona niente; lampade a 1 |
| Interruzioni (gioco vero) | in pausa durante la goccia, finita la scena la goccia sparisce; tornando al titolo durante la goccia non resta niente; Nuova partita e Continua sono puliti (`interruzioni.txt`) |
| Test | CI 42480775126 verde su 7ef6ed5b (test della scena, degli interni, della luce viola e degli effetti al primo uso, che controlla la goccia: canvas 0) |

## Da sapere

- A 4,43-4,50 s la goccia appena arrivata fa da lente sulla lampada del muro dietro e diventa quasi bianca per 3-4 fotogrammi. Negli scatti approvati è uguale (`1_04_50s.jpg`).
