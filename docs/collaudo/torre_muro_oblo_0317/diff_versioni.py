"""uso: diff_versioni.py <dir_a> <dir_b>: per ogni scatto presente in tutte e due (non _come_0316/_di_nuovo)"""
import sys, os, glob
import numpy as np
from PIL import Image
def carica(p): return np.asarray(Image.open(p).convert("RGB")).astype(np.int16)
a, b = sys.argv[1], sys.argv[2]
for pa in sorted(glob.glob(os.path.join(a, "*.png"))):
    n = os.path.basename(pa)
    if "_come_0316" in n or "_di_nuovo" in n: continue
    pb = os.path.join(b, n)
    if not os.path.exists(pb): continue
    x, y = carica(pa), carica(pb)
    d = np.abs(x - y).max(axis=2); m = d > 8
    print("%-28s media %.2f, %6.2f%% px >8, max %3d" % (n[:-4], float(np.abs(x - y).mean()), m.mean() * 100, int(d.max())))
