# Documento di progetto (GDD)

Titolo provvisorio: **Splash Lagoon**. Le voci segnate **Da decidere** vanno proposte all'utente, con immagini o render e 2-3 opzioni, prima di andare avanti.

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
  - **Il bambino col cubo**: in testa ha un cubo di **piastrelle da piscina** crepato, con cirripedi e alghe e una faccina carina disegnata. Quando si rivela, il cubo si apre e mostra una massa di tentacoli rosa traslucidi con **occhi gialli**. Il corpo è da rifare (era "troppo pacioccone"): un bambino magro di 7-9 anni, un po' curvo, con una muta da sub consumata.
  - **L'agnellino**: un peluche cucito, zuppo e macchiato di sale, con bottoni d'ottone al posto degli occhi e un fiocco alla marinara. Quando si rivela, il muso si spacca e mostra **un unico grande occhio**, scelto dall'utente. La testa di lupo resta solo come alternativa.

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

## La mascotte del capitolo 1: la medusa

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

### Natura: fuori bambola, dentro viva (deciso)

- Il corpo è quello di una **bambola-mascotte in vinile**: liscio come un manichino, con un aspetto "plasticoso" voluto.
- **Campana, tentacoli e bocca sono organici e vivi.**
- Non si spiega niente: il giocatore si chiede da solo se sia un giocattolo diventato vivo o qualcosa che ci è cresciuto dentro.
- Nel modello 3D **niente capezzoli**: il busto è liscio. Il seno si copre di volta in volta con le mani, i capelli, i tentacoli o l'inquadratura.

### Bocca (deciso)

- Da chiusa **non si vede**.
- Quando attacca, la pelle del viso **si strappa sotto l'occhio** e si apre una **fauce enorme con file di denti da squalo**.
- Va costruita nel modello 3D: geometria nascosta, osso o shape key per aprirla, bordi strappati.

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
- **Asset CC0**: texture da Poly Haven e ambientCG, modelli da Kenney e Quaternius.
