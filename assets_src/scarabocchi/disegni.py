"""I disegni degli scarabocchi (scelte consigliate dal coordinatore all'utente, 28 ottobre: C, C, B):
- **cosa**: tutti e due, misti. Scarabocchi (spirali, un cerchio, macchie colorate forte, cancellature fitte); disegnini da bambini (la
  nave, i pesci, il sole, i bambini che si tengono per mano, Jilly sorridente come sui poster); qua e là qualcuno che
  mette a disagio (tante manine che salgono verso l'alto, Jilly col suo occhio solo, i bambini sott'acqua con lei). Mai
  lei che prende qualcuno, niente che spieghi cosa è successo (la regola delle Polaroid).
- **colori**: i disegnini coi colori di una scatola di pastelli, sbiaditi dall'umidità; quelli a disagio in nero e rosso.
- **regole**: niente lettere, numeri, frecce; niente cerchi gialli, rossi e blu in fila (i colori dell'enigma della
  piscina a onde): qui un cerchio è sempre da solo, e nessun disegno ha tre tondi di quei colori vicini.
Ogni funzione disegna su un Pastello largo w e alto h pixel (coordinate in pixel, y in giù).
"""
import math

from motivi import sole, omino, onde, medusa, nave, scarabocchio  # noqa: F401


# ------------------------------------------------------------------ motivi nuovi
def pesce(p, cx, cy, lungo, colore, verso=1):
    h = lungo * 0.45
    corpo = [(cx - verso * lungo * 0.5 + verso * lungo * t, cy + h * 0.5 * math.sin(math.pi * t) * s)
             for s in (-1, 1) for t in ([i / 10 for i in range(11)] if s < 0 else [1 - i / 10 for i in range(11)])]
    p.riempi(corpo, colore, passo_mm=11)
    p.tratto(corpo + [corpo[0]], colore)
    coda = cx - verso * lungo * 0.5
    p.tratto([(coda, cy), (coda - verso * lungo * 0.25, cy - h * 0.45), (coda - verso * lungo * 0.25, cy + h * 0.45), (coda, cy)], colore)
    p.ovale(cx + verso * lungo * 0.28, cy - h * 0.1, h * 0.08, h * 0.08, 'nero', larg_mm=12)


def bambini_per_mano(p, x0, x1, y, alto, colori):
    n = len(colori)
    xs = [x0 + (x1 - x0) * (i + 0.5) / n for i in range(n)]
    for x, c in zip(xs, colori):
        omino(p, x, y, alto * (0.85 + 0.25 * p.rng.random()), c)
    # le mani che si tengono: una riga fra un bambino e l'altro, all'altezza delle mani
    for i in range(n - 1):
        ym = y - alto * 0.52
        p.linea((xs[i] + alto * 0.2, ym), (xs[i + 1] - alto * 0.2, ym), colori[i], curva=0.06)


def jilly_sorridente(p, cx, cy, r, colore='rosa'):
    """Jilly come sui poster: la campana rosa, l'occhio grande al centro, il sorriso largo, i tentacoli ricci."""
    medusa(p, cx, cy, r, colore, tentacoli=7, occhio=True)
    # il sorriso sotto l'occhio
    p.tratto([(cx - r * 0.35 + r * 0.7 * t, cy - r * 0.12 + r * 0.14 * math.sin(math.pi * t)) for t in [i / 10 for i in range(11)]], 'rosso', larg_mm=13)
    # le guance
    for s in (-1, 1):
        p.ovale(cx + s * r * 0.55, cy - r * 0.2, r * 0.09, r * 0.07, 'rosso', larg_mm=10)


def manina(p, cx, cy, r, colore, ang=0.0):
    """Il contorno di una manina (il palmo e cinque dita), girata di [ang] radianti (0: le dita in su)."""
    def ruota(x, y):
        return (cx + x * math.cos(ang) - y * math.sin(ang), cy + x * math.sin(ang) + y * math.cos(ang))
    palmo = [ruota(r * 0.55 * math.cos(a), r * 0.6 * math.sin(a) + r * 0.25) for a in [math.pi * (0.05 + 0.9 * i / 16) for i in range(17)]]
    p.tratto(palmo, colore, larg_mm=13)
    for k, (dx, lung, inc) in enumerate([(-0.5, 0.55, -0.5), (-0.28, 0.9, -0.12), (0.0, 1.0, 0.0), (0.26, 0.92, 0.1), (0.5, 0.7, 0.25)]):
        base = (r * dx, r * 0.2)
        punta = (base[0] + math.sin(inc) * r * lung, base[1] - math.cos(inc) * r * lung)
        p.linea(ruota(*base), ruota(*punta), colore, larg_mm=13, curva=0.04)


