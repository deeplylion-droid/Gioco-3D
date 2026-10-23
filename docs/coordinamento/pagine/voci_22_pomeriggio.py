# Pagina del pomeriggio del 22 ottobre: Jilly nell'inseguimento (animazioni di mascotte, voce B di grafica),
# poi lo sfondo del titolo (prove di ambienti-2) e il tuffo (ambienti-1) quando arrivano.
import os

def V(vid, titolo, testo, media, scelte):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

OK = [("ok", "Approvo"), ("cambia", "Da cambiare")]
CARTELLA = os.environ.get("MEDIA_POMERIGGIO", "")

def c_e(*nomi):
    return CARTELLA and all(os.path.exists(os.path.join(CARTELLA, n)) for n in nomi)

INTRO = ("Grazie: seconda vasca b, grata a e menu A+B sono già in lavorazione per stasera. Restano il tuffo ritoccato e "
         "due piccole cose degli interni, in fondo alla pagina.")

SEZIONI = [
    ("Inseguimento", [
        V("INS", "1. Jilly nell'inseguimento",
          "Video dal gioco vero, con la sua voce nuova. Nella vasca sale e incombe, con la testa che ti segue: la prima "
          "volta la colpisci col getto e si copre il viso, la seconda ti afferra, la terza torna sotto. Poi sbatte tre "
          "volte contro la grata, e alla fine ti fissa aggrappata al bordo del pozzo."
          "\nNel video mancano l'acqua e il metallo della grata, che nel gioco ci sono.",
          [("video", "lei_inseguimento.mp4", "Dal gioco, con la voce nuova (24 secondi)"),
           ("img", "lei_animazioni.jpg", "Gli stessi momenti: sale, incombe, si copre il viso, ti afferra, la grata, il pozzo", 1200)],
          OK),
        V("VOC", "2. La sua voce",
          "Versi nuovi fatti apposta, nello stesso stile di quando sbuca nell'area bimbi. Niente parole. Qui sotto un "
          "verso per momento; nel gioco quelli che si ripetono hanno 2 o 3 varianti.",
          [("audio", "voce_sale_1.mp3", "Quando sale e incombe"),
           ("audio", "voce_presa_1.mp3", "Quando ti afferra"),
           ("audio", "voce_respinta_1.mp3", "Quando la colpisci col getto"),
           ("audio", "voce_sb1.mp3", "Mentre ti fissa dal pozzo"),
           ("audio", "voce_grata.mp3", "Contro la grata, tre colpi")],
          OK),
    ]),
]

SEZIONI.append(("Inseguimento, due posti da decidere", [
    V("VAS2", "3. Da dove sale Jilly nella seconda vasca",
      "Lì sale sopra la condotta, ma così attraversa la grata di metallo sotto di lei, proprio all'altezza dei tuoi occhi."
      "\na: un buco nella grata, da cui sale."
      "\nb: sale accanto alla vasca, come nella prima. Consigliata. È già provata nel gioco (scatto qui sotto): per farle "
      "posto, il serbatoio grande lì accanto si sposta di 1,5 m verso il muro."
      "\nc: non sale, si cala dall'alto scavalcando la condotta. Serve un'animazione nuova.",
      [("img", "vasca2_b.jpg", "b, provata nel gioco: lei sale accanto alla vasca, vista da dentro")],
      [("a", "a"), ("b", "b"), ("c", "c"), ("vedere", "Fammi vedere")]),
    V("GRATA", "4. Jilly dietro la grata",
      "Dietro la grata il pavimento ha solo 60 cm d'acqua, e lei è più alta dello sbocco del tubo: ora sale attraversando "
      "il pavimento e il tubo. Ogni soluzione cambia un po' quel punto."
      "\na: un pozzetto nel pavimento dietro la grata, come quello della fine, da cui sale. Consigliata: è la più semplice."
      "\nb: un'apertura più grande accanto al tubo, da cui lei arriva avanzando invece di salire. Serve anche una piccola animazione nuova."
      "\nc: è già lì, ferma al buio dietro la grata, e la vedi quando la luce la prende; poi sbatte. Per farle posto, lo "
      "sbocco del tubo va allargato di molto.",
      [("img", "grata_adesso.jpg", "La grata adesso")],
      [("a", "a"), ("b", "b"), ("c", "c"), ("vedere", "Fammi vedere")]),
]))

