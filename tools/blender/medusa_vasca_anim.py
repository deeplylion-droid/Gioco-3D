"""Animazioni della tappa 8 (docs/livello/capitolo1.md, "lei sbuca dal bordo"), tutte dalla posa affacciata e
nella stessa vasca (marker medusa_affacciata, stessa scala vera):

  - scivola_sotto (60 fotogrammi, 2,5 s): lascia il bordo. Le dita scivolano sul coping all'indietro, le mani
    si staccano verso l'alto e vanno a premersi sul petto (ognuna sul suo seno: resta coperto anche quando il
    busto si raddrizza), poi il busto si stende all'indietro e affonda mentre la campana scivola indietro sul
    fondo; i tentacoli fuori dal bordo si ritirano in acqua. Gli ultimi a sparire sono l'occhio, che resta su chi
    guarda, e la cima dei capelli. Finisce nella posa di nuota_via.
  - nuota_via (48 fotogrammi, 2 s, in ciclo): sott'acqua, stesa sulla schiena con le mani sul petto, la testa
    verso dove va (+Y in Blender, lontano dal bordo) e l'occhio che guarda indietro verso il bordo. La campana
    pulsa come una medusa vera (campana_contrai), il busto ondeggia con la spinta, i tentacoli si allargano
    dietro con un'onda che va verso le punte. Ciclo sul posto: lo spostamento lo fa il motore.
  - afferra (29 fotogrammi, 1,2 s): scatta in avanti oltre il bordo verso chi e' vicino. Sale dall'acqua (la
    campana torna alta), si piega in avanti con le braccia tese ad artiglio, la fauce si apre del tutto e
    l'occhio si accende (blend shape 'venatura' dell'occhio, anche segnale per lo shader). Due zampe salgono
    dall'acqua e si incrociano sul petto. L'ultimo fotogramma tiene la presa.

Le pose sono calcolate in metri nel mondo della vasca (come la posa affacciata: _mod/_mondo con la scala vera k
e il piano zp) e scritte come azioni NLA per il passo 7 (tracce dello scheletro e delle shape key con lo stesso
nome, che l'export glTF unisce in un'animazione sola).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_pose as POSE  # noqa: E402
import medusa_affacciata as AFF  # noqa: E402
import medusa_attacco as ATT  # noqa: E402
import medusa_fauce as FAUCE  # noqa: E402
from mathutils import Quaternion  # noqa: E402

V = AFF.VASCA
_mod, _mondo = AFF._mod, AFF._mondo

# ---------------------------------------------------------------- parametri

# scivola_sotto
SCIVOLA = 60                            # fotogrammi (2,5 s a 24 fps)
VITA_FONDO = (0.0, -0.3, 0.41)          # la campana scivola indietro sul fondo (circa 75 cm), il bordo appena sopra
BUSTO_STESO = (-74.0, -34.0, -11.0)     # colonna_1, colonna_2, petto (gradi): stesa sulla schiena, sott'acqua
COLLO_STESO = 10.0                      # collo e testa appena in avanti: il viso guarda in su, verso il bordo
TESTA_STESA = 14.0
# nella vasca sollevata (0,88 m d'acqua) stesa cosi' ha mani, viso e capelli sott'acqua di 6-35 cm; dietro la nuca
# i capelli passano il fondo (non si vede da sopra): per sparire del tutto servono almeno 0,85 m d'acqua
SGUARDO_VICINO = (0.0, -4.5, 1.7)       # chi guarda dal bordo, a pochi metri
SCORRE_DITA = 0.17                      # di quanto i polsi scivolano indietro sul coping (m)
# nuota_via
NUOTO = 48                              # fotogrammi (2 s), in ciclo
# afferra
AFFERRA = 29                            # fotogrammi (1,2 s)
VITA_SU = (0.0, -0.98, 1.12)            # sale dall'acqua: la campana torna alta e resta sopra il fondo
BUSTO_AVANTI = (34.0, 24.0, 12.0)       # piegata in avanti oltre il bordo
TESTA_AVANTI = (-6.0, -52.0)            # collo, testa: il viso guarda chi e' vicino
GIOCATORE = (0.0, -2.9, 1.62)           # chi si avvicina troppo (occhi), poco fuori dal bordo
POLSI_SU = (0.5, -1.92, 1.3)            # le mani si staccano dal coping verso l'alto, prima di tendersi (x per il lato)
POLSI_AVANTI = (0.3, -2.78, 1.45)       # polsi tesi verso il giocatore (x per il lato)
GOMITI_AVANTI = (1.2, -1.6, 0.9)        # verso dove si piegano i gomiti (x per il lato)
ZAMPE_ALZA = 0.022                      # zampe sul petto piu' in alto mentre il busto sale (modello; 0 a fine scatto)


def _liscio(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def _mix(a, b, w):
    return tuple(float(x) * (1 - w) + float(y) * w for x, y in zip(a, b))


# ---------------------------------------------------------------- corpo

def corpo(arm, k, zp, vita, busto, collo, testa, gobba=(0.0, 0.0)):
    """Vita (cima della campana) nel punto del mondo, busto, collo e testa (gradi), spalle (m: su, avanti)."""
    POSE.azzera(arm)
    vita_riposo = np.array(arm.data.bones['colonna_1'].head_local)
    d = _mod(vita, k, zp) - vita_riposo
    pr = arm.pose.bones['radice']
    pr.matrix = Matrix.Translation(Vector(d)) @ arm.data.bones['radice'].matrix_local
    POSE.aggiorna()
    for nome, gradi in zip(('colonna_1', 'colonna_2', 'petto'), busto):
        pb = arm.pose.bones[nome]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi), 0, 0)
    for nome, (gradi, rollio) in (('collo', (collo, 0.0)), ('testa', testa)):
        pb = arm.pose.bones[nome]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi), 0, math.radians(rollio))
    POSE.aggiorna()
    if gobba[0] or gobba[1]:
        for suf in ('.L', '.R'):
            pb = arm.pose.bones['clavicola' + suf]
            testa_c, coda = np.array(pb.head), np.array(pb.tail)
            nuova = coda + np.array([0.0, -gobba[1] / k, gobba[0] / k])
            POSE.orienta(arm, 'clavicola' + suf, Vector(testa_c), Vector(nuova - testa_c))


def occhio_su(arm, k, zp, bersaglio, massimo=15.0):
    """L'occhio guarda il bersaglio (mondo), al massimo 15 gradi dalla posizione di riposo nella testa."""
    pe = arm.pose.bones['occhio']
    testa_occ = np.array(pe.head)
    dirz = _mod(bersaglio, k, zp) - testa_occ
    dirz /= np.linalg.norm(dirz)
    attuale = np.array(pe.matrix.col[1][:3])
    attuale /= np.linalg.norm(attuale)
    ang = math.acos(np.clip(attuale @ dirz, -1, 1))
    if ang > math.radians(massimo):
        q = Vector(attuale).rotation_difference(Vector(dirz))
        q = Quaternion().slerp(q, math.radians(massimo) / ang)
        dirz = np.array(q @ Vector(attuale))
    POSE.orienta(arm, 'occhio', Vector(testa_occ), Vector(dirz))


