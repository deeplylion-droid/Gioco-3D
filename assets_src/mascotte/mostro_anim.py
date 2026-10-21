"""Mostro-squalo A: l'animazione dell'inizio del gioco, scritta come funzioni del tempo e cotta
fotogramma per fotogramma sullo scheletro di mostro_rig.py (le gambe con una IK a due ossa fatta qui,
così i piedi restano piantati a terra e non scivolano).

Lo spazio è quello del modello in Blender: lo squalo parte nell'origine e guarda verso -Y, dove c'è
il giocatore (la sua testa a Y = GIOCATORE_Y); la porta tagliafuoco è dietro di lui, verso +Y, a
Y = PORTA_Y. Il giro (Godot) mette questo spazio nel corridoio.

Le fasi (secondi), le stesse che usa scripts/interni/risveglio_squalo.gd (le legge dal .json):
- 0,0  addosso al giocatore che si sveglia: chino, la testa giù all'altezza della sua faccia, la bocca
       che si apre piano; le mani artigliate ai lati della faccia;
- MINACCIA: la bocca spalancata a pochi centimetri, il fiato, piccoli scatti in avanti;
- RICHIAMO: il verso lontano di Jilly dalla porta. Si blocca, la testa scatta verso il suono, dietro
       di sé, sopra la spalla;
- GIRO: si gira (tre passi sul posto) verso la porta, la bocca si chiude a metà;
- ESITA: fermo verso la porta, mezzo passo; si volta a guardare il giocatore sopra la spalla, sbuffa;
- CORSA: parte, corsa pesante e piegata in avanti, il corpo che ondeggia, la coda che fa da
       contrappeso, le braccia che pompano; alla porta si abbassa e passa;
- FINE: oltre la porta (Godot la chiude e lo nasconde).
"""
import json, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler

FPS = 30
GIOCATORE_Y = -1.70      # la faccia del giocatore, davanti allo squalo
PORTA_Y = 5.80           # la porta tagliafuoco, dietro di lui
FASI = dict(MINACCIA=2.4, RICHIAMO=5.4, GIRO=5.85, ESITA=6.75, CORSA=7.75, PORTA=None, FINE=None)
VEL_CORSA = 2.8          # m/s
ACCEL = 0.9              # secondi per arrivare alla velocità di corsa
CADENZA = 2.2            # passi al secondo
FINE_Y = PORTA_Y + 1.6   # dove si ferma il conto (oltre la porta, ormai chiusa)


def liscio(a, b, t0, t1, t):
    """Da a a b tra t0 e t1, con l'accelerazione e la frenata dolci."""
    if t <= t0:
        return a
    if t >= t1:
        return b
    x = (t - t0) / (t1 - t0)
    x = x * x * x * (x * (x * 6 - 15) + 10)
    return a + (b - a) * x


def chiavi(t, punti):
    """Curva per chiavi [(t, valore)], liscia tra una chiave e l'altra (valori scalari o tuple)."""
    if t <= punti[0][0]:
        return punti[0][1]
    for (ta, va), (tb, vb) in zip(punti, punti[1:]):
        if t <= tb:
            if isinstance(va, tuple):
                return tuple(liscio(x, y, ta, tb, t) for x, y in zip(va, vb))
            return liscio(va, vb, ta, tb, t)
    return punti[-1][1]


def rumore(t, f, seme):
    """Rumore liscio (somma di seni a frequenze non multiple), da -1 a 1 circa."""
    return (math.sin(t * f * 6.283 + seme) * 0.5 + math.sin(t * f * 2.71 * 6.283 + seme * 1.7) * 0.3
            + math.sin(t * f * 5.13 * 6.283 + seme * 2.3) * 0.2)


# ---------------------------------------------------------------- moto della radice (corsa)
def posizione_corsa(t):
    """Distanza percorsa lungo +Y dopo il giro (ESITA ha mezzo passo), e velocità."""
    t0 = FASI['CORSA']
    if t < t0:
        return 0.0, 0.0
    dt = t - t0
    if dt < ACCEL:
        # accelerazione dolce: v = V * (x^2 (3 - 2x))
        x = dt / ACCEL
        v = VEL_CORSA * x * x * (3 - 2 * x)
        s = VEL_CORSA * ACCEL * (x ** 3 - 0.5 * x ** 4)
        return s, v
    s_acc = VEL_CORSA * ACCEL * 0.5
    return s_acc + VEL_CORSA * (dt - ACCEL), VEL_CORSA


