"""Capelli a ciocche (modello eroe). Stesso taglio e stessa sagoma del concept approvato: sopra il volume dei
capelli di Meshy (che resta sotto, piu' scuro, come il fondo tra una ciocca e l'altra) si stendono ciocche
separate e stratificate che seguono le ciocche scolpite, con un po' di volume e punte sottili.

  - direzione delle ciocche: per ogni vertice dei capelli, l'asse lungo cui le normali cambiano meno (le ciocche
    scolpite sono come cilindri), col verso che scende dalla cima della testa; dove la superficie e' piatta,
    "giu' dalla cima";
  - semi sparsi sulla parte esterna dei capelli (distanza minima fissa), linee di flusso tracciate sulla
    superficie a passi di 6 mm proiettati con un BVH: indietro per la radice, che resta sotto le altre ciocche,
    e avanti fino in fondo; poi la punta continua un poco e si assottiglia;
  - ogni ciocca e' un nastro a cupola (piatto sotto, tondo sopra), largo 2-4 cm, appoggiato sulla superficie a
    strati di altezza diversa, con UV (u attraverso, v lungo: 0 alla radice, 1 in punta) per le fibre e la punta
    traslucida rosa (come la campana).
Colore (GDD: "argento-rosa", come nel concept): argento chiaro in alto, riflessi rosa (alcune ciocche piu' rosate),
sempre piu' rosa verso il basso e sulle punte. Le ciocche lo hanno nel colore dei vertici; il volume dei capelli
sotto (atlante del corpo) lo prende con ricolora_atlante(), un po' piu' scuro, dal passo 8.
Un oggetto (Medusa_Ciocche), materiale M_ciocche, pesi sull'osso 'testa'. Uso dal passo 7: crea_ciocche(arm, corpo).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

CIOCCHE = dict(
    seme=12,
    distanza_semi=0.06,         # distanza minima tra i semi (m, unita' del modello)
    larghezza=(0.03, 0.05),     # larghezza massima della ciocca
    spessore=0.32,              # spessore / larghezza
    strato=(0.0015, 0.007),     # altezza della ciocca sulla superficie (strati)
    radice=(0.03, 0.12),        # quanto risale la radice dal seme
    passo=0.006,                # passo del tracciamento
    anelli=0.02,                # distanza tra gli anelli della mesh
    punta=(0.015, 0.04),        # punta che esce oltre la fine della ciocca scolpita
    cima=(0.0, 0.03, 0.915),    # cima della testa (da qui scendono)
    centro_testa=(0.0, 0.014, 0.6),
    z_max_semi=0.895,           # niente semi sul ciuffo ad anello in cima
)
TEX_CIOCCHE = os.path.join(TEX, 'ciocche_base.jpg')
TEX_CIOCCHE_N = os.path.join(TEX, 'ciocche_normal.png')
TEX_CIOCCHE_E = os.path.join(TEX, 'ciocche_emissione.jpg')

# colore finale (sRGB, sotto luce bianca): argento in alto, riflessi rosa, rosa in basso e sulle punte
ARGENTO = (0.91, 0.9, 0.94)
RIFLESSO = (0.93, 0.78, 0.9)
ROSA = (0.94, 0.64, 0.81)
FONDO_CAPELLI = 0.84            # il volume sotto le ciocche e' un po' piu' scuro (fa da fondo tra le ciocche)


# ---------------------------------------------------------------- colore

def _liscio(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def lineare(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def srgb(c):
    c = np.clip(np.asarray(c, float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def colore_capelli(alto, punta=None, riflesso=None):
    """Colore lineare (N x 3). alto: 0 in fondo ai capelli, 1 in cima al ciuffo; punta: 0 alla radice della
    ciocca, 1 in punta; riflesso: 0..1, quanto la ciocca e' rosata."""
    alto = np.atleast_1d(np.asarray(alto, float))
    w = 0.92 * _liscio(0.68, 0.1, alto)                         # il rosa sale dal basso
    if punta is not None:
        w = w + (1 - w) * 0.5 * _liscio(0.6, 1.0, punta)        # punte piu' rosa
    c = lineare(ARGENTO) * (1 - w[:, None]) + lineare(ROSA) * w[:, None]
    if riflesso is not None:
        r = (np.asarray(riflesso, float) * (1 - w))[:, None]
        c = c * (1 - r) + lineare(RIFLESSO) * r
    return c


