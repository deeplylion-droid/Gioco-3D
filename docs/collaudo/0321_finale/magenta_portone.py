# Per ogni scatto magenta della discesa: i pixel magenta fuori dal vano del portone proiettato (la sala non c'è nella
# corsa "torre da sola", quindi il vano è magenta per forza).
import json, math, glob, sys, os
import numpy as np
from PIL import Image
d = json.load(open('/home/user/wt/collaudo/godot/assets/ambiente/torre/torre_percorso.json'))
punti = {}
k = 0
for q in d:
    if q['cosa'] not in ('scivolo', 'pedana'):
        continue
    if k % 3 == 0:
        punti['discesa%02d' % k] = np.array([q['x'], q['z'] + 1.0, -q['y']])
    k += 1
dirs = {"est": (1, 0, 0.001), "ovest": (-1, 0, 0.001), "nord": (0.001, 0, -1), "sud": (0.001, 0, 1), "su": (0.001, 1, 0.002), "giu": (0.001, -1, 0.002)}
W, H, FOV = 1280, 720, 90.0
def proietta(o, f, up, p):
    f = f / np.linalg.norm(f); r = np.cross(f, up); r /= np.linalg.norm(r); u = np.cross(r, f)
    v = p - o; z = v @ f
    if z <= 0.05: return None
    t = math.tan(math.radians(FOV / 2))
    x = (v @ r) / (z * t) * (H / 2) + W / 2; y = H / 2 - (v @ u) / (z * t) * (H / 2)
    return x, y
# il vano del portone, largo: x 19,9..20,3, y -0,5..4,5, z -16,8..-13,2
ang = [np.array([x, y, z]) for x in (19.5, 20.6) for y in (-1.0, 5.0) for z in (-18.5, -11.5)]
fuori_tot = 0
for f in sorted(glob.glob(sys.argv[1] + '/cubo_discesa*.jpg')):
    nome = os.path.basename(f)[5:-4]; pt, dd = nome.rsplit('_', 1)
    o = punti[pt]; fw = np.array(dirs[dd], float); up = np.array([0, 1, 0.]) if abs(fw[1]) < 0.95 else np.array([1, 0, 0.])
    a = np.asarray(Image.open(f).convert('RGB')).astype(int)
    m = (a[..., 0] > 150) & (a[..., 2] > 150) & (a[..., 1] < 110) & (abs(a[..., 0] - a[..., 2]) < 60)
    if m.sum() == 0: continue
    pr = [proietta(o, fw, up, c) for c in ang]
    if any(p is None for p in pr):
        fuori = int(m.sum())
    else:
        xs = [p[0] for p in pr]; ys = [p[1] for p in pr]
        ys_, xs_ = np.nonzero(m)
        dentro = (xs_ >= min(xs) - 10) & (xs_ <= max(xs) + 10) & (ys_ >= min(ys) - 10) & (ys_ <= max(ys) + 10)
        fuori = int((~dentro).sum())
    fuori_tot += fuori
    print('%-26s magenta %6d, fuori dal vano del portone %d' % (nome, int(m.sum()), fuori))
print('TOTALE fuori dal vano', fuori_tot)
