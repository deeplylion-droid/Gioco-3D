"""La texture degli scatoloni delle pile del fiume lento (riscontro dell'utente sulla v0.3.11, punti 4 e 7): cartone
marrone con le fibre, gli spigoli più scuri, il nastro da pacchi e i pittogrammi da magazzino (ombrello "teme
l'umidità", bicchiere "fragile"), senza scritte. Una texture per le sei facce di una BoxMesh di Godot, nella sua griglia
3 x 2 (ogni cella una faccia, con l'alto della faccia in alto: vedi CELLE). Il colore lo dà il MultiMesh (un marrone
diverso per ogni scatolone), quindi qui il cartone è chiaro.
Uso: /home/user/tools/blender-venv/bin/python assets_src/fiume_lento/scatoloni/genera_texture.py
Uscita: godot/assets/fiume_lento/texture/scatolone_pile.jpg e cassa_pile.jpg (le casse di plastica blu del piano di
sotto, i pesanti sotto), 1536 x 1024"""
import os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.abspath(os.path.join(QUI, '..', '..', '..'))
USCITA = os.path.join(RADICE, 'godot', 'assets', 'fiume_lento', 'texture', 'scatolone_pile.jpg')
USCITA_CASSE = os.path.join(RADICE, 'godot', 'assets', 'fiume_lento', 'texture', 'cassa_pile.jpg')
# gli scatoloni colorati del parco (richiesta dell'utente del 24 ottobre: "dalle multicolore, dobbiamo riprendere il tema
# giocoso ogni tanto, per fare contrasto con l'horror"): cartone verniciato chiaro, il colore lo dà il MultiMesh
USCITA_COLORATI = os.path.join(RADICE, 'godot', 'assets', 'fiume_lento', 'texture', 'scatolone_colorato_pile.jpg')
C = 512                       # lato di una cella
# per ogni cella (colonna, riga): quale faccia è e di quanti gradi va girato il disegno (0 = l'alto in alto)
CELLE = {(0, 0): ('lato', 0), (1, 0): ('lato', 0), (2, 0): ('sopra', 0),
         (0, 1): ('lato', 0), (1, 1): ('lato', 0), (2, 1): ('sopra', 0)}
rnd = random.Random(1023)


