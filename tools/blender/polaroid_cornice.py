"""Polaroid del capitolo 1: dalla foto quadrata alla texture finale con il bordo.

Uso (dalla radice del repository, con il venv di Blender che ha numpy, pillow e opencv):
    PY=/home/user/tools/blender-venv/bin/python
    $PY tools/blender/polaroid_cornice.py            # tutte e 10 + retro + normal map + tavola
    $PY tools/blender/polaroid_cornice.py P07 P09    # solo alcune (la tavola si rifà comunque)

Ingresso: assets_src/polaroid/foto/Pxx.jpg (la foto quadrata generata con Meshy, senza bordo).
Uscita, in assets_src/polaroid/texture/:
    Pxx.jpg            colore della faccia davanti: foto con il bordo, 1024 x 1245 px
    Pxx_rugosita.jpg   rugosità (scala di grigi, lineare): foto lucida, bordo satinato, macchie opache
    normale.png        normal map comune a tutte (OpenGL, Y+): finestra della foto incassata, grana
    retro.jpg          colore del retro (comune), retro_rugosita.jpg
e la tavola riassuntiva docs/proposte/polaroid/tavola_polaroid.jpg (2 righe da 5, etichette P1-P10).

Il formato è quello della Polaroid 600: 88 x 107 mm, finestra 79 x 79 mm, bordo 4,5 mm ai lati,
6,5 mm sopra e 21,5 mm sotto. Tutto il "vecchio" è procedurale e deterministico (un seme per foto):
viraggio dei colori, flash, grana, sfocatura, difetti dello sviluppo ai bordi, graffi, polvere, e
un'usura che cresce da P1 a P10: infiltrazioni d'acqua dai bordi, aloni, sale, bolle
dell'emulsione, muffa, angoli piegati. Il soggetto al centro resta sempre leggibile.
"""
import os, sys
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
FOTO = os.path.join(RADICE, 'assets_src', 'polaroid', 'foto')
TEX = os.path.join(RADICE, 'assets_src', 'polaroid', 'texture')
TAVOLA = os.path.join(RADICE, 'docs', 'proposte', 'polaroid', 'tavola_polaroid.jpg')

# ------------------------------------------------------------------ formato (mm -> px)
W_MM, H_MM, WIN_MM, LATO_MM, SOPRA_MM = 88.0, 107.0, 79.0, 4.5, 6.5
W = 1024
PX = W / W_MM                                   # 11,64 px per mm
H = int(round(H_MM * PX))                       # 1245
WIN = int(round(WIN_MM * PX))                   # 919
X0, Y0 = int(round(LATO_MM * PX)), int(round(SOPRA_MM * PX))   # 52, 76
X1, Y1 = X0 + WIN, Y0 + WIN
R_ANGOLO = int(round(2.5 * PX))                 # raggio degli angoli del cartoncino (2,5 mm)
R_FINESTRA = 8                                  # raggio degli angoli della finestra

# usura generale (0-1) e danni d'acqua (0-1): le ultime sono le più rovinate
USURA = {'P01': .12, 'P02': .18, 'P03': .22, 'P04': .40, 'P05': .45,
         'P06': .52, 'P07': .62, 'P08': .74, 'P09': .86, 'P10': 1.0,
         'P11': .30,   # P11, la pecora che brilla: chiusa nella cassaforte dell'infermeria, asciutta
         # P12-P16 (proposta del 25 ottobre notte): più rovinate quanto più il posto è bagnato
         'P12': .35, 'P13': .45, 'P14': .55, 'P15': .50, 'P16': .70}
ACQUA = {'P01': .0, 'P02': .05, 'P03': .1, 'P04': .35, 'P05': .3,
         'P06': .45, 'P07': .55, 'P08': .7, 'P09': .85, 'P10': 1.0, 'P11': .0,
         'P12': .2, 'P13': .4, 'P14': .5, 'P15': .3, 'P16': .8}
# angolo piegato: (angolo 0-3 in senso orario da in alto a sinistra, distanza della piega in px)
PIEGA = {'P01': None, 'P02': (2, 70), 'P03': None, 'P04': (1, 95), 'P05': None,
         'P06': (3, 80), 'P07': None, 'P08': (0, 120), 'P09': (2, 150), 'P10': (1, 110), 'P11': None,
         'P12': (1, 90), 'P13': None, 'P14': (3, 100), 'P15': (0, 80), 'P16': (2, 120)}
