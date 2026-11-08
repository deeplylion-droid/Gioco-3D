# Collaudo del menu di prova F9 col mouse (#143), enigmi, 8 novembre

- Correzione di ambienti-2: `lavoro/menu-f9-mouse` `80529af4`.
- Cosa cambia: in `menu_prova.gd` il menu sta su `LAYER = 110`, sopra la Radice del titolo (layer 100, che ferma i
  clic) e sotto la dissolvenza (120). Il resto è uguale a main `18546b01`.
- Il titolo vero (`menu_principale.tscn`) col renderer Vulkan (llvmpipe sotto xvfb, finestra 1280x720).
- **Ogni caso in una cartella utente nuova e vuota** (`XDG_DATA_HOME` nuova).
- Il mouse e la tastiera sono veri: `xdotool` manda gli eventi X11 alla finestra del gioco (spostamento del mouse, clic
  sinistro premuto e rilasciato, tasti), come una persona.
- Il joypad passa da `Input.parse_input_event`: sono gli stessi eventi che arrivano da un joypad vero (croce, A, B).
- Strumento: `godot/tests/collaudo/collaudo_menu_f9.gd`. Per ogni passo registra:
  - cosa c'è sotto il mouse prima del clic, e cosa ha il fuoco;
  - se il menu si apre e si chiude;
  - se parte la partenza giusta: la scena di caricamento col checkpoint dell'istantanea, o lo spot VHS per «Inizio»;
  - l'opacità della dissolvenza fotogramma per fotogramma, e se il menu c'è ancora.
- Appena una partenza è partita il processo esce, perché la sala renderizzata con llvmpipe non sta nella memoria. La riga
  «COLLAUDO: ESCO» separa il log del collaudo da quello dell'uscita.

## Esito: superato, nessun difetto

| Caso | Controlli |
|---|---|
| Clic su Risalita, Fiume lento, Torre, Inseguimento, Tunnel (uno per processo) | 4 su 4 in ciascuno |
| Opzioni (7 schede e calibrazione), Comandi, chiusure del menu F9, clic su Inizio | 24 su 24 |
| Tastiera | 13 su 13 |
| Joypad | 9 su 9 |
| Con un salvataggio: Nuova partita, Inizio dal menu F9, clic su Risalita | 9 su 9 |
| Continua col mouse | 2 su 2 |
| Inglese: Opzioni, Comandi, menu F9, clic su Tunnel | 24 su 24 |
| **Base senza correzione** (main `18546b01`), clic su Risalita | non parte: è il difetto #143 |

### 1. Con F9 ogni voce si clicca col mouse e fa partire la sua partenza (foglio 1)

- **Tutte e sei le voci** si cliccano col mouse: prima del clic, sotto il mouse c'è proprio la voce.
- Ognuna fa partire la sua partenza:
  - **Inizio:** la nuova partita, cioè lo spot VHS.
  - **Le altre cinque:** la schermata di caricamento, col checkpoint della sua istantanea:
    - Risalita: `CheckpointT7Inizio`;
    - Fiume lento: `CheckpointIngresso` del fiume;
    - Torre: `Checkpoint_portone` della torre;
    - Inseguimento: `Checkpoint_fondo` della torre;
    - Tunnel: `Checkpoint_6` della sala sottomarino.
- Il menu si chiude anche col clic su «Indietro», con F9 e con Esc. Le voci del titolo tornano visibili.
- **La base senza correzione** (foglio 5): lo stesso clic su Risalita, sotto il mouse c'è la «Radice» del titolo (layer
  100). Il menu resta aperto e non parte niente. Lo strumento vede quindi il difetto #143, e con la correzione non c'è
  più.

### 2. Tastiera e joypad come prima (foglio 4)

- **Tastiera:**
  - F9 apre il menu col fuoco sulla prima voce;
  - le frecce giù e su spostano il fuoco una voce alla volta;
  - si chiude con Esc, con F9 e con Invio su «Indietro»;
  - Invio su «Fiume lento» fa partire il fiume.
- **Joypad:**
  - la croce giù e su sposta il fuoco;
  - si chiude con B e con A su «Indietro»;
  - A su «Torre» fa partire la torre.

### 3. Gli altri pannelli del titolo non cambiano (foglio 3)

- **Opzioni:**
  - si aprono col clic;
  - le **7 schede** si aprono col clic: Schermo, Resa, Luci e ombre, Immagine, Controlli, Luminosità, Audio;
  - dalla scheda Luminosità, col clic, si apre la **calibrazione della luminosità**; «Conferma» la chiude e si torna alle
    opzioni;
  - «Chiudi» le chiude.
- **Comandi:** si aprono col clic, «Indietro» li chiude.
- **Con un salvataggio:**
  - nel titolo c'è «Continua»;
  - «Nuova partita» chiede «Ricominciare da capo?» col fuoco su «No», e «No» torna al titolo;
  - anche «Inizio» del menu F9 fa la stessa domanda;
  - dopo il No, il clic su Risalita parte.
- **Continua:** col clic riparte dal salvataggio (caricamento, `Checkpoint_portone` della torre).

### 4. La dissolvenza copre il menu F9 quando si parte (foglio 2)

- Al clic il menu di prova si toglie subito, prima che lo schermo si scurisca.
- Fotogramma per fotogramma, dopo il clic su Tunnel il nero sale (22%, 45%, 67%, 88%, 99%) e poi arriva il caricamento.
  **In nessun fotogramma il menu è sopra il nero.**
- Lo stesso per Inizio verso lo spot e per tutte le altre partenze.

### 5. Anche in inglese (foglio 4)

- Il menu F9 è tradotto: «Test start», «Start · new game», «Climb back», «Lazy river», «Tower of Slides», «Chase»,
  «Underwater tunnel», «Back».
- Le voci si cliccano: Tunnel parte col suo checkpoint.
- Opzioni (Display, Rendering, Lights and shadows, Image, Controls, Brightness, Audio), calibrazione e Comandi vanno
  come in italiano.

### 6. Nessun errore nel log

- In tutti i 13 processi, prima della riga «COLLAUDO: ESCO», nessun ERROR né WARNING, a parte quelli dell'audio, che
  nella macchina di prova non c'è (`audio_driver_alsa`).
- Dopo l'uscita c'è «Parse Error: Failed» di `sala_principale.tscn`: è il caricamento a thread della sala, interrotto
  perché lo strumento chiude il gioco mentre carica. Non viene dal gioco.

## Fogli

1. `1_partenze_col_mouse.jpg`: il titolo con la cartella vuota, il menu F9, poi il clic su ognuna delle sei voci (lo
   spot VHS per Inizio, la schermata di caricamento per le altre).
2. `2_dissolvenza_dopo_il_clic.jpg`: dopo il clic su Tunnel, fotogramma per fotogramma, il nero che sale senza il menu,
   poi il caricamento.
3. `3_altri_pannelli.jpg`: le 7 schede delle opzioni, la calibrazione, i comandi, il titolo col salvataggio, le due
   domande «Ricominciare da capo?», il caricamento di Continua.
4. `4_tastiera_joypad_inglese.jpg`: la tastiera (F9, frecce, Invio sul fiume), il joypad (croce, A sulla torre), e in
   inglese il menu F9, le opzioni, la calibrazione e il clic su Tunnel.
5. `5_senza_correzione.jpg`: la base main: F9, e dopo il clic su Risalita il menu è ancora lì.
