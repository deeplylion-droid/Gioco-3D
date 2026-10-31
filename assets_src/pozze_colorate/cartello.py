"""Il cartello di divieto d'accesso accanto alla porta nord dell'infermeria, l'indizio della stanza delle pozze colorate
(GDD, "La stanza delle pozze colorate", scelta A dell'utente del 31 ottobre): il cartello del parco (cerchio rosso con la
barra bianca, sotto la sagoma di un bambino con la mano alzata) e sopra, disegnati a pastello dai bambini, tre
quadratini pieni dei 3 colori giusti (EnigmaPozze.GIUSTI: turchese, viola, arancione), come tre pozze. Nessuna scritta.

Il cartello è smalto bianco su lamiera, invecchiato (graffi, scheggiature con la lamiera scura sotto, ruggine alle viti,
sporco che scende); i quadratini sono cera di pastello a tratto grosso, col riempimento storto dei bambini, fatti con lo
stesso pastello degli scarabocchi sui muri (assets_src/scarabocchi/pastello.py). I colori dei pastelli sono quelli
delle pozze, un po' spenti: si devono riconoscere a colpo d'occhio sotto la lampadina bianca.
Texture del gioco (non un concept): 34 x 46 cm, mezzo millimetro per pixel.
Uso: /home/user/tools/blender-venv/bin/python cartello.py [uscita.png]
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '..', 'scarabocchi'))
from pastello import Pastello, rumore  # noqa: E402

USCITA = os.path.join(QUI, '..', '..', 'godot', 'assets', 'pozze_colorate', 'cartello_divieto.png')
MM = 0.5                       # millimetri per pixel
W, H = int(340 / MM), int(460 / MM)
SEME = 31

# i pastelli dei tre colori giusti (le pozze: WaterMix.TURCHESE, VIOLA, ARANCIONE), cera un po' spenta
TURCHESE = (24, 172, 162)
VIOLA = (120, 52, 168)
ARANCIONE = (232, 108, 22)

SMALTO = np.array([238, 234, 222], np.float32)
ROSSO = (196, 28, 34)
BLU_SAGOMA = (28, 44, 92)
LAMIERA = np.array([84, 80, 76], np.float32)
RUGGINE = np.array([122, 62, 30], np.float32)


def px(mm):
    return int(round(mm / MM))


def lastra():
    """Lo smalto bianco col bordo arrotondato e il filo grigio, il disco rosso con la barra, la sagoma del bambino."""
    im = Image.new('RGB', (W, H), tuple(int(v) for v in SMALTO))
    d = ImageDraw.Draw(im)
    # il filo grigio stampato a 8 mm dal bordo
    d.rounded_rectangle([px(8), px(8), W - px(8), H - px(8)], radius=px(14), outline=(150, 150, 146), width=px(2.5))
    # il divieto d'accesso: disco rosso, barra bianca
    cx, cy, r = W // 2, px(125), px(78)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ROSSO)
    bw, bh = px(108), px(26)
    d.rectangle([cx - bw // 2, cy - bh // 2, cx + bw // 2, cy + bh // 2], fill=tuple(int(v) for v in SMALTO))
    # la sagoma del bambino con la mano alzata, ferma (la mano aperta in alto a destra)
    sy = px(222)
    testa = px(15)
    d.ellipse([cx - testa, sy, cx + testa, sy + 2 * testa], fill=BLU_SAGOMA)
    collo = sy + 2 * testa + px(3)
    busto = [(cx - px(17), collo), (cx + px(17), collo), (cx + px(22), collo + px(52)), (cx - px(22), collo + px(52))]
    d.polygon(busto, fill=BLU_SAGOMA)
    # le gambe
    for lato in (-1, 1):
        x0 = cx + lato * px(4)
        x1 = cx + lato * px(18)
        d.polygon([(x0, collo + px(50)), (x1, collo + px(50)), (x1 + lato * px(2), collo + px(96)),
                   (x0 + lato * px(1), collo + px(96))], fill=BLU_SAGOMA)
        d.ellipse([min(x0, x1) - px(2) + lato * px(3), collo + px(91), max(x0, x1) + px(4) + lato * px(3),
                   collo + px(101)], fill=BLU_SAGOMA)
    # il braccio giù a sinistra
    d.line([(cx - px(15), collo + px(5)), (cx - px(30), collo + px(38)), (cx - px(29), collo + px(55))],
           fill=BLU_SAGOMA, width=px(9.5), joint='curve')
    # il braccio alzato a destra con la mano aperta (il palmo verso chi guarda)
    gomito = (cx + px(37), collo + px(8))
    polso = (cx + px(44), collo - px(26))
    d.line([(cx + px(13), collo + px(5)), gomito, polso], fill=BLU_SAGOMA, width=px(9.5), joint='curve')
    d.ellipse([polso[0] - px(10), polso[1] - px(14), polso[0] + px(10), polso[1] + px(6)], fill=BLU_SAGOMA)
    for k, (dx, lung) in enumerate([(-8, 12), (-3, 16), (2, 17), (7, 15)]):
        x = polso[0] + px(dx)
        d.line([(x, polso[1] - px(8)), (x + px(dx * 0.15), polso[1] - px(8 + lung))], fill=BLU_SAGOMA, width=px(4.2))
    d.line([(polso[0] + px(9), polso[1] - px(2)), (polso[0] + px(17), polso[1] - px(10))], fill=BLU_SAGOMA, width=px(4.2))
    # le quattro viti
    for vx, vy in ((px(20), px(20)), (W - px(20), px(20)), (px(20), H - px(20)), (W - px(20), H - px(20))):
        d.ellipse([vx - px(5), vy - px(5), vx + px(5), vy + px(5)], fill=(150, 148, 140), outline=(90, 88, 84), width=2)
        d.line([vx - px(3.5), vy - px(1), vx + px(3.5), vy + px(1)], fill=(80, 78, 74), width=2)
    return im


def quadratini():
    """I tre quadratini dei bambini, a pastello: il contorno ripassato e il riempimento storto che esce un po'."""
    p = Pastello(W, H, SEME, mm=MM)
    rng = np.random.default_rng(SEME + 5)
    lato = px(54)
    y0 = px(405)
    for i, c in enumerate((VIOLA, ARANCIONE, TURCHESE)):
        cx = W // 2 + (i - 1) * px(92) + rng.normal(0, px(3))
        cy = y0 + rng.normal(0, px(4))
        a = rng.normal(0, 0.06)
        ang = [a + math.pi / 4 + k * math.pi / 2 for k in range(4)]
        rr = lato / math.sqrt(2)
        poli = [(cx + rr * (1 + rng.normal(0, 0.05)) * math.cos(t), cy + rr * (1 + rng.normal(0, 0.05)) * math.sin(t))
                for t in ang]
        p.riempi(poli, c, larg_mm=7.0, passo_mm=4.2, pressione=245)
        p.tratto(poli + [poli[0], poli[1]], c, larg_mm=6.0, volte=2, trem=0.8, pressione=250)
    return p.finisci(bagnato=0.15, sbiadito=0.0)


