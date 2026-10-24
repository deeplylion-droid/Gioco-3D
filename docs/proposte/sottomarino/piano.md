# Inseguimento lungo: il viaggio sottomarino (piano di ambienti-2, 24 ottobre)

Richiesta dell'utente dopo la v0.3.12: "L'inseguimento con jilly va allungato. Recuperiamo quel percorso che
avevamo lasciato indietro (sottomarino mi pare?) e facciamo che dopo gli scivoli sali la scaletta e inizia quello,
con jilly che ti insegue visibilmente dietro, e tu che devi procedere e spruzzarla per rallentarla ogni tanto.
Falla con la bocca aperta in questa fase." E poi: "era l'alternativa al fiume che mi avevi proposto".

Solo piano scritto: niente render né scatti nuovi finché l'utente non sceglie. Per ogni punto ci sono le opzioni,
i pro e i contro e la raccomandazione (R).

## Da dove si parte (com'è oggi nel gioco)

- La sala delle condotte (SalaInseguimento) è figlia della sala della torre e si costruisce a pezzi insieme a lei.
  Nel bacino di scarico lei sbuca dal pozzo e ti guarda (SB1). La scaletta sul bordo ovest del bacino porta a una
  passerella e alla porta di servizio, nel muro in comune con la torre (x 40, quota -30, cioè 10 m sotto il fondo
  della torre). Oggi lì c'è il nero e la fine del capitolo.
- Lei è alta 4,5 m. Nelle vasche sale dall'acqua, e un getto in faccia di circa mezzo secondo (0,6 litri) la
  ricaccia sotto.
- Lo zaino ha 20 litri. Si ricarica nell'acqua che scorre: sulla ciambella del fiume lento entrano 8 litri al
  secondo.
- Il fiume lento ha già la ciambella (2,2 m/s; sparando all'indietro si va fino a 3,2 m/s, in avanti si frena fino
  a 1,2 m/s), le paratie col bersaglio e i checkpoint.
- Del fiume B ci sono i modelli Meshy in assets_src/fiume_lento/meshy/: corallo, ancora, forziere, rete_stelle,
  portello, pesce_vetroresina, palombaro, tartaruga. Ci sono anche i 5 scatti della proposta del 19 ottobre.
- A piedi il giocatore va a 3,4 m/s, a 5,8 m/s di corsa e a 1,7 m/s accovacciato.

## 1. Dove va fisicamente e come si carica

**Dove.** Oltre la porta di servizio del bacino, verso ovest, sotto il fondo della torre: è un corridoio di
servizio che si apre nel tunnel. La porta è già lì e si raggiunge con la scaletta, come chiede l'utente. Il tunnel
può girare sotto la torre e uscire verso sud o verso nord, dove non c'è niente di costruito. L'acqua del bacino
scende nel canale del tunnel: è lì che entra lei.

**Come si carica:**
- **a) Figlio della sala della torre, come la sala delle condotte.**
  - Pro: è il sistema di oggi, e non serve niente di nuovo.
  - Contro: in memoria restano insieme torre, condotte e tunnel. La memoria video sale oltre l'attuale circa
    1,79 GB. Nel sandbox la sala con la torre arriva già a 12-13 GB di RAM, e le prove non ci starebbero.
- **b) Scena a parte, caricata in un thread mentre sei nelle condotte, come la precarica della torre.** Dopo la
  prima curva del tunnel, quando la torre e le condotte non si vedono più, queste si liberano.
  - Pro: in memoria resta solo il tunnel (stima: 150-250 MB di memoria video in più rispetto alle condotte da
    sole, quindi il picco sta sotto i 2 GB). Le prove nel sandbox stanno nei limiti. Nessun caricamento visibile.
  - Contro: serve un punto di passaggio pulito, e lei deve passare da una scena all'altra (vedi la parte su
    come ti segue).
- **c) Cambio di scena con un nero breve alla porta.**
  - Pro: è la più semplice.
  - Contro: rompe la continuità, perché lei "visibilmente dietro" si perde nel nero.

**R: b.** Lei passa al tunnel tuffandosi nel bacino e riemergendo nel canale del tunnel dietro di te. I
checkpoint del tunnel ripartono dentro il tunnel, senza ricaricare la torre.

## 2. Come si muove il giocatore

- **a) A piedi, sulla banchina di servizio accanto al canale.** Lei arriva nel canale, alle tue spalle.
  - Pro: è il verbo dell'utente, "devi procedere". Si corre e ci si gira per spruzzarla, come un inseguimento
    vero. La tensione la decide il giocatore.
  - Contro: girarsi mentre si corre è più difficile. La ricarica va messa in punti precisi (vedi il punto 4).