def altezza_testa(arm, ob, punti):
    """Coordinata lungo l'osso 'testa' (posa di riposo) dei punti dati nello spazio dell'oggetto ob: il colore
    segue la testa, non la gravita' (vale uguale prima e dopo che la posa della statua diventa il riposo)."""
    B = arm.matrix_world @ arm.data.bones['testa'].matrix_local
    M = np.array(B.inverted() @ ob.matrix_world)
    p = np.asarray(punti, float)
    return p @ M[:3, :3].T[:, 1] + M[1, 3]


# ---------------------------------------------------------------- superficie dei capelli e direzioni

def superficie_capelli(corpo):
    me = corpo.data
    co = coords(me)
    nrm = np.empty(len(co) * 3)
    me.vertices.foreach_get('normal', nrm)
    nrm = nrm.reshape(-1, 3)
    nomi = [m.name if m else '' for m in me.materials]
    ic = nomi.index('M_capelli')
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    me.calc_loop_triangles()
    nt = len(me.loop_triangles)
    tv = np.empty(nt * 3, dtype=np.int64); me.loop_triangles.foreach_get('vertices', tv)
    tl = np.empty(nt * 3, dtype=np.int64); me.loop_triangles.foreach_get('loops', tl)
    tp = np.empty(nt, dtype=np.int64); me.loop_triangles.foreach_get('polygon_index', tp)
    sel = mi[tp] == ic
    tri = tv.reshape(-1, 3)[sel]
    uv = loop_uv(me)[tl.reshape(-1, 3)[sel]]          # (Nt, 3, 2)
    return co, nrm, tri, uv


def campo_direzioni(co, nrm, tri, par):
    """Direzione delle ciocche per vertice (unitaria, nel piano tangente)."""
    import scipy.sparse as sp
    nv = len(co)
    e = np.vstack([tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [2, 0]]])
    A = sp.coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(nv, nv)).tocsr()
    A = ((A + A.T + sp.identity(nv)) > 0).astype(np.float64)
    A2 = (A @ A > 0).astype(np.float64)
    O = (nrm[:, :, None] * nrm[:, None, :]).reshape(nv, 9)
    C = (A2 @ O).reshape(nv, 3, 3)
    usati = np.unique(tri)
    w, vec = np.linalg.eigh(C[usati])
    asse = vec[:, :, 0]                                    # autovalore piu' piccolo: asse della ciocca
    conf = np.clip((w[:, 1] - w[:, 0]) / (w[:, 2] + 1e-9) * 4.0, 0, 1)
    p = co[usati]
    n = nrm[usati]
    g = p - np.array(par['cima'])
    g = g - n * (g * n).sum(1, keepdims=True)
    g /= np.linalg.norm(g, axis=1, keepdims=True) + 1e-9
    asse = asse - n * (asse * n).sum(1, keepdims=True)
    asse /= np.linalg.norm(asse, axis=1, keepdims=True) + 1e-9
    asse *= np.sign((asse * g).sum(1, keepdims=True) + 1e-9)
    f = np.zeros((nv, 3))
    f[usati] = conf[:, None] * asse + (1 - conf[:, None]) * g
    # ammorbidisce sui vicini (allineando il verso)
    for _ in range(4):
        m = A @ f
        f2 = f + 0.0
        f2[usati] = m[usati]
        f2 = f2 - nrm * (f2 * nrm).sum(1, keepdims=True)
        f = f2 / (np.linalg.norm(f2, axis=1, keepdims=True) + 1e-9)
    return f


# ---------------------------------------------------------------- tracciamento

