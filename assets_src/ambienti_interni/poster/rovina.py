"""Rovina molto i poster di Jilly (richiesta dell'utente, 24 ottobre: "bruciare e scarabocchiare e rovinare
molto i poster di Jilly"). Ognuno in modo diverso, solo disegni e niente scritte:
  - cartellone del corridoio (interni): bruciato dal basso a destra, bordo carbonizzato, fuliggine che sale,
    buchi di sigaretta, occhio crocettato e denti aguzzi a pennarello sul sorriso;
  - poster del bagnino (bacheca dello stanzino): scarabocchiato con rabbia, occhio annerito a spirale,
    denti rossi, linee nervose, tagli di coltello, angolo strappato e angolo ripiegato, puntine;
  - manifesto dello spettacolo (sala principale): fradicio, strisce strappate, colature e muffa, l'occhio
    strappato via col graffio intorno, denti a penna. "LIVE SHOW" e gli orari restano leggibili.
Le parti bruciate, strappate o tagliate sono trasparenti (alfa vero, in Godot alpha scissor): si vede il
muro sotto. Partono dalle texture invecchiate già nel gioco, che non si toccano.

Uso: python3 assets_src/ambienti_interni/poster/rovina.py
Escono: godot/assets/ambienti_interni/texture/{cartellone_medusa,poster_bagnino}_rovinato.png e
godot/assets/models/mascotte/jilly/manifesto_rovinato_col.png (+ manifesto_rovinato_alfa.png per il retro).
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
from invecchia import blob  # noqa: E402

ROOT = os.path.abspath(os.path.join(QUI, '../../..'))
TEX_INT = os.path.join(ROOT, 'godot/assets/ambienti_interni/texture')
JILLY = os.path.join(ROOT, 'godot/assets/models/mascotte/jilly')
JILLY_TEX = os.path.join(ROOT, 'assets_src/mascotte/jilly_tex/gioco')


# ---------------------------------------------------------------- utilità
def f32(im):
    return np.asarray(im, np.float32) / 255


def sfoca(a, s):
    return ndimage.gaussian_filter(a, s)


def mescola(a, colore, quanto):
    q = np.clip(quanto, 0, 1)[..., None]
    return a * (1 - q) + np.asarray(colore, np.float32) * q


def strappo_vecchio(nome, seed, strappi, w, h):
    """Il bordo strappato già dipinto da invecchia.py (lì si vedeva la lamiera dipinta): ora diventa trasparente."""
    blob((h, w), seed, 3); blob((h, w), seed + 1, 6); blob((h, w), seed + 2, 10)
    yy = np.linspace(0, 1, h)[:, None]
    t = blob((h, w), seed + 3, 4)
    bordo = np.minimum.reduce([yy * np.ones((1, w)), (1 - yy) * np.ones((1, w)),
                               np.ones((h, 1)) * np.linspace(0, 1, w)[None], np.ones((h, 1)) * np.linspace(1, 0, w)[None]])
    s = ((t * 0.6 + (0.07 - bordo) * 9) > (1 - strappi)).astype(np.float32)
    return sfoca(s, 1.5)


def bordo_strappato(a, alfa, larghezza=3.0, forza=0.75):
    """Il filo bianco delle fibre dove la carta è strappata, e un'ombra appena dentro."""
    fuori = 1 - alfa
    vicino = np.clip(sfoca(fuori, larghezza) * 3, 0, 1) * alfa
    a = mescola(a, (0.9, 0.87, 0.78), vicino * forza)
    return a


def bruciatura(a, alfa, campo, soglia_buco, banda, seme, fuliggine=0.0, verso=(0, -1)):
    """campo: più alto = più bruciato. Oltre soglia_buco la carta non c'è più; prima un bordo nero
    carbonizzato, poi marrone strinato e una sfumatura gialla. La fuliggine sale (verso)."""
    h, w = alfa.shape
    buco = (campo > soglia_buco).astype(np.float32)
    d = soglia_buco - campo   # >0 fuori dal buco
    nero = np.clip(1 - d / (banda * 0.35), 0, 1) * (1 - buco)
    bruno = np.clip(1 - d / banda, 0, 1) * (1 - buco)
    giallo = np.clip(1 - d / (banda * 2.6), 0, 1) * (1 - buco)
    a = mescola(a, (0.55, 0.38, 0.16), giallo * 0.45)
    a = mescola(a, (0.3, 0.16, 0.06), bruno * 0.85)
    gr = blob((h, w), seme, 40)
    a = mescola(a, (0.035, 0.028, 0.022), np.clip(nero * (1.1 + 0.4 * gr), 0, 1))
    # crepe chiare della cenere sul bordo nero
    cr = (blob((h, w), seme + 1, 60) > 0.72).astype(np.float32) * nero
    a = mescola(a, (0.32, 0.3, 0.27), cr * 0.5)
    if fuliggine:
        fu = np.clip(nero + bruno * 0.5, 0, 1)
        dx, dy = verso
        acc = np.zeros_like(fu)
        for k in range(1, 40):
            sh = ndimage.shift(fu, (dy * k * h * 0.006, dx * k * w * 0.006 + math.sin(k * 0.7) * 3), order=1)
            acc = np.maximum(acc, sh * (1 - k / 40) ** 1.3)
        acc = sfoca(acc, 9) * (0.6 + 0.6 * blob((h, w), seme + 2, 6))
        a = mescola(a, (0.06, 0.05, 0.045), np.clip(acc * fuliggine, 0, 0.85))
    return a, alfa * (1 - buco)


