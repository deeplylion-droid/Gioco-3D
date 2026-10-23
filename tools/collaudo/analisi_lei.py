# Collaudo dei tentacoli di lei: dalla registrazione di sonda_lei.gd rifà la pelle deformata (tutte le mesh) e misura
# i tentacoli contro la geometria vera della scena (geometria.gd): vertici dentro le superfici (distanza con segno dalla
# superficie più vicina, entro 5 cm di lato) e punte sospese (distanza dalla superficie più vicina e vuoto sotto).
# Uso: python analisi_lei.py <registrazione> <geometria (base)> <uscita.json> [ogni quanti fotogrammi]
import json, sys, numpy as np
from scipy.spatial import cKDTree
R, GEO, OUT = sys.argv[1:4]
OGNI = int(sys.argv[4]) if len(sys.argv) > 4 else 3
d = json.load(open(f'{R}/scena.json')); info, fot = d['info'], d['fotogrammi']
NB = info['ossa']; nomi = info['nomi_ossa']
pose_all = np.fromfile(f'{R}/pelle.bin', dtype=np.float32).reshape(len(fot), NB, 4, 3)
mesh = []
for me in info['mesh']:
    B = np.zeros((len(me['binds']), 4, 4))
    for k, (o, m) in enumerate(me['binds']):
        M = np.eye(4); M[:3, 0] = m[0:3]; M[:3, 1] = m[3:6]; M[:3, 2] = m[6:9]; M[:3, 3] = m[9:12]; B[k] = M
    bb = np.array([b[0] for b in me['binds']])
    for s in me['superfici']:
        f = s['file']
        v = np.fromfile(f'{R}/{f}_v.bin', dtype=np.float32).reshape(-1, 3)
        b = np.fromfile(f'{R}/{f}_b.bin', dtype=np.int32).reshape(len(v), -1)
        w = np.fromfile(f'{R}/{f}_w.bin', dtype=np.float32).reshape(len(v), -1)
        # osso principale di ogni vertice (dello scheletro)
        princ = bb[b[np.arange(len(v)), w.argmax(1)]]
        tent = np.array([nomi[i].startswith('tentacolo_') if i >= 0 else False for i in princ])
        mesh.append({'nome': me['nome'], 'mat': s['materiale'], 'v': v, 'b': b, 'w': w, 'B': B, 'bb': bb, 'tent': tent, 'princ': princ})


def pelle(fi):
    P = np.zeros((NB, 4, 4)); P[:, 3, 3] = 1
    p = pose_all[fi]; P[:, :3, 0] = p[:, 0]; P[:, :3, 1] = p[:, 1]; P[:, :3, 2] = p[:, 2]; P[:, :3, 3] = p[:, 3]
    out = []
    for s in mesh:
        M = P[s['bb']] @ s['B']
        vh = np.c_[s['v'], np.ones(len(s['v']))]
        acc = np.zeros((len(vh), 3)); tot = np.zeros(len(vh))
        for j in range(s['b'].shape[1]):
            wj = s['w'][:, j]; sel = wj > 0
            if not sel.any(): continue
            Mj = M[s['b'][sel, j]]
            acc[sel] += np.einsum('nij,nj->ni', Mj[:, :3, :], vh[sel]) * wj[sel, None]; tot[sel] += wj[sel]
        out.append(acc / np.maximum(tot, 1e-9)[:, None])
    return out


