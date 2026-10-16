#!/usr/bin/env python3
"""Mappa schematica dall'alto del capitolo 1, versione decisa (percorso A).

Uso:
    python genera_mappa_capitolo1.py            # scrive le due mappe accanto allo script
    python genera_mappa_capitolo1.py <cartella>

Scrive:
    mappa_capitolo1.png           percorso deciso, tappa per tappa
    mappa_capitolo1_proposte.png  proposte da approvare: Polaroid e bambini

Serve matplotlib. Le coordinate sono in pixel dell'immagine
(1200 di larghezza, y verso il basso). Le parti ancora da confermare
sono disegnate con il bordo tratteggiato rosso.
Le mappe delle proposte (percorsi A, B, C) restano in docs/proposte/livello/mappe/.
"""
import math
import sys
from pathlib import Path as FsPath

import matplotlib

matplotlib.use("Agg")
import matplotlib.patheffects as pe  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import (  # noqa: E402
    Circle,
    FancyBboxPatch,
    PathPatch,
    Polygon,
    Rectangle,
)
from matplotlib.path import Path  # noqa: E402

W = 1200
DPI = 100
PT = 72 / DPI  # da pixel a punti
matplotlib.rcParams["hatch.linewidth"] = 2.0

# ---- colori -------------------------------------------------------------
SFONDO = "#F6F3EC"
INCHIOSTRO = "#1F2328"
GRIGIO = "#56616B"
BORDO = "#47525C"
SALA = "#E2E8EE"
BIMBI = "#FFE29A"
VASCA = "#B9DAF2"
PISCINA = ("#DDECF9", "#C6DEF3", "#AECDEA")  # spiaggia -> fondo
TORRE = "#C6E6CF"
SPOGLIATOI = "#E2D4F1"
POMPE = "#F5CDAE"
PONTE = "#D6D6D6"
SCIVOLI = "#EDB2D6"
PRIMA = "#1E5EC8"  # blu: prima delle pompe
DOPO = "#D0312D"  # rosso: dopo le pompe, lei e' sveglia
STATUA = "#C2185B"
LEGNO = "#7A4A2A"
TRATTEGGIO = (0, (2, 1.2))  # bordo delle cose da confermare
VIOLA = "#5E35B1"  # bambini visti di sfuggita
FOTO = "#2F4A5E"  # interno delle Polaroid
TENUE = "#B4AC9F"  # percorso sullo sfondo, nella mappa delle proposte


def px(v):
    return v * PT


# ---- primitive ----------------------------------------------------------
def nuova_figura(h):
    fig = plt.figure(figsize=(W / DPI, h / DPI), dpi=DPI)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, W)
    ax.set_ylim(h, 0)
    ax.axis("off")
    fig.patch.set_facecolor(SFONDO)
    return fig, ax


def testo(ax, x, y, s, size=40, bold=True, color=INCHIOSTRO, ha="center",
          va="center", alone=None, style="normal", z=30):
    t = ax.text(x, y, s, fontsize=px(size), color=color, ha=ha, va=va,
                fontweight="bold" if bold else "normal", fontstyle=style,
                linespacing=1.0, zorder=z)
    if alone:
        t.set_path_effects([pe.withStroke(linewidth=px(10), foreground=alone)])
    return t


def stanza(ax, x0, y0, x1, y1, colore, tratteggio=False, r=22, z=2, lw=4):
    p = FancyBboxPatch((x0, y0), x1 - x0, y1 - y0,
                       boxstyle=f"round,pad=0,rounding_size={r}",
                       facecolor=colore, edgecolor=BORDO, lw=px(lw), zorder=z)
    if tratteggio:
        p.set_linestyle((0, (3.5, 2)))
    ax.add_patch(p)
    return p


def _arrotonda(punti, r=30):
    verts, codes = [punti[0]], [Path.MOVETO]
    for i in range(1, len(punti) - 1):
        (x0, y0), (x1, y1), (x2, y2) = punti[i - 1], punti[i], punti[i + 1]
        l1 = math.hypot(x1 - x0, y1 - y0)
        l2 = math.hypot(x2 - x1, y2 - y1)
        rr = min(r, l1 / 2, l2 / 2)
        a = (x1 - (x1 - x0) / l1 * rr, y1 - (y1 - y0) / l1 * rr)
        b = (x1 + (x2 - x1) / l2 * rr, y1 + (y2 - y1) / l2 * rr)
        verts += [a, (x1, y1), b]
        codes += [Path.LINETO, Path.CURVE3, Path.CURVE3]
    verts.append(punti[-1])
    codes.append(Path.LINETO)
    return Path(verts, codes)


