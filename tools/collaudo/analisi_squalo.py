# Collaudo dello squalo: dalla registrazione di sonda_squalo_scena.gd (pelle a riposo, pose delle ossa) rifà la pelle
# deformata in ogni fotogramma e misura camera, denti, bava, piedi, ostacoli e porta.
# Uso: python analisi_squalo.py <cartella della registrazione> <geometria statica (base di geometria.gd)> <uscita.json>
import json, sys, numpy as np
from scipy.spatial import cKDTree

R, GEO, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(f'{R}/scena.json'))
info, fot = d['info'], d['fotogrammi']
NB = info['ossa']
nomi = info['nomi_ossa']
pose_all = np.fromfile(f'{R}/pelle.bin', dtype=np.float32).reshape(len(fot), NB, 4, 3)
mesh = info['mesh'][0]
binds = mesh['binds']
B = np.zeros((len(binds), 4, 4))
for k, (o, m) in enumerate(binds):
    M = np.eye(4); M[:3, 0] = m[0:3]; M[:3, 1] = m[3:6]; M[:3, 2] = m[6:9]; M[:3, 3] = m[9:12]; B[k] = M
bind_bone = np.array([b[0] for b in binds])
sup = []
for s in mesh['superfici']:
    f = s['file']
    v = np.fromfile(f'{R}/{f}_v.bin', dtype=np.float32).reshape(-1, 3)
    i = np.fromfile(f'{R}/{f}_i.bin', dtype=np.int32).reshape(-1, 3)
    b = np.fromfile(f'{R}/{f}_b.bin', dtype=np.int32).reshape(len(v), -1)
    w = np.fromfile(f'{R}/{f}_w.bin', dtype=np.float32).reshape(len(v), -1)
    sup.append({'mat': s['materiale'], 'v': v, 'i': i, 'b': b, 'w': w})


def pose_mat(fi):
    P = np.zeros((NB, 4, 4)); P[:, 3, 3] = 1
    p = pose_all[fi]
    P[:, :3, 0] = p[:, 0]; P[:, :3, 1] = p[:, 1]; P[:, :3, 2] = p[:, 2]; P[:, :3, 3] = p[:, 3]
    return P


def pelle(fi):
    P = pose_mat(fi)
    M = P[bind_bone] @ B  # per bind
    out = []
    for s in sup:
        vh = np.c_[s['v'], np.ones(len(s['v']))]
        acc = np.zeros((len(vh), 3)); tot = np.zeros(len(vh))
        for j in range(s['b'].shape[1]):
            wj = s['w'][:, j]; sel = wj > 0
            if not sel.any():
                continue
            Mj = M[s['b'][sel, j]]
            acc[sel] += np.einsum('nij,nj->ni', Mj[:, :3, :], vh[sel]) * wj[sel, None]
            tot[sel] += wj[sel]
        out.append(acc / np.maximum(tot, 1e-9)[:, None])
    return out


def osso(fi, nome):
    return pose_all[fi, nomi.index(nome), 3]


# geometria statica (interni): campioni delle superfici nel corridoio, per mesh
g = json.load(open(GEO + '.json'))
gt = np.fromfile(GEO + '.bin', dtype=np.float32).reshape(-1, 3, 3)
stat_pts = []; stat_own = []
for mi, m in enumerate(g['mesh']):
    if not m['visibile']:
        continue
    b = m['box']
    if b[0] > 23 or b[0] + b[3] < 11 or b[2] > 0.6 or b[2] + b[5] < -3.2:
        continue
    t = gt[m['da']:m['da'] + m['n']].astype(np.float64)
    c = t.mean(1)
    sel = (c[:, 0] > 11) & (c[:, 0] < 23) & (c[:, 2] > -3.2) & (c[:, 2] < 0.6)
    t = t[sel]
    if len(t) == 0:
        continue
    # campioni ogni ~2 cm
    l = np.maximum(np.linalg.norm(t[:, 1] - t[:, 0], axis=1), np.linalg.norm(t[:, 2] - t[:, 0], axis=1))
    k = np.clip(np.ceil(l / 0.02), 1, 60).astype(int)
    for kk in np.unique(k):
        s = k == kk
        u, v = np.meshgrid(np.arange(kk + 1), np.arange(kk + 1)); mm = (u + v) <= kk
        u = u[mm] / kk; v = v[mm] / kk
        A, Bb, C = t[s, 0], t[s, 1], t[s, 2]
        p = (A[:, None] + (Bb - A)[:, None] * u[None, :, None] + (C - A)[:, None] * v[None, :, None]).reshape(-1, 3)
        stat_pts.append(p); stat_own.append(np.full(len(p), mi))
