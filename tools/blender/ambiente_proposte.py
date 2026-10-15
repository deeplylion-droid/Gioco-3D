"""Compone i JPG delle proposte e delle consegne con etichette grandi, leggibili sul telefono.

Uso:
  PY=/home/user/tools/blender-venv/bin/python
  $PY tools/blender/ambiente_proposte.py angolo <cartella_render>     # Opzione 1/2/3 + confronto
  $PY tools/blender/ambiente_proposte.py oggetti <cartella_render>
  $PY tools/blender/ambiente_proposte.py sala <cartella_render>       # render della sala principale
Le immagini sono SOLO render 3D (Blender Cycles) della geometria vera: niente immagini generate.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
RADICE = os.path.abspath(os.path.join(QUI, '..', '..'))
PROPOSTE = os.path.join(RADICE, 'docs', 'proposte', 'ambiente')
FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT_R = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def font(px, bold=True):
    return ImageFont.truetype(FONT_B if bold else FONT_R, px)


def con_etichetta(img, titolo, sottotitolo='', nota=''):
    """Aggiunge una fascia scura in alto con titolo e sottotitolo (e una nota piccola in basso)."""
    W, H = img.size
    t = int(W * 0.045)
    st = int(W * 0.03)
    fascia = int(t * 1.45 + (st * 1.4 if sottotitolo else 0) + W * 0.02)
    nota_h = int(W * 0.03) if nota else 0
    out = Image.new('RGB', (W, H + fascia + nota_h), (16, 18, 22))
    out.paste(img, (0, fascia))
    d = ImageDraw.Draw(out)
    x = int(W * 0.025)
    d.text((x, int(W * 0.012)), titolo, font=font(t), fill=(255, 214, 64))
    if sottotitolo:
        d.text((x, int(W * 0.012 + t * 1.3)), sottotitolo, font=font(st, False), fill=(235, 235, 235))
    if nota:
        d.text((x, H + fascia + int(nota_h * 0.12)), nota, font=font(int(nota_h * 0.62), False), fill=(170, 170, 170))
    return out


def impila(immagini, larghezza=1080, spazio=18):
    """Una sotto l'altra, stessa larghezza (comodo da scorrere sul telefono)."""
    rid = []
    for im in immagini:
        h = int(im.size[1] * larghezza / im.size[0])
        rid.append(im.resize((larghezza, h), Image.LANCZOS))
    H = sum(i.size[1] for i in rid) + spazio * (len(rid) - 1)
    out = Image.new('RGB', (larghezza, H), (8, 8, 10))
    y = 0
    for i in rid:
        out.paste(i, (0, y))
        y += i.size[1] + spazio
    return out


def salva(img, nome, cartella=PROPOSTE, qualita=88):
    os.makedirs(cartella, exist_ok=True)
    p = os.path.join(cartella, nome)
    img.save(p, quality=qualita, optimize=True, progressive=True)
    print(p, img.size, os.path.getsize(p) // 1024, 'KB')
    return p


def angolo(cartella):
    from ambiente_palette import PALETTE
    fatti = []
    for i, pn in enumerate(('p1_bianco_turchese', 'p2_blu_giallo', 'p3_pastelli_90'), 1):
        f = os.path.join(cartella, f'angolo_{pn}.png')
        if not os.path.exists(f):
            print('manca', f)
            continue
        pal = PALETTE[pn]
        im = con_etichetta(Image.open(f).convert('RGB'), f'OPZIONE {i}', pal['sottotitolo'],
                           'Render 3D (Blender Cycles) dei pezzi del kit, stessa luce e stessa inquadratura')
        salva(im, f'angolo_opzione{i}.jpg')
        fatti.append(im)
    if fatti:
        salva(impila(fatti), 'angolo_confronto.jpg')


def oggetti(cartella):
    f = os.path.join(cartella, 'oggetti_p1_bianco_turchese.png')
    im = con_etichetta(Image.open(f).convert('RGB'), 'OGGETTI DI SCENA (Meshy 3D)',
                       'Paperella, delfino sgonfio, lettino: modelli 3D veri',
                       'Sfondo: angolo di prova, Opzione 1 (solo come contesto)')
    salva(im, 'oggetti_esempi_meshy.jpg')


SALA = [('S04_statua', 'LA STATUA (piedistallo vuoto)', "Dall'ingresso degli spogliatoi: piedistallo, lampione, piscina, cupola"),
        ('S06_pozza', 'LA POZZA', 'Piscina a onde vuota: pozza torbida sul fondo, giocattoli, rosa dei venti'),
        ('S09_vasca_bimbi', 'AREA BIMBI', 'Vasca bassa a scacchi, funghi-fontana, struttura con il secchio gigante'),
        ('S10_torre', 'DALLA TORRE DEGLI SCIVOLI', 'La sala vista dalla piattaforma in cima alla torre'),
        ('panoramica', 'LA SALA PRINCIPALE', 'Vista dalla balconata: cupola, piscina, scivoli, torre'),
        ('S08_piedistallo', 'IL PIEDISTALLO', 'Il piedistallo vuoto da vicino')]


def sala(cartella, uscita=None):
    uscita = uscita or os.path.join(PROPOSTE, 'sala')
    fatti = []
    for nome, tit, sott in SALA:
        f = os.path.join(cartella, f'sala_{nome}.png')
        if not os.path.exists(f):
            continue
        im = con_etichetta(Image.open(f).convert('RGB'), tit, sott,
                           'Render 3D della sala (Blender Cycles): geometria e materiali del gioco')
        salva(im, f'sala_{nome}.jpg', uscita, 90)
        fatti.append(im)
    if fatti:
        salva(impila(fatti, 1080), 'sala_tutte.jpg', uscita, 86)


if __name__ == '__main__':
    {'angolo': angolo, 'oggetti': oggetti, 'sala': sala}[sys.argv[1]](sys.argv[2])
