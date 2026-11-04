# Raffinamento del capitolo 1: proposte di grafica-2

Solo proposte: nel gioco non è cambiato niente. Non ci sono render né scatti nuovi, solo immagini già fatte.
Ho tenuto fuori le cose già decise o bocciate: altri spaventi con lei, la luce blu dagli oblò, la nebbia viola, i teli della sala ("così") e la luce sui poster rovinati (B). Le lampade non si toccano: nessuna proposta cambia una luce.

## grafica2-1 Luminosità all'inizio: una prova sul gioco vero

**Zona**: la schermata "Luminosità" al primo avvio (si riapre dalle opzioni).

**Cosa non va oggi, visto dal giocatore**: la schermata c'è già e compare da sola al primo avvio. Però si regola su tre simboli grigi su fondo nero, che non somigliano al gioco. Chi gioca su uno schermo scuro, o di giorno con la luce in stanza, la sistema "giusta" e poi nei punti più bui vede nero pieno. Succede nel corridoio degli scatoloni (tratti 2 e 3) e al bivio 1 dell'anello, dove un pixel su dieci è a 0,1 su 255. Chi ha uno schermo chiaro, invece, vede lo stesso corridoio molto più luminoso. È il caso del corridoio degli scatoloni: due giocatori possono vedere due giochi diversi.

**Proposta**:
- **A) Sotto i tre simboli, una seconda prova con un'immagine vera del gioco** (consigliata). È uno scatto già fatto del corridoio delle pile al 20%, schiarito o scurito col cursore come il resto. La regola è facile: "regola finché vedi appena la scatola in fondo". La luce del gioco non cambia: cambia solo come il giocatore regola il suo schermo, e lo fa guardando il gioco vero. Così il buio arriva a tutti come lo vuoi tu.
- B) Si tengono solo i tre simboli, ma più vicini al buio vero del gioco: il simbolo più scuro scende da 2 su 255 a meno di 1, come il buio del corridoio 2. Costa meno, ma resta una prova astratta.
- C) Resta com'è.

**Costo**: piccolo, solo la schermata. **Rischio**: basso. Lo scatto va preso col preset di serie, o diventa un'altra misura. Chi ha già regolato non la rivede, se non dalle opzioni.

**Immagini già fatte**:
- `docs/report/corridoio_20/foglio_pile_sfalsate_20.jpg` (branch `lavoro/corridoio-20`, 07dabc0c): il corridoio delle pile come è ora, al 20% con le pile sfalsate. Da qui si sceglierebbe l'immagine della prova.
- `docs/report/scatoloni_0319/foglio_scatoloni.jpg` (`lavoro/nebbia-0317`, 9e6a926d): lo stesso corridoio nelle versioni dalla 0.3.15 alla 0.3.19.

## grafica2-2 Segni fosforescenti nei punti neri della strada

**Zona**: fiume. I tratti 2 e 3 del corridoio degli scatoloni, il bivio 1 e il bivio 3 dell'anello.

**Cosa non va oggi, visto dal giocatore**: con le lampade al 20% questi punti sono quasi neri. Il buio va bene ed è voluto, ma al bivio non si vede da che parte andare, e nelle pile non si vede dove finisce il passaggio. Il GDD vuole un giocatore "che si sente guidato". Nella torre degli scivoli la via giusta si vede con frecce disegnate e luci verdi.

**Proposta**:
- **A) Pochi segni fosforescenti del parco, come il salvagente dell'approdo** (consigliata). Sono strisce verde chiaro sul bordo della passerella e una freccia disegnata, senza scritte, su una pila o su una roccia al bivio giusto. Brillano poco, come il salvagente: si vedono nel nero ma non illuminano niente attorno, quindi il buio resta quello di ora. In tutto 4 o 5 segni. È lo stesso linguaggio della torre (frecce disegnate) e del salvagente (fosforescente), quindi è coerente col resto.
- B) Piccole spie verdi sulla via giusta, come le luci verdi della torre. Si vedono meglio, ma sono luci nuove: illuminano un po' quello che hanno attorno, e il buio di quei punti cambia.
- C) Resta com'è: il buio è la difficoltà.

**Costo**: piccolo. **Rischio**: basso. Le frecce gialle a terra in C2 erano state tolte perché portavano al magazzino chiuso: queste vanno messe solo sulla strada giusta, e controllate col posizionamento e col collaudo.

