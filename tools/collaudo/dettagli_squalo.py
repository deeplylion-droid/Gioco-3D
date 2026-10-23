# Collaudo dello squalo, controlli fini su fotogrammi scelti: distanze dalle superfici vere (campioni ogni 3 mm),
# dentro/fuori dal cartello e dall'anta aperta (raggi che contano gli incroci), ossa dei vertici che sbagliano.
import json, sys, numpy as np
from scipy.spatial import cKDTree
TEMPI_ARG = sys.argv[4] if len(sys.argv) > 4 else ''
sys.argv = sys.argv[:4]
exec(open(__file__.replace('dettagli_squalo.py', 'analisi_squalo.py')).read().split('res = {')[0])

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
pass

def campiona(V, T, passo=0.003):
    t = V[T]
    l = np.maximum(np.linalg.norm(t[:, 1] - t[:, 0], axis=1), np.linalg.norm(t[:, 2] - t[:, 0], axis=1))
    k = np.clip(np.ceil(l / passo), 1, 80).astype(int); out = []
    for kk in np.unique(k):
        s = k == kk
        u, v = np.meshgrid(np.arange(kk + 1), np.arange(kk + 1)); mm = (u + v) <= kk
        u = u[mm] / kk; v = v[mm] / kk
        A, Bb, C = t[s, 0], t[s, 1], t[s, 2]
        out.append((A[:, None] + (Bb - A)[:, None] * u[None, :, None] + (C - A)[:, None] * v[None, :, None]).reshape(-1, 3))
    return np.concatenate(out)

def dentro(punti, tri):
    # parità degli incroci di un raggio verso +y (con un piccolo storto) contro i triangoli
    D = np.array([0.013, 1.0, 0.007]); D /= np.linalg.norm(D)
    v0 = tri[:, 0]; e1 = tri[:, 1] - v0; e2 = tri[:, 2] - v0
    pp = np.cross(D, e2); det = (e1 * pp).sum(1); ok = np.abs(det) > 1e-12; inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    out = np.zeros(len(punti), bool)
    for i, p in enumerate(punti):
        sv = p - v0; u = (sv * pp).sum(1) * inv; q = np.cross(sv, e1); vv = (q * D).sum(1) * inv; tt = (e2 * q).sum(1) * inv
        out[i] = (ok & (u >= 0) & (vv >= 0) & (u + vv <= 1) & (tt > 0)).sum() % 2 == 1
    return out

def osso_principale(k_sup, idx):
    s = sup[k_sup]; bb = bind_bone[s['b'][idx]]; w = s['w'][idx]
    c = {}
    for row_b, row_w in zip(bb, w):
        j = row_b[np.argmax(row_w)]; c[nomi[j]] = c.get(nomi[j], 0) + 1
    return sorted(c.items(), key=lambda x: -x[1])[:3]

