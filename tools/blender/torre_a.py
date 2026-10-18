"""Sala della torre, versione A (seconda passata del 17 ottobre): la struttura mastodontica.

Riscontro del coordinatore sulla prima A: troppo vuota e buia, pochi tubi sparsi, foresta di pali sottili e cavi.
Qui la sala è piena: quattro torri di traliccio sulle diagonali, con una piattaforma ogni 3 m dal fondo alla cima,
due scale di servizio, e tra le torri decine di scivoli colorati (canali aperti e tubi chiusi, anche a strisce) su
tutti i livelli. Ogni scivolo è retto da una travatura che va da una torre all'altra, con le mensole quando
passa vicino a una torre o a un muro: niente pali sottili né cavi.

La discesa (quella che si fa) gira in senso orario da una torre all'altra, sempre più in basso:
  NO 0 (dal portone) -> NE -3 (con un salto a metà) -> SE -6 (vasca intermedia) -> SO -9 (spezzato: salto col
  getto) -> NO -12 (la Polaroid 10) -> NE -15 (con un salto) -> spirale attorno al pozzo fino alla vasca est.
Gli altri scivoli si scelgono da soli tra centinaia di candidati (a quarti di giro, a mezzo giro, a spirale, nelle
vasche del fondo, dentro i muri), tenendo solo quelli che non toccano niente: sopra la discesa restano sempre
2,4 m liberi.

Uso: tramite torre_proposte.py (versione "A"); la prima passata è la versione "A0".
"""
import json, math, os, random, sys
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import ambiente_kit as K  # noqa: E402
import ambiente_sala as S  # noqa: E402
import torre_proposte as P  # noqa: E402
from torre_proposte import polare, elica, XI0, XI1, YI0, YI1, H, FONDO, LARGO, PROF, SPONDA, R_GROVIGLIO  # noqa: E402

C = (31.0, 15.0)
TORRI = {'NO': 135.0, 'NE': 45.0, 'SE': 315.0, 'SO': 225.0}
ORDINE = ['NO', 'NE', 'SE', 'SO']          # in senso orario: l'angolo scende
R_TORRE = 8.0                              # distanza delle torri dal centro (sulle diagonali)
NUCLEO = 1.1                               # mezzo lato del traliccio
PONTE = 2.9                                # mezzo lato delle piattaforme
LIVELLI = [12.0, 9.0, 6.0, 3.0, 0.0, -3.0, -6.0, -9.0, -12.0, -15.0, -18.0]
BANDA = 7.4                                # raggio della discesa
BANDE = [5.2, 5.9, 6.5, 8.3, 9.0, 9.6]              # raggi degli altri scivoli
M_APERTO = LARGO + SPONDA + 0.05           # mezza larghezza di un canale aperto
# il canale della discesa (quella che si fa) è più largo e profondo: con il movimento di grafica le curve
# veloci vogliono sponde alte circa 1 m (prova: raggio 8 m a 12 m/s)
LARGO_D, PROF_D, SPONDA_D = 1.05, 0.95, 0.25      # U quasi tonda come la scena di prova di grafica
M_DISCESA = LARGO_D + SPONDA + 0.05
R_SPIRALE = 4.6                            # raggio della spirale finale attorno al pozzo
M_CHIUSO = R_GROVIGLIO + 0.1               # mezza larghezza di un tubo chiuso
QUANTI = 38                                # scivoli decorativi da tenere
GIOCO = False                              # True: GLB per il gioco (collisioni -col, prop solidi) e torre_gioco.json
COLORI = {'tsc_giallo': '#f0b414', 'tsc_rosso': '#d22a1e', 'tsc_blu': '#1f62c4', 'tsc_verde': '#35a63a',
          'tsc_arancio': '#f06a14', 'tsc_viola': '#7e36b4', 'tsc_turchese': '#14a8b0', 'tsc_rosa': '#e0507e',
          'tsc_bianco': '#e8e4d8'}
STRISCE = [('tsc_rosso', 'tsc_bianco'), ('tsc_blu', 'tsc_giallo'), ('tsc_verde', 'tsc_bianco'),
           ('tsc_viola', 'tsc_giallo'), ('tsc_arancio', 'tsc_bianco'), ('tsc_turchese', 'tsc_rosa')]
# la pedana interna della NO a -12 (verso il vuoto): ci arriva il mezzo giro da SE e ci parte la spirale finale,
# tutte e due sulla fascia interna; la piattaforma della torre da sola lì è troppo piccola
PEDANA_NO12 = None   # (26.0, 16.0, 29.9, 19.9) quando c'era la spirale
DISCESA_PONTI = {('NO', 0.0), ('NE', -3.0), ('SE', -6.0), ('SO', -9.0), ('NO', -12.0), ('NE', -15.0)}
VERNICI_TORRI = {'NO': 'gioco_giallo', 'NE': 'gioco_blu', 'SE': 'gioco_rosso', 'SO': 'gioco_verde'}


# --- materiali nuovi: vetroresina sbiadita nei colori pieni dell'acquapark ---------------------------------

def materiali_scivoli(mats):
    """Le tinte dei tsc_* come le altre 'tinta' della palette (vetroresina con aloni), salvate accanto alle
    derivate della sala la prima volta."""
    import ambiente_texture as TX
    from PIL import Image
    import numpy as np
    cart = os.path.join(K.TEX, 'derivate', mats.palette)
    for nome, hexa in COLORI.items():
        r = dict(ricetta='tinta', sorgente='vetroresina', colore=hexa, sporco=0.7)
        mats.pal['materiali'][nome] = r
        dest = os.path.join(cart, f'{nome}_col.jpg')
        if not os.path.exists(dest):
            out = TX.ricetta_tinta(r, 1)
            TX._salva_jpg(Image.fromarray((TX.lin_srgb(out) * 255 + 0.5).astype(np.uint8)), dest)


# --- lo spazio: chi occupa cosa ----------------------------------------------------------------------------

MOTIVI = {}


def _no(motivo):
    MOTIVI[motivo] = MOTIVI.get(motivo, 0) + 1
    return False


class Spazio:
    def __init__(self):
        self.discesa = []       # punti dei canali della discesa
        self.deco = []          # (punti, mezza larghezza)
        self.scatole = []       # (x0, y0, z0, x1, y1, z1, nome)

    def scatola(self, x0, y0, z0, x1, y1, z1, nome):
        self.scatole.append((x0, y0, z0, x1, y1, z1, nome))

    def libero(self, pts, mezza, esenti=(), muro_alla_fine=False):
        """Vero se il tracciato (punti fitti) non tocca niente. `esenti`: scatole da non controllare (le
        piattaforme dei due capi). Con muro_alla_fine l'ultimo metro può entrare nel muro."""
        n = len(pts)
        lung = [0.0]
        for i in range(1, n):
            lung.append(lung[-1] + (pts[i] - pts[i - 1]).length)
        for i, t in enumerate(pts):
            dal_capo = min(lung[i], lung[-1] - lung[i])
            fine = muro_alla_fine and lung[-1] - lung[i] < 1.4
            if not fine and not (XI0 + mezza + 0.1 < t.x < XI1 - mezza - 0.1 and YI0 + mezza + 0.1 < t.y < YI1 - mezza - 0.1):
                return _no('muri')
            if t.z > H - 1.2 - mezza or t.z < FONDO + 0.3:
                return _no('quota')
            for (x0, y0, z0, x1, y1, z1, nome) in self.scatole:
                if nome in esenti and dal_capo < 4.0:
                    continue
                if x0 - mezza < t.x < x1 + mezza and y0 - mezza < t.y < y1 + mezza and z0 - mezza - 0.15 < t.z < z1 + mezza:
                    return _no('scatola ' + nome.split('_')[0])
            for route in self.discesa:
                for q in route[::2]:
                    if abs(q.x - t.x) < 3 and abs(q.y - t.y) < 3 and \
                            math.hypot(q.x - t.x, q.y - t.y) < mezza + M_DISCESA + 0.15:
                        dz = t.z - q.z
                        if -(1.4 + mezza) < dz < 2.4 + mezza:
                            return _no('discesa')
            for (altri, m2) in self.deco:
                for q in altri[::2]:
                    if abs(q.x - t.x) < 3 and abs(q.y - t.y) < 3 and \
                            math.hypot(q.x - t.x, q.y - t.y) < mezza + m2 + 0.15 and abs(t.z - q.z) < mezza + m2 + 1.1:
                        return _no('deco')
        return True


def fitti(pts, passo=0.4):
    return P.fitti(pts, passo)


# --- geometria delle torri ---------------------------------------------------------------------------------

def centro(t):
    return polare(C, R_TORRE, TORRI[t])


def ponte(t, L):
    """Rettangolo della piattaforma della torre t al livello L."""
    c = centro(t)
    return (c.x - PONTE, c.y - PONTE, c.x + PONTE, c.y + PONTE)


