# Documento di progetto (GDD)

Titolo: **Jilly Jubilee** (scelta dell'utente, 22 ottobre: "Sì, chiamiamolo Jilly Jubilee"), come la mascotte. Prima era "Splash Lagoon", che resta il nome provvisorio del parco nel gioco. Il logo è **A, l'insegna del parco rovinata** (scelta dell'utente, 22 ottobre: "Senti usiamo l'A di prima", dopo il secondo giro D/E/F): "Jilly" in corsivo corallo e "JUBILEE" in oro su un nastro blu, con stelle e una piccola medusa, come insegna, targa e manifesto del parco, ma con lo smalto saltato fino alla ruggine, colature e crepe. Va nella schermata del titolo com'era nella prova che ha visto (`titolo_a.jpg`, in alto a sinistra sopra "Capitolo 1 · demo" e il menu). Scartati: B anni '90 e C horror del primo giro, D neon, E titolo da film e F disegno a pastelli del secondo giro. Le voci segnate **Da decidere** vanno proposte all'utente, con immagini o render e 2-3 opzioni, prima di andare avanti.

## Regola d'oro

Le scelte di **stile, trama e design** le decide l'utente: si preparano proposte e si aspetta il suo via, soprattutto all'inizio. Il lavoro tecnico (strumenti, pipeline, codice, ottimizzazione) si può fare liberamente.

## Genere e riferimenti

- Horror in prima persona del genere "mascot horror": Poppy Playtime capitolo 1, FNAF, Garten of Banban.
- L'idea di fondo è l'innocenza tradita: un posto fatto per far felici i bambini, con mascotte simpatiche, diventa una trappola.
- Gioco a sé, per PC, fatto con Godot 4. Modelli creati con Meshy (API) e Blender (script `bpy`).

## Ambientazione (decisa)

- Una **nave da crociera per famiglie** anni '90, abbandonata.
- **Capitolo 1**: l'**acquapark coperto** della nave.
- Per i capitoli successivi sono stati proposti teatro, club dei bambini e sala macchine (**da decidere**).

## Stile visivo (deciso)

- Base: **stile A, realistico e cupo** (`docs/concept/ambiente_A_realistico.jpg`). Luci d'emergenza rosse, neon che sfarfallano, nebbia bassa, piastrelle bagnate, ruggine, vernice scrostata, cupola di vetro con il mare in tempesta di notte.
- Ci vanno sopra i **giocattoli e i cartelloni colorati e saturi dello stile B** (`docs/concept/ambiente_B_colorato.jpg`): ogni tanto spunta un colore allegro, e inquieta di più.
- Anche lo **stile C**, anni '90 con pastelli sbiaditi (`docs/concept/ambiente_C_anni90.jpg`), va bene per alcune zone.
- L'atmosfera la fanno soprattutto **luci, nebbia e post-processing**, e l'utente è d'accordo.
- **L'acqua deve essere resa benissimo** (lo ha chiesto l'utente): riflessi, trasparenza, caustiche, schizzi, superfici bagnate, livello che sale e scende davvero.

## Trama (decisa)

- Il giocatore **si sveglia a bordo**, senza spiegazioni e senza prologhi lunghi. Il mistero resta.
- I nomi proposti finora sono la nave *Jubilee*, la compagnia *Wonderwave Cruises* e l'acquapark *Splash Lagoon*. Sono **provvisori**: l'utente non li ha confermati.

### Lore nascosta (decisa dall'utente)

- La crociera **è naufragata**.
- **Un gruppo di bambini** a bordo è sopravvissuto, cavandosela da solo.
- **Un mostro marino ha preso possesso della bambola-mascotte** (la nostra medusa) e negli anni **li ha cresciuti e allevati**.
- Il gioco non la racconta in modo esplicito. Si scopre **solo in parte** con le Polaroid da collezione: nel capitolo 1 ce ne sono 10, e insieme non rivelano tutto.

### Creature minori: i bambini (decise dall'utente, aspetto da decidere)

- Sono i bambini cresciuti dal mostro, e compaiono **già nel capitolo 1**, magari solo **viste di sfuggita**.
- **Da decidere**, con proposte all'utente: aspetto, quanti sono, che età hanno ora, cosa fanno, dove e come si vedono nel capitolo 1.
- Vincoli fissi: sempre vestiti, niente nudità, niente gore e niente violenza esplicita sui bambini. Fanno paura con la postura, le maschere, gli occhi e il modo di muoversi.
- **Primi due bambini (decisi dall'utente, 14 ottobre)**, ispirati ai disegni di Maniani (l'utente dichiara di avere i diritti) ma nel nostro stile marittimo. Modelli in `assets_src/bambini/`.
  - **Il bambino col cubo**: in testa ha un cubo di **piastrelle da piscina** crepato, con cirripedi e alghe e una faccina carina disegnata. Quando si rivela, il cubo si apre e mostra una massa di tentacoli rosa traslucidi con **occhi gialli**. Il primo corpo era "troppo pacioccone". Rifatto il 15 ottobre: bambino magro di 7-9 anni, un po' curvo, con una muta da sub consumata (render inviato all'utente, in attesa di riscontro; il primo corpo è in `scartati/`).
  - **L'agnellino**: un peluche cucito, zuppo e macchiato di sale, con bottoni d'ottone al posto degli occhi e un fiocco alla marinara. Quando si rivela, il muso si spacca e mostra **un unico grande occhio**, scelto dall'utente. La testa di lupo resta solo come alternativa.
  - **Idea dell'utente (17 ottobre), da sviluppare**: la medusa ha modificato l'agnellino con i suoi geni e ora brilla al buio, come le pecore vere rese fluorescenti con un gene di medusa. Scelta del 18 ottobre: **variante B**, tutto il pelo brilla a chiazze del rosa dei tentacoli, più forte sul muso. Con la torcia addosso non si nota.

## Qualità grafica: prima di tutto (deciso dall'utente, 15 ottobre, dopo aver giocato la v0.2.0)

