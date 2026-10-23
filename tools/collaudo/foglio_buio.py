# foglio del giro al buio: per ogni interattivo lo scatto al buio e lo stesso con la luce sulla camera
import sys, json
from PIL import Image, ImageDraw, ImageFont
d_, out = sys.argv[1], sys.argv[2]
E = [e for e in json.load(open(d_ + '/interattivi.json')) if e.get('veduta', '').startswith('int_')]
F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
W, H = 480, 270
im = Image.new('RGB', (2 * W + 6, len(E) * (H + 24)), (18, 18, 18)); d = ImageDraw.Draw(im)
for i, e in enumerate(E):
    y = i * (H + 24)
    d.text((4, y + 4), f"{e['n']}. {e['nodo']} ({e['prompt']}) a {e['distanza']} m", fill=(240, 240, 240), font=F)
    im.paste(Image.open(f"{d_}/{e['veduta']}.jpg").resize((W, H)), (0, y + 22))
    try: im.paste(Image.open(f"{d_}/{e['veduta']}_luce.jpg").resize((W, H)), (W + 6, y + 22))
    except Exception: pass
im.save(out, quality=85); print(out, len(E), [e['nodo'] for e in json.load(open(d_ + '/interattivi.json')) if not e.get('veduta', '').startswith('int_')])
