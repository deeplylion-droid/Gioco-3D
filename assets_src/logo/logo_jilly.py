"""Proposte del logo del gioco, "Jilly Jubilee" (richiesta dell'utente del 22 ottobre, dopo il cambio di nome).

Tre direzioni, tutte con tipografia vera e grafica disegnata da codice (PIL + numpy + scipy), niente
immagini generate:
  A  l'insegna del parco: "Jilly" in corsivo corallo e "JUBILEE" in oro su un nastro blu, stelle e la
     medusa, come insegna, targa e manifesto del gioco (stile B), smalto saltato fino alla ruggine;
  B  lo show per bambini anni '90 com'era da nuovo: lettere tonde che saltellano, i colori del parco, la
     medusa al posto del puntino della i; una cosa sola stona: la medusa ha un occhio vero;
  C  la versione horror: lo stesso logo della B rovinato dall'acqua (colature, crepe, pezzi caduti,
     macchie) col bagliore rosa di lei, su fondo scuro.
Font (tutti SIL Open Font License, anche per uso commerciale; licenze in font/<nome>/OFL.txt):
  Pacifico (Vernon Adams) e Alfa Slab One (JM Solé) per la A; Fredoka Bold (Milena Brandão) per B e C.

Uso: /home/user/tools/blender-venv/bin/python assets_src/logo/logo_jilly.py [scatto_titolo.png] [cartella]
Escono: logo_<x>.png (trasparente), logo_<x>_scuro.jpg, steam_<x>.png (231x87) e steam_<x>_x3.png,
titolo_<x>.jpg (sopra lo scatto del titolo, se c'è).
"""
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
from scipy import ndimage
from scipy.spatial import cKDTree

QUI = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(QUI, 'font')
REPO = os.path.dirname(os.path.dirname(QUI))
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, 'docs', 'proposte', 'logo', 'scartati')  # scartate dall'utente il 22 ottobre

# I colori del parco (insegna e targa del gioco, stile B)
NAVY = (38, 52, 92)
CORALLO = (226, 116, 128)
ORO = (226, 190, 102)
PANNA = (238, 230, 212)
ROSA = (238, 140, 170)
ROSA_CHIARO = (250, 206, 220)


def font(nome, px, peso=None, larghezza=None):
    f = ImageFont.truetype(os.path.join(FONT, nome), px)
    if peso:
        f.set_variation_by_axes([peso] + ([larghezza] if larghezza else []))
    return f


def rng(seme):
    return np.random.default_rng(seme)


# ---------------------------------------------------------------- maschere
def maschera_testo(testo, f, margine=40):
    """Maschera L del testo, con un margine (per contorni ed estrusioni)."""
    l, t, r, b = f.getbbox(testo)
    im = Image.new('L', (r - l + 2 * margine, b - t + 2 * margine), 0)
    ImageDraw.Draw(im).text((margine - l, margine - t), testo, font=f, fill=255)
    return im


def allarga(m, px):
    """Contorno tondo di px pixel attorno alla maschera (distanza vera, bordi lisci)."""
    a = np.asarray(m, np.float32) / 255.0
    d = ndimage.distance_transform_edt(a < 0.5)
    v = np.clip(px + 0.5 - d, 0, 1)
    return Image.fromarray((np.maximum(v, a) * 255).astype(np.uint8))


