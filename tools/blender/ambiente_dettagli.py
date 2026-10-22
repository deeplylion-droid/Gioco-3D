"""Dettagli della sala principale (passata di qualità).

- sporco in spazio mondo nei colori dei vertici (niente ripetizioni: macchie grandi, umidità che
  risale, colature dall'alto, angoli più sporchi, linea dell'acqua nella piscina);
- pavimento con un solo materiale (l'umidità sfumata è nei colori dei vertici; i materiali diversi
  piastrella per piastrella facevano chiazze a quadretti) e pozzanghere a specchio opache, 3 mm sopra
  il pavimento, che seguono le zone bagnate;
- funzioni di rumore (numpy) usate anche dalle texture.

Lo usa tools/blender/ambiente_sala.py (che va lanciato come script: importa questo modulo).
"""
import math
import numpy as np
import bpy
from mathutils import Vector

import ambiente_kit as K
import ambiente_sala as S   # import circolare voluto: qui si leggono solo costanti, al momento della chiamata


# ----------------------------------------------------------------------------- rumore (numpy)

def _hash(ix, iy, iz, seme):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ ((seme * 2654435761) & 0xFFFFFFFF)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float64) / 16777216.0


def rumore3(P, scala=1.0, seme=0):
    """Value noise 3D liscio (0..1) nei punti P (n, 3), in metri x scala."""
    Q = np.asarray(P, np.float64) * scala
    i = np.floor(Q).astype(np.int64)
    f = Q - i
    u = f * f * (3 - 2 * f)
    r = np.zeros(len(Q))
    for dx in (0, 1):
        wx = u[:, 0] if dx else 1 - u[:, 0]
        for dy in (0, 1):
            wy = u[:, 1] if dy else 1 - u[:, 1]
            for dz in (0, 1):
                wz = u[:, 2] if dz else 1 - u[:, 2]
                r += wx * wy * wz * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seme)
    return r


def fbm3(P, scala=1.0, ottave=4, seme=0):
    """Somma di ottave di rumore (0..1, media 0,5)."""
    tot = np.zeros(len(P))
    amp, norma = 1.0, 0.0
    for o in range(ottave):
        tot += amp * rumore3(P, scala * (2.03 ** o), seme + 101 * o)
        norma += amp
        amp *= 0.5
    return tot / norma


