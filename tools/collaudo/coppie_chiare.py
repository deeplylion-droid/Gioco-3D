# righe prima | dopo, schiarite (le viste del fiume sono buie): <prima> <dopo> <uscita> <guadagno> <viste,...>
import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
P, D, OUT, G = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]); V = sys.argv[5].split(',')
F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 14)
W, H = 640, 360
im = Image.new('RGB', (2 * W, len(V) * H)); d = ImageDraw.Draw(im)
for r, v in enumerate(V):
    for c, (cart, t) in enumerate([(P, os.environ.get('ETI_A', 'prima')), (D, os.environ.get('ETI_B', 'correzione'))]):
        x = ImageEnhance.Brightness(Image.open(os.path.join(cart, v + '.jpg')).convert('RGB')).enhance(G)
        im.paste(x.resize((W - 2, H - 2)), (c * W, r * H)); d.text((c * W + 4, r * H + 3), f'{v}  {t}', fill=(255, 255, 0), font=F)
im.save(OUT, quality=85)