- **Non si fanno altri ambienti finché la qualità non è quella giusta.** Si lavora su un pezzo campione (corridoio del risveglio, zona davanti allo stanzino dei bagnini con il tornello) finché l'utente non lo approva; poi si porta tutto allo stesso livello.
- **Pezzo campione approvato dall'utente (15 ottobre)**: il "dopo" del confronto (modelli Meshy di ambienti-1 più la luce nuova di grafica, `docs/report/render_grafica/campione/combinato_*.jpg`). "Belle le luci e anche le grafiche". Lo giudicherà meglio in gioco. Questo è il livello minimo per tutto il resto: ora si porta la sala principale allo stesso livello, poi si va avanti con gli ambienti nuovi.
- **Grana della pellicola e glow spenti di serie** (deciso dall'utente giocando la v0.2.1, 15 ottobre): li ha spenti e gli piace di più. Restano attivabili dalle opzioni.
- Bocciato nella v0.2.0: forme troppo squadrate, texture che si ripetono troppo (soprattutto nel corridoio), tornello in bassissima definizione. I modelli devono essere di qualità vera: per oggetti e arredi si usa Meshy ad alta risoluzione, come deciso all'inizio.
- Luce e immagine: l'immagine è offuscata e piatta. Servono ombre, profondità, antialiasing nitido, profondità di campo e l'atmosfera giusta.
- La luce della torcia è troppo forte e brutta: va studiata diversamente.
- I poster si vede che sono generati con l'IA: serve un altro stile (da decidere più avanti).
- **Da fare più avanti (richiesta dell'utente, 16 ottobre)**: i poster grandi, e anche dei piccoli volantini da mettere in giro sulle pareti, con gli eventi e i manifesti della crociera. Stile e contenuti si propongono all'utente.

## Principi di livello (deciso dall'utente, 15 ottobre)

- **Il giocatore deve sentirsi guidato**: obiettivi chiari e oggetti da usare ben segnalati.
- **Niente backtracking**: non si torna indietro per strade già fatte.
- **Sempre un ambiente nuovo**: dopo ogni parte si entra in un posto mai visto, per esempio passando un cancello importante rimasto chiuso fino a quel momento.
- Le risposte al questionario del 15 ottobre sono in `docs/riscontri/2026-10-15_questionario.md`.
- **Ambienti nuovi pieni da subito** (17 ottobre): ogni ambiente nuovo si fa già pieno e credibile dalla prima proposta, tenendo conto di tutte le correzioni fatte finora. Niente prop messi in modo insensato: niente oggetti appesi al nulla o storti rispetto al muro, niente compenetrazioni, niente oggetti davanti a quello che devono lasciare libero, niente ripetizioni evidenti.

## Scelte del 16 ottobre (pagina delle proposte)

Risposte complete, con le note parola per parola, in `docs/riscontri/2026-10-16_proposte.md`.

- **Torcia**: sincronizzata con lo sguardo, cono di 40°, luce più uniforme. Approvata, ma l'utente la vuole rivedere in gioco.
- **Interni**: approvati il vetro del primo pulsante con le crepe e la turbina nuova del cancello. **Da rifare**:
  - la lamiera vicino all'estintore va tolta di lì del tutto;
  - le valvole rosse vanno sul tubo con lo stesso diametro della sezione con la valvola.
- **Sala principale**: approvati il soppalco tolto (neon, fari e cartelloni sulle pareti) e il cordone chiuso tutto intorno alla vasca della medusa, con un muro invisibile alto 2,5 m.
- **Medusa**:
  - approvate le 17 file di denti dentro la bocca;
  - l'occhio che si chiude (easter egg, circa 5 secondi quando le spruzzi la faccia) ha una palpebra sola che scende dall'alto, come negli occhi delle bambole;
  - voce della tappa 8: la versione gutturale.
- **Area bimbi**: disposizione 1. La struttura sta nell'angolo con la scala verso chi arriva, lo scivolo scende nella vasca piccola e due funghi sono nella piazza.
- **Piscina a onde (tappa 5)**:
  - si svuota con lo zaino in circa **30 secondi, 4 zainate**;
  - l'acqua sparata dentro la vasca ci torna, quindi va sparata fuori;
  - niente scritte a schermo;
  - l'acqua resta torbida com'è, ma ci nuotano **micro medusine luminose di vari colori** che attirano l'attenzione: si aspirano con l'acqua e si sparano via;
  - pulsante della botola: versione A, un fungo rosso su una cassetta gialla con il lampeggiante giallo, che diventa verde quando lo colpisci.
- **Sala pompe**: approvati la leva nuova, il cavo dalla leva al chiavistello, i tubi colorati dalle turbine alla chiusura stagna e lo schermo della TV appoggiato sul vetro.
- **Tappa 7**: dopo la sala pompe si risale dal **magazzino dei gonfiabili** (proposta B). Si esce da una serranda nell'angolo sud-ovest della sala e la scia va lungo il muro fino all'area bimbi.
- **Tappa 8**:
  - lei resta affacciata finché non la guardi bene per 2 secondi (entro 18°, a meno di 14 m, senza ostacoli), poi dopo 6 secondi scivola sotto;
  - la scia e la bava rosa sono **visibili al 75%**, cioè un po' trasparenti.
- **Suoni nuovi** (seconda pagina dello stesso giorno):
  - piscina che si svuota: gorgo;
  - pulsante della botola: richiamo, con un jingle giocattolo che cala e un bi-bu insieme al lampeggiante;
  - micro medusine: tintinnii di vetro;
  - portone: motore e rulli.
  L'utente ha notato le bollicine nel fondo della pioggia sulla cupola: si tolgono.
- **Ritocchi approvati (terza pagina)**:
  - il portone della torre si apre da solo dopo la tappa 8;
  - le micro medusine vanno bene così;
  - la pioggia resta senza bollicine;
  - i passi bagnati non hanno più le goccioline.
- **Dopo la tappa 8**: la sala della torre è dietro la parete est (versione 2). Si entra da un portone scorrevole con la torre dipinta e le bande a strisce, **senza il cartello sopra**. L'interno della sala, gli scivoli nuovi e i bambini della balconata si propongono a parte.

## Prova della v0.3.1 (16 ottobre)

L'utente ha giocato la v0.3.1. Il messaggio completo, parola per parola, è in `docs/riscontri/2026-10-16_prova_v031.md`. Le sue richieste:
- **Vaschetta lava-piedi davanti ai tornelli**: si riempie di nuovo quando la svuoti.
- **Portellone della piscina a onde**: deve notarsi di più, per esempio con una luce che si veda attraverso l'acqua. A piscina vuota deve restare all'asciutto.
- **I due cancelli stagni dopo la scala**: si aprono da soli al tuo passaggio, con un suono metallico forte.
- **Stanza dei generatori (sala pompe)**: l'acqua lì non si esaurisce mai. La scaletta della vasca deve far risalire.
- **Serranda di sud-ovest (tappa 7)**: resta chiusa finché non risali dal magazzino.
- **Strada di risalita**: è troppo vuota e brutta. Va arredata, con un'apparizione dei bambini mostriciattoli. Prima si mostra all'utente.
- **Scia di bava (tappa 8)**: parte dalla vasca centrale della sala, dove la medusa stava affacciata.
- **Medusa nella fossa dell'area bimbi (tappa 8)**: è già affacciata quando arrivi. Nel jumpscare guarda la camera da qualsiasi lato ti avvicini.

## Lo zaino (scelte del 16 ottobre, quarta pagina)

- **Getto**: B, "potenziata". Prima di partire c'è una carica di 0,35 s in cui la lancia trema, poi un getto grosso con rinculo e un ventaglio di spruzzi all'impatto. L'aspirazione è una colonna d'acqua che si torce fino all'ugello. Suoni della versione B.
- **Lancia**: C1, industriale, arancio antincendio e giallo, tenuta con **una mano**. Sopra la canna c'è la finestrella con il livello del serbatoio.

## Prova della v0.3.2 (16 ottobre)

L'utente ha giocato la v0.3.2. Le sue parole, punto per punto, sono in `docs/riscontri/2026-10-16_prova_v032.md`. Le richieste sono queste:
- **Musichetta in loop**: va tolta. Era il bi-bu del pulsante della botola, che si ripeteva col lampeggiante: ora resta solo il jingle, una volta.
- **Torcia**: 20% di luce in meno.
- **Luce del portellone**: va giù sul portellone, sotto l'acqua, non sopra.
- **Difetti**: il soffitto storto nel corridoio iniziale, i puntini bianchi nella cupola, la scia rosa che si interrompe (deve essere continua) e lo scivolo giallo che si attraversa.
- **Jumpscare della medusa**: più movimentato (scosse, effetto glitch) e rumoroso (un urlo alla FNAF). Si propone prima di metterlo nel gioco.
- **Quando sparisce nella fossa dell'area bimbi**: un'esplosione d'acqua la avvolge completamente, poi sparisce. Si propone prima.
- **Entrata della sala**: nei due angoli verso la prima entrata ci vanno due pile alte quasi fino al soffitto, una di palloni da spiaggia gonfi e sgonfi e una di scatoloni di vari colori. Si propone prima, con scatti dal gioco.

## Scelte del 17 ottobre (pagina delle scelte)

Risposte complete, con le note parola per parola, in `docs/riscontri/2026-10-17_scelte.md`.

- **Strada di risalita (tappa 7)**: l'arredo è un misto delle proposte A (deposito della festa) e B (manutenzione), con i modelli più riusciti dell'una e dell'altra. I bambini compaiono una volta: l'agnellino aspetta in cima alla scala del corridoio C2, inclina la testa quando lo guardi e scappa avanti dove devi andare.
- **Sala grande, vicino alla prima entrata**: entrando, a destra (sud-est) c'è la pila di palloni da spiaggia dentro la rete da carico, a sinistra (sud-ovest) la pila di scatoloni. Sono alte circa 10 m.
- **Area bimbi**: la variante HD ridisegnata, con la disposizione 1 di prima.
- **Jumpscare della medusa**: A, glitch forte, con l'urlo al massimo del volume.
- **Quando sparisce nella fossa (tappa 8)**: A, un geyser d'acqua. L'acqua non deve essere trasparente: deve coprirla del tutto mentre sparisce.

## Prova della v0.3.4 (17 ottobre)

Parole dell'utente in `docs/riscontri/2026-10-17_prova_v034.md`.
- **Tappa 8, nuova regola**: lei resta affacciata alla fossa finché non la spruzzi con la lancia. Appena il getto la colpisce, parte subito il geyser e lei sparisce. Questo prende il posto della regola del 16 ottobre ("la guardi 2 secondi, poi dopo 6 secondi scivola sotto").
- **L'agnellino della risalita** scappa molto più veloce: non lo devi mai raggiungere né vedere mentre sparisce.
- **Niente scatti al primo uso**: aspirazione, getto e geyser non devono bloccare il gioco la prima volta.
- **La pila di palloni** all'entrata della sala va senza rete: un mucchio a piramide, con la base molto più larga, appoggiato nell'angolo.

## Prova della v0.3.5 (18 ottobre)

Parole dell'utente in `docs/riscontri/2026-10-18_prova_v035.md`.
- **Niente scatti al primo uso**: per l'aspirazione e il geyser è risolto. Resta da risolvere per il primo spruzzo dello zaino.
- **Suoni più bassi**: tutto il suono è 20 dB più basso, e il massimo ora suona come il 10% a cui l'utente teneva il volume generale. Gli equilibri tra i suoni non cambiano, e il volume generale del menu resta regolabile.
- **Torcia**: un altro 50% di luce in meno, dopo il 20% del 17 ottobre.
- **Niente torcia** (decisione dell'utente, 18 ottobre sera): "togliamo la torcia". Le luci in più le indica lui. Per ora sono due: una lampada bianca a soffitto sopra la pozza d'acqua davanti ai tornelli e una luce rossa lampeggiante prima del portone stagno n. 1. I bambini scappano solo se ti avvicini troppo.
- **La torcia torna** (richiesta dell'utente, 21 ottobre): "nella prossima build mettimi la flashlight ma riducila di intensità di un ulteriore 50% dopo l'ultima riduzione che avevamo fatto". Quindi torna il tasto F, con l'energia dimezzata da 2,8 a 1,4. Le due luci aggiunte il 18 ottobre restano. I bambini continuano a scappare solo se ti avvicini troppo, non dalla luce della torcia ("lascia come ora").
- **Menu**: la medusa va inquadrata in modo che la faccia resti sempre visibile, dall'inizio dell'animazione.
- **Il geyser della tappa 8** è di bassa qualità e va rifatto. L'idea resta quella del 17 ottobre: una colonna d'acqua bianca, non trasparente, che la avvolge e poi ricade come pioggia pesante.
  - **Scelta del 19 ottobre: la V1**, cioè la colonna simulata con Mantaflow e portata in Godot come sequenza di mesh 3D, giusta da ogni lato (lavoro/ambienti-1, 867d33c e successivi). La V2, un flipbook su un piano, è stata scartata. Resta da togliere il punto bianco al centro della colonna, che si vede in tutte e due.
  - **Riserva approvata dall'utente** (21 ottobre): "se non riusciamo a essere soddisfatti col geyser possiamo eliminarlo e fare un'animazione di tuffo verso il basso di Jilly". Se la V1 nel gioco non convince, al posto del geyser lei si tuffa verso il basso nella fossa.
  - **Si passa al tuffo** (decisione del coordinatore, 22 ottobre notte, come autorizzato dall'utente). Nel gioco la V1 ha dei buchi da cui si vedono l'occhio e il viso di lei proprio mentre sparisce, ed è rosa a grumi, più gelatina che acqua. Chiuderli vorrebbe dire rifare la simulazione, giorni di lavoro con un risultato incerto. La V1 resta da parte nel branch lavoro/ambienti-1. Fino al tuffo resta il geyser di prima (GeyserFossa).
  - **Il tuffo: scelta A, di testa** (scelta dell'utente, 22 ottobre). Si spinge sulle mani sul bordo, ti guarda un'ultima volta, si inarca e si tuffa di testa nella fossa; i tentacoli entrano per ultimi, come una frusta. Le parti comuni sono già fatte: schizzo all'entrata, onde, tonfo, e lei che sparisce solo quando è tutta sotto. Lo schizzo su misura (corona alta, gocce grosse, schiuma bianca) si fa insieme all'animazione. Scartate: B "da medusa" e C all'indietro.

## La sala della torre (idea dell'utente, 17 ottobre)

Prende il posto della salita della tappa 9 descritta in `docs/livello/capitolo1.md`.
- È una **struttura mastodontica di scivoli colorati**.
- **Non si scala: si scende**, scivolando tra diversi segmenti di scivoli spezzati, senza cadere.
- A volte ci si aiuta con il getto per saltare da un pezzo all'altro.
- Le versioni (dove entri in alto, come è fatta la discesa, dove stanno la balconata dei bambini, la luce di lei e la Polaroid 10) si propongono all'utente con scatti dal motore.
- **Scelta del 18 ottobre** (`docs/riscontri/2026-10-18_torre_agnellino.md`): si sviluppa la **versione A**.
  - Quattro torri di traliccio colorate alte 34 m, con più di 30 scivoli intrecciati e il vuoto centrale col pozzo da cui sale la luce di lei.
  - Si entra dal portone in cima e si scende fino al fondo, 20 m più giù nello scafo.
  - La discesa va fatta con **più salti**.
  - Le piattaforme stanno **solo dove servono**.
  - La luce resta com'è: rosso d'emergenza con fari e lampade da lavoro.

**Scelte del 18 ottobre:** discesa e aspetto approvati. L'utente vuole provarla nel gioco prima di dire altro: "Lo devo vedere in gioco per dirti". Nei due salti col getto resta la carica del getto B: si impara a spruzzare prima del bordo.

## La strada nella torre degli scivoli (prova del 19 ottobre, scelte del 21)

L'utente: "nella torre degli scivoli non si capisce dove bisogna andare, le vie sbagliate non ti devono portare a morire a caso, devono avere senso (es cadi ecc)". Scelte del 21 ottobre:
- **la strada giusta** si capisce in tutti e due i modi: segnali del parco (frecce disegnate, senza scritte, e luci verdi sulla via giusta) e l'ambiente (le vie sbagliate si vedono rotte o sbarrate);
- **nelle vie sbagliate non si muore**: cadi in una vasca di raccolta e risali da una scaletta fino all'ultimo checkpoint.
- **meno sostegni** (richiesta dell'utente, 21 ottobre): "togli un po' di barre di sostegno, vanno anche in mezzo ai percorsi dove devi scendere, sono brutti da vedere e fanno solo caos". Via quelli che attraversano i percorsi o la vista della strada; gli altri sfoltiti e ordinati, quanto basta perché nessun pezzo sembri sospeso.

**Come è fatta nella v0.3.8** (ambienti-2; approvata dall'utente il 22 ottobre, compresa la fascia liscia sul portale giusto):
- l'imbocco giusto di ogni discesa ha un portale con una fila di led verdi e una lampada verde. La fascia del portale è liscia: le strisce gialle e nere vogliono dire "chiuso";
- gli imbocchi sbagliati vicino alle pedane sono chiusi da un cancelletto a strisce, con una lampada rossa guasta che sfarfalla oppure spenta;
- sotto i salti ci sono vasche di raccolta, e una scaletta di servizio riporta alla pedana di partenza. Si muore solo per una caduta libera di più di 8 m;
- nessuna barra di sostegno nei 2,4 m sopra i canali di discesa.

## L'enigma degli acquari (idea dell'utente, 18 ottobre)

L'utente trova il capitolo corto e vuole un enigma in più nella sala principale. Le sue parole: "saranno tre acquari di acqua colorata, due pieni di due colori e uno vuoto, in quello vuoto bisognerà versare i due colori per formarne un terzo, per farlo serviranno due zaini di un colore e uno zaino dell'altro. Fare bene aprirà il cancello della torre degli scivoli, che a questo punto risulterà chiuso MA avrà lampade luminose prima spente che saranno invece accese quando rientriamo nella sala. Anche gli acquari saranno comparsi ora mentre prima, durante il primo accesso alla sala non c'erano. Se sbagli la combo dei colori devi poter resettare l'enigma. Deve esserci un riferimento al colore da creare."

Risposte alle domande (18 ottobre):
- **Colori**: giallo e blu; con due zainate di giallo e una di blu viene il verde.
- **Indizio**: accanto agli acquari c'è un disegno a pastello dei bambini con quel verde.
- **Quando**: gli acquari compaiono quando rientri nella sala dal magazzino (tappa 7), insieme alle lampade del portone della torre che si accendono. Si possono usare dopo la tappa 8, quando lei se n'è andata.
- **Se sbagli**: sotto l'acquario c'è una grossa valvola rossa da colpire col getto. L'acquario si svuota col gorgo e i due acquari colorati tornano pieni.
- **Cosa apre**: il portone della torre. Prende il posto della regola di prima ("si apre da solo dopo la tappa 8").
- L'aspetto (acquari, posizione, disegno, lampade) si propone all'utente con scatti dal motore prima di metterlo nel gioco.

**Scelte del 18 ottobre (pagina, risposte in `docs/riscontri/2026-10-18_scelte_acquari_torre_mascotte.md`):**
- stile B: grandi cilindri di vetro tra una base e un coperchio di acciaio rosso, con tubi e manometri;
- posizione 2: sul lato est, vicino al portone della torre. Dalla serranda non si vedono, si scoprono a metà sala;
- il miscuglio è basso e largo, in mezzo ai due alti, perché con lo zaino si versa solo fino a circa 0,8 m. Sotto c'è la valvola rossa;
- sul portone ci sono le lampadine da luna park, spente al primo passaggio e accese quando rientri dal magazzino;
- l'indizio è un disegno a pastello attaccato al vetro dell'acquario giallo, retroilluminato dall'acquario, così si legge anche senza torcia;
- i colori dell'acqua (giallo, blu, verde e torbido) sono approvati;
- zaino: quando inizi ad aspirare un colore, l'acqua normale che avevi nel serbatoio viene buttata via da sola.


**Acquari grandi il doppio** (prova del 19 ottobre e scelta del 21): gli acquari vanno ingranditi del doppio, tutta la struttura, e la valvola di reset va illuminata. Il miscuglio raddoppiato ha il bordo a circa 1,56 m, quindi davanti c'è una **pedana di servizio a gradini** (grigliato d'acciaio con parapetto), scelta dell'utente: "fai in modo che ci si possa arrampicare sulla bacinella su cui versare, è il modo più pratico per versare, farlo sotto i propri piedi". Le quantità restano uguali: 2 zaini di giallo e 1 di blu fanno il verde.

**Davanti al portone, vuoti fin dall'inizio** (richiesta dell'utente, 21 ottobre): "le vasche dell'enigma di fronte al portone della torre degli scivoli: mettile proprio davanti al portone suddetto. Inoltre mettile fin dall'inizio del gioco, ma VUOTE. Si riempiranno quando ritorni nella sala." Quindi gli acquari (con la pedana) stanno proprio davanti al portone della torre, lasciando libero il passaggio, al posto della posizione 2 del 18 ottobre. Ci sono dal primo passaggio, vuoti e con le lampadine del portone spente; quando rientri nella sala dal magazzino sono pieni (le pompe sono ripartite nella tappa 6) e le lampadine sono accese.

**Posizione davanti al portone** (enigmi, 22 ottobre). Raddoppiati sono lunghi quasi 16 m in fila e il portone è largo 6,3 m: una fila dritta davanti lo chiuderebbe. Tre modi, in attesa della scelta dell'utente:
- P1: in fila lungo il muro nord, accanto al viale del portone, con il giallo subito a sinistra del portone. È quella costruita, e la consiglia la squadra;
- P2: giallo e blu ai due lati del portone come colonne d'ingresso, il miscuglio con la pedana staccato, a circa 6 m;
- P3: fila a 9 m davanti al portone con un varco largo quanto il portone in mezzo, e i tubi che passano sopra il varco a 3,2 m.

**Scelta dell'utente (22 ottobre): P1**, quella costruita. È nella v0.3.8.

## Nuove mascotte (idea dell'utente, 18 ottobre)

Parole dell'utente: "su meshy abbiamo ancora troppi crediti. Vogliamo preparare qualche altra mascotte, tipo statue di animali marini personificati, da mettere in giro? Magari anche un mostro tipo questo" (con un acquerello di uno squalo-mostro in piedi su due zampe; è il disegno di un artista, quindi ci si ispira ma non lo si copia). Le sue risposte:
- **Stile delle statue**: mascotte del parco, cioè vetroresina dipinta da acquapark, sorridenti e colorate, ora scolorite e crepate. Sono della stessa famiglia della medusa.
- **Animali**: uno squalo e un polpo.
- **Il mostro-squalo**: per ora solo il modello. Il ruolo nel gioco si decide dopo.
- **Dove metterle**: si decide dopo aver visto i render, su scatti dal gioco.
- I crediti Meshy del mese (circa 12.600) si perdono il 15 novembre: si possono usare.

**Scelte del 18 ottobre:** statua dello squalo A (pollice in su, pantaloncini rossi, salvagente), tutte e due le statue del polpo (A rosa con le braccia aperte, B lilla con maschera, salvagente, pallone e gelato) e mostro-squalo A, quello vicino al disegno. Le posizioni si scelgono su scatti dal gioco.

**Posizioni, scelte il 19 ottobre** (scatti in `docs/proposte/mascotte/posti/`, lavoro/mascotte 961a53a):
- **squalo A in S2**: sul bordo est della piscina a onde, accanto alla sedia del bagnino e ai lettini, rivolto verso la piscina (x 10, z 1,5, -90°);
- **polpo A in A3**: all'ingresso dell'area bimbi, vicino allo scivolo giallo (x -5,5, z -18, -12°);
- **polpo B in B1**: nell'area bimbi contro il muro ovest, accanto al fungo (x -18,3, z -8, 90°). Nella tappa 8, al buio, resta quasi nascosto dietro la medusa della fossa: l'utente l'ha visto e l'ha scelto lo stesso.

## L'inizio con il mostro-squalo (idea dell'utente, 21 ottobre)

Parole dell'utente: "ritocchiamo l'inizio. Quando ti alzi da terra. Mettiamo che davanti a te c'è lo squalo mostro che abbiamo fatto, facciamo che vedi la bocca che ti sta per mangiare la faccia, addosso alla telecamera quindi, ma poi un boato dietro lo squalo, dove c'è la porta in fondo al corridoio lo fa scappare. Tu lo vedi proprio girarsi, esitare e poi correre via verso la porta che poi si chiude."

Quindi il mostro-squalo A (quello scelto il 18 ottobre) compare al risveglio nel corridoio: la bocca aperta addosso alla camera, poi il boato dalla porta in fondo al corridoio; lui si gira, esita, corre via verso quella porta, che si chiude dietro di lui. Le risposte dell'utente sui dettagli (21 ottobre):
- **La camera** (risposta dell'utente, 21 ottobre): "telecamera fissa che si muove come se fosse la faccia del personaggio spaventato". Il giocatore non la controlla durante la scena: la camera è guidata e si muove come la testa di chi è terrorizzato (sussulti, si ritrae dalla bocca, trema, segue lo squalo che si gira e scappa).
- **Il boato** (risposta dell'utente, 21 ottobre: opzione b): è il verso lontano e profondo di lei, Jilly, che lo chiama dalla porta in fondo al corridoio. Lo squalo obbedisce: si gira, esita e corre da lei.
- **La porta** (risposta dell'utente, 21 ottobre: sì): è la porta tagliafuoco del ponte inferiore che già si chiudeva da sola. Ora si chiude dietro lo squalo che scappa e resta chiusa: da lì non si passa.
- **Niente video prima** (risposta dell'utente, 21 ottobre): la scena va direttamente nel gioco e l'utente la giudica giocando. "Mi raccomando di farla bene. Lo squalo si vede in primissimo piano con la bocca spalancata."
- **Dove ti svegli** (risposta dell'utente, 21 ottobre: a): il risveglio si sposta di circa 6 m verso ovest (x 14-15), davanti alla porta chiusa della sala pompe, guardando a est. Lo squalo corre per circa 7 m fino alla porta tagliafuoco. Finita la scena si torna verso ovest, la strada di sempre. Il tratto di corridoio che prima restava alle spalle va rifinito come il resto.
- **I dettagli della scena** (decisi da mascotte, approvati dall'utente il 22 ottobre): lo squalo scatta tre volte con la testa come per mordere; nell'esitazione si volta a guardarti con uno sbuffo; alla porta si abbassa per passare; durante la scena sei in ginocchio, con gli occhi a circa 1 m; dura circa 13 secondi, poi riprendi i comandi. La torcia e la riga dei comandi aspettano la fine della scena. È nella v0.3.8.

## Allungare il capitolo (scelte dell'utente, 18 ottobre)

L'utente: "al momento, arrivare alla porta della torre si impiegano 5 minuti". Con gli acquari e la torre per lui diventano circa 10 minuti, e per chi gioca la prima volta 20-25, mentre ne erano previsti 39-42. Per allungare, l'utente ha scelto:
- **l'inseguimento e il finale**, già nella scaletta (I1 e SB1): dopo la torre lei ti insegue negli scivoli, e il capitolo finisce con lei che sbuca dal bordo;
- **due stanze nuove con un enigma**: il **fiume lento**, un canale buio con la corrente che ti trascina, dove col getto colpisci le chiuse per deviare la corrente verso l'uscita giusta (se sbagli, il giro ti riporta all'inizio), e l'**infermeria**, la stanza del medico del parco con una cassaforte il cui codice è nascosto tra cartelle e Polaroid, e la storia delle pecore modificate con i geni della medusa.
Le stanze sono due, in sequenza: prima il fiume lento, poi l'infermeria. Il posto l'ha scelto l'utente: "possiamo collocarle lungo il percorso in risalita da dopo la stanza dei generatori, evitando che si apra la serranda che riporta alla sala centrale, finché non hai preso una keycard dall'infermeria. Aggiungi una lettore per leggere la keycard a quella serranda e fallo illuminato." Quindi le stanze stanno lungo la strada di risalita, dopo la sala dei generatori. Nell'infermeria si prende una keycard, e la serranda del magazzino che riporta nella sala grande si apre solo passando la keycard in un lettore illuminato accanto alla serranda, che si vede anche al buio.
Prima si fanno le proposte con render veri. Le altre idee (enigmi nelle zone che ci sono già, più esplorazione e Polaroid) si valutano dopo.

**La logica, approvata dall'utente il 18 ottobre** (nota di enigma-logica in `docs/proposte/fiume_infermeria/nota_logica.md`):
- **Fiume lento** (4-6 minuti la prima volta, 80 s un giro giusto). La corrente c'è perché le pompe sono ripartite dopo la tappa 6. Si sta su una ciambella del parco a 2,2 m/s. Ci si guarda intorno, si spruzza e si aspira; spruzzando all'indietro si accelera fino a 3,2 m/s, in avanti si frena fino a 1,2 m/s. Tre bivi su un anello: prima di ognuno, 12-15 m prima, col getto si colpisce un disco a strisce di 80 cm che gira la paratia. Al bivio 1 la paratia va girata; al 2 è già giusta, e se la colpisci la sbagli; al 3 il disco si vede solo dopo averlo passato, quindi si spara all'indietro. L'indizio sono i cartelli verdi d'uscita d'emergenza: dopo il blackout sono accesi solo sui rami giusti (scelta dell'utente). Se sbagli, un ramo corto e uno scivolo ti riportano all'imbarco, e le paratie restano come le hai lasciate. Non si cade e non si muore.
- **Infermeria** (3-5 minuti, senza testi da leggere). 1) Col getto colpisci l'interruttore e si accende il negatoscopio. 2) Una Polaroid del medico mostra lo schedario con un cassetto segnato da un adesivo rosa, che al buio brilla. 3) Nel cassetto c'è la radiografia di un agnello: sul negatoscopio, nelle ossa brillano puntini rosa, 4 nella testa, 1 nel corpo e 7 nella coda. È anche la storia delle pecore modificate. 4) La cassaforte ha tre rotelle segnate testa, corpo e coda: il codice è 4-1-7. Dentro trovi la keycard per la serranda e una Polaroid della pecora che brilla.
- **Dove**: tra la sala pompe e il magazzino, lungo la strada di risalita. Prima il fiume, poi l'infermeria, poi dalla scala di servizio il magazzino con la serranda e il lettore della keycard.

**L'inseguimento e il finale, scelta del 19 ottobre** (proposta di ambienti-2 in `docs/proposte/inseguimento/inseguimento.md`, lavoro/ambienti-2 9aa6217): **versione A, "Le condotte"**. È una sala macchine piena e allagata, ricavata nello scafo dietro la bocca in fondo alla torre. Si scivola in tubi chiusi tra tre vasche sospese, con tre bivi. Ai bivi la paratia giusta ha la luce verde e l'anello di led verdi, la sbagliata una lampada rossa guasta; si colpisce il bersaglio col getto. Lei ti raggiunge nelle vasche, e un getto in faccia la respinge. Poi una spirale attorno al serbatoio, la grata che cala davanti a lei e, prima della porta, SB1: lei sbuca dal pozzo di scarico e ti guarda. Dura circa 5:40 senza errori. Le pose di lei sono provvisorie: le animazioni dell'inseguimento sono da fare.

**Nel gioco** (ambienti-2, 22 ottobre, branch lavoro/ambienti-2-inseguimento, non ancora unito): la sala c'è dietro il muro est della torre, con i tubi in cui si scivola accovacciati, le sei paratie col bersaglio, lei che sale nelle vasche, la grata, SB1 e i checkpoint. Due scelte da fare per l'utente:
- vasche ancora scure, l'acqua quasi nera: a) acqua meno torbida, verde-azzurra, col fondo che si intravede; b) una lampada da lavoro sopra ogni vasca; c) tutte e due (consigliata);
- strisce delle paratie: nella torre le strisce vogliono dire "chiuso". a) sulla paratia giusta la trave diventa liscia (consigliata); b) restano tutte a strisce, perché finché non colpisci il bersaglio sono chiuse.

**Scelte dell'utente (22 ottobre):** vasche **c**, cioè acqua meno torbida e verde-azzurra col fondo che si intravede, più una lampada da lavoro sopra ogni vasca; strisce **a**, la trave della paratia giusta diventa liscia e sulla sbagliata le strisce restano.
Nota dell'utente sulla B, "Le rapide": "Se hai già fatto anche le rapide possiamo usarle per qualcos'altro". Gli scogli, i gommoni e il canale delle rapide restano da parte per un altro punto del gioco, senza la scritta "LE RAPIDE".

**L'aspetto delle stanze nuove, scelte del 19 ottobre** (proposte di enigma-ambiente in `docs/proposte/fiume_aspetto/`, `infermeria_aspetto/` e `tessera_lettore/`, lavoro/enigma-ambiente 295e9c6):
- **fiume lento: A, "giungla finta"**. Rocce finte color ocra sotto il tetto del capannone, palme e liane di plastica, maschere tiki, pappagallo e scimmia di vetroresina, tettoia di paglia sull'imbarco, luce calda. La B, "viaggio sottomarino", non si butta. Parole dell'utente: "Però tieni anche l'altro, magari potrebbe essere il viaggio di ritorno, oppure una nuova sezione. Non è da buttare. Riproponimelo." Va riproposta più avanti;
- **infermeria: B, "per bambini del parco"**. Mobili pastello, adesivi grandi di balena, tartaruga, stella e cavalluccio, metro a giraffa, cavallo a dondolo, orsetto e trenino, con gli oggetti veri dell'enigma (pulsante del parco, negatoscopio, schedario con l'adesivo, cassaforte a rotelle);
- **lettore della serranda: 1**, a strisciata anni '90, di plastica beige, con la spia tonda in alto (rossa, poi verde). La luce verde va più debole che negli scatti;
- **keycard: 1**, il tesserino bianco del personale del parco, con la foto, le onde e la banda magnetica. Vale la regola delle scritte: solo disegni.
- **il corridoio con le scale verso il magazzino** (C2) si chiude con la stessa grata verde con catena e lucchetto della scala degli interni (scelta dell'utente, 21 ottobre). Dove (scelta β, 21 ottobre): le scale del raccordo restano, l'agnellino compare e scappa nel buco come oggi, e subito dopo il buco c'è la grata; la porta di servizio sta nel tratto basso di C2, prima della grata, e da lì una scala scende all'imbarco del fiume;
- **nei rami sbagliati del fiume** non c'è niente da vedere: solo il ramo con lo scivolo che riporta all'imbarco (scelta dell'utente, 21 ottobre). Lo scivolo (scelta B, 22 ottobre): il fiume resta tutto alla stessa altezza, e la fine del ramo sbagliato è un canale stretto e veloce di vetroresina colorata, come uno scivolo, con una discesa di circa 20 cm, che sbocca nella vasca dell'imbarco. Scartate: A, vasca più bassa con nastro trasportatore; C, rapida d'acqua bianca;
- **le frecce gialle dipinte a terra in C2**, che puntavano al magazzino ora chiuso dalla grata, si tolgono (scelta dell'utente, 22 ottobre).
- **la Polaroid della pecora che brilla** nella cassaforte va direttamente nel gioco, fatta come le altre Polaroid (scelta dell'utente, 21 ottobre).

## Capitolo 1: scaletta (approvata)

- Il giocatore entra nell'acquapark dal ponte inferiore.
- Le zone sono gli **spogliatoi**, la **piscina a onde vuota**, l'**area bimbi con il secchio gigante**, la **torre degli scivoli** e la **sala pompe**.
- **Tra il 5° e il 7° minuto** il giocatore vede la mascotte **immobile come una statua**, come Huggy Wuggy nel primo capitolo di Poppy Playtime. Più tardi ripassa di lì e non c'è più.
- Nella sala pompe il giocatore **riattiva le pompe** e la mascotte si sveglia.
- **Finale**: inseguimento dentro gli scivoli.
### Livello: scelte dell'utente (14 ottobre 2026)

Le proposte complete stanno in `docs/proposte/livello/capitolo1.md`. La versione decisa è in `docs/livello/capitolo1.md`. Queste sono le scelte:

- **Percorso A, lineare** (circa 42 minuti, vedi `docs/livello/capitolo1.md`): risveglio, spogliatoi (zaino), statua, area bimbi (secchio gigante), piscina a onde vuota, sala pompe (lei si sveglia), ritorno al buio con il piedistallo vuoto, torre degli scivoli, inseguimento, fine.
- **Statua S1, "il benvenuto"**: vicina e immobile, il giocatore le gira intorno quanto vuole e non succede niente.
- **Piedistallo vuoto V1, "silenzio"**: una pozza d'acqua sul piedistallo e una scia di gocce che si allontana nel buio, senza musica.
- **Inseguimento I1**: scivolata veloce negli scivoli con l'acqua che scorre. Ai bivi si colpisce la paratia giusta; ci si gira e la si respinge col getto. Alla fine una grata di sicurezza cala davanti a lei.
- **Zaino Z1**: è una vera pompa. Aspira l'acqua da una vasca e la spara in un'altra, con un serbatoio; nell'acqua che scorre si ricarica.
- **La scena in cui sbuca dal bordo va messa due volte**: a metà capitolo (SB2) e come ultima immagine del capitolo (SB1).
- Il giocatore **si sveglia per terra nel corridoio**.
- **Lo zaino si trova nello stanzino dei bagnini.**
- **Oggetti da collezione: 10 Polaroid**, che rivelano una parte della lore nascosta.
- **Checkpoint invisibili ma frequenti.**
- **Morte**: la scena intera si può saltare.
- **Prima dell'inseguimento lei può prenderti solo se te la vai a cercare** (per esempio se le arrivi troppo vicino). Non ti dà la caccia.

**Confermato dall'utente il 14 ottobre:**
- La scena dal bordo a metà capitolo va al ritorno al buio dopo le pompe: le vasche basse dell'area bimbi si stanno riempiendo e lei sbuca dal bordo a pochi metri. Poi scivola sotto e la sua luce si allontana sott'acqua.
- La pianta comune: una sola sala sotto la cupola, con la piscina a onde al centro, l'area bimbi a sinistra e la torre degli scivoli a destra.
- Il ritorno al buio passando dagli spogliatoi.
- Nella scena della statua, quando parte la sigla, i canali della campana pulsano a tempo per un attimo.
- 10 Polaroid, che rivelano la lore nascosta ma non per intero (vedi sopra).

## Strumento: lo zaino-pompa (approvato)

- È uno zaino-pompa con lancia d'acqua, al posto delle mani di Poppy Playtime.
- Il getto attiva turbine e pulsanti a distanza.
- Riempie e svuota le vasche per raggiungere posti nuovi.
- Respinge i mostri per un attimo e dà una spinta per saltare.
- **Versione Z1, decisa dall'utente**: aspira l'acqua da una vasca o pozza (il livello scende davvero) e la spara altrove. Ha un serbatoio, che si ricarica nell'acqua che scorre.
- **Aspetto scelto dall'utente il 14 ottobre**: lo zaino-giocattolo anni '90, colorato (turchese, giallo e arancione, con adesivi di delfini), con un serbatoio trasparente e una pistola ad acqua tipo Super Soaker. È un modello 3D di Meshy, l'opzione 2 in `godot/assets/models/zaino/`.
- **Rework estetico chiesto dall'utente il 16 ottobre**: "Deve essere diversa in mano, ma anche il getto aspirato e sparato deve essere molto molto più imponente e soddisfacente da vedere e sentire. Pensa alla pompa dei pompieri e potenzia ancora. Dobbiamo competere con il grab pack e al momento abbiamo una pisciatina stupidita. La fisica delle pozze invece va bene."
  - Da rifare: la lancia in mano, il getto sparato, l'aspirazione e i loro suoni. La fisica delle pozze resta com'è.
  - L'utente sceglie da proposte con video e suoni veri. Riferimenti: la pompa dei pompieri potenziata e il Grab Pack di Poppy Playtime.

## La mascotte del capitolo 1: la medusa

**Il suo nome è Jilly Jubilee** (scelta dell'utente, 18 ottobre). Il gioco si chiama come lei: **Jilly Jubilee** (scelta dell'utente, 22 ottobre); "Splash Lagoon" resta il nome provvisorio del parco. I titoli proposti dal coordinatore ("No Lifeguard on Duty", "The Deep End" e simili) non gli sono piaciuti.

**Il nome nel parco, scelte del 19 ottobre** (render e scatti in `docs/proposte/mascotte/jilly/`, lavoro/mascotte 38c2738):
- **logo stile B**, "spettacolo della nave": "Jilly" in corsivo corallo, "JUBILEE" in oro su un nastro blu, stelle e una piccola medusa. Nota dell'utente: "ma molto più invecchiati", quindi targa, manifesto e insegna vanno invecchiati molto di più di quelli proposti;
- **la targa** smaltata (70 x 39 cm) sul lato ovest della vasca di Jilly, accanto al cordone: sì;
- **il manifesto dello spettacolo** (70 x 105 cm) sul muro ovest vicino all'ingresso, tra il cartello giallo e l'oblò: sì;
- **l'insegna** di lamiera (1,8 x 1 m) in alto sul muro ovest sopra la vasca d'arrivo: sì, **con le sue due lampade a collo d'oca**, luce calda e debole solo sul pannello.

**Le scritte nel parco** (scelta dell'utente, 19 ottobre): **solo disegni, niente scritte**. Le scritte di Jilly Jubilee fanno eccezione. Parole dell'utente: "Togli la scritta le rapide, sostituiscila con un disegno. Le scritte di Jilly Jubilee fanno eccezione". Anche "LIVE SHOW" e gli orari del manifesto restano (scelta dell'utente, 19 ottobre).

### Riferimenti approvati

- `docs/concept/medusa_statua.jpg`: ferma come una statua sul piedistallo.
- `docs/concept/medusa_sottacqua.jpg`: brilla sott'acqua.
- `docs/concept/medusa_sbircia.jpg`: sbuca dal bordo della piscina, la scena preferita dall'utente.
- Il punto di partenza è un disegno dato dall'utente, che dichiara di avere i diritti per usarlo.
- `docs/concept/altri/sketch1_sbircia_da_tenere_presente.jpg` viene da un primo sketch dell'utente, poi abbandonato. L'utente vuole "tenerlo presente", ma non lo convince.

### Aspetto (deciso)

- Busto umanoide snello, pelle azzurro-pervinca.
- **Un solo grande occhio** con iride rosa al centro del viso.
- Capelli corti e mossi, argento-rosa.
- Dalla vita in giù, una **campana di medusa trasparente** con canali radiali luminosi e lunghi **tentacoli magenta**, ispirata alla medusa vera *Halitrephes maasi*.

### Scartato dall'utente

- La croce sulla fronte.
- La versione con due occhi.
- Il costume a fascia.

### Il centro della sala: la vasca sollevata con la medusa affacciata (deciso dall'utente, 15 ottobre, sostituisce la statua)

- La statua che poi si anima è "troppo Poppy Playtime". **La statua si tiene per più avanti** (modello e monumento restano negli asset).
- Al suo posto, al centro della sala, c'è la **vasca sollevata** del concept `docs/concept/medusa_sbircia.jpg`: bordo piastrellato rialzato, acqua quasi al bordo. Dentro c'è **la medusa vera, affacciata e immobile**: mani sul bordo, campana in acqua, tentacoli che ricadono fuori, l'occhio che guarda chi entra.
- **Poi sparisce**, nel punto della scaletta approvata in cui il piedistallo restava vuoto (tappa 7, ritorno al buio dopo la sala pompe). Con la stessa inquadratura, la vasca è vuota, l'acqua si muove ancora e una scia di gocce scende dal bordo e si allontana nel buio, verso l'area bimbi.
- Vale la regola sulla qualità: vasca e posa della medusa devono essere al livello del pezzo campione.

### La statua: il simbolo del gioco (deciso dall'utente, 15 ottobre)

- La medusa è **il simbolo del gioco**. La sua statua deve essere **imponente** e messa in scena come Huggy Wuggy nella hall di Poppy Playtime.
- Alta circa **4,5 m** in tutto, testa più tentacoli appoggiati. La creatura ha la stessa taglia.
- La statua **poggia sui tentacoli**, che si appoggiano al piedistallo e si piegano, e non galleggia. I tentacoli devono essere di alta qualità: nastri carnosi e trasparenti, non tubicini.
- **Tentacoli approvati dall'utente (15 ottobre)**: i nastri carnosi e traslucidi del commit ccbcfe5 ("molto belli"). Non cambiarli. Il resto della ragazza va portato allo stesso livello: prima i capelli, poi viso e occhio, superficie in vinile, mani e campana.
- Sta su un **piedistallo monumentale**: entrando nella sala il giocatore la vede subito, intera e centrata, illuminata come un monumento, e poi le gira intorno. Da vicino incombe.
- Alla base ci sono offerte lasciate dai bambini: un indizio silenzioso della lore.
- **Com'è nella v0.2.0 (15 ottobre)**: per avere la statua intera e centrata a circa 10 m dalla porta degli spogliatoi, la sala è stata allungata di 8 m verso sud. Il monumento a gradoni sta in (0, 0, 10) e ha il piano largo 3,7 m, così i tentacoli appoggiano tutti. Ai lati della statua pendono due teli con la mascotte. Dall'ingresso la statua compete ancora con la cupola: c'è da proporre all'utente una versione più grande, circa 6 m con il monumento in proporzione.

### Natura: fuori bambola, dentro viva (deciso)

- Il corpo è quello di una **bambola-mascotte in vinile**: liscio come un manichino, con un aspetto "plasticoso" voluto.
- **Campana, tentacoli e bocca sono organici e vivi.**
- Non si spiega niente: il giocatore si chiede da solo se sia un giocattolo diventato vivo o qualcosa che ci è cresciuto dentro.
- Nel modello 3D **niente capezzoli**: il busto è liscio. Il seno si copre di volta in volta con le mani, i capelli, i tentacoli o l'inquadratura.

### Bocca (deciso)

- Da chiusa **non si vede**.
- Quando attacca, la pelle del viso **si strappa sotto l'occhio** e si apre una **fauce enorme con file di denti da squalo**.
- Va costruita nel modello 3D: geometria nascosta, osso o shape key per aprirla, bordi strappati.
- **Versione malvagia (richiesta dell'utente, 15 ottobre)**: con la fauce aperta l'**occhio diventa più venato**, con capillari rossi dal bordo verso l'iride, così fa paura. Nel materiale è un parametro, così in gioco le vene compaiono quando attacca.
- **Approvazione definitiva del modello**: l'utente vuole una scheda con il giro completo, i dettagli in viste separate e la versione malvagia (`docs/proposte/medusa/scheda/`).
- **Modello approvato dall'utente (15 ottobre)** con la scheda di lavoro/medusa 94782be: giro, dettagli, versione malvagia e mani nuove ("a parte questo ci sta"). Resta da correggere solo la fauce: i denti sono tutti inclinati da una parte. Serve una fila sull'arcata di sopra e una su quella di sotto, inclinate in senso opposto, che si incastrano come in uno squalo.

### Movimento (deciso)

- **Non corre, fluttua**: veloce, inclinata in avanti, con la campana che pulsa come una medusa vera e le braccia tese verso il giocatore.
- I **tentacoli si muovono con la fisica in Godot**: 10-12 tentacoli grossi simulati, più quelli sottili mossi da uno shader.
- Busto, braccia, mani e testa sono animati in Blender.
- Meshy non può fare lo scheletro: il suo auto-rig funziona solo con personaggi a due gambe.

### Modello

- Base grezza in `assets_src/medusa/meshy_base.glb`, generata da Meshy multi-image-to-3D a partire da `docs/concept/medusa_turnaround.jpg`.
- Prime viste: `docs/concept/medusa_modello_grezzo.jpg`.
- **Da decidere**, con proposte all'utente:
  - finitura del vinile;
  - colore e intensità della luce della campana;
  - aspetto dell'occhio di vetro;
  - forma dei denti e dello strappo;
  - numero, lunghezza e forma dei tentacoli;
  - nome della mascotte.

## Tecnica

- **Godot 4.7.2**, renderer Forward+, per PC. Build automatiche con GitHub Actions e Release su GitHub.
- **Blender 5.2** usato come modulo Python (`bpy`) per modellare, fare il rig, animare e fare i render da script.
- **Meshy API** per immagini concept, modelli 3D e rig degli umanoidi. La chiave è nella variabile `MESHY_API_KEY`. L'utente non bada ai crediti, ma non vanno sprecati.
- **Crediti Meshy (16 ottobre)**: 14.628 crediti mensili, che si azzerano il 15 novembre. L'utente è d'accordo a usarli di più per la qualità:
  - rifare ad alta definizione gli oggetti della sala che non sono ancora di Meshy (struttura dell'area bimbi, funghi, secchio);
  - la sala della torre e gli scivoli nuovi.
  Si propone sempre all'utente con i render prima di metterli nel gioco.
- **Asset CC0**: texture da Poly Haven e ambientCG, modelli da Kenney e Quaternius.