def _punta(ax, da, a, colore, z, lung=40, larg=38):
    dx, dy = a[0] - da[0], a[1] - da[1]
    lun = math.hypot(dx, dy)
    ux, uy = dx / lun, dy / lun
    bx, by = a[0] - ux * lung, a[1] - uy * lung
    nx, ny = -uy, ux
    tri = [a, (bx + nx * larg / 2, by + ny * larg / 2),
           (bx - nx * larg / 2, by - ny * larg / 2)]
    ax.add_patch(Polygon(tri, closed=True, facecolor=colore, edgecolor="white",
                         lw=px(3), joinstyle="miter", zorder=z))


def _accorcia(p_da, p_a, d):
    dx, dy = p_a[0] - p_da[0], p_a[1] - p_da[1]
    lun = math.hypot(dx, dy)
    return (p_a[0] - dx / lun * d, p_a[1] - dy / lun * d)


def percorso(ax, punti, colore, tratteggiato=False, spessore=12, punta=True, z=10,
             testa=1.0):
    punti = [tuple(p) for p in punti]
    linea = list(punti)
    if punta:
        linea[-1] = _accorcia(linea[-2], linea[-1], 30 * testa)
    path = _arrotonda(linea)
    ax.add_patch(PathPatch(path, fill=False, lw=px(spessore + 8), edgecolor="white",
                           capstyle="round", joinstyle="round", zorder=z))
    pp = PathPatch(path, fill=False, lw=px(spessore), edgecolor=colore,
                   capstyle="butt" if tratteggiato else "round",
                   joinstyle="round", zorder=z + 0.1)
    if tratteggiato:
        pp.set_linestyle((0, (1.4, 0.9)))
    ax.add_patch(pp)
    if punta:
        _punta(ax, punti[-2], punti[-1], colore, z + 0.2, lung=40 * testa, larg=38 * testa)


def numero(ax, x, y, n, colore=INCHIOSTRO, r=28, z=40):
    ax.add_patch(Circle((x, y), r, facecolor=colore, edgecolor="white",
                        lw=px(4), zorder=z))
    testo(ax, x, y + 1, str(n), size=(33 if n < 10 else 28) * r / 28,
          color="white", z=z + 1)


def numero_da_confermare(ax, x, y, n, r=28, z=40):
    """Tappa ancora da confermare: cerchio bianco con bordo rosso tratteggiato."""
    c = Circle((x, y), r, facecolor="white", edgecolor=DOPO, lw=px(5), zorder=z)
    c.set_linestyle(TRATTEGGIO)
    ax.add_patch(c)
    testo(ax, x, y + 1, str(n), size=(33 if str(n).isdigit() and int(n) < 10 else 28) * r / 28,
          color=DOPO, z=z + 1)


def strada_chiusa(ax, x, y, lato=52, z=8):
    """Strada bloccata (da confermare): riquadro grigio con una croce."""
    p = FancyBboxPatch((x - lato / 2, y - lato / 2), lato, lato,
                       boxstyle="round,pad=0,rounding_size=8", facecolor="#8A8F96",
                       edgecolor=DOPO, lw=px(4), zorder=z)
    p.set_linestyle(TRATTEGGIO)
    ax.add_patch(p)
    testo(ax, x, y + 1, "×", size=lato * 0.9, color="white", z=z + 1)


def polaroid(ax, x, y, n, z=45):
    """Polaroid da collezione: cornice bianca, foto scura con il numero."""
    w, h = 50, 60
    ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h,
                                boxstyle="round,pad=0,rounding_size=4", facecolor="white",
                                edgecolor=INCHIOSTRO, lw=px(3), zorder=z))
    ax.add_patch(Rectangle((x - w / 2 + 6, y - h / 2 + 6), w - 12, h - 22,
                           facecolor=FOTO, edgecolor="none", zorder=z + 0.1))
    testo(ax, x, y - 5, str(n), size=26 if n < 10 else 21, color="white", z=z + 0.2)


