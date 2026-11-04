# Raffinamento del capitolo 1: proposte di ambienti-2

Zone: sala principale, torre degli scivoli, inseguimento nelle condotte, tunnel sottomarino.
Solo proposte: nel gioco non è cambiato niente. Le immagini sono già nel repo (branch `lavoro/godot`, 22a27ce8); nessuno scatto nuovo.
Ho tenuto conto delle decisioni del GDD: niente spaventi nuovi con lei, lei non più vicina, la nebbia non si tocca, niente torcia, luci toccate solo dove servono.

## ambienti2-1 Dentro i tubi dell'inseguimento non si vede dove si va
- Zona: inseguimento nelle condotte, i tubi fra le vasche (tubi giusti e scoli).
- Cosa non va oggi, visto dal giocatore: nei tubi si scivola accovacciati per molti metri quasi al buio pesto. Non c'è la torcia (tolta il 23 ottobre), e le uniche luci sono vicino alle paratie e sopra le vasche. Non si vede la curva che arriva né quanto manca, e i tubi giusti sembrano uguali agli scoli. È il tratto più veloce del capitolo, ma lo si fa "alla cieca".
- Proposta:
  - A) **(consigliata)** Strisce fosforescenti verde chiaro sul fondo dei tubi giusti, un trattino ogni 2-3 m, come le strisce di sicurezza dei parchi acquatici. Si vedono nel buio senza fare luce sulle pareti, quindi l'atmosfera resta quella di adesso. Sono lo stesso verde della "via giusta" della torre (led dei portali) e delle paratie giuste, e negli scoli non ci sono: chi sbaglia paratia lo capisce entrando.
  - B) Anelli di luce verde fioca dentro i tubi giusti, ogni 6 m. Si capisce meglio dove si va, ma sono luci nuove e schiariscono le pareti dei tubi.
  - C) Lasciare com'è: il buio aumenta la tensione, ma resta "alla cieca".
- Costo: piccolo (A), medio (B). Rischio: basso. Le strisce sono decal sul fondo, senza collisione e senza luci nuove; il controllo di posizionamento le controlla come gli altri oggetti.
- Immagini già fatte:
  - `docs/collaudo/torre_0317/foglio_tubi_inseguimento.jpg`, ultima riga "Dentro lo scolo 0, sulla curva": dagli occhi, dentro un tubo si vede solo il nero.
  - `docs/collaudo/vasche_sotto/foglio_ins_A_scolo_2.jpg`, ultima riga: a 2 m dentro il tubo, guardando indietro, il tubo è buio e si vede solo la bocca.

## ambienti2-2 Entrando nei tubi dalle vasche, per un attimo l'acqua è all'altezza degli occhi
- Zona: inseguimento, le 6 bocche dei tubi che partono dalle vasche dei bivi (dopo le paratie dei bersagli verdi).
- Cosa non va oggi, visto dal giocatore: dalla 0.3.20 la superficie non si vede più da sotto (la parete d'acqua nella bocca, approvata). Però, mentre ci si accovaccia per entrare, l'occhio passa per un attimo a 0-1 cm sopra il pelo, e la superficie si vede esattamente di taglio, come una riga sottile. Dura pochi fotogrammi, ma è proprio il punto in cui l'utente aveva visto il difetto la prima volta. Il test `test_occhio_sopra_acque` lo misura: margine più piccolo da 0,1 a 1,4 cm, in tutte e 6 le bocche.
- Proposta:
  - A) **(consigliata)** Alzare di 8-10 cm il fondo della bocca, per il primo metro del tubo. Un gradino basso, come la soglia di un portello, su cui si passa camminando senza accorgersene. L'occhio resta almeno 8 cm sopra il pelo, e anche l'acqua "fermata" dalla soglia ha più senso. Il test si stringe a 5 cm di margine, così non può tornare.
  - B) Abbassare ancora l'acqua delle vasche dei bivi (da 70 a 62 cm). Si risolve lo stesso, ma le vasche sembrano meno piene.
  - C) Lasciare com'è: è una riga di un attimo, ed è anche quello che si vede davvero con gli occhi a pelo d'acqua.