class Superficie:
    def __init__(self, co, nrm, tri, uv, flusso, par):
        from mathutils.bvhtree import BVHTree
        self.co, self.nrm, self.tri, self.uv, self.f = co, nrm, tri, uv, flusso
        self.bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(t) for t in tri])
        self.H = np.array(par['centro_testa'])

    def _bari(self, p, i):
        a, b, c = self.co[self.tri[i]]
        v0, v1, v2 = b - a, c - a, p - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01 + 1e-18
        v = (d11 * d20 - d01 * d21) / den
        w = (d00 * d21 - d01 * d20) / den
        return np.clip(np.array([1 - v - w, v, w]), 0, 1)

    def vicino(self, p):
        loc, nor, i, d = self.bvh.find_nearest(Vector(p))
        if loc is None:
            return None
        q = np.array(loc)
        bc = self._bari(q, i)
        bc /= bc.sum()
        t = self.tri[i]
        f = (self.f[t] * bc[:, None]).sum(0)
        n = (self.nrm[t] * bc[:, None]).sum(0)
        n /= np.linalg.norm(n) + 1e-12
        f = f - n * (f @ n)
        f /= np.linalg.norm(f) + 1e-12
        uv = (self.uv[i] * bc[:, None]).sum(0)
        return q, n, f, uv

    def esterno(self, q, n):
        r = q - self.H
        return (n @ (r / (np.linalg.norm(r) + 1e-9))) > -0.05

    def traccia(self, p0, verso, lmax, passo):
        """Linea di flusso sulla superficie. self.fine dice perche' si e' fermata: 'bordo' (attaccatura dei
        capelli, sul viso o sul collo), 'sotto' (la ciocca gira sotto: punta libera), 'lunghezza'."""
        pts, nor, uvs = [], [], []
        self.fine = 'lunghezza'
        s = self.vicino(p0)
        if s is None:
            return pts, nor, uvs
        p, n, f, uv = s
        pts.append(p); nor.append(n); uvs.append(uv)
        d_prec = f * verso
        fatto = 0.0
        while fatto < lmax:
            q = p + d_prec * passo * 0.5 + f * verso * passo * 0.5
            s = self.vicino(q)
            if s is None:
                break
            q, n2, f2, uv2 = s
            step = np.linalg.norm(q - p)
            if step < passo * 0.35:
                self.fine = 'bordo'
                break
            if not self.esterno(q, n2):
                self.fine = 'sotto'
                break
            d = (q - p) / step
            if d @ d_prec < 0.5:
                self.fine = 'sotto'
                break
            pts.append(q); nor.append(n2); uvs.append(uv2)
            d_prec, f, p = d, f2, q
            fatto += step
        return pts, nor, uvs


