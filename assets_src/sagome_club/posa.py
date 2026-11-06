"""Dove stanno le sagome del club nelle condotte dell'inseguimento, come sono tenute su e la loro forma 3D (scelta A
dell'utente del 6 novembre). Legge assets_src/sagome_club/sagome.json (il contorno tagliato a mano, da genera.py) e
scrive godot/assets/sagome_club/posa.json per SagomeClub (scripts/game/sagome_club.gd): per ogni sagoma dove sta
nella sala dell'inseguimento (le sue coordinate), la faccia già divisa in triangoli coi fori delle legature, i bordi
(contorno e fori), e le cose che la tengono su.

Le vasche non hanno ringhiere tranne la 2 (la passerella nord), quindi:
- vasca 1 e vasca 3: in piedi sul bordo di piastrelle (largo 18 cm, dove non si passa: si sta nell'acqua), girate verso
  l'acqua, la faccia a 2,5 cm dallo spigolo interno; dietro un puntello di cartone (una striscia incollata alla schiena,
  col piede piegato sul bordo) e sul piede un mattone, di fianco al puntello;
- vasca 2: in piedi sulla passerella nord, dietro la ringhiera, contro il corrimano basso (le più alte lo toccano) e
  legate con lo spago al corrimano in due punti fra i montanti: lo spago passa dal cartone e gira attorno al corrimano,
  stretto (le più basse ci restano appese); verso la vasca sporge solo sopra i 2 m dal fondo.
Lontano dalle bocche dei tubi, dalle paratie, dai pali delle lampade e da dove sale lei (la bava rosa della vasca 1 a
nord-ovest, il lato est della vasca 2, il lato sud della vasca 3). Le coordinate sono quelle dei GLB della sala (struttura, tubi), che entrano
nella sala senza spostamenti.
Uso: /home/user/tools/blender-venv/bin/python assets_src/sagome_club/posa.py
"""
import json
import math
import os

import bpy  # noqa: F401  (serve a mathutils)
import numpy as np
from mathutils.geometry import tessellate_polygon

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.normpath(os.path.join(QUI, '..', '..'))
CARTELLA = os.path.join(RADICE, 'godot', 'assets', 'sagome_club')

SPESSORE = 0.005          # il cartone ondulato
DAL_BORDO = 0.025         # la faccia dallo spigolo interno del bordo della vasca
# lo spago delle legature (largo e spesso: uno spago da pacchi schiacciato), quanto stringe, il foro
SPAGO = (0.0035, 0.0025)
AGIO = 0.0003
# le vasche: il piano del bordo (y) e le facce interne dei muri (x ovest, x est, z nord, z sud)
VASCHE = {
    1: {'bordo': -21.50, 'O': 50.18, 'E': 54.82, 'N': -17.82, 'S': -12.18},
    2: {'bordo': -24.50, 'O': 62.68, 'E': 68.32, 'N': -30.32, 'S': -25.18},
    3: {'bordo': -27.50, 'O': 66.68, 'E': 72.32, 'N': -7.82, 'S': -2.18},
}
# la passerella nord della vasca 2: il grigliato e il corrimano basso (misurati sui triangoli della struttura)
PASSERELLA = {'piano': -24.01, 'corrimano': (-23.50, -30.20, 0.022), 'montanti': [61.22 + 0.4055 * k for k in range(22)],
              'r_montante': 0.016}
# [nome, vasca, lato, dove lungo il lato (x per N/S, z per O/E), il mattone a destra (+1) o a sinistra (-1)]
SUL_BORDO = [
    ['balena', 1, 'S', 51.65, 1], ['granchio', 1, 'S', 53.75, -1], ['stella', 1, 'N', 54.15, -1],
    ['tartaruga', 1, 'O', -13.30, 1],
    # (nella vasca 3 lei sale da sud, 2,3 m fuori dal bordo: lì niente; a nord il muro ha la tacca del tubo da x 69,0
    # a 71,5: il bordo c'è da 66,55 a 69,0 e da 71,5 a 72,45)
    ['foca', 3, 'N', 67.60, 1], ['pesce', 3, 'O', -6.30, -1], ['razza', 3, 'E', -4.40, 1], ['cavalluccio', 3, 'N', 71.86, -1],
]
# [nome, x del centro] sulla passerella della vasca 2
SULLA_RINGHIERA = [['pesce_palla', 63.85], ['polpo', 65.05], ['delfino', 66.35], ['squalo', 67.65]]


