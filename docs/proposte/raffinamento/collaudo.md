# Raffinamento del capitolo 1: le proposte del collaudo

Squadra collaudo, 4 novembre. Sono cinque proposte, tutte nate da cose misurate nei collaudi dalla 0.3.17 alla 0.3.20 col giocatore vero. Sono solo proposte: nel gioco non ho cambiato niente.

Ho lasciato fuori le cose già decise dall'utente:
- niente spaventi nuovi con lei, e lei non si avvicina di più;
- la nebbia non si tocca;
- le lampade del fiume restano al 20%;
- teli e faretto restano così;
- l'angolo vuoto degli scatoloni lo decide l'utente.

Le luci le tocco solo in un punto, dove ora non si vede niente.

## collaudo-1 La scaletta del bacino non arriva all'acqua
- Zona: bacino in fondo all'inseguimento, dove lei sbuca dal pozzo (SB1).
- Cosa non va oggi, visto dal giocatore: dopo che l'acqua è stata abbassata (bacino a 74 cm), la scaletta comincia sopra il bordo di piastrelle, e il bordo sta 26 cm sopra l'acqua. Da dentro l'acqua si vede un muretto, e la scaletta sopra che sembra appesa.
- Proposta:
  - A) allungare la scaletta di due pioli, fino a sotto il pelo dell'acqua. **Consigliata**: è la cosa che si vede, e non cambia niente del gioco.
  - B) abbassare il bordo di piastrelle solo davanti alla scaletta.
  - C) lasciarla così: si usa solo in SB1, che chiude il capitolo.
- Costo: piccolo. Rischio: basso. Con A va ricontrollato solo che la scala si prenda ancora come prima.
- Immagini già fatte: `docs/collaudo/0320/fogli/bacino_paperella_scaletta.jpg` (branch `lavoro/collaudo-0320`, 341dc1cb). Gli scatti in basso: la scaletta vista dagli occhi, da vicino in basso e in cima.

## collaudo-2 Le lampade rosse della scala di servizio sono 2 cm troppo basse
- Zona: la scala di servizio, dalla stanza delle pozze verso C3: la lampada nuova in cima alla seconda rampa e quella del corridoio.
- Cosa non va oggi, visto dal giocatore: la parte di sotto della lampada sta a 1,98 m dal pavimento e sporge 50 cm dal muro, in un passaggio largo 2 m. La regola dell'utente vuole libero lo spazio fino a 2 m sopra dove si cammina. Chi passa vicino al muro se la trova all'altezza della fronte. Il controllo automatico la accetta, ma è al limite.
- Proposta:
  - A) alzarle di 5 cm (la parte di sotto a 2,03 m). **Consigliata**: è un numero solo nel codice, e rispetta la regola.
  - B) lasciarle così.
- Costo: piccolo. Rischio: basso (va rifatto il controllo di posizionamento).
- Immagini già fatte: `docs/collaudo/stanza_pozze/ricontrollo_0319/fogli/cerniere.jpg` (branch `lavoro/collaudo-stanza-pozze` 359ae59b, già in `lavoro/godot`). Gli scatti dal 009 al 014 sono le lampade della scala, di fronte e di lato.

## collaudo-3 Il corridoio verso C3 è quasi nero
- Zona: in cima alla scala di servizio, il tratto in piano col muro dell'oblò, fino alla porta di C3.
- Cosa non va oggi, visto dal giocatore: dopo la lampada della scala, per una decina di metri lo schermo ha una luminosità media fra 1,5 e 4 su 255. Si vede solo lei nell'oblò, e poi un rettangolo chiaro che è la porta di C3. Non si vedono pavimento e muri.
- Proposta:
  - A) una lampada rossa piccola, come quelle della scala, sopra la porta di C3, al 20% come le altre. **Consigliata**: la porta diventa la meta che si vede, e lei nell'oblò resta l'unica cosa forte.
  - B) lasciarlo così: il buio fa risaltare lei.
- Costo: piccolo. Rischio: basso, solo da guardare dagli occhi che lei nell'oblò resti la cosa più chiara.
- Immagini già fatte: `docs/collaudo/stanza_pozze/ricontrollo_0319/fogli/scala_su.jpg` (branch `lavoro/collaudo-stanza-pozze` 359ae59b). Gli ultimi scatti sono il corridoio verso C3. I numeri, scatto per scatto, sono in `docs/collaudo/stanza_pozze/ricontrollo_0319/scala_luminosita.txt` (scatti 038-047).

## collaudo-4 Ripartire dopo una morte è lento dove si muore spesso
- Zona: inseguimento nelle vasche, tunnel sottomarino; vale per ogni ripartenza.
- Cosa non va oggi, visto dal giocatore: ogni volta che lei ti prende c'è la scena (5 s, si salta tenendo premuto Spazio), poi la sala si ricarica. Sulla macchina di prova, saltando la scena, si riparte dopo 5,7 s nell'inseguimento, 9,0-9,2 s nel tunnel, 8,0-9,8 s nel fiume. Sul PC dell'utente sarà più veloce, ma nell'inseguimento si muore spesso, e la stessa attesa ripetuta stanca.
- Proposta:
  - A) dalla seconda morte allo stesso checkpoint, la scena si accorcia da sola a un secondo (la presa, poi il nero). **Consigliata**: la prima volta la scena fa paura intera, dopo non serve.
  - B) ripartire senza ricaricare la sala. Più veloce, ma è proprio il punto dove ci sono stati i crash delle ripartenze: non lo consiglio.
  - C) lasciare così.
- Costo: A piccolo, B grande. Rischio: A basso; B alto.
- Immagini già fatte: nessuna. I tempi sono nei resoconti `docs/collaudo/0320/resoconto.md` (branch `lavoro/collaudo-0320` 341dc1cb) e `docs/collaudo/0317/resoconto.md` (branch `lavoro/collaudo-0317` 17a27166).

## collaudo-5 Entrando nei tubi, l'occhio passa a 1 mm dall'acqua
- Zona: le bocche dei tubi e degli scoli che partono dalle vasche dei bivi dell'inseguimento.
- Cosa non va oggi, visto dal giocatore: oggi niente, l'acqua si vede sempre da sopra. Ma il test che lo controlla (test_occhio_sopra_acque, 64 ok) dice che entrando nello scolo 0 e nel tubo 3 l'occhio passa solo 1 mm sopra il pelo, nello scolo 2 4 mm, nei tubi 1 e 2 1 cm. Basta un passo un po' più basso, o un fotogramma più lento, e si rivede l'acqua da sotto. È proprio la cosa che l'utente ha segnalato due volte (sulla 0.3.16 e sulla 0.3.19).
- Proposta:
  - A) nei primi metri del tubo, dove si scende accovacciati, tenere l'occhio almeno 3 cm sopra il pelo, e far chiedere al test almeno 3 cm. **Consigliata**: non cambia niente di quello che si vede oggi, e toglie il rischio.
  - B) lasciare così, col test che lo controlla a 0.
- Costo: piccolo. Rischio: basso (va rifatto test_occhio_sopra_acque e uno sguardo agli imbocchi).
- Immagini già fatte: `docs/collaudo/0320/fogli/tubi_entrando.jpg` e `tubi_bocche.jpg` (branch `lavoro/collaudo-0320` 341dc1cb): lo scolo 0 e il tubo 3 visti da chi ci entra, e le bocche viste da dentro.
