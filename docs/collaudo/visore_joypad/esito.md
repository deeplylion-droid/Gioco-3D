# Ricontrollo visore-joypad 42ea553c (#128, VISORE_JOYPAD scelta A)

Fatto da mascotte il 9 novembre su `lavoro/visore-joypad-testo` 42ea553c, che parte da main e3104cd2.

**Esito: SUPERATO.** Il branch non ha difetti. Due cose da sapere, che vengono da prima e non da questo branch, sono in fondo.

## 1. Il testo

Il testo è letto a schermo nel gioco vero, tradotto:
- italiano: «E · Spazio · clic · A · B per continuare»;
- inglese: «E · Space · click · A · B to continue».

## 2 e 3. Aperture e chiusure, nel gioco vero

Le prove sono in `prove_nel_gioco.txt`: 27 su 27. Si parte dalla sala principale col giocatore vero, il raggio dell'interazione e gli eventi veri di tastiera, mouse e joypad.

| Come si apre | Lingua | Come si chiude |
|---|---|---|
| Polaroid15 raccolta nel mondo con E | it | Start non chiude, E chiude |
| Polaroid13 raccolta nel mondo con E | it | A del joypad chiude |
| Polaroid01 raccolta nel mondo con E | en | Spazio chiude |
| Polaroid02 raccolta nel mondo con E | en | Start non chiude, B del joypad chiude |
| dall'album, riaperta con Invio | it | clic chiude, si resta nell'album in pausa |
| dall'album, riaperta con A del joypad | it | E chiude |
| dall'album, riaperta con A del joypad | en | Start non chiude, B chiude, si resta nell'album |
| dall'album, riaperta con Invio | en | Spazio chiude |

## 4. Nello schermo

Le misure sono in `misure.txt` e gli scatti col renderer vero sono in `0_foglio_visore.jpg`.

A 1280x720, 1920x1080 e 2560x1080 il testo:
- sta su una riga, centrato in basso;
- è largo 309 px in italiano e 285 px in inglese, su una larghezza di base di 1280 px;
- non esce dallo schermo e non è tagliato.

L'interfaccia scala dalla base 1280x720: nel formato largo la base diventa 1706x720. Carattere e stile sono quelli di prima: Open Sans SemiBold 18, grigio chiaro (0,85) all'80%. Il codice dello stile non è cambiato, è cambiato solo il testo.

Gli scatti sono fatti sopra gli interni del gioco, col visore aperto come fa la Polaroid quando la raccogli. La sala intera col Vulkan supera la memoria della macchina (12 GB, uccisa due volte), anche con la grafica al minimo.

## 5. Nessun peggioramento

- `test_album_polaroid` 29/29;
- `test_lingua` 30/30;
- `test_polaroid` (Polaroid 4) 5/5.

## 6. Scatti per il foglio

`1_visore_italiano.jpg`, `2_visore_inglese.jpg` e `3_visore_largo_2560x1080.jpg`.

## Da sapere (vengono da prima, non da questo branch)

- **Nel mondo il joypad non raccoglie.** L'azione «interact» ha solo il tasto E e nessun bottone del joypad. Nel gioco le azioni col joypad sono solo `ui_accept` (A) e `ui_cancel` (B). Quindi col joypad la foto si chiude con A e B, come dice il testo, ma per raccoglierla nel mondo serve E. Se l'utente gioca col joypad, è un lavoro a parte da decidere con lui.
- **Anche Esc chiude la foto** (azioni `pause` e `ui_cancel`), ma il testo non lo dice. Era così anche prima, e la scelta A elenca solo quei cinque.
