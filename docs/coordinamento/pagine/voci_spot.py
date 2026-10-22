# Pagina dello spot VHS della crociera (22 ottobre, sera): testo dello speaker, nomi, inquadrature, logo e finale.
# Bozza di ambienti-2 in docs/proposte/spot/bozza.md (lavoro/ambienti-2-spot 59dd150). Solo testo e immagini già fatte.

def V(vid, titolo, testo, media, scelte):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

OK = [("ok", "Approvo"), ("cambia", "Da cambiare")]

INTRO = ("Lo spot VHS che parte dopo «Nuova partita», subito prima del risveglio. Per ora è solo scritto: le foto sono "
         "dei posti come sono oggi nel gioco, al buio. Nello spot saranno accesi e puliti, come quando la nave era nuova. "
         "Si fa dopo la v0.3.9: sono circa 4-5 giornate di lavoro, che con più squadre insieme diventano circa due giorni.")

SEZIONI = [
    ("Il testo", [
        V("TESTO", "1. Lo speaker",
          "Uno speaker americano anni '90, caldo e sorridente, con la sigla pulita sotto. Le frasi da 1 a 5 sono una "
          "pubblicità vera, la 6 è già strana, la 7 si guasta insieme al nastro."
          "\n1. «Wonderwave Cruises presents...» (Wonderwave Cruises presenta...)"
          "\n2. «...the Jubilee! The happiest ship on the seven seas!» (...la Jubilee! La nave più felice dei sette mari!)"
          "\n3. «Splash into Splash Lagoon, the biggest indoor water park afloat!» (Tuffatevi nello Splash Lagoon, "
          "il più grande acquapark coperto che galleggi!)"
          "\n4. «Twist and turn on the Tower of Slides!» (Curve e giri sulla Torre degli Scivoli!)"
          "\n5. «And meet the star of the show... Jilly Jubilee!» (E conoscete la star dello spettacolo... Jilly Jubilee!)"
          "\n6. «Jilly loves kids. Jilly will keep them safe. Forever.» (Jilly ama i bambini. Li terrà al sicuro. Per sempre.)"
          "\n7. «Come aboard. Stay aboard.», con la voce che rallenta e si abbassa (Salite a bordo. Restate a bordo.)",
          [], OK),
        V("NOMI", "2. I nomi detti dallo speaker",
          "Lo speaker dice ad alta voce tre nomi che sono ancora provvisori: la nave Jubilee, la compagnia Wonderwave "
          "Cruises e l'acquapark Splash Lagoon. Li confermi? Se ne vuoi cambiare qualcuno, scrivilo nella nota.",
          [], [("ok", "Confermo"), ("cambia", "Da cambiare")]),
    ]),
    ("Le inquadrature", [
        V("INQ", "3. Le inquadrature (circa 43 secondi)",
          "1. Schermo blu del videoregistratore con «PLAY», poi il logo (0-3 s)."
          "\n2. La cupola col cielo azzurro, poi giù sulla sala accesa (3-8 s)."
          "\n3. La piscina a onde piena, con le onde vere (8-13 s)."
          "\n4. La camera scende in un tubo della torre, tra gli schizzi (13-19 s)."
          "\n5. Jilly sul piedistallo, con le luci da spettacolo e l'insegna da nuova (19-26 s)."
          "\n6. Primo piano di Jilly che sorride e saluta; la camera le si avvicina troppo (26-32 s)."
          "\n7. Il nastro si guasta: righe, colori sbavati, la sigla rallenta (32-38 s)."
          "\n8. L'occhio di Jilly (38-43 s, è la voce 6 qui sotto)."
          "\n9. Nero, il ronzio della TV, poi il risveglio nel corridoio."
          "\nSi gira tutto nel gioco vero, con sopra il filtro della TV a tubo.",
          [("img", "menu_ab.jpg", "La cupola e Jilly oggi: nello spot saranno accese e pulite"),
           ("img", "torre_gioco_1_cima.jpg", "La torre degli scivoli oggi"),
           ("img", "monitor_crt_vicino_prima_dopo.jpg", "Lo schermo a tubo che c'è già nel gioco: il filtro dello spot parte da qui")],
          OK),
        V("PISC", "4. Piscina e torre",
          "Le inquadrature 3 (piscina) e 4 (torre) si possono tenere tutte e due, oppure una sola, per uno spot più corto "
          "di circa 6 secondi.",
          [], [("due", "Tutte e due"), ("piscina", "Solo la piscina"), ("torre", "Solo la torre")]),
        V("LOGO", "5. Il logo all'inizio",
          "Nelle scritte del gioco va solo il nome di Jilly Jubilee (la tua regola dei cartelli). Per l'inizio dello spot:"
          "\na: il logo della compagnia, Wonderwave Cruises, un disegno con il nome."
          "\nb: subito il logo di Jilly, da nuovo, senza ruggine. Consigliata: rispetta la regola, e Jilly si conosce "
          "subito."
          "\nIn tutti e due i casi resta la scritta «PLAY» del videoregistratore.",
          [], [("a", "a"), ("b", "b")]),
    ]),
    ("Il finale", [
        V("OCCHIO", "6. L'occhio di Jilly",
          "L'occhio riempie lo schermo. La pupilla si allarga e si stringe col ritmo di un battito che accelera. Nella "
          "pupilla girano spirali e anelli rosa e viola, come i suoi tentacoli, e i colori si separano a ogni battito. "
          "I fotogrammi saltano, e per un attimo l'immagine va in negativo. Si sente un ronzio basso che sale, con la "
          "sigla al contrario. Alla fine l'occhio scatta verso di te, e subito nero. Niente sangue: fa paura col ritmo, "
          "l'occhio e il suono.",
          [("img", "6b_affacciata_vicino.jpg", "Il suo occhio oggi, dal modello del gioco")],
          OK),
    ]),
]
