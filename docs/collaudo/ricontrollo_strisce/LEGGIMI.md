# Ricontrollo delle strisce fosforescenti in cima alla scala di servizio (enigmi, 6 novembre)

- Branch ricontrollato: `lavoro/strisce-fosforescenti`, punta `b89c8fc0` di grafica-2. È partito da `46768c5d`, che
  qui fa da "prima". La CI della punta è verde.
- Gli scatti sono di `godot/tests/collaudo/pozze_giro.gd scala`: col giocatore vero, dalla porta stagna su per le rampe
  fino alla porta di C3, poi giù.
  - Ambiente vero (`VERO=1`), cioè con SDFGI, nebbia volumetrica e SSIL accese.
  - Luci del blackout, 960x540.
  - Un fotogramma ogni 15, gli stessi numeri prima e dopo.
- Il preset basso col fotogramma "prima" l'ho fatto con una copia di `pozze_giro.gd` che accetta `PRESET`.
- Nei fogli, "x10" vuol dire la stessa immagine schiarita 10 volte.

## Esito: passa

1. **Dagli occhi, su e giù** (foglio 1, normale e x10).
   - Nel corridoio buio verso C3, prima le strisce non si vedevano. Adesso il nastro è una serie di righe verdi sottili
     che porta alla porta, e la fascia è un filo verde chiaro sul muro.
   - Pavimento e muro intorno restano neri anche schiariti 10 volte: nessuna luce attorno.
   - Nel tratto rosso in cima alla rampa le strisce si vedono appena e non cambiano il resto.
2. **Bordi dei gradini delle rampe** (foglio 2): uguali a prima, nelle stesse pose, salendo e scendendo.
   - Nel codice il nastro è un duplicato di `_mat_pericolo`. I bordi dei gradini usano ancora `_mat_pericolo` con
     `_box`.
   - `gi_mode` disabilitato vale solo per `_striscia`, che fa soltanto nastro e fascia.
3. **Preset basso** (foglio 3).
   - Le strisce si vedono come nell'alto.
   - Il muro e il soffitto rosa del corridoio verso C3 c'erano già prima, sempre col preset basso. È il preset, non le
     strisce.
4. **Pipeline** (`godot/tests/collaudo/pipeline_strisce.gd`).
   - Ho caricato la Risalita della scena di prova con l'ambiente vero e guardato tutto con le strisce nascoste: rampe,
     corridoio e porta.
   - Poi ho mostrato le strisce: 0 compilazioni "surface", 0 "draw" e 0 "specialization" nei fotogrammi dopo.
   - Il materiale del nastro ha uno shader che il riscaldamento dell'avvio non ha; quello della fascia sì. Si compila
     comunque mentre la sala si carica, dietro la schermata, perché le strisce ci sono dall'avvio della sala: al primo
     sguardo non si ferma niente.
   - Prima della modifica: 0, 0, 0 anche lì.
   - Riscaldamento e Risalita insieme non stanno nella memoria del sandbox con llvmpipe. Il riscaldamento da solo si
     può aggiungere con `RISC=1`.
5. **Posizionamento**, tutte le zone, sulla punta: 0 nuovi, 0 da correggere, 0 eccezioni sparite. `NastroCimaScala` è
   controllato, coi suoi 26 oggetti, negli stati inizio, risalita_arrivo e risalita_dopo.

## Fogli

1. `1_cima_scala_prima_dopo.jpg`: dalla cima della rampa alla porta di C3.
2. `2_rampe_bordi_dei_gradini.jpg`: le rampe salendo e il corridoio scendendo.
3. `3_preset_basso.jpg`: prima e dopo, col preset basso.
