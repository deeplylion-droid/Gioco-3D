"""Invecchia i cartelloni: sbiadito, macchie d'acqua dal basso, muffa, pieghe e pezzi strappati
che lasciano vedere la lamiera. Uso: python invecchia.py  -> <nome>_vecchio.jpg"""
import os
import numpy as np
from PIL import Image, ImageFilter
QUI = os.path.dirname(os.path.abspath(__file__))
MURO = os.path.join(QUI, '../texture/lamiera_crema_col.jpg')

def blob(shape, seed, scala):
    rng = np.random.default_rng(seed)
    h, w = shape; acc = np.zeros(shape, np.float32); amp = 1
    for o in range(5):
        k = scala * 2 ** o
        g = rng.random((k + 1, int(k * w / h) + 2)).astype(np.float32)
        acc += np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), np.float32) / 255 * amp
        amp *= 0.5
    return (acc - acc.min()) / (acc.max() - acc.min())

def invecchia(nome, seed, strappi=0.12):
    im = np.asarray(Image.open(os.path.join(QUI, nome + '.png')).convert('RGB'), np.float32) / 255
    h, w, _ = im.shape
    # sbiadito e un po' ingiallito
    lum = im.mean(2, keepdims=True)
    im = im * 0.9 + lum * 0.1
    im = im * np.array([0.97, 0.95, 0.86]) + 0.02
    yy = np.linspace(0, 1, h)[:, None]
    # macchie d'acqua che salgono dal basso
    n = blob((h, w), seed, 3)
    acqua = np.clip((yy - 0.55 + n * 0.35) * 2.2, 0, 1)
    im = im * (1 - acqua[..., None] * np.array([0.3, 0.32, 0.42])) + acqua[..., None] * np.array([0.08, 0.07, 0.04])
    # bordi delle macchie (aloni)
    alone = np.exp(-((yy - 0.55 + n * 0.35) * 2.2 - 0.05) ** 2 / 0.004)
    im = im * (1 - alone[..., None] * 0.25)
    # muffa verdastra a chiazze
    m = blob((h, w), seed + 1, 6)
    muffa = np.clip((m - 0.68) * 5, 0, 1) * np.clip(yy * 1.5, 0, 1)
    im = im * (1 - muffa[..., None] * 0.6) + muffa[..., None] * np.array([0.12, 0.14, 0.06]) * 0.6
    # sporco generale e graffi verticali
    s = blob((h, w), seed + 2, 10)
    im *= (0.8 + 0.2 * s)[..., None]
    rng = np.random.default_rng(seed)
    for _ in range(40):
        x = rng.integers(0, w); y0 = rng.integers(0, h); L = rng.integers(20, 200)
        im[y0:y0 + L, x:x + 2] *= 0.75
    # pezzi strappati: si vede la lamiera sotto
    muro = np.asarray(Image.open(MURO).convert('RGB').resize((w, h)), np.float32) / 255
    t = blob((h, w), seed + 3, 4)
    bordo = np.minimum.reduce([yy * np.ones((1, w)), (1 - yy) * np.ones((1, w)),
                               np.ones((h, 1)) * np.linspace(0, 1, w)[None], np.ones((h, 1)) * np.linspace(1, 0, w)[None]])
    strappo = ((t * 0.6 + (0.07 - bordo) * 9) > (1 - strappi)).astype(np.float32)
    strappo = np.asarray(Image.fromarray((strappo * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255
    carta = np.clip(strappo * 3, 0, 1) - strappo  # bordo bianco della carta strappata
    im = im * (1 - strappo[..., None]) + muro * strappo[..., None]
    im = im * (1 - carta[..., None] * 0.6) + np.array([0.85, 0.82, 0.72]) * carta[..., None] * 0.6
    Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8)).save(os.path.join(QUI, nome + '_vecchio.jpg'), quality=92)
    print('ok', nome)

if __name__ == '__main__':
    invecchia('cartellone_medusa', 5, 0.10)
    invecchia('cartello_regole', 6, 0.05)
    invecchia('poster_bagnino', 7, 0.08)