def tela(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def dipingi(dst, m, colore, xy=(0, 0)):
    """Dipinge un colore pieno attraverso la maschera m, nella posizione xy della tela."""
    pezzo = Image.new('RGBA', m.size, colore + (255,) if len(colore) == 3 else colore)
    pezzo.putalpha(ImageChops.multiply(m, pezzo.getchannel('A')))
    dst.alpha_composite(pezzo, (int(xy[0]), int(xy[1])))


def stella(d, cx, cy, r, colore, contorno=None, larg=0, rot=-90):
    pts = []
    for i in range(10):
        a = math.radians(rot + i * 36)
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    if contorno:
        d.polygon(pts, fill=contorno)
        # contorno: la stessa stella più grande sotto
    d.polygon(pts, fill=colore)
    return pts


def stella_bordata(img, cx, cy, r, colore, contorno, larg, rot=-90):
    m = Image.new('L', img.size, 0)
    stella(ImageDraw.Draw(m), cx, cy, r, 255, rot=rot)
    dipingi(img, allarga(m, larg), contorno)
    dipingi(img, m, colore)


# ---------------------------------------------------------------- la medusa
def medusa(w, h, colore, chiaro, contorno, larg, seme=3, tentacoli=5, occhio=False):
    """Una medusa da insegna: cupola a smerlo e tentacoli ondulati. Ritorna RGBA w x h."""
    s = 4  # disegna grande e riduce: bordi lisci
    W, H = w * s, h * s
    m_cupola = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m_cupola)
    cx, cy, rx, ry = W / 2, H * 0.30, W * 0.42, H * 0.25
    d.pieslice((cx - rx, cy - ry, cx + rx, cy + ry), 180, 360, fill=255)
    # smerlo sotto la cupola
    n = 5
    for i in range(n):
        x0 = cx - rx + i * 2 * rx / n
        d.ellipse((x0, cy - ry * 0.18, x0 + 2 * rx / n, cy + ry * 0.30), fill=255)
    m_tent = Image.new('L', (W, H), 0)
    dt = ImageDraw.Draw(m_tent)
    r = random.Random(seme)
    for i in range(tentacoli):
        x0 = cx - rx * 0.7 + i * 1.4 * rx / (tentacoli - 1)
        lung = H * (0.55 + 0.12 * r.random()) - cy
        fase, amp = r.random() * 6.28, W * (0.035 + 0.02 * r.random())
        pts = [(x0 + amp * math.sin(fase + t * 9) * (0.4 + t), cy + ry * 0.2 + t * lung) for t in np.linspace(0, 1, 40)]
        for j, (a, b) in enumerate(zip(pts, pts[1:])):
            larg_t = W * 0.05 * (1 - j / 40) + W * 0.012
            dt.line((a, b), fill=255, width=int(larg_t))
            dt.ellipse((b[0] - larg_t / 2, b[1] - larg_t / 2, b[0] + larg_t / 2, b[1] + larg_t / 2), fill=255)
    tutto = ImageChops.lighter(m_cupola, m_tent)
    out = tela(W, H)
    dipingi(out, allarga(tutto, larg * s), contorno)
    dipingi(out, m_tent, chiaro)
    dipingi(out, m_cupola, colore)
    # riflesso e righe sulla cupola
    lume = Image.new('L', (W, H), 0)
    dl = ImageDraw.Draw(lume)
    dl.ellipse((cx - rx * 0.62, cy - ry * 0.78, cx - rx * 0.12, cy - ry * 0.42), fill=255)
    dipingi(out, ImageChops.multiply(lume, m_cupola).filter(ImageFilter.GaussianBlur(s * 3)), chiaro + (170,))
    fascia = Image.new('L', (W, H), 0)
    ImageDraw.Draw(fascia).pieslice((cx - rx * 0.86, cy - ry * 0.2, cx + rx * 0.86, cy + ry * 0.26), 0, 180, fill=255)
    dipingi(out, ImageChops.multiply(fascia, m_cupola).filter(ImageFilter.GaussianBlur(s)), tuple(int(c * 0.86) for c in colore))
    if occhio:
        _occhio(out, cx, cy - ry * 0.32, rx * 0.36)
    return out.resize((w, h), Image.LANCZOS)


