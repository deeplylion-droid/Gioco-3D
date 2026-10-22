# Pagina della mattina del 22 ottobre: le scelte in attesa e le novità della v0.3.8 da approvare.
# media: (tipo, file nella cartella dei media, didascalia[, larghezza]).

def V(vid, titolo, testo, media=(), scelte=None):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

OK = [("ok", "Approvo"), ("cambia", "Da cambiare")]

INTRO = ("Buongiorno. Qui c'è tutto quello che mi serve da te: prima sei scelte, poi le cose nuove della v0.3.8 da "
         "approvare. Sono tutti scatti presi dal gioco. La v0.3.8 è pronta e ha passato tutti i test: la pubblico appena "
         "scegli la posizione degli acquari (con P1 subito). Tocca una foto per ingrandirla.")

SEZIONI = [
    ("Da scegliere", [
        V("ACQ", "Acquari: dove li metto",
          "Raddoppiati, in fila sono lunghi quasi 16 m, e il portone è largo 6,3 m: una fila dritta davanti lo chiuderebbe. "
          "Negli scatti c'è P1, già costruita e provata nel gioco: vuoti e impolverati all'inizio, pieni al rientro dal "
          "magazzino, con la pedana a gradini e la valvola illuminata."
          "\nP1: in fila lungo il muro nord, accanto al viale che porta al portone; il giallo è subito a sinistra del "
          "portone. Il viale resta libero e i tubi restano uniti. La consiglia la squadra."
          "\nP2: il giallo e il blu ai due lati del portone, come colonne d'ingresso; il miscuglio con la pedana resta "
          "staccato, a circa 6 m verso la spiaggia."
          "\nP3: una fila a 9 m davanti al portone, con in mezzo un varco largo quanto il portone. Arrivi al portone "
          "passando tra gli acquari, e i loro tubi ti passano sopra a 3,2 m."
          "\nCon P1 pubblico subito; con P2 o P3 ci vuole circa un'ora e mezza in più.",
          [("img", "p1_vuoti.jpg", "P1 all'inizio: vuoti, lampadine del portone spente"),
           ("img", "p1_pieni.jpg", "P1 al rientro dal magazzino: pieni, con la pedana davanti al miscuglio"),
           ("img", "p1_valvola.jpg", "La valvola rossa con la sua lampada")],
          [("P1", "P1"), ("P2", "P2"), ("P3", "P3"), ("vedere", "Fammi vedere P2 e P3")]),
        V("TUF", "Il tuffo di Jilly, al posto del geyser",
          "Sul geyser ho deciso io, come mi avevi detto: si passa al tuffo. Nel gioco il geyser V1 aveva dei buchi da cui "
          "si vedevano l'occhio e il viso di lei proprio mentre spariva (nella foto), ed era rosa a grumi, più gelatina che "
          "acqua. Chiuderli voleva dire rifare la simulazione, giorni di lavoro con un risultato incerto. Il V1 resta da "
          "parte; nella v0.3.8 c'è ancora il geyser di prima. Per il tuffo ci sono tre modi:"
          "\nA, di testa (circa 1,3 s): si spinge sulle mani sul bordo, ti guarda un'ultima volta, si inarca e si tuffa "
          "di testa nella fossa; i tentacoli entrano per ultimi, come una frusta. È quello che avevi chiesto, e lo "
          "consiglia la squadra."
          "\nB, da medusa (circa 0,9 s): non si stacca dal bordo; la campana si contrae di colpo e la spinge giù, poi "
          "sott'acqua si capovolge. Più strano, meno tuffo."
          "\nC, all'indietro (circa 1,2 s): si lascia cadere all'indietro nella fossa, fissandoti con l'occhio fino "
          "all'ultimo. La più inquietante."
          "\nIn tutti e tre c'è uno schizzo grande quando entra in acqua, e lei sparisce solo quando è tutta sotto.",
          [("img", "geyser_buchi.jpg", "Il geyser V1 nel gioco, da vicino: a 1,8 s si vede l'occhio da un buco, a 2,1 s il viso")],
          [("A", "A, di testa"), ("B", "B, da medusa"), ("C", "C, all'indietro"), ("vedere", "Fammi vedere delle prove")]),
        V("VAS", "Inseguimento: le vasche troppo scure",
          "Nell'inseguimento nelle condotte, che arriva dopo la v0.3.8, l'acqua delle vasche è quasi nera. Le foto sono "
          "della proposta del 19 ottobre; nel gioco è uguale."
          "\na) Acqua meno torbida, verde-azzurra, con le piastrelle del fondo che si intravedono."
          "\nb) Una lampada da lavoro appesa sopra ogni vasca, che fa una pozza di luce sull'acqua."
          "\nc) Tutte e due. La consiglia la squadra.",
          [("img", "ins_vasca.jpg", "Lei ti raggiunge nella vasca"), ("img", "ins_bivio.jpg", "Il primo bivio")],
          [("a", "a, acqua più chiara"), ("b", "b, lampade"), ("c", "c, tutte e due"), ("vedere", "Fammi vedere")]),
        V("STR", "Inseguimento: le strisce sulle paratie",
          "Nella torre ora le strisce gialle e nere vogliono dire \"chiuso\". Nell'inseguimento la trave in alto è a "
          "strisce sia sulla paratia giusta (verde) sia sulla sbagliata (rossa), come nella foto."
          "\na) Sulla paratia giusta la trave diventa liscia, del colore dei montanti; sulla sbagliata le strisce restano. "
          "La consiglia la squadra."
          "\nb) Restano come sono: finché non colpisci il bersaglio sono tutte e due chiuse.",
          [("img", "ins_bivio2.jpg", "Il secondo bivio: le due paratie")],
          [("a", "a, liscia sulla giusta"), ("b", "b, restano a strisce")]),
        V("SCI", "Fiume lento: lo scivolo dei rami sbagliati",
          "Per i rami sbagliati del fiume avevi scelto \"niente, solo il ramo con lo scivolo che riporta all'imbarco\". "
          "Ma il fiume è tutto alla stessa altezza, quindi oggi uno scivolo vero non c'è. Il fiume entra dopo la v0.3.8."
          "\nA: la vasca dell'imbarco sta 50 cm più in basso. Il ramo sbagliato finisce con uno scivolo di 2-3 m nella "
          "vasca, e la ciambella risale su un nastro trasportatore, come nei parchi veri."
          "\nB: tutto alla stessa altezza. La fine del ramo è un canale stretto e veloce, colorato come uno scivolo, con "
          "una discesa di circa 20 cm. La consiglia la squadra."
          "\nC: come la B, ma con una piccola rapida d'acqua bianca al posto del canale.",
          [("img", "fiume_ramo.jpg", "Il fiume A che hai scelto (dalla proposta): un ramo"),
           ("img", "fiume_imbarco.jpg", "L'imbarco")],
          [("A", "A, scivolo e nastro"), ("B", "B, canale"), ("C", "C, rapida"), ("vedere", "Fammi vedere")]),
        V("FRE", "Corridoio C2: le frecce gialle a terra",
          "Con la grata subito dopo il buco dell'agnellino (la β che hai scelto), le frecce gialle dipinte a terra in C2 "
          "puntano ancora verso il magazzino, cioè verso la grata chiusa. La strada nuova passa dalla porta di servizio, "
          "che scende verso il fiume.",
          [("img", "c2_cima.jpg", "Una delle frecce a terra in C2"), ("img", "beta_grata.jpg", "La grata dopo il buco"),
           ("img", "beta_porta.jpg", "La porta di servizio verso il fiume")],
          [("togli", "Toglile"), ("lascia", "Lasciale, c'erano già"), ("gira", "Girane una verso la porta")]),
    ]),
    ("Da approvare: le novità", [
        V("SQU", "L'inizio con il mostro-squalo",
          "La scena vera, presa dal gioco. Il video è muto perché qui il registratore non ha l'audio; nel gioco ci sono il "
          "fiato e i ringhi dello squalo, il verso di Jilly da oltre la porta, i passi e la porta che sbatte. Questi "
          "dettagli li ha decisi la squadra per far funzionare la scena: dimmi se ne vuoi cambiare qualcuno."
          "\nLo squalo scatta tre volte con la testa, come per morderti."
          "\nNell'esitazione si volta a guardarti con uno sbuffo."
          "\nAlla porta si abbassa per passare."
          "\nDurante la scena sei in ginocchio, con gli occhi a circa un metro da terra."
          "\nDura circa 13 secondi, poi riprendi i comandi; la torcia e la riga dei comandi arrivano dopo.",
          [("video", "squalo.mp4", "La scena intera, senza audio"),
           ("img", "sq_bocca.jpg", "La bocca addosso alla camera"), ("img", "sq_esita.jpg", "Esita e si volta a guardarti"),
           ("img", "sq_corsa.jpg", "Corre verso la porta tagliafuoco")],
          OK),
        V("TOR", "La strada nella torre degli scivoli",
          "Come avevi scelto. L'imbocco giusto ha un portale con i led e la lampada verdi. Le bocche sbagliate vicino alle "
          "pedane sono chiuse da un cancelletto a strisce, con una lampada rossa guasta o spenta. Sotto i salti ci sono "
          "vasche di raccolta, e una scaletta ti riporta alla pedana da cui eri partito: si muore solo cadendo davvero "
          "nel vuoto. Ci sono meno barre di sostegno, e nessuna dove scendi."
          "\nUna cosa l'ho decisa io, per coerenza: sul portale giusto c'era una fascia a strisce gialle e nere, che però "
          "vogliono dire \"chiuso\". Ora è liscia, rossa come il portale.",
          [("img", "torre_giusto.jpg", "L'imbocco giusto"), ("img", "torre_chiuso.jpg", "Un imbocco chiuso"),
           ("img", "torre_vasca.jpg", "Una vasca di raccolta con la scaletta")],
          OK),
        V("P04", "Dove sta ora la Polaroid 4",
          "Era sospesa a 6,4 m, poi su una pedana dove a piedi non si arriva. Ora è in cima alla scala della struttura dei "
          "giochi nell'area bimbi, appoggiata sul pianerottolo. Un test sale la scala come il giocatore e la raccoglie.",
          [("img", "p04.jpg", "La Polaroid 4 dalla scala")],
          OK),
    ]),
    ("Da approvare: quello che avevi chiesto", [
        V("SOT", "Il sottopassaggio dopo i generatori",
          "Il tubo che passava davanti alla faccia sulla scala ora sta a 2,25 m: esce dal muro e ci rientra, con due "
          "staffe. Davanti al cancello in fondo ho tolto la pila di lettini e scatoloni. Dalle scale ho tolto palloni e "
          "cestini, e le pile contro i muri arrivano al massimo a 1,3 m, col pesante sotto.",
          [("img", "c2_tubo_f2.jpg", "Il tubo sopra la scala"), ("img", "c2_scala_v038.jpg", "La scala libera"),
           ("img", "t_c2.jpg", "Il corridoio prima della scala"), ("img", "c2_serranda.jpg", "Davanti al cancello in fondo")],
          OK),
        V("MAS", "Le statue e Jilly Jubilee nel gioco",
          "Nei posti che avevi scelto: lo squalo sul bordo della piscina a onde, i due polpi nell'area bimbi. Jilly in "
          "stile B, molto invecchiato: la targa sulla vasca, il manifesto con LIVE SHOW e gli orari, l'insegna con le "
          "sue due lampade.",
          [("img", "st_squalo.jpg", "Lo squalo"), ("img", "st_polpoA.jpg", "Il polpo all'ingresso dell'area bimbi"),
           ("img", "st_polpoB.jpg", "Il polpo vicino al fungo"), ("img", "j_targa.jpg", "La targa di Jilly sulla vasca"),
           ("img", "j_manifesto.jpg", "Il manifesto, sul muro vicino all'ingresso"),
           ("img", "j_insegna.jpg", "L'insegna con le due lampade")],
          OK),
        V("POL", "Le Polaroid coperte",
          "Quella al bordo della vasca d'arrivo era sotto un pannello caduto dal soffitto, quella sulla scrivania della "
          "sala pompe sotto un foglio: ora sono tutte e due libere e appoggiate bene.",
          [("img", "p08.jpg", "Al bordo della vasca d'arrivo"), ("img", "p07.jpg", "Sulla scrivania della sala pompe")],
          OK),
        V("POR", "Il portone e la parete della torre",
          "Il portone ora si apre del tutto. La cornice di lampadine poggia a terra ed è legata al muro con quattro "
          "staffe. La parete dentro la torre non lampeggia più: nella foto, prima e dopo.",
          [("img", "portone.jpg", "Il portone aperto"), ("img", "cornice.jpg", "La cornice di lampadine"),
           ("img", "parete.jpg", "La parete della torre, prima e dopo")],
          OK),
        V("BUI", "La torre dopo una morte",
          "A sinistra com'è ora: dopo una morte le luci della torre restano accese. A destra com'era nella v0.3.7, tutta "
          "buia.",
          [("img", "torre_morte.jpg", "Ora (sinistra) e nella v0.3.7 (destra)")],
          OK),
        V("GOC", "Lo spruzzo da vicino contro un muro",
          "Sopra, a 0,8 m dal muro: a sinistra prima, a destra ora. Le gocce sono meno, più piccole e più brevi, e il "
          "gioco non rallenta più. Sotto, a 6 m: uguale a prima.",
          [("img", "gocce.jpg", "Sopra da vicino, sotto da lontano; a sinistra prima, a destra ora")],
          OK),
    ]),
]

CORRETTI = [
    "La torcia torna: tasto F, con metà dell'intensità dell'ultima volta. I bambini scappano solo se ti avvicini, non dalla luce. Al buio non riesco a fotografarla: la vedi nel gioco.",
    "Corretto un blocco che poteva capitare alla prima partita sui computer con 4 core.",
    "C'è un controllo automatico che cerca oggetti sospesi, cose all'altezza della faccia dove si cammina, tubi che non arrivano da nessuna parte e Polaroid coperte. Sul gioco ha trovato una novantina di casi: le squadre li correggono dopo la v0.3.8.",
    "Il fiume lento, l'infermeria, la keycard, il lettore, la strada nuova con la grata in C2 e la Polaroid della pecora sono pronti a parte: entrano dopo la v0.3.8, con le tue scelte di questa pagina.",
]
