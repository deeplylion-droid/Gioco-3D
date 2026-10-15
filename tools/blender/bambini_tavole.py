"""Tavole JPG dei render 3D dei bambini, da guardare sul telefono (solo PIL).

Uso:
    /home/user/tools/blender-venv/bin/python tools/blender/bambini_tavole.py <cartella_render>

Nella cartella dei render cerca i PNG prodotti da bambini_scena.py e bambini_render.py
(<modello>_eroe.png, <modello>_giro.png, <modello>_studio_<vista>.png). Scrive:
  docs/proposte/bambini/<personaggio>_3d.jpg       tavola con tutti i render del personaggio
  docs/proposte/bambini/render/<nome>.jpg          ogni render da solo, a piena risoluzione
Le immagini mancanti vengono saltate.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
OUT = os.path.join(REPO, 'docs', 'proposte', 'bambini')
FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
W = 1600
FONDO = (14, 15, 18)

# personaggio: titolo, sottotitolo, pannelli (file nella cartella render, nome del singolo, etichetta)
TAVOLE = {
    'cubo': ('TESTA A CUBO', 'modello 3D in Blender, alto 1,2 m', [
        ('cubo_calmo_eroe.png', 'cubo_travestito_acquapark', 'TRAVESTITO'),
        ('cubo_rivelato_eroe.png', 'cubo_rivelato_acquapark', 'RIVELATO'),
        ('@studio:cubo_calmo', 'cubo_travestito_studio', 'TRAVESTITO · studio: davanti, 3/4, dietro'),
        ('@studio:cubo_rivelato', 'cubo_rivelato_studio', 'RIVELATO · studio: davanti, 3/4, dietro'),
    ]),
    'agnello': ('AGNELLINO', 'modello 3D in Blender, alto 1,2 m', [
        ('agnello_calmo_eroe.png', 'agnello_travestito_acquapark', 'TRAVESTITO'),
        ('agnello_occhio_eroe.png', 'agnello_occhio_acquapark', 'RIVELATO · occhio unico'),
        ('@studio:agnello_calmo', 'agnello_travestito_studio', 'TRAVESTITO · studio: davanti, 3/4, dietro'),
        ('@studio:agnello_occhio', 'agnello_occhio_studio', 'RIVELATO · studio: davanti, 3/4, dietro'),
    ]),
}


def font(dim, bold=True):
    return ImageFont.truetype(FONT_BOLD if bold else FONT, dim)


def carica(cartella, f):
    """Un PNG della cartella, oppure '@studio:<modello>': le tre viste da studio affiancate."""
    if f.startswith('@studio:'):
        m = f.split(':', 1)[1]
        viste = [os.path.join(cartella, f'{m}_studio_{v}.png') for v in ('davanti', 'tre_quarti', 'dietro')]
        if not all(os.path.exists(v) for v in viste):
            return None
        ims = [Image.open(v).convert('RGB') for v in viste]
        h = ims[0].height
        tela = Image.new('RGB', (sum(i.width for i in ims), h))
        x = 0
        for i in ims:
            tela.paste(i, (x, 0)); x += i.width
        return tela
    p = os.path.join(cartella, f)
    return Image.open(p).convert('RGB') if os.path.exists(p) else None


def etichetta(im, testo, dim=58):
    d = ImageDraw.Draw(im, 'RGBA')
    f = font(dim)
    x0, y0, x1, y1 = d.textbbox((0, 0), testo, font=f)
    pad = 18
    d.rounded_rectangle((24, 24, 24 + x1 - x0 + 2 * pad, 24 + y1 - y0 + 2 * pad), 14, fill=(0, 0, 0, 175))
    d.text((24 + pad - x0, 24 + pad - y0), testo, font=f, fill=(255, 255, 255))
    return im


def con_banda(im, testo, dim=52, alto=96):
    """Etichetta in una fascia scura sopra l'immagine (per le viste da studio, dove le teste
    arrivano in cima e un'etichetta sopra le coprirebbe)."""
    tela = Image.new('RGB', (im.width, im.height + alto), FONDO)
    tela.paste(im, (0, alto))
    d = ImageDraw.Draw(tela)
    f = font(dim)
    x0, y0, x1, y1 = d.textbbox((0, 0), testo, font=f)
    d.text((28 - x0, (alto - (y1 - y0)) // 2 - y0), testo, font=f, fill=(255, 255, 255))
    return tela


def tavola(chiave, cartella):
    titolo, sotto, pannelli = TAVOLE[chiave]
    os.makedirs(os.path.join(OUT, 'render'), exist_ok=True)
    blocchi = []
    for f, nome, testo in pannelli:
        im = carica(cartella, f)
        if im is None:
            print('manca', f)
            continue
        im.save(os.path.join(OUT, 'render', nome + '.jpg'), quality=90, optimize=True)
        im = im.resize((W, round(im.height * W / im.width)), Image.LANCZOS)
        blocchi.append(con_banda(im, testo) if f.startswith('@studio:') else etichetta(im, testo))
    if not blocchi:
        return None
    th = 190
    gap = 14
    H = th + sum(b.height for b in blocchi) + gap * len(blocchi)
    tela = Image.new('RGB', (W, H), FONDO)
    d = ImageDraw.Draw(tela)
    d.text((40, 28), titolo, font=font(84), fill=(255, 255, 255))
    d.text((44, 128), sotto, font=font(40, bold=False), fill=(190, 195, 205))
    y = th
    for b in blocchi:
        tela.paste(b, (0, y)); y += b.height + gap
    out = os.path.join(OUT, f'{chiave}_3d.jpg')
    tela.save(out, quality=86, optimize=True)
    print('scritto', os.path.relpath(out, REPO), tela.size, f'{os.path.getsize(out) / 1e6:.1f} MB')
    return out


if __name__ == '__main__':
    cartella = sys.argv[1]
    for k in TAVOLE:
        tavola(k, cartella)
