# Pagina della mattina del 22 ottobre, versione corta e solo testo (richiesta dell'utente: "il minimo indispensabile").

def V(vid, titolo, testo, scelte):
    return dict(id=vid, titolo=titolo, testo=testo, media=[], scelte=scelte)

OK = [("ok", "Approvo"), ("cambia", "Da cambiare")]

INTRO = ("La v0.3.8 è pronta e ha passato i test: esce appena scegli gli acquari (con P1 subito). "
         "Le altre scelte servono per dopo.")

SEZIONI = [
    ("Da scegliere", [
        V("ACQ", "1. Acquari davanti al portone",
          "In fila sono lunghi 16 m, il portone è largo 6,3 m."
          "\nP1: in fila lungo il muro accanto al viale, il giallo subito a sinistra del portone. È già pronta."
          "\nP2: giallo e blu ai lati del portone come colonne, il miscuglio con la pedana a 6 m."
          "\nP3: fila a 9 m davanti al portone, con un varco in mezzo da cui passi.",
          [("P1", "P1"), ("P2", "P2"), ("P3", "P3"), ("vedere", "Fammi vedere")]),
        V("TUF", "2. Il tuffo di Jilly al posto del geyser",
          "Il geyser nel gioco aveva buchi da cui si vedeva il viso di lei: l'ho tolto, come mi avevi permesso. Nella "
          "v0.3.8 resta quello vecchio."
          "\nA: di testa, ti guarda un'ultima volta e si tuffa nella fossa. Consigliata."
          "\nB: da medusa, la campana si contrae e la spinge giù."
          "\nC: all'indietro, fissandoti fino all'ultimo.",
          [("A", "A"), ("B", "B"), ("C", "C"), ("vedere", "Fammi vedere")]),
        V("VAS", "3. Inseguimento: vasche troppo scure",
          "a: acqua più chiara, si vede il fondo."
          "\nb: una lampada da lavoro sopra ogni vasca."
          "\nc: tutte e due. Consigliata.",
          [("a", "a"), ("b", "b"), ("c", "c"), ("vedere", "Fammi vedere")]),
        V("STR", "4. Inseguimento: strisce sulle paratie",
          "Nella torre le strisce ora vogliono dire \"chiuso\"."
          "\na: sulla paratia giusta la trave diventa liscia. Consigliata."
          "\nb: restano a strisce tutte e due.",
          [("a", "a"), ("b", "b")]),
        V("SCI", "5. Fiume: lo scivolo dei rami sbagliati",
          "A: vasca dell'imbarco più bassa, scivolo di 2-3 m e nastro che riporta su la ciambella."
          "\nB: canale stretto e veloce, discesa di 20 cm. Consigliata."
          "\nC: come B, con una piccola rapida bianca.",
          [("A", "A"), ("B", "B"), ("C", "C"), ("vedere", "Fammi vedere")]),
        V("FRE", "6. Frecce gialle a terra in C2",
          "Puntano ancora al magazzino, ora chiuso dalla grata.",
          [("togli", "Toglile"), ("lascia", "Lasciale"), ("gira", "Girane una")]),
    ]),
    ("Da approvare", [
        V("SQU", "7. Scena dello squalo: i dettagli decisi dalla squadra",
          "Scatta tre volte con la testa; nell'esitazione si volta a guardarti con uno sbuffo; alla porta si abbassa; "
          "sei in ginocchio; dura 13 secondi.",
          OK),
        V("TOR", "8. Torre: portale giusto senza strisce",
          "Sull'imbocco giusto c'era una fascia a strisce, che però vuol dire \"chiuso\": l'ho fatta liscia.",
          OK),
        V("P04", "9. Polaroid 4 in cima alla scala dei giochi",
          "Era sospesa nel vuoto; ora è sul pianerottolo della struttura dell'area bimbi, dove arrivi a piedi.",
          OK),
    ]),
]

CORRETTI = [
    "Tutti gli 8 punti della prova del 19 sono nella v0.3.8: acquari doppi con valvola illuminata, portone e cornice, "
    "parete della torre, torre buia dopo una morte, Polaroid coperte, gocce dello spruzzo, strada nella torre con le vasche.",
    "Anche: inizio con lo squalo, torcia (F, metà intensità), statue e Jilly, sottopassaggio sistemato, meno barre nella torre.",
]