# ---------------------------------------------------------------- braccia

def ossa_braccia():
    nomi = []
    for suf in ('.L', '.R'):
        nomi += ['braccio' + suf, 'avambraccio' + suf, 'mano' + suf]
        nomi += [f'{d}_{f}{suf}' for d in POSE.DITA for f in (1, 2, 3)]
    return nomi


def leggi(arm, nomi):
    return {n: arm.pose.bones[n].matrix_basis.copy() for n in nomi}


def scrivi(arm, pose, w=None, altra=None):
    """Scrive le rotazioni locali (matrix_basis); con 'altra' e w le mescola (slerp): braccia che passano con
    continuita' da una posa all'altra, qualunque sia la posa del busto."""
    for n, A in pose.items():
        if altra is None or w is None:
            M = A
        else:
            la, ra, sa = A.decompose()
            lb, rb, sb = altra[n].decompose()
            M = Matrix.LocRotScale(la.lerp(lb, w), ra.slerp(rb, w), sa.lerp(sb, w))
        arm.pose.bones[n].matrix_basis = M
    POSE.aggiorna()


def braccia_bordo(arm, k, zp, scorri=0.0):
    """Mani aggrappate al coping come nella posa affacciata; con scorri (0..1) i polsi scivolano indietro e le
    dita strisciano sul coping (si cercano di nuovo le pieghe che le tengono appoggiate: quando lo spigolo non si
    raggiunge piu' si distendono sulle piastrelle)."""
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = (s * AFF.MANI_X, AFF.POLSO[0] + SCORRE_DITA * scorri, AFF.POLSO[1] + 0.012 * scorri)
        polo = (s * AFF.POLO_GOMITI[0], AFF.POLO_GOMITI[1] + 0.25 * scorri, AFF.POLO_GOMITI[2])
        d_mano = np.array([s * 0.1, -1.0, 0.0])
        d_mano /= np.linalg.norm(d_mano)
        POSE.posa_braccio(arm, suf, Vector(_mod(polso, k, zp)), Vector(_mod(polo, k, zp)), Vector(d_mano),
                          Vector((0.0, 0.0, 1.0)))
        AFF._orienta_dita(arm, suf, d_mano, k, zp, piega_min=20 if scorri <= 0 else 0)
    POSE.aggiorna()


def mani_alzate(arm, k, zp, alza=0.24):
    """Mani appena staccate dalle piastrelle (fine di scivola_sotto): polsi dove le dita hanno smesso di
    strisciare, alzati di 'alza', la mano appena inclinata in su e le dita rilassate: sopra il coping."""
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = (s * AFF.MANI_X, AFF.POLSO[0] + SCORRE_DITA, AFF.POLSO[1] + alza)
        polo = (s * AFF.POLO_GOMITI[0], AFF.POLO_GOMITI[1] + 0.25, AFF.POLO_GOMITI[2] + alza)
        d_mano = np.array([s * 0.1, -1.0, 0.25])
        d_mano /= np.linalg.norm(d_mano)
        POSE.posa_braccio(arm, suf, Vector(_mod(polso, k, zp)), Vector(_mod(polo, k, zp)), Vector(d_mano),
                          Vector((0.0, 0.25, 1.0)))
        POSE.piega_dita(arm, suf, 18 - POSE.DITA_STATUA, pollice=8 - POSE.POLLICE_STATUA)
    POSE.aggiorna()


def braccia_su(arm, k, zp, polsi=POLSI_SU):
    """Mani appena staccate dal coping: polsi in alto sopra il bordo, dita rilassate oltre lo spigolo."""
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = (s * polsi[0], polsi[1], polsi[2])
        polo = (s * 1.1, -1.2, 0.8)
        d_mano = np.array([s * 0.15, -0.8, -0.6])
        d_mano /= np.linalg.norm(d_mano)
        POSE.posa_braccio(arm, suf, Vector(_mod(polso, k, zp)), Vector(_mod(polo, k, zp)), Vector(d_mano),
                          Vector((s * 0.1, -0.5, 0.85)))
        POSE.piega_dita(arm, suf, 12 - POSE.DITA_STATUA, pollice=6 - POSE.POLLICE_STATUA)
    POSE.aggiorna()