def manine_su(p, w, h, quante=9):
    """Tante manine che salgono verso l'alto, una sopra l'altra, nere e rosse."""
    for i in range(quante):
        t = i / max(1, quante - 1)
        # da sinistra in basso verso destra in alto, a zig-zag: salgono
        x = w * (0.1 + 0.8 * t) + p.rng.normal(0, w * 0.03)
        y = h * (0.82 - 0.55 * t) + (h * 0.12 if i % 2 else 0.0)
        manina(p, x, y, h * (0.2 + 0.04 * p.rng.random()), 'nero' if i % 3 else 'rosso', ang=p.rng.normal(0, 0.25))


def occhio_solo(p, cx, cy, r):
    """Jilly col suo occhio solo: un occhio grande che guarda, nero e rosso, senza il resto di lei."""
    p.ovale(cx, cy, r * 1.6, r, 'nero', larg_mm=18, giri=1.3)
    p.riempi([(cx + r * 0.55 * math.cos(a), cy + r * 0.55 * math.sin(a)) for a in [i * 2 * math.pi / 16 for i in range(16)]], 'rosso', passo_mm=8)
    p.ovale(cx, cy, r * 0.25, r * 0.25, 'nero', larg_mm=22)
    for i in range(9):
        a = math.pi * (0.1 + 0.8 * i / 8)
        p.linea((cx + r * 1.6 * math.cos(a) * 0.95, cy - r * math.sin(a) * 0.95),
                (cx + r * 2.0 * math.cos(a), cy - r * 1.35 * math.sin(a)), 'nero', larg_mm=12)
    # le vene rosse
    for i in range(5):
        a = p.rng.uniform(0, 2 * math.pi)
        p.linea((cx + r * 0.6 * math.cos(a), cy + r * 0.55 * math.sin(a)), (cx + r * 1.3 * math.cos(a), cy + r * 0.85 * math.sin(a)), 'rosso', larg_mm=9, curva=0.15)


def sott_acqua(p, w, h, con_lei=True):
    """I bambini sott'acqua con lei (come nella P16): l'acqua sopra, le bollicine, i bambini che galleggiano fermi e lei
    in mezzo. Nero e rosso; nessuno che prende nessuno."""
    onde(p, w * 0.03, w * 0.97, h * 0.12, h * 0.03, colore='nero', righe=2)
    # (i bambini ai lati, lei in mezzo, più in alto: non tocca nessuno)
    for i, fx in enumerate([0.1, 0.27, 0.73, 0.9]):
        x = w * fx + p.rng.normal(0, w * 0.015)
        omino(p, x, h * (0.88 - 0.06 * (i % 2)), h * 0.45, 'nero', braccia_su=True)
        for k in range(3):
            p.ovale(x + p.rng.normal(0, h * 0.03), h * (0.42 - 0.08 * k), h * 0.018, h * 0.018, 'nero', larg_mm=9, giri=1.0)
    if con_lei:
        medusa(p, w * 0.5, h * 0.36, h * 0.14, colore='rosso', tentacoli=5, occhio=True)


def spirale(p, cx, cy, r, colore, giri=5):
    pts = [(cx + r * (i / (giri * 24)) * math.cos(i * 2 * math.pi / 24), cy + r * 0.85 * (i / (giri * 24)) * math.sin(i * 2 * math.pi / 24))
           for i in range(giri * 24 + 1)]
    p.tratto(pts, colore, volte=1)


