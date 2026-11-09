# Ricontrollo goccia-riscaldamento 617888f5 (0.3.24)

Fatto da mascotte il 9 novembre su `lavoro/goccia-riscaldamento` 617888f5, contro main 48553e74 (la 0.3.23).

**Esito: SUPERATO.** Il branch non ha difetti. Una sola cosa non si è potuta fare su questa macchina: la strada vera col renderer vero (punto 1).

## 1. Strada vera: 0 compilazioni quando la goccia compare

- **Col renderer vero non si può fare qui.** La sala col Vulkan supera la memoria della macchina: uccisa per memoria a 1280x720 e anche a 320x180, sia con preset alto sia con basso.
- **Al suo posto:**
  - `test_effetti_primo_uso` col renderer vero: «goccia di bava sullo schermo: canvas 0». Senza riscaldamento dà canvas 1 e FAIL, quindi il test vede davvero la goccia;
  - la sonda di grafica-2 `sonda_goccia_pipeline_g2.gd`, col riscaldamento intero della schermata di caricamento: la goccia creata, nascosta e poi accesa per 2,7 s fa canvas +0 in ogni fase;
  - `test_squalo_schermo`, che parte dal titolo e passa dalla schermata di caricamento vera: profilo nuovo 7/7 e profilo provato 6/6, compresi i controlli nuovi sui 10 fotogrammi. È senza schermo (headless), quindi non conta le pipeline.
- **Preset basso:** non l'ho provato a parte col renderer vero. La pipeline 2D della goccia non dipende dal preset.

## 2. Senza riscaldamento (giro interni con la spia, `spia_giro_interni_*.txt`)

| | branch 617888f5 | main 48553e74 |
|---|---|---|
| pipeline della goccia | fotogramma 3, quando nasce sotto il buio | fotogramma 190, quando compare |
| quando compare (4,43 s) | 0 | +1 |

Lo conferma anche la sonda di grafica-2 senza riscaldamento: +1 quando nasce trasparente, +0 quando si accende.

## 3. Nei 10 fotogrammi la goccia non si vede

- **Confronto pixel col main** (che in quei fotogrammi non disegna la goccia), nei primi 14 fotogrammi della scena (`inizio_confronto_pixel.txt`): la differenza massima è 8 su 255 e non c'è nessun pixel oltre 8. È il rumore del JPEG su un'immagine quasi nera, con luminosità media 1-2.
- **Schiariti 40 volte** (`2_primi_fotogrammi_schiariti.jpg`): nessun alone, lampo o forma della goccia.
- **Nel codice:** con forza 0 lo shader dà `COLOR = vec4(0)`, cioè trasparente del tutto.

## 4. Uguale agli scatti approvati della goccia B

`1_goccia_approvati_main_branch.jpg` mette a confronto 4,50, 4,67, 4,83, 5,07 e 6,43 s: approvati (0.3.23), main e branch. La goccia, il filo, la rottura e la scia sono uguali per forma, posizione e resa. Cambiano solo lo sfondo (lo sfarfallio delle luci) e la posa dello squalo, che variano da un'esecuzione all'altra anche fra due giri di main.

## 5. Interruzioni e test

- `test_interni` 73/73, `test_squalo_viola` 15/15;
- `test_continua` 127/127, `test_menu` 85/85 (titolo e pausa);
- `test_squalo_schermo` nuovo 7/7 e provato 6/6;
- `test_effetti_primo_uso` 7/7.

Se la scena si interrompe nei 10 fotogrammi (`_attivo` falso), la goccia resta accesa a forza 0, quindi invisibile, finché i fotogrammi non sono passati. Poi `_muovi_goccia` la nasconde. Se il livello se ne va, la goccia se ne va con lui.
