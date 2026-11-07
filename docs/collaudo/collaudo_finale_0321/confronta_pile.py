"""Confronto delle pile del fiume: 0.3.20 (dal generatore) e candidata (dal file), istanze dei MultiMesh nella scena, in
coordinate del fiume. Per ogni gruppo: istanze identiche (posizione e rotazione entro 0,1 mm), spostate (stessa
istanza più vicina entro 0,5 m ma diversa), mancanti, nuove, specchiate (determinante negativo). Le differenze nell'angolo
a sinistra dell'ingresso (la pila nuova della 0.3.21) a parte."""
import sys
import numpy as np
from scipy.spatial import cKDTree

def leggi(p):
    g = {}
    cur = None
    for r in open(p):
        r = r.strip()
        if not r:
            continue
        if not r[0] in "-0123456789":
            parti = r.split()
            cur = parti[0]
            g[cur] = {"n": int(parti[1]) if len(parti) > 1 and parti[1].isdigit() else -1, "mesh": parti[2] if len(parti) > 2 else "", "o": [], "b": [], "c": []}
            continue
        pz = r.split("|")
        g[cur]["o"].append([float(x) for x in pz[0].split()])
        g[cur]["b"].append([float(x) for x in pz[1].split()])
        g[cur]["c"].append(pz[2].strip() if len(pz) > 2 else "")
    for k in g:
        g[k]["o"] = np.array(g[k]["o"]).reshape(-1, 3)
        g[k]["b"] = np.array(g[k]["b"]).reshape(-1, 9)
    return g

ANGOLO = (np.array([-30.4, -0.2, -28.8]), np.array([-28.4, 5.8, -27.1]))
def in_angolo(o):
    return np.all((o >= ANGOLO[0]) & (o <= ANGOLO[1]), axis=-1)

a = leggi(sys.argv[1])   # 0.3.20
b = leggi(sys.argv[2])   # candidata
tot = {"uguali": 0, "spostate": 0, "mancanti": 0, "nuove": 0}
for k in sorted(set(a) | set(b)):
    if k not in a or k not in b:
        print("%s: solo in %s" % (k, "candidata" if k in b else "0.3.20"))
        continue
    A, B = a[k], b[k]
    detA = np.linalg.det(A["b"].reshape(-1, 3, 3)) if len(A["b"]) else np.array([])
    detB = np.linalg.det(B["b"].reshape(-1, 3, 3)) if len(B["b"]) else np.array([])
    print("%s: 0.3.20 %d, candidata %d; mesh %s / %s; specchiate %d / %d" % (k, len(A["o"]), len(B["o"]), A["mesh"], B["mesh"], (detA < 0).sum(), (detB < 0).sum()))
    if len(A["o"]) == 0 or len(B["o"]) == 0:
        continue
    tb = cKDTree(B["o"]); ta = cKDTree(A["o"])
    usate = set()
    uguali = spostate = mancanti = 0
    mancanti_ang = mancanti_fuori = 0
    righe = []
    for i, o in enumerate(A["o"]):
        d, j = tb.query(o)
        diff_b = np.abs(A["b"][i] - B["b"][j]).max()
        if d < 1e-4 and diff_b < 1e-4 and A["c"][i] == B["c"][j]:
            uguali += 1; usate.add(j)
        elif d < 0.5:
            spostate += 1; usate.add(j)
            righe.append("  spostata %s: %.4f m, rotazione %.4f, tinta %s%s" % (np.round(o, 3), d, diff_b, "uguale" if A["c"][i] == B["c"][j] else "diversa", " (angolo)" if in_angolo(o) else ""))
        else:
            mancanti += 1
            if in_angolo(o): mancanti_ang += 1
            else:
                mancanti_fuori += 1
                righe.append("  MANCANTE fuori dall'angolo %s" % np.round(o, 3))
    nuove = [j for j in range(len(B["o"])) if j not in usate]
    nuove_ang = sum(1 for j in nuove if in_angolo(B["o"][j]))
    for j in nuove:
        if not in_angolo(B["o"][j]):
            d, i = ta.query(B["o"][j])
            righe.append("  NUOVA fuori dall'angolo %s (la più vicina della 0.3.20 a %.3f m)" % (np.round(B["o"][j], 3), d))
    print("  uguali %d, spostate %d, mancanti %d (nell'angolo %d), nuove %d (nell'angolo %d)" % (uguali, spostate, mancanti, mancanti_ang, len(nuove), nuove_ang))
    for r in righe[:40]:
        print(r)
    if len(righe) > 40:
        print("  ... altre %d" % (len(righe) - 40))
    tot["uguali"] += uguali; tot["spostate"] += spostate; tot["mancanti"] += mancanti; tot["nuove"] += len(nuove)
print("TOTALE", tot)
