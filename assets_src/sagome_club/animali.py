"""Gli animali del mare delle sagome del club dei bambini della nave (scelta A dell'utente del 6 novembre, cartonati
nelle condotte dell'inseguimento), disegnati col pastello del gioco (assets_src/scarabocchi/pastello.py): come li
disegnano i bambini, forme semplici riempite col va e vieni, il contorno ripassato, gli occhi tondi e il sorriso.
Tre portano un disegno di Jilly (scelta A, "Jilly fra i disegni"): sulla balena vecchia la mascotte sorridente coi
pesci, sul pesce palla più recente lei alta coi tentacoli sopra i bambini piccoli, sul pesce nuovo solo il suo occhio.
Solo disegni: niente lettere, numeri o frecce; niente cerchi gialli, rossi e blu in fila (i colori dell'enigma della
piscina a onde). Ogni funzione disegna su un Pastello (coordinate in pixel, y in giù) e aggiunge a p.sagome i poligoni
pieni che danno la forma da ritagliare.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scarabocchi'))
from motivi import omino, onde, medusa  # noqa: E402
from disegni import pesce as pesciolino, jilly_sorridente, manina  # noqa: E402


def ell(cx, cy, rx, ry, n=28, a0=0.0, a1=2 * math.pi):
    return [(cx + rx * math.cos(a0 + (a1 - a0) * i / (n - 1)), cy + ry * math.sin(a0 + (a1 - a0) * i / (n - 1))) for i in range(n)]


def forma(p, pts, colore, bordo='nero', larg=15.0, passo=10.0, pieno=True):
    """Una forma riempita col va e vieni e ripassata sul bordo; entra nella sagoma da ritagliare."""
    p.sagome.append(pts)
    if pieno:
        p.riempi(pts, colore, passo_mm=passo)
    p.tratto(pts + [pts[0]], bordo, larg_mm=larg)


def occhio(p, cx, cy, r):
    p.ovale(cx, cy, r, r, 'nero', larg_mm=12)
    p.riempi(ell(cx, cy, r * 0.75, r * 0.75, 14), 'bianco', passo_mm=6)
    p.ovale(cx + r * 0.15, cy + r * 0.1, r * 0.38, r * 0.38, 'nero', larg_mm=16, giri=1.0)


def sorriso(p, cx, cy, largo, colore='nero', su=0.35):
    p.tratto([(cx - largo / 2 + largo * t, cy + largo * su * math.sin(math.pi * t)) for t in [i / 10 for i in range(11)]], colore, larg_mm=12)


def firma(p, x, y, r, colore):
    """La manina al posto della firma (niente nomi): il contorno della mano del bambino, in un colore suo."""
    manina(p, x, y, r, colore, ang=p.rng.normal(0, 0.2))


# ------------------------------------------------------------------ gli animali (W, H: il foglio in pixel)
def balena(p, W, H):
    cx, cy = W * 0.46, H * 0.58
    corpo = ell(cx, cy, W * 0.36, H * 0.3, 34, math.pi * 0.95, math.pi * 2.05) + [(cx + W * 0.3, cy + H * 0.18), (cx - W * 0.3, cy + H * 0.22)]
    forma(p, corpo, 'azzurro', 'blu', passo=13)
    coda = [(cx + W * 0.33, cy - H * 0.02), (cx + W * 0.46, cy - H * 0.3), (cx + W * 0.43, cy - H * 0.05), (cx + W * 0.49, cy + H * 0.08),
            (cx + W * 0.34, cy + H * 0.08)]
    forma(p, coda, 'azzurro', 'blu', passo=11)
    # lo spruzzo
    for k in (-1, 0, 1):
        p.linea((cx - W * 0.12, cy - H * 0.3), (cx - W * 0.12 + k * W * 0.07, cy - H * 0.5), 'azzurro', curva=0.15 * k)
    p.sagome.append(ell(cx - W * 0.12, cy - H * 0.42, W * 0.08, H * 0.1, 12))
    occhio(p, cx - W * 0.26, cy - H * 0.05, H * 0.035)
    sorriso(p, cx - W * 0.25, cy + H * 0.08, W * 0.12, 'blu', su=0.2)
    # J1: sul fianco i bambini hanno disegnato la mascotte del parco coi pesci (i disegni vecchi)
    jilly_sorridente(p, cx + W * 0.02, cy - H * 0.08, H * 0.1)
    for i, c in enumerate(['arancio', 'verde', 'giallo']):
        pesciolino(p, cx + W * (0.12 + 0.07 * i), cy + H * (0.02 + 0.07 * (i % 2)), W * 0.05, c, verso=-1)
    firma(p, cx + W * 0.18, cy + H * 0.2, H * 0.05, 'rosso')


def stella(p, W, H):
    cx, cy = W * 0.5, H * 0.52
    R, r = W * 0.45, W * 0.2
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = R if i % 2 == 0 else r
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    # punte arrotondate: ogni punta diventa un piccolo arco
    tonde = []
    for i, q in enumerate(pts):
        if i % 2 == 0:
            a = math.atan2(q[1] - cy, q[0] - cx)
            tonde += ell(cx + (R - W * 0.04) * math.cos(a), cy + (R - W * 0.04) * math.sin(a), W * 0.045, W * 0.045, 7, a - 1.3, a + 1.3)
        else:
            tonde.append(q)
    forma(p, tonde, 'arancio', 'rosso', passo=11)
    for k in range(9):
        a = p.rng.uniform(0, 2 * math.pi)
        d = p.rng.uniform(0.1, 0.35) * W
        p.ovale(cx + d * math.cos(a), cy + d * math.sin(a), W * 0.015, W * 0.015, 'giallo', larg_mm=10, giri=1.0)
    occhio(p, cx - W * 0.06, cy - H * 0.04, W * 0.035)
    occhio(p, cx + W * 0.06, cy - H * 0.04, W * 0.035)
    sorriso(p, cx, cy + H * 0.06, W * 0.12)
    firma(p, cx + W * 0.2, cy + H * 0.25, W * 0.05, 'viola')


def tartaruga(p, W, H):
    cx, cy = W * 0.45, H * 0.6
    guscio = ell(cx, cy, W * 0.32, H * 0.4, 30, math.pi, 2 * math.pi) + [(cx + W * 0.32, cy + H * 0.04), (cx - W * 0.32, cy + H * 0.04)]
    for s in (-1, 1):   # le zampe
        for dx in (-0.2, 0.2):
            forma(p, ell(cx + W * dx + s * 0.0, cy + H * 0.14, W * 0.06, H * 0.12, 14), 'verde_chiaro', 'verde', passo=9)
    forma(p, ell(cx + W * 0.4, cy - H * 0.06, W * 0.1, H * 0.12, 18), 'verde_chiaro', 'verde', passo=9)   # la testa
    forma(p, [(cx - W * 0.31, cy), (cx - W * 0.42, cy + H * 0.06), (cx - W * 0.3, cy + H * 0.05)], 'verde_chiaro', 'verde')   # la coda
    forma(p, guscio, 'verde', 'marrone', passo=12)
    # le piastre del guscio
    for i in range(3):
        x = cx + W * (-0.16 + 0.16 * i)
        p.ovale(x, cy - H * 0.17, W * 0.065, H * 0.08, 'marrone', larg_mm=11, giri=1.05)
    occhio(p, cx + W * 0.43, cy - H * 0.1, H * 0.035)
    sorriso(p, cx + W * 0.42, cy - H * 0.02, W * 0.06)
    firma(p, cx - W * 0.2, cy + H * 0.26, H * 0.06, 'blu')


def granchio(p, W, H):
    cx, cy = W * 0.5, H * 0.6
    for s in (-1, 1):
        for k in range(3):   # le zampe
            p.linea((cx + s * W * 0.18, cy + H * (0.02 + 0.07 * k)), (cx + s * W * 0.4, cy + H * (0.12 + 0.12 * k)), 'rosso', larg_mm=16, curva=0.1 * s)
            p.sagome.append(ell(cx + s * W * 0.3, cy + H * (0.08 + 0.1 * k), W * 0.1, H * 0.04, 10))
        # le chele, sulle braccia alzate
        p.linea((cx + s * W * 0.2, cy - H * 0.12), (cx + s * W * 0.32, cy - H * 0.38), 'rosso', larg_mm=18)
        chela = ell(cx + s * W * 0.34, cy - H * 0.5, W * 0.1, H * 0.14, 18, math.pi * 0.6 if s < 0 else -math.pi * 0.4, math.pi * 2.3 if s < 0 else math.pi * 1.3)
        forma(p, chela, 'rosso', 'rosso', passo=9)
        p.sagome.append(ell(cx + s * W * 0.27, cy - H * 0.26, W * 0.05, H * 0.12, 10))
    forma(p, ell(cx, cy, W * 0.24, H * 0.2, 30), 'rosso', 'marrone', passo=11)
    for s in (-1, 1):   # gli occhi sulle antenne
        p.linea((cx + s * W * 0.07, cy - H * 0.16), (cx + s * W * 0.09, cy - H * 0.3), 'rosso', larg_mm=12)
        occhio(p, cx + s * W * 0.09, cy - H * 0.33, H * 0.045)
        p.sagome.append(ell(cx + s * W * 0.09, cy - H * 0.3, W * 0.04, H * 0.07, 10))
    sorriso(p, cx, cy + H * 0.02, W * 0.14)
    firma(p, cx - W * 0.12, cy + H * 0.1, H * 0.06, 'giallo')


def pesce_palla(p, W, H):
    cx, cy = W * 0.5, H * 0.52
    R = W * 0.36
    corpo = ell(cx, cy, R, R * 0.95, 36)
    for i in range(16):   # gli aculei
        a = 2 * math.pi * i / 16 + 0.1
        p.linea((cx + R * 0.95 * math.cos(a), cy + R * 0.9 * math.sin(a)), (cx + R * 1.22 * math.cos(a), cy + R * 1.17 * math.sin(a)), 'marrone', larg_mm=14)
    p.sagome.append(ell(cx, cy, R * 1.18, R * 1.13, 36))
    forma(p, corpo, 'giallo', 'arancio', passo=14)
    forma(p, [(cx + R * 0.9, cy), (cx + R * 1.3, cy - R * 0.3), (cx + R * 1.3, cy + R * 0.3)], 'arancio', 'arancio')   # la coda
    occhio(p, cx - R * 0.5, cy - R * 0.35, R * 0.1)
    p.ovale(cx - R * 0.78, cy + R * 0.02, R * 0.08, R * 0.06, 'rosso', larg_mm=14)   # la bocca a o
    return cx, cy, R


def pesce_palla_jilly(p, W, H):
    """J2 sul pesce palla: dentro il tondo lei alta coi tentacoli sopra i bambini piccoli."""
    cx, cy, R = pesce_palla(p, W, H)
    medusa(p, cx + R * 0.12, cy - R * 0.45, R * 0.22, colore='rosso', tentacoli=6, occhio=True)
    for i in range(5):
        x = cx - R * 0.05 + R * 0.08 * i
        p.tratto([(x + R * 0.03 * math.sin(t * 7 + i), cy - R * 0.25 + R * 0.55 * t) for t in [j / 12 for j in range(13)]], 'nero', larg_mm=9)
    for i, fx in enumerate([-0.3, -0.12, 0.22, 0.42]):
        omino(p, cx + R * fx, cy + R * 0.62, R * 0.24, 'nero', braccia_su=bool(i % 2))
    firma(p, cx + R * 0.55, cy + R * 0.55, R * 0.12, 'verde')


def polpo(p, W, H):
    """Il polpo dei bambini: la testa tonda in alto e otto zampe grosse che si allargano di lato e finiscono arricciate,
    con le ventose; arancio, non rosa (non deve sembrare lei, che è una medusa)."""
    cx, cy = W * 0.5, H * 0.3
    R = W * 0.2
    for i in range(8):
        s = -1 if i < 4 else 1
        k = i if i < 4 else 7 - i          # 0 la più esterna, 3 la più interna
        a0 = math.pi / 2 + s * (0.25 + 0.3 * (3 - k))
        pts = []
        for j in range(15):
            t = j / 14
            rr = R * 0.8 + H * 0.55 * t
            a = a0 + s * 0.5 * t
            x = cx + rr * math.cos(a) * (0.75 + 0.35 * (3 - k) / 3)
            y = cy + R * 0.4 + rr * math.sin(a) * 0.9
            pts.append((x, y))
        # il ricciolo in fondo
        ex, ey = pts[-1]
        for j in range(1, 9):
            a = math.pi / 2 + s * j * 0.7
            pts.append((ex + s * W * 0.035 * (1 - j / 10) * math.cos(a) - s * W * 0.03, ey - W * 0.035 * (1 - j / 10) * math.sin(a)))
        p.tratto(pts, 'arancio', larg_mm=44)
        for q in pts[3:13:3]:
            p.ovale(q[0], q[1], W * 0.012, W * 0.012, 'rosso', larg_mm=9, giri=1.0)
        for q in pts:
            p.sagome.append(ell(q[0], q[1], W * 0.035, W * 0.035, 10))
    forma(p, ell(cx, cy, R, R * 1.15, 34), 'arancio', 'rosso', passo=11)
    occhio(p, cx - R * 0.38, cy + R * 0.1, R * 0.17)
    occhio(p, cx + R * 0.38, cy + R * 0.1, R * 0.17)
    sorriso(p, cx, cy + R * 0.5, R * 0.45)
    firma(p, cx + R * 0.1, cy - R * 0.55, R * 0.2, 'blu')


def delfino(p, W, H):
    cx, cy = W * 0.48, H * 0.55
    sopra = [(cx - W * 0.42 + W * 0.8 * t, cy - H * 0.32 * math.sin(math.pi * (0.1 + 0.85 * t))) for t in [i / 20 for i in range(21)]]
    sotto = [(cx + W * 0.38 - W * 0.8 * t, cy + H * 0.1 * math.sin(math.pi * (0.1 + 0.85 * t)) + H * 0.05) for t in [i / 20 for i in range(21)]]
    corpo = sopra + sotto
    forma(p, corpo, 'azzurro', 'blu', passo=12)
    forma(p, [(cx - W * 0.42, cy - H * 0.05), (cx - W * 0.5, cy - H * 0.02), (cx - W * 0.42, cy + H * 0.08)], 'azzurro', 'blu')   # il becco
    forma(p, [(cx - W * 0.02, cy - H * 0.3), (cx + W * 0.06, cy - H * 0.52), (cx + W * 0.12, cy - H * 0.26)], 'azzurro', 'blu')   # la pinna
    forma(p, [(cx + W * 0.36, cy - H * 0.1), (cx + W * 0.5, cy - H * 0.32), (cx + W * 0.46, cy - H * 0.04), (cx + W * 0.5, cy + H * 0.2), (cx + W * 0.36, cy + H * 0.06)], 'azzurro', 'blu')
    occhio(p, cx - W * 0.3, cy - H * 0.1, H * 0.04)
    sorriso(p, cx - W * 0.38, cy + H * 0.02, W * 0.08, su=0.25)
    firma(p, cx + W * 0.06, cy + H * 0.04, H * 0.07, 'arancio')


def squalo(p, W, H):
    cx, cy = W * 0.48, H * 0.55
    sopra = [(cx - W * 0.44 + W * 0.82 * t, cy - H * 0.26 * math.sin(math.pi * (0.05 + 0.9 * t))) for t in [i / 20 for i in range(21)]]
    sotto = [(cx + W * 0.38 - W * 0.82 * t, cy + H * 0.18 * math.sin(math.pi * (0.05 + 0.9 * t))) for t in [i / 20 for i in range(21)]]
    forma(p, sopra + sotto, 'blu', 'nero', passo=13)
    forma(p, [(cx - W * 0.05, cy - H * 0.24), (cx + W * 0.04, cy - H * 0.5), (cx + W * 0.12, cy - H * 0.2)], 'blu', 'nero')
    forma(p, [(cx + W * 0.36, cy - H * 0.05), (cx + W * 0.5, cy - H * 0.36), (cx + W * 0.46, cy), (cx + W * 0.5, cy + H * 0.3), (cx + W * 0.36, cy + H * 0.08)], 'blu', 'nero')
    forma(p, [(cx - W * 0.02, cy + H * 0.12), (cx + W * 0.08, cy + H * 0.36), (cx + W * 0.12, cy + H * 0.12)], 'blu', 'nero')
    occhio(p, cx - W * 0.3, cy - H * 0.08, H * 0.05)
    # il sorriso buffo coi dentini tondi (bianchi)
    sorriso(p, cx - W * 0.3, cy + H * 0.06, W * 0.14, su=0.3)
    for k in range(4):
        p.ovale(cx - W * 0.35 + W * 0.035 * k, cy + H * 0.09 + H * 0.02 * math.sin(k), W * 0.01, W * 0.012, 'bianco', larg_mm=11, giri=1.0)
    firma(p, cx + W * 0.1, cy + H * 0.0, H * 0.07, 'verde_chiaro')


def pesce_occhio(p, W, H):
    """J3, l'ultimo: un pesce a righe coi colori ancora vivi, e al posto del suo occhio c'è quello di lei."""
    cx, cy = W * 0.46, H * 0.52
    corpo = ell(cx, cy, W * 0.36, H * 0.34, 36)
    forma(p, corpo, 'arancio', 'rosso', passo=12)
    for k in range(3):   # le righe
        x = cx - W * 0.05 + W * 0.12 * k
        p.tratto([(x + W * 0.02 * math.sin(t * 3), cy - H * 0.3 * math.cos(math.asin(min(1, abs(t - 0.5) * 2))) + H * 0.6 * t) for t in [j / 10 for j in range(11)]], 'giallo', larg_mm=26, volte=1)
    forma(p, [(cx + W * 0.32, cy), (cx + W * 0.5, cy - H * 0.32), (cx + W * 0.5, cy + H * 0.32)], 'giallo', 'rosso', passo=10)
    forma(p, [(cx - W * 0.05, cy - H * 0.32), (cx + W * 0.1, cy - H * 0.5), (cx + W * 0.18, cy - H * 0.28)], 'giallo', 'rosso')
    # l'occhio di lei, grande, nero e rosso, con le ciglia (come lo scarabocchio "l'occhio" della sala)
    ex, ey, r = cx - W * 0.2, cy - H * 0.06, H * 0.09
    p.riempi(ell(ex, ey, r * 1.5, r, 20), 'bianco', passo_mm=7)
    p.ovale(ex, ey, r * 1.6, r, 'nero', larg_mm=18, giri=1.3)
    p.riempi(ell(ex, ey, r * 0.55, r * 0.55, 16), 'rosso', passo_mm=7)
    p.ovale(ex, ey, r * 0.25, r * 0.25, 'nero', larg_mm=22)
    for i in range(7):
        a = math.pi * (0.12 + 0.76 * i / 6)
        p.linea((ex + r * 1.55 * math.cos(a), ey - r * 0.95 * math.sin(a)), (ex + r * 1.95 * math.cos(a), ey - r * 1.4 * math.sin(a)), 'nero', larg_mm=11)
    sorriso(p, cx - W * 0.31, cy + H * 0.12, W * 0.08)
    firma(p, cx + W * 0.12, cy + H * 0.12, H * 0.07, 'viola')


def cavalluccio(p, W, H):
    """Il cavalluccio: la testa col muso lungo, la pancia tonda davanti, la coda arricciata in fondo."""
    u = [(0.42, 0.04), (0.55, 0.06), (0.62, 0.12), (0.96, 0.15), (0.97, 0.22), (0.62, 0.24), (0.56, 0.3), (0.66, 0.38),
         (0.74, 0.5), (0.72, 0.62), (0.62, 0.72), (0.5, 0.78), (0.52, 0.86), (0.62, 0.9), (0.68, 0.84), (0.64, 0.79),
         (0.72, 0.78), (0.76, 0.88), (0.66, 0.97), (0.48, 0.96), (0.38, 0.86), (0.36, 0.74), (0.3, 0.6), (0.28, 0.46),
         (0.3, 0.34), (0.34, 0.22), (0.36, 0.12)]
    corpo = [(W * x, H * y) for x, y in u]
    forma(p, corpo, 'giallo', 'arancio', passo=10)
    # le righe della pancia e la pinna sulla schiena
    for k in range(5):
        y = H * (0.4 + 0.07 * k)
        p.linea((W * 0.36, y), (W * (0.66 - 0.02 * abs(k - 2)), y + H * 0.01), 'arancio', larg_mm=10, curva=0.08)
    forma(p, [(W * 0.31, H * 0.42), (W * 0.06, H * 0.48), (W * 0.29, H * 0.58)], 'arancio', 'rosso')
    forma(p, [(W * 0.4, H * 0.06), (W * 0.36, H * 0.0), (W * 0.48, H * 0.05)], 'arancio', 'rosso')
    occhio(p, W * 0.5, H * 0.14, W * 0.055)
    firma(p, W * 0.5, H * 0.66, W * 0.09, 'rosso')


def razza(p, W, H):
    cx, cy = W * 0.5, H * 0.4
    corpo = [(cx, cy - H * 0.3), (cx + W * 0.2, cy - H * 0.12), (cx + W * 0.47, cy + H * 0.02), (cx + W * 0.2, cy + H * 0.18),
             (cx + W * 0.06, cy + H * 0.3), (cx - W * 0.06, cy + H * 0.3), (cx - W * 0.2, cy + H * 0.18), (cx - W * 0.47, cy + H * 0.02),
             (cx - W * 0.2, cy - H * 0.12)]
    forma(p, corpo, 'viola', 'blu', passo=13)
    coda = [(cx + W * 0.03 * math.sin(t * 6), cy + H * 0.3 + H * 0.55 * t) for t in [i / 12 for i in range(13)]]
    p.tratto(coda, 'viola', larg_mm=28)
    for x, y in coda:
        p.sagome.append(ell(x, y, W * 0.025, H * 0.025, 8))
    occhio(p, cx - W * 0.07, cy - H * 0.06, H * 0.045)
    occhio(p, cx + W * 0.07, cy - H * 0.06, H * 0.045)
    sorriso(p, cx, cy + H * 0.06, W * 0.1)
    for k in range(6):
        a = p.rng.uniform(0, 2 * math.pi)
        p.ovale(cx + W * 0.25 * math.cos(a), cy + H * 0.1 * math.sin(a), W * 0.018, W * 0.018, 'azzurro', larg_mm=10, giri=1.0)
    firma(p, cx + W * 0.22, cy + H * 0.08, H * 0.06, 'giallo')


def foca(p, W, H):
    cx, cy = W * 0.45, H * 0.62
    corpo = ell(cx, cy, W * 0.36, H * 0.24, 30, math.pi * 0.9, math.pi * 2.1) + [(cx + W * 0.36, cy + H * 0.12), (cx - W * 0.3, cy + H * 0.2)]
    forma(p, corpo, 'marrone', 'nero', passo=13)
    forma(p, ell(cx - W * 0.3, cy - H * 0.22, W * 0.14, H * 0.16, 24), 'marrone', 'nero', passo=10)   # la testa alzata
    forma(p, [(cx + W * 0.34, cy + H * 0.02), (cx + W * 0.48, cy - H * 0.1), (cx + W * 0.44, cy + H * 0.1), (cx + W * 0.48, cy + H * 0.24), (cx + W * 0.34, cy + H * 0.16)], 'marrone', 'nero')
    forma(p, [(cx - W * 0.1, cy + H * 0.12), (cx - W * 0.02, cy + H * 0.34), (cx + W * 0.06, cy + H * 0.14)], 'marrone', 'nero')
    occhio(p, cx - W * 0.33, cy - H * 0.27, H * 0.04)
    for s in (-1, 1):   # i baffi
        p.linea((cx - W * 0.4, cy - H * 0.17), (cx - W * 0.5, cy - H * (0.17 + s * 0.06)), 'nero', larg_mm=8)
    sorriso(p, cx - W * 0.4, cy - H * 0.12, W * 0.06)
    # la palla sul naso, a spicchi
    bx, by, br = cx - W * 0.42, cy - H * 0.55, H * 0.12
    forma(p, ell(bx, by, br, br, 22), 'rosso', 'nero', passo=8)
    p.linea((bx, by - br), (bx, by + br), 'bianco', larg_mm=20, curva=0.2)
    firma(p, cx + W * 0.1, cy + H * 0.02, H * 0.07, 'azzurro')


# nome: (funzione, larga, alta in metri)
ANIMALI = {
    'balena': (balena, 1.30, 0.80),
    'stella': (stella, 0.70, 0.70),
    'tartaruga': (tartaruga, 1.00, 0.68),
    'granchio': (granchio, 0.80, 0.62),
    'pesce_palla': (pesce_palla_jilly, 1.00, 0.95),
    'polpo': (polpo, 1.05, 0.88),
    'delfino': (delfino, 1.20, 0.62),
    'squalo': (squalo, 1.20, 0.62),
    'pesce': (pesce_occhio, 1.05, 0.72),
    'cavalluccio': (cavalluccio, 0.52, 1.18),
    'razza': (razza, 1.05, 0.90),
    'foca': (foca, 1.05, 0.75),
}
