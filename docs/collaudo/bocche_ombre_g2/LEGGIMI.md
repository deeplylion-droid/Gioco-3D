# Bocche dell'inseguimento e ombre delle lampade verdi (grafica-2, 0.3.21)

Branch `lavoro/bocche-ombre-g2`, partito dalla candidata `lavoro/candidata-0321` b44dfab7. "Prima" è la candidata: la parete delle bocche con `water_inseguimento.gdshader` e l'ombra su tutte e tre le lampade verdi.

## 1. La parete d'acqua delle bocche vista da dentro il tubo
- Le pareti delle bocche (`SalaInseguimento._veli_bocche`) usano uno shader nuovo, solo loro: `godot/shaders/water_inseguimento_velo.gdshader`. L'acqua delle vasche resta `water_inseguimento.gdshader`, com'era.
- Da dentro il tubo la parete è piena (alfa 1). Il fondo della vasca si intravede sfocato, perché si legge dallo schermo a una mipmap bassa. È anche mosso da onde lente e tinto dall'acqua.
- Il colore dell'acqua è lo stesso in tutte e sei le bocche, come nella candidata.
- Dalla vasca la parete si vede da dietro, come prima.
- Foglio: `bocche_prima_dopo.jpg`, dalle pose di `scatti_bocche_da_sotto.gd confronto`, cioè a 1 m dentro ogni tubo guardando la vasca.
  - Prima si vedevano le piastrelle nitide con le macchie di luce (tubi 2 e 3) e la griglia (scolo 1).
  - Dopo il fondo è una macchia verde sfocata e mossa.
- Misura del dettaglio nella parte bassa dello scatto (media della differenza dall'immagine sfocata; dentro c'è anche il getto in mano, quindi non scende a 0):

  | bocca | prima | dopo |
  |---|---|---|
  | tubo_1 | 2,45 | 2,48 |
  | tubo_2 | 3,35 | 2,96 |
  | tubo_3 | 3,00 | 2,40 |
  | scolo_0 | 2,91 | 2,35 |
  | scolo_1 | 2,76 | 2,06 |
  | scolo_2 | 3,53 | 3,26 |

## 2. Le ombre delle lampade verdi delle paratie
- L'ombra resta solo sulla lampada verde della paratia giusta della vasca 3 (66,95; -24,35; -3,6), quella che faceva la riga verde nel tubo 3. Le altre due tornano senza, com'erano prima della candidata. Nella scena le luci con ombra passano da 48 a 46.
- La riga nel tubo 3: come nella candidata, sparita (`riga_tubo_3` in fondo al foglio delle bocche).
- Dalle vasche (`paratie_verdi_prima_dopo.jpg`): le paratie verdi 0 e 2 tornano senza ombra. Cambia il 3,5% dei pixel, un po' più chiari. La 4 è uguale.
- Tempi del fotogramma con `sonda_ombre.gd` del collaudo, su llvmpipe a 960x540, due giri. Contano le proporzioni. Ogni configurazione è misurata nei due giri, e la differenza fra i giri dà il rumore (`ombre.txt`):

  | posa | tre ombre | solo vasca 3 (il gioco) | nessuna |
  |---|---|---|---|
  | paratia verde 0 | 981 / 944 ms | 905 / 856 ms | 859 / 826 ms |
  | paratia verde 2 | 1506 / 1608 ms | 1472 / 1483 ms | 1379 / 1513 ms |
  | paratia verde 4 | 2088 / 2120 ms | 2031 / 2048 ms | 1940 / 1974 ms |
  | tubo 3 da dentro | 564 / 639 ms | 625 / 620 ms | 591 / 574 ms |
  | punto peggiore | 952 / 860 ms | 864 / 820 ms | 794 / 787 ms |

  - Il costo resta dove serve, davanti alla paratia della vasca 3: circa +4% su "nessuna".
  - Altrove si torna vicino a "nessuna".

## Test
test_occhio_sopra_acque 106, test_inseguimento 43, test_morbidezza_inseguimento 72: tutti ok. Posizionamento della torre: 0 nuovi e 0 da correggere. check_scripts 0; strati_luci, morbidezza_operatori e texture_compresse a 0.
