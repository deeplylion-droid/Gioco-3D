# Collaudo della Polaroid 16 col fiume fermo: `lavoro/polaroid-fiume` 925e256c (9 novembre)

Squadra grafica come collaudo. Prima = main d01e5a95, dopo = 925e256c. Nel gioco non ho cambiato niente.

**Esito: la correzione funziona (punti 2, 3 e 4 superati). Punto 1 non superato, ma il difetto non è di questo branch:** le Polaroid sono sollevate di 3-4 mm dal pavimento, ed è così anche su main.

## 1. I 4 mm: c'è uno spazio di 3-4 mm sotto la foto (difetto, anche su main)
- **Il modello** (`godot/tests/collaudo/polaroid_spessore.gd`): la foto è quasi piatta. Il suo fondo sta da 0,1 a 0,8 mm sotto l'origine (la riga di un lato corto a −0,6…−0,8 mm, il resto a −0,1…−0,3 mm); la faccia di sopra sta a +3,1 mm.
- **Le Polaroid** (`Posa.appoggia_a_terra(self, 0.004)` e lo `_snap` di sempre, `hit.position + n * 0.004`) mettono l'origine 4 mm sopra il pavimento. Quindi tutta la foto resta sollevata: **3,2 mm sotto un lato corto, 3,7-3,9 mm sotto il resto.**
- **Da vicino** (`p16_vicino_*.jpg`, `p16_ritagli_radenti.jpg`; camera a 25 cm, lampadina sulla camera o solo le luci del blackout):
  - dall'alto, a 35 cm d'altezza, e da accovacciati (occhi a 0,97 m, a 50 cm, `p16_accovacciato.jpg`): sembra appoggiata, non si vede spazio;
  - di lato, a 2 cm e a 6 mm d'altezza: da 270° si vede lo spazio, uno spicchio scuro sotto il bordo. Dagli altri lati il bordo bianco della foto sembra galleggiare appena sul pavimento.
- **Il giocatore** con gli occhi a 2 cm dal pavimento non ci arriva. Ma la regola dice che anche 1-2 mm di distacco sono un difetto, e qui sono 3-4 mm.
- **Vale per tutte le Polaroid appoggiate**: 14 su 14 nella sonda, a 4,0 mm dalla collisione e dalla mesh vera. La P05 è a 8,4 mm, la P08 a 7 mm dalla mesh: le ho viste solo coi numeri, non da vicino.
- **Proposta:** `fondo` 0,001 al posto di 0,004, sia in `_appoggia` sia in `_snap`. Il fondo della foto andrebbe a 0,2-0,9 mm dal pavimento. Va controllato su un pavimento con le mattonelle in rilievo e sul fondo inclinato della piscina, dove lo `_snap` alza gli angoli che entrano.

## 2. Le Polaroid allo stesso posto, e la P16 si raccoglie
- **Nel gioco vero** (`polaroid_posti.gd`, `dati/posti_*.txt`): 14 Polaroid, la P10 e la P12 no, perché la torre non è caricata. Posizione, giro e distanza dal pavimento sono **identici fra main e il branch**, sia con le stanze messe subito sia «a richiesta» (dal corridoio, come nel gioco).
- **Col fiume fermo a lungo** (`test_polaroid_fiume_ferma`, `dati/test_ferma_*.txt`):
  - sul branch passa, P16 a 4,0 mm, nello stesso posto di quando il fiume si costruisce acceso;
  - **su main fallisce:** 30,0 mm, spostata di 26 mm.
- **La P16 si raccoglie:** col tasto (interact) entra nella collezione «polaroid», che è quella che leggono l'album e il contatore (`trovata(16)` vera, una foto trovata), e il nodo sparisce.

## 3. Il fiume come nella 0.3.23
- **Il codice:** fra main e il branch nessun file del fiume è cambiato.
- **Il giro dagli occhi** (`fiume_giro.jpg`, 101 scatti con passo 24 m, `fiume_giro.gd`): come prima.

## 4. Posizionamento
0 da correggere, nessun caso nuovo (64 già noti) (`dati/posizionamento.txt`).

## Strumenti
In `godot/tests/collaudo/`: `polaroid_spessore.gd`, `polaroid_posti.gd` (modi `subito` e `richiesta`), `polaroid16_vicino.gd` (`LAMPADA=1`), `fiume_giro.gd` (dal collaudo della riga del fiume).


# Secondo ricontrollo: il fondo a filo, `lavoro/polaroid-fiume` 6dbafdfe (9-10 novembre)

**Esito: superato su tutti e cinque i punti.**

## 1. Le 16 Polaroid, da vicino
I fogli sono `ricontrollo_2/foglio_*.jpg`. Per ogni foto, nel sistema della foto (sul fondo in pendenza la camera segue la pendenza):
- da accovacciati: occhi 0,97 m sopra la foto, a 50 cm;
- di lato: a 25 cm, 2 cm sopra la foto;
- radente: a 22 cm, 6 mm sopra la foto;
- dai 4 lati, con una lampadina con ombre sulla camera.

