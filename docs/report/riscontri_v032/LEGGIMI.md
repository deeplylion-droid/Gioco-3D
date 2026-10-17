# Prova della v0.3.2: scatti dal motore (ambienti-2)

Preset Alto, 1600x900, renderer software. Il "prima" è la v0.3.2 (o, per il soffitto, la v0.3.1, che ha lo stesso pannello).

| File | Punto | Cosa mostra |
|---|---|---|
| `2_soffitto_prima.jpg` / `_dopo` | 2 | Il soffitto del corridoio del risveglio: il pannello che pendeva in obliquo sotto il condotto, ora dritto (`screenshots_interni.gd`, `interni_soffitto`) |
| `5_cupola_prima.jpg` / `_dopo` | 5 | La cupola dal bordo della piscina: i puntini bianchi erano i riflessi delle gocce sul vetro. Su 4 fotogrammi di fila cambiavano 700-900 pixel, ora nessuno sulla cupola (`scatti_tappe56.gd`, `cupola`) |
| `6_scia_*_prima.jpg` / `_dopo` | 6 | La scia di bava rosa lungo tutto il percorso: vasca centrale, serranda, centro della sala, verso l'area bimbi, muro ovest, fossa. Prima si interrompeva dove il pavimento non era a quota 0, ora è appoggiata al pavimento (`scatti_tappa8.gd`, `SCATTI_BAVA_VECCHIA=1` per il prima) |
| `9_portellone_spiaggia_prima.jpg` / `_dopo` | 9 | Piscina piena, dalla spiaggia: prima un alone forte sul pelo dell'acqua, ora un chiarore ambra sotto l'acqua |
| `9_portellone_vicino_prima.jpg` / `_dopo` | 9 | Dal bordo: ora si vede l'anello sul portellone, sul fondo, attraverso l'acqua |

Punto 1 (musichetta) e punto 10 (scivolo) si provano nei test: `test_audio.gd` (niente bi-bu ripetuto) e `test_tappa8.gd` (il giocatore va contro lo scivolo, ci sale sopra e sta sui tre tetti).
Lo scatto a vasca vuota del punto 9 non è stato possibile: sul renderer software il livello con la piscina svuotata supera la memoria della sessione, anche al preset medio.
