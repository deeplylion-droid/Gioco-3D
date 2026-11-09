# Ricontrollo del guanto per la 0.3.23 (enigmi, 8 novembre)

> **Nota del 9 novembre.** Qui alcune misure dell'indice e del mignolo erano prese a quote sbagliate (indice a y -0,196
> invece di -0,202). Sono rifatte alle quote vere in `terzo_5325f596/LEGGIMI.md`, sezione «Correzioni»: il «bordo alto a
> 2-3,6 mm» era un errore dello strumento, la base era a 4,3-13,3 mm, il mignolo a 2,15 mm.

- Base `lavoro/guanto` `98ded0d2` di ambienti-1, già unito con main `e3104cd2`.
- Lo stesso giro del collaudo della 0.3.22 (`lavoro/collaudo-0322-guanto` `d567a73d`), con lo stesso strumento.
- Per confronto, il modello di prima (`efed85b1`) nelle stesse viste.
- Cosa è cambiato:
  - il guanto usa una copia del materiale della canna, con texture uniformi che rifanno il suo colore e la sua
    ruvidezza (`lance_rig.gd`, `mani_col_materiale_del_modello`);
  - la punta dell'indice è stata rifatta;
  - lo spiraglio fra anulare e mignolo è chiuso.
- Strumenti:
  - `godot/tests/collaudo/collaudo_guanto.gd`, con due modi in più:
    - `punti`: ingrandimenti mirati a 11 cm, campo visivo 40°;
    - `aspetto`: materiale di prima e nuovo nella stessa luce;
  - `godot/tests/collaudo/sonda_guanto_pipeline.gd`: le compilazioni di ogni tipo quando il guanto entra in vista;
  - in `strumenti/` le misure sul modello: `misura_dita.py`, `misura_indice.py`, `misura_guanto.py`, `bordi_np.py`,
    `pieghe_np.py`, `raggio_np.py`.

## Esito

**Dagli occhi del giocatore e nel gioco: superato.**
- Il materiale nuovo non cambia l'aspetto approvato.
- Il guanto non compila più niente quando entra in vista, nemmeno nella luce di lei.
- Lo spiraglio fra anulare e mignolo è chiuso.

**Da vicino restano due cose sul modello dell'indice**, che dagli occhi non si vedono:
- la conchetta sulla punta, più piccola dello strappo di prima ma con uno spigolo vivo;
- l'indice un po' staccato dall'impugnatura (2-9 mm, prima 0,4 mm), senza buchi visibili.

Le decide il coordinatore con ambienti-1.

### 1. Gli stessi punti della 0.3.22

- **Spiraglio fra anulare e mignolo: chiuso** (foglio `2b`, ultima riga). Da destra non si vede più l'arancione
  dell'impugnatura.
- **Strappo sulla punta dell'indice:**
  - **più piccolo, ma da vicino si vede ancora** (fogli `2b` e `2c`). Resta una conchetta di circa 6 x 3 mm con uno
    spigolo vivo, sia con la luce della camera sia con le luci del livello;
  - dove: glTF circa (-0,026, -0,196, 0,433), un paio di cm verso il pollice rispetto allo strappo di prima;
  - lì 15 spigoli sono piegati fino a 163-165° (`pieghe_np.py`), non 37°;
  - **dagli occhi non si vede**:
    - sotto i 70° il guanto non entra nello schermo;
    - a 90°, ingrandendo quasi 4 volte, la punta dell'indice è bianco uniforme (foglio `1`).
- **Niente grigio.** Nella lancia si vedono solo:
  - la canna con la sua texture;
  - il tubo arancione;
  - il guanto, bianco 0,933, col materiale «Material_0» copiato dalla canna;
  - l'indicatore.

  I segnaposto grigi sono nascosti.
- **I 17 stati, a 16:9:**
  - a 50° e a 62° il guanto non entra mai nello schermo;
  - a 90° entra in tutti, fino al 16% dell'altezza (prima 16,9%).
- **Soglia:** in tutti e quattro i formati il guanto entra da 70° in su, come prima. A 70° entra un po' meno: 250
  vertici invece di 760.
- **Le scene** (morte, ripartenza, presa di lei):
  - a 62° il guanto non entra mai nello schermo;
  - a 90° resta sull'impugnatura (foglio `4`).
- **Il guanto segue la lancia** in tutte le pose: al più 0,0001 mm.
- **Dita dentro il fucile:** 24 vertici, al più **0,47 mm** (prima 6 vertici, 0,47 mm). Non si vedono.
- **Distacchi dita-impugnatura (`misura_dita.py` e `misura_indice.py`):**
  - medio, anulare e mignolo come prima (al più 1,15 mm);
  - **l'indice si è staccato dall'impugnatura:**
    - prima stava a circa 0,4 mm tutto intorno;
    - ora, alla base sul lato destro, vicino al palmo, glTF circa (0,031-0,034, -0,196, 0,50), è a **5-9 mm**;
    - sul bordo alto, davanti e a sinistra, glTF y -0,194, è a **2-3,6 mm**.
  - Non si vede:
    - negli ingrandimenti nelle stesse viste di prima (foglio `2b`) non c'è nessun buco;
    - ricostruendo la vista coi raggi da quella parte (`raggio_np.py`), l'impugnatura si vede solo fuori dalla sagoma,
      sopra il bordo del dito, e mai attraverso il guanto.

    Le dita sono tubi tondi: il contatto sta sotto, e il punto da 48,7 mm è un raggio che passa sopra il dito.

### 2. L'aspetto col materiale nuovo (fogli `3a` e `3b`)

