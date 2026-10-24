# Errori da non ripetere

Sono le correzioni che l'utente ci ha già fatto, con le sue parole. Il 24 ottobre ha scritto: "vai e non commettere gli errori che ti ho corretto nuovamente". Chi costruisce una zona controlla questo elenco punto per punto prima di consegnare, e lo stesso fa il collaudo. Vale insieme alle regole di posizionamento di `CLAUDE.md` e di `docs/tecnico/posizionamento/LEGGIMI.md`.

## Oggetti e posizionamento

- **Niente oggetti sospesi, staccati o compenetrati.** Parole sue: "basta con queste robe volanti o staccate dal resto", "valvole rosse appese al nulla", "gonfiabile azzurro incastrato nella scala. Controllare meglio che non ci siano altri oggetti compenetrati con lo sfondo"; "1 scatola e 1 estintore e 1 pompa antincendio arrotolata compenetrati con il corrimano"; "gli scivoli sono leggermente compenetrati con le piattaforme su cui si appoggiano, quasi tutti". Anche 1-2 cm sono un difetto: lo scatto ravvicinato del collaudo lo deve mostrare.
- **Anche le parti che si muovono, in tutti i loro stati.** Sulla v0.3.13: "c'è un cazzo di pallone a ciambella compenetrato con una delle ante degli armadietti all'inizio". Ante, portelli, paratie e grate si controllano chiuse, mentre si muovono e aperte, con tutto quello che hanno vicino o dentro; il controllo di posizionamento deve vederle in ogni stato.
- **Pezzi della stessa misura e attaccati.** "Non vedi che la dimensione del tubo che hai messo è completamente diversa dalla sezione con la valvola?"; "La leva inoltre gira dalla parte sbagliata e si stacca dal resto". I tubi e i cavi partono e arrivano da qualche parte, e le cose che girano (leve, volantini) girano nel verso giusto restando attaccate.
- **Ogni oggetto ha un motivo per stare lì.** "Ma è sempre davanti all'estintore! Che senso ha? Spostala da lì e quando ti correggo qualcosa non ripropormelo uguale!!". Una cosa corretta non torna uguale in un altro posto.
- **Niente cose che danno fastidio lungo la strada.** "Ci sono due salvagenti lungo il percorso nel fiume che danno un po' fastidio, spostali a bordo del fiume". Lungo la strada restano solo le cose che servono al gioco o che stanno ai bordi.
- **Pile e mucchi come starebbero davvero**, il pesante sotto, appoggiati a qualcosa.

## Modelli e superfici

- **Facce nel verso giusto.** Nella v0.3.12 le pile di scatoloni del fiume erano vuote da un lato: "manca l'interno... sono tutte sfanculate", "da una parte le scatole sono ok e dall'altra sono vuote". Si controllano sempre con i materiali veri, mai con quelli a due facce, e il test `test_multimesh_specchiati.gd` deve passare.
- **Niente oggetti piatti al posto di quelli veri.** "Lo scivolo giallo dell'area bimbi è bidimensionale, va sistemato."
- **Niente sfarfallii.** "c'è una parete buggata che flasha"; "la texture del cemento si glitcha con il muro in un punto"; "Sotto la scala poi, c'è una texture a cerchietti che è buggata e flasha un po'". Due superfici sullo stesso piano non si sovrappongono, e nemmeno l'acqua con quello che copre: "Quando finisci di aspirare l'acqua rimane un poco d'acqua che copre il portellone aperto."
- **Texture calme.** "Ci sono alcune texture di muri che mi danno fastidio perché sono troppo dettagliate"; "ci sono anche altre macchie di ruggine fastidiose". Pochi segni, poca ruggine.
- **Bordi continui.** "All'inizio del percorso in salvagente ci sono delle parti dove manca la roccia ai bordi, deve essere continua." Niente buchi e niente pezzi grigi fra un pezzo di muro e l'altro.
- **Scritte solo a disegni.** "Togli la scritta le rapide, sostituiscila con un disegno. Le scritte di Jilly Jubilee fanno eccezione"; "Però senza il cartello sopra, basta il cancello con il suo disegno". I cartelli guardano verso chi arriva ("i cartelli sono girati a cazzo di cane, devono essere rivolti verso la direzione da cui arriva il giocatore"), e numeri e disegni sono dritti, mai di lato o capovolti ("hanno le cifre anche di lato, e sono pure capovolte").

