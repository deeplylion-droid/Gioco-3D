"""JILLY JUBILEE nel gioco: targa, manifesto e insegna con le lampade, stile B, molto invecchiati.

Scelte dell'utente del 19 ottobre (docs/riscontri/2026-10-19_scelte.md): logo stile B "ma molto più
invecchiati"; targa sì; manifesto sì, con "LIVE SHOW" e gli orari; insegna sì, con le sue due lampade a
collo d'oca. Le forme sono quelle delle proposte (jilly_oggetti.py); qui cambia l'invecchiamento, molto
più forte: smalto e vernice saltati a chiazze fino alla lamiera arrugginita, colature di ruggine dalle viti
e dai bordi, crosta di sale in basso, vernice cotta e screpolata; carta del manifesto ingiallita e
sbiadita, macchie d'acqua con l'alone, muffa, inchiostro consumato sulle pieghe, strappi più grandi.
Si aggiungono le mappe delle normali (rilievo delle scaglie, delle crepe e della ruggine) e la ruggine
vera sulla cornice e sulle lampade.

Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python \
        assets_src/mascotte/jilly_gioco.py [solo_texture | riusa_texture] [targa] [manifesto] [insegna]
Servono le grafiche originali in gen/jilly/ (logo_b_gpt_0.png, manifesto_b_gpt_0.png: si riscaricano
da Meshy con i task_id di meshy_log.json). Escono in godot/assets/models/mascotte/jilly/:
targa.glb, manifesto.glb, insegna.glb (con le lampade e gli empty luce_sx / luce_dx).
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import jilly_oggetti as J  # noqa: E402  (solo funzioni: il giro delle proposte è sotto __main__)
from jilly_oggetti import rumore, ritaglia_logo, su_fondo, bordo  # noqa: E402

TEX = os.path.join(QUI, 'jilly_tex', 'gioco')
OUT = os.path.join(J.REPO, 'godot', 'assets', 'models', 'mascotte', 'jilly')
os.makedirs(TEX, exist_ok=True); os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------- strati di invecchiamento
def f32(im):
    return np.asarray(im, np.float32)


def img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def sfoca(m, r):
    return ndimage.gaussian_filter(m.astype(np.float32), r)


def rumore_deformato(w, h, scala, seme, ottave=5, forza=0.08):
    """Rumore con il dominio deformato: chiazze dal contorno frastagliato, non tondeggiante."""
    dx = rumore(w, h, 3, 3, seme + 101) - 0.5
    dy = rumore(w, h, 3, 3, seme + 102) - 0.5
    n = rumore(w, h, scala, ottave, seme)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return ndimage.map_coordinates(n, [np.clip(yy + dy * h * forza, 0, h - 1),
                                       np.clip(xx + dx * w * forza, 0, w - 1)], order=1)


def ruggine(w, h, seme):
    """Colore della lamiera arrugginita: bruno scuro, arancio e quasi nero a chiazze, con puntini."""
    n1 = rumore(w, h, 8, 5, seme)
    n2 = rumore(w, h, 30, 3, seme + 1)
    scuro = np.array([52, 34, 26], np.float32)
    bruno = np.array([104, 56, 30], np.float32)
    arancio = np.array([160, 82, 34], np.float32)
    t = np.clip((n1 - 0.3) * 2.2, 0, 1)[..., None]
    a = scuro * (1 - t) + bruno * t
    o = np.clip((n2 - 0.55) * 4, 0, 1)[..., None]
    a = a * (1 - 0.6 * o) + arancio * 0.6 * o
    return a, n1 * 0.6 + n2 * 0.4


def scaglie(w, h, seme, copertura, scala=10, pesi=None):
    """Maschera della vernice saltata (1 = saltata). [pesi] alza o abbassa la probabilità per zona."""
    n = rumore_deformato(w, h, scala, seme)
    fine = rumore(w, h, scala * 4, 3, seme + 7)
    n = n * 0.8 + fine * 0.2
    if pesi is not None:
        n = n + (pesi - 0.5) * 0.35
    soglia = np.quantile(n, 1 - copertura)
    m = (n > soglia).astype(np.float32)
    # schegge piccole sparse
    r = np.random.default_rng(seme + 9)
    punti = rumore(w, h, scala * 9, 2, seme + 8)
    m = np.maximum(m, (punti > np.quantile(punti, 0.997)).astype(np.float32) * (r.random((h, w)) > 0.5))
    m = ndimage.binary_opening(m > 0.5, iterations=1)
    # niente schegge isolate più piccole di qualche pixel (sembravano bollicine)
    lab, n = ndimage.label(m)
    if n:
        aree = ndimage.sum(m, lab, range(1, n + 1))
        m = np.isin(lab, np.where(aree >= w * h * 0.00002)[0] + 1)
    return m.astype(np.float32)


def craquelure(w, h, seme, celle=900, larghezza=1.6):
    """Vernice cotta e screpolata: rete di crepe sottili (bordi di un diagramma di Voronoi deformato)."""
    r = np.random.default_rng(seme)
    pts = r.random((celle, 2)) * [w, h]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = (rumore(w, h, 6, 3, seme + 1) - 0.5) * w * 0.02
    dy = (rumore(w, h, 6, 3, seme + 2) - 0.5) * w * 0.02
    q = np.stack([(xx + dx).ravel(), (yy + dy).ravel()], 1)
    d, _ = cKDTree(pts).query(q, k=2)
    bordo_c = (d[:, 1] - d[:, 0]).reshape(h, w)
    return np.clip(1 - bordo_c / larghezza, 0, 1)


def colature(w, h, sorgenti, seme, lunghezza=(0.15, 0.5), larghezza=(3, 10), forza=1.0):
    """Colature verso il basso (in immagine: y che cresce) da una lista di punti (x, y) in pixel."""
    col = np.zeros((h, w), np.float32)
    r = np.random.default_rng(seme)
    for (x0, y0) in sorgenti:
        for _ in range(r.integers(2, 5)):
            x = int(x0 + r.normal(0, larghezza[1]))
            lw = int(r.integers(larghezza[0], larghezza[1] + 1))
            ln = int(h * r.uniform(*lunghezza))
            y1 = min(h, int(y0) + ln)
            if y1 <= y0 or x < 0 or x >= w:
                continue
            prof = np.linspace(1, 0, y1 - int(y0)) ** 0.7 * r.uniform(0.5, 1.0)
            onda = (np.sin(np.linspace(0, r.uniform(2, 6), y1 - int(y0)) + r.uniform(0, 6)) * lw * 0.6).astype(int)
            for k, yy in enumerate(range(int(y0), y1)):
                xa = np.clip(x + onda[k], 0, w - 1)
                col[yy, max(0, xa - lw // 2):min(w, xa + lw // 2 + 1)] = np.maximum(
                    col[yy, max(0, xa - lw // 2):min(w, xa + lw // 2 + 1)], prof[k])
    return np.clip(sfoca(col, max(1.0, w / 900)) * forza, 0, 1)


def sale(w, h, seme, dal_basso=0.35):
    """Crosta bianca di sale e calcare: più fitta in basso, a chiazze."""
    yy = np.linspace(0, 1, h)[:, None]
    grad = np.clip((yy - (1 - dal_basso)) / dal_basso, 0, 1) ** 1.5
    n = rumore_deformato(w, h, 14, seme) * 0.6 + rumore(w, h, 70, 2, seme + 1) * 0.4
    return np.clip((n - 0.55) * 6 + grad * 1.2 - 0.5, 0, 1) * np.clip(grad * 1.6, 0, 1) * 0.8


def normali(alt, forza):
    """Mappa delle normali (convenzione OpenGL, quella del glTF) da una mappa d'altezza 0-1."""
    gx = ndimage.sobel(alt, 1) * forza
    gy = ndimage.sobel(alt, 0) * forza
    n = np.stack([-gx, gy, np.ones_like(alt)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return img((n * 0.5 + 0.5) * 255)


def salva(nome, colore, rug=None, nor=None):
    out = {}
    out['col'] = os.path.join(TEX, f'{nome}_col.jpg'); img(colore).save(out['col'], quality=92)
    if rug is not None:
        out['rug'] = os.path.join(TEX, f'{nome}_rug.jpg'); img(rug * 255).convert('L').save(out['rug'], quality=92)
    if nor is not None:
        out['nor'] = os.path.join(TEX, f'{nome}_nor.png'); nor.save(out['nor'])
    return out


def maschera_logo(im):
    """Dove c'è il disegno del logo (non il fondo pieno): lì la vernice salta un po' meno, così il nome
    resta leggibile."""
    a = f32(im)
    fondo = np.median(a.reshape(-1, 3), 0)
    d = np.abs(a - fondo).sum(-1)
    return sfoca((d > 60).astype(np.float32), 6)


def pesi_bordi(w, h, raggio):
    """Più scaglie vicino ai bordi (urti, acqua che ristagna)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy])
    return np.clip(1 - d / raggio, 0, 1)


def pesi_punti(w, h, punti, raggio):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    p = np.zeros((h, w), np.float32)
    for x, y in punti:
        p = np.maximum(p, np.clip(1 - np.hypot(xx - x, yy - y) / raggio, 0, 1))
    return p


def vernice_vecchia(im, seme, copertura, sotto_rgb, viti=(), sorgenti_colature=(), sbiadire=0.6,
                    gesso=(205, 202, 192), crepe=True, scala_scaglie=10):
    """Vernice o smalto su lamiera, molto invecchiati. Restituisce colore, rugosità e altezza."""
    w, h = im.size
    a = f32(im)
    logo = maschera_logo(im)
    # 1. sbiadita e gessosa (la vernice ossidata diventa opaca e chiara), poco meno sul disegno
    g = a.mean(-1, keepdims=True)
    a = a * (1 - 0.55 * sbiadire) + g * 0.55 * sbiadire
    a = a * (1 - 0.38 * sbiadire) + np.array(gesso, np.float32) * 0.38 * sbiadire
    # 2. sporco grasso e scuro sui bordi e a chiazze
    sporco = np.clip(pesi_bordi(w, h, w * 0.12) * 0.7 + (rumore(w, h, 5, 4, seme + 3) - 0.5) * 0.8, 0, 1)
    a = a * (1 - 0.35 * sporco[..., None]) + np.array([60, 50, 38]) * 0.35 * sporco[..., None]
    # 3. crepe della vernice cotta
    alt = np.ones((h, w), np.float32)
    if crepe:
        cr = craquelure(w, h, seme + 4, celle=int(w * h / 3500))
        cr *= np.clip(rumore(w, h, 3, 3, seme + 5) * 1.6 - 0.3, 0, 1)      # solo in alcune zone
        a = a * (1 - 0.5 * cr[..., None]) + np.array([40, 32, 26]) * 0.5 * cr[..., None]
        alt -= 0.35 * cr
    # 4. scaglie: vernice saltata fino alla lamiera arrugginita, con un filo di fondo chiaro sul bordo
    pesi = 0.5 + 0.45 * pesi_bordi(w, h, w * 0.08) + 0.5 * pesi_punti(w, h, viti, w * 0.05) - 0.25 * logo
    m = scaglie(w, h, seme + 6, copertura, scala_scaglie, pesi)
    rug_rgb, rug_n = ruggine(w, h, seme + 7)
    fondo_c = np.clip((sfoca(m, 1.2) > 0.12).astype(np.float32) - m, 0, 1)   # filo di fondo attorno alla scaglia
    fondo_c *= np.clip(rumore(w, h, 30, 2, seme + 13) * 2 - 0.6, 0, 1)
    a = a * (1 - fondo_c[..., None] * 0.6) + np.array(sotto_rgb, np.float32) * fondo_c[..., None] * 0.6
    a = a * (1 - m[..., None]) + rug_rgb * m[..., None]
    alone = np.clip(sfoca(m, w / 260) * 1.6 - m, 0, 1)                 # la ruggine si allarga sotto la vernice
    a = a * (1 - 0.45 * alone[..., None]) + np.array([120, 66, 32]) * 0.45 * alone[..., None]
    alt = alt * (1 - m) + (0.25 + 0.25 * rug_n) * m
    # 5. colature di ruggine dalle viti, dai bordi e dalle scaglie più grandi
    lab, n = ndimage.label(m)
    grandi = []
    if n:
        aree = ndimage.sum(m, lab, range(1, n + 1))
        cen = ndimage.center_of_mass(m, lab, range(1, n + 1))
        r = np.random.default_rng(seme + 8)
        for ar, (cy, cx) in zip(aree, cen):
            if ar > w * h * 0.0006 and r.random() < 0.5:
                grandi.append((cx, cy))
    col = colature(w, h, list(viti) + list(sorgenti_colature) + grandi, seme + 9,
                   larghezza=(max(2, w // 500), max(4, w // 160)))
    a = a * (1 - 0.6 * col[..., None]) + np.array([118, 58, 26]) * 0.6 * col[..., None]
    # 6. sale e calcare in basso
    sl = sale(w, h, seme + 10)
    a = a * (1 - 0.55 * sl[..., None]) + np.array([214, 210, 198]) * 0.55 * sl[..., None]
    alt += 0.12 * sl
    # 7. grana fine
    a *= (0.9 + 0.1 * rumore(w, h, 60, 2, seme + 11))[..., None]
    rug = np.clip(0.55 + 0.35 * m + 0.25 * sl + 0.15 * sporco - 0.1 * (1 - m) + 0.08 * rumore(w, h, 25, 3, seme + 12), 0.3, 1)
    return a, rug, alt, m


def carta_vecchia(im, seme):
    """Manifesto di carta: ingiallito, sbiadito (spariscono prima i rossi e i gialli), macchie d'acqua con
    l'alone, muffa, inchiostro consumato, pieghe sporche."""
    w, h = im.size
    a = f32(im)
    # sbiadito: il colore cala molto, i rossi più del blu (ciano che resta), contrasto basso
    g = a.mean(-1, keepdims=True)
    a = a * 0.45 + g * 0.55
    a *= np.array([0.86, 0.93, 1.0], np.float32)
    carta = np.array([222, 200, 150], np.float32)
    a = a * 0.6 + carta * 0.4
    # inchiostro consumato: chiazze dove resta quasi solo la carta
    cons = np.clip((rumore_deformato(w, h, 9, seme) - 0.58) * 4, 0, 1)
    a = a * (1 - 0.7 * cons[..., None]) + carta * 0.7 * cons[..., None]
    # pieghe (in quattro): righe chiare consumate con un filo di sporco
    for yy in (h // 2,):
        fascia = np.exp(-((np.arange(h) - yy) / 4.0) ** 2)[:, None]
        a = a * (1 - 0.45 * fascia[..., None]) + 245 * 0.45 * fascia[..., None]
        a[yy - 1:yy + 1] *= 0.8
    for xx in (w // 2,):
        fascia = np.exp(-((np.arange(w) - xx) / 3.0) ** 2)[None, :]
        a = a * (1 - 0.4 * fascia[..., None]) + 245 * 0.4 * fascia[..., None]
        a[:, xx - 1:xx + 1] *= 0.82
    # macchie d'acqua: dall'alto (colature lunghe) e dal basso (umidità che risale), con l'alone scuro
    alt = np.zeros((h, w), np.float32)
    yy = np.linspace(0, 1, h)[:, None]
    for k, (base, quanto) in enumerate(((rumore_deformato(w, h, 4, seme + 1) + (yy - 0.55) * 0.9, 0.62),
                                        (rumore_deformato(w, h, 5, seme + 2) + (yy - 0.5) * 0.4, 0.78))):
        dentro = (base > quanto).astype(np.float32)
        dentro = sfoca(dentro, 1.5)
        alone = np.clip(dentro * (1 - dentro) * 4, 0, 1) ** 1.5
        a = a * (1 - 0.32 * dentro[..., None]) + np.array([185, 140, 75]) * 0.32 * dentro[..., None]
        a = a * (1 - 0.6 * alone[..., None]) + np.array([110, 75, 35]) * 0.6 * alone[..., None]
        alt += 0.4 * dentro
    col = colature(w, h, [(x, 0) for x in np.random.default_rng(seme + 3).uniform(0, w, 9)], seme + 4,
                   lunghezza=(0.2, 0.6), larghezza=(3, 9))
    a = a * (1 - 0.45 * col[..., None]) + np.array([120, 92, 52]) * 0.45 * col[..., None]
    # muffa: puntini neri e grigio-verdi a grappoli, più fitti in basso e negli angoli
    r = np.random.default_rng(seme + 5)
    zona = np.clip((rumore_deformato(w, h, 5, seme + 6) + yy * 0.35 + pesi_bordi(w, h, w * 0.2) * 0.3 - 0.85) * 4, 0, 1)
    punti = (r.random((h, w)) < 0.012 * zona ** 2).astype(np.float32)
    punti = np.maximum(sfoca(punti, 1.1) * 5, 0)
    alone_m = sfoca(punti, 6) * 3
    a = a * (1 - np.clip(alone_m, 0, 0.4)[..., None]) + np.array([90, 96, 70]) * np.clip(alone_m, 0, 0.4)[..., None]
    a = a * (1 - np.clip(punti, 0, 0.9)[..., None]) + np.array([30, 32, 26]) * np.clip(punti, 0, 0.9)[..., None]
    # macchie di ruggine della carta (foxing): puntini bruni sfumati
    fx = (r.random((h, w)) < 0.00025).astype(np.float32)
    fx = np.clip(sfoca(fx, 4) * 60, 0, 1) * np.clip(rumore(w, h, 4, 3, seme + 9) * 2 - 0.4, 0, 1)
    a = a * (1 - 0.5 * fx[..., None]) + np.array([150, 100, 50]) * 0.5 * fx[..., None]
    # graffi e grana della carta
    a *= (0.88 + 0.12 * rumore(w, h, 70, 2, seme + 7))[..., None]
    a = a * (1 - 0.25 * pesi_bordi(w, h, w * 0.06)[..., None]) + np.array([90, 72, 45]) * 0.25 * pesi_bordi(w, h, w * 0.06)[..., None]
    alt += 0.3 * rumore(w, h, 40, 3, seme + 8)
    return a, alt


# ---------------------------------------------------------------- texture dei tre oggetti
GEN = os.path.join(QUI, 'gen', 'jilly')


def tex_targa():
    W, H = 1400, 780
    logo = ritaglia_logo(os.path.join(GEN, 'logo_b_gpt_0.png'))
    im = su_fondo(logo, W, H, (24, 38, 82), 0.09)
    im = bordo(im, (200, 160, 60), 14, 60)
    viti = [((0.5 + x / 0.70) * W, (0.5 - z / 0.39) * H) for x, z in
            ((-0.315, 0.155), (0.315, 0.155), (-0.315, -0.155), (0.315, -0.155))]
    a, rug, alt, m = vernice_vecchia(im, 112, 0.10, (225, 222, 212), viti=viti,
                                     sorgenti_colature=[(W * 0.5, 0)], sbiadire=0.55, gesso=(150, 156, 168),
                                     crepe=False, scala_scaglie=9)
    # lo smalto è lucido dove resta, la ruggine opaca
    rug = np.clip(0.28 + 0.6 * m + (rug - 0.55) * 0.5, 0.2, 1)
    return salva('targa', a, rug, normali(sfoca(alt, 1.2), 3.0))


def tex_insegna():
    W, H = 2048, 1138
    logo = ritaglia_logo(os.path.join(GEN, 'logo_b_gpt_0.png'))
    im = su_fondo(logo, W, H, (246, 238, 214), 0.07)
    im = bordo(im, (24, 38, 82), 26, 0)
    a, rug, alt, m = vernice_vecchia(im, 142, 0.15, (190, 186, 172),
                                     sorgenti_colature=[(x, 0) for x in np.linspace(60, W - 60, 9)],
                                     sbiadire=0.7, gesso=(200, 196, 182), crepe=True, scala_scaglie=8)
    return salva('insegna', a, rug, normali(sfoca(alt, 1.0), 4.0))


def tex_manifesto():
    src = Image.open(os.path.join(GEN, 'manifesto_b_gpt_0.png')).convert('RGB')
    W, H = 1280, 1920
    im = src.resize((W, H), Image.LANCZOS)
    a, alt = carta_vecchia(im, 222)
    return salva('manifesto', a, None, normali(sfoca(alt, 2.0), 2.5))


def tex_ruggine(nome, seme, w=1024, h=1024, vernice=None, copertura=0.5):
    """Ruggine ripetibile per la cornice, le staffe e le lampade (con un resto di vernice se [vernice])."""
    rg, n = ruggine(w, h, seme)
    a = rg
    alt = 0.4 + 0.4 * n
    if vernice is not None:
        m = scaglie(w, h, seme + 1, copertura, 6)
        v = np.array(vernice, np.float32) * (0.85 + 0.3 * rumore(w, h, 20, 3, seme + 2))[..., None]
        a = v * (1 - m[..., None]) + rg * m[..., None]
        alt = (1 - m) + alt * m * 0.6
    a *= (0.85 + 0.15 * rumore(w, h, 50, 2, seme + 3))[..., None]
    rug = np.clip(0.75 + 0.2 * n, 0, 1)
    return salva(nome, a, rug, normali(sfoca(alt, 1.0), 3.0))


def tutte_le_texture():
    return dict(targa=tex_targa(), insegna=tex_insegna(), manifesto=tex_manifesto(),
                cornice=tex_ruggine('cornice', 301, vernice=(52, 46, 40), copertura=0.55),
                lampada=tex_ruggine('lampada', 302, vernice=(26, 44, 34), copertura=0.35),
                ferro=tex_ruggine('ferro', 303))


def texture_salvate():
    """Le texture già fatte in jilly_tex/gioco/ (senza le grafiche originali di gen/jilly/)."""
    out = {}
    for nome in ('targa', 'insegna', 'manifesto', 'cornice', 'lampada', 'ferro'):
        out[nome] = {k: os.path.join(TEX, f'{nome}_{k}.{e}') for k, e in (('col', 'jpg'), ('rug', 'jpg'), ('nor', 'png'))
                     if os.path.exists(os.path.join(TEX, f'{nome}_{k}.{e}'))}
    return out


# ---------------------------------------------------------------- modelli (Blender)
def materiale(nome, t, rug=None, met=0.0, nor_forza=1.0):
    import bpy
    m = bpy.data.materials.new(nome); m.use_nodes = True
    m.use_backface_culling = True
    nt, ln = m.node_tree.nodes, m.node_tree.links
    b = nt['Principled BSDF']
    b.inputs['Metallic'].default_value = met
    c = nt.new('ShaderNodeTexImage'); c.image = bpy.data.images.load(t['col'])
    ln.new(c.outputs['Color'], b.inputs['Base Color'])
    if 'rug' in t:
        r = nt.new('ShaderNodeTexImage'); r.image = bpy.data.images.load(t['rug'])
        r.image.colorspace_settings.name = 'Non-Color'
        ln.new(r.outputs['Color'], b.inputs['Roughness'])
    else:
        b.inputs['Roughness'].default_value = rug if rug is not None else 0.85
    if 'nor' in t:
        n = nt.new('ShaderNodeTexImage'); n.image = bpy.data.images.load(t['nor'])
        n.image.colorspace_settings.name = 'Non-Color'
        nm = nt.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = nor_forza
        ln.new(n.outputs['Color'], nm.inputs['Color'])
        ln.new(nm.outputs['Normal'], b.inputs['Normal'])
    return m


def uv_scatola(o, scala=1.0):
    """UV proiettate a scatola in metri (per i materiali ripetibili su cornice e staffe)."""
    import bmesh
    bm = bmesh.new(); bm.from_mesh(o.data)
    uv = bm.loops.layers.uv.verify()
    mw = o.matrix_world
    for f in bm.faces:
        nn = f.normal
        ax = max(range(3), key=lambda i: abs(nn[i]))
        for l in f.loops:
            p = mw @ l.vert.co
            u, v = [(p.y, p.z), (p.x, p.z), (p.x, p.y)][ax]
            l[uv].uv = (u * scala, v * scala)
    bm.to_mesh(o.data); bm.free()


def targa(t):
    import bpy
    J.scena_vuota()
    mf = materiale('targa', t['targa'], met=0.0, nor_forza=1.0)
    ml = materiale('targa_lati', t['ferro'], met=0.4)
    J.lastra('targa', 0.70, 0.39, 0.012, mf, ml, raggio=0.03)
    mv = materiale('vite', t['ferro'], met=0.5)
    for i, (x, z) in enumerate(((-0.315, 0.155), (0.315, 0.155), (-0.315, -0.155), (0.315, -0.155))):
        J.vite(f'vite_{i}', x, z, -0.014, 0.012, mv)
    J.esporta(os.path.join(OUT, 'targa.glb'))


def manifesto(t):
    """Come la proposta B, con strappi più grandi: l'angolo in alto a destra, un morso sul bordo sinistro
    e l'angolo in basso a sinistra che si stacca dal muro e si arriccia. Il nastro di sinistra non c'è
    più (resta il segno giallo della colla). La riga degli orari resta tutta dentro."""
    import bpy, bmesh
    J.scena_vuota()
    mf = materiale('manifesto', t['manifesto'], rug=0.88, nor_forza=0.6)
    mr = J.tinta('carta_retro', (0.62, 0.57, 0.45), 0.92)
    w, h = 0.70, 1.05
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=70, y_subdivisions=105, size=1)
    o = bpy.context.active_object; o.name = 'manifesto'
    o.scale = (w, h, 1); bpy.ops.object.transform_apply(scale=True)
    o.rotation_euler = (math.pi / 2, 0, 0); bpy.ops.object.transform_apply(rotation=True)
    bm = bmesh.new(); bm.from_mesh(o.data)
    nb = rumore(256, 384, 6, 4, 33)
    nf = rumore(256, 384, 30, 3, 34)
    via = []
    for f in bm.faces:
        c = f.calc_center_median()
        u, v = c.x / w + 0.5, c.z / h + 0.5
        n = nb[int((1 - v) * 383), int(u * 255)] * 0.75 + nf[int((1 - v) * 383), int(u * 255)] * 0.25
        d = min(u, 1 - u, v, 1 - v)
        strappo = d < 0.014 + 0.04 * n
        angolo = (u > 0.74 and v > 0.80 and (u - 0.74) / 0.26 + (v - 0.80) / 0.20 > 0.85 + 0.35 * n)
        morso = (u < 0.10 and abs(v - 0.58) < 0.09 and u < 0.10 * (1 - abs(v - 0.58) / 0.09) + 0.04 * n)
        if strappo or angolo or morso:
            via.append(f)
    bmesh.ops.delete(bm, geom=via, context='FACES')
    for vtx in bm.verts:
        u, v = vtx.co.x / w + 0.5, vtx.co.z / h + 0.5
        bordo_v = min(u, 1 - u, v, 1 - v)
        y = -(0.004 + 0.007 * math.sin(u * 9 + v * 4) ** 2 + 0.035 * max(0, 0.12 - bordo_v) * (v < 0.3))
        # angolo in basso a sinistra staccato e arricciato in avanti
        k = max(0.0, 0.28 - (u + v)) / 0.28
        y -= 0.09 * k ** 1.6
        # angolo in alto a sinistra senza nastro: si piega un poco in avanti
        k2 = max(0.0, 0.16 - (u + (1 - v))) / 0.16
        y -= 0.03 * k2 ** 1.5
        vtx.co.y = y
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = (l.vert.co.x / w + 0.5, l.vert.co.z / h + 0.5)
    bm.to_mesh(o.data); bm.free()
    o.data.materials.append(mf)
    retro = o.copy(); retro.data = o.data.copy(); J.collega(retro)
    bm = bmesh.new(); bm.from_mesh(retro.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for vtx in bm.verts:
        vtx.co.y += 0.0008
    bm.to_mesh(retro.data); bm.free()
    retro.data.materials.clear(); retro.data.materials.append(mr)
    # resta solo il nastro di destra, ingiallito; a sinistra la macchia della colla
    mt = J.tinta('nastro', (0.62, 0.50, 0.26), 0.45)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0.25, -0.013, h / 2 - 0.03))
    tt = bpy.context.active_object; tt.scale = (0.12, 0.035, 1)
    tt.rotation_euler = (math.pi / 2, -0.3, 0); tt.data.materials.append(mt)
    mc = J.tinta('colla', (0.42, 0.33, 0.16), 0.6)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(-0.29, -0.0015, h / 2 + 0.005))
    cc = bpy.context.active_object; cc.scale = (0.09, 0.025, 1)
    cc.rotation_euler = (math.pi / 2, 0.25, 0); cc.data.materials.append(mc)
    J.esporta(os.path.join(OUT, 'manifesto.glb'))


def insegna(t):
    """Come la proposta B con le lampade (insegna_luce_b), con la cornice e le lampade arrugginite."""
    import bpy
    J.scena_vuota()
    mf = materiale('insegna', t['insegna'], met=0.0, nor_forza=1.0)
    acc = materiale('acciaio_ruggine', t['cornice'], met=0.3)
    w, h, sp = 1.8, 1.0, 0.03
    J.lastra('pannello', w, h, sp, mf, acc)
    for nome, (x, z, sx, sz) in {'cornice_su': (0, h / 2, w + 0.1, 0.06), 'cornice_giu': (0, -h / 2, w + 0.1, 0.06),
                                 'cornice_sx': (-w / 2, 0, 0.06, h), 'cornice_dx': (w / 2, 0, 0.06, h)}.items():
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -sp - 0.02, z))
        c = bpy.context.active_object; c.name = nome; c.scale = (sx, 0.05, sz); c.data.materials.append(acc)
    for i, (x, z) in enumerate(((-0.7, 0.32), (0.7, 0.32), (-0.7, -0.32), (0.7, -0.32))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0.06, z))
        s = bpy.context.active_object; s.name = f'staffa_{i}'; s.scale = (0.04, 0.12, 0.04)
        s.data.materials.append(acc)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0.115, z))
        p = bpy.context.active_object; p.name = f'piastra_{i}'; p.scale = (0.11, 0.01, 0.11)
        p.data.materials.append(acc)
    for o in bpy.context.scene.objects:
        o.location.y -= 0.12
    J.collo_d_oca()
    # le lampade: smalto verde quasi tutto saltato e ferro arrugginito
    sm = materiale('smalto_lampada', t['lampada'], met=0.2)
    fe = materiale('ferro_lampada', t['ferro'], met=0.4)
    for o in bpy.context.scene.objects:
        if o.type != 'MESH':
            continue
        for i, mat in enumerate(o.data.materials):
            if mat and mat.name.startswith('smalto_lampada') and mat != sm:
                o.data.materials[i] = sm
            elif mat and mat.name.startswith('ferro_lampada') and mat != fe:
                o.data.materials[i] = fe
    for o in bpy.context.scene.objects:
        if o.type == 'MESH' and (o.name.startswith(('cornice', 'staffa', 'piastra', 'lampada_'))):
            bpy.context.view_layer.objects.active = o
            for mod in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=mod.name)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            uv_scatola(o, 2.0)
    J.esporta(os.path.join(OUT, 'insegna.glb'))


if __name__ == '__main__':
    # riusa_texture: le texture già fatte (servono se mancano le grafiche originali); con i nomi dei modelli
    # (targa, manifesto, insegna) rifà solo quelli
    t = texture_salvate() if 'riusa_texture' in sys.argv else tutte_le_texture()
    scelti = [m for m in ('targa', 'manifesto', 'insegna') if m in sys.argv] or ['targa', 'manifesto', 'insegna']
    if 'solo_texture' not in sys.argv:
        for m in scelti:
            {'targa': targa, 'manifesto': manifesto, 'insegna': insegna}[m](t)
