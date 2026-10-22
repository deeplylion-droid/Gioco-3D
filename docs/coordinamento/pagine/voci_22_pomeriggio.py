# Pagina del pomeriggio del 22 ottobre: Jilly nell'inseguimento (animazioni di mascotte, voce B di grafica),
# poi lo sfondo del titolo (prove di ambienti-2) e il tuffo (ambienti-1) quando arrivano.
import os

def V(vid, titolo, testo, media, scelte):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

OK = [("ok", "Approvo"), ("cambia", "Da cambiare")]
CARTELLA = os.environ.get("MEDIA_POMERIGGIO", "")

def c_e(*nomi):
    return CARTELLA and all(os.path.exists(os.path.join(CARTELLA, n)) for n in nomi)

INTRO = ("Jilly nell'inseguimento, con le animazioni e la voce nuova. Gli scatti dello sfondo del menu e il tuffo "
         "li aggiungo su questa pagina appena arrivano.")

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

if c_e("menu_bc.jpg", "menu_ab.jpg", "menu_ab_lampo.jpg"):
    SEZIONI.append(("Menu", [
        V("MENU", "3. Sfondo della schermata del titolo",
          "Scatti dal menu vero, col logo A."
          "\nB+C: lei esce da una vasca allagata che la riflette, con le luci rosse d'emergenza; dietro, sfocati nella "
          "nebbia, le ghirlande di lampadine, i neon e la cornice del portone della torre."
          "\nA+B: la stessa acqua, e dietro la cupola di vetro con la pioggia: a ogni lampo si vedono le travi e la torre "
          "degli scivoli.",
          [("img", "menu_bc.jpg", "B+C"),
           ("img", "menu_ab.jpg", "A+B, tra un lampo e l'altro"),
           ("img", "menu_ab_lampo.jpg", "A+B, durante il lampo")],
          [("BC", "B+C"), ("AB", "A+B"), ("cambia", "Nessuna: rifalle")]),
    ]))

if c_e("tuffo_griglia.jpg"):
    SEZIONI.append(("Tuffo", [
        V("TUF", "4. Il tuffo di Jilly",
          "Al posto del geyser: si spinge sul bordo, ti guarda un'ultima volta e si tuffa di testa nella fossa. I "
          "tentacoli entrano per ultimi. Lo schizzo è stato ritoccato: acqua bianca, più spruzzi, gocce grosse.",
          [("img", "tuffo_griglia.jpg", "Il tuffo, un fotogramma ogni decimo di secondo circa", 1200)],
          OK),
    ]))

CORRETTI = [
    "Il logo A è nella schermata del titolo.",
    "Corretto il blocco del gioco quando lo chiudi mentre la torre si sta caricando.",
]
