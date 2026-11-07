# Collaudo finale 0.3.21: il fondo nero dietro la porta di servizio del bacino (enigmi, 7 novembre)

- Candidata finale `lavoro/candidata-0321` `c6187286`.
- Il fondo è `SalaInseguimento._fondo_porta` ("FondoPortaServizio", di ambienti-1): un quadrato nero opaco, 4 mm
  dietro il muro della cabina sul palco, più grande del vano. C'è finché il tunnel non è pronto (AttesaZone "tunnel");
  quando lo è va via, controllato ogni 0,2 s.
- Strumenti, in `godot/tests/collaudo/`:
  - `sonda_fondo_porta.gd`: il gioco vero senza schermo, fotogramma per fotogramma;
  - `scatti_fondo_porta.gd`: gli scatti dagli occhi, con la sala della torre (condotte comprese) e poi il tunnel messo
    come lo mette la sala. Tutta la sala con llvmpipe non sta nella memoria.

## Esito: il fondo passa in tutti e cinque i casi

Senza schermo, `--fixed-fps 60`. "Vuoto" = condotte visibili col giocatore, tunnel non pronto e nessun fondo.

| Caso | Fotogrammi col vuoto | Nero rimasto col tunnel pronto | Fondi al massimo | Doppioni | Comparso / tolto |
|---|---|---|---|---|---|
| Morte nelle condotte (si riparte dal bacino) | 0 | 5 fotogrammi (0,08 s) | 1 | 0 | 2 / 2 |
| Continua dal checkpoint del bacino | 0 | 2 (0,03 s) | 1 | 0 | 2 / 2 |
| F9 Inseguimento | 0 | 3 (0,05 s) | 1 | 0 | 1 / 1 |
| Due morti di fila al bacino, la seconda prima del tunnel | 0 | 9 in tre vite (0,15 s) | 1 | 0 | 3 / 3 |
| Dal titolo arrivando dalla torre (Continua dal portone, poi subito al bacino) | 0 | 10 (0,17 s) | 1 | 0 | 1 / 1 |

- In ogni ripartenza il fondo c'è già quando il giocatore riprende i comandi. Il tunnel entra circa 0,1-2,4 s dopo, è
  costruito 2,1-2,5 s dopo ancora e pronto 2,5-3 s dopo. Il fondo va via entro 0,2 s (il controllo è ogni 0,2 s).
  Mentre c'è il fondo, il tunnel che si costruisce sta dietro.
- Dopo le due morti di fila c'è sempre un solo fondo: la sala si rifà da capo.
- Arrivando dalla torre il fondo c'è dall'inizio e il tunnel è pronto circa 5 s dopo.
- Dal checkpoint del bacino si vedono 5 punti del vano su 9 (a 9 m). Dagli altri punti di ripartenza (fondo della torre,
  vasche 1-3) non se ne vede nessuno.
- Il test di ambienti-1 `tests/test_fondo_porta_bacino.gd` passa: 20 controlli su 20 (dal titolo, F9, morte 1 e 2).

### Dagli occhi (fogli 1-3)

- Prima che il tunnel sia pronto, dal punto di ripartenza del bacino e dal mezzo del bacino il vano è un rettangolo nero
  pieno in cima alla scaletta: un corridoio buio, non il vuoto né il cielo. Pronto il tunnel, nel vano si vede il tunnel
  verde.
- **Da vicino** (in cima alla scaletta a 1 m e a 40 cm, e radente ai tre lati):
  - il nero sta in fondo allo spessore del muro;
  - gli stipiti e l'architrave si vedono interi, coi bordi puliti, senza fessure né luce intorno;
  - a 40 cm lo schermo è tutto nero;
  - si capisce solo che dietro non c'è niente: non si vede il pavimento oltre la soglia e il nero non ha nessun
    dettaglio.
  Non sembra un pannello appiccicato al muro: sembra buio.
- **Il passaggio**, dal mezzo del bacino, un fotogramma ogni 3 mentre il tunnel si costruisce e diventa pronto (150
  fotogrammi):
  - il vano resta nero in tutti finché il tunnel non è pronto (fotogramma 402);
  - al 405 il nero non c'è più e si vede il tunnel;
  - nessun fotogramma col vuoto, nessuno sfarfallio del nero e niente nero rimasto sopra il tunnel.
- Dal fotogramma 87 in poi la vista è un po' più stretta. È la mia prova, non il gioco: costruendosi il tunnel la
  grafica rimette il campo visivo delle impostazioni (62°) alla camera del gioco, e la mia camera era a 75°. Il
  giocatore è già a 62°.

## Osservazione, non del fondo: un lampo rosa sul muro del bacino mentre il tunnel si riscalda

- Nel passaggio, ai fotogrammi 87-93 (circa 0,1-0,15 s), il muro sinistro del bacino, la scaletta e la ringhiera della
  cabina si colorano di rosa. Il vano intanto resta nero.
- È la luce rosa del riscaldamento del tunnel: `SalaSottomarino._riscalda` e
  `EffettiInseguimento.riscalda_da(cam, true)`.
  - La luce si mette 1 m dietro la camera nascosta, a spot 70° e 40 m di portata, senza ombre.
  - Nella prima vista (`VISTE_RISCALDA` s = 0, l'inizio del tunnel dietro la porta del bacino) quel metro dietro cade
    nelle condotte, e la luce illumina la faccia del muro verso il bacino.
- Nel gioco succede quando il tunnel si costruisce con il giocatore nelle condotte: dopo una morte, un Continua o F9,
  circa 4-6 s dopo che si riprendono i comandi.
- C'era già nella 0.3.20: `riscalda_da` è di `14458189`. Non lo causa il fondo nero.
- Possibili rimedi (da decidere chi ce l'ha):
  - la luce davanti alla camera nascosta invece che dietro, nelle prime viste;
  - oppure saltare la vista s = 0 per la luce;
  - oppure una maschera di luce che non prenda le condotte.

## Fogli

1. `1_vano_prima_dopo.jpg`: dal punto di ripartenza del bacino, dal mezzo del bacino, a 1 m e a 40 cm. Tunnel non pronto
   a sinistra, pronto a destra.
2. `2_filo_del_muro.jpg`: radente agli stipiti sud e nord e all'architrave, prima e dopo.
3. `3_passaggio_dal_bacino.jpg`: il passaggio dal mezzo del bacino, col lampo rosa ai fotogrammi 87-93.
