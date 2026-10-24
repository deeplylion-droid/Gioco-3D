# Collaudo risalita e fiume (lavoro/godot ff9860bb)

Collaudo fatto il 23 e 24 ottobre. Non ho corretto niente: qui trovi solo quello che ho visto e misurato.
Gli scatti sono del motore (Godot). Quelli "semplici" hanno i materiali piatti di COLLAUDO_SEMPLICE, `veri.jpg` ha i materiali veri.

## Difetti

1. **Sulla sponda interna del canale (a sinistra della ciambella) la roccia non è continua.** Fra un pannello di roccia e l'altro si vede il muro grigio liscio, e in certi tratti c'è solo quello.
   - Foglio: `difetto_1_roccia_sponda.jpg`.
   - Scatti dalla ciambella, rivolti a sinistra:
     - c_Imbarco: 05, 06, 07, 09, 11, 12, 13;
     - c_Giusto1: 00, 01, 06, 07, 09;
     - c_Giusto2: 00, 01.
   - Le coordinate di ogni scatto sono in `lista_ciambella.txt`, nella cartella di lavoro del collaudo.
2. **Nel corridoio C3 c'è una staffa a muro vuota.** Sono `Tecnici/Ambienti/Raccordo/ArredoRisalita/G_c3s_m_5_piastra` e `G_c3s_m_5_piolo`, a (-16,0; 1,7; 30,95). Non ci appende niente: l'oggetto `G_c3s_m_5` non esiste. Per confronto, la staffa m_1 ha appeso il suo oggetto.
   - Foglio: `difetto_2_staffa_vuota_c3.jpg`.

## Da sapere (non difetti per la regola del coordinatore)

- **Cartelli** (foglio `cartelli.jpg`). Tutti e tre si leggono di fronte quando ci arrivi. Di spalle o di taglio si vedono solo dopo averli passati:
  - **bimbi**, a (-7,44; 68,15): si legge di fronte dall'ingresso.
  - **tuffi della fila**, a (-28,98; 87,76): si legge di fronte lungo la fila e alla fine della fila. Dall'imbarco (-32,08; 89,06) si vede di spalle o di taglio: è il rettangolo nero visto da grafica (`k_tuffi_fila__imbarco`).
  - **tuffi dell'approdo**, a (-37,88; 55,14): si legge di fronte arrivando in ciambella (`k_tuffi_approdo__arrivo_canale`). Dal punto dove si scende si vede di taglio, dalla porta del personale di spalle.
- **Cemento all'ingresso.** Ho cercato i triangoli sovrapposti sullo stesso piano fra x -13 e -3 e fra z 56 e 72.
  - Ci sono solo al pavimento (y -5,4: il pavimento sotto le basi delle transenne e delle pile) e fra una cassa e l'altra delle pile.
  - Sui muri dell'ingresso (Risalita/@273, @279, @275, @277) le facce stanno solo una accanto all'altra, oppure sono facce interne coperte.
  - Negli scatti fermi con i materiali veri (v_g010, v_g011) non si vede sfarfallio.
  - Lo sfarfallio va verificato in movimento sul pavimento, dove le basi delle transenne poggiano esattamente alla quota del pavimento.
- **Paratia5 all'uscita del canale.** Sta a 0,49 m dal centro della ciambella in c_Uscita_01 (-35; 64): passa molto vicina, ma non la tocca (`ciambella_verde_e_paratia.jpg`).

## Controlli passati

- **Controllo automatico di posizionamento** negli stati risalita_arrivo e risalita_dopo: 0 casi nuovi, 16 noti, 2 ok (`controllo_posizionamento.md`).
- **Distanze vere.** Ho misurato 1349 oggetti di risalita e raccordo, con soglia 1 cm.
  - Solo 5 non sono attaccati a qualcosa: ciambella, ciambella4, ciambella5, ciambella6 e paperella. Galleggiano sull'acqua.
  - Lo stacco più grande è 5,6 mm (G_mag_11), poi 5,0 mm (pezzi piccoli dell'infermeria). Tutti gli altri restano sotto i 4,1 mm.
- **Scala dalla sala generatori.** Scatola, estintore e manichetta stanno fuori dal corrimano. L'oggetto più vicino è G_c2oa_4 a 3,5 cm, poi G_c2o_m_2 a 9,9 cm. Vedute: `vedute_*.jpg`.
- **Pile di scatoloni.** Ho tirato 2808 raggi da 13 punti della passerella: nessun buco verso il vuoto. I soli raggi "lunghi" arrivano al tetto del capannone, a 41-43 m.
- **Le 3 lampade sulle pile** (@788, @790, @792) sono attaccate alla pila, con la staffa che si vede (`lampade_pile.jpg`). Nelle vedute pila1 e pila3 ci sono dei triangoli neri: la camera finisce dentro o dietro una pila, non è la lampada.
- **La ciambella verde fluorescente** si vede bene nei rami sbagliati (Sbagliato1_03, Sbagliato2_03).
- **Strada dall'approdo alla porta dopo**: libera (`strada_*.jpg`, `veri.jpg`).

## Fogli

| File | Cosa contiene |
|---|---|
| `ciambella_*.jpg` | giro in ciambella |
| `piedi_*.jpg` | giro a piedi |
| `vedute_*.jpg` | ogni oggetto piccolo da vicino |
| `strada_*.jpg` | strada vera, cartelli e mire |
| `veri.jpg` | materiali veri |