def semi(sup, par, rng):
    co, nrm, tri = sup.co, sup.nrm, sup.tri
    cen = co[tri].mean(1)
    nf = np.cross(co[tri[:, 1]] - co[tri[:, 0]], co[tri[:, 2]] - co[tri[:, 0]])
    nf /= np.linalg.norm(nf, axis=1, keepdims=True) + 1e-12
    r = cen - sup.H
    est = (nf * r).sum(1) / (np.linalg.norm(r, axis=1) + 1e-9) > 0.3
    cand = cen[est & (cen[:, 2] < par['z_max_semi'])]
    cand = cand[rng.permutation(len(cand))]
    scelti = []
    dmin = par['distanza_semi']
    griglia = {}
    for p in cand:
        k = tuple((p // dmin).astype(int))
        ok = True
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for q in griglia.get((k[0] + dx, k[1] + dy, k[2] + dz), ()):
                        if np.linalg.norm(p - q) < dmin:
                            ok = False
                            break
                    if not ok:
                        break
                if not ok:
                    break
            if not ok:
                break
        if ok:
            griglia.setdefault(k, []).append(p)
            scelti.append(p)
    return np.array(scelti)


def _liscia(P, sigma):
    if len(P) < 4:
        return P
    k = np.arange(-3, 4)
    g = np.exp(-0.5 * (k / sigma) ** 2); g /= g.sum()
    pad = np.vstack([np.repeat(P[:1], 3, 0), P, np.repeat(P[-1:], 3, 0)])
    out = np.stack([np.convolve(pad[:, i], g, mode='valid') for i in range(3)], 1)
    out[0], out[-1] = P[0], P[-1]
    return out


def ciocca(sup, seme, par, rng):
    """Una ciocca: linea centrale, normali della superficie, uv della texture dei capelli, profilo."""
    ind, ni, ui = sup.traccia(seme, -1, rng.uniform(*par['radice']), par['passo'])
    ava, na, ua = sup.traccia(seme, 1, 0.9, par['passo'])
    fine = sup.fine
    if len(ava) < 6:
        return None
    pts = np.array(ind[::-1][:-1] + ava)
    nor = np.array(ni[::-1][:-1] + na)
    uvs = np.array(ui[::-1][:-1] + ua)
    # ricampiona agli anelli e liscia
    L = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    if L[-1] < 0.06:
        return None
    n_an = max(int(L[-1] / par['anelli']), 5)
    s = np.linspace(0, L[-1], n_an + 1)
    P = np.stack([np.interp(s, L, pts[:, i]) for i in range(3)], 1)
    N = np.stack([np.interp(s, L, nor[:, i]) for i in range(3)], 1)
    N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
    UV = np.stack([np.interp(s, L, uvs[:, i]) for i in range(2)], 1)
    P = _liscia(P, 1.0)
    # punta: continua nella direzione finale, si stacca appena dalla superficie e si assottiglia
    d = P[-1] - P[-2]
    d /= np.linalg.norm(d) + 1e-12
    # punta libera solo dove la ciocca finisce davvero (gira sotto); sull'attaccatura (viso, collo) resta corta
    lp = rng.uniform(*par['punta']) if fine != 'bordo' else 0.01
    k = 4
    for i in range(1, k + 1):
        t = i / k
        dd = d - N[-1] * 0.12 * t                 # la punta si chiude un poco verso la testa
        dd /= np.linalg.norm(dd)
        P = np.vstack([P, P[-1] + dd * lp / k])
        N = np.vstack([N, N[-1]])
        UV = np.vstack([UV, UV[-1]])
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))]
    return P, N, UV, s


def mesh_ciocca(P, N, s, par, rng, u0=0.0):
    """Nastro a cupola lungo P (normali della superficie N). Ritorna vertici, facce, uv per faccia."""
    n = len(P)
    T = np.gradient(P, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True) + 1e-12
    Nn = N - T * (N * T).sum(1, keepdims=True)
    Nn /= np.linalg.norm(Nn, axis=1, keepdims=True) + 1e-12
    B = np.cross(T, Nn)
    t = s / s[-1]
    W = rng.uniform(*par['larghezza'])
    # profilo: cresce dalla radice, massimo a un terzo, si assottiglia fino alla punta sottile
    prof = np.clip(t / 0.25, 0, 1) ** 0.6 * (1 - 0.88 * np.clip((t - 0.35) / 0.65, 0, 1) ** 1.3)
    prof = np.maximum(prof, 0.06)
    w = W * prof * (1 + 0.1 * np.sin(2 * math.pi * s / 0.09 + rng.uniform(0, 6)))
    h = w * par['spessore']
    alza = rng.uniform(*par['strato'])
    centro = P + Nn * (alza - 0.25 * h)[:, None]
    ang = np.radians([0, 45, 90, 135, 180])          # cupola; l'ultima faccia (180 -> 0) e' il fondo piatto
    ca, sa = np.cos(ang), np.sin(ang)
    verts = (centro[:, None, :] + (w / 2)[:, None, None] * ca[None, :, None] * B[:, None, :]
             + (h / 2)[:, None, None] * sa[None, :, None] * Nn[:, None, :]).reshape(-1, 3)
    lati = len(ang)
    facce, uvf = [], []
    for i in range(n - 1):
        for j in range(lati):
            jn = (j + 1) % lati
            facce.append((i * lati + j, i * lati + jn, (i + 1) * lati + jn, (i + 1) * lati + j))
            uvf.append([(u0 + j / lati, t[i]), (u0 + (j + 1) / lati, t[i]), (u0 + (j + 1) / lati, t[i + 1]),
                        (u0 + j / lati, t[i + 1])])
    c0, c1 = len(verts), len(verts) + 1
    verts = np.vstack([verts, centro[0] - T[0] * 0.002, centro[-1] + T[-1] * 0.004])
    for j in range(lati):
        jn = (j + 1) % lati
        facce.append((jn, j, c0)); uvf.append([(u0 + jn / lati, 0.0), (u0 + j / lati, 0.0), (u0 + 0.5, 0.0)])
        facce.append(((n - 1) * lati + j, (n - 1) * lati + jn, c1))
        uvf.append([(u0 + j / lati, 1.0), (u0 + jn / lati, 1.0), (u0 + 0.5, 1.0)])
    return verts, facce, uvf


