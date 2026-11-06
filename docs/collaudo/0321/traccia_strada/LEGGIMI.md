# La traccia della strada del capitolo (collaudo, candidata 0.3.21 080ec07e)

La strada vera, percorsa dal giocatore vero di `test_strada.gd` senza schermo: dal corridoio del risveglio fino alla passerella della torre, passando per la sala pompe, la Risalita col giro in barca sul fiume, l'infermeria, la stanza delle pozze, la scala di servizio, il raccordo C3, la serranda e la spiaggia. test_strada è passato (36 ok).

Strumento: `godot/tests/collaudo/traccia_strada.gd`.
- Estende test_strada.
- Scrive un punto ogni 2 m, solo coi piedi a terra; nel giro in barca, il punto è dove sta seduto.

## `traccia.txt`
Una riga per punto, campi separati da `|`:

`tratto|x|y|z|yaw`

- **tratto**: il nome del tratto di test_strada (`_vai`), per esempio "nella sala pompe fino alla porta del ponte inferiore".
- **x, y, z**: i **piedi** del giocatore, in coordinate del mondo della sala principale. Gli occhi sono 1,6 m più su; in barca circa 1,15 m.
- **yaw**: dove guarda, in gradi (0 verso -z). In barca resta fisso: meglio la direzione fra il punto prima e quello dopo.

Sono 237 punti. Gli ultimi 3 ("attraverso il portone") sono già nella torre.

## Le liste per `giro.gd` (`lista_<zona>.txt`)
Fatte da `liste.py`. Per ogni punto, quattro scatti dagli occhi: avanti lungo la strada, a sinistra, a destra e dietro, inclinati di 12 gradi in basso. Il formato è quello di `tests/collaudo/giro.gd`: `nome x y z yaw pitch`, con gli occhi già messi.

| zona | tratti | stato per giro.gd | nodi da togliere (la sala per parti) |
|---|---|---|---|
| I (16 punti) | dal corridoio del risveglio al tornello | inizio | Sala,Vasca,Risalita,Piscina,Vasche,Tecnici,Mascotte,Atmosfera,LuciSala,BambiniBalconata |
| S1 (6) | sotto la saracinesca fino alla statua | inizio | Interni,Risalita,Tecnici |
| T (42) | camera delle onde, sala pompe, rampe del raccordo, corridoio C2 | aperto | Interni,Sala,Vasca,Piscina,Vasche,Mascotte,Atmosfera,LuciSala,Risalita,BambiniBalconata |
| R (128) | scala del fiume, capannone e giro in barca, approdo, infermeria, pozze, scala di servizio | aperto (con COLLAUDO_RISALITA=1) | Interni,Sala,Mascotte,Vasca,Vasche,Gioco,Piscina,Atmosfera,LuciSala,Tecnici,BambiniBalconata |
| C (9) | da C3 al magazzino dei gonfiabili | ritorno | come T |
| S2 (33) | dalla serranda lungo la scia all'area bimbi e alla spiaggia fino al portone | risolto | Interni,Risalita,Tecnici |

Stati e nodi sono una proposta: non li ho provati col renderer, perché il giro è passato a grafica-2 e mascotte.

Esempio, a lotti di 160 righe:

```
xvfb-run -a -s '-screen 0 640x360x24' godot --path godot --rendering-driver vulkan --fixed-fps 60 --resolution 640x360 \
  --script res://tests/run.gd -- res://tests/collaudo/giro.gd res://scenes/sala_principale.tscn <stato> <cartella> <lista> <togli> 75
```

Il tunnel del viaggio sottomarino non c'è: test_strada si ferma alla torre.
