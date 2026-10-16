"""Pianta (vista dall'alto, coordinate Godot globali) dei due percorsi proposti per la tappa 7.
Uso: /home/user/tools/blender-venv/bin/python tools/pianta_tappa7.py -> docs/proposte/tappa7/pianta_<a|b>.png"""
import os
from PIL import Image, ImageDraw, ImageFont

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', 'docs', 'proposte', 'tappa7')
S = 16                      # pixel per metro
X0, X1, Z0, Z1 = -32, 40, -34, 52
W, H = (X1 - X0) * S, (Z1 - Z0) * S
try:
    F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 17)
    FB = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 22)
except OSError:
    F = FB = ImageFont.load_default()


def p(x, z):
    return ((x - X0) * S, (z - Z0) * S)


def rett(d, x0, x1, z0, z1, fill, out=(40, 40, 40), w=2, alfa=255):
    d.rectangle([p(x0, z0), p(x1, z1)], fill=(*fill, alfa), outline=(*out, 255), width=w)


def testo(d, x, z, t, f=F, col=(20, 20, 20)):
    d.text(p(x, z), t, font=f, fill=col, anchor='mm')


def base():
    im = Image.new('RGBA', (W, H), (236, 233, 226, 255))
    d = ImageDraw.Draw(im, 'RGBA')
    # sala grande
    rett(d, -20, 20, -24, 20, (214, 222, 228))
    rett(d, -20, 20, 17, 20, (200, 206, 212), w=1); testo(d, 0, 18.5, 'galleria (soppalco, 4 m)')
    rett(d, -3, 3, 7.75, 12.25, (150, 185, 205)); testo(d, 0, 10, 'vasca\nmedusa')
    rett(d, -16, -9, -3, 7, (175, 205, 222), w=1); testo(d, -12.5, 2, 'vasca\nd\'arrivo')
    rett(d, -14.8, -10.4, -11.2, -6, (175, 205, 222), w=1); testo(d, -12.6, -9.5, 'area bimbi\n(fossa)')
    d.ellipse([p(-10, -8), p(10, 12)], outline=(120, 140, 160), width=2); testo(d, 6.5, -3, 'piscina a onde')
    testo(d, 0, -21, 'SALA GRANDE (pavimento y = 0)', FB)
    # interni (già visti) e vano verso gli spogliatoi
    for (a, b, c, e) in ((-9.7, 12.3, 38.1, 40.9), (-6.7, 1.3, 29.9, 37.9), (-1.1, 1.1, 20.4, 29.7), (1.5, 5.5, 30.3, 34.7)):
        rett(d, a, b, c, e, (205, 200, 190), out=(120, 115, 105), alfa=150)
    testo(d, -11.5, 34.5, 'interni, già visti\n(y 0, non si ripassa)', F, (110, 100, 90))
    # camera delle onde e sala pompe (sotto, y -9)
    rett(d, -2.2, 2.2, -0.6, 25.4, (120, 170, 120), out=(70, 100, 70), alfa=90)
    testo(d, -6.0, 23.5, 'camera delle onde\n(sotto, y -9)', F, (60, 90, 60))
    rett(d, -3.8, 8.2, 29.7, 47.7, (120, 170, 120), out=(60, 100, 60), w=3, alfa=110)
    testo(d, 2.2, 44.5, 'SALA POMPE (y -9)', FB, (40, 80, 40))
    d.ellipse([p(-0.5, 41.5), p(0.5, 42.5)], fill=(200, 40, 40)); testo(d, 2.6, 41.2, 'qui parte la tappa 7', F, (160, 30, 30))
    rett(d, -3, 3, 7.75, 12.25, (150, 185, 205)); testo(d, 0, 10, 'vasca\nmedusa')   # sopra la camera delle onde
    return im, d


