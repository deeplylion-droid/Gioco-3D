"""I motivi dei disegni a pastello (si combinano in disegni.py)."""
import math


def sole(p, cx, cy, r, colore='giallo', raggi=10):
    p.riempi([(cx + r * math.cos(a) * 0.95, cy + r * math.sin(a) * 0.95) for a in [i * 2 * math.pi / 14 for i in range(14)]], colore)
    p.ovale(cx, cy, r, r, colore if colore != 'giallo' else 'arancio')
    for i in range(raggi):
        a = 2 * math.pi * i / raggi + p.rng.normal(0, 0.08)
        p.linea((cx + r * 1.25 * math.cos(a), cy + r * 1.25 * math.sin(a)),
                (cx + r * 1.9 * math.cos(a), cy + r * 1.9 * math.sin(a)), colore)


def omino(p, x, y, alto, colore, braccia_su=False):
    """Un bambino stilizzato coi piedi in (x, y)."""
    testa = alto * 0.1
    collo = y - alto * 0.64
    p.ovale(x, collo - testa, testa, testa, colore)
    p.linea((x, collo), (x, y - alto * 0.3), colore)
    for s in (-1, 1):
        p.linea((x, y - alto * 0.3), (x + s * alto * 0.18, y), colore)
        fine = (x + s * alto * 0.28, collo - (alto * 0.2 if braccia_su else -alto * 0.12))
        p.linea((x, collo + alto * 0.06), fine, colore)


def onde(p, x0, x1, y, alt, colore='azzurro', righe=2):
    for k in range(righe):
        pts = []
        n = 40
        for i in range(n + 1):
            t = i / n
            pts.append((x0 + (x1 - x0) * t, y + k * alt * 1.6 + alt * math.sin(t * 2 * math.pi * 4 + k)))
        p.tratto(pts, colore)


def medusa(p, cx, cy, r, colore='rosa', tentacoli=6, occhio=True):
    """Jilly come la disegnano i bambini: la campana, l'occhio grande, i tentacoli ondulati."""
    pts = [(cx + r * math.cos(a), cy - r * 0.9 * math.sin(a)) for a in [math.pi * i / 20 for i in range(21)]]
    pts.append((cx - r, cy))
    p.riempi(pts, colore)
    p.tratto(pts, 'viola' if colore == 'rosa' else 'nero')
    if occhio:
        p.ovale(cx, cy - r * 0.45, r * 0.3, r * 0.26, 'bianco')
        p.ovale(cx, cy - r * 0.45, r * 0.12, r * 0.12, 'nero', larg_mm=18)
    for i in range(tentacoli):
        x = cx - r * 0.8 + 1.6 * r * i / max(1, tentacoli - 1)
        pts = [(x + r * 0.12 * math.sin(t * 6 + i), cy + r * 1.6 * t) for t in [j / 12 for j in range(13)]]
        p.tratto(pts, colore)


def nave(p, cx, y, largo, colore='blu'):
    scafo = [(cx - largo / 2, y), (cx + largo / 2, y), (cx + largo * 0.4, y + largo * 0.18), (cx - largo * 0.4, y + largo * 0.18)]
    p.riempi(scafo, colore)
    p.tratto(scafo + [scafo[0]], 'nero')
    p.riempi([(cx - largo * 0.25, y), (cx + largo * 0.2, y), (cx + largo * 0.2, y - largo * 0.15), (cx - largo * 0.25, y - largo * 0.15)], 'bianco')
    p.linea((cx + largo * 0.05, y - largo * 0.15), (cx + largo * 0.05, y - largo * 0.3), 'rosso')


def scarabocchio(p, cx, cy, r, colore, giri=8):
    """Il groviglio a caso di chi prova i colori."""
    pts = []
    for i in range(giri * 12):
        a = i * 0.55 + p.rng.normal(0, 0.3)
        rr = r * (0.3 + 0.7 * p.rng.random())
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a) * 0.7))
    p.tratto(pts, colore, volte=1)


