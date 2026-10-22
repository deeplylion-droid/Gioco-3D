# Pagina dello spot, seconda: la voce dello speaker (enigmi, lavoro/spot-enigmi 5978caa), il sorriso di Jilly
# (mascotte) e logo, insegna e targa di Jilly da nuovi (mascotte, lavoro/spot-mascotte 11ca3c7). Notte del 22 ottobre.

def V(vid, titolo, testo, media, scelte):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

OK = [("ok", "Approvo"), ("cambia", "Da cambiare")]

INTRO = ("Tre cose per lo spot, che intanto si prepara a parte: la build non cambia. Rispondi quando vuoi, anche "
         "domattina.")

SEZIONI = [
    ("La voce dello speaker", [
        V("VOCE", "1. Quale voce?",
          "Tre voci americane che dicono le 7 frasi approvate, con il filtro da TV a tubo. Nella frase 6 il nastro "
          "ondeggia appena; nella 7 rallenta come un nastro che muore, e la voce scende e si allunga. "
          "Si possono usare anche in un gioco in vendita."
          "\nSe nessuna ti convince, c'è la tua seconda scelta: niente speaker, solo la sigla e il logo.",
          [("audio", "voce_A_uomo_caldo.mp3", "A: uomo, caldo"),
           ("audio", "voce_B_uomo_squillante.mp3", "B: uomo, squillante"),
           ("audio", "voce_C_donna_sorridente.mp3", "C: donna, sorridente")],
          [("A", "A"), ("B", "B"), ("C", "C"), ("nessuna", "Nessuna: solo sigla")]),
    ]),
    ("Jilly sul palco", [
        V("SORRISO", "2. Come sorride Jilly mentre saluta",
          "Jilly non ha una bocca normale: la sua bocca è la fauce che si apre, e nello spot non va bene."
          "\na: sorride con l'occhio: la palpebra di sotto sale a mezzaluna, come l'occhio \"^\" delle mascotte."
          "\nb: sorride con il corpo: testa inclinata, spalle su e la campana che pulsa allegra, senza cambiare il viso."
          "\nc: tutte e due insieme. Consigliata."
          "\nIl saluto con la mano c'è in tutti i casi.",
          [("img", "6b_affacciata_vicino.jpg", "Il suo occhio oggi, dal modello del gioco")],
          [("a", "a"), ("b", "b"), ("c", "c"), ("vedere", "Fammi vedere")]),
        V("NUOVA", "3. Logo, insegna e targa di Jilly da nuovi",
          "Per lo spot: gli stessi oggetti del gioco, come erano prima di invecchiarli. Smalto lucido, vernice pulita, "
          "niente ruggine. Negli scatti dal motore, a sinistra quelli del gioco e a destra quelli nuovi. All'inizio "
          "dello spot va il logo su schermo, sotto il filtro VHS.",
          [("img", "jilly_nuova_insegne.jpg", "L'insegna e la targa: com'è nel gioco e da nuova"),
           ("img", "jilly_nuova_insegna_nuova.jpg", "L'insegna nuova con le sue due lampade"),
           ("img", "jilly_nuova_targa_nuova_luce.jpg", "La targa nuova")],
          OK),
    ]),
]