def buchi_sigaretta(a, alfa, punti, raggio, seme):
    h, w = alfa.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    campo = np.zeros((h, w), np.float32)
    n = blob((h, w), seme, 30)
    for (x, y), r in zip(punti, raggio):
        campo = np.maximum(campo, 1 - np.hypot(xx - x, yy - y) / (r * 2.2) + (n - 0.5) * 0.25)
    return bruciatura(a, alfa, campo, 0.55, 0.28, seme + 3)


def taglio(alfa, a, p0, p1, larghezza, seme):
    """Un taglio di coltello: fessura sottile trasparente, con i lembi un po' scuri."""
    h, w = alfa.shape
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    rng = np.random.default_rng(seme)
    pts = [p0]
    for t in np.linspace(0, 1, 9)[1:]:
        pts.append((p0[0] + (p1[0] - p0[0]) * t + rng.normal(0, 2), p0[1] + (p1[1] - p0[1]) * t + rng.normal(0, 2)))
    for i in range(len(pts) - 1):
        lw = max(1, int(larghezza * math.sin(math.pi * (i + 0.5) / (len(pts) - 1)) + 0.5))
        d.line([pts[i], pts[i + 1]], fill=255, width=lw)
    f = f32(m)
    lembo = np.clip(sfoca(f, 2.5) * 2.5, 0, 1) * (1 - f)
    a = mescola(a, (0.12, 0.1, 0.08), lembo * 0.55)
    a = mescola(a, (0.9, 0.87, 0.78), np.clip(sfoca(f, 1.0) * 2, 0, 1) * (1 - f) * 0.5)
    return a, alfa * (1 - (f > 0.5))


def angolo_ripiegato(a, alfa, angolo, d, ombra=0.5, seme=0):
    """L'angolo si è piegato in avanti sulla faccia del poster, piatto: dove c'era resta il muro, sopra
    l'immagine si vede il retro della carta (il riflesso dell'angolo sulla piega).
    angolo: 'bd' (basso destra), 'ad', 'bs', 'as'. d in pixel."""
    h, w = alfa.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx = w - 1 if angolo[1] == 'd' else 0
    cy = h - 1 if angolo[0] == 'b' else 0
    sx = -1 if cx else 1
    sy = -1 if cy else 1
    u, v = np.abs(xx - cx), np.abs(yy - cy)
    s = u + v
    via = s < d
    lembo = (s >= d) & (u <= d) & (v <= d)
    # la carta del lembo c'è se c'era nel punto riflesso (d - v, d - u)
    rx = np.clip(cx + sx * (d - v), 0, w - 1).astype(int)
    ry = np.clip(cy + sy * (d - u), 0, h - 1).astype(int)
    lembo &= alfa[ry, rx] > 0.5
    q = np.clip((s - d) / d, 0, 1)   # 0 sulla piega, 1 sulla punta
    tinta = np.array((0.8, 0.74, 0.6), np.float32) * (0.88 + 0.12 * blob((h, w), seme + 1, 8))[..., None]
    tinta = tinta * (1.0 - 0.18 * q[..., None])   # la punta si alza appena: più in ombra
    # ombra del lembo sulla carta sotto, spostata in basso a destra
    lf = lembo.astype(np.float32)
    om = ndimage.shift(sfoca(lf, 4), (5, 4), order=1) * (1 - lf)
    alfa = alfa * (~via)
    a = mescola(a, (0.03, 0.025, 0.02), np.clip(om, 0, 1) * ombra * alfa)
    a = np.where(lembo[..., None], tinta, a)
    alfa = np.maximum(alfa, lf)
    piega = np.exp(-((s - d) / 1.6) ** 2) * (u <= d) * (v <= d)
    return mescola(a, (0.96, 0.93, 0.86), piega * 0.7), alfa


