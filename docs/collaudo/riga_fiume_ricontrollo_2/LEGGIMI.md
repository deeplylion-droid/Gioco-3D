# Secondo ricontrollo della riga del fiume (#130): `lavoro/riga-fiume` fed6fd28 (8 novembre, sera)

Squadra collaudo. Prima = main e3104cd2, dopo = fed6fd28. Ho usato gli stessi strumenti e gli stessi scatti del primo ricontrollo (`../riga_fiume_ricontrollo/`): fiume da solo, luci del blackout, ambiente della sala, preset alto. Nel gioco non ho cambiato niente.

**Esito: superato sui cinque punti. Un difetto piccolo nuovo:** sei pinne di parete dentro l'acqua, dove le toppe incontrano le conche.

## 1. La riga al bivio nord: sparita
`fogli/riga_bivio_nord.jpg`: prima e dopo schiariti 3 volte, più il magenta senz'acqua.
- **Da dove ho guardato:** da Giusto1 a 17, 25 e 33 m, da Giusto2 a 1 m e dalla banchina (Giusto2 1 m, Sbagliato2 1 m).
- **Cosa si vede ora:** la riga di cielo non c'è più; al suo posto ci sono le piastrelle delle pareti.
- **Magenta senz'acqua:** 0 pixel in tutti questi scatti.
- **La mappa ogni 5 cm** (`dati/mappa_bivio.txt`): a x ±3,1, z 24-25,4 è tutta acqua. Niente lame e niente buchetto a (−3,40; 25,15).

## 2. Il buco all'estremità est: chiuso
`fogli/buco_est.jpg`: dall'Imbarco a 33, 41 e 49 m, da Giusto1 a 1 m, dalla banchina di Sbagliato1 e da Sbagliato3.
- La striscia di cielo a pelo d'acqua (x 26,3…27, z −3…+3) non c'è più; si vedono le pareti.
- Magenta senz'acqua: 0 pixel.

## 3. Magenta senz'acqua: tutti i 221 scatti
`dati/magenta_senza_acqua_*.txt`.
- **I numeri:** gli scatti con magenta passano da 100 (prima) a 23 (dopo). Nessuno è nuovo o più grande.
- **I 23 che restano non sono al bordo dell'acqua e c'erano già prima, uguali o più piccoli** (`fogli/altri_buchi_gia_prima.jpg`):
  - la porta di servizio all'approdo (Uscita 9 m) e le due viste dall'alto: nella scena del solo fiume dietro non c'è niente, nel gioco va bene;
  - fessure di pochi pixel fra gli oggetti vicino all'imbarco:
    - fra la capanna e la parete, da Sbagliato1 e Sbagliato2 a 25 m e dalla banchina dell'Imbarco a 1 m;
    - sotto la valvola verde dell'approdo (Uscita 1 m);
  - punti lontanissimi sul muro ovest (1-8 pixel).

## 4. Collisioni: la strada di chi cammina è uguale
- **La prova** (`dati/confronto_barriere.txt`): griglia di 0,5 m sul pavimento. Fra ogni coppia di punti vicini, tutti e due di pavimento, un raggio a 1 m d'altezza sullo strato delle barriere: dopo nessun passaggio fra due punti di pavimento è chiuso.
- **Le 3 coppie che risultano «chiuse ora»** (a (16,5…17,0; −14,6…−14,1) e (3,0; −23,1…−22,6)) non sono passaggi. I loro punti stanno proprio sulle righe della griglia di 2 m (x 17 e 3, z −14,6), sul bordo dell'acqua, e il raggio corre dentro il piano della barriera nuova. La banchina accanto resta aperta.
- **I punti di pavimento:** 12 611 prima, 12 640 dopo. 12 coppie spariscono perché dove c'erano le lame ora c'è acqua.
- **I raggi delle collisioni** (`dati/confronto_raggi.txt`): cambiano dove ci sono le barriere nuove lungo i lati delle conche e le toppe d'acqua. Le pareti hanno di nuovo la collisione dal lato della banchina, come prima: i raggi dall'acqua arrivano al fondo.
- **test_fiume_gioco** passa 34 controlli su 34: a piedi fino all'imbarco, nel canale non si cade, il tasto E per la ciambella, la corsa, i bivi, l'approdo.
- **Barriere con l'acqua dai due lati:** sono 18 nuove, nei punti delle pinne del punto 5 (`dati/barriere_dopo.txt`). Lì il giocatore non arriva.

## 5. Pareti e posizionamento
- **Il verso delle pareti** (`dati/pareti.txt`): su 2 662 triangoli, 0 hanno la faccia davanti non verso l'acqua e 0 hanno la normale contro la faccia.
- **Difetto piccolo, nuovo: 24 triangoli hanno l'acqua dai due lati.** Sono 6 coppie di pareti schiena contro schiena, cioè pinne di mosaico dal pelo al fondo, dentro l'acqua. Stanno dove le toppe d'acqua incontrano le conche (`fogli/pinne_nell_acqua.jpg`, prima e dopo schiariti 2 volte). Dagli occhi si vedono come uno spigolo di piastrelle che scende in diagonale nell'acqua all'angolo della conca. Le posizioni, ricavate dai triangoli:

  | bivio | da | a | lunghezza |
  |---|---|---|---|
  | nord-ovest | (−3,01; 24,26) | (−3,19; 25,40) | circa 1,15 m |
  | nord-est | (3,01; 24,26) | (3,19; 25,40) | circa 1,15 m |
  | est, primo pezzo | (24,31; −3,01) | (25,00; −3,13) | |
  | est, secondo pezzo | (25,00; −3,12) | (25,39; −3,21) | |
  | est (sud) | (25,0; 3,13) | (25,4; 3,2) | |
  | ovest | (−25,0; 3,13) | (−25,4; 3,2) | |

  Probabilmente è un pezzo di pavimento larghissimo meno di un centimetro, rimasto fra la toppa e la conca, con le sue due pareti.
- **controllo_cielo:** 686 posti, 0 col cielo, compreso «risalita: il fiume dalla ciambella» (`dati/test.txt`).
- **controllo_posizionamento: 0 da correggere.**
- **test_fiume** passa 35 controlli su 35.

## Strumenti
In `godot/tests/collaudo/`:
- quelli del primo ricontrollo;
- `sonda_barriere_fiume.gd`: le coppie di punti della banchina e le barriere. Il confronto lo fa `confronta_barriere.py`, qui accanto;
- `fiume_pinne.gd`: gli scatti da vicino dei sei punti.
