# Ricontrollo dei ritocchi di ambienti-2: scaletta del bacino e occhi nelle bocche

Squadra collaudo, 6 novembre. Branch `lavoro/ritocchi-ambienti2`, sha dad2934d. Non ho cambiato niente nel gioco.

## In breve
- **Scaletta del bacino: va bene.**
  - I montanti scavalcano il bordo e scendono contro il muro, e i pioli nuovi stanno sotto il pelo.
  - Dall'acqua si prende e si sale fino alla porta.
  - C'è un solo dettaglio piccolo, nel gomito di sinistra (vedi sotto).
- **Occhi nelle bocche dei tubi: c'è un difetto da correggere.**
  - Nei primi 2 m l'acqua si vede sempre da sopra, con l'occhio 4 cm sopra il pelo.
  - Fra 1,3 e 2,6 m dentro, però, il limite tiene la camera sopra il soffitto del tubo in 5 bocche su 6, e poi la lascia di colpo: la camera cade di 46-96 cm in un fotogramma.
  - Nello scolo 0 a 2,23 m si vede la sala fuori dal tubo.

## Test (tutti verdi, 0 BUG, 0 SCRIPT ERROR)
| test | esito |
|---|---|
| test_occhio_sopra_acque | 64 ok; margine più piccolo 0,040 m in tutte le 6 bocche (prima 1 mm) |
| test_scaletta_bacino | 13 ok (dalla scaletta alla porta in 2,5-3,1 s) |
| test_inseguimento | 43 ok |
| test_morbidezza_inseguimento | 72 ok |
| test_lei_discese | 21 ok |
| test_sottomarino_gioco | 13 ok |
| controllo_posizionamento | 0 da correggere, 0 nuovi, 64 già noti |

## a) La scaletta del bacino
Scatti col renderer vero, dopo SB1, col faro della scaletta acceso (`fogli/scaletta_occhi_ravvicinati.jpg`, `fogli/scaletta_salita.jpg`).
- **Dall'acqua**, in piedi e accovacciati a 1 e 2 m:
  - la scaletta scende oltre il bordo fin dentro l'acqua;
  - non sembra più appesa.
- **Ravvicinati** (con e senza lampadina tecnica):
  - i montanti poggiano sul bordo di piastrelle, girano e scendono attaccati al muro;
  - i due pioli nuovi sono sotto il pelo;
  - non si vedono stacchi.
- **Dettaglio piccolo:**
  - nel gomito di sinistra, sopra il bordo, si vede il tappo piatto a spigoli del tubo orizzontale, che sporge oltre il montante;
  - il gomito di destra è pulito.
  - Si vede solo da vicino (`vicino_curva_bordo`, in alto a sinistra nel foglio).
- **Salita dall'acqua alla porta, col giocatore vero:**
  - si parte dall'acqua a 1,2 m dalla scaletta;
  - la scala si prende dopo 0,12 s;
  - i piedi passano da -34,00 a -29,88 e si arriva alla porta.
  - Il passaggio dall'acqua al primo piolo è senza intoppi.
- (La mia prima prova, nella torre da sola, si fermava a metà con gli scatti neri: era colpa dello strumento, che non aveva la scena del tunnel. L'ho rifatta nella scena di test_scaletta_bacino, con SB1 vero.)

## b) Gli occhi nelle 6 bocche
**Prove fatte:**
- paratie tutte aperte, giuste e sbagliate;
- giocatore vero accovacciato, dalla vasca fino a 3,3 m dentro, e poi indietro da 1,2 m.

**Strumenti:**
- `sonda_bocche2.gd` registra ogni fotogramma in `bocche_fotogrammi.tsv`:
  - quanto si è dentro;
  - piedi, occhio naturale, limite, camera e soffitto del tubo, tutti rispetto al pelo.
- `vista_bacino.gd bocche` fa uno scatto ogni 6 fotogrammi.

**Cosa va:**
- **Nei primi 2 m va bene**:
  - camera sempre 0,040 m sopra il pelo;
  - girati verso la vasca da 1,2 m dentro, l'acqua si vede da sopra in tutte;
  - nessun salto dove il limite entra (vicino alla bocca).

**Il difetto:**
- **Oltre 2 m** il limite scende solo di 0,3 m per metro (`OCCHI_TRATTO`), mentre i tubi e gli scoli lì scendono di 0,5-1 m per metro.
  - Il limite tiene la camera molto sopra l'occhio naturale (fino a 1 m) e la spinge oltre il soffitto del tubo.
  - Poi smette di colpo, o a `l.z > OCCHI_TRATTO + 0,6` o quando l'occhio scende sotto `pelo - 1,0`, e la camera cade sull'occhio naturale in un fotogramma.

| bocca | camera a meno di 5 cm dal soffitto o oltre | quanto oltre il soffitto, al massimo | caduta in un fotogramma |
|---|---|---|---|
| tubo_1 (C1) | da 2,0 a 2,6 m | 0,16 m (indietro 0,10) | 65 cm a 2,60 m (indietro 42) |
| scolo_0 (C1) | da 1,3 a 2,3-2,5 m | **0,55 m** (indietro 0,53) | **96 cm** a 2,34 m (indietro 91) |
| tubo_2 (C2) | mai (al minimo 7 cm sotto) | — | 46 cm a 2,62 m (indietro 36) |
| scolo_1 (C2) | da 1,9 a 2,1-2,4 m | 0,10 m | 62 cm a 2,15 m (indietro 38) |
| tubo_3 (C3) | da 1,6 a 1,9-2,0 m | 0,18 m | 63 cm a 1,92 m (indietro 58) |
| scolo_2 (C3) | da 1,6 a 2,6 m | 0,31 m (indietro 0,24) | 85 cm a 2,61 m (indietro 53) |

Il soffitto lo calcolo dal punto più vicino della linea del tubo più `R_TUBO`, quindi a gradini di qualche centimetro. Gli scatti però confermano:
- `fogli/bocca_scolo_0.jpg`:
  - dal 019 al 021 (1,45-1,96 m) lo schermo è tutto parete rossa da vicinissimo;
  - **il 022 (2,23 m) mostra la sala fuori dal tubo**, con grate, cisterna e luci rosse;
  - dal 023 si torna dentro, più in basso.
- `fogli/bocca_tubo_1.jpg`:
  - dal 022 al 023 (2,1-2,4 m) la camera è schiacciata contro il soffitto;
  - dal 024 è di nuovo al centro del tubo.
- Per il resto della strada, prima del limite, il passo più grande della camera in un fotogramma è di 1-3 cm.

**Proposta tecnica per ambienti-2** (la soluzione la sceglie la squadra):
- il limite non deve mai superare il soffitto del tubo in quel punto, meno near e qualche cm;
- oltre il tratto deve raccordarsi all'occhio naturale, senza tagli netti né a 2,6 m né a pelo - 1,0;
- test_occhio_sopra_acque potrebbe controllare anche la camera sotto il soffitto e il salto per fotogramma.

**Nota, credo voluta:**
- col tasto indietro, da 1,2 m dentro non si torna in vasca: si scivola giù (in tutti i tubi);
- andando fino in fondo allo scolo 1, alla fine si muore.

## Cosa ricontrollare dopo la correzione
- `sonda_bocche2.gd`, una bocca per volta. Ogni bocca deve dare:
  - camera sempre sotto il soffitto;
  - caduta per fotogramma di qualche cm.
- `vista_bacino.gd bocche` per gli scatti;
- di nuovo test_occhio_sopra_acque.