def bambini(ax, x, y, n, s=31, z=45):
    """Momento in cui si vedono di sfuggita i bambini: rombo viola."""
    ax.add_patch(Polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)], closed=True,
                         facecolor=VIOLA, edgecolor="white", lw=px(4), zorder=z))
    testo(ax, x, y + 1, f"B{n}", size=21, color="white", z=z + 0.1)


def statua(ax, x, y, r=27, z=38):
    ax.add_patch(Circle((x, y), r, facecolor=STATUA, edgecolor="white",
                        lw=px(4), zorder=z))
    testo(ax, x, y + 2, "★", size=36 * r / 27, bold=False, color="white",
          z=z + 1)


def secchio(ax, x, y, z=5):
    ax.add_patch(Polygon([(x - 32, y - 24), (x + 32, y - 24), (x + 21, y + 26),
                          (x - 21, y + 26)], closed=True, facecolor="#F28C28",
                         edgecolor=BORDO, lw=px(3), zorder=z))
    ax.add_patch(Rectangle((x - 36, y - 30), 72, 8, facecolor="#C96A12",
                           edgecolor=BORDO, lw=px(2), zorder=z + 0.1))


def scala(ax, x0, y0, x1, y1, z=4):
    ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0, facecolor="white",
                           edgecolor=BORDO, lw=px(3), hatch="---", zorder=z))


def porta(ax, x, y, verticale=True, z=6):
    if verticale:
        ax.add_patch(Rectangle((x - 8, y - 28), 16, 56, facecolor=LEGNO,
                               edgecolor="white", lw=px(2), zorder=z))
    else:
        ax.add_patch(Rectangle((x - 28, y - 8), 56, 16, facecolor=LEGNO,
                               edgecolor="white", lw=px(2), zorder=z))


def scivoli(ax, punti, z=3):
    path = _arrotonda(punti, r=40)
    ax.add_patch(PathPatch(path, fill=False, lw=px(34), edgecolor=SCIVOLI,
                           capstyle="round", joinstyle="round", zorder=z))


# ---- pianta (da confermare anche lei) -----------------------------------
STATUA_XY = (600, 905)
SCIVOLO = [(1095, 300), (1095, 205), (55, 205), (55, 722), (140, 722)]


