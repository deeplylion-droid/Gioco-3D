"""Il rosa per fotogramma fuori dal motore: per ogni fotogramma piccolo (320x180) di scatti_lampo_bacino.gd, quanti pixel
diventano rosa rispetto al riferimento (rosso e blu salgono più del verde), e dove. Uso: misura_rosa.py <cartella> <punto>"""
import os, sys
import numpy as np
from PIL import Image
d = os.path.join(sys.argv[1], sys.argv[2] + '_piccoli')
R = np.asarray(Image.open(os.path.join(d, 'riferimento.png')).convert('RGB')).astype(float) / 255
righe = []
for f in sorted(x for x in os.listdir(d) if x[0].isdigit()):
    A = np.asarray(Image.open(os.path.join(d, f)).convert('RGB')).astype(float) / 255
    dr, dg, db = (A - R).transpose(2, 0, 1)
    m = (dr > dg + 0.025) & (db > dg + 0.012) & (dr > 0.02)
    righe.append((int(f[:4]), int(m.sum()), float(((dr + db) / 2 - dg)[m].mean() * 255) if m.any() else 0.0))
tot = len(righe)
rosa = [r for r in righe if r[1] > 80]   # (80 su 57600 = gli stessi 20 su 14400 della misura di ambienti-2)
print('%s: %d fotogrammi, con più di 80 pixel rosa su 57600: %d %s; il peggiore %s' % (sys.argv[2], tot, len(rosa),
      [r[0] for r in rosa][:60], max(righe, key=lambda r: r[1]) if righe else '-'))
