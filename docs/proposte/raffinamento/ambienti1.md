# Raffinamento del capitolo 1: proposte di ambienti-1

Zone: risalita, fiume lento, infermeria, stanza delle pozze, scala di servizio e corridoi. Sono solo proposte: nel gioco non è stato cambiato niente. Le immagini sono quelle già fatte nei collaudi. Non ci sono le cose già decise o ancora aperte: il cartello delle pozze nel corridoio prima dell'infermeria e l'angolo vuoto all'ingresso degli scatoloni (A/B).

## ambienti1-1 La cima della scala di servizio: nel buio non si capisce dove andare

- **Zona**: la scala di servizio dietro la porta stagna delle pozze, dalla cima della seconda rampa alla porta del magazzino.
- **Cosa non va oggi, visto dal giocatore**:
  - Le due rampe si leggono bene: c'è la luce rossa in cima e le strisce gialle e nere sui gradini.
  - Dopo l'ultima rampa, invece, il pianerottolo e il corridoio verso il magazzino sono neri: muri, pavimento e spigoli spariscono, e si vede solo il rettangolo azzurro della porta in fondo.
  - Il giocatore non sa se davanti c'è un gradino, una svolta o un muro. Avanza a tentoni, e quel punto sembra un errore più che una scelta di paura.
- **Proposta**:
  - **A) (consigliata)** Senza luci nuove: si portano sul pavimento del pianerottolo e del corridoio le stesse strisce gialle e nere dei gradini, come nastro antiscivolo, e una fascia catarifrangente all'altezza della mano sul muro. Prendono il poco riflesso della luce rossa e della porta, e disegnano la strada nel buio. È coerente con la scala, che è un passaggio tecnico, e il buio resta.
  - **B)** Una seconda lampada a gabbia rossa, uguale a quella in cima alla rampa, sopra la porta del magazzino. Si capisce subito dove andare, ma è una luce in più.
  - **C)** Lasciare così, buio pieno.
- **Costo**: piccolo. **Rischio**: basso. Con A non cambia niente nelle luci; va solo controllato che le strisce non si vedano troppo nella nebbia.
- **Immagini già fatte**: `docs/collaudo/stanza_pozze/ricontrollo_0319/fogli/scala_su.jpg` (lavoro/godot 22a27ce8). Negli scatti dal 041 al 049 si vede il tratto dopo l'ultima rampa: tutto nero e solo la porta azzurra in fondo.

## ambienti1-2 La stanza delle pozze è troppo nuova e pulita rispetto al resto del parco

- **Zona**: la stanza delle pozze colorate.
- **Cosa non va oggi, visto dal giocatore**:
  - Le zone intorno sono tutte segnate dall'abbandono: l'infermeria, il corridoio del fiume con la muffa e le colature, la scala arrugginita.
  - Questa stanza invece ha muri grigi lisci, piastrelle intatte, passerella pulita e acqua perfetta. Sembra appena costruita, e l'occhio la sente diversa dal resto del parco.
- **Proposta** (i colori delle pozze e la luce restano come sono, perché sono l'indizio):
  - **A) (consigliata)** Usura dell'acqua, come in una piscina chiusa da anni:
    - aloni di calcare bianchi sui bordi di piastrelle delle pozze;
    - colature di ruggine sotto i tubi e i bulloni;
    - qualche piastrella scheggiata o mancante sui muri;
    - una striscia d'umido alla base dei muri;
    - sulla passerella, piccole impronte bagnate di piedini che dalla porta vanno verso le pozze: i bambini sono passati di qui.
  - **B)** Come A, ma senza le impronte: solo calcare, ruggine e piastrelle rotte.
  - **C)** Lasciarla pulita, come una stanza tecnica rimasta chiusa.
