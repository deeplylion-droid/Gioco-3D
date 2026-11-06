# Ricontrollo delle sagome del club (ambienti-1, 6 novembre)

Branch `lavoro/sagome-club` 6404d7cf (enigmi). Collaudo: `godot/tests/collaudo/collaudo_sagome_club.gd`. Gira nella sala dell'inseguimento vera, con le sagome costruite dalla coda della sala, e misura sulla geometria vera (collisioni più mesh visibili, senza le sagome); difetto sopra i 5 mm.

## Esito: superato, 0 difetti

- Base sul bordo (vasche 1 e 3) e sul grigliato (vasca 2): tutti i vertici del taglio di base a 0,0 mm, nessuno senza appoggio.
- Lunghezza appoggiata, in cm: balena 86, granchio 50, stella 27, tartaruga 46, foca 64, pesce 62, razza 7, cavalluccio 20, pesce palla 48, polpo 69, delfino 81, squalo 61.
- Puntelli: la cima della lama sulla schiena del cartone a 0,0 mm, dentro il contorno; la lama sul suo piede a 0,0 mm; il piede sul bordo a 0,0 mm.
- Mattoni: sul piede a 0,0 mm, poggiati per il 100%.
- Compenetrazioni:
  - lama, piede e mattone (scatole rimpicciolite di 1 mm) non entrano in niente;
  - nel cartone (griglia di 2 cm, raggi nel suo piano) niente del mondo;
  - anche il cavalluccio e il suo mattone, a filo del tubo rosso, non ci entrano.
- Vasca 2:
  - lo spago passa da tutti i fori, con 168-240 vertici per foro;
  - ogni legatura tocca il corrimano a 0,5-0,8 mm, con 216-420 vertici entro 3 mm.

**Da guardare** (non è un difetto di posizionamento): la razza poggia sul bordo solo per 7 cm e si regge sul puntello.

## Unione con lavoro/salite-lei (4af88de1)

Senza conflitti. Sull'unione passano:
- check_scripts;
- test_sagome_club;
- test_inseguimento, test_lei_animazioni, test_inseguimento_suoni;
- test_morbidezza_inseguimento a 30 fps;
- posizionamento, con 0 casi da correggere.