def tempo_alla_porta():
    # mezzo passo dell'esitazione: 0,35 m
    t = FASI['CORSA']
    while True:
        s, _ = posizione_corsa(t)
        if 0.35 + s >= PORTA_Y:
            return t
        t += 1.0 / FPS


def radice(t):
    """(x, y, yaw) della radice: fermo, il giro di 180° sul posto, mezzo passo, la corsa."""
    yaw = chiavi(t, [(FASI['GIRO'] + 0.05, 0.0), (FASI['GIRO'] + 0.80, math.pi)])
    # mentre minaccia si sporge in avanti e indietro di qualche centimetro
    avanti = 0.0
    if t < FASI['RICHIAMO']:
        avanti = chiavi(t, [(0.0, 0.0), (FASI['MINACCIA'], -0.10), (FASI['MINACCIA'] + 0.6, -0.04),
                            (FASI['MINACCIA'] + 1.4, -0.12), (FASI['MINACCIA'] + 2.0, -0.06), (FASI['RICHIAMO'], -0.08)])
    else:
        avanti = chiavi(t, [(FASI['RICHIAMO'], -0.08), (FASI['GIRO'] + 0.8, 0.0)])
    passo = chiavi(t, [(FASI['ESITA'] + 0.15, 0.0), (FASI['ESITA'] + 0.55, 0.35)])
    s, _ = posizione_corsa(t)
    return 0.0, avanti + passo + s, yaw


# ---------------------------------------------------------------- appoggi dei piedi
class Piedi:
    """Dove sta ogni caviglia in ogni istante (spazio del modello), e quanto è alzata: fermi da piantati,
    tre passi per girarsi, mezzo passo, poi la corsa a passi alternati con una fase di volo."""

    def __init__(self, caviglie_riposo):
        # caviglie nella posa di riposo, nello spazio della radice: +x avanti di 0,3 m, -x dietro
        self.riposo = {s: Vector(c) for s, c in caviglie_riposo.items()}
        # in piedi per minacciare: i piedi un po' più larghi e allineati
        self.fermo = {'L': Vector((0.34, 0.30, 0.20)), 'R': Vector((-0.30, 0.42, 0.20))}
        self.appoggi = {'L': [], 'R': []}       # (t_inizio, t_fine, posizione caviglia, yaw)
        self._costruisci()

    def _mondo(self, locale, x, y, yaw):
        c, s = math.cos(yaw), math.sin(yaw)
        return Vector((x + locale.x * c - locale.y * s, y + locale.x * s + locale.y * c, locale.z))

    def _costruisci(self):
        g = FASI['GIRO']
        # fermi fino al giro
        for s in 'LR':
            self.appoggi[s].append((0.0, g + 0.10 + (0.0 if s == 'L' else 0.3), self.fermo[s].copy(), 0.0))
        # il giro: tre passi (L, R, L) mentre la radice gira di 180°
        for k, (s, t0) in enumerate((('L', g + 0.32), ('R', g + 0.62), ('L', g + 0.90))):
            dur_fine = FASI['ESITA'] + (0.15 if s == 'L' else 0.45)
            fine = dur_fine if (s == 'R' or k == 2) else g + 0.90 - 0.18
            yaw = math.pi * min(1.0, (t0 - g) / 0.8)
            x, y, _ = radice(t0)
            self.appoggi[s].append((t0, fine, self._mondo(self.fermo[s], x, y, yaw), yaw))
        # mezzo passo dell'esitazione: prima il destro poi il sinistro raggiunge
        e = FASI['ESITA']
        self.appoggi['R'].append((e + 0.42, FASI['CORSA'] + 0.05, self._mondo(self.fermo['R'], 0, 0.35, math.pi) + Vector((0, 0.18, 0)), math.pi))
        self.appoggi['L'].append((e + 0.62, FASI['CORSA'] - 0.05, self._mondo(self.fermo['L'], 0, 0.35, math.pi), math.pi))
        # la corsa: passi alternati, ogni appoggio centrato sotto l'anca a metà appoggio
        t = FASI['CORSA'] + 0.12
        lato = 'L'
        while t < FASI['CORSA'] + 6.0:
            _, v = posizione_corsa(t)
            v = max(v, 0.9)
            appoggio = min(0.32, 0.78 / v)
            tm = t + appoggio / 2
            x, y, yaw = radice(tm)
            off = Vector((0.26 if lato == 'L' else -0.26, 0.0, 0.20))
            pos = self._mondo(off, x, y, yaw)
            self.appoggi[lato].append((t, t + appoggio, pos, yaw))
            t += 1.0 / CADENZA * (1.0 if v > 2.0 else 1.25)
            lato = 'R' if lato == 'L' else 'L'

    def caviglia(self, s, t):
        """(posizione, alzata 0-1, yaw del piede)."""
        ap = self.appoggi[s]
        for i, (a, b, p, yaw) in enumerate(ap):
            if a <= t <= b:
                return p, 0.0, yaw
            if i + 1 < len(ap) and b < t < ap[i + 1][0]:
                a2, _, p2, yaw2 = ap[i + 1]
                x = (t - b) / (a2 - b)
                xs = x * x * (3 - 2 * x)
                pos = p.lerp(p2, xs)
                alza = math.sin(math.pi * x)
                passo = (p2 - p).length
                pos.z += alza * min(0.22, 0.06 + passo * 0.12)
                return pos, alza, yaw + (yaw2 - yaw) * xs
        return ap[-1][2], 0.0, ap[-1][3]

    def in_volo(self, t):
        return all(self.caviglia(s, t)[1] > 0.0 for s in 'LR')

    def tempi_appoggio(self, s):
        return [(a, b) for a, b, _, _ in self.appoggi[s]]


