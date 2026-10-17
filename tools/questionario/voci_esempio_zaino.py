# Esempio: la pagina del rework dello zaino (16 ottobre). media: (tipo, file nella cartella dei media, didascalia[, larghezza]).
# Tipi: "img" (jpg), "audio" (mp3), "video" (mp4, con accanto <nome>_poster.jpg).
APPROVA = [("ok", "Approvo"), ("cambia", "Da cambiare")]

def V(vid, titolo, testo, media=(), scelte=None):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte or APPROVA)

INTRO = ("Il rework dello zaino che mi hai chiesto: la lancia in mano, il getto e l'aspirazione molto più imponenti, "
         "come una manichetta dei pompieri potenziata. Video e foto sono presi dal gioco. Il getto e la lancia si "
         "scelgono separatamente: puoi prendere il getto di una proposta e la lancia di un'altra.")

LANCE = [
    ("A", "a_pompiere", "A, pompiere: ottone, ugello grosso, leva a staffa e manichetta rossa"),
    ("B", "b_cannone", "B, cannone giocattolo: colori più accesi e più scuri e un po' di ruggine, come mi hai chiesto"),
    ("C", "c_industriale", "C, industriale: bande gialle e nere, manometro e maniglia sopra"),
    ("C1", "c1_antincendio", "C1: la C con l'arancio antincendio al posto del nero"),
    ("C2", "c2_turchese", "C2: la C con il turchese dello zaino al posto del nero"),
]

def media_lance():
    m = [("img", "neon_0_attuale.jpg", "Oggi: la pistola giocattolo che hai adesso")]
    for _, n, dida in LANCE:
        m.append(("img", f"neon_{n}.jpg", dida))
        m.append(("img", f"lancia_{n}_3lati.jpg", "Il modello da tre lati", 1400))
    return m

SEZIONI = [
    ("Il getto e l'aspirazione", [
        V("Z1", "Quanto deve essere potente",
          "Tre video di 8 secondi presi dal gioco, tutti con la stessa scena: aspira dalla vaschetta lava-piedi, "
          "poi spara contro il tornello a 7 metri. Alza il volume. La fisica delle pozze non cambia. "
          "Nei video c'è ancora la pistola di oggi: il getto nuovo uscirà dalla lancia che scegli più sotto. "
          "\nIn tutte e due le proposte l'aspirazione è una colonna d'acqua che si torce dalla vaschetta fino "
          "all'ugello, con il gorgo sotto e il livello che scende davvero. Il getto è acqua lucida e piena, "
          "con il rinculo quando parte e la camera che vibra. "
          "\nOggi: il getto e il suono di adesso, per il confronto. "
          "A, manichetta: un getto pieno di 8 centimetri che si apre dopo circa un metro. Sul tornello fa schizzi, "
          "rivoli e nebbia. Nel suono senti la pompa che parte, il risucchio profondo e il glu-glu nel serbatoio, "
          "poi il colpo della valvola, il ruggito del getto e lo scroscio sul muro. "
          "B, potenziata: ancora più grosso e violento. Prima del colpo la lancia trema per un attimo mentre si "
          "carica, e all'impatto si apre un ventaglio d'acqua di un metro e mezzo che rimbalza verso di te, "
          "con goccioloni e strattoni del tubo. Nel suono una turbina sale di giri, la pressione si carica prima "
          "del colpo e i bassi sono più profondi. "
          "\nSe vuoi il getto di una e il suono dell'altra, o ancora più forza, scrivilo nella nota.",
          [("video", "getto_attuale.mp4", "Oggi"),
           ("video", "getto_A.mp4", "A, manichetta"),
           ("video", "getto_B.mp4", "B, potenziata")],
          [("A", "A, manichetta"), ("B", "B, potenziata"), ("cambia", "Nessuna: rifalle")]),
    ]),
    ("La lancia in mano", [
        V("Z2", "Quale lancia",
          "La lancia nuova prende il posto della pistola di oggi. Lo zaino resta il giocattolo anni '90 e la lancia ci è "
          "collegata con un tubo. Sono modelli 3D veri, messi nel gioco nello stesso punto del corridoio con la luce "
          "normale, così si leggono i colori. Sono circa 1,4 volte più grandi delle prime prove, che erano troppo piccole.",
          media_lance(),
          [("A", "A, pompiere"), ("B", "B, cannone"), ("C", "C, industriale"),
           ("C1", "C1, arancio"), ("C2", "C2, turchese"), ("cambia", "Nessuna")]),
        V("Z3", "Una mano o due",
          "Una manichetta vera si regge con due mani: con la sinistra sulla leva sembra più pesante e potente. "
          "La torcia resta sulla testa, quindi non serve una mano libera. Si può fare con tutte le lance: te lo "
          "mostro con la A. Le braccia sono quelle semplici che il gioco ha oggi.",
          [("img", "neon_a_pompiere.jpg", "Una mano"),
           ("img", "neon_a_pompiere_2mani.jpg", "Due mani: la sinistra stringe la leva a staffa")],
          [("1", "Una mano"), ("2", "Due mani"), ("cambia", "Altro")]),
    ]),
]