def liscio(e0, e1, x):
    t = np.clip((np.asarray(x, np.float64) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def p3(x, y, z=None):
    x = np.asarray(x, np.float64)
    y = np.asarray(y, np.float64)
    z = np.zeros_like(x) if z is None else np.asarray(z, np.float64)
    return np.stack([x, y, z], -1)


# ----------------------------------------------------------------------------- colori dei vertici

def colora(ob, funz):
    """Colori dei vertici calcolati in spazio mondo: funz(P, N) -> valori 0..1 (uno per angolo,
    oppure (n, 3)). Il valore finisce nel byte del colore così com'è: in Godot moltiplica l'albedo
    (vertex_color_use_as_albedo, vedi godot/ambiente_post_import.gd)."""
    if ob is None or ob.type != 'MESH':
        return
    me = ob.data
    nl = len(me.loops)
    if nl == 0:
        return
    a = me.color_attributes.get('Col') or me.color_attributes.new('Col', 'BYTE_COLOR', 'CORNER')
    vi = np.empty(nl, np.int64)
    me.loops.foreach_get('vertex_index', vi)
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3)
    mw = np.array(ob.matrix_world)
    P = co[vi] @ mw[:3, :3].T + mw[:3, 3]
    npol = len(me.polygons)
    ls = np.empty(npol, np.int64); me.polygons.foreach_get('loop_start', ls)
    lt = np.empty(npol, np.int64); me.polygons.foreach_get('loop_total', lt)
    pidx = np.empty(nl, np.int64)
    if np.all(np.diff(ls) >= 0):
        pidx[:] = np.repeat(np.arange(npol), lt)
    else:
        for i in range(npol):
            pidx[ls[i]:ls[i] + lt[i]] = i
    pn = np.empty(npol * 3); me.polygons.foreach_get('normal', pn)
    N = pn.reshape(-1, 3)[pidx] @ mw[:3, :3].T
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    v = np.clip(np.asarray(funz(P, N), np.float64), 0.0, 1.0)
    rgb = np.repeat(v[:, None], 3, 1) if v.ndim == 1 else v
    col = np.ones((nl, 4), np.float32)
    col[:, :3] = rgb
    a.data.foreach_set('color_srgb', col.ravel())
    me.color_attributes.active_color = a


# ----------------------------------------------------------------------------- campi della sala

def dist_muri(x, y):
    return np.minimum(np.minimum(x - S.X0, S.X1 - x), np.minimum(y - S.Y0, S.Y1 - y))


def dist_rett(x, y, x0, y0, x1, y1):
    """Distanza dal rettangolo (0 dentro)."""
    dx = np.maximum(np.maximum(x0 - x, 0), x - x1)
    dy = np.maximum(np.maximum(y0 - y, 0), y - y1)
    return np.hypot(dx, dy)


def bagnato(x, y):
    """Quanto è bagnato il pavimento (0 asciutto .. 1 velo d'acqua) in ogni punto della sala.
    Più bagnato vicino alle vasche, sotto le lastre rotte della cupola (piove dentro) e lungo la
    linea di gocciolamento del bordo della galleria; più asciutto contro i muri."""
    x = np.asarray(x, np.float64); y = np.asarray(y, np.float64)
    w = liscio(0.38, 0.66, fbm3(p3(x, y), 0.17, 3, seme=41)) * 0.7
    P, V = S.PISCINA, S.VASCA_ARRIVO
    w = w + 0.45 * liscio(3.2, 0.4, dist_rett(x, y, P['x0'] - 0.5, P['y0'] - 0.5, P['x1'] + 0.5, P['y1'] + 0.5))
    w = w + 0.4 * liscio(2.6, 0.4, dist_rett(x, y, V['x0'] - 0.5, V['y0'] - 0.5, V['x1'] + 0.5, V['y1'] + 0.5))
    for (px, py) in S.lastre_rotte_xy():
        w = w + 0.75 * liscio(3.0, 0.6, np.hypot(x - px, y - py))
    dg = np.minimum(np.minimum(np.abs(y - (S.Y0 + S.PROF_GAL)), np.abs(y - (S.Y1 - S.PROF_GAL))),
                    np.minimum(np.abs(x - (S.X1 - S.PROF_GAL)), np.abs(x - (S.X0 + S.PROF_GAL))))
    w = w + 0.3 * liscio(0.8, 0.1, dg) * liscio(0.45, 0.6, fbm3(p3(x, y), 0.9, 2, seme=7))
    w = w * (0.55 + 0.45 * liscio(0.3, 2.2, dist_muri(x, y)))
    return np.clip(w, 0.0, 1.0)


_GRIGLIA = {}


def bagnato_punto(x, y):
    """bagnato() letto da una griglia di 25 cm calcolata una volta sola (veloce per tanti punti)."""
    if 'w' not in _GRIGLIA:
        xs = np.arange(S.X0, S.X1 + 0.25, 0.25)
        ys = np.arange(S.Y0, S.Y1 + 0.25, 0.25)
        X, Y = np.meshgrid(xs, ys, indexing='ij')
        _GRIGLIA['w'] = bagnato(X.ravel(), Y.ravel()).reshape(X.shape)
    W = _GRIGLIA['w']
    i = int(round((min(max(x, S.X0), S.X1) - S.X0) / 0.25))
    j = int(round((min(max(y, S.Y0), S.Y1) - S.Y0) / 0.25))
    return float(W[min(i, W.shape[0] - 1), min(j, W.shape[1] - 1)])


def sporco_pavimento(P, N):
    x, y = P[:, 0], P[:, 1]
    n1 = fbm3(P, 0.12, 3, seme=3)
    n2 = fbm3(P, 0.55, 3, seme=9)
    v = 0.5 + 0.5 * liscio(0.3, 0.72, 0.65 * n1 + 0.35 * n2)
    v *= 0.78 + 0.22 * liscio(0.2, 1.8, dist_muri(x, y))                      # sporco contro i muri
    P_ = S.PISCINA
    d = dist_rett(x, y, P_['x0'] - 0.5, P_['y0'] - 0.5, P_['x1'] + 0.5, P_['y1'] + 0.5)
    v *= 1 - 0.14 * liscio(1.2, 0.2, d)                                        # aloni secchi intorno al bordo
    v *= 1 - 0.3 * bagnato(x, y)                                              # il bagnato è più scuro
    v *= 0.94 + 0.06 * rumore3(P, 4.0, seme=5)                                 # piastrella per piastrella
    return np.clip(v, 0.3, 1.0)


def _lungo_muro(P, N):
    """Coordinata orizzontale lungo il muro (per colature e umidità)."""
    return np.where(np.abs(N[:, 0]) > 0.5, P[:, 1], P[:, 0]) + np.where(np.abs(N[:, 0]) > 0.5, 100.0, 0.0)


def sporco_pareti_basse(P, N):
    z = P[:, 2]
    s = _lungo_muro(P, N)
    S1 = np.stack([s, np.zeros_like(s), np.zeros_like(s)], -1)
    # umidità che risale dal pavimento, con il bordo irregolare e la linea della marea
    h = 0.3 + 0.55 * fbm3(S1, 0.35, 3, seme=12)
    umido = liscio(h + 0.06, h - 0.1, z)
    linea = np.exp(-((z - h) / 0.05) ** 2)
    # colature dall'alto (dal bordo della galleria): righe verticali che sfumano scendendo
    righe = liscio(0.56, 0.74, fbm3(S1, 2.6, 2, seme=31)) * liscio(1.2, 3.6, z)
    macchie = fbm3(np.stack([s, z, np.zeros_like(s)], -1), 0.8, 3, seme=17)
    v = (0.86 + 0.14 * liscio(0.3, 0.7, macchie))
    v *= 1 - 0.3 * umido
    v *= 1 - 0.18 * linea
    v *= 1 - 0.3 * righe
    # angoli della sala più sporchi
    ang = np.minimum(np.minimum(np.abs(P[:, 0] - S.X0), np.abs(P[:, 0] - S.X1)) + np.minimum(np.abs(P[:, 1] - S.Y0), np.abs(P[:, 1] - S.Y1)), 9.0)
    v *= 1 - 0.18 * liscio(2.0, 0.3, ang)
    # in alto, sotto la galleria, fumo e muffa
    v *= 1 - 0.2 * liscio(3.3, 4.0, z)
    return np.clip(v, 0.3, 1.0)


def sporco_pareti_alte(P, N):
    z = P[:, 2]
    s = _lungo_muro(P, N)
    S1 = np.stack([s, np.zeros_like(s), np.zeros_like(s)], -1)
    righe = liscio(0.52, 0.72, fbm3(S1, 1.7, 2, seme=37)) * liscio(5.0, 10.5, z)
    macchie = fbm3(np.stack([s, z, np.zeros_like(s)], -1), 0.45, 3, seme=19)
    v = 0.8 + 0.2 * liscio(0.3, 0.7, macchie)
    v *= 1 - 0.35 * righe
    v *= 1 - 0.3 * liscio(9.5, 11.4, z)              # sotto il soffitto: muffa e fumo
    v *= 1 - 0.15 * liscio(4.9, 4.3, z)              # sopra la galleria: sporco del pavimento
    return np.clip(v, 0.3, 1.0)


def sporco_metallo(P, N, quota_pulita=1.5, minimo=0.62):
    """Telai, colonne, ringhiere, torre: sporchi in basso e a chiazze."""
    z = P[:, 2]
    m = fbm3(P, 0.9, 3, seme=23)
    v = 0.82 + 0.18 * liscio(0.3, 0.7, m)
    v *= minimo + (1 - minimo) * liscio(0.0, quota_pulita, z)
    v *= 1 - 0.12 * liscio(0.2, -0.8, N[:, 2])        # sotto (dove gocciola) più scuro
    return np.clip(v, 0.3, 1.0)


def sporco_soffitto(P, N):
    x, y = P[:, 0], P[:, 1]
    m = fbm3(P, 0.25, 4, seme=29)
    v = 0.62 + 0.38 * liscio(0.32, 0.7, m)
    v *= 0.75 + 0.25 * liscio(0.2, 3.0, dist_muri(x, y))
    return np.clip(v, 0.3, 1.0)


def sporco_intradosso(P, N):
    """Sotto la galleria (lamiera verniciata): aloni d'acqua e ruggine."""
    m = fbm3(P, 0.6, 3, seme=33)
    v = 0.66 + 0.34 * liscio(0.35, 0.68, m)
    return np.clip(v, 0.3, 1.0)


def sporco_piscina(P, N):
    """Vasca vuota: linea dell'ultimo livello dell'acqua, fondo sempre più sporco, alghe verso lo
    scarico (dove l'acqua è rimasta di più), colature sotto il bordo."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    prof = -z
    livello = 0.36
    v = 0.97 - 0.2 * liscio(livello - 0.02, livello + 0.06, prof) - 0.16 * liscio(0.9, 2.1, prof)
    v *= 1 - 0.22 * np.exp(-((prof - livello) / 0.035) ** 2)          # linea scura dell'acqua
    sx, sy = S.PISCINA['scarico']
    v *= 1 - 0.38 * liscio(6.0, 1.2, np.hypot(x - sx, y - sy))
    m = fbm3(P, 0.7, 3, seme=47)
    v *= 0.8 + 0.2 * liscio(0.3, 0.7, m)
    # colature verticali sulle pareti (dal bordo verso il basso)
    parete = np.abs(N[:, 2]) < 0.5
    s = _lungo_muro(P, N)
    righe = liscio(0.55, 0.75, fbm3(np.stack([s * 3.0, np.zeros_like(s), np.zeros_like(s)], -1), 1.0, 2, seme=53))
    v = np.where(parete, v * (1 - 0.25 * righe * liscio(0.05, livello, prof)), v)
    return np.clip(v, 0.25, 1.0)


def sporco_galleria(P, N):
    """Soletta della galleria: sopra è pavimento (sporco ai bordi), sotto e sul fronte lamiera."""
    sopra = N[:, 2] > 0.5
    m = fbm3(P, 0.5, 3, seme=35)
    pav = (0.6 + 0.4 * liscio(0.3, 0.7, m)) * (0.8 + 0.2 * liscio(0.2, 1.2, dist_muri(P[:, 0], P[:, 1])))
    return np.where(sopra, np.clip(pav, 0.3, 1.0), sporco_intradosso(P, N))


def sporco_scivolo(P, N):
    """Tubi in vetroresina: sotto più scuri (gocciolano), aloni lungo il tubo."""
    m = fbm3(P, 0.5, 3, seme=59)
    v = 0.8 + 0.2 * liscio(0.3, 0.7, m)
    v *= 0.72 + 0.28 * liscio(-0.7, 0.4, N[:, 2])
    return np.clip(v, 0.3, 1.0)


def sporco_giochi(P, N):
    m = fbm3(P, 0.8, 3, seme=61)
    v = 0.78 + 0.22 * liscio(0.3, 0.7, m)
    v *= 0.7 + 0.3 * liscio(0.0, 1.2, P[:, 2])
    return np.clip(v, 0.3, 1.0)


# ----------------------------------------------------------------------------- pozzanghere

def posti_pozzanghere(n=48, seme=8):
    """Centri e raggi delle pozzanghere: solo dove il pavimento è bagnato, fuori da vasche,
    piedistallo, struttura e torre. Più fitte lungo il percorso del giocatore."""
    import random
    rnd = random.Random(seme)
    # struttura e vasche basse dove stavano fino al 15 ottobre (così le altre pozzanghere restano dov'erano)
    P, V, PD, ST, T = S.PISCINA, S.VASCA_ARRIVO, S.PIEDISTALLO, S.STRUTTURA_15_OTTOBRE, S.TORRE
    vietati = [(P['x0'] - 0.75, P['y0'] - 0.75, P['x1'] + 0.75, P['y1'] + 0.75),
               (V['x0'] - 0.75, V['y0'] - 0.75, V['x1'] + 0.75, V['y1'] + 0.75),
               tuple(v + d for v, d in zip(S.ingombro_centro('vasca'), (-0.2, -0.2, 0.2, 0.2))),
               (S.LAMPIONE[0] - 0.4, S.LAMPIONE[1] - 0.4, S.LAMPIONE[0] + 0.4, S.LAMPIONE[1] + 0.4),
               (-1.2, S.Y0, 1.2, S.Y0 + 1.6),
               (ST['cx'] - 4.6, ST['cy'] - 5.6, ST['cx'] + 2.0, ST['cy'] + 3.4),
               (T['cx'] - 3.3, T['cy'] - 4.5, T['cx'] + 3.3, T['cy'] + 3.3),
               (15.5, 2.8, 17.1, 9.8)] + \
              [(a - 0.3, b - 0.3, c + 0.3, d + 0.3) for a, b, c, d in S.VASCHE_BASSE_15_OTTOBRE]
    fatti, tent = [], 0
    while len(fatti) < n and tent < 6000:
        tent += 1
        if rnd.random() < 0.4:   # percorso: dall'ingresso al monumento e intorno alla piscina
            x, y = rnd.uniform(-9.5, 9.5), rnd.uniform(S.Y0 + 0.7, -5.2)
        else:
            x, y = rnd.uniform(S.X0 + 0.6, S.X1 - 0.6), rnd.uniform(S.Y0 + 0.6, S.Y1 - 0.6)
        w = bagnato_punto(x, y)
        if w < 0.42 or rnd.random() > w:
            continue
        r0 = rnd.uniform(0.25, 0.6) + 1.2 * rnd.random() ** 2 * w
        if any(a - r0 < x < c + r0 and b - r0 < y < d + r0 for a, b, c, d in vietati):
            continue
        if not (S.X0 + r0 + 0.25 < x < S.X1 - r0 - 0.25 and S.Y0 + r0 + 0.25 < y < S.Y1 - r0 - 0.25):
            continue
        if any(math.hypot(x - a, y - b) < (r0 + rb) * 0.8 for a, b, rb in fatti):
            continue
        fatti.append((x, y, r0))
    # niente pozzanghere sulla fossa della vasca bimbi (tolte dopo, così le altre restano dov'erano)
    F = S.FOSSA_BIMBI
    fatti = [(x, y, r0) for (x, y, r0) in fatti
             if not (F['x0'] - 0.3 - r0 < x < F['x1'] + 0.3 + r0 and F['y0'] - 0.3 - r0 < y < F['y1'] + r0)]
    # area bimbi rifatta il 16 ottobre (disposizione 1): via quelle sotto la struttura, le vasche e i funghi
    ST = S.STRUTTURA
    nuovi = [(ST['cx'] - 4.6, ST['cy'] - 5.6, ST['cx'] + 2.0, ST['cy'] + 3.4)] + \
            [(a - 0.3, b - 0.3, c + 0.3, d + 0.3) for a, b, c, d in S.VASCHE_BASSE] + \
            [(x - 1.2 * s, y - 1.2 * s, x + 1.2 * s, y + 1.2 * s) for (x, y, _, s) in S.FUNGHI]
    fatti = [(x, y, r0) for (x, y, r0) in fatti
             if not any(a - r0 < x < c + r0 and b - r0 < y < d + r0 for a, b, c, d in nuovi)]
    return fatti, rnd


def pozzanghere(mats, n=48, seme=8):
    """Pozzanghere a specchio: poligoni irregolari 3 mm sopra il pavimento, con la stessa texture
    del pavimento (UV in scala reale: le fughe combaciano) ma lisci e scuri (M_amb_pozzanghera:
    opaco, così in Godot riflettono con SSR)."""
    c = K.Costruttore(mats)
    posti, rnd = posti_pozzanghere(n, seme)
    for (x, y, r0) in posti:
        k = 30
        fase = [rnd.uniform(0, 6.28) for _ in range(4)]
        sx, sy = rnd.uniform(0.7, 1.45), rnd.uniform(0.6, 1.25)
        a = rnd.uniform(0, math.pi)
        pts = []
        for i in range(k):
            t = 2 * math.pi * i / k
            rr = r0 * (1 + 0.22 * math.sin(2 * t + fase[0]) + 0.12 * math.sin(3 * t + fase[1]) +
                       0.07 * math.sin(5 * t + fase[2]) + 0.04 * math.sin(9 * t + fase[3]))
            px, py = math.cos(t) * rr * sx, math.sin(t) * rr * sy
            pts.append((x + px * math.cos(a) - py * math.sin(a), y + px * math.sin(a) + py * math.cos(a), 0.003))
        c.faccia(pts, 'pozzanghera')
    ob = c.crea('sala_pozzanghere')
    colora(ob, lambda P, N: 0.62 + 0.1 * fbm3(P, 0.8, 2, seme=71))
    return ob


# ----------------------------------------------------------------------------- piastrelle mancanti

def piastrelle_mancanti(mats, gruppi_pareti=44, gruppi_piscina=14, seme=12):
    """Piastrelle staccate (12,5 cm), a gruppi: quadratini di colla a righe (M_amb_malta) 3 mm davanti
    alle pareti basse e alle pareti della piscina, sulla griglia delle piastrelle. Evitano il vano,
    gli oblò, la turbina, le bocchette e le scalette."""
    import random
    rnd = random.Random(seme)
    c = K.Costruttore(mats)
    T = 0.125
    P = S.PISCINA
    # (asse lungo il muro, coordinata fissa, normale verso la stanza, intervallo, quote ammesse)
    muri = [('x', S.Y1, (0, -1, 0), (S.X0 + 0.5, S.X1 - 0.5), (0.125, 1.875)),
            ('x', S.Y0, (0, 1, 0), (S.X0 + 0.5, S.X1 - 0.5), (0.125, 1.875)),
            ('y', S.X1, (-1, 0, 0), (S.Y0 + 0.5, S.Y1 - 0.5), (0.125, 1.875)),
            ('y', S.X0, (1, 0, 0), (S.Y0 + 0.5, S.Y1 - 0.5), (0.125, 1.875))]
    vasca = [('x', P['y0'], (0, 1, 0), (P['x0'] + 0.3, P['x1'] - 0.3), (-1.125, -0.25)),
             ('y', P['x1'], (-1, 0, 0), (P['y0'] + 0.3, P['y_pendenza'] + 1.0), (-1.125, -0.25)),
             ('y', P['x0'], (1, 0, 0), (P['y0'] + 0.3, P['y_pendenza'] + 1.0), (-1.125, -0.25))]
    def vietato(muro, a, z):
        asse, fisso = muro[0], muro[1]
        if asse == 'x' and abs(fisso - S.Y0) < 1e-6 and -0.95 < a < 0.95:
            return True                                    # vano e telaio della porta stagna
        if asse == 'y' and abs(abs(fisso) - abs(S.X1)) < 1e-6:
            i = math.floor((a - S.Y0) / 2)                 # oblò bassi nei moduli dispari
            if i % 2 == 1 and abs(a - (S.Y0 + 2 * i + 1)) < 0.55 and 0.95 < z < 2.05:
                return True
            if abs(a - (-1.0 if fisso < 0 else 4.0)) < 0.6 or abs(a - (11.0 if fisso < 0 else -7.6)) < 0.6:
                return True                                # salvagenti appesi
        if muro in vasca:
            if asse == 'x' and (abs(a - 4.6) < 0.7 or abs(a - 1.9) < 0.3):
                return True                                # turbina e pulsante
            if asse == 'x' and z < -0.75 and any(abs(a - bx) < 1.2 for bx in (-4.5, 0.0, 4.5)):
                return True                                # bocchette della camera delle onde
            if asse == 'y' and (abs(a - (-3.2 if fisso > 0 else -2.2)) < 0.5):
                return True                                # scalette
        return False
    va, vb, vh = S.varco_torre()
    PB = S.PULSANTE_BOTOLA
    def nascosto(muro, a, z):
        """Posti nuovi del 16 ottobre: il varco della sala della torre (e il portone) nella parete est, la
        cassetta del pulsante della botola, il varco della serranda del magazzino nel muro sud. Lì il gruppo non si disegna ma conta come fatto: i numeri
        casuali restano gli stessi e le altre piastrelle mancanti non si spostano."""
        asse, fisso = muro[0], muro[1]
        if asse == 'y' and abs(fisso - S.X1) < 1e-6 and va - 0.25 < a < vb + 0.25:
            return True
        if muro in vasca and asse == 'x' and abs(a - PB['x']) < 0.46 and z > PB['z'] - 0.62:
            return True
        VS = S.VANO_SERRANDA          # varco della serranda del magazzino (ambienti-1, tappa 7 B)
        if asse == 'x' and abs(fisso - S.Y0) < 1e-6 and abs(a - VS['cx']) < 1.0 and z < VS['h'] + 0.1:
            return True
        return False
    def gruppo(muro):
        asse, fisso, nrm, (a0, a1), (z0, z1) = muro
        a = round(rnd.uniform(a0, a1) / T) * T
        z = round(rnd.uniform(z0, z1) / T) * T
        celle = [(a, z)]
        for _ in range(rnd.choice((0, 0, 1, 1, 2, 3, 4, 6))):
            da, dz = rnd.choice(((T, 0), (-T, 0), (0, T), (0, -T), (T, 0)))
            na, nz = celle[-1][0] + da, celle[-1][1] + dz
            if z0 <= nz <= z1 and (na, nz) not in celle:
                celle.append((na, nz))
        if any(vietato(muro, ca + T / 2, cz + T / 2) for ca, cz in celle):
            return False
        if any(nascosto(muro, ca + T / 2, cz + T / 2) for ca, cz in celle):
            return True
        o = 0.003
        for (ca, cz) in celle:
            if asse == 'x':
                y = fisso + nrm[1] * o
                q = [(ca, y, cz), (ca + T, y, cz), (ca + T, y, cz + T), (ca, y, cz + T)]
            else:
                x = fisso + nrm[0] * o
                q = [(x, ca, cz), (x, ca + T, cz), (x, ca + T, cz + T), (x, ca, cz + T)]
            c.faccia_verso(q, 'malta', nrm, uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
        return True
    for lista, n in ((muri, gruppi_pareti), (vasca, gruppi_piscina)):
        fatti, tent = 0, 0
        while fatti < n and tent < 2000:
            tent += 1
            fatti += 1 if gruppo(rnd.choice(lista)) else 0
    ob = c.crea('sala_piastrelle_mancanti')
    colora(ob, lambda P_, N_: 0.85 + 0.15 * fbm3(P_, 2.0, 2, seme=83))
    return ob


# ----------------------------------------------------------------------------- insegne e luci calde

def _materiale_neon(nome, colore, forza):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*colore, 1)
    b.inputs['Emission Color'].default_value = (*colore, 1)
    b.inputs['Emission Strength'].default_value = forza
    b.inputs['Roughness'].default_value = 0.3
    return m


def insegne_neon(mats):
    """Insegne al neon disegnate (nessuna scritta): un'onda azzurra sopra il vano della porta (dentro la
    sala) e una stella-sole gialla sulla parete nord sopra l'area bimbi. Un tratto dell'onda è spento.
    Restituisce (oggetto, luci)."""
    m_az = _materiale_neon('M_amb_neon_azzurro', (0.25, 0.85, 1.0), 22.0)
    m_gi = _materiale_neon('M_amb_neon_giallo', (1.0, 0.72, 0.2), 22.0)
    m_sp = mats.get('neon_spento')
    class _M:
        def lato(self, n): return 1.0
        def get(self, n): return {'az': m_az, 'gi': m_gi, 'sp': m_sp}.get(n) or mats.get(n)
    c = K.Costruttore(_M())
    luci = []
    # onda sopra il vano (parete sud, verso +y), due tubi paralleli su distanziali
    y = S.Y0 + 0.07
    for riga, dz in enumerate((0.0, -0.22)):
        pts = [(x, y, 3.05 + dz + 0.12 * math.sin((x + 1.1) / 2.2 * 3 * math.pi)) for x in [-1.1 + 2.2 * k / 60 for k in range(61)]]
        if riga == 1:
            c.tubo(pts[:40], 0.014, 'az', seg=8)
            c.tubo(pts[39:52], 0.014, 'sp', seg=8)     # tratto spento
            c.tubo(pts[51:], 0.014, 'az', seg=8)
        else:
            c.tubo(pts, 0.014, 'az', seg=8)
        for k in range(0, 61, 15):
            px, py, pz = pts[k]
            c.cilindro((px, S.Y0 + 0.001, pz), (px, py, pz), 0.008, 'metallo', seg=6)
    luci.append(dict(nome='luce_insegna_onda', pos=(0.0, S.Y0 + 0.5, 2.95), colore=(0.25, 0.85, 1.0)))
    # stella-sole sulla parete nord (verso -y), sopra l'area bimbi
    cx, cz, y = -12.5, 7.0, S.Y1 - 0.07
    stella = []
    for i in range(11):
        a = math.pi / 2 + i * 2 * math.pi / 10
        rr = 0.75 if i % 2 == 0 else 0.32
        stella.append((cx + math.cos(a) * rr, y, cz + math.sin(a) * rr))
    c.tubo(stella, 0.016, 'gi', seg=8)
    for i in range(12):
        a = i * 2 * math.pi / 12 + 0.13
        c.tubo([(cx + math.cos(a) * 0.95, y, cz + math.sin(a) * 0.95), (cx + math.cos(a) * 1.2, y, cz + math.sin(a) * 1.2)],
               0.014, 'gi' if i not in (4, 9) else 'sp', seg=8)
    for (dx, dz) in ((0, 0.75), (0.7, -0.6), (-0.7, -0.6)):
        c.cilindro((cx + dx, S.Y1 - 0.001, cz + dz), (cx + dx, y, cz + dz), 0.008, 'metallo', seg=6)
    luci.append(dict(nome='luce_insegna_stella', pos=(cx, S.Y1 - 0.6, cz), colore=(1.0, 0.72, 0.25)))
    return c.crea('sala_insegne_neon'), luci


def plafoniere_calde(mats):
    """Plafoniere navali 'a tartaruga' ancora accese, luce calda: un po' di caldo in mezzo al rosso
    (vicino alla porta, sul muro est, sul muro ovest sopra il salvagente e sulla parete nord). Dal 16
    ottobre la 3 non c'è più (era sulla torre degli scivoli, tolta dalla sala) e la 4, che era su una
    colonna del soppalco nord, è sulla parete nord: i nomi delle luci restano gli stessi.
    La 1, sul muro est, era in y 9: lì ora scorre il portone della sala della torre aperto del tutto, quindi è
    in y 2, sopra la panca. Restituisce (oggetto, luci)."""
    posti = [((1.75, S.Y0, 2.5), (0, 1, 0)), ((S.X1, 2.0, 2.7), (-1, 0, 0)), ((S.X0, -1.0, 2.7), (1, 0, 0)),
             None, ((-4.6, S.Y1, 3.0), (0, -1, 0))]
    c = K.Costruttore(mats)
    luci = []
    for i, posto in enumerate(posti):
        if posto is None:
            continue
        p, n = posto
        P = Vector(p); N = Vector(n)
        su = Vector((0, 0, 1)); lato = su.cross(N).normalized()
        c.scatola_assi(P + N * 0.02, (lato, su, N), (0.15, 0.1, 0.02), 'metallo')
        seg = 12
        for k in range(seg):   # vetro a mezzo cilindro, caldo
            t0, t1 = math.pi * k / seg, math.pi * (k + 1) / seg
            a0 = lato * math.cos(t0) * 0.1 + N * (0.04 + math.sin(t0) * 0.07)
            a1 = lato * math.cos(t1) * 0.1 + N * (0.04 + math.sin(t1) * 0.07)
            q = [P + a0 - su * 0.07, P + a1 - su * 0.07, P + a1 + su * 0.07, P + a0 + su * 0.07]
            c.faccia_verso([tuple(v) for v in q], 'lampadina', tuple((a0 + a1) / 2 - N * 0.04), liscia=True)
        for zz in (-0.05, 0.0, 0.05):   # gabbia
            arco = [P + su * zz + lato * math.cos(t) * 0.112 + N * (0.04 + math.sin(t) * 0.082) for t in [math.pi * k / 10 for k in range(11)]]
            c.tubo([tuple(v) for v in arco], 0.005, 'metallo', seg=5)
        luci.append(dict(nome=f'luce_calda_{i}', pos=tuple(P + N * 0.25), colore=(1.0, 0.68, 0.38)))
    return c.crea('sala_plafoniere_calde'), luci


def sporco_vasca_centrale(P, N):
    """Vasca sollevata: fuori sporco in basso (schizzi, pavimento bagnato) e righe dove l'acqua è
    traboccata dal bordo; dentro, sotto l'acqua, verdastro (alghe) e più scuro verso il fondo."""
    V = S.VASCA_CENTRALE
    x, y, z = P[:, 0] - V['cx'], P[:, 1] - V['cy'], P[:, 2]
    radiale = np.stack([x, y], -1)
    fuori = (N[:, 0] * x + N[:, 1] * y) > 0
    ang = np.arctan2(y, x)
    S1 = np.stack([ang * 3.2, np.zeros_like(ang), np.zeros_like(ang)], -1)
    m = fbm3(P, 1.4, 3, seme=91)
    v = 0.84 + 0.16 * liscio(0.3, 0.7, m)
    righe = liscio(0.55, 0.78, fbm3(S1, 2.2, 2, seme=93)) * liscio(0.15, 0.85, z)
    est = v * (0.74 + 0.26 * liscio(0.0, 0.4, z)) * (1 - 0.28 * righe)
    sotto = z < V['acqua'] - 0.01
    inn = v * np.where(sotto, 0.72 - 0.25 * liscio(0.8, 0.1, z), 0.95)
    val = np.where(fuori, est, inn)
    rgb = np.repeat(val[:, None], 3, 1)
    verde = np.where((~fuori) & sotto, 1.0, 0.0)[:, None]
    rgb = rgb * (1 - 0.25 * verde) + rgb * np.array([0.78, 0.95, 0.72]) * 0.25 * verde
    return np.clip(rgb, 0.25, 1.0)
