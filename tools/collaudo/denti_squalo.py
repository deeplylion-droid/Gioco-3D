import json, sys, numpy as np
TEMPI_ARG = ''
sys.argv = sys.argv[:4]
exec(open(sys.argv[0].replace('denti_squalo.py', 'analisi_squalo.py')).read().split('res = {')[0])
a = open(sys.argv[0].replace('denti_squalo.py', 'analisi_squalo.py')).read()
exec(a[a.index("denti_i = "):a.index("piede_v = {}")].replace("res['denti'] = len(denti)", "pass"))
# apertura della bocca nel tempo: distanza fra le ossa bocca e mento_punta
ap = np.array([np.linalg.norm(osso(i, 'mento_punta') - osso(i, 'testa')) for i in range(len(fot))])
tt = np.array([f['t'] for f in fot])
i_max = int(np.argmax(ap[tt < 6.2])); 
print('bocca: apertura (testa-mento) min %.3f max %.3f a t %.2f' % (ap.min(), ap.max(), tt[i_max]))
# i morsi: minimi locali dell'apertura prima della girata
mins = [i for i in range(1, len(ap) - 1) if ap[i] <= ap[i - 1] and ap[i] < ap[i + 1] and tt[i] < 8.2]
print('morsi (bocca più chiusa) a t', [round(tt[i], 2) for i in mins][:12])
def seg_tri(P0, P1, T):
    # intersezioni segmenti-triangoli (Möller), a blocchi
    hits = np.zeros(len(P0), bool)
    v0 = T[:, 0]; e1 = T[:, 1] - v0; e2 = T[:, 2] - v0
    for s in range(0, len(P0), 400):
        o = P0[s:s + 400, None]; D = (P1 - P0)[s:s + 400, None]
        pp = np.cross(D, e2[None]); det = (e1[None] * pp).sum(-1); ok = np.abs(det) > 1e-14
        inv = np.where(ok, 1 / np.where(ok, det, 1), 0); sv = o - v0[None]
        u = (sv * pp).sum(-1) * inv; q = np.cross(sv, e1[None]); v = (q * D).sum(-1) * inv; t = (e2[None] * q).sum(-1) * inv
        hits[s:s + 400] = (ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t >= 0) & (t <= 1)).any(1)
    return hits
for fi in [0, i_max] + mins[:6]:
    sk = pelle(fi)
    D_ = sk[denti_i]; Td = sup[denti_i]['i']
    E = np.concatenate([Td[:, [0, 1]], Td[:, [1, 2]], Td[:, [2, 0]]])
    for nome, k in (('bocca_interno (palato e lingua)', bocca_i), ('gola', gola_i), ('gengiva', geng_i)):
        T = sk[k][sup[k]['i']]
        h = seg_tri(D_[E[:, 0]], D_[E[:, 1]], T)
        quali = sorted(set(comp[E[h, 0]]))
        idx = [list(np.unique(comp)).index(c) for c in quali]
        print(f"t {tt[fi]:5.2f} apertura {ap[fi]:.3f}: spigoli dei denti che passano {nome}: {h.sum()}, denti {len(idx)} {idx[:20]}")
