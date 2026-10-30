# Ricontrollo del rosso della torre (ambienti-1, 29 ottobre)

Confronto fra **lavoro/torre-rosso 5e56de96** (codice in 0c1518ed: veli dell'acqua accesi a ROSSO × 0,1 e vetro
dell'oblò a ROSSO × 0,5, in emissione, senza luci) e la **0.3.15** (main 503b5d45).

**Come.** Lo stesso script sulle due versioni (`godot/tests/collaudo/torre_rosso_a1.gd`):
- la camera vera del giocatore, la torre costruita a pezzi e preparata come nel gioco;
- la vasca vuota, poi lei comparsa vista da 9, 6, 3,5, 2 e 1,2 m dal vetro e da sotto di lato;
- le condotte dietro la cisterna, dai due lati;
- il distacco.

Gli oblò della risalita sono in `oblo_risalita_a1.gd`.

I fogli: `confronto_1_lontano.jpg`, `confronto_2_vicino.jpg`, `confronto_3_condotte_risalita.jpg`,
`confronto_4_risalita.jpg` (0.3.15 a sinistra, il branch a destra) e `lei_1_2m_ingrandita.jpg`. Le misure sono in
`misure_*.txt`.

## 1. Dalla camera del giocatore: da lontano somiglia, da vicino no

**Da 9, 6 e 3,5 m è quasi uguale alla 0.3.15.** Il riquadro del vetro ha in media R 93/89/81 contro 96/92/82.

**Da 2 e 1,2 m no** (`lei_1_2m_ingrandita.jpg`):
- Il vetro sembra colorato: su tutto quello che c'è dietro c'è un velo rosa-rosso piatto, uguale dappertutto, come
  un vetro latteo.
- Lei è slavata e grigiastra:
  - capelli R 94 contro 112, color sabbia invece che rosso-rosa;
  - pelle grigia;
  - meno contrasto fra lei e il fondo.
- Nella 0.3.15 lei era accesa di rosso, coi capelli rosso-rosa saturi, le ombre profonde e il fondo della vasca scuro
  dietro di lei.
- Le mani non sono più rosse ma grigie. Sono un po' più scure di prima (R 85 contro 92), ma sul fondo rosa si
  staccano di più, perché sono grigie su un fondo colorato.
- Nessun bordo netto del velo e nessun alone a scalini: il difetto è proprio che è uniforme.

**Probabile causa.** Il vetro a ROSSO × 0,5 in emissione aggiunge la stessa luce a ogni pixel. Il rosso della 0.3.15
invece illuminava lei e la nebbia, con le ombre. Abbassare l'emissione del vetro, e magari dare un po' più di rosso
ai veli dietro di lei, dovrebbe avvicinarlo alla 0.3.15.

**Il resto della torre.**
- Il muro e la lampada sopra l'oblò hanno una zona scura netta accanto alla lampada (in alto a sinistra in
  `prima_vuota`, `lei_3.5_m` e `dopo_vuota`). È l'ombra della lampada d'emergenza, che ora fa ombra: viene dalla
  correzione delle righe già in lavoro/godot, non da questo branch.
- Da tenere presente: nella 0.3.15 quella zona era rossa.

## 2. Condotte: le righe non tornano

Nella 0.3.15, da tutti e due i lati, si vedono le righe rosa e i bordi rossi delle lamiere. Nel branch no: le
condotte restano buie.

## 3. Oblò della risalita: uguali

ObloPersonale, ObloServizio e ObloFiume sono identici alla 0.3.15: i loro veli e il vetro non hanno colore.

## 4. Comparsa e distacco

- Pipeline nuove alla comparsa di lei: +0 / +0 (disegno / specializzazione).
- Pipeline in tutti gli scatti e nel distacco: +0 / +0.
- Nessuna riga "ERROR: BUG,", in tutte e due le versioni.
- Costruzione a pezzi e riscaldamento come nel gioco.
- **Veli e vetro non si spengono con lei.** Sono accesi da quando la torre è costruita, anche con la vasca vuota prima
  che lei compaia (`prima_vuota`: R 70 contro 68 della 0.3.15).
  - Nella 0.3.15 la lampada accendeva la vasca anche vuota, quindi è coerente con prima.
  - Se l'utente vuole il rosso solo con lei, va tolto anche dopo il distacco.
- Il distacco nei 60 s del giro non è finito in nessuna delle due versioni: lo scatto `dopo_vuota` è con lei che si
  sta scurendo. È uguale nelle due versioni.

