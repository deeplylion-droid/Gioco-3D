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
- ARRETRA (scelta dell'utente del 23 ottobre, "C": il giro di prima, sul posto in mezzo secondo, era goffo):
       arretra verso la porta con quattro passi pesanti senza staccare gli occhi dal giocatore, la bocca
       mezza aperta, le braccia ancora alzate; a metà uno sguardo veloce alla porta;
- GIRO: a 2,4 m dal giocatore sbuffa e si gira verso la porta in 1,1 s con tre passi; il busto resta
       indietro e la testa resta sul giocatore fino agli ultimi gradi, poi si stacca;
- ESITA (= la fine del giro, il nome resta per il gioco): parte la corsa;
- CORSA: parte, corsa pesante e piegata in avanti, il corpo che ondeggia, la coda che fa da
       contrappeso, le braccia che pompano; alla porta si abbassa e passa;
- FINE: oltre la porta (Godot la chiude e lo nasconde).
"""
import json, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler

FPS = 30
# spalle e mani nella posa di riposo (le stesse giunture di mostro_rig.G)
SPALLE = {'L': (0.45, -0.58, 1.45), 'R': (-0.42, -0.52, 1.42)}
MANI_RIPOSO = {'L': (0.71, -1.06, 0.86), 'R': (-0.58, -1.06, 1.44)}
GIOCATORE_Y = -1.55      # la faccia del giocatore, davanti allo squalo
PORTA_Y = 5.95           # la porta tagliafuoco, dietro di lui
# Arretra a passi (uno ogni PASSO_ARRETRA s; i piedi avanzano verso la porta di ARRETRA_PIEDI, uno alla volta:
# il bacino sta a metà tra i due), poi il giro di T_GIRO s, poi la corsa.
PASSO_ARRETRA = 0.5
ARRETRA_PIEDI = (('L', 0.8), ('R', 1.6), ('L', 2.4), ('R', 2.4))
T_GIRO = 1.1
FASI = dict(MINACCIA=2.4, RICHIAMO=5.4, ARRETRA=6.05)
FASI.update(GIRO=round(FASI['ARRETRA'] + PASSO_ARRETRA * len(ARRETRA_PIEDI) + 0.12, 3))
FASI.update(ESITA=round(FASI['GIRO'] + T_GIRO, 3))
FASI.update(CORSA=FASI['ESITA'], PORTA=None, FINE=None)
SBUFFO = round(FASI['GIRO'] - 0.2, 3)    # lo sbuffo prima di girarsi, ancora verso il giocatore
VEL_CORSA = 4.4          # m/s (era 2,8)
ACCEL = 0.8              # secondi per arrivare alla velocità di corsa (0,42: lo scatto da cartone animato)
CADENZA = 3.0            # passi al secondo (era 2,2)


def g_(a):
    """Un istante del giro (0..1 della sua durata)."""
    return FASI['GIRO'] + a * T_GIRO


def passi_arretra():
    """[(lato, inizio, fine, y del piede a fine passo)] dei passi all'indietro."""
    return [(lato, FASI['ARRETRA'] + k * PASSO_ARRETRA, FASI['ARRETRA'] + (k + 1) * PASSO_ARRETRA - 0.04, y)
            for k, (lato, y) in enumerate(ARRETRA_PIEDI)]


def arretrato(t):
    """Di quanto il bacino è andato indietro verso la porta (m): a metà tra i due piedi, liscio a ogni passo."""
    piedi = {'L': 0.0, 'R': 0.0}
    for lato, a, b, y in passi_arretra():
        piedi[lato] = liscio(piedi[lato], y, a, b, t) if t < b else y
        if t < b:
            break
    return 0.5 * (piedi['L'] + piedi['R'])
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
    t = FASI['CORSA']
    while True:
        s, _ = posizione_corsa(t)
        if radice(t)[1] >= PORTA_Y:
            return t
        t += 1.0 / FPS


def _cicli_fiato():
    """Gli istanti del fiato del suono squalo_minaccia (assets_src/audio/genera_squalo.py: gli stessi cicli,
    con lo stesso seme), nel tempo della scena: [(inizio, durata, 'insp' | 'esp')]."""
    rng = np.random.default_rng(2110)
    inizio = 0.8                            # MINACCIA_INIZIO del suono
    dur = FASI['RICHIAMO'] - inizio + 0.4
    out = []
    t = 0.05
    while t < dur - 0.6:
        lungo = 1.2 if t < 1.4 else 0.85
        out.append((inizio + t, lungo * 0.45, 'insp'))
        out.append((inizio + t + lungo * 0.45, lungo * 0.55, 'esp'))
        t += lungo + rng.uniform(0.02, 0.12)
    return out


CICLI_FIATO = _cicli_fiato()


def fiato_mascella(t):
    """Da -1 (inspira: la mascella si stringe) a 1 (espira: si apre), liscio."""
    for t0, d, tipo in CICLI_FIATO:
        if t0 <= t < t0 + d:
            u = (t - t0) / d
            return math.sin(math.pi * u) * (1.0 if tipo == 'esp' else -0.6)
    return 0.0


def morso(dt):
    """Quanto è chiusa la mascella in un morso (0..1), dt secondi dallo scatto della testa: si chiude in 0,12 s
    (chiusa da + 0,06 a + 0,14 s), si riapre in 0,4 s."""
    if dt < -0.06 or dt > 0.55:
        return 0.0
    if dt < 0.06:
        return liscio(0.0, 1.0, -0.06, 0.06, dt)
    if dt < 0.14:
        return 1.0
    return liscio(1.0, 0.0, 0.14, 0.55, dt)


def radice(t):
    """(x, y, yaw) della radice: fermo, arretra a passi, il giro di 180°, la corsa."""
    yaw = chiavi(t, [(g_(0.0), 0.0), (g_(1.0), math.pi)])
    # mentre minaccia si sporge in avanti e indietro di qualche centimetro
    avanti = 0.0
    if t < FASI['RICHIAMO']:
        avanti = chiavi(t, [(0.0, 0.0), (FASI['MINACCIA'], -0.10), (FASI['MINACCIA'] + 0.6, -0.04),
                            (FASI['MINACCIA'] + 1.4, -0.12), (FASI['MINACCIA'] + 2.0, -0.06), (FASI['RICHIAMO'], -0.08)])
    else:
        avanti = chiavi(t, [(FASI['RICHIAMO'], -0.08), (FASI['ARRETRA'], 0.0)])
    passo = arretrato(t)
    # girandosi va ancora un poco verso la porta
    passo += chiavi(t, [(g_(0.1), 0.0), (g_(1.0), 0.3)])
    s, _ = posizione_corsa(t)
    return 0.0, avanti + passo + s, yaw


# ---------------------------------------------------------------- appoggi dei piedi
class Piedi:
    """Dove sta ogni caviglia in ogni istante (spazio del modello), e quanto è alzata: fermi da piantati,
    quattro passi all'indietro, tre passi per girarsi, poi la corsa a passi alternati con una fase di volo."""

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
        # fermi fino al primo passo all'indietro; poi i passi: il piede si alza, va verso la porta e si pianta
        # (gli appoggi: dalla fine del passo fino all'inizio del passo dopo dello stesso piede)
        inizio = {'L': 0.0, 'R': 0.0}
        dove = {s: self.fermo[s].copy() for s in 'LR'}
        for lato, a, b, y in passi_arretra():
            self.appoggi[lato].append((inizio[lato], a, dove[lato].copy(), 0.0))
            dove[lato] = self.fermo[lato] + Vector((0.0, y, 0.0))
            inizio[lato] = b
        # il giro: tre passi (L, R, L) mentre la radice gira di 180°; il primo appoggio di ognuno finisce quando
        # il piede si alza per il giro
        alza = {'L': g_(0.12), 'R': g_(0.42)}
        for s in 'LR':
            self.appoggi[s].append((inizio[s], alza[s], dove[s].copy(), 0.0))
        for k, (s, t0, fine) in enumerate((('L', g_(0.33), g_(0.70)), ('R', g_(0.66), FASI['CORSA'] + 0.05),
                                           ('L', g_(0.98), FASI['CORSA'] - 0.02))):
            x, y, yaw = radice(min(t0 + 0.12, g_(1.0)))
            self.appoggi[s].append((t0, fine, self._mondo(self.fermo[s], x, y, yaw), yaw))
        # la corsa: passi alternati, ogni appoggio centrato sotto l'anca a metà appoggio
        t = FASI['CORSA'] + 0.12
        lato = 'L'
        while t < FASI['CORSA'] + 6.0:
            _, v = posizione_corsa(t)
            v = max(v, 0.9)
            appoggio = min(0.30, 0.70 / v)
            tm = t + appoggio / 2
            x, y, yaw = radice(tm)
            off = Vector((0.26 if lato == 'L' else -0.26, 0.0, 0.20))
            pos = self._mondo(off, x, y, yaw)
            self.appoggi[lato].append((t, t + appoggio, pos, yaw))
            t += 1.0 / CADENZA * (1.0 if v > 2.5 else 1.2)
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
    corsa = liscio(0.0, 1.0, C - 0.12, C + 0.3, t)
    _, v = posizione_corsa(t)
    fase = (t - C) * CADENZA * math.pi            # mezzo giro per passo
    # --- quanto è chino: addosso al giocatore (testa giù), poi si raddrizza al richiamo
    A = FASI['ARRETRA']
    # arretrando resta chino (mezzo), come una bestia che non ti perde di vista; si raddrizza nel giro
    chino = chiavi(t, [(0.0, 1.0), (R + 0.05, 1.0), (R + 0.45, 0.25), (A + 0.3, 0.55), (G, 0.5), (g_(0.6), 0.2),
                       (C, 0.35)])
    abbassa = 0.14 * chino
    # il peso: a ogni piede che si pianta (arretra e giro) il bacino scende e risale
    for lato, a, b, y in passi_arretra():
        abbassa += 0.045 * math.exp(-((t - b - 0.06) / 0.11) ** 2)
    for tp_ in (g_(0.33), g_(0.66), g_(0.98)):
        abbassa += 0.035 * math.exp(-((t - tp_ - 0.1) / 0.1) ** 2)
    # alla porta: si abbassa ancora per passare sotto l'architrave
    abbassa += liscio(0.0, 0.16, tp - 0.32, tp - 0.10, t) - liscio(0.0, 0.16, tp + 0.16, tp + 0.38, t)
    # la corsa: il bacino scende a ogni appoggio e risale nel volo (poco: la corsa è fluida, non saltellata)
    if corsa > 0:
        abbassa += corsa * (0.03 + 0.022 * math.cos(2 * fase))
    p['_abbassa'] = abbassa
    # --- respiro (sempre): il petto si gonfia
    resp = math.sin(t * 2 * math.pi * (0.55 if t < R else 0.9))
    # --- bacino e busto
    # nella corsa più piegato in avanti (deciso) e con meno rollio (fluido)
    p['bacino'] = [('x', 5 * chino + 9 * corsa), ('z', 4 * corsa * math.sin(fase)),
                   ('y', 2.5 * corsa * math.sin(fase))]
    # nell'esitazione si volta indietro con tutto il busto, non solo con la testa: dietro di lui il
    # giocatore deve vedergli il muso e l'occhio
    # nel giro il busto resta indietro e la testa resta sul giocatore (girano al contrario della radice) finché
    # metà giro passato; poi si staccano piano (0,8 s: legati all'angolo della radice scattavano di 150° in 0,2 s)
    # e raggiungono il corpo nei primi passi della corsa. tiene: quanto lo tiene d'occhio
    yaw_g = math.degrees(radice(t)[2])
    tiene = 1.0 - liscio(0.0, 1.0, g_(0.55), C + 0.6, t)
    torsione = -yaw_g * tiene * 0.4 / 58.0
    p['spina'] = [('x', 5 * chino + 9 * corsa + 1.5 * resp), ('z', -4 * corsa * math.sin(fase) + 26 * torsione)]
    p['petto'] = [('x', 4 * chino + 2 * corsa - 2 * resp), ('z', -6 * corsa * math.sin(fase) + 32 * torsione)]
    # alla porta il busto si piega di più
    p['spina'].append(('x', liscio(0, 10, tp - 0.32, tp - 0.10, t) - liscio(0, 10, tp + 0.16, tp + 0.38, t)))
    # --- collo e testa: giù verso la faccia del giocatore, poi lo scatto verso il richiamo (dietro a
    # sinistra, sopra la spalla), il giro, lo sguardo indietro al giocatore nell'esitazione
    # (lo scatto dura mezzo secondo: più svelto la pelle della bocca si strappava tra un fotogramma e
    # l'altro e nel gioco sembrava un salto)
    # al richiamo la testa scatta verso il suono (dietro, a sinistra), poi torna sul giocatore e arretra; a
    # metà uno sguardo veloce alla porta; nel giro resta sul giocatore (al contrario della radice)
    guarda = chiavi(t, [(R + 0.08, 0.0), (R + 0.55, 75.0), (A - 0.1, 75.0), (A + 0.4, 0.0), (A + 0.95, 0.0),
                        (A + 1.15, 40.0), (A + 1.4, 40.0), (A + 1.65, 0.0)])
    guarda += -yaw_g * tiene * 0.6
    alza = chiavi(t, [(R + 0.08, 0.0), (R + 0.55, -18.0), (A + 0.4, -6.0), (G, -6.0), (C, 0.0)])
    scatti = 0.0
    if M < t < R:
        # piccoli scatti in avanti della testa, come per mordere
        for tc in (M + 0.7, M + 1.6, M + 2.5):
            scatti += math.exp(-((t - tc) / 0.09) ** 2) * 7.0
    tremito = rumore(t, 3.0, 1.0) * (1.0 if t < R else 0.4)
    p['collo'] = [('x', 6 * chino + 0.5 * tremito - 4 * corsa), ('z', guarda * 0.45), ('x', alza * 0.5)]
    # con la bocca spalancata il muso si alza: l'apertura guarda in avanti, verso la faccia del giocatore
    muso_su = chiavi(t, [(0.0, 0.0), (1.2, -4.0), (M, -24.0), (R + 0.05, -24.0), (R + 0.50, 0.0)])
    p['testa'] = [('x', 4 * chino + muso_su + scatti - 6 * corsa - 3 * corsa * math.cos(2 * fase)),
                  ('z', guarda * 0.55 + 1.5 * tremito), ('x', alza * 0.5), ('y', 6 * chino * math.sin(t * 0.9))]
    # --- mascella: si apre piano al risveglio, spalancata nella minaccia, mezza chiusa al richiamo, sbuffo
    # nell'esitazione, ansima nella corsa
    # arretrando la bocca mezza aperta (ringhia); lo sbuffo prima del giro; nel giro si chiude
    apri = chiavi(t, [(0.0, 8.0), (1.2, 12.0), (M, 52.0), (R + 0.05, 55.0), (R + 0.50, 30.0), (A + 0.3, 24.0),
                      (SBUFFO - 0.12, 20.0), (SBUFFO + 0.05, 34.0), (SBUFFO + 0.35, 14.0), (g_(0.6), 10.0),
                      (C, 14.0)])
    # il respiro della mascella, a tempo con il fiato del suono (squalo_minaccia, dal suo inizio a 0,8 s): si
    # apre un poco nell'espirazione e si richiude nell'inspirazione
    if t < R + 0.3:
        apri += fiato_mascella(t) * (3.0 if t < M else 6.0) * (1.0 if t < R else (R + 0.3 - t) / 0.3)
    # i tre morsi (riscontro dell'utente del 23 ottobre: "gli animerei anche la bocca"): a ogni scatto della
    # testa la mascella si chiude di colpo, chiusa quando suonano i denti (squalo_denti a scatto + 0,08 s,
    # lo schiocco del suono a + 0,12 s), poi si riapre più piano
    if M < t < R:
        for tc in (M + 0.7, M + 1.6, M + 2.5):
            apri -= 46.0 * morso(t - tc)
    if corsa > 0:
        apri += corsa * 6.0 * (0.5 + 0.5 * math.sin(2 * fase + 1.0))
    p['mascella'] = [('_apri', apri)]
    # --- braccia: nella minaccia aperte ai lati della faccia del giocatore, gli artigli in avanti; al
    # richiamo si fermano; nella corsa pompano (opposte alle gambe) con il gomito piegato
    # arretrando le braccia restano mezze alzate, gli artigli verso il giocatore; giù nel giro
    braccia = chiavi(t, [(0.0, 1.0), (R + 0.1, 1.0), (A + 0.5, 0.55), (G, 0.5), (g_(0.7), 0.0)])
    # le mani con una IK (in mostro_rig.cuoci): qui dove vanno, rispetto alla spalla, nello spazio della
    # radice prima del giro (lo squalo guarda -Y). A riposo come nel modello; nella minaccia ai lati della
    # faccia del giocatore, gli artigli aperti; nella corsa pompano davanti al petto, opposte alle gambe.
    oscilla = math.sin(fase) if corsa > 0 else 0.0
    for s, segno in (('L', 1.0), ('R', -1.0)):
        spalla = Vector(SPALLE[s])
        riposo = Vector(MANI_RIPOSO[s]) - spalla
        minaccia = Vector((0.40 * segno, GIOCATORE_Y + 0.42, 1.12 + (0.08 if s == 'R' else 0.0))) - spalla
        minaccia += Vector((0.0, 0.03, 0.03)) * rumore(t, 1.7, 2.0 + segno)
        # nella corsa la mano che pende si tiene su, davanti al petto (non deve strisciare a terra)
        su = Vector((-0.05, -0.10, 0.42)) if s == 'L' else Vector((0.0, 0.0, -0.05))
        corsa_off = riposo + su + Vector((0.0, -0.18 * oscilla * segno, 0.07 * oscilla * segno))
        resto = max(0.0, 1.0 - braccia - corsa)
        p['_mano.' + s] = riposo * resto + minaccia * braccia + corsa_off * corsa
    p['mano.L'] = [('x', -10 * braccia + 4 * rumore(t, 2.0, 3.0) * braccia)]
    p['mano.R'] = [('x', 4 * rumore(t, 2.2, 5.0) * braccia)]
    # --- coda: ondeggia lenta, nella corsa fa da contrappeso (in ritardo sul bacino)
    amp = 6 + 14 * corsa
    for k, b in enumerate(('coda1', 'coda2', 'coda3')):
        # quando si volta indietro la coda va dall'altra parte (contrappeso; e non copre il muso)
        p[b] = [('z', amp * math.sin((fase if corsa > 0 else t * 1.3) - 0.9 * (k + 1)) * (1 + 0.3 * k)
                 + 25 * torsione),
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
    return dict(fps=FPS, durata=round(tp + 0.9, 3), porta=round(tp, 3), passi=sorted(passi), sbuffo=SBUFFO,
                ringhio=round(FASI['ARRETRA'] + 0.1, 3),
                giocatore_y=GIOCATORE_Y, porta_y=PORTA_Y, **{k.lower(): v for k, v in FASI.items() if v is not None})