def pianta(ax):
    # sala grande sotto la cupola
    stanza(ax, 20, 165, 1180, 1010, SALA, r=36, z=1)
    testo(ax, 42, 988, "sala grande (sotto la cupola)", size=24, bold=False,
          color=GRIGIO, ha="left", z=3)

    # area bimbi, con le vasche basse
    stanza(ax, 90, 245, 400, 560, BIMBI)
    testo(ax, 245, 425, "AREA BIMBI", size=40, alone=BIMBI)
    testo(ax, 245, 470, "secchio gigante", size=28, bold=False, alone=BIMBI)
    secchio(ax, 150, 300)

    # vasca d'arrivo degli scivoli
    stanza(ax, 90, 640, 400, 860, VASCA)
    testo(ax, 255, 765, "VASCA", size=34, alone=VASCA)
    testo(ax, 255, 805, "D'ARRIVO", size=34, alone=VASCA)

    # piscina a onde (vuota): spiaggia in alto, fondo in basso
    x0, x1, y0, y1 = 480, 790, 245, 800
    stanza(ax, x0, y0, x1, y1, PISCINA[1])
    ax.add_patch(Rectangle((x0 + 3, y0 + 3), x1 - x0 - 6, 120, facecolor=PISCINA[0],
                           edgecolor="none", zorder=2.1))
    ax.add_patch(Rectangle((x0 + 3, y1 - 175), x1 - x0 - 6, 172, facecolor=PISCINA[2],
                           edgecolor="none", zorder=2.1))
    stanza(ax, x0, y0, x1, y1, "none", z=2.2)
    testo(ax, 690, 322, "spiaggia", size=24, bold=False, color=GRIGIO,
          style="italic", z=3)
    testo(ax, 525, 778, "fondo", size=24, bold=False, color=GRIGIO,
          style="italic", ha="left", z=3)
    testo(ax, 640, 470, "PISCINA", size=40, alone=PISCINA[1])
    testo(ax, 640, 515, "A ONDE", size=40, alone=PISCINA[1])
    testo(ax, 640, 560, "(vuota)", size=30, bold=False, alone=PISCINA[1])

    # torre degli scivoli
    stanza(ax, 840, 245, 1150, 520, TORRE)
    testo(ax, 985, 365, "TORRE", size=40, alone=TORRE)
    testo(ax, 985, 410, "SCIVOLI", size=40, alone=TORRE)

    # scivoli: dalla cima della torre, lungo il bordo della sala, fino alla vasca d'arrivo
    scivoli(ax, SCIVOLO)

    # spogliatoi
    stanza(ax, 300, 1050, 800, 1190, SPOGLIATOI)
    testo(ax, 610, 1158, "SPOGLIATOI", size=40, alone=SPOGLIATOI)

    # sala pompe, un piano sotto
    stanza(ax, 860, 1050, 1170, 1340, POMPE, tratteggio=True)
    testo(ax, 1015, 1150, "SALA", size=38)
    testo(ax, 1015, 1192, "POMPE", size=38)
    testo(ax, 1015, 1232, "(un piano sotto)", size=24, bold=False)

    # camera delle onde: tunnel sotto il bordo profondo, verso la sala pompe
    stanza(ax, 700, 812, 790, 846, "#9FB4C6", tratteggio=True, r=8, z=2, lw=3)
    testo(ax, 802, 817, "camera", size=22, bold=False, color=GRIGIO, ha="left", z=3)
    testo(ax, 802, 843, "delle onde", size=22, bold=False, color=GRIGIO, ha="left",
          z=3)

    # ponte inferiore (ingresso)
    stanza(ax, 40, 1230, 860, 1340, PONTE)
    testo(ax, 40, 1372, "PONTE INFERIORE (ingresso)", size=30, ha="left")

    # scale e porte
    scala(ax, 365, 1190, 445, 1230)
    porta(ax, 860, 1290)  # porta della sala pompe sul ponte inferiore
    testo(ax, 900, 1372, "porta chiusa", size=24, bold=False, color=GRIGIO,
          ha="center")
    porta(ax, 620, 1050, verticale=False)  # uscita degli spogliatoi verso la sala


def legenda(ax, y0, tappe, da_confermare=()):
    y = y0
    ax.plot([30, 1170], [y - 40, y - 40], color="#CFC8BA", lw=px(3), zorder=1)
    percorso(ax, [(40, y), (130, y)], PRIMA, spessore=12, z=50)
    testo(ax, 150, y, "prima delle pompe", size=30, bold=False, ha="left")
    percorso(ax, [(620, y), (710, y)], DOPO, spessore=12, z=50)
    testo(ax, 730, y, "dopo: lei è sveglia", size=30, bold=False, ha="left")
    y += 58
    scivoli(ax, [(45, y), (125, y)], z=49)
    percorso(ax, [(40, y), (130, y)], DOPO, tratteggiato=True, z=50)
    testo(ax, 150, y, "inseguimento (scivoli)", size=30, bold=False, ha="left")
    statua(ax, 665, y, r=24)
    testo(ax, 730, y, "la statua", size=30, bold=False, ha="left")
    y += 58
    stanza(ax, 45, y - 18, 125, y + 18, "white", tratteggio=True, r=6, z=49, lw=3)
    testo(ax, 150, y, "un piano sotto", size=30, bold=False, ha="left")
    porta(ax, 665, y, z=50)
    testo(ax, 730, y, "porta", size=30, bold=False, ha="left")
    y += 60
    strada_chiusa(ax, 85, y, lato=44, z=50)
    testo(ax, 150, y, "strada chiusa (da confermare)", size=30, bold=False, ha="left")
    y += 50
    ax.plot([30, 1170], [y, y], color="#CFC8BA", lw=px(3), zorder=1)
    y += 48
    for n, nome, minuti in tappe:
        if n in da_confermare:
            numero_da_confermare(ax, 62, y, n, r=24)
        else:
            numero(ax, 62, y, n, r=24)
        testo(ax, 104, y, nome, size=32, bold=False, ha="left")
        testo(ax, 1165, y, minuti, size=32, ha="right")
        y += 54
    return y


