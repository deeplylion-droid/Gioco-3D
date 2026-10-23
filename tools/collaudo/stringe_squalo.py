import json, sys, numpy as np
sys.argv = [sys.argv[0].replace('stringe_squalo.py','analisi_squalo.py'), sys.argv[1], sys.argv[2], 'x']
exec(open(sys.argv[0]).read().split('res = {')[0])
# scala delle ossa del busto nel tempo e larghezza del corpo (perpendicolare alla direzione del corpo, in orizzontale)
busto = [n for n in nomi if any(k in n.lower() for k in ('spina', 'busto', 'torace', 'petto', 'bacino', 'collo'))]
print('ossa', busto)
for fi in range(0, len(fot), 3):
    t = fot[fi]['t']
    if t < 9.0 or t > 12.0: continue
    sc = {}
    for n in busto:
        p = pose_all[fi, nomi.index(n)]
        sc[n] = [round(float(np.linalg.norm(p[k])), 2) for k in range(3)]
    sk = pelle(fi)[0]
    # direzione del corpo: dal bacino alla testa (in orizzontale)
    a = osso(fi, busto[0]); b = osso(fi, 'testa')
    d = (b - a); d[1] = 0; d /= np.linalg.norm(d) + 1e-9
    lat = np.array([-d[2], 0, d[0]])
    m = (sk[:, 1] > 0.6) & (sk[:, 1] < 1.6)
    w = sk[m] @ lat
    print(f"t {t:5.2f} larghezza busto {w.max()-w.min():.2f} m  scale {sc}")
