# Ricontrollo della riga del fiume (#130): `lavoro/riga-fiume` d59e2d44 (8 novembre)

Squadra collaudo. Confronto fra prima (main 29f78c94) e dopo (d59e2d44), sul fiume lento da solo (`scenes/risalita/fiume.tscn`), con le luci del blackout, l'ambiente e l'esposizione della sala e il preset alto, come gli scatti di mascotte. Nel gioco non ho cambiato niente.

**Esito: non superato.**
- La riga è sparita quasi ovunque, ma al bivio nord ne resta un pezzo che si vede.
- C'è anche un buco verso il cielo all'estremità est, che c'era già prima.
- Collisioni, test e posizionamento sono a posto.

## 1. La riga chiara: sparita quasi ovunque, ma al bivio nord ne resta un pezzo
Ho fatto 221 scatti per versione:
- tutti i 7 tratti, ogni 8 m;
- in piedi (1,65 m) e accovacciato (0,97 m), avanti, a sinistra e a destra;
- dalla banchina ai due lati ogni 16 m;
- 3 viste lontane e 4 viste della ciambella.

Per vedere i buchi ho rifatto gli stessi scatti con lo sfondo magenta e con l'acqua nascosta, perché con l'acqua lo specchio riflette lo sfondo e confonde la misura (`dati/magenta_senza_acqua_*.txt`).

**I numeri.**
- Gli scatti con un buco passano da 100 a 60. Nessuno ha un buco nuovo o più grande.
- Dove c'era la riga lunga, i pixel scendono molto. Per esempio Giusto1 a 33 m accovacciato passa da 5 561 a 254 pixel, Giusto2 a 1 m da 12 447 a 292.

**Quello che resta: un pezzo corto della riga al bivio nord, ai due lati della conca.** (`fogli/riga_residui.jpg`, le prime quattro righe)
- **Dove:** al pelo dell'acqua intorno a x ±2,6…3,0, z 25,7…27,0 (`dati/residui.log`).
- **Da dove si vede:**
  - Giusto1 a 17, 25 e 33 m;
  - Giusto2 a 1 m;
  - dalla banchina a Giusto2 1 m e a Sbagliato2 1 m.
- **Quanto si vede:** nel gioco è una macchia chiara di cielo, luminanza 31-56 contro 1-6 intorno, su 255.
- **La geometria lì vicino** (`dati/mappa_bivio.txt`, griglia di 5 cm):
  - a x ≈ ±3,05, fra z 24,55 e 25,4, ci sono due lame di pavimento larghe 5-15 cm, con l'acqua dai due lati;
  - a (−3,40; 25,15) c'è un buchetto di 5 cm nel pavimento, da dove si vede il fondo.
- **Le pareti:** sono tutte rivolte bene (vedi il punto 2). Il pezzo che resta viene quindi da un'altra cosa: un tratto di bordo senza parete, o il fondo che lì non arriva (oltre z 28,6 il fondo non c'è).

## 2. Le pareti: giuste
- **La mesh** (`dati/pareti.txt`): su 2 338 triangoli delle pareti del canale, tutti hanno la faccia davanti verso l'acqua. Nessuno ha l'acqua dai due lati o da nessuno.
- **A schermo** (`fogli/sette_tratti_dopo.jpg`, `fogli/ciambella_pareti.jpg`): dall'acqua e dalla banchina le pareti non sono trasparenti, non sono nere e la luce non è rovesciata.
- **Vicino alla ciambella:** ora si vedono le piastrelle verde-acqua illuminate dalla ciambella; prima lì era nero.

## 3. Buchi verso il cielo o il nero
- **Bivio nord:** è il pezzo di riga del punto 1.
- **Estremità est: c'era già prima, uguale** (`fogli/buco_est.jpg`; `fogli/riga_residui.jpg`, le ultime tre righe).
  - **Dove:** al pelo dell'acqua intorno a x 26,3…27,0, z −3…+3.
  - **Che cosa si vede:** una striscia di cielo a filo d'acqua, larga e lunga. Guardando verso il fondo, i raggi escono oltre x 28,6, dove il fondo finisce.
  - **Da dove si vede:**
    - dall'Imbarco fra 33 e 49 m;
    - da Giusto1 a 1 m;
    - da Sbagliato1, 2 e 3;
    - dalla banchina a Sbagliato1 1 m.
  - **Prima e dopo:** i pixel sono gli stessi (per esempio Imbarco 49 m: 1 796 → 1 744), quindi la correzione non lo cambia.
- **Altro, che va bene così:**
  - la porta di servizio all'approdo (Uscita 9 m) apre su una stanza che nella scena del solo fiume non c'è: nel gioco va bene;
  - nella vista dall'alto «lontano_nord» si vede il cielo sopra il muro nord;
  - all'Imbarco a 1 m c'è un buchetto di 7-13 pixel a x 3,6, z −2,04, a 1 m d'altezza. C'era già prima, uguale.

## 4. Collisioni: come prima per chi cammina; cambiano solo i raggi sott'acqua
- **Il confronto dei raggi** (`dati/confronto_raggi.txt`): 324 096 raggi da 6 752 punti, dalla ciambella ogni metro e dalla banchina su una griglia di 1 m, in 16 direzioni per 3 inclinazioni. 1 137 sono diversi:
  - 1 132 raggi in giù verso l'acqua ora si fermano sulle pareti sommerse (sotto quota 0) invece di attraversarle fino al fondo. Così il getto ora colpisce le pareti del canale sott'acqua;
  - 5 raggi vanno più lontano. Tutti stanno al bivio nord (x ±3,1, z 24,3-25), vicino alle lame del punto 1.
- **Le barriere** lungo il bordo dell'acqua non cambiano.
- **I test:** test_fiume passa 35 controlli su 35 e test_fiume_gioco 34 su 34. Coprono la strada a piedi fino all'imbarco, il canale dove non si cade, il tasto E per salire sulla ciambella, la corsa, i bivi e l'approdo.

## 5. Posizionamento
`controllo_posizionamento`: **0 da correggere.** Gli ERROR nel log (102 sulle blend shape e 16 su forme Jolt vuote) c'erano uguali nei giri precedenti (`dati/test.txt`).

## Strumenti
In `godot/tests/collaudo/`:
- `fiume_giro.gd`: gli scatti. Con `MAGENTA=1` usa lo sfondo magenta e conta i pixel; con `NASCONDI_ACQUA=1` nasconde l'acqua.
- `fiume_raggi.gd`: i raggi delle collisioni. Il confronto lo fa `confronta_raggi.py`, qui accanto.
- `sonda_pareti_fiume.gd`: il verso di ogni triangolo delle pareti.
- `sonda_punto_fiume.gd`: la mappa ogni 5 cm al bivio.
- `sonda_residui_fiume.gd`: dove stanno nel mondo i pixel magenta rimasti.