def titolo(ax, t, sotto):
    testo(ax, 40, 60, t, size=58, ha="left")
    testo(ax, 40, 118, sotto, size=32, bold=False, color=GRIGIO, ha="left")


def salva(fig, ax, h_usata, out):
    ax.set_ylim(h_usata, 0)
    fig.set_size_inches(W / DPI, h_usata / DPI)
    fig.savefig(out, dpi=DPI, facecolor=SFONDO)
    plt.close(fig)
    # PNG piu' leggero: palette da 128 colori, senza retinatura
    from PIL import Image
    with Image.open(out) as im:
        ridotta = im.convert("RGB").quantize(colors=128, method=Image.Quantize.MEDIANCUT,
                                             dither=Image.Dither.NONE)
    ridotta.save(out, optimize=True)
    print("scritta", out)


# ---- percorso A, versione decisa ----------------------------------------
# Tratti blu: prima delle pompe
ARRIVO = [(770, 1268), (405, 1268), (405, 1088), (580, 1088), (580, 940)]  # 1 -> 2 -> 3
VERSO_BIMBI = [(572, 905), (420, 905), (420, 600), (245, 600), (245, 568)]  # 3 -> 4
VERSO_PISCINA = [(400, 340), (510, 340), (510, 740)]  # 4 -> 5, giu' fino al fondo
VERSO_POMPE = [(510, 740), (745, 740), (745, 985), (930, 985), (930, 1075)]  # 5 -> 6
# Tratti rossi: dopo le pompe
RITORNO = [(905, 1300), (435, 1300), (435, 1120), (640, 1120), (640, 1050),
           (628, 940)]  # 6 -> 7, dagli spogliatoi al buio
VERSO_VASCHE = [(585, 868), (455, 868), (455, 520), (368, 520)]  # 7 -> 8, vasche basse
VERSO_TORRE = [(400, 290), (850, 290)]  # 8 -> 9, sulla spiaggia della piscina vuota
PRIMA_DELLE_POMPE = (ARRIVO, VERSO_BIMBI, VERSO_PISCINA, VERSO_POMPE)
DOPO_LE_POMPE = (RITORNO, VERSO_VASCHE, VERSO_TORRE)


def tubo_rotto(ax):
    """Da confermare: un tubo scoppiato chiude la strada diretta per la torre."""
    ax.add_patch(PathPatch(_arrotonda([(630, 905), (1000, 905), (1000, 524)]),
                           fill=False, lw=px(6), edgecolor="#8A8F96",
                           linestyle=(0, (2, 1.6)), capstyle="butt", zorder=5))
    strada_chiusa(ax, 870, 905)
    testo(ax, 870, 950, "tubo rotto", size=22, bold=False, color=GRIGIO, z=3)


def mappa_capitolo1(cartella):
    fig, ax = nuova_figura(2450)
    titolo(ax, "Capitolo 1 · Percorso A", "Versione decisa · circa 42 minuti")
    pianta(ax)
    statua(ax, *STATUA_XY)
    tubo_rotto(ax)

    z = 10
    for punti in PRIMA_DELLE_POMPE:
        percorso(ax, punti, PRIMA, z=z)
        z += 1
    for punti in DOPO_LE_POMPE:
        percorso(ax, punti, DOPO, z=z)
        z += 1
    percorso(ax, SCIVOLO, DOPO, tratteggiato=True, z=z)  # 9 -> 10 -> 11

    numero(ax, 800, 1268, 1)
    numero(ax, 345, 1120, 2)
    numero(ax, 540, 965, 3)
    numero(ax, 330, 330, 4)
    numero(ax, 700, 640, 5)
    numero(ax, 1015, 1290, 6)
    numero(ax, 680, 965, 7, colore=DOPO)
    numero(ax, 300, 520, 8, colore=DOPO)
    numero(ax, 1090, 470, 9, colore=DOPO)
    numero(ax, 480, 205, 10, colore=DOPO)
    numero(ax, 205, 680, 11, colore=DOPO)

    h = legenda(ax, 1450, [
        (1, "Risveglio nel corridoio", "0-2 min"),
        (2, "Spogliatoi: lo zaino-pompa", "2-6 min"),
        (3, "La statua (S1)", "6-7 min"),
        (4, "Area bimbi: il secchio gigante", "7-15 min"),
        (5, "Piscina a onde vuota", "15-21 min"),
        (6, "Sala pompe: lei si sveglia", "21-28 min"),
        (7, "Ritorno al buio: piedistallo vuoto (V1)", "28-31 min"),
        (8, "Lei sbuca dal bordo (SB2)", "31-33 min"),
        (9, "Torre degli scivoli", "33-38 min"),
        (10, "Inseguimento negli scivoli (I1)", "38-41 min"),
        (11, "Fine: lei al bordo della vasca (SB1)", "41-42 min"),
    ])
    salva(fig, ax, h + 20, cartella / "mappa_capitolo1.png")