def _occhio(img, cx, cy, r, bagliore=None, seme=7):
    """L'occhio vero, quello che stona: bulbo umido con le venuzze, iride grigia, pupilla piccola."""
    W, H = img.size
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx, dy = (xx - cx) / r, (yy - cy) / (r * 0.78)
    d = np.sqrt(dx * dx + dy * dy)
    bulbo = np.clip((1 - d) * r * 0.5, 0, 1)
    col = np.zeros((H, W, 4), np.float32)
    # bianco giallastro, più scuro ai bordi
    base = np.array([236, 226, 214], np.float32) * (1 - 0.35 * np.clip(d, 0, 1) ** 2)[..., None]
    # venuzze: rumore filtrato, solo verso i bordi
    g = rng(seme)
    v = ndimage.gaussian_filter(g.random((H, W)).astype(np.float32), r * 0.04)
    v = np.abs(v - v.mean()) < 0.0035
    ven = v & (d > 0.45) & (d < 1)
    base[ven] = base[ven] * 0.45 + np.array([190, 40, 40]) * 0.55
    # iride e pupilla, un po' di lato: guarda chi guarda
    ix, iy = cx + r * 0.12, cy + r * 0.05
    di = np.sqrt((xx - ix) ** 2 + (yy - iy) ** 2) / (r * 0.42)
    iride = np.clip((1 - di) * r * 0.42, 0, 1)
    tinta = bagliore if bagliore else (120, 132, 140)
    raggi = 0.75 + 0.25 * np.sin(np.arctan2(yy - iy, xx - ix) * 23)
    ir = np.array(tinta, np.float32)[None, None] * (0.55 + 0.45 * di[..., None]) * raggi[..., None]
    base = base * (1 - iride[..., None]) + ir * iride[..., None]
    pup = np.clip((1 - np.sqrt((xx - ix) ** 2 + (yy - iy) ** 2) / (r * 0.13)) * r * 0.13, 0, 1)
    base = base * (1 - pup[..., None]) + np.array([12, 10, 12]) * pup[..., None]
    # riflesso umido
    rif = np.clip((1 - np.sqrt((xx - ix + r * 0.14) ** 2 + (yy - iy + r * 0.14) ** 2) / (r * 0.07)) * 4, 0, 1)
    base = base * (1 - rif[..., None]) + 255 * rif[..., None]
    col[..., :3] = base
    col[..., 3] = bulbo * 255
    occ = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), 'RGBA')
    # palpebra: contorno scuro
    m = Image.fromarray((bulbo * 255).astype(np.uint8))
    bordo = ImageChops.subtract(allarga(m, max(2, int(r * 0.08))), m)
    dipingi(img, bordo, (40, 20, 30))
    img.alpha_composite(occ)


# ---------------------------------------------------------------- testo lungo una curva
def lettere_su_curva(img, testo, f, x0, x1, y_di, colori, margine=60, rot_extra=None, salti=None,
                      spaziatura=0.0, estrusione=None):
    """Mette le lettere tra x0 e x1 sulla curva y_di(x), ruotate lungo la tangente.
    colori: lista di (allargamento_px, colore) dal fondo alla cima (0 = la lettera piena).
    estrusione: (dx, dy, passi, colore) un rilievo 3D sotto ogni lettera."""
    larg = [f.getlength(c) for c in testo]
    tot = sum(larg) + spaziatura * (len(testo) - 1)
    scala = 1.0
    pezzi = []
    x = (x0 + x1) / 2 - tot / 2
    for i, c in enumerate(testo):
        cx = x + larg[i] * scala / 2
        x += (larg[i] + spaziatura) * scala
        y = y_di(cx)
        ang = -math.degrees(math.atan2(y_di(cx + 1) - y_di(cx - 1), 2))
        if rot_extra:
            ang += rot_extra[i]
        if salti:
            y += salti[i]
        m = maschera_testo(c, f, margine)
        pezzi.append((c, m, cx, y, ang))
    # prima tutti i fondi (contorni ed estrusioni), poi le lettere: le lettere vicine non si coprono
    livelli = sorted({c[0] for c in colori}, reverse=True)
    if estrusione:
        dx, dy, passi, col = estrusione
        big = max(livelli)
        for c, m, cx, y, ang in pezzi:
            mm = allarga(m, big).rotate(ang, Image.BICUBIC, expand=True)
            for k in range(passi, 0, -1):
                dipingi(img, mm, col, (cx - mm.width / 2 + dx * k / passi, y - mm.height / 2 + dy * k / passi))
    for lv in livelli:
        col = [c for l, c in colori if l == lv][0]
        for c, m, cx, y, ang in pezzi:
            mm = (allarga(m, lv) if lv else m).rotate(ang, Image.BICUBIC, expand=True)
            if callable(col):
                col(img, mm, (cx - mm.width / 2, y - mm.height / 2), c)
            else:
                dipingi(img, mm, col, (cx - mm.width / 2, y - mm.height / 2))
    return pezzi


