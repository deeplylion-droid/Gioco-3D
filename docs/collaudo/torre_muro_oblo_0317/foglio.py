"""Foglio: righe = viste, colonne = versioni. uso: foglio.py <uscita.jpg> <titolo> <viste,separate,da,virgola> <etichetta=dir> ..."""
import sys, os
from PIL import Image, ImageDraw, ImageFont

uscita, titolo, viste = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
colonne = [a.split("=", 1) for a in sys.argv[4:]]
W, H = 640, 360
f = ImageFont.load_default(size=20)
im = Image.new("RGB", (W * len(colonne), 40 + len(viste) * (H + 28)), (20, 20, 20))
dr = ImageDraw.Draw(im)
dr.text((10, 8), titolo, fill=(255, 255, 255), font=f)
for r, v in enumerate(viste):
    y = 40 + r * (H + 28)
    for c, (et, d) in enumerate(colonne):
        p = os.path.join(d, v + ".png")
        dr.text((c * W + 8, y + 3), "%s - %s" % (v, et), fill=(255, 230, 120), font=f)
        if os.path.exists(p):
            im.paste(Image.open(p).convert("RGB").resize((W, H)), (c * W, y + 28))
im.save(uscita, quality=86)
print(uscita, im.size)
