"""Proposte del logo del gioco, secondo giro (22 ottobre: l'utente ha scartato A, B e C, in scartati/).

Tre direzioni lontane dal cartone animato, con tipografia vera e grafica disegnata da codice (PIL + numpy +
scipy), niente immagini generate:
  D  l'insegna al neon del parco di notte: "Jilly" in corsivo e "JUBILEE" in tubi rosa e azzurri su lamiera
     scura, con le mollette, i cavi e il trasformatore; una lettera mezza accesa e una spenta (il tubo di
     vetro si vede lo stesso, il nome si legge); la medusa anche lei di neon, con un tentacolo spento;
  E  il titolo da film horror: maiuscole sottili e spaziate, chiare su nero; un solo segno di Jilly: la
     coda della J scende e diventa un suo tentacolo, rosa e trasparente;
  F  il disegno dei bambini: il nome a pastelli a cera, lettere storte di sei colori, la medusa col
     sorriso, su un foglio ingiallito con lo scotch; il brivido: il bambino che le tiene la mano ha la faccia
     cancellata col pastello nero.
Font (tutti SIL Open Font License, anche per uso commerciale; licenze in font/<nome>/OFL.txt):
  D: Sacramento (Astigmatic) e Quicksand (Andrew Paglinawan); E: Cormorant Garamond (Christian Thalmann);
  F: Gaegu Bold (JIKJI SOFT).

Uso: /home/user/tools/blender-venv/bin/python assets_src/logo/logo_jilly_2.py [scatto_titolo] [cartella]
Escono, per d, e, f: logo_<x>.png, logo_<x>_scuro.jpg, steam_<x>.png e steam_<x>_x3.png, titolo_<x>.jpg.
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import logo_jilly as L  # noqa: E402  (font, maschere, rumore, uscite)
from logo_jilly import font, maschera_testo, allarga, tela, dipingi, frattale, rumore, rng  # noqa: E402

OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(L.REPO, 'docs', 'proposte', 'logo')


def arr(im):
    return np.asarray(im, np.float32) / 255.0


def a_img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def rgba(rgb, al):
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(al, 0, 1) * 255]).astype(np.uint8), 'RGBA')


# ================================================================ D: il neon
ROSA_NEON = np.array([255, 70, 160], np.float32)
AZZURRO_NEON = np.array([70, 200, 255], np.float32)


def tubo(m, colore, stato=1.0):
    """Un tubo di neon dalla maschera m (già della larghezza del tubo). stato 1 acceso, 0.3 mezzo, 0 spento.
    Ritorna (luce additiva RGB float, vetro RGBA): la luce va sommata, il vetro sopra."""
    a = arr(m)
    nucleo = ndi_erodi(a, 0.45)
    bagl1 = arr(m.filter(ImageFilter.GaussianBlur(14)))
    bagl2 = arr(m.filter(ImageFilter.GaussianBlur(60)))
    luce = (colore[None, None] * (bagl1[..., None] * 0.9 + bagl2[..., None] * 0.75)) * stato
    # il vetro: spento è grigio-rosato col riflesso; acceso è colore pieno col nucleo quasi bianco
    spento = np.array([70, 62, 72], np.float32) + 0.15 * colore
    corpo = spento * (1 - stato) + colore * stato
    rgb = np.broadcast_to(corpo, a.shape + (3,)).copy()
    bianco = np.array([255, 240, 250], np.float32)
    rgb = rgb * (1 - nucleo[..., None] * stato * 0.85) + bianco * nucleo[..., None] * stato * 0.85
    # riflesso sul vetro spento (una riga chiara su un lato)
    rif = np.clip(a - np.roll(a, 3, axis=0), 0, 1) * (1 - stato)
    rgb = rgb + 90 * rif[..., None]
    return luce, rgba(rgb, a)


def ndi_erodi(a, frac):
    from scipy import ndimage
    d = ndimage.distance_transform_edt(a > 0.5)
    return np.clip(d / max(1.0, d.max() * frac) - 0.6, 0, 1)


def linea_maschera(W, H, punti, larg):
    m = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m)
    d.line(punti, fill=255, width=int(larg), joint='curve')
    for p in (punti[0], punti[-1]):
        d.ellipse((p[0] - larg / 2, p[1] - larg / 2, p[0] + larg / 2, p[1] + larg / 2), fill=255)
    return m


def logo_d(W=2400, H=1300, seme=5):
    g = rng(seme)
    # la lamiera: pannello scuro con i bordi piegati, rivetti, un po' di ruggine e sporco
    pan = tela(W, H)
    pm = Image.new('L', (W, H), 0)
    ImageDraw.Draw(pm).rounded_rectangle((40, 40, W - 40, H - 40), radius=36, fill=255)
    n = frattale(H, W, seme, (300, 80, 20, 6))
    base = np.array([30, 32, 38], np.float32)[None, None] * (0.75 + 0.5 * n[..., None])
    rug = np.clip((frattale(H, W, seme + 1, (90, 30, 8)) - 0.68) * 5, 0, 1)
    base = base * (1 - rug[..., None] * 0.7) + np.array([70, 38, 22]) * rug[..., None] * 0.7
    # colature dai rivetti e dall'alto
    col = np.clip(rumore(H, W, 3, seme + 2) - 0.5, 0, 1) * np.linspace(1, 0.2, H)[:, None]
    from scipy import ndimage
    col = ndimage.gaussian_filter(col, (60, 1.5))
    base = base * (1 - np.clip(col * 6, 0, 0.4)[..., None])
    bordo = arr(pm) - arr(Image.fromarray((ndimage.binary_erosion(np.asarray(pm) > 128, iterations=26) * 255).astype(np.uint8)))
    base = base * (1 + 0.5 * bordo[..., None])
    pan = rgba(base, arr(pm))
    d = ImageDraw.Draw(pan)
    for x in np.linspace(90, W - 90, 14):
        for y in (90, H - 90):
            d.ellipse((x - 9, y - 9, x + 9, y + 9), fill=(60, 62, 68, 255))
            d.ellipse((x - 5, y - 7, x + 3, y - 1), fill=(110, 110, 116, 255))
    luce = np.zeros((H, W, 3), np.float32)
    vetri = []
    cavi = []
    # "Jilly" corsivo rosa; la seconda l è mezza accesa (sfarfalla)
    f_j = font('sacramento/Sacramento-Regular.ttf', 720)
    f_u = font('quicksand/Quicksand.ttf', 270, 600, None)
    x0 = W * 0.07
    stati_j = [1, 1, 1, 0.3, 1]
    for i, c in enumerate('Jilly'):
        m = maschera_testo(c, f_j, 40)
        m = allarga(m, 5)
        big = Image.new('L', (W, H), 0)
        big.paste(m, (int(x0 + f_j.getlength('Jilly'[:i]) * 0.86 - 40), int(H * 0.05)))
        lu, ve = tubo(big, ROSA_NEON, stati_j[i])
        luce += lu
        vetri.append(ve)
        cavi.append(big)
    # JUBILEE azzurro, l'ultima E spenta
    m_u = []
    larg = sum(f_u.getlength(c) for c in 'JUBILEE') + 60 * 6
    x = W * 0.5 - larg / 2
    for i, c in enumerate('JUBILEE'):
        m = maschera_testo(c, f_u, 40)
        big = Image.new('L', (W, H), 0)
        big.paste(allarga(m, 2), (int(x - 40), int(H * 0.63)))
        x += f_u.getlength(c) + 60
        lu, ve = tubo(big, AZZURRO_NEON, 0.0 if i == 6 else 1.0)
        luce += lu
        vetri.append(ve)
        cavi.append(big)
    # la medusa di neon, lilla-rosa, un tentacolo spento
    cx, cy, r = W * 0.80, H * 0.24, 200
    cupola = [(cx + r * math.cos(t), cy - r * 0.85 * math.sin(t)) for t in np.linspace(0, math.pi, 60)]
    smerlo = []
    for k in range(5):
        xa = cx + r - k * 2 * r / 5
        for t in np.linspace(0, math.pi, 12):
            smerlo.append((xa - r / 5 + r / 5 * math.cos(t), cy + r * 0.12 * math.sin(t)))
    pezzi_med = [(cupola, 1.0), (smerlo, 1.0)]
    for k in range(4):
        xa = cx - r * 0.6 + k * r * 0.4
        fase = g.uniform(0, 6)
        pts = [(xa + 22 * math.sin(fase + t * 8), cy + 40 + t * 330) for t in np.linspace(0, 1, 40)]
        pezzi_med.append((pts, 0.0 if k == 2 else 1.0))
    lilla = np.array([235, 110, 255], np.float32)
    for pts, st in pezzi_med:
        m = linea_maschera(W, H, pts, 18)
        lu, ve = tubo(m, lilla, st)
        luce += lu
        vetri.append(ve)
    # mollette dei tubi: due per lettera, distanziatori grigi con l'ombra
    mol = tela(W, H)
    dm = ImageDraw.Draw(mol)
    for m in cavi:
        a = np.asarray(m) > 128
        ys, xs = np.nonzero(a)
        if len(ys) == 0:
            continue
        for k in g.choice(len(ys), 2, replace=False):
            y, x = ys[k], xs[k]
            dm.ellipse((x - 14, y + 6, x + 14, y + 22), fill=(0, 0, 0, 120))
            dm.rectangle((x - 5, y - 4, x + 5, y + 14), fill=(120, 124, 130, 255))
            dm.arc((x - 13, y - 12, x + 13, y + 12), 200, 340, fill=(150, 152, 158, 255), width=4)
    # cavi: dal fondo di ogni lettera giù al trasformatore in basso a destra
    tx, ty = W * 0.88, H * 0.88
    cav = tela(W, H)
    dc = ImageDraw.Draw(cav)
    for m in cavi[::2]:
        a = np.asarray(m) > 128
        ys, xs = np.nonzero(a)
        if len(ys) == 0:
            continue
        k = np.argmax(ys)
        x, y = xs[k], ys[k]
        yb = H * 0.93 + g.uniform(-8, 8)
        punti = [(x, y + 10), (x + g.uniform(-6, 6), yb), (tx - 60, yb), (tx - 60, ty + 20)]
        dc.line(punti, fill=(12, 12, 14, 255), width=6, joint='curve')
    dc.rectangle((tx - 110, ty - 40, tx + 90, ty + 60), fill=(46, 48, 52, 255), outline=(80, 82, 88, 255), width=4)
    for k in range(5):
        dc.line((tx - 90 + k * 36, ty - 30, tx - 90 + k * 36, ty + 50), fill=(36, 37, 40, 255), width=8)
    # composizione: lamiera, luce che la colora, cavi, mollette, vetri, poi il bagliore sopra
    out = np.asarray(pan, np.float32)
    rgb = out[..., :3] + luce * 0.55 * (out[..., 3:] / 255)
    img = rgba(rgb, out[..., 3] / 255)
    img.alpha_composite(cav)
    for v in vetri:
        img.alpha_composite(v)
    img.alpha_composite(mol)
    o = np.asarray(img, np.float32)
    rgb = o[..., :3] + luce * 0.35
    al = np.maximum(o[..., 3] / 255, np.clip(luce.max(2) / 255, 0, 1))
    return rgba(rgb, al)


# ================================================================ E: il film
AVORIO = np.array([232, 226, 214], np.float32)
ROSA_LEI = np.array([255, 120, 180], np.float32)


def logo_e(W=2400, H=1300, seme=8):
    f = font('cormorantgaramond/CormorantGaramond.ttf', 330, 500, None)
    img = tela(W, H)
    righe = [('JILLY', H * 0.22), ('JUBILEE', H * 0.50)]
    track = 70
    j_bordo = None
    for testo, y in righe:
        larg = sum(f.getlength(c) for c in testo) + track * (len(testo) - 1)
        x = W / 2 - larg / 2
        for i, c in enumerate(testo):
            m = maschera_testo(c, f, 40)
            pos = (x - 40, y - m.height / 2)
            dipingi(img, m, tuple(int(v) for v in AVORIO), pos)
            if testo == 'JUBILEE' and i == 0:
                a = np.asarray(m) > 128
                ys, xs = np.nonzero(a)
                k = np.argmax(ys - 0.2 * xs)  # la punta in basso a sinistra della coda della J
                j_bordo = (pos[0] + xs[k], pos[1] + ys[k])
                spess = np.asarray(m).max(0).astype(bool)
            x += f.getlength(c) + track
    # il tentacolo: continua la coda della J, scende tra le due parole e si arriccia sotto JUBILEE
    g = rng(seme)
    x0, y0 = j_bordo
    pts = []
    for t in np.linspace(0, 1, 260):
        x = x0 - 30 * math.sin(t * 2.2) + 60 * t + 26 * math.sin(t * 13) * t
        y = y0 + t * H * 0.42
        if t > 0.82:  # il ricciolo in fondo
            u = (t - 0.82) / 0.18
            ang = u * 4.4
            rr = 70 * (1 - u * 0.6)
            x = x0 + 60 * 0.82 - 30 * math.sin(0.82 * 2.2) + 26 * math.sin(0.82 * 13) * 0.82 + rr * (1 - math.cos(ang))
            y = y0 + 0.82 * H * 0.42 + rr * math.sin(ang)
        pts.append((x, y))
    t_al = np.zeros((H, W), np.float32)
    t_col = np.zeros((H, W, 3), np.float32)
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        u = i / len(pts)
        w = 13 * (1 - u) ** 1.2 + 2
        m = Image.new('L', (W, H), 0)
        dd = ImageDraw.Draw(m)
        dd.line((a, b), fill=255, width=int(max(2, w)))
        dd.ellipse((b[0] - w / 2, b[1] - w / 2, b[0] + w / 2, b[1] + w / 2), fill=255)
        mm = arr(m)
        alfa = 1.0 - 0.55 * u
        colore = AVORIO * (1 - min(1, u * 2.5)) + ROSA_LEI * min(1, u * 2.5)
        nuovo = mm * alfa
        piu = nuovo > t_al
        t_al = np.where(piu, nuovo, t_al)
        t_col[piu] = colore
    tent = rgba(t_col, t_al)
    glow = a_img(t_al * np.clip(np.linspace(0, 1, H)[:, None] * 2 - 0.4, 0, 1)).filter(ImageFilter.GaussianBlur(18))
    out = tela(W, H)
    dipingi(out, glow, (255, 90, 170))
    out.alpha_composite(img)
    out.alpha_composite(tent)
    # grana leggera della pellicola, solo dentro le lettere
    o = np.asarray(out, np.float32)
    gr = rng(seme + 1).normal(0, 7, (H, W, 1))
    o[..., :3] = np.clip(o[..., :3] + gr, 0, 255)
    return Image.fromarray(o.astype(np.uint8), 'RGBA')


# ================================================================ F: il disegno a pastelli
PASTELLI = [(232, 70, 120), (60, 120, 220), (245, 190, 30), (70, 170, 80), (240, 120, 40), (150, 80, 200)]


def pastello(m, colore, seme, angolo=None):
    """Riempie la maschera m come un pastello a cera: tratteggio storto, la grana della carta che salta, il
    bordo ripassato più forte."""
    a = arr(m)
    H, W = a.shape
    g = rng(seme)
    ang = angolo if angolo is not None else g.uniform(-0.9, 0.9)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    u = xx * math.cos(ang) + yy * math.sin(ang)
    onda = rumore(H, W, 40, seme + 1) * 9
    tratti = 0.5 + 0.5 * np.sin((u + onda) / 3.2)
    grana = frattale(H, W, seme + 2, (6, 2.5, 1.2))
    copre = np.clip((tratti * 0.22 + grana * 1.0 - 0.40) * 3.4, 0, 1)
    from scipy import ndimage
    dentro = ndimage.distance_transform_edt(a > 0.5)
    bordo = np.clip(1 - dentro / 7, 0, 1) * (a > 0.5)
    al = a * np.clip(copre * 0.85 + bordo * 0.6, 0, 1)
    tinta = np.array(colore, np.float32)[None, None] * (0.85 + 0.3 * grana[..., None])
    return rgba(tinta, al)


def scarabocchio(W, H, pts, larg, seme, tremolio=3.0):
    """Una riga a mano di bambino: la linea trema e passa due volte, un po' spostata."""
    g = rng(seme)
    m = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m)
    for passata in range(2):
        q = [(x + g.normal(0, tremolio), y + g.normal(0, tremolio)) for x, y in pts]
        d.line(q, fill=255, width=int(larg), joint='curve')
    return m