# ---------------------------------------------------------------- A: l'insegna del parco
def nastro(img, x0, x1, y_di, alto, colore, bordo, larg_bordo, coda):
    W, H = img.size
    xs = np.linspace(x0, x1, 80)
    su = [(x, y_di(x) - alto / 2) for x in xs]
    giu = [(x, y_di(x) + alto / 2) for x in xs[::-1]]
    m = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m)
    d.polygon(su + giu, fill=255)
    # le code ripiegate dietro, con la V
    mc = Image.new('L', (W, H), 0)
    dc = ImageDraw.Draw(mc)
    for lato in (-1, 1):
        xb = x0 if lato < 0 else x1
        yb = y_di(xb) + alto * 0.35
        xe = xb + lato * coda
        pts = [(xb - lato * coda * 0.5, yb - alto / 2), (xe, yb - alto / 2 - alto * 0.05),
               (xe - lato * coda * 0.35, yb), (xe, yb + alto / 2 + alto * 0.05), (xb - lato * coda * 0.5, yb + alto / 2)]
        dc.polygon(pts, fill=255)
    tutto = ImageChops.lighter(m, mc)
    dipingi(img, allarga(tutto, larg_bordo * 2.2), NAVY)
    dipingi(img, allarga(tutto, larg_bordo), bordo)
    dipingi(img, mc, tuple(int(c * 0.72) for c in colore))
    dipingi(img, allarga(m, larg_bordo * 0.9), NAVY)
    dipingi(img, m, colore)
    # filetto oro dentro il nastro
    filetto = ImageChops.subtract(m, allarga(Image.fromarray((ndimage.binary_erosion(np.asarray(m) > 128, iterations=int(alto * 0.09)) * 255).astype(np.uint8)), 0))
    filetto = ImageChops.subtract(filetto, Image.fromarray((ndimage.binary_erosion(np.asarray(m) > 128, iterations=int(alto * 0.07)) * 255).astype(np.uint8)))
    dipingi(img, filetto, bordo)


def logo_a(W=2400, H=1300):
    img = tela(W, H)
    f_j = font('pacifico/Pacifico-Regular.ttf', 520)
    f_u = font('alfaslabone/AlfaSlabOne-Regular.ttf', 200)
    cx = W * 0.47
    # nastro col JUBILEE, che sorride
    y_n = lambda x: H * 0.76 - 0.00028 * (x - cx) ** 2
    nastro(img, cx - W * 0.33, cx + W * 0.33, y_n, 270, NAVY, ORO, 12, 190)
    lettere_su_curva(img, 'JUBILEE', f_u, cx - W * 0.26, cx + W * 0.26, lambda x: y_n(x) - 6,
                     [(10, NAVY), (0, ORO)], spaziatura=22)
    # Jilly, corsivo che sale un po'
    m = maschera_testo('Jilly', f_j, 60)
    m = m.rotate(8, Image.BICUBIC, expand=True)
    x, y = cx - m.width / 2 - 40, H * 0.43 - m.height / 2
    ombra = allarga(m, 34)
    dipingi(img, ombra, NAVY, (x, y))
    dipingi(img, allarga(m, 16), PANNA, (x, y))
    dipingi(img, allarga(m, 8), NAVY, (x, y))
    dipingi(img, m, CORALLO, (x, y))
    # riflesso dello smalto in alto nelle lettere
    lume = ImageChops.multiply(m, ImageChops.offset(m, 0, 14).point(lambda v: 255 - v))
    dipingi(img, lume.filter(ImageFilter.GaussianBlur(2)), (255, 214, 214, 150), (x, y))
    # stelle e medusa
    for (sx, sy, r, rot) in [(0.17, 0.30, 70, -80), (0.12, 0.55, 48, -95), (0.62, 0.47, 40, -100), (0.88, 0.50, 62, -85)]:
        stella_bordata(img, W * sx, H * sy, r, ORO, NAVY, 10, rot)
    med = medusa(430, 640, ROSA, ROSA_CHIARO, NAVY, 7)
    img.alpha_composite(med, (int(W * 0.69), int(H * 0.05)))
    return img


