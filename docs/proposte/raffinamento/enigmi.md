# Raffinamento del capitolo 1: enigmi e Polaroid (proposte di enigmi, 4 novembre)

Sono solo proposte scritte: nel gioco non cambia niente finché non dai il via.
- **Niente cose nuove.** Niente stanze, enigmi o spaventi nuovi: si migliora quello che c'è.
- **Le immagini** sono tutte già nel repository, su `lavoro/godot` (22a27ce8). Non ho fatto render nuovi.
- **I suoni nuovi** te li facciamo sentire prima, come sempre.
- **Lasciata fuori** perché l'hai già decisa: lo spostamento del cartello delle pozze nel corridoio prima dell'infermeria, lontano dalla porta.

## enigmi-1 Polaroid: rivederle e contarle giuste

- **Zona:** tutto il capitolo (le 16 Polaroid) e il menu di pausa.
- **Cosa non va oggi, visto dal giocatore:**
  - Quando raccogli una Polaroid la vedi grande una volta sola, e poi non la puoi più rivedere. La storia dei bambini e di lei si capisce solo mettendo insieme le foto: chi le ha prese all'inizio non se le ricorda più.
  - Il contatore che compare ("Polaroid 3/…") ha un totale che cresce mentre vai avanti: per esempio all'inizio "1 su 5", più avanti "7 su 12", alla fine "su 16". Il gioco conta solo quelle delle zone già caricate. Sembra un errore, e non sai mai quante ne mancano.
- **Proposta:**
  - **A) (consigliata)** Un album nel menu di pausa: una griglia di 16 cornici bianche. Quelle trovate mostrano la foto, e toccandole la vedi grande come quando l'hai raccolta. Quelle che mancano sono cornici vuote, senza dire dove cercarle. Il contatore diventa sempre "n su 16". **Perché:** le Polaroid sono l'unico modo per scoprire la storia, e così si possono rileggere in ordine. Le cornici vuote invogliano a esplorare senza aiutare troppo.
  - **B)** Solo il contatore giusto, sempre "n su 16", senza album.
  - **C)** Come A, ma sotto ogni cornice vuota c'è un piccolo disegno della zona dove si trova (la sala, la risalita, la torre...). Aiuta chi vuole trovarle tutte, ma toglie un po' di scoperta.
- **Costo:** A e C medio (una schermata nuova nel menu, in italiano e inglese, anche col joypad); B piccolo. **Rischio:** basso; il salvataggio delle Polaroid prese c'è già.
- **Immagini già fatte:**
  - `docs/proposte/polaroid_nuove/foto_p12_p16.jpg` (lavoro/godot 22a27ce8): le foto delle 5 Polaroid nuove una accanto all'altra, come starebbero nell'album;
  - `godot/assets/models/polaroid/texture/P01.jpg` … `P16.jpg`: tutte le foto.

## enigmi-2 La cassaforte dell'infermeria è muta

- **Zona:** infermeria, la cassaforte a rotelle (testa, corpo, coda).
- **Cosa non va oggi, visto dal giocatore:** le rotelle girano senza nessun rumore, e quando metti il codice giusto (4-1-7) lo sportello si apre in silenzio. In una cassaforte il clic delle cifre e il colpo del chiavistello sono metà della soddisfazione. Senza, l'apertura sembra un errore della grafica più che una conquista.
- **Proposta:**
  - **A) (consigliata)** A ogni cifra un clic metallico secco, un po' diverso per ognuna delle tre rotelle. Col codice giusto: il colpo pesante del chiavistello, poi il cigolio dello sportello che si apre. Col codice sbagliato non succede niente, come in una cassaforte vera. **Perché:** dà la sensazione di girare un meccanismo vero, e premia il momento giusto senza aiutare a indovinare.
  - **B)** Come A, più un clic più pieno quando una rotella arriva sulla cifra giusta, come nei film. Rende l'enigma molto più facile: si trova il codice provando, senza la radiografia. **Sconsigliata**, visto che il cartello delle pozze ti era sembrato troppo facile.
  - **C)** Solo il suono dell'apertura, le rotelle restano mute.
- **Costo:** piccolo (tre suoni e il loro collegamento). **Rischio:** molto basso.
- **Immagini già fatte:** `docs/proposte/infermeria_luci/dopo/luce/infermeria_luce_rotelle.jpg` (lavoro/godot 22a27ce8): la cassaforte coi tre simboli dell'agnello (testa, corpo, coda) e le rotelle sullo 0.

## enigmi-3 Fiume lento: il colpo sul disco non si sente

