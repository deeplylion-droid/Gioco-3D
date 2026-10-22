#!/usr/bin/env python3
"""Collaudo: righe "mira" per giro.gd, gli scatti ravvicinati degli oggetti da guardare da vicino:
gli oggetti piccoli (sotto i 40 cm) che non stanno sul pavimento e tutti quelli che non arrivano
all'architettura (distanze.py). Scrive anche l'elenco degli oggetti piccoli in CSV.
Uso: ravvicinati.py <distanze.json> <celle.json> <lista di uscita> <elenco.csv> [--box x0,z0,x1,z1,y0,y1] [--prefisso p]
"""
import argparse
import csv
import json
import math

ap = argparse.ArgumentParser()
ap.add_argument("distanze")
ap.add_argument("celle")
ap.add_argument("uscita")
ap.add_argument("elenco")
ap.add_argument("--box")
ap.add_argument("--prefisso", default="r")
a = ap.parse_args()
ogg = json.load(open(a.distanze))["oggetti"]
celle = json.load(open(a.celle))["celle"]
griglia = {}
for x, y, z, o in celle:
    griglia.setdefault((round(x * 2), round(z * 2)), []).append(y)


def pavimento(x, y, z):
    """Il pavimento dove si cammina più vicino sotto (x, z), nel raggio di 1,5 m."""
    best = None
    for dx in range(-3, 4):
        for dz in range(-3, 4):
            for yy in griglia.get((round(x * 2) + dx, round(z * 2) + dz), []):
                if yy <= y + 0.05 and (best is None or yy > best):
                    best = yy
    return best


def dentro(c):
    if not a.box:
        return True
    v = [float(t) for t in a.box.split(",")]
    return v[0] <= c[0] <= v[2] and v[1] <= c[2] <= v[3] and (len(v) < 6 or v[4] <= c[1] <= v[5])


righe, elenco = [], []
for o in ogg:
    c, d = o["centro"], o["dim"]
    if not dentro(c):
        continue
    basso = c[1] - d[1] / 2
    pav = pavimento(c[0], basso, c[2])
    alto_da_terra = None if pav is None else basso - pav
    sul_pavimento = alto_da_terra is not None and alto_da_terra < 0.06
    if o["piccolo"]:
        elenco.append([o["nodo"], o["istanza"], *c, *d, o.get("distanza"), o.get("vicino"), o.get("sotto"),
                       None if alto_da_terra is None else round(alto_da_terra, 3), "sì" if sul_pavimento else "no",
                       "sì" if o["retto"] else "NO", o.get("stacco"), o.get("stacco_da")])
    nome = (f"{a.prefisso}_{o['nodo'].split('/')[-1]}" + (f"_{o['istanza']}" if o["istanza"] >= 0 else "")).replace(" ", "_")
    if (o["piccolo"] and not sul_pavimento) or not o["retto"]:
        dist = min(2.0, max(0.45, 2.2 * max(d)))
        righe.append(f"mira {nome} {c[0]:.3f} {c[1]:.3f} {c[2]:.3f} {dist:.2f}")
    # lo stacco da vicino: dal resto per chi non arriva all'architettura, dal suo pezzo gemello (anta e corpo)
    coppia = o.get("stacco_coppia") if not o["retto"] else o.get("fratelli_coppia")
    if coppia:
        p, q = coppia
        righe.append(f"spazio {nome}_stacco {p[0]:.4f} {p[1]:.4f} {p[2]:.4f} {q[0]:.4f} {q[1]:.4f} {q[2]:.4f}")
open(a.uscita, "w").write("\n".join(righe) + "\n")
with open(a.elenco, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["nodo", "istanza", "x", "y", "z", "dx", "dy", "dz", "distanza_min_m", "piu_vicino", "spazio_sotto_m",
                "altezza_da_terra_m", "sul_pavimento", "arriva_all_architettura", "stacco_gruppo_m", "stacco_da"])
    w.writerows(elenco)
print(f"{len(elenco)} oggetti piccoli, {len(righe)} da guardare da vicino")