- **b) Sulla ciambella, con la corrente.** È il fiume lento rifatto sottomarino.
  - Pro: c'è già quasi tutto: corrente, spinta del getto e ricarica automatica. E c'è un bel doppio senso:
    sparando all'indietro la rallenti e intanto acceleri tu.
  - Contro: il giocatore è portato, non "procede". La velocità è decisa dalla corrente, e si somiglia molto al
    fiume lento che c'è già.
- **c) A guado, nell'acqua fino al ginocchio.**
  - Pro: si sente il peso dell'acqua, ed è il più angosciante.
  - Contro: è lento (circa 2 m/s), quindi ci vuole più tunnel per lo stesso tempo, e può stancare.
- **d) Misto:** a piedi sulla banchina, con un tratto finale sulla ciambella (o uno scivolo breve) fino al
  portello.
  - Pro: varia il ritmo.
  - Contro: più lavoro.

**R: a**, con la d come variante se l'utente vuole più varietà.

## 3. Quanto dura e com'è la strada

**Durata:**
- **a) circa 2 minuti** (circa 250 m);
- **b) circa 3 minuti** (circa 350-400 m, con gli ostacoli del punto 5);
- **c) 4 minuti** (500 m o più).

Più è lungo, più tunnel c'è da costruire e controllare, e più è facile che stanchi senza idee nuove.

**R: circa 3 minuti.** L'inseguimento di oggi dura circa 5:40, quindi in tutto si arriva a quasi 9 minuti.

**La strada, a parole (con la R):**
1. Dalla porta di servizio, un corridoio stretto e basso che si apre nel tunnel. È la prima volta che si vede
   il mosaico blu con gli oblò illuminati.
2. Un rettilineo di 40-50 m, che serve a vederla arrivare dietro.
3. Una curva larga a sinistra. A ogni curva lei sparisce un attimo e ricompare: è il momento di girarsi e
   spruzzarla.
4. Una sala più larga con il palombaro e il forziere: il primo portello col bersaglio.
5. Un tratto a S stretto con un passaggio basso.
6. Un rettilineo lungo con i pesci sui piedistalli e la tartaruga appesa.
7. L'ultima curva e il portello da sottomarino in fondo.

**Misure:** il canale è largo circa 4 m, la banchina 2 m, quindi il tunnel è largo 6-7 m. La volta sta a
**6,5 m dal pelo dell'acqua**: lei è alta 4,5 m, nel canale ne restano fuori circa 3,5-4 m, e così ci sta col
margine per la bocca spalancata e i tentacoli alzati. Nei passaggi bassi la volta scende a 3 m sulla banchina e
lei deve rallentare per passare sotto.

## 4. Come ti segue e come la rallenti

**Distanza:**
- **a) Fissa, a 10-12 m dietro.** Se ti fermi, si avvicina a 4 m/s.
- **b) Elastica, tra 8 e 18 m.** Corre di più se sei lontano e di meno se sei vicino, così si vede sempre.
  Diventa pericolosa solo se ti fermi o sbagli.

**R: b.** Ti prende quando arriva a meno di 2,5 m, con la fauce di presa e le vene nell'occhio
(medusa_statue.gd attacca()).

**Il getto:**
- **a)** Un getto in faccia la ferma per 2 s e la rimanda indietro di circa 6 m.
- **b)** Come la a, ma dopo 3 getti di fila "si arrabbia" e torna più veloce per qualche secondo.
- **c)** Si rallenta in proporzione a quanto la tieni sotto il getto.

**R: a.** È leggibile e c'è già nelle vasche. Getto da circa mezzo secondo (0,6 litri), come oggi.

**Ricarica dello zaino:**
- **a)** Si aspira dal canale in qualunque punto. Il livello non cambia, perché è acqua che scorre.
  - Pro: semplice.
  - Contro: tensione zero.
- **b)** Solo dalle bocchette della corrente (2-3 lungo il tunnel), messe in vista.
  - Pro: diventano tappe tese, perché ti fermi mentre lei arriva.
  - Contro: se uno le manca, resta a secco.

**R: b**, con un pieno all'ingresso.

**Checkpoint:**
- all'ingresso del tunnel;
- dopo il primo portello;
- dopo il passaggio basso.

Si riparte col serbatoio pieno e lei a 18 m.

## 5. Ostacoli lungo il tunnel

