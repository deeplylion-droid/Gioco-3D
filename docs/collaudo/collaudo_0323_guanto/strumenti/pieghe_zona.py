"""Pieghe (angolo fra le normali di due facce vicine) in una scatola glTF. Uso: pieghe_zona.py V.npy F.npy x0 y0 z0 x1 y1 z1"""
import sys, numpy as np
V, F = np.load(sys.argv[1]), np.load(sys.argv[2])
lo, hi = np.array([float(x) for x in sys.argv[3:6]]), np.array([float(x) for x in sys.argv[6:9]])
n = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]); n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-30
e = {}
for fi, f in enumerate(F):
    for a, b in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
        e.setdefault((min(a, b), max(a, b)), []).append(fi)
out = []
for (a, b), fs in e.items():
    if len(fs) != 2: continue
    m = (V[a] + V[b]) / 2
    if not (np.all(m >= lo) and np.all(m <= hi)): continue
    ang = np.degrees(np.arccos(np.clip(np.dot(n[fs[0]], n[fs[1]]), -1, 1)))
    out.append((ang, tuple(np.round(m, 4))))
out.sort(reverse=True)
A = np.array([o[0] for o in out])
print("spigoli nella scatola %d; piega massima %.0f gradi; oltre 60: %d, oltre 90: %d, oltre 120: %d, oltre 150: %d" % (len(A), A.max(), (A > 60).sum(), (A > 90).sum(), (A > 120).sum(), (A > 150).sum()))
for o in out[:5]: print("   %.0f gradi in %s" % o)