# ---------------------------------------------------------------- scarabocchi (solo disegni)
class Pennarello:
    """Disegna in un livello a 2x poi lo moltiplica sull'immagine: tratti di pennarello con un po' di tremolio."""

    def __init__(self, w, h, seme):
        self.k = 2
        self.w, self.h = w, h
        self.liv = Image.new('RGBA', (w * 2, h * 2), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.liv)
        self.rng = np.random.default_rng(seme)

    def tratto(self, pts, larg, col, trem=1.5, alfa=235):
        k = self.k
        pp = [(x * k + self.rng.normal(0, trem), y * k + self.rng.normal(0, trem)) for x, y in pts]
        lw = max(1, int(larg * k))
        for i in range(len(pp) - 1):
            self.d.line([pp[i], pp[i + 1]], fill=col + (alfa,), width=lw)
            r = lw / 2
            self.d.ellipse([pp[i][0] - r, pp[i][1] - r, pp[i][0] + r, pp[i][1] + r], fill=col + (alfa,))

    def linea(self, p0, p1, larg, col, n=10, trem=1.5, alfa=235, curva=0.0):
        pts = []
        nx, ny = -(p1[1] - p0[1]), p1[0] - p0[0]
        for t in np.linspace(0, 1, n):
            b = math.sin(t * math.pi) * curva
            pts.append((p0[0] + (p1[0] - p0[0]) * t + nx * b, p0[1] + (p1[1] - p0[1]) * t + ny * b))
        self.tratto(pts, larg, col, trem, alfa)

    def croce(self, cx, cy, r, larg, col, volte=2):
        for v in range(volte):
            j = self.rng.normal(0, r * 0.08, 4)
            self.linea((cx - r + j[0], cy - r + j[1]), (cx + r + j[2], cy + r + j[3]), larg, col, curva=0.03)
            j = self.rng.normal(0, r * 0.08, 4)
            self.linea((cx + r + j[0], cy - r + j[1]), (cx - r + j[2], cy + r + j[3]), larg, col, curva=-0.03)

    def spirale(self, cx, cy, r, larg, col, giri=14):
        """Occhio annerito con rabbia: tanti giri stretti, sempre un po' fuori posto."""
        pts = []
        n = giri * 24
        for i in range(n):
            t = i / n
            ang = t * giri * 2 * math.pi
            rr = r * (0.25 + 0.75 * abs(math.sin(t * 5.3 + 0.4))) * (0.85 + 0.15 * self.rng.random())
            pts.append((cx + rr * math.cos(ang) * 1.1, cy + rr * math.sin(ang) * 0.95))
        self.tratto(pts, larg, col, trem=1.0)

    def denti(self, cx, cy, larg, alt, n, col_bordo, col_bocca, col_denti, spessore, arco=0.25):
        """Un ghigno largo con due file di denti a punta che si incastrano, disegnato sopra il sorriso."""
        k = self.k
        def y_bocca(t, su):
            # labbro: arco verso l'alto ai lati (ghigno), la bocca è aperta di "alt"
            b = cy - arco * alt * (1 - (2 * t - 1) ** 2) * -1
            return b + (-alt / 2 if su else alt / 2) * math.sin(math.pi * (0.08 + 0.84 * t))
        xs = [cx - larg / 2 + larg * t for t in np.linspace(0, 1, 40)]
        top = [(x, y_bocca(t, True)) for x, t in zip(xs, np.linspace(0, 1, 40))]
        bot = [(x, y_bocca(t, False)) for x, t in zip(xs, np.linspace(0, 1, 40))]
        poly = [(x * k, y * k) for x, y in top + bot[::-1]]
        self.d.polygon(poly, fill=col_bocca + (240,))
        # denti di sopra (in giù) e di sotto (in su), sfalsati
        for fila, su in ((top, True), (bot, False)):
            m = n if su else n - 1
            for i in range(m):
                t0 = (i + (0 if su else 0.5)) / n
                t1 = (i + 1 + (0 if su else 0.5)) / n
                if t1 > 1:
                    break
                tm = (t0 + t1) / 2
                x0, x1, xm = cx - larg / 2 + larg * t0, cx - larg / 2 + larg * t1, cx - larg / 2 + larg * tm
                y0, y1 = y_bocca(t0, su), y_bocca(t1, su)
                ap = (y_bocca(tm, False) - y_bocca(tm, True))
                punta = (xm + self.rng.normal(0, larg * 0.006), (y0 + y1) / 2 + (0.78 if su else -0.78) * ap)
                tri = [(x0 * k, y0 * k), (x1 * k, y1 * k), (punta[0] * k, punta[1] * k)]
                self.d.polygon(tri, fill=col_denti + (245,))
                self.tratto([(x0, y0), punta, (x1, y1)], spessore * 0.6, col_bordo, trem=0.6)
        self.tratto(top, spessore, col_bordo, trem=0.8)
        self.tratto(bot, spessore, col_bordo, trem=0.8)

    def nervose(self, cx, cy, r, n, larg, col, lung=(0.3, 1.0)):
        """Linee nervose a zig-zag intorno a un punto."""
        for _ in range(n):
            ang = self.rng.uniform(0, 2 * math.pi)
            l = r * self.rng.uniform(*lung)
            r0 = r * self.rng.uniform(0.2, 0.6)
            pts = []
            for i in range(8):
                t = i / 7
                rr = r0 + l * t
                a2 = ang + self.rng.normal(0, 0.08)
                pts.append((cx + rr * math.cos(a2), cy + rr * math.sin(a2)))
            self.tratto(pts, larg * self.rng.uniform(0.6, 1.1), col, trem=2.0)

    def tratteggio(self, x0, y0, x1, y1, n, larg, col, ang=0.9):
        """Righe fitte e storte, avanti e indietro (cancellare con rabbia)."""
        pts = []
        for i in range(n):
            t = i / max(1, n - 1)
            x = x0 + (x1 - x0) * t
            dy = (y1 - y0)
            pts.append((x + self.rng.normal(0, 2), y0 + self.rng.normal(0, dy * 0.05)))
            pts.append((x + dy * math.cos(ang) * 0.3 + self.rng.normal(0, 2), y1 + self.rng.normal(0, dy * 0.05)))
        self.tratto(pts, larg, col, trem=1.2)

    def applica(self, a, alfa):
        liv = self.liv.resize((self.w, self.h), Image.LANCZOS)
        l = f32(liv)
        q = l[..., 3:4] * alfa[..., None]
        # il pennarello è inchiostro: moltiplica i colori scuri, copre quelli chiari (vernice/bianchetto)
        chiaro = (l[..., :3].mean(-1, keepdims=True) > 0.6).astype(np.float32)
        molt = a * l[..., :3]
        mix = molt * (1 - chiaro) + l[..., :3] * chiaro
        return a * (1 - q) + mix * q

    def applica_pastello(self, a, alfa, seme):
        """Pastello a cera: copre (non moltiplica) ma salta sui rilievi della carta, a granelli."""
        liv = self.liv.resize((self.w, self.h), Image.LANCZOS)
        l = f32(liv)
        grana = blob((self.h, self.w), seme, 120) * 0.6 + np.random.default_rng(seme).random((self.h, self.w)) * 0.4
        q = l[..., 3] * np.clip((grana - 0.12) * 4.0, 0, 1) * alfa
        return mescola(a, l[..., :3], q * 0.92)