- **a) Solo corsa e getti.**
  - Pro: è il più pulito.
  - Contro: dopo un minuto può diventare ripetitivo.
- **b) Due portelli da aprire col bersaglio** (la meccanica delle paratie: 1,5 s di getto sul bersaglio), mentre
  lei si avvicina: devi scegliere se spruzzare il bersaglio o lei.
  - Pro: è la tensione più bella e riusa una regola che il giocatore conosce già.
- **c) Passaggi bassi accovacciati e un salto col getto.**
  - Pro: varia i movimenti.
  - Contro: il salto col getto, inseguiti, rischia di essere frustrante.

**R: b più un passaggio basso** (dalla c, senza il salto).

## 6. Il finale

- **a) Il portello da sottomarino all'approdo.** Lo raggiungi, si chiude dietro di te con il volantino che gira,
  e lei ci sbatte contro con la faccia schiacciata sull'oblò e la bocca spalancata. Poi nero e "FINE DELLA
  DEMO".
  - Pro: è un'immagine forte e chiude bene.
  - Contro: serve un'animazione nuova (lo schianto sull'oblò).
- **b) Lei resta incastrata nel passaggio basso.** Tu prosegui, ti giri, e lei allunga un tentacolo verso di te;
  poi nero.
  - Pro: è più inquietante.
  - Contro: è meno chiaro come fine.
- **c) Tu prendi un ascensore di servizio.** Lei arriva quando le porte si chiudono.
  - Contro: è già visto.

**R: a.**

**SB1:**
- **a) Resta com'è** (lei sbuca dal pozzo e ti guarda) e diventa l'inizio della fase. Invece del nero, lei si
  tuffa e tu sali la scaletta: alla porta ti giri e la vedi riemergere nel canale con la bocca aperta.
- **b) Come la a, ma più breve:** ti guarda per 1-2 s, poi parte.

**R: b.** L'immagine resta, il ritmo no.

## 7. Stima delle ore e chi fa cosa

**ambienti-2:**
- Tunnel nel generatore Blender: volta a mosaico, oblò, canale, banchina, sale, passaggi bassi, portelli e
  modelli Meshy del fiume B messi con lo strumento comune: **12-16 h**.
- Logica: lei che segue, getti, prese, portelli, ricarica, checkpoint, caricamento in thread e rilascio della
  torre, finale: **10-12 h**.
- Collaudo e controlli di posizionamento: **4-6 h**.
- Totale: circa **26-34 h**.

**mascotte**, animazioni di lei a bocca aperta:
- avanzare nel canale (ciclo), girarsi in curva, respinta col getto, presa, tuffo nel bacino e riemersione,
  schianto sull'oblò;
- **10-14 h**.

**grafica:** i tentacoli morbidi mentre avanza, e la scia nell'acqua del canale: **6-8 h**.

**Voce:** i versi della scelta B ci sono già (incombe, presa, lamento, rabbia). Forse serve un ruggito "a bocca
aperta" per la corsa.

## Immagini già fatte per la pagina (niente di nuovo)

**Il fiume B, "viaggio sottomarino" (19 ottobre):**
- docs/proposte/fiume_aspetto/fiume_B_imbarco.jpg
- docs/proposte/fiume_aspetto/fiume_B_bivio.jpg
- docs/proposte/fiume_aspetto/fiume_B_bersaglio.jpg
- docs/proposte/fiume_aspetto/fiume_B_ramo.jpg
- docs/proposte/fiume_aspetto/fiume_B_approdo.jpg (il portello da sottomarino)

**SB1:**
- docs/report/mascotte/lei_inseguimento/6_sb1_ti_fissa.jpg
- docs/report/mascotte/lei_inseguimento/giro/5_sb1.jpg
- docs/report/ambienti2_giro_22ott/ins_5_sb1.jpg

**Lei nell'inseguimento:**
- docs/report/mascotte/lei_inseguimento/1_sale_1.0s.jpg
- 2_incombe_3.0s.jpg
- 3_respinta_4.3s.jpg
- 4_presa_9.2s.jpg (la fauce di presa, cioè la bocca aperta)
- 5_colpo_grata.jpg

Tutte sono nella stessa cartella e tutte ci sono su 7d96c62a.

**Facoltative:** le anteprime dei modelli Meshy del fiume B in assets_src/fiume_lento/meshy/*_anteprima.png
(corallo, ancora, forziere, palombaro, pesce, portello, rete, tartaruga). Sono anteprime dei modelli veri, non
render del gioco: vanno messe solo se il coordinatore le considera adatte.
