# Proposte: nuove mascotte (18 ottobre)

Render Cycles (CPU, denoiser) di modelli 3D Meshy veri. Per ogni variante: `tre_quarti`, `davanti`,
`lato`, `dettaglio` (fondo grigio) e `buio` (piastrelle bagnate, luci d'emergenza, torcia di 40° dalla camera).
Le statue hanno anche `_nuova_tre_quarti` e `_nuova_buio`: lo stesso modello con la vernice fresca del 1995.

| Variante | Modello | Triangoli |
| --- | --- | --- |
| Statua squalo A: pollice in su, salvagente, pantaloncini da bagnino | `assets_src/mascotte/statua_squalo_A.glb` | 430.078 |
| Statua squalo B: cappello da marinaio, fischietto, tavola da surf dipinta | `assets_src/mascotte/statua_squalo_B.glb` | 364.352 |
| Statua polpo A: braccia aperte a salutare, cappello da marinaio, papillon a pois | `assets_src/mascotte/statua_polpo_A.glb` | 535.196 |
| Statua polpo B: maschera da sub, salvagente, pallone e gelato | `assets_src/mascotte/statua_polpo_B.glb` | 771.566 |
| Mostro-squalo A: vicino al disegno, a goccia, mano alzata | `assets_src/mascotte/mostro_squalo_A.glb` | 313.334 |
| Mostro-squalo B: più horror, curvo, cirripedi, artigli lunghi | `assets_src/mascotte/mostro_squalo_B.glb` | 495.172 |

Texture PBR di Meshy a 4096 e 2048 px. Statue alte 2,3 m col basamento, mostri 2,2 m. Modelli grezzi
(non ancora ridotti per il gioco). Come rigenerarli: `assets_src/mascotte/meshy_mascotte.py`, render con
`assets_src/mascotte/render_tutti.sh`.
