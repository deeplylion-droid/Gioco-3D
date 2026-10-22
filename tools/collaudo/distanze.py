#!/usr/bin/env python3
"""Collaudo del posizionamento: distanze vere fra le mesh (squadra collaudo).

Legge <base>.json e <base>.bin scritti da godot/tests/collaudo/geometria.gd e, per ogni oggetto (mesh o istanza
di MultiMesh con il box fra 4 cm e 6 m di diagonale, visibile, non acqua), misura la distanza minima fra la sua
superficie e quella di tutto il resto (punto-triangolo nei due sensi). Poi segue i contatti (distanza fino a
SOGLIA) a partire dall'architettura (mesh più grandi di 6 m): un oggetto che non ci arriva, da solo o attraverso
altri oggetti, è staccato.

Uso: python3 tools/collaudo/distanze.py <base> [soglia in m, predefinita 0.01] [prefissi dei nodi da misurare, con la virgola]
Scrive <base>_distanze.json con, per ogni oggetto: nodo, istanza, centro, box, piccolo (<40 cm), distanza
minima, oggetto più vicino, punto di contatto, spazio sotto (fra i punti più bassi e quello che c'è sotto),
"retto" (vero se arriva all'architettura) e "catena".
"""
import json
import sys
from collections import deque

import numpy as np
from scipy.spatial import cKDTree

MARGINE = 0.15
OGGETTO_MIN, OGGETTO_MAX = 0.04, 6.0
PICCOLO = 0.40
MAX_PUNTI = 1000


def punto_triangolo(p, a, b, c):
    """Distanza (al quadrato) fra i punti p (n,3) e i triangoli abc (m,3): matrice (n,m). Ericson, vettoriale."""
    p = p[:, None, :]
    a = a[None]
    b = b[None]
    c = c[None]
    ab = b - a
    ac = c - a
    ap = p - a
    d1 = (ab * ap).sum(-1)
    d2 = (ac * ap).sum(-1)
    bp = p - b
    d3 = (ab * bp).sum(-1)
    d4 = (ac * bp).sum(-1)
    cp = p - c
    d5 = (ab * cp).sum(-1)
    d6 = (ac * cp).sum(-1)
    va = d3 * d6 - d5 * d4
    vb = d5 * d2 - d1 * d6
    vc = d1 * d4 - d3 * d2
    den = va + vb + vc
    den = np.where(np.abs(den) < 1e-20, 1e-20, den)
    v = vb / den
    w = vc / den
    q = a + ab * v[..., None] + ac * w[..., None]   # interno
    # regioni dei vertici e degli spigoli
    m_a = (d1 <= 0) & (d2 <= 0)
    m_b = (d3 >= 0) & (d4 <= d3)
    m_c = (d6 >= 0) & (d5 <= d6)
    m_ab = (vc <= 0) & (d1 >= 0) & (d3 <= 0)
    m_ac = (vb <= 0) & (d2 >= 0) & (d6 <= 0)
    m_bc = (va <= 0) & ((d4 - d3) >= 0) & ((d5 - d6) >= 0)
    with np.errstate(divide="ignore", invalid="ignore"):
        t_ab = np.nan_to_num(d1 / (d1 - d3))
        t_ac = np.nan_to_num(d2 / (d2 - d6))
        t_bc = np.nan_to_num((d4 - d3) / ((d4 - d3) + (d5 - d6)))
    q = np.where(m_bc[..., None], b + (c - b) * t_bc[..., None], q)
    q = np.where(m_ac[..., None], a + ac * t_ac[..., None], q)
    q = np.where(m_ab[..., None], a + ab * t_ab[..., None], q)
    q = np.where(m_c[..., None], np.broadcast_to(c, q.shape), q)
    q = np.where(m_b[..., None], np.broadcast_to(b, q.shape), q)
    q = np.where(m_a[..., None], np.broadcast_to(a, q.shape), q)
    return ((p - q) ** 2).sum(-1)


