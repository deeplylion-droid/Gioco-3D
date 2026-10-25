# conta i pixel magenta (vuoto fuori dal livello) nelle maschere <nome>_m.png di una sonda: python3 conta_magenta.py <cartella>
import sys, os
from PIL import Image
d = sys.argv[1]
res = []
for f in sorted(os.listdir(d)):
    if not f.endswith("_m.png"): continue
    im = Image.open(os.path.join(d, f)).convert("RGB"); px = im.load(); w, h = im.size; n = 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 200 and g < 60 and b > 200: n += 1
    res.append((n, f))
res.sort(reverse=True)
tot = sum(1 for n, f in res if n > 0)
print("viste %d, con vuoto %d" % (len(res), tot))
for n, f in res[:25]:
    if n > 0: print("  %6d px  %s" % (n, f))