# alone di ruggine: P05 sul fondo della piscina, P06 nel tunnel, P10 e P12 sulla torre
RUGGINE = ('P05', 'P06', 'P10', 'P12')

LUM = np.array([0.299, 0.587, 0.114], np.float32)


# ------------------------------------------------------------------ strumenti
def fbm(rng, h, w, scala, ottave=4, pers=0.5):
    """Rumore frattale liscio in [0,1]: 'scala' è la dimensione delle macchie più grandi in px."""
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(ottave):
        s = max(scala / (2 ** o), 2)
        gh, gw = int(h / s) + 3, int(w / s) + 3
        g = rng.random((gh, gw)).astype(np.float32)
        big = cv2.resize(g, (int(gw * s), int(gh * s)), interpolation=cv2.INTER_CUBIC)
        oy = rng.integers(0, max(1, big.shape[0] - h))
        ox = rng.integers(0, max(1, big.shape[1] - w))
        out += amp * big[oy:oy + h, ox:ox + w]
        tot += amp
        amp *= pers
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mescola(img, col, a):
    a = a[..., None] if a.ndim == 2 else a
    return img * (1 - a) + np.asarray(col, np.float32) * a


def rettangolo_arrotondato(h, w, x0, y0, x1, y1, r):
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((x0, y0, x1 - 1, y1 - 1), radius=r, fill=255)
    return np.asarray(m, np.float32) / 255.0


def macchia(rng, h, w, cx, cy, r, morb=0.07, irregolare=0.9):
    """Macchia organica: cerchio deformato da rumore a più scale. Ritorna (maschera, valore)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    val = 1 - d + (fbm(rng, h, w, r * 0.9, 5) - 0.5) * irregolare
    return smooth(0, morb, val), val


def alone(rng, img, rug, cx, cy, r, forza, tinta=(0.80, 0.69, 0.50), orlo_col=(0.60, 0.47, 0.30)):
    """Alone d'acqua seccata sul cartoncino: velo appena visibile e orlo più scuro, spezzato."""
    h, w = img.shape[:2]
    m, val = macchia(rng, h, w, cx, cy, r)
    orlo = smooth(0, 0.035, val) - smooth(0.03, 0.10, val)
    orlo = cv2.GaussianBlur(np.clip(orlo, 0, 1), (0, 0), 1.0)
    orlo *= np.clip(fbm(rng, h, w, 40, 3) * 1.8 - 0.25, 0, 1)
    img = mescola(img, tinta, m * forza * 0.12 * (0.5 + fbm(rng, h, w, r * 0.5, 3)))
    img = mescola(img, orlo_col, np.clip(orlo * forza * 0.55, 0, 0.5))
    rug = rug + m * 0.05 + orlo * 0.18
    return img, rug