def mani_sul_petto(arm, k, zp, palmo=(0.194, -0.6, -0.27), alza=80.0, indietro=25.0, polo=(1.02, -0.95, -1.11),
                   dita=0.0):
    """Mani aperte e premute sul petto, ognuna sul suo seno, con le dita in su verso la clavicola (i gomiti in
    fuori e in basso): il seno resta coperto da davanti, dall'alto e di lato sia col busto dritto sia steso (la
    regola del GDD), senza che le braccia si incrocino o entrino nel corpo. Bersagli nella posa di riposo, in
    frazioni della larghezza delle spalle dal loro punto medio: centro del palmo (x verso il lato della mano),
    direzione della mano (alza: gradi sopra l'orizzontale, verso il centro; indietro: gradi verso il corpo, per
    seguire il petto) e polo del gomito; portati nella posa attuale con l'osso 'petto'."""
    pb = arm.pose.bones['petto']
    D = pb.matrix @ arm.data.bones['petto'].matrix_local.inverted()
    R3 = D.to_3x3()
    sl = np.array(arm.data.bones['braccio.L'].head_local)
    sr = np.array(arm.data.bones['braccio.R'].head_local)
    w = np.linalg.norm(sl - sr)
    mezzo = (sl + sr) / 2
    a, b = math.radians(alza), math.radians(indietro)
    for suf, s in (('.L', 1), ('.R', -1)):
        # in su e un po' verso il centro (-s in x), inclinata indietro verso il corpo (+y)
        dm = np.array([-s * math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b)])
        dm /= np.linalg.norm(dm)
        centro = mezzo + w * np.array([s * palmo[0], palmo[1], palmo[2]])
        polso = centro - 0.1665 * w * dm               # il centro del palmo e' a circa 9 cm dal polso
        pol = mezzo + w * np.array([s * polo[0], polo[1], polo[2]])
        n = np.cross(dm, np.array([-s * 1.0, 0.0, 0.0]))   # dorso della mano in avanti, fuori dal petto
        if n[1] > 0:
            n = -n
        POSE.posa_braccio(arm, suf, D @ Vector(polso), D @ Vector(pol), R3 @ Vector(dm), R3 @ Vector(n))
        POSE.piega_dita(arm, suf, dita - POSE.DITA_STATUA, pollice=8 - POSE.POLLICE_STATUA)
        pollice_steso(arm, suf)
    POSE.aggiorna()


def pollice_steso(arm, suf, apertura=28.0, dorso=-0.12):
    """Pollice accostato alla mano, quasi nel piano del palmo: con la mano appoggiata al petto
    non entra nel corpo (quello di riposo va verso il palmo, per le mani giunte della statua)."""
    pm = arm.pose.bones['mano' + suf]
    y = np.array(pm.matrix.col[1][:3])
    z = np.array(pm.matrix.col[2][:3])
    y /= np.linalg.norm(y)
    z = z - (z @ y) * y
    z /= np.linalg.norm(z)
    x = np.cross(y, z)
    nomi = [f'pollice_{f}{suf}' for f in (1, 2, 3)]
    testa = np.array(arm.pose.bones[nomi[0]].head)
    if (testa - np.array(pm.head)) @ x < 0:
        x = -x                                         # x verso il pollice
    a = math.radians(apertura)
    p = testa
    for i, n in enumerate(nomi):
        ai = a - math.radians(6.0) * i                 # le falangi tornano appena verso l'indice
        d = y * math.cos(ai) + x * math.sin(ai) + z * dorso
        d /= np.linalg.norm(d)
        POSE.orienta(arm, n, Vector(p), Vector(d), Vector(0.62 * x + 0.78 * z))   # unghia come a riposo
        p = p + d * arm.data.bones[n].length


def braccia_petto(arm):
    """Mani giunte sul petto: la posa di riposo delle braccia (la statua), che segue il busto."""
    for n in ossa_braccia():
        arm.pose.bones[n].matrix_basis = Matrix()
    POSE.aggiorna()


def braccia_avanti(arm, k, zp, artiglio=1.0):
    """Braccia tese verso il giocatore, mani aperte ad artiglio."""
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = (s * POLSI_AVANTI[0], POLSI_AVANTI[1], POLSI_AVANTI[2])
        polo = (s * GOMITI_AVANTI[0], GOMITI_AVANTI[1], GOMITI_AVANTI[2])   # gomiti in fuori e in basso
        d_mano = np.array([s * 0.12, -1.0, 0.05])
        d_mano /= np.linalg.norm(d_mano)
        dorso = (s * 0.15, 0.05, 1.0)
        POSE.posa_braccio(arm, suf, Vector(_mod(polso, k, zp)), Vector(_mod(polo, k, zp)), Vector(d_mano),
                          Vector(dorso))
        POSE.piega_dita(arm, suf, 42 * artiglio - POSE.DITA_STATUA, pollice=18 * artiglio - POSE.POLLICE_STATUA)
    POSE.aggiorna()


# ---------------------------------------------------------------- tentacoli

def _ricampiona(pts, n=64):
    """Polilinea ricampionata a n punti alla stessa distanza (per mescolare due percorsi)."""
    P = np.asarray(pts, float)
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))]
    s = np.linspace(0, L[-1], n)
    return np.stack([np.interp(s, L, P[:, i]) for i in range(3)], 1)