g = json.load(open(GEO + '.json')); gt = np.fromfile(GEO + '.bin', dtype=np.float32).reshape(-1, 3, 3)
# la zona di lei in tutta la registrazione
tutte = np.concatenate([pose_all[i, :, 3] for i in range(0, len(fot), 10)])
lo = tutte.min(0) - 1.5; hi = tutte.max(0) + 1.5
pts, nor, own = [], [], []
SALTA = ('acqua', 'water', 'medusa', 'lei', 'jilly', 'player', 'giocatore', 'superficie', 'gocc', 'bolle', 'particell')
for mi, m in enumerate(g['mesh']):
    if not m.get('visibile', True): continue
    nodo = m['nodo'].lower()
    if any(k in nodo for k in SALTA): continue
    b = m['box']
    if b[0] > hi[0] or b[0] + b[3] < lo[0] or b[1] > hi[1] or b[1] + b[4] < lo[1] or b[2] > hi[2] or b[2] + b[5] < lo[2]: continue
    t = gt[m['da']:m['da'] + m['n']].astype(np.float64)
    c = t.mean(1); sel = np.all((c > lo) & (c < hi), axis=1); t = t[sel]
    if len(t) == 0: continue
    n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0]); ln = np.linalg.norm(n, axis=1); ok = ln > 1e-10; t = t[ok]; n = n[ok] / ln[ok, None]
    l = np.maximum(np.linalg.norm(t[:, 1] - t[:, 0], axis=1), np.linalg.norm(t[:, 2] - t[:, 0], axis=1))
    k = np.clip(np.ceil(l / 0.015), 1, 80).astype(int)
    for kk in np.unique(k):
        s_ = k == kk
        u, v = np.meshgrid(np.arange(kk + 1), np.arange(kk + 1)); mm = (u + v) <= kk; u = u[mm] / kk; v = v[mm] / kk
        A, Bb, C = t[s_, 0], t[s_, 1], t[s_, 2]
        p = (A[:, None] + (Bb - A)[:, None] * u[None, :, None] + (C - A)[:, None] * v[None, :, None]).reshape(-1, 3)
        pts.append(p); nor.append(np.repeat(n[s_], len(u), axis=0)); own.append(np.full(len(p), mi))
pts = np.concatenate(pts); nor = np.concatenate(nor); own = np.concatenate(own)
albero = cKDTree(pts)
nomi_g = [m['nodo'] for m in g['mesh']]
# punte dei tentacoli: le ossa tentacolo_ senza figli tentacolo_ (dall'ordine dei nomi: l'ultimo numero di ogni catena)
catene = {}
for i, n in enumerate(nomi):
    if n.startswith('tentacolo_'):
        parti = n.split('_'); chiave = '_'.join(parti[:-1]) if len(parti) > 2 else n
        catene.setdefault(chiave, []).append(i)
punte = [max(v) for v in catene.values()]
res = {'catene': len(catene), 'fotogrammi': []}
for fi in range(0, len(fot), OGNI):
    f = fot[fi]; sk = pelle(fi)
    tv = np.concatenate([s_[mesh[k]['tent']] for k, s_ in enumerate(sk)])
    r = {'t': f['t'], 'tag': f.get('tag', ''), 'tl': f.get('tl', 0)}
    dd, ii = albero.query(tv, distance_upper_bound=0.05)
    vic = np.isfinite(dd)
    sd = np.full(len(tv), np.inf)
    sd[vic] = ((tv[vic] - pts[ii[vic]]) * nor[ii[vic]]).sum(1)
    dentro = vic & (sd < -0.01)
    r['dentro'] = int(dentro.sum())
    if dentro.any():
        r['dentro_max_cm'] = round(float(-sd[dentro].min()) * 100, 1)
        chi = {}
        for o in own[ii[dentro]]: chi[nomi_g[o]] = chi.get(nomi_g[o], 0) + 1
        r['dentro_chi'] = dict(sorted(chi.items(), key=lambda x: -x[1])[:4])
        r['dentro_box'] = [tv[dentro].min(0).round(2).tolist(), tv[dentro].max(0).round(2).tolist()]
    # punte: distanza dalla superficie più vicina
    pp = pose_all[fi, punte, 3]
    dp, _ = albero.query(pp)
    r['punte_cm'] = [round(float(x) * 100, 1) for x in dp]
    res['fotogrammi'].append(r)
json.dump(res, open(OUT, 'w'))
print('fatto', len(res['fotogrammi']), 'catene', len(catene), 'campioni', len(pts))
