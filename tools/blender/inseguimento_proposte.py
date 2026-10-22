"""Proposte per l'inseguimento I1 e il finale SB1 (18 ottobre): solo proposte, nel gioco non entra niente finché
l'utente non sceglie.

Dal GDD: "Inseguimento I1: scivolata veloce negli scivoli con l'acqua che scorre. Ai bivi si colpisce la
paratia giusta; ci si gira e la si respinge col getto. Alla fine una grata di sicurezza cala davanti a lei."
e "SB1: l'ultima immagine del capitolo, lei che sbuca dal bordo".
Si parte dalla bocca del tubo dell'inseguimento sul muro est della sala della torre (in fondo alla discesa,
(40, 15, -18,4) in coordinate di Blender) e si va dietro quel muro, più giù nello scafo.

Lei è alta 4,5 m (assets/models/medusa): nei tubi non ci entra. Nelle due versioni ci si salva dentro gli
scivoli e lei raggiunge il giocatore dove il percorso si apre: le vasche dei bivi (A) o il canale aperto (B).

Versioni (GLB in godot/proposte/inseguimento/, fuori dall'export del gioco; luci e posizioni di lei in
inseguimento_<v>_luci.json, il percorso per le viste in inseguimento_<v>_percorso.json):
  A  "Le condotte": la sala delle condotte dietro la torre, allagata; tre tubi grandi tra tre vasche di
     smistamento sospese sul vuoto; a ogni vasca due paratie (quella giusta ha la lampada verde e l'acqua
     che filtra sotto), la sbagliata porta a una vasca di scolo senza uscita; l'ultimo tubo scende a spirale
     attorno a un serbatoio fino al bacino di scarico, dove la grata cala sulla bocca del tubo.
  B  "Le rapide": la giostra delle rapide abbandonata (acqua bianca tra scogli finti, non il fiume lento), un canale aperto largo 3,2 m con l'acqua che corre,
     che scende a salti tra scogli finti; ai tre bivi due paratie a ghigliottina sopra il canale (si colpisce
     il bersaglio di quella giusta e si alza); lei nuota nel canale dietro di te; il canale finisce nella
     laguna d'arrivo, la saracinesca cala sull'arco del canale.

Coordinate di Blender (Z in alto, metri); in Godot (x, z, -y).
Uso: /home/user/tools/blender-venv/bin/python tools/blender/inseguimento_proposte.py A|B [--gioco] [--blend file.blend]
--gioco (solo A, la versione scelta dall'utente il 19 ottobre): la sala vera del gioco in
godot/assets/ambiente/inseguimento/ (vedi GIOCO).
"""
import json, math, os, random, sys
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import bpy  # noqa: E402
from mathutils import Vector, Matrix  # noqa: E402
import ambiente_kit as K  # noqa: E402
import ambiente_sala as S  # noqa: E402
import torre_proposte as P  # noqa: E402
import torre_a as TA  # noqa: E402

USCITA = os.path.normpath(os.path.join(QUI, '..', '..', 'godot', 'proposte', 'inseguimento'))
GIOCO_USCITA = os.path.normpath(os.path.join(QUI, '..', '..', 'godot', 'assets', 'ambiente', 'inseguimento'))
BOCCA = Vector((40.0, 17.4, -18.4))      # la bocca del tubo dell'inseguimento sul muro est della torre
R_TUBO = 0.8                             # il tubo dell'inseguimento (come la bocca)
X0 = 40.0                                # il muro in comune con la sala della torre
# Nel gioco (--gioco) la sala sta nel mondo accanto alla torre, quindi:
# - il muro ovest è in X0_GIOCO, non nel piano del muro est della torre (x 40: due facce nello stesso piano
#   lampeggiano) e oltre i tubi della torre che entrano 30 cm nel muro;
# - il primo tubo continua quello della bocca della torre (che finisce in x 41);
# - struttura e grigliati hanno le collisioni ("-col"), i prop una scatola convessa;
# - i pannelli delle paratie e le sbarre della grata sono nodi a parte (si muovono), le paratie aperte in su
#   e la grata alzata;
# - inseguimento_gioco.json: linee dei tubi, vasche, paratie, grata, checkpoint, pozzo di SB1, scale, uscita.
GIOCO = False
X0_GIOCO = 40.4
BOCCA_TORRE = [(37.6, 17.4, -18.15), (38.8, 17.4, -18.38), (41.0, 17.4, -18.6)]   # come in torre_a.py (GIOCO), nel verso della discesa
MOBILI = []                              # i pezzi che si muovono (pannelli delle paratie, sbarre della grata)
GIOCO_DATI = dict(paratie=[], grata=None, tubi={}, scale=[])


# --- pezzi comuni -----------------------------------------------------------------------------------

def curva_in_discesa(ctrl, passo=0.3):
    """Come curva(), ma la quota scende sempre: x e y dalla Catmull-Rom, z interpolata in modo monotono
    (PCHIP) lungo la lunghezza, tra le quote dei punti di controllo (che devono scendere). Nel gioco un
    avvallamento in un tubo ferma chi scivola."""
    from scipy.interpolate import PchipInterpolator
    zs = [p[2] for p in ctrl]
    assert all(b_ < a_ for a_, b_ in zip(zs, zs[1:])), f'quote dei punti che non scendono: {zs}'
    pts = curva(ctrl, passo)
    s_ = [0.0]
    for i in range(1, len(pts)):
        s_.append(s_[-1] + (pts[i] - pts[i - 1]).xy.length)
    # la lunghezza (in pianta) dove passano i punti di controllo: il punto della curva più vicino a ognuno
    sc = [min(range(len(pts)), key=lambda i: (pts[i].xy - Vector(c[:2])).length) for c in ctrl]
    sc[0], sc[-1] = 0, len(pts) - 1
    f = PchipInterpolator([s_[i] for i in sc], zs)
    return [Vector((q.x, q.y, float(f(s_[i])))) for i, q in enumerate(pts)]


def curva(ctrl, passo=0.35):
    """Punti fitti (Catmull-Rom) lungo i punti di controllo."""
    P_ = [Vector(p) for p in ctrl]
    E = [P_[0] + (P_[0] - P_[1])] + P_ + [P_[-1] + (P_[-1] - P_[-2])]
    out = []
    for i in range(1, len(E) - 2):
        n = max(2, int((E[i + 1] - E[i]).length / passo))
        for k in range(n):
            t = k / n
            p0, p1, p2, p3 = E[i - 1], E[i], E[i + 1], E[i + 2]
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P_[-1])
    return out


def guscio(c, x1, y0, y1, z0, z1, buco=None, porta=None, fossa=None):
    """La sala dietro la torre: muri di lamiera e cemento dello scafo con le costole, soffitto con le travi,
    pavimento. Nel muro ovest (x = X0) il buco della bocca; porta = (y, z) della porta d'uscita nel muro ovest;
    fossa = (x0, y0, x1, y1, profondità, quota del bordo): il pozzo di scarico nel pavimento (dove lei si nasconde per SB1)."""
    if fossa is None:
        c.faccia_griglia([(X0, y0, z0), (x1, y0, z0), (x1, y1, z0), (X0, y1, z0)], 'pavimento', 2.0)
    else:
        fx0, fy0, fx1, fy1, fp, zb = fossa
        for (a0, b0, a1, b1) in ((X0, y0, fx0, y1), (fx1, y0, x1, y1), (fx0, y0, fx1, fy0), (fx0, fy1, fx1, y1)):
            c.faccia_griglia([(a0, b0, z0), (a1, b0, z0), (a1, b1, z0), (a0, b1, z0)], 'pavimento', 2.0)
        zf = z0 - fp
        c.faccia_griglia([(fx0, fy0, zf), (fx1, fy0, zf), (fx1, fy1, zf), (fx0, fy1, zf)], 'vasca', 1.0)
        for (p, q) in (((fx1, fy0), (fx0, fy0)), ((fx0, fy1), (fx1, fy1)), ((fx0, fy0), (fx0, fy1)), ((fx1, fy1), (fx1, fy0))):
            c.faccia_griglia([(p[0], p[1], zf), (q[0], q[1], zf), (q[0], q[1], z0), (p[0], p[1], z0)], 'vasca', 1.0)
        # la grata di scarico sul fondo e il bordo piastrellato che esce dall'acqua (con la fascia gialla)
        c.scatola(((fx0 + fx1) / 2 - 0.5, (fy0 + fy1) / 2 - 0.5, zf), ((fx0 + fx1) / 2 + 0.5, (fy0 + fy1) / 2 + 0.5, zf + 0.06), 'metallo')
        for (a, b) in (((fx0 - 0.25, fy0 - 0.25), (fx1 + 0.25, fy0)), ((fx0 - 0.25, fy1), (fx1 + 0.25, fy1 + 0.25)),
                       ((fx0 - 0.25, fy0), (fx0, fy1)), ((fx1, fy0), (fx1 + 0.25, fy1))):
            c.scatola((a[0], a[1], z0 - 0.3), (b[0], b[1], zb - 0.06), 'vasca_bimbi', smusso=0.02)
            c.scatola((a[0], a[1], zb - 0.06), (b[0], b[1], zb), 'giallo_sicurezza')
    c.faccia_griglia([(X0, y1, z1), (x1, y1, z1), (x1, y0, z1), (X0, y0, z1)], 'stanza_soffitto', 4.0)
    for (p, q) in (((x1, y0), (X0, y0)), ((X0, y1), (x1, y1)), ((x1, y1), (x1, y0))):
        c.faccia_griglia([(p[0], p[1], z0), (q[0], q[1], z0), (q[0], q[1], z0 + 2.0), (p[0], p[1], z0 + 2.0)], 'vasca', 1.0)
        c.faccia_griglia([(p[0], p[1], z0 + 2.0), (q[0], q[1], z0 + 2.0), (q[0], q[1], z1), (p[0], p[1], z1)], 'stanza_muro', 2.0)
    # muro ovest: a pezzi attorno al buco della bocca e alla porta
    fori = []
    if buco is not None:
        fori.append((buco.y - 1.1, buco.y + 1.1, buco.z - 1.1, buco.z + 1.1))
    if porta is not None:
        fori.append((porta[0] - 0.75, porta[0] + 0.75, porta[1], porta[1] + 2.2))
    ys = sorted({y0, y1} | {f[0] for f in fori} | {f[1] for f in fori})
    for ya, yb in zip(ys[:-1], ys[1:]):
        zs = [z0, z1]
        for f in fori:
            if f[0] <= ya and yb <= f[1]:
                zs += [f[2], f[3]]
        zs = sorted(zs)
        for za, zb in zip(zs[::2], zs[1::2]):
            if zb - za > 0.01:
                c.faccia_griglia([(X0, yb, za), (X0, ya, za), (X0, ya, zb), (X0, yb, zb)], 'stanza_muro', 2.0)
    # costole dello scafo sui muri nord e sud e travi del soffitto
    for x in range(int(X0) + 4, int(x1), 4):
        for y, s in ((y0, 1), (y1, -1)):
            c.scatola((x - 0.18, min(y, y + s * 0.4), z0), (x + 0.18, max(y, y + s * 0.4), z1 - 0.4), 'metallo_grigio')
        c.scatola((x - 0.2, y0, z1 - 0.6), (x + 0.2, y1, z1), 'metallo_grigio')


def anello_tubo(c, p, d, r, mat='metallo'):
    c.anello(p, d, r + 0.02, r + 0.11, 0.18, mat, seg=20)


def appendi_tubo(c, pts, r, soffitto, ogni=3.5, pedane=(), mat='metallo', altri=()):
    """Regge un tubo dal soffitto (o dal fondo di una pedana sopra): fascia attorno al tubo ogni `ogni` metri,
    due tiranti dai lati fino al soffitto, con la piastra. altri = linee di altri tubi (e del tubo stesso): un
    tirante che passerebbe dentro un tubo non si mette (nel gioco ci si sbatterebbe contro scivolando)."""
    s = 0.0
    prossimo = ogni * 0.5
    for i in range(1, len(pts) - 1):
        s += (pts[i] - pts[i - 1]).length
        if s < prossimo:
            continue
        prossimo += ogni
        p = pts[i]
        d = (pts[i + 1] - pts[i - 1]).normalized()
        lat = Vector((-d.y, d.x, 0)).normalized()
        anello_tubo(c, p, d, r, mat)
        for sg in (-1, 1):
            q = p + lat * (sg * (r + 0.12))
            top = soffitto
            for (x0, y0, x1, y1, zp) in pedane:
                if x0 < q.x < x1 and y0 < q.y < y1 and q.z < zp < top:
                    top = zp - 0.3
            if any((Vector((t.x, t.y)) - q.xy).length < r + 0.2 and t.z > q.z - r for linea in altri for t in linea
                   if (t - p).length > 1.5):
                continue
            c.cilindro(q, Vector((q.x, q.y, top)), 0.035, 'metallo', seg=8)
            c.scatola((q.x - 0.1, q.y - 0.1, top - 0.03), (q.x + 0.1, q.y + 0.1, top + 0.02), 'metallo')
            c.cilindro(q, p + lat * (sg * (r + 0.02)), 0.03, 'metallo', seg=6)


