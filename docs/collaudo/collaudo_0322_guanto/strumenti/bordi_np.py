"""Bordi aperti del guanto senza Blender (numpy): anelli, lunghezza, centro e scatola in coordinate glTF."""
import json, struct, sys
import numpy as np
from collections import defaultdict
d = open(sys.argv[1], 'rb').read()
n = struct.unpack_from('<I', d, 12)[0]
js = json.loads(d[20:20 + n]); binoff = 20 + n + 8
def acc(i):
    a = js['accessors'][i]; bv = js['bufferViews'][a['bufferView']]
    comp = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a['componentType']]
    k = {'SCALAR': 1, 'VEC3': 3, 'VEC2': 2, 'VEC4': 4}[a['type']]
    o = binoff + bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    return np.frombuffer(d, comp, a['count'] * k, o).reshape(-1, k) if k > 1 else np.frombuffer(d, comp, a['count'], o)
P = []; T = []
for m in js['meshes']:
    for pr in m['primitives']:
        p = acc(pr['attributes']['POSITION']).astype(np.float64); t = acc(pr['indices']).reshape(-1, 3).astype(np.int64)
        T.append(t + sum(len(x) for x in P)); P.append(p)
P = np.vstack(P); T = np.vstack(T)
print('nodi', [(x.get('name'), x.get('translation'), x.get('rotation'), x.get('scale')) for x in js['nodes']])
# unisce i vertici con la stessa posizione (cuciture di UV e materiali)
q = np.round(P / 1e-6).astype(np.int64)
_, idx, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
inv = inv.reshape(-1); V = P[idx]; F = inv[T]
F = F[(F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])]
E = np.sort(np.vstack([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), axis=1)
ue, cnt = np.unique(E, axis=0, return_counts=True)
print('vertici %d (uniti %d), facce %d, spigoli %d, aperti %d, con più di 2 facce %d' % (len(P), len(V), len(F), len(ue), (cnt == 1).sum(), (cnt > 2).sum()))
ap = ue[cnt == 1]
adj = defaultdict(list)
for a, b in ap:
    adj[a].append(b); adj[b].append(a)
visti = set(); gruppi = []
for s in adj:
    if s in visti: continue
    g = []; coda = [s]; visti.add(s)
    while coda:
        x = coda.pop(); g.append(x)
        for y in adj[x]:
            if y not in visti: visti.add(y); coda.append(y)
    gruppi.append(g)
print('anelli aperti', len(gruppi))
for g in sorted(gruppi, key=len, reverse=True):
    pts = V[g]; c = pts.mean(0)
    print('  %3d vertici, centro (%.4f, %.4f, %.4f), scatola %s mm' % (len(g), *c, np.round((pts.max(0) - pts.min(0)) * 1000, 1)))
np.save(sys.argv[2], V); np.save(sys.argv[3], F)
for t in ue[cnt > 2][:20]:
    print('  spigolo con %d facce in' % 3, np.round(V[t].mean(0), 4))
