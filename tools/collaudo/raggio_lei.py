import json, sys, numpy as np
from scipy.spatial import cKDTree
R, GEO, TAG, TL = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
argv0 = sys.argv[0]; sys.argv = [argv0.replace('raggio_lei.py', 'analisi_lei.py'), R, GEO, '/dev/null']
src = open(sys.argv[0]).read(); exec(src[:src.index("g = json.load")])
fi = min((i for i, f in enumerate(fot) if f.get('tag', '') == TAG), key=lambda i: abs(fot[i]['tl'] - TL))
sk = pelle(fi)
k = [i for i, s in enumerate(mesh) if s['nome'] == 'Medusa_Tentacoli'][0]
V = sk[k]; princ = mesh[k]['princ']
P = pose_all[fi, :, 3]
# raggio: distanza di ogni vertice dall'osso principale (segmento osso -> figlio)
figlio = {}
for i, n in enumerate(nomi):
    if n.startswith('tentacolo_'):
        a = n.rsplit('_', 1); nx = a[0] + '_%02d' % (int(a[1]) + 1)
        if nx in nomi: figlio[i] = nomi.index(nx)
rr = []
for vi in range(0, len(V), 7):
    b = princ[vi]
    if b < 0 or b not in figlio: continue
    A, B = P[b], P[figlio[b]]; e = B - A; s = np.clip(((V[vi] - A) @ e) / (e @ e), 0, 1)
    rr.append(np.linalg.norm(V[vi] - (A + e * s)))
rr = np.array(rr)
print('raggio del tentacolo (vertici dall asse): mediana %.1f cm, 90%% %.1f cm, max %.1f cm' % (np.median(rr) * 100, np.percentile(rr, 90) * 100, rr.max() * 100))
# assi a terra: ossa dei tentacoli sopra il pavimento della sala (y fra -0.05 e 0.1) e i vertici della loro pelle sotto 0
ossa_t = [i for i, n in enumerate(nomi) if n.startswith('tentacolo_')]
ya = P[ossa_t, 1]
print('ossa dei tentacoli con y fra -0.02 e 0.08:', int(((ya > -0.02) & (ya < 0.08)).sum()), 'di', len(ossa_t), '; y di quelle', np.round(np.sort(ya[(ya > -0.02) & (ya < 0.08)])[:12], 3))
