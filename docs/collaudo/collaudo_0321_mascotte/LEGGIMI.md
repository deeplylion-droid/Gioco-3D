# Collaudo finale 0.3.21: le cose di enigmi (mascotte, 6 novembre)

Candidata `lavoro/candidata-0321` 080ec07e, senza la correzione degli stendardi e varchi-cielo. Gli scatti sono presi
dagli occhi del giocatore, con Vulkan software a 1280x720. Gli strumenti sono in `godot/tests/collaudo/`:
`collaudo_0321_cartello.gd`, `collaudo_0321_album.gd` e `collaudo_0321_luminosita.gd` (miei), più
`scatti_disegno_torre.gd` (di enigmi, gruppi «disegno» e «fascette»).

## 1. Cartello delle pozze: va (`1_cartello_pozze.jpg`)
- C'è un solo CartelloPozze: quello nel corridoio del personale dopo l'approdo, sul muro est.
- Si legge da lontano entrando dal capannone e da vicino; i tre quadratini viola, arancione e turchese si distinguono.
- È fissato al muro: ho misurato con i raggi nei quattro angoli e al centro, e dappertutto il muro è a 0,0 mm dal
  retro della lastra. Visto di taglio, da sinistra e da destra, non si vede nessuno stacco.
- Il faretto bianco è stretto sul cartello, con la base contro il soffitto (0,0 mm).
- Nell'infermeria non c'è il cartello: il muro della porta nord è vuoto. Restano solo il faretto del negatoscopio e
  quello della cassaforte.

## 2. Disegno guida dei giocattoli: va (`2_disegno_guida.jpg`, `3_disegno_fascette.jpg`)
- Sta sulla torretta col tetto blu dell'area bimbi, legato alla ringhiera della pedana. Si vede dal percorso da 4 m e
  da lontano (d1, d3, d4). Da 1 m si leggono i tre cerchi e il quadrato (d2, d5).
- Le quattro fascette, da vicino davanti e dietro, girano attorno ai corrimani. Il cartoncino sta a filo della
  ringhiera, e di lato (d6) non si vedono distacchi.
- Il muro della piscina dove stava prima è vuoto (d7).

## 3. Album delle Polaroid nel menu di pausa: va (`4_album_polaroid.jpg`)
- A 0: «0 su 16», 16 cornici vuote.
- Dopo 5 Polaroid raccolte (1, 4, 10, 12, 16): «5 su 16», con la foto nelle cornici giuste. La 4 si apre grande.
- Con le Polaroid di un salvataggio ripreso come fa Continua (GameState.prepara_ripresa con la partenza «torre»):
  «14 su 16», con 14 foto. La Continua vera, che passa dalla schermata di caricamento, la controlla test_continua.
- test_album_polaroid: 22/22.
- Nota piccola: sotto la foto grande la scritta dice «E · Spazio · clic per continuare» anche col joypad.

## 4. Suoni degli enigmi: vanno
- Cassaforte (test_infermeria_gioco, 75/75): un clic a ogni cifra, diverso per rotella. Col codice giusto suonano il
  «fatto giusto», il chiavistello e il cigolio, e lo sportello arriva aperto con la fine del cigolio. Col codice
  sbagliato non suona niente.
- Dischi del fiume (test_fiume_gioco, 34/34): il gong di lamiera sul disco, una volta, e le due chiuse del bivio 1
  che si muovono col motore e le catene.
- «Fatto giusto» (test_pozze 144/144, test_enigma_giocattoli 94/94, test_acquari 84/84, cassaforte): suona una
  volta a ogni enigma risolto, e non di nuovo alla ripresa. Il file giusto.ogg dura 0,75 s e ha 3 note (circa 775,
  970 e 1165 Hz), quindi è il jingle accorciato.
- Domanda, non è un difetto: il fiume non ha il «fatto giusto» quando lo risolvi. Enigmi l'ha messo solo su acquari,
  pozze, giocattoli e cassaforte (commit baaaf30f).

## 5. Luminosità al primo avvio: va (`5_luminosita.jpg`)
- Sotto i simboli c'è lo scatto vero del corridoio delle pile, con la frase «Regola finché vedi appena la scatola in
  fondo.»; in inglese «Adjust until you can barely see the box at the end.».
- La croce del joypad muove il cursore e la prova lo segue: 1,00, poi 1,10 dopo 5 volte a destra, poi 0,90 dopo 10
  volte a sinistra.
- test_menu: 84/84.

## Nota sull'ambiente
Al primo giro test_enigma_giocattoli, test_acquari e test_menu fallivano perché nel mio worktree mancava
la classe StendardiInseguimento: non avevo rifatto l'import di Godot. Dopo `godot --import` passano tutti, quindi non
sono difetti del gioco.
