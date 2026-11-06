# Ricontrollo della correzione di ambienti-2: occhi nelle bocche e gomito della scaletta

Squadra collaudo, 6 novembre. Ho controllato `lavoro/ritocchi-ambienti2` allo sha 7cb9d82b; la correzione è il commit 0fc590e9. Nel gioco non ho cambiato niente.

## In breve
- **Le bocche vanno bene in tutte e 6, in tutti e due i sensi.**
  - La camera passa il pelo una volta sola, fra 0,8 e 1,5 m dentro, e non sta mai a filo dell'acqua: resta sempre almeno 2 cm sopra o sotto.
  - Non esce più dal soffitto: nel punto più stretto resta 5 cm sotto, nello scolo 0.
  - Il passo più grande della camera è di 55 mm, nel fotogramma in cui passa sotto. Nella parte ripida dello scolo 0 arriva a 66 mm.
  - L'acqua non si vede mai da sotto: dove la camera è sotto il pelo, la parete d'acqua della bocca copre la superficie.
- **Il gomito della scaletta va bene**: ogni montante è un tubo solo piegato, senza tappi.
- **Test verdi** e posizionamento a 0 casi da correggere.
- **Due cose da far vedere all'utente**, nessuna delle due blocca:
  - la parete d'acqua vista da sotto è abbastanza trasparente;
  - nel tubo 3 c'è una striscia verde, che viene da una luce.

## Test (0 BUG, 0 SCRIPT ERROR)
| test | esito |
|---|---|
| test_occhio_sopra_acque | 106 ok |
| test_scaletta_bacino | 13 ok |
| test_inseguimento | 43 ok |
| test_morbidezza_inseguimento | 72 ok |
| test_lei_discese | 21 ok |
| test_sottomarino_gioco | 13 ok |
| controllo_posizionamento | 0 da correggere, 0 nuovi, 64 già noti |

## Le 6 bocche, coi numeri
Ho usato `sonda_bocche2.gd`, un'esecuzione per ogni bocca e per ogni senso:
- andata: dalla vasca fino a 3,3 m dentro;
- ritorno: fino a 1,2 m dentro, poi col tasto indietro.

I valori di ogni fotogramma sono in `bocche_fotogrammi.tsv`, nelle colonne lz, piedi, occhio naturale, limite, camera, soffitto (rispetto al pelo) e alzata.

| bocca | passa il pelo a | camera dal pelo al minimo | spostata dall'occhio naturale al massimo | sotto il soffitto al minimo | passo più grande in un fotogramma |
|---|---|---|---|---|---|
| tubo_1 | 1,41 m (giù) | 2,0 cm | 2,6 cm | 22-33 cm | 55 mm (al passaggio) |
| scolo_0 | 1,22 m | 2,0 cm | 3,1 cm | 5,1-5,6 cm | 64-66 mm (a 2,1 m, dove lo scolo è ripido) |
| tubo_2 | 0,92 m | 2,0 cm | 2,4 cm | 42-45 cm | 55 mm |
| scolo_1 | 0,80 m | 2,0 cm | 1,8 cm | 24-27 cm | 55-68 mm |
| tubo_3 | 1,32-1,52 m | 2,0 cm | 3,5 cm | 16-29 cm | 55 mm |
| scolo_2 | 1,28 m | 2,0 cm | 2,0 cm | 21-26 cm | 55 mm |

- Ogni bocca passa il pelo una volta sola.
- Nessun fotogramma è sotto il pelo dal lato della vasca.
- Per lo scolo 1 la sonda conta anche dei fotogrammi "sotto il pelo dal lato della vasca", ma non sono veri. Lì lo scolo gira e torna sotto la vasca, e la camera sta 2,3 m sotto il pelo, dentro il tubo.

## Gli scatti dagli occhi
Ho fatto gli scatti col renderer vero, con `vista_bacino.gd bocche <bocca>`, uno per bocca. Si scatta:
- ogni 6 fotogrammi;
- **a ogni fotogramma** quando la camera è a meno di 12 cm dal pelo e negli 8 fotogrammi dopo il passaggio;
- girati verso la vasca, guardando un po' giù e un po' su, a 1,2, 1,8 e 2,4 m e nel primo fotogramma sotto il pelo.

I fogli sono `fogli/bocca_<bocca>_passaggio.jpg`:
- gli scatti prima e dopo il passaggio, con lo scatto `_PASSA`;
- tutti i girati.

Cosa si vede:
- Al passaggio la vista avanti resta tranquilla: niente salti e niente lampi.
- Girati verso la vasca da sotto il pelo, si vede la bocca piena d'acqua fino al pelo, con sopra la sala. La superficie non si vede mai da sotto.
- **Da far vedere all'utente.** Da sotto il pelo la parete d'acqua lascia vedere le piastrelle del fondo della vasca. Nel tubo 1 e nello scolo 2 l'acqua è verde piena. Nello scolo 0 e nello scolo 1, invece, l'acqua è scura, quasi grigia, e le piastrelle si vedono nitide. Esempi:
  - `bocca_scolo_0_passaggio.jpg`, girato a 1,30 m;
  - `bocca_scolo_1_passaggio.jpg`, girati a 0,89 e 0,98 m.

  È la stessa acqua trasparente che si vede da sopra, quindi per me non è un difetto della correzione. Però l'utente aveva detto che "la vasca sembrava asciutta", e va guardata.
- **Striscia verde nel tubo 3** (`fogli/striscia2_tubo_3.jpg`):
  - girati verso la vasca da 1,3 m dentro, nel buio del tubo si vede una riga verde chiara, sottile e dritta;
  - con lo strumento `vista_striscia.gd` resta anche togliendo le pareti d'acqua e le altre acque, e sparisce spegnendo le 28 luci verdi;
  - quindi è la luce verde di una lampada (paratia o uscita) che illumina l'interno del tubo, probabilmente da fuori, attraverso il tubo;
  - non è acqua e non è un buco: è una piccola cosa di luci, che c'era già prima.

## Il gomito della scaletta
Il foglio è `fogli/gomito_scaletta.jpg`: i due gomiti visti da davanti, di lato, dall'alto e da sotto, con una lampadina tecnica.
- Ogni montante è un tubo solo, piegato in curve morbide.
- Poggia sul bordo e scende contro la parete interna.
- Non ci sono tappi e non ci sono stacchi.