def macchia(p, cx, cy, rx, ry, colore):
    """Una macchia colorata forte, a va e vieni fitto in tutte le direzioni: non ci sono segni da contare (righe in fila
    sembrerebbero tacche, come quelle di un indizio)."""
    forma = [(cx + rx * (0.75 + 0.25 * p.rng.random()) * math.cos(a), cy + ry * (0.75 + 0.25 * p.rng.random()) * math.sin(a))
             for a in [i * 2 * math.pi / 14 for i in range(14)]]
    for ang in (0.5, 1.6, 2.6):
        p.riempi(forma, colore, larg_mm=13, passo_mm=9, ang=ang + p.rng.normal(0, 0.2))


def cancellatura(p, x0, y0, x1, y1, colore='nero'):
    """Cancellare con rabbia: un va e vieni fitto sopra quello che c'era."""
    forma = [(x0, y0), (x1, y0 + p.rng.normal(0, 10)), (x1, y1), (x0, y1 + p.rng.normal(0, 10))]
    # due passate storte e incrociate, con i buchi fra un segno e l'altro (si vede ancora sotto quello che c'era)
    p.riempi(forma, colore, larg_mm=12, passo_mm=20, ang=1.1)
    p.riempi(forma, colore, larg_mm=11, passo_mm=26, ang=2.2)


# ------------------------------------------------------------------ le composizioni (una per muro, scelte in genera.py)
def mare_e_nave(p, w, h):
    sole(p, w * 0.12, h * 0.22, h * 0.11, raggi=9)
    nave(p, w * 0.5, h * 0.62, w * 0.34, colore='blu')
    onde(p, w * 0.04, w * 0.96, h * 0.82, h * 0.025, colore='azzurro', righe=2)
    pesce(p, w * 0.82, h * 0.9, w * 0.09, 'arancio', verso=-1)


def per_mano(p, w, h):
    bambini_per_mano(p, w * 0.08, w * 0.7, h * 0.95, h * 0.6, ['rosso', 'verde', 'viola', 'arancio'])
    jilly_sorridente(p, w * 0.85, h * 0.35, h * 0.2)


def jilly_e_pesci(p, w, h):
    jilly_sorridente(p, w * 0.3, h * 0.33, h * 0.22)
    for i, c in enumerate(['verde', 'arancio', 'viola']):
        pesce(p, w * (0.6 + 0.13 * i), h * (0.5 + 0.15 * (i % 2)), w * 0.09, c, verso=1 if i % 2 else -1)
    onde(p, w * 0.05, w * 0.95, h * 0.92, h * 0.02, colore='azzurro', righe=1)


def scarabocchi_misti(p, w, h):
    spirale(p, w * 0.2, h * 0.45, h * 0.3, 'verde')
    macchia(p, w * 0.55, h * 0.5, w * 0.06, h * 0.4, 'viola')
    scarabocchio(p, w * 0.83, h * 0.5, h * 0.28, 'marrone')


def cerchio_e_cancellatura(p, w, h):
    # un omino cancellato, accanto un tondo grande verde ripassato tante volte
    omino(p, w * 0.3, h * 0.92, h * 0.6, 'blu')
    cancellatura(p, w * 0.2, h * 0.3, w * 0.42, h * 0.95, 'nero')
    p.ovale(w * 0.72, h * 0.5, h * 0.3, h * 0.3, 'verde', giri=2.6)


def pesci_sul_fiume(p, w, h):
    onde(p, w * 0.03, w * 0.97, h * 0.3, h * 0.03, colore='azzurro', righe=3)
    for i, c in enumerate(['arancio', 'verde', 'rosa', 'marrone']):
        pesce(p, w * (0.15 + 0.22 * i), h * (0.7 + 0.08 * (i % 2)), w * 0.1, c, verso=1 if i % 2 else -1)


def disagio_manine(p, w, h):
    manine_su(p, w, h, quante=7)


def disagio_occhio(p, w, h):
    occhio_solo(p, w * 0.5, h * 0.5, h * 0.32)


def disagio_sott_acqua(p, w, h):
    sott_acqua(p, w, h)


BASSI = [mare_e_nave, per_mano, jilly_e_pesci, scarabocchi_misti, cerchio_e_cancellatura]
BASSI_BAGNATI = [pesci_sul_fiume, jilly_e_pesci, scarabocchi_misti, mare_e_nave, cerchio_e_cancellatura]
ALTI = [disagio_manine, disagio_occhio, disagio_sott_acqua]
