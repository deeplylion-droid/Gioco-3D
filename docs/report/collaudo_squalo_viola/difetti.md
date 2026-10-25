# Collaudo dello squalo con la luce viola e la nebbia (lavoro/godot 4559b0c3)

Il collaudo l'ha fatto la squadra enigmi, che non ha costruito la scena. Il 25 ottobre, tra le 07:10 e le 10:00 UTC, ho guardato la scena dello squalo all'inizio del gioco: dal risveglio al ritorno del controllo, più 5 s. Ho guardato con la camera del giocatore e coi materiali veri, sia col preset **alto** (quello di serie) sia col preset **basso** (grafica al minimo, senza nebbia volumetrica). Non ho corretto niente.

## Come

- **Strumento**: `godot/tests/collaudo/giro_squalo.gd`. La scena si lancia come scena e non con `--script`, perché con `--script` il gioco si crede in una prova automatica e salta la scena dello squalo. Per ogni fotogramma scrive una riga con:
  - la camera e la sua distanza dalla pelle dello squalo (tutti i vertici, nella posa del momento);
  - luce viola, controluce e nebbia;
  - la porta, i suoni partiti e il tremolio;
  - le pipeline compilate.
  
  Fa anche uno scatto ogni 0,5 s, a 30 fotogrammi fissi al secondo, e alla fine due scatti (verso la porta e indietro).
- **Confronti nella sala vera**: sala principale caricata dal caricamento, come con "Nuova partita", ma senza schermo. Ho confrontato la scena con AtmosferaSqualo e senza ("prima").
- **Scatti**: la sala intera renderizzata non ci sta più nei 15 GB della macchina di prova. Sia col preset alto sia col basso il processo viene ucciso per mancanza di memoria a circa 14 GB, durante il caricamento (vedi la nota in fondo). Gli scatti sono quindi presi con gli interni nella posizione che hanno nella sala, con l'ambiente e gli attributi della camera della sala (LookSala). Il giocatore parte dove lo mette la sala, senza zaino. Il risveglio parte nello stesso fotogramma e c'è la stessa dissolvenza dal nero del caricamento. Ho verificato senza schermo che è equivalente alla sala intera: luce, controluce, nebbia, porta, tremolio e controllo sono identici a ogni fotogramma, e la camera differisce al massimo di 3 cm.

## Controlli

| Cosa | Esito | Misura |
|---|---|---|
| L'inizio resta buio | ok | Da 0 a 1 s lo schermo è nero (8 fotogrammi neri, poi la dissolvenza di 1,6 s). Fino a 1,5 s si vede solo il rosso delle lampade. La luce viola è accesa dal primo fotogramma, ma si ferma prima del giocatore (fogli alto, scatti 000-003). |
| Lo squalo è una sagoma scura col bordo viola | ok | Da 2 a 6 s la faccia resta scura, mentre bordi, pinne, mani e denti sono accesi di viola (005, 010). Da 7 a 11 s si stacca nero contro la nebbia viola della porta (015-021). A 7 s, quando si gira verso di te, la faccia si legge (014), come voluto: "è una sagoma, ma non sparisce". |
| La luce si spegne quando la porta si chiude | ok | La porta si chiude a 11,50 s e la luce viola è a 0 dallo stesso fotogramma; prima è a 28, e a 37,8 nel boato. |
| La nebbia si dirada in 4 s | ok | Durante la scena la densità è 0,3. Dal ritorno del controllo (14,33 s) vale 0,25 dopo 1 s, 0,15 dopo 2 s, 0,047 dopo 3 s e 0 dopo 4 s. |
| La nebbia non resta nel corridoio | ok | La densità è 0 da +4 s fino alla fine. Negli scatti a +5 s, verso la porta e indietro, il corridoio è pulito (039, 040). |
| Niente scatti la prima volta | ok | Le pipeline compilate durante il disegno sono 66, tutte nei primi 0,33 s, cioè a schermo ancora nero. Le specializzazioni, che si fanno in sottofondo e non bloccano, finiscono a 0,83 s. Poi fino alla fine non si compila più niente: né al boato, né alla porta, né quando la luce si spegne, la nebbia si dirada o torna il controllo. Col preset basso succede lo stesso (46 compilazioni nei primi 0,33 s). |
| La camera non entra mai nello squalo | ok | La camera non va mai a meno di 0,209 m dalla pelle (a 5,8 s); il piano vicino della camera è a 0,03 m. Non è mai dentro. |
| Porta, suoni e tremolio come prima | ok | Nella sala vera, con e senza AtmosferaSqualo, la camera ha posizione e rotazione identiche a ogni fotogramma (differenza 0) e lo scossone del tremolio è identico. La porta si chiude a 11,50 s in tutti e due i casi. I 23 suoni partono agli stessi tempi: minaccia 0,83 s; denti 3,2, 4,1 e 5,0 s; richiamo 5,43 s; ringhio 6,07 s; sbuffo 8,33 s; porta 11,50 s; 15 passi da 6,43 a 11,53 s. |
| Le luci tolte allo squalo tornano | ok | Nella sala vera ci sono 285 luci. Durante la scena 282 non toccano lo squalo, cioè tutte tranne la luce viola, la controluce e la luce della corsa. Col controllo tornano tutte: dopo sono 0 su 284 (la luce della corsa è stata tolta). Senza AtmosferaSqualo il conteggio è 0 sia durante sia dopo. |
| Grafica al minimo | ok, con una nota (D1) | Non c'è nebbia, quindi niente raggi. La luce viola dalla porta tinge di viola pareti, soffitto e pavimento intorno allo squalo, e lui resta una sagoma scura (scatti basso 015-021). L'inizio è buio e la fine è pulita come con l'alto. |

