# Collaudo del tunnel "viaggio sottomarino" (24-25 ottobre, notte)

Squadra collaudo. Il tunnel giocato da cima a fondo col giocatore vero, dalla camera del giocatore, con i materiali e la luce del gioco. Le correzioni sono arrivate durante la notte, quindi le basi sono state quattro, una dopo l'altra:

| Base | Cosa c'è | Cosa ci ho fatto |
|---|---|---|
| `lavoro/godot` **766fc039** | tunnel ad4dfae9, menu F9, bitte e reti, pallone | primo giro: trovato T1 (scaletta); test, ravvicinati, armadietti |
| `lavoro/sottomarino` **8de0780a** | T1 (4b3dd64b), collaudo di enigmi 0-240 (3c17ef1b), corde (91487f8d), forzieri | partite intere, ravvicinati, giro di enigmi 0-240 e 236-553, posizionamento, test; trovati la difficoltà, G1 e P1 |
| 8de0780a + `lavoro/tunnel-distanza` **0253b17c** | la regola degli 8 m di mascotte | partite con la presa vera e con la presa solo segnata, test |
| `lavoro/godot` **743681b8** + `lavoro/sottomarino` **e05ca769** (P1) | tutto: G1, P1, la distanza di lei, il resto della notte | partita intera, portello da 9 punti, gallerie, test, posizionamento, scritta di fine |

Le basi 3 e 4 sono unioni fatte solo in locale (senza conflitti) per provare le correzioni prima che arrivassero in `lavoro/godot`. Non ho corretto niente io: i difetti sono andati a chi ha costruito la zona.

**Esito:**
- **sull'ultima base il tunnel si gioca tutto senza essere presi**: SB1, scaletta, riemersione, 552 m di corsa coi 5 attraversamenti, le due gallerie basse, l'approdo col guado, scala e pontile, portello, schianto, nero. Partita p13, con la presa vera: 0 prese, 0 incastri, 6 getti e 6 respinte;
- **tutti i difetti trovati sono stati corretti e ricontrollati**: T1, G1, P1, la difficoltà, i punti di enigmi 1-10 e le corde;
- restano solo cose da far decidere (D1-D4) e quello che qui non si può verificare (in fondo);
- test del tunnel verdi; controllo di posizionamento con 0 casi nuovi e 0 da correggere.

## Come è stato fatto