def controlla_tubi(oggetti, linee, r):
    """Nel gioco dentro i tubi non deve entrare niente della struttura (ci si sbatterebbe scivolando): i
    vertici degli oggetti a meno di r dalla linea di un tubo, lontano dai suoi capi (lì ci sono le vasche).
    Restituisce [(oggetto, punto)]."""
    import numpy as np
    trovati = []
    L = [np.array([list(q) for q in linea]) for linea in linee]
    for o in oggetti:
        if o.type != 'MESH':
            continue
        M = np.array(o.matrix_world)
        V = np.array([v.co for v in o.data.vertices])
        if len(V) == 0:
            continue
        V = (np.c_[V, np.ones(len(V))] @ M.T)[:, :3]
        for P_ in L:
            lo, hi = P_.min(0) - r, P_.max(0) + r
            sel = V[np.all((V > lo) & (V < hi), axis=1)]
            corpo = P_[4:-4] if len(P_) > 10 else P_[:0]
            for v in sel:
                d = np.linalg.norm(corpo - v, axis=1) if len(corpo) else np.array([9.0])
                if d.min() < r - 0.03:
                    trovati.append((o.name, tuple(round(x, 2) for x in v)))
                    break
    return trovati


def gambe(c, x0, y0, x1, y1, z_alto, z_basso, mat='metallo_grigio', r=0.16):
    """Quattro colonne dagli angoli fino a terra, con le croci sui lati."""
    angoli = [(x0 + 0.2, y0 + 0.2), (x1 - 0.2, y0 + 0.2), (x1 - 0.2, y1 - 0.2), (x0 + 0.2, y1 - 0.2)]
    for (x, y) in angoli:
        c.cilindro((x, y, z_basso), (x, y, z_alto), r, mat, seg=12)
        c.anello((x, y, z_basso), (0, 0, 1), 0.0, r + 0.2, 0.05, 'metallo', seg=12)
    passo = 3.0
    for i in range(4):
        a, b = angoli[i], angoli[(i + 1) % 4]
        z = z_alto - 0.3
        while z - passo > z_basso + 0.3:
            c.cilindro((a[0], a[1], z), (b[0], b[1], z - passo), 0.05, 'metallo', seg=6)
            c.cilindro((b[0], b[1], z), (a[0], a[1], z - passo), 0.05, 'metallo', seg=6)
            c.cilindro((a[0], a[1], z - passo), (b[0], b[1], z - passo), 0.07, mat, seg=8)
            z -= passo


def vasca_sospesa(c, x0, y0, x1, y1, z, z_terra, nome, alto=1.1, bocche=None):
    """La vasca di smistamento: bordo alto 1,1 m, su un piano di lamiera con le travi e quattro gambe.
    Nel gioco (bocche) i muri sono aperti dove passano i tubi."""
    c.scatola((x0 - 0.15, y0 - 0.15, z - 0.35), (x1 + 0.15, y1 + 0.15, z), 'metallo_grigio')
    for x in (x0 + 0.4, (x0 + x1) / 2, x1 - 0.4):
        c.scatola((x - 0.1, y0 - 0.1, z - 0.7), (x + 0.1, y1 + 0.1, z - 0.35), 'gioco_giallo')
    gambe(c, x0, y0, x1, y1, z - 0.35, z_terra)
    if bocche:
        return vasca_bocche(c, x0, y0, x1, y1, z, alto, nome, bocche)
    return P.vasca(c, x0, y0, x1, y1, z, alto=alto, nome_acqua=nome)


def vasca_bocche(c, x0, y0, x1, y1, z, alto, nome_acqua, bocche, largo=1.8):
    """Come P.vasca, ma con i muri aperti dove entrano o escono i tubi (nel gioco ci si passa):
    bocche = [(lato 'n'|'s'|'e'|'o', coordinata lungo il lato[, larghezza])], aperture larghe `largo` (o la loro)
    per tutta l'altezza (i tubi che passano di sbieco ne vogliono una più larga)."""
    P.OSTACOLI.append((x0, y0, x1, y1, z + alto))
    sp = 0.18
    lati = {'s': ('x', y0, y0 + sp), 'n': ('x', y1 - sp, y1), 'o': ('y', x0, x0 + sp), 'e': ('y', x1 - sp, x1)}
    for lato, (asse, a, b) in lati.items():
        lo, hi = (x0, x1) if asse == 'x' else (y0, y1)
        tagli = sorted((b_[1] - (b_[2] if len(b_) > 2 else largo) / 2, b_[1] + (b_[2] if len(b_) > 2 else largo) / 2)
                       for b_ in bocche if b_[0] == lato)
        pezzi, cur = [], lo
        for (t0, t1) in tagli:
            pezzi.append((cur, t0))
            cur = t1
        pezzi.append((cur, hi))
        for (u0, u1) in pezzi:
            if u1 - u0 < 0.01:
                continue
            if asse == 'x':
                c.scatola((u0, a, z), (u1, b, z + alto), 'vasca_bimbi', smusso=0.02)
            else:
                c.scatola((a, u0, z), (b, u1, z + alto), 'vasca_bimbi', smusso=0.02)
    c.scatola((x0 + sp, y0 + sp, z), (x1 - sp, y1 - sp, z + 0.02), 'vasca')
    return P.acqua_piano(nome_acqua, x0 + sp, y0 + sp, x1 - sp, y1 - sp, z + alto - 0.12)


def paratia(c, centro, n, giusta, luci, aperta=False, largo=1.9, alto=1.9):
    """Paratia a ghigliottina davanti a una bocca: due montanti gialli, la trave a strisce, il pannello
    d'acciaio col bersaglio tondo giallo e nero (si colpisce col getto), la lampada di servizio sopra (verde
    sulla giusta, rossa guasta sulla sbagliata) e, sotto la giusta, il velo d'acqua che filtra."""
    n = Vector((n[0], n[1], 0)).normalized()
    lat = Vector((-n.y, n.x, 0))
    base = Vector(centro) - Vector((0, 0, alto / 2))
    top = base.z + alto * 2 + 0.3
    for sg in (-1, 1):
        q = base + lat * (sg * (largo / 2 + 0.12))
        c.scatola_assi(Vector((q.x, q.y, (base.z + top) / 2)), [n, lat, Vector((0, 0, 1))], (0.1, 0.1, (top - base.z) / 2), 'giallo_sicurezza')
    # nel gioco la trave a strisce gialle e nere vuol dire "chiuso" (come nella torre, scelta dell'utente del 22
    # ottobre): sulla paratia giusta è liscia, gialla come i montanti
    trave = 'giallo_sicurezza' if (GIOCO and giusta) else 'strisce'
    c.scatola_assi(Vector((base.x, base.y, top + 0.15)), [n, lat, Vector((0, 0, 1))], (0.14, largo / 2 + 0.3, 0.15), trave)
    zp = base.z + alto / 2 + (alto + 0.05 if aperta else 0.0)
    pann = Vector((base.x, base.y, zp)) - n * 0.05
    cp = K.Costruttore(c.mats) if GIOCO else c          # nel gioco il pannello è un nodo a parte
    cp.scatola_assi(pann, [n, lat, Vector((0, 0, 1))], (0.05, largo / 2, alto / 2), 'acciaio_portone')
    for k in (-1, 1):       # nervature
        cp.scatola_assi(pann + Vector((0, 0, k * alto * 0.3)) - n * 0.06, [n, lat, Vector((0, 0, 1))], (0.03, largo / 2, 0.05), 'metallo_grigio')
    # bersaglio: tre anelli concentrici, verso la vasca
    t = pann - n * 0.1 + Vector((0, 0, alto * 0.22))      # in alto sul pannello: fuori dall'acqua
    t_centro = Vector(t)
    for r_, m in ((0.42, 'giallo_sicurezza'), (0.3, 'nero_opaco'), (0.18, 'giallo_sicurezza'), (0.08, 'nero_opaco')):
        cp.disco(t, -n, r_, m, seg=28)
        t = t - n * 0.004
    if GIOCO:
        k_ = len(GIOCO_DATI['paratie'])
        ob = S.con_perno(cp.crea(f'ins_paratia_{k_}'), tuple(pann))
        K.collisione_scatola(f'ins_paratia_{k_}_col', (-0.11, -largo / 2, -alto / 2), (0.11, largo / 2, alto / 2), padre=ob)
        # la scatola di collisione segue gli assi del pannello: n è sempre lungo x o y
        if abs(n.y) > 0.5:
            col = ob.children[-1]
            col.data.transform(Matrix.Rotation(math.pi / 2, 4, 'Z'))
        MOBILI.append(ob)
        GIOCO_DATI['paratie'].append(dict(nodo=ob.name, giusta=giusta, pannello=list(pann), verso=[n.x, n.y, 0.0],
                                          bersaglio=list(t_centro), corsa=alto + 0.05, largo=largo, alto=alto))
    # lampada di servizio sopra la trave
    lamp = Vector((base.x, base.y, top + 0.55)) - n * 0.25
    c.scatola_assi(lamp + n * 0.12, [n, lat, Vector((0, 0, 1))], (0.08, 0.12, 0.2), 'nero_opaco')
    c.cilindro(lamp, lamp - n * 0.08, 0.13, 'faro_giallo' if giusta else 'faro_rosso', seg=16)
    luci['paratie'].append([[lamp.x, lamp.y, lamp.z], 'verde' if giusta else 'rossa', [-n.x, -n.y, 0.0]])
    luci['bersagli'].append([t.x, t.y, t.z])


def grata(c, centro, n, chiusa, largo=2.4, alto=2.4):
    """La grata di sicurezza: telaio d'acciaio con le sbarre, scorre nelle guide dei montanti; contrappeso
    e catena sopra. Chiusa: le sbarre arrivano a terra davanti alla bocca."""
    n = Vector((n[0], n[1], 0)).normalized()
    lat = Vector((-n.y, n.x, 0))
    base = Vector(centro) - Vector((0, 0, alto / 2))
    top = base.z + alto * 2 + 0.4
    for sg in (-1, 1):
        q = base + lat * (sg * (largo / 2 + 0.15))
        c.scatola_assi(Vector((q.x, q.y, (base.z + top) / 2)), [n, lat, Vector((0, 0, 1))], (0.14, 0.12, (top - base.z) / 2), 'metallo_grigio')
    c.scatola_assi(Vector((base.x, base.y, top + 0.2)), [n, lat, Vector((0, 0, 1))], (0.2, largo / 2 + 0.4, 0.2), 'strisce')
    zb = base.z if chiusa else base.z + alto
    cg = K.Costruttore(c.mats) if GIOCO else c          # nel gioco le sbarre sono un nodo a parte (cala)
    nb = int(largo / 0.17)
    for k in range(nb + 1):
        q = Vector((base.x, base.y, zb)) + lat * (-largo / 2 + k * largo / nb)
        cg.cilindro(q, q + Vector((0, 0, alto)), 0.03, 'metallo', seg=8)
    for h in (0.05, alto * 0.5, alto - 0.05):
        a = Vector((base.x, base.y, zb + h)) - lat * (largo / 2)
        cg.cilindro(a, a + lat * largo, 0.045, 'giallo_sicurezza', seg=8)
    if GIOCO:
        perno = Vector((base.x, base.y, zb))
        ob = S.con_perno(cg.crea('ins_grata'), tuple(perno))
        K.collisione_scatola('ins_grata_col', (-0.08, -largo / 2, 0.0), (0.08, largo / 2, alto), padre=ob)
        if abs(n.y) > 0.5:
            ob.children[-1].data.transform(Matrix.Rotation(math.pi / 2, 4, 'Z'))
        MOBILI.append(ob)
        GIOCO_DATI['grata'] = dict(nodo=ob.name, perno=list(perno), corsa=alto, chiusa=chiusa, verso=[n.x, n.y, 0.0], largo=largo)
    # catena e contrappeso
    cp = Vector((base.x, base.y, top + 0.4)) + lat * (largo / 2 + 0.5)
    c.cilindro(cp, cp + Vector((0, 0, 1.2)), 0.02, 'metallo', seg=6)
    c.scatola((cp.x - 0.2, cp.y - 0.2, cp.z - 0.5), (cp.x + 0.2, cp.y + 0.2, cp.z), 'nero_opaco')


