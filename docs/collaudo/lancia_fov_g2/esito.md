# La lancia a FOV largo (#146) e la misura del caricamento (#139), grafica-2

## #146: la lancia guardando in basso col FOV largo

**Il difetto.** È il tubo della lancia verso lo zaino, `TuboZaino` (`pezzi_fov90.txt`).
- Tutte le mesh del giocatore nascoste, poi riaccese una per volta a FOV 90 giù 65: solo lui compila, 2 draw e 2 specialization.
- Ha un formato dei vertici suo (senza UV) e un materiale senza texture. La canna e il guanto sono sempre in vista; lui sta sotto il bordo dello schermo ed entra in vista solo col FOV largo guardando in basso.
- Compilava anche dopo il riscaldamento vero della schermata di caricamento (`giro_prima.txt`).

**La correzione** (`RiscaldamentoShader._disegna_lancia`).
- Nel riscaldamento che già c'è entra la lancia vera, `lancia_c1.tscn`, la stessa scena del giocatore.
- Entra nascosta e si accende un pezzo alla volta, coi passi delle ombre.
- La scena si chiede al caricamento nel thread (lo stesso della sala), non con un load(): nessun file nuovo all'avvio.

**Le prove.**
- **Le pose:** a FOV 70, 90 e 110, giù 40, 65 e 85, con la lancia ferma, che spruzza e che aspira: 0 pipeline nuove in tutte le 27 pose (`giro_dopo.txt`). Prima: 2 draw a FOV 90 giù 65.
- **Gli scatti prima/dopo** (`lancia_prima_dopo.jpg`: prima, dopo, differenza ×40): la lancia e il tubo sono identici pixel per pixel. Le uniche differenze, al più 7 su 255, sono nel pavimento lontano in alto, per gli effetti a schermo che cambiano da un giro all'altro.
- **test_riscaldamento_pipeline** (nella CI) ha il caso nuovo 6: col giocatore vero, a FOV 70, 90 e 110 giù 40, 65 e 85, nessuna compilazione che blocca.
  - Sul codice nuovo passa 12 su 12 e il riscaldamento ha il fotogramma peggiore a 10 pipeline, nel limite.
  - Senza la correzione il caso 6 fallisce: «FOV 90 giù 65: surface 0, draw 2».
  - Il caso costa 9 pose, pochi secondi.
- **check_scripts:** 0 errori.

## #139: misura_caricamento_jilly

- La memoria del processo si legge riga per riga. I file di /proc hanno lunghezza 0 e `get_as_text()` li leggeva vuoti.
- Se la memoria libera della macchina scende sotto 2 GB, la misura si ferma e stampa quello che ha. Con `FINO=<s>` si ferma dopo tanti secondi.
- Alla fine ferma la schermata ed esce subito. Con Game.esci prendeva la sala dal thread e girava altri 30 fotogrammi: lì il processo veniva ucciso, a 12,4 GB.

Le misure sono in `misura_caricamento_139.txt`:
- **misura intera:** esce con 0, RSS da 1517 a 12438 MB, 2,7 GB liberi all'uscita;
- **con FINO=8:** si ferma a 8 s e stampa «interrotta».
