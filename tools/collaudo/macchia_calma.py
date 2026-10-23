# Macchia più calma (proposta, fuori dal gioco): stessa forma, bordi più morbidi, meno coprente, colore meno acceso.
# Uso: python semplifica_macchia.py <png con alfa> <uscita.png> [alfa 0.5] [sfocatura 0.006] [saturazione 0.6]
import sys, numpy as np
from PIL import Image, ImageFilter
src, out = sys.argv[1:3]
fa = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
sf = float(sys.argv[4]) if len(sys.argv) > 4 else 0.006
sat = float(sys.argv[5]) if len(sys.argv) > 5 else 0.6
im = Image.open(src).convert('RGBA')
r = max(1.0, sf * im.size[0])
a = np.asarray(im.getchannel('A').filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) * fa
rgb = np.asarray(im.convert('RGB'), dtype=np.float32)
grigio = rgb.mean(-1, keepdims=True)
rgb = grigio + (rgb - grigio) * sat
Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 255)]).astype(np.uint8), 'RGBA').save(out)
print('fatto', src)