def graffi(a, alfa, n, seme, lung=(40, 220)):
    """Graffi di unghie o chiavi: righe chiare (la carta sotto l'inchiostro) con un filo scuro accanto."""
    h, w = alfa.shape
    rng = np.random.default_rng(seme)
    m = Image.new('L', (w, h), 0); d = ImageDraw.Draw(m)
    s = Image.new('L', (w, h), 0); ds = ImageDraw.Draw(s)
    for _ in range(n):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ang = rng.normal(1.2, 0.35)
        l = rng.uniform(*lung)
        pts = [(x + math.cos(ang) * l * t + rng.normal(0, 1), y + math.sin(ang) * l * t + rng.normal(0, 1)) for t in np.linspace(0, 1, 6)]
        d.line(pts, fill=255, width=int(rng.integers(1, 3)))
        ds.line([(p[0] + 1.5, p[1] + 1.5) for p in pts], fill=255, width=1)
    a = mescola(a, (0.12, 0.1, 0.08), f32(s) * 0.35)
    a = mescola(a, (0.88, 0.85, 0.76), f32(m) * 0.75)
    return a


# ---------------------------------------------------------------- acqua, muffa, sporco, scotch, puntine
def colature(a, alfa, n, seme, forza=0.5, colore=(0.38, 0.28, 0.15), da_y=0.0):
    h, w = alfa.shape
    rng = np.random.default_rng(seme)
    m = Image.new('L', (w, h), 0); d = ImageDraw.Draw(m)
    for _ in range(n):
        x = rng.uniform(0, w); y = h * (da_y + rng.uniform(0, 0.15)); l = h * rng.uniform(0.15, 0.7)
        lw = rng.uniform(3, 12) * w / 1000
        pts = []
        for t in np.linspace(0, 1, 30):
            pts.append((x + math.sin(t * 7 + x) * 3, y + l * t))
        for i in range(len(pts) - 1):
            ww = max(1, int(lw * (1 - 0.6 * i / len(pts))))
            d.line([pts[i], pts[i + 1]], fill=int(255 * (1 - 0.5 * i / len(pts))), width=ww)
        d.ellipse([pts[-1][0] - lw, pts[-1][1] - lw * 0.6, pts[-1][0] + lw, pts[-1][1] + lw * 1.2], fill=160)
    c = sfoca(f32(m), 1.2)
    bordo = np.clip(c - sfoca(c, 3), 0, 1) * 3
    a = mescola(a, colore, c * forza)
    return mescola(a, np.asarray(colore) * 0.5, np.clip(bordo, 0, 1) * forza * 0.6)


def macchie_acqua(a, campo, soglie, colore=(0.55, 0.42, 0.22)):
    """Poche macchie grandi con l'alone: il campo si liscia prima, così i bordi non fanno le curve di livello."""
    campo = sfoca(campo, campo.shape[1] * 0.012)
    for s in soglie:
        dentro = sfoca((campo > s).astype(np.float32), 2.5)
        alone = np.clip(dentro * (1 - dentro) * 4, 0, 1) ** 1.5
        a = mescola(a, colore, dentro * 0.18)
        a = mescola(a, np.asarray(colore) * 0.5, alone * 0.4)
    return a


