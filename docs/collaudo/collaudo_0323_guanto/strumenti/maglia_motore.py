"""La maglia del guanto salvata dal motore (collaudo_guanto.gd, modo maglia): vertici uniti, bordi aperti, pieghe e
normali spezzate (stessa posizione, normali diverse: uno spigolo nell'ombreggiatura). Uso: maglia_motore.py file.bin cartella_uscita"""
import sys, os, struct
import numpy as np
b = open(sys.argv[1], 'rb').read(); nv, ni = struct.unpack_from('<II', b, 0)
P = np.frombuffer(b, '<f4', nv * 3, 8).reshape(-1, 3).astype(np.float64)
Nn = np.frombuffer(b, '<f4', nv * 3, 8 + nv * 12).reshape(-1, 3).astype(np.float64)
I = np.frombuffer(b, '<i4', ni, 8 + nv * 24).reshape(-1, 3)
print('MOTORE: %d vertici, %d triangoli, scatola %s - %s' % (nv, len(I), P.min(0).round(4), P.max(0).round(4)))
k = np.round(P / 1e-6).astype(np.int64)
u, inv = np.unique(k, axis=0, return_inverse=True); inv = inv.ravel()
V = np.zeros((len(u), 3)); V[inv] = P
F = inv[I]
F = F[(F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])]
os.makedirs(sys.argv[2], exist_ok=True)
np.save(os.path.join(sys.argv[2], '_V.npy'), V); np.save(os.path.join(sys.argv[2], '_F.npy'), F)
e = np.sort(np.vstack([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1)
_, cnt = np.unique(e, axis=0, return_counts=True)
print('MOTORE: vertici uniti %d, bordi aperti %d, spigoli con più di due facce %d' % (len(V), (cnt == 1).sum(), (cnt > 2).sum()))
# normali spezzate: per ogni posizione, l'angolo massimo fra le normali dei vertici che ci stanno
Nn = Nn / np.maximum(np.linalg.norm(Nn, axis=1, keepdims=True), 1e-12)
ordine = np.argsort(inv); gi = inv[ordine]; tagli = np.flatnonzero(np.diff(gi)) + 1
peggio = []
for grp in np.split(ordine, tagli):
    if len(grp) < 2: continue
    nn = Nn[grp]; d = np.clip(nn @ nn.T, -1, 1); a = np.degrees(np.arccos(d.min()))
    if a > 1: peggio.append((a, tuple(P[grp[0]].round(4))))
peggio.sort(reverse=True)
print('MOTORE: posizioni con normali spezzate oltre 1 grado %d, oltre 30 %d, al più %.0f gradi' % (len(peggio), sum(1 for a, _ in peggio if a > 30), peggio[0][0] if peggio else 0))
for a, p in peggio[:6]: print('   %.0f gradi in %s' % (a, p))
