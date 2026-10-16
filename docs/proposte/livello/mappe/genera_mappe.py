#!/usr/bin/env python3
"""Mappe schematiche dall'alto del capitolo 1: percorsi A, B e C.

Uso:
    python genera_mappe.py            # scrive percorso_A.png, _B, _C accanto allo script
    python genera_mappe.py <cartella>

Serve matplotlib. Le coordinate sono in pixel dell'immagine
(1200 di larghezza, y verso il basso). Sono proposte: si cambiano qui
e si rigenera.
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


def percorso(ax, punti, colore, tratteggiato=False, spessore=12, punta=True,
             doppia=False, z=10):
    punti = [tuple(p) for p in punti]
    linea = list(punti)
    if punta:
        linea[-1] = _accorcia(linea[-2], linea[-1], 30)
    if doppia:
        linea[0] = _accorcia(linea[1], linea[0], 30)
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
        _punta(ax, punti[-2], punti[-1], colore, z + 0.2)
    if doppia:
        _punta(ax, punti[1], punti[0], colore, z + 0.2)


def numero(ax, x, y, n, colore=INCHIOSTRO, r=28, z=40):
    ax.add_patch(Circle((x, y), r, facecolor=colore, edgecolor="white",
                        lw=px(4), zorder=z))
    testo(ax, x, y + 1, str(n), size=(33 if n < 10 else 28) * r / 28,
          color="white", z=z + 1)


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


# ---- pianta comune ------------------------------------------------------
STATUA_XY = (600, 905)
SCIVOLO = [(1095, 300), (1095, 205), (55, 205), (55, 722), (140, 722)]


def pianta(ax, botola=False):
    # sala grande sotto la cupola
    stanza(ax, 20, 165, 1180, 1010, SALA, r=36, z=1)
    testo(ax, 42, 988, "sala grande (sotto la cupola)", size=24, bold=False,
          color=GRIGIO, ha="left", z=3)

    # area bimbi
    stanza(ax, 90, 245, 400, 560, BIMBI)
    testo(ax, 245, 425, "AREA BIMBI", size=40, alone=BIMBI)
    testo(ax, 245, 470, "secchio gigante", size=28, bold=False, alone=BIMBI)
    secchio(ax, 150, 300)

    # vasca d'arrivo degli scivoli
    stanza(ax, 90, 640, 400, 860, VASCA)
    testo(ax, 255, 765, "VASCA", size=34, alone=VASCA)
    testo(ax, 255, 805, "D'ARRIVO", size=34, alone=VASCA)

    # piscina a onde (vuota): spiaggia in alto, fondo in basso
    x0, x1, y0, y1 = 450, 790, 245, 800
    stanza(ax, x0, y0, x1, y1, PISCINA[1])
    ax.add_patch(Rectangle((x0 + 3, y0 + 3), x1 - x0 - 6, 120, facecolor=PISCINA[0],
                           edgecolor="none", zorder=2.1))
    ax.add_patch(Rectangle((x0 + 3, y1 - 175), x1 - x0 - 6, 172, facecolor=PISCINA[2],
                           edgecolor="none", zorder=2.1))
    stanza(ax, x0, y0, x1, y1, "none", z=2.2)
    testo(ax, 620, 268, "spiaggia", size=24, bold=False, color=GRIGIO,
          style="italic", z=3)
    testo(ax, 500, 778, "fondo", size=24, bold=False, color=GRIGIO,
          style="italic", ha="left", z=3)
    testo(ax, 625, 470, "PISCINA", size=40, alone=PISCINA[1])
    testo(ax, 625, 515, "A ONDE", size=40, alone=PISCINA[1])
    testo(ax, 625, 560, "(vuota)", size=30, bold=False, alone=PISCINA[1])

    # torre degli scivoli
    stanza(ax, 840, 245, 1150, 520, TORRE)
    testo(ax, 985, 365, "TORRE", size=40, alone=TORRE)
    testo(ax, 985, 410, "SCIVOLI", size=40, alone=TORRE)

    # scivoli: dalla torre, lungo il bordo della sala, fino alla vasca d'arrivo
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

    if botola:
        ax.add_patch(Rectangle((880, 935), 50, 50, facecolor="#8A8F96",
                               edgecolor=BORDO, lw=px(3), hatch="++", zorder=4))
        testo(ax, 945, 960, "botola", size=24, bold=False, color=GRIGIO,
              ha="left", z=3)


def legenda(ax, y0, tappe, nota=None):
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
    y += 50
    ax.plot([30, 1170], [y, y], color="#CFC8BA", lw=px(3), zorder=1)
    y += 48
    for n, nome, minuti in tappe:
        numero(ax, 62, y, n, r=24)
        testo(ax, 104, y, nome, size=32, bold=False, ha="left")
        testo(ax, 1165, y, minuti, size=32, ha="right")
        y += 54
    if nota:
        y += 6
        testo(ax, 40, y, nota, size=28, bold=False, color=GRIGIO, ha="left",
              style="italic")
        y += 40
    return y


def titolo(ax, t, sotto):
    testo(ax, 40, 60, t, size=58, ha="left")
    testo(ax, 40, 118, sotto, size=32, bold=False, color=GRIGIO, ha="left")


def salva(fig, ax, h_usata, nome, cartella):
    ax.set_ylim(h_usata, 0)
    fig.set_size_inches(W / DPI, h_usata / DPI)
    out = cartella / nome
    fig.savefig(out, dpi=DPI, facecolor=SFONDO)
    plt.close(fig)
    # PNG piu' leggero: palette da 128 colori, senza retinatura
    from PIL import Image
    with Image.open(out) as im:
        ridotta = im.convert("RGB").quantize(colors=128, method=Image.Quantize.MEDIANCUT,
                                             dither=Image.Dither.NONE)
    ridotta.save(out, optimize=True)
    print("scritta", out)


# ---- percorsi -----------------------------------------------------------
# Tratti comuni a tutti e tre i percorsi
ARRIVO = [(770, 1268), (405, 1268), (405, 1088), (580, 1088), (580, 940)]
RITORNO = [(905, 1300), (435, 1300), (435, 1120), (640, 1120), (640, 1050),
           (628, 940)]
INSEGUIMENTO = SCIVOLO


def percorso_a(cartella):
    fig, ax = nuova_figura(2300)
    titolo(ax, "Percorso A · Lineare", "Proposta · circa 40 minuti · una zona dopo l'altra")
    pianta(ax)
    statua(ax, *STATUA_XY)
    z = 10
    for punti in (
        ARRIVO,
        [(572, 905), (425, 905), (425, 600), (245, 600), (245, 568)],  # -> area bimbi
        [(400, 290), (478, 290), (478, 740)],  # -> piscina, giu' fino al fondo
        [(478, 740), (745, 740), (745, 985), (930, 985), (930, 1075)],  # -> sala pompe
    ):
        percorso(ax, punti, PRIMA, z=z)
        z += 1
    for punti in (
        RITORNO,
        [(628, 905), (1000, 905), (1000, 528)],  # -> torre
    ):
        percorso(ax, punti, DOPO, z=z)
        z += 1
    percorso(ax, INSEGUIMENTO, DOPO, tratteggiato=True, z=z)

    numero(ax, 800, 1268, 1)
    numero(ax, 345, 1120, 2)
    numero(ax, 540, 965, 3)
    numero(ax, 330, 330, 4)
    numero(ax, 700, 640, 5)
    numero(ax, 1015, 1290, 6)
    numero(ax, 680, 965, 7, colore=DOPO)
    numero(ax, 1090, 470, 8, colore=DOPO)
    numero(ax, 480, 205, 9, colore=DOPO)
    numero(ax, 205, 680, 10, colore=DOPO)

    h = legenda(ax, 1450, [
        (1, "Risveglio sul ponte inferiore", "0-2 min"),
        (2, "Spogliatoi: lo zaino-pompa", "2-6 min"),
        (3, "La statua", "6-7 min"),
        (4, "Area bimbi: il secchio gigante", "7-15 min"),
        (5, "Piscina a onde vuota", "15-21 min"),
        (6, "Sala pompe: lei si sveglia", "21-28 min"),
        (7, "Ritorno al buio: piedistallo vuoto", "28-31 min"),
        (8, "Torre degli scivoli", "31-36 min"),
        (9, "Inseguimento negli scivoli", "36-39 min"),
        (10, "Fine del capitolo", "39-40 min"),
    ])
    salva(fig, ax, h + 20, "percorso_A.png", cartella)


def percorso_b(cartella):
    fig, ax = nuova_figura(2400)
    titolo(ax, "Percorso B · A raggiera", "Proposta · circa 42 minuti · tutto passa dalla statua")
    pianta(ax, botola=True)
    statua(ax, *STATUA_XY)
    z = 10
    percorso(ax, ARRIVO, PRIMA, z=z)
    z += 1
    for punti in (
        [(572, 905), (425, 905), (425, 600), (245, 600), (245, 568)],  # area bimbi
        [(600, 877), (600, 700)],  # piscina a onde
        [(628, 895), (990, 895), (990, 528)],  # torre, piani bassi
    ):
        percorso(ax, punti, PRIMA, doppia=True, z=z)
        z += 1
    percorso(ax, [(625, 925), (650, 960), (905, 960), (905, 1075)], PRIMA, z=z)  # botola
    z += 1
    percorso(ax, RITORNO, DOPO, z=z)
    z += 1
    percorso(ax, [(628, 912), (1040, 912), (1040, 528)], DOPO, z=z)  # torre, in cima
    z += 1
    percorso(ax, INSEGUIMENTO, DOPO, tratteggiato=True, z=z)

    numero(ax, 800, 1268, 1)
    numero(ax, 345, 1120, 2)
    numero(ax, 540, 965, 3)
    numero(ax, 330, 330, 4)
    numero(ax, 680, 640, 5)
    numero(ax, 900, 465, 6)
    numero(ax, 1015, 1290, 7)
    numero(ax, 700, 1000, 8, colore=DOPO)
    numero(ax, 1100, 465, 9, colore=DOPO)
    numero(ax, 480, 205, 10, colore=DOPO)
    numero(ax, 205, 680, 11, colore=DOPO)

    h = legenda(ax, 1450, [
        (1, "Risveglio sul ponte inferiore", "0-2 min"),
        (2, "Spogliatoi: lo zaino-pompa", "2-5 min"),
        (3, "La statua, all'incrocio dei rami", "5-6 min"),
        (4, "Area bimbi: valvola 1", "6-13 min"),
        (5, "Piscina a onde: valvola 2", "13-19 min"),
        (6, "Torre, piani bassi: valvola 3", "19-25 min"),
        (7, "Sala pompe: lei si sveglia", "25-31 min"),
        (8, "Ritorno al buio: piedistallo vuoto", "31-34 min"),
        (9, "Torre, in cima", "34-37 min"),
        (10, "Inseguimento negli scivoli", "37-41 min"),
        (11, "Fine del capitolo", "41-42 min"),
    ], nota="4, 5 e 6 in qualsiasi ordine: si torna sempre davanti alla statua.")
    salva(fig, ax, h + 20, "percorso_B.png", cartella)


def percorso_c(cartella):
    fig, ax = nuova_figura(2300)
    titolo(ax, "Percorso C · Sveglia a metà", "Proposta · circa 39 minuti · metà calma, metà con lei")
    pianta(ax)
    statua(ax, *STATUA_XY)
    z = 10
    for punti in (
        ARRIVO,
        [(600, 877), (600, 740)],  # -> piscina, fondo
        [(600, 740), (745, 740), (745, 985), (930, 985), (930, 1075)],  # -> sala pompe
    ):
        percorso(ax, punti, PRIMA, z=z)
        z += 1
    for punti in (
        RITORNO,
        [(572, 905), (425, 905), (425, 600), (245, 600), (245, 568)],  # -> area bimbi
        [(400, 330), (850, 330)],  # attraverso la piscina vuota -> torre
    ):
        percorso(ax, punti, DOPO, z=z)
        z += 1
    percorso(ax, INSEGUIMENTO, DOPO, tratteggiato=True, z=z)

    numero(ax, 800, 1268, 1)
    numero(ax, 345, 1120, 2)
    numero(ax, 540, 965, 3)
    numero(ax, 680, 640, 4)
    numero(ax, 1015, 1290, 5)
    numero(ax, 680, 965, 6, colore=DOPO)
    numero(ax, 330, 360, 7, colore=DOPO)
    numero(ax, 1090, 470, 8, colore=DOPO)
    numero(ax, 480, 205, 9, colore=DOPO)
    numero(ax, 205, 680, 10, colore=DOPO)

    h = legenda(ax, 1450, [
        (1, "Risveglio sul ponte inferiore", "0-2 min"),
        (2, "Spogliatoi: lo zaino-pompa", "2-5 min"),
        (3, "La statua", "5-6 min"),
        (4, "Piscina a onde vuota", "6-12 min"),
        (5, "Sala pompe: lei si sveglia", "12-18 min"),
        (6, "Ritorno al buio: piedistallo vuoto", "18-21 min"),
        (7, "Area bimbi: lei ti osserva", "21-30 min"),
        (8, "Torre degli scivoli", "30-35 min"),
        (9, "Inseguimento negli scivoli", "35-38 min"),
        (10, "Fine del capitolo", "38-39 min"),
    ])
    salva(fig, ax, h + 20, "percorso_C.png", cartella)


if __name__ == "__main__":
    cartella = FsPath(sys.argv[1]) if len(sys.argv) > 1 else FsPath(__file__).parent
    cartella.mkdir(parents=True, exist_ok=True)
    percorso_a(cartella)
    percorso_b(cartella)
    percorso_c(cartella)