Lo strumento è `godot/tests/collaudo/polaroid_tutte_vicino.gd`, una zona per volta.

**Lo spicchio scuro sotto il bordo non c'è più**, da nessuna parte. Da accovacciati sembrano tutte appoggiate. Di lato si vede solo la foto un po' curva ai bordi: un angolo si alza appena, come una foto vera. Non sembra sollevata.

Le misure nel gioco vero (`ricontrollo_2/dati/misure.txt`, 7 x 7 punti come test_polaroid_appoggiate):
- tutte a 0,19-0,20 mm nel punto più vicino, 0 punti dentro;
- il massimo è 1,7-2,9 mm sempre allo stesso angolo: è la curva del modello.

Due eccezioni nelle misure:
- **P02**: attaccata col nastro alla porta di un armadietto, sulle feritoie. Il massimo di 174 mm è un punto sopra una feritoia. Si vede bene.
- **P10**: sul gradino della scaletta. Un lato lungo sporge di circa 1,4 cm oltre lo spigolo del gradino: lì sotto ci sono 17-18 mm di vuoto, ed è una colonna su sette. Il baricentro è sul gradino. Di lato, da 90° e 270°, si vede il bordo sporgere. **Va bene così** (il coordinatore, 9 novembre): poggia sul gradino come una foto caduta lì, e non è staccata.

**P11**: è dentro la cassaforte dell'infermeria, quindi l'ho guardata anche nello stato dopo il codice. Con la cassaforte aperta (`APRI=1`, `foglio_p11_cassaforte_aperta.jpg`, `p11_ritagli_radenti.jpg`), da davanti dallo sportello, di lato e radente: è appoggiata sul fondo della cassaforte, accanto alla keycard. Sotto si vede solo il riflesso sul fondo lucido, non uno spazio. Le misure: 0,20-2,86 mm, 0 punti dentro.

## 2. P05 e P08
- **P05**: sul fondo in pendenza della piscina a onde (sala_piscina_onde, normale inclinata di circa 3,8°). La foto segue la pendenza, 0,20 mm, niente dentro e niente sollevato.
- **P08**: sul bordo dell'arrivo degli scivoli (Sala/TorreScivoli/arrivo_bordi). Inclinata di 3,4° (y = 0,06; 0,998; 0), 0,20 mm.

Gli scatti della P08 sono fatti con il bordo dell'arrivo sotto (`foglio_p05_p08.jpg`): la foto segue la piega del bordo, appoggiata, niente dentro. Gli scatti della P06 e della P07 sullo stesso foglio sono fatti coi tecnici sotto.

## 3. P10 e P12 nella torre
Dal portone (SalaPrincipale._aggiungi_torre) e da F9 i due posti sono identici:
- **P10** in (23,5931; −11,6695; −22,4069);
- **P12** in (22,1; −0,0095; −13,95).

**P12, i −9,5 mm:** sono misurati dalla collisione del grigliato, che sta circa 1 cm sopra le barre. Dalla mesh delle barre il fondo della foto è a 0,20 mm, 0 punti dentro. Negli scatti di lato la foto è appoggiata sulle barre: né affondata fra le barre, né sospesa.

## 4. Il controllo di posizionamento col riquadro orientato
Sul branch, lo stesso gioco con le due versioni del controllo (`ricontrollo_2/dati/pos_*.txt`):
- **orientato:** 0 nuovi, 64 già noti, 0 da correggere;
- **allineato al mondo (quello di main):** gli stessi 64 noti, più 2 nuovi, la P05 e la P08 come «compenetrato». Sono il caso che il riquadro orientato corregge.

Quindi il cambio non nasconde nessuna compenetrazione vera altrove.

- **Su main, col suo controllo:** 0 nuovi, 64 già noti, 0 da correggere.
- **Il rapporto del branch confrontato con quello di main:** gli stessi 64 casi. Cambiano solo i nomi automatici di 12 mesh del sottomarino (@MeshInstance3D@…), che sono casi «voluto».

## 5. La P16 col fiume fermo, raccolta e album
- **test_polaroid_fiume_ferma:** 6/6. Fondo a 0,20 mm, ferma 30 s e poi riaccesa nello stesso posto.
- **test_polaroid_appoggiate:** 19/19.

- **La P16 raccolta** (`dati/p16_raccolta.txt`, gioco vero, a richiesta): col tasto entra nella collezione «polaroid», quella che legge l'album (trovata(16) vera, una foto trovata), e il nodo sparisce.

## Strumenti
In `godot/tests/collaudo/`:
- `polaroid_misure.gd`: le misure e la torre dal portone e da F9;
- `polaroid_tutte_vicino.gd`: gli scatti, con le zone `interni`, `sala`, `sala_vasca`, `tecnici`, `torre`, `risalita`, più `SOLO=<foto>` e `APRI=1`;
- `polaroid_sotto.gd`: cosa c'è sotto una foto;
- `polaroid_posti.gd`: dal primo ricontrollo.
