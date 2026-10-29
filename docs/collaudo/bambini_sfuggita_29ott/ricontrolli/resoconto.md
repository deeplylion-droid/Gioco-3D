# Ricontrolli dei bambini visti di sfuggita (29 ottobre, mattina)

Squadra collaudo. Le stesse sonde del collaudo di 3e445450 (`godot/tests/collaudo/monitor_bambini.gd`, aggiornato).
Misura lo scivolamento del piede piantato come `test_bambini_passi`, il giocatore più vicino, le 24 ossa in vista
quando il bambino sparisce, e fa uno scatto radente da davanti.

## fe52c8f7

- D2 (piega della C2) risolto: i piedi non vanno sotto -0,5 cm (prima -14,5).
- D1 molto meglio: corridoio 0,14-0,21 m/s, tunnel 0,2-0,3, C2 0,32-0,37, con qualche fotogramma isolato fino a 2,5.
- Da guardare: nella piega della C2 il piede più basso stava a 0,5 cm e si spostava di 2,4-4 m/s (trascinato).
- Corridoio col bambino col cubo: non tocca stipiti, testa e muri.

## f9b7c8cd

- **Suole del cubo:** toccano terra (`fogli/f9b7c8cd_cubo_suole_radente.jpg`).
- **C2:**
  - il tuffo davanti al buco ha i piedi in aria: nella striscia nessun piede scorre a terra;
  - il punto più basso è a -5 mm;
  - il giocatore non va sotto 1,26 m (dalla capsula alla scatola).
- **D1:**
  - corridoio pulito (al massimo 0,21 m/s);
  - tunnel 3 fotogrammi su 13 sopra 0,5 m/s;
  - C2, svolta di scatto, 8 su 11 fra 0,8 e 2,5 m/s.
  - Negli scatti dagli occhi non si nota: in C2 il bambino è a circa 10 m. Serve il video.
- **Corridoio, difetto:** il cubo sparisce con mezzo corpo in vista.
  - Nel fotogramma prima, 11 ossa su 24 erano in vista dalla camera a 13,6 m (Hips, cosce, gamba e piede destri, Spine, braccio e mano sinistri).
  - Nell'ultimo scatto, 0,2 s prima, è a metà dietro lo stipite (`fogli/f9b7c8cd_corridoio_cubo_alla_porta.jpg`).
  - Spostare l'ultimo punto della fuga non cambia niente: sparisce quando `visibile_da()` dice falso.
  - Probabilmente la griglia di quella funzione (sul piano del bambino) col bambino di fianco finisce dietro lo spigolo prima del corpo.
- 0 righe "ERROR: BUG,"; test_bambini_passi 16/16, test_agnellino 12/12, test_bambini_sfuggita 39/39.
