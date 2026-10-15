"""Texture derivate dalle CC0 di ambientCG: colori dei tubi-scivolo, vernici delle pompe, quadrante dei
manometri, schema a colori delle pompe, pavimento bagnato, neve del monitor.

Uso: /home/user/tools/blender-venv/bin/python tools/blender/ambienti2_texture_derivate.py
Scrive in assets_src/ambienti_tecnici/texture/derivate/. Tutto deterministico (seed fisso).
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(QUI, '..', '..', 'assets_src', 'ambienti_tecnici', 'texture')
OUT = os.path.join(TEX, 'derivate')
rng = np.random.default_rng(7)

# Colori di riferimento (sRGB) condivisi da tutti gli script: vedi assets_src/ambienti_tecnici/README.md
COLORI_SCIVOLI = {   # allineati alle texture degli scivoli della sala (lavoro/ambiente, palette sala_a)
    'rosso': (178, 62, 45),
    'verde': (92, 142, 62),
    'blu': (45, 92, 155),
    'giallo': (205, 158, 55),
    'arancio': (240, 108, 58),
}
COLORI_POMPE = {'blu': (30, 90, 200), 'giallo': (235, 180, 20), 'rosso': (200, 30, 30)}


def carica(aid, mappa, size=None, mode='RGB'):
    im = Image.open(os.path.join(TEX, aid, f'{aid}_{mappa}.jpg')).convert(mode)
    return im.resize((size, size), Image.LANCZOS) if size else im


def arr(im):
    return np.asarray(im).astype(np.float32) / 255.0


def salva(a, nome, q=90):
    a = np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(a).save(os.path.join(OUT, nome), quality=q)


def rumore(size, scala, ottave=4, seed=0):
    """Rumore frattale tileable (somma di onde con frequenze intere)."""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size] / size
    acc = np.zeros((size, size), np.float32)
    amp = 1.0
    for o in range(ottave):
        f = scala * (2 ** o)
        for _ in range(6):
            fx, fy = r.integers(-f, f + 1, 2)
            ph = r.random() * 2 * math.pi
            acc += amp * np.sin(2 * math.pi * (fx * x + fy * y) + ph)
        amp *= 0.5
    acc -= acc.min(); acc /= acc.max()
    return acc


def scivoli():
    """Plastica colorata consumata. U = lungo il tubo, V = intorno (V=0.5 e' il fondo del tubo)."""
    S = 2048
    grana = arr(carica('Plastic006', 'Color', S, 'L'))
    grana = 0.85 + 0.3 * (grana - grana.mean())
    sporco = 0.35 + 0.5 * rumore(S, 3, 5, seed=17)
    ao = 0.7 + 0.3 * rumore(S, 5, 3, seed=19)
    rough_base = arr(carica('Plastic006', 'Roughness', S, 'L'))
    v = (np.mgrid[0:S, 0:S][0] / S).astype(np.float32)      # riga = V
    fondo = np.exp(-((v - 0.5) / 0.16) ** 2)                 # fascia bagnata sul fondo
    righe = rumore(S, 2, 3, seed=3)
    # striature lungo il tubo (l'acqua scorre in direzione U)
    stri = np.asarray(Image.fromarray((rumore(S, 6, 3, seed=5) * 255).astype(np.uint8)).resize((S, S // 32)).resize((S, S), Image.BILINEAR)).astype(np.float32) / 255
    stri = np.asarray(Image.fromarray((stri * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1))).astype(np.float32) / 255
    # graffi chiari: linee sottili lungo U
    graffi = Image.new('L', (S, S), 0); d = ImageDraw.Draw(graffi)
    for _ in range(260):
        y0 = rng.normal(0.5, 0.18) * S; x0 = rng.random() * S; L = rng.random() * 260 + 40
        d.line([(x0, y0), (x0 + L, y0 + rng.normal(0, 6))], fill=int(rng.random() * 120 + 60), width=1)
    graffi = arr(graffi.filter(ImageFilter.GaussianBlur(0.6)))
    for nome, c in COLORI_SCIVOLI.items():
        base = np.array(c, np.float32) / 255.0
        col = base[None, None, :] * grana[..., None]
        # scolorito dal sole/cloro sopra, sporco e calcare sul fondo
        sbiadito = 0.25 * (1 - fondo) * righe
        col = col * (1 - sbiadito[..., None]) + sbiadito[..., None] * np.array([0.8, 0.78, 0.72])
        sporco_m = np.clip((fondo * 0.75 + 0.35 * stri) * (1.2 - sporco) * 1.3 - 0.25, 0, 1)
        calcare = np.array([0.36, 0.33, 0.24])
        col = col * (1 - 0.8 * sporco_m[..., None]) + 0.8 * sporco_m[..., None] * calcare * sporco[..., None] * 1.3
        col = col * (0.6 + 0.4 * ao[..., None])
        col = col + graffi[..., None] * 0.35
        salva(col, f'scivolo_{nome}_Color.jpg')
    rough = np.clip(0.45 + 0.25 * (rough_base - 0.5) - 0.3 * fondo + 0.25 * stri * (1 - fondo), 0.08, 0.9)
    salva(np.repeat(rough[..., None], 3, 2), 'scivolo_Roughness.jpg')


def vernici_pompe():
    """PaintedMetal006 (verde scrostato con ruggine) ricolorato nei tre colori delle pompe."""
    im = carica('PaintedMetal006', 'Color').convert('HSV')
    h, s, v = [np.asarray(c).astype(np.float32) for c in im.split()]
    verde = (h > 60) & (h < 150) & (s > 60)
    for nome, c in COLORI_POMPE.items():
        hc, sc, vc = Image.new('RGB', (1, 1), c).convert('HSV').getpixel((0, 0))
        h2 = np.where(verde, hc, h); s2 = np.where(verde, np.minimum(255, s * 0.4 + sc * 0.6), s)
        v2 = np.where(verde, np.clip(v * (vc / 160.0), 0, 255), v)
        out = Image.merge('HSV', [Image.fromarray(x.astype(np.uint8)) for x in (h2, s2, v2)]).convert('RGB')
        out.save(os.path.join(OUT, f'vernice_{nome}_Color.jpg'), quality=90)


def manometro():
    S = 512
    im = Image.new('RGB', (S, S), (222, 214, 190)); d = ImageDraw.Draw(im)
    c = S / 2
    for i in range(41):
        a = math.radians(225 - i * 270 / 40)
        r1 = S * 0.42; r2 = S * (0.34 if i % 5 == 0 else 0.38)
        col = (170, 20, 20) if i > 32 else (20, 20, 20)
        d.line([(c + r1 * math.cos(a), c - r1 * math.sin(a)), (c + r2 * math.cos(a), c - r2 * math.sin(a))],
               fill=col, width=6 if i % 5 == 0 else 3)
    d.arc([S * 0.08, S * 0.08, S * 0.92, S * 0.92], -45 - 270 * 0 - 0, -45 + 0, fill=(170, 20, 20), width=10)
    # numeri generici di scala (scritta tecnica ammessa)
    for k, i in enumerate(range(0, 41, 10)):
        a = math.radians(225 - i * 270 / 40); r = S * 0.25
        d.text((c + r * math.cos(a) - 8, c - r * math.sin(a) - 8), str(k * 2), fill=(30, 30, 30), font_size=34)
    d.ellipse([c - 18, c - 18, c + 18, c + 18], fill=(25, 25, 25))
    a = np.asarray(im).astype(np.float32) / 255
    grime = rumore(S, 2, 4, seed=11)[..., None]
    y, x = np.mgrid[0:S, 0:S]; rr = np.hypot(x - c, y - c) / c
    a = a * (0.55 + 0.45 * (1 - grime * 0.8)) * (1 - 0.5 * np.clip(rr - 0.7, 0, 1)[..., None] * 3)
    a = a * np.array([1.0, 0.95, 0.82])
    salva(a, 'manometro_Color.jpg')


def schema_pompe():
    """Pannello dipinto sul muro: tre dischi colorati, puntini 1-2-3 e frecce. Niente testo.
    Ordine giusto: BLU (1) -> GIALLO (2) -> ROSSO (3). Le pompe nella sala, da sinistra: giallo, rosso, blu."""
    W, H = 2048, 1024
    im = Image.new('RGB', (W, H), (200, 196, 182)); d = ImageDraw.Draw(im)
    d.rectangle([20, 20, W - 20, H - 20], outline=(40, 40, 40), width=14)
    ordine = ['blu', 'giallo', 'rosso']
    xs = [380, 1024, 1668]
    for i, (nome, x) in enumerate(zip(ordine, xs)):
        c = COLORI_POMPE[nome]
        # sagoma di pompa stilizzata
        d.rounded_rectangle([x - 200, 300, x + 200, 640], 60, fill=c, outline=(30, 30, 30), width=12)
        d.ellipse([x - 120, 360, x + 120, 600], fill=tuple(int(v * 0.6) for v in c), outline=(30, 30, 30), width=10)
        for k in range(8):  # turbina
            a = k * math.pi / 4
            d.line([(x, 480), (x + 110 * math.cos(a), 480 + 110 * math.sin(a))], fill=(30, 30, 30), width=12)
        # puntini d'ordine
        for k in range(i + 1):
            px = x - (i * 70) / 2 + k * 70
            d.ellipse([px - 26, 720, px + 26, 772], fill=(25, 25, 25))
        if i < 2:
            ax = x + 225
            d.polygon([(ax, 455), (ax + 110, 455), (ax + 110, 405), (ax + 190, 480), (ax + 110, 555), (ax + 110, 505), (ax, 505)], fill=(30, 30, 30))
    # leva finale, a destra: freccia in alto verso la leva
    d.polygon([(1900, 300), (1940, 160), (1980, 300)], fill=(30, 30, 30))
    a = np.asarray(im).astype(np.float32) / 255
    vern = arr(carica('PaintedMetal006', 'Color', None, 'L').resize((W, H)))
    rug = arr(carica('Rust004', 'Color').resize((W, H)))
    m = np.clip((rumore(1024, 2, 5, seed=21) - 0.62) * 4, 0, 1)
    m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
    a = a * (0.75 + 0.35 * vern[..., None])
    a = a * (1 - m[..., None]) + rug * m[..., None]
    colature = np.asarray(Image.fromarray((rumore(1024, 3, 3, seed=4) * 255).astype(np.uint8)).resize((W // 16, H // 2)).resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
    a = a * (0.65 + 0.35 * colature[..., None])
    salva(a, 'schema_pompe_Color.jpg')


def pavimento_bagnato():
    """Roughness del pavimento con pozzanghere (per le piastrelle Tiles107 sporche)."""
    S = 2048
    r = arr(carica('Tiles107', 'Roughness', S, 'L'))
    poz = np.clip((rumore(S, 1, 5, seed=9) - 0.55) * 5, 0, 1)
    rough = r * (1 - poz) * 0.9 + 0.06 * poz
    salva(np.repeat(rough[..., None], 3, 2), 'pavimento_bagnato_Roughness.jpg')
    col = arr(carica('Tiles107', 'Color', S))
    sp = arr(carica('Concrete042C', 'Color', S))
    m = rumore(S, 2, 4, seed=13)[..., None]
    col = col * (0.35 + 0.25 * m) * np.array([0.95, 1.0, 0.98]) + sp * 0.25 * (1 - m)
    col = col * (1 - 0.35 * poz[..., None])
    salva(col, 'pavimento_sporco_Color.jpg')


def piastrelle_sporche():
    """Tiles133D invecchiate: piu' scure, ingiallite, con colature verticali di ruggine e muffa."""
    im = carica('Tiles133D', 'Color')
    S = im.size[0]
    col = arr(im)
    m = rumore(512, 2, 5, seed=31)
    m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((S, S), Image.BILINEAR)).astype(np.float32) / 255
    col_ = np.asarray(Image.fromarray((rumore(512, 4, 3, seed=33) * 255).astype(np.uint8)).resize((S // 24, S // 3)).resize((S, S), Image.BICUBIC)).astype(np.float32) / 255
    colature = np.clip((col_ - 0.45) * 2.2, 0, 1)
    ingiallito = np.array([0.86, 0.8, 0.66])
    out = col * ingiallito * (0.42 + 0.3 * m[..., None])
    rug = np.array([0.32, 0.17, 0.08]); muffa = np.array([0.16, 0.18, 0.12])
    out = out * (1 - 0.55 * colature[..., None]) + 0.55 * colature[..., None] * (rug * 0.6 + muffa * 0.4) * (0.5 + m[..., None])
    salva(out, 'piastrelle_sporche_Color.jpg')
    r = arr(carica('Tiles133D', 'Roughness', None, 'L'))
    salva(np.repeat(np.clip(r * 0.8 + 0.25 * colature - 0.1 * m, 0.05, 1)[..., None], 3, 2), 'piastrelle_sporche_Roughness.jpg')


def neve_crt():
    S = 512
    n = rng.random((S // 2, S // 2)).astype(np.float32)
    n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((S, S), Image.NEAREST)).astype(np.float32) / 255
    righe = 0.75 + 0.25 * np.sin(np.arange(S) * math.pi / 2)[:, None]
    a = np.clip(n * righe * 0.9, 0, 1)
    a = np.stack([a * 0.85, a * 0.95, a], -1)
    salva(a, 'crt_neve_Color.jpg')


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    scivoli(); vernici_pompe(); manometro(); schema_pompe(); pavimento_bagnato(); neve_crt(); piastrelle_sporche()
    print(sorted(os.listdir(OUT)))