- Costo: medio (A: i tubi e le paratie si rigenerano da `tools/blender/inseguimento_proposte.py`, con i test delle morbidezze e dei tentacoli da rifare), piccolo (B). Rischio: medio per A (la geometria delle bocche tocca paratie, tentacoli e controllo di posizionamento), basso per B.
- Immagini già fatte:
  - `docs/collaudo/vasche_sotto/foglio_ins_A_tubo_1.jpg`, seconda riga "appena dentro": la superficie vista dalla bocca, quasi all'altezza degli occhi.
  - `docs/collaudo/vasche_sotto/foglio_parete_ritocchi.jpg`: la parete d'acqua com'è adesso.

## ambienti2-3 Dopo una morte nelle condotte o nel tunnel si riparte dopo un caricamento lungo
- Zona: torre, inseguimento e tunnel sottomarino: le ripartenze dai checkpoint oltre il portone.
- Cosa non va oggi, visto dal giocatore: nell'inseguimento e nel tunnel si muore spesso (lei prende in 6 secondi nelle vasche, 2,5 negli scoli, sotto i 2,5 m nel tunnel). A ogni morte il gioco ricarica tutta la sala principale e poi la torre (o il tunnel), dietro lo schermo nero. Dalla 0.3.18 è più leggero (interni e tecnici non si caricano più), ma resta un caricamento intero. In un inseguimento, morire e riprovare dovrebbe essere veloce, se no la tensione si spezza. Il tempo vero sul PC dell'utente non lo conosciamo: sulle nostre macchine di prova la sala non si misura bene.
- Proposta:
  - A) **(consigliata)** Prima misurare. Nella build c'è già la partenza da riga di comando (`--partenza=inseguimento --muori-dopo=…`, la usa la "Prova su Vulkan"), che scrive i tempi in un file: l'utente lancia una volta un collegamento già pronto e ci manda il file. Se la ripartenza supera circa 5 secondi, si passa a B.
  - B) Ripartenza "corta" oltre il portone: dopo una morte nella torre, nelle condotte o nel tunnel si rimette a posto solo la zona in cui si è (lei, paratie, grata, gommoni) e il giocatore torna al checkpoint, senza ricaricare la sala. Pochi secondi invece di un caricamento intero.
  - C) Lasciare com'è.
- Costo: piccolo (A), grande (B). Rischio: B tocca le ripartenze, il punto del crash della 0.3.17. Va fatto con calma, con tutti i test delle ripartenze, delle morti e della memoria, e con la "Prova su Vulkan".
- Immagini già fatte: nessuna.

## ambienti2-4 I tubi giusti e gli scoli si somigliano anche da fuori
- Zona: inseguimento, ai tre bivi.
- Cosa non va oggi, visto dal giocatore: al bivio si sceglie dalla paratia: la giusta ha la luce verde e l'anello di led verdi, la sbagliata una lampada rossa guasta. Una volta aperta la paratia, però, le due bocche si distinguono solo per il colore del tubo, che non dice niente (rosso, rosa, arancio: i colori del parco), e gli scoli finiscono in una vasca senza uscita dove lei prende (scelta approvata, che resta). Chi ha colpito il bersaglio sbagliato lo scopre solo quando è troppo tardi.
- Proposta:
  - A) **(consigliata)** Un dettaglio sulla bocca degli scoli, coerente con le vie sbagliate della torre: la fascia della bocca a strisce gialle e nere (nella torre vuol dire "chiuso") e un cartello a disegni di "uscita chiusa". Non cambia la regola, la rende leggibile prima di entrare.
  - B) Un rumore diverso dalla bocca degli scoli quando la paratia si apre: acqua ferma e un gocciolio, che fa capire che lì l'acqua non scorre.
  - C) Lasciare com'è.
- Costo: piccolo (A e B). Rischio: basso. A va controllato col controllo di posizionamento (il cartello appoggiato al muro, non davanti alla bocca).
- Immagini già fatte:
  - `docs/collaudo/vasche_sotto/foglio_ins_A_scolo_0.jpg`, prima riga: la bocca di uno scolo vista dalla vasca.
  - `docs/collaudo/vasche_sotto/foglio_ins_A_tubo_1.jpg`, prima riga: la bocca di un tubo giusto vista dalla vasca. Oggi si somigliano.
