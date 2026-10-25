# Infermeria della risalita: più buia, faretti e negatoscopio A (24-25 ottobre)

Richiesta dell'utente: "l'infermeria sembra low quality come ambiente, prova a renderla un po più buia illuminando però lo schermo dove si poggia la radiografia e puntando anche un faretto molto poco luminoso sulla cassaforte". Per il negatoscopio l'utente ha scelto la versione A.

- **Più buia**: le due lampade rosse d'emergenza passano da 1,6 a 0,9 e la lucina della luna da 1,2 a 0,6. Il pulsante del parco col lampeggiante giallo, lo schizzo viola e l'adesivo rosa del cassetto, la cassaforte con le rotelle e il cartello verde d'uscita si vedono ancora senza torcia.
- **Negatoscopio, versione A**: finché non colpisci l'interruttore resta spento del tutto, senza più lo sfarfallio (`Negatoscopio.sfarfalla = false`). Lo fa notare un faretto debole a soffitto che illumina la cornice e il muro intorno. Quando lo colpisci si accende da solo, con la sua luce sulla scrivania, e la radiografia si legge come prima.
- **Faretto sulla cassaforte**: è molto debole e caldo, a soffitto, e lascia una macchia morbida sulla cassaforte.
- I due faretti hanno una piastra avvitata al soffitto, il gambo, il barattolo puntato e il vetro appena acceso. Il cavo corre contro il soffitto fino a una scatola di derivazione nell'angolo col muro (`_faretto_soffitto` in `infermeria_gioco.gd`). Gli oggetti dell'enigma non si sono spostati.

Scatti dal motore con i materiali veri e la luce d'ambiente di `tests/scatti_infermeria_gioco.gd`, dagli stessi punti:
- `prima/` è su lavoro/godot, `dopo/` sul branch;
- `chiusa/` ha il negatoscopio spento, `luce/` ce l'ha acceso, cioè dopo l'interruttore;
- i fogli affiancati sono `confronto_chiusa.jpg` e `confronto_luce.jpg`;
- in `faretti/` ci sono gli scatti ravvicinati dei due faretti, con una lampadina per vederli. Lo script è `godot/proposte/infermeria_luci/scatti_faretti.gd`.

## Dopo il pulsante: variante A o B (da scegliere con l'utente, 25 ottobre)

Con il negatoscopio acceso la stanza tornava chiara quasi come prima. Il motivo non sono le luci bianche al 40%: il negatoscopio ne è escluso, e la sua SpotLight sulla scrivania era a 3,0 con un cono di 75°, quindi illuminava tutta la stanza. L'opzione nel codice è `buia_dopo_pulsante` in `infermeria_gioco.gd`:
- **B**, la scelta di partenza (falso): com'è adesso, la luce larga del negatoscopio illumina la stanza;
- **A** (vero): la stanza resta buia anche dopo. La sua luce sulla scrivania scende a 0,9 con un cono di 42°, e la luce principale è lo schermo acceso più il faretto della cassaforte. Pulsante verde, schizzo rosa, rotelle e uscita si trovano ancora.

Gli scatti della A sono in `variante_A/luce/`, dagli stessi punti di `dopo/luce/`, e il foglio affiancato è `confronto_luce_A_B.jpg`. Per rifarli: `INFERMERIA_BUIA=1` con `tests/scatti_infermeria_gioco.gd`.
