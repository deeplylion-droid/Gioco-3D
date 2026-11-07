"""Spigoli piegati del guanto (angolo fra le facce vicine) e facce rovesciate: dove sono, in coordinate glTF."""
import sys
import numpy as np
from collections import defaultdict
V = np.load(sys.argv[1]); F = np.load(sys.argv[2])
n = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
ar = np.linalg.norm(n, axis=1); n = n / np.maximum(ar[:, None], 1e-15)
ed = defaultdict(list)
for i, f in enumerate(F):
    for a, b in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
        ed[(min(a, b), max(a, b))].append(i)
ang = []
for e, fs in ed.items():
    if len(fs) == 2:
        c = np.clip(np.dot(n[fs[0]], n[fs[1]]), -1, 1)
        ang.append((np.degrees(np.arccos(c)), e, fs))
ang.sort(key=lambda x: -x[0])
print('facce minuscole (area < 1e-10 m2):', (ar / 2 < 1e-10).sum())
for soglia in (60, 90, 120, 150):
    print('spigoli piegati oltre %d gradi: %d' % (soglia, sum(1 for a in ang if a[0] > soglia)))
# raggruppa gli spigoli oltre 60 gradi per vicinanza (2 mm)
forti = [a for a in ang if a[0] > 60]
pts = np.array([(V[e[0]] + V[e[1]]) / 2 for _, e, _ in forti]) if forti else np.zeros((0, 3))
gr = []
for i, p in enumerate(pts):
    for g in gr:
        if np.min(np.linalg.norm(pts[g] - p, axis=1)) < 0.003:
            g.append(i); break
    else:
        gr.append([i])
for g in sorted(gr, key=len, reverse=True)[:15]:
    c = pts[g].mean(0); mx = max(forti[i][0] for i in g)
    print('  %3d spigoli, fino a %.0f gradi, centro (%.4f, %.4f, %.4f), scatola %s mm' % (len(g), mx, *c, np.round((pts[g].max(0) - pts[g].min(0)) * 1000, 1)))
