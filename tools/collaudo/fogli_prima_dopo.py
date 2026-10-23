# Fogli prima/dopo: ogni riga una veduta, 4 colonne (prima e dopo nella luce del gioco al 40%, prima e dopo in luce neutra).
# Uso: python fogli_pd.py <uscita.jpg> <titolo> veduta:etichetta ...
import sys, os
from PIL import Image, ImageDraw, ImageFont
T = os.path.dirname(os.path.abspath(__file__))
out, titolo = sys.argv[1:3]
righe = [a.split(':', 1) for a in sys.argv[3:]]
W, H, M = 420, 236, 6
try:
    F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 18)
    Fp = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
except OSError:
    F = Fp = ImageFont.load_default()
top = 64
im = Image.new('RGB', (4 * W + 5 * M, top + len(righe) * (H + 28 + M)), (18, 18, 18))
d = ImageDraw.Draw(im)
d.text((M, 8), titolo, fill=(240, 240, 240), font=F)
for j, c in enumerate(['PRIMA (gioco, luci 40%)', 'DOPO (gioco, luci 40%)', 'PRIMA (luce neutra)', 'DOPO (luce neutra)']):
    d.text((M + j * (W + M), 38), c, fill=(255, 210, 90) if 'DOPO' in c else (180, 180, 180), font=Fp)
for i, (n, et) in enumerate(righe):
    y = top + i * (H + 28 + M)
    # etichetta con * in fondo: nella luce del gioco i due scatti hanno luci diverse (allarme che lampeggia), si
    # mostra solo la luce neutra
    solo_neutra = et.endswith('*')
    et = et.rstrip('*')
    d.text((M, y + 4), et, fill=(230, 230, 230), font=Fp)
    if solo_neutra:
        d.text((M + 10, y + 26 + H // 2), "luce del gioco non confrontabile (luce d'allarme che lampeggia)", fill=(150, 150, 150), font=Fp)
    for j, (cart, suf) in enumerate([('scatti_prima', ''), ('scatti_dopo', ''), ('scatti_prima', '_n'), ('scatti_dopo', '_n')]):
        if solo_neutra and suf == '':
            continue
        p = os.path.join(T, cart, n + suf + '.jpg')
        if os.path.exists(p):
            im.paste(Image.open(p).convert('RGB').resize((W, H)), (M + j * (W + M), y + 26))
im.save(out, quality=88)
print(out, im.size)
