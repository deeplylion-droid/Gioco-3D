# Raffinamento del capitolo 1: proposte di mascotte

Jilly e le altre creature: animazioni, comportamento nell'inseguimento e nel tunnel, voce e suoni. Solo proposte:
niente è stato cambiato nel gioco. Niente spaventi nuovi, Jilly resta alla distanza di adesso, e il bambino col cubo
resta con la regola scelta (A). Le immagini e i video sono quelli già fatti, sul branch `lavoro/godot` (22a27ce8).

In ordine di utilità, secondo me.

## mascotte-1 I bambini non fanno nessun suono

- Zona: corridoio prima del fiume (bambino col cubo), scala del corridoio C2 e tunnel sottomarino (agnellini).
- Cosa non va oggi, visto dal giocatore: quando un bambino ti guarda e poi scappa, non si sente niente: né i passi
  né altro. Un bambino che corre via sulle piastrelle bagnate in silenzio sembra un'immagine, non qualcosa che c'è
  davvero. E chi è girato dall'altra parte non ha nessun motivo per voltarsi. (Ho controllato il codice: nessun suono
  è collegato ai bambini di adesso; lo stinger musicale dei bambini c'è, ma è collegato solo a quelli vecchi della
  balconata, che sono spenti.)
- Proposta:
  - **A) i passi**, consigliata. Passi di corsa leggeri, che vengono da dove sta lui e si sentono anche di spalle.
    Diversi per i due: il bambino col cubo con la muta bagnata (un "ciac" morbido e svelto), l'agnellino di peluche
    zuppo (tonfi soffici e spugnosi, con un filo d'acqua strizzata). Bassi di volume, come i passi del giocatore.
    È il modo più semplice per farli sembrare veri, e non aggiunge spaventi.
  - **B) i passi più lo stinger** dei bambini (la nota musicale breve che c'è già) la prima volta che lo vedi.
  - **C) lasciare il silenzio.**
  - Con la A, chi si ferma nel corridoio sentirà correre il bambino col cubo anche se non lo stava guardando: lo
    noterà più spesso. La regola di quando compare non cambia.
- Costo: piccolo. Rischio: basso; i suoni si fanno sentire prima di metterli nel gioco.
- Immagini già fatte:
  - `docs/proposte/bambini_sfuggita/corridoio_fiume.mp4`: il bambino col cubo che guarda e scappa (è il momento in
    cui si sentirebbero i passi).
  - `docs/proposte/bambini_sfuggita/galleria_tunnel.mp4`: l'agnellino del tunnel che scappa nella galleria.

## mascotte-2 Il getto in faccia: una reazione subito

- Zona: inseguimento nelle condotte (le vasche) e tunnel sottomarino.
- Cosa non va oggi, visto dal giocatore: per respingere Jilly serve mezzo secondo di getto in faccia. In quel mezzo
  secondo lei non fa niente: si vedono solo gli spruzzi del getto. Quindi non capisci se la stai colpendo nel punto
  giusto (il viso) o sul corpo, che non serve, finché all'improvviso si ritrae. Nel momento più teso non sai se stai
  facendo la cosa giusta.
- Proposta:
  - **A) un sussulto appena l'acqua le tocca il viso**, consigliata: l'occhio si strizza un poco e la testa si
    tira indietro di qualche centimetro, e si sente un piccolo verso soffocato. Al mezzo secondo parte la ritirata di
    adesso. Ti dice subito "stai mirando bene, continua". Le regole (mezzo secondo, distanze, tempi) non cambiano.
  - **B) solo il suono**: uno sfrigolio d'acqua sul viso che cresce fino alla ritirata.
  - **C) lasciare com'è.**
- Costo: piccolo. Rischio: basso (è un movimento piccolo sopra quelli che ci sono).
- Immagini già fatte:
  - `docs/report/mascotte/lei_inseguimento/3_respinta_4.3s.jpg`: la respinta nelle condotte, com'è oggi.
  - `docs/proposte/inseguimento_effetti/confronto_ritrae.jpg`: lei che si ritrae nel tunnel.

## mascotte-3 Gli agnellini animati come il bambino col cubo

- Zona: scala del corridoio C2 (l'agnellino che si tuffa nel buco) e tunnel sottomarino (l'agnellino della galleria).
- Cosa non va oggi, visto dal giocatore: il bambino col cubo ora è vivo da fermo e corre coi piedi ben piantati. Gli
  agnellini usano ancora le animazioni di prima. Sul bambino col cubo avevo misurato: da fermo era immobile come una
  statua, alla partenza passava di colpo a corsa piena, e correndo i piedi pattinavano. Sugli agnellini non l'ho
  misurato, ma usano lo stesso modo di partire e di correre. Visti uno dopo l'altro, si nota che non sono fatti allo
  stesso livello ("attenzione alle animazioni. falle bene").