stat_pts = np.concatenate(stat_pts); stat_own = np.concatenate(stat_own)
nomi_g = [m['nodo'].split('/')[-1] for m in g['mesh']]
porta_i = [i for i, m in enumerate(g['mesh']) if m['nodo'].endswith('porta_tagliafuoco')][0]
porta_loc = None
pm = g['mesh'][porta_i]
porta_tri = gt[pm['da']:pm['da'] + pm['n']].reshape(-1, 3).astype(np.float64)
# niente porta tagliafuoco tra gli statici (si muove): la si mette a parte
keep = stat_own != porta_i
stat_pts, stat_own = stat_pts[keep], stat_own[keep]
albero = cKDTree(stat_pts)

res = {'fotogrammi': []}
# la porta: le sue coordinate locali (alla posa del dump di geometria: pos e rot della prima riga della registrazione
# non servono, la porta del dump è com'era nella scena caricata)
def rot_y(a):
    a = np.radians(a); c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

# posa della porta nel dump: dalla prima registrazione non la sappiamo; la ricaviamo dal box del dump e dal
# fotogramma della registrazione con lo stesso box
p0 = None
for f in fot:
    if f.get('porta_box') and np.allclose(f['porta_box'], pm['box'], atol=0.005):
        p0 = f; break
if p0 is None:
    p0 = fot[0]
R0 = rot_y(p0['porta'][1]); T0 = np.array(p0['porta'][0])
porta_locale = (porta_tri - T0) @ R0  # R0^T (v - T0)
lo_p, hi_p = porta_locale.min(0), porta_locale.max(0)
res['porta_rif'] = {'t': p0['t'], 'box_dump': pm['box'], 'box_locale': [lo_p.tolist(), hi_p.tolist()]}

denti_i = [k for k, s in enumerate(sup) if s['mat'].startswith('denti')][0]
geng_i = [k for k, s in enumerate(sup) if s['mat'].startswith('gengiva')][0]
bocca_i = [k for k, s in enumerate(sup) if s['mat'].startswith('bocca_interno')][0]
gola_i = [k for k, s in enumerate(sup) if s['mat'].startswith('gola')][0]
# i denti, uno per uno (pezzi connessi della superficie)
tri = sup[denti_i]['i']; nv = len(sup[denti_i]['v'])
par = np.arange(nv)
def trova(x):
    while par[x] != x:
        par[x] = par[par[x]]; x = par[x]
    return x
for a, b_, c in tri:
    for u, v in ((a, b_), (a, c)):
        ru, rv = trova(u), trova(v)
        if ru != rv: par[ru] = rv
comp = np.array([trova(x) for x in range(nv)])
denti = [np.where(comp == c)[0] for c in np.unique(comp)]
res['denti'] = len(denti)
piede_v = {}
for lato in ('L', 'R'):
    bi = nomi.index('piede.' + lato)
    # i vertici del corpo legati soprattutto al piede (attraverso i bind)
    bb = bind_bone[sup[0]['b']]  # osso dello scheletro per ogni influenza
    peso = np.where(bb == bi, sup[0]['w'], 0).sum(1)
    piede_v[lato] = np.where(peso > 0.5)[0]
