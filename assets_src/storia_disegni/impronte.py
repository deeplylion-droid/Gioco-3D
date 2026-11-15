"""Le impronte bagnate dei piedi nudi del bambino con la scatola (componente DisegnoBambino, opzione «impronte»):
un piede di bambino (circa 17 cm) visto da sopra, bagnato: pianta, tallone, arco più stretto e cinque dita. Texture con
l'alfa per un Decal (scuro e lucido lo fa il materiale del Decal). Esporta il piede sinistro e il destro (specchiato).
Uso: python3 impronte.py"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
USCITA = os.path.join(QUI, '..', '..', 'godot', 'assets', 'storia_disegni')
W, H = 128, 256


def piede() -> Image.Image:
    a = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(a)
    # pianta (davanti), arco (stretto, sul lato esterno) e tallone (dietro); in alto le dita
    d.ellipse((24, 66, 106, 150), fill=255)
    d.polygon([(30, 130), (70, 135), (66, 200), (40, 200)], fill=255)
    d.ellipse((34, 178, 92, 244), fill=255)
    # l'arco interno non tocca (piede sinistro: interno a destra)
    d.ellipse((66, 138, 120, 200), fill=0)
    for x, y, r in [(90, 40, 13), (66, 28, 9), (47, 30, 8), (31, 38, 7), (19, 52, 6)]:
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    a = a.filter(ImageFilter.GaussianBlur(2.2))
    # bagnato: pieno al centro, più chiaro sui bordi, qualche goccia sparsa
    rng = np.random.default_rng(7)
    arr = np.asarray(a).astype(np.float32) / 255.0
    rumore = rng.random((H, W)).astype(np.float32)
    arr = np.clip(arr * (0.75 + 0.35 * rumore), 0, 1) ** 1.2
    img = np.zeros((H, W, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = (arr * 255).astype(np.uint8)
    return Image.fromarray(img, 'RGBA')


if __name__ == '__main__':
    os.makedirs(USCITA, exist_ok=True)
    sx = piede()
    sx.save(os.path.join(USCITA, 'impronta_sx.png'))
    sx.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(USCITA, 'impronta_dx.png'))
    print('fatte')
