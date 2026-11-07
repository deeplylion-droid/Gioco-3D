# Collaudo del guanto per la 0.3.22 (enigmi, 7 novembre)

- Base `lavoro/guanto` `efed85b1`, di ambienti-1.
- Scelte dell'utente, tutte A:
  - la lancia resta dov'è;
  - il guanto bianco sulla mano destra, chiuso sull'impugnatura sotto il bordo dello schermo;
  - il braccio sinistro grigio è tolto;
  - bianco pulito, dita tonde di circa 2,5 cm, polsino largo.
- Il guanto è `assets/models/zaino/guanto/guanto_destro.glb`, messo dalla `LanciaC1` (`right_hand_scene`) nelle
  coordinate glTF della lancia. La mano sinistra non c'è più.
- Strumenti:
  - `godot/tests/collaudo/collaudo_guanto.gd`: il livello di prova col giocatore vero, la lancia in mano e il guanto. Fa
    il giro dagli occhi, la soglia del campo visivo, le viste da vicino e le scene;
  - in `strumenti/` le misure sul modello, fuori dal motore: `misura_dita.py`, `misura_guanto.py` e `bordi_guanto.py`
    in Blender, `bordi_np.py`, `pieghe_np.py` e `raggio_np.py` con numpy, e `fogli_guanto.py`, che compone i fogli.

## Esito: non superato per due difetti piccoli del modello, che si vedono solo da vicino

Il resto passa:
- niente grigio da nessuna parte;
- il guanto segue la lancia in tutte le pose;
- quando entra nello schermo sta bene.

### Difetti (al coordinatore, con lo scatto e il punto)

1. **Strappo sulla punta dell'indice** (foglio `2d_strappo_punta_indice.jpg`).
   - Una piega della superficie di circa 5 mm, con i bordi in ombra: sembra un taglietto. È sulla punta dell'indice,
     dalla parte sinistra e davanti all'impugnatura.
   - Punto glTF circa (-0,044, -0,197, 0,424), fra (-0,042, -0,194, 0,422) e (-0,045, -0,199, 0,426).
   - Lì 19 spigoli sono piegati fino a 116° (`pieghe_np.py`).
   - Si vede negli scatti `vicino_fermo_davanti` e `vicino_fermo_sinistra`.
   - Dagli occhi non si vede: sotto i 70° il guanto non entra nello schermo, e a 90° la punta dell'indice è 1-2 pixel.
2. **Spiraglio fra anulare e mignolo** (foglio `2c_spiraglio_fra_le_dita.jpg`).
   - Sul lato destro dell'impugnatura, vicino alle nocche, le due dita non si toccano. Nel buco, di circa 7 x 2 mm, si
     vede l'arancione dell'impugnatura.
   - Attraverso il buco si vede l'impugnatura in glTF circa (0,031-0,037, -0,262, 0,458-0,468), fra l'anulare
     (y -0,247) e il mignolo (y -0,2725).
   - C'è anche nel modello, non solo nell'immagine: ricostruendo la vista coi raggi sui triangoli (`raggio_np.py`) lo
     spiraglio viene uguale.
   - Si vede negli scatti `vicino_fermo_destra` e `vicino_carica_destra`.
   - Dagli occhi non si vede: quel lato guarda in fuori a destra.

### 1. Dagli occhi del giocatore (fogli `1a`, `1b`, `1c`)

- **Niente grigio.** Nella lancia sono visibili solo:
  - la lancia con la sua texture;
  - il tubo arancione;
  - il guanto, bianco 0,936;
  - l'indicatore del serbatoio: plastica trasparente, acqua (materiale a shader), tappi arancioni.

  I tre segnaposto grigi (Lancia, Impugnatura, Valvola) sono nascosti, e la mano sinistra non c'è.
- **Stati** (17): fermo, camminando, correndo, carica, sparo, aspirando, accovacciato, accovacciato camminando, salto con
  atterraggio, tutto in su, tutto in giù, contro un muro, scale, scaletta, in acqua, guado e raccolta dello zaino.
  - Per ogni fotogramma si proietta sullo schermo un vertice per ogni faccia del guanto: 19260 punti.
- **Campo visivo e formati.** La camera tiene l'altezza, quindi il campo visivo verticale è lo stesso in ogni formato:
  il guanto entra solo dal basso.

  | Formato | 50° | 62° (normale) | 90° |
  |---|---|---|---|
  | 16:9 | mai | mai | in tutti i 17 stati, fino al 16,9% dell'altezza (carica) |
  | 16:10 | - | mai | in tutti i 17, fino al 16,7% (carica) |
  | 21:9 | - | mai | in tutti i 17, fino al 16,7% (carica) |
  | 4:3 | - | mai | in tutti i 17, fino al 16,7% (carica) |

  - **Soglia:** da fermo, in tutti e quattro i formati, il guanto entra da 70° in su.