def percorso(d, punti, col):
    d.line([p(*q) for q in punti], fill=col, width=7, joint='curve')
    x, z = punti[-1]
    d.ellipse([p(x - 0.7, z - 0.7), p(x + 0.7, z + 0.7)], fill=col)


def salva(im, nome, titolo, righe):
    im = im.convert('RGB')
    d = ImageDraw.Draw(im)
    d.rectangle([(10, 10), (W - 10, 60 + 26 * len(righe))], fill=(255, 255, 255), outline=(60, 60, 60))
    d.text((24, 22), titolo, font=FB, fill=(20, 20, 20))
    for i, r in enumerate(righe):
        d.text((24, 58 + 26 * i), r, font=F, fill=(40, 40, 40))
    d.text((24, H - 34), 'Vista dall\'alto, coordinate del gioco in metri. Verde trasparente = sotto terra (y -9).', font=F, fill=(90, 90, 90))
    im.save(os.path.join(OUT, nome))


# A: locale caldaie, si sbuca a terra nell'angolo sud-est della sala
im, d = base()
rett(d, 10, 21, 22, 29, (232, 190, 160), out=(150, 70, 30), w=3); testo(d, 15.5, 25.5, 'LOCALE CALDAIE\n(y -4,6)', FB, (130, 50, 20))
rett(d, 8.2, 11, 31.5, 33.5, (232, 210, 180), out=(150, 70, 30)); testo(d, 12.5, 33.2, 'scala di servizio\n(sale 4,5 m)')
percorso(d, [(0.0, 42.0), (8.2, 32.5), (10.5, 32.5), (12.0, 29.0), (15.5, 25.5), (19.0, 23.0), (15.0, 20.0), (15.0, 18.4)], (200, 80, 30))
testo(d, 15.0, 15.8, 'porta di servizio nel muro sud\n(angolo sud-est, a terra)', F, (150, 60, 20))
salva(im, 'pianta_a_caldaie.png', 'Proposta A: dietro le quinte, locale caldaie', [
    'Sala pompe -> porta nuova nel muro est -> scala di servizio',
    '-> locale caldaie (due caldaie, vapore, tubi) -> scala in grata',
    '-> porta di servizio: si sbuca a terra nell\'angolo sud-est della sala',
    'grande. La scia di gocce porta a nord-ovest, verso l\'area bimbi.'])

# B: magazzino dei gonfiabili, si sbuca da una serranda nell'angolo sud-ovest, lungo il muro ovest
im, d = base()
rett(d, -19, -9, 21, 27, (226, 200, 225), out=(120, 50, 120), w=3); testo(d, -14, 24, 'MAGAZZINO\nGONFIABILI (y 0)', FB, (110, 40, 110))
rett(d, -9, -3.8, 28.5, 30.5, (232, 210, 230), out=(120, 50, 120)); testo(d, -10.5, 31.6, 'corridoio + scala\n(sale 9 m)')
percorso(d, [(0.0, 42.0), (-3.8, 33.0), (-6.5, 29.5), (-9.0, 27.0), (-14.0, 24.0), (-14.0, 20.0), (-14.0, 18.6)], (140, 50, 150))
testo(d, -11.5, 15.6, 'serranda nel muro sud\n(angolo sud-ovest)', F, (110, 40, 110))
d.line([p(-17.5, 16), p(-17.5, -4)], fill=(140, 50, 150), width=3)
testo(d, -15.0, 6.0, 'scia\nlungo il\nmuro ovest', F, (110, 40, 110))
salva(im, 'pianta_b_magazzino.png', 'Proposta B: dietro le quinte, magazzino dei gonfiabili', [
    'Sala pompe -> porta nuova nel muro ovest -> corridoio e scala',
    '(sale 9 m) -> magazzino dei gonfiabili -> serranda mezza alzata',
    'nell\'angolo sud-ovest. La scia va lungo il muro ovest fino all\'area',
    'bimbi, dove la medusa sbuca rivolta a sud-ovest, verso chi arriva.'])
print('piante scritte')
