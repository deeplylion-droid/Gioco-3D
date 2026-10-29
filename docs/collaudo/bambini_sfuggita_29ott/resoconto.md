# Collaudo dei bambini visti di sfuggita (29 ottobre, notte)

Squadra collaudo. `lavoro/bambini-sfuggita` **3e445450** (dentro c'è `lavoro/godot` con le Polaroid). Dopo è arrivato
d5545056, che cambia solo i campioni dei materiali del tunnel: non l'ho riprovato.

**Esito: due difetti nelle animazioni, il resto va.**
- I tre bambini compaiono fuori vista, guardano e scappano.
- Spariscono sempre coperti da un muro o fuori dall'inquadratura, mai davanti alla camera.
- Nessuna pipeline nuova quando compaiono, e 0 righe "ERROR: BUG," in tutti i log.
- Nel tunnel il bambino non disturba l'inseguimento e non si vede attraverso i muri.

I due difetti:
1. **Nella partenza della fuga, quando si volta sul posto, i piedi scivolano** (tutti e tre i punti).
2. **Nella scala C2, mentre si piega per il buco, i piedi entrano nel pavimento fino a 14 cm** (davanti al muro, in vista).

## Difetti

### D1. Voltandosi sul posto i piedi scivolano (bambino.gd, `_segui_punti`)

Quando deve voltarsi di più di 75 gradi per scappare, il corpo sta fermo (`voluta = 0`) e gira, mentre l'animazione
di corsa va al passo minimo (`_passo_animazione`, scala 0,25). Così il bambino corre sul posto e il piede a terra
scivola. È la stessa misura di `test_bambini_passi`: il piede più basso, entro 1,5 cm dal pavimento, che non sale e non
scende (sotto 0,1 m/s in verticale).

| Dove | Corpo | Piede a terra | Quanto dura |
|---|---|---|---|
| corridoio del fiume | 0,2-0,5 m/s | 0,8-0,95 m/s | ~0,1 s (6 fotogrammi), poi parte |
| galleria del tunnel | fermo (0,0 m/s) | 0,85-0,92 m/s | ~0,3 s (16 fotogrammi), poi altri 0,1 s sotto 0,5 m/s |
| scala C2 (`giro_corsa` 600) | fermo | 1,54-1,74 m/s | ~0,2 s (11 fotogrammi), poi 1,6-2,1 m/s mentre parte |

- **Nella corsa invece i piedi tengono:** 0,14-0,25 m/s a 1,9-2,4 m/s, dentro i 0,35 m/s di `test_bambini_passi`.
- **Da fermo (GUARDA):** 0,01 m/s, con i piedi a 0,5-0,7 cm dal pavimento.
- `test_bambini_passi` non lo vede: prova una strada con una curva a 60 gradi, non la voltata oltre i 75 gradi.

### D2. Scala C2: piegandosi per il buco i piedi passano sotto il pavimento (agnellino_scala.gd, `_piega`)

Nella striscia davanti al buco l'agnellino si piega fino a 75 gradi in avanti (perno ai piedi) e si alza di 12 cm,
ma l'animazione di corsa continua. Le gambe, ruotate con il corpo, scendono sotto il pavimento a ogni passo.

| z (mondo) | Sotto il piede | Il punto più basso dei piedi |
|---|---|---|
| 45,77 (corsia, prima della curva) | `c2_pav_alto_col` | da -4,7 a -6,7 cm |
| 46,0-46,6 (davanti al muro, in vista) | `c2_pav_alto_col` | fino a **-14,4 cm**, poi +14 cm (il passo dopo, in aria) |
| 46,77-47,07 (nel muro) | `c2_muro_s_sotto_buco_col` | fino a -10,2 cm |
| 47,2-47,9 (nella cavità) | `buco_pav_col` | fino a -14,5 cm |

- Sono le ossa dei piedi (LeftFoot, RightFoot, LeftToeBase, RightToeBase); il modello arriva circa 0,5 cm più sotto.
- Il giocatore che lo insegue gli arriva a 1,4 m (test_agnellino).
- `test_agnellino` passa (10 su 10): controlla che il corpo non attraversi muri, pavimento e roba, non i piedi.
- Si vede negli scatti ravvicinati da dietro, all'altezza dei piedi: nel 011 di
  `fogli/scala_c2_piega_nel_pavimento.jpg` la gamba entra nel pavimento davanti al buco, col riflesso sulla pozza.
  Tutta la corsa è in `fogli/scala_c2_piedi_ravvicinati.jpg`.

## I tre punti

### 1. Corridoio del fiume (risalita)

Ho giocato col giocatore vero in `tests/scene/risalita_prova.tscn`, col blackout, giù dalla scala del fiume:
1. guardo la scala;
2. guardo lei all'oblò finché non si stacca;
3. guardo di nuovo la scala;
4. poi il fondo del corridoio e cammino verso la porta.

- **Lei, poi il bambino** (la misura di lei nell'inquadratura è della ripetizione senza schermo). L'oblò passa da 1 (lei pronta) a 2 (vista), il giocatore guarda via, lei si stacca. Poi
  compare l'agnellino, in fondo e fuori vista, e l'oblò è già finito (4). Lei e l'agnellino non sono mai nell'inquadratura insieme.
- **P13:** sta a 7,6 m dal bambino (dalla scatola del bambino a quella della Polaroid). Non la copre e non la tocca.
- **Piedi:** fermo, a 0,5-0,7 cm dal pavimento (`fogli/corridoio_piedi.jpg`). Nella corsa vanno da -0,6 a +6,4 cm.
- **Contatti:** nessuno con muri, porte e roba, né fermo né correndo.
- **Sparisce** dietro lo stipite della porta del capannone: era nell'inquadratura ma coperto dal muro `Corridoi`.
- **Pipeline:** 0 quando compare.
- **Il resto:** dopo 2,6 s che lo guardo scappa, come da proposta. D1 qui dura poco.

### 2. Galleria del tunnel

Ho fatto la partita vera del tunnel (`partita_tunnel.gd`), con lei che insegue, fino a 240 m.

- **Compare** a s 170 m, con il bambino a circa 32 m, sulla banchina sinistra.
- **Scappa** a s 184 m. A s 186-190 m entra nella bocca della galleria (circa 198 m) e sparisce coperto dal muro.
- **Lei:** fra 17,5 e 17,9 m dietro per tutto il tempo che il bambino si vede. Nessuna presa.
- **Morsi e respinte:** l'unico morso è a s 136, prima della zona del bambino. Le respinte sono 3.
- **Attraverso i muri:** nelle viste della partita da 160 a 200 m il bambino non si vede attraverso il muro della
  galleria, né entrando né dopo (`fogli/tunnel_viste_partita.jpg`).
- **Piedi:** fermo, a 0,5-0,7 cm. Nella corsa da -0,6 a +5,9 cm. Nessun contatto. Pipeline 0 quando compare.
- **Al caricamento** il bambino si accende fuori vista per il riscaldamento (291 pipeline in quel fotogramma, con
  tutta la scena), poi si spegne.

Da guardare (scelta dell'utente, non un difetto):
- **Si vede comparire.** Fra la vista a s 168,4 (non c'è) e quella a s 171,3 (c'è) si accende nell'inquadratura,
  a circa 32 m (`fogli/tunnel_comparsa_ingrandita.jpg`). La proposta dice "lontano, oltre i 26 m, nel buio del
  tunnel", ma lì la banchina è illuminata dalle lampade e l'agnellino rosa si nota.
- **Nella galleria c'è l'agnellino** (`BAMBINO_AGNELLO`), come nel corridoio. Il bambino col cubo non compare in
  nessuno dei due punti nuovi. Il GDD (sera del 25 ottobre) parla di "il bambino col cubo e l'agnellino lontani".

### 3. Agnellino della scala C2

- **test_agnellino:** 10 su 10, 0 BUG, sia senza schermo sia col renderer vero.
  - Col renderer vero due volte: nella sala ridotta (640x360) e nella scena di prova della tappa 7 (960x540). Nella
    sala ridotta a 960x540 Godot è stato ucciso per la memoria.
  - Corre a 3,0 m/s con l'animazione a tempo (velocità 1,58).
  - Scappa sotto i 9 m e si infila nel buco: il più vicino che il giocatore gli arriva è 1,4 m.
  - Sparisce in fondo alla cavità, fuori dall'inquadratura.
- **Contatti:** nessuno, né col bordo del buco né con la roba. La scatola è di 38 cm, dai piedi alla testa: le mesh
  dei bambini danno una scatola piatta.
- **Pipeline:** 0 quando compare.
- **Piedi:** D1 e D2.

## Come

Sonde in `godot/tests/collaudo/`, renderer vero llvmpipe e lock, una alla volta:
- **`monitor_bambini.gd`**, il nodo che misura a ogni fotogramma ogni Bambino visibile:
  - i piedi (altezza sul pavimento col raggio della fisica, su cosa poggiano, quanto scivola il piede piantato);
  - i contatti (una scatola contro la fisica);
  - la distanza dalla P13;
  - lei all'oblò nell'inquadratura;
  - come sparisce (fuori dall'inquadratura, coperto, o davanti);
  - le pipeline;
  - gli scatti dagli occhi e ravvicinati dei piedi.
- `sonda_bambini_corridoio.gd`, `sonda_bambini_tunnel.gd`, `sonda_bambini_scala.gd`, `agnellino_vulkan.gd` (copia di
  test_agnellino nella sala ridotta), `agnellino_vulkan2.gd` (nella scena di prova della tappa 7).
- I dati: `dati/*.csv` e `dati/*_eventi.txt`.

Test del branch, tutti verdi e senza "ERROR: BUG,": test_bambini_sfuggita 39/39, test_bambini_passi 8/8,
test_agnellino 10/10, test_bambini 49/49.

## Non verificato

- d5545056, cioè i campioni dei materiali del tunnel.
- La sala intera col renderer vero: non entra in memoria.
- Le prestazioni sulla GPU vera.
- Il caso in cui il giocatore passa nel corridoio senza vedere lei: secondo la proposta il bambino aspetta. Il
  test del branch lo copre, io no.
