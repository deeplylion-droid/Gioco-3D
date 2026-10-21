"""Le insegne della giostra delle rapide per la proposta B dell'inseguimento (disegnate qui con PIL, niente IA):
l'insegna grande, i cartelli di sicurezza e quello verde dell'uscita, un po' invecchiati.
Uscita: assets_src/inseguimento/insegne/<nome>.png. Si chiama da inseguimento_proposte.py."""
import os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
CARTELLA = os.path.normpath(os.path.join(QUI, '..', '..', 'assets_src', 'inseguimento', 'insegne'))
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def _font(n):
    return ImageFont.truetype(FONT, n)


def _invecchia(im, seme):
    rnd = random.Random(seme)
    d = ImageDraw.Draw(im, 'RGBA')
    w, h = im.size
    for _ in range(260):           # graffi e macchie
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        if rnd.random() < 0.6:
            d.line([(x, y), (x + rnd.uniform(-40, 40), y + rnd.uniform(-6, 6))], fill=(255, 255, 255, rnd.randint(20, 60)), width=1)
        else:
            r = rnd.uniform(4, 22)
            d.ellipse([x - r, y - r, x + r, y + r], fill=(60, 40, 20, rnd.randint(25, 70)))
    for _ in range(14):            # colature di ruggine dal bordo alto
        x = rnd.uniform(0, w)
        d.line([(x, 0), (x + rnd.uniform(-5, 5), rnd.uniform(h * 0.1, h * 0.45))], fill=(120, 60, 20, 90), width=rnd.randint(3, 8))
    return im.filter(ImageFilter.GaussianBlur(0.6))


def _testo(d, xy, testo, font, fill, ombra=(0, 0, 0), bordo=8):
    d.text(xy, testo, font=font, fill=fill, anchor='mm', stroke_width=bordo, stroke_fill=ombra)


def insegna_rapide():
    w, h = 2048, 560
    im = Image.new('RGB', (w, h), (18, 92, 110))
    d = ImageDraw.Draw(im)
    # onde a righe in basso
    for k in range(5):
        y0 = h - 70 - k * 34
        pts = [(x, y0 + 16 * ((x // 64) % 2)) for x in range(0, w + 64, 64)]
        d.line(pts, fill=(235, 245, 240) if k % 2 == 0 else (40, 160, 175), width=14)
    d.rectangle([0, 0, w - 1, h - 1], outline=(242, 183, 5), width=26)
    _testo(d, (w // 2, 200), 'LE RAPIDE', _font(250), (255, 214, 40), (90, 30, 10), 14)
    _testo(d, (w // 2, 360), 'TENERSI FORTE!', _font(80), (255, 255, 255), (10, 40, 50), 6)
    return _invecchia(im, 1)


def cartello(nome, testo, sotto, fondo, colore, seme):
    w, h = 1024, 640
    im = Image.new('RGB', (w, h), fondo)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 14, w - 15, h - 15], outline=colore, width=22)
    _testo(d, (w // 2, 250), testo, _font(130 if len(testo) < 10 else 100), colore, (0, 0, 0), 6)
    _testo(d, (w // 2, 450), sotto, _font(90), colore, (0, 0, 0), 5)
    return _invecchia(im, seme)


def disegna_tutto():
    os.makedirs(CARTELLA, exist_ok=True)
    fatti = {}
    for nome, im in (('insegna_rapide', insegna_rapide()),
                     ('cartello_tenersi', cartello('t', 'ATTENZIONE', 'SALTO!', (242, 183, 5), (20, 20, 20), 2)),
                     ('cartello_vietato', cartello('v', 'VIETATO', 'ALZARSI', (235, 235, 230), (200, 25, 20), 3)),
                     ('cartello_uscita', cartello('u', 'USCITA', '<<<', (20, 120, 60), (240, 250, 240), 4)),
                     ('cartello_altezza', cartello('h', 'ALTEZZA', 'MINIMA 1,20 m', (235, 235, 230), (20, 60, 140), 5)),
                     ('cartello_turno', cartello('c', 'ATTENDERE', 'IL TURNO', (18, 92, 110), (255, 214, 40), 6))):
        p = os.path.join(CARTELLA, nome + '.png')
        im.save(p)
        fatti[nome] = p
    return fatti


if __name__ == '__main__':
    print(disegna_tutto())