# ---------------------------------------------------------------- texture e materiale

def texture_ciocche():
    """Fibre della ciocca (u attraverso, v lungo): moltiplicatore del colore, emissione delle punte, normal.
    Ritorna il moltiplicatore medio (lineare) del lato in vista, per compensarlo nel colore dei vertici."""
    import cv2
    rng = np.random.default_rng(6)
    H, Wt = 1024, 512
    v = 1 - (np.arange(H) + 0.5) / H
    u = (np.arange(Wt) + 0.5) / Wt
    V, U = np.meshgrid(v, u, indexing='ij')
    fib = cv2.GaussianBlur(rng.normal(size=(H, Wt)).astype(np.float32), (0, 0), sigmaX=1.2, sigmaY=40)
    fib /= fib.std() + 1e-6
    fib2 = cv2.GaussianBlur(rng.normal(size=(H, Wt)).astype(np.float32), (0, 0), sigmaX=5, sigmaY=60)
    fib2 /= fib2.std() + 1e-6
    a = 2 * math.pi * U                          # intorno alla sezione: 0 e 0.5 = bordi, 0.25 = cresta
    cresta = np.clip(np.sin(a), 0, 1)
    lati = 1 - 0.16 * (1 - cresta) ** 2         # bordi un po' piu' scuri: le ciocche si staccano tra loro
    molt = (0.95 + 0.035 * fib + 0.025 * fib2) * lati
    punta = np.clip((V - 0.72) / 0.28, 0, 1) ** 1.5
    tinta = np.array([1.0, 0.78, 0.9])            # punta rosa chiaro, traslucida (come la campana)
    col = molt[..., None] * (1 - 0.35 * punta[..., None]) + tinta * 0.35 * punta[..., None]
    cv2.imwrite(TEX_CIOCCHE, (np.clip(col, 0, 1) * 255).astype(np.uint8)[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, 92])
    em = np.array([1.0, 0.36, 0.66]) * (0.3 * punta)[..., None]
    cv2.imwrite(TEX_CIOCCHE_E, (np.clip(em, 0, 1) * 255).astype(np.uint8)[..., ::-1], [cv2.IMWRITE_JPEG_QUALITY, 92])
    h = 0.7 * fib + 0.3 * fib2
    gu, gv = np.gradient(h, axis=1), np.gradient(h, axis=0)
    nrm = np.stack([-gu * 0.9, gv * 0.9, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    cv2.imwrite(TEX_CIOCCHE_N, ((nrm * 0.5 + 0.5) * 255).astype(np.uint8)[..., ::-1])
    vista = (U < 0.5) & (V < 0.72)                # lato di sopra, prima della punta
    return float(lineare(np.clip(molt[vista], 0, 1)).mean())


def materiale_ciocche(nome='M_ciocche'):
    """Ciocche lucide e bagnate: colore dei vertici (argento-rosa) x fibre, punte rosa traslucide."""
    molt = texture_ciocche()
    m = materiale_pbr(nome, base=TEX_CIOCCHE, normal=TEX_CIOCCHE_N, roughness=0.16, normal_strength=0.6)
    m['molt_fibre'] = molt
    nt = m.node_tree
    b = nt.nodes['BSDF']
    va = nodo(nt, 'ShaderNodeVertexColor', (-700, 450))
    va.layer_name = 'Col'
    mul = nodo(nt, 'ShaderNodeMix', (-100, 350))
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    nt.links.new(va.outputs['Color'], mul.inputs['A'])
    nt.links.new(nt.nodes['base'].outputs['Color'], mul.inputs['B'])
    nt.links.new(mul.outputs['Result'], b.inputs['Base Color'])
    te = nodo(nt, 'ShaderNodeTexImage', (-400, -700))
    te.image = immagine(TEX_CIOCCHE_E)
    te.name = 'emissione'
    nt.links.new(te.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 1.0
    b.inputs['Coat Weight'].default_value = 0.6
    b.inputs['Coat Roughness'].default_value = 0.03
    b.inputs['Subsurface Weight'].default_value = 0.12
    b.inputs['Subsurface Radius'].default_value = (1.0, 0.62, 0.88)     # rosa, non arancio, in controluce
    b.inputs['Subsurface Scale'].default_value = 0.02
    return m


# ---------------------------------------------------------------- creazione

def crea_ciocche(arm, corpo, par=CIOCCHE):
    """Ciocche sopra i capelli, colore argento-rosa nel colore dei vertici (lineare)."""
    rng = np.random.default_rng(par['seme'])
    co, nrm, tri, uv = superficie_capelli(corpo)
    flusso = campo_direzioni(co, nrm, tri, par)
    sup = Superficie(co, nrm, tri, uv, flusso, par)
    S = semi(sup, par, rng)
    mat = materiale_ciocche()
    molt = float(mat['molt_fibre'])
    # altezza lungo la testa: 0 in fondo ai capelli, 1 in cima al ciuffo
    yh = altezza_testa(arm, corpo, co[np.unique(tri)])
    y0, y1 = yh.min(), yh.max()
    rng_c = np.random.default_rng(par['seme'] + 101)       # generatore a parte: la forma delle ciocche non cambia
    V, F, UVF, COL = [], [], [], []
    n_ok = 0
    for p in S[rng.permutation(len(S))]:
        c = ciocca(sup, p, par, rng)
        if c is None:
            continue
        P, N, UVt, s = c
        v, f, uvf = mesh_ciocca(P, N, s, par, rng)
        lati = 5
        # colore per anello: argento-rosa per altezza e lungo la ciocca, qualche ciocca piu' rosata (riflessi);
        # diviso per il moltiplicatore medio delle fibre, cosi' il colore finale e' quello voluto
        alto = np.clip((altezza_testa(arm, corpo, P) - y0) / (y1 - y0), 0, 1)
        rif = np.full(len(P), 0.9 * rng_c.uniform(0, 1) ** 1.5)
        col_an = colore_capelli(alto, s / s[-1], rif) * rng_c.uniform(0.95, 1.02) / molt
        col_an = np.clip(col_an, 0, 1)
        col = np.vstack([np.repeat(col_an, lati, 0), col_an[:1], col_an[-1:]])
        off = sum(len(x) for x in V)
        V.append(v)
        F.extend(tuple(k + off for k in ff) for ff in f)
        UVF.extend(uvf)
        COL.append(col)
        n_ok += 1
    verts = np.vstack(V)
    cols = np.vstack(COL)
    me = bpy.data.meshes.new('Medusa_Ciocche')
    me.from_pydata([tuple(x) for x in verts], [], F)
    uvl = me.uv_layers.new(name='UVMap')
    for poly, uvs in zip(me.polygons, UVF):
        for li, u in zip(poly.loop_indices, uvs):
            uvl.data[li].uv = u
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    ca.data.foreach_set('color', np.hstack([cols, np.ones((len(cols), 1))]).astype(np.float32).ravel())
    me.color_attributes.active_color = ca
    me.shade_smooth()
    me.materials.append(mat)
    ob = bpy.data.objects.new('Medusa_Ciocche', me)
    collega(ob)
    ob.parent = arm
    vg = ob.vertex_groups.new(name='testa')
    vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
    mod = ob.modifiers.new('Scheletro', 'ARMATURE')
    mod.object = arm
    ntri = sum(len(p.vertices) - 2 for p in me.polygons)
    log(f'ciocche: {n_ok} su {len(S)} semi, {ntri} triangoli')
    return ob


# ---------------------------------------------------------------- volume dei capelli nell'atlante del corpo

def ricolora_atlante(sorgente, uscita, arm=None, corpo=None, margine=10):
    """Il volume dei capelli (isole M_capelli dell'atlante del corpo) prende lo stesso argento-rosa delle ciocche,
    piu' scuro di FONDO_CAPELLI (fa da fondo tra una ciocca e l'altra; il ciuffo ad anello in cima resta chiaro).
    Dalla cottura del passo 8 resta solo il dettaglio: la luminanza rispetto alla media intorno (solchi delle
    ciocche, occlusione, usura). Riparte sempre dal PNG della cottura (sorgente), quindi si puo' rifare; scrive il
    JPG dell'atlante (uscita). Anche il margine intorno alle isole cambia colore, per non avere bordi mauve."""
    import cv2
    from PIL import Image
    from scipy import ndimage
    arm = arm or bpy.data.objects['Medusa_Scheletro']
    corpo = corpo or bpy.data.objects['Medusa']
    img = np.asarray(Image.open(sorgente).convert('RGB')).astype(np.float32) / 255.0
    H, W = img.shape[:2]
    me = corpo.data
    co = coords(me)
    nomi = [m.name if m else '' for m in me.materials]
    ic = nomi.index('M_capelli')
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    ls = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get('loop_start', ls)
    lt = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get('loop_total', lt)
    uvs = loop_uv(me)
    lv = loop_vert(me)
    cap = np.unique(lv[np.concatenate([np.arange(s, s + t) for s, t, m in zip(ls, lt, mi) if m == ic])])
    y = altezza_testa(arm, corpo, co)
    y0, y1 = y[cap].min(), y[cap].max()
    alto_v = (y - y0) / (y1 - y0)
    # isole dei capelli (con l'altezza media della faccia) e isole delle altre parti
    capelli = np.zeros((H, W), np.uint8)
    altri = np.zeros((H, W), np.uint8)
    somma = np.zeros((H, W), np.float32)
    for s, t, m in zip(ls, lt, mi):
        q = uvs[s:s + t]
        pts = np.round(np.column_stack([q[:, 0] * W, (1 - q[:, 1]) * H]) * 16).astype(np.int32)
        if m == ic:
            cv2.fillPoly(capelli, [pts], 255, cv2.LINE_8, 4)
            cv2.fillPoly(somma, [pts], float(alto_v[lv[s:s + t]].mean()), cv2.LINE_8, 4)
        else:
            cv2.fillPoly(altri, [pts], 255, cv2.LINE_8, 4)
    dentro = capelli > 0
    fuori = altri > 0
    k = dentro.astype(np.float32)
    den = cv2.GaussianBlur(k, (0, 0), 6)
    alto = np.where(den > 1e-4, cv2.GaussianBlur(somma * k, (0, 0), 6) / np.maximum(den, 1e-4), 0)
    # dettaglio della cottura: luminanza (lineare) rispetto alla media delle isole dei capelli intorno
    lin = lineare(img)
    L = lin @ np.array([0.2126, 0.7152, 0.0722])
    den2 = cv2.GaussianBlur(k, (0, 0), 24)
    media = cv2.GaussianBlur((L * k).astype(np.float32), (0, 0), 24) / np.maximum(den2, 1e-4)
    det = np.clip(L / np.maximum(media, 1e-4), 0.5, 1.3)
    # margine: i texel vuoti piu' vicini ai capelli che alle altre isole prendono i valori del texel dentro piu' vicino
    d, (iy, ix) = ndimage.distance_transform_edt(~dentro, return_indices=True)
    d_altri = ndimage.distance_transform_edt(~fuori)
    bordo = (d > 0) & (d <= margine) & (d < d_altri)
    alto = np.where(bordo, alto[iy, ix], alto)
    det = np.where(bordo, det[iy, ix], det)
    sel = dentro | bordo
    a = alto[sel]
    fondo = FONDO_CAPELLI + (1 - FONDO_CAPELLI) * _liscio(0.9, 0.97, a)     # il ciuffo in cima resta chiaro
    nuovo = colore_capelli(a) * (fondo * det[sel])[:, None]
    out = img.copy()
    out[sel] = srgb(nuovo)
    Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)).save(uscita, quality=92, subsampling=0)
    log(f'capelli argento-rosa nell\'atlante: {int(dentro.sum())} texel (+{int(bordo.sum())} di margine) -> '
        f'{os.path.relpath(uscita, REPO)}')
    return uscita
