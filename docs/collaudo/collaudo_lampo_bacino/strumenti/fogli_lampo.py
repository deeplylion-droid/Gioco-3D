"""Fogli del ricontrollo del lampo rosa sul bacino (#131). Uso: fogli_lampo.py <cartella lampo> [quali]"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
L = sys.argv[1]
QUALI = sys.argv[2].split(',') if len(sys.argv) > 2 else ['1', '2', '3']
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
TW, BAR = 480, 24
def casella(p, t, w=TW):
    im = Image.open(p).convert('RGB')
    h = round(im.height * w / im.width)
    o = Image.new('RGB', (w, h + BAR), (20, 20, 20))
    o.paste(im.resize((w, h), Image.LANCZOS), (0, BAR))
    ImageDraw.Draw(o).text((6, 3), t, font=FONT, fill=(235, 235, 235))
    return o
def griglia(c, col, nome):
    r = [c[i:i + col] for i in range(0, len(c), col)]
    W = max(sum(x.width for x in rr) for rr in r); H = sum(max(x.height for x in rr) for rr in r)
    o = Image.new('RGB', (W, H), (20, 20, 20)); y = 0
    for rr in r:
        x = 0
        for cc in rr:
            o.paste(cc, (x, y)); x += cc.width
        y += max(cc.height for cc in rr)
    o.save(os.path.join(L, 'fogli', nome), quality=88); print('foglio', nome, o.size)
if '1' in QUALI:
    c = []
    for d, v in [('prima2', 'senza correzione'), ('dopo2', 'con la correzione')]:
        c.append(casella(f'{L}/{d}/mezzo_riferimento.jpg', f'{v}: prima del tunnel'))
        for k in [90, 92, 96]:
            c.append(casella(f'{L}/{d}/mezzo_{k:04d}.jpg', f'{v}: fotogramma {k}, riscalda'))
    griglia(c, 4, '1_lampo_prima_dopo.jpg')
if '2' in QUALI:
    c = []
    for q, t in [('ripartenza', 'dove si riparte'), ('mezzo', 'mezzo del bacino'), ('scaletta', 'in cima alla scaletta')]:
        fs = sorted(f for f in os.listdir(f'{L}/dopo2') if f.startswith(q + '_0'))
        c.append(casella(f'{L}/dopo2/{q}_riferimento.jpg', f'{t}: prima del tunnel'))
        c.append(casella(f'{L}/dopo2/{fs[1]}', f'{t}: fotogramma {fs[1][-8:-4]}, riscalda'))
        c.append(casella(f'{L}/dopo2/{q}_pronto.jpg', f'{t}: tunnel pronto'))
    griglia(c, 3, '2_correzione_tre_punti.jpg')
if '3' in QUALI:
    c = []
    for f, t in [('luce_avanti', 'corre, la luce rosa avanti'), ('morso', 'si gira, il morso'), ('ritrae', 'lei si ritrae')]:
        c.append(casella(f'{L}/video_base/{f}_dopo.png', f'senza correzione: {t}'))
        c.append(casella(f'{L}/video_dopo/{f}_dopo.png', f'con la correzione: {t}'))
    griglia(c, 2, '3_inseguimento_prima_dopo.jpg')
