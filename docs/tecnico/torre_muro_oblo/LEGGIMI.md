# Torre, il muro sopra l'oblò (grafica, lavoro/torre-muro-oblo)

Collaudo di ambienti-1 del 29 ottobre: a sinistra della lampada d'emergenza del muro est, sopra l'oblò, c'era una fascia scura col bordo netto. Lì il muro era R 40 contro 74 della 0.3.15.

## Causa

La lampada ha l'ombra accesa perché la sua luce non passi il muro e non faccia la riga rossa nelle condotte. Così anche il tubo della struttura della torre (`torre_A`), che passa sul muro subito sopra la lampada, faceva ombra: il muro sopra il tubo restava scuro. La causa l'ha trovata la sonda `godot/tests/sonda_ombra_muro_oblo.gd`.

## Correzione

- `torre_A` sta solo sullo strato nuovo 1<<14 (`SalaTorre.STRATO_SENZA_OMBRA_EST`, aggiunto all'elenco in `docs/coordinamento/errori_da_non_ripetere.md`).
- Le lampade d'emergenza del muro est lo tolgono da chi fa ombra (`shadow_caster_mask`). La cull mask non cambia.
- Le altre luci, le camere e i riflessi hanno tutti gli strati e la vedono come prima.
- La luce verso le condotte la ferma la struttura della sala delle condotte, che fa ancora ombra.

## Misure

Scatti con la camera vera del giocatore, `godot/tests/collaudo/muro_oblo_ombra.gd`.

R medio del muro accanto alla lampada:

| punto | 0.3.15 | 0.3.16 | correzione |
|---|---|---|---|
| sopra a sinistra | 53 | 38 | 53 |
| sopra | 89 | 81 | 89 |

- Nelle condotte, con 4 viste, non c'è la riga rossa della 0.3.15: le viste sono come nella 0.3.16.
- Pipeline durante gli scatti: +0 di disegno.
- Il foglio è `muro_e_condotte_prima_dopo.jpg`.
