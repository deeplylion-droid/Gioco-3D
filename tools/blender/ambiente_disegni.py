"""Texture disegnate (PIL) per i pezzi della sala scelti dall'utente il 16 ottobre 2026: le strisce gialle e
nere (bande ai lati del portone della sala della torre) e il portone scorrevole con la torre dipinta.
Sono le stesse delle proposte approvate (tools/blender/proposte_sala.py sul branch lavoro/proposte-sala):
stesso disegno, stessi semi per lo sporco. Nessuna scritta.

Scrive in assets_src/ambiente/textures/disegnate/ (le usa ambiente_sala.py):
  strisce_col.jpg          1024 x 1024, strisce a 45 gradi con il centro in metallo scuro
  insegna_torre_col.jpg    2048 x 640, la torre con i tubi che scendono all'acqua (serve al portone)
  portone_torre_col.jpg    1536 x 1280, lamiera grecata gialla, bande a strisce, la torre al centro
Uso: /home/user/tools/blender-venv/bin/python tools/blender/ambiente_disegni.py
"""
import math, os

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
CARTELLA = os.path.join(RADICE, 'assets_src', 'ambiente', 'textures', 'disegnate')
FILE = {'strisce': 'strisce_col.jpg', 'insegna_torre': 'insegna_torre_col.jpg', 'portone': 'portone_torre_col.jpg'}


def percorso(nome):
    return os.path.join(CARTELLA, FILE[nome])


