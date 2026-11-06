# Ricontrollo di grafica-2: angolo corretto (lavoro/ritocchi-mascotte a17def48)

Il branch contiene la pila nuova di ambienti-1 (fino a 35149413) e la fuga del bambino di mascotte. Ho guardato:
- la Risalita della scena di prova, col renderer vero e le luci del blackout;
- i raggi sulle collisioni del gioco;
- i video dagli occhi a 30 fotogrammi al secondo.

Gli scatti ravvicinati della pila hanno una luce tecnica sulla camera, che nel gioco non c'è.

## Esito

| cosa | esito |
|---|---|
| Pila: appoggiata | 37 unità, la più bassa a 0 mm dal pavimento; collisione 1,2 x 5,4 x 1,0, di traverso, base a 0 |
| Pila: contro il muro nord | le scatole arrivano a z -28,598, il muro sta a -28,600: 2 mm. Collisione a 6 mm, uguale in 12 punti da 0,2 a 4 m d'altezza. Negli scatti radenti e sullo spigolo, in basso e in alto, è attaccata |
| Fessura fra pila e muro | non c'è più |
| Nicchia: il fondo, dove sparisce il bambino | non si vede da nessuna delle 22 posizioni (le mie di prima, la soglia, da 1 a 6 m, di lato, accucciati e 12 punti di corsa fino a -10,4; 65,0): 0 punti visibili fra z -28,55 e -28,2 |
| Nicchia: la bocca | dalla strada si vede il bordo, la fila di punti a 10 cm dentro (z -27,5) e, da un solo punto della corsa, quella a -27,85: 3-12 punti su 48 per posizione. È l'apertura fra la pila e il muro dell'approdo, non il fondo |
| Pile dal file | uguali a quelle costruite, compresa la pila dell'angolo: 7.114 righe uguali byte per byte |
| test_bambini_sfuggita | 75/75, dopo l'import dei passi nuovi (senza import: 72/75 per i file dei passi mancanti) |
| Inseguimento fino alla soglia | visto l'ultima volta al fotogramma 210, sparisce al 257 (47 fotogrammi dopo) |
| Inseguimento 1 m dentro | 229 e 257 (28 fotogrammi) |
| Inseguimento 2 m dentro | 234 e 257 (23 fotogrammi) |
| Di corsa fino in fondo alla strada (-10,4; 65,0) | 238 e 258 (20 fotogrammi) |
| Ripartenza a fuga cominciata (BambinoSfuggita.load_state, come il ritorno al checkpoint) | torna in attesa, nascosto, esattamente al suo posto (0,000 m) e con l'animazione da fermo; poi ricompare, guarda e scappa da capo fino a sparire |
| Piedi dopo la ripartenza | correndo, i piedi a terra scivolano in media di 0,17 m/s (84 misure; il test dei bambini ammette fino a 0,3); il massimo di 2,2 m/s è un fotogramma allo stacco |

## Fogli
- `foglio_angolo_a17.jpg`: dalla soglia e dalla strada; la pila dall'alto, radente al muro nord, spigolo basso e alto, piede sud, base; la nicchia da dentro e il suo fondo.
- `foglio_inseguimenti_a17.jpg`: i quattro inseguimenti, dall'ultima volta che il bambino si vede alla sparizione.
- `foglio_ripartenza_a17.jpg`: la ripartenza: prima, subito dopo (corridoio vuoto) e la fuga di nuovo.