def _tronca(pts, L):
    """Polilinea tagliata alla lunghezza L (allungata in linea retta se e' piu' corta)."""
    P = np.asarray(pts, float)
    seg = np.linalg.norm(np.diff(P, axis=0), axis=1)
    cum = np.r_[0, np.cumsum(seg)]
    if cum[-1] <= L:
        d = P[-1] - P[-2]
        d /= np.linalg.norm(d) + 1e-12
        return np.vstack([P, P[-1] + d * (L - cum[-1] + 1e-6)])
    j = int(np.searchsorted(cum, L))
    t = (L - cum[j - 1]) / max(seg[j - 1], 1e-12)
    return np.vstack([P[:j], P[j - 1] + (P[j] - P[j - 1]) * t])


def mescola_percorsi(A, B, w, gonfia=None, lunghezza=None):
    """Percorso a meta' tra A e B (punti alla stessa frazione di lunghezza); 'gonfia' (funzione punto -> vettore)
    lo allontana dal corpo a meta' strada. Con 'lunghezza' (quella della catena, con un po' di margine) si
    mescolano solo i tratti dei due percorsi che la catena usa davvero: il resto (per esempio la parte fuori dal
    bordo di un tentacolo gia' ritirato) non tira la catena attraverso il muro."""
    if w <= 0:
        return np.asarray(A, float)
    if w >= 1:
        return np.asarray(B, float)
    if lunghezza is not None:
        A, B = _tronca(A, lunghezza), _tronca(B, lunghezza)
    a, b = _ricampiona(A), _ricampiona(B)
    m = a * (1 - w) + b * w
    if gonfia is not None:
        m = m + np.array([gonfia(p) for p in m]) * math.sin(math.pi * w)
    return m


def _ansa(W1, vita, phi, verso):
    """Ansa sott'acqua che raccoglie un tentacolo tirato indietro: da W1 gira intorno alla campana verso il dietro
    per phi radianti, a mezz'acqua, e torna indietro un po' piu' larga (una U larga fino a 35 cm, che i giunti
    seguono anche con ossa lunghe). Coordinate del mondo; vuota per phi = 0."""
    if phi <= 0:
        return []
    c = np.array(vita[:2], float)
    p = np.array(W1[:2], float) - c
    r0 = float(np.linalg.norm(p))
    az0 = math.atan2(p[1], p[0])
    r_in = max(r0, 1.0)
    largo = 0.35 * min(phi / 0.4, 1.0)
    lim = V['mezza_larghezza'] - 0.15
    n = max(int(math.ceil(phi / 0.1)), 2)
    pts = []
    for i in range(1, n + 1):
        f = i / n
        a = az0 + verso * phi * f
        r = r0 + (r_in - r0) * min(3 * f, 1.0)
        pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a), 0.1 + 0.15 * f))
    for i in range(n, -1, -1):
        f = i / n
        a = az0 + verso * phi * f
        r = r_in + largo
        pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a), 0.3 + 0.1 * f))
    return [(float(np.clip(x, -lim, lim)), float(np.clip(y, V['dentro'] + 0.15, lim)), z) for x, y, z in pts]


def _ascissa(P, q):
    """Ascissa curvilinea del punto della polilinea P piu' vicino a q."""
    P = np.asarray(P, float)
    a, b = P[:-1], P[1:]
    ab = b - a
    t = np.clip(np.einsum('ij,ij->i', q - a, ab) / np.maximum(np.einsum('ij,ij->i', ab, ab), 1e-12), 0, 1)
    d = np.linalg.norm(a + ab * t[:, None] - q, axis=1)
    j = int(np.argmin(d))
    seg = np.linalg.norm(ab, axis=1)
    return float(seg[:j].sum() + seg[j] * t[j])


def ritira(c, k, zp, vita, u):
    """Tentacolo che usciva dal bordo, tirato indietro (u 0..1): la punta torna indietro lungo il suo percorso,
    sopra il coping (che il tentacolo tirato non tocca piu') e giu' nella vasca; la lunghezza in piu' si raccoglie
    in un'ansa sott'acqua intorno alla campana, verso il dietro (come una corda tirata). L'ansa si allarga finche'
    la catena vera (giunti alla distanza delle ossa) ha la punta dove deve: a u = 1 il tentacolo e' tutto dentro,
    30 cm prima del fondo del muro. Punti nello spazio dello scheletro."""
    R_mod = c['R_mod']
    W = AFF.percorso_bordo(c['R'], c['x_t'], c['verso'], c['curva'], c['z_fondo'], c['g'], vita)
    if u <= 0:
        return [R_mod] + [_mod(p, k, zp) for p in W[1:]]
    # tirato, il tentacolo si stacca dal bordo: sale sopra il coping e si scosta dai muri
    alza = 0.06 * min(u * 5, 1) + 0.06 * math.sin(math.pi * min(u * 1.25, 1.0))
    W = [list(p) for p in W]
    W[3][1] += 0.08 * min(u * 3, 1)
    for j in (4, 5):
        W[j][2] += alza
    W[6][1] -= 0.05 * min(u * 3, 1)
    W[6][2] += alza * 0.6
    az = math.atan2(c['R'][1] - vita[1], c['R'][0] - vita[0])
    verso = 1.0 if math.cos(az) >= 0 else -1.0
    lunghezze = c['lunghezze']

    def percorso(phi):
        return [R_mod] + [_mod(p, k, zp) for p in [W[1]] + _ansa(W[1], vita, phi, verso) + W[2:]]

    def oltre(phi):
        """Quanta catena va oltre il fondo del muro (W2), in metri: negativa se la punta e' prima."""
        P = percorso(phi)
        G = AFF.giunti_catena(P, lunghezze)
        s2 = _ascissa(P, _mod(W[2], k, zp))
        return (_ascissa(P, G[-1]) - s2) * k
    O0 = oltre(0.0)
    bersaglio = (1 - u) * O0 - u * 0.3
    lo, hi = 0.0, math.radians(170)
    if oltre(hi) > bersaglio:
        return percorso(hi)
    for _ in range(14):
        mid = 0.5 * (lo + hi)
        if oltre(mid) > bersaglio:
            lo = mid
        else:
            hi = mid
    return percorso(hi)


