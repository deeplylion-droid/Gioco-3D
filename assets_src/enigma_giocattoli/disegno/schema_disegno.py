"""Lo schema del disegno a pastello del muro ovest (accordo del 28 ottobre): la piscina a onde vista dall'alto come la
vede chi sta davanti al muro ovest della parte profonda (in alto l'ovest, x -7; a destra il nord, la spiaggia; a sinistra
il muro sud della parte fonda, z 5), con la botola e i tre cerchi nelle posizioni della scena di enigmi. Lo schema
(forme piene, posizioni giuste) va a Meshy image-to-image che lo ridisegna a pastello (genera_disegno_muro.py).
I cerchi e i giocattoli sono disegnati più grandi del vero (1,9 m invece di 1), come li disegnerebbe un bambino.
Uso: python3 schema_disegno.py -> schema_disegno.png (1200 x 900)"""
import os
from PIL import Image, ImageDraw

QUI = os.path.dirname(os.path.abspath(__file__))
W, H = 1200, 900
X0, X1 = 90, 1110          # z 5 .. -13
PX = (X1 - X0) / 18.0      # pixel per metro
Y0 = (H - 14 * PX) / 2     # x -7 in alto


def p(x, z):
    return X0 + (5 - z) * PX, Y0 + (x + 7) * PX


CERCHI = [((-3.9, 3.3), (235, 190, 20), 'paperella'), ((3.9, 3.3), (215, 35, 30), 'pallone'),
          ((-3.9, -0.1), (30, 80, 200), 'balena')]

if __name__ == '__main__':
    im = Image.new('RGB', (W, H), (250, 248, 240))
    d = ImageDraw.Draw(im)
    a, b = p(-7, 5), p(7, -13)
    d.rounded_rectangle([a[0], a[1], b[0], b[1]], 40, fill=(150, 200, 235), outline=(20, 50, 160), width=10)
    sp = p(-7, -9)                                  # la spiaggia (sabbia) all'estremo nord
    d.rounded_rectangle([sp[0], a[1] + 5, b[0] - 5, b[1] - 5], 35, fill=(245, 228, 185))
    pf = p(-7, -1)                                  # la parte fonda più scura
    d.rounded_rectangle([a[0] + 5, a[1] + 5, pf[0], b[1] - 5], 35, fill=(110, 170, 225))
    c = p(0, 2.0)
    h = 1.4 * PX / 2 * 1.4
    d.rectangle([c[0] - h, c[1] - h, c[0] + h, c[1] + h], fill=(90, 90, 90), outline=(20, 20, 20), width=6)
    r = 1.9 * PX / 2
    for (x, z), col, _ in CERCHI:
        c = p(x, z)
        d.ellipse([c[0] - r - 9, c[1] - r - 9, c[0] + r + 9, c[1] + r + 9], fill=(200, 245, 170))   # il bordo fosforescente
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col, outline=(30, 30, 30), width=4)
    im.save(os.path.join(QUI, 'schema_disegno.png'))
    print({n: tuple(round(v) for v in p(x, z)) for (x, z), _, n in CERCHI}, 'botola', tuple(round(v) for v in p(0, 2)))
