"""Dettagli della sala principale (passata di qualità).

- sporco in spazio mondo nei colori dei vertici (niente ripetizioni: macchie grandi, umidità che
  risale, colature dall'alto, angoli più sporchi, linea dell'acqua nella piscina);
- pavimento bagnato a chiazze (tre materiali con rugosità diverse, assegnati piastrella per
  piastrella) e pozzanghere a specchio che seguono le zone bagnate;
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


def materiali_pavimento(cx, cy):
    """Materiale di ogni piastrella (25 cm) di centro (cx, cy): asciutto, umido o bagnato."""
    w = bagnato(np.asarray(cx, np.float64), np.asarray(cy, np.float64))
    return np.where(w > 0.6, 'pavimento_bagnato', np.where(w < 0.3, 'pavimento_asciutto', 'pavimento'))


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
    P, V, PD, ST, T = S.PISCINA, S.VASCA_ARRIVO, S.PIEDISTALLO, S.STRUTTURA, S.TORRE
    vietati = [(P['x0'] - 0.75, P['y0'] - 0.75, P['x1'] + 0.75, P['y1'] + 0.75),
               (V['x0'] - 0.75, V['y0'] - 0.75, V['x1'] + 0.75, V['y1'] + 0.75),
               (PD['cx'] - PD['r_cordone'] - 0.4, PD['cy'] - PD['r_cordone'] - 0.4, PD['cx'] + PD['r_cordone'] + 0.4, PD['cy'] + PD['r_cordone'] + 0.4),
               (S.LAMPIONE[0] - 0.4, S.LAMPIONE[1] - 0.4, S.LAMPIONE[0] + 0.4, S.LAMPIONE[1] + 0.4),
               (-1.2, S.Y0, 1.2, S.Y0 + 1.6),
               (ST['cx'] - 4.6, ST['cy'] - 5.6, ST['cx'] + 2.0, ST['cy'] + 3.4),
               (T['cx'] - 3.3, T['cy'] - 4.5, T['cx'] + 3.3, T['cy'] + 3.3),
               (15.5, 2.8, 17.1, 9.8)] + \
              [(a - 0.3, b - 0.3, c + 0.3, d + 0.3) for a, b, c, d in S.VASCHE_BASSE]
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
    return fatti, rnd


def pozzanghere(mats, n=48, seme=8):
    """Pozzanghere a specchio: poligoni irregolari 4 mm sopra il pavimento, con la stessa texture
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
            pts.append((x + px * math.cos(a) - py * math.sin(a), y + px * math.sin(a) + py * math.cos(a), 0.004))
        c.faccia(pts, 'pozzanghera')
    ob = c.crea('sala_pozzanghere')
    colora(ob, lambda P, N: 0.62 + 0.1 * fbm3(P, 0.8, 2, seme=71))
    return ob
