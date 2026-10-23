import json, sys, numpy as np
from scipy.spatial import cKDTree
sys.argv = sys.argv[:4]
exec(open(sys.argv[0].replace('bava_squalo.py', 'analisi_squalo.py')).read().split('res = {')[0])
d2 = open(sys.argv[0].replace('bava_squalo.py', 'dettagli_squalo.py')).read()
exec(d2[d2.index('def campiona'):d2.index('def dentro')])
for tq in (0.5, 1.0, 2.0, 3.0, 4.5, 5.5, 6.5, 7.5):
    fi = min(range(len(fot)), key=lambda i: abs(fot[i]['t'] - tq)); f = fot[fi]
    sk = pelle(fi)
    alb = cKDTree(np.concatenate([campiona(sk[k], sup[k]['i'], 0.004) for k in range(len(sk))]))
    b = np.array(f['bava'])
    if len(b) == 0:
        print(f"t {f['t']}: nessuna bava (forza {f['bava_forza']})"); continue
    dd = alb.query(b)[0]
    cam = np.array(f['camera'])
    capi = [[round(alb.query(a)[0] * 1000, 1), round(alb.query(c)[0] * 1000, 1), i, round(float(np.linalg.norm(np.array(a) - cam)), 2)] for a, c, i in f['capi_bava']]
    print(f"t {f['t']:5.2f} forza {f['bava_forza']}: {len(b)} punti della bava, distanza dalla pelle mm: min {dd.min()*1000:.1f} mediana {np.median(dd)*1000:.1f} max {dd.max()*1000:.1f}; oltre 10 mm: {int((dd>0.01).sum())}; capi (su, giù, intero, dist. camera) {capi}")