def percorso_nuoto(c, k, zp, vita, t):
    """Tentacolo che nuota con lei: come quelli sott'acqua della posa affacciata (scende sotto il bordo della
    campana e le gira intorno a mezz'acqua, nella vasca), con un'onda che scende verso la punta (t: fase del
    ciclo, 0..1), raggio e altezza che ondeggiano. Punti nello spazio dello scheletro."""
    rng = np.random.default_rng(100 + c['i'])
    R = np.array(c['R'], float)
    L = sum(c['lunghezze']) * k
    az = math.atan2(R[1] - vita[1], R[0] - vita[0])
    cx, cy = vita[0], vita[1]
    pts = [R, (R[0] + 0.25 * math.cos(az), R[1] + 0.25 * math.sin(az), 0.075)]
    verso = 1.0 if math.cos(az) >= 0 else -1.0
    r0 = rng.uniform(1.15, 1.5)
    giro = min(L / r0, math.radians(150))
    fase = rng.uniform(0, 2 * math.pi)
    n = 24
    lim = V['mezza_larghezza'] - 0.12
    for i in range(1, n + 1):
        f = i / n
        a = az + verso * giro * f + 0.12 * f * math.sin(2 * math.pi * (1.3 * f - t) + fase)
        r = r0 + 0.14 * f * math.sin(2 * math.pi * (1.5 * f - t) + fase)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        x = float(np.clip(x, -lim, lim))
        y = float(np.clip(y, V['dentro'] + 0.15, lim))
        z = 0.1 + 0.4 * f + 0.09 * math.sin(2 * math.pi * (2 * f - t) + fase)
        pts.append((x, y, min(z, V['acqua'] - 0.1)))
    return [_mod(p, k, zp) for p in pts]


def sposta_in_vasca(c, k, zp, vita):
    """Tentacolo sott'acqua della posa affacciata che segue la campana spostata in 'vita' (stesso percorso,
    traslato), tenuto dentro i muri della vasca. Punti nello spazio dello scheletro."""
    d = np.array(vita, float) - np.array(AFF.VITA, float)
    lim = V['mezza_larghezza'] - 0.12
    out = [c['R_mod']]
    for p in c['pts'][1:]:
        w = _mondo(p, k, zp) + d
        w[0] = np.clip(w[0], -lim, lim)
        w[1] = np.clip(w[1], V['dentro'] + 0.15, lim)
        out.append(_mod(w, k, zp))
    return out


def catene_vasca(arm, k, zp):
    """Le catene dei tentacoli con il loro ruolo nella posa affacciata (calcolato una volta, dalla posa)."""
    perc = AFF.percorsi_tentacoli(arm, k, zp)
    for c in perc:
        c['lunghezze'] = [arm.data.bones[n].length for n in c['nomi']]
    return perc


def radici(arm, k, zp, catene, vita, schiaccia):
    """Radici dei tentacoli nella posa attuale (mondo e modello), con la campana schiacciata di 'schiaccia': le
    ossa non si schiacciano (lo fa la shape key), quindi la radice sale con il bordo della campana, come nella
    posa affacciata."""
    vita_w = np.array(vita, float)
    for c in catene:
        R = _mondo(np.array(arm.pose.bones[c['nomi'][0]].head), k, zp)
        R[2] = vita_w[2] - (vita_w[2] - R[2]) * (1.0 - schiaccia * (1.0 - AFF.SCHIACCIA[0]))
        c['R'] = R
        c['R_mod'] = _mod(R, k, zp)


def metti(arm, nomi, pts):
    AFF.adatta_catena(arm, nomi, pts)


def mescola_catene(arm, nomi, A, B, w, k=1.0, zp=0.0):
    """Catena a meta' fra quella sul percorso A e quella sul percorso B: ogni osso prende la direzione a meta'
    (slerp nel mondo, non nella gerarchia) e i giunti si rifanno dalla radice con le lunghezze vere. Le ossa non
    si allungano e la forma passa con continuita' dall'una all'altra, senza le torsioni che si sommano lungo la
    catena mescolando le rotazioni locali."""
    L = [arm.data.bones[n].length for n in nomi]
    JA = AFF.giunti_catena(A, L)
    JB = AFF.giunti_catena(B, L)
    p = np.asarray(JA[0], float)
    J = [p]
    for i in range(len(L)):
        a = Vector(JA[i + 1] - JA[i]).normalized()
        b = Vector(JB[i + 1] - JB[i]).normalized()
        d = np.array(a.slerp(b, w, a if a.dot(b) > -0.999 else Vector((0.0, 0.0, 1.0))))
        p = p + d * L[i]
        J.append(p)
    # a meta' strada la catena puo' allargarsi: i giunti restano dentro i muri, sopra il fondo e sott'acqua
    # (qualche passata: dentro la scatola, poi di nuovo le lunghezze delle ossa dalla radice)
    lim = V['mezza_larghezza'] - 0.14
    lo = np.array([-lim, V['dentro'] + 0.16, 0.1])
    hi = np.array([lim, lim, V['acqua'] - 0.14])
    Jw = [_mondo(q, k, zp) for q in J]
    Lw = [x * k for x in L]
    for _ in range(6):
        for i in range(1, len(Jw)):
            Jw[i] = np.clip(Jw[i], lo, hi)
        for i in range(1, len(Jw)):
            d = Jw[i] - Jw[i - 1]
            Jw[i] = Jw[i - 1] + d / (np.linalg.norm(d) + 1e-12) * Lw[i - 1]
    J = [_mod(q, k, zp) for q in Jw]
    for i, n in enumerate(nomi):
        POSE.orienta(arm, n, Vector(J[i]), Vector(J[i + 1] - J[i]))


