# Strisce fosforescenti in cima alla scala di servizio (scelta B dell'utente, 0.3.21)

Branch `lavoro/strisce-fosforescenti`, partito da `lavoro/candidata-0321` 46768c5d.

## Cosa cambia
Il codice è in `godot/scripts/risalita/risalita_gioco.gd`, `_materiali_strisce` e `_strisce_cima_scala`.
- Il nastro giallo e nero sul pavimento brilla di un filo di luce propria verde chiaro, come la ciambella del fiume ma molto più debole.
  - Usa un duplicato di `_mat_pericolo`: l'emissione moltiplica la sua texture, quindi brilla solo il giallo. Energia 0,4.
  - I bordi dei gradini restano col materiale di prima.
- La fascia sul muro, bianca e lucida, prende lo stesso filo verde chiaro. Energia 0,05.
- Niente luci nuove, niente alone, niente geometria nuova. Le strisce sono fuori dalla GI (`gi_mode` disabilitato), così non illuminano pavimento e muro intorno.
- I due materiali nuovi stanno nei campioni della risalita (`_campioni`) e il loro shader si crea all'avvio della sala. La lista dei campioni ora è una copia: prima si aggiungeva alla risorsa caricata.

## Scatti
Dalle stesse pose della pagina dell'utente: `godot/tests/collaudo/pozze_giro.gd scala`, gli scatti dal 038 al 047, dalla cima della rampa alla porta di C3.
- `foglio_strisce_prima_dopo.jpg`: prima e dopo, come nel gioco e schiariti 10 volte.
- `foglio_strisce_basso.jpg`: dopo, col preset basso (`PRESET=basso`).

## Misure nello scatto 040
I valori sono da 0 a 255.

| | prima | dopo | preset basso |
|---|---|---|---|
| verde medio nella zona del nastro | 2,5 | 7,0 | 9,4 |
| pavimento lontano dal nastro | 0,96 | 0,96 | 1,08 |
| muro | 0,35 | 0,35 | 0,38 |

Pavimento e muro non cambiano. Col preset basso è tutto un po' più chiaro anche prima: è il preset.
