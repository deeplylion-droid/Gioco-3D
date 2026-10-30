# Nebbia viola 0.3.17: misure (riscontro dell'utente sulla 0.3.16)

Renderer vero (llvmpipe), dagli occhi del giocatore, preset alto. Strumenti: `godot/tests/collaudo/misura_tunnel_0317.gd`, `misura_nebbia_0317.gd`, `prova_nebbia_grana.gd`.

## Tunnel dell'inseguimento (luminosità dello schermo 0-255: media / mediana / 10° percentile)

| punto | 0.3.15 (503b5d45) | 0.3.16 | 0.3.17 |
|---|---|---|---|
| lei lontana (12 m), avanti | 54 / 42 / 17 | 43 / 34 / 19 | 38 / 27 / 13 |
| lei vicina (5 m), avanti (il punto buio) | 8 / 3 / 1 | 10 / 7 / 3 | 6 / 2 / 1 |
| lei vicina, guardandola | 47 / 43 / 16 | 30 / 26 / 8 | 27 / 22 / 6 |

- Nel tunnel la nebbia ha l'aria viola a 0,25 e l'alone a 0,7 (ZonaNebbiaViola del tunnel). Nei punti bui i neri sono come nella 0.3.15. La foschia resta vicino alle lampade.
- La luce rosa degli effetti: con lei lontana scende a 0,3 (prima 0,55). Energia 8,8 da lontano, 16-18 da vicino.
- Nella 0.3.16, a pari punto, la luce rosa da sola aggiungeva poco: +1,5 di media. La nebbia invece alzava i neri, con la mediana del buio da 4 a 7.

## Piscina a onde (copertura della nebbia 1 - T)

- Lo strato più fitto sta sul pavimento. Sotto il pavimento scende verso il fondo che si vede, per il 40% della differenza.
- Calcolata con la formula dello shader, alla stessa distanza (3, 4, 5, 6, 8 m):
  - fondo della piscina: 0,44 / 0,46 / 0,45 / 0,42 / 0,29;
  - pavimento della sala: 0,42 / 0,44 / 0,39 / 0,33 / 0,29;
  - fondo nella 0.3.16: 0,77 / 0,79 / 0,77 / 0,71 / 0,58.
- Nel gioco, nella parte alta dell'immagine:
  - piscina vuota: 0,59;
  - piscina piena: da 0,71 a 0,64;
  - pavimento: 0,54.

## Grana

- Il "film grain" della pellicola è spento per tutti, una volta (impostazioni versione 3).
- La nebbia aveva un trattino diagonale fisso sullo schermo (l'inizio sfalsato per pixel). Ora fa più passi: alto e ultra 32, medio 24, basso 16.
- Rumore fine (deviazione del laplaciano, 0-255; senza nebbia 0,68):

| passi | rumore fine |
|---|---|
| 10 | 2,83 |
| 16 | 1,46 |
| 20 | 1,12 |
| 24 | 1,01 |
| 32 | 0,84 |

- Costo stimato su una scheda media a 1080p: circa +0,35 ms ad alto e +0,3 ms a basso.

## Pipeline

`test_riscaldamento_pipeline` 11/11 col renderer e senza_bug: accendendo la nebbia, surface 0, draw 0, sottofondo 0.
