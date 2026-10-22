# Pagina del logo del gioco, 22 ottobre: le tre proposte di grafica (lavoro/grafica-nome 912c4c6).

def V(vid, titolo, testo, media, scelte):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

INTRO = ("Tre loghi nuovi, molto diversi dai primi e meno da cartone animato. Anche questi sono fatti con caratteri "
         "veri e grafica disegnata da codice, niente immagini generate. Per ognuno c'è il logo, il logo sulla schermata "
         "del titolo vera e la prova in piccolo, grande come la copertina di Steam (qui ingrandita).")

def tre(x, nome):
    return [("img", f"logo_{x}_scuro.jpg", f"{nome}: il logo"),
            ("img", f"titolo_{x}.jpg", f"{nome}: sulla schermata del titolo"),
            ("img", f"steam_{x}_x3.png", f"{nome}: grande come la copertina di Steam")]

SEZIONI = [
    ("Il logo, secondo giro", [
        V("LOGO2", "Quale logo",
          "D, l'insegna al neon del parco, di notte: \"Jilly\" in tubo rosa e \"JUBILEE\" in tubo azzurro su lamiera "
          "scura, con la medusa in neon lilla. Una l è mezza accesa e l'ultima E è spenta, ma il nome si legge sempre."
          "\nE, il titolo da film horror: maiuscole sottili e spaziate, avorio su nero. Un solo segno di lei: la coda "
          "della J di JUBILEE scende e diventa un tentacolo rosa. È la più pulita da piccola."
          "\nF, il disegno dei bambini: il nome a pastelli a cera su un foglio ingiallito con lo scotch. Sotto, la "
          "medusa sorridente tiene per mano un bambino, che ha la faccia cancellata col pastello nero.",
          tre("d", "D") + tre("e", "E") + tre("f", "F"),
          [("D", "D, neon"), ("E", "E, film"), ("F", "F, disegno"), ("cambia", "Nessuno: rifalli")]),
    ]),
]

CORRETTI = []