def dentro_rett(p, r, marg=0.0):
    return r[0] + marg < p.x < r[2] - marg and r[1] + marg < p.y < r[3] - marg


def fuori_nucleo(p, t, mezza):
    c = centro(t)
    return max(abs(p.x - c.x), abs(p.y - c.y)) > NUCLEO + 0.25 + mezza + 0.12


def angolo_capo(t, banda, verso, mezza):
    """Angolo del capo di uno scivolo sulla banda `banda` che parte (o arriva) dalla piattaforma della torre t
    andando nel verso `verso` (-1 orario, +1 antiorario): il primo punto fuori dal traliccio, ancora sulla
    piattaforma. None se la banda non ci passa."""
    a0 = TORRI[t]
    r = ponte(t, 0)
    for k in range(0, 400):
        a = a0 + verso * k * 0.25
        p = polare(C, banda, a)
        if not dentro_rett(p, r, 0.15):
            return None
        if fuori_nucleo(p, t, mezza):
            return a
    return None


def angolo_bordo(t, banda, verso, dentro, extra=None):
    """Angolo dove la banda esce dalla piattaforma della torre t (rimpicciolita di `dentro`), andando nel
    verso dato dall'angolo della torre: i tratti della discesa partono al bordo (dietro c'è la pedana per
    entrarci camminando) e arrivano un po' dentro (c'è spazio per fermarsi)."""
    r = ponte(t, 0)
    a = TORRI[t]
    for k in range(0, 800):
        p = polare(C, banda, a + verso * k * 0.25)
        if not dentro_rett(p, r, dentro) and not (extra and dentro_rett(p, extra, dentro)):
            return a + verso * (k - 1) * 0.25
    return None


# --- pezzi --------------------------------------------------------------------------------------------------

def arco(banda0, banda1, a0, a1, z0, z1, passo=0.35):
    return elica(C, banda0, banda1, a0, a1, z0, z1, passo)


def liscia(pts, giri):
    """Media mobile sulla linea (1-2-1) per arrotondare gli spigoli; i due capi restano fermi."""
    pts = [Vector(p) for p in pts]
    for _ in range(giri):
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


def pendenza(pts):
    lung = sum((pts[i] - pts[i - 1]).length for i in range(1, len(pts)))
    return (pts[0].z - pts[-1].z) / max(lung, 1e-6), lung


def scivolo_discesa(c, pts, mat):
    """Un pezzo della discesa: canale aperto più largo e con le sponde alte (vedi LARGO_D)."""
    S.scivolo_solido(c, [Vector(p) for p in pts], W=LARGO_D, D=PROF_D, T=0.05, H=SPONDA_D, R=0.035, mat=mat)


def travatura(c, pts, chiuso, esclusi, mat='metallo', largo=None, prof=None):
    """La travatura sotto uno scivolo: selle trasversali ogni 1,2 m, montanti e diagonali fino a una trave di
    chiglia 0,75 m più giù. Salta i tratti sopra le piattaforme `esclusi` (rettangoli)."""
    du = R_GROVIGLIO + 0.07 if chiuso else (prof or PROF) + 0.1
    passo = 1.2
    s = 0.0
    sotto = []
    lung = [0.0]
    for i in range(1, len(pts)):
        lung.append(lung[-1] + (pts[i] - pts[i - 1]).length)
    for i in range(1, len(pts)):
        s += (pts[i] - pts[i - 1]).length
        if s < passo:
            continue
        s = 0.0
        p = pts[i]
        # niente selle all'inizio e alla fine del pezzo (nei salti ci si atterrerebbe sopra)
        if lung[i] < 1.5 or lung[-1] - lung[i] < 1.5:
            continue
        if any(dentro_rett(p, r, -0.3) for r in esclusi):
            sotto.append(None)
            continue
        sotto.append((p, i))
    prec = None
    for k, v in enumerate(sotto):
        if v is None:
            prec = None
            continue
        p, i = v
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        d = (b - a); d.z = 0
        d.normalize()
        lat = Vector((-d.y, d.x, 0))
        u = p - Vector((0, 0, du))
        kp = u - Vector((0, 0, 0.75))
        w = 0.45 if chiuso else (0.45 if largo else LARGO + 0.08)
        c.scatola_assi(u - Vector((0, 0, 0.05)), [d, lat, Vector((0, 0, 1))], (0.05, w, 0.05), mat)
        c.cilindro(u - Vector((0, 0, 0.1)), kp, 0.045, mat, seg=8, tappi=False)
        if prec is not None:
            pu, pk = prec
            c.cilindro(pk, kp, 0.06, mat, seg=8, tappi=False)
            c.cilindro(pu - Vector((0, 0, 0.1)), kp, 0.035, mat, seg=6, tappi=False)
        prec = (u, kp)


def torre(c, t, mat, livelli_ponte=None):
    """Traliccio della torre: quattro colonne grosse, travi a ogni livello, croci di Sant'Andrea sulle facce e
    i bracci che reggono la piattaforma (più larga del traliccio)."""
    cc = centro(t)
    ang = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    col = [Vector((cc.x + sx * NUCLEO, cc.y + sy * NUCLEO, 0)) for sx, sy in ang]
    for p in col:
        c.cilindro((p.x, p.y, FONDO), (p.x, p.y, H - 0.2), 0.2, mat, seg=16)
        c.anello((p.x, p.y, FONDO), (0, 0, 1), 0.0, 0.42, 0.04, 'metallo', seg=16)
        c.scatola((p.x - 0.3, p.y - 0.3, H - 0.2), (p.x + 0.3, p.y + 0.3, H), 'metallo')
    quote = [FONDO + 1.0] + LIVELLI[::-1]
    for L in LIVELLI:
        for i in range(4):
            a, b = col[i], col[(i + 1) % 4]
            c.cilindro((a.x, a.y, L - 0.3), (b.x, b.y, L - 0.3), 0.12, mat, seg=10)
        # bracci verso gli angoli della piattaforma (solo dove c'è; altrimenti un secondo anello di travi)
        if livelli_ponte is not None and L not in livelli_ponte:
            for i in range(4):
                a, b = col[i], col[(i + 1) % 4]
                c.cilindro((a.x, a.y, L - 1.5), (b.x, b.y, L - 1.5), 0.08, 'metallo', seg=8)
            continue
        for (sx, sy), p in zip(ang, col):
            q = Vector((cc.x + sx * (PONTE - 0.15), cc.y + sy * (PONTE - 0.15), 0))
            c.cilindro((p.x, p.y, L - 0.3), (q.x, q.y, L - 0.3), 0.09, mat, seg=8)
            c.cilindro((p.x, p.y, L - 1.4), (q.x, q.y, L - 0.32), 0.06, mat, seg=8)
    for z0, z1 in zip(quote[:-1], quote[1:]):
        for i in range(4):
            a, b = col[i], col[(i + 1) % 4]
            c.cilindro((a.x, a.y, z0 - 0.25), (b.x, b.y, z1 - 0.35), 0.05, 'metallo', seg=6)
            c.cilindro((b.x, b.y, z0 - 0.25), (a.x, a.y, z1 - 0.35), 0.05, 'metallo', seg=6)