# ---------------------------------------------------------------- shape key nelle azioni

def chiavi_forma(nome, valori, nla):
    """Azioni delle shape key: valori = {oggetto: {shape key: [(fotogramma, valore), ...]}}."""
    for ob_nome, chiavi in valori.items():
        ob = bpy.data.objects.get(ob_nome)
        if ob is None or not ob.data.shape_keys:
            continue
        key = ob.data.shape_keys
        act = bpy.data.actions.new(f'{nome}_{ob_nome}')
        ad = key.animation_data or key.animation_data_create()
        ad.action = act
        for kname, punti in chiavi.items():
            kb = key.key_blocks.get(kname)
            if kb is None:
                continue
            for f, v in punti:
                kb.value = v
                kb.keyframe_insert('value', frame=f)
            kb.value = 0.0
        nla(key, nome, act)


def _campana(valore_schiaccia, frames):
    out = {}
    for ob in ('Medusa', 'Medusa_Interno', 'Medusa_Bordo'):
        out[ob] = {'campana_schiaccia': [(f, valore_schiaccia(f)) for f in frames]}
    return out


# ---------------------------------------------------------------- 1. scivola_sotto

def stato_scivola(t):
    """Parametri della posa a meta' di scivola_sotto (t: 0..1)."""
    ant = math.sin(math.pi * min(t / 0.12, 1.0)) if t < 0.12 else 0.0          # un attimo di presa piu' forte
    scorri = _liscio(0.06, 0.26, t)        # le dita strisciano indietro sulle piastrelle
    mani = _liscio(0.24, 0.42, t)          # poi si staccano e vanno sul petto, prima che il busto si raddrizzi
    indietro = _liscio(0.36, 0.88, t)
    stende = _liscio(0.4, 0.92, t)
    testa = _liscio(0.38, 0.9, t)
    ritiro = _liscio(0.18, 0.7, t)
    nuoto = _liscio(0.72, 1.0, t)
    vita_n, busto_n, collo_n, testa_n = corpo_nuoto(0.0)      # finisce nella prima posa di nuota_via
    vita = _mix(AFF.VITA, vita_n, indietro)
    busto = _mix(AFF.INCLINA, busto_n, stende)
    su = math.sin(math.pi * _liscio(0.6, 0.98, t))      # mentre affonda tiene il viso su, verso chi guarda
    collo = AFF.COLLO * (1 - testa) + collo_n * testa + 16.0 * su
    testa_r = (AFF.TESTA[0] * (1 - testa) + testa_n[0] * testa - 4.0 * ant + 10.0 * su, AFF.TESTA[1] * (1 - testa))
    gobba = (AFF.GOBBA[0] * (1 - mani) + 0.02 * ant, AFF.GOBBA[1] * (1 - mani))
    return dict(vita=vita, busto=busto, collo=collo, testa=testa_r, gobba=gobba, scorri=scorri, mani=mani,
                ritiro=ritiro, nuoto=nuoto)


def posa_scivola(arm, k, zp, catene, t):
    S = stato_scivola(t)
    corpo(arm, k, zp, S['vita'], S['busto'], S['collo'], S['testa'], S['gobba'])
    nomi_b = ossa_braccia()
    if S['mani'] >= 1:
        mani_sul_petto(arm, k, zp)
    else:
        braccia_bordo(arm, k, zp, S['scorri'])
        if S['mani'] > 0:
            # dalle piastrelle le mani si alzano dritte (le dita non attraversano il coping), poi vanno sul petto
            bordo = leggi(arm, nomi_b)
            mani_alzate(arm, k, zp)
            alzate = leggi(arm, nomi_b)
            mani_sul_petto(arm, k, zp)
            petto = leggi(arm, nomi_b)
            m = S['mani']
            if m < 0.4:
                scrivi(arm, bordo, _liscio(0.0, 0.4, m), alzate)
            else:
                scrivi(arm, alzate, _liscio(0.4, 1.0, m), petto)
    occhio_su(arm, k, zp, _mix(AFF.SGUARDO, SGUARDO_VICINO, _liscio(0.0, 0.2, t)))
    radici(arm, k, zp, catene, S['vita'], 1.0)
    for c in catene:
        if c['ruolo'] == 'bordo':
            A = ritira(c, k, zp, S['vita'], S['ritiro'])
        else:
            A = sposta_in_vasca(c, k, zp, S['vita'])
        if S['nuoto'] > 0:
            # verso il nuoto si mescolano le direzioni delle ossa: la catena resta lunga uguale e la punta gira
            # con continuita' intorno alla campana
            mescola_catene(arm, c['nomi'], A, percorso_nuoto(c, k, zp, S['vita'], 0.0), S['nuoto'], k, zp)
        else:
            metti(arm, c['nomi'], A)
    POSE.aggiorna()
    return S


