#!/usr/bin/env python3
"""Collaudo: fogli degli scatti. Mette insieme gli scatti di una cartella in fogli JPG (griglia con il nome
sotto ogni scatto). Uso: foglio.py <cartella> <uscita senza estensione> [colonne=4] [per foglio=24] [larghezza=320]
[filtro: prefisso dei nomi]. Scrive <uscita>_01.jpg, _02.jpg..."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

cart, usc = sys.argv[1], sys.argv[2]
col = int(sys.argv[3]) if len(sys.argv) > 3 else 4
per = int(sys.argv[4]) if len(sys.argv) > 4 else 24
lar = int(sys.argv[5]) if len(sys.argv) > 5 else 320
filtro = sys.argv[6] if len(sys.argv) > 6 else ""
nomi = sorted(f for f in os.listdir(cart) if f.endswith(".jpg") and f.startswith(filtro))
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
except OSError:
    font = ImageFont.load_default()
for k in range(0, len(nomi), per):
    gruppo = nomi[k:k + per]
    im0 = Image.open(os.path.join(cart, gruppo[0]))
    alt = round(lar * im0.height / im0.width)
    righe = (len(gruppo) + col - 1) // col
    foglio = Image.new("RGB", (col * lar, righe * (alt + 18)), (20, 20, 20))
    d = ImageDraw.Draw(foglio)
    for i, n in enumerate(gruppo):
        im = Image.open(os.path.join(cart, n)).convert("RGB").resize((lar, alt), Image.LANCZOS)
        x, y = (i % col) * lar, (i // col) * (alt + 18)
        foglio.paste(im, (x, y))
        d.text((x + 4, y + alt + 2), n[:-4], fill=(255, 230, 120), font=font)
    out = f"{usc}_{k // per + 1:02d}.jpg"
    foglio.save(out, quality=82)
    print(out)
