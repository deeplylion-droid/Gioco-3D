# Collaudo degli scarabocchi su lavoro/scarabocchi (ambienti-1, 29 ottobre)

Il collaudo l'ha fatto ambienti-1, che non ha lavorato ai disegni.

Primo giro su 219ddf9b. Poi ricontrollo su 372c0dc0, coi 6 muri corretti da ambienti-2: inseguimento_1, sala_1,
alto_sala_3, risalita_2, tunnel_1 e torre_3 spostato.

## Come

- **Geometria** (`godot/tests/collaudo/geometria_scarabocchi.gd`), indipendente dagli strumenti di ambienti-2, senza
  renderer, su tutti e 18 i muri. Per ognuno:
  - 13 × 7 = 91 raggi sulla faccia del disegno. Il controllo cerca punti senza muro (il disegno si taglia), superfici
    non parallele al muro (il disegno si stira) e rilievi a più di 3 cm (cornici, tubi).
  - Le mesh che entrano nella scatola della decal, anche quelle nascoste che compaiono dopo e i piani come il pelo
    dell'acqua.
  - Porte, Polaroid, pulsanti, poster, oblò, indizi, acquari e grate entro 1 m.
- **Scatti col renderer vero** (`godot/tests/collaudo/giro_scarabocchi.gd`, la sala montata a parti come nello
  strumento di ambienti-2), 4 per muro:
  - dagli occhi del giocatore;
  - di fronte da 1,1 m;
  - radente da sinistra e da destra, a 45 cm dal muro.
- I fogli per zona sono `foglio_<zona>.jpg`, con una riga per muro.
  - Qualche scatto radente è nero o mostra il cielo: la camera è finita dentro un muro o un angolo vicino, non è un
    difetto.

## Esito: superato su 372c0dc0

- **Geometria, tutti e 18 i muri:**
  - 0 raggi fuori dal muro, 0 su superfici storte, 0 rilievi;
  - nessuna mesh estranea nella scatola;
  - niente sotto l'acqua.
- **Niente copre porte, Polaroid, pulsanti, poster, oblò o indizi.**
  - Il più vicino è un oblò della sala, a 0,46 m da sala_1, alto_sala_1 e alto_sala_3: non lo tocca.
  - In torre_3 il poster della balena sta a circa 2 m.
  - Nessun portone, grata o acquario entro 1 m da un disegno: negli stati che cambiano dopo non si sovrappongono a
    niente.
- **Niente che sembri un indizio:**
  - niente lettere, numeri o frecce;
  - niente cerchi giallo, rosso e blu in fila;
  - le righe viola che si potevano contare (risalita_2, tunnel_1) ora sono una macchia.

### I difetti del primo giro (219ddf9b), tutti corretti in 372c0dc0

1. **inseguimento_1:** la parte bassa finiva sotto il pelo dell'acqua allagata (y -33,4) e i pesci erano tagliati a
   metà. Ora il disegno sta 20 cm sopra l'acqua.
2. **sala_1:** 13 raggi su 91 cadevano sulla parte inclinata del muro (stiramento). Ora è tutto sulla parte piatta.
3. **alto_sala_3:** 7 raggi su 91 erano fuori dal muro (bordo tagliato). Ora è dentro.
4. **Le 4 righe viola** in risalita_2 e tunnel_1 sembravano tacche da contare, come la P6. Ora c'è una macchia.
5. **torre_3:** spostato da ambienti-2, perché le scale erano a 12-13 cm dal muro. Ora è a posto.

### Da sapere (scelte di design, non difetti)

- Nei corridoi rossi della risalita (risalita_2, risalita_3) e nel fiume (fiume_1) i disegni si vedono appena, come
  scritto nel LEGGIMI di ambienti-2.
- sala_1 sta sulla fascia di piastrelle con la riga rossa: la medusa cade proprio sulla riga rossa e si legge meno.
- Il disegno di Jilly coi pesci (sala_1, inseguimento_3) somiglia alla medusina rosa del disegno degli acquari. Sta a
  più di 3 m dagli acquari, ma è da tenere presente se l'utente lo legge come un indizio.
