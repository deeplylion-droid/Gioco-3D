# Acqua: tre aspetti per le vasche

Screenshot dal motore (Godot 4.7, sala principale vera con l'acqua dell'addon `godot/addons/acqua`,
qualità alta, 960x540). Stessa inquadratura, cambia solo l'aspetto dell'acqua delle vasche (vasca
d'arrivo degli scivoli e vasche bimbi). La pozza sul fondo della piscina a onde resta torbida e
verdastra in tutte e tre le opzioni.

| Opzione | Com'è | File dello stile |
|---|---|---|
| 1 - Limpida | azzurra e trasparente, si vede il fondo | `presets/stile_1_limpida.tres` |
| 2 - Torbida | grigio-verde, opaca, con patina in superficie | `presets/stile_2_torbida.tres` |
| 3 - Scura e profonda | quasi nera, riflessi rossi delle luci d'emergenza allungati a scia | `presets/stile_3_scura.tres` |

**Predefinita: la 3.** È la più vicina ai concept approvati (storyboard S12 e S09, medusa
sott'acqua): acqua scura e profonda con le scie rosse delle luci d'emergenza e la luce rosa della
medusa che si diffonde sotto la superficie. È già quella usata nel gioco.

Immagini:

- `aspetto_acqua_vasca.jpg`: la vasca d'arrivo vista dal bordo.
- `aspetto_acqua_scie.jpg`: la stessa vasca vista di taglio, verso le luci rosse della parete.

Per cambiare aspetto basta assegnare un altro stile (`style`) alle superfici d'acqua delle vasche.