# ---- proposte da approvare: Polaroid e bambini --------------------------
# Posizioni indicative. P1 e' la Polaroid piu' innocente, P10 la piu' inquietante.
POLAROID = {
    1: (660, 1290),   # tappa 1, ponte inferiore, vicino al risveglio
    2: (700, 1090),   # tappa 2, spogliatoi, in un armadietto
    3: (770, 1090),   # tappa 2, stanzino dei bagnini
    4: (225, 305),    # tappa 4, area bimbi, sotto la tettoia accanto al secchio
    5: (600, 730),    # tappa 5, fondo della piscina, sotto la pozza
    6: (745, 829),    # tappa 5, camera delle onde
    7: (1000, 1092),  # tappa 6, sala pompe, vicino al monitor
    8: (790, 1290),   # tappa 7, ponte inferiore, dove ti eri svegliato
    9: (330, 525),    # tappa 8, area bimbi, accanto alle vasche basse
    10: (1090, 475),  # tappa 9, in cima alla torre (sparita negli spogliatoi, B4)
}
BAMBINI = {
    1: (350, 1085),   # tappa 2, impronte bagnate verso la grata
    2: (130, 520),    # tappa 4, risatine dagli scarichi
    3: (1120, 1092),  # tappa 6, una sagoma sul monitor
    4: (350, 1160),   # tappa 7, la Polaroid che sparisce
    5: (160, 925),    # tappa 9, sagome sulla balconata
}


def mappa_proposte(cartella):
    fig, ax = nuova_figura(1900)
    titolo(ax, "Capitolo 1 · Polaroid e bambini",
           "Proposte da approvare · posizioni indicative")
    pianta(ax)
    statua(ax, *STATUA_XY)

    z = 10
    for punti in PRIMA_DELLE_POMPE + DOPO_LE_POMPE:
        percorso(ax, punti, TENUE, spessore=7, z=z, testa=0.6)
        z += 1
    percorso(ax, SCIVOLO, TENUE, tratteggiato=True, spessore=7, z=z, testa=0.6)

    for n, (x, y) in POLAROID.items():
        polaroid(ax, x, y, n)
    for n, (x, y) in BAMBINI.items():
        bambini(ax, x, y, n)

    y = 1450
    ax.plot([30, 1170], [y - 45, y - 45], color="#CFC8BA", lw=px(3), zorder=1)
    polaroid(ax, 85, y, 1, z=50)
    testo(ax, 150, y, "Polaroid: 1 la più innocente, 10 la più inquietante",
          size=30, bold=False, ha="left")
    y += 72
    bambini(ax, 85, y, 1, z=50)
    testo(ax, 150, y, "bambini visti di sfuggita (5 momenti)", size=30, bold=False,
          ha="left")
    y += 66
    percorso(ax, [(40, y), (130, y)], TENUE, spessore=7, z=50, testa=0.6)
    testo(ax, 150, y, "percorso A, per orientarsi", size=30, bold=False, ha="left")
    salva(fig, ax, y + 50, cartella / "mappa_capitolo1_proposte.png")


if __name__ == "__main__":
    cartella = FsPath(sys.argv[1]) if len(sys.argv) > 1 else FsPath(__file__).parent
    cartella.mkdir(parents=True, exist_ok=True)
    mappa_capitolo1(cartella)
    mappa_proposte(cartella)