def serbatoio(c, x, y, z0, h, r, mat='metallo_grigio', scala=True):
    """Serbatoio verticale con le fasce, la cupola, la scaletta e le gambe corte."""
    c.cilindro((x, y, z0 + 0.6), (x, y, z0 + h), r, mat, seg=32)
    c.disco((x, y, z0 + h), (0, 0, 1), r, mat, seg=32)
    c.cilindro((x, y, z0 + h), (x, y, z0 + h + 0.5), r * 0.25, 'metallo', seg=16)
    for k in range(1, int(h / 2.5)):
        c.anello((x, y, z0 + 0.6 + k * 2.5), (0, 0, 1), r, r + 0.06, 0.12, 'metallo', seg=32)
    for a in range(0, 360, 90):
        q = Vector((x + math.cos(math.radians(a)) * r * 0.8, y + math.sin(math.radians(a)) * r * 0.8, z0))
        c.cilindro(q, q + Vector((0, 0, 0.7)), 0.15, 'metallo', seg=10)
    if scala:
        q = Vector((x + r + 0.25, y, 0))
        for sg in (-0.22, 0.22):
            c.cilindro((q.x, q.y + sg, z0 + 0.6), (q.x, q.y + sg, z0 + h + 0.8), 0.025, 'metallo', seg=6)
        zz = z0 + 0.9
        while zz < z0 + h:
            c.cilindro((q.x, q.y - 0.22, zz), (q.x, q.y + 0.22, zz), 0.018, 'metallo', seg=6)
            zz += 0.3
        zz = z0 + 1.2
        while zz < z0 + h:      # staffe che tengono la scaletta al serbatoio
            for sg in (-0.22, 0.22):
                c.cilindro((q.x, q.y + sg, zz), (x + r - 0.05, y + sg, zz), 0.02, 'metallo', seg=6)
            zz += 2.5


def condotta(c, a, b, r, mat='metallo_grigio', z_terra=None, muro=None):
    """Condotta grande (tubo d'acciaio) con le flange ogni 3 m e le selle: a terra con i piedi se z_terra,
    altrimenti mensole al muro (muro = ('x'|'y', valore))."""
    a, b = Vector(a), Vector(b)
    c.cilindro(a, b, r, mat, seg=28)
    d = (b - a).normalized()
    L = (b - a).length
    k = 1.5
    while k < L:
        p = a + d * k
        c.anello(p, d, r, r + 0.1, 0.16, 'metallo', seg=28)
        if z_terra is not None:
            c.scatola((p.x - 0.25, p.y - 0.25, z_terra), (p.x + 0.25, p.y + 0.25, p.z - r + 0.1), 'metallo')
            c.scatola((p.x - r * 0.8, p.y - r * 0.8, p.z - r - 0.05), (p.x + r * 0.8, p.y + r * 0.8, p.z - r + 0.15), 'metallo')
        elif muro is not None:
            asse, v = muro
            q = Vector((v, p.y, p.z)) if asse == 'x' else Vector((p.x, v, p.z))
            c.cilindro(q - Vector((0, 0, r)), p - Vector((0, 0, r)), 0.08, 'metallo', seg=8)
            c.cilindro(q - Vector((0, 0, r + 1.0)), p - Vector((0, 0, r)), 0.06, 'metallo', seg=8)
        k += 3.0


def pompa(c, x, y, z, rot=0.0):
    """Gruppo pompa e motore su un basamento."""
    d = Vector((math.cos(rot), math.sin(rot), 0))
    lat = Vector((-d.y, d.x, 0))
    c.scatola_assi(Vector((x, y, z + 0.21)), [d, lat, Vector((0, 0, 1))], (1.4, 0.7, 0.23), 'cemento')
    c.cilindro(Vector((x, y, z + 0.9)) - d * 1.1, Vector((x, y, z + 0.9)) + d * 0.1, 0.5, 'gioco_verde', seg=20)
    c.cilindro(Vector((x, y, z + 0.9)) + d * 0.1, Vector((x, y, z + 0.9)) + d * 1.1, 0.42, 'metallo_grigio', seg=20)
    c.cilindro(Vector((x, y, z + 0.9)) + d * 0.6, Vector((x, y, z + 2.2)) + d * 0.6, 0.18, 'metallo', seg=12)


def passerella_muro(c, xa, xb, y, z, verso):
    """Passerella di grata lungo un muro nord/sud (verso = +1 dal muro sud, -1 dal muro nord), con le mensole."""
    y0, y1 = (y, y + 1.4) if verso > 0 else (y - 1.4, y)
    P.piattaforma(c, xa, y0, xb, y1, z, lati=('n',) if verso > 0 else ('s',), pali=False)
    x = xa + 0.4
    while x < xb:
        ym = y if verso > 0 else y
        c.scatola((x - 0.06, min(y0, y1), z - 0.32), (x + 0.06, max(y0, y1), z - 0.22), 'gioco_giallo')
        c.cilindro((x, y + verso * 1.25, z - 0.27), (x, ym, z - 1.5), 0.05, 'gioco_giallo', seg=8)
        x += 2.5


def scala_pioli(c, x, y, z0, z1, verso_x=1):
    for sg in (-0.25, 0.25):
        c.cilindro((x, y + sg, z0), (x, y + sg, z1 + 1.0), 0.03, 'giallo_sicurezza', seg=8)
    zz = z0 + 0.3
    while zz < z1 + 0.2:
        c.cilindro((x, y - 0.25, zz), (x, y + 0.25, zz), 0.022, 'giallo_sicurezza', seg=6)
        zz += 0.3


def porta_uscita(c, y, z, luci):
    """La porta di servizio nel muro ovest (verso la nave): telaio, battente socchiuso, cartello verde."""
    c.scatola((X0 + 0.02, y - 0.85, z), (X0 + 0.15, y - 0.7, z + 2.3), 'metallo_grigio')
    c.scatola((X0 + 0.02, y + 0.7, z), (X0 + 0.15, y + 0.85, z + 2.3), 'metallo_grigio')
    c.scatola((X0 + 0.02, y - 0.85, z + 2.2), (X0 + 0.15, y + 0.85, z + 2.35), 'metallo_grigio')
    c.scatola_assi(Vector((X0 + 0.55, y + 0.25, z + 1.1)), [Vector((0.8, 0.6, 0)).normalized(), Vector((-0.6, 0.8, 0)).normalized(), Vector((0, 0, 1))], (0.03, 0.72, 1.08), 'portone')
    c.scatola((X0 + 0.05, y - 0.4, z + 2.5), (X0 + 0.12, y + 0.4, z + 2.8), 'faro_giallo')
    luci['uscita'].append([X0 + 0.24, y, z + 2.65])      # (la lampadina tocca la plafoniera)


def luci_nuove():
    return dict(emergenza=[], lavoro=[], paratie=[], bersagli=[], uscita=[], lei=[], acqua_scorre=[], arredi=[], appese=[],
                neon=[], fari=[], lanterne=[], schiuma=[])


def arredo(luci, fonte, nodo, p, ry=0.0, appoggio='base', normale=None, scala=1.0):
    """Un oggetto vero del gioco messo dallo script degli scatti (non sta nei GLB della proposta):
    fonte 'pompe' = un nodo di assets/ambienti_tecnici/sala_pompe.gltf (anche una lista di nodi che si
    muovono insieme), fonte 'det/<categoria>' = un nodo del kit di dettagli (assets/ambiente/dettagli).
    appoggio: 'base' (il fondo della scatola sul punto p), 'muro' (la scatola contro il muro: p sul muro
    all'altezza del fondo, normale = verso la stanza), 'origine' (l'origine del nodo in p: i dettagli del kit
    da muro e da soffitto hanno l'origine sull'attacco). ry: rotazione attorno alla verticale (gradi)."""
    luci['arredi'].append(dict(f=fonte, n=nodo, p=[round(v, 3) for v in p], ry=ry, a=appoggio,
                               nrm=list(normale) if normale else None, s=scala))


def ry_muro(nx, ny):
    """La rotazione (gradi, attorno alla verticale) che gira il +Z locale di Godot dei dettagli del kit da muro
    verso la stanza, data la normale del muro (nx, ny) in coordinate di Blender."""
    return math.degrees(math.atan2(nx, -ny))


# --- versione A: le condotte -------------------------------------------------------------------------

