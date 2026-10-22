# Controllo di posizionamento: istruzioni per le squadre

Il controllo cerca da solo gli oggetti messi male (regola dell'utente del 21 ottobre). Gira nella CI a ogni push e fallisce solo se trova un caso **nuovo**, cioè uno che non è nel file delle eccezioni.

## Lanciarlo in locale

Da `godot/`, con il lock come ogni Godot:

```
flock /home/user/tools/render.lock godot --headless --path . --fixed-fps 60 --script res://tests/run.gd -- res://tests/controllo_posizionamento.gd
```

Ci mette circa 30 secondi e usa 2,5 GB. Per controllare una sola scena aggiungi in fondo il nome del file: `sala_principale` oppure `sala_torre`. Le zone nuove si aggiungono alla lista `ZONE` in cima a `godot/tests/controllo_posizionamento.gd`. L'ultima riga dice `RISULTATO: ... 0 falliti` se non ci sono casi nuovi.

## Leggere il rapporto

Il controllo riscrive `docs/tecnico/posizionamento/rapporto.md`, con una tabella per zona: squadra, problema, nodo, posizione (x, y, z nel mondo) e dettaglio. Prima vengono i casi nuovi, poi quelli già noti, infine le eccezioni che non trova più. I problemi sono:

- **sospeso**: l'oggetto non ha niente a meno di 5 cm. Nessun pavimento, parete o soffitto, nessun altro oggetto o filo a cui sia attaccato.
- **ingombro**: qualcosa di visibile, con o senza collisione, a meno di 10 cm dall'asse del giocatore, fra 0,35 e 2 m sopra un pavimento dove si passa a piedi partendo dai checkpoint. Il dettaglio dice se è all'altezza delle gambe, del busto o della testa.
- **compenetrato**: una Polaroid, un pulsante, una porta, un cancello o un oggetto da raccogliere entra dentro un altro oggetto.
- **coperto**: lo stesso tipo di oggetto non si vede da nessuno dei punti di vista vicini, a 1-1,8 m all'altezza degli occhi. Conta anche un foglio appoggiato sopra. Il dettaglio dice cosa lo copre.
- **compenetra**: un oggetto di scena ne attraversa un altro.
- **estremita_libera**: un tubo, un cavo o una condotta ha un capo che non tocca niente.

## Dopo una correzione

Rilancia il controllo. Il caso finisce in fondo al rapporto, fra le eccezioni non più trovate: togli la sua voce da `godot/tests/posizionamento_eccezioni.json`.

## Segnare un caso come voluto

Se un caso è voluto, per esempio una porta aperta dove non si passa o il tubo del neon dentro la sua plafoniera, cerca la sua voce in `godot/tests/posizionamento_eccezioni.json`. Se è nuovo, copiala da `rapporto.json`. Poi cambia `stato` in `"voluto"` e scrivi in `motivo` perché va bene così:

```json
{"zona": "interni", "nodo": "Interni/Ambienti/Stanzino/porta_stanzino", "squadra": "ambienti-1",
 "problema": "ingombro", "pos": [0.53, 0.0, 32.25], "stato": "voluto",
 "motivo": "la porta resta aperta contro il muro, il giocatore non ci passa"}
```

Un caso si riconosce da zona, nodo e problema. I nodi creati da codice hanno nomi automatici, come `@MeshInstance3D@217`: per loro conta anche la posizione, arrotondata a mezzo metro. Le voci con stato `"da correggere"` sono casi noti, già assegnati: la CI non fallisce per loro.
