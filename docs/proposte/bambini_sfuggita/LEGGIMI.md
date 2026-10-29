# I bambini visti di sfuggita

Proposta approvata dall'utente la sera del 25 ottobre (GDD, scelte della sera del 25 ottobre), con la nota:
"attenzione alle animazioni. falle bene". Il bambino a cubo o l'agnellino compare per un attimo, lontano, sta fermo a
guardarti e scappa dietro un angolo prima che tu ci arrivi. Niente aggressioni.

Branch `lavoro/bambini-sfuggita` (da `lavoro/godot` efc7352f). **Non unito: aspetta l'ok dell'utente.**

## I punti

### 1. Il corridoio del fiume (risalita)

- **Dove**: il corridoio di 17 m che dal fondo della scala porta al capannone del fiume lento. L'agnellino sta in
  fondo, sul pavimento del corridoio, a destra della porta aperta del capannone, girato verso la scala.
- **Quando compare**: col giocatore sul pianerottolo in fondo alla scala o nel primo tratto del corridoio, e solo
  mentre non può vederlo (si mette al suo posto fuori vista). Mai insieme a lei all'oblò dello stesso corridoio:
  compare solo dopo che lei è stata vista ed è andata via. Se il giocatore passa senza vederla, lei torna la volta
  dopo e il bambino aspetta ancora.
- **Le Polaroid**: la P13, per terra sotto l'oblò, è a 5,9 m dalla strada della fuga, e il bambino fermo non la copre
  (sta 8 m fuori dalla linea fra il giocatore e lei). La P15 è nella zona del personale, non in questo corridoio.
- **Cosa fa**: fermo, respira, ti segue con la testa e ogni tanto la inclina piano. Quando lo hai guardato per poco più
  di un secondo, o ti avvicini sotto i 9 m, aspetta ancora un attimo, si volta e corre nella porta del capannone.
- **Quando non si vede più**: appena lo stipite della porta lo nasconde sparisce (dal corridoio dove va non si vede:
  la rientranza fra la porta e il muro dell'approdo). Una volta sola: lo stato si salva coi checkpoint.

### 2. La galleria del tunnel sottomarino

- **Dove**: sulla banchina sinistra del tunnel, davanti alla bocca della prima galleria di servizio (a 203 m dalla
  presa), girato verso chi arriva.
- **Quando compare**: mentre si scappa da lei lungo la banchina sinistra, fra 34 e 8 m dalla galleria. Lì si corre
  guardando avanti, quindi il bambino compare lontano, oltre i 26 m, nel buio del tunnel.
- **Cosa fa**: ti guarda; quando lo guardi o ti avvicini sotto i 12 m entra nella bocca della galleria (è piccolo, ci
  sta in piedi: la galleria è alta 1,25 m) e va dietro il muro.
- **Quando non si vede più**: dietro il muro della galleria; poi il giocatore passa nella stessa galleria e non c'è più.

### 3. Il fiume lento (non fatto stanotte)

Era previsto sulla riva dell'anello, prima del bivio 2. Ma la banchina è larga 1,4 m fra l'acqua e la fila delle
rocce finte, che si apre solo ai bivi: per scappare il bambino dovrebbe passare in mezzo alle rocce o alle piante, e un
posto dove sparisca davvero fuori vista dalla ciambella non l'ho trovato in tempo. Lo propongo per il prossimo giro,
se l'utente vuole un terzo punto (per esempio al bivio 2, lungo la banchina del ramo sbagliato).

## Le animazioni

Per tutti i bambini del gioco (`scripts/creature/bambino.gd`):

- **piedi che non scivolano**: il corpo avanza alla velocità dei piedi a terra misurata sulle animazioni (il bambino
  a cubo 0,45 m/s camminando e 2,45 correndo, l'agnellino, che ha le gambe più corte, 0,34 e 1,9; prima avevano la
  stessa e l'agnellino scivolava); l'animazione va alla velocità del corpo;
- **partenza e arresto col passo**: il corpo accelera e rallenta, non parte di colpo;
- **curve, non giri sul posto**: gira al massimo di 110 gradi al secondo camminando e 260 correndo, e rallenta nelle
  curve strette; quando deve voltarsi per scappare (chi lo guardava è dietro di lui) prima si volta quasi sul posto, a
  passi lenti, poi parte;
- **lo stare fermo**: respira, segue con la testa e ogni 3-4 secondi la inclina piano.

- **curve strette**: prima di una curva di più di 45 gradi rallenta e la fa col passo, senza tagliare lo spigolo;
  non va mai più veloce di quanto serve per prendere il punto girando.

### Cosa cambia per l'agnellino della scala C2 (già nel gioco)

Con le curve nuove l'agnellino della scala tagliava la curva davanti al buco, toccava il bordo e si fermava: il
giocatore lo raggiungeva. Ora (test_agnellino verde):

- quello che si vede resta uguale: compare in cima alla scala, ti guarda, scappa nella corsia, si piega e si infila
  nel buco;
- si volta di scatto (600 gradi al secondo) e parte più svelto, perché la corsia è stretta e il giocatore gli corre
  dietro;
- scappa quando ti avvicini sotto i 9 m invece dei 7 di prima (per girarsi col passo gli serve quel mezzo secondo);
- comincia a piegarsi per entrare nel buco a 1,4 m dal muro invece di 1,15, e ci arriva già piegato a 0,85 m invece
  di 0,75, così la testa resta lontana dal bordo alto;
- la curva in fondo alla corsia la fa da sé, col passo; poi si raddrizza verso il buco come prima.

Il bambino si muove sempre in coordinate del mondo (`top_level`), così il nodo che lo mette al suo posto può essere
girato.

## Le regole tecniche

- Niente pipeline nuove quando compare: il bambino si crea nascosto quando nasce la zona e si disegna una volta fuori
  vista, al suo posto, prima un pezzo per volta (`RiscaldamentoShader.disegna_a_pezzi`) e poi da dove lo vedrà il
  giocatore, con le luci della zona. Si cambiano solo gli strati dei suoi nodi visibili, mai la cull mask delle luci.
- Modello e materiali in preload (col thread della zona).

## I test

- `godot/tests/test_bambini_passi.gd`: i due bambini camminano e corrono (con una curva, da fermi): il piede a terra
  nel mondo scivola in media 0,06 e 0,11 m/s camminando, 0,15 e 0,21 m/s correndo; le punte dei piedi toccano terra.
- `godot/tests/test_bambini_sfuggita.gd` (39 controlli verdi): per ogni punto, poggia a terra, al suo posto non entra
  in niente, la strada della fuga è libera e ha il pavimento, passa lontano dalle Polaroid e fermo non ne copre
  nessuna, con lei all'oblò ancora da vedere non compare, dove sparisce non si vede da nessun punto della zona,
  compare col giocatore girato dall'altra parte, guardato scappa, sparisce quando non si vede più, non ricompare, lo
  stato si salva.
- Verdi anche, in locale: check_scripts, test_bambini, test_agnellino, test_tecnici, test_risalita,
  test_sottomarino_lei, test_tappa7 e il controllo di posizionamento (nessun caso nuovo). Unito con `lavoro/godot`
  (le Polaroid nuove) prima degli ultimi test.

## Video e scatti

Dal motore, dagli occhi del giocatore (`godot/tests/collaudo/video_bambini_sfuggita.gd`): `corridoio_fiume.mp4` e
`galleria_tunnel.mp4`, con uno scatto per punto.
