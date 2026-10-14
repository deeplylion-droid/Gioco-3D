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
- I nomi proposti finora sono la nave *Jubilee*, la compagnia *Wonderwave Cruises*, l'anno 1997 e l'acquapark *Splash Lagoon*. Sono **provvisori**: l'utente non li ha confermati.

## Capitolo 1: scaletta (approvata)

- Il giocatore entra nell'acquapark dal ponte inferiore.
- Le zone sono gli **spogliatoi**, la **piscina a onde vuota**, l'**area bimbi con il secchio gigante**, la **torre degli scivoli** e la **sala pompe**.
- **Tra il 5° e il 7° minuto** il giocatore vede la mascotte **immobile come una statua**, come Huggy Wuggy nel primo capitolo di Poppy Playtime. Più tardi ripassa di lì e non c'è più.
- Nella sala pompe il giocatore **riattiva le pompe** e la mascotte si sveglia.
- **Finale**: inseguimento dentro gli scivoli.
- Ordine delle zone, enigmi, tempi e percorso sono **da decidere**: vanno proposti all'utente.

## Strumento: lo zaino-pompa (approvato)

- È uno zaino-pompa con lancia d'acqua, al posto delle mani di Poppy Playtime.
- Il getto attiva turbine e pulsanti a distanza.
- Riempie e svuota le vasche per raggiungere posti nuovi.
- Respinge i mostri per un attimo e dà una spinta per saltare.
- L'aspetto dello zaino è **da decidere**.

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
