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
- **Le texture del gioco si importano compresse per la scheda e con le mipmap, mai "Lossless".** Godot senza editor importa le immagini nuove in Lossless senza mipmap, e `tools/godot_vram_textures.py` converte solo quelle estratte dai GLB. Così il 29 ottobre le foto delle Polaroid P11-P16 si decodificavano sulla CPU nel fotogramma in cui entravano: il passo delle Polaroid nella torre a pezzi passava da 9 a 331 ms e test_attesa_zone era rosso. La P11 era già così nella 0.3.15. Chi aggiunge un'immagine al gioco la importa VRAM Compressed con le mipmap (le normal map come normal map); Lossless resta solo per interfaccia e scritte a schermo.
- **Un raggio solo non basta per trovare il fondo.** Il test raggio-triangolo di Jolt non è a tenuta: un raggio a meno di ~0,002 mm da un lato condiviso fra due triangoli passa nella crepa. Il 29 ottobre il pallone dell'enigma, spinto lungo x = 0 (a 1e-16 dalla giunzione del fondo della piscina), trovava il soffitto della camera delle onde 2,4 m più sotto e ci cadeva; poi, col raggio che partiva da lui, restava giù per sempre e l'enigma non si finiva più. Chi cerca un fondo o un appoggio parte dall'alto con una distanza limitata, lancia più raggi spostati di pochi millimetri e prende il più alto valido, e mette una rete di sicurezza anche nel ripristino da checkpoint. Il giocatore e i corpi con una forma non sono toccati.
- **I collaudi costruiscono le zone come il gioco**: a pezzi e col riscaldamento (`RISCALDA=1` per la schermata di caricamento, `RISCALDA=tunnel` per il tunnel). Il 29 ottobre le 10-15 compilazioni "alla prima curva" del tunnel e la pipeline rimasta all'oblò del personale c'erano solo nelle prove che costruivano tutto subito senza riscaldamento: nel gioco vero erano 0, e si è perso tempo a cercarle.

## Consegne

- **Le cose grosse si fanno giuste alla prima**, controllando la coerenza con il GDD e con il resto del gioco.
- **Collaudo prima di ogni build** fatto da una squadra che non ha costruito la zona, con i materiali veri, in tutti gli stati (anche quelli che cambiano dopo: portelli chiusi, lei che sbatte, galleggianti che si muovono).
- **I link delle build vanno in chat**, per intero, nell'ultimo messaggio.
- **Una correzione non deve romperne un'altra.** Il 24 ottobre il pallone tolto dall'anta dell'armadietto è finito in mezzo al passaggio fra spogliatoi e vasca lava-piedi, e il giocatore non passava più (test_passaggi_interni rosso). Chi sposta un oggetto rifà girare i test dei passaggi della sua zona, e nessuno dice "fatto" né unisce un branch con la CI rossa.
- **Un push di soli documenti su un branch con la CI in corso va con [skip ci].** Il 25 ottobre un jpg aggiunto sul branch degli oblò ha cancellato la CI a metà e l'ha fatta ripartire da capo: 30 minuti persi.
- **I collaudi dei movimenti si fanno con `--fixed-fps 60`.** Senza, su llvmpipe un fotogramma della torre vale più di un secondo di gioco, e un distacco lento di 2,6 s sembrava una sparizione (D5, 25 ottobre).
- **Le vasche e gli spazi nascosti si chiudono anche da fuori.** Con le facce solo verso dentro, da una fessura del pavimento si vedeva dentro la vasca di lei (D7, 25 ottobre). I calcoli pesanti su una mesh grande si fanno una volta e si salvano, non mentre si costruisce la zona (oblò della torre oltre i 100 ms per fotogramma).
- **Ai problemi segnalati si lavora subito, senza chiedere log.** Il 25 ottobre, sulla v0.3.14, l'utente ha segnalato blocchi al primo avvio, un crash dopo il primo spavento e il Continua che mancava, e gli sono stati chiesti i log e dove succedeva. Risposta: "Non ti do log e quando ti segnalo un problema devi lavorarci immediatamente senza aspettare altro da me".
- **Una scelta non toglie le cose ovvie.** Aver scelto il menu nascosto F9 (B) al posto del Continua (A) per le prove non voleva dire niente Continua nel gioco: "ciò non significa che non ci debba essere continua sul menu, ovviamente!!".
- **I test devono fare il caso vero.** test_tappa8 saltava la sequenza della presa, quindi il crash dopo lo spavento intero non poteva vederlo.
- **Un problema nuovo si cerca prima in quello che è appena stato aggiunto.** I blocchi della v0.3.14 sono comparsi insieme agli oblò con lei, che la caricavano e la riscaldavano nel fotogramma in cui compare. L'utente: "Ci potevi arrivare anche da solo eh. Te li ho segnalati subito dopo che abbiamo aggiunto questa feature". E le misure dei blocchi si fanno col renderer vero, non solo senza disegno: il riscaldamento di lei headless non girava.
- **Chi cambia un passaggio sistema anche i test che lo attraversano.** Il 28 ottobre test_presa_vera (il crash dopo lo spavento, su lavoro/blocchi) passava dalla porta nord dell'infermeria, che su lavoro/porta-infermeria resta chiusa fino al pulsantone: presi da soli i due branch erano verdi, uniti la CI d'insieme è diventata rossa e la build è slittata di due ore. Chi chiude o sposta un passaggio cerca nei test il nome della zona e sistema quelli che ci passano, nello stesso branch.
- **Gli strati di rendering stanno in un elenco unico.** Fra il 25 e il 27 ottobre lo strato di preparazione è stato messo prima sullo stesso dell'acqua (1<<19) e poi su quello delle lampade dell'infermeria (1<<17). Ora è 1<<15, e test_strati fallisce se due costanti usano lo stesso strato. Quelli in uso: 2 la lancia in mano, 1<<15 preparazione, 1<<16 squalo, 1<<17 lampade dell'infermeria, 1<<18 interno della piscina, 1<<19 acqua, tempesta e geyser.
- **Le luci cambiano solo il loro strato, mai la cull mask.** Cambiare light_cull_mask a una luce nascosta lasciava nel motore abbinamenti sbagliati fra luci e mesh: "ERROR: BUG, indexing did not unpair geometries from light" e poi un crash all'uscita (signal 11), sugli oblò il 27 ottobre. Ora tools/ci/senza_bug.sh fa fallire la CI a ogni riga "ERROR: BUG,".
- **Poche squadre alla volta.** Il 25 ottobre verso le 23:00 UTC, con tutte e sette le squadre al lavoro insieme, si è esaurito il limite settimanale dell'account: tutto fermo fino al 28 sera e la build 0.3.15 non è uscita. Si lavora con 2-3 squadre alla volta e pochi subagenti, salvo scelta diversa dell'utente.
- **Il coordinatore segue la CI con un timeout lungo** (2 ore): con quello di base di 30 minuti i controlli in background venivano fermati prima della fine della CI, e l'esito arrivava tardi.
- **La CI ha un limite di tempo, e i test lo consumano.** Il 30 ottobre la CI d'insieme di lavoro/godot arrivava a 117 minuti su 120: i branch con un test in più venivano annullati durante l'esportazione, e la build di main del mattino dopo avrebbe fatto lo stesso, senza Release. Il limite del job è passato a 180 minuti (lavoro/godot 70ebf363). Il coordinatore guarda quanto dura la CI d'insieme a ogni unione: sopra i due terzi del limite, si alza il limite o si accorciano i test più lunghi (il primo uso con l'ingresso nella torre da solo prende 33 minuti, il posizionamento 15).
