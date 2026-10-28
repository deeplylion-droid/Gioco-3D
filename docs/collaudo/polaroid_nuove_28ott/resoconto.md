# Collaudo delle Polaroid P12-P16 (28 ottobre, notte)

Squadra collaudo. `lavoro/godot` **d8d254ed**: la 0.3.15, il cuore e il ritmo dell'inseguimento e le Polaroid nuove di enigmi (polaroid-nuove ca17decc).

**Esito: P13, P14, P15 e P16 sono a posto. La P12 è da correggere: sta sospesa di 13,5 mm sul grigliato della torre.**

## Come

- **`godot/tests/collaudo/sonda_polaroid.gd`.** Senza schermo, nella sala intera, negli stati inizio, ritorno e risolto di `stati.gd`, con le stanze della Risalita caricate a gioco avviato e la torre caricata.
  - **Distacco:** per ogni Polaroid, sotto il centro e i 4 angoli, cerca la superficie più alta delle mesh che si vedono, comprese le multimesh, e non delle collisioni. Il distacco è il fondo della Polaroid meno quella superficie.
  - **Raccolta:** il giocatore va a 0,9 m dalla parte più libera, la guarda e preme E.
  - **Totale:** quello della collezione.
  - **Partenze:** le Polaroid già raccolte nell'istantanea di ogni partenza del menu F9.
  - **P13:** anche con lei che compare all'oblò del fiume e poi si stacca.
- **Scatti col renderer vero** (`giro.gd`, zone da sole), per ognuna 4 viste radenti a 35 cm, una dall'alto, 2 dagli occhi e 2 ravvicinate:
  - P12 nella torre;
  - P13, P15 e P16 nella risalita, stati inizio e ritorno;
  - P14 nella sala, stati inizio, ritorno e risolto, con le parti lontane tolte.
  - Per la P12 anche 8 viste a 18 e 30 cm, a 1,2 e 3 cm d'altezza, coi materiali veri.

## Risultati

| Polaroid | Dove | Distacco dalla superficie visibile (centro e 4 angoli) | Raccolta | Scatti |
|---|---|---|---|---|
| **P12** | torre, pianerottolo del portone, sul grigliato | **13,5 mm** in tutti e tre gli stati, uguale ovunque | sì | **sospesa**: si vede il vuoto sotto (`fogli/P12_sospesa_sul_grigliato.jpg`) |
| P13 | risalita, sotto l'oblò del corridoio verso il capannone | 3,2 mm, anche con lei all'oblò e dopo che si stacca (le mesh dell'oblò non la toccano) | sì | a terra, piatta (`fogli/P13_P15_P16_risalita.jpg`) |
| P14 | sala, davanti all'acquario giallo | 3,2 mm, con gli acquari vuoti e pieni | sì | a terra, piatta, vista dagli occhi accanto ai piedi dell'acquario (`fogli/P14_acquari_tre_stati.jpg`, `fogli/P14_dagli_occhi.jpg`) |
| P15 | risalita, zona del personale accanto alla porta del capannone | 3,2 mm | sì | a terra, piatta |
| P16 | risalita, approdo del fiume, fra i detriti e il muro | 3,2 mm, col fiume caricato a gioco avviato | sì | a terra, piatta |

- **La P12:**
  - la collisione del pianerottolo sta a y 0; la mesh del grigliato (`torre_A_grigliati`) sta 1,05 cm più sotto;
  - Posa la appoggia 4 mm sopra la collisione, quindi resta 13,5 mm sopra le barre;
  - correzione possibile: appoggiarla alla mesh e non alla collisione, cioè 1,35 cm più in basso, oppure metterla dove pavimento visibile e collisione coincidono.
- **Totale:** la collezione conta 16 in tutti gli stati.
- **Nessuna coperta o bloccata:** il raggio del giocatore le trova e si raccolgono tutte e cinque, da un posto libero a 0,9 m. Negli scatti dagli occhi si vedono.
- **Partenze F9:**

  | Partenza | Polaroid raccolte |
  |---|---|
  | risalita (dopo la sala generatori) | 9, P1-P9 |
  | fiume (all'ingresso del fiume) | 9, P1-P9 |
  | torre (oltre il portone) | 14: P1-P9, la pecora, P13, P14, P15, P16 |
  | inseguimento | 16: anche P10 e P12 |
  | tunnel | 16: anche P10 e P12 |

  - **Da decidere:** nella partenza "fiume" manca la P13, che sta nel corridoio subito prima del capannone. Chi parte da lì la trova per terra alle sue spalle.
- **Test:** test_risalita 15/15, test_risalita_tardi 12/12, test_partenze_prova 72/72, test_torre 94/94.
- **Log:** 0 righe "ERROR: BUG,", né senza schermo né col renderer vero.

## Note

- Coi materiali semplici dei giri, il grigliato si disegna pieno, senza buchi (`fogli/P12_materiali_semplici.jpg`): lì il distacco non si vede. Si vede negli scatti coi materiali veri.
- **Non fatto: il giro del tunnel per sentire il cuore e il ritmo.** Si ascolta, e qui non si può. Si rifà col giro completo, dopo gli effetti di grafica-2.
