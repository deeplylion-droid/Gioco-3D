# Bersagli da luna park delle paratie (proposta A di grafica-2): scatti dal motore per l'utente

Branch `lavoro/bersagli-luna-park`, partito da `lavoro/candidata-0321` a70f2e95. **Non è unito**: si aspetta il sì dell'utente.

## Cosa cambia
- La faccia del pannello verso la vasca è dipinta come il tiro a segno delle giostre: smalto chiaro, cerchi a pastello a cera sbiaditi e al centro un disegno grande, circa 1 m, dove si mira.
  - **Giusta**: un sole sorridente giallo, cerchi rosa e verde chiaro. L'anello di led verdi, la lampada verde e la trave liscia restano come prima.
  - **Sbagliata**: lo stesso tiro a segno spento e graffiato, con un pesce con gli occhi a croce. I colori sono quasi grigi e la vernice è scrostata fino all'acciaio arrugginito. Lampada rossa guasta e trave a strisce come prima.
- I montanti delle paratie sono ridipinti a strisce caramella, giallo e bianco sporco.
- Al posto dei dischi gialli e neri c'è la pittura. Le nervature del pannello non ci sono più: sul davanti coprivano il disegno, sul retro entravano nella bocca del tubo dietro la paratia (lo ha trovato il controllo di posizionamento).
- Collisioni, sfera di colpo, anello, lampade e vasche non cambiano.

## Come è fatto
- I disegni sono fatti col pastello degli scarabocchi (`assets_src/scarabocchi/pastello.py`), senza immagini fatte con l'IA. Lo script è `assets_src/inseguimento/bersagli/bersagli.py`.
- I modelli escono da `tools/blender/inseguimento_proposte.py A --gioco`.
  - Senza modifiche lo script ridà i file di oggi uguali, salvo un byte per file.
  - Sono cambiati solo `inseguimento_mobili.glb` (i pannelli) e `inseguimento_struttura.glb` (i montanti). Dati, luci, tubi e oggetti restano quelli di prima.

## Scatti
Dal motore: la torre con le condotte, l'ambiente della sala, le luci del blackout e il giocatore vero (`godot/tests/collaudo/scatti_bersagli_g2.gd`).
- In ogni vasca le paratie da dove si spara e ognuna da 2,5 m.
- Nella vasca 1 il getto che colpisce il sole, e lei su.

Il foglio con tutti gli scatti è `foglio_bersagli.jpg`.
