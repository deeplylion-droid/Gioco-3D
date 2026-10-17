# Proposta: l'agnellino fluorescente (i geni della medusa)

L'idea è dell'utente: la medusa ha modificato l'agnellino con i suoi geni, come le pecore vere rese fluorescenti col gene di una medusa, e ora brilla al buio col rosa dei suoi tentacoli. È solo una proposta e nel gioco non c'è niente.

Il modello e le inquadrature sono gli stessi per tutti: l'agnellino in cima alla scala del corridoio C2, nel punto della tappa 7 dove compare, col blackout.
- `1_buio.jpg`: senza torcia;
- `2_torcia.jpg`: con la torcia;
- `3_vicino.jpg`: da vicino, senza torcia.

Varianti:
- `senza/`: l'agnellino di oggi, per il confronto.
- `a/`: brillano solo le cuciture e i bottoni-occhi. Quando si rivela brillano anche il grande occhio e le cuciture del modello rivelato.
- `b/`: tutto il pelo ha una luminescenza tenue e a chiazze, più forte sul muso.
- `c/`: come la A, ma la luce respira lenta, con un respiro ogni 4 secondi. La pulsazione si vede in `c_respiro.mp4` (5 s, da vicino) e in `c_respiro_fotogrammi.jpg`.

Tecnica:
- Le maschere sono ricavate dalla texture del colore del peluche (`assets_src/agnello_fluo/maschere.py`) e stanno in `godot/assets/models/bambini/proposte_fluo/`.
- Lo script `scripts/creature/agnello_fluorescente.gd` aggiunge l'emissione su copie dei materiali.
- Le scene delle varianti sono in `scenes/creature/proposte/agnello_fluo_{a,b,c}.tscn`; quelle per gli scatti in `tests/scene/agnello_fluo_*.tscn`.
