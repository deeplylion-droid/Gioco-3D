# Pagina delle scelte del 19 ottobre: posti delle statue, nome Jilly Jubilee nel parco, lingua delle scritte,
# inseguimento e finale, geyser. media: (tipo, file nella cartella dei media, didascalia[, larghezza]).

def V(vid, titolo, testo, media=(), scelte=None):
    return dict(id=vid, titolo=titolo, testo=testo, media=list(media), scelte=scelte)

SI_NO = [("si", "Sì, mettila"), ("no", "No, non serve"), ("cambia", "Da cambiare")]

INTRO = ("Le proposte di questa notte, tutte su modelli e scatti veri dal gioco, senza torcia e con le luci vere: dove "
         "mettere le statue che hai scelto, il nome Jilly Jubilee nel parco, l'inseguimento con il finale e il geyser "
         "nuovo. Nel gioco per ora non c'è niente di tutto questo: metto solo quello che approvi. Tocca una foto per "
         "ingrandirla.")

PIANTA = ("img", "pianta_posti.jpg", "La sala vista dall'alto con i nove posti", 1000)

SEZIONI = [
    ("Dove mettere le statue", [
        V("SQP", "Lo squalo A (pollice in su)",
          "Dove lo metto? Nella pianta sono S1, S2 e S3."
          "\nS1, all'ingresso: appena entri dagli spogliatoi, a destra, vicino alla pila di palloni. Guarda chi entra, e "
          "nella luce rossa dell'ingresso resta colorato."
          "\nS2, bordo est: sul bordo della piscina a onde, accanto alla sedia del bagnino e ai lettini. Guarda la piscina."
          "\nS3, spiaggia: contro il muro nord, in fondo alla spiaggia della piscina. Guarda la piscina."
          "\nIn S2 e in S3 si vede come una sagoma scura contro i muri illuminati.",
          [PIANTA,
           ("img", "squalo_1_ingresso.jpg", "S1, all'ingresso"),
           ("img", "squalo_2_bordo_est.jpg", "S2, bordo est della piscina a onde"),
           ("img", "squalo_3_spiaggia.jpg", "S3, in fondo alla spiaggia")],
          [("S1", "S1, ingresso"), ("S2", "S2, bordo est"), ("S3", "S3, spiaggia"), ("nessuno", "Nessuno: altri posti")]),
        V("PAP", "Il polpo A (braccia aperte)",
          "Dove lo metto? Nella pianta sono A1, A2 e A3."
          "\nA1, all'ingresso: appena entri, a sinistra; saluta chi entra. Senza torcia si vede poco: è lontano, nella "
          "penombra rossa."
          "\nA2, davanti alla serranda del magazzino: lo vedi bene anche uscendo dal magazzino al buio, nella tappa 7 "
          "(ultima foto, con la scia rosa accanto)."
          "\nA3, all'area bimbi: all'ingresso dell'area, vicino allo scivolo giallo.",
          [("img", "polpo_A_1_ingresso.jpg", "A1, all'ingresso"),
           ("img", "polpo_A_2_serranda.jpg", "A2, davanti alla serranda del magazzino"),
           ("img", "polpo_A_2_serranda_buio.jpg", "A2 al buio, nella tappa 7"),
           ("img", "polpo_A_3_bimbi.jpg", "A3, all'ingresso dell'area bimbi")],
          [("A1", "A1, ingresso"), ("A2", "A2, serranda"), ("A3", "A3, area bimbi"), ("nessuno", "Nessuno: altri posti")]),
        V("PBP", "Il polpo B (maschera e gelato)",
          "Dove lo metto? Nella pianta sono B1, B2 e B3."
          "\nB1, area bimbi: contro il muro ovest, accanto al fungo. Nella tappa 8, al buio, resta quasi nascosto dietro la "
          "medusa che sbuca dalla fossa (ultima foto)."
          "\nB2, spiaggia: nell'angolo nord-est della spiaggia della piscina."
          "\nB3, solarium: dietro i lettini sul lato est."
          "\nIn B2 e in B3 si vede come una sagoma scura contro i muri illuminati.",
          [("img", "polpo_B_1_bimbi.jpg", "B1, area bimbi accanto al fungo"),
           ("img", "polpo_B_1_bimbi_buio.jpg", "B1 nella tappa 8, dietro la medusa"),
           ("img", "polpo_B_2_spiaggia_est.jpg", "B2, angolo della spiaggia"),
           ("img", "polpo_B_3_solarium.jpg", "B3, dietro i lettini")],
          [("B1", "B1, area bimbi"), ("B2", "B2, spiaggia"), ("B3", "B3, solarium"), ("nessuno", "Nessuno: altri posti")]),
    ]),
    ("Il nome Jilly Jubilee nel parco", [
        V("JLS", "Lo stile del logo",
          "Due stili, ognuno su tre oggetti: una targa, il manifesto dello spettacolo e un'insegna. Le prime due foto sono "
          "render dei modelli veri, le altre sono ingrandimenti presi dal gioco."
          "\nA, \"a bolle\": lettere gonfie e lucide come un gonfiabile, dal rosa al lilla, con il contorno bianco, bollicine "
          "e un'onda. Il puntino delle due i è l'occhio di Jilly. È nello spirito delle mascotte del parco."
          "\nB, \"spettacolo della nave\": \"Jilly\" in corsivo corallo, \"JUBILEE\" in oro su un nastro blu, stelle e una "
          "piccola medusa. Fa più spettacolo anni '90 in crociera.",
          [("img", "jilly_oggetti_stile_a.jpg", "Stile A: targa, manifesto e insegna", 1000),
           ("img", "jilly_oggetti_stile_b.jpg", "Stile B: targa, manifesto e insegna", 1000),
           ("img", "jilly_manifesto_a_dettaglio.jpg", "Il manifesto A nel gioco, da vicino"),
           ("img", "jilly_manifesto_b_dettaglio.jpg", "Il manifesto B nel gioco, da vicino")],
          [("A", "A, a bolle"), ("B", "B, spettacolo della nave"), ("cambia", "Nessuno: rifalli")]),
        V("JLT", "La targa sulla vasca di Jilly",
          "Una targa smaltata di 70 x 39 cm, avvitata sul lato ovest della vasca sollevata, accanto al cordone. Da vicino "
          "si legge.",
          [("img", "jilly_targa_a.jpg", "Targa A"), ("img", "jilly_targa_a_dettaglio.jpg", "Targa A, da vicino"),
           ("img", "jilly_targa_b.jpg", "Targa B"), ("img", "jilly_targa_b_dettaglio.jpg", "Targa B, da vicino")],
          SI_NO),
        V("JLM", "Il manifesto dello spettacolo",
          "Un manifesto di 70 x 105 cm sul muro ovest vicino all'ingresso, tra il cartello giallo e l'oblò. È sbiadito, "
          "piegato e strappato, con il nastro adesivo. Dice \"LIVE SHOW, EVERY DAY 11 AM & 4 PM\". Nella luce rossa "
          "della lampada accanto si riconoscono Jilly e il logo, ma gli orari si leggono a fatica.",
          [("img", "jilly_manifesto_a.jpg", "Manifesto A"), ("img", "jilly_manifesto_a_dettaglio.jpg", "Manifesto A, da vicino"),
           ("img", "jilly_manifesto_b.jpg", "Manifesto B"), ("img", "jilly_manifesto_b_dettaglio.jpg", "Manifesto B, da vicino")],
          SI_NO),
        V("JLI", "L'insegna sopra la vasca d'arrivo",
          "Un'insegna di lamiera dipinta di 1,8 x 1 m in una cornice d'acciaio, in alto sul muro ovest, sopra la vasca "
          "d'arrivo del finale, tra due oblò. Lassù arriva poca luce: al buio è quasi nera e il logo non si legge. Se la "
          "vuoi leggibile, posso darle due lampade sue a collo d'oca, consumate, con una luce calda e debole: in quel caso "
          "te la mostro accesa prima di metterla nel gioco.",
          [("img", "jilly_insegna_a.jpg", "Insegna A, com'è al buio"), ("img", "jilly_insegna_a_dettaglio.jpg", "Insegna A, ingrandita"),
           ("img", "jilly_insegna_b.jpg", "Insegna B, com'è al buio"), ("img", "jilly_insegna_b_dettaglio.jpg", "Insegna B, ingrandita")],
          [("buio", "Sì, al buio com'è"), ("lampade", "Sì, con le sue lampade"), ("no", "No, non serve"), ("cambia", "Da cambiare")]),
        V("LINGUA", "La lingua delle scritte del parco",
          "Finora i cartelli del gioco hanno solo disegni. Il manifesto di Jilly è in inglese (\"LIVE SHOW\"), mentre "
          "l'insegna della giostra dell'inseguimento B è in italiano (\"LE RAPIDE\"). Le scritte del parco devono essere "
          "tutte nella stessa lingua: quale?",
          [("img", "jilly_manifesto_b_dettaglio.jpg", "In inglese: il manifesto di Jilly"),
           ("img", "inseguimento_B_1_partenza.jpg", "In italiano: l'insegna delle rapide")],
          [("en", "Inglese"), ("it", "Italiano"), ("disegni", "Solo disegni, niente scritte")]),
    ]),
    ("L'inseguimento e il finale", [
        V("INS", "L'inseguimento negli scivoli e il finale SB1",
          "Dalla bocca in fondo alla torre si scende in una sala nuova, ricavata nello scafo, e lei ti insegue. Ai bivi la "
          "paratia giusta ha la luce verde e un anello di led verdi, quella sbagliata una lampada rossa guasta: la colpisci "
          "col getto e scivoli via. Se sbagli, lei ti prende e riparti dal bivio. Un getto in faccia la respinge per qualche "
          "secondo. In fondo cala una grata davanti a lei; poi, prima della porta d'uscita, lei sbuca dal pozzo di scarico "
          "e ti guarda: è l'ultima immagine del capitolo (SB1)."
          "\nA, \"Le condotte\": una sala macchine piena e allagata. Si scivola in tubi chiusi tra tre vasche sospese: nel "
          "tubo non la vedi, nelle vasche sì. Più claustrofobica, a fasi. Circa 5 minuti e 40 secondi."
          "\nB, \"Le rapide\": una giostra di rapide, con acqua bianca in un canale aperto tra scogli finti, gommoni "
          "rovesciati e lampioncini sulle sponde. Lei nuota dietro di te e la vedi quasi sempre. Più d'azione. Circa 6 "
          "minuti e 30 secondi."
          "\nSono proposte: lei usa ancora le pose che il modello ha già, e le animazioni vere dell'inseguimento sono da "
          "fare. Nella B la schiuma è ancora a chiazze e il fondo tra gli scogli è scuro: li sistemo nella versione che "
          "scegli.",
          [("video", "inseguimento_A.mp4", "A, Le condotte: il percorso"),
           ("img", "inseguimento_A_pianta.jpg", "A, la pianta"),
           ("img", "inseguimento_A_1_primo_bivio.jpg", "A, il primo bivio"),
           ("img", "inseguimento_A_2_lei_ti_raggiunge.jpg", "A, lei ti raggiunge nella vasca"),
           ("img", "inseguimento_A_5_sb1.jpg", "A, il finale SB1"),
           ("video", "inseguimento_B.mp4", "B, Le rapide: il percorso"),
           ("img", "inseguimento_B_pianta.jpg", "B, la pianta"),
           ("img", "inseguimento_B_1b_rapide.jpg", "B, nel canale delle rapide"),
           ("img", "inseguimento_B_3_bivio_2.jpg", "B, il secondo bivio, con lei sullo scoglio"),
           ("img", "inseguimento_B_5_sb1.jpg", "B, il finale SB1")],
          [("A", "A, Le condotte"), ("B", "B, Le rapide"), ("cambia", "Nessuna: rifalle")]),
    ]),
    ("Il geyser", [
        V("GEY", "Il geyser che avvolge Jilly",
          "Il geyser nuovo, rifatto dopo che quello di prima ti era sembrato di bassa qualità. L'acqua non è trasparente."
          "\nV2, la proposta: una colonna d'acqua simulata e resa come un filmato, che prende la luce rossa e rosa della "
          "sala, con gocce sottili che brillano solo dove le colpisce una luce. Da 5-8 metri, cioè da dove la spruzzi, "
          "sembra acqua che esplode; da vicino resta un po' grumosa. Il punto bianco al centro è un difetto che tolgo."
          "\nV1, l'alternativa: la stessa simulazione come modello 3D vero, giusta da ogni lato, ma da vicino più simile "
          "alla panna."
          "\nPer andare oltre servirebbe una simulazione più fine, che richiede molte ore.",
          [("video", "geyser_v2.mp4", "V2, nella sala al buio"),
           ("img", "geyser_v2_fotogrammi.jpg", "V2: fotogrammi ingranditi (prima, dopo, con la camera che gira)", 1000),
           ("video", "geyser_v1.mp4", "V1, nella sala al buio")],
          [("V2", "V2"), ("V1", "V1"), ("cambia", "Nessuno: rifallo")]),
    ]),
]