- Proposta:
  - **A) tutti e due gli agnellini**, consigliata. Il fermo vivo (il peso che passa da un piede all'altro, il
    respiro), il primo passo vero e la corsa coi piedi fermi a terra, come il bambino col cubo. Resta tutto quello che
    hai scelto: la girata veloce della scala (com'era nella 0.3.15), il tuffo nel buco, e l'agnellino del tunnel che
    non sparisce mai sotto gli occhi.
  - **B) solo l'agnellino del tunnel**, quello che si vede correre più a lungo.
  - **C) lasciare com'è.**
- Costo: medio. Rischio: medio, perché la girata veloce della scala va tenuta uguale. Si misura ogni prova come per il
  bambino col cubo (piedi, scatti, pavimento) e si rifà il video prima e dopo.
- Immagini già fatte:
  - `docs/collaudo/bambino_cubo/bambino_cubo_prima_dopo.mp4`: il bambino col cubo prima e dopo, cioè quello che
    cambierebbe negli agnellini.
  - `docs/collaudo/bambini_squalo_0317/1_tunnel_corsa_in_galleria.jpg`: l'agnellino del tunnel com'è oggi.
  - `docs/collaudo/bambini_squalo_0317/2_agnellino_c2_girata_prima_dopo.jpg`: la girata dell'agnellino della scala.

## mascotte-4 Nelle condotte lei sale sempre nello stesso modo

- Zona: inseguimento nelle condotte, le tre vasche dei bivi.
- Cosa non va oggi, visto dal giocatore: nelle tre vasche Jilly sale dall'acqua sempre con la stessa animazione.
  Alla seconda la riconosci, alla terza te l'aspetti: la paura cala proprio mentre l'inseguimento dovrebbe crescere.
  Fa eccezione la grata, dove sale più veloce.
- Proposta (le regole e i tempi restano uguali: da quando è su hai sempre lo stesso tempo per ricacciarla):
  - **A) una salita diversa per ogni vasca**, consigliata. Vasca 1 com'è oggi. Vasca 2: prima esce una mano che
    si aggrappa al bordo, poi lei si tira su. Vasca 3: sale più in fretta, già con l'occhio puntato su di te. Ognuna
    coi tentacoli morbidi, controllati come gli altri.
  - **B) due salite**: la vasca 1 come oggi, e una salita nuova per la 2 e la 3.
  - **C) lasciare com'è.**
- Costo: medio (due animazioni nuove, con i tentacoli morbidi e i loro controlli). Rischio: medio (le pose nuove vanno
  controllate perché i tentacoli non entrino nei muri; i controlli automatici ci sono già).
- Immagini già fatte:
  - `docs/report/mascotte/lei_inseguimento/1_sale_1.0s.jpg`: la salita di oggi.
  - `docs/report/mascotte/lei_inseguimento/giro/2_lei_ti_raggiunge.jpg` e `giro/9_vasca_3.jpg`: lei nella vasca 1 e
    nella vasca 3, dagli occhi del giocatore.

## mascotte-5 Il battito del cuore anche nelle condotte

- Zona: inseguimento nelle condotte (prima del tunnel).
- Cosa non va oggi, visto dal giocatore: nel tunnel, quando lei si avvicina, c'è il battito del cuore che accelera
  (più i colpi bassi). Nelle condotte no: quando lei ti incombe da una vasca si sentono solo la sua voce e l'acqua.
  Le due fughe sembrano fatte in modo diverso, e nelle condotte manca un segnale chiaro di "è vicina, sbrigati".
- Proposta:
  - **A) solo il cuore, solo quando lei è su**, consigliata. Il battito parte quando lei sale in una vasca e
    rallenta quando la ricacci sotto; più è vicina, più è veloce, come nel tunnel. I colpi bassi restano solo nel
    tunnel, che così resta il punto più forte.
  - **B) cuore e colpi bassi** per tutte le condotte, come nel tunnel.
  - **C) lasciare com'è**: il silenzio delle condotte fa da contrasto col tunnel.
- Costo: piccolo (i suoni sono quelli già approvati). Rischio: basso.
- Immagini già fatte:
  - `docs/proposte/voce_lei/lei_inseguimento_con_voce.mp4`: le condotte con la voce di lei, senza il cuore.
