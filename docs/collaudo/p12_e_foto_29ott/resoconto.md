# Ricontrollo della P12 e delle foto P11-P16 (29 ottobre, mattina)

Squadra collaudo. `lavoro/godot` **0b2c2564** (P12 corretta e texture delle Polaroid P11-P16 compresse). 0 righe
"ERROR: BUG,"; `test_torre` 94 su 94.

**Esito: va.**

- **P12:** ora sta a **3,2 mm** sopra le barre della grata (`torre_A_grigliati`) sotto il centro e sotto i quattro
  angoli: OK, come le altre Polaroid nuove. Prima era a 13,5 mm. Misura di `sonda_polaroid.gd` (raggi sulle facce vere
  delle mesh e delle multimesh); le misure di P12-P16 sono in `misure.txt`.
- **Gli 8 scatti radenti** col renderer vero (18 e 30 cm, dai quattro lati, nella torre coi materiali veri): la foto
  poggia sulle barre e non si vede più il vuoto sotto (`fogli/p12_radenti_prima_e_ora.jpg`, `fogli/p12_otto_radenti.jpg`).
  Si raccoglie ancora (collezione da 7 a 8).
- **Le foto P11-P16 da vicino.** Importazione identica a P01-P10 (compressione VRAM con mipmap, stessi parametri per
  la foto e per la rugosità) e stessa risoluzione (1024x1245).
  - Scatti col renderer vero sulla scena vera della Polaroid, nelle stesse condizioni per tutte:
    dall'alto a 25 e 60 cm, e di sbieco a 40 cm (`fogli/foto_da_vicino.jpg`, `foto_a_60cm.jpg`, `foto_di_sbieco.jpg`).
  - Nitide come le altre. La nitidezza misurata (varianza del laplaciano sulla foto a 25 cm) va da 257 a 411 per
    P11-P16 e da 167 a 464 per P01, P03, P05, P07 e P10.
- Sonda: `godot/tests/collaudo/polaroid_nitide.gd`.
