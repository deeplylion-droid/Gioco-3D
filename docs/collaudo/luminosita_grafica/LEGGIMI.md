# Collaudo della schermata «Luminosità», parte di grafica (6 novembre)

Branch controllato: `lavoro/ritocchi-grafica2` 719d283b. Continua il collaudo di ambienti-2 (`docs/collaudo/luminosita_a2/`).
Strumento: `godot/tests/collaudo/collaudo_luminosita_grafica.gd` (Vulkan software, Xvfb; uso nell'intestazione).

## Esito: nessun difetto
1. **Dalle opzioni del titolo vero, clic del mouse su «Calibra la luminosità…»**: la schermata si apre e il focus va
   su «Conferma» dentro la schermata. Esc la chiude e si torna alle opzioni. Si apre anche col joypad (A sul pulsante),
   B la chiude, e con la tastiera (Invio). Il caso di ambienti-2 (il focus restava su «Continua») veniva dalle opzioni
   aperte con `Game.open_options()` sopra il titolo, non dalla voce Opzioni del titolo: dal titolo vero non succede.
2. **Inglese**: ogni scritta della schermata e della scheda ha la traduzione (Brightness, Darker/Lighter,
   Default/Confirm, la frase sotto lo scatto); niente esce dai bordi.
3. **Misure della finestra**: 1280x720, 1920x1080, 900x720, 800x600, 1280x1024. Tutto dentro lo schermo, niente si
   copre. Lo scatto è mostrato a 487x274 in 16:9 (1280x720 e 1920x1080) e più grande nelle finestre più alte
   (804x452 a 800x600, 889x500 a 900x720 e 1280x1024).
4. **Primo avvio vero** (gioco lanciato senza `--script`, cartella dei dati vuota, registrato con `--write-movie`): la
   schermata compare subito sopra il titolo, intera, e `settings.cfg` resta con `calibrato=false` finché non si
   conferma. Qui è uscita in inglese perché la macchina non ha una lingua impostata (Lingua: senza lingua salvata
   prende quella del sistema; "en" solo se il sistema è in inglese).
5. **Lo scatto e il gioco di oggi**: lo stesso strumento di grafica-2 (`scatto_calibrazione_g2.gd`, la stessa posa e le
   stesse condizioni) rifatto in CI sul gioco di oggi (`lavoro/scatto-calibrazione-confronto`, cioè
   `lavoro/ritocchi-grafica` db8cfdf4 con le pile di ambienti-1; run 42189435238) dà gli stessi valori dello scatto
   della prova (run 42162291507), in tutti i 16 punti della fila. Nel punto della prova, `fila_08`: media 9,3, mediana
   6,4, 10° percentile 0,1, 90° 18,2 tutte e due le volte. Le sole differenze sono di 0,1 sulla mediana di due scatti
   lunghi (fila_62_lungo 2,0 contro 2,1; fila_90_lungo 6,5 contro 6,4). Lo scatto somiglia al gioco di oggi: niente da
   rifare. (Le immagini sono negli artifact delle due run, «scatto-calibrazione»; qui i numeri, perché gli artifact non
   si scaricano dalla sessione.)

## Fogli
- `foglio_titolo_lingue_misure.jpg`: le opzioni del titolo, la schermata aperta col mouse e col joypad, in inglese,
  e alle cinque misure.
- `foglio_primo_avvio_vero.jpg`: i fotogrammi del primo avvio vero (1, 6, 12, 20, 30, 40 s a 10 fps).
- Singoli: `1_calibrazione_dal_titolo_mouse.jpg`, `2_calibrazione_en.jpg`, `3_calibrazione_800x600.jpg`.
