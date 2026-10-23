# Per ogni osso dei tentacoli: le superfici sopra e sotto nella sua verticale (campioni entro 3 cm di lato), con la
# normale. Un osso con sopra di sé, vicino, una superficie che guarda in su (un pavimento) è sotto il pavimento.
import json, sys, numpy as np
from scipy.spatial import cKDTree
R, GEO, TAG, TL = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4]); PRE = sys.argv[5] if len(sys.argv) > 5 else 'tentacolo_'
argv0 = sys.argv[0]; sys.argv = [argv0.replace('sotto_lei.py', 'analisi_lei.py'), R, GEO, '/dev/null']
src = open(sys.argv[0]).read(); exec(src[:src.index("res = {")])
fi = min((i for i, f in enumerate(fot) if f.get('tag', '') == TAG), key=lambda i: abs(fot[i]['tl'] - TL))
P = pose_all[fi, :, 3]
alb2 = cKDTree(pts[:, [0, 2]])
sotto = []
for i, n in enumerate(nomi):
    if not n.startswith(PRE): continue
    q = P[i]
    idx = alb2.query_ball_point(q[[0, 2]], 0.03)
    if not idx: continue
    ys = pts[idx, 1]; ny = nor[idx, 1]
    sopra = [(ys[j] - q[1], ny[j], nomi_g[own[idx[j]]].split('/')[-1]) for j in range(len(idx)) if ys[j] > q[1]]
    if sopra:
        s = min(sopra)
        if s[1] > 0.5 and s[0] < 1.5:   # un pavimento (normale in su) sopra l'osso
            sotto.append((n, round(float(q[1]), 2), round(float(s[0]) * 100, 1), s[2]))
print(len(sotto), 'ossa dei tentacoli sotto un pavimento (sopra di loro, entro 1,5 m, una superficie che guarda in su):')
for x in sorted(sotto, key=lambda x: -x[2])[:25]: print('  ', x)
