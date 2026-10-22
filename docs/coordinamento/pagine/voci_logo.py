# Pagina del logo del gioco, 22 ottobre: le tre proposte di grafica (lavoro/grafica-nome 912c4c6).

def V(vid, titolo, testo, media, scelte):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

INTRO = ("Le tre proposte per il logo di Jilly Jubilee. Nessuna è un'immagine generata: sono fatte con caratteri veri "
         "e grafica disegnata da codice, con font liberi anche per la vendita. Per ognuna c'è il logo, il logo sulla "
         "schermata del titolo vera e la prova in piccolo, grande come la copertina di Steam (qui ingrandita). Tocca "
         "una foto per ingrandirla.")

def tre(x, nome):
    return [("img", f"logo_{x}_scuro.jpg", f"{nome}: il logo"),
            ("img", f"titolo_{x}.jpg", f"{nome}: sulla schermata del titolo"),
            ("img", f"steam_{x}_x3.png", f"{nome}: grande come la copertina di Steam")]

SEZIONI = [
    ("Il logo", [
        V("LOGO", "Quale logo",
          "A, l'insegna del parco: \"Jilly\" in corsivo corallo e \"JUBILEE\" in oro su un nastro blu, con stelle e "
          "medusa, come insegna, targa e manifesto del gioco, ma rovinato: smalto saltato fino alla ruggine, colature, "
          "crepe. È la più fitta di dettagli."
          "\nB, lo show per bambini anni '90 com'era da nuovo: lettere tonde e lucide, rosa e gialle, con le bolle. La "
          "medusa fa il puntino della i, e l'unica cosa che stona è il suo occhio vero, umido, che ti guarda. È la più "
          "leggibile."
          "\nC, la versione horror: la B rovinata dall'acqua, con colori spenti, crepe, muffa e colature, e dietro il "
          "bagliore rosa di lei che passa anche dai buchi.",
          tre("a", "A") + tre("b", "B") + tre("c", "C"),
          [("A", "A, insegna"), ("B", "B, anni '90"), ("C", "C, horror"), ("cambia", "Nessuna: rifalle")]),
    ]),
]

CORRETTI = []
