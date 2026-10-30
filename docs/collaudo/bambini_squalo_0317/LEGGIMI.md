# Riscontri della 0.3.16: agnellini e squalo (30 ottobre)

Branch `lavoro/bambini-squalo-0317`.

1. **Agnellino del tunnel** (BambinoGalleria).
   - Prima spariva a metà della galleria di servizio, che è dritta e illuminata: chi gli correva dietro e ci entrava vedeva che non c'era più.
   - Ora corre per tutta la galleria ed esce dalla bocca in fondo. Sparisce solo dopo, dietro la testa della bocca, fuori dall'inquadratura e coperto dal muro.
   - Se lo si guarda sempre, corre via sulla banchina dopo il crollo e lì resta finché non lo si perde di vista (come gli altri bambini).
   - Fogli dal motore, dagli occhi di chi gli corre dietro allo sprint e si ferma alla bocca a guardare dentro:
     - `1_tunnel_corsa_in_galleria.jpg`: un fotogramma ogni 10;
     - `1_tunnel_sparisce_fotogrammi.jpg`: tutti i fotogrammi intorno a quando sparisce, al 283. Gira dietro lo spigolo al 277-278.
   - Test in CI: `test_bambini_sfuggita`, due inseguimenti.
2. **Agnellino della scala di C2** (AgnellinoScala). Torna la girata della 0.3.15: si volta di scatto mentre parte di corsa.
   - Foglio `2_agnellino_c2_girata_prima_dopo.jpg`, fotogrammi ogni 0,1 s da quando scappa. La 0.3.16 a 1,1 s si girava ancora sul posto; ora a 0,6 s corre già via.
3. **Squalo all'inizio**, la girata verso la porta.
   - Prima le braccia si raccoglievano in un nodo fermo davanti al petto e la pinna dell'avambraccio spuntava sotto.
   - Ora il braccio alzato resta accanto al muso, con lo spazio fra braccio e testa della scelta A. L'altro pende piegato. Dondolano a ogni passo e restano un po' indietro rispetto al corpo che gira.
   - Vicino al muro nord la mano si ritira: `test_interni` controlla i polsi, che arrivano a 18 cm dal muro.
   - Render del modello vero (Blender, Cycles), da sopra e dagli occhi del giocatore: `3_squalo_girata_prima_dopo.jpg`. Di lato: `3_squalo_girata_lato_prima.jpg` e `3_squalo_girata_lato_dopo.jpg`.

## Correzioni dopo il ricontrollo di enigmi (30 ottobre pomeriggio)

Il ricontrollo è sul branch `lavoro/collaudo-bambini-squalo-0317`, in `docs/collaudo/bambini_squalo_0317_ricontrollo/`.

- **La mano destra entrava nel muso nel giro.** Nel giro la testa resta sul giocatore e gira verso il braccio alzato.
  - Ora, dal richiamo in poi, il polso resta lontano dalla bocca e dal muso: `MANO_MUSO` in `mostro_anim.py`, applicato in `mostro_rig.cuoci`. Il braccio alzato dondola solo indietro.
  - `test_interni` controlla ogni fotogramma: nessun polso a meno di 26 cm dall'osso della bocca. Era il minimo della 0.3.16.
  - Foglio: `4_squalo_girata_dopo_ricontrollo.jpg`. In alto la 0.3.16, sotto la versione corretta, da sopra e dagli occhi.