- **Costo**: medio. **Rischio**: basso. Le macchie non devono cadere sull'acqua né cambiare i colori; si rifà il controllo di posizionamento.
- **Immagini già fatte**:
  - `docs/collaudo/stanza_pozze/fogli/sbagliato.jpg` e `docs/collaudo/stanza_pozze/fogli/giro_viste.jpg` (lavoro/godot 22a27ce8): la stanza com'è, con muri e passerella puliti;
  - `docs/collaudo/corridoio_fiume/r09_muffa_ovest.jpg` e `r10_oblo_muffa_e_colatura.jpg`: la muffa e le colature del corridoio del fiume, il livello di usura a cui avvicinarsi.

## ambienti1-3 Stanza delle pozze: non si vede quanti colori hai già tolto

- **Zona**: la stanza delle pozze.
- **Cosa non va oggi, visto dal giocatore**:
  - Il controllo si fa al terzo colore tolto: se uno è sbagliato, solo allora la lampada rossa lampeggia e le pozze si riempiono di nuovo.
  - Prima non c'è nessun segno che la stanza "conti" i colori. Chi ne toglie uno a caso per provare non sa che sta già usando uno dei tre tentativi.
  - Quando poi tutto si riempie di colpo, può non capire perché.
- **Proposta**:
  - **A) (consigliata)** Sul quadro elettrico già appeso alla parete di destra, quella della porta stagna, tre spie tonde spente:
    - a ogni colore tolto se ne accende una, gialla;
    - al terzo diventano tutte verdi, se è giusto, insieme alla porta, oppure rosse lampeggianti, se è sbagliato, insieme alla lampada rossa;
    - al riempimento si spengono.
    È come un contatore, senza scritte, e usa un oggetto che c'è già.
  - **B)** Tre tacche sul tubo sopra le pozze, che si illuminano una alla volta.
  - **C)** Lasciare così: le pozze vuote bastano a contare.
- **Costo**: piccolo. **Rischio**: basso. Tocca la logica dell'enigma solo per leggere quanti colori sono stati tolti, quindi va fatta insieme a enigmi.
- **Immagini già fatte**: `docs/collaudo/stanza_pozze/fogli/sbagliato.jpg` (lavoro/godot 22a27ce8). Si vede il quadro sulla parete di destra, dove andrebbero le spie, e la lampada rossa quando si sbaglia.

## ambienti1-4 Le pile di scatoloni del fiume: salvarle una volta per tutte invece di costruirle a ogni caricamento

- **Zona**: il corridoio degli scatoloni del fiume lento, fino al salvagente.
- **Cosa non va oggi, visto dal giocatore**:
  - Le circa 120 colonne di scatoloni (3.500 scatole) le costruisce il gioco a ogni caricamento del fiume, provando ogni colonna contro le rocce, le transenne e le vicine. È tempo in più quando la zona si carica, soprattutto sui PC lenti.
  - C'è anche un rischio: basta un piccolo cambio al codice e tutte le pile si rimescolano. È successo il 2 novembre, quando una correzione all'ingresso rischiava di cambiare anche pile già controllate. Allora l'ho evitato apposta, ma ogni volta bisogna starci attenti.
- **Proposta**:
  - **A) (consigliata)** Si costruiscono una volta sola, come sono adesso, e si salvano in un file della scena. Il gioco le carica già pronte: caricamento più veloce, e pile identiche per sempre a quelle approvate e collaudate. Per cambiarle si rifà il file di proposito.
  - **B)** Si continuano a costruire, ma il risultato viene salvato in un file la prima volta e riusato. Lo stesso guadagno, ma più complicato.
  - **C)** Lasciare così.
- **Costo**: medio. **Rischio**: basso, perché l'aspetto non cambia. Si rifanno il controllo di posizionamento, il test della fuga del bambino e una misura del caricamento prima e dopo.
- **Immagini già fatte**: `docs/proposte/scatole_sfalsate/foglio2_lati_1.jpg` e `pianta_dopo2.png` (lavoro/scatole-sfalsate 79a367e5): le pile come sono ora, che resterebbero uguali.
