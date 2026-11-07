# Riporta i pixel magenta degli scatti della discesa sul piano del muro ovest della torre (x 20,2): dove stanno in (y, z).
import json, math, glob, sys, os
import numpy as np
from PIL import Image
exec(open('/home/user/collaudo_log/ff21/magenta_portone.py').read().split("# il vano del portone")[0])
tot = []
for f in sorted(glob.glob(sys.argv[1] + '/cubo_discesa*.jpg')):
    nome = os.path.basename(f)[5:-4]; pt, dd = nome.rsplit('_', 1)
    o = punti[pt]; fw = np.array(dirs[dd], float); fw /= np.linalg.norm(fw)
    up = np.array([0, 1, 0.]) if abs(fw[1]) < 0.95 else np.array([1, 0, 0.])
    r = np.cross(fw, up); r /= np.linalg.norm(r); u = np.cross(r, fw)
    a = np.asarray(Image.open(f).convert('RGB')).astype(int)
    m = (a[..., 0] > 150) & (a[..., 2] > 150) & (a[..., 1] < 110) & (abs(a[..., 0] - a[..., 2]) < 60)
    ys, xs = np.nonzero(m)
    if len(xs) == 0: continue
    t = math.tan(math.radians(FOV / 2))
    dx = (xs - W / 2) / (H / 2) * t; dy = -(ys - H / 2) / (H / 2) * t
    d = fw[None, :] + dx[:, None] * r[None, :] + dy[:, None] * u[None, :]
    s = (20.2 - o[0]) / d[:, 0]
    ok = s > 0
    p = o[None, :] + s[ok, None] * d[ok]
    tot.append(p)
    print('%-22s y %.2f..%.2f  z %.2f..%.2f' % (nome, np.percentile(p[:, 1], 1), np.percentile(p[:, 1], 99), np.percentile(p[:, 2], 1), np.percentile(p[:, 2], 99)))
p = np.concatenate(tot)
print('TUTTI: y %.2f..%.2f  z %.2f..%.2f (1-99%%)' % (np.percentile(p[:, 1], 1), np.percentile(p[:, 1], 99), np.percentile(p[:, 2], 1), np.percentile(p[:, 2], 99)))
print('estremi: y %.2f..%.2f  z %.2f..%.2f' % (p[:, 1].min(), p[:, 1].max(), p[:, 2].min(), p[:, 2].max()))