- **Oltre la porta il muso entrava 1,3 m nel muro di fondo** (c'era già nella 0.3.16). Dietro la porta c'è un vano chiuso profondo 3 m.
  - Ora, passata la porta, lo squalo frena e si ferma prima del muro di fondo. Resta stretto, con le braccia raccolte e la coda ferma, finché la porta si chiude e lui sparisce.
  - La porta e i suoni restano agli stessi tempi.
- **Arretrando, il fianco entrava di qualche centimetro nel cartello del corridoio** (c'era già nella 0.3.16). Ora arretra 4 cm più a nord. La minaccia resta com'era.
- **Nuovo controllo in `test_interni`.** Dal richiamo finché lo squalo si vede, verifica che i punti della pelle deformata non entrino nei muri, anche oltre la porta: ne entrano 0 m.
- **Test del tunnel.** Nella galleria il giocatore va alla velocità da accucciato (1,7 m/s), e gli occhi con cui il bambino decide se è visto sono all'altezza della camera.
- **Strumento.** `tests/collaudo/sonda_oltre_porta.gd` sonda i muri del vano dietro la porta.

## Secondo ricontrollo di enigmi (30 ottobre sera)

- **La coda nella porta che si chiude.** Dietro la porta lo squalo si ferma 33 cm più avanti di prima (`Y_FERMO`), gira la testa di lato (`TESTA_GIRA`) e alza un poco la coda (`CODA_SU`). Così il muso non arriva al muro di fondo del vano e, con la porta chiusa, la coda è tutta oltre il battente: il punto più indietro è a x 22,12, il battente arriva a 22,00.
  - Nuovo controllo in `test_interni`: con la porta quasi chiusa e lo squalo ancora visibile, nessun punto della pelle sta dalla parte del giocatore.
- **Gomito e artigli al mento.** Nel giro la testa resta sul giocatore e passa sopra la spalla destra, a 21 cm dal mento. Le correzioni:
  - il gomito del braccio alzato va giù, in guardia;
  - gomito, polso, mano e artigli restano lontani da bocca, cerniera della mascella e mento, nel giro e alla porta (alla porta la mano si sposta solo in giù);
  - la spinta che li tiene lontani passa da un fotogramma al successivo e cambia al più di 10 cm per fotogramma. Senza, la mano saltava di 75 cm da un lato all'altro del mento fra due fotogrammi, e a 60 fps, nell'interpolazione, il gomito gli passava a 9 cm.
  - Misura dal GLB, a 120 campioni al secondo da 5,5 a 11,5 s: il punto più vicino è a 30 cm. Il salto più grande di una mano è di 5 cm ogni 1/120 s, nella corsa.
  - `test_interni` ora controlla anche gomiti e artigli, non solo i polsi, contro bocca, mascella e mento: al più vicino 0,30 m.
- Foglio: `5_squalo_girata_secondo_ricontrollo.jpg`, la 0.3.16 sopra e la versione corretta sotto, da sopra e dagli occhi (render Blender del modello vero).
- Strumento in più: `tests/collaudo/scatti_piscina_vuota.gd` fa gli scatti dal fondo della piscina a onde vuota, con la nebbia viola, per il ricontrollo della nebbia.

## Terzo ricontrollo di enigmi: la mano sinistra tremava alla porta

La spinta che tiene le braccia lontane dal muso si accendeva e si spegneva a fotogrammi alterni. Ora è continua:
- la spinta voluta ha una direzione fissa rispetto al corpo: in fuori, in giù e un poco indietro; alla porta solo in giù;
- la sua quantità è la minima che basta, cercata a passi di 1 cm, quindi cambia in modo continuo;
- la spinta vera la segue con una molla smorzata (`MOLLA` in `mostro_rig.py`), con velocità continua sia quando si accende sia quando si spegne;
- il margine `MANO_MUSO` (0,42 m) lascia spazio al ritardo della molla.

Insieme alla spinta sono cambiate tre pose:
- nel giro il braccio destro alzato sta un poco più in fuori e più in basso, e così la spinta non serve quasi mai;
- alla porta le mani raccolte stanno più in basso;
- nella corsa la mano sinistra sta un poco meno alta e col polso piegato in giù, perché prima gli artigli puntavano al mento.

Misure dal GLB, ai fotogrammi dell'animazione (30 al secondo), dal richiamo a dopo la porta:
- il salto più grande della velocità di una mano rispetto al petto è 2,25 m/s; nella 0.3.16 era 2,65;
- alla porta, fra 10,6 e 10,8 s, la mano sinistra fa 0,56, 0,32, 0,39, 0,68, 0,66, 2,00, 1,68, 0,50 m/s: un solo movimento mentre si china, non più il su e giù;
- il punto più vicino a bocca, mascella e mento è a 0,264 m (il gomito destro).

`test_interni` controlla anche che la velocità delle mani rispetto al petto non cambi più di 2,7 m/s in un fotogramma: la 0.3.16 arrivava a 2,65. Ora il salto più grande è 2,57 m/s, misurato a 60 fps nel gioco.