- **Zona:** fiume lento, i dischi a strisce prima dei tre bivi e le chiuse.
- **Cosa non va oggi, visto dal giocatore:** quando colpisci col getto il disco a strisce sul palo, vicino a te non succede niente: nessun suono, e il disco resta fermo. La chiusa 12-15 m più avanti sale o scende in silenzio, e si accende la luce sul ramo aperto. Seduto sulla ciambella, con la corrente che ti porta, non sei sicuro di aver preso il disco: si continua a spruzzare, e dopo un secondo la paratia si rigira dalla parte sbagliata.
- **Proposta:**
  - **A) (consigliata)** Quando il colpo prende il disco, un colpo di lamiera, come un gong. Poi il rumore del motore e delle catene della chiusa che si muove, con un colpo sordo quando arriva in fondo: lo stesso suono delle paratie della camera delle onde, che conosci già. **Perché:** ti dice "preso" e "qualcosa si è mosso là davanti", senza dirti se era giusto. Il bivio resta da capire coi cartelli verdi d'uscita.
  - **B)** Come A, e in più il disco fa mezzo giro sul palo a ogni colpo: si vede anche da lontano che l'hai preso.
  - **C)** Come A, e in più la lampada sul palo fa un lampo bianco a ogni colpo.
- **Costo:** A piccolo (i suoni ci sono già, vanno solo collegati); B e C piccolo in più. **Rischio:** basso. Con B il disco che gira non deve nascondere la faccia a strisce a chi arriva.
- **Immagini già fatte:**
  - `docs/proposte/fiume_aspetto/fiume_A_bersaglio.jpg` (lavoro/godot 22a27ce8): il disco a strisce sul palo, lungo il canale, visto dalla ciambella;
  - `docs/collaudo/risalita/scatti/vris_Paratia1_Disco.jpg`: il disco del bivio 1 da vicino.

## enigmi-4 Un segnale unico per "fatto giusto"

- **Zona:** gli enigmi risolti: acquari, giocattoli, pozze, cassaforte.
- **Cosa non va oggi, visto dal giocatore:** ogni enigma finisce in un modo diverso.
  - agli acquari il miscuglio diventa verde e parte il motore del portone;
  - ai giocattoli c'è il risucchio degli scarichi e la luce del pulsante passa al verde;
  - alle pozze si apre la porta stagna;
  - alla cassaforte non c'è niente.

  Funziona, ma il giocatore non impara un segnale suo per "ho fatto giusto", e agli acquari il momento si confonde col motore del portone che parte.
- **Proposta:**
  - **A) (consigliata)** Lo stesso jingle giocattolo che cala del pulsante della botola, accorciato a 2-3 note, ogni volta che un enigma è risolto, dal punto dell'enigma. **Perché:** è un suono che hai già scelto. Diventa il "bravo" del parco: allegro e un po' storto, quindi inquietante, nello spirito dell'innocenza tradita. In più si impara subito.
  - **B)** Un jingle diverso per ogni enigma, quattro varianti della stessa melodia del parco.
  - **C)** Niente di nuovo: restano i suoni delle macchine, come oggi.
- **Costo:** piccolo (un suono, collegato a quattro enigmi), da farti sentire prima. **Rischio:** che sembri troppo "da videogioco": per questo lo terrei corto e un po' stonato.
- **Immagini già fatte:** `docs/proposte/enigma_giocattoli/scatto_5_luce_verde.jpg` (lavoro/godot 22a27ce8): la luce del pulsante della botola che diventa verde, il "giusto" di oggi ai giocattoli.

## enigmi-5 Giocattoli: i colori dei cerchi danno già la soluzione

- **Zona:** piscina a onde, l'enigma dei giocattoli.
- **Cosa non va oggi, visto dal giocatore:**
  - I tre cerchi sul fondo sono giallo, rosso e blu, come i tre giocattoli: paperella gialla, pallone rosso, balena blu. Basta guardarli per sapere dove va ognuno, e il disegno dei bambini sul muro non serve.
  - Come per il cartello delle pozze, la soluzione si vede subito. La parte vera dell'enigma resta spingerli col getto.
- **Proposta:**
  - **A) (consigliata)** I tre cerchi tutti dello stesso mosaico azzurro piscina, ognuno con un piccolo simbolo diverso nel mosaico: una stella, un'onda, una conchiglia. Il disegno dei bambini mostra ogni giocattolo sul suo simbolo, e per capire dove va ognuno bisogna guardare il disegno. **Perché:** il disegno diventa l'indizio, come agli acquari e alle pozze. L'enigma resta corto, ma un po' meno ovvio.
  - **B)** Cerchi colorati, ma coi colori scambiati: la paperella va sul cerchio blu, e il disegno lo mostra. **Sconsigliata**: sembra un trucco, e chi non guarda il disegno pensa che il gioco sbagli.
  - **C)** Lascia così: i colori aiutano chi gioca per la prima volta a capire la regola, e la difficoltà sta nello spingere.
- **Costo:** piccolo-medio (il disegno e il mosaico dei cerchi sono fatti da codice, vanno cambiati e ricontrollati, e il test va aggiornato). **Rischio:** basso. Il bordo che si accende quando il giocattolo è sul cerchio giusto resta, ed è la conferma.
- **Immagini già fatte** (lavoro/godot 22a27ce8):
  - `docs/proposte/enigma_giocattoli/disegno_vicino.jpg`: il disegno dei bambini sul muro, coi tre giocattoli nei cerchi colorati;
  - `docs/proposte/enigma_giocattoli/scatto_3_piatti.jpg`: i cerchi sul fondo intorno alla botola.
