# Collaudo del lavoro tecnico di grafica (29 ottobre, notte)

Squadra collaudo. DOPO: `lavoro/godot` **4e59b2d7**, che contiene tecnica-0316 61118c86. PRIMA: **d8d254ed**, la build delle Polaroid. Stessi strumenti, stesse prove, stessa macchina.

**Esito: tutto a posto.**
- La memoria non cresce più a ogni morte.
- Nelle 15 ripartenze non ci sono errori, nemmeno all'uscita.
- La memoria video è uguale.
- Al preset più basso la luce viola dello squalo tiene l'ombra.
- Da neon.gd non escono più errori.

## Memoria a ogni morte (`godot/tests/collaudo/sonda_morti.gd`)

6 morti di fila (sequenza saltata tenendo premuto) e ripartenze dal checkpoint. La crescita è la media per morte dalla seconda in poi.

| | PRIMA | DOPO |
|---|---|---|
| Sala intera, senza schermo: memoria statica | +4,02 MB | **+0,01 MB** |
| Sala intera, senza schermo: oggetti | +74,4 | **+1,8** |
| Sala intera, senza schermo: RSS | +5,0 MB | −10,0 MB |
| Renderer vero, sala ridotta: memoria video dopo ogni ripartenza | 1789 MB, piatta | 1789 MB, piatta |
| Renderer vero, sala ridotta: picco della memoria video nella ripartenza | 1887 MB | 1887 MB |
| Renderer vero, sala ridotta: RSS | +37,0 MB | +13,4 MB |
| Renderer vero, sala ridotta: oggetti | +2,4 | +0,2 |
| Errori del motore e degli script, "ERROR: BUG," | 0, 0 | 0, 0 |

Col renderer vero la ripartenza dura 19 s, contro i 16-17 s di prima. Su llvmpipe però i tempi non sono affidabili.

## 15 ripartenze dalla presa vera (`sonda_spavento.gd`)

La strada vera fino alla serranda, con la torre caricata nel thread. Poi 15 prese di lei alla fossa, 8 con la sequenza intera e 7 saltate.

| | PRIMA | DOPO |
|---|---|---|
| Controlli | 142 su 142 | 142 su 142 |
| Errori del motore e degli script dalla serranda in poi | 1, all'uscita: "2 RID allocations of type DummyMesh were leaked" | **0** |
| "ERROR: BUG," | 0 | 0 |
| Memoria statica 10 s dopo ogni ripartenza | da 2087 a 2148 MB (+4,3 a ripartenza) | **2079 MB dalla 1ª alla 15ª** |
| Oggetti | da 17643 a 19632 (+142 a ripartenza) | **17463, poi 17464** |
| Nodi, orfani | 6920, 304 fissi | 6921, 304 fissi |

## Memoria video (`memoria_video.gd`, stima delle texture e delle mesh raggiungibili)

| Zona | PRIMA | DOPO |
|---|---|---|
| tutto (sala, stanze e torre) | 1817 MB | 1817 MB |
| sala | 1170 MB | 1170 MB |
| torre | 573 MB | 573 MB |
| inseguimento | 249 MB | 249 MB |

- memoria_video.gd conta quello che si raggiunge dai nodi della zona. La torre e i file dell'inseguimento tenuti in cache fra le ripartenze contano solo se sono in scena.
- La memoria video vera, misurata a ogni ripartenza col renderer vero nella sala ridotta, resta piatta. La sala ridotta però non ha la torre.
- Il costo della torre tenuta in memoria si legge nella riga "tutto": è il massimo, 1817 MB, con sala, stanze e torre insieme.

## Squalo e neon

- `test_squalo_viola`, col renderer vero:
  - preset normale: 14 su 14;
  - preset "basso" (ombre 0, `godot/tests/collaudo/squalo_minimo.gd`): 14 su 14, con "durante la scena la luce viola è accesa, fortissima e con l'ombra".
- `test_torre`: 94 su 94, e nessuna riga con neon.gd nel log.

## Non verificato

- La memoria video sulla GPU vera con la torre in cache: la sala intera col renderer vero non entra nei 15 GB della macchina.