def base(lato):
    """La base della sagoma sul lato [lato] di una vasca: la normale della faccia (verso l'acqua), la x locale."""
    z = {'S': (0, 0, -1), 'N': (0, 0, 1), 'O': (1, 0, 0), 'E': (-1, 0, 0)}[lato]
    Z = np.array(z, float)
    Y = np.array([0.0, 1.0, 0.0])
    X = np.cross(Y, Z)
    return np.stack([X, Y, Z], 1)        # colonne: x, y, z locali nel mondo


def area(loop):
    a = 0.0
    for i in range(len(loop)):
        x0, y0 = loop[i]
        x1, y1 = loop[(i + 1) % len(loop)]
        a += x0 * y1 - x1 * y0
    return a * 0.5


def intervalli_x(contorno, x):
    """Dove il cartone c'è lungo la verticale x (locale): le y in cui il contorno la taglia, a coppie."""
    ys = []
    n = len(contorno)
    for i in range(n):
        (x0, y0), (x1, y1) = contorno[i], contorno[(i + 1) % n]
        if (x0 - x) * (x1 - x) < 0:
            ys.append(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
    ys.sort()
    return [(ys[i], ys[i + 1]) for i in range(0, len(ys) - 1, 2)]


def guscio(punti):
    """L'involucro convesso (monotone chain), in senso antiorario."""
    P = sorted(set((round(p[0], 7), round(p[1], 7)) for p in punti))
    def giro(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    basso, alto = [], []
    for p in P:
        while len(basso) >= 2 and giro(basso[-2], basso[-1], p) <= 0:
            basso.pop()
        basso.append(p)
    for p in reversed(P):
        while len(alto) >= 2 and giro(alto[-2], alto[-1], p) <= 0:
            alto.pop()
        alto.append(p)
    return basso[:-1] + alto[:-1]


def anello_spago(punti_2d, a_mondo):
    """La legatura: lo spago stretto attorno ai [punti_2d] (nel piano della legatura) a AGIO, arrotondato sugli
    spigoli; [a_mondo] porta un punto (u, v) del piano nel mondo. Torna triangoli (vertici, normali) e il punto più
    lontano dal cartone (per il nodo)."""
    g = guscio(punti_2d)
    d = AGIO + SPAGO[1] * 0.5
    linea, normali = [], []
    n = len(g)
    for i in range(n):
        p = np.array(g[i])
        e_in = p - np.array(g[i - 1])
        e_out = np.array(g[(i + 1) % n]) - p
        e_in /= np.linalg.norm(e_in)
        e_out /= np.linalg.norm(e_out)
        a0 = math.atan2(-e_in[0], e_in[1])
        a1 = math.atan2(-e_out[0], e_out[1])
        giro = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
        passi = int(math.ceil(abs(giro) / math.radians(25))) if abs(giro) > 1e-4 else 0
        for j in range(passi + 1):
            a = a0 + (giro * j / passi if passi else 0.0)
            nn = np.array([math.cos(a), math.sin(a)])
            linea.append(p + nn * d)
            normali.append(nn)
    vert, norm = [], []
    w, s = SPAGO[0] * 0.5, SPAGO[1] * 0.5
    def q(a, b, c, dd, nrm):
        for t in (a, b, c, a, c, dd):
            vert.append(t)
            norm.append(nrm)
    m = len(linea)
    for j in range(m):
        j1 = (j + 1) % m
        fa, fb = linea[j] + normali[j] * s, linea[j1] + normali[j1] * s
        da, db = linea[j] - normali[j] * s, linea[j1] - normali[j1] * s
        nf = normali[j] + normali[j1]
        nf /= np.linalg.norm(nf)
        P = lambda pt, dx: a_mondo(pt, dx)
        nf3 = a_mondo.dir(nf)
        q(P(fa, -w), P(fb, -w), P(fb, w), P(fa, w), nf3)
        q(P(da, -w), P(db, -w), P(db, w), P(da, w), -nf3)
        q(P(da, -w), P(fa, -w), P(fb, -w), P(db, -w), -a_mondo.x)
        q(P(da, w), P(fa, w), P(fb, w), P(db, w), a_mondo.x)
    return vert, norm


class Piano:
    """Il piano di una legatura attorno al corrimano basso: x della sagoma fissa, (u, v) = (y, z) locali della sagoma;
    lo spago è largo lungo la x locale."""
    def __init__(self, R, O, x):
        self.R, self.O, self.xl = R, O, x
        self.x = R[:, 0]
    def __call__(self, uv, dx=0.0):
        return self.O + self.R @ np.array([self.xl + dx, uv[0], uv[1]])
    def dir(self, nuv):
        return self.R @ np.array([0.0, nuv[0], nuv[1]])


def legature(nome, contorno, R, O):
    """Due legature attorno al corrimano basso della ringhiera (a 2,08 m sopra il fondo della vasca), fra i montanti.
    Lo spago passa da un foro del cartone (o da due, se il cartone va oltre il corrimano) e gira attorno al corrimano;
    dove il cartone finisce sotto il corrimano sale dal foro, passa sopra il bordo e lo tiene appeso. Il nodo è dietro.
    Così verso la vasca sporge solo il giro attorno al corrimano, sopra i 2 m: sotto, lo spago sta contro il cartone.
    Torna i fori (rettangoli nel sistema della sagoma) e le mesh dello spago."""
    yr = PASSERELLA['corrimano'][0] - O[1]
    zr = PASSERELLA['corrimano'][1] - O[2]
    r = PASSERELLA['corrimano'][2]
    xs = [p[0] for p in contorno]
    larg = max(xs) - min(xs)
    alto_foro = AGIO + SPAGO[1] + 0.001
    meta = SPAGO[0] * 0.5 + 0.0006
    fori, mesh = [], []
    for frazione in (0.27, 0.73):
        scelto = None
        for spost in [0.0, 0.02, -0.02, 0.04, -0.04, 0.06, -0.06, 0.08, -0.08, 0.1, -0.1, 0.12, -0.12, 0.15, -0.15]:
            x = min(xs) + larg * frazione + spost
            xm = (O + R @ np.array([x, 0, 0]))[0]
            if min(abs(xm - m) for m in PASSERELLA['montanti']) < PASSERELLA['r_montante'] + 0.03:
                continue
            # il cartone ai due lati dello spago: il pezzo più alto, che arrivi almeno a 25 cm
            iv = None
            for dx in (-meta, 0.0, meta):
                pezzi = [(a, b) for a, b in intervalli_x(contorno, x + dx) if b > 0.25]
                if not pezzi:
                    iv = None
                    break
                a, b = max(pezzi, key=lambda t: t[1])
                iv = (a, b) if iv is None else (max(iv[0], a), min(iv[1], b))
            if iv and iv[1] - iv[0] > 0.1:
                scelto = (x, iv)
                break
        if not scelto:
            raise SystemExit('%s: nessun punto per la legatura al %d%%' % (nome, frazione * 100))
        x, (y0, y1) = scelto
        y_alto = None
        if y1 >= yr - r - 0.03:
            y_basso = min(yr - r - 0.012, y1 - 0.03)     # il foro sotto il corrimano
            if y1 >= yr + r + 0.04:
                y_alto = yr + r + 0.012                  # e uno sopra
        else:
            y_basso = y1 - 0.03                          # appesa: il foro 3 cm sotto il bordo, lo spago sale al corrimano
        fori.append([x - meta, y_basso - alto_foro, x + meta, y_basso])
        if y_alto is not None:
            fori.append([x - meta, y_alto, x + meta, y_alto + alto_foro])
        cima = y_alto if y_alto is not None else min(y1, yr)
        punti = [(y_basso, 0.0), (y_basso, SPESSORE), (cima, 0.0), (cima, SPESSORE)]
        punti += [(yr + r / math.cos(math.pi / 24) * math.cos(t), zr + r / math.cos(math.pi / 24) * math.sin(t))
                  for t in [i * 2 * math.pi / 24 for i in range(24)]]
        v, n = anello_spago(punti, Piano(R, O, x))
        nodo = O + R @ np.array([x, y_basso + 0.02, -(AGIO + SPAGO[1] + 0.004)])
        mesh.append({'v': np.round(np.array(v).ravel(), 5).tolist(), 'n': np.round(np.array(n).ravel(), 4).tolist(),
                     'nodo': np.round(nodo, 5).tolist()})
    return fori, mesh


def faccia(contorno, fori):
    """I triangoli della faccia (contorno coi fori) e i bordi: il contorno in senso antiorario, i fori in senso
    orario (così la normale verso fuori di un lato (dx, dy) è sempre (dy, -dx))."""
    out = [list(map(tuple, contorno))]
    if area(out[0]) < 0:
        out[0].reverse()
    for f in fori:
        x0, y0, x1, y1 = f
        out.append([(x0, y0), (x0, y1), (x1, y1), (x1, y0)])     # orario
    tri = tessellate_polygon([[(x, y, 0.0) for x, y in loop] for loop in out])
    piatti = [p for loop in out for p in loop]
    return piatti, [i for t in tri for i in t], out


def mondo(R, O, p):
    return O + R @ np.asarray(p, float)


def genera():
    sagome = json.load(open(os.path.join(QUI, 'sagome.json')))
    out = {'sagome': [], 'puntelli': [], 'mattoni': [], 'legature': []}
    for nome, v, lato, dove, verso_mattone in SUL_BORDO:
        s = sagome[nome]
        V = VASCHE[v]
        R = base(lato)
        Z = R[:, 2]
        # la schiena a DAL_BORDO + SPESSORE dallo spigolo interno, verso fuori (-Z)
        if lato in 'NS':
            O = np.array([dove, V['bordo'], V[lato]]) - Z * (DAL_BORDO + SPESSORE)
        else:
            O = np.array([V[lato], V['bordo'], dove]) - Z * (DAL_BORDO + SPESSORE)
        contorno = s['contorno']
        h = max(p[1] for p in contorno)
        piatti, tri, anelli = faccia(contorno, [])
        out['sagome'].append({'nome': nome, 'vasca': v, 'eta': s['eta'], 'base': np.round(R.T.ravel(), 6).tolist(),
                              'origine': np.round(O, 5).tolist(), 'punti': np.round(piatti, 5).tolist(), 'tri': tri,
                              'anelli': [len(a) for a in anelli], 'uv': s['uv']})
        # il puntello: dalla schiena (a hs) al bordo, 10 cm dietro; il piede piegato sul bordo e il mattone accanto
        hs = min(0.4, 0.42 * h)
        a = np.array([0.0, hs, 0.0])
        b = np.array([0.0, SPESSORE, -0.085])
        lungo = np.linalg.norm(b - a)
        asse = (b - a) / lungo
        cen = (a + b) / 2 - np.cross(np.array([1.0, 0, 0]), asse) * (SPESSORE / 2) * -1
        Ry = asse
        Rz = np.cross(np.array([1.0, 0, 0]), Ry)
        Rl = np.stack([np.array([1.0, 0, 0]), Ry, Rz], 1)
        out['puntelli'].append({'base': np.round((R @ Rl).T.ravel(), 6).tolist(), 'centro': np.round(mondo(R, O, cen), 5).tolist(),
                                'misura': [0.06, round(lungo, 4), SPESSORE]})
        # (il bordo è piano fino a 2 cm dallo spigolo esterno, cioè fino a -0,13 nel sistema della sagoma)
        piede = np.array([0.1 * verso_mattone, SPESSORE * 0.5, -0.085])
        out['puntelli'].append({'base': np.round(R.T.ravel(), 6).tolist(), 'centro': np.round(mondo(R, O, piede), 5).tolist(),
                                'misura': [0.32, SPESSORE, 0.09]})
        mattone = np.array([0.145 * verso_mattone, SPESSORE + 0.0275, -0.085])
        out['mattoni'].append({'base': np.round(R.T.ravel(), 6).tolist(), 'centro': np.round(mondo(R, O, mattone), 5).tolist(),
                               'misura': [0.2, 0.055, 0.08]})
    _, zr, r = PASSERELLA['corrimano']
    for nome, xc in SULLA_RINGHIERA:
        s = sagome[nome]
        R = base('N')                                 # la faccia verso sud, verso la vasca
        Z = R[:, 2]
        O = np.array([xc, PASSERELLA['piano'], zr - r - AGIO - SPESSORE])
        contorno = s['contorno']
        fori, mesh = legature(nome, contorno, R, O)
        piatti, tri, anelli = faccia(contorno, fori)
        out['sagome'].append({'nome': nome, 'vasca': 2, 'eta': s['eta'], 'base': np.round(R.T.ravel(), 6).tolist(),
                              'origine': np.round(O, 5).tolist(), 'punti': np.round(piatti, 5).tolist(), 'tri': tri,
                              'anelli': [len(a) for a in anelli], 'uv': s['uv'], 'fori': np.round(fori, 5).tolist()})
        out['legature'] += mesh
    with open(os.path.join(CARTELLA, 'posa.json'), 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print('%d sagome, %d puntelli, %d mattoni, %d legature' % (len(out['sagome']), len(out['puntelli']), len(out['mattoni']), len(out['legature'])))
    return out


if __name__ == '__main__':
    genera()
