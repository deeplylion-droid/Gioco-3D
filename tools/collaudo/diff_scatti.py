import sys, os, numpy as np
from PIL import Image
a, b = sys.argv[1], sys.argv[2]
r = []
for f in sorted(os.listdir(b)):
    if not os.path.exists(os.path.join(a, f)): continue
    x = np.asarray(Image.open(os.path.join(a, f)).convert('L'), float)
    y = np.asarray(Image.open(os.path.join(b, f)).convert('L'), float)
    d = np.abs(x - y); r.append((float((d > 40).mean() * 100), f))
r.sort(reverse=True)
print(len(r), "confrontati")
for v, f in r[:int(sys.argv[3]) if len(sys.argv) > 3 else 15]: print("%.2f%% %s" % (v, f))
