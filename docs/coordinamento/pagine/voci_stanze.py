# Pagina delle scelte del 19 ottobre, seconda: l'aspetto del fiume lento e dell'infermeria, keycard e lettore.
# media: (tipo, file nella cartella dei media, didascalia[, larghezza]).

def V(vid, titolo, testo, media=(), scelte=None):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

INTRO = ("Le due stanze nuove che hai approvato, lungo la strada di risalita dopo la sala dei generatori: prima il fiume "
         "lento, poi l'infermeria. Le regole sono quelle che hai già scelto. Qui scegli l'aspetto: due versioni per stanza, "
         "con gli stessi oggetti e temi diversi, più la keycard e il lettore illuminato della serranda. Sono tutti scatti dal "
         "gioco, senza torcia. Per ora nel gioco non c'è niente. Tocca una foto per ingrandirla.")

def coppie(prefisso, viste):
    out = []
    for chiave, nome in viste:
        out.append(("img", f"{prefisso}_A_{chiave}.jpg", f"A, {nome}"))
        out.append(("img", f"{prefisso}_B_{chiave}.jpg", f"B, {nome}"))
    return out

SEZIONI = [
    ("Il fiume lento", [
        V("FIU", "L'aspetto del fiume lento",
          "Un pezzo del percorso: l'imbarco, il primo bivio con la paratia, il disco a strisce da colpire col getto e i "
          "cartelli verdi d'uscita, un ramo e l'approdo con la scaletta. Gli oggetti sono gli stessi nelle due versioni: "
          "ciambelle alla deriva, scalette, bocchette della corrente, cartelli con i disegni, lampade rotte, ciabatte e "
          "paperelle perse."
          "\nA, \"giungla finta\": rocce finte color ocra sotto il tetto del capannone, palme e liane di plastica, maschere "
          "tiki, un pappagallo e una scimmia di vetroresina, la tettoia di paglia sull'imbarco. Luce calda."
          "\nB, \"viaggio sottomarino\": un tunnel a volta di mosaico blu con gli oblò illuminati, coralli, un'ancora, un "
          "forziere, un palombaro, pesci sui piedistalli e una tartaruga appesa, il portello da sottomarino all'approdo. "
          "Più freddo e chiuso.",
          coppie("fiume", [("imbarco", "l'imbarco"), ("bivio", "il bivio con la paratia"),
                           ("bersaglio", "il disco da colpire"), ("ramo", "un ramo"), ("approdo", "l'approdo")]),
          [("A", "A, giungla finta"), ("B", "B, viaggio sottomarino"), ("cambia", "Nessuna: rifallo")]),
    ]),
    ("L'infermeria", [
        V("INF", "L'aspetto dell'infermeria",
          "La stanza del medico del parco, al buio, con le luci rosse d'emergenza. Ci sono gli oggetti dell'enigma: il "
          "pulsante del parco che accende il negatoscopio, la radiografia dell'agnello con i puntini 4-1-7, lo schedario "
          "con l'adesivo rosa che brilla e la cassaforte nel muro con le tre rotelle. Intorno ci sono il lettino con la "
          "tenda, la sedia a rotelle, la bilancia, l'asta per la flebo e le cartelle per terra."
          "\nA, \"ambulatorio di bordo anni '90\": piastrelle bianche, muri grigioverdi, acciaio smaltato."
          "\nB, \"infermeria per bambini del parco\": stessi mobili color pastello, adesivi grandi di balena, tartaruga, "
          "stella e cavalluccio, il metro a giraffa, il cavallo a dondolo, un orsetto e un trenino.",
          coppie("infermeria", [("porta", "dalla porta"), ("stanza", "la stanza"), ("negatoscopio", "il negatoscopio"),
                                ("scrivania", "la scrivania con la Polaroid"), ("schedario", "lo schedario con l'adesivo"),
                                ("cassaforte", "la cassaforte")]),
          [("A", "A, ambulatorio anni '90"), ("B", "B, per bambini"), ("cambia", "Nessuna: rifalla")]),
    ]),
    ("La keycard e il lettore della serranda", [
        V("LET", "Il lettore accanto alla serranda del magazzino",
          "Senza keycard il lettore è rosso e la serranda resta chiusa; la passi e diventa verde. La prima foto di ogni "
          "versione è da lontano, al buio del magazzino."
          "\n1: lettore a strisciata anni '90, di plastica beige, con la spia tonda in alto. Da lontano si vede meglio."
          "\n2: lettore industriale d'acciaio, con l'anello luminoso intorno al riquadro di lettura."
          "\nNelle foto verdi la luce del lettore colora tutto il muro: nel gioco la faccio più debole.",
          [("img", "lettore_1_rosso_lontano.jpg", "1, da lontano"), ("img", "lettore_1_rosso_vicino.jpg", "1, rosso"),
           ("img", "lettore_1_verde_vicino.jpg", "1, verde"), ("img", "lettore_2_rosso_lontano.jpg", "2, da lontano"),
           ("img", "lettore_2_rosso_vicino.jpg", "2, rosso"), ("img", "lettore_2_verde_vicino.jpg", "2, verde")],
          [("1", "1, plastica beige"), ("2", "2, acciaio"), ("cambia", "Nessuno: rifallo")]),
        V("TES", "La keycard nella cassaforte",
          "La trovi nella cassaforte dell'infermeria, accanto alla Polaroid."
          "\n1: il tesserino bianco del personale del parco, con la foto, le onde e la banda magnetica."
          "\n2: una tessera arancione con il chip e il disegno di una chiave.",
          [("img", "tessera_1.jpg", "1, tesserino del personale"), ("img", "tessera_2.jpg", "2, tessera arancione")],
          [("1", "1, tesserino del personale"), ("2", "2, tessera arancione"), ("cambia", "Nessuna: rifalla")]),
    ]),
]
