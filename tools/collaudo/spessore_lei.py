# Tentacoli: per ogni tratto (osso -> figlio) il raggio della pelle e la distanza del suo asse dalla superficie vera più
# vicina: se l'asse sta più vicino del raggio, il tubo entra nella superficie (di raggio - distanza).
# Uso: python spessore_lei.py <registrazione> <geometria> <uscita.json> [ogni]
import json, sys, numpy as np
from scipy.spatial import cKDTree
R, GEO, OUT2 = sys.argv[1], sys.argv[2], sys.argv[3]
OGNI2 = int(sys.argv[4]) if len(sys.argv) > 4 else 3
argv0 = sys.argv[0]; sys.argv = [argv0.replace('spessore_lei.py', 'analisi_lei.py'), R, GEO, '/dev/null']
src = open(sys.argv[0]).read(); exec(src[:src.index("res = {")])
k = [i for i, s in enumerate(mesh) if s['nome'] == 'Medusa_Tentacoli'][0]
princ = mesh[k]['princ']
figlio = {}
for i, n in enumerate(nomi):
    if n.startswith('tentacolo_'):
        a = n.rsplit('_', 1); nx = a[0] + '_%02d' % (int(a[1]) + 1)
        if nx in nomi: figlio[i] = nomi.index(nx)
# raggio a riposo di ogni tratto (dalla prima posa)
sk0 = pelle(0)[k]; P0 = pose_all[0, :, 3]; rag = {}
for b in figlio:
    vi = np.where(princ == b)[0]
    if len(vi) == 0: continue
    A, B = P0[b], P0[figlio[b]]; e = B - A
    s = np.clip(((sk0[vi] - A) @ e) / (e @ e), 0, 1); d = np.linalg.norm(sk0[vi] - (A + e[None] * s[:, None]), axis=1)
    rag[b] = float(np.percentile(d, 75))
out = []
for fi in range(0, len(fot), OGNI2):
    P = pose_all[fi, :, 3]; f = fot[fi]
    entra = []
    for b, r in rag.items():
        for s in (0.25, 0.5, 0.75):
            q = P[b] + (P[figlio[b]] - P[b]) * s
            dq, iq = albero.query(q)
            if dq < r - 0.01:
                entra.append((r - dq, nomi_g[own[iq]], nomi[b], [round(float(x), 2) for x in q]))
                break
    entra.sort(reverse=True)
    out.append({'t': f['t'], 'tag': f.get('tag', ''), 'tl': f.get('tl', 0), 'tratti': len(rag), 'entrano': len(entra),
                'max_cm': round(entra[0][0] * 100, 1) if entra else 0, 'dove': {}, 'lista': [[round(e[0]*100,1), e[1].split('/')[-1], e[2], e[3]] for e in entra]})
    for e in entra:
        nm = e[1].split('/')[-1]; out[-1]['dove'][nm] = out[-1]['dove'].get(nm, 0) + 1
json.dump(out, open(OUT2, 'w'))
print('tratti', len(rag), 'raggi cm', np.round(np.percentile([r * 100 for r in rag.values()], [10, 50, 90]), 1))
