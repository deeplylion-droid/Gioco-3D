# Fiume: 0.3.12 / 0.3.14 / 0.3.15 (ricerca interrotta: la causa era nelle lampade del tunnel)

Stesso script di scatto in tutte (scatti_fiume_gioco di lavoro/godot, luce d'ambiente fissa, luci bianche al 40%), 1280x720. Media / mediana / 10° percentile.

| punto | 0312 | 0314 | 0315 |
|---|---|---|---|
| corridoio_1 | 33.8 / 32.5 / 15.5 | 40.8 / 36.0 / 21.9 | 40.8 / 36.0 / 21.9 |
| corridoio_2 | 25.4 / 21.3 / 3.1 | 29.1 / 25.2 / 10.1 | 29.1 / 25.2 / 10.1 |
| porta_ingresso | 37.4 / 27.4 / 14.0 | 37.4 / 27.4 / 14.0 | 37.4 / 27.4 / 14.0 |
| imbarco | 13.4 / 12.8 / 2.9 | 13.5 / 12.9 / 2.9 | 13.5 / 12.9 / 2.9 |
| ramo | 29.5 / 25.9 / 12.0 | 29.7 / 26.0 / 11.8 | 29.7 / 26.0 / 11.8 |
| approdo | 13.1 / 7.8 / 1.1 | 14.9 / 9.9 / 1.4 | 14.9 / 9.9 / 1.4 |
| porta_approdo | 27.3 / 17.4 / 7.3 | 27.3 / 17.4 / 7.3 | 27.3 / 17.4 / 7.3 |

Cambia solo fra 0.3.12 e 0.3.14, nel corridoio delle pile (e poco all'approdo): pile girate giuste (f075a6e2, prima da un lato le facce non si disegnavano) e scatole colorate (377f6239, a99c6c50, 8cfcfa45, 7a3c3f40). 0.3.14 e 0.3.15 identiche. Nessuna correzione (ordine dell'utente). Foglio: foglio_fiume_0312_0315.jpg.
