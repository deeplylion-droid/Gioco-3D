"""Lente sul guanto senza motore: piccolo render ortografico (raggi su triangoli) attorno a un punto glTF, guardando
dalla direzione data (o dalla normale media). Uso: lente_np.py V.npy F.npy uscita.png x y z [lato_mm] [dx dy dz]"""
import sys
import numpy as np
from PIL import Image
V = np.load(sys.argv[1]); F = np.load(sys.argv[2]); out = sys.argv[3]
c = np.array([float(x) for x in sys.argv[4:7]]); lato = float(sys.argv[7]) / 1000 if len(sys.argv) > 7 else 0.02
A, B, C = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
n = np.cross(B - A, C - A); n /= np.maximum(np.linalg.norm(n, axis=1)[:, None], 1e-15)
cen = (A + B + C) / 3
vic = np.linalg.norm(cen - c, axis=1) < lato * 1.5
if len(sys.argv) > 10:
    d = -np.array([float(x) for x in sys.argv[8:11]])
else:
    d = -n[vic].mean(0)
d /= np.linalg.norm(d)
u = np.cross(d, [0, 1, 0]); u = u / np.linalg.norm(u) if np.linalg.norm(u) > 1e-6 else np.array([1., 0, 0])
w = np.cross(u, d)
A, B, C, nn = A[vic], B[vic], C[vic], n[vic]
R = 320
img = np.zeros((R, R, 3), np.uint8); img[:] = (40, 50, 70)
e1, e2 = B - A, C - A
for j in range(R):
    for i in range(R):
        o = c + u * ((i / R - 0.5) * lato) - w * ((j / R - 0.5) * lato) - d * 0.05
        p = np.cross(d, e2); det = (e1 * p).sum(1)
        ok = np.abs(det) > 1e-14
        inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
        s = o - A; uu = (s * p).sum(1) * inv
        q = np.cross(s, e1); vv = (q * d).sum(1) * inv; t = (e2 * q).sum(1) * inv
        hit = ok & (uu >= 0) & (vv >= 0) & (uu + vv <= 1) & (t > 0)
        if hit.any():
            k = np.where(hit)[0][np.argmin(t[hit])]
            dn = np.dot(nn[k], -d)
            if dn >= 0:
                g = int(60 + 190 * max(0.0, np.dot(nn[k], -d * 0.8 + w * 0.6 / 1.0)))
                img[j, i] = (min(g, 255),) * 3
            else:
                img[j, i] = (230, 40, 200)  # faccia rovesciata vista da dietro
img = Image.fromarray(img).resize((640, 640), Image.NEAREST)
img.save(out)
print('lente', out, 'centro', c, 'guardando verso', np.round(d, 3), 'lato %.0f mm' % (lato * 1000))