- **Il materiale:**

  | | Bianco | Ruvidezza | Metallo |
  |---|---|---|---|
  | Prima | 0,936 | 0,62 | 0 |
  | Nuovo | 0,933 | 0,6196 | 0 |

  La differenza viene dagli 8 bit delle texture uniformi. Le cuciture hanno il loro colore scuro.
- **Stesso modello e stessa luce, materiale di prima e nuovo**, da vicino (destra, sinistra, dietro):
  - con le luci del livello: differenza media 0,5-0,7 su 255;
  - con in più la luce rosa di lei (LeiOblo.ROSA, energia 4, a 1,2 m): 0,6-1,0 su 255;
  - colore medio del guanto uguale entro 1, cuciture comprese.
- **Dagli occhi a 90°:** con la luce rosa la differenza media è 1,3 su 255. Con le luci del livello è 3,1, ma lì la
  lancia ha oscillato un po' fra i due scatti.
- **Con gli scatti approvati** dall'utente (A/A/A, pagina «Il guanto sul fucile», `docs/proposte/guanto/dopo/`):
  - rifatti oggi con lo stesso strumento di allora (`scatti_guanto.gd`, 16 pose);
  - il bianco del guanto è lo stesso entro 1-2 su 255 per canale, in ogni posa;
  - stesse cuciture scure, stesso polsino;
  - le caselle dello sparo cambiano di più per gli spruzzi d'acqua, che sono casuali.

### 3. Niente scatti la prima volta, nel gioco vero

`sonda_guanto_pipeline.gd` riproduce il gioco in quest'ordine:
1. il riscaldamento degli shader dell'avvio (RiscaldamentoShader, 250-270 s);
2. poi uno di questi due casi:
   - il tunnel costruito come nel gioco, col suo riscaldamento, e il giocatore vero sulla banchina a s 133;
   - un oblò con lei (ObloLei), col giocatore vero davanti;
3. la lancia in vista, poi lei che compare con la sua luce rosa (solo all'oblò);
4. lo sguardo da 0° a -89° e ritorno, a 62° e poi a 90°.

Conta le compilazioni di ogni tipo (canvas, mesh, surface, draw, specialization) fotogramma per fotogramma.

| Caso | Guanto | Primo fotogramma col giocatore | Lei compare | In basso a 62° | In basso a 90° |
|---|---|---|---|---|---|
| Tunnel | nuovo | surface 4, draw 1, spec. 1 | - | **nessuna** | draw 2, spec. 2 a -18° |
| Tunnel | di prima | surface 4, draw **3**, spec. **3** | - | nessuna | draw 2, spec. 2 a -18° |
| Oblò | nuovo | surface 4, draw 2, spec. 2 | **nessuna** | **nessuna** (il guanto entra nella vista a -9°, nella luce di lei) | draw 2, spec. 2 a -59° |
| Oblò | di prima | surface 4, draw 2, spec. 2 | nessuna | **draw 2, spec. 2 a -9°**, quando il guanto entra nella vista | draw 2, spec. 2 a -59° |

- **Il guanto non compila più niente.**
  - Col materiale di prima, quando il guanto entra nella vista all'oblò, nella luce di lei, si compilano 2 draw e 2
    specialization: è il difetto che ha trovato ambienti-1. Col materiale nuovo, nello stesso fotogramma, nessuna.
  - Nel tunnel, col materiale di prima, il guanto aggiunge 2 draw e 2 specialization al primo fotogramma; col nuovo
    no.
  - Canvas e mesh: nessuna, in nessun caso.
- **Quando il guanto entra nella vista.** La sua scatola entra nella vista prima che un suo pixel arrivi nello schermo:
  - nel tunnel è già nella vista guardando dritto;
  - all'oblò ci entra a -9°;
  - nello schermo il guanto arriva solo da 70° di campo visivo in su.

  È lì che col materiale di prima si compilava.
- **Il primo fotogramma col giocatore** (surface 4, draw 1-2, specialization 1-2) è il giocatore che entra nella scena
  della prova. Nel gioco vero il giocatore c'è da prima.
- **Osservazione, non del guanto:** a 90°, guardando in basso, si compilano 2 draw e 2 specialization (-18° nel tunnel,
  -59° all'oblò), uguali col materiale di prima e col nuovo.
  - Col solo guanto nascosto restano; con tutta la lancia in mano nascosta spariscono.
  - È quindi un altro pezzo della lancia, che a 62° non entra mai nella vista.
  - Succede solo a chi alza il campo visivo nelle opzioni.

## Fogli

- `1_occhi_90.jpg`: dagli occhi a 90° (fermo, tutto in su) e il guanto ingrandito: la punta dell'indice non mostra la
  conchetta.
- `2a_vicino_fermo.jpg`: da vicino, gli stessi sette lati della 0.3.22.
- `2b_ingrandimenti_prima_dopo.jpg`: gli ingrandimenti mirati sul modello di prima e sul nuovo, nelle stesse viste:
  - la punta dell'indice;
  - la base e il bordo alto dell'indice;
  - lo spiraglio fra anulare e mignolo.
- `2c_conchetta_punta_indice.jpg`: la conchetta rimasta sulla punta dell'indice, con due luci, e com'era prima.
- `3a_aspetto_materiale_prima_nuovo.jpg`: stesso modello, materiale di prima e nuovo, con le luci del livello e con la
  luce rosa di lei.
- `3b_approvati_e_rifatti.jpg`: le 16 pose approvate e le stesse rifatte oggi.
- `4_scene_90.jpg`: morte, ripartenza e presa di lei a 90°.
- `misure_blender.txt`: le misure di Blender.