def min_per_triangolo(punti, tri, blocco=4_000_000):
    """Per ogni triangolo, la distanza minima dai punti, e il punto più vicino."""
    m = len(tri)
    out = np.full(m, np.inf)
    idx = np.zeros(m, dtype=np.int64)
    if m == 0 or len(punti) == 0:
        return np.sqrt(out), idx
    passo = max(1, blocco // max(1, len(punti)))
    for s in range(0, m, passo):
        t = tri[s:s + passo]
        d = punto_triangolo(punti, t[:, 0], t[:, 1], t[:, 2])
        out[s:s + passo] = d.min(0)
        idx[s:s + passo] = d.argmin(0)
    return np.sqrt(out), idx


def punti_di(tri):
    """I vertici distinti (al mm), ridotti a MAX_PUNTI tenendo gli estremi in 26 direzioni."""
    v = np.unique(np.round(tri.reshape(-1, 3), 3), axis=0)
    if len(v) <= MAX_PUNTI:
        return v
    dirs = np.array([[x, y, z] for x in (-1, 0, 1) for y in (-1, 0, 1) for z in (-1, 0, 1) if (x, y, z) != (0, 0, 0)], float)
    estremi = v[np.unique((v @ dirs.T).argmax(0))]
    # griglia: un punto per cella
    lato = (v.max(0) - v.min(0)).max() / 30.0
    for _ in range(8):
        celle = np.floor(v / max(lato, 1e-4)).astype(np.int64)
        _, primo = np.unique(celle, axis=0, return_index=True)
        if len(primo) <= MAX_PUNTI:
            break
        lato *= 1.4
    return np.vstack([v[primo], estremi])


def sotto(punti, tri, lo, hi):
    """Spazio verticale fra i punti più bassi dell'oggetto e il primo triangolo sotto di loro (None se niente)."""
    tmin, tmax = tri.min(1), tri.max(1)
    tri = tri[(tmin[:, 1] <= lo[1] + 0.005) & (tmin[:, 0] <= hi[0]) & (tmax[:, 0] >= lo[0]) & (tmin[:, 2] <= hi[2]) & (tmax[:, 2] >= lo[2])]
    if len(tri) == 0:
        return None
    ymin = punti[:, 1].min()
    bassi = punti[punti[:, 1] < ymin + 0.02]
    if len(bassi) > 200:
        bassi = bassi[np.linspace(0, len(bassi) - 1, 200).astype(int)]
    a, b, c = tri[:, 0], tri[:, 1], tri[:, 2]
    # baricentriche in xz
    v0 = (c - a)[:, [0, 2]]
    v1 = (b - a)[:, [0, 2]]
    d00 = (v0 * v0).sum(-1)
    d01 = (v0 * v1).sum(-1)
    d11 = (v1 * v1).sum(-1)
    den = d00 * d11 - d01 * d01
    ok = np.abs(den) > 1e-12
    meglio = np.inf
    for p in bassi:
        v2 = p[[0, 2]] - a[:, [0, 2]]
        d02 = (v0 * v2).sum(-1)
        d12 = (v1 * v2).sum(-1)
        with np.errstate(divide="ignore", invalid="ignore"):
            u = (d11 * d02 - d01 * d12) / den
            w = (d00 * d12 - d01 * d02) / den
        dentro = ok & (u >= -1e-6) & (w >= -1e-6) & (u + w <= 1 + 1e-6)
        if not dentro.any():
            continue
        y = a[dentro, 1] + u[dentro] * (c[dentro, 1] - a[dentro, 1]) + w[dentro] * (b[dentro, 1] - a[dentro, 1])
        y = y[y <= p[1] + 0.005]
        if len(y):
            meglio = min(meglio, p[1] - y.max())
    return None if meglio == np.inf else float(max(meglio, 0.0))


def misura(punti, mio, tri, own, lo, hi, soglia, blocco=1500):
    """Distanza minima dall'oggetto per ogni vicino. Limite inferiore per triangolo: distanza fra il suo centro e
    il punto dell'oggetto più vicino, meno il suo raggio; il calcolo esatto si fa sui triangoli in ordine di
    limite, finché il limite non supera il minimo trovato (e la soglia dei contatti)."""
    albero = cKDTree(punti)
    centro = tri.mean(1)
    raggio = np.sqrt(((tri - centro[:, None]) ** 2).sum(-1)).max(1)
    dc, _ = albero.query(centro)
    # il passo fra i punti dell'oggetto: un punto della superficie può stare fino a mezzo passo da un vertice
    lb = np.maximum(0.0, dc - raggio - passo_punti(punti))
    ordine = np.argsort(lb, kind="stable")
    per = {}
    best, punto = np.inf, None
    k = 0
    while k < len(ordine) and lb[ordine[k]] <= max(soglia, best):
        pezzo = ordine[k:k + blocco]
        pezzo = pezzo[lb[pezzo] <= max(soglia, best)]
        d, idx = min_per_triangolo(punti, tri[pezzo])
        for j, dj in zip(own[pezzo], d):
            if dj < per.get(j, np.inf):
                per[j] = dj
        m = int(np.argmin(d))
        if d[m] < best:
            best, punto = float(d[m]), punti[idx[m]].round(3).tolist()
        k += blocco
    # i vertici dei vicini vicinissimi all'oggetto contro i suoi triangoli (un gancio che tocca una faccia),
    # solo per i vicini non ancora a contatto, contro i 24 triangoli dell'oggetto più vicini a ciascun vertice
    vt = tri.reshape(-1, 3)
    vo = np.repeat(own, 3)
    gia = np.array([per.get(j, np.inf) <= soglia for j in vo]) if len(vo) else np.zeros(0, bool)
    sel = (vt >= lo - soglia).all(1) & (vt <= hi + soglia).all(1) & ~gia
    vp, vo = vt[sel], vo[sel]
    if len(vp):
        vp, inv = np.unique(np.round(vp, 4), axis=0, return_inverse=True)
        vo_u = np.zeros(len(vp), dtype=vo.dtype)
        vo_u[inv.ravel()] = vo
        vo = vo_u
        if len(vp) > 3000:
            pick = np.random.default_rng(0).choice(len(vp), 3000, replace=False)
            vp, vo = vp[pick], vo[pick]
        cm = mio.mean(1)
        kk = min(24, len(mio))
        _, vic = cKDTree(cm).query(vp, k=kk)
        vic = vic.reshape(len(vp), kk)
        t = mio[vic]                       # (n, k, 3, 3)
        dd = np.sqrt(punto_triangolo_coppie(np.repeat(vp, kk, 0), t.reshape(-1, 3, 3)).reshape(len(vp), kk).min(1))
        for j, dj in zip(vo, dd):
            if dj < per.get(j, np.inf):
                per[j] = dj
    return per, punto


def passo_punti(punti):
    if len(punti) < 2:
        return 0.0
    d, _ = cKDTree(punti).query(punti, k=2)
    return float(np.median(d[:, 1])) * 0.5


def punto_triangolo_coppie(p, t):
    """Distanza al quadrato fra p[i] e il triangolo t[i] (coppie)."""
    out = np.empty(len(p))
    for s in range(0, len(p), 200000):
        pp, tt = p[s:s + 200000], t[s:s + 200000]
        # riuso la versione a matrice sulla diagonale, a pezzi piccoli
        out[s:s + 200000] = _coppie(pp, tt)
    return out


def _coppie(p, t):
    a, b, c = t[:, 0], t[:, 1], t[:, 2]
    ab, ac, ap = b - a, c - a, p - a
    d1, d2 = (ab * ap).sum(-1), (ac * ap).sum(-1)
    bp = p - b
    d3, d4 = (ab * bp).sum(-1), (ac * bp).sum(-1)
    cp = p - c
    d5, d6 = (ab * cp).sum(-1), (ac * cp).sum(-1)
    va, vb, vc = d3 * d6 - d5 * d4, d5 * d2 - d1 * d6, d1 * d4 - d3 * d2
    den = va + vb + vc
    den = np.where(np.abs(den) < 1e-20, 1e-20, den)
    q = a + ab * (vb / den)[:, None] + ac * (vc / den)[:, None]
    with np.errstate(divide="ignore", invalid="ignore"):
        t_ab = np.nan_to_num(d1 / (d1 - d3))
        t_ac = np.nan_to_num(d2 / (d2 - d6))
        t_bc = np.nan_to_num((d4 - d3) / ((d4 - d3) + (d5 - d6)))
    q = np.where(((va <= 0) & ((d4 - d3) >= 0) & ((d5 - d6) >= 0))[:, None], b + (c - b) * t_bc[:, None], q)
    q = np.where(((vb <= 0) & (d2 >= 0) & (d6 <= 0))[:, None], a + ac * t_ac[:, None], q)
    q = np.where(((vc <= 0) & (d1 >= 0) & (d3 <= 0))[:, None], a + ab * t_ab[:, None], q)
    q = np.where(((d6 >= 0) & (d5 <= d6))[:, None], c, q)
    q = np.where(((d3 >= 0) & (d4 <= d3))[:, None], b, q)
    q = np.where(((d1 <= 0) & (d2 <= 0))[:, None], a, q)
    return ((p - q) ** 2).sum(-1)


def main():
    base = sys.argv[1]
    soglia = float(sys.argv[2]) if len(sys.argv) > 2 else 0.01
    prefissi = sys.argv[3].split(",") if len(sys.argv) > 3 else []
    meta = json.load(open(base + ".json"))
    tutti = np.fromfile(base + ".bin", dtype=np.float32).reshape(-1, 3, 3).astype(np.float64)
    voci = meta["mesh"]
    box_min = np.array([v["box"][:3] for v in voci])
    box_max = box_min + np.array([v["box"][3:] for v in voci])
    diag = np.linalg.norm(box_max - box_min, axis=1)
    vis = np.array([v["visibile"] for v in voci])
    acqua = np.array([v["acqua"] for v in voci])
    oggetto = vis & ~acqua & (diag > OGGETTO_MIN) & (diag < OGGETTO_MAX)
    if prefissi:
        oggetto &= np.array([any(v["nodo"].startswith(p) for p in prefissi) for v in voci])
    architettura = vis & ~acqua & (diag >= OGGETTO_MAX)
    print(f"{len(voci)} mesh, {oggetto.sum()} oggetti, {architettura.sum()} pezzi di architettura, {len(tutti)} triangoli")
    tri_min = tutti.min(1)
    tri_max = tutti.max(1)
    risultati = []
    contatti = {}
    distanze_di = {}
    for conta, i in enumerate(np.nonzero(oggetto)[0]):
        if conta % 100 == 0:
            print(f"  {conta}/{oggetto.sum()}", flush=True)
        v = voci[i]
        mio = tutti[v["da"]:v["da"] + v["n"]]
        lo, hi = box_min[i] - MARGINE, box_max[i] + MARGINE
        vicini = np.nonzero(vis & (box_min <= hi).all(1) & (box_max >= lo).all(1))[0]
        vicini = vicini[vicini != i]
        tri_l, owner = [], []
        for j in vicini:
            s, n = voci[j]["da"], voci[j]["n"]
            sel = np.nonzero((tri_min[s:s + n] <= hi).all(1) & (tri_max[s:s + n] >= lo).all(1))[0]
            if len(sel):
                tri_l.append(tutti[s + sel])
                owner.append(np.full(len(sel), j))
        punti = punti_di(mio)
        r = {"i": int(i), "nodo": v["nodo"], "istanza": v["istanza"], "centro": ((box_min[i] + box_max[i]) / 2).round(3).tolist(),
             "dim": (box_max[i] - box_min[i]).round(3).tolist(), "piccolo": bool((box_max[i] - box_min[i]).max() < PICCOLO)}
        if not tri_l:
            r.update({"distanza": None, "vicino": None, "sotto": None})
            risultati.append(r)
            continue
        tri = np.concatenate(tri_l)
        own = np.concatenate(owner)
        per, punto = misura(punti, mio, tri, own, box_min[i], box_max[i], soglia)
        if not per:
            r.update({"distanza": None, "vicino": None, "sotto": sotto(punti, tri, box_min[i], box_max[i])})
            risultati.append(r)
            contatti[int(i)] = []
            continue
        jbest = min(per, key=per.get)
        r["distanza"] = round(float(per[jbest]), 4)
        r["vicino"] = voci[jbest]["nodo"] + ("" if voci[jbest]["istanza"] < 0 else f"#{voci[jbest]['istanza']}")
        r["punto"] = punto
        s_ = sotto(punti, tri, box_min[i], box_max[i])
        r["sotto"] = None if s_ is None else round(s_, 4)
        contatti[int(i)] = [int(j) for j, d in per.items() if d <= soglia]
        distanze_di[int(i)] = {int(j): float(d) for j, d in per.items() if d <= MARGINE}
        r["tocca"] = [voci[j]["nodo"] for j in contatti[int(i)]][:6]
        risultati.append(r)
    # chi arriva all'architettura
    retto = set(int(i) for i in np.nonzero(architettura)[0])
    vicini_di = {}
    for i, js in contatti.items():
        for j in js:
            vicini_di.setdefault(i, set()).add(j)
            vicini_di.setdefault(j, set()).add(i)
    coda = deque(retto)
    while coda:
        i = coda.popleft()
        for j in vicini_di.get(i, ()):
            if j not in retto:
                retto.add(j)
                coda.append(j)
    for r in risultati:
        r["retto"] = r["i"] in retto
        if not r["retto"]:
            # il gruppo di oggetti che si toccano fra loro senza arrivare a niente
            gruppo, coda = {r["i"]}, deque([r["i"]])
            while coda:
                i = coda.popleft()
                for j in vicini_di.get(i, ()):
                    if j not in gruppo:
                        gruppo.add(j)
                        coda.append(j)
            r["catena"] = len(gruppo)
            # quanto manca al gruppo per toccare qualcos'altro, e cosa
            fuori = [(d, j) for g in gruppo for j, d in distanze_di.get(g, {}).items() if j not in gruppo]
            if fuori:
                d, j = min(fuori)
                r["stacco"] = round(d, 4)
                r["stacco_da"] = voci[j]["nodo"] + ("" if voci[j]["istanza"] < 0 else f"#{voci[j]['istanza']}")
            else:
                r["stacco"] = None
            r["gruppo"] = sorted(voci[g]["nodo"] for g in gruppo)[:8]
    sfx = ("_" + sys.argv[4]) if len(sys.argv) > 4 else ""
    json.dump({"base": base, "soglia": soglia, "oggetti": risultati}, open(base + "_distanze" + sfx + ".json", "w"), indent=0)
    staccati = [r for r in risultati if not r["retto"]]
    print(f"{len(risultati)} oggetti misurati, {len(staccati)} non arrivano all'architettura (soglia {soglia * 100:.0f} cm)")


if __name__ == "__main__":
    main()