def invecchia(im):
    """Graffi, scheggiature dello smalto con la lamiera sotto, ruggine alle viti e sul bordo, sporco che scende."""
    a = np.asarray(im, np.float32)
    rng = np.random.default_rng(SEME + 9)
    # lo sporco: più in basso e ai bordi, a macchie larghe
    macchie = rumore((H, W), SEME + 11, 40)
    giu = np.linspace(0.15, 0.6, H, dtype=np.float32)[:, None]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    bordo = np.clip(1.0 - np.minimum.reduce([xx, yy, W - 1 - xx, H - 1 - yy]) / px(30), 0, 1)
    sporco = np.clip(macchie * 0.55 * giu + bordo * 0.35, 0, 0.6)
    a = a * (1 - sporco[..., None] * 0.35) + np.array([96, 88, 70], np.float32) * sporco[..., None] * 0.35
    # le scheggiature: macchie piccole con la lamiera scura, il bordo appena arrugginito
    sch = Image.new('L', (W, H), 0)
    ds = ImageDraw.Draw(sch)
    for _ in range(12):
        # vicino ai bordi, dove la lamiera si piega e lo smalto salta
        if rng.random() < 0.5:
            x = int(rng.choice([rng.integers(0, px(22)), rng.integers(W - px(22), W)]))
            y = int(rng.integers(0, H))
        else:
            x = int(rng.integers(0, W))
            y = int(rng.choice([rng.integers(0, px(22)), rng.integers(H - px(22), H)]))
        r = rng.uniform(px(1.0), px(3.5))
        pts = [(x + r * (1 + rng.normal(0, 0.35)) * math.cos(t), y + r * (1 + rng.normal(0, 0.35)) * math.sin(t))
               for t in np.linspace(0, 2 * math.pi, 9)[:-1]]
        ds.polygon(pts, fill=255)
    for vx, vy in ((px(20), px(20)), (W - px(20), px(20)), (px(20), H - px(20)), (W - px(20), H - px(20))):
        ds.ellipse([vx - px(8), vy - px(8), vx + px(8), vy + px(8)], fill=110)
    m = np.asarray(sch.filter(ImageFilter.GaussianBlur(1.0)), np.float32) / 255.0
    alone = np.asarray(sch.filter(ImageFilter.GaussianBlur(px(4))), np.float32) / 255.0
    a = a * (1 - np.clip(alone * 0.8, 0, 0.5)[..., None]) + RUGGINE * np.clip(alone * 0.8, 0, 0.5)[..., None]
    a = a * (1 - m[..., None]) + LAMIERA * m[..., None]
    # le colature di ruggine sotto le viti in basso e in alto
    for vx, vy in ((px(20), px(20)), (W - px(20), px(20)), (px(20), H - px(20)), (W - px(20), H - px(20))):
        lun = int(rng.uniform(px(20), px(60)))
        y1 = min(H, vy + lun)
        larg = px(2.5)
        for y in range(vy, y1):
            k = (1 - (y - vy) / max(lun, 1)) * 0.5
            x0 = int(vx + math.sin(y * 0.05) * 2)
            a[y, max(0, x0 - larg):min(W, x0 + larg)] = a[y, max(0, x0 - larg):min(W, x0 + larg)] * (1 - k) + RUGGINE * k
    # i graffi fini
    gr = Image.new('L', (W, H), 0)
    dg = ImageDraw.Draw(gr)
    for _ in range(40):
        x, y = rng.integers(0, W), rng.integers(0, H)
        l = rng.uniform(px(8), px(45))
        t = rng.uniform(0, math.pi)
        dg.line([(x, y), (x + l * math.cos(t), y + l * math.sin(t))], fill=int(rng.uniform(60, 140)), width=1)
    g = np.asarray(gr, np.float32)[..., None] / 255.0
    a = a * (1 - g * 0.5) + np.array([170, 168, 160], np.float32) * g * 0.5
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGB')


def main():
    uscita = sys.argv[1] if len(sys.argv) > 1 else USCITA
    base = lastra()
    # la cera sopra lo smalto, poi l'invecchiamento su tutto (lo sporco passa anche sui pastelli)
    cera = quadratini()
    base = base.convert('RGBA')
    base.alpha_composite(cera)
    finale = invecchia(base.convert('RGB'))
    os.makedirs(os.path.dirname(os.path.abspath(uscita)), exist_ok=True)
    finale.save(uscita)
    print(uscita, finale.size)


if __name__ == '__main__':
    main()