## In breve

- Condotte, oblò della risalita, pipeline ed errori: a posto.
- Il rosso da lontano: a posto.
- Da vicino non somiglia alla 0.3.15: velo rosa piatto sul vetro e lei slavata. Da ritoccare (vetro meno acceso).

# Secondo ricontrollo: lavoro/torre-rosso aff0a946 (29 ottobre sera)

Cosa è cambiato in aff0a946:
- un faretto rosso corto (1,8 m) con l'ombra, appena fuori dal foro;
- i veli a 0,15 e il vetro spento;
- la lampada del muro est senza l'ombra del suo corpo e l'ombra della condotta sfocata.

Stesso script, stessa camera. I fogli hanno il prefisso `aff0a946_`; le misure sono in `misure_aff0a946.txt`.

## Lei da 2 e 1,2 m: rossa, satura, con le ombre. Il velo latteo non c'è più

`aff0a946_lei_1_2m_ingrandita.jpg`, la 0.3.15 a sinistra:
- Lei somiglia molto alla 0.3.15: rossa, con le ombre e il fondo della vasca scuro dietro.
- È un po' più accesa e più calda della 0.3.15, come illuminata da davanti:
  - capelli R 159 contro 112, saturazione 100 contro 61;
  - più rosa-arancio.
- **Le mani si vedono più di prima:** R 129 contro 92, rosa chiaro invece che scure. Nella 0.3.15 restavano quasi in
  ombra.
- Se si vuole identica: il faretto un po' più debole, o puntato più in alto, così da lasciare le mani in ombra.

## Il muro sopra l'oblò accanto alla lampada: c'è ancora un'ombra netta

`aff0a946_muro_sopra_oblo.jpg`, sopra la 0.3.15 e sotto aff0a946:
- A sinistra della lampada c'è ancora una fascia scura orizzontale col bordo basso netto. È l'ombra di quello che sta
  sopra (la condotta), e non sembra sfocata.
- Lì il muro è R 40 contro R 74 della 0.3.15, dove era acceso di rosso.
- A destra della lampada il muro è uguale (R 42 contro 47).

## Da 9, 6 e 3,5 m: uguale alla 0.3.15

Vetro R 95/92/84 contro 96/92/82.

## Un puntino rosso nel vetro a vasca vuota

Nello scatto `prima_vuota`, prima che lei compaia, al centro del vetro si vede un puntino rosso acceso: probabilmente
è il faretto visto attraverso il foro. Nella 0.3.15 non c'è. Si vede poco, ma a vasca vuota attira l'occhio.

## Condotte, oblò della risalita, pipeline

- Condotte: nessuna riga, buie come prima della correzione.
- Oblò della risalita (Personale, Servizio, Fiume): identici alla 0.3.15.
- Pipeline +0 alla comparsa di lei; +0 in tutti gli scatti e nel distacco.
- Nessuna riga "ERROR: BUG,".

## In breve

- Lei da vicino e il resto: a posto per la build. Lei è un po' più accesa e le mani più chiare della 0.3.15.
- Da sistemare:
  - l'ombra netta a sinistra della lampada sopra l'oblò;
  - il puntino rosso nel vetro a vasca vuota.

# Passaggio breve: lavoro/torre-rosso 5af7f8a8 (light_specular 0 sul faretto RossoFaccia)

- **Il puntino non c'è più.** A vasca vuota il centro del vetro è liscio (`5af7f8a8_puntino_prima_dopo.jpg`: aff0a946 a
  sinistra, 5af7f8a8 a destra). Era il riflesso del faretto sul vetro.
- **Lei da 2 e 1,2 m è come in aff0a946:** rossa, satura, con le ombre. Il vetro misura R 85 e 106, contro 86 e 107.
  - Si perde solo il piccolo riflesso bianco del faretto sul suo occhio, da 1,2 m.
  - Il riflesso della lampada in alto nel vetro resta, come nella 0.3.15.
  - Il confronto delle tre versioni è in `5af7f8a8_confronto.jpg`.
- **Condotte:** nessuna riga, come in aff0a946. Nella 0.3.15 c'erano.
- **Pipeline e errori:** +0 alla comparsa di lei e in tutti gli scatti e nel distacco; nessuna riga "ERROR: BUG,".
- **Esito: superato.** Resta per dopo la build l'ombra netta sul muro sopra l'oblò, a sinistra della lampada.
