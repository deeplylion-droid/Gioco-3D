# Ricontrollo di bambini e squalo per la 0.3.17 (30 ottobre)

Ricontrollo del branch di mascotte `lavoro/bambini-squalo-0317` (598f11f2), fatto da enigmi su richiesta del coordinatore.
Gli scatti sono tutti dal motore. Gli strumenti sono in `godot/tests/collaudo/` su `lavoro/collaudo-bambini-squalo-0317`.

**Esito:** agnellino del tunnel e agnellino di C2 superati. Squalo: **un difetto**, la mano destra entra nel muso durante il giro. CI di 598f11f2 verde, con 0 casi da correggere nel controllo di posizionamento e nessun `ERROR: BUG,`.

## 1. Agnellino del tunnel: superato

Strumento: `collaudo_agnellino_tunnel.gd`. Il giocatore lo insegue, la camera vera lo guarda sempre e gira al massimo a 300° al secondo. Gli occhi del giocatore, quelli con cui il bambino decide se è visto, stanno alla stessa altezza della camera, anche da accucciati.

Nel fotogramma in cui sparisce, il disegno si rifà due volte, con lui nella stessa posa e senza: i pixel che cambiano sono quello che si vedrebbe sparire. In tutti i casi i pixel cambiano quanto il rumore (acqua e nebbia si muovono anche a camera ferma), e dove stava lui non resta nessuna forma: non si vede sparire, nemmeno in parte. Foglio: `1_tunnel_riassunto.jpg`; l'inseguimento intero del caso "meta" è in `1_tunnel_meta_galleria.jpg`.

| Caso | Sparisce | Pixel diversi (≥6/255) / rumore |
|---|---|---|
| bocca: sprint fino alla bocca, fermo a guardare dentro (quello di mascotte) | fotogramma 284, nella bocca d'uscita, coperto dal muro | 281 / 148 |
| indietro: dentro accucciato, a un terzo si volta, torna e riguarda dentro | 284, dietro le spalle | 25 / 10 |
| meta: accucciato a 1,7 m/s, fermo 3 s a metà galleria, poi riparte | 284, dietro il muro in fondo alla galleria | 291 / 146 (dove stava, solo puntini sparsi, nessuna forma) |
| lontano: lo guarda da 18 m prima della bocca, poi va alla bocca | 313, a 32 m, fuori vista | 52 / 30 |
| via: sprint anche accucciato fin fuori, poi si gira | 371, fuori dall'inquadratura | 27 / 13 |

Due cose sui test di mascotte (`test_bambini_sfuggita`, `video_bambini_sfuggita.gd`). Non sono difetti del gioco:

- Nella galleria fanno correre il giocatore a 5,8 m/s. Nel gioco, accucciati, si va al massimo a 1,7 m/s (`Player._max_speed`). L'agnellino va a circa 2,5 m/s, quindi nel gioco non si raggiunge. A 5,8 m/s invece il giocatore lo raggiunge e gli passa attraverso: è il caso "via", foglio `1_tunnel_via_sorpasso.jpg`, fotogrammi 192-204.
- La camera è a 0,95 m, ma `get_eye_position()` resta a 1,6 m, perché il giocatore è fermo. Quindi il bambino decide se è visto da un punto più alto della camera. Con gli occhi giusti il risultato è lo stesso (caso bocca: sparisce allo stesso punto, s 217,9, a 10 m).

## 2. Agnellino della scala di C2: superato

Strumento: `girata_agnellino_c2.gd`. Il confronto è fra la 0.3.15 (503b5d45, con il suo `bambino.gd`, `agnellino_scala.gd` e `bambino_agnello.tscn`) e il branch. Foglio: `2_girata_c2_015_branch.jpg`.

La girata è uguale: parte allo stesso fotogramma, gira di 18° per fotogramma e fa 177° in 0,33 s. L'unica differenza è che ora prende velocità in un quarto di secondo: a 0,4 s è a 0,87 m invece che a 1,2 m, poi va alla stessa velocità.

## 3. Squalo all'inizio: un difetto

### Difetto: la mano destra entra nel muso

Nel giro il braccio alzato non resta accanto al muso. La mano destra ci passa sopra e dentro due volte, a 9,1-9,27 s e a 9,67-9,77 s, e gli artigli escono dalla bocca. Il polso arriva a 5,8 cm dall'osso della bocca (a 9,20 s) e a 2,4 cm (a 9,73 s). Nella 0.3.16 restava ad almeno 26 cm. Lo spazio fra braccio e testa della scelta A quindi non c'è.

- Foglio `3_squalo_mano_bocca.jpg`: il modello vero nel motore, a 1,1 m dalla bocca, prima e dopo.
- Dalla camera del giocatore si vede a 9,07-9,17 s: il braccio passa sul muso. Fogli `3_squalo_giro_giocatore.jpg` e `3_squalo_giro_giocatore_vicino.jpg`.
- Causa probabile: in `mostro_anim.py` la mano destra nel giro va a `(-0.10, -0.46 - 0.12*dondolo, ...)`, ruotata di `ritardo_braccia`. Con il dondolo e il ritardo la mano passa davanti al muso.

### Il resto: superato

- **Muri.** Ho controllato ogni vertice della pelle vera a ogni fotogramma, con un raggio dal petto a ogni vertice. Nel corridoio, durante il giro e la corsa fino alla porta, niente entra nei muri.
- **Scatti.** Il salto di velocità delle mani più grande in un fotogramma è uguale a quello della 0.3.16, negli stessi istanti della corsa (10,23 s). Le braccia si muovono di più, come chiesto, senza scatti nuovi.
- **La pinna dell'avambraccio** non spunta più sotto il petto (fogli `3_squalo_viste_dopo.jpg` e `3_squalo_viste_prima.jpg`).