def muffa(a, zona, seme, densita=0.02):
    h, w = zona.shape
    r = np.random.default_rng(seme)
    punti = (r.random((h, w)) < densita * zona ** 2).astype(np.float32)
    punti = np.clip(sfoca(punti, 1.0) * 5, 0, 1)
    alone = np.clip(sfoca(punti, 5) * 3, 0, 0.45)
    a = mescola(a, (0.32, 0.36, 0.24), alone)
    return mescola(a, (0.08, 0.09, 0.06), punti * 0.9)


def scotch(a, alfa, cx, cy, lw, lh, ang, seme, solo_carta=True):
    """Scotch vecchio ingiallito, lucido, con i bordi sporchi. solo_carta: resta sopra la carta."""
    h, w = alfa.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    c, s = math.cos(ang), math.sin(ang)
    u = (xx - cx) * c + (yy - cy) * s
    v = -(xx - cx) * s + (yy - cy) * c
    n = blob((h, w), seme, 25)
    dentro = (np.abs(u) < lw / 2 + (n - 0.5) * 6) & (np.abs(v) < lh / 2)
    m = dentro.astype(np.float32)
    if solo_carta:
        m *= alfa
    bordo = np.clip(sfoca(m, 1.2) * (1 - sfoca(m, 1.2)) * 6, 0, 1)
    a = mescola(a, (0.8, 0.62, 0.28), m * 0.42)
    a = a * (1 + 0.12 * m[..., None] * blob((h, w), seme + 1, 12)[..., None])
    a = mescola(a, (0.25, 0.2, 0.12), bordo * 0.6)
    return a, np.maximum(alfa, m)


def puntina(a, alfa, cx, cy, r, colore):
    h, w = alfa.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    om = np.exp(-(((xx - cx - r * 0.5) ** 2 + (yy - cy - r * 0.6) ** 2) / (r * 1.1) ** 2))
    a = mescola(a, (0.02, 0.02, 0.02), om * 0.55)
    dd = np.hypot(xx - cx, yy - cy) / r
    testa = np.clip((1 - dd) * r * 0.8, 0, 1)
    luce = np.clip(1 - np.hypot(xx - cx + r * 0.35, yy - cy + r * 0.35) / (r * 0.4), 0, 1)
    col = np.asarray(colore, np.float32) * (0.55 + 0.45 * (1 - dd))[..., None]
    a = a * (1 - testa[..., None]) + col * testa[..., None]
    a = mescola(a, (1, 1, 1), luce * 0.7)
    return a, np.maximum(alfa, testa)


def salva(a, alfa, percorso):
    rgba = np.dstack([np.clip(a, 0, 1), (alfa > 0.5).astype(np.float32)])
    Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA').save(percorso, optimize=True)
    print('ok', os.path.relpath(percorso, ROOT), (alfa <= 0.5).mean().round(3), 'trasparente')


