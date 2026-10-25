# D5 degli oblò: "nella torre lei sparisce di colpo"

D5 non è un errore del gioco: dipende da come lo script di collaudo conta i fotogrammi.

- **Il gioco.** Tutti i distacchi degli oblò durano 2,60 s, compreso `oblo_occhio_stacca` della torre, e anche la luce rosa si spegne in 2,6 s. Nella torre `_oblo_via()` chiama `oblo.via()`, che passa da `_stacca()`, cioè il distacco lento.
- **Il collaudo.** `tests/collaudo/distacco_oblo.gd` di grafica gira senza `--fixed-fps`, quindi ogni fotogramma vale il tempo vero che llvmpipe impiega a disegnare la torre, circa 0,13 s. Gli scatti "ogni 8 fotogrammi" sono così distanti 1,07 s di gioco (`tempi_tempo_vero.txt`): il fotogramma 16 è a 2,14 s, con il distacco a 2,01 s su 2,60, e il 24 è a 3,21 s, quando il distacco è già finito.
- **La stessa sequenza a 60 fotogrammi fissi**, come gira il gioco, con uno scatto ogni 8 fotogrammi (0,13 s): `foglio_60fps_fisso_ogni_8_fotogrammi.jpg` e `tempi_60fps_fisso.txt`. Lei si stacca e si allontana piano, mentre la luce cala, per 152 fotogrammi (2,53 s). Se ne va al fotogramma 160 (2,67 s).

Per i collaudi dei movimenti conviene usare sempre `--fixed-fps 60`. Lo script con il tempo stampato è `godot/tests/collaudo/distacco_oblo.gd` su questo branch; le variabili d'ambiente `OGNI` e `SCATTI` dicono ogni quanti fotogrammi scattare e quanti scatti fare.
