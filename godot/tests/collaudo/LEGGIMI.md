# Collaudo del posizionamento

Strumenti della squadra collaudo per trovare, prima di ogni build, gli oggetti sospesi, staccati, compenetrati o messi dove non hanno senso, con occhi diversi da chi ha costruito. Non correggono niente: trovano e documentano.

Ogni Godot passa da `flock /home/user/tools/render.lock`, e gli scatti partono solo con almeno 13,5 GB di `MemAvailable`.

## 1. Geometria e celle (`geometria.gd`)

```
flock /home/user/tools/render.lock godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- \
    res://tests/collaudo/geometria.gd res://scenes/sala_principale.tscn <stato> <uscita> [nodi da togliere]
```

Scrive tutti i triangoli delle mesh nel mondo (`<uscita>.bin`), l'elenco delle mesh (`<uscita>.json`) e le celle raggiungibili a piedi dai checkpoint (`<uscita>_celle.json`). Conta anche le istanze dei MultiMesh (i dettagli della sala con 6 o più copie), gli oggetti grandi e quelli nascosti all'inizio, che il controllo della CI salta.

Gli stati (`stati.gd`): `inizio`, `aperto` (porte, portelli, paratie e serrande aperte), `ritorno` (blackout della tappa 7, acquari pieni e lampadine del portone accese, tappa 8 finita), `risolto` (enigma risolto, portone della torre aperto).

## 2. Distanze vere (`tools/collaudo/distanze.py`)

```
python3 tools/collaudo/distanze.py <uscita> [soglia, di serie 0.01 m]
```

Per ogni oggetto (box fra 4 cm e 6 m) misura la distanza minima fra la sua superficie e tutto il resto, punto-triangolo nei due sensi, e lo spazio sotto i suoi punti più bassi. Poi segue i contatti fino a 1 cm partendo dall'architettura (mesh più grandi di 6 m): un oggetto che non ci arriva, da solo o attraverso altri oggetti, è staccato. Scrive `<uscita>_distanze.json`.

## 3. Giro dagli occhi del giocatore (`giro.gd`)

```
python3 tools/collaudo/punti_giro.py <uscita> lista.txt --box x0,z0,x1,z1 --passo 3.5
xvfb-run -a -s "-screen 0 640x360x24" flock /home/user/tools/render.lock godot --path godot --rendering-driver vulkan \
    --fixed-fps 60 --resolution 640x360 --script res://tests/run.gd -- res://tests/collaudo/giro.gd \
    res://scenes/sala_principale.tscn <stato> <cartella> lista.txt [nodi da togliere]
python3 tools/collaudo/foglio.py <cartella> <foglio>
```

Un punto ogni 3,5 m fra le celle raggiungibili, quattro scatti per punto all'altezza degli occhi (nord, ovest, sud, est, 12 gradi in basso), 640x360 senza GI, con una luce bianca sulla camera. Le righe `mira nome x y z distanza` della lista fanno due scatti ravvicinati di un oggetto, dalla parte più libera e di lato.

Per le scene pesanti (la sala intera sul renderer software) `tools/collaudo/giro_lotti.sh <scena> <stato> <cartella> <lista> <togli> [righe]` divide la lista in lotti, un processo Godot per lotto, con `COLLAUDO_SEMPLICE=1`: i materiali diventano colori piatti (la media della texture) e le texture si liberano. `COLLAUDO_OMBRE=0` spegne le ombre. Il giro toglie GI, sonde, particelle e nebbie, tranne quelle del giocatore (lo zaino d'acqua le usa nel suo `_ready`). Con dei nodi da togliere il giocatore resta fermo e nascosto, perché senza il pavimento cadrebbe e morirebbe. La riga `origine x y z` sposta i punti della lista per le scene aperte da sole (gli interni stanno in -9,7, 0, 40,9).

Le zone nascoste finché il giocatore non è vicino (fiume e infermeria della risalita) le rende visibili `stati.gd` (`mostra_nascosti`), prima di misurare e di scattare.

## 4. Vedute ravvicinate e oggetti piccoli

```
python3 tools/collaudo/ravvicinati.py <uscita>_distanze.json <uscita>_celle.json /dev/null oggetti_piccoli.csv
python3 tools/collaudo/vedute.py <uscita> <uscita>_distanze.json <uscita>_celle.json vedute.txt --tutti-piccoli --stacchi
```

`ravvicinati.py` scrive l'elenco degli oggetti sotto i 40 cm (distanza da ciò che li regge, altezza da terra, stacco del gruppo). `vedute.py` sceglie per ogni oggetto da guardare un punto dove si cammina, fra 0,8 e 5 m, da cui la vista è libera (raggi contro i triangoli veri), e scrive le righe per `giro.gd` all'altezza degli occhi.

## 5. Controlli mirati

- `tools/collaudo/testa.py <uscita> [prefissi]`: mesh che passano a meno di 30 cm in pianta da una cella dove si cammina, fra 0,5 e 1,95 m sopra di lei (lo spazio per la testa).
- `tools/collaudo/sotto.py <uscita> /Nodo`: per ogni vertice di un nastro o di una scia, che cosa c'è sotto e a che distanza.
- `sonda.gd`: raggi e mesh vicine attorno a dei punti; `memoria.gd`: quanta memoria prende una scena.