def azione_scivola_sotto(arm, k, zp, chiave, nla, catene):
    act = bpy.data.actions.new('scivola_sotto')
    (arm.animation_data or arm.animation_data_create()).action = act
    # chiavi ogni 2 fotogrammi; ogni fotogramma quando i tentacoli passano alla posa del nuoto (cambiano in fretta)
    frames = list(range(1, 42, 2)) + list(range(42, SCIVOLA + 2))
    for f in frames:
        t = (f - 1) / SCIVOLA
        posa_scivola(arm, k, zp, catene, t)
        chiave(arm, f)
    nla(arm, 'scivola_sotto', act)
    chiavi_forma('scivola_sotto', _campana(lambda f: 1.0, (1, SCIVOLA + 1)), nla)
    POSE.azzera(arm)


# ---------------------------------------------------------------- 2. nuota_via

def corpo_nuoto(t):
    """Vita, busto, collo e testa nel ciclo di nuoto (t: 0..1): la spinta della campana muove appena il busto,
    con un'onda che sale dalla vita alla testa."""
    def onda(ritardo):                       # 0 all'inizio del ciclo, 1 a meta' (con un ritardo che sale)
        return 0.5 * (1 - math.cos(2 * math.pi * t - ritardo)) - 0.5 * (1 - math.cos(ritardo))
    spinta = math.sin(2 * math.pi * t)
    vita = (VITA_FONDO[0], VITA_FONDO[1] + 0.025 * max(spinta, 0), VITA_FONDO[2] - 0.012 * onda(0.0))
    busto = (BUSTO_STESO[0] - 2.0 * onda(0.0), BUSTO_STESO[1] - 1.5 * onda(0.7), BUSTO_STESO[2] - 1.0 * onda(1.4))
    collo = COLLO_STESO + 2.0 * onda(1.8)
    testa = (TESTA_STESA + 2.0 * onda(2.2), 0.0)
    return vita, busto, collo, testa


def posa_nuoto(arm, k, zp, catene, t):
    """Posa del ciclo di nuoto (t: 0..1)."""
    vita, busto, collo, testa = corpo_nuoto(t)
    corpo(arm, k, zp, vita, busto, collo, testa)
    mani_sul_petto(arm, k, zp)
    occhio_su(arm, k, zp, SGUARDO_VICINO)
    radici(arm, k, zp, catene, vita, 1.0)
    for c in catene:
        B = percorso_nuoto(c, k, zp, vita, t)
        mescola_catene(arm, c['nomi'], B, B, 1.0, k, zp)      # come alla fine di scivola_sotto: dentro la vasca
    POSE.aggiorna()


def azione_nuota_via(arm, k, zp, chiave, nla, catene):
    act = bpy.data.actions.new('nuota_via')
    (arm.animation_data or arm.animation_data_create()).action = act
    for f in range(1, NUOTO + 2, 3):
        posa_nuoto(arm, k, zp, catene, (f - 1) / NUOTO)
        chiave(arm, f)
    nla(arm, 'nuota_via', act)
    # la campana pulsa come quella di una medusa vera: si chiude in fretta (spinta), si riapre piano
    pulsa = [(1, 0.0), (9, 0.85), (17, 0.55), (29, 0.12), (41, 0.0), (49, 0.0)]
    valori = _campana(lambda f: 1.0, (1, NUOTO + 1))
    for ob in valori:
        valori[ob]['campana_contrai'] = pulsa
    chiavi_forma('nuota_via', valori, nla)
    POSE.azzera(arm)


# ---------------------------------------------------------------- 3. afferra

def stato_afferra(t):
    ant = math.sin(math.pi * min(t / 0.13, 1.0)) if t < 0.13 else 0.0
    x = min(max((t - 0.18) / 0.28, 0.0), 1.0)
    scatto = 1 - (1 - x) ** 3                                               # parte di scatto, frena alla fine
    oltre = 0.05 * math.sin(math.pi * min(max((t - 0.38) / 0.45, 0.0), 1.0))  # un filo oltre, poi torna
    L = min(scatto + oltre, 1.06)
    # le due zampe salgono sul petto subito, prima che il busto esca dall'acqua (regola del GDD sul seno)
    return dict(ant=ant, L=L, stacca=_liscio(0.02, 0.14, t), braccia=_liscio(0.1, 0.4, t), zampe=_liscio(0.0, 0.17, t),
                fauce=_liscio(0.22, 0.52, t), vene=_liscio(0.08, 0.45, t))


