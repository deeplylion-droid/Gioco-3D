# Oblò con lei: la dissolvenza alla fine del distacco (D5bis del collaudo degli oblò)

## Il difetto

Alla fine del distacco lei spariva tutta insieme, modello e luce, mentre si vedeva ancora bene. `LeiOblo.stacca()` spegne la sua luce rosa in 2,6 s e poi toglie il modello. Lei però resta illuminata dall'ambiente.

- **Nella torre** il salto è grande: nella posa "occhio" lei si stacca indietro di soli 0,45 m, quindi alla fine è ancora vicina al vetro.
- **Nella Risalita** il salto è più piccolo: lei va più indietro e più giù, e alla fine è piccola e scura.

Si vede in `torre_prima.jpg` e `fiume_prima.jpg`.

## La correzione

È in `godot/scripts/game/oblo_lei.gd` (ObloLei).

- **Durante il distacco**, dal 35% alla fine, le mesh di lei si dissolvono con `GeometryInstance3D.transparency` da 0 a 1, insieme alla luce che si spegne. Quando il modello viene tolto non si vede più.
- **Nel riscaldamento**, che c'era già (appena lei compare, fuori vista, una camera nascosta guarda il vetro), ora negli ultimi 3 fotogrammi lei è mezza trasparente. Così le varianti trasparenti dei suoi materiali si compilano lì e non al distacco.
- I materiali non cambiano, e la lei della sala resta com'è.

## Prove

Fogli degli ultimi 40 fotogrammi del distacco, uno scatto ogni 4 fotogrammi, a 60 fotogrammi fissi al secondo, dagli occhi del giocatore. Lo script è `godot/tests/collaudo/distacco_oblo.gd`, con `SALTA=116 OGNI=4 SCATTI=11` e la scena `torre` o `fiume`.

| | Prima | Dopo |
|---|---|---|
| Torre (posa "occhio") | `torre_prima.jpg`: lei ben visibile fino al fotogramma 156, sparita al 160 | `torre_dopo.jpg`: si dissolve piano, è un'ombra al 152, al 156 non c'è più |
| Risalita, oblò del fiume (schiacciata) | `fiume_prima.jpg`: piccola e scura in fondo, ma c'è fino al 156 | `fiume_dopo.jpg`: si dissolve, al 156 non c'è più |

Pipeline di disegno compilate (`tempi_*.txt`):

| | Prima del distacco | Durante il distacco (fotogrammi 0-156) | Quando lei viene tolta (160) |
|---|---|---|---|
| Torre, prima → dopo | 103 → 110 | 0 → 0 | +4 → +4 |
| Fiume, prima → dopo | 56 → 63 | 0 → 0 | 0 → 0 |

- Le 7 pipeline in più del "dopo" sono le varianti trasparenti, compilate nel riscaldamento.
- Durante il distacco non si compila niente.
- Le 4 compilazioni della torre quando lei viene tolta c'erano già prima della correzione.