def bordi_bagnati(rng, h, w, portata):
    """Acqua entrata dai bordi: maschera (1 al bordo, sfuma verso l'interno) e fascia del fronte."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    # alcuni tratti di bordo restano asciutti, altri si bagnano molto
    tratti = np.clip(fbm(rng, h, w, 420, 2) * 2.2 - 0.5, 0, 1.4)
    fronte = portata * tratti * (0.6 + 0.8 * fbm(rng, h, w, 90, 4))
    val = (fronte - d) / (portata + 1) + (fbm(rng, h, w, 25, 3) - 0.5) * 0.12
    m = smooth(0.0, 0.18, val) * (fronte > 2)
    fascia = np.clip(smooth(-0.02, 0.05, val) - smooth(0.05, 0.16, val), 0, 1) * (fronte > 2)
    return m, fascia


def graffi(img, rug, rng, n, scuri=0.15, lungo=90):
    """Graffi sottili e quasi dritti, poco contrastati."""
    h, w = img.shape[:2]
    strato = np.zeros((h, w), np.float32)
    strato_s = np.zeros((h, w), np.float32)
    for _ in range(n):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ang = rng.uniform(0, np.pi)
        lung = rng.uniform(8, lungo) * (3 if rng.random() < 0.1 else 1)
        dx, dy = np.cos(ang) * lung, np.sin(ang) * lung
        al = rng.uniform(0.25, 0.8)
        dest = strato_s if rng.random() < scuri else strato
        cv2.line(dest, (int(x), int(y)), (int(x + dx), int(y + dy)), al, 1, cv2.LINE_AA)
    img = mescola(img, (0.93, 0.92, 0.88), np.clip(strato, 0, 1) * 0.35)
    img = mescola(img, (0.15, 0.13, 0.12), np.clip(strato_s, 0, 1) * 0.3)
    return img, rug + (strato + strato_s) * 0.3


def polvere(img, rng, n):
    """Granelli di polvere: puntini piccoli, chiari o scuri, morbidi."""
    h, w = img.shape[:2]
    chiari = np.zeros((h, w), np.float32)
    scuri = np.zeros((h, w), np.float32)
    for _ in range(n):
        x, y = int(rng.uniform(0, w)), int(rng.uniform(0, h))
        dest = chiari if rng.random() < 0.55 else scuri
        cv2.circle(dest, (x, y), 1 if rng.random() < 0.9 else 2, rng.uniform(0.3, 0.8), -1, cv2.LINE_AA)
    chiari = cv2.GaussianBlur(chiari, (0, 0), 0.6)
    scuri = cv2.GaussianBlur(scuri, (0, 0), 0.6)
    img = mescola(img, (0.92, 0.91, 0.88), np.clip(chiari, 0, 1) * 0.7)
    return mescola(img, (0.1, 0.09, 0.08), np.clip(scuri, 0, 1) * 0.7)


def gocce(img, rug, rng, n):
    """Gocce seccate sulla superficie lucida: dischetti appena più chiari con un orlo sottile."""
    h, w = img.shape[:2]
    acc, orli = np.zeros((h, w), np.float32), np.zeros((h, w), np.float32)
    for _ in range(n):
        x, y, r = rng.uniform(0, w), rng.uniform(0, h), rng.uniform(3, 16)
        disco = np.zeros((h, w), np.float32)
        cv2.ellipse(disco, (int(x), int(y)), (int(r), int(r * rng.uniform(0.7, 1.0))),
                    rng.uniform(0, 180), 0, 360, 1.0, -1, cv2.LINE_AA)
        acc = np.maximum(acc, disco)
        orli = np.maximum(orli, cv2.GaussianBlur(disco, (0, 0), 0.8) - cv2.GaussianBlur(
            cv2.erode(disco, np.ones((3, 3), np.uint8)), (0, 0), 0.8))
    img = mescola(img, (0.85, 0.85, 0.8), cv2.GaussianBlur(acc, (0, 0), 1.0) * 0.05)
    img = mescola(img, (0.92, 0.9, 0.85), np.clip(orli * 2, 0, 1) * 0.12)
    return img, rug + acc * 0.12 + orli * 0.2


# ------------------------------------------------------------------ la foto
def sviluppa(foto, nome, rng):
    """Foto quadrata -> immagine della finestra (WIN x WIN, float RGB 0-1) con il look Polaroid."""
    u, a = USURA[nome], ACQUA[nome]
    img = np.asarray(foto.convert('RGB').resize((WIN, WIN), Image.LANCZOS), np.float32) / 255.0
    h = w = WIN
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    # morbidezza dell'istantanea: un po' di sfocatura e un alone sulle luci
    img = cv2.GaussianBlur(img, (0, 0), 0.75)
    img = img + cv2.GaussianBlur(np.clip(img - 0.6, 0, 1), (0, 0), 9) * 0.35

    # colori: meno saturi, neri lattiginosi, luci compresse
    lum = img @ LUM
    img = lum[..., None] + (img - lum[..., None]) * (0.9 - 0.16 * u)
    nero, bianco = 0.05 + 0.03 * u, 0.94 - 0.04 * u
    img = nero + (bianco - nero) * np.clip(img, 0, 1) ** (1.0 + 0.08 * u)
    # viraggio: ombre ciano-verdi, luci color crema; invecchiando vira al caldo
    lum = img @ LUM
    ombre, luci = ((1 - lum) ** 2)[..., None], (lum ** 2)[..., None]
    img = img + ombre * np.array([-0.035, 0.012, 0.03]) + luci * np.array([0.04, 0.02, -0.045])
    img = img + u * np.array([0.03, -0.004, -0.04]) * (0.6 + 0.4 * luci)

    # flash: centro più chiaro, angoli scuri (centro un po' fuori asse, diverso per foto)
    cx, cy = w * rng.uniform(0.45, 0.55), h * rng.uniform(0.42, 0.52)
    r2 = ((xx - cx) ** 2 + (yy - cy) ** 2) / (0.5 * w) ** 2
    img = img * (1.08 - 0.30 * np.clip(r2, 0, 2.2) ** 1.2)[..., None]

    # grana (luminanza + un po' di colore)
    g = cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0), 0.6)
    gc = cv2.GaussianBlur(rng.normal(0, 1, (h, w, 3)).astype(np.float32), (0, 0), 1.2)
    img = img + g[..., None] * (0.03 + 0.02 * u) + gc * 0.012

    # sviluppo: orlo scuro e caldo lungo i bordi, a volte "dita" chiare di reagente dall'alto
    d = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    img = mescola(img, (0.30, 0.20, 0.12), np.exp(-d / (3.0 + 4 * fbm(rng, h, w, 120, 2))) * 0.45)
    if rng.random() < 0.35 + 0.5 * u:
        dita = np.zeros((h, w), np.float32)
        for _ in range(rng.integers(2, 7)):
            x, lung, larg = rng.uniform(0, w), rng.uniform(8, 25 + 50 * u), rng.uniform(4, 18)
            dita += np.exp(-((xx - x) / larg) ** 2) * np.clip(1 - yy / lung, 0, 1)
        img = mescola(img, (0.93, 0.88, 0.72), np.clip(dita, 0, 1) * 0.7)

    rug = np.full((h, w), 0.16, np.float32)
    if a > 0:
        # acqua dai bordi: colori che sbiadiscono e colano, con il fronte appena più scuro
        m, fascia = bordi_bagnati(rng, h, w, 18 + 105 * a)
        mosso = cv2.GaussianBlur(img, (0, 0), 2.0)
        tinta = [np.array([1.02, 0.98, 0.82]), np.array([0.86, 0.96, 1.04]),
                 np.array([1.05, 0.88, 1.0])][rng.integers(0, 3)]
        sbiadito = ((mosso @ LUM)[..., None] * 0.35 + mosso * 0.65) * tinta * (1 - 0.1 * a) + 0.08 + 0.10 * a
        img = mescola(img, sbiadito, m * (0.45 + 0.35 * a) * (0.7 + 0.6 * fbm(rng, h, w, 60, 3)))
        img = mescola(img, (0.40, 0.30, 0.20), fascia * (0.12 + 0.12 * a))
        rug += m * 0.15 + fascia * 0.15
        img, rug = gocce(img, rug, rng, int(2 + 14 * a))
        if a > 0.6:
            # emulsione che si scolla vicino a un bordo: velo lattiginoso e bollicine
            mb, _ = bordi_bagnati(rng, h, w, 30 + 60 * a)
            img = mescola(img, (0.82, 0.80, 0.76), mb * 0.28 * fbm(rng, h, w, 20, 3))
            ys, xs = np.nonzero(mb > 0.6)
            bol = np.zeros((h, w), np.float32)
            for _ in range(int(10 + 30 * a) if len(xs) else 0):
                i = rng.integers(0, len(xs))
                cv2.circle(bol, (int(xs[i]), int(ys[i])), int(rng.uniform(2, 7)), rng.uniform(0.4, 1), -1, cv2.LINE_AA)
            bol = cv2.GaussianBlur(bol, (0, 0), 1.2)
            img = mescola(img, (0.88, 0.86, 0.82), bol * 0.3)
            rug += mb * 0.2 + bol * 0.3
    # muffa: piccole colonie scure e sfumate
    if u > 0.75:
        muffa = np.zeros((h, w), np.float32)
        for _ in range(int(1 + 3 * u)):
            gx, gy = rng.uniform(0, w), rng.choice([rng.uniform(0, 160), rng.uniform(h - 160, h)])
            for _ in range(rng.integers(8, 30)):
                x, y = gx + rng.normal(0, 18), gy + rng.normal(0, 18)
                cv2.circle(muffa, (int(x), int(y)), int(rng.uniform(1, 3)), rng.uniform(0.4, 1), -1, cv2.LINE_AA)
        muffa = cv2.GaussianBlur(muffa, (0, 0), 1.0)
        img = mescola(img, (0.12, 0.14, 0.09), np.clip(muffa, 0, 1) * 0.6)
        rug += muffa * 0.3
    img, rug = graffi(img, rug, rng, int(4 + 40 * u))
    img = polvere(img, rng, int(15 + 90 * u))
    return np.clip(img, 0, 1), np.clip(rug, 0, 1)


# ------------------------------------------------------------------ il cartoncino intero
def cornice(nome, finestra, rug_foto, rng):
    u, a = USURA[nome], ACQUA[nome]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # bianco del bordo: un po' crema, ingiallisce con l'età
    base = np.array([0.955, 0.950, 0.925]) * (1 - 0.5 * u) + np.array([0.905, 0.865, 0.765]) * 0.5 * u
    nz = fbm(rng, H, W, 300, 4)
    img = np.ones((H, W, 3), np.float32) * base
    img = img * (0.985 + 0.03 * nz[..., None]) * (0.99 + 0.02 * fbm(rng, H, W, 6, 2)[..., None])
    rug = np.full((H, W), 0.42, np.float32) + (nz - 0.5) * 0.08

    # la foto nella finestra, con un filo d'ombra del bordo sopra la foto
    mw = rettangolo_arrotondato(H, W, X0, Y0, X1, Y1, R_FINESTRA)
    full = np.zeros((H, W, 3), np.float32)
    full[Y0:Y1, X0:X1] = finestra
    rf = np.zeros((H, W), np.float32)
    rf[Y0:Y1, X0:X1] = rug_foto
    img = img * (1 - mw[..., None]) + full * mw[..., None]
    rug = rug * (1 - mw) + rf * mw
    filo = cv2.GaussianBlur(mw, (0, 0), 1.2) - cv2.GaussianBlur(
        cv2.erode(mw, np.ones((3, 3), np.uint8)), (0, 0), 1.2)
    img = mescola(img, (0.25, 0.22, 0.2), np.clip(filo * 2, 0, 1) * 0.3)

    # sporco verso i bordi del cartoncino, di più negli angoli
    d = np.minimum.reduce([xx, yy, W - 1 - xx, H - 1 - yy])
    angoli = np.exp(-(np.minimum(xx, W - 1 - xx) + np.minimum(yy, H - 1 - yy)) / 90.0)
    sporco = np.clip(np.exp(-d / (10 + 14 * u)) * (0.6 + 0.8 * fbm(rng, H, W, 60, 3)) + angoli * 0.6, 0, 1)
    sporco *= (0.16 + 0.5 * u)
    img = mescola(img, (0.42, 0.38, 0.31), sporco * (1 - mw * 0.6))
    rug += sporco * 0.25

    # angoli consumati: lo strato bianco si sfrangia e diventa grigio chiaro
    for (cx, cy) in ((0, 0), (W, 0), (W, H), (0, H)):
        m, _ = macchia(rng, H, W, cx, cy, rng.uniform(14, 24 + 30 * u), 0.15, 1.2)
        img = mescola(img, (0.78, 0.76, 0.72), m * 0.5)
        rug += m * 0.2

    # aloni d'acqua sul cartoncino, soprattutto sul bordo in basso
    for _ in range(int(round(a * 4 + (1 if u > 0.3 else 0)))):
        if rng.random() < 0.65:
            px, py = rng.uniform(0, W), rng.uniform(Y1 + 30, H + 40)
        else:
            px, py = rng.choice([rng.uniform(-40, X0), rng.uniform(X1, W + 40)]), rng.uniform(0, H)
        img, rug = alone(rng, img, rug, px, py, rng.uniform(40, 70 + 110 * a), 0.55 + 0.45 * a)

    # ruggine (dove la foto è rimasta appoggiata al metallo): alone granuloso lungo un bordo
    if nome in RUGGINE:
        m, _ = macchia(rng, H, W, rng.uniform(0, W), rng.choice([H + 20, -20]), rng.uniform(70, 120), 0.2, 1.1)
        gr = np.clip(fbm(rng, H, W, 3, 2) * 1.6 - 0.3, 0, 1)
        img = mescola(img, (0.55, 0.34, 0.18), m * (0.08 + 0.18 * gr) * (1 - mw * 0.5))
        rug += m * 0.25

    # sale: crosticine biancastre e ruvide lungo i bordi (si vedono più nella rugosità)
    if a > 0.3:
        sale = np.clip(fbm(rng, H, W, 10, 2) * 2.2 - 1.1, 0, 1) * np.exp(-d / (12 + 20 * a))
        sale *= np.clip(fbm(rng, H, W, 200, 2) * 2 - 0.6, 0, 1)
        img = mescola(img, (0.97, 0.97, 0.95), sale * 0.5)
        rug += sale * 0.6

    # angolo piegato: la piega è una riga chiara con l'ombra accanto, la punta è più sciupata
    if PIEGA[nome]:
        k, dist = PIEGA[nome]
        cx, cy = [(0, 0), (W, 0), (W, H), (0, H)][k]
        sx, sy = (1 if cx == 0 else -1), (1 if cy == 0 else -1)
        dd = (sx * (xx - cx) + sy * (yy - cy) - dist) / np.sqrt(2)
        dd = dd + (fbm(rng, H, W, 30, 2) - 0.5) * 3
        luce = np.exp(-((dd + 1.2) / 1.0) ** 2)
        ombra = np.exp(-((dd - 1.8) / 1.6) ** 2)
        punta = (dd < 0).astype(np.float32)
        img = mescola(img, (1.0, 1.0, 0.98), luce * 0.45)
        img = mescola(img, (0.2, 0.18, 0.16), ombra * 0.3)
        img = img * (1 - punta[..., None] * 0.05)
        rug += (luce + ombra) * 0.3 + punta * 0.08

    # graffi e polvere anche sul bordo, e un po' di grana della plastica
    img, rug = graffi(img, rug, rng, int(2 + 14 * u), scuri=0.5, lungo=60)
    img = polvere(img, rng, int(10 + 60 * u))
    img = img + cv2.GaussianBlur(rng.normal(0, 1, (H, W)).astype(np.float32), (0, 0), 0.7)[..., None] * 0.008

    # fuori dagli angoli arrotondati ripeto il colore del bordo (la geometria li taglia)
    mc = rettangolo_arrotondato(H, W, 0, 0, W, H, R_ANGOLO)
    img = img * mc[..., None] + base * (1 - mc[..., None])
    return np.clip(img, 0, 1), np.clip(rug, 0.05, 1)


def normale():
    """Normal map comune: finestra della foto incassata di un soffio, bordo con grana di plastica."""
    rng = np.random.default_rng(7)
    mw = rettangolo_arrotondato(H, W, X0, Y0, X1, Y1, R_FINESTRA)
    alt = 1.0 - cv2.GaussianBlur(mw, (0, 0), 1.6)          # bordo alto, foto bassa
    alt = alt + (fbm(rng, H, W, 18, 3) - 0.5) * 0.08 * (1 - mw)
    alt = alt + (fbm(rng, H, W, 140, 3) - 0.5) * 0.25      # ondulazione leggera del cartoncino
    gx = cv2.Sobel(alt, cv2.CV_32F, 1, 0, ksize=3) / 8.0
    gy = cv2.Sobel(alt, cv2.CV_32F, 0, 1, ksize=3) / 8.0
    forza = 2.2
    n = np.stack([-gx * forza, gy * forza, np.ones_like(gx)], -1)   # OpenGL: Y verso l'alto
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)


def retro():
    """Retro comune: plastica nera opaca, consumata, con aloni e sale. Niente scritte."""
    rng = np.random.default_rng(11)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nz = fbm(rng, H, W, 250, 4)
    img = np.ones((H, W, 3), np.float32) * np.array([0.055, 0.055, 0.06]) * (0.85 + 0.3 * nz[..., None])
    rug = np.full((H, W), 0.55, np.float32) + (nz - 0.5) * 0.15
    # la striscia in basso, dove c'era la sacca dei reagenti, è un po' più lucida
    sacca = np.clip((yy - (Y1 + 20)) / 30, 0, 1)
    rug -= sacca * 0.12
    img *= (1 + sacca[..., None] * 0.15)
    d = np.minimum.reduce([xx, yy, W - 1 - xx, H - 1 - yy])
    img = mescola(img, (0.25, 0.23, 0.2), np.exp(-d / 18) * fbm(rng, H, W, 50, 3) * 0.5)
    for _ in range(5):
        img, rug = alone(rng, img, rug, rng.uniform(0, W), rng.uniform(0, H), rng.uniform(60, 200), 0.9,
                         tinta=(0.22, 0.22, 0.21), orlo_col=(0.36, 0.35, 0.33))
    img, rug = graffi(img, rug, rng, 60, scuri=0.0, lungo=120)
    img = polvere(img, rng, 150)
    sale = np.clip(fbm(rng, H, W, 10, 2) * 2.2 - 1.1, 0, 1) * np.exp(-d / 30)
    img = mescola(img, (0.75, 0.75, 0.73), sale * 0.5)
    rug += sale * 0.4
    return np.clip(img, 0, 1), np.clip(rug, 0.05, 1)


def salva_rgb(a, path, q=93):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, quality=q, subsampling=0)


def salva_grigio(a, path, q=92):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), 'L').save(path, quality=q)


# ------------------------------------------------------------------ tavola riassuntiva
def tavola(nomi):
    """Due righe da cinque, etichette grandi, pensata per lo schermo del telefono."""
    cw = 360
    ch = int(round(cw * H / W))
    marg, et = 40, 92
    TW, TH = 5 * cw + 6 * marg, 2 * (ch + et) + 3 * marg
    rng = np.random.default_rng(3)
    sfondo = np.zeros((TH, TW, 3), np.float32) + np.array([0.075, 0.07, 0.075])
    sfondo *= (0.85 + 0.3 * fbm(rng, TH, TW, 400, 3))[..., None]
    tav = Image.fromarray((sfondo * 255).astype(np.uint8))
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 70)
    d = ImageDraw.Draw(tav)
    mask0 = Image.new('L', (W, H), 0)
    ImageDraw.Draw(mask0).rounded_rectangle((0, 0, W - 1, H - 1), radius=R_ANGOLO, fill=255)
    for i, n in enumerate(nomi):
        r, c = divmod(i, 5)
        x, y = marg + c * (cw + marg), marg + r * (ch + et + marg)
        rgba = Image.open(os.path.join(TEX, f'{n}.jpg')).convert('RGB').resize((cw, ch), Image.LANCZOS)
        rgba.putalpha(mask0.resize((cw, ch), Image.LANCZOS))
        rgba = rgba.rotate(rng.uniform(-2.5, 2.5), resample=Image.BICUBIC, expand=True)
        ombra = Image.new('RGBA', rgba.size, (0, 0, 0, 0))
        ombra.putalpha(rgba.getchannel('A').point(lambda v: int(v * 0.7)))
        ombra = ombra.filter(ImageFilter.GaussianBlur(10))
        ox, oy = x + (cw - rgba.size[0]) // 2, y + et + (ch - rgba.size[1]) // 2
        tav.paste(ombra, (ox + 8, oy + 12), ombra)
        tav.paste(rgba, (ox, oy), rgba)
        d.text((x + cw // 2, y + et // 2 - 4), 'P' + str(int(n[1:])), font=font, fill=(250, 245, 235), anchor='mm')
    os.makedirs(os.path.dirname(TAVOLA), exist_ok=True)
    tav.save(TAVOLA, quality=90)
    print('tavola', TAVOLA, tav.size)


def main(nomi):
    os.makedirs(TEX, exist_ok=True)
    for n in nomi:
        rng = np.random.default_rng(1000 + int(n[1:]))
        fin, rug_f = sviluppa(Image.open(os.path.join(FOTO, f'{n}.jpg')), n, rng)
        img, rug = cornice(n, fin, rug_f, rng)
        salva_rgb(img, os.path.join(TEX, f'{n}.jpg'))
        salva_grigio(rug, os.path.join(TEX, f'{n}_rugosita.jpg'))
        print(n, 'ok', img.shape)
    if len(nomi) == 10 or not os.path.exists(os.path.join(TEX, 'normale.png')):
        Image.fromarray(normale()).save(os.path.join(TEX, 'normale.png'), optimize=True)
        r, rr = retro()
        salva_rgb(r, os.path.join(TEX, 'retro.jpg'))
        salva_grigio(rr, os.path.join(TEX, 'retro_rugosita.jpg'))
        print('normale e retro ok')
    tavola([f'P{i:02d}' for i in range(1, 11)])


if __name__ == '__main__':
    main(sys.argv[1:] or [f'P{i:02d}' for i in range(1, 11)])
