# Collaudo delle lingue su lavoro/inglese 82e79630 (ambienti-1, 28-29 ottobre)

La CI di 82e79630 è verde (run 40775847290). Il collaudo l'ha fatto ambienti-1, che non ha lavorato sul ramo.

Gli scatti vengono dal motore (Vulkan software, 1280×720), in tutte e due le lingue
(`godot/tests/collaudo/giro_lingua.gd`):

- `foglio_en_1_menu.jpg`, `foglio_it_1_menu.jpg`: il titolo senza e con Continua, la domanda di Nuova partita, le
  opzioni scheda per scheda, il cambio di lingua dalle opzioni (avanti e indietro), la calibrazione e i comandi.
- `foglio_en_2_gioco_spot.jpg`, `foglio_it_2_gioco_spot.jpg`: la pausa e i comandi dalla pausa, il menu F9, l'attesa al
  ritorno al checkpoint, la schermata di caricamento, "FINE DEL CAPITOLO 1" (con la riga della torre e senza) e i sette
  sottotitoli dello spot, a metà di ogni frase.
- `foglio_riaperto.jpg`: chiudi e riapri.
  - Si sceglie la lingua dal menu a tendina delle opzioni e si chiude il gioco (`scegli_lingua.gd`).
  - Poi lo si riapre e Lingua legge la lingua salvata, come nel gioco vero (`riaperto_lingua.gd`, lanciato con `-s`).
  - L'avvio è riuscito in tutti e due i versi: scelto l'inglese riparte in inglese, scelto l'italiano riparte in
    italiano.
  - Lo scatto mostra la calibrazione della luminosità, che il gioco apre al primo avvio, nella lingua giusta.

## Esito: superato, con un difetto piccolo

- **Niente rimasto in italiano** nella versione inglese, e niente in inglese in quella italiana. L'unica eccezione è il
  difetto qui sotto.
- **Nessuna scritta esce dai riquadri o dallo schermo, e nessuna è tagliata.**
  - L'ho controllato a occhio sugli scatti e con un controllo automatico su ogni etichetta e pulsante visibile: ha
    trovato 0 casi in tutte e due le lingue.
- **I tasti si vedono tutti**, nei comandi dal titolo e dalla pausa. In inglese: Shift, Ctrl, Space, "Left mouse
  button", "Right mouse button", Esc e la nota "hold".
- **Lo spot:** i sottotitoli inglesi sono le frasi lette dallo speaker (`assets_src/spot/voce/genera_voci.py`), parola
  per parola.
  - L'unica differenza è nella frase 2: il sottotitolo dice "...the Jubilee!" e la voce "The Jubilee!". Va bene, perché
    continua la frase 1 ("presents... the Jubilee").
  - In italiano i sottotitoli restano la traduzione.
- **"FINE DEL CAPITOLO 1"** diventa "END OF CHAPTER 1", e la riga della torre diventa "The descent goes on into the
  dark. / Thank you for playing!".
  - Il puntino sotto la scritta è il mirino del HUD, non un difetto.
- **Il cambio di lingua dalle opzioni vale subito**, avanti e indietro: titoli delle schede, righe, scelte e pulsanti.
- **Si salva:** riaperto il gioco, la lingua è quella scelta.

### Difetto (piccolo)

1. **Il testo del campo visivo non cambia lingua.** Nelle opzioni (scheda Schermo/Display), cambiando lingua il testo
   accanto al cursore del FOV resta nella lingua di prima: per esempio "62° (94° horiz.)" anche in italiano, o
   "(94° orizz.)" in inglese.
   - Si corregge solo quando si muove il cursore.
   - La causa: `_testo()` in `addons/grafica/menu_opzioni.gd` compone la stringa una volta sola. Va rifatta anche con
     `Lingua.segui`.

### Limiti del collaudo

- La schermata di caricamento è fotografata in dissolvenza, perché nello scatto carica una scena leggera al posto della
  sala. Si leggono la scritta "Preparing the hall…" / "Caricamento della sala…" e la colonna dei comandi.
- I consigli coi tasti li prova test_lingua.
- La sala intera con llvmpipe non ci sta in memoria: la pausa e i comandi dalla pausa sono fotografati sopra il titolo.
