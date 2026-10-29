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