## Acqua

- **Dall'acqua si esce sempre.** "Se cadi nella piscinetta della stanza generatori non puoi uscire, la scala non funziona."
- **L'acqua da aspirare non finisce.** "Non deve essere possibile esaurire l'acqua nella stanza dei generatori"; "la piccola piscina di fronte ai tornelli deve riempirsi di nuovo se finisci l'acqua".
- **Niente vista subacquea per sbaglio.** "ci sono un paio di pezzi del tunnel dove c'è acqua e ti fa la visuale sottomarina." Se la testa è fuori dall'acqua, la vista resta normale.
- **Acqua non trasparente** dove deve nascondere qualcosa: "L'acqua non deve essere trasparente, altrimenti si vede lo stesso lei scomparire."

## Luce e guida

- **Quello che serve si vede al buio**, senza torcia: "illuminare la valvola di reset che non si vede"; "Il portellone sotto l'acqua... va reso un po più facile da notare, magari aggiungiamoci una luce"; la Polaroid 2 che al buio non si trovava; "il salvagente, che è troppo poco visibile. Va reso glow in the dark".
- **Il giocatore si sente guidato.** "Iniziamo a prestare attenzione a far sì che le persone si sentano guidate, che non debbano fare backtracking e che ci sia sempre un ambiente nuovo."
- **I momenti importanti aspettano che il giocatore li veda.** "Non l'ho vista, forse mi sono allontanato ed è sparita? Dovrebbe restare finché non la vedi bene o ti avvicini." E niente sparizioni a vista: "Il bambino pecora deve correre più veloce perché altrimenti puoi raggiungerlo e vederlo sparire dietro l'angolo."

## Personaggi

- **Lei e i mostri non attraversano niente**: né i tentacoli né il corpo, neanche nelle porte (lo squalo che si stringe alla porta tagliafuoco è un difetto noto). I test della morbidezza devono passare.
- **La camera non entra nei personaggi.** "c'è un breve momento che la telecamere passa dentro lo squalo".
- **Movimenti veloci e decisi, non goffi.** "si muove troppo lentamente e in modo goffo."

## Suoni

- **Volumi bassi.** "i suoni risultano tutti troppo alti"; "abbassiamo ulteriormente il volume, io lo tengo al 10%".
- **Niente musichette in loop**: "hai aggiunto una musichetta in loop che da molto fastidio. toglila."
- **Suoni puliti**: "Ma perché in tutti i suoni c'è un rumore di bollicine in sottofondo?"; "il suono che si sente sotto è strano, corrotto".
- Ogni suono nuovo si fa sentire all'utente prima di metterlo nel gioco.

## Prestazioni

- **Niente scatti la prima volta che succede qualcosa.** "la prima volta che ho usato sia il risucchio d'acqua, sia lo sparo... mi ha laggato il gioco per 1 secondo di freeze." I materiali e gli effetti nuovi si precaricano, come nella risalita (`tests/aggiorna_risorse_risalita.gd`).
- **Memoria video nel budget**: texture compresse (`tools/godot_vram_textures.py`) e misura con `godot/tests/collaudo/memoria_video.gd`.

## Consegne

- **Le cose grosse si fanno giuste alla prima**, controllando la coerenza con il GDD e con il resto del gioco.
- **Collaudo prima di ogni build** fatto da una squadra che non ha costruito la zona, con i materiali veri, in tutti gli stati (anche quelli che cambiano dopo: portelli chiusi, lei che sbatte, galleggianti che si muovono).
- **I link delle build vanno in chat**, per intero, nell'ultimo messaggio.
- **Una correzione non deve romperne un'altra.** Il 24 ottobre il pallone tolto dall'anta dell'armadietto è finito in mezzo al passaggio fra spogliatoi e vasca lava-piedi, e il giocatore non passava più (test_passaggi_interni rosso). Chi sposta un oggetto rifà girare i test dei passaggi della sua zona, e nessuno dice "fatto" né unisce un branch con la CI rossa.
