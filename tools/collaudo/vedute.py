#!/usr/bin/env python3
"""Collaudo: vedute ravvicinate dagli occhi del giocatore. Per ogni oggetto scelto cerca, fra le celle dove si
cammina (celle.json di geometria.gd), il punto all'altezza degli occhi più vicino (fra MIN e MAX metri) da cui il
centro dell'oggetto si vede senza niente in mezzo (raggi contro i triangoli veri di <base>.bin), e scrive una riga
per giro.gd con la camera lì, puntata sull'oggetto, col campo visivo stretto quanto basta.
Uso: vedute.py <base> <distanze.json> <celle.json> <uscita> [--nodi a,b,c] [--tutti-piccoli] [--prefisso p]
     [--box x0,z0,x1,z1,y0,y1] [--stacchi]   (--stacchi: anche chi non arriva all'architettura e i pezzi gemelli staccati)
"""
import argparse
import json
import math

import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument("base")
ap.add_argument("distanze")
ap.add_argument("celle")
ap.add_argument("uscita")
ap.add_argument("--nodi", default="")
ap.add_argument("--tutti-piccoli", action="store_true")
ap.add_argument("--stacchi", action="store_true")
ap.add_argument("--prefisso", default="v")
ap.add_argument("--box")
ap.add_argument("--min", type=float, default=0.8)
ap.add_argument("--max", type=float, default=5.0)
a = ap.parse_args()

meta = json.load(open(a.base + ".json"))["mesh"]
tutti = np.fromfile(a.base + ".bin", dtype=np.float32).reshape(-1, 3, 3)
vis = np.array([v["visibile"] and not v["acqua"] for v in meta])
owner = np.zeros(len(tutti), dtype=np.int32)
for k, v in enumerate(meta):
    owner[v["da"]:v["da"] + v["n"]] = k
ok_tri = vis[owner]
tmin = tutti.min(1)
tmax = tutti.max(1)
ogg = json.load(open(a.distanze))["oggetti"]
celle = np.array([c[:3] for c in json.load(open(a.celle))["celle"]], dtype=np.float64)


def dentro(c):
    if not a.box:
        return True
    v = [float(t) for t in a.box.split(",")]
    return v[0] <= c[0] <= v[2] and v[1] <= c[2] <= v[3] and (len(v) < 6 or v[4] <= c[1] <= v[5])


def libero(p, q, escluso):
    """Vero se il segmento p-q non tocca triangoli (tranne quelli dell'oggetto e gli ultimi 3 cm)."""
    lo, hi = np.minimum(p, q) - 0.01, np.maximum(p, q) + 0.01
    sel = np.nonzero(ok_tri & (tmin <= hi).all(1) & (tmax >= lo).all(1) & (owner != escluso))[0]
    if len(sel) == 0:
        return True
    t = tutti[sel].astype(np.float64)
    d = q - p
    lung = np.linalg.norm(d)
    d = d / lung
    e1 = t[:, 1] - t[:, 0]
    e2 = t[:, 2] - t[:, 0]
    h = np.cross(d, e2)
    det = (e1 * h).sum(1)
    okd = np.abs(det) > 1e-12
    f = np.where(okd, 1.0 / np.where(okd, det, 1), 0)
    s = p - t[:, 0]
    u = f * (s * h).sum(1)
    qv = np.cross(s, e1)
    v = f * (qv @ d)
    tt = f * (qv * e2).sum(1)
    hit = okd & (u >= 0) & (v >= 0) & (u + v <= 1) & (tt > 0.05) & (tt < lung - 0.03)
    return not hit.any()


scelti = []
nodi = set(x for x in a.nodi.split(",") if x)
for o in ogg:
    if not dentro(o["centro"]):
        continue
    if o["nodo"] in nodi or (o["nodo"] + "#" + str(o["istanza"])) in nodi:
        scelti.append(o)
    elif a.tutti_piccoli and o["piccolo"]:
        scelti.append(o)
    elif a.stacchi and (not o["retto"] or o.get("fratelli_coppia")):
        scelti.append(o)
righe = []
senza = 0
for o in scelti:
    c = np.array(o["centro"], dtype=np.float64)
    occhi = celle + np.array([0, 1.6, 0])
    dist = np.linalg.norm(occhi - c, axis=1)
    cand = np.nonzero((dist >= a.min) & (dist <= a.max))[0]
    cand = cand[np.argsort(np.abs(dist[cand] - max(a.min, 1.6 * max(o["dim"]) + 0.6)))]
    trovato = None
    for k in cand[:40]:
        if libero(occhi[k], c, o["i"]):
            trovato = occhi[k]
            break
    nome = (f"{a.prefisso}_{'_'.join(o['nodo'].split('/')[-2:])}" + (f"_{o['istanza']}" if o["istanza"] >= 0 else "")).replace(" ", "_")
    if trovato is None:
        senza += 1
        righe.append(f"# {nome}: nessun punto dove si cammina da cui si veda")
        continue
    d = c - trovato
    yaw = math.degrees(math.atan2(-d[0], -d[2]))
    pitch = math.degrees(math.atan2(d[1], math.hypot(d[0], d[2])))
    fov = max(12.0, min(70.0, math.degrees(2 * math.atan(max(max(o["dim"]) * 1.8, 0.35) / np.linalg.norm(d)))))
    righe.append(f"{nome} {trovato[0]:.3f} {trovato[1]:.3f} {trovato[2]:.3f} {yaw:.1f} {pitch:.1f} {fov:.1f}")
open(a.uscita, "w").write("\n".join(righe) + "\n")
print(f"{len(scelti)} oggetti, {len(scelti) - senza} vedute, {senza} senza un punto da cui si vedano")