if c_e("menu_bc.jpg", "menu_ab.jpg", "menu_ab_lampo.jpg"):
    SEZIONI.append(("Menu", [
        V("MENU", "5. Sfondo della schermata del titolo",
          "Scatti dal menu vero, col logo A, all'inizio della salita della camera. La parte sinistra resta scura, per il menu."
          "\nB+C: dietro di lei la parete della sala, con il portone della torre e la sua cornice di lampadine, due "
          "ghirlande mezze spente e i manifesti di Jilly col neon."
          "\nA+B: sopra di lei la cupola di vetro con la pioggia. A ogni lampo si accendono il vetro e le travi, e dietro "
          "si intravede la torre degli scivoli."
          "\nSi possono anche mettere tutte e tre insieme: di questa non c'è lo scatto, se la scegli te la faccio vedere prima."
          "\nIl menu ci mette uno o due secondi in più a partire.",
          [("img", "menu_bc.jpg", "B+C"),
           ("img", "menu_ab.jpg", "A+B, tra un lampo e l'altro"),
           ("img", "menu_ab_lampo.jpg", "A+B, durante il lampo")],
          [("BC", "B+C"), ("AB", "A+B"), ("ABC", "Tutte e tre"), ("cambia", "Nessuna: rifalle")]),
        V("ACQM", "6. L'acqua ai suoi piedi, nel menu",
          "In tutte e due le prove l'acqua c'è, ma quasi non si vede: la camera parte bassa e guarda in su, verso di lei, "
          "così lo specchio d'acqua e i riflessi restano sotto l'inquadratura."
          "\na: all'inizio abbasso un po' lo sguardo della camera, così si vedono l'acqua e i riflessi; il viso resta sempre dentro."
          "\nb: la camera resta com'è.",
          [],
          [("a", "a"), ("b", "b"), ("vedere", "Fammi vedere")]),
    ]))

if c_e("tuffo_griglia.jpg"):
    SEZIONI.append(("Tuffo e interni", [
        V("TUF", "7. Il tuffo di Jilly, ritoccato",
          "Al posto del geyser: si spinge sul bordo, ti guarda un'ultima volta e si tuffa di testa nella fossa, con i "
          "tentacoli che restano dietro di lei ed entrano per ultimi. Lo schizzo ora è acqua bianca che si rompe in fili e "
          "spruzzi, con gocce chiare."
          "\nAlla fine le gocce bianche sono tante e luminose, quasi neve (ultimi due fotogrammi): ti consiglio di ridurle."
          "\nGli scatti sono fatti con una luce più semplice di quella del gioco.",
          [("img", "tuffo_griglia.jpg", "Il tuffo, un fotogramma ogni decimo di secondo circa", 1200)],
          [("ok", "Approvo così"), ("gocce", "Sì, ma meno gocce"), ("cambia", "Da cambiare")]),
        V("VALV", "8. La valvola nel corridoio degli interni",
          "È sul muro all'altezza della testa e sporge di 30 cm: ci passi attraverso."
          "\nA: la sposto in alto, sul tubo grande del soffitto, tutta sopra i 2 m. La vedi alzando lo sguardo. Consigliata."
          "\nB: resta dov'è, ma ci sbatti contro come contro un muro."
          "\nC: più piccola e più vicina al muro, ma resta all'altezza della testa.",
          [("img", "valvola_adesso.jpg", "La valvola adesso")],
          [("A", "A"), ("B", "B"), ("C", "C"), ("vedere", "Fammi vedere")]),
        V("TURB", "9. La turbina prima della saracinesca",
          "La ruota di 60 cm sul muro scende fino a 1,75 m: ci passi attraverso con la testa."
          "\nA: la alzo di 30 cm, fin sotto il soffitto. Stessa ruota, che gira quando arriva l'acqua. Consigliata."
          "\nB: resta dov'è, ma ci sbatti contro."
          "\nC: una ruota più piccola, alzata di poco: si legge meno.",
          [("img", "turbina_adesso.jpg", "La turbina adesso, al buio")],
          [("A", "A"), ("B", "B"), ("C", "C"), ("vedere", "Fammi vedere")]),
    ]))

CORRETTI = [
    "Il logo A è nella schermata del titolo.",
    "Corretto il blocco del gioco quando lo chiudi mentre la torre si sta caricando.",
]