def versione_A(mats):
    rnd = random.Random(23)
    c = K.Costruttore(mats)
    P.GRATE[0] = K.Costruttore(mats)
    luci = luci_nuove()
    acque = []
    x1, y0, y1, z0, z1 = 78.0, -2.0, 32.0, -34.0, -6.0
    T = -33.4                                       # pelo dell'acqua che allaga il fondo
    porta = (5.0, -30.0)
    guscio(c, x1, y0, y1, z0, z1, buco=BOCCA, porta=porta, fossa=(43.6, 7.9, 45.8, 10.1, 4.5, -33.4 + 0.12))
    collare = None
    if GIOCO:   # il collare attorno al tubo della bocca, sul muro ovest (copre gli angoli del foro), solo da vedere
        cc = K.Costruttore(mats)
        cc.anello((X0, BOCCA.y, BOCCA.z), (1, 0, 0), 0.86, 1.62, 0.08, 'metallo', seg=32)
        collare = cc.crea('ins_A_collare')
    acque.append(P.acqua_piano('acqua_allagata', X0, y0, x1, y1, T))
    oggetti_tubi = []
    pedane = []

    # le vasche di smistamento (x0, y0, x1, y1, z fondo)
    C1 = (50.0, 12.0, 55.0, 18.0, -22.6)
    C2 = (62.5, 25.0, 68.5, 30.5, -25.6)
    C3 = (66.5, 2.0, 72.5, 8.0, -28.6)
    # nel gioco i muri delle vasche sono aperti dove passano i tubi (arrivo e le due paratie)
    BOCCHE = {'c1': [('o', 15.0), ('e', 16.4), ('e', 13.6)], 'c2': [('o', 27.8), ('s', 67.0), ('s', 64.0)],
              'c3': [('n', 70.25, 2.4), ('o', 3.6), ('e', 6.75, 2.1)]}
    for nome, v in (('c1', C1), ('c2', C2), ('c3', C3)):
        acque.append(vasca_sospesa(c, v[0], v[1], v[2], v[3], v[4], z0, f'acqua_vasca_{nome}', bocche=BOCCHE[nome] if GIOCO else None))
        pedane.append((v[0], v[1], v[2], v[3], v[4] - 0.4))
    # le vasche di scolo senza uscita (dove portano le paratie sbagliate), con la scaletta per risalire
    D = [(57.0, 10.2, 61.0, 13.4, -26.0), (56.0, 26.0, 60.0, 30.5, -29.0), (73.5, 12.0, 77.0, 16.0, -31.0)]
    for k, v in enumerate(D):
        acque.append(vasca_sospesa(c, v[0], v[1], v[2], v[3], v[4], z0, f'acqua_scolo_{k}', alto=0.9))

    da_appendere = []

    def tubo(nome, ctrl, colori, passo=2.0):
        # nel gioco il tubo (modello e collisione) segue una linea che scende sempre
        pts = curva_in_discesa(ctrl, 0.3) if GIOCO else curva(ctrl, 0.3)
        o = K.tubo_scivolo(mats, pts if GIOCO else ctrl, nome=nome, materiali=colori, seg=24, r=R_TUBO, spessore=0.06, passo_flange=passo)
        oggetti_tubi.append(o)
        GIOCO_DATI['tubi'][nome] = [[round(v, 3) for v in q] for q in pts]
        if GIOCO:
            da_appendere.append(pts)       # dopo, quando ci sono tutti i tubi (i tiranti non li devono attraversare)
        else:
            appendi_tubo(c, pts, R_TUBO, z1 - 0.6, pedane=pedane)
        return pts

    zc1 = C1[4] + 0.75                    # centro delle bocche nelle pareti delle vasche
    zc2 = C2[4] + 0.75
    zc3 = C3[4] + 0.75
    # T0: dalla bocca alla vasca 1 (entra dal lato ovest)
    # (nel gioco continua il tubo della bocca della torre, che finisce in x 41)
    t0 = tubo('ins_A_tubo_0', [(41.0 if GIOCO else 39.5, 17.4, -18.6), (43.0, 17.2, -19.6), (46.5, 15.2, -20.9), (49.0, 15.0, zc1 + 0.3), (50.4, 15.0, zc1)], ['tsc_giallo'])
    # bivio 1 (lato est della vasca 1): a nord la giusta (verso la vasca 2), a sud la sbagliata (scolo 0)
    paratia(c, (C1[2] - 0.2, 16.4, zc1), (1, 0), True, luci)
    paratia(c, (C1[2] - 0.2, 13.6, zc1), (1, 0), False, luci)
    t1 = tubo('ins_A_tubo_1', [(C1[2] - 0.3, 16.4, zc1 - 0.1), (57.5, 17.5, -23.4), (60.5, 21.0, -24.2), (61.3, 25.0, zc2 + 0.5), (61.9, 27.6, zc2 + 0.2), (C2[0] + 0.3, 27.8, zc2)]
              if not GIOCO else   # nel gioco la discesa è distribuita meglio (al 3 % ci si fermava)
              [(C1[2] - 0.3, 16.4, zc1 - 0.1), (57.5, 17.5, -22.9), (60.5, 21.0, -23.6), (61.3, 25.0, -24.25), (61.9, 27.6, -24.6), (C2[0] + 0.3, 27.8, zc2)],
              ['tsc_rosso', 'tsc_bianco'])
    tubo('ins_A_scolo_0', [(C1[2] - 0.3, 13.6, zc1 - 0.1), (56.6, 13.9, -23.5), (58.2, 13.0, -24.4), (59.0, 11.8, D[0][4] + 0.9)]
         if not GIOCO else [(C1[2] - 0.3, 13.6, zc1 - 0.1), (56.6, 13.9, -22.6), (58.2, 13.0, -23.8), (59.0, 11.8, D[0][4] + 0.9)], ['tsc_rosso'])
    # bivio 2 (lato sud della vasca 2): a est la giusta (verso la vasca 3), a ovest la sbagliata (scolo 1)
    paratia(c, (67.0, C2[1] + 0.2, zc2), (0, -1), True, luci)
    paratia(c, (64.0, C2[1] + 0.2, zc2), (0, -1), False, luci)
    t2 = tubo('ins_A_tubo_2', [(67.0, C2[1] + 0.3, zc2 - 0.1), (68.5, 21.5, -26.4), (71.5, 17.0, -27.3), (72.0, 12.0, -27.9), (70.5, 8.6, zc3 + 0.3), (69.5, 7.6, zc3)]
              if not GIOCO else [(67.0, C2[1] + 0.3, zc2 - 0.1), (68.5, 21.5, -26.0), (71.5, 17.0, -26.8), (72.0, 12.0, -27.3), (70.5, 8.6, -27.6), (69.5, 7.6, zc3)],
              ['tsc_turchese', 'tsc_rosa'])
    tubo('ins_A_scolo_1', [(64.0, C2[1] + 0.3, zc2 - 0.1), (62.0, 23.0, -26.6), (59.5, 25.0, -27.6), (58.0, 27.0, D[1][4] + 0.9)]
         if not GIOCO else [(64.0, C2[1] + 0.3, zc2 - 0.1), (62.0, 23.0, -25.9), (59.5, 25.0, -27.2), (58.0, 27.0, D[1][4] + 0.9)], ['tsc_turchese'])
    # bivio 3 (lato ovest della vasca 3): a sud la giusta (la spirale finale), a nord la sbagliata (scolo 2)
    paratia(c, (C3[0] + 0.2, 3.6, zc3), (-1, 0), True, luci)
    # la sbagliata: il suo tubo (scolo 2) parte dal muro est, quindi nel gioco la paratia sta lì
    if GIOCO:
        paratia(c, (C3[2] - 0.2, 6.6, zc3), (1, 0), False, luci)
    else:
        paratia(c, (C3[0] + 0.2, 6.6, zc3), (-1, 0), False, luci)
    tubo('ins_A_scolo_2', [(C3[2] - 0.2, 6.6, zc3 - 0.1), (74.5, 9.0, -29.6), (75.5, 12.5, -30.3), (75.2, 14.0, D[2][4] + 0.9)]
         if not GIOCO else [(C3[2] - 0.2, 6.6, zc3 - 0.1), (74.8, 7.4, -29.0), (75.6, 11.5, -29.7), (75.2, 14.0, D[2][4] + 0.9)], ['tsc_viola'])
    # T3: la spirale finale attorno al serbatoio grande, giù fino al bacino di scarico
    sx, sy = 60.0, 4.5
    serbatoio(c, sx, sy, z0, 13.0, 2.6)
    spir = [(C3[0] - 0.3, 3.6, zc3 - 0.1), (64.5, 2.0, -28.8 if GIOCO else -29.6)]
    for k in range(1, 9):
        a = math.radians(-60 - k * 52)
        spir.append((sx + math.cos(a) * 4.2, sy + math.sin(a) * 4.2 + 0.0, -29.8 - k * (0.33 if GIOCO else 0.42)))
    # nel gioco il tubo finisce col fondo sul fondo del bacino, davanti all'apertura del suo muro est
    spir += [(53.5, 6.0, -32.9), (50.8, 6.5, -33.2)] if GIOCO else [(53.5, 6.0, -33.6), (51.0, 6.5, -33.75)]
    t3 = tubo('ins_A_tubo_3', spir, ['tsc_arancio', 'tsc_giallo'], passo=1.6)
    # il bacino di scarico: una vasca larga nel fondo allagato (bordo sopra l'acqua)
    BX = (42.5, 1.0, 50.5, 11.0)
    muri_bacino = [((BX[0], BX[1]), (BX[2], BX[1] + 0.3)), ((BX[0], BX[3] - 0.3), (BX[2], BX[3])),
                   ((BX[0], BX[1]), (BX[0] + 0.3, BX[3]))]
    if GIOCO:       # il muro est aperto dove arriva la spirale (lì cala la grata), largo quanto il tubo: dai lati
        # non si esce sul fondo allagato della sala
        muri_bacino += [((BX[2] - 0.3, BX[1]), (BX[2], 6.5 - 0.95)), ((BX[2] - 0.3, 6.5 + 0.95), (BX[2], BX[3]))]
    else:
        muri_bacino.append(((BX[2] - 0.3, BX[1]), (BX[2], BX[3])))
    for (a, b) in muri_bacino:
        c.scatola((a[0], a[1], z0), (b[0], b[1], T + 0.55), 'vasca_bimbi', smusso=0.03)
    acque.append(P.acqua_piano('acqua_bacino', BX[0] + 0.3, BX[1] + 0.3, BX[2] - 0.3, BX[3] - 0.3, T + 0.35))
    # la grata di sicurezza sulla bocca del tubo finale (chiusa: è calata davanti a lei)
    grata(c, (BX[2] - 0.1, 6.5, z0 + 2.0), (1, 0), not GIOCO, largo=3.0, alto=4.0)   # nel gioco alzata: cala dopo
    # la strada per uscire: scaletta sul bordo ovest del bacino, passerella, porta di servizio
    scala_pioli(c, BX[0] + 0.15, 3.2, T - 0.3, porta[1])
    GIOCO_DATI['scale'].append(dict(x=BX[0] + 0.3, y=3.2, z0=z0, z1=porta[1], verso=[1.0, 0.0, 0.0]))
    P.piattaforma(c, X0 + 0.1, 2.0, BX[0] + 0.4, 7.0, porta[1], lati=('s', 'n'), pali=False)
    gambe(c, X0 + 0.1, 2.0, BX[0] + 0.4, 7.0, porta[1] - 0.3, z0)
    porta_uscita(c, porta[0], porta[1], luci)

    for pts in da_appendere:
        appendi_tubo(c, pts, R_TUBO, z1 - 0.6, pedane=pedane, altri=da_appendere)

    # --- l'ambiente pieno: condotte, serbatoi, pompe, passerelle lungo i muri ----------------------------
    condotta(c, (X0 + 0.5, y1 - 1.6, -12.0), (x1 - 0.5, y1 - 1.6, -12.0), 1.3, muro=('y', y1))
    condotta(c, (X0 + 0.5, y0 + 1.7, -15.5), (x1 - 0.5, y0 + 1.7, -15.5), 1.1, muro=('y', y0))
    condotta(c, (x1 - 1.6, y0 + 0.5, -20.0), (x1 - 1.6, y1 - 0.5, -20.0), 1.2, muro=('x', x1))
    condotta(c, (46.0, 20.0, T + 1.2), (76.0, 20.0, T + 1.2), 1.0, z_terra=z0)
    condotta(c, (X0 + 1.3, 17.2, -21.5), (X0 + 1.3, y1 - 0.5, -21.5), 0.9, 'metallo', muro=('x', X0))
    if GIOCO:   # nel gioco la spirale ci passerebbe dentro: la condotta sale dal pavimento a nord della spirale
        condotta(c, (64.0, 10.6, T + 1.0), (64.0, 31.5, T + 1.0), 0.8, z_terra=z0)
        c.cilindro((64.0, 10.6, z0), (64.0, 10.6, T + 1.0), 0.8, 'metallo_grigio', seg=28)
        c.disco((64.0, 10.6, T + 1.0), (0, 0, 1), 0.8, 'metallo_grigio', seg=28)
        c.anello((64.0, 10.6, T + 0.3), (0, 0, 1), 0.8, 0.9, 0.16, 'metallo', seg=28)
    else:
        condotta(c, (64.0, -1.5, T + 1.0), (64.0, 31.5, T + 1.0), 0.8, z_terra=z0)
    # (nel gioco il primo sta 1,5 m più verso il muro est: fra lui e la vasca 2 sale lei)
    for (x, y, h, r) in ((75.5 if GIOCO else 74.0, 27.0, 16.0, 2.2), (45.5, 26.5, 12.0, 2.4), (75.0, 4.0, 11.0, 1.8)):
        serbatoio(c, x, y, z0, h, r)
    # le pompe vere della sala pompe (una per tipo, niente doppioni), su basamenti sopra l'acqua
    for (x, y, nodi) in ((50.0, 23.6, 'POMPA_1'), (54.4, 23.6, 'POMPA_2'), (67.0, 14.5, ['POMPA_3', 'POMPA_3_modello'])):
        P.piattaforma(c, x - 2.1, y - 1.6, x + 2.1, y + 1.6, T + 0.6, lati=(), pali=False)
        gambe(c, x - 2.1, y - 1.6, x + 2.1, y + 1.6, T + 0.3, z0)
        arredo(luci, 'pompe', nodi, (x, y, T + 0.6), ry=90.0)
    arredo(luci, 'det/detriti', 'det_pannello_lamiera', (48.6, 22.6, T + 0.6), ry=25.0, appoggio='origine')
    # il filtro grande su un plinto di cemento, tra il bacino e la spirale
    c.scatola((51.3, -0.6, z0), (54.3, 2.4, T + 0.3), 'cemento')
    arredo(luci, 'pompe', 'FILTRO_1_modello', (52.8, 0.9, T + 0.3), ry=30.0)
    # il ballatoio delle macchine contro il muro est: quadro elettrico, volano della turbina, attrezzi
    BM = (72.6, 17.2, x1 - 0.1, 24.0, -29.0)
    P.piattaforma(c, BM[0], BM[1], BM[2], BM[3], BM[4], lati=('o', 's'), pali=False)
    gambe(c, BM[0], BM[1], BM[2], BM[3], BM[4] - 0.3, z0)
    scala_pioli(c, BM[0] - 0.1, 20.6, z0, BM[4])
    arredo(luci, 'pompe', 'QUADRO_elettrico', (x1, 22.6, BM[4]), ry=90.0, appoggio='muro', normale=(-1, 0))
    arredo(luci, 'pompe', 'TURBINA_1', (75.4, 19.0, BM[4]), ry=90.0)
    arredo(luci, 'det/detriti', 'det_griglia_caduta', (73.6, 21.8, BM[4]), ry=-20.0, appoggio='origine')
    arredo(luci, 'det/elettrico', 'det_cassetta_aperta', (x1, 18.2, BM[4] + 1.3), ry=ry_muro(-1, 0), appoggio='origine')
    # il palo della plafoniera, dal ballatoio, col braccio
    c.cilindro((77.5, 20.6, BM[4]), (77.5, 20.6, BM[4] + 3.4), 0.05, 'metallo_grigio', seg=8)
    c.cilindro((77.5, 20.6, BM[4] + 3.35), (74.6, 20.6, BM[4] + 3.35), 0.035, 'metallo_grigio', seg=8)
    luci['neon'].append([75.4, 20.6, BM[4] + 3.365])     # (il tubo, 10 cm sotto, tocca il braccio)
    # la postazione di controllo sul muro sud: un balcone sulla passerella con la scrivania e gli strumenti
    PC = (45.5, y0 + 1.8, 52.5, y0 + 3.6, -20.0)
    P.piattaforma(c, PC[0], PC[1], PC[2], PC[3], PC[4], lati=('n', 'e', 'o'), pali=False)
    for x in (PC[0] + 0.3, (PC[0] + PC[2]) / 2, PC[2] - 0.3):
        c.cilindro((x, PC[3] - 0.2, PC[4] - 0.3), (x, y0 + 0.05, PC[4] - 2.2), 0.06, 'gioco_giallo', seg=8)
        c.scatola((x - 0.12, y0, PC[4] - 2.35), (x + 0.12, y0 + 0.08, PC[4] - 2.05), 'metallo')
    arredo(luci, 'pompe', 'SCRIVANIA', (48.0, PC[1] + 0.55, PC[4]), ry=180.0)
    arredo(luci, 'pompe', 'SEDIA', (48.2, PC[1] + 1.35, PC[4]), ry=160.0)
    arredo(luci, 'pompe', 'QUADRO_strumenti', (50.9, y0, PC[4] + 0.9), ry=0.0, appoggio='muro', normale=(0, 1))
    arredo(luci, 'det/elettrico', 'det_quadro_elettrico', (46.2, y0, PC[4] + 1.4), ry=ry_muro(0, 1), appoggio='origine')
    arredo(luci, 'det/detriti', 'det_vetri_rotti_1', (51.6, PC[1] + 1.0, PC[4]), ry=40.0, appoggio='origine')
    arredo(luci, 'det/detriti', 'det_foglio_2', (49.4, PC[1] + 1.2, PC[4]), ry=-15.0, appoggio='origine')
    c.cilindro((49.0, y0, PC[4] + 3.05), (49.0, PC[1] + 1.0, PC[4] + 3.05), 0.035, 'metallo_grigio', seg=8)
    c.scatola((48.9, y0, PC[4] + 2.9), (49.1, y0 + 0.05, PC[4] + 3.2), 'metallo')
    luci['neon'].append([49.0, PC[1] + 0.8, PC[4] + 3.065])     # (il tubo, 10 cm sotto, tocca il braccio)
    passerella_muro(c, X0 + 1.0, x1 - 1.0, y0 + 0.4, -20.0, 1)
    passerella_muro(c, X0 + 1.0, x1 - 1.0, y1 - 0.4, -24.0, -1)
    for x in range(44, 78, 7):
        P.tubo_muro(c, [(x, y0 + 0.35, z0 + 0.4), (x, y0 + 0.35, z1 - 0.5)], r=0.12)
    # catene appese dal soffitto (con il gancio)
    for (x, y) in ((58.0, 15.0), (66.0, 18.0), (48.0, 22.0)):
        c.cilindro((x, y, z1), (x, y, -17.0 - rnd.uniform(0, 3)), 0.03, 'metallo', seg=6)
    # i dettagli del kit sui muri e sotto le passerelle: valvole, tubi, cavi, cartelli, lampade
    for (cat, nodo, p, nrm) in (
            ('tubi', 'det_tubo_valvola_T', (55.0, y1, -23.0), (0, -1)),
            ('tubi', 'det_tubo_curva_su', (61.0, y0, -19.9), (0, 1)),
            ('tubi', 'det_tubo_valvola_T', (X0, 11.8, -29.2), (1, 0)), ('elettrico', 'det_interruttore_stagno', (X0, 7.8, -28.9), (1, 0)),
            ('cartelli', 'det_cartello_uscita', (X0, 3.2, -27.6), (1, 0)), ('cartelli', 'det_cartello_profondita', (X0, 9.6, -31.9), (1, 0)),
            ('cartelli', 'det_cartello_salvagente', (57.0, y0, -18.3), (0, 1)), ('cartelli', 'det_cartello_non_correre_penzolante', (71.0, y1, -22.4), (0, -1)),
            ('elettrico', 'det_cassetta_piccola', (x1, 9.0, -30.0), (-1, 0)), ('tubi', 'det_bocchetta_rettangolare_rotta', (x1, 27.0, -27.0), (-1, 0)),
            ('lampade', 'det_applique_emergenza_rotta', (66.0, y0, -24.5), (0, 1)),
            ('tubi', 'det_condotta_aria_4m', (X0, 24.5, -19.6), (1, 0)),
            ('elettrico', 'det_cassetta_aperta', (X0, 17.6, -24.0), (1, 0)), ('cartelli', 'det_cartello_non_tuffarsi', (X0, 22.0, -19.2), (1, 0)),
            ('tubi', 'det_tubo_verticale_3m', (X0, 28.5, -25.0), (1, 0)), ('tubi', 'det_bocchetta_tonda', (X0, 26.0, -23.0), (1, 0))):
        arredo(luci, 'det/' + cat, nodo, p, ry=ry_muro(*nrm), appoggio='origine')
    # sotto le passerelle: fasci di cavi a festone (dall'attacco pendono in giù), legati alla trave di mezzo
    # (passerella_muro: in mezzo alla larghezza, sotto la trave che finisce 16 cm sotto il piano)
    for (cat, nodo, p, ry) in (('cavi', 'det_fascio_cavi_4m', (46.0, y0 + 1.1, -20.17), 0.0), ('cavi', 'det_cavo_festone_3', (58.0, y0 + 1.1, -20.17), 0.0),
                               ('cavi', 'det_cavo_festone_2', (52.0, y1 - 1.1, -24.17), 180.0), ('cavi', 'det_cavo_festone_3', (64.5, y1 - 1.1, -24.17), 180.0),
                               ('catene_corde', 'det_corda_pendente_2', (74.0, y0 + 1.1, -20.17), 0.0)):
        arredo(luci, 'det/' + cat, nodo, p, ry=ry, appoggio='origine')
    # sulla piattaforma della porta: corda, catena, la paletta di un bagnino
    for (cat, nodo, p, ry) in (('catene_corde', 'det_corda_rotolo', (41.0, 6.2, porta[1]), 0.0), ('catene_corde', 'det_catena_a_terra', (42.3, 2.6, porta[1]), 60.0),
                               ('detriti', 'det_pannello_lamiera_2', (41.4, 4.6, porta[1]), 12.0)):
        arredo(luci, 'det/' + cat, nodo, p, ry=ry, appoggio='origine')
    # lampade industriali appese al soffitto sopra le macchine (cavo dal soffitto)
    luci['appese'] += [[51.5, 7.5, -16.5, True], [61.5, 17.5, -17.5, False], [70.5, 24.0, -18.5, True], [45.0, 22.5, -19.0, True],
                       [43.8, 28.5, -17.0, False], [61.0, 9.9, -23.5, True]]
    # prop nell'acqua e sulle passerelle
    props = []
    for (nome, x, y, z, rot) in (('salvagente_nave', 47.0, 18.0, T - 0.05, 30), ('ciambella_gonfiabile', 68.0, 22.5, T - 0.1, 120),
                                 ('paperella_gigante', 48.5, 4.0, T + 0.2, 200), ('cartello_pavimento_bagnato', 41.3, 5.8, porta[1], 15),
                                 ('pallone_spiaggia', 72.0, 30.0, T - 0.15, 0)):
        props.append(P.prop(nome, (x, y, z), rot))

    # --- luci (le mette lo script degli scatti) ------------------------------------------------------------
    luci['emergenza'] += [[X0 + 0.15, 25.0, -16.0], [x1 - 0.15, 10.0, -22.0], [60.0, y1 - 0.15, -18.0], [50.0, y0 + 0.15, -26.0], [70.0, y0 + 0.15, -14.0]]
    if not GIOCO:
        luci['lavoro'] += [[C1[0] + 0.3, C1[1] + 0.3, C1[4] + 1.6], [C2[0] + 0.3, C2[3] - 0.3, C2[4] + 1.6], [C3[2] - 0.3, C3[3] - 0.3, C3[4] + 1.6],
                           [BX[0] + 0.6, BX[1] + 0.6, T + 2.0]]
    else:
        # una lampada da lavoro su ogni vasca e sul bacino (scelta dell'utente del 22 ottobre): un palo nell'angolo,
        # un braccio verso il mezzo della vasca e la testa con la lampadina sotto, sopra i 2 m di chi cammina
        for (ax, ay, zb, zv), (vx, vy) in (((C1[0] + 0.25, C1[1] + 0.25, C1[4], C1[4]), (1, 1)),
                                         ((C2[0] + 0.25, C2[3] - 0.25, C2[4], C2[4]), (1, -1)),
                                         ((C3[2] - 0.25, C3[3] - 0.25, C3[4], C3[4]), (-1, -1)),
                                         ((BX[0] + 0.55, BX[1] + 0.55, z0, T), (1, 1))):
            d = Vector((vx, vy, 0)).normalized()
            zt = zv + 2.55
            testa = Vector((ax, ay, zt - 0.1)) + d * 0.8
            c.cilindro((ax, ay, zb), (ax, ay, zt), 0.035, 'metallo_grigio', seg=8)
            c.cilindro((ax, ay, zt - 0.05), (testa.x, testa.y, zt - 0.05), 0.025, 'metallo_grigio', seg=8)
            c.cilindro((testa.x, testa.y, zt - 0.04), (testa.x, testa.y, zt - 0.26), 0.13, 'gioco_giallo', seg=14)
            luci['lavoro'].append([round(testa.x, 3), round(testa.y, 3), round(zt - 0.3, 3)])
    luci['acqua_scorre'] += [[x, y, z] for (x, y, z) in ((50.8, 15.0, zc1), (62.8, 27.8, zc2), (69.6, 7.4, zc3), (50.8, 6.5, -33.4))]
    # lei: dove ti raggiunge (le pose per gli scatti)
    luci['lei'] += [[47.5, 18.3, -25.0, 200.0, 'insegue', 'raggiunge la vasca 1 dal basso'],
                    ([70.8, 27.6, -21.0, 270.0, 'insegue', 'sale accanto alla vasca 2, dal lato est'] if GIOCO else
                     [62.0, 31.0, -21.0, 160.0, 'insegue', 'arriva sulla condotta nord alla vasca 2']),
                    [BX[2] + 2.2, 6.5, -34.0, 270.0, 'insegue', 'sbatte contro la grata'],
                    [44.7, 9.0, T + 0.12 - 0.8, 120.0, 'affacciata', 'SB1: sbuca dal pozzo di scarico del bacino']]

    percorso = [('bocca', BOCCA)] + [('tubo', p) for p in t0[::4]] + [('vasca 1', Vector(((C1[0] + C1[2]) / 2, (C1[1] + C1[3]) / 2, C1[4])))]
    percorso += [('bivio', Vector((C1[2], 15.0, C1[4])))] + [('tubo', p) for p in t1[::4]]
    percorso += [('vasca 2', Vector(((C2[0] + C2[2]) / 2, (C2[1] + C2[3]) / 2, C2[4]))), ('bivio', Vector((65.5, C2[1], C2[4])))]
    percorso += [('tubo', p) for p in t2[::4]] + [('vasca 3', Vector(((C3[0] + C3[2]) / 2, (C3[1] + C3[3]) / 2, C3[4]))), ('bivio', Vector((C3[0], 5.0, C3[4])))]
    percorso += [('tubo', p) for p in t3[::4]] + [('grata', Vector((BX[2], 6.5, T)))]
    percorso += [('bacino', Vector(((BX[0] + BX[2]) / 2, 6.0, T))), ('uscita', Vector((X0 + 0.5, porta[0], porta[1])))]
    sbagliate = [D[0], D[1], D[2]]

    suff = '-col' if GIOCO else ''
    gr = P.GRATE[0].crea('ins_A_grigliati' + suff)
    ob = c.crea('ins_A_struttura' + suff, sporco=lambda co: 0.55 + 0.45 * min(1.0, max(0.0, (co.z + 34.0) / 10.0)))
    gruppi = {'struttura': [ob, gr] + acque + ([collare] if collare else []), 'tubi': oggetti_tubi, 'prop': props}
    info = dict(sbagliate=[list(v) for v in sbagliate], vasche=[list(C1), list(C2), list(C3)], bacino=list(BX), limiti=[X0, y0, x1, y1, z0, z1])
    if GIOCO:
        gruppi['mobili'] = list(MOBILI)
        dentro = controlla_tubi([ob, gr] + list(MOBILI), [[Vector(q) for q in v] for v in GIOCO_DATI['tubi'].values()], R_TUBO)
        print(f'controllo dei tubi: {len(dentro)} punti della struttura dentro i tubi', dentro[:12])
        for o in props:     # i prop sono solidi: una scatola convessa sui loro limiti (come nella torre)
            if o.name.startswith('prop_') and o.type == 'MESH':
                me = o.data
                xs = [v.co.x for v in me.vertices]; ys_ = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
                K.collisione_scatola(o.name, (min(xs), min(ys_), min(zs)), (max(xs), max(ys_), max(zs)), padre=o).hide_render = True
        # la bocca della torre fa parte del primo tubo (la collisione la fa il gioco lungo tutta la linea)
        # (la linea del tubo della torre, come la disegna tubo_scivolo, poi quella del primo tubo da x 41)
        GIOCO_DATI['tubi']['ins_A_tubo_0'] = [[round(v, 3) for v in q] for q in curva(BOCCA_TORRE, 0.3)[:-1] + t0]
        # a ogni paratia il tubo che apre e la vasca dove sta (in ordine: giusta e sbagliata dei bivi 1, 2, 3)
        dove = [('ins_A_tubo_1', 0), ('ins_A_scolo_0', 0), ('ins_A_tubo_2', 1), ('ins_A_scolo_1', 1), ('ins_A_tubo_3', 2), ('ins_A_scolo_2', 2)]
        for pa, (tb, v) in zip(GIOCO_DATI['paratie'], dove):
            pa['tubo'] = tb
            pa['vasca'] = v
        GIOCO_DATI.update(
            vasche=[dict(rett=list(v[:4]), fondo=v[4], acqua=v[4] + 1.1 - 0.12) for v in (C1, C2, C3)],
            scolo=[dict(rett=list(v[:4]), fondo=v[4], acqua=v[4] + 0.9 - 0.12) for v in D],
            bacino=dict(rett=list(BX), fondo=z0, acqua=T + 0.35),
            allagato=dict(acqua=T, fondo=z0),
            pozzo=dict(rett=[43.6, 7.9, 45.8, 10.1], fondo=z0 - 4.5, bordo=T + 0.12),
            porta=dict(pos=[X0, porta[0], porta[1]], uscita=[X0 + 1.2, porta[0], porta[1]]),
            piattaforma_porta=[X0 + 0.1, 2.0, BX[0] + 0.4, 7.0, porta[1]],
            limiti=[X0, y0, x1, y1, z0, z1],
            lei=[dict(pos=L[:3], ry=L[3], posa=L[4], nota=L[5]) for L in luci['lei']])
        # i checkpoint: in ogni vasca, guardando le paratie; nel bacino dopo la grata
        # (rett: l'area del checkpoint, tutta la vasca)
        GIOCO_DATI['checkpoint'] = [
            dict(nome='vasca_1', pos=[51.4, 15.0, C1[4]], guarda=[C1[2], 15.0, C1[4]], rett=list(C1[:4])),
            dict(nome='vasca_2', pos=[64.0, 28.6, C2[4]], guarda=[65.5, C2[1], C2[4]], rett=list(C2[:4])),
            dict(nome='vasca_3', pos=[69.5, 5.0, C3[4]], guarda=[C3[0], 4.0, C3[4]], rett=list(C3[:4])),
            dict(nome='bacino', pos=[48.6, 6.5, z0], guarda=[BX[0], 4.0, z0], rett=[BX[0] + 0.3, BX[1] + 0.3, BX[2] - 0.3, BX[3] - 0.3])]
    return gruppi, percorso, luci, info