ci = [i for i, m in enumerate(g['mesh']) if m['nodo'].endswith('cartello_corridoio')][0]
cm = g['mesh'][ci]; cart_tri = gt[cm['da']:cm['da'] + cm['n']].astype(np.float64)
tempi = [float(x) for x in TEMPI_ARG.split(',')] if TEMPI_ARG else [0.033, 2.4, 3.0, 4.6, 6.0, 8.6, 9.9, 10.2]
for tq in tempi:
    fi = min(range(len(fot)), key=lambda i: abs(fot[i]['t'] - tq)); f = fot[fi]
    sk = pelle(fi)
    print(f"== t {f['t']}")
    # cartello: vertici del corpo dentro la mesh del cartello
    lo = cart_tri.reshape(-1, 3).min(0); hi = cart_tri.reshape(-1, 3).max(0)
    for k_s in range(len(sk)):
        inb = np.where(np.all((sk[k_s] > lo) & (sk[k_s] < hi), axis=1))[0]
        if len(inb):
            dn = dentro(sk[k_s][inb], cart_tri)
            if dn.any():
                P = sk[k_s][inb[dn]]
                print(f"   cartello: {dn.sum()} vertici di {sup[k_s]['mat']} DENTRO, box {P.min(0).round(3)} {P.max(0).round(3)} ossa {osso_principale(k_s, inb[dn])}")
            else:
                print(f"   cartello: {len(inb)} vertici di {sup[k_s]['mat']} nel box ma fuori dalla mesh")
    # porta aperta: vertici dentro l'anta
    Rf = rot_y(f['porta'][1]); Tf = np.array(f['porta'][0])
    for k_s in range(len(sk)):
        loc = (sk[k_s] - Tf) @ Rf
        inl = np.all((loc > lo_p + 0.005) & (loc < hi_p - 0.005), axis=1)
        if inl.any():
            P = sk[k_s][inl]; pen = np.minimum(loc[inl] - lo_p, hi_p - loc[inl]).min(1).max()
            print(f"   anta della porta (rot {f['porta'][1]}): {inl.sum()} vertici di {sup[k_s]['mat']} dentro, fino a {pen*100:.1f} cm, box {P.min(0).round(3)} {P.max(0).round(3)} ossa {osso_principale(k_s, np.where(inl)[0])}")
    # vertici sotto il pavimento
    for k_s in range(len(sk)):
        sotto = np.where(sk[k_s][:, 1] < -0.003)[0]
        if len(sotto):
            print(f"   sotto il pavimento: {len(sotto)} vertici di {sup[k_s]['mat']}, fino a {-sk[k_s][sotto,1].min()*100:.1f} cm, ossa {osso_principale(k_s, sotto)}")
    # vertici oltre i muri del corridoio (fra x 11 e 21,75) e vicino agli statici
    tutti = np.concatenate(sk)
    oltre = tutti[((tutti[:, 2] > 0.003) | (tutti[:, 2] < -2.603)) & (tutti[:, 0] < 21.75) & (tutti[:, 0] > 11)]
    if len(oltre):
        print(f"   oltre i muri: {len(oltre)} vertici, box {oltre.min(0).round(3)} {oltre.max(0).round(3)}")
    alti = tutti[tutti[:, 1] > 0.03]
    dd, ii = albero.query(alti, distance_upper_bound=0.005)
    vic = np.isfinite(dd)
    if vic.any():
        P = alti[vic]; chi = {}
        for o in stat_own[ii[vic]]: chi[nomi_g[o]] = chi.get(nomi_g[o], 0) + 1
        print(f"   a meno di 5 mm dagli statici: {chi}, box {P.min(0).round(3)} {P.max(0).round(3)}")
    # denti: distanza di ogni dente dalle superfici di gengiva, bocca e corpo (campioni ogni 3 mm)
    sup_ap = cKDTree(np.concatenate([campiona(sk[geng_i], sup[geng_i]['i']), campiona(sk[bocca_i], sup[bocca_i]['i']),
                                     campiona(sk[0], sup[0]['i'], 0.006)]))
    stacc = []
    for k, dv in enumerate(denti):
        dmin = sup_ap.query(sk[denti_i][dv])[0].min()
        if dmin > 0.004:
            stacc.append((k, round(dmin * 1000, 1)))
    print(f"   denti a più di 4 mm da gengiva/bocca/corpo: {len(stacc)} di {len(denti)} {stacc[:12]}")
    # denti dentro la bocca (palato e lingua, superficie bocca_interno): punte che passano dall'altra parte
    dn = dentro(sk[denti_i][::7], np.concatenate([sk[0][sup[0]['i']]]))
    print(f"   vertici dei denti (1 su 7) dentro il corpo chiuso: {dn.sum()} di {len(dn)}")
    # bava: capi dalle superfici
    alb = cKDTree(np.concatenate([campiona(sk[0], sup[0]['i'], 0.004), campiona(sk[denti_i], sup[denti_i]['i']),
                                  campiona(sk[geng_i], sup[geng_i]['i'])]))
    capi = [[round(alb.query(a)[0] * 1000, 1), round(alb.query(b_)[0] * 1000, 1), i] for a, b_, i in f.get('capi_bava', [])]
    print(f"   bava (forza {f.get('bava_forza')}): capi a mm dalla pelle {capi}")