## File

- **`fogli/`**: uno scatto ogni 0,5 s dagli occhi del giocatore, con il tempo dall'inizio della scena.
  - `alto_1_scena.jpg`: 0-11,5 s;
  - `alto_2_fine_e_dopo.jpg`: 12 s fino a 5 s dopo il controllo, più verso la porta e indietro;
  - `basso_1_scena.jpg` e `basso_2_fine_e_dopo.jpg`: gli stessi momenti con la grafica al minimo;
  - `prima_senza_luce_viola_0-7s.jpg`: lo stesso giro senza AtmosferaSqualo, per confronto.
- **`scatti/`**: i momenti citati qui, a grandezza piena.
- **`dati/`**: i registri per fotogramma, in jsonl compresso.
  - `*_interni`: i giri con gli scatti;
  - `sala_*`: i giri senza schermo nella sala vera, con e senza AtmosferaSqualo.
- **Strumento**: `godot/tests/collaudo/giro_squalo.gd`, con `prepara_grafica.gd` per preparare la grafica. Il comando per lanciarlo è nel commento in cima al file.

## Difetti e note

Non ho trovato difetti che blocchino la build. Ci sono queste note, dalla più importante:

- **D1 (estetica, bassa): con la grafica al minimo la luce viola non fa ombra.** Lo dice il codice e lo confermano gli scatti. Con "ombre 0", Grafica spegne l'ombra delle luci a priorità 1, quella di serie, e LuceViola non ha `grafica_priorita_ombra`. Lo squalo quindi non proietta ombra e il pavimento davanti a lui è acceso di viola (scatti/basso_017). Si legge comunque come sagoma. Se si vuole tenere l'ombra anche al minimo, basta mettere `set_meta("grafica_priorita_ombra", 0)` su LuceViola: costa un'ombra di faretto per 11 s. Da decidere con grafica.
- **D2 (nota tecnica): la nebbia resta nel corridoio con densità 0.** Dopo il diradamento il FogVolume `NebbiaCorridoio` resta acceso con densità 0 per tutto il gioco. Non si vede niente, ma la nebbia volumetrica lo rasterizza a ogni fotogramma finché gli interni sono in vista. Nasconderlo (`visible = false`) a diradamento finito non cambierebbe niente a schermo.
- **D3 (già così prima, non dipende dalla luce viola): l'apertura sopra lo squalo a circa 6 s.** In alto a sinistra si vede il soffitto del corridoio attraverso un'apertura nella sagoma dello squalo, mentre si gira, tra il braccio alzato e la testa. Il bordo viola ne accende il contorno (scatti/alto_012), ma l'apertura c'è identica nello scatto senza AtmosferaSqualo (scatti/prima_012). La camera è a 0,23 m dalla pelle, quindi non è la camera dentro lo squalo.
- **Nota sulla memoria, per tutte le squadre.** La sala principale renderizzata con llvmpipe non ci sta più nella macchina di prova. Il processo viene ucciso dal limite di memoria con 12,3 GB di memoria anonima più 1,6 GB condivisa, durante il caricamento, sia col preset alto sia col basso. CLAUDE.md dice ancora 12-13 GB. Gli scatti della sala intera vanno fatti per parti, come qui con gli interni.
