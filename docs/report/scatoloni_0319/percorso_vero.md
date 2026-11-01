# Corridoio delle pile nel percorso vero (CI, run 41319002451)

Gioco vero renderizzato (Vulkan software, 1280x720, swap 24 GB), dopo il caricamento: partenza F9 "risalita" (fiume dal thread, disegna_fuori_vista, riaccensione a pezzi) e, per confronto, "fiume". Media / mediana / 10%:

| punto | 0.3.18 risalita | 0.3.19 risalita | 0.3.18 fiume | 0.3.19 fiume |
|---|---|---|---|---|
| porta d'ingresso | 29,8 / 21,7 / 7,0 | uguale | uguale | uguale |
| corridoio 1 | 22,8 / 20,2 / 4,7 | uguale | uguale | uguale |
| corridoio 2 | 15,5 / 11,6 / 1,1 | uguale | uguale | uguale |
| corridoio 3 | 12,0 / 6,8 / 0,1 | uguale | uguale | uguale |
| corridoio 4 | 13,9 / 9,1 / 0,9 | uguale | uguale | uguale |
| imbarco | 8,6 / 4,4 / 0,1 | 8,7 / 4,5 / 0,1 | 8,6 / 4,4 / 0,1 | 8,6 / 4,4 / 0,1 |

Identiche: l'ipotesi del riscaldamento non regge. Nella 0.3.18 alla fine 4 "ERROR: BUG, indexing did not unpair" (quelli tolti da Strati nella 0.3.19), senza effetto sulla luce. Foglio: foglio_percorso_vero.jpg.
