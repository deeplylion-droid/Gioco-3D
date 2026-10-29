# Collaudo del portone della torre (29 ottobre, mattina)

Squadra collaudo. `lavoro/godot` **ca4aef21**, con dentro `lavoro/portone-torre` 9afdcf0e di enigmi. Cosa cambia:
- appena si entra, sulla soglia c'è un muro invisibile;
- il portone resta chiuso anche ripartendo da un checkpoint della torre;
- interni e tecnici si scaricano solo a portone chiuso.

**Esito: va.**
- Non si torna nella sala in nessun modo provato: di corsa, saltando, accucciati, di lato lungo tutta la soglia.
- Dopo una morte e col Continua dal checkpoint del portone si riparte nella torre col portone chiuso e senza interni e tecnici, anche chiudendo il gioco a metà chiusura.
- Appoggiati alla soglia non si resta incastrati.
- 0 righe "ERROR: BUG," e 0 errori del motore e degli script.

## Prove

Tutte senza schermo, col giocatore vero e i tasti veri. Il mondo è fatto fino al portone aperto, come in
`test_portone_torre`. Il muro invisibile è a x 19,80-19,88, il controllo della soglia a x 19,84.

| Prova | Esito |
|---|---|
| `test_portone_torre` | 20 su 20 |
| `test_torre` | 94 su 94 |
| A. entrati, indietro di corsa saltando ogni 1/3 di secondo | si arriva a x 20,23, non si passa |
| B. entrati, indietro accucciati | x 20,23, non si passa |
| C. di corsa contro la soglia, andando di lato avanti e indietro per 5 s | da z -16,22 a -13,78, cioè tutta la larghezza fino agli stipiti: x 20,23, nessun buco agli spigoli |
| D. una morte 0,7 s dopo essere entrati, col portone al 73% e interni e tecnici ancora caricati | si riparte dal checkpoint del portone a x 21,4, col portone chiuso e senza interni e tecnici; di corsa verso la sala ci si ferma a x 20,24 |
| Continua, chiudendo il gioco mezzo secondo dopo l'entrata (portone all'80%) | si riparte a x 21,4, portone chiuso, senza interni e tecnici; non si passa (x 20,24) |
| Continua, chiudendo il gioco a portone chiuso | uguale |
| Appoggiati alla soglia per tutta la chiusura | fermi a x 20,23, a terra; poi si cammina nella torre |

- Dopo ogni prova il portone si chiude del tutto (quanto 0) e interni e tecnici vanno via. Poi si cammina nella
  torre e si sta in piedi (y 0,00).
- **Il Continua** l'ho fatto con due processi, come chi gioca: uno salva su disco e chiude il gioco, l'altro va al
  titolo e preme Invio su Continua, che ha il focus.
- **La camera appoggiata alla soglia** sta a x 20,23 e il muro invisibile a x 19,80-19,88: fra la camera e il muro ci
  sono 0,35 m, il piano vicino della camera è a 0,03 m. L'anta scorre nello stesso spessore, quindi la camera non entra nell'anta.
- **Il muro invisibile** copre z da -18,15 a -11,85 e y da 0 a 5,1 m. C'è anche un pezzo piccolo, la maniglia
  dell'anta sul lato della sala.

### Da sapere (non è un difetto)

- **Il checkpoint del portone si prende sulla soglia** (a x 19,85), prima dell'entrata nella torre (da x 21,4), col
  portone ancora aperto. Su disco il portone risulta aperto (`"aperto": true, "chiuso_dietro": false`): è il caso che
  enigmi ha corretto. Se dopo quel checkpoint si muore o si esce senza essere entrati, si riparte comunque dentro la
  torre, col portone chiuso. Mi sembra quello che si vuole.

## Non verificato

- **Gli scatti col renderer vero della chiusura vista dalla soglia.** La sala con la torre non entra nei 15 GB, nemmeno ridotta e senza il tunnel precaricato: Godot è stato ucciso per la memoria due volte (800x450 e 640x360). Al posto degli scatti c'è la misura della camera qui sopra.
- **Le righe rosa della torre** (`lavoro/righe-torre`): aspetto lo sha.

## Come

- `godot/tests/collaudo/sonda_portone.gd`, con i modi `giochi`, `salva <cartella> <subito|chiuso>`, `continua <cartella>` e `misura`.
- `godot/tests/collaudo/sonda_portone_scatti.gd`: gli scatti col renderer vero, non riusciti per la memoria.
- I log sono in `log/`.