def scala_servizio(c, sp, x0, y0, lungo, asse, verso_ponte, mat='gioco_giallo'):
    """Scala di servizio a rampe (1,5 m l'una) dal fondo all'ultimo livello: due corsie affiancate larghe 1,1 m
    lungo `asse` ('x' o 'y'), pianerottolo 1,2 m a ogni capo; il pianerottolo d'inizio di ogni giro (ogni 3 m)
    è alla quota delle piattaforme e ci si attacca. Colonne agli angoli, corrimano fuori."""
    largo = 2.2
    corsa = 2.4
    lp = 1.2

    def P_(u, v, z):           # u lungo l'asse, v di traverso
        return Vector((x0 + u, y0 + v, z)) if asse == 'x' else Vector((x0 + v, y0 + u, z))

    def box(u0, v0, z0, u1, v1, z1, m):
        a, b = P_(u0, v0, z0), P_(u1, v1, z1)
        c.scatola((min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)), (max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)), m)
    tot = lp * 2 + corsa
    for (u, v) in ((0, 0), (tot, 0), (tot, largo), (0, largo)):
        p = P_(u, v, 0)
        c.cilindro((p.x, p.y, FONDO), (p.x, p.y, LIVELLI[0] + 1.1), 0.1, mat, seg=10)
    a, b = P_(0, 0, FONDO), P_(tot, largo, LIVELLI[0] + 1.2)
    sp.scatola(min(a.x, b.x), min(a.y, b.y), FONDO, max(a.x, b.x), max(a.y, b.y), LIVELLI[0] + 1.2, 'scala')
    z = FONDO + 2.0 - 3.0 * 0           # primo pianerottolo: 2 m sopra il fondo (si sale dal fondo con la prima rampa)
    quote = [L for L in LIVELLI[::-1]]
    gradini = 8
    alz = 1.5 / gradini
    pedata = corsa / gradini
    # rampa iniziale dal fondo al primo pianerottolo (-18)
    for L in quote:
        # pianerottolo d'inizio giro (alla quota L) e di metà (L + 1,5)
        box(0, 0, L - 0.08, lp, largo, L, 'metallo_grigio')
        box(lp + corsa, 0, L + 1.5 - 0.08, tot, largo, L + 1.5, 'metallo_grigio')
        if L == quote[-1]:
            continue
        for g in range(gradini):     # su lungo l'asse nella corsia 0, poi indietro nella corsia 1
            box(lp + g * pedata, 0.05, L + (g + 1) * alz - 0.05, lp + (g + 1) * pedata, 1.05, L + (g + 1) * alz, 'metallo_grigio')
            box(lp + corsa - (g + 1) * pedata, 1.12, L + 1.5 + (g + 1) * alz - 0.05, lp + corsa - g * pedata, largo - 0.05,
                L + 1.5 + (g + 1) * alz, 'metallo_grigio')
        # cosciali
        for vv in (0.0, 1.1, 1.2, largo - 0.05):
            if vv < 1.15:
                a_, b_ = P_(lp, vv, L), P_(lp + corsa, vv, L + 1.5)
            else:
                a_, b_ = P_(lp + corsa, vv, L + 1.5), P_(lp, vv, L + 3.0)
            c.cilindro(a_ - Vector((0, 0, 0.12)), b_ - Vector((0, 0, 0.12)), 0.05, mat, seg=6)
        # corrimano sul lato esterno (lontano dal ponte) e in testa
        lato = largo if verso_ponte < 0 else 0.0
        P.ringhiera_dritta(c, P_(lp + corsa, lato, L + 1.5), P_(tot, lato, L + 1.5))
        P.ringhiera_dritta(c, P_(tot, 0, L + 1.5), P_(tot, largo, L + 1.5))
    # rampa dal fondo al primo pianerottolo
    L0 = quote[0]
    n0 = int((L0 - FONDO) / alz)
    for g in range(n0):
        box(lp + corsa - (g + 1) * (corsa / n0), 1.2, FONDO + (g + 1) * alz - 0.05, lp + corsa - g * (corsa / n0),
            largo - 0.05, FONDO + (g + 1) * alz, 'metallo_grigio')


def ringhiere_ponte(c, r, L, aperture):
    """Ringhiera sui quattro lati della piattaforma, meno le aperture [(lato, da, a)] in metri lungo il lato."""
    x0, y0, x1, y1 = r
    lati = {'s': ((x0, y0), (x1, y0)), 'n': ((x0, y1), (x1, y1)), 'o': ((x0, y0), (x0, y1)), 'e': ((x1, y0), (x1, y1))}
    for l, ((ax, ay), (bx, by)) in lati.items():
        lung = math.hypot(bx - ax, by - ay)
        tratti = [(0.0, lung)]
        for (la, t0, t1) in aperture:
            if la != l:
                continue
            nuovi = []
            for (u0, u1) in tratti:
                if t1 <= u0 or t0 >= u1:
                    nuovi.append((u0, u1))
                else:
                    if t0 > u0:
                        nuovi.append((u0, t0))
                    if t1 < u1:
                        nuovi.append((t1, u1))
            tratti = nuovi
        for (u0, u1) in tratti:
            if u1 - u0 < 0.3:
                continue
            a = (ax + (bx - ax) * u0 / lung, ay + (by - ay) * u0 / lung, L)
            b = (ax + (bx - ax) * u1 / lung, ay + (by - ay) * u1 / lung, L)
            P.ringhiera_dritta(c, a, b)


def apertura(r, pts, mezza=1.25):
    """Dove il tracciato esce dal rettangolo r: (lato, da, a) in metri lungo quel lato."""
    a = aperture_tutte(r, pts, mezza)
    return a[0] if a else None


def aperture_tutte(r, pts, mezza):
    """Le aperture della ringhiera dove il tracciato esce dal rettangolo r: sul lato che attraversa e, se è
    vicino a un angolo, anche sull'altro lato dell'angolo."""
    x0, y0, x1, y1 = r
    for p in pts:
        if not dentro_rett(p, r):
            d = {'o': abs(p.x - x0), 'e': abs(p.x - x1), 's': abs(p.y - y0), 'n': abs(p.y - y1)}
            l = min(d, key=d.get)
            u = (p.y - y0) if l in 'oe' else (p.x - x0)
            lung = (y1 - y0) if l in 'oe' else (x1 - x0)
            out = [(l, u - mezza, u + mezza)]
            if u - mezza < 0.6:          # vicino all'angolo basso: si apre anche il lato che parte da lì
                altro = 's' if l in 'oe' else 'o'
                pos = 0.0 if l in 'os' else (x1 - x0 if l == 'e' else y1 - y0)
                out.append((altro, pos - 0.1 - (mezza if l in 'en' else 0), pos + (mezza - u + 0.6) if l in 'os' else pos + 0.1))
            if u + mezza > lung - 0.6:   # vicino all'angolo alto
                altro = 'n' if l in 'oe' else 'e'
                pos = 0.0 if l in 'os' else (x1 - x0 if l == 'e' else y1 - y0)
                out.append((altro, pos - (u + mezza - lung + 0.6) if l in 'en' else pos - 0.1, pos + 0.1 + (mezza if l in 'os' else 0)))
            return out
    return []


# --- la versione A -------------------------------------------------------------------------------------------