def posa_afferra(arm, k, zp, catene, t):
    S = stato_afferra(t)
    L = S['L']
    vita = _mix(AFF.VITA, VITA_SU, min(L, 1.0))
    vita = (vita[0], vita[1] - 0.04 * max(L - 1.0, 0) / 0.06, vita[2] - 0.03 * S['ant'])
    busto = _mix(AFF.INCLINA, BUSTO_AVANTI, L)
    collo = AFF.COLLO * (1 - L) + TESTA_AVANTI[0] * L
    testa = (AFF.TESTA[0] * (1 - L) + TESTA_AVANTI[1] * L + 6.0 * S['ant'], AFF.TESTA[1] * (1 - L))
    gobba = (AFF.GOBBA[0] * (1 - L) + 0.03 * S['ant'], AFF.GOBBA[1] * (1 - L) + 0.04 * L)
    schiaccia = 1.0 - min(L, 1.0)
    corpo(arm, k, zp, vita, busto, collo, testa, gobba)
    nomi_b = ossa_braccia()
    braccia_bordo(arm, k, zp, 0.0)
    bordo = leggi(arm, nomi_b)
    braccia_su(arm, k, zp)                          # prima si staccano dal coping verso l'alto
    su = leggi(arm, nomi_b)
    braccia_avanti(arm, k, zp, 1.0)
    avanti = leggi(arm, nomi_b)
    scrivi(arm, bordo, S['stacca'], su)
    if S['braccia'] > 0:
        mezzo = leggi(arm, nomi_b)
        scrivi(arm, mezzo, S['braccia'], avanti)
    occhio_su(arm, k, zp, _mix(AFF.SGUARDO, GIOCATORE, _liscio(0.0, 0.15, t)))
    FAUCE.apri_fauce(arm, S['fauce'])
    radici(arm, k, zp, catene, vita, schiaccia)
    dietro = ATT.zampe_dietro(arm)
    sul_petto = {tuple(n): s for s, n in dietro.items()}
    asse = (_mod(vita, k, zp), np.array(arm.pose.bones['collo'].head))
    for c in catene:
        if c['ruolo'] == 'bordo':
            A = ritira(c, k, zp, vita, 0.0)
        else:
            A = sposta_in_vasca(c, k, zp, vita)
        s = sul_petto.get(tuple(c['nomi']))
        if s is not None and S['zampe'] > 0:
            # mentre il busto sale lo si guarda piu' dall'alto: le zampe stanno un po' piu' su, poi scendono
            perc = ATT.percorso_petto(arm, bpy.data.objects['Medusa'], c['nomi'], s,
                                      ZAMPE_ALZA * (1 - _liscio(0.55, 1.0, L)))
            if perc is not None:
                B, normali = perc
                # il tratto intorno alla campana segue la campana schiacciata (come le radici), la radice e' quella
                f_sch = 1.0 - schiaccia * (1.0 - AFF.SCHIACCIA[0])
                Bw = np.array([_mondo(q, k, zp) for q in B])
                sotto = Bw[:, 2] < vita[2]
                Bw[sotto, 2] = vita[2] - (vita[2] - Bw[sotto, 2]) * f_sch
                B = [c['R_mod']] + [_mod(q, k, zp) for q in Bw[1:]]

                def fuori(p, a=asse[0], b=asse[1]):
                    ab = b - a
                    u = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
                    r = p - (a + u * ab)
                    return r / (np.linalg.norm(r) + 1e-9) * (0.35 / k)
                if S['zampe'] >= 1:
                    ATT.metti_zampa(arm, c['nomi'], B, normali)
                    continue
                A = mescola_percorsi(A, B, S['zampe'], fuori, lunghezza=1.1 * sum(c['lunghezze']))
                # a meta' strada: sopra il fondo e, sotto il coping, dentro il muro davanti
                Aw = np.array([_mondo(q, k, zp) for q in A[1:]])
                Aw[:, 2] = np.maximum(Aw[:, 2], 0.12)
                basso = Aw[:, 2] < V['cima'] + 0.05
                Aw[basso, 1] = np.maximum(Aw[basso, 1], V['dentro'] + 0.14)
                A = [A[0]] + [_mod(q, k, zp) for q in Aw]
        metti(arm, c['nomi'], A)
    POSE.aggiorna()
    return S


def azione_afferra(arm, k, zp, chiave, nla, catene):
    act = bpy.data.actions.new('afferra')
    (arm.animation_data or arm.animation_data_create()).action = act
    # ogni fotogramma all'inizio (le zampe salgono in fretta sul petto), poi ogni 2
    frames = list(range(1, 13)) + list(range(13, AFFERRA + 1, 2))
    if frames[-1] != AFFERRA:
        frames.append(AFFERRA)
    stati = {}
    for f in frames:
        t = (f - 1) / (AFFERRA - 1)
        stati[f] = posa_afferra(arm, k, zp, catene, t)
        chiave(arm, f)
    nla(arm, 'afferra', act)
    valori = _campana(lambda f: 1.0 - min(stati[f]['L'], 1.0), frames)
    valori['Medusa']['fauce_strappo'] = [(f, stati[f]['fauce']) for f in frames]
    for ob in ('Medusa_Gola', 'Medusa_Denti', 'Medusa_Strappo'):
        valori[ob] = {'fauce_aperta': [(f, stati[f]['fauce']) for f in frames]}
    valori['Medusa_Occhio'] = {'venatura': [(f, stati[f]['vene']) for f in frames]}
    chiavi_forma('afferra', valori, nla)
    FAUCE.apri_fauce(arm, 0.0)
    POSE.azzera(arm)


# ---------------------------------------------------------------- tutte

def azioni_vasca(arm, k, zp, chiave, nla):
    """Le tre animazioni della tappa 8 (dal passo 7, dopo l'azione affacciata, prima della scala vera)."""
    import time
    t0 = time.time()
    AFF.posa_affacciata(arm, k, zp)
    catene = catene_vasca(arm, k, zp)
    azione_scivola_sotto(arm, k, zp, chiave, nla, catene)
    azione_nuota_via(arm, k, zp, chiave, nla, catene)
    azione_afferra(arm, k, zp, chiave, nla, catene)
    log(f'animazioni della vasca: scivola_sotto ({SCIVOLA} f), nuota_via ({NUOTO} f, ciclo), afferra ({AFFERRA} f)'
        f' in {time.time() - t0:.0f} s')
