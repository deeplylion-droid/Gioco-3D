import json, sys, numpy as np
sys.argv = sys.argv[:4]
exec(open(sys.argv[0].replace('parti_squalo.py', 'analisi_squalo.py')).read().split('res = {')[0])
def osso_principale(idx):
    s = sup[0]; bb = bind_bone[s['b'][idx]]; w = s['w'][idx]; c = {}
    for rb, rw in zip(bb, w):
        j = rb[np.argmax(rw)]; c[nomi[j]] = c.get(nomi[j], 0) + 1
    return sorted(c.items(), key=lambda x: -x[1])[:3]
for i, f in enumerate(fot):
    t = f['t']
    if not (8.5 < t < 8.85 or 10.0 < t < 10.75):
        continue
    V = pelle(i)[0]
    muro_n = np.where((V[:, 2] > 0.005) & (V[:, 0] > 18.0) & (V[:, 0] < 21.75))[0]
    vano = (V[:, 0] > 22.0) & (V[:, 0] < 22.2)
    sud = np.where(vano & (V[:, 2] < -1.90))[0]; nord = np.where(vano & (V[:, 2] > -0.68))[0]; alto = np.where(vano & (V[:, 1] > 2.0))[0]
    out = []
    if len(muro_n): out.append(f"muro nord: {len(muro_n)} vertici fino a {V[muro_n,2].max()*100:.1f} cm, {osso_principale(muro_n)}")
    if len(sud): out.append(f"stipite sud: {len(sud)} fino a {(-1.90-V[sud,2].min())*100:.1f} cm, {osso_principale(sud)}")
    if len(nord): out.append(f"stipite nord: {len(nord)} fino a {(V[nord,2].max()+0.68)*100:.1f} cm, {osso_principale(nord)}")
    if len(alto): out.append(f"architrave: {len(alto)} fino a {(V[alto,1].max()-2.0)*100:.1f} cm, {osso_principale(alto)}")
    if out: print(f"t {t:5.2f}: " + " | ".join(out))