def logo_f(W=2400, H=1300, seme=12):
    g = rng(seme)
    r = random.Random(seme)
    # il foglio ingiallito, un po' storto, con la piega e lo scotch
    fo = Image.new('L', (W, H), 0)
    ImageDraw.Draw(fo).polygon([(70, 90), (W - 60, 50), (W - 90, H - 70), (100, H - 40)], fill=255)
    n = frattale(H, W, seme, (400, 120, 30, 5))
    carta = np.array([226, 210, 168], np.float32)[None, None] * (0.86 + 0.2 * n[..., None])
    macchie = np.clip((frattale(H, W, seme + 3, (200, 60)) - 0.62) * 3, 0, 1)
    carta = carta * (1 - 0.25 * macchie[..., None]) + np.array([150, 110, 60]) * 0.25 * macchie[..., None]
    piega = np.exp(-((np.arange(W) - W * 0.52) / 6.0) ** 2)[None, :]
    carta = carta * (1 - 0.12 * piega[..., None])
    bordo_scuro = arr(fo) - arr(fo.filter(ImageFilter.MinFilter(41)))
    carta = carta * (1 - 0.12 * np.clip(bordo_scuro, 0, 1)[..., None])
    img = rgba(carta, arr(fo))
    for (x, y, a) in [(150, 90, -30), (W - 140, 70, 25)]:
        s = Image.new('RGBA', (260, 80), (240, 236, 210, 150))
        s = s.rotate(a, expand=True)
        img.alpha_composite(s, (int(x - s.width / 2), int(y - s.height / 2)))
    # le lettere: Gaegu, ogni lettera di un colore, storte, una riga che sale
    f = font('gaegu/Gaegu-Bold.ttf', 420)
    testo = 'Jilly Jubilee'
    x = W * 0.06
    ci = 0
    for i, c in enumerate(testo):
        if c == ' ':
            x += f.getlength(' ') * 0.7
            continue
        m = maschera_testo(c, f, 60)
        m = allarga(m, 6).rotate(r.uniform(-12, 12), Image.BICUBIC, expand=True)
        m = m.resize((int(m.width * r.uniform(0.9, 1.15)), int(m.height * r.uniform(0.9, 1.15))))
        y = H * 0.12 - i * 6 + r.uniform(-25, 25)
        big = Image.new('L', (W, H), 0)
        big.paste(m, (int(x - 60), int(y)))
        img.alpha_composite(pastello(big, PASTELLI[ci % 6], seme + i))
        ci += 1
        x += f.getlength(c) * 1.02
    # la medusa col sorriso, rosa, in basso a destra
    cx, cy, rr = W * 0.40, H * 0.66, 190
    cup = [(cx + rr * math.cos(t), cy - rr * 0.9 * math.sin(t)) for t in np.linspace(0, math.pi, 30)]
    cup.append(cup[0])
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon(cup, fill=255)
    img.alpha_composite(pastello(m, (240, 120, 170), seme + 40, 0.6))
    img.alpha_composite(pastello(scarabocchio(W, H, cup, 12, seme + 41), (200, 60, 120), seme + 42))
    tent_pts = []
    for k in range(5):
        xa = cx - rr * 0.8 + k * rr * 0.4
        pts = [(xa + 25 * math.sin(t * 9 + k), cy + t * 280) for t in np.linspace(0, 1, 20)]
        tent_pts.append(pts)
        img.alpha_composite(pastello(scarabocchio(W, H, pts, 14, seme + 50 + k), (220, 80, 150), seme + 60 + k))
    # faccina: occhi a puntino e il sorriso
    fac = Image.new('L', (W, H), 0)
    df = ImageDraw.Draw(fac)
    for ox in (-60, 60):
        df.ellipse((cx + ox - 16, cy - 110, cx + ox + 16, cy - 74), fill=255)
    img.alpha_composite(pastello(fac, (30, 30, 40), seme + 70))
    sorriso = [(cx - 80 + t * 160, cy - 40 + 45 * math.sin(t * math.pi)) for t in np.linspace(0, 1, 14)]
    img.alpha_composite(pastello(scarabocchio(W, H, sorriso, 12, seme + 71), (30, 30, 40), seme + 72))
    # il bambino che le tiene la mano (l'ultimo tentacolo), a omino
    bx, by = W * 0.58, H * 0.66
    om = Image.new('L', (W, H), 0)
    corpo = [(bx, by - 60), (bx, by + 110)]
    gambe = [(bx - 50, by + 220), (bx, by + 110), (bx + 50, by + 220)]
    braccia = [(tent_pts[-1][14][0] + 10, tent_pts[-1][14][1]), (bx, by + 10), (bx + 70, by + 60)]
    for pts in (corpo, gambe, braccia):
        om = ImageChops.lighter(om, scarabocchio(W, H, pts, 13, seme + 80 + len(pts)))
    testa = [(bx + 58 * math.cos(t), by - 120 + 62 * math.sin(t)) for t in np.linspace(0, 6.3, 24)]
    om = ImageChops.lighter(om, scarabocchio(W, H, testa, 12, seme + 90))
    img.alpha_composite(pastello(om, (60, 120, 220), seme + 91))
    # il brivido: la faccia cancellata col pastello nero, a spirale fitta
    canc = []
    for t in np.linspace(0, 1, 140):
        canc.append((bx + 48 * math.sin(t * 60) * (0.7 + 0.3 * math.sin(t * 7)), by - 160 + t * 82))
    img.alpha_composite(pastello(scarabocchio(W, H, canc, 16, seme + 92, 2), (18, 16, 22), seme + 93))
    return img


# ================================================================ uscite
def main():
    os.makedirs(OUT, exist_ok=True)
    scatto = sys.argv[1] if len(sys.argv) > 1 and os.path.exists(sys.argv[1]) else None
    loghi = {'d': L.ritaglia(logo_d(), 10), 'e': L.ritaglia(logo_e(), 40), 'f': L.ritaglia(logo_f(), 10)}
    for k, logo in loghi.items():
        logo.save(os.path.join(OUT, f'logo_{k}.png'))
        L.su_scuro(logo, 1600, 900, fondo=(8, 8, 10)).save(os.path.join(OUT, f'logo_{k}_scuro.jpg'), quality=92)
        st = L.su_scuro(logo, 231, 87, 0.94, fondo=(8, 8, 10))
        st.save(os.path.join(OUT, f'steam_{k}.png'))
        st.resize((231 * 3, 87 * 3), Image.NEAREST).save(os.path.join(OUT, f'steam_{k}_x3.png'))
        if scatto:
            L.sul_titolo(logo, scatto).save(os.path.join(OUT, f'titolo_{k}.jpg'), quality=92)
        print('fatto', k, logo.size)


if __name__ == '__main__':
    main()
