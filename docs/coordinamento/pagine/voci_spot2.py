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
        V("SALUTO", "3. Il saluto, già fatto",
          "L'animazione nuova di mascotte, dal motore: alza il braccio, saluta con la mano aperta di lato al viso, "
          "con il busto che ondeggia appena e la testa piegata verso la mano, poi torna giù. Qui è su un piedistallo "
          "di prova; nello spot avrà la sala pulita e i fari rosa e viola.",
          [("img", "saluto_saluta_a.jpg", "Mentre saluta"),
           ("img", "saluto_primo_piano.jpg", "Il primo piano dell'inquadratura 6"),
           ("img", "saluto_alza.jpg", "Quando alza il braccio")],
          OK),
        V("PIEDISTALLO", "4. Dove sta Jilly sul palco",
          "Nel gioco, al centro della sala c'è la vasca a scacchi con Jilly affacciata, e non c'è un piedistallo."
          "\na: un piedistallo dentro la vasca: un tamburo rotondo a mosaico blu, alto quanto il bordo, che esce "
          "dall'acqua al centro. Jilly ci sta in piedi, e qualche tentacolo scende in acqua. Vasca, colonnine col "
          "cordone, targa e pulsante restano quelli del gioco: è lo stesso posto, anni prima. Consigliata."
          "\nb: il monumento a gradoni delle prime versioni, al posto della vasca. Il modello c'è già, ma il posto "
          "non sarebbe più lo stesso del gioco.",
          [("img", "vasca_oggi.jpg", "La vasca di oggi, dove andrebbe il piedistallo della a"),
           ("img", "sala_godot_monumento_ingresso.jpg", "b: il monumento a gradoni, dalle prime versioni")],
          [("a", "a"), ("b", "b"), ("vedere", "Fammi vedere")]),
        V("NUOVA", "5. Logo, insegna e targa di Jilly da nuovi",
          "Per lo spot: gli stessi oggetti del gioco, come erano prima di invecchiarli. Smalto lucido, vernice pulita, "
          "niente ruggine. Negli scatti dal motore, a sinistra quelli del gioco e a destra quelli nuovi. All'inizio "
          "dello spot va il logo su schermo, sotto il filtro VHS.",
          [("img", "jilly_nuova_insegne.jpg", "L'insegna e la targa: com'è nel gioco e da nuova"),
           ("img", "jilly_nuova_insegna_nuova.jpg", "L'insegna nuova con le sue due lampade"),
           ("img", "jilly_nuova_targa_nuova_luce.jpg", "La targa nuova")],
          OK),
    ]),
]