# ---------------------------------------------------------------- posa del corpo (rotazioni nel mondo)
def posa(t, piedi):
    """Rotazioni (gradi, assi del mondo del modello a riposo: x di lato, y indietro, z su) di ogni osso
    rispetto alla posa di riposo, l'abbassamento del bacino, l'apertura della mascella."""
    M, R, G, E, C = FASI['MINACCIA'], FASI['RICHIAMO'], FASI['GIRO'], FASI['ESITA'], FASI['CORSA']
    tp = tempo_alla_porta()
    p = {}
    corsa = liscio(0.0, 1.0, C - 0.1, C + 0.5, t)
    _, v = posizione_corsa(t)
    fase = (t - C) * CADENZA * math.pi            # mezzo giro per passo
    # --- quanto è chino: addosso al giocatore (testa giù), poi si raddrizza al richiamo
    chino = chiavi(t, [(0.0, 1.0), (R + 0.05, 1.0), (R + 0.45, 0.25), (G + 0.8, 0.1), (E + 0.6, 0.15), (C, 0.35)])
    abbassa = 0.14 * chino
    # alla porta: si abbassa ancora per passare sotto l'architrave
    abbassa += liscio(0.0, 0.16, tp - 0.45, tp - 0.15, t) - liscio(0.0, 0.16, tp + 0.25, tp + 0.55, t)
    # la corsa: il bacino scende a ogni appoggio e risale nel volo
    if corsa > 0:
        abbassa += corsa * (0.07 + 0.06 * math.cos(2 * fase))
    p['_abbassa'] = abbassa
    # --- respiro (sempre): il petto si gonfia
    resp = math.sin(t * 2 * math.pi * (0.55 if t < R else 0.9))
    # --- bacino e busto
    p['bacino'] = [('x', 5 * chino + 16 * corsa), ('z', 6 * corsa * math.sin(fase)),
                   ('y', 4 * corsa * math.sin(fase))]
    p['spina'] = [('x', 5 * chino + 8 * corsa + 1.5 * resp), ('z', -5 * corsa * math.sin(fase))]
    p['petto'] = [('x', 4 * chino + 6 * corsa - 2 * resp), ('z', -6 * corsa * math.sin(fase))]
    # alla porta il busto si piega di più
    p['spina'].append(('x', liscio(0, 10, tp - 0.45, tp - 0.15, t) - liscio(0, 10, tp + 0.25, tp + 0.55, t)))
    # --- collo e testa: giù verso la faccia del giocatore, poi lo scatto verso il richiamo (dietro a
    # sinistra, sopra la spalla), il giro, lo sguardo indietro al giocatore nell'esitazione
    guarda = chiavi(t, [(R + 0.08, 0.0), (R + 0.30, 75.0), (G + 0.2, 75.0), (G + 0.8, 0.0), (E + 0.7, 0.0),
                        (E + 0.85, 100.0), (E + 1.35, 100.0), (E + 1.5, 70.0), (C - 0.15, 0.0)])
    alza = chiavi(t, [(R + 0.08, 0.0), (R + 0.30, -18.0), (G + 0.8, -5.0), (C, 0.0)])
    scatti = 0.0
    if M < t < R:
        # piccoli scatti in avanti della testa, come per mordere
        for tc in (M + 0.7, M + 1.6, M + 2.5):
            scatti += math.exp(-((t - tc) / 0.09) ** 2) * 7.0
    tremito = rumore(t, 3.0, 1.0) * (1.0 if t < R else 0.4)
    p['collo'] = [('x', 6 * chino + 0.5 * tremito - 4 * corsa), ('z', guarda * 0.45), ('x', alza * 0.5)]
    # con la bocca spalancata il muso si alza: l'apertura guarda in avanti, verso la faccia del giocatore
    muso_su = chiavi(t, [(0.0, 0.0), (1.2, -4.0), (M, -24.0), (R + 0.05, -24.0), (R + 0.30, 0.0)])
    p['testa'] = [('x', 4 * chino + muso_su + scatti - 6 * corsa - 3 * corsa * math.cos(2 * fase)),
                  ('z', guarda * 0.55 + 1.5 * tremito), ('x', alza * 0.5), ('y', 6 * chino * math.sin(t * 0.9))]
    # --- mascella: si apre piano al risveglio, spalancata nella minaccia, mezza chiusa al richiamo, sbuffo
    # nell'esitazione, ansima nella corsa
    apri = chiavi(t, [(0.0, 8.0), (1.2, 12.0), (M, 52.0), (R + 0.05, 55.0), (R + 0.30, 30.0), (G + 0.8, 12.0),
                      (E + 0.85, 10.0), (E + 1.0, 32.0), (E + 1.3, 6.0), (C, 14.0)])
    if M < t < R:
        apri += 3.0 * math.sin(t * 2 * math.pi * 0.55)
    if corsa > 0:
        apri += corsa * 6.0 * (0.5 + 0.5 * math.sin(2 * fase + 1.0))
    p['mascella'] = [('_apri', apri)]
    # --- braccia: nella minaccia aperte ai lati della faccia del giocatore, gli artigli in avanti; al
    # richiamo si fermano; nella corsa pompano (opposte alle gambe) con il gomito piegato
    braccia = chiavi(t, [(0.0, 1.0), (R + 0.1, 1.0), (G + 0.6, 0.3), (C, 0.0)])
    pomp = corsa * 20 * math.sin(fase)
    # il braccio +x (L) pende: si alza e va in avanti e in fuori
    p['braccio.L'] = [('x', -22 * braccia - 10 * corsa + pomp), ('y', 10 * braccia)]
    p['avambraccio.L'] = [('x', -15 * braccia - 20 * corsa - 0.4 * pomp)]
    p['mano.L'] = [('x', -10 * braccia + 4 * rumore(t, 2.0, 3.0) * braccia)]
    # il braccio -x (R) è già alzato davanti al muso: si sposta di lato per non coprire la bocca
    p['braccio.R'] = [('z', 15 * braccia), ('x', -6 * braccia + 25 * corsa - pomp), ('y', -8 * braccia)]
    p['avambraccio.R'] = [('x', 6 * braccia - 15 * corsa + 0.4 * pomp)]
    p['mano.R'] = [('x', 4 * rumore(t, 2.2, 5.0) * braccia)]
    # --- coda: ondeggia lenta, nella corsa fa da contrappeso (in ritardo sul bacino)
    amp = 6 + 14 * corsa
    for k, b in enumerate(('coda1', 'coda2', 'coda3')):
        p[b] = [('z', amp * math.sin((fase if corsa > 0 else t * 1.3) - 0.9 * (k + 1)) * (1 + 0.3 * k)),
                ('x', -4 * corsa)]
    return p


def dati_per_godot(piedi):
    """I tempi che servono al giro in Godot (camera, suoni, porta), con la durata dell'animazione."""
    tp = tempo_alla_porta()
    passi = []
    for s in 'LR':
        for a, b in piedi.tempi_appoggio(s):
            if a > 0.05 and a < tp + 0.8:
                passi.append(round(a, 3))
    return dict(fps=FPS, durata=round(tp + 0.9, 3), porta=round(tp, 3), passi=sorted(passi),
                giocatore_y=GIOCATORE_Y, porta_y=PORTA_Y, **{k.lower(): v for k, v in FASI.items() if v is not None})