# --- versione B: le rapide ---------------------------------------------------------------------------

W_B, D_B, H_B = 1.6, 0.9, 0.5        # canale delle rapide: mezza larghezza, profondità, sponde


def canale_rapide(c, pts, mat='vasca_alta'):
    S.scivolo_solido(c, [Vector(p) for p in pts], W=W_B, D=D_B, T=0.14, H=H_B, R=0.08, mat=mat)
    TA.flange_u(c, [Vector(p) for p in pts], W_B, D_B, 0.14, H_B, 'vasca_alta_bordo', ogni=3.0, e=0.04, b=0.06)


def nastro_acqua(nome, pts, mezza, sotto):
    """L'acqua che corre nel canale: un nastro lungo la linea, `sotto` metri sotto il bordo."""
    vs, fs = [], []
    for i, p in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        d = (b - a).normalized()
        lat = d.cross(Vector((0, 0, 1))).normalized()
        su = lat.cross(d).normalized()
        q = p - su * sotto
        vs += [tuple(q - lat * mezza), tuple(q + lat * mezza)]
        if i:
            k = 2 * i
            fs.append((k - 2, k - 1, k + 1, k))
    me = bpy.data.meshes.new(nome)
    me.from_pydata(vs, [], fs)
    # UV: u attraverso il canale (0..1), v lungo la corrente (metri); nella seconda UV la pendenza
    # (la schiuma è più fitta nei salti): lo shader delle rapide ci disegna le strisce che corrono
    lung = [0.0]
    for i in range(1, len(pts)):
        lung.append(lung[-1] + (pts[i] - pts[i - 1]).length)
    pend = []
    for i in range(len(pts)):
        a_, b_ = pts[max(i - 2, 0)], pts[min(i + 2, len(pts) - 1)]
        dz = a_.z - b_.z
        dl = max((b_ - a_).length, 0.01)
        pend.append(min(1.0, max(0.0, dz / dl * 4.0)))
    uv = me.uv_layers.new(name='UVMap')
    uv2 = me.uv_layers.new(name='UVSalto')          # in Godot è UV2: x = pendenza
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uv.data[li].uv = (vi % 2, lung[vi // 2])
            uv2.data[li].uv = (pend[vi // 2], 0.0)
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def sostieni_canale(c, pts, z_terra, ogni=3.0):
    """Pilastri di cemento sotto il canale, con il capitello a sella."""
    s = 0.0
    prossimo = ogni * 0.5
    for i in range(1, len(pts) - 1):
        s += (pts[i] - pts[i - 1]).length
        if s < prossimo:
            continue
        prossimo += ogni
        p = pts[i]
        zf = p.z - D_B - 0.14
        if zf - z_terra < 0.3:
            continue
        d = (pts[i + 1] - pts[i - 1])
        d.z = 0
        d.normalize()
        lat = Vector((-d.y, d.x, 0))
        c.scatola_assi(Vector((p.x, p.y, (zf + z_terra) / 2)), [d, lat, Vector((0, 0, 1))], (0.3, 0.45, (zf - z_terra) / 2 + 0.05), 'cemento')
        c.scatola_assi(Vector((p.x, p.y, zf - 0.15)), [d, lat, Vector((0, 0, 1))], (0.35, W_B + 0.1, 0.15), 'cemento')


def scoglio(c, x, y, z0, h, r, rnd):
    """Scoglio finto di vetroresina (quelli delle rapide): blocchi arrotondati sovrapposti."""
    zz = z0
    rr = r
    while zz < z0 + h:
        hh = rnd.uniform(0.6, 1.3)
        dx, dy = rnd.uniform(-0.3, 0.3) * rr, rnd.uniform(-0.3, 0.3) * rr
        c.scatola_smussata((x + dx - rr, y + dy - rr * 0.8, zz), (x + dx + rr, y + dy + rr * 0.8, zz + hh), 'cemento', s=0.25)
        zz += hh * 0.8
        rr *= rnd.uniform(0.7, 0.9)


def materiali_rapide(mats):
    """Vetroresina degli scogli finti, gomma dei gommoni, le insegne disegnate (inseguimento_insegne.py)."""
    import inseguimento_insegne as INS
    for nome, col, rough in (('roccia_finta', (0.42, 0.27, 0.15), 0.8), ('roccia_finta_scura', (0.22, 0.16, 0.12), 0.85),
                             ('gomma_gialla', (0.85, 0.6, 0.02), 0.55), ('gomma_rossa', (0.62, 0.06, 0.03), 0.55),
                             ('gomma_blu', (0.05, 0.2, 0.55), 0.55), ('gomma_nera_ins', (0.03, 0.03, 0.03), 0.7),
                             ('gomma_verde', (0.05, 0.4, 0.12), 0.55), ('gomma_arancio', (0.85, 0.28, 0.02), 0.55)):
        if nome not in mats.cache:
            mats.cache[nome] = mats._semplice(nome, col, rough)
    for nome, file in INS.disegna_tutto().items():
        if nome in mats.cache:
            continue
        m, nt, b = mats._base(nome)
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(file, check_existing=True)
        nt.links.new(uv.outputs['UV'], t.inputs['Vector'])
        nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
        b.inputs['Roughness'].default_value = 0.6
        mats.cache[nome] = m


_ICO = None


def _icosfera():
    """I vertici e i triangoli di un'icosfera (2 suddivisioni), calcolati una volta."""
    global _ICO
    if _ICO:
        return _ICO
    t = (1 + 5 ** 0.5) / 2
    vv = [Vector(v).normalized() for v in ((-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
                                           (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1))]
    ff = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
          (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    for _ in range(2):
        mezzi = {}
        nuove = []
        def m(a, b):
            k = (min(a, b), max(a, b))
            if k not in mezzi:
                vv.append(((vv[a] + vv[b]) / 2).normalized())
                mezzi[k] = len(vv) - 1
            return mezzi[k]
        for (a, b, c_) in ff:
            ab, bc, ca = m(a, b), m(b, c_), m(c_, a)
            nuove += [(a, ab, ca), (b, bc, ab), (c_, ca, bc), (ab, bc, ca)]
        ff = nuove
    _ICO = (vv, ff)
    return _ICO


def masso(c, centro, raggi, rnd, mat='roccia_finta'):
    """Un masso di vetroresina: un'icosfera schiacciata e bitorzoluta (ognuno diverso)."""
    vv, ff = _icosfera()
    fase = [rnd.uniform(0, 6.28) for _ in range(6)]
    def forma(d):
        k = 1.0 + 0.16 * math.sin(3.1 * d.x + fase[0]) * math.sin(2.7 * d.y + fase[1]) + 0.1 * math.sin(5.3 * d.z + fase[2]) \
            + 0.06 * math.sin(7.7 * d.x + 6.1 * d.y + fase[3])
        return Vector((centro[0] + d.x * raggi[0] * k, centro[1] + d.y * raggi[1] * k, centro[2] + d.z * raggi[2] * k))
    pp = [forma(d) for d in vv]
    for (a, b, c_) in ff:
        c.faccia([pp[a], pp[b], pp[c_]], mat, liscia=True)


def scoglio(c, x, y, z0, h, r, rnd):
    """Scoglio finto delle rapide: massi di vetroresina dipinta sovrapposti, il primo affondato nel pavimento."""
    zz = z0 - 0.3
    rr = r
    k = 0
    while zz < z0 + h - 0.3 and k < 9:
        hh = max(rr * rnd.uniform(0.75, 1.05), h / 6.0)
        dx, dy = rnd.uniform(-0.25, 0.25) * rr, rnd.uniform(-0.25, 0.25) * rr
        masso(c, (x + dx, y + dy, zz + hh * 0.55), (rr, rr * rnd.uniform(0.75, 0.95), hh * 0.75), rnd,
              'roccia_finta' if k % 3 != 2 else 'roccia_finta_scura')
        zz += hh * 0.9
        rr = max(rr * rnd.uniform(0.72, 0.88), r * 0.4)
        k += 1


def gommone(mats, nome, centro, mat, rot=(0.0, 0.0, 0.0)):
    """Il gommone tondo delle rapide (sei posti): il tubolare, il fondo, i sedili a raggiera e le maniglie.
    Un oggetto a parte, girato con rot (gradi) attorno al suo centro: anche rovesciato."""
    c = K.Costruttore(mats)
    R, r = 1.15, 0.32
    c.toro((0, 0, r), (0, 0, 1), R, r, mat, seg=48, seg_r=12)
    c.disco((0, 0, 0.04), (0, 0, 1), R, 'gomma_nera_ins', seg=40)
    c.disco((0, 0, 0.03), (0, 0, -1), R, 'gomma_nera_ins', seg=40)
    c.cilindro((0, 0, 0.0), (0, 0, 0.05), R + 0.02, 'gomma_nera_ins', seg=40, tappi=False)
    for k in range(6):
        a = 2 * math.pi * k / 6
        d = Vector((math.cos(a), math.sin(a), 0))
        c.scatola_assi(d * 0.55 + Vector((0, 0, 0.22)), [d, Vector((-d.y, d.x, 0)), Vector((0, 0, 1))], (0.42, 0.13, 0.18), mat)
        q = d * (R + r * 0.9) + Vector((0, 0, r * 1.2))
        c.toro(q, Vector((-d.y, d.x, 0)), 0.09, 0.018, 'gomma_nera_ins', seg=12, seg_r=6)
    ob = c.crea(nome)
    ob.location = Vector(centro)
    ob.rotation_euler = tuple(math.radians(v) for v in rot)
    return ob


def insegna(c, nome_mat, centro, n, largo, alto):
    """Un pannello disegnato con la cornice, la faccia verso n (orizzontale)."""
    n = Vector((n[0], n[1], 0)).normalized()
    lat = Vector((-n.y, n.x, 0))         # da davanti la scritta si legge da sinistra a destra
    o = Vector(centro)
    q = [o - lat * (largo / 2) + n * 0.03, o + lat * (largo / 2) + n * 0.03, o + lat * (largo / 2) + n * 0.03 + Vector((0, 0, alto)),
         o - lat * (largo / 2) + n * 0.03 + Vector((0, 0, alto))]
    c.faccia(q, nome_mat, uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    c.scatola_assi(o + Vector((0, 0, alto / 2)), [n, lat, Vector((0, 0, 1))], (0.025, largo / 2 + 0.05, alto / 2 + 0.05), 'metallo_grigio')


def lanterna(c, luci, p, lat):
    """Il lampioncino del percorso sulla sponda del canale: il palo dentro la sponda, la lampada a gabbia."""
    b = Vector(p) + Vector(lat) * (W_B + 0.07)
    c.cilindro(b - Vector((0, 0, 0.35)), b + Vector((0, 0, 1.25)), 0.035, 'nero_opaco', seg=8)
    c.cilindro(b + Vector((0, 0, 1.25)), b + Vector((0, 0, 1.47)), 0.075, 'faro_giallo', seg=10)
    c.disco(b + Vector((0, 0, 1.5)), (0, 0, 1), 0.11, 'nero_opaco', seg=10)
    c.cilindro(b + Vector((0, 0, 1.47)), b + Vector((0, 0, 1.5)), 0.11, 'nero_opaco', seg=10)
    luci['lanterne'].append([round(b.x, 2), round(b.y, 2), round(b.z + 1.36, 2)])


def versione_B(mats):
    rnd = random.Random(31)
    c = K.Costruttore(mats)
    P.GRATE[0] = K.Costruttore(mats)
    luci = luci_nuove()
    acque = []
    x1, y0, y1, z0, z1 = 84.0, -6.0, 36.0, -36.0, -6.0
    porta = (-3.0, -32.6)
    guscio(c, x1, y0, y1, z0, z1, buco=BOCCA, porta=porta, fossa=(44.8, -3.0, 47.0, -0.8, 4.5, z0 + 0.9 + 0.25 + 0.12))
    canali = K.Costruttore(mats)
    materiali_rapide(mats)
    # sotto il canale, il bacino di raccolta della giostra: acqua ferma e scura tra gli scogli
    acque.append(P.acqua_piano('acqua_fondo', X0 + 1.0, y0 + 1.0, x1 - 1.0, y1 - 1.0, z0 + 0.15))

    # T0: corto tubo dalla bocca alla vasca di partenza delle rapide
    t0c = [(39.5, 15.0, -18.6), (42.0, 15.0, -19.2), (44.2, 15.0, -19.9)]
    tubi = [K.tubo_scivolo(mats, t0c, nome='ins_B_tubo_0', materiali=['tsc_giallo'], seg=24, r=R_TUBO, spessore=0.06)]
    appendi_tubo(c, curva(t0c), R_TUBO, z1 - 0.6)
    VP = (44.0, 11.5, 50.0, 18.5, -21.2)
    acque.append(vasca_sospesa(c, VP[0], VP[1], VP[2], VP[3], VP[4], z0, 'acqua_partenza', alto=1.0))

    # il canale: tratti tra i bivi (punti del bordo del canale, z del bordo)
    stato = {'lato': 1}

    def tratto(ctrl, nome):
        pts = curva(ctrl, 0.35)
        canale_rapide(canali, pts)
        sostieni_canale(c, pts, z0)
        acque.append(nastro_acqua(f'acqua_{nome}', pts, W_B * 0.82, D_B * 0.55))
        luci['schiuma'].append(f'acqua_{nome}')
        # i lampioncini del percorso, ogni 6 m sulla sponda, a lati alterni
        s_ = 0.0
        prossimo = 2.5
        for i in range(1, len(pts) - 1):
            s_ += (pts[i] - pts[i - 1]).length
            if s_ < prossimo:
                continue
            prossimo += 6.0
            d = (pts[i + 1] - pts[i - 1]).normalized()
            lat = Vector((-d.y, d.x, 0)).normalized() * stato['lato']
            stato['lato'] *= -1
            lanterna(c, luci, pts[i], lat)
        return pts

    zr = VP[4] + 1.0
    r0 = tratto([(VP[2] - 0.2, 15.0, zr), (54.0, 15.0, zr - 0.5), (58.0, 17.0, zr - 1.0), (62.0, 21.0, zr - 1.6), (64.5, 22.5, zr - 1.9)], 'r0')
    # bivio 1: due rami attorno a uno scoglio; paratie a ghigliottina sopra l'inizio di ciascuno
    b1 = Vector((65.0, 22.6, zr - 1.95))
    scoglio(c, 69.5, 22.6, z0, zr - 2.4 - z0, 2.0, rnd)
    rG1 = tratto([(b1.x, b1.y, b1.z), (67.0, 25.5, b1.z - 0.3), (71.0, 27.5, b1.z - 0.7), (75.0, 26.0, b1.z - 1.2), (77.0, 22.0, b1.z - 1.8)], 'r1')
    rS1 = tratto([(b1.x, b1.y, b1.z), (67.5, 19.5, b1.z - 0.4), (69.5, 17.5, b1.z - 0.9), (70.0, 15.5, b1.z - 1.4)], 's1')
    paratia(c, (66.0, 24.0, b1.z - 0.3), (0.45, 0.9), True, luci, largo=3.4, alto=1.6)
    paratia(c, (66.2, 21.0, b1.z - 0.3), (0.5, -0.86), False, luci, largo=3.4, alto=1.6)
    # la sbagliata finisce nella chiusa senza uscita
    acque.append(vasca_sospesa(c, 68.5, 12.5, 72.5, 15.5, b1.z - 2.9, z0, 'acqua_chiusa_1', alto=1.2))
    # salto d'acqua e secondo tratto, verso sud
    zz = b1.z - 1.8
    r2 = tratto([(77.0, 22.0, zz), (78.5, 18.0, zz - 0.4), (78.0, 13.5, zz - 1.6), (76.0, 10.5, zz - 2.0), (73.0, 9.0, zz - 2.3)], 'r2')
    b2 = Vector((72.5, 9.0, zz - 2.35))
    scoglio(c, 68.0, 8.8, z0, b2.z - 0.5 - z0, 1.9, rnd)
    rG2 = tratto([(b2.x, b2.y, b2.z), (70.0, 6.0, b2.z - 0.4), (66.0, 4.5, b2.z - 0.9), (62.0, 4.0, b2.z - 1.5)], 'r3')
    rS2 = tratto([(b2.x, b2.y, b2.z), (70.0, 11.5, b2.z - 0.4), (66.5, 12.5, b2.z - 0.9), (64.5, 12.0, b2.z - 1.3)], 's2')
    paratia(c, (71.5, 7.6, b2.z - 0.3), (-0.6, -0.8), True, luci, largo=3.4, alto=1.6)
    paratia(c, (71.3, 10.4, b2.z - 0.3), (-0.6, 0.8), False, luci, largo=3.4, alto=1.6)
    acque.append(vasca_sospesa(c, 61.0, 11.0, 64.5, 14.5, b2.z - 2.6, z0, 'acqua_chiusa_2', alto=1.2))
    # terzo tratto con un salto, verso ovest, e il bivio 3
    zz = b2.z - 1.5
    r4 = tratto([(62.0, 4.0, zz), (58.0, 3.5, zz - 0.6), (55.0, 4.5, zz - 1.8), (52.5, 7.0, zz - 2.2)], 'r4')
    b3 = Vector((52.0, 7.5, zz - 2.25))
    scoglio(c, 50.0, 11.5, z0, b3.z - 0.5 - z0, 1.6, rnd)
    rG3 = tratto([(b3.x, b3.y, b3.z), (49.5, 7.5, b3.z - 0.6), (47.5, 6.5, b3.z - 1.4), (46.0, 5.5, b3.z - 2.2)], 'r5')
    rS3 = tratto([(b3.x, b3.y, b3.z), (51.0, 10.5, b3.z - 0.5), (49.0, 13.5, b3.z - 1.0), (47.0, 15.0, b3.z - 1.4)], 's3')
    paratia(c, (51.0, 7.3, b3.z - 0.3), (-1.0, -0.1), True, luci, largo=3.4, alto=1.6)
    paratia(c, (51.6, 9.0, b3.z - 0.3), (-0.3, 0.95), False, luci, largo=3.4, alto=1.6)
    acque.append(vasca_sospesa(c, 45.0, 13.0, 49.0, 16.5, b3.z - 2.0, z0, 'acqua_chiusa_3', alto=1.2))
    # la laguna d'arrivo: il canale finisce sotto un arco, dove cala la saracinesca
    LG = (41.5, -5.0, 54.0, 4.5)
    zl = z0 + 0.9
    for (a, b) in (((LG[0], LG[1]), (LG[2], LG[1] + 0.35)), ((LG[0], LG[3] - 0.35), (LG[2], LG[3])),
                   ((LG[0], LG[1]), (LG[0] + 0.35, LG[3])), ((LG[2] - 0.35, LG[1]), (LG[2], LG[3]))):
        c.scatola((a[0], a[1], z0), (b[0], b[1], zl + 0.5), 'vasca_bimbi', smusso=0.03)
    acque.append(P.acqua_piano('acqua_laguna', LG[0] + 0.35, LG[1] + 0.35, LG[2] - 0.35, LG[3] - 0.35, zl + 0.25))
    fine = rG3[-1]
    # l'ultimo salto dentro la laguna
    rF = tratto([(fine.x, fine.y, fine.z), (45.0, 4.6, fine.z - 0.6), (44.5, 3.0, zl + 1.0)], 'rf')
    # l'arco di finti scogli sopra l'ultimo salto e la saracinesca calata (davanti a lei)
    for sg in (-1, 1):
        scoglio(c, 45.2 + sg * 2.4, 4.6, z0, fine.z + 1.5 - z0, 0.9, rnd)
    c.scatola_smussata((42.2, 4.0, fine.z + 1.6), (48.2, 5.2, fine.z + 2.6), 'cemento', s=0.3)
    grata(c, (45.2, 4.6, fine.z - 1.4 + 1.5), (0, -1), True, largo=3.6, alto=3.0)
    # uscita: scaletta e pontile verso la porta di servizio
    scala_pioli(c, LG[0] + 0.2, 0.0, zl - 0.2, porta[1])
    P.piattaforma(c, X0 + 0.1, -4.5, LG[0] + 0.5, -1.5, porta[1], lati=('s', 'n'), pali=False)
    gambe(c, X0 + 0.1, -4.5, LG[0] + 0.5, -1.5, porta[1] - 0.3, z0)
    porta_uscita(c, porta[0], porta[1], luci)

    # --- ambiente pieno: la scenografia della giostra -------------------------------------------------------
    # l'insegna grande sul portale della partenza, i murales (uno per tipo), i cartelli della giostra
    pz = zr - 0.35
    for sg in (-1, 1):
        q = Vector((51.4, 15.0 + sg * (W_B + 0.07), pz))
        c.cilindro(q, q + Vector((0, 0, 3.4)), 0.09, 'gioco_rosso', seg=10)
    c.scatola((51.3, 15.0 - W_B - 0.2, pz + 3.3), (51.5, 15.0 + W_B + 0.2, pz + 3.5), 'gioco_rosso')
    insegna(c, 'insegna_rapide', (51.25, 15.0, pz + 1.95), (-1, 0), 4.6, 1.26)
    luci['fari'].append([[49.4, 15.0, pz + 3.9], [51.25, 15.0, pz + 2.5], [1.0, 0.85, 0.6]])
    # --- la partenza della giostra: la pedana d'imbarco a nord della vasca, con le transenne della coda,
    # la pila di gommoni, la cabina dell'operatore, i cartelli e le lucine (alcune rotte)
    zi = VP[4] + 1.0
    PI = (43.5, VP[3] + 0.2, 50.0, 23.5)
    P.piattaforma(c, PI[0], PI[1], PI[2], PI[3], zi, lati=('n', 'e', 'o'), pali=False)
    gambe(c, PI[0], PI[1], PI[2], PI[3], zi - 0.3, z0)
    for k, yq in enumerate((20.0, 21.3, 22.6)):
        xa, xb = (45.4, 47.4) if k % 2 == 0 else (46.0, 48.0)
        x = xa
        while x <= xb + 0.01:
            c.cilindro((x, yq, zi), (x, yq, zi + 1.0), 0.03, 'metallo_grigio', seg=8)
            x += 0.5
        for h in (0.5, 0.95):
            c.cilindro((xa, yq, zi + h), (xb, yq, zi + h), 0.022, 'gioco_giallo', seg=8)
    props_partenza = [gommone(mats, 'ins_B_gommone_pila_0', (44.75, 20.0, zi), 'gomma_arancio', (0.0, 0.0, 10.0)),
                      gommone(mats, 'ins_B_gommone_pila_1', (44.75, 20.0, zi + 0.64), 'gomma_verde', (0.0, 0.0, 47.0)),
                      gommone(mats, 'ins_B_gommone_pila_2', (44.8, 20.05, zi + 1.28), 'gomma_gialla', (0.0, 0.0, -20.0))]
    # la cabina dell'operatore: muri con la finestra verso la coda, il tetto rosso, il quadro dei comandi
    CB = (48.3, 21.8, PI[2] - 0.12, PI[3] - 0.12)
    hc = 2.3
    c.scatola((CB[0], CB[3] - 0.08, zi), (CB[2], CB[3], zi + hc), 'gioco_giallo')
    c.scatola((CB[2] - 0.08, CB[1], zi), (CB[2], CB[3], zi + hc), 'gioco_giallo')
    c.scatola((CB[0], CB[1], zi), (CB[2], CB[1] + 0.08, zi + 1.0), 'gioco_giallo')
    c.scatola((CB[0], CB[1], zi + 1.95), (CB[2], CB[1] + 0.08, zi + hc), 'gioco_giallo')
    for x in (CB[0], CB[2] - 0.08):
        c.scatola((x, CB[1], zi + 1.0), (x + 0.08, CB[1] + 0.08, zi + 1.95), 'gioco_giallo')
    c.scatola((CB[0], CB[1], zi), (CB[0] + 0.08, CB[1] + 0.5, zi + hc), 'gioco_giallo')
    c.scatola((CB[0] - 0.15, CB[1] - 0.2, zi + hc), (CB[2] + 0.1, CB[3] + 0.1, zi + hc + 0.12), 'gioco_rosso')
    c.scatola((CB[0] + 0.15, CB[1] + 0.1, zi), (CB[2] - 0.15, CB[1] + 0.55, zi + 0.95), 'nero_opaco')
    for k, m_ in enumerate(('faro_rosso', 'faro_giallo', 'faro_giallo', 'faro_rosso')):
        q = Vector((CB[0] + 0.35 + k * 0.28, CB[1] + 0.3, zi + 0.95))
        c.cilindro(q, q + Vector((0, 0, 0.04)), 0.045, m_, seg=10)
    insegna(c, 'cartello_altezza', (PI[0] + 0.05, 21.0, zi + 1.1), (1, 0), 0.9, 0.56)
    q = Vector((47.8, PI[1] + 0.2, zi))
    c.cilindro(q, q + Vector((0, 0, 1.9)), 0.04, 'nero_opaco', seg=8)
    insegna(c, 'cartello_turno', q + Vector((0.0, 0.05, 1.15)), (0, -1), 1.0, 0.62)
    # le lucine della giostra: sul traverso del portale e lungo la ringhiera nord della pedana (alcune rotte)
    luci['lucine'] = []
    k = 0
    y = 15.0 - W_B - 0.15
    while y <= 15.0 + W_B + 0.15:
        luci['lucine'].append([51.4, round(y, 2), pz + 3.52, k % 5 != 3, k % 3])
        y += 0.42
        k += 1
    x = PI[0] + 0.2
    while x <= PI[2] - 0.2:
        luci['lucine'].append([round(x, 2), PI[3] - 0.03, zi + 1.12, k % 4 != 1, k % 3])
        x += 0.55
        k += 1
    luci['fari'].append([[CB[0] - 0.1, CB[1] - 0.15, zi + hc - 0.1], [46.0, 20.5, zi], [1.0, 0.8, 0.55]])
    # i murales, ognuno col suo faro sul traliccio più vicino
    luci['fari'].append([[56.4, 30.0, -9.6], [60.0, 35.8, -13.6], [1.0, 0.92, 0.8], 30.0, 26.0])
    luci['fari'].append([[82.0, 14.4, -9.6], [83.8, 22.0, -14.6], [1.0, 0.92, 0.8], 30.0, 26.0])
    for (x, y, z, rot, graf) in ((60.0, y1 - 0.02, -15.0, 0, 'p1'), (x1 - 0.02, 22.0, -16.0, 90, 'p3')):
        cart = K.cartellone(mats, 5.0, 2.8, nome=f'ins_B_cartellone_{graf}')
        cart.location = Vector((x, y, z))
        cart.rotation_euler = (0, 0, math.radians(rot))
        for j, m in enumerate(cart.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                cart.data.materials[j] = mats.get('cartellone_' + graf)
        acque.append(cart)
    q = Vector((VP[0] + 0.09, 12.3, VP[4] + 1.0))
    c.cilindro(q, q + Vector((0, 0, 1.9)), 0.04, 'nero_opaco', seg=8)
    insegna(c, 'cartello_vietato', q + Vector((0.08, 0, 1.1)), (1, 0), 1.2, 0.75)
    p2 = r2[len(r2) // 3]
    q = p2 + Vector((W_B + 0.07, 0, -0.35))
    c.cilindro(q, q + Vector((0, 0, 2.6)), 0.04, 'nero_opaco', seg=8)
    insegna(c, 'cartello_tenersi', q + Vector((0.0, 0.0, 1.5)), (-1, 0.3), 1.2, 0.75)
    insegna(c, 'cartello_uscita', (X0, porta[0] + 2.0, porta[1] + 1.4), (1, 0), 1.0, 0.62)
    # gli scogli finti contro i muri (un canyon), tutti diversi
    for (x, y, h, r) in ((58.0, 29.0, 6.0, 2.2), (78.0, 31.0, 9.0, 2.5), (80.5, 2.0, 7.0, 2.0), (56.0, -2.5, 5.0, 1.8), (63.5, 15.5, 4.0, 1.5),
                         (47.0, 32.0, 10.0, 2.6), (52.5, 32.6, 7.0, 2.1), (81.6, 24.5, 12.0, 2.3), (70.0, 33.2, 6.0, 1.9), (66.5, -3.6, 6.0, 1.8),
                         (75.0, -3.4, 8.0, 2.0), (42.5, 22.0, 8.0, 1.9)):
        scoglio(c, x, y, z0, h, r, rnd)
    # i fari di scena a terra che illuminano gli scogli più grandi dal basso (colori della giostra)
    for (x, y, h, r, d, col) in ((47.0, 32.0, 10.0, 2.6, (0, -1), (0.4, 0.9, 1.0)), (81.6, 24.5, 12.0, 2.3, (-1, 0), (1.0, 0.6, 0.3)),
                                 (78.0, 31.0, 9.0, 2.5, (0, -1), (0.9, 0.45, 1.0)), (75.0, -3.4, 8.0, 2.0, (0, 1), (0.4, 1.0, 0.7)),
                                 (42.5, 22.0, 8.0, 1.9, (1, 0), (1.0, 0.8, 0.4)), (58.0, 29.0, 6.0, 2.2, (0, -1), (1.0, 0.5, 0.6))):
        q = Vector((x + d[0] * (r + 1.6), y + d[1] * (r + 1.6), z0))
        c.scatola((q.x - 0.25, q.y - 0.25, q.z), (q.x + 0.25, q.y + 0.25, q.z + 0.18), 'nero_opaco')
        c.cilindro(q + Vector((0, 0, 0.18)), q + Vector((0, 0, 0.42)), 0.17, 'nero_opaco', seg=12)
        luci['fari'].append([[q.x, q.y, q.z + 0.45], [x, y, z0 + h * 0.6], list(col), 30.0, 40.0])
    condotta(c, (X0 + 0.5, y1 - 1.5, -11.0), (x1 - 0.5, y1 - 1.5, -11.0), 1.1, muro=('y', y1))
    condotta(c, (x1 - 1.5, y0 + 0.5, -13.0), (x1 - 1.5, y1 - 0.5, -13.0), 1.0, muro=('x', x1))
    passerella_muro(c, X0 + 1.0, x1 - 1.0, y0 + 0.4, -17.0, 1)
    # i tralicci delle luci di scena, coi fari accesi puntati sul canale (il colore della giostra)
    for (x, y, mira, col) in ((56.0, 30.0, (65.0, 22.6, -22.2), (0.55, 1.0, 0.95)), (82.0, 14.0, (78.0, 14.0, -25.5), (1.0, 0.75, 0.4)),
                              (62.0, -4.0, (55.0, 4.5, -29.0), (1.0, 0.55, 0.85))):
        c.cilindro((x, y, z0), (x, y, -9.2), 0.18, 'gioco_rosso', seg=12)
        c.scatola((x - 0.25, y - 0.25, -9.8), (x + 0.25, y + 0.25, -9.4), 'nero_opaco')
        c.anello((x, y, z0), (0, 0, 1), 0.0, 0.45, 0.05, 'metallo', seg=12)
        for k in range(3):
            q = Vector((x, y, -10.5 - k * 0.6))
            c.scatola((q.x - 0.25, q.y - 0.25, q.z - 0.2), (q.x + 0.25, q.y + 0.25, q.z + 0.2), 'nero_opaco')
            luci['fari'].append([[q.x, q.y, q.z], [mira[0] + (k - 1) * 2.5, mira[1], mira[2]], list(col)])
    # i gommoni tondi della giostra, rovesciati e abbandonati (tre colori)
    props = props_partenza + [gommone(mats, 'ins_B_gommone_giallo', (60.8, 14.0, z0 + 0.64), 'gomma_gialla', (180.0, 0.0, 20.0)),
             gommone(mats, 'ins_B_gommone_blu', (57.8, -3.4, z0 + 0.64), 'gomma_blu', (180.0, 0.0, 70.0)),
             gommone(mats, 'ins_B_gommone_rosso', (48.5, 26.0, z0), 'gomma_rossa', (0.0, 0.0, -35.0))]
    for (nome, x, y, z, rot) in (('salvagente_nave', 48.0, 0.0, zl + 0.2, 30), ('paperella_gigante', 70.5, 13.8, b1.z - 2.9 + 1.1, 200),
                                 ('delfino_gonfiabile_sgonfio', 60.0, 26.0, z0 + 0.1, 80),
                                 ('cartello_pavimento_bagnato', 41.0, -2.2, porta[1], 15), ('balena_gonfiabile_sgonfia', 74.0, 2.0, z0 + 0.1, 40)):
        props.append(P.prop(nome, (x, y, z), rot))

    luci['emergenza'] += [[X0 + 0.15, 25.0, -16.0], [x1 - 0.15, 8.0, -20.0], [66.0, y1 - 0.15, -18.0], [52.0, y0 + 0.15, -22.0]]
    luci['lavoro'] += [[VP[0] + 0.3, VP[1] + 0.3, VP[4] + 1.5], [b1.x, b1.y + 2.6, b1.z + 1.6], [b2.x + 2.0, b2.y, b2.z + 1.6],
                       [b3.x + 2.0, b3.y + 1.0, b3.z + 1.6], [LG[0] + 0.6, LG[1] + 0.6, zl + 2.0]]
    luci['acqua_scorre'] += [[p.x, p.y, p.z - 0.4] for p in (r0[0], r2[0], r4[0], rF[-1])]
    luci['lei'] += [[57.0, 17.0, zr - 1.0 - D_B - 1.2, 50.0, 'insegue', 'nuota nel canale dietro di te'],
                    [69.0, 9.5, b2.z - D_B - 0.5, 60.0, 'insegue', 'sale sullo scoglio del bivio 2'],
                    [45.2, 6.6, fine.z - D_B - 0.6, 180.0, 'insegue', 'contro la saracinesca'],
                    [45.9, -1.9, zl + 0.37 - 0.8, 300.0, 'affacciata', 'SB1: sbuca dal pozzo di scarico della laguna']]

    percorso = [('bocca', BOCCA), ('vasca di partenza', Vector(((VP[0] + VP[2]) / 2, 15.0, VP[4])))] + [('canale', p) for p in r0[::4]]
    percorso += [('bivio', b1)] + [('canale', p) for p in rG1[::4]] + [('canale', p) for p in r2[::4]]
    percorso += [('bivio', b2)] + [('canale', p) for p in rG2[::4]] + [('canale', p) for p in r4[::4]]
    percorso += [('bivio', b3)] + [('canale', p) for p in rG3[::4]] + [('grata', Vector((45.2, 4.6, fine.z)))]
    percorso += [('laguna', Vector(((LG[0] + LG[2]) / 2, 0.0, zl))), ('uscita', Vector((X0 + 0.5, porta[0], porta[1])))]
    gr = P.GRATE[0].crea('ins_B_grigliati')
    ob = c.crea('ins_B_struttura', sporco=lambda co: 0.55 + 0.45 * min(1.0, max(0.0, (co.z + 36.0) / 10.0)))
    oc = canali.crea('ins_B_canali', sporco=lambda co: 0.7)
    gruppi = {'struttura': [ob, gr] + acque, 'tubi': tubi + [oc], 'prop': props}
    info = dict(sbagliate=[[p.x, p.y, p.z] for p in (rS1[-1], rS2[-1], rS3[-1])], laguna=list(LG), limiti=[X0, y0, x1, y1, z0, z1])
    return gruppi, percorso, luci, info


VERSIONI = {'A': versione_A, 'B': versione_B}


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    nome = argv[0] if argv else 'A'
    K.svuota()
    S._MODELLI.clear()
    mats = K.Materiali(S.PALETTE_SALA, per_render=False)
    S.materiali_nuovi(mats)
    P.materiali_torre(mats)
    TA.materiali_scivoli(mats)
    gioco = '--gioco' in argv
    uscita, prefisso = USCITA, f'inseguimento_{nome}'
    if gioco:
        assert nome == 'A', "nel gioco c'è solo la A (scelta dell'utente del 19 ottobre)"
        global GIOCO, X0
        GIOCO, X0 = True, X0_GIOCO
        uscita, prefisso = GIOCO_USCITA, 'inseguimento'
    gruppi, percorso, luci, info = VERSIONI[nome](mats)
    os.makedirs(uscita, exist_ok=True)
    if gioco:
        with open(os.path.join(uscita, 'inseguimento_gioco.json'), 'w') as f:
            json.dump(GIOCO_DATI, f, indent=1)
    for g, oggetti in gruppi.items():
        out = os.path.join(uscita, f'{prefisso}_{g}.glb')
        K.esporta(oggetti, out)
        tri = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in oggetti if o.type == 'MESH')
        print(f'GLB {out}: {len(oggetti)} oggetti, {tri} triangoli, {os.path.getsize(out) / 1e6:.1f} MB')
    luci['info'] = info
    with open(os.path.join(uscita, f'{prefisso}_luci.json'), 'w') as f:
        json.dump(luci, f, indent=1)
    with open(os.path.join(uscita, f'{prefisso}_percorso.json'), 'w') as f:
        json.dump([dict(cosa=k, x=round(p.x, 2), y=round(p.y, 2), z=round(p.z, 2)) for k, p in percorso], f, indent=1)
    if '--blend' in argv:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(argv[argv.index('--blend') + 1]))


if __name__ == '__main__':
    main()
