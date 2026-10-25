# Ritocchi tecnici per la 0.3.15 (enigmi)

## L'ombra della lampada d'emergenza nell'infermeria

Collaudo del 25 ottobre: sul soffitto e sul muro dietro le due lampade d'emergenza rosse dell'infermeria c'era una grande ombra nera a forma di lampada. La luce rossa sta 30 cm davanti alla lampada, e il corpo della lampada le fa ombra verso il muro e il soffitto.

**La correzione** è in `infermeria_gioco.gd`, in `_luci()`:
- il corpo della lampada sta in uno strato di disegno suo (`STRATO_LAMPADA`, 1 << 17);
- la sua luce non prende quello strato fra chi fa ombra (`shadow_caster_mask`);
- le altre luci e le altre ombre restano com'erano. Per esempio resta l'ombra del faretto della cassaforte sul soffitto, che viene da un'altra luce.

**Scatti** dagli occhi del giocatore, col renderer Vulkan, con `tests/scatti_infermeria_gioco.gd` e le camere `soffitto_sud` e `soffitto_est`:
- `lampada_emergenza_sud.jpg`: la lampada sopra la porta d'ingresso, prima e dopo;
- `lampada_emergenza_est.jpg`: la lampada sopra la cassaforte, prima e dopo.

## Il volume della nebbia dello squalo

Prima, alla fine del diradamento, il volume della nebbia del corridoio (`AtmosferaSqualo.nebbia`) restava acceso a densità 0 per tutto il gioco. Lo stesso succedeva quando la scena dello squalo non partiva affatto: ripartenze, Continua, partenze F9.

**Ora** si disegna a densità 0 solo nei primi 10 fotogrammi del livello, così shader e pipeline sono pronti prima della scena, come prima. Poi è nascosto quando la scena non c'è, e di nuovo alla fine del diradamento. Durante la scena è visibile.

Nessun altro lo usa: lo crea solo `RisveglioSqualo`, e la scena parte solo nella partita nuova.

`test_squalo_viola` controlla anche che, finito il diradamento, il volume sia nascosto.