def cartone(w, h):
    """Cartone ondulato chiaro: rumore a righe (le onde viste attraverso la carta) e macchie."""
    base = np.full((h, w, 3), (205, 168, 120), dtype=np.float32)
    righe = np.sin(np.arange(w) / w * np.pi * 2 * 90)[None, :, None] * 3.0
    rumore = np.random.default_rng(7).normal(0, 6, (h, w, 1))
    macchie = np.array(Image.fromarray(np.random.default_rng(3).integers(0, 255, (h // 32, w // 32), dtype=np.uint8))
                       .resize((w, h), Image.BICUBIC), dtype=np.float32)[:, :, None]
    img = base + righe + rumore - (macchie - 128) * 0.05
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def bordi(img):
    """Gli spigoli più scuri e un po' consumati."""
    w, h = img.size
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    for k in range(18):
        d.rectangle((k, k, w - 1 - k, h - 1 - k), outline=int(120 * (1 - k / 18) ** 2))
    m = m.filter(ImageFilter.GaussianBlur(3))
    scuro = Image.new('RGB', (w, h), (90, 66, 40))
    return Image.composite(scuro, img, m)


def nastro(img, verticale=False):
    w, h = img.size
    d = ImageDraw.Draw(img, 'RGBA')
    l = int(min(w, h) * 0.16)
    if verticale:
        d.rectangle((w // 2 - l // 2, 0, w // 2 + l // 2, h), fill=(222, 196, 150, 150))
    else:
        d.rectangle((0, 0, w, int(l * 0.9)), fill=(222, 196, 150, 150))   # il nastro che chiude il coperchio, in alto
    return img


def ombrello(d, x, y, s, col):
    d.pieslice((x - s, y - s, x + s, y + s), 180, 360, fill=col)
    d.line((x, y, x, y + s * 1.1), fill=col, width=max(3, s // 8))
    d.arc((x - s * 0.35, y + s * 0.85, x + s * 0.05, y + s * 1.35), 0, 180, fill=col, width=max(3, s // 8))
    for k in range(4):   # le gocce
        gx = x - s + k * s * 0.66
        d.line((gx, y - s * 1.5, gx - s * 0.12, y - s * 1.2), fill=col, width=max(3, s // 9))


def bicchiere(d, x, y, s, col):
    d.polygon([(x - s * 0.55, y - s), (x + s * 0.55, y - s), (x + s * 0.2, y), (x - s * 0.2, y)], outline=col, width=max(3, s // 8))
    d.line((x, y, x, y + s * 0.8), fill=col, width=max(3, s // 8))
    d.line((x - s * 0.4, y + s * 0.8, x + s * 0.4, y + s * 0.8), fill=col, width=max(3, s // 8))
    d.line((x + s * 0.05, y - s, x - s * 0.1, y - s * 0.6, x + s * 0.12, y - s * 0.4), fill=col, width=max(2, s // 12))   # la crepa


def frecce(d, x, y, s, col):
    for dx in (-s * 0.45, s * 0.45):
        d.line((x + dx, y + s, x + dx, y - s * 0.4), fill=col, width=max(4, s // 6))
        d.polygon([(x + dx - s * 0.35, y - s * 0.3), (x + dx + s * 0.35, y - s * 0.3), (x + dx, y - s)], fill=col)
    d.line((x - s * 0.9, y + s * 1.15, x + s * 0.9, y + s * 1.15), fill=col, width=max(4, s // 6))


def faccia(tipo):
    img = bordi(cartone(C, C))
    if tipo == 'sopra':
        return nastro(img, verticale=True)
    img = nastro(img)
    d = ImageDraw.Draw(img)
    inchiostro = (60, 45, 35)
    # i pittogrammi in un riquadro, in basso a destra (stampati sul cartone)
    d.rectangle((C * 0.52, C * 0.55, C * 0.92, C * 0.86), outline=inchiostro, width=4)
    ombrello(d, int(C * 0.62), int(C * 0.71), int(C * 0.05), inchiostro)
    bicchiere(d, int(C * 0.73), int(C * 0.71), int(C * 0.06), inchiostro)
    frecce(d, int(C * 0.84), int(C * 0.7), int(C * 0.06), inchiostro)
    return img


def onda(d, x, y, s, col):
    """Un'onda del parco: tre creste arricciate."""
    w = max(6, s // 7)
    for k in range(3):
        cx = x - s + k * s
        d.arc((cx - s * 0.5, y - s * 0.5, cx + s * 0.5, y + s * 0.5), 180, 360, fill=col, width=w)
        d.arc((cx + s * 0.1, y - s * 0.55, cx + s * 0.45, y - s * 0.2), 90, 300, fill=col, width=w)
    d.line((x - s * 1.5, y + s * 0.15, x + s * 1.5, y + s * 0.15), fill=col, width=w)


def stella(d, x, y, s, col):
    import math
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = s if k % 2 == 0 else s * 0.42
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
    d.polygon(pts, fill=col)


def paperella(d, x, y, s, col):
    """La sagoma di una paperella di gomma, girata a destra."""
    d.ellipse((x - s, y - s * 0.35, x + s * 0.7, y + s * 0.55), fill=col)            # il corpo
    d.ellipse((x + s * 0.05, y - s * 0.95, x + s * 0.65, y - s * 0.3), fill=col)     # la testa
    d.polygon([(x + s * 0.6, y - s * 0.7), (x + s * 1.0, y - s * 0.6), (x + s * 0.62, y - s * 0.48)], fill=col)   # il becco
    d.polygon([(x - s, y - s * 0.1), (x - s * 1.25, y - s * 0.45), (x - s * 0.8, y - s * 0.2)], fill=col)          # la coda


def cerchi(d, x, y, s, col):
    """Tre cerchi concentrici, come un bersaglio."""
    for k, r in enumerate((1.0, 0.66, 0.32)):
        d.ellipse((x - s * r, y - s * r, x + s * r, y + s * r), outline=col, width=max(8, s // 6))


def pois(d, x, y, s, col):
    """I pois, a quinconce su tutta la faccia."""
    passo = C // 5
    for r in range(6):
        for c in range(6):
            cx = c * passo + (passo // 2 if r % 2 else 0)
            cy = r * passo + passo // 3
            d.ellipse((cx - s * 0.28, cy - s * 0.28, cx + s * 0.28, cy + s * 0.28), fill=col)


def niente(d, x, y, s, col):
    pass


def colorato(tipo, disegno):
    """Cartone verniciato chiaro (lo tinge il MultiMesh), sporco e consumato agli spigoli, col nastro; sui lati un
    disegno semplice in bianco sbiadito (una stella, i pois, i cerchi), niente scritte; un velo di polvere."""
    w = h = C
    base = np.full((h, w, 3), (196, 192, 186), dtype=np.float32)   # più scuro del bianco dei disegni: si leggono
    rumore = np.random.default_rng(17).normal(0, 5, (h, w, 1))
    macchie = np.array(Image.fromarray(np.random.default_rng(19).integers(0, 255, (h // 64, w // 64), dtype=np.uint8))
                       .resize((w, h), Image.BICUBIC), dtype=np.float32)[:, :, None]
    img = Image.fromarray(np.clip(base + rumore - (macchie - 128) * 0.035, 0, 255).astype(np.uint8))
    img = bordi(img)
    if tipo == 'sopra':
        return nastro(img, verticale=True)
    img = nastro(img)
    d = ImageDraw.Draw(img, 'RGBA')
    bianco = (255, 255, 252, 235)
    {'onda': onda, 'stella': stella, 'paperella': paperella, 'cerchi': cerchi, 'pois': pois, 'niente': niente}[disegno](
        d, int(C * 0.5), int(C * 0.6), int(C * 0.17), bianco)
    # un velo di polvere chiara, a chiazze larghe (consumate, non sporche)
    polvere = np.array(Image.fromarray(np.random.default_rng(23).integers(0, 255, (8, 8), dtype=np.uint8))
                       .resize((C, C), Image.BICUBIC), dtype=np.float32)[:, :, None] / 255.0
    arr = np.array(img, dtype=np.float32)
    arr = arr * (1 - polvere * 0.1) + 215 * polvere * 0.1
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return img


def cassa(tipo):
    """Una cassa di plastica blu: costole in rilievo e le feritoie (lato), il bordo e la griglia (sopra)."""
    img = Image.new('RGB', (C, C), (38, 86, 160))
    d = ImageDraw.Draw(img)
    rum = np.random.default_rng(11).normal(0, 4, (C, C, 1))
    img = Image.fromarray(np.clip(np.array(img, dtype=np.float32) + rum, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    scuro, chiaro = (20, 48, 98), (70, 120, 196)
    d.rectangle((0, 0, C - 1, C - 1), outline=scuro, width=14)
    if tipo == 'sopra':
        for k in range(1, 8):
            d.line((k * C // 8, 20, k * C // 8, C - 20), fill=scuro, width=6)
            d.line((20, k * C // 8, C - 20, k * C // 8), fill=scuro, width=6)
        return img
    d.rectangle((0, 0, C - 1, int(C * 0.12)), fill=chiaro)          # il bordo alto della cassa
    for k in range(1, 6):                                           # le costole verticali
        x = k * C // 6
        d.rectangle((x - 7, int(C * 0.12), x + 7, C - 1), fill=chiaro)
    for r in range(3):                                              # le feritoie
        for k in range(6):
            x0 = k * C // 6 + 16
            y0 = int(C * 0.22) + r * int(C * 0.24)
            d.rounded_rectangle((x0, y0, x0 + C // 6 - 32, y0 + int(C * 0.14)), radius=8, fill=scuro)
    d.rounded_rectangle((C * 0.35, C * 0.03, C * 0.65, C * 0.09), radius=10, fill=scuro)   # la maniglia
    return img


tex = Image.new('RGB', (C * 3, C * 2))
for (cx, cy), (tipo, gradi) in CELLE.items():
    tex.paste(faccia(tipo).rotate(gradi), (cx * C, cy * C))
os.makedirs(os.path.dirname(USCITA), exist_ok=True)
tex.save(USCITA, quality=90)
print('scritta', USCITA)
tex = Image.new('RGB', (C * 3, C * 2))
for (cx, cy), (tipo, gradi) in CELLE.items():
    tex.paste(cassa(tipo).rotate(gradi), (cx * C, cy * C))
tex.save(USCITA_CASSE, quality=90)
print('scritta', USCITA_CASSE)
# gli scatoloni colorati: su ogni lato un disegno diverso (una stella, i pois, i cerchi, niente), come giocattoli
tex = Image.new('RGB', (C * 3, C * 2))
disegni = {(0, 0): 'stella', (1, 0): 'pois', (0, 1): 'cerchi', (1, 1): 'niente'}
for (cx, cy), (tipo, gradi) in CELLE.items():
    tex.paste(colorato(tipo, disegni.get((cx, cy), 'stella')).rotate(gradi), (cx * C, cy * C))
tex.save(USCITA_COLORATI, quality=90)
print('scritta', USCITA_COLORATI)