prec_piede = {}
for fi, f in enumerate(fot):
    sk = pelle(fi)
    tutti = np.concatenate(sk)
    cam = np.array(f['camera'])
    r = {'t': f['t']}
    # camera: distanza dalla pelle (vertici) e quanti vertici davanti alla camera più vicini del near
    dcam = np.linalg.norm(tutti - cam, axis=1)
    r['camera_dist'] = float(dcam.min())
    # dentro? raggio verso l'alto, contando gli incroci con i triangoli del corpo
    V = sk[0]; T = sup[0]['i']
    v0 = V[T[:, 0]]; e1 = V[T[:, 1]] - v0; e2 = V[T[:, 2]] - v0
    D = np.array([0.0, 1.0, 0.0])
    pp = np.cross(D, e2); det = (e1 * pp).sum(1); ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0); sv = cam - v0
    u = (sv * pp).sum(1) * inv; q = np.cross(sv, e1); vv = (q * D).sum(1) * inv; tt = (e2 * q).sum(1) * inv
    r['camera_incroci_su'] = int((ok & (u >= 0) & (vv >= 0) & (u + vv <= 1) & (tt > 0)).sum())
    # denti: per ogni dente la distanza minima da gengiva, bocca e corpo (radice nel vuoto se > 5 mm)
    alb_ap = cKDTree(np.concatenate([sk[geng_i], sk[bocca_i], sk[0]]))
    lontani = []
    for k, dv in enumerate(denti):
        dmin = alb_ap.query(sk[denti_i][dv])[0].min()
        if dmin > 0.005:
            lontani.append([k, round(float(dmin) * 100, 1)])
    r['denti_staccati'] = lontani
    # denti di sopra e di sotto che si compenetrano: vertici di denti diversi a meno di 2 mm (solo pezzi diversi)
    pts_d = sk[denti_i]; alb_d = cKDTree(pts_d)
    coppie = alb_d.query_pairs(0.002, output_type='ndarray')
    if len(coppie):
        diversi = comp[coppie[:, 0]] != comp[coppie[:, 1]]
        r['denti_vicini'] = int(diversi.sum())
    else:
        r['denti_vicini'] = 0
    # bava: capi sulle labbra (distanza dalla pelle)
    alb_t = cKDTree(tutti)
    capi = []
    for a, b_, intero in f.get('capi_bava', []):
        capi.append([round(float(alb_t.query(a)[0]) * 100, 1), round(float(alb_t.query(b_)[0]) * 100, 1), intero])
    r['bava_capi_cm'] = capi
    r['bava_forza'] = f.get('bava_forza')
    # piedi: il vertice più basso, e lo scivolamento mentre tocca
    for lato, vi in piede_v.items():
        pv = sk[0][vi]
        ymin = float(pv[:, 1].min())
        r['piede_' + lato] = round(ymin * 100, 1)
        basso = pv[pv[:, 1] < ymin + 0.01]
        c = basso.mean(0)
        if lato in prec_piede and prec_piede[lato][1] < 0.01 and ymin < 0.01:
            r['scivola_' + lato] = round(float(np.linalg.norm((c - prec_piede[lato][0])[[0, 2]])) * 100, 2)
        prec_piede[lato] = (c, ymin)
    # ostacoli: vertici dello squalo vicini (1 cm) agli statici, sopra il pavimento
    alti = tutti[tutti[:, 1] > 0.03]
    dd, ii = albero.query(alti, distance_upper_bound=0.01)
    vic = np.isfinite(dd)
    chi = {}
    for o in stat_own[ii[vic]]:
        chi[nomi_g[o]] = chi.get(nomi_g[o], 0) + 1
    r['tocca'] = chi
    # attraverso i muri del corridoio: oltre z 0 (nord) o z -2.6 (sud), prima della porta (x < 21.8)
    nel = tutti[(tutti[:, 0] < 21.75) & (tutti[:, 0] > 11)]
    r['oltre_nord_cm'] = round(float(max(0, nel[:, 2].max())) * 100, 1) if len(nel) else 0
    r['oltre_sud_cm'] = round(float(max(0, -2.6 - nel[:, 2].min())) * 100, 1) if len(nel) else 0
    r['sotto_pavimento_cm'] = round(float(max(0, -tutti[:, 1].min())) * 100, 1)
    r['testa_su_cm'] = round(float(tutti[:, 1].max()) * 100, 1)
    # dentro il cartello del corridoio (il suo box, un po' ristretto)
    cb = [15.9, 0.0, -2.35, 0.59, 0.62, 0.81]
    lo = np.array(cb[:3]) + 0.02; hi = np.array(cb[:3]) + np.array(cb[3:]) - 0.02
    r['dentro_cartello'] = int(np.all((tutti > lo) & (tutti < hi), axis=1).sum())
    # porta tagliafuoco: vertici dentro l'anta (nella sua posa di questo fotogramma)
    if f.get('porta'):
        Rf = rot_y(f['porta'][1]); Tf = np.array(f['porta'][0])
        loc = (tutti - Tf) @ Rf
        r['dentro_porta'] = int(np.all((loc > lo_p + 0.01) & (loc < hi_p - 0.01), axis=1).sum())
        r['porta_rot'] = f['porta'][1]
    # nel vano della porta: x fra 21.81 e 22.12 (spessore del muro) i vertici devono stare nel vano
    nv_ = tutti[(tutti[:, 0] > 21.85) & (tutti[:, 0] < 22.1)]
    if len(nv_):
        r['vano'] = [round(float(nv_[:, 2].min()), 3), round(float(nv_[:, 2].max()), 3), round(float(nv_[:, 1].max()), 3)]
    r['bocca'] = [round(float(x), 3) for x in osso(fi, 'mento_punta')]
    res['fotogrammi'].append(r)
json.dump(res, open(OUT, 'w'))
print('fatto', len(res['fotogrammi']), 'denti', len(denti))
