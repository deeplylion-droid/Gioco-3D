# vedute delle pile di scatoloni da tutti e due i lati di ogni gruppo (coordinate della risalita)
import json, math, sys
import numpy as np
d = json.load(open(sys.argv[1]))
C = (-35.0, -5.4, 92.0)
def W(p): return (C[0] - p[2], C[1] + p[1], C[2] + p[0])
def yaw(dx, dz):
    wx, wz = -dz, dx
    return math.degrees(math.atan2(-wx, -wz))
g = [o for o in d['piccoli'] if o.get('grande')]
P = np.array([[o['centro'][0], o['centro'][2]] for o in g])
par = list(range(len(P)))
def f(i):
    while par[i] != i: par[i] = par[par[i]]; i = par[i]
    return i
for i in range(len(P)):
    for j in range(i + 1, len(P)):
        if np.linalg.norm(P[i] - P[j]) < 1.7: par[f(i)] = f(j)
gr = {}
for i in range(len(P)): gr.setdefault(f(i), []).append(i)
righe = []
for k, (rad, idx) in enumerate(sorted(gr.items(), key=lambda kv: -len(kv[1]))):
    Q = P[idx]; c = Q.mean(0); u, s, vt = np.linalg.svd(Q - c); ax = vt[0]; n = np.array([-ax[1], ax[0]])
    t = (Q - c) @ ax; w = (Q - c) @ n
    for tt in np.arange(t.min(), t.max() + 0.01, 3.0):
        for lato, sg in (('p', 1), ('m', -1)):
            off = (w.max() if sg > 0 else -w.min()) + 0.6 + 2.5
            cam = c + ax * tt + n * sg * off
            y0 = yaw(-n[0] * sg, -n[1] * sg)
            for h, pitch, nome in ((1.6, -5, 'o'), (1.6, 25, 'a')):
                w3 = W([cam[0], h, cam[1]])
                righe.append("pila%d_%02d_%s%s %.2f %.2f %.2f %.1f %d" % (k, int(round((tt - t.min()) / 3)), lato, nome, w3[0], w3[1], w3[2], y0, pitch))
open(sys.argv[2], 'w').write("\n".join(righe) + "\n")
print(len(righe), "vedute delle pile")