- **Quando entra, sta bene** (foglio `1b`, ingrandito):
  - le dita sono chiuse sull'impugnatura, il pollice sopra;
  - niente spazi e niente compenetrazioni visibili;
  - nessun pezzo staccato.
- Contro un muro la lancia si ritira: a 90° il guanto arriva solo al 5,3% dell'altezza.

### 2. Da vicino, fuori dalla camera del giocatore (fogli `2a`-`2d`)

- **Viste:** camera a 28 cm dal centro del guanto, da otto lati:
  - destra, sinistra, davanti, dietro, sotto e sopra;
  - dietro e sotto il polsino, dietro e a destra del polsino.

  La vista da sopra finisce dentro il fucile, perché sopra la mano c'è il corpo della lancia: non è nel foglio.
- **Nessun dito dentro il fucile.**
  - 6 vertici su 9755 sono appena dentro, al più 0,47 mm (`misura_guanto.py`). Non si vedono.
- **Distacchi dita-impugnatura** (`misura_dita.py`):
  - raggi dalla superficie dell'impugnatura verso il guanto, ogni 3° lungo ogni dito, al centro del dito e a ±2 mm:
    780 punti;
  - **al più 1,49 mm**, sul dito 3 (mignolo; i diti vanno da 0, l'indice, a 3), a -2 mm e a 137°;
  - 9 punti sopra 0,8 mm, 4 sopra 1 mm, nessuno sopra 2 mm;
  - al centro del dito: 0,81 mm sull'indice, 0,56 sul medio, 0,73 sull'anulare e 1,18 sul mignolo.

  Ambienti-1 dichiarava al più 0,8 mm: è un po' di più, ma resta sotto la soglia di 1-2 cm della regola.
  - Sul palmo le distanze fino a 11 mm sono i solchi naturali fra le dita tonde. Quelle fino a 49 mm, fra -25° e -40°,
    sono raggi che escono di lato oltre il bordo del palmo. Non si vede spazio vuoto, salvo lo spiraglio del difetto 2.
- **Polsino non vuoto.** Da dietro e da sotto si vede l'anello del polsino con dentro la cupola bianca.
  - Il modello è chiuso: unendo i vertici nella stessa posizione non resta nessun bordo aperto e nessuno spigolo con più
    di due facce (`bordi_np.py`). I "bordi aperti" che vede Blender sono solo le cuciture dei materiali e delle UV.
  - È fatto di cinque pezzi chiusi, appoggiati al corpo del guanto: il corpo, l'anello del polsino e le tre cuciture sul
    dorso. Negli scatti da vicino non c'è spazio fra i pezzi.
- **Le pose:**
  - carica, sparo, aspirando, correndo e accovacciato, fotogramma per fotogramma;
  - il guanto rispetto alla lancia si sposta **al più di 0,0001 mm**: segue la lancia;
  - negli scatti da destra e da sotto (foglio `2b`) la presa è la stessa in ogni posa.

### 3. Le scene (fogli `3` e `3b`)

- Morte (la camera che cade), ripartenza, presa di lei (la camera tirata verso il suo viso) e raccolta dello zaino.
- Prima col campo normale (62°), poi a 90°, dove il guanto si vede.
- **A 62°:** il guanto non entra mai nello schermo, né nella morte, né nella ripartenza, né nella presa.
- **A 90°:**
  - il guanto si vede in tutte e tre, fino al 16,2% dell'altezza;
  - resta chiuso sull'impugnatura mentre la camera cade e mentre è tirata verso di lei: segue la lancia, nessun pezzo
    staccato.
- **Niente grigio**, in nessuna scena.
- **Ripartenza:** il giocatore nuovo ha la lancia in mano col guanto.
- **Raccolta:** la lancia sale dal basso col guanto già sull'impugnatura.
- Alla fine della presa, quando il giocatore viene tolto, il mio strumento dava un errore per un fotogramma: cercava la
  camera che non c'era più. È corretto in `collaudo_guanto.gd`. Il gioco non c'entra.

## Fogli

- `1a_occhi_16x9_fov62.jpg`: i 17 stati dagli occhi, 16:9 a 62°: il guanto non si vede mai.
- `1b_campo_visivo_90.jpg`: a 90°, fermo e sparo, e il guanto ingrandito (fermo e tutto in su).
- `1c_formati_90.jpg`: i quattro formati a 90°, fermo e carica.
- `2a_vicino_fermo.jpg`: da vicino, sette lati e le punte delle dita ingrandite.
- `2b_vicino_pose.jpg`: da vicino nelle pose (carica, sparo, aspirando, correndo, accovacciato), da destra e da sotto.
- `2c_spiraglio_fra_le_dita.jpg`: il difetto 2.
- `2d_strappo_punta_indice.jpg`: il difetto 1.
- `3_scene_campo_62.jpg` e `3b_scene_campo_90.jpg`: morte, ripartenza, presa di lei e raccolta.
- `misure_blender.txt`: le misure di Blender.