def versione_A(mats):
    P.CANALI.clear(); P.DECO.clear(); P.OSTACOLI.clear(); P.PALI_PEDANE.clear()
    materiali_scivoli(mats)
    rnd = random.Random(17)
    c = K.Costruttore(mats)            # guscio, torri, piattaforme, travature
    cs = K.Costruttore(mats)           # canali aperti
    P.GRATE[0] = K.Costruttore(mats)
    sp = Spazio()
    P.guscio_profondo(c)
    luci = dict(lavoro=[], fari=[], gocce=[], emergenza=[])
    percorso = []
    aperture = {}                      # (torre, L) -> lista di aperture della ringhiera

    capi_pts = {}                      # (torre, L) -> tracciati dal capo (per le pedane piccole)

    def apri(t, L, pts_dal_capo, mezza=1.25):
        capi_pts.setdefault((t, L), []).append(pts_dal_capo)
        if PEDANA_NO12 and (t, L) == ('NO', -12.0) and dentro_rett(pts_dal_capo[0], PEDANA_NO12):
            aperture.setdefault(('pedana_no12', L), []).extend(aperture_tutte(PEDANA_NO12, pts_dal_capo, mezza))
            return
        aperture.setdefault((t, L), []).extend(aperture_tutte(ponte(t, L), pts_dal_capo, mezza))

    # torri e piattaforme (le scatole servono subito ai controlli)
    for t in ORDINE:
        cc = centro(t)
        sp.scatola(cc.x - NUCLEO - 0.25, cc.y - NUCLEO - 0.25, FONDO, cc.x + NUCLEO + 0.25, cc.y + NUCLEO + 0.25, H, f'nucleo_{t}')
        for L in LIVELLI:
            x0, y0, x1, y1 = ponte(t, L)
            sp.scatola(x0, y0, L - 0.45, x1, y1, L + 1.15, f'ponte_{t}_{L:g}')
    # scale di servizio: tasca ovest della torre NO e tasca sud della torre SE
    rno, rse = ponte('NO', 0), ponte('SE', 0)
    # portone, passerella e balconata
    sp.scatola(XI0, 13.4, -0.5, rno[0] + 0.1, 16.6, 5.0, 'passerella')
    sp.scatola(rno[0] - 2.5, 16.5, -0.5, rno[0] + 0.1, rno[1] + 0.1, 1.2, 'passerella_2')
    sp.scatola(XI0, rno[1] + 0.1, FONDO, XI0 + 2.5, rno[1] + 5.1, LIVELLI[0] + 1.2, 'scala_no')
    sp.scatola(rse[0] + 0.1, YI0, FONDO, rse[0] + 5.1, YI0 + 2.6, LIVELLI[0] + 1.2, 'scala_se')
    sp.scatola(28.4, YI1 - 1.8, -3.8, 33.6, YI1, 1.2, 'balconata')
    sp.scatola(XI0, 12.0, -0.5, XI0 + 0.6, 18.0, 5.2, 'portone')
    # vasche del fondo e pozzo
    # la vasca ovest è quella del fondo, dove finisce la discesa (la spirale attorno al pozzo ci arriva)
    VASCHE = {'est': (33.2, 12.4, 39.6, 17.6), 'sud': (27.6, 4.3, 33.4, 7.6), 'ovest': (20.4, 12.2, 27.2, 17.8)}
    for nome, (x0, y0, x1, y1) in VASCHE.items():
        sp.scatola(x0, y0, FONDO, x1, y1, FONDO + 0.7, f'vasca_{nome}')
    sp.scatola(C[0] - 2.3, C[1] - 2.3, FONDO, C[0] + 2.3, C[1] + 2.3, FONDO + 0.8, 'pozzo')

    # --- la discesa -------------------------------------------------------------------------------------
    def z_capo(L, chiuso=False):
        return L + (0.6 if chiuso else 0.4)

    def spezzato(r0, r1, a0, a1, z0, z1, buchi):
        """Un tratto della discesa da a0 ad a1 (gradi, raggio da r0 a r1, quota da z0 a z1), spezzato nei
        buchi [(angolo, larghezza in metri, dislivello in più, tipo)]. In volo si va dritti: attorno a ogni
        buco la curva si sostituisce con la sua corda (dentro il cerchio, lontano dai tralicci), lunga il buco
        più RINCORSA metri per parte; il pezzo prima finisce sulla corda, quello dopo riparte sulla stessa
        linea, più in basso del dislivello. La pendenza si aggiusta perché l'ultimo pezzo arrivi a z1."""
        RINCORSA = 1.6
        D = sum(b[2] for b in buchi)
        verso = -1 if a1 < a0 else 1

        def f_di(a):
            return (a - a0) / (a1 - a0)

        def r_di(a):
            return r0 + (r1 - r0) * f_di(a)

        def z_di(a):
            giu = sum(b[2] for b in buchi if (a - b[0]) * verso > 0)
            return z0 + (z1 - z0 + D) * f_di(a) - giu

        def punto(a):
            return polare(C, r_di(a), a, z_di(a))
        buchi = sorted(buchi, key=lambda b_: (b_[0] - a0) * verso)
        pezzi, salti = [], []
        corrente = []
        a_prec = a0
        for (ab, larg, dz, tipo) in buchi:
            r = r_di(ab)
            mezzo = math.degrees(math.asin(min(0.95, (larg / 2 + RINCORSA) / r)))
            a_s, a_e = ab - verso * mezzo, ab + verso * mezzo
            # l'arco fino all'inizio della corda
            corrente += arco(r_di(a_prec), r_di(a_s), a_prec, a_s, z_di(a_prec + verso * 1e-6) if a_prec != a0 else z0,
                             z_di(a_s))[:-1]
            ps, pe = punto(a_s), punto(a_e)
            pe = Vector((pe.x, pe.y, z_di(a_e - verso * 1e-6)))      # la quota senza il salto, poi giù di dz
            L = (Vector((pe.x, pe.y, 0)) - Vector((ps.x, ps.y, 0))).length
            u_t = (L - larg) / (2 * L)
            n = max(3, int(L / 0.3))
            for j in range(n + 1):
                u = j / n
                if u > u_t:
                    break
                corrente.append(ps.lerp(pe, u))
            decollo = ps.lerp(pe, u_t)
            corrente.append(decollo)
            pezzi.append(corrente)
            atterra = ps.lerp(pe, 1 - u_t) - Vector((0, 0, dz))
            corrente = [atterra]
            for j in range(n + 1):
                u = j / n
                if u > 1 - u_t:
                    corrente.append(ps.lerp(pe, u) - Vector((0, 0, dz)))
            salti.append(dict(tipo=tipo, larghezza=larg, dislivello=dz, da=decollo, a=atterra))
            a_prec = a_e
        corrente += arco(r_di(a_prec), r1, a_prec, a1, z_di(a_prec + verso * 1e-6) if a_prec != a0 else z0, z1)[1:]
        pezzi.append(corrente)
        # dove l'arco diventa corda c'è uno spigolo: si arrotonda (i capi restano dove sono)
        pezzi = [liscia(pz, 12) for pz in pezzi]
        for k, s_ in enumerate(salti):
            s_['da'], s_['a'] = pezzi[k][-1], pezzi[k + 1][0]
        for s_ in salti:
            # la velocità minima per arrivare senza getto (caduta libera dal capo al pezzo dopo)
            h = max(0.01, s_['da'].z - s_['a'].z)
            s_['v_minima'] = round(s_['larghezza'] / math.sqrt(2 * h / 9.81), 2)
        return pezzi, salti

    def spezzato_regolato(r0, r1, a0, a1, z0, z1, buchi):
        """Come spezzato, ma per i buchi 'getto' il terzo valore è la caduta vera voluta sul buco (piccola: senza
        getto non si arriva): il dislivello in più si trova per approssimazioni."""
        voluti = {i: b[2] for i, b in enumerate(buchi) if b[3] == 'getto'}
        lav = [list(b) for b in buchi]
        for _ in range(6):
            pezzi, salti = spezzato(r0, r1, a0, a1, z0, z1, [tuple(b) for b in lav])
            ordine = sorted(range(len(lav)), key=lambda i: (lav[i][0] - a0) * (-1 if a1 < a0 else 1))
            for k, i in enumerate(ordine):
                if i in voluti:
                    h = salti[k]['da'].z - salti[k]['a'].z
                    lav[i][2] -= h - voluti[i]
        return pezzi, salti

    def tratto_discesa(t0, L0, t1, L1, buchi=(), alza_fine=0.0, banda=BANDA):
        """Scivolo della discesa dalla torre t0 (livello L0) alla t1 (L1) sulla banda BANDA, in senso orario,
        spezzato nei `buchi` [(angolo, larghezza m, dislivello m, 'salto'|'getto')]."""
        a0 = angolo_bordo(t0, banda, -1, 0.15, PEDANA_NO12 if (t0, L0) == ('NO', -12.0) else None)
        a1 = angolo_bordo(t1, banda, +1, 0.25, PEDANA_NO12 if (t1, L1) == ('NO', -12.0) else None)
        if a1 > a0:
            a1 -= 360.0
        z0, z1 = L0 + PROF_D + 0.06, L1 + PROF_D + 0.06 + alza_fine
        buchi = [(b[0] if b[0] <= a0 else b[0] - 360.0, b[1], b[2], b[3]) for b in buchi]
        pezzi, salti = spezzato_regolato(banda, banda, a0, a1, z0, z1, list(buchi))
        for pz in pezzi:
            assert len(pz) < 120 and min(q.z for q in pz) > L1 - 1.5, f'tratto {t0}->{t1} sbagliato'
            sp.discesa.append(pz)
            P.CANALI.append(pz)
        apri(t0, L0, pezzi[0], 2.0)
        apri(t1, L1, pezzi[-1][::-1], 2.0)
        return pezzi, salti

    # la discesa: 6 salti normali e 2 col getto, sempre più difficili. Il primo è corto e basso e insegna
    # (davanti alla balconata dei bambini); la velocità minima dei salti normali cresce da 2 a 5,5 m/s,
    # quelli col getto ne vorrebbero quasi 10 (senza getto non si arriva)
    # la discesa (18 ottobre, "più salti"): 6 tratti da una torre alla successiva sulla fascia larga (le curve
    # strette non si tengono, col movimento di grafica), 4 salti normali sempre più lunghi e 2 col getto. Il
    # primo salto è corto e basso e insegna, davanti alla balconata dei bambini. I salti col getto sono alla fine
    # di un tratto: lo scivolo finisce nel vuoto e si atterra su qualcosa di largo (la pedana NO a -12, poi la
    # vasca del fondo); senza la planata del getto si cade prima.
    def getto_lungo(t0, L0, d_volo, h, verso_pedana=None, verso=-1, arco_m=4.2, tipo='getto'):
        """Un tratto che finisce nel vuoto: dalla pedana t0 (L0) lungo la fascia, finché davanti (in linea retta)
        il bersaglio è a d_volo metri; il capo è h metri sopra l'arrivo. verso_pedana = (torre, L) del bersaglio,
        oppure None (il bersaglio è la vasca del fondo, che si mette lì)."""
        a0 = angolo_bordo(t0, BANDA, verso, 0.15)
        z0 = L0 + PROF_D + 0.06
        for k in range(8, 400):
            a = a0 + verso * k * 0.5
            e = polare(C, BANDA, a)
            tg = polare(C, BANDA, a + verso * 0.5) - e
            tg.normalize()
            if verso_pedana:
                r = ponte(*verso_pedana)
                dd = next((d / 10 for d in range(5, 120) if dentro_rett(e + tg * (d / 10), r, 0.6)), None)
                if dd is not None and dd <= d_volo:
                    break
            elif abs(a0 - a) * math.pi / 180 * BANDA > arco_m:
                dd = d_volo
                break
        z_fine = (verso_pedana[1] if verso_pedana else FONDO + 0.6) + h + PROF_D + 0.06
        pz = liscia(arco(BANDA, BANDA, a0, a, z0, z_fine), 2)
        fine = pz[-1]
        tg = pz[-1] - pz[-2]
        tg.z = 0
        tg.normalize()
        arrivo = fine + tg * (dd + 1.0)
        arrivo.z = (verso_pedana[1] if verso_pedana else FONDO)
        s_ = dict(tipo=tipo, larghezza=round(dd, 2), dislivello=round(h, 2), da=fine, a=arrivo,
                  v_minima=round(dd / math.sqrt(2 * h / 9.81), 2))
        return pz, s_, tg

    discesa, salti, tappe = [], [], []
    for (t0, L0, t1, L1, buchi, alza, mat) in (
            ('NO', 0.0, 'NE', -3.0, [(90.0, 0.8, 0.8, 'salto')], 0.0, 'tsc_rosso'),
            ('NE', -3.0, 'SE', -6.0, [(0.0, 1.1, 0.85, 'salto')], 0.5, 'tsc_giallo'),
            ('SE', -6.0, 'SO', -9.0, [(270.0, 1.4, 0.9, 'salto')], 0.0, 'tsc_blu'),
            ('SO', -9.0, 'NO', -12.0, 'getto', 0.0, 'tsc_turchese'),
            ('NO', -12.0, 'NE', -15.0, 'getto', 0.0, 'tsc_arancio'),
            ('NE', -15.0, None, FONDO, 'getto', 0.0, 'tsc_viola')):
        if buchi == 'getto':
            # i due col getto finiscono sopra una pedana lontana (il secondo più lungo); l'ultimo tratto è un
            # salto normale che finisce nella vasca del fondo, sul lato est
            if t1:
                pz, s_, tg = getto_lungo(t0, L0, 4.3 if t1 == 'NO' else 4.8, 1.5, (t1, L1))
            else:
                pz, s_, tg = getto_lungo(t0, L0, 2.2, 1.7, None, -1, 2.0, 'salto')
            pezzi, ss = [pz], [s_]
            for q in pz:
                pass
            sp.discesa.append(pz)
            P.CANALI.append(pz)
            apri(t0, L0, pz, 2.0)
            if t1 is None:
                # la vasca del fondo dove si atterra col getto (senza, si cade sul pavimento prima)
                c0 = s_['da'] + tg * 3.0
                VASCHE['fondo'] = (max(c0.x - 2.8, 30.0), max(c0.y - 2.8, 11.1), min(c0.x + 2.8, XI1 - 0.3), min(c0.y + 2.8, 18.6))
                x0, y0, x1, y1 = VASCHE['fondo']
                sp.scatola(x0, y0, FONDO, x1, y1, FONDO + 0.7, 'vasca_fondo')
        else:
            pezzi, ss = tratto_discesa(t0, L0, t1, L1, buchi, alza)
        discesa.append(('scivolo', pezzi, mat))
        tappe.append((t0, L0, t1, L1))
        salti += ss
    spirale = []
    spir = discesa[-1][1][-1]
    # la discesa non deve toccare i tralicci
    for pz in sp.discesa:
        for q in pz:
            for t in ORDINE:
                cc = centro(t)
                d = max(abs(q.x - cc.x), abs(q.y - cc.y))
                assert d > NUCLEO + 0.2 + LARGO_D, f'la discesa tocca il traliccio {t} in {tuple(round(v, 1) for v in q)}'
    # le piattaforme che la discesa attraversa senza fermarsi non si fanno (niente capi di scivoli lì)
    vietati = set()
    for t in ORDINE:
        r = ponte(t, 0)
        for L in LIVELLI:
            if (t, L) in DISCESA_PONTI:
                continue
            if any(dentro_rett(q, r, -1.0) and L - 3.0 < q.z < L + 2.8 for pz in sp.discesa for q in pz):
                vietati.add((t, L))
    print('salti:', [(s_['tipo'], s_['larghezza'], s_['dislivello'], s_['v_minima']) for s_ in salti])

    # le tappe: le pedane d'arrivo (checkpoint), i salti, la Polaroid, il fondo
    percorso.append(('portone', Vector((XI0 + 0.5, 15.0, 0.0))))
    nomi_arrivo = ['pedana NE -3', 'vasca intermedia', 'pedana SO -9', 'polaroid 10', 'pedana NE -15', 'fondo']
    for k, (_, pezzi, mat) in enumerate(discesa):
        for j, pz in enumerate(pezzi):
            if j >= 1:
                percorso.append((salti[sum(len(d[1]) - 1 for d in discesa[:k]) + j - 1]['tipo'], pz[0]))
            percorso += [('scivolo', p) for p in pz[::5]]
            percorso.append(('scivolo', pz[-1]))
        if k < len(discesa) - 1:
            percorso.append((nomi_arrivo[k], pezzi[-1][-1]))
    percorso.append(('fondo', spir[-1]))

    # la vasca intermedia sulla piattaforma SE a -6, dove arriva lo scivolo
    arrivo = discesa[1][1][-1][-1]
    cse = centro('SE')
    # la vasca è una striscia tra il traliccio e il bordo della piattaforma, dal lato dove arriva lo scivolo
    dx, dy = arrivo.x - cse.x, arrivo.y - cse.y
    a_, b_ = NUCLEO + 0.45, PONTE - 0.15
    if abs(dy) >= abs(dx):
        y0_, y1_ = (cse.y + a_, cse.y + b_) if dy > 0 else (cse.y - b_, cse.y - a_)
        rv = (cse.x - PONTE + 0.15, y0_, cse.x + PONTE - 0.15, y1_)
    else:
        x0_, x1_ = (cse.x + a_, cse.x + b_) if dx > 0 else (cse.x - b_, cse.x - a_)
        rv = (x0_, cse.y - PONTE + 0.15, x1_, cse.y + PONTE - 0.15)
    va = Vector(((rv[0] + rv[2]) / 2, (rv[1] + rv[3]) / 2, arrivo.z))
    sp.scatola(rv[0], rv[1], -6.3, rv[2], rv[3], -5.3, 'vasca_intermedia')

    # --- gli altri scivoli: si scelgono da soli --------------------------------------------------------
    candidati = []
    for t in ORDINE:
        for L in LIVELLI:
            for verso in (-1, 1):
                for passi in (1, 2, 4, 5):
                    for banda in BANDE:
                        if passi >= 4 and banda > 6.6:
                            continue
                        for chiuso in (True, False):
                            candidati.append(('torre', t, L, verso, passi, banda, chiuso))
            for muro in ('n', 's', 'o', 'e'):
                candidati.append(('muro', t, L, muro, 0, 0, True))
            if L <= -9:
                for v in VASCHE:
                    candidati.append(('vasca', t, L, v, 0, 0, True))
    rnd.shuffle(candidati)
    scelti = []
    conta = {}
    TETTO = {'spirale': 4, 'vasca': 4, 'muro': 7}
    for cand in candidati:
        if len(scelti) >= QUANTI:
            break
        tipo, t, L, x, passi, banda, chiuso = cand
        mezza = M_CHIUSO if chiuso else M_APERTO
        genere = 'spirale' if (tipo == 'torre' and passi >= 4) else tipo
        if conta.get(genere, 0) >= TETTO.get(genere, 99):
            continue
        i0 = ORDINE.index(t)
        if tipo == 'torre':
            verso = x
            t1 = ORDINE[(i0 - verso * passi) % 4]       # in senso orario l'indice cresce
            L1 = L - 3.0 * (passi if passi < 4 else passi - 2)
            if L1 < LIVELLI[-1]:
                continue
            a0 = angolo_capo(t, banda, verso, mezza)
            a1 = angolo_capo(t1, banda, -verso, mezza)
            if a0 is None or a1 is None:
                _no('capo'); continue
            giro = 90.0 * passi
            a1 = a0 + verso * (giro - abs(a1 - TORRI[t1]) - abs(a0 - TORRI[t]))
            pts = arco(banda, banda, a0, a1, z_capo(L, chiuso), z_capo(L1, chiuso))
            esenti = (f'ponte_{t}_{L:g}', f'ponte_{t1}_{L1:g}')
            capi = [(t, L), (t1, L1)]
            muro_fine = False
        elif tipo == 'muro':
            muro = x
            ang_muro = {'n': 90.0, 's': 270.0, 'o': 180.0, 'e': 0.0}[muro]
            d = TORRI[t] - ang_muro
            d = (d + 180) % 360 - 180
            if abs(d) > 60:
                continue
            verso = -1 if d > 0 else 1
            banda = rnd.choice([6.3, 8.3, 9.0])
            a0 = angolo_capo(t, banda, verso, mezza)
            if a0 is None:
                continue
            dist_muro = {'n': YI1 - C[1], 's': C[1] - YI0, 'o': C[0] - XI0, 'e': XI1 - C[0]}[muro] + 0.8
            a1 = ang_muro + rnd.uniform(-12, 12)
            r1 = dist_muro / max(0.35, abs(math.cos(math.radians(a1 - ang_muro))))
            pts = arco(banda, r1, a0, a1, z_capo(L, True), z_capo(L, True) - rnd.uniform(1.5, 3.0))
            esenti = (f'ponte_{t}_{L:g}',)
            capi = [(t, L)]
            muro_fine = True
            # al contrario, a volte: il tubo esce dal muro e arriva sulla piattaforma
            if rnd.random() < 0.5:
                pts = arco(r1, banda, a1, a0, z_capo(L, True) + rnd.uniform(1.5, 3.0), z_capo(L, True))
                pts = pts[::-1]          # i controlli vogliono il muro alla fine
        else:   # vasca del fondo
            v = x
            x0, y0, x1, y1 = VASCHE[v]
            pv = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
            av = math.degrees(math.atan2(pv.y - C[1], pv.x - C[0]))
            r_v = math.hypot(pv.x - C[0], pv.y - C[1])
            d = (av - TORRI[t] + 180) % 360 - 180
            verso = 1 if d > 0 else -1
            giro = abs(d) + (360.0 if rnd.random() < 0.5 else 0.0)
            banda = rnd.choice([5.6, 6.3, 8.3])
            a0 = angolo_capo(t, banda, verso, mezza)
            if a0 is None:
                continue
            pts = arco(banda, r_v, a0, TORRI[t] + verso * giro, z_capo(L, True), FONDO + 0.9)
            esenti = (f'ponte_{t}_{L:g}', f'vasca_{v}')
            capi = [(t, L)]
            muro_fine = False
        if any(c_ in vietati for c_ in capi):
            _no('pedana attraversata dalla discesa'); continue
        pend, lung = pendenza(pts)
        pend = abs(pend)
        if not (0.07 < pend < (0.6 if chiuso else 0.45)) or lung < 4.0:
            _no(f'pendenza {tipo}'); continue
        if not sp.libero(pts, mezza, esenti, muro_fine):
            continue
        sp.deco.append((pts, mezza))
        P.DECO.append((pts, mezza))
        scelti.append((cand, pts, capi))
        conta[genere] = conta.get(genere, 0) + 1
    print('scivoli decorativi scelti:', len(scelti), 'su', len(candidati), 'candidati; tipi:', conta, 'scarti:', MOTIVI)

    # --- costruzione degli scivoli ------------------------------------------------------------------
    oggetti_scivoli = []
    colori = list(COLORI)
    canali_discesa = []
    for k, (_, pezzi, mat) in enumerate(discesa):
        for j, pz in enumerate(pezzi):
            cd = K.Costruttore(mats)
            scivolo_discesa(cd, pz, mat)
            # solo da vedere: la collisione la fa SalaTorre dalla linea del fondo (come la prova di grafica)
            canali_discesa.append(cd.crea(f'discesa_{k}_{j}', sporco=lambda co: 0.75))
    for j, (cand, pts, capi) in enumerate(scelti):
        tipo, t, L, x, passi, banda, chiuso = cand
        if chiuso:
            if rnd.random() < 0.45:
                m = list(rnd.choice(STRISCE))
            else:
                m = [rnd.choice(colori[:-1])]
            oggetti_scivoli.append(K.tubo_scivolo(mats, pts, nome=f'torre_scivolo_{j}' + ('-col' if GIOCO else ''), materiali=m, seg=18,
                                                  passo_flange=1.6 if len(m) > 1 else 2.5))
        else:
            P.scivolo(cs, pts, rnd.choice(colori[:-1]))
        for (tt, LL) in capi:
            apri(tt, LL, pts if (tt, LL) == capi[0] else pts[::-1])
    # travature: sotto tutto, tranne sopra le piattaforme dei capi
    rett_ponti = [ponte(t, 0) for t in ORDINE]
    for _, pezzi, _m in discesa:
        for pz in pezzi:
            travatura(c, pz, False, rett_ponti, 'metallo', LARGO_D, PROF_D)
    for cand, pts, capi in scelti:
        travatura(c, pts, cand[6], rett_ponti, rnd.choice(['metallo', 'metallo_grigio']))
    # mensole: dove uno scivolo passa accanto a un traliccio, un braccio lo regge
    for pts, mezza in [(p, M_DISCESA) for p in sp.discesa] + sp.deco:
        for t in ORDINE:
            cc = centro(t)
            # (non ai capi del pezzo: nei salti ci si atterrerebbe sopra)
            vicini = [(max(abs(p.x - cc.x), abs(p.y - cc.y)), i) for i, p in enumerate(pts) if 5 <= i < len(pts) - 5]
            if not vicini:
                continue
            dmin, i = min(vicini)
            if NUCLEO + mezza + 0.2 < dmin < NUCLEO + mezza + 1.6 and not dentro_rett(pts[i], ponte(t, 0)):
                p = pts[i]
                du = (R_GROVIGLIO + 0.07) if mezza < 0.8 else (PROF_D if mezza > M_APERTO else PROF) + 0.1
                q = Vector((min(max(p.x, cc.x - NUCLEO), cc.x + NUCLEO), min(max(p.y, cc.y - NUCLEO), cc.y + NUCLEO), p.z - du - 0.1))
                c.cilindro(q, Vector((p.x, p.y, q.z)), 0.08, 'metallo', seg=8)
                c.cilindro(Vector((q.x, q.y, q.z - 1.0)), Vector((p.x, p.y, q.z)), 0.05, 'metallo', seg=6)
    # la spirale finale ha i suoi piloni dove sotto non passa niente
    tutta = [q for pz in spirale for q in pz]
    for pz in spirale:
        for i in range(6, len(pz) - 4, 14):
            p = pz[i]
            if all(not (math.hypot(q.x - p.x, q.y - p.y) < 1.4 and q.z < p.z - 0.5) for q in tutta) and \
                    not dentro_rett(p, VASCHE['fondo'], -0.5):
                z1 = p.z - PROF_D - 0.12
                c.cilindro((p.x, p.y, FONDO), (p.x, p.y, z1), 0.18, 'gioco_giallo', seg=14)
                c.anello((p.x, p.y, FONDO), (0, 0, 1), 0.0, 0.36, 0.04, 'metallo', seg=14)
                c.scatola((p.x - 0.4, p.y - 0.4, z1 - 0.06), (p.x + 0.4, p.y + 0.4, z1), 'metallo')

    # --- torri, piattaforme, ringhiere, scale ---------------------------------------------------------
    # piattaforme solo dove parte o arriva uno scivolo (scelta dell'utente del 18 ottobre: "solo dove servono")
    servono = set(DISCESA_PONTI)
    for cand, pts, capi in scelti:
        servono.update(capi)
    print('piattaforme:', len(servono), 'su', len(ORDINE) * len(LIVELLI))
    for t in ORDINE:
        torre(c, t, VERNICI_TORRI[t], {L for (tt, L) in DISCESA_PONTI if tt == t})
        for L in LIVELLI:
            if (t, L) not in servono:
                continue
            r = ponte(t, L)
            ap = list(aperture.get((t, L), []))
            if (t, L) not in DISCESA_PONTI:
                # solo scivoli decorativi: una pedana piccola attaccata al traliccio, grande quanto serve
                cc = centro(t)
                xs, ys = [cc.x - NUCLEO, cc.x + NUCLEO], [cc.y - NUCLEO, cc.y + NUCLEO]
                for pts_ in capi_pts.get((t, L), []):
                    xs += [pts_[0].x - 1.1, pts_[0].x + 1.1]
                    ys += [pts_[0].y - 1.1, pts_[0].y + 1.1]
                r = (max(r[0], min(xs)), max(r[1], min(ys)), min(r[2], max(xs)), min(r[3], max(ys)))
                ap = [a_ for a_ in (apertura(r, pts_) for pts_ in capi_pts.get((t, L), [])) if a_]
                P.piattaforma(c, r[0], r[1], r[2], r[3], L, lati=(), pali=False)
            if (t, L) == ('NO', -12.0) and PEDANA_NO12:
                pr = PEDANA_NO12
                P.piattaforma(c, pr[0], pr[1], pr[2], pr[3], L, lati=(), pali=False)
                ringhiere_ponte(c, pr, L, aperture.get(('pedana_no12', L), []))
                cc = centro(t)
                for (qx, qy) in ((pr[2] - 0.2, pr[3] - 0.2), (pr[2] - 0.2, pr[1] + 0.2), (pr[0] + 0.2, pr[1] + 0.2)):
                    a_ = Vector((cc.x + NUCLEO, cc.y - NUCLEO, L - 0.3))
                    c.cilindro(a_, (qx, qy, L - 0.25), 0.1, VERNICI_TORRI[t], seg=10)
                    c.cilindro(a_ - Vector((0, 0, 1.8)), (qx, qy, L - 0.3), 0.07, 'metallo', seg=8)
                ringhiere_ponte(c, r, L, ap)
                continue
            P.piattaforma(c, r[0], r[1], r[2], r[3], L, lati=(), pali=False)
            if t == 'NO':
                ap.append(('o', 0.0, 2.6))          # verso la scala
                if L == 0.0:
                    ap.append(('o', 0.0, 5.2))      # dalla passerella del portone
            if t == 'SE':
                ap.append(('s', 0.0, 2.6))
            ringhiere_ponte(c, r, L, ap)
    scala_servizio(c, sp, XI0 + 0.05, rno[1] + 0.2, 4.8, 'y', 1)
    scala_servizio(c, sp, rse[0] + 0.2, YI0 + 0.08, 4.8, 'x', 1)
    # passerella dal portone alla torre NO (a quota 0)
    P.piattaforma(c, XI0, 13.4, rno[0] + 0.05, 16.6, 0.0, lati=('s',), pali=False)
    P.piattaforma(c, rno[0] - 2.4, 16.6, rno[0] + 0.05, rno[1] + 0.05, 0.0, lati=('o',), pali=False)
    P.ringhiera_dritta(c, (XI0 + 0.3, 16.6, 0.0), (rno[0] - 2.4, 16.6, 0.0))
    P.mensola(c, 13.6, 16.4, XI0, 0.0, 'o')
    # il portale di partenza (senza le sbarre: il cancello è aperto, si entra camminando nel canale)
    b0 = discesa[0][1][0][0]
    v0 = discesa[0][1][0][3] - b0
    v0.z = 0
    v0.normalize()
    t0v = Vector((-v0.y, v0.x, 0))
    base = Vector((b0.x, b0.y, 0.0))
    for s_ in (-1, 1):
        ap = base + t0v * (s_ * (LARGO_D + 0.45))
        c.cilindro(ap, ap + Vector((0, 0, 2.6)), 0.07, 'gioco_rosso', seg=12)
    c.cilindro(base - t0v * (LARGO_D + 0.45) + Vector((0, 0, 2.6)), base + t0v * (LARGO_D + 0.45) + Vector((0, 0, 2.6)), 0.07,
               'gioco_rosso', seg=12)
    c.scatola_assi(base + Vector((0, 0, 2.85)), [v0, t0v, Vector((0, 0, 1))], (0.03, LARGO_D + 0.55, 0.22), 'strisce')
    P.balconata(c, 28.6, 33.4, YI1, -1.5)
    # il fondo: pozzo, vasche, la bocca del tubo dell'inseguimento sul muro nord
    P.pozzo_lei(c, C)
    acque = []
    vf = VASCHE['fondo']
    for nome, (x0, y0, x1, y1) in VASCHE.items():
        if nome != 'fondo' and x0 < vf[2] + 0.5 and vf[0] < x1 + 0.5 and y0 < vf[3] + 0.5 and vf[1] < y1 + 0.5:
            continue    # la vasca del fondo prende il suo posto
        acque.append(P.vasca(c, x0, y0, x1, y1, FONDO, alto=0.6, nome_acqua=f'acqua_vasca_{nome}'))
    # la bocca del tubo grande dell'inseguimento: dal muro est, sopra la vasca est
    bocca = [(XI1 + 1.0, 15.0, FONDO + 1.4), (XI1 - 1.2, 15.0, FONDO + 1.6), (XI1 - 2.4, 15.0, FONDO + 1.6)]
    oggetti_scivoli.append(K.tubo_scivolo(mats, bocca, nome='torre_tubo_inseguimento', materiali=['tsc_giallo'], r=0.8, spessore=0.06))
    acque.append(P.vasca(c, rv[0], rv[1], rv[2], rv[3], -6.0, alto=0.45, nome_acqua='acqua_vasca_intermedia'))
    # tubi di servizio sui muri
    for z in (-17.0, -7.5, 4.5, 10.5):
        P.tubo_muro(c, [(XI0 + 0.3, YI0 + 0.35, z), (XI1 - 0.35, YI0 + 0.35, z)], r=0.16)
        P.tubo_muro(c, [(XI1 - 0.35, YI0 + 0.35, z + 0.6), (XI1 - 0.35, YI1 - 0.35, z + 0.6)], r=0.12)

    # --- prop: sulle piattaforme lontano dai capi degli scivoli, e sul fondo ---------------------------
    props = []
    capi_ponti = {}
    for _, pezzi, _m in discesa:
        for pz in pezzi:
            capi_ponti.setdefault('x', []).extend([pz[0], pz[-1]])
    for cand, pts, capi in scelti:
        capi_ponti['x'].extend([pts[0], pts[-1]])
    tutti_capi = capi_ponti['x']
    scelta_prop = ['salvagente_nave', 'ciambella_gonfiabile', 'cestino_pesce', 'tubi_galleggianti',
                   'pallone_spiaggia', 'cartello_pavimento_bagnato', 'paperella_gigante']
    usati_ponti = set()
    for t in ORDINE:
        cc = centro(t)
        for L in LIVELLI:
            if (t, L) not in DISCESA_PONTI:
                continue
            for _ in range(12):
                sx, sy = rnd.choice([(-1, -1), (1, -1), (1, 1), (-1, 1), (0, -1), (0, 1), (-1, 0), (1, 0)])
                p = Vector((cc.x + sx * (PONTE - 0.95), cc.y + sy * (PONTE - 0.95), L))
                if max(abs(p.x - cc.x), abs(p.y - cc.y)) < NUCLEO + 0.8:
                    continue
                if any((Vector((q.x, q.y, 0)) - Vector((p.x, p.y, 0))).length < 2.0 and abs(q.z - L) < 1.5 for q in tutti_capi):
                    continue
                if any(math.hypot(q.x - p.x, q.y - p.y) < 1.9 and -0.5 < q.z - L < 2.5
                       for pts_ in sp.discesa + [d_[0] for d_ in sp.deco] for q in pts_[::2]):
                    continue
                if t == 'NO' and p.x < cc.x - 1.0 and sy <= 0:   # davanti alla scala
                    continue
                if t == 'SE' and p.y < cc.y - 1.0:
                    continue
                if (t, L) == ('SE', -6.0) and dentro_rett(p, rv, -1.0):
                    continue
                props.append(P.prop(rnd.choice(scelta_prop), (p.x, p.y, L), rnd.uniform(0, 360)))
                usati_ponti.add((t, L))
                break
    # la Polaroid 10 sul lettino della piattaforma NO a -12
    cno = centro('NO')
    pl = Vector((cno.x - 1.0, cno.y + 2.1, -12.0))
    props.append(P.prop('lettino_plastica', (pl.x, pl.y, -12.0), 90))
    polaroid_pos = Vector((pl.x, pl.y, -12.0 + 0.36))
    c2 = K.Costruttore(mats)
    P.polaroid(c2, Vector((pl.x, pl.y, -12.0 + 0.36)), Vector((1, 0, 0)))
    pol = c2.crea('torre_polaroid_10')
    oltre = Vector((rv[0] + 0.6, (rv[1] + rv[3]) / 2, 0)) if arrivo.x > va.x else Vector((rv[2] - 0.6, (rv[1] + rv[3]) / 2, 0))
    props += [P.prop('paperella_gigante', (oltre.x, oltre.y, -6.0 + 0.45 - 0.12 - 0.15), 200),
              P.prop('cartello_pavimento_bagnato', (cno.x - 1.8, cno.y - 1.6, 0.0), 30)]
    fondo = [('sedia_bagnino', (29.4, 9.9), 0), ('lettino_plastica', (21.2, 9.0), 90), ('lettino_plastica', (21.2, 10.8), 95),
             ('balena_gonfiabile_sgonfia', (30.0, 21.6), 15), ('delfino_gonfiabile_sgonfio', (25.6, 4.9), 120),
             ('pallone_spiaggia', (27.0, 12.6), 0), ('secchio_gigante', (32.6, 9.6), 30),
             ('cestino_pesce', (39.4, 11.6), 200), ('cannoncino_acqua', (24.2, 11.5), 300), ('salvagente_nave', (24.4, 4.6), 80),
             ('cartello_pavimento_bagnato', (28.0, 18.2), 140), ('tubi_galleggianti', (27.4, 24.8), 10),
             ('ciambella_gonfiabile', (38.6, 16.6, FONDO + 0.6 - 0.2), 70), ('ciambella_gonfiabile', (30.0, 5.8, FONDO + 0.6 - 0.2), 10),
             ('orsacchiotto_grande', (20.9, 19.0), 100)]
    for nome, pos, rot in fondo:
        z = pos[2] if len(pos) > 2 else FONDO
        props.append(P.prop(nome, (pos[0], pos[1], z), rot))
    if GIOCO:
        # nel gioco i prop sono solidi: una scatola convessa sui limiti di ciascuno (come in ambiente_sala)
        for o in props:
            if o.name.startswith('prop_') and o.type == 'MESH':
                me = o.data
                xs = [v.co.x for v in me.vertices]; ys_ = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
                cb = K.collisione_scatola(o.name, (min(xs), min(ys_), min(zs)), (max(xs), max(ys_), max(zs)), padre=o)
                cb.hide_render = True
    # cartelloni dipinti sui muri, tra le costole
    for i, (pos, rot, graf) in enumerate((((32.0, YI1 - 0.005, 6.5), 0, 'p1'), ((32.0, YI0 + 0.005, -4.5), 180, 'p2'),
                                          ((24.0, YI0 + 0.005, 8.0), 180, 'p3'), ((36.0, YI1 - 0.005, -12.0), 0, 'p1'))):
        cart = K.cartellone(mats, 3.2, 1.8, nome=f'torre_cartellone_{i}')
        cart.location = Vector(pos)
        cart.rotation_euler = (0, 0, math.radians(rot))
        for j, m in enumerate(cart.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                cart.data.materials[j] = mats.get('cartellone_' + graf)
        props.append(cart)

    # --- luci (le mette lo script degli scatti) -------------------------------------------------------
    for (t, L) in [('NO', 0.0), ('NE', -3.0), ('SE', -6.0), ('SO', -9.0), ('NO', -12.0), ('NE', -15.0)] + \
            [tl for tl in sorted(usati_ponti) if tl[1] in (9.0, 3.0, -9.0, -18.0)][:6]:
        cc = centro(t)
        sx = 1 if (TORRI[t] % 360) in (45.0, 315.0) else -1
        sy = 1 if (TORRI[t] % 360) in (45.0, 135.0) else -1
        luci['lavoro'].append([cc.x + sx * (PONTE - 0.1), cc.y + sy * (PONTE - 0.1), L + 1.25])
    luci['lavoro'].append([31.0, YI1 - 0.35, -1.5 + 2.45])     # sopra la porta della balconata dei bambini
    # fari sui tralicci: ognuno punta il centro di uno scivolo dall'altra parte della sala, più in basso
    medi = [pts[len(pts) // 2] for _, pts, _ in scelti] + [pz[len(pz) // 2] for _, pezzi, _ in discesa for pz in pezzi]
    usati = set()
    for t in ORDINE:
        cc = centro(t)
        for zf in (H - 0.6, 1.5, -10.5):
            p = Vector((cc.x, cc.y, zf))
            buoni = [(abs((m.z - (zf - 7.0))), i) for i, m in enumerate(medi) if i not in usati
                     and (Vector((m.x, m.y, 0)) - Vector((cc.x, cc.y, 0))).length > 8.0 and m.z < zf - 1.0]
            if not buoni:
                continue
            _, i = min(buoni)
            usati.add(i)
            luci['fari'].append([[p.x, p.y, p.z], [medi[i].x, medi[i].y, medi[i].z]])
    luci['emergenza'] = [[[XI0 + 0.1, 20.5, 6.0], 'e'], [[XI1 - 0.1, 15.0, 1.5], 'o'], [[31.0, YI0 + 0.1, -2.5], 'n'],
                         [[31.0, YI1 - 0.1, -8.0], 's'], [[XI0 + 0.1, 10.0, -12.0], 'e'], [[XI1 - 0.1, 15.0, -16.5], 'o'],
                         [[27.0, YI1 - 0.1, 9.0], 's']]
    for cand, pts, capi in scelti[::3]:
        luci['gocce'].append([pts[-1].x, pts[-1].y, pts[-1].z - 0.4])
    luci['lei'] = [C[0], C[1], FONDO]

    sporco = lambda co: 0.55 + 0.45 * min(1.0, max(0.0, (co.z - FONDO) / 8.0))
    suff = '-col' if GIOCO else ''
    gr = P.GRATE[0].crea('torre_A_grigliati' + suff)
    ob = c.crea('torre_A' + suff, sporco=sporco)
    ob_s = cs.crea('torre_A_canali' + suff, sporco=lambda co: 0.75)
    gruppi = {'struttura': [ob, gr, pol] + acque, 'scivoli': [ob_s] + canali_discesa + oggetti_scivoli, 'prop': props}
    # per il gioco: checkpoint, salti, Polaroid, balconata, pozzo e vasca del fondo (coordinate di Blender)
    gioco = dict(checkpoint=[], salti=[], tratti=[])
    passerella = Vector((XI0 + 1.2, 15.0, 0.0))
    t0_ = discesa[0][1][0][1] - discesa[0][1][0][0]
    t0_.z = 0
    t0_.normalize()
    gioco['checkpoint'].append(dict(nome='portone', pos=list(passerella), spawn=list(passerella),
                                    guarda=list(passerella + Vector((1, 0, 0)))))
    arrivi = [(t1, L1) for (t0, L0, t1, L1) in tappe if t1]

    def salti_fine_tratto(k):
        # il salto col getto con cui finisce il tratto k (il capo è sopra il vuoto), o None
        n_prima = sum(len(d[1]) - 1 for d in discesa[:k]) + sum(1 for (t0_, L0_, t1_, L1_), d in zip(tappe[:k], discesa[:k]) if len(d[1]) == 1 and k and False)
        for s_ in salti:
            if s_['tipo'] == 'getto' and (s_['da'] - discesa[k][1][-1][-1]).length < 0.01:
                return s_
        return None
    for k, (_, pezzi, _m) in enumerate(discesa):
        fine = pezzi[-1][-1]
        if k < len(arrivi):
            t_arr, L = arrivi[k]
            # il checkpoint è dove arriva lo scivolo; si riparte un metro dietro l'inizio del tratto dopo, nella
            # sua direzione (così ci si entra camminando dritti)
            pos = Vector((fine.x, fine.y, L)) if salti_fine_tratto(k) is None else Vector((salti_fine_tratto(k)['a'].x, salti_fine_tratto(k)['a'].y, L))
            nuovo = discesa[k + 1][1][0]
            tang = nuovo[1] - nuovo[0]
            tang.z = 0
            tang.normalize()
            spawn = Vector((nuovo[0].x, nuovo[0].y, L)) - tang * 1.1
            cc = centro(t_arr)
            assert max(abs(spawn.x - cc.x), abs(spawn.y - cc.y)) > NUCLEO + 0.55, f'ripartenza dentro il traliccio {t_arr}'
            gioco['checkpoint'].append(dict(nome=f'{t_arr} {L:g}', pos=list(pos), spawn=list(spawn),
                                            guarda=list(spawn + tang * 3.0)))
        tg = pezzi[0][1] - pezzi[0][0]
        tg.z = 0
        tg.normalize()
        L0 = tappe[k][1]
        entra = Vector((pezzi[0][0].x, pezzi[0][0].y, L0)) - tg * 1.1
        # la linea del fondo di ogni pezzo (per la collisione, in Godot)
        linee = [[[round(v, 3) for v in (q - Vector((0, 0, PROF_D)))] for q in pz] for pz in pezzi]
        # i salti di questo tratto, in ordine: quelli tra i suoi pezzi e quello col getto alla fine (se c'è)
        fini = [pz[-1] for pz in pezzi]
        tipi = [s_['tipo'] for s_ in salti if any((s_['da'] - f_).length < 0.01 for f_ in fini)]
        gioco['tratti'].append(dict(pezzi=[f'discesa_{k}_{j}' for j in range(len(pezzi))], linee=linee, salti=tipi,
                                    da=list(pezzi[0][0]), a=list(fine), entrata=list(entra), verso=list(tg)))
    xv0, yv0, xv1, yv1 = VASCHE['fondo']
    gioco['checkpoint'].append(dict(nome='fondo', pos=[(xv0 + xv1) / 2, (yv0 + yv1) / 2, FONDO], guarda=[C[0], C[1], FONDO]))
    for s_ in salti:
        gioco['salti'].append(dict(tipo=s_['tipo'], larghezza=s_['larghezza'], dislivello=round(s_['dislivello'], 3),
                                   v_minima=s_['v_minima'], da=list(s_['da']), a=list(s_['a'])))
    gioco['polaroid_10'] = list(polaroid_pos)
    gioco['balconata'] = dict(centro=[31.0, YI1 - 0.8, -1.5], primo_salto=list(salti[0]['da']))
    gioco['pozzo'] = [C[0], C[1], FONDO]
    gioco['vasca_fondo'] = dict(rett=[xv0, yv0, xv1, yv1], acqua=FONDO + 0.6 - 0.12)
    gioco['passerella'] = list(passerella)
    luci['gioco'] = gioco
    return gruppi, percorso, luci
