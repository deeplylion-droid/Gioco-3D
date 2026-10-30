"""Le macchie dell'acqua che filtra dalla vasca dell'oblò nel corridoio del fiume (scelta A+C, 30 ottobre): decal PNG con
alfa, disegnati qui (numpy). Sotto la luce rossa del corridoio il verde scuro della muffa non si vede: le macchie si
leggono per luminosità, con le colature scure e bagnate e il bordo bianco di calcare (efflorescenze), come su un muro
vero che perde.
- macchie_colature.png (512 x 1024): chiazza di muffa in alto e colature verticali che scendono fino in fondo;
- macchie_muffa.png (1024 x 768): chiazze di muffa e alone di calcare per il muro di fronte;
- pozza_alone.png (1024 x 384) e pozza_alone_orm.png: il cemento bagnato attorno alla pozza, che sfuma verso l'asciutto
  (ricontrollo di grafica del 30 ottobre: da metà corridoio la pozza era una striscia scura col bordo netto).
Uso: python3 genera_macchie.py"""
import os
import numpy as np
from PIL import Image, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
USCITA = os.path.join(QUI, '..', '..', 'godot', 'assets', 'ambienti_tecnici', 'corridoio_fiume', 'texture')
rng = np.random.default_rng(30)


def rumore(w, h, scala, ottave=4):
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    for o in range(ottave):
        s = max(2, int(scala * 2 ** o))
        r = Image.fromarray((rng.random((max(2, h * s // w), s)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(r, np.float32) / 255.0 * amp
        amp *= 0.5
    return out / out.max()


def liscia(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def componi(bagnato, calcare, muffa):
    """Colore e alfa: bagnato scuro, muffa nero-verde, calcare bianco sporco."""
    h, w = bagnato.shape
    col = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    for m, c, k in ((bagnato, (0.10, 0.08, 0.06), 0.85), (muffa, (0.05, 0.07, 0.04), 0.95), (calcare, (0.86, 0.84, 0.78), 0.9)):
        aa = np.clip(m, 0, 1) * k
        col = col * (1 - aa[..., None]) + np.array(c) * aa[..., None]
        a = a + aa * (1 - a)
    col = np.where(a[..., None] > 1e-3, col / np.maximum(a[..., None], 1e-3) * a[..., None] + col * 0, col)
    rgba = np.dstack([np.clip(col / np.maximum(a[..., None], 1e-3), 0, 1), a])
    return Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA')


def colature():
    w, h = 512, 1024
    y = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    x = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
    # la chiazza in alto (dove il bordo dell'oblò perde)
    chiazza = np.exp(-(((x - 0.5) / 0.38) ** 2 + ((y - 0.18) / 0.16) ** 2)) * (0.6 + 0.6 * rumore(w, h, 6))
    chiazza = np.clip((chiazza - 0.35) * 2.2, 0, 1)
    # le colature: righe verticali che partono dalla chiazza e si assottigliano scendendo, ognuna lunga a caso
    righe = np.zeros((h, w), np.float32)
    lungo = rumore(w, h, 3)
    for k in range(11):
        cx = rng.uniform(0.22, 0.78)
        inizio = rng.uniform(0.12, 0.3)
        fine = rng.uniform(0.5, 0.97)
        larga = rng.uniform(0.004, 0.016)
        forza = rng.uniform(0.45, 1.0)
        fase = rng.uniform(0, 6)
        for i in range(h):
            yy = i / h
            if yy < inizio or yy > fine:
                continue
            t = (yy - inizio) / (fine - inizio)
            # entra sfumata dalla chiazza, si allarga e si stringe, si interrompe a tratti, sfuma in fondo
            l = larga * (0.6 + 0.8 * lungo[i, int(cx * (w - 1))]) * (1 - 0.5 * t)
            dx = 0.012 * np.sin(yy * 14 + fase) + 0.006 * np.sin(yy * 37 + fase * 2)
            d = np.abs(x[i] - cx - dx)
            v = np.clip(1 - d / l, 0, 1) * min(1.0, t * 8) * (1 - t ** 2) * forza
            v *= 0.55 + 0.45 * np.sin(yy * 23 + fase * 3) ** 2
            righe[i] = np.maximum(righe[i], v)
    righe = liscia(righe, 3.5)
    bagnato = np.clip(chiazza + righe, 0, 1)
    muffa = np.clip((chiazza * rumore(w, h, 10) - 0.25) * 2.0, 0, 1)
    bordo = np.clip(liscia(bagnato, 10) - bagnato, 0, 1) * 3.0
    calcare = np.clip(bordo * (0.2 + rumore(w, h, 12)), 0, 1) * 0.6
    return componi(bagnato, calcare, muffa)


def muffa():
    w, h = 1024, 768
    n = rumore(w, h, 5)
    y = np.linspace(0, 1, h)[:, None] * np.ones((1, w))
    x = np.ones((h, 1)) * np.linspace(0, 1, w)[None, :]
    forma = np.exp(-(((x - 0.5) / 0.42) ** 2 + ((y - 0.55) / 0.38) ** 2))
    m = np.clip((forma * (0.5 + n) - 0.55) * 2.5, 0, 1)
    macchie = np.clip((rumore(w, h, 14) * m - 0.3) * 2.5, 0, 1)
    bagnato = np.clip(m * 0.8, 0, 1)
    bordo = np.clip(liscia(m, 14) - m * 0.9, 0, 1) * 3.0
    calcare = np.clip(bordo * (0.3 + rumore(w, h, 16)), 0, 1) * 0.75
    return componi(bagnato, calcare, macchie)


def pozza_alone(w=1024, h=384):
    """Colore scuro di cemento bagnato con l'alfa che va a zero verso il bordo, irregolare."""
    y = np.linspace(-1, 1, h)[:, None] * np.ones((1, w))
    x = np.ones((h, 1)) * np.linspace(-1, 1, w)[None, :]
    d = np.sqrt(x ** 2 + y ** 2) + (rumore(w, h, 6) - 0.5) * 0.35
    a = np.clip((1.0 - d) / 0.55, 0, 1) ** 1.3 * 0.8
    col = np.zeros((h, w, 4), np.float32)
    col[..., :3] = (0.11, 0.10, 0.09)
    col[..., 3] = a
    orm = np.zeros((h, w, 3), np.float32)
    orm[..., 0] = 1.0
    orm[..., 1] = 0.22
    return (Image.fromarray((col * 255).astype(np.uint8), 'RGBA'), Image.fromarray((orm * 255).astype(np.uint8), 'RGB'))


if __name__ == '__main__':
    os.makedirs(USCITA, exist_ok=True)
    colature().save(os.path.join(USCITA, 'macchie_colature.png'))
    muffa().save(os.path.join(USCITA, 'macchie_muffa.png'))
    al, orm = pozza_alone()
    al.save(os.path.join(USCITA, 'pozza_alone.png'))
    orm.save(os.path.join(USCITA, 'pozza_alone_orm.png'))
    print('fatto')
