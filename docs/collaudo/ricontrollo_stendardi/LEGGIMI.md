# Ricontrollo degli stendardi di grafica (enigmi, 6 novembre)

- Branch ricontrollato: `lavoro/stendardi-inseguimento`, commit `edb09d89`. Il loro lavoro non l'ho toccato.
- Script degli scatti: `godot/tests/collaudo/ricontrollo_stendardi.gd`. Gruppi: `giro`, `lei`, `distanze`, `tubo`, `lato`,
  `vicino`, `fessura`.
- Scatti con la sala della torre intera e le luci della sala come durante l'inseguimento (blackout). Gli occhi stanno a
  1,65 m dal fondo; FOV 75.

## Esito: due difetti da correggere, visibili solo da vicino; il resto passa

### Passa

- **Dagli occhi.** Tre posti per vasca: il mezzo, davanti al bersaglio giusto e l'angolo opposto, più il giro tutto
  intorno (foglio 1).
  - Ogni stendardo si vede: l'1 dalla vasca 1, il 2 dalla vasca 2, il 3 e il 4 dalla vasca 3.
  - Nessuno copre bocche, paratie, bersagli o lampade: stanno tutti davanti agli stendardi o di lato.
- **Con lei su**, in ogni vasca e in ogni scolo (foglio 2):
  - lo stendardo non copre lei e non sta sopra i posti dove sale;
  - ho misurato la pelle di lei, cioè la mesh in posa, a metà salita e a salita finita: nessun pezzo degli stendardi
    è entro 1 m da lei;
  - fa eccezione lo scolo 0, dove il lenzuolo 3 resta a 1,16 m da lei: niente compenetrazioni.
- **Tubo verso lo scolo 0** (foglio 3):
  - il tubo è chiuso: da dentro il lenzuolo non si vede, si vede solo la bocca in fondo;
  - all'uscita, il fondo del lenzuolo 3 (y -22,68) sta 2,4 m sopra l'ultimo punto del tubo (-25,1) e 3,3 m sopra il
    fondo dello scolo (-26,0);
  - in piedi nello scolo resta 1,7 m sopra la testa. I 2 m liberi ci sono.
- **Mollette** (foglio 4):
  - ognuna tocca il bastone, ci entra di 6 mm, e stringe la stoffa: in tutte e 19 ci sono vertici della stoffa dentro;
  - fra una molletta e l'altra la stoffa si affloscia fino a 12 cm sotto il bastone, come un lenzuolo vero;
  - nota estetica, non di posizionamento: da vicino sono scatoline blu di 8 x 6 x 1,8 cm, più larghe del bastone. Da
    lontano non si nota.

### Da correggere

Il difetto è lo stesso su tutti e quattro gli stendardi, perché viene dallo stesso codice di
`assets_src/stendardi/stendardi.py`.

1. **Le corde non sono legate al bastone** (8 capi; foglio 5).
   - La corda scende e finisce tagliata piatta sul capo del bastone, con metà della sezione fuori dal capo: non c'è
     nessun giro e nessun nodo attorno al bastone.
   - Misura per lo stendardo 1: la corda sta fra x 44,388 e 44,412 e il bastone finisce a 44,400. Il fondo della corda
     è 1-3 mm dentro la cima del bastone.
   - Proposta: un giro di corda attorno al bastone, 5-8 cm prima del capo, da cui parte la corda. Si può fare come il
     nodo alla trave, attorno al tubo da 2,2 cm.
2. **I nodi alle travi** (8 nodi; fogli 6 e 7).
   - La trave (40 x 60 cm) è attaccata al soffitto: la sua cima è a -6,00, che è anche il soffitto. La corda quindi non
     può girarle sopra.
   - I due giri salgono sui fianchi della trave e spariscono dentro la trave 10 cm sotto il soffitto: il tratto alto del
     giro, a -6,10, passa dentro la trave.
   - La corda che sale finisce 1,1-1,2 cm sotto la trave, fra i due giri, a 6 mm da ognuno: non tocca né la trave né il
     nodo.
   - Proposta: un golfare avvitato sotto la trave, con la corda annodata all'occhiello e il nodo che tocca l'occhiello.
     In alternativa, il giro può passare da un foro nella trave.

Le travi stanno 15 m sopra le vasche e i capi dei bastoni 4-9 m sopra. Dagli occhi i due difetti non si vedono, ma con la
regola dell'1-2 cm restano difetti.

### Non rifatto

- Il controllo di posizionamento non l'ho rilanciato. Grafica scrive 0 nuovi e 0 da correggere, ma tutti i commit del
  branch sono `[skip ci]`, quindi in CI non ha ancora girato.

## Il mio parere: si leggono come «giganti»?

No: dalle vasche sembrano lenzuoli grandi appesi in alto, non stendardi giganti.

- Dalla vasca 1 il lenzuolo 1 è a 12 m: guardato dritto prende circa un terzo dell'altezza dello schermo e un decimo
  della larghezza, perché si vede di sbieco.
- Dalla vasca 2 il lenzuolo 2 è a 10 m, in parte dietro il portale giallo.
- Dalla vasca 3 il 3 è a 14 m e il 4 a 10 m. Il 4 si guarda in su, fra i cavi.

La sala è alta quasi 30 m, dal fondo allagato (-34) al soffitto (-6): lì dentro 3 x 4,6 m sembrano normali. Per
sembrare giganti servirebbero almeno il doppio (6 x 9 m), oppure lenzuoli che scendono molto più in basso. Non ho
cambiato niente.

## Fogli

1. `1_dagli_occhi.jpg`: dalle tre vasche, verso gli stendardi.
2. `2_con_lei_su.jpg`: lei su nelle vasche e negli scoli 0 e 2.
3. `3_tubo_e_scolo0.jpg`: dentro il tubo, all'uscita, nello scolo 0 e di lato.
4. `4_mollette.jpg`: davanti, di lato e da dietro, con la luce di servizio.
5. `5_corde_ai_capi_del_bastone.jpg`: difetto 1.
6. `6_nodi_alle_travi.jpg`: difetto 2, i giri che entrano nella trave.
7. `7_nodi_fessura.jpg`: difetto 2, la corda che si ferma sotto la trave senza toccarla.