# ---------------------------------------------------------------- 1. cartellone del corridoio: bruciato
def cartellone():
    src = Image.open(os.path.join(TEX_INT, 'cartellone_medusa_vecchio.jpg')).convert('RGB')
    w0, h0 = src.size
    W, H = 1536, 2048
    k = W / w0
    vecchio = strappo_vecchio('cartellone_medusa', 5, 0.10, w0, h0)
    a = f32(src.resize((W, H), Image.LANCZOS))
    alfa = 1 - (np.asarray(Image.fromarray((vecchio * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR), np.float32) / 255 > 0.45)
    alfa = alfa.astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # scarabocchi prima della bruciatura (il fuoco li ha mangiati in parte)
    p = Pennarello(W, H, 51)
    ex, ey, er = 445 * k, 250 * k, 46 * k
    p.croce(ex, ey, er * 1.25, 9 * k / 2, (14, 12, 12), volte=3)
    p.d.ellipse([(ex - er * 1.4) * 2, (ey - er * 1.3) * 2, (ex + er * 1.4) * 2, (ey + er * 1.3) * 2], outline=(14, 12, 12, 220), width=int(6 * k))
    p.denti(455 * k, 308 * k, 150 * k, 56 * k, 9, (14, 12, 12), (40, 6, 8), (236, 230, 214), 5 * k / 2, arco=0.5)
    p.nervose(ex, ey, er * 2.6, 26, 3.2 * k / 2, (14, 12, 12), lung=(0.4, 1.0))
    # le due stelline marine e i pesci: occhi crocettati anche a loro, piccoli
    for (x, y) in ((70, 1068), (775, 1068), (95, 708), (775, 660)):
        p.croce(x * k, y * k, 14 * k, 3.5 * k / 2, (14, 12, 12), volte=2)
    a = p.applica(a, alfa)
    a = graffi(a, alfa, 22, 52, lung=(60 * k, 220 * k))
    # bruciatura grande: sale dall'angolo in basso a destra e si mangia mezza campana e i tentacoli
    n = blob((H, W), 53, 5) * 0.65 + blob((H, W), 54, 18) * 0.35
    dist = np.hypot((xx - W * 1.02) / W, (yy - H * 1.05) / H * 1.15)
    campo = 1 - dist * 1.55 + (n - 0.5) * 0.55
    a, alfa = bruciatura(a, alfa, campo, 0.42, 0.14, 55, fuliggine=1.6, verso=(-0.25, -1))
    # una seconda lingua di fuoco sul bordo sinistro, più piccola
    dist2 = np.hypot((xx - W * -0.02) / W * 1.4, (yy - H * 0.62) / H * 0.8)
    campo2 = 1 - dist2 * 3.4 + (blob((H, W), 56, 7) - 0.5) * 0.6
    a, alfa = bruciatura(a, alfa, campo2, 0.48, 0.12, 57, fuliggine=0.7, verso=(0.15, -1))
    # buchi di sigaretta sul corpo e uno nell'occhio
    a, alfa = buchi_sigaretta(a, alfa, [(ex + 8, ey + 4), (300 * k, 560 * k), (560 * k, 470 * k), (380 * k, 800 * k), (640 * k, 210 * k)],
                              [9 * k, 7 * k, 8 * k, 6 * k, 7 * k], 58)
    # acqua e muffa in basso (lo spegnimento), muffa negli angoli
    a = macchie_acqua(a, blob((H, W), 59, 3) + np.linspace(0, 1, H)[:, None] * 0.5 - 0.1, (0.62, 0.74))
    zona = np.clip((blob((H, W), 60, 5) + np.linspace(0, 1, H)[:, None] * 0.4 - 0.75) * 4, 0, 1)
    a = muffa(a, zona, 61, 0.018)
    a = colature(a, alfa, 7, 62, forza=0.35, da_y=0.0)
    # scotch vecchio che tiene uniti due strappi
    a, alfa = scotch(a, alfa, 250 * k, 930 * k, 120 * k, 34 * k, 0.6, 63)
    a, alfa = scotch(a, alfa, 600 * k, 120 * k, 140 * k, 36 * k, -0.2, 64)
    a = bordo_strappato(a, alfa, 2.0, 0.5)
    salva(a, alfa, os.path.join(TEX_INT, 'cartellone_medusa_rovinato.png'))


# ---------------------------------------------------------------- 2. poster del bagnino: scarabocchiato
def bagnino():
    src = Image.open(os.path.join(TEX_INT, 'poster_bagnino_vecchio.jpg')).convert('RGB')
    W, H = src.size
    vecchio = strappo_vecchio('poster_bagnino', 7, 0.08, W, H)
    a = f32(src)
    alfa = (vecchio < 0.45).astype(np.float32)
    p = Pennarello(W, H, 71)
    nero, rosso = (12, 10, 12), (150, 12, 14)
    ex, ey, er = 408, 146, 31
    p.spirale(ex, ey, er * 1.4, 7, nero, giri=30)
    p.spirale(ex + 3, ey - 2, er * 0.9, 5, nero, giri=14)
    p.denti(420, 192, 120, 46, 8, nero, (30, 4, 6), (238, 232, 220), 3.5, arco=0.6)
    p.nervose(ex, ey + 20, 130, 18, 4.2, rosso, lung=(0.5, 1.1))
    # rosso che cola dagli occhi giù sulle guance
    for dx in (-18, 2, 20):
        p.linea((ex + dx, ey + 20), (ex + dx * 1.3 + p.rng.normal(0, 4), ey + 110 + p.rng.normal(0, 20)), 4, rosso, n=14, trem=1.2)
    # il delfino e il salvagente: occhi annullati
    p.spirale(776, 262, 14, 3, nero, giri=10)
    p.croce(172, 306, 16, 3, nero)
    # nuvola di scarabocchi rabbiosi sul busto e un'altra rossa sulla campana
    p.spirale(425, 500, 75, 3.6, nero, giri=9)
    p.spirale(440, 700, 110, 3.2, rosso, giri=7)
    a = p.applica(a, alfa)
    a = graffi(a, alfa, 25, 72, lung=(30, 150))
    # tagli di coltello in croce sul viso e lungo il corpo (fessure vere)
    a, alfa = taglio(alfa, a, (330, 80), (500, 330), 4, 73)
    a, alfa = taglio(alfa, a, (495, 70), (330, 320), 3, 74)
    a, alfa = taglio(alfa, a, (430, 420), (470, 900), 3, 75)
    a, alfa = taglio(alfa, a, (250, 600), (360, 1050), 2, 76)
    # angolo in alto a sinistra strappato via (resta il pezzetto sotto la puntina), in basso a destra ripiegato
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nb = blob((H, W), 77, 12)
    via = ((xx / W) + (yy / H) * 0.9 + (nb - 0.5) * 0.12) < 0.3
    resto = np.hypot(xx - 40, yy - 38) < 26 + (nb - 0.5) * 18   # il brandello sotto la puntina
    alfa = alfa * (~via | resto)
    a, alfa = angolo_ripiegato(a, alfa, 'bd', 230, ombra=0.55, seme=78)
    # macchie d'acqua e muffa (moderate: qui comanda il pennarello)
    a = macchie_acqua(a, blob((H, W), 79, 3) + np.linspace(0, 1, H)[:, None] * 0.35, (0.72, 0.8))
    a = muffa(a, np.clip((blob((H, W), 80, 5) - 0.6) * 3, 0, 1), 81, 0.01)
    # puntine: quattro, una tiene il brandello dell'angolo strappato
    for (x, y), c in (((40, 38), (0.75, 0.08, 0.06)), ((W - 34, 30), (0.1, 0.3, 0.75)),
                      ((34, H - 40), (0.85, 0.75, 0.1)), ((W / 2 + 6, 22), (0.1, 0.55, 0.2))):
        a, alfa = puntina(a, alfa, x, y, 11, c)
    # (la puntina in basso a destra è sotto l'angolo ripiegato: c'è solo il buchino)
    a = bordo_strappato(a, alfa, 1.6, 0.6)
    salva(a, alfa, os.path.join(TEX_INT, 'poster_bagnino_rovinato.png'))


# ---------------------------------------------------------------- 3. manifesto della sala: fradicio e strappato
def manifesto():
    src = Image.open(os.path.join(JILLY, 'manifesto_manifesto_col.jpg')).convert('RGB')
    W, H = src.size
    a = f32(src)
    alfa = np.ones((H, W), np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    ex, ey, er = 631, 702, 46
    p = Pennarello(W, H, 91)
    nero, blu = (16, 14, 18), (22, 30, 92)
    # denti a penna biro sul sorriso, tanti e fitti
    p.denti(636, 768, 160, 58, 11, nero, (24, 10, 30), (230, 226, 214), 5.5, arco=0.55)
    # linee nervose a biro intorno all'occhio strappato e lacrime nere
    p.nervose(ex, ey, er * 2.4, 60, 2.2, blu, lung=(0.3, 1.2))
    for dx in (-20, 0, 18):
        p.linea((ex + dx, ey + er), (ex + dx * 1.5, ey + er + 160 + p.rng.normal(0, 30)), 5, nero, n=16, trem=1.2)
    a = p.applica(a, alfa)
    a = graffi(a, alfa, 30, 92, lung=(40, 200))
    # l'occhio strappato via: buco con il bordo sfilacciato e i segni di unghie intorno
    nn = blob((H, W), 93, 25)
    occhio = np.hypot((xx - ex) / 1.1, yy - ey) < er * 1.05 + (nn - 0.5) * 26
    alfa *= ~occhio
    for i in range(7):
        ang = -0.6 + i * 0.22
        a, alfa = taglio(alfa, a, (ex + math.cos(ang) * er * 1.1, ey + math.sin(ang) * er * 1.1),
                         (ex + math.cos(ang) * er * 2.1, ey + math.sin(ang) * er * 2.3), 2, 94 + i)
    # strisce strappate: una grande in diagonale sulla campana (sotto la figura, sopra "LIVE SHOW")
    n2 = blob((H, W), 101, 9)
    u, v = xx / W, yy / H
    banda = np.abs((v - 0.66) - (u - 0.5) * 0.35) < 0.045 + (n2 - 0.5) * 0.06
    banda &= (u > 0.38) & (u < 1.0)
    # pezzo mancante sul bordo destro a metà (il morso che si allarga)
    morso = (u > 0.84 - (n2 - 0.5) * 0.12) & (np.abs(v - 0.42) < 0.12 + (n2 - 0.5) * 0.05)
    alfa *= ~(banda | morso)
    # la striscia strappata lascia attaccati brandelli: piccole isole di carta nel buco
    isole = (blob((H, W), 102, 40) > 0.78) & banda
    alfa = np.maximum(alfa, isole.astype(np.float32))
    # un bruciacchiato piccolo in alto a sinistra (accendino), senza toccare il logo
    a, alfa = buchi_sigaretta(a, alfa, [(140, 620), (1120, 1180), (300, 1010)], [12, 9, 10], 103)
    # acqua: colature lunghe dall'alto, alone grande dal basso, muffa forte in basso e sul bordo sinistro
    a = colature(a, alfa, 14, 104, forza=0.5, da_y=0.0)
    a = macchie_acqua(a, blob((H, W), 105, 3) + v * 0.55 - 0.05, (0.6, 0.75), colore=(0.5, 0.4, 0.22))
    zona = np.clip((blob((H, W), 106, 5) + v * 0.45 + np.clip(0.12 - u, 0, 1) * 3 - 0.8) * 4, 0, 1)
    # gli orari in basso restano leggibili: la muffa li sfiora
    orari = (v > 0.86) & (v < 0.97) & (u > 0.12) & (u < 0.88)
    zona *= np.where(orari, 0.25, 1.0)
    a = muffa(a, zona, 107, 0.03)
    # scotch messo dopo per tenere su il pezzo sotto lo strappo
    a, alfa = scotch(a, alfa, 0.62 * W, 0.735 * H, 150, 40, 1.35, 108)
    a, alfa = scotch(a, alfa, 0.83 * W, 0.56 * H, 120, 36, 0.2, 109)
    a = bordo_strappato(a, alfa, 2.2, 0.7)
    salva(a, alfa, os.path.join(JILLY_TEX, 'manifesto_rovinato_col.png'))
    # il retro della carta (carta_retro nel modello) ha gli stessi buchi: bianco con l'alfa
    bianco = np.ones_like(a)
    salva(bianco, alfa, os.path.join(JILLY_TEX, 'manifesto_rovinato_alfa.png'))


# ---------------------------------------------------------------- 4. pannello rosa dell'infermeria: pastelli a cera
def infermeria():
    """Lo stesso cartellone dell'arcobaleno, nell'infermeria per bambini: rovinato a pastello a cera, come se
    l'avessero rifatto i bambini (occhio cancellato a giri neri, denti rossi, lacrime viola, la campana
    annerita, onde e nuvole cattive), poco bruciato: solo un buco di sigaretta. Angolo strappato e scotch."""
    src = Image.open(os.path.join(TEX_INT, 'cartellone_medusa_vecchio.jpg')).convert('RGB')
    W, H = src.size
    vecchio = strappo_vecchio('cartellone_medusa', 5, 0.10, W, H)
    a = f32(src)
    alfa = (vecchio < 0.45).astype(np.float32)
    p = Pennarello(W, H, 111)
    nero, rosso, viola, verde = (20, 18, 22), (200, 30, 30), (110, 40, 150), (40, 110, 40)
    ex, ey, er = 445, 250, 46
    p.spirale(ex, ey, er * 1.3, 13, nero, giri=40)
    p.spirale(ex, ey, er * 0.7, 14, nero, giri=20)
    p.denti(455, 312, 180, 66, 8, rosso, (120, 10, 14), (245, 240, 230), 8, arco=0.6)
    for dx in (-26, -6, 16, 32):
        p.linea((ex + dx, ey + er), (ex + dx * 1.4 + p.rng.normal(0, 6), ey + er + 140 + p.rng.normal(0, 25)), 7, viola, n=12, trem=2)
    # la campana colorata di nero a zig-zag, i tentacoli ripassati in rosso come graffi
    zig = []
    for i in range(22):
        y = 470 + i * 10
        zig += [(255 + p.rng.normal(0, 12), y), (645 + p.rng.normal(0, 12), y + 5)]
    p.tratto(zig, 9, nero, trem=3)
    for i in range(7):
        x = 300 + i * 50
        p.linea((x, 690), (x + p.rng.normal(0, 40), 1020 + p.rng.normal(0, 40)), 6, rosso, n=10, trem=4)
    # l'arcobaleno cancellato con nuvole nere e pioggia
    for cx in (170, 360, 700):
        p.spirale(cx, 120 + p.rng.normal(0, 20), 60, 8, (60, 60, 70), giri=6)
    for i in range(14):
        x = p.rng.uniform(80, 820)
        p.linea((x, 180), (x - 25, 300 + p.rng.uniform(0, 80)), 4, viola, n=5, trem=1.5)
    # la manina che saluta: ripassata in verde con le dita a punta
    p.nervose(745, 335, 70, 9, 6, verde, lung=(0.5, 1.0))
    a = p.applica_pastello(a, alfa, 112)
    a = graffi(a, alfa, 14, 113, lung=(30, 140))
    a, alfa = buchi_sigaretta(a, alfa, [(560, 860)], [9], 114)
    # angolo in alto a destra strappato via, dentro la cornice di nastro adesivo
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nb = blob((H, W), 115, 12)
    via = ((W - xx) / W + yy / H * 0.8 + (nb - 0.5) * 0.12) < 0.36
    alfa = alfa * ~via
    a = macchie_acqua(a, blob((H, W), 116, 3) + np.linspace(0, 1, H)[:, None] * 0.4, (0.78,))
    # scotch agli angoli rimasti, sopra la carta
    for (x, y, ang) in ((70, 75, 0.7), (70, H - 75, -0.7), (W - 70, H - 75, 0.7)):
        a, alfa = scotch(a, alfa, x, y, 140, 38, ang, 117 + int(x + y))
    a = bordo_strappato(a, alfa, 1.6, 0.6)
    salva(a, alfa, os.path.join(TEX_INT, 'cartellone_medusa_infermeria.png'))


if __name__ == '__main__':
    scelti = sys.argv[1:] or ['cartellone', 'bagnino', 'manifesto', 'infermeria']
    for s in scelti:
        globals()[s]()