**Immagini già fatte**:
- `docs/report/corridoio_20/foglio_anello_20.jpg` (`lavoro/corridoio-20`, 07dabc0c): l'anello prima e dopo le lampade al 20%. Al bivio 1 e al bivio 3 si vede quanto sono neri.
- `docs/report/corridoio_20/foglio_corridoio_20.jpg` (stesso branch): i tratti 1-4 del corridoio delle pile al 20%.

## grafica2-3 Volantini della crociera e stile dei poster

**Zona**: tutte le zone con muri del parco: sala, corridoi, bagnino, infermeria, approdo del fiume.

**Cosa non va oggi, visto dal giocatore**: nel GDD è ancora aperto "i poster si vede che sono generati con l'IA: serve un altro stile". Ci sono anche i piccoli volantini della crociera "da fare più avanti". I poster rovinati coprono molto, ma dove sono interi si vede ancora lo stile IA. I muri lontani dai poster sono vuoti e tutti uguali.

**Proposta**:
- **A) Volantini piccoli in uno stile solo: stampa a 2-3 colori anni '80-'90, coi colori di Jilly** (consigliata). Un disegno per evento, senza scritte: lo spettacolo di Jilly, la gara di scivoli, la festa in piscina, il buffet. Sono invecchiati come il logo, cioè scoloriti, strappati e attaccati col nastro. Ne vanno 10-15 in tutto il capitolo, dove il giocatore si ferma (bacheche, porte, vicino ai pulsanti ma senza coprirli). Lo stesso stile fa da guida per rifare poi i poster grandi interi. Si comincia in piccolo e si vede subito se ti piace.
- B) Si rifanno subito anche i poster grandi interi nello stile nuovo. È più coerente, ma è molto lavoro su cose già approvate rovinate.
- C) Solo i volantini, ognuno nello stile del suo poster vicino.

**Costo**: medio, con le texture e il posizionamento. **Rischio**: basso. Vanno tenuti lontani da Polaroid, cartelli degli enigmi e pulsanti, perché non si confondano con gli indizi.

**Immagini già fatte**:
- `docs/proposte/poster_rovinati/confronto_bagnino.jpg`, `confronto_manifesto.jpg`, `confronto_cartellone.jpg` e `confronto_infermeria.jpg` (`lavoro/godot`, 22a27ce8): i poster di Jilly prima e dopo averli rovinati. Dove sono interi si vede lo stile di oggi.

## grafica2-4 L'occhio che si abitua al buio

**Zona**: i passaggi da una zona illuminata a una buia. Per esempio dall'infermeria al corridoio, dalla piazza del fiume al corridoio delle pile e dall'approdo al tunnel.

**Cosa non va oggi, visto dal giocatore**: quando si passa da una stanza chiara a una buia, il buio è subito lo stesso, come se gli occhi fossero già abituati. Il passaggio è piatto. Le differenze ci sono: l'infermeria al lettino ha una luminosità media di 37 su 255, il corridoio 2 delle pile di 8.

**Proposta**:
- **A) Solo entrando nel buio: per 2-3 secondi l'immagine è un po' più scura, poi torna come oggi** (consigliata). È come l'occhio che si abitua. Alla fine la luce è esattamente quella di ora: nessuna lampada cambia, e lo si controlla con gli scatti di prima e dopo. Il momento in cui entri nel buio diventa più teso.
- B) Si abitua in tutti e due i sensi: anche uscendo nella luce si è abbagliati per un attimo. È più realistico, ma per un attimo è più chiaro di oggi, e il buio l'hai sempre voluto così.
- C) Resta com'è.

**Costo**: medio, con l'esposizione della camera e le misure. **Rischio**: medio. Va misurato bene, perché non diventi "di nuovo più luminoso" a regime. Se non ti piace in prova si spegne con un'opzione.

**Immagini già fatte**:
- `docs/report/luminosita_0316/foglio_luminosita.jpg` (`lavoro/nebbia-0317`, 9e6a926d): piscina, tunnel, infermeria e acquari a confronto. Si vede la differenza fra stanze chiare e buie.
- `docs/report/corridoio_20/foglio_corridoio_20.jpg` (`lavoro/corridoio-20`, 07dabc0c): il corridoio delle pile, cioè il buio in cui si entra dalla piazza.