# ---------------------------------------------------------------- invecchiamento (A e C)
def rumore(H, W, scala, seme):
    g = rng(seme)
    piccolo = g.random((max(2, int(H / scala)) + 2, max(2, int(W / scala)) + 2)).astype(np.float32)
    grande = ndimage.zoom(piccolo, (H / (piccolo.shape[0] - 2), W / (piccolo.shape[1] - 2)), order=3)
    return grande[:H, :W]


def frattale(H, W, seme, scale=(220, 90, 35, 12)):
    t, p = np.zeros((H, W), np.float32), 1.0
    for i, s in enumerate(scale):
        t += p * rumore(H, W, s, seme + i)
        p *= 0.5
    t -= t.min()
    return t / t.max()


def ruggine(H, W, seme):
    n = frattale(H, W, seme, (60, 20, 7, 3))
    c1, c2, c3 = np.array([92, 42, 22]), np.array([150, 70, 30]), np.array([196, 110, 52])
    a = np.clip(n * 1.6 - 0.3, 0, 1)[..., None]
    b = np.clip(n * 2 - 1.2, 0, 1)[..., None]
    return c1 * (1 - a) + c2 * a + (c3 - c2) * b


def crepe(H, W, passo, seme, spessore=1.3):
    g = rng(seme)
    n = int(H * W / passo ** 2)
    pts = g.random((n, 2)) * [H, W]
    yy, xx = np.mgrid[0:H, 0:W]
    q = np.stack([yy.ravel(), xx.ravel()], 1)
    dist, _ = cKDTree(pts).query(q, k=2)
    diff = (dist[:, 1] - dist[:, 0]).reshape(H, W)
    return np.clip(1 - diff / spessore, 0, 1)