- **Partita automatica col giocatore vero** (`godot/tests/collaudo/partita_tunnel.gd`), nella scena di prova `sottomarino_prova.tscn`, col renderer vero (Vulkan su llvmpipe), 640×360, a 60 fotogrammi fissi. Il bot gioca come una persona:
  - finisce SB1, sale la scaletta guardando la porta, entra e guarda la riemersione dalla porta;
  - corre in sprint e ogni 9 s si gira a guardare lei;
  - attraversa saltando da un gommone all'altro;
  - entra accovacciato nelle gallerie e, se resta fermo più di 1 s, fa un passo di lato;
  - guada all'approdo, sale la scala, va al volantino e preme E;
  - spruzza in faccia a lei quando la ha fra 5,5 e 6,5 m, guardandola e indietreggiando.

  Uno scatto dagli occhi (con l'HUD) ogni mezzo secondo, più gli scatti dei momenti importanti. Ogni scatto ha una riga di registro con posizione, lato, acqua, accovacciato, stato di lei e distanza. Con `SENZA_PRESA=1` la presa viene solo segnata (dove e in che fase) e lei torna a 18 m: così una partita sola trova tutti i punti dove prende. In tutto 13 partite.
- **Sonde col giocatore vero**, una cosa alla volta:

  | Sonda | Cosa prova |
  |---|---|
  | `sonda_scaletta.gd` | la scaletta del bacino in quattro modi |
  | `sonda_ripartenza.gd` | il getto da una distanza data (`GETTO=1 GAP=…`) e la presa |
  | `sonda_galleria.gd` | le gallerie basse una per una (`GAL=0` la 205, `GAL=1` la 425), nello stesso modo di `test_sottomarino_gioco` |
  | `sonda_portello.gd` | chiudere il portello da un punto della camera stagna, con tre scatti e la misura di quanto si viene spinti e di quanto l'oblò resta in vista |
  | `sonda_varco.gd` | le facce che la correzione di T1 toglie dalla collisione |
  | `sonda_f9.gd` | il menu F9 e le partenze, coi tasti veri |
- **Ravvicinati** (`scatti_tunnel.gd`, il tunnel da solo con la luce del gioco):
  - ostacoli, 4 viste ciascuno;
  - corde (anello, maniglia, intera);
  - gommoni in tre momenti dell'onda;
  - gallerie fuori e dentro, gradini ogni 45 m;
  - lei in tutti gli stati;
  - portello aperto e chiuso, volantino, schianto.
- **Giro di enigmi** (`giro_tunnel.gd`, il loro strumento, con l'aggiunta dei punti in coordinate della strada): sul tratto 0-240 per ricontrollare i loro punti, e sul tratto 236-553, che nessuno aveva ancora girato. Strada ogni 8 m, oggetti con le misure, facce dal retro.

## Difetti trovati e corretti

| # | Cosa | Corretto in | Ricontrollo |
|---|---|---|---|
| T1 | In cima alla scaletta del bacino ci si incastrava fra i montanti (4 volte su 5) | 4b3dd64b | i 4 modi arrivano all'uscita in 2,3-7,7 s; nelle partite la scaletta si sale in 1,3 s. Con `sonda_varco.gd`: la correzione toglie 316 facce in una fetta spessa 6 cm, larga 56 cm e alta 4,7 m, cioè solo i montanti e i pioli. Nessun buco nelle pareti. `test_scaletta_bacino` 13/13 |
| — | La difficoltà: lei prendeva chi non sbagliava (dettagli sotto) | 85a245c3, 018ac91e, 0253b17c | partite p12 e p13: 0 prese; `test_tunnel_attraversamenti` 24/24 |
| G1 | All'imbocco della galleria bassa a 425 ci si fermava contro lo spigolo interno della bocca (velocità 0, raggi davanti liberi); col bot di prima, 40 s fermo e presa. In CI veniva provata solo la galleria a 205 | b2ad2d92 | 425 passata in 17,0 s senza fermarsi (205 in 9,9 s); `test_gallerie_sottomarino` 6/6 (`fogli/galleria_425_incastro_G1.jpg` prima, `fogli/partita_finale_getto_galleria_425.jpg` dopo) |
| P1 | Al portello il battente che si chiude spingeva il giocatore e lo schianto non si vedeva. Da 0,3 e 0,6 m E non funzionava (la camera stava dentro la zona d'interazione); da 1,0 m si veniva spinti di 0,92 m e l'oblò restava in un angolo; da 1,5 m si veniva spinti di 1,51 m contro il muro e lo schianto non si vedeva mai. Bene solo da 2,2 m | e05ca769 | 9 punti (0,3, 0,6, 1,0, 1,5, 2,2 m sull'asse e 4 di lato): E funziona sempre, il giocatore fa da solo il passo indietro a 2,2 m sull'asse, il battente non lo tocca, l'oblò è in vista 139 fotogrammi su 139 con la faccia di lei al centro. `test_portello_sottomarino` 30/30 (`fogli/portello_P1_prima_*.jpg`, `fogli/portello_P1_corretto.jpg`, `fogli/finale_corretto.jpg`) |

### La difficoltà, nel dettaglio

Su 8de0780a, senza la regola degli 8 m, lei prendeva chi non sbagliava in questi punti (partite p6-p10):

| Punto | Cosa succedeva |
|---|---|
| attraversamenti (74, 138, 268, 348, 484) | due salti richiedono 4,5-7,5 s e lei recupera 13,5 m dai 18 massimi: all'atterraggio è a 4,4 m. Il getto ci mette circa 0,5 s a fermarla e intanto lei avanza di 2,3 m (misurato da 4,4, 5,5 e 7 m). Chi si girava a spruzzare veniva preso: 3 partite su 3 a 70-75 m |
| gallerie a 205 e 425 | accovacciati si va a 2,3 m/s: lei arrivava a 0,5 m, aspettava e prendeva all'uscita (s 217,9) |
| approdo | dopo 484 si è per forza sulla banchina destra e la scala parte da sinistra: lei prendeva sul gradino all'uscita dal guado |
| scala e pontile | sul pontile s non avanza: lei arrivava a 3,4 m prima del volantino |
| portello | durante i 2 s della chiusura lei inseguiva ancora |

Con la regola di mascotte (lei almeno a 8 m nei passaggi obbligati lenti fatti senza errori) le partite p12 e p13 arrivano in fondo senza prese. Dopo ogni attraversamento il getto all'atterraggio la respinge, e sulle banchine lei sta a 16-18 m.

### Il collaudo di enigmi 0-240 (3c17ef1b), rifatto col loro strumento

| # | Prima (ee20554a) | Ora |
|---|---|---|
| 1 | lampade sopra le bocche delle gallerie a 1,79 m | 2,24 m |
| 2 | lastre del crollo a 74 sospese, quattro uguali in fila | lastre spezzate diverse, appoggiate al fondo e al muro, coi ferri (vedi D1) |
| 3 | fasce gialle e nere a pezzi sovrapposti | un pezzo solo per bocca, strisce continue |
| 4 | oblò sotto i 2 m | 2,09 m |
| 5 | casse lisce, colonna sopra l'acqua, ancora per terra | casse con assi, spigoli e reggette; niente ancora per terra |
| 6 | corde con le facce al contrario (scure) | corde chiare color canapa, dagli anelli alle maniglie |
| 7 | testa del tunnel nera | lampada sul muro sinistro prima della porta (vedi D2) |
| 8 | palombaro e forziere poco leggibili | faretto su ogni mensola |
| 9 | banchina crollata davanti alle gallerie col taglio dritto | lastre rotte alle teste (vedi D1) |
| 10 | staffe dell'ancora come blocchi | piastre coi bulloni, bracci e collare |

Mensole dei coralli, del forziere e del palombaro: viste di traverso sono a filo del muro (`fogli/mensole_di_traverso.jpg`). Fogli: `fogli/punti_corretti_0_240_*.jpg`, `fogli/ostacoli.jpg`, `fogli/corde.jpg`, `fogli/strada_0_240.jpg`.

## Da far decidere (coordinatore o utente)

| # | Cosa | Dove | Fogli |
|---|---|---|---|
| D1 | **Le facce rotte delle lastre sono lisce, senza texture.** Nei crolli a 74 e 203 e nelle macerie a 348 il piano delle lastre ha la graniglia, ma i bordi spezzati e i pezzi piccoli sono beige o grigi uniformi, come cartone. Dalla banchina e dall'acqua si notano. Le macerie a 348 si leggono ancora poco: una lastra di mosaico appoggiata al muro e blocchi lisci | 74-82 sinistra, 203-218 e 423-438 destra, 348 destra | `fogli/ostacoli.jpg`, `fogli/punti_corretti_0_240_1.jpg` (ultime due righe) |
| D2 | **La testa del tunnel senza torcia resta scura** negli scatti del giro. Nella partita vera, però, la riemersione dalla porta del bacino si legge bene: la lampada nuova, la luce rosa di lei e la sua ombra sul muro | s -4,5 - 2 | `fogli/partita_inizio.jpg` (0023-0025) |
| D3 | **Facce viste dal retro all'approdo** (giro "retro" 236-553): le mensole sotto il ballatoio, viste dall'acqua e dalle banchine a 540-548, e un tratto del telaio del portello visto dal tunnel sono rosse, cioè da lì si vede il retro delle facce. Nei colori veri non salta all'occhio. Il rosso a 268 e 484 non conta: la camera del giro sta dentro il cancello e la vetrina | 540-548 | `fogli/facce_dal_retro_236_553.jpg` |
| D4 | **Il testo sotto "FINE DELLA DEMO" dopo il tunnel è quello della torre**: "La discesa continua nel buio. Grazie per aver giocato!" (`fine_torre_testo`). La scritta si legge bene sul nero, col renderer vero | finale | `fogli/fine_della_demo_tunnel.jpg` |

## Tutto il resto

- **SB1**: lei fissa il giocatore 3,5-5,3 s e si tuffa; tornano i comandi; la scaletta e la lampada si vedono subito (`fogli/partita_inizio.jpg`, 0011-0013).
- **Riemersione** vista dalla porta del bacino: lei sale dalla presa, con la luce rosa e l'ombra sul muro (0023-0025). Lei esce a 3 m dalla porta e, se il giocatore resta fermo, lo prende dopo circa 2,8 s. Durante la risalita il getto non conta (vale solo quando lei insegue): da sapere, non è un difetto.
- **Lei**, ravvicinati in tutti gli stati: ferma alla presa, che sale, che insegue a 5, 8, 12 e 18 m, ritratta dopo il getto, che prende. Bocca aperta coi denti, occhio grande, tentacoli (`fogli/lei.jpg`). Durante la corsa, girandosi, la si vede dietro a bocca aperta. Morsi sotto i 7 m e presa sotto i 2,5 m: confermati.
- **Getto**: la respinge di 6 m e la ferma 2 s (`fogli/attraversamenti_e_getto.jpg`).
- **Gommoni**: galleggiano nei tre momenti dell'onda, nessuno entra nel fondo o nella banchina; le corde partono dagli anelli murati nel gradino e arrivano alle maniglie (`fogli/gommoni.jpg`, `fogli/corde.jpg`).
- **Gallerie basse**: plafoniere a filo del soffitto, fasce in un pezzo, dentro si sta accovacciati (`fogli/gallerie.jpg`).
- **Seconda metà 236-553** (giro di enigmi): 138 scatti della strada e 187 ravvicinati. Pesci sulle mensole, reti, abisso blu, cartelli a disegni, vetrina, approdo. Nessun oggetto sospeso o davanti alla faccia sotto i 2 m; il palombaro a 190 passa sopra la testa a 2,2 m (`fogli/strada_236_553_*.jpg`).
- **Bitte e reti di ambienti-1** (scatti mirati sull'ultima base, luce del gioco senza luce in più):
  - le quattro bitte dell'approdo (497, 503, 517, 524) sono un pezzo unico di ghisa poggiato sul pavimento della banchina, a 30 cm dal bordo;
  - le tre reti con le stelle (325, 333,5, 388,3) ora hanno il faretto sopra e si vedono dalla stessa banchina, dall'altra e dall'acqua (`fogli/bitte_e_reti.jpg`).

  Negli scatti bassi delle bitte la camera è finita troppo vicina al bordo e non dicono niente: contano quelli dagli occhi.
- **Portello**: chiuso dal tunnel, dal canale, dalle banchine e dalla scala; aperto e chiuso dalla camera; volantino rosso; schianto con la faccia di lei sull'oblò d'ottone (`fogli/portello.jpg`, `fogli/finale_corretto.jpg`).
- **Fine**: `test_fine_titolo` con `FINE_TUNNEL=1` 13/13; scatto col renderer vero della scritta sopra il nero (D4). Su 766fc039 questo test si bloccava, perché il portello veniva chiuso prima che il tunnel fosse costruito; ora il test aspetta.
- **Menu F9** (`fogli/f9_menu.jpg`, `fogli/f9_dopo_esc.jpg`): dal titolo F9 apre "Partenza di prova" con le sei partenze e "Indietro"; Esc lo chiude e F9 lo riapre. Ogni partenza mostra la schermata di caricamento del Capitolo 1 coi comandi (`fogli/f9_tunnel_caricamento.jpg`); per l'arrivo vedi sotto.
- **Armadietti degli spogliatoi** (`scatti_armadietti.gd`, su 766fc039 e sull'ultima base): l'anta che sbatte chiusa, a metà e aperta, col salvagente-papera dentro; niente compenetrato. Il pallone ora è a terra accanto alla panca (2d90261f), fuori dal passaggio: `test_passaggi_interni` 29/29 (`fogli/armadietti_e_pallone.jpg`).
- **Controllo di posizionamento** su 8de0780a e sull'ultima base: 0 casi nuovi, 63 già noti, 0 da correggere.
- **Test**, sull'ultima base: portello_sottomarino 30/30, gallerie_sottomarino 6/6, sottomarino_gioco 13/13, tunnel_attraversamenti 24/24, scaletta_bacino 13/13, fine_titolo (tunnel) 13/13, parkour_gommoni 16/16, sottomarino_arredi 27/27. Su 8de0780a anche: sottomarino 9/9, sottomarino_lei 5/5, guado 8/8, partenze_prova 72/72, ante_armadietti 3/3, passaggi_interni 29/29.

## Non verificato qui

- **Le partenze del menu F9 col renderer vero fino all'arrivo**. Tutte e cinque quelle provate (tunnel, risalita, fiume, torre, inseguimento), lanciate da sole dal titolo, durante il caricamento della sala arrivano a 13,9-14 GB (11,6-11,9 GB propri più 2,1-2,2 GB condivisi) e la macchina le chiude. Succede uguale a 640×360 e a 960×540, e la memoria cresce ancora quando il processo viene chiuso. Senza schermo, `test_partenze_prova` fa tutte e sei le partenze con un picco di 5,0 GB (72/72): almeno 9 GB vengono dalla grafica. Secondo la squadra grafica è la compilazione degli shader su llvmpipe, non le texture: con la grafica al minimo non cambia, e succedeva già con la v0.3.13. Per i giri nella sala si usano `tools/collaudo/giro_lotti.sh` con `COLLAUDO_SEMPLICE=1` e le scene delle zone caricate da sole (0,3-1 GB senza schermo).
- **Scatti al primo uso e suoni**: col renderer software non si misurano i tempi dei fotogrammi e non si sentono i suoni. Vanno guardati su una macchina vera.
- **Cadute in acqua**: nelle partite il giocatore non è mai caduto. Guado, risalita dal gradino e aspirazione li coprono `test_guado` e `test_parkour_gommoni`; la vista con la testa fuori dall'acqua la copre `test_vista_subacquea` (10/10 su 0031a2e4).
- **Ripartenza dai checkpoint nel gioco vero**: la scena di prova ricarica senza il tunnel. La coprono `test_partenze_prova` e la partenza "tunnel" del menu F9.

## Strumenti

In `godot/tests/collaudo/`: `partita_tunnel.gd`, `scatti_tunnel.gd`, `sonda_galleria.gd`, `sonda_portello.gd`, `sonda_varco.gd`, `sonda_f9.gd`, `sonda_ripartenza.gd`, e `giro_tunnel.gd` (lo strumento di enigmi, da `lavoro/collaudo-tunnel-enigmi`, con l'aggiunta di `COLLAUDO_PUNTI_S`). Come si lanciano è scritto in cima a ciascuno.
