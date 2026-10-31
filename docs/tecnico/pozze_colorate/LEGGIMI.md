# La stanza delle pozze colorate: la logica e il cartello (enigmi, 31 ottobre)

**L'idea.** È dell'utente (31 ottobre), con tutte le scelte consigliate della pagina delle proposte. Le scelte sono nel GDD, alla sezione "La stanza delle pozze colorate".

**Chi fa cosa** (branch `lavoro/stanza-pozze`):
- **ambienti-1:** la stanza dopo l'infermeria, con la passerella, le vasche, la porta stagna, il lampeggiante, le luci, la scala spostata, il caricamento e il checkpoint d'ingresso;
- **enigmi:** l'acqua, la logica, il cartello e i test.

## Come funziona (`scripts/game/enigma_pozze.gd`, EnigmaPozze)

**Le pozze.** Sono 25, in 5x5, una attaccata all'altra:
- lato interno 1 m, 1,1 m da centro a centro, profonde 0,75 m;
- l'acqua arriva a 5 cm dal bordo;
- ci sono 5 colori, 5 pozze per colore: arancione, rosa, viola, turchese e bianco latte.

**La griglia.** Il colore della pozza è `(colonna + 2 riga) mod 5`:
- ogni riga e ogni colonna ha tutti i colori;
- due pozze dello stesso colore non si toccano, nemmeno in diagonale;
- ogni colore ha pozze sul bordo. Dalla passerella sud, quella da cui si entra, se ne vede una per colore.

**I colori giusti.** Quelli da togliere sono turchese, viola e arancione. Con il pastello sul bianco del cartello sono i tre più diversi fra loro; il bianco latte sul foglio bianco non si vedrebbe. Restano il rosa e il bianco latte.

**Togliere un colore.**
- Basta aspirare 2 litri da una pozza: tutte quelle del suo colore si svuotano insieme, col gorgo, in 3,5 s.
- Lo zaino prende il colore. Se dentro c'era acqua di un altro colore, la butta da sola (`WaterPack.scarta_altri_colori`). Le pozze hanno il meta `scarta_altri_colori`.
- Le pozze non prendono il getto: l'acqua sparata dentro trabocca e non cambia i colori.

**Il controllo**, al terzo colore tolto:
- **giusto:** `PortaStagna.apri()` apre la porta, la cui lampada passa da rossa a verde, e si raggiunge `CheckpointRisolto` (ordine 15);
- **sbagliato:** il lampeggiante `LampeggianteErrore` lampeggia e si sente lo scarico. Dopo 1,5 s le pozze vuote si riempiono di nuovo coi loro colori, in 4 s. Mentre si riempiono non si aspira.
- Un quarto colore non comincia mentre tre sono tolti o si stanno togliendo.

**Il salvataggio.** Lo stato si salva coi checkpoint e con Continua (gruppo "persist"). I livelli e i colori li salvano le pozze stesse (WaterTank). Quello che era a metà si finisce caricando:
- un colore che si stava svuotando riparte vuoto;
- uno sbaglio riparte già ricaricato;
- se era risolto, la porta si apre senza animazione.

**L'acqua.** Ogni pozza è un WaterTank senza muri, con l'acqua vera dell'addon (WaterTankLink) nello stile del suo colore (`assets/pozze_colorate/acqua_<colore>.tres`):
- il gorgo e i suoni (scarico, riempimento, vasca svuotata) sono quelli delle vasche: uno scarico per colore e un carico per tutte;
- niente simulazione delle increspature e niente cubemap: sono 25 pozze piccole;
- le pozze stanno fuori dalla tabella delle masse d'acqua dell'addon (`WaterManager`, al più 12). Altrimenti avrebbero preso il posto delle vasche e dei canali del resto del gioco: per questo sui fondi delle pozze non ci sono le caustiche;
- chi cade in una pozza ne esce saltando (il salto è 1 m).

## Il cartello (l'indizio)

- **Dove:** nell'infermeria, sul muro nord, a ovest della porta da cui si esce verso le pozze. Sta fra lo stipite e l'angolo, 8 cm per parte, perché a est si appoggia l'anta aperta. È all'altezza degli occhi (centro a 1,5 m) ed è a contatto col muro; il listello si interrompe da solo.
- **Com'è:** lamiera smaltata di 34 x 46 cm, con:
  - il disco rosso con la barra bianca;
  - la sagoma di un bambino con la mano alzata;
  - i tre quadratini a pastello dei bambini: viola, arancione e turchese.
  Nessuna scritta.
- **La texture:** è procedurale, da `assets_src/pozze_colorate/cartello.py`, col pastello degli scarabocchi sui muri (`assets_src/scarabocchi/pastello.py`), così i colori sono proprio quelli delle pozze. È VRAM compressa, con le mipmap.
- **La luce:** un faretto a soffitto con una lampadina bianca, puntato sul cartello. La luce verde dell'uscita falserebbe i pastelli; il resto dell'infermeria resta buio.

## Test

- `tests/test_pozze.gd`, in CI, col giocatore vero che guarda una pozza dalla passerella e tiene il tasto destro. Per ora gira nella stanza grigia di prova (`tests/pozze/stanza_prova.gd`). Controlla:
  - la griglia;
  - risolto nei due ordini;
  - sbagliato e poi giusto;
  - un quarto colore no;
  - lo stato salvato a metà e da risolto;
  - si esce saltando da una pozza.
- `tests/test_infermeria_gioco.gd`: il cartello (posto, muro, altezza, texture, faretto) e l'anta aperta che non lo copre.
- **Da fare con la stanza vera:**
  - la strada da F9 Fiume attraverso le pozze;
  - Continua a metà e da risolto;
  - `test_strada` attraverso la stanza;
  - le partenze F9 rigenerate, con le pozze risolte per quelle dopo.
