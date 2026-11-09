# Terzo ricontrollo del guanto (enigmi, 9 novembre)

- Base `lavoro/guanto` `5325f596` di ambienti-1: cambiano solo il modello (`guanto_destro.glb`) e il suo generatore.
- Sono gli stessi punti del ricontrollo di prima (`a19d3260`, su `98ded0d2`), con gli stessi strumenti e le stesse viste.
- Per confronto ci sono anche il modello di prima (`98ded0d2`) e quello della 0.3.22 (`efed85b1`).
- Il pezzo della lancia a 90° (#146) non conta per questo esito.

## Esito: superato

- L'indice ora sta attaccato all'impugnatura: al più 0,7 mm tutto intorno, alla base e sopra.
- La conchetta sulla punta non c'è più. Nessuno spigolo oltre i 150°, né nel modello né nel motore.
- La fossetta sul pollice non c'è più.
- Il guanto non entra nella lancia in nessun punto.
- L'aspetto è uguale agli scatti approvati in tutte le 16 pose.
- Quando il guanto entra in vista non si compila niente, né nel tunnel né all'oblò.

Ci sono anche due osservazioni, che non sono cambiate con questo modello: il mignolo e il pollice (punti 5 e 3).

## 1. L'indice e l'impugnatura

Misura fatta alle quote vere delle dita. È la stessa nota che ha mandato ambienti-1: l'indice sta a y -0,202, e da questo modello le dita non hanno più un passo fisso.
- Lungo tutto il giro dell'indice, ogni 3°, al centro del dito e 2 mm sopra e sotto: **al più 0,7 mm** (`misura_indice.py` e `misura_dita.py`).
- Sullo stesso modello di prima (`98ded0d2`), alle stesse quote: alla base, sul lato destro vicino al palmo (da -25° a -19°), c'erano **4,3-13,3 mm**. Ora lì ci sono 0,4-0,7 mm.
- Negli ingrandimenti a 11 cm (foglio `1`, righe «base» e «bordo alto»; foglio `2`, prima riga, alla quota vera) non si vede nessuno spazio.

## 2. La punta dell'indice

- **La conchetta non c'è più** (foglio `1`, righe 1-4): nelle stesse viste di prima la superficie è liscia, con la luce della camera e con le luci del livello.
- Pieghe sulla punta dell'indice:

  | | Modello | Nel motore |
  |---|---|---|
  | 98ded0d2 | fino a 165° | - |
  | 5325f596 | **60°** | **61°** |

  «Nel motore» vuol dire la maglia letta dal gioco dopo l'import (`collaudo_guanto.gd`, modo `maglia`).
- Su tutto il guanto:
  - nessuno spigolo oltre i 150°;
  - uno solo oltre i 120°: 126°, nella valle fra anulare e mignolo, sul dorso. C'era uguale anche prima, e da vicino è una piega morbida (foglio `2`, ultima riga);
  - nel motore la maglia è chiusa e le normali sono lisce (nessuna normale spezzata sul corpo del guanto). Gli spigoli vivi sono solo quelli delle cuciture, come prima.

## 3. Il pollice

- **La fossetta non c'è più.** Nella zona del pollice la piega più forte ora è di 49°, prima era di 95° in (-0,061, -0,177, 0,469). Negli ingrandimenti dov'era (foglio `2`) la superficie è liscia.
- La punta del pollice appoggia sull'impugnatura a **0,4-0,5 mm**.
- Il resto del pollice è identico al millimetro nei tre modelli (0.3.22, 98ded0d2, 5325f596; `misura_pollice.py`):
  - parte dal palmo;
  - passa sopra il dorso dell'impugnatura e scende sul lato sinistro, come dice il generatore;
  - appoggia sopra l'indice.
- **Osservazione, non cambiata:** dietro l'impugnatura il pollice fa un ponte.
  - Fra il pollice e il dorso dell'impugnatura, in orizzontale, ci sono 0,5-3,8 cm d'aria.
  - Da ogni vista, dietro al pollice c'è l'impugnatura o il palmo, mai lo sfondo (foglio `6`).
  - È com'era negli scatti approvati. La segnalo solo perché la regola parla anche di distacchi di 1-2 cm.

## 4. Niente dentro la lancia

- Ho contato i vertici del guanto dentro la lancia con la parità dei raggi: 6 direzioni, ed è dentro se gli attraversamenti sono dispari in almeno 4. Così non conta da che parte guardano i triangoli della lancia (`misura_dentro.py`).
- Su 5325f596: **0 vertici** su 7023 vicini alla lancia.
- Sul modello di prima lo stesso strumento dà 24 vertici, al più 0,47 mm: il numero del ricontrollo di prima era giusto.

## 5. Le altre dita

- Medio: al più 0,52 mm. Anulare: al più 0,55 mm.
- **Mignolo, osservazione non cambiata:**
  - 2 mm sotto il centro del dito, ai due angoli davanti dell'impugnatura, c'è un punto a **2,16 mm** e uno a 1,70 mm (glTF circa (-0,026 / 0,031, -0,275, 0,464));
  - era uguale su 98ded0d2 (2,15 mm); nella 0.3.22 era 1,49 mm;
  - negli ingrandimenti a 11 cm, da sotto, non si vede spazio (foglio `2`, righe del mignolo).

## 6. L'aspetto (fogli `4` e `5`)

- **Le 16 pose approvate**, rifatte con lo stesso strumento di allora (`scatti_guanto.gd`):
  - il bianco del guanto è uguale entro 0,5-2,3 su 255 per canale, in ogni posa;
  - fra 98ded0d2 e 5325f596 la differenza media è 0,1 su 255: cambia lo 0,02-0,04% dei pixel, sulla punta dell'indice;
  - le pose dello sparo cambiano di più per gli spruzzi d'acqua, che sono casuali.
- **Dagli occhi:**
  - a 62° il guanto non entra mai nello schermo (17 stati);
  - a 90° entra in tutti, fino al 16,1% dell'altezza, come prima;
  - soglia: in tutti e quattro i formati entra da 70° in su.
- **Segue la lancia** in tutte le pose: al più 0,0001 mm.

## 7. Le compilazioni (`sonda_guanto_pipeline.gd`)

Lo stesso giro di prima: il riscaldamento dell'avvio, poi il gioco vero con una cartella utente nuova.

| Caso | Primo fotogramma col giocatore | Lei compare | In basso a 62° | In basso a 90° |
|---|---|---|---|---|
| Tunnel | surface 4, draw 1, spec. 1 | - | **nessuna** | draw 2, spec. 2 a -18° (#146) |
| Oblò | surface 4, draw 2, spec. 2 | **nessuna** | **nessuna** (il guanto entra nella vista a -9°) | draw 2, spec. 2 a -59° (#146) |

- È identico a 98ded0d2: il modello nuovo non aggiunge niente.
- Il primo fotogramma è il giocatore che entra nella scena della prova.
- I 2+2 a 90° sono il pezzo della lancia (#146).

## Correzioni al ricontrollo di prima (`a19d3260`)

Lì il mio strumento usava l'indice a y -0,196 col passo fisso della 0.3.22, invece di -0,202. Rifatte alle quote vere:
- **«Bordo alto dell'indice a 2-3,6 mm (y -0,194)»: era un errore dello strumento.** Quella quota è 8 mm sopra il centro del dito, dove il tubo si curva via dall'impugnatura. Alle quote vere, su 98ded0d2, il bordo alto stava al più a 0,6 mm.
- **«Base a 5-9 mm»: il difetto era vero, e più grande.** Alle quote vere erano 4,3-13,3 mm. Ora è corretto.
- **«Medio, anulare e mignolo al più 1,15 mm»: era sbagliato.** Era la riga al centro del dito: 2 mm sotto, il mignolo era già a 2,15 mm (punto 5).

## Fogli

- `1_ingrandimenti_tre_modelli.jpg`: gli ingrandimenti a 11 cm del ricontrollo di prima, sui tre modelli (0.3.22, 98ded0d2, 5325f596). Punta dell'indice, dov'era la conchetta, base e bordo alto dell'indice, fra anulare e mignolo.
- `2_ingrandimenti_nuovi.jpg`: ingrandimenti nuovi a 11 cm, con la luce della camera e con le luci del livello. Base dell'indice alla quota vera, pollice dov'era la fossetta e da sopra, mignolo da sotto, dorso fra anulare e mignolo.
- `3_vicino_fermo.jpg`: da vicino, i sette lati del ricontrollo di prima.
- `4_approvati_e_rifatti.jpg`: le 16 pose approvate e le stesse rifatte su 5325f596.
- `5_occhi.jpg`: dagli occhi a 90° (fermo, tutto in giù, in carica) e a 62°; la mano ingrandita su 5325f596 e su 98ded0d2.
- `6_pollice_tre_modelli.jpg`: il pollice visto coi raggi sui triangoli nei tre modelli. Guanto bianco, lancia arancione, sfondo blu: si vede se fra il pollice e la lancia passa la vista.
- `misure_blender.txt`: tutte le misure (dita, indice, dentro la lancia, pieghe, maglia nel motore, pollice), con quelle di 98ded0d2 alle quote vere.

## Strumenti

In `../strumenti/`:
- `misura_dita.py` e `misura_indice.py`, con le quote vere delle dita (`DITA_Y`); `DETTAGLI=1` dà i punti sopra 1 mm;
- nuovi:
  - `misura_dentro.py`: dentro la lancia, con la parità dei raggi;
  - `misura_pollice.py`;
  - `pieghe_zona.py`: le pieghe in una scatola;
  - `maglia_motore.py`: la maglia salvata dal motore;
  - `lente_bvh.py`: la vista coi raggi su guanto e lancia;
  - `fogli_terzo.py`.

In `godot/tests/collaudo/collaudo_guanto.gd`: il modo `maglia` e gli ingrandimenti nuovi.
