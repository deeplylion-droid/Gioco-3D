# Peso della build

Misure del 19 ottobre 2026, prese su un clone pulito con gli stessi passi della CI (import, `tools/godot_vram_textures.py`, import, esportazione). Il peso per cartella di ogni build sta nel log della CI, stampato da `tools/verifica_pck.py`.

## Il limite

GitHub non accetta file di Release sopra i 2 GiB.

- **Exe unico** (Windows, con il .pck dentro): `build.yml` lo pubblica solo sotto 1,95 GB. Sopra, nel log compare l'avviso "Exe unico non pubblicato" e nella Release resta solo lo zip.
  - In quel caso le note della versione (`docs/release/vX.md`) non devono parlare dell'exe.
- **Zip**: la CI si ferma con un errore se uno zip supera i 2 GiB.
  - Lo zip pesa circa il 60% del .pck, perché le texture BC si comprimono ancora un po'. Quindi c'è margine fino a un .pck di circa 3,3 GB.

## Dove sono i MB

v0.3.6: .pck 1658 MB, exe unico 1,77 GB, zip 1,0 GB.

| Tipo | MB |
|---|---|
| Texture (`.ctex`) | 1472 |
| Scene e mesh (`.scn`) | 127 |
| GI cotta (`.res`) | 46 |
| Audio | 8 |

Le texture sono già tutte compresse per la scheda video (BC/S3TC). Sopra i 2048 px ci sono solo le 5 texture 4K della medusa.

## Già fatto (v0.3.7, invisibile)

Risultato: .pck da 1658 a 1240 MB, exe unico circa 1,35 GB.

- **Doppioni, −374 MB.** Il plugin `addons/esportazione` (EsportaSenzaDoppioni) mette una volta sola le texture importate identiche byte per byte. Sala e torre, per esempio, estraggono gli stessi materiali dai loro GLB. Il `.import` di ogni doppione rimanda ai dati della copia che resta. Il plugin agisce solo all'esportazione.
- **File inutili, −44 MB.** Esclusi dai preset i file usati solo da proposte scartate.
  - `test_esportazione.gd` controlla che nessun file rimasto nel pacchetto ne usi uno escluso.

Peso per cartella dopo questi passi, in MB:

| Cartella | MB |
|---|---|
| ambienti_interni/texture | 260 |
| ambiente/sala | 210 |
| ambienti_tecnici/texture | 124 |
| ambiente/torre | 113 |
| ambienti_tecnici/arredo_risalita | 110 |
| models/medusa | 75 |
| ambiente/dettagli | 68 |
| models/bambini | 56 |

## Proposte che si vedono

Da riprendere quando l'exe unico si avvicina a 1,8 GB. Prima vanno mostrati all'utente gli scatti prima/dopo dal motore. Il lavoro sono poche righe in `tools/godot_vram_textures.py` (`LIMITI_ESTRATTE` / `TEXTURE_3D`).

| | Cosa | Risparmio stimato | Rischio |
|---|---|---|---|
| A | Torre: normal e ORM da 2048 a 1024, come già nella sala | ~40 MB, più altri doppioni con la sala | basso, consigliata |
| B | Oggetti piccoli dei .gltf (props Meshy di interni, tecnici, arredo risalita) da 2048 a 1024 | ~250 MB | da guardare da vicino (estintori, leve, sedie), consigliata con gli scatti |
| C | Sala: texture colore da 2048 a 1024 | ~104 MB | superfici grandi viste da vicino: si vede, sconsigliata |
| D | Medusa da 4K a 2K | ~50 MB | è la protagonista, sconsigliata |

## Riserva: solo lo zip

Senza l'exe unico non cambia niente nel gioco. L'utente deve solo scompattare lo zip, come già per Linux. La CI lo fa da sola quando l'exe supera il limite.