def _rumore(im, forza=18, seme=3):
    """Un po' di sporco e graffi: le texture nuove non devono sembrare appena stampate."""
    from PIL import Image, ImageFilter
    import numpy as np
    rng = np.random.default_rng(seme)
    a = np.asarray(im).astype(np.float32)
    n = rng.normal(0, 1, (a.shape[0] // 8 + 1, a.shape[1] // 8 + 1)).astype(np.float32)
    n = np.asarray(Image.fromarray(((n - n.min()) / (n.max() - n.min()) * 255).astype(np.uint8)).resize(
        (a.shape[1], a.shape[0]), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
    a *= (1.0 - forza / 255 * 3 * (n[..., None] - 0.3).clip(0, 1))
    for _ in range(60):   # graffi chiari
        x, y = rng.integers(0, a.shape[1]), rng.integers(0, a.shape[0])
        L = rng.integers(10, 60); ang = rng.uniform(0, math.pi)
        for t in range(L):
            xx, yy = int(x + math.cos(ang) * t), int(y + math.sin(ang) * t)
            if 0 <= xx < a.shape[1] and 0 <= yy < a.shape[0]:
                a[yy, xx] = a[yy, xx] * 0.6 + 200 * 0.4
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def disegna_strisce(p, N=1024):
    """Quadrato a strisce gialle e nere a 45 gradi (fascia di N/4), centro in metallo scuro."""
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (N, N), (242, 183, 5))
    d = ImageDraw.Draw(im)
    passo = N // 8
    for k in range(-N, 2 * N, passo):
        d.polygon([(k, 0), (k + passo // 2, 0), (k + passo // 2 - N, N), (k - N, N)], fill=(22, 22, 22))
    f = N // 4
    d.rectangle([f, f, N - f, N - f], fill=(48, 52, 54))
    d.rectangle([f - 10, f - 10, N - f + 10, N - f + 10], outline=(20, 20, 20), width=14)
    d.rectangle([4, 4, N - 5, N - 5], outline=(20, 20, 20), width=10)
    for (x, y) in ((f // 2, f // 2), (N - f // 2, f // 2), (f // 2, N - f // 2), (N - f // 2, N - f // 2)):
        d.ellipse([x - 18, y - 18, x + 18, y + 18], fill=(150, 150, 140), outline=(30, 30, 30), width=4)
    _rumore(im, 14, 5).save(p, quality=92)


def disegna_insegna_torre(p, W=2048, H=640):
    """La torre degli scivoli con il tubo che scende fino all'acqua, sui colori del parco (blu, giallo,
    rosso). Senza scritte. Sta dipinta al centro del portone."""
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (W, H), (250, 196, 30))
    d = ImageDraw.Draw(im)
    BLU, ROSSO, NERO, BIANCO, ACQUA = (24, 92, 170), (206, 40, 30), (20, 24, 28), (250, 248, 240), (40, 170, 220)
    d.rounded_rectangle([12, 12, W - 12, H - 12], radius=60, outline=NERO, width=16)
    d.rounded_rectangle([44, 44, W - 44, H - 44], radius=44, outline=BLU, width=14)
    for k in range(0, W, 90):   # onde in basso
        d.arc([k, H - 170, k + 90, H - 110], 0, 180, fill=ACQUA, width=18)
        d.arc([k + 45, H - 130, k + 135, H - 70], 0, 180, fill=BLU, width=14)
    cx = W // 2   # torre al centro
    for sx in (-1, 1):
        d.line([(cx + sx * 110, H - 150), (cx + sx * 80, 120)], fill=NERO, width=26)
    for yy in (430, 330, 230, 140):
        w = 80 + (yy - 120) * 30 / 330
        d.rectangle([cx - w - 20, yy - 14, cx + w + 20, yy + 14], fill=ROSSO, outline=NERO, width=6)
    d.polygon([(cx - 120, 140), (cx + 120, 140), (cx, 70)], fill=ROSSO, outline=NERO)
    for sx, col in ((-1, BLU), (1, ROSSO)):   # tubi che scendono dai due lati fino all'acqua
        pts = []
        for i in range(60):
            t = i / 59
            x = cx + sx * (130 + 720 * t)
            y = 150 + (H - 300) * (t ** 0.8) + 40 * math.sin(t * math.pi * 3)
            pts.append((x, y))
        d.line(pts, fill=NERO, width=86, joint='curve')
        d.line(pts, fill=col, width=62, joint='curve')
        d.line([(q[0], q[1] - 12) for q in pts], fill=BIANCO, width=10, joint='curve')
        ex, ey = pts[-1]
        for k in range(5):   # spruzzi all'arrivo
            a = math.radians(200 + 35 * k) if sx < 0 else math.radians(-20 - 35 * k)
            d.line([(ex + math.cos(a) * 60, ey + math.sin(a) * 60), (ex + math.cos(a) * 110, ey + math.sin(a) * 110)], fill=ACQUA, width=14)
    for (x, y) in ((260, 150), (W - 260, 150), (420, 90), (W - 420, 90)):   # stelle
        pts = []
        for k in range(10):
            r = 34 if k % 2 == 0 else 14
            a = math.radians(-90 + k * 36)
            pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
        d.polygon(pts, fill=BIANCO, outline=NERO)
    _rumore(im, 12, 9).save(p, quality=92)


def disegna_lamiera_portone(p, W=1536, H=1280):
    """Portone scorrevole: lamiera grecata gialla sbiadita, bande a strisce sui bordi, al centro la
    torre con gli scivoli dipinta grande (senza scritte)."""
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (W, H), (214, 170, 52))
    d = ImageDraw.Draw(im)
    for k in range(0, W, 48):   # nervature della lamiera
        d.rectangle([k, 0, k + 10, H], fill=(176, 136, 40))
        d.rectangle([k + 10, 0, k + 14, H], fill=(236, 196, 92))
    NERO = (24, 24, 24)
    for (y0, y1) in ((0, 110), (H - 110, H)):
        for k in range(-W, 2 * W, 96):
            d.polygon([(k, y0), (k + 48, y0), (k + 48 + (y1 - y0), y1), (k + (y1 - y0), y1)], fill=NERO)
    ins = Image.open(percorso('insegna_torre')).resize((W - 220, int((W - 220) * 640 / 2048)))
    im.paste(ins, (110, (H - ins.size[1]) // 2))
    _rumore(im, 26, 11).save(p, quality=90)


def disegna_tutto(forza=False):
    """Disegna le texture che mancano (o tutte, con forza=True). Restituisce la cartella."""
    os.makedirs(CARTELLA, exist_ok=True)
    for nome, funz in (('strisce', disegna_strisce), ('insegna_torre', disegna_insegna_torre),
                       ('portone', disegna_lamiera_portone)):
        if forza or not os.path.exists(percorso(nome)):
            funz(percorso(nome))
            print('disegnata', percorso(nome))
    return CARTELLA


if __name__ == '__main__':
    disegna_tutto(forza=True)