### Due compenetrazioni che c'erano già nella 0.3.16

Ossa e animazione del corpo sono identiche al millimetro, quindi non le ha introdotte questo branch:

- a 6,47-6,50 s, il fianco dietro, all'altezza x 16,3, entra di 3,8 cm per due fotogrammi in `corridoio_collisione`;
- a 11,33-11,50 s, oltre la porta, il davanti dello squalo entra fino a 1,3 m nel muro di fondo, mentre la porta si chiude (si chiude del tutto a 11,48 s, e lui sparisce a 11,52 s). Dalla camera del giocatore si vede appena, nella nebbia viola, dalla fessura della porta. Foglio `3_squalo_porta_muro.jpg`.

## 4. Secondo giro: lo squalo corretto da mascotte (ef383996)

Strumenti: gli stessi del primo giro (`collaudo_squalo_girata.gd`, `squalo_braccia_misure.gd`, `squalo_braccia_viste.gd`), più la vista "mento", a 0,7 m dalla punta del mento.

**Esito:** la mano, il muro di fondo e i 6,47 s sono corretti. Ci sono però due cose nuove: l'avambraccio e gli artigli vicino al muso, e la coda nella porta che si chiude.

### Corretto

- **La mano non entra più nel muso.** Il polso resta ad almeno 26 cm da bocca, mascella e mento (0,260 m a 9,27 s). Nella 0.3.16 erano 26 cm, nel primo giro 2,4.
- **Oltre la porta** non entra più nel muro di fondo: frena con la spina a x 23,09.
- **A 6,47 s** il fianco non entra più nel cartello.
- **Muri del corridoio:** ho controllato tutti i vertici della pelle a ogni fotogramma, e niente entra nei muri.
- **Test del tunnel:** ora va a 1,7 m/s da accucciato e ha gli occhi all'altezza della camera.

### Da guardare: avambraccio e artigli vicino al muso, a 9,6-9,67 s

- Il gomito del braccio alzato passa a 7,6 cm dall'osso del mento (9,60 s). Nella 0.3.16 restava ad almeno 27 cm.
- Gli artigli lunghi della mano attraversano la bocca aperta: foglio `4_squalo_ef38_mento.jpg`, viste "e" e "sotto_e" a 9,633 e 9,667 s.
- Dalla camera del giocatore, in quel momento lo squalo è di schiena, e non si vede.
- Si vede invece a 9,07-9,17 s (`4_squalo_ef38_giro_giocatore.jpg`): il braccio alzato passa davanti al muso nella sagoma, anche se in 3D resta a più di 26 cm. Lo spazio fra braccio e testa della scelta A, da lì, non si legge.

### Nuovo: la coda nella porta che si chiude, a 11,48-11,52 s

- Ora lo squalo si ferma subito dopo la porta, e la coda resta nel vano.
- Quando la porta finisce di chiudersi (11,48 s), la punta della coda sta 14-16 cm oltre la porta chiusa, dalla parte del giocatore: punto (21,85; 1,12; -1,86), con la porta a x 21,97.
- Questo vale per il fotogramma a 11,50 s: a 11,52 s lo squalo sparisce.
- Dalla camera del giocatore, nella nebbia viola a circa 10 m, non si distingue (`4_squalo_ef38_porta.jpg`), ma è una compenetrazione.
- Possibili correzioni: fermarlo 20-30 cm più avanti, raccogliere la coda in frenata, o farlo sparire quando la porta si chiude (porta + 0,58 invece di + 0,62).

## 5. Terzo giro: lo squalo su 37d772ca

**Esito:** coda e porta, gomito e artigli, e muri corretti. La scelta A dagli occhi del giocatore va giudicata. Un difetto nuovo, che il giocatore non vede: la mano sinistra trema alla porta.

### Corretto

- **Coda contro porta:** a ogni fotogramma, porta chiusa compresa, nessun vertice della pelle entra nei muri o nella porta (0,000 m in tutta la scena). Foglio `5_squalo_37d7_porta.jpg`.
- **Gomiti e polsi:** dal richiamo in poi restano ad almeno 30 cm da bocca, mascella e mento (0.3.16: 6 cm; secondo giro: 7,5 cm).
- **Artigli:** a 0,7 m dal mento, a 9,2-9,67 s, di lato si vede lo spazio fra artigli e mascella. Da sotto gli artigli si sovrappongono al mento solo in proiezione (`5_squalo_37d7_mento.jpg`).
- Nessun `ERROR: BUG,`.

### Scelta A dagli occhi del giocatore: da giudicare

Foglio `5_squalo_37d7_giro_giocatore.jpg`.

- A 8,77-8,87 s il braccio alzato sta accanto al muso, con lo spazio: si legge.
- A 9,07-9,27 s, col gomito "in guardia", nella sagoma il braccio passa davanti alla mascella. In 3D resta a più di 30 cm, ma da lì lo spazio non si vede.
- Da 9,47 s lo squalo è di schiena.

### Nuovo: la mano sinistra trema alla porta, a 10,6-10,8 s

- Nello spazio del petto, la velocità della mano sinistra salta da un fotogramma all'altro: 0,27, 1,69, 0,85, 1,52, 1,67, 0,65, 0,83 m/s. Nella 0.3.16 andava liscia, fra 0,2 e 0,6.
- Il salto più grande in un fotogramma è 3,06 m/s, il doppio del massimo della 0.3.16 (1,50).
- Probabile causa: la spinta che tiene le braccia lontane dal muso (al più 10 cm per fotogramma) si accende e si spegne.
- Dagli occhi del giocatore non si vede: lo squalo è di schiena nella luce e le mani sono coperte.
