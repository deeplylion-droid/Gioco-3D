# Collaudo della schermata «Luminosità» con la seconda prova (grafica-2, 0.3.21) — fatto a metà

Branch controllato: `lavoro/ritocchi-grafica2` 719d283b. Strumento: `godot/tests/collaudo/collaudo_luminosita.gd`
(uso nell'intestazione). Fatto da ambienti-2 solo a 1280x720 in italiano; il resto passa a grafica.

## Esito a 1280x720, italiano (35 controlli ok, 1 da capire)
- La calibrazione aperta come al primo avvio (`Game._show_calibration`): si apre e ferma il titolo.
- Posizioni: lo scatto, disegnato a 500x281 (in un controllo di 1120x281), non copre i simboli, il cursore, la frase
  né i pulsanti; tutto dentro lo schermo; i simboli hanno 98 px d'altezza.
- Joypad:
  - croce a destra ×5: +0,10;
  - levetta tenuta 1 s: il cursore scorre (1,10 → 0,84) e si ferma quando la si lascia;
  - croce tenuta 1 s: scorre;
  - su e giù, con la croce e con la levetta, passano fra Conferma e Predefinito; il focus resta su Conferma;
  - A conferma.
- Tastiera e mouse:
  - le frecce muovono di 0,02;
  - un clic a un quarto del cursore porta a 0,89;
  - Predefinito col mouse torna a 1,00.
- Lo scatto segue sempre il cursore, con la stessa gamma.
- Dopo la conferma, la luminosità del gioco e la gamma del post-processing sono uguali al cursore (1,12).
- Dalle opzioni, «Calibra la luminosità…» tre volte: ogni volta la stessa schermata con lo scatto, la croce muove
  il cursore, ed Esc chiude senza cambiare.
- **Da capire**: in quel giro il clic del mouse su «Calibra la luminosità…» non apriva la schermata (il focus restava
  su «Continua» del titolo). Le opzioni però erano aperte con `Game.open_options()`, non dal titolo. Nello strumento
  ora si aprono con `apri_opzioni()` del titolo: va rifatto prima di dire se è un difetto. Le tre volte sono state
  aperte col segnale del pulsante.

## Scatti
`foglio_1280_it.jpg` e i singoli `it_1280_*.jpg`: la schermata aperta, a 1,10, a 0,84, il focus su Predefinito, col
mouse a 0,89, il più chiaro (1,80), il più scuro (0,60), il titolo dopo la conferma, le opzioni, e le tre aperture
dalle opzioni.

## Da fare (a grafica)
- Il giro dalle opzioni del titolo, col clic del mouse.
- In inglese (terzo argomento `en`).
- A 1920x1080 e in una finestra stretta.
- Il primo avvio vero senza settings.cfg: lanciare il gioco senza `--script`, dopo una copia di settings.cfg.
  Lo strumento cambia la lingua in settings.cfg: rimettere la copia dopo.
- Il confronto dello scatto con la candidata, dalla stessa posa.
