"""I bersagli delle paratie delle condotte come il tiro a segno delle giostre per bambini (proposta A di grafica-2, scelta
dall'utente per la 0.3.21): il pannello d'acciaio di 1,9 m è dipinto di smalto chiaro, coi cerchi concentrici e al
centro un disegno grande (circa 1 m, la sfera di colpo) a pastelli a cera sbiaditi.
- giusta: un sole sorridente giallo, cerchi rosa e verde chiaro (l'anello di led verdi e la lampada verde restano);
- sbagliata: lo stesso tiro a segno spento e graffiato, un pesce con gli occhi a croce, colori quasi grigi, vernice
  scrostata fino all'acciaio arrugginito;
- i montanti delle paratie ridipinti a strisce caramella, giallo e bianco sporco.
I disegni sono fatti col pastello degli scarabocchi (assets_src/scarabocchi/pastello.py), niente immagini fatte con l'IA.
Solo disegni: niente lettere né numeri; niente cerchi gialli, rossi e blu in fila (i colori dell'enigma della piscina).
Scrive in assets_src/inseguimento/bersagli/: bersaglio_giusto_col.png e bersaglio_sbagliato_col.png (1024x1024, tutta la
faccia del pannello: u da sinistra a destra di chi guarda la paratia, v dal basso in alto) e caramella_col.png (512x512,
ripetibile). Le usa tools/blender/inseguimento_proposte.py (materiali bersaglio_giusto, bersaglio_sbagliato, caramella).
Uso: /home/user/tools/blender-venv/bin/python assets_src/inseguimento/bersagli/bersagli.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '..', '..', 'scarabocchi'))
from pastello import Pastello, rumore  # noqa: E402

LATO = 1024
# il pannello: 1,94 m di largo (da guida a guida) e 1,9 di alto; il centro della sfera di colpo è 22% dell'altezza sopra
# il centro (inseguimento_proposte.paratia: t = pann + alto * 0.22)
ALTO_M = 1.9
MM = ALTO_M * 1000 / LATO                       # millimetri per pixel (1,86)
CX = LATO / 2
CY = LATO * (0.5 - 0.22)                         # in pixel dall'alto
PX = LATO / ALTO_M                               # pixel per metro
# l'anello di led verdi sta fra 0,47 e 0,55 m dal centro: il disegno resta dentro, i cerchi fuori
R_DISEGNO = 0.45 * PX


def smalto(seme, tinta, scrostato, ruggine=0.5):
    """Lo smalto del pannello: [tinta] (RGB 0-255) con lo sporco, colature verso il basso e, dove è scrostato, l'acciaio
    sotto con la ruggine. [scrostato] 0-1: quanto è venuto via."""
    h = w = LATO
    t = np.array(tinta, np.float32) / 255.0
    macchie = rumore((h, w), seme, 70)
    fine = rumore((h, w), seme + 1, 6)
    colate = rumore((h, w // 10), seme + 2, 25)
    colate = np.asarray(Image.fromarray((colate * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255.0
    giu = np.linspace(0.3, 1.0, h, dtype=np.float32)[:, None]
    sporco = np.clip(macchie * 0.5 + colate * 0.6 * giu + fine * 0.25 - 0.45, 0, 1)
    col = t * (1.0 - 0.35 * sporco[..., None]) + np.array([0.28, 0.25, 0.2], np.float32) * 0.35 * sporco[..., None]
    # acciaio e ruggine sotto lo smalto
    acciaio = np.array([0.24, 0.25, 0.26], np.float32)
    rugg = np.array([0.42, 0.2, 0.09], np.float32)
    r = rumore((h, w), seme + 3, 14)
    sotto = acciaio * (1 - ruggine * r[..., None]) + rugg * ruggine * r[..., None]
    # scrostature: macchie di grana media coi bordi netti, di più vicino ai bordi del pannello e in basso (l'acqua)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    bordo = np.clip(1.0 - np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / (0.16 * w), 0, 1)
    s = rumore((h, w), seme + 4, 22) * 0.55 + rumore((h, w), seme + 5, 5) * 0.45
    via = (s + bordo * 0.35 + (yy / h) * 0.15) > (1.12 - scrostato * 0.75)
    via = np.asarray(Image.fromarray((via * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3)), np.float32) / 255.0
    col = col * (1 - via[..., None]) + sotto * via[..., None]
    return np.clip(col, 0, 1), via


def sopra(base, strato):
    """Il livello di cera RGBA sopra lo smalto (cera opaca: copre)."""
    a = np.asarray(strato, np.float32) / 255.0
    return base * (1 - a[..., 3:4]) + a[..., :3] * a[..., 3:4]


def anelli(p, colori, r0, passo, larg_mm=46.0, quanti=6):
    """I cerchi concentrici del tiro a segno: bande di cera fatte di tondi ripassati, una sì e una no colorata."""
    for k in range(quanti):
        c = colori[k % len(colori)]
        if c is None:
            continue
        r_in = r0 + k * passo
        r = r_in + larg_mm / MM * 0.5
        while r < r_in + passo - larg_mm / MM * 0.35:
            p.ovale(CX, CY, r, r, c, larg_mm=larg_mm, giri=1.08, trem=1.6)
            r += larg_mm / MM * 0.55


def sole_grande(p, r):
    """Il sole che riempie la sfera di colpo: il disco pieno (due passate di giallo), il bordo arancio e i raggi fino
    a [constant R_DISEGNO]."""
    disco = [(CX + r * math.cos(a), CY + r * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 28, endpoint=False)]
    p.riempi(disco, 'giallo', larg_mm=34, passo_mm=22)
    p.riempi(disco, 'giallo', larg_mm=30, passo_mm=26, ang=-0.7)
    p.ovale(CX, CY, r, r, 'arancio', larg_mm=30)
    for i in range(12):
        a = 2 * math.pi * i / 12 + p.rng.normal(0, 0.06)
        p.linea((CX + r * 1.18 * math.cos(a), CY + r * 1.18 * math.sin(a)),
                (CX + R_DISEGNO * math.cos(a), CY + R_DISEGNO * math.sin(a)), 'giallo', larg_mm=34)


def faccia_sole(p, r):
    """Gli occhi e il sorriso del sole (il corpo lo fa motivi.sole)."""
    for s in (-1, 1):
        p.ovale(CX + s * r * 0.36, CY - r * 0.18, r * 0.09, r * 0.12, 'nero', larg_mm=26, giri=1.6)
        p.ovale(CX + s * r * 0.58, CY + r * 0.2, r * 0.11, r * 0.08, 'rosa', larg_mm=22, giri=1.4)
    p.tratto([(CX - r * 0.42 + r * 0.84 * t, CY + r * 0.22 + r * 0.24 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 14)],
             'rosso', larg_mm=30)


def pesce_morto(p, r, colore, colore_occhi):
    """Il pesce con gli occhi a croce, steso di traverso, la bocca aperta."""
    lungo, h = r * 1.7, r * 0.78
    corpo = [(CX - lungo * 0.5 + lungo * t, CY + h * 0.5 * math.sin(math.pi * t) * s)
             for s in (-1, 1) for t in (np.linspace(0, 1, 13) if s < 0 else np.linspace(1, 0, 13))]
    p.riempi(corpo, colore, larg_mm=30, passo_mm=26)
    p.tratto(corpo + [corpo[0]], colore_occhi, larg_mm=26)
    coda = CX - lungo * 0.5
    p.tratto([(coda, CY), (coda - lungo * 0.22, CY - h * 0.42), (coda - lungo * 0.22, CY + h * 0.42), (coda, CY)], colore_occhi, larg_mm=26)
    # l'occhio a croce e la bocca storta
    ox, oy, d = CX + lungo * 0.27, CY - h * 0.1, r * 0.17
    p.linea((ox - d, oy - d), (ox + d, oy + d), colore_occhi, larg_mm=26)
    p.linea((ox - d, oy + d), (ox + d, oy - d), colore_occhi, larg_mm=26)
    p.tratto([(CX + lungo * 0.5, CY + h * 0.05), (CX + lungo * 0.42, CY + h * 0.14), (CX + lungo * 0.5, CY + h * 0.2)], colore_occhi, larg_mm=24)
    # le lische sulla pancia
    for k in range(2):
        x = CX - lungo * 0.12 + k * lungo * 0.13
        p.linea((x, CY - h * 0.28), (x - lungo * 0.04, CY + h * 0.28), colore_occhi, larg_mm=16, curva=0.05)


def graffi(base, seme, quanti, colore):
    """Graffi sottili e dritti, a mazzi, che scoprono il chiaro sotto (la sbagliata è stata presa a calci e raschiata)."""
    rng = np.random.default_rng(seme)
    im = Image.new('L', (LATO, LATO), 0)
    d = ImageDraw.Draw(im)
    for _ in range(quanti):
        x, y = rng.uniform(0, LATO), rng.uniform(0, LATO)
        a = rng.uniform(-0.9, 0.9) + (math.pi / 2 if rng.random() < 0.3 else 0)
        for k in range(rng.integers(2, 6)):
            l = rng.uniform(40, 220)
            o = rng.normal(0, 6, 2)
            d.line([(x + o[0], y + o[1]), (x + o[0] + l * math.cos(a), y + o[1] + l * math.sin(a))], fill=int(rng.uniform(120, 230)), width=1)
    g = np.asarray(im.filter(ImageFilter.GaussianBlur(0.6)), np.float32)[..., None] / 255.0
    return base * (1 - g) + np.array(colore, np.float32) / 255.0 * g


def giusta():
    base, _ = smalto(11, (226, 218, 196), scrostato=0.14)
    p = Pastello(LATO, LATO, 101, mm=MM)
    anelli(p, ['rosa', None, 'verde_chiaro', None, 'rosa', None], 0.57 * PX, 0.13 * PX)
    sole_grande(p, 0.27 * PX)
    faccia_sole(p, 0.27 * PX)
    base = sopra(base, p.finisci(bagnato=0.3, sbiadito=0.12))
    return base


def sbagliata():
    base, via = smalto(23, (172, 170, 162), scrostato=0.4, ruggine=0.75)
    p = Pastello(LATO, LATO, 202, mm=MM)
    # gli stessi cerchi, quasi grigi (ex rosa ed ex verde)
    anelli(p, [(150, 132, 132), None, (128, 138, 124), None, (150, 132, 132), None], 0.57 * PX, 0.13 * PX)
    pesce_morto(p, R_DISEGNO, (112, 120, 128), (52, 50, 56))
    cera = np.asarray(p.finisci(bagnato=0.55, sbiadito=0.2), np.float32)
    # la cera non tiene dove lo smalto è venuto via
    cera[..., 3] *= 1.0 - np.clip(via * 0.6, 0, 1)
    base = sopra(base, Image.fromarray(cera.astype(np.uint8), 'RGBA'))
    base = graffi(base, 7, 70, (200, 196, 186))
    # tutto più spento: verso il grigio
    grigio = base.mean(axis=2, keepdims=True)
    return base * 0.55 + grigio * 0.45


def caramella():
    """Strisce diagonali a 45 gradi, giallo e bianco sporco, ripetibili (periodo 128 px lungo x+y)."""
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    f = ((xx + yy) % 128) / 128.0
    # bordo un po' irregolare (pennellata), ma ripetibile: il rumore si ripete ogni 512
    rng = np.random.default_rng(5)
    onda = 0.03 * np.sin((xx - yy) / n * 2 * math.pi * 3 + rng.uniform(0, 6)) + 0.015 * np.sin((xx - yy) / n * 2 * math.pi * 11)
    giallo = ((f + onda) % 1.0) < 0.5
    g = np.array([0.93, 0.72, 0.12], np.float32)
    b = np.array([0.86, 0.83, 0.75], np.float32)
    col = np.where(giallo[..., None], g, b)
    # sporco ripetibile: rumore su una griglia che si chiude
    k = 16
    r = rng.random((k, k)).astype(np.float32)
    r = np.tile(r, (3, 3))
    big = np.asarray(Image.fromarray((r * 255).astype(np.uint8)).resize((n * 3, n * 3), Image.BICUBIC), np.float32)[n:2 * n, n:2 * n] / 255.0
    col = col * (0.82 + 0.18 * big[..., None]) - np.array([0.06, 0.06, 0.05]) * (big[..., None] > 0.7)
    return np.clip(col, 0, 1)


def salva(arr, nome):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), 'RGB').save(os.path.join(QUI, nome), optimize=True)
    print('scritto', nome)


if __name__ == '__main__':
    salva(giusta(), 'bersaglio_giusto_col.png')
    salva(sbagliata(), 'bersaglio_sbagliato_col.png')
    salva(caramella(), 'caramella_col.png')
