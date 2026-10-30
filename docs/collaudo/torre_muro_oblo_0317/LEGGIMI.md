# Ricontrollo del muro sopra l'oblò della torre (enigmi, 30 ottobre)

Branch controllato: `lavoro/torre-muro-oblo` 78b3ffc0 (grafica). La correzione mette `torre_A` sullo strato 1<<14 e lo toglie da chi fa ombra per le lampade d'emergenza del muro est.

Lo stesso giro, `godot/tests/collaudo/collaudo_muro_oblo_versioni.gd`, è girato su tre versioni vere, ognuna col suo import:
- 0.3.15 (503b5d45)
- 0.3.16 (7deab786)
- il branch

In tutti e tre la torre è costruita e preparata come nel gioco, al buio dopo la sala pompe, con la camera vera del giocatore. Sul branch ogni vista è scattata anche con `torre_A` com'era nella 0.3.16 (strato 1, maschera piena), nello stesso momento, e 4 viste due volte per misurare il rumore.

**Esito: superato.**

## 1. Il muro sopra l'oblò (foglio `1_muro_e_lei_versioni.jpg`, righe 1-2)

R medio del muro accanto alla lampada d'emergenza più vicina all'oblò (39,52; -16,5; -15):

| punto | 0.3.15 | 0.3.16 | branch |
|---|---|---|---|
| sopra a sinistra | 51 | 36 | 51 |
| sopra | 88 | 80 | 88 |

- Nel branch la fascia scura col bordo netto sopra il tubo non c'è più, e il muro è com'era nella 0.3.15.
- La vista del muro differisce dalla 0.3.15 solo nell'1,9% dei pixel, al massimo di 59 su 255.
- La 0.3.16 vera e il branch messo come la 0.3.16 differiscono nello 0,49% dei pixel, cioè il rumore. La prova "prima e dopo" nello stesso giro corrisponde quindi alla 0.3.16 vera.

## 2. Le condotte (foglio `2_condotte_versioni.jpg`)

Le 4 viste dalla sala delle condotte attorno alla cisterna dell'oblò:
- **0.3.15**: c'è la riga rossa sullo spigolo, e anche la lancia in mano è rossa.
- **0.3.16 e branch**: nessuna riga. Fra le due, il 99,2-100% dei pixel è uguale; quel che cambia è la lancia che ondeggia e il rumore della nebbia.

Nel branch, le lampade del muro est fanno ancora ombra con la struttura della sala delle condotte.

## 3. Lei nell'oblò (foglio 1, righe 3-4)

Lei compare con `_mostra()` ed è scattata da lontano, dal pavimento, e da vicino, dalla vasca. Colore medio del vetro, in RGB:

| | 0.3.15 | 0.3.16 | branch |
|---|---|---|---|
| da lontano | 110 53 57 | 136 60 61 | 135 60 60 |
| da vicino | 113 66 69 | 167 82 78 | 166 82 77 |

Nel branch lei è rossa come nella 0.3.16 (scelta B dell'utente). Le differenze fra gli scatti sono il suo occhio e i capelli che si muovono.

## 4. Le altre ombre della torre (foglio `3_altre_lampade_prima_dopo.jpg`)

**Nel codice.** La torre ha 50 luci:
- le 2 lampade d'emergenza con l'ombra sul muro est hanno `shadow_caster_mask` 0xFBFFF;
- tutte le altre hanno la maschera dell'ombra e la cull mask piene, quindi `torre_A` fa ombra e prende luce da loro come prima;
- la camera del giocatore e le camere dei riflessi vedono lo strato 14;
- `torre_A` resta su 0x4000 dopo la costruzione e la preparazione.

**Negli scatti.** Ci sono 28 viste: muro, fronte, 4 condotte, 4 viste larghe e una per ogni luce con l'ombra. Ognuna è confrontata col branch messo come la 0.3.16:
- **Lontano dal muro est**, le viste dei fari e delle lampade a x 27 e in alto: 0,02-0,48% di pixel diversi. Due scatti uguali ne danno 0,35-0,94%, quindi è rumore.
- **Dove arriva la luce delle due lampade del muro est** cambia davvero, come voluto: muro 26%, la lampada dell'oblò 15%, la vista larga verso l'alto a est 16%, il centro della torre verso est 3,5%, il sotto dello scivolo vicino al muro est 3%.
- **La vista larga verso l'alto a est**: torna sul pavimento sotto l'oblò la pozza di luce rossa che la 0.3.16 aveva oscurato. Rispetto alla 0.3.15 cambia solo lo 0,84% dei pixel: è come nella 0.3.15, dove quelle lampade non avevano nessuna ombra.

## 5. Pipeline e "ERROR: BUG"

| | 0.3.15 | 0.3.16 | branch |
|---|---|---|---|
| costruzione e preparazione | +118 / +169 | +119 / +169 | +119 / +169 |
| viste | +1 / +1 | +1 / +1 | +1 / +1 |
| lei | +0 / +0 | +0 / +0 | +0 / +0 |
| "ERROR: BUG," | 0 | 0 | 0 |

- **Pipeline.** Il branch non compila nessuna pipeline nuova rispetto alla 0.3.16. Il +1 delle viste c'è in tutte e tre le versioni. Il +1 della costruzione rispetto alla 0.3.15 c'è già nella 0.3.16.
- **"ERROR: BUG,".** È 0 anche nel branch, dove lo strato di `torre_A` e le maschere sono cambiati 56 volte a gioco avviato.
- **Avvisi di Posa.** I 7 avvisi "nessun muro dietro" delle lampade d'emergenza sono gli stessi nelle tre versioni.

**CI di 78b3ffc0** (run 41101194158), verde:
- "ERROR: BUG," 0: l'unica riga è il testo del comando grep;
- posizionamento 0 da correggere;
- texture 0 da correggere.

## File

- `godot/tests/collaudo/collaudo_muro_oblo_versioni.gd`:
  - il giro;
  - con `VISTE_CORTE=1` o `2` le versioni vecchie fanno meno viste.
- `diff_ab.py`: confronta il branch col branch messo come la 0.3.16.
- `diff_versioni.py`: confronta due versioni.
- `foglio.py`: monta i fogli.
