"""Riferimenti INTERNI per la fauce (Meshy image-to-image): solo input per modellare, NON da consegnare.

L'utente non vuole vedere immagini generate dall'IA: queste restano in build/riferimenti_interni/
(ignorata da git) e servono solo come riferimento per costruire la fauce in 3D (medusa_fauce.py).

Parte da docs/concept/medusa_sbircia.jpg (la scena preferita dall'utente) e chiede a Meshy di cambiare
SOLO il viso sotto l'occhio: la pelle si strappa e mostra piu' file di denti da squalo.
Varianti: taglio verticale, taglio orizzontale da guancia a guancia, viso che si apre a petali.
Tutto il resto deve restare identico (un solo occhio, capelli, niente croce, posa, sfondo).

Scrive le immagini e una tavola di confronto in assets_src/medusa/build/riferimenti_interni/.
Non usa bpy: si lancia con qualsiasi python (serve MESHY_API_KEY):
    /home/user/tools/blender-venv/bin/python tools/blender/medusa_proposta_fauce.py [--rifai NOME|tutte]
"""
import base64
import json
import os
import sys

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import meshy  # noqa: E402

SORGENTE = os.path.join(REPO, 'docs', 'concept', 'medusa_sbircia.jpg')
CARTELLA = os.path.join(REPO, 'assets_src', 'medusa', 'build', 'riferimenti_interni', 'fauce')
TAVOLA = os.path.join(REPO, 'assets_src', 'medusa', 'build', 'riferimenti_interni', 'E_fauce.jpg')
MODELLO = 'nano-banana-pro'

COMUNE = (
    "Edit ONLY the lower half of the creature's face, below the single big eye. Keep everything else exactly "
    "identical to the reference image: same single cyclops eye with pink iris (only one eye, never two eyes), "
    "same wavy silver-pink hair, same pose with both hands gripping the pool edge, same smooth periwinkle "
    "vinyl-doll skin, same magenta tentacles, same dark abandoned indoor water park at night with red emergency "
    "lights, same camera framing and lighting. No cross or symbol on the forehead, no clothing, no extra eyes, "
    "no nipples, no text. The glowing pink translucent jellyfish bell with radial light canals stays visible "
    "under the water surface below the torso, exactly as in the reference. The creature attacks: the smooth doll skin of the face under the eye RIPS OPEN with "
    "ragged torn edges like torn rubber and wet flesh, revealing a huge gaping maw lined with several rows of "
    "sharp serrated triangular shark teeth, dark red wet throat inside. Photorealistic horror, same rendering "
    "style as the reference. "
)
VARIANTI = [
    ('1_verticale', 'Opzione 1: strappo verticale',
     "The tear is VERTICAL: a long rip that starts right under the eye and runs straight down to the chin; the two "
     "sides of the face peel apart left and right like a vertical mouth, with rows of shark teeth along both "
     "vertical edges."),
    ('2_orizzontale', 'Opzione 2: strappo orizzontale',
     "The tear is HORIZONTAL: a wide rip from cheek to cheek just below the eye, opening like an enormous jaw that "
     "drops open; the upper and lower torn edges are lined with multiple rows of shark teeth."),
    ('3_petali', 'Opzione 3: viso a petali',
     "The lower face SPLITS INTO FOUR PETALS: the skin under the eye tears into four pointed flaps that peel outward "
     "like a blooming flower, each flap lined on its inner side with rows of small shark teeth, revealing a round "
     "dark throat ringed with teeth in the center."),
]


def data_uri(path):
    with open(path, 'rb') as f:
        return 'data:image/jpeg;base64,' + base64.b64encode(f.read()).decode()


def genera(nome, extra):
    os.makedirs(CARTELLA, exist_ok=True)
    out = os.path.join(CARTELLA, f'{nome}.png')
    info = os.path.join(CARTELLA, f'{nome}.json')
    rifai = '--rifai' in sys.argv and sys.argv[sys.argv.index('--rifai') + 1] in (nome, 'tutte')
    if os.path.exists(out) and not rifai:
        print('gia\' fatto', out)
        return out
    body = {'ai_model': MODELLO, 'prompt': COMUNE + extra, 'reference_image_urls': [data_uri(SORGENTE)],
            'aspect_ratio': '16:9'}
    tid = meshy.create('image-to-image', body)
    print('task', nome, tid, flush=True)
    t = meshy.wait('image-to-image', tid)
    if t['status'] != 'SUCCEEDED':
        raise RuntimeError(f'{nome}: {t["status"]} {t.get("task_error")}')
    meshy.download(t['image_urls'][0], out)
    with open(info, 'w') as f:
        json.dump({'task_id': tid, 'modello': MODELLO, 'prompt': body['prompt']}, f, indent=1)
    print('scaricato', out, flush=True)
    return out


def tavola(percorsi):
    sys.path.insert(0, QUI)
    from PIL import Image, ImageDraw, ImageFont
    FONT_B = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
    celle = [(SORGENTE, 'Riferimento approvato (bocca chiusa)')] + percorsi
    W = 960
    ims = []
    for p, t in celle:
        im = Image.open(p).convert('RGB')
        im = im.resize((W, int(im.size[1] * W / im.size[0])), Image.LANCZOS)
        ims.append((im, t))
    h = ims[0][0].size[1]
    eh, gap = 74, 10
    titolo = 84
    out = Image.new('RGB', (2 * W + 3 * gap, titolo + 2 * (h + eh) + 3 * gap), (18, 18, 22))
    d = ImageDraw.Draw(out)
    d.text((out.size[0] // 2, titolo // 2 + 4), 'E. La fauce: come si apre?', fill=(255, 255, 255),
           font=ImageFont.truetype(FONT_B, 50), anchor='mm')
    for i, (im, t) in enumerate(ims):
        r, c = divmod(i, 2)
        x = gap + c * (W + gap); y = titolo + gap + r * (h + eh + gap)
        d.rectangle((x, y, x + W, y + eh - 2), fill=(250, 250, 250) if i else (200, 200, 205))
        d.text((x + W // 2, y + eh // 2), t, fill=(15, 15, 20), font=ImageFont.truetype(FONT_B, 40), anchor='mm')
        out.paste(im.resize((W, h)), (x, y + eh))
    out.save(TAVOLA, quality=90)
    print('tavola', TAVOLA, out.size)


if __name__ == '__main__':
    fatti = []
    for nome, etichetta, extra in VARIANTI:
        fatti.append((genera(nome, extra), etichetta))
    tavola(fatti)
