# Verifica dei vertici dei tentacoli "dentro": distanza esatta dal triangolo più vicino di ogni mesh vicina, con il lato
# (normale del triangolo) e, per i pavimenti, la quota. Uso: python verifica_lei.py <registrazione> <geometria> <tag> <tl> [mesh,...]
import json, sys, numpy as np
from scipy.spatial import cKDTree
R, GEO, TAG, TL = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
argv0 = sys.argv[0]; sys.argv = [argv0.replace('verifica_lei.py', 'analisi_lei.py'), R, GEO, '/dev/null']
src = open(sys.argv[0]).read()
exec(src[:src.index("g = json.load")])
g = json.load(open(GEO + '.json')); gt = np.fromfile(GEO + '.bin', dtype=np.float32).reshape(-1, 3, 3)
fi = min((i for i, f in enumerate(fot) if f.get('tag', '') == TAG), key=lambda i: abs(fot[i]['tl'] - TL))
sk = pelle(fi)
tv = np.concatenate([s_[mesh[k]['tent']] for k, s_ in enumerate(sk)])
lo = tv.min(0) - 0.3; hi = tv.max(0) + 0.3


def dist_tri(p, A, B, C):
    # distanza punto-triangolo (vettorizzata su molti triangoli per un punto)
    ab = B - A; ac = C - A; ap = p - A
    n = np.cross(ab, ac); n2 = (n * n).sum(1)
    t = ((ap) * n).sum(1) / n2
    proj = p - n * t[:, None]
    # coordinate baricentriche
    v0 = ab; v1 = ac; v2 = proj - A
    d00 = (v0 * v0).sum(1); d01 = (v0 * v1).sum(1); d11 = (v1 * v1).sum(1); d20 = (v2 * v0).sum(1); d21 = (v2 * v1).sum(1)
    den = d00 * d11 - d01 * d01
    v = (d11 * d20 - d01 * d21) / den; w = (d00 * d21 - d01 * d20) / den; u = 1 - v - w
    dentro = (u >= 0) & (v >= 0) & (w >= 0)
    d = np.where(dentro, np.abs(t) * np.sqrt(n2), np.inf)
    # fuori dal triangolo: distanza dai lati
    for P0, P1 in ((A, B), (B, C), (C, A)):
        e = P1 - P0; s = np.clip(((p - P0) * e).sum(1) / (e * e).sum(1), 0, 1)
        q = P0 + e * s[:, None]; d = np.minimum(d, np.linalg.norm(p - q, axis=1))
    sign = np.sign(((p - A) * n).sum(1))
    return d, sign, n / np.sqrt(n2)[:, None]


for mi, m in enumerate(g['mesh']):
    b = m['box']
    if b[0] > hi[0] or b[0] + b[3] < lo[0] or b[1] > hi[1] or b[1] + b[4] < lo[1] or b[2] > hi[2] or b[2] + b[5] < lo[2]: continue
    if any(k in m['nodo'].lower() for k in ('medusa', 'acqua', 'water', 'player')): continue
    t = gt[m['da']:m['da'] + m['n']].astype(np.float64)
    c = t.mean(1); sel = np.all((c > lo - 1) & (c < hi + 1), axis=1); t = t[sel]
    if len(t) == 0: continue
    alb = cKDTree(c[sel])
    raggio = np.linalg.norm(t - t.mean(1, keepdims=True), axis=2).max() + 0.06
    dd = []; neg = 0; prof = []
    for p in tv:
        idx = alb.query_ball_point(p, raggio)
        if not idx: continue
        d, s, n = dist_tri(p, t[idx, 0], t[idx, 1], t[idx, 2])
        k = int(np.argmin(d))
        if d[k] < 0.05 and s[k] < 0 and d[k] > 0.01:
            neg += 1; prof.append(d[k])
    if neg:
        print(f"{m['nodo']}: {neg} vertici dei tentacoli a più di 1 cm dalla parte di dietro della superficie, fino a {max(prof)*100:.1f} cm (mediana {np.median(prof)*100:.1f})")
print('tentacoli: vertici', len(tv), 'y min', round(float(tv[:, 1].min()), 3))
