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