def invecchia_a(img, seme=11):
    """Smalto saltato a chiazze fino alla ruggine, colature dalle chiazze, crepe nello smalto, sbiadito."""
    a = np.asarray(img, np.float32)
    rgb, al = a[..., :3], a[..., 3] / 255
    H, W = al.shape
    # sbiadito e ingiallito
    grigio = rgb.mean(2, keepdims=True)
    rgb = rgb * 0.72 + grigio * 0.28
    rgb = rgb * np.array([1.0, 0.95, 0.85]) * 0.92 + np.array([10, 6, 0])
    # crepe dello smalto (solo nelle zone chiare e piene)
    cr = crepe(H // 2, W // 2, 34, seme)
    cr = ndimage.zoom(cr, 2, order=1)[:H, :W]
    rgb = rgb * (1 - 0.3 * cr[..., None] * np.clip(frattale(H, W, seme + 2, (300, 100)) * 1.6 - 0.4, 0, 1)[..., None])
    # chiazze saltate: ruggine sotto, bordo scuro
    n = frattale(H, W, seme + 5, (160, 60, 22, 8))
    salt = np.clip((n - 0.66) * 14, 0, 1)
    bordo = np.clip((n - 0.61) * 14, 0, 1) - salt
    rug = ruggine(H, W, seme + 9)
    rgb = rgb * (1 - np.clip(bordo, 0, 1)[..., None] * 0.55)
    rgb = rgb * (1 - salt[..., None]) + rug * salt[..., None]
    # colature di ruggine verso il basso, dalle chiazze
    sorg = ndimage.gaussian_filter(salt, 2) * rumore(H, W, 6, seme + 3)
    col = np.zeros_like(sorg)
    acc = np.zeros(W, np.float32)
    for y in range(H):
        acc = acc * 0.985 + sorg[y] * 0.08
        col[y] = acc
    col = np.clip(col * 2.2, 0, 0.6) * (1 - salt)
    rgb = rgb * (1 - col[..., None]) + np.array([120, 58, 26]) * col[..., None]
    # pezzi caduti del tutto ai bordi delle lettere: buchi piccoli
    buchi = np.clip((frattale(H, W, seme + 20, (40, 14, 5)) - 0.86) * 20, 0, 1)
    al = al * (1 - buchi * 0.9)
    out = np.dstack([np.clip(rgb, 0, 255), al * 255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


# ---------------------------------------------------------------- B: lo show per bambini
PAL_B = dict(j=(255, 108, 150), j_ombra=(30, 150, 170), u=(255, 206, 52), u_ombra=(238, 112, 40),
             contorno=(30, 42, 90), bianco=(255, 255, 255), med=(255, 140, 190), med_chiaro=(255, 214, 232))


def logo_b(W=2400, H=1300, pal=PAL_B, occhio_bagliore=None):
    img = tela(W, H)
    f_j = font('fredoka/Fredoka.ttf', 500, 700, 112)
    f_u = font('fredoka/Fredoka.ttf', 250, 700, 118)
    cx = W * 0.5
    con, bi = pal['contorno'], pal['bianco']
    # bolle e stelline dietro
    r = random.Random(4)
    for (bx, by, br) in [(0.12, 0.25, 50), (0.08, 0.42, 26), (0.90, 0.20, 40), (0.94, 0.37, 22), (0.86, 0.80, 30)]:
        m = Image.new('L', (W, H), 0)
        ImageDraw.Draw(m).ellipse((W * bx - br, H * by - br, W * bx + br, H * by + br), fill=255)
        dipingi(img, allarga(m, 9), con)
        dipingi(img, m, (150, 222, 240))
        ImageDraw.Draw(img).ellipse((W * bx - br * 0.5, H * by - br * 0.6, W * bx - br * 0.1, H * by - br * 0.2), fill=bi)
    # Jilly, le lettere saltellano; la i senza puntino (la medusa ci va sopra)
    testo = 'Jılly'
    salti = [0, -24, 8, -18, 10]
    rot = [-6, 4, -3, 5, -3]

    def piena(colore, lume):
        def f(dst, mm, xy, c):
            dipingi(dst, mm, colore, xy)
            # riflesso bianco in alto a sinistra, dentro la lettera
            ins = Image.fromarray((ndimage.binary_erosion(np.asarray(mm) > 128, iterations=16) * 255).astype(np.uint8))
            sp = ImageChops.subtract(ins, ImageChops.offset(ins, 10, 14))
            dipingi(dst, sp.filter(ImageFilter.GaussianBlur(1.5)), lume, xy)
        return f
    y_j = lambda x: H * 0.40 + 0.00004 * (x - cx) ** 2
    pezzi = lettere_su_curva(img, testo, f_j, cx - W * 0.33, cx + W * 0.29, y_j,
                             [(26, con), (0, piena(pal['j'], bi + (230,)))], rot_extra=rot, salti=salti,
                             spaziatura=-6, estrusione=(14, 26, 14, pal['j_ombra']))
    # JUBILEE sotto, ad arco che sorride
    y_u = lambda x: H * 0.72 - 0.00010 * (x - cx) ** 2
    lettere_su_curva(img, 'JUBILEE', f_u, cx - W * 0.30, cx + W * 0.30, y_u,
                     [(20, con), (0, piena(pal['u'], bi + (210,)))], rot_extra=[-4, 3, -3, 4, -2, 3, -4],
                     salti=[0, -10, 5, -8, 4, -6, 0], spaziatura=4, estrusione=(10, 18, 10, pal['u_ombra']))
    # la medusa al posto del puntino della i
    # la cima del gambo della i (senza puntino)
    _, m_i, ix, iy, ang = pezzi[1]
    cima = np.nonzero(np.asarray(m_i).max(1) > 128)[0][0]
    y_cima = iy - m_i.height / 2 + cima
    mw = 330
    mh = int(mw * 1.2)
    my = int(y_cima - mh * 0.72)
    med = medusa(mw, mh, pal['med'], pal['med_chiaro'], con, 7, seme=9, tentacoli=4)
    img.alpha_composite(med, (int(ix - mw / 2 + 12), my))
    # l'occhio vero, quello che stona
    _occhio(img, ix + 12, my + mh * 0.25, mw * 0.15, bagliore=occhio_bagliore)
    return img


# ---------------------------------------------------------------- C: rovinato dall'acqua
PAL_C = dict(j=(196, 112, 132), j_ombra=(40, 78, 86), u=(196, 170, 96), u_ombra=(122, 72, 44),
             contorno=(26, 30, 46), bianco=(214, 210, 200), med=(214, 120, 160), med_chiaro=(230, 190, 206))
GLOW = np.array([255, 70, 170], np.float32)


def logo_c(W=2400, H=1300, seme=31):
    base = logo_b(W, H, PAL_C, occhio_bagliore=(255, 80, 170))
    a = np.asarray(base, np.float32)
    rgb, al = a[..., :3], a[..., 3] / 255
    g = rng(seme)
    # acqua dall'alto: macchie con l'alone e sbiaditura a chiazze
    n = frattale(H, W, seme, (260, 90, 30))
    rgb = rgb * (0.78 + 0.22 * n[..., None])
    alone = np.abs(n - 0.55) < 0.012
    rgb[alone] *= 0.7
    # crepe
    cr = ndimage.zoom(crepe(H // 2, W // 2, 26, seme + 1, 1.1), 2, order=1)[:H, :W]
    cr *= np.clip(frattale(H, W, seme + 6, (300, 100)) * 2 - 0.6, 0, 1)
    rgb = rgb * (1 - 0.5 * cr[..., None])
    # pezzi caduti
    buchi = np.clip((frattale(H, W, seme + 2, (70, 25, 8)) - 0.74) * 16, 0, 1)
    al = al * (1 - buchi)
    # colature: dal bordo basso delle lettere scende il colore, lungo e sottile, con la goccia in fondo
    piena = al > 0.5
    fondo = piena & ~np.roll(piena, -3, axis=0)
    ys, xs = np.nonzero(fondo)
    sc = tela(W, H)
    d = ImageDraw.Draw(sc)
    tieni = (ys > H * 0.3) & (xs > W * 0.15) & (xs < W * 0.85)
    ys, xs = ys[tieni], xs[tieni]
    scelte = g.choice(len(ys), size=min(len(ys), 34), replace=False)
    for k in scelte:
        y, x = ys[k], xs[k]
        lung = min(g.uniform(50, 280), H - y - 60)
        if lung < 30:
            continue
        lg = g.uniform(14, 30)
        tinta = PAL_C['j'] if y < H * 0.58 else PAL_C['u']
        c = tuple(int(v * g.uniform(0.55, 0.8)) for v in tinta) + (215,)
        # una colatura: larga in alto, si stringe e ondeggia un po', goccia in fondo
        fase = g.uniform(0, 6.28)
        sx, dx_ = [], []
        for t in np.linspace(0, 1, 24):
            w = lg * (1.0 - 0.55 * t ** 0.6) / 2
            ox = 3 * math.sin(fase + t * 7)
            sx.append((x + ox - w, y - 6 + t * lung))
            dx_.append((x + ox + w, y - 6 + t * lung))
        d.polygon(sx + dx_[::-1], fill=c)
        e = lg * 0.42
        d.ellipse((x + ox - e, y + lung - e * 0.6, x + ox + e, y + lung + e * 1.4), fill=c)
    col = np.asarray(sc, np.float32)
    ca = col[..., 3:] / 255
    rgb = rgb * (1 - ca) * (al[..., None]) + col[..., :3] * ca + rgb * (1 - ca) * (1 - al[..., None])
    al = np.maximum(al, ca[..., 0])
    # muffa e sporco verso il basso
    muffa = np.clip((frattale(H, W, seme + 4, (50, 15, 5)) - 0.6) * 4, 0, 1) * np.linspace(0.2, 1, H)[:, None]
    rgb = rgb * (1 - 0.5 * muffa[..., None]) + np.array([40, 52, 38]) * 0.5 * muffa[..., None]
    lettere = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), al * 255]).astype(np.uint8), 'RGBA')
    # il bagliore rosa di lei, dietro e nei buchi
    alone_rosa = Image.fromarray((np.clip(al, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(60))
    out = tela(W, H)
    dipingi(out, alone_rosa.point(lambda v: int(v * 0.75)), tuple(int(c) for c in GLOW))
    out.alpha_composite(lettere)
    rosa_vicino = Image.fromarray((np.clip(al, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10))
    bordo = ImageChops.subtract(rosa_vicino, Image.fromarray((al * 255).astype(np.uint8)))
    dipingi(out, bordo.point(lambda v: min(255, v * 2)), (255, 110, 190))
    return out


# ---------------------------------------------------------------- uscite
def ritaglia(img, margine=20):
    bb = img.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    l, t, r, b = bb
    return img.crop((max(0, l - margine), max(0, t - margine), min(img.width, r + margine), min(img.height, b + margine)))


def su_scuro(logo, W, H, riempi=0.82, fondo=(14, 14, 18), alone=None):
    sfondo = Image.new('RGBA', (W, H), fondo + (255,))
    if alone is not None:
        g = Image.new('L', (W, H), 0)
        ImageDraw.Draw(g).ellipse((W * 0.2, H * 0.15, W * 0.8, H * 0.85), fill=alone)
        dipingi(sfondo, g.filter(ImageFilter.GaussianBlur(min(W, H) * 0.18)), (90, 20, 60))
    s = min(W * riempi / logo.width, H * riempi / logo.height)
    l = logo.resize((max(1, int(logo.width * s)), max(1, int(logo.height * s))), Image.LANCZOS)
    sfondo.alpha_composite(l, ((W - l.width) // 2, (H - l.height) // 2))
    return sfondo.convert('RGB')


def sul_titolo(logo, scatto):
    """Il logo nello spazio vuoto in alto a sinistra, sopra capitolo e voci del menu (x 56-560, y 30-255)."""
    t = Image.open(scatto).convert('RGBA')
    k = t.width / 1280
    box_w, box_h = 520 * k, 225 * k
    s = min(box_w / logo.width, box_h / logo.height)
    l = logo.resize((int(logo.width * s), int(logo.height * s)), Image.LANCZOS)
    t.alpha_composite(l, (int(56 * k + (box_w - l.width) / 2 - 10 * k), int(30 * k + (box_h - l.height) / 2)))
    return t.convert('RGB')


def main():
    os.makedirs(OUT, exist_ok=True)
    scatto = sys.argv[1] if len(sys.argv) > 1 and os.path.exists(sys.argv[1]) else None
    loghi = {'a': ritaglia(invecchia_a(logo_a())), 'b': ritaglia(logo_b()), 'c': ritaglia(logo_c(), 60)}
    for k, logo in loghi.items():
        logo.save(os.path.join(OUT, f'logo_{k}.png'))
        su_scuro(logo, 1600, 900, alone=60 if k == 'c' else None).save(os.path.join(OUT, f'logo_{k}_scuro.jpg'), quality=92)
        st = su_scuro(logo, 231, 87, 0.92, alone=60 if k == 'c' else None)
        st.save(os.path.join(OUT, f'steam_{k}.png'))
        st.resize((231 * 3, 87 * 3), Image.NEAREST).save(os.path.join(OUT, f'steam_{k}_x3.png'))
        if scatto:
            sul_titolo(logo, scatto).save(os.path.join(OUT, f'titolo_{k}.jpg'), quality=92)
        print('fatto', k, logo.size)


if __name__ == '__main__':
    main()
