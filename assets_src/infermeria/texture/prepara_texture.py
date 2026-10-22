"""Dalle immagini grezze alle texture dell'infermeria in godot/assets/infermeria/texture/.
- radiografia.jpg / radiografia_emi.jpg: la radiografia dell'agnello con i puntini rosa 4-1-7 (testa,
  corpo, coda); la seconda è solo la luce dei puntini (emissione).
- simbolo_testa/corpo/coda.png: l'agnello in grigio con la parte della rotella in bianco.
- adesivo_<n>.png: gli adesivi da cartone dei muri del B (balena, stella, pesce, cavalluccio, tartaruga).
- rotella_cifre.jpg: le cifre 0-9 intorno alla rotella (lato del cilindro).
- polaroid_medico.jpg, polaroid_medico_B.jpg: la Polaroid sulla scrivania (aspetti A e B).
Uso: blender-venv/bin/python prepara_texture.py"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', '..', 'godot', 'assets', 'infermeria', 'texture')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
ROSA = (255, 60, 190)

# puntini sulla radiografia (coordinate nell'immagine 896x1200): gruppi distinti e ben separati
PUNTI = {
    'testa': [(125, 215), (160, 190), (150, 250), (195, 225)],
    'corpo': [(480, 470)],
    'coda': [(800, 640), (812, 680), (818, 720), (815, 760), (805, 800), (790, 838), (772, 872)],
}


def radiografia():
    im = Image.open(os.path.join(QUI, 'radiografia_grezza.png')).convert('RGB')
    emi = Image.new('RGB', im.size, (0, 0, 0))
    d = ImageDraw.Draw(im)
    de = ImageDraw.Draw(emi)
    for pts in PUNTI.values():
        for x, y in pts:
            r = 15
            d.ellipse((x - r, y - r, x + r, y + r), fill=ROSA)
            de.ellipse((x - r, y - r, x + r, y + r), fill=ROSA)
    alone = emi.filter(ImageFilter.GaussianBlur(14))
    emi = Image.fromarray(np.clip(np.asarray(emi, np.float32) + np.asarray(alone, np.float32) * 1.6, 0, 255).astype(np.uint8))
    im.save(os.path.join(OUT, 'radiografia.jpg'), quality=92)
    emi.save(os.path.join(OUT, 'radiografia_emi.jpg'), quality=92)


def simboli():
    ico = np.asarray(Image.open(os.path.join(QUI, 'agnello_icona.png')).convert('L'), np.float32) / 255.0
    n = ico.shape[1]
    x = np.arange(n)[None, :].repeat(ico.shape[0], 0)
    zone = {'testa': x < 0.4 * n, 'corpo': (x >= 0.4 * n) & (x < 0.755 * n), 'coda': x >= 0.755 * n}
    for nome, z in zone.items():
        v = ico * np.where(z, 1.0, 0.28)
        rgb = np.stack([v * 245, v * 238, v * 225], -1)
        Image.fromarray(rgb.astype(np.uint8)).resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, 'simbolo_%s.png' % nome))


def rotella():
    # le cifre stanno in fila lungo la circonferenza (U del cilindro), ognuna con l'alto lungo U: si
    # leggono dritte di fronte con la rotella ad asse orizzontale. Le celle sono alte (in V) quanto la
    # rotella è larga: 128 px di circonferenza (3,8 cm) per 292 px di larghezza (8,6 cm).
    cw, h = 128, 292
    im = Image.new('RGB', (cw * 10, h), (232, 226, 210))
    f = ImageFont.truetype(FONT, 104)
    for i in range(10):
        c = Image.new('RGB', (h, cw), (232, 226, 210))
        ImageDraw.Draw(c).text((h / 2, cw / 2), str(i), font=f, fill=(25, 25, 25), anchor='mm')
        im.paste(c.rotate(90, expand=True), (i * cw, 0))
    d = ImageDraw.Draw(im)
    for i in range(10):
        d.line((i * cw, 0, i * cw, h), fill=(150, 145, 130), width=3)
    im.save(os.path.join(OUT, 'rotella_cifre.jpg'), quality=92)


def polaroid():
    im = Image.open(os.path.join(QUI, 'polaroid_medico.png')).convert('RGB')
    im.crop((150, 84, 874, 940)).save(os.path.join(OUT, 'polaroid_medico.jpg'), quality=90)
    im = Image.open(os.path.join(QUI, 'polaroid_medico_B.png')).convert('RGB')
    im.crop((130, 64, 896, 964)).save(os.path.join(OUT, 'polaroid_medico_B.jpg'), quality=90)


def decalcomanie():
    # sfondo grigio chiaro tolto (riempimento dai bordi), poi un PNG per ogni adesivo
    from scipy import ndimage
    im = np.asarray(Image.open(os.path.join(QUI, 'decalcomanie.png')).convert('RGB'), np.float32)
    lum = im.mean(-1)
    sat = im.max(-1) - im.min(-1)
    fondo = (lum > 200) & (lum < 250) & (sat < 10)
    lab, _ = ndimage.label(fondo)
    bordo = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    via = np.isin(lab, list(bordo))
    alpha = ndimage.binary_opening(~via, iterations=2)
    pezzi, n = ndimage.label(alpha)
    k = 0
    for sl in sorted(ndimage.find_objects(pezzi), key=lambda s: s[1].start):
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if h * w < 4000:
            continue
        rgba = np.dstack([im[sl], alpha[sl] * 255.0]).astype(np.uint8)
        Image.fromarray(rgba, 'RGBA').save(os.path.join(OUT, 'adesivo_%d.png' % k))
        k += 1
    print('adesivi', k)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    radiografia(); simboli(); rotella(); polaroid(); decalcomanie()
