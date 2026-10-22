#!/usr/bin/env python3
"""Collaudo: sceglie i punti del giro dagli occhi del giocatore dalle celle raggiungibili a piedi
(<base>_celle.json di godot/tests/collaudo/geometria.gd) e scrive la lista per giro.gd.

Un punto ogni PASSO metri (di serie 3,5) fra le celle della zona, nell'ordine dei checkpoint; da ogni punto
quattro scatti all'altezza degli occhi (1,6 m), verso nord, est, sud e ovest, un po' inclinati in basso.
Uso: python3 tools/collaudo/punti_giro.py <base> <lista di uscita> [--box x0,z0,x1,z1[,y0,y1]] [--ordini a-b]
     [--passo 3.5] [--pitch -12] [--prefisso p]
"""
import argparse
import json
import math

ap = argparse.ArgumentParser()
ap.add_argument("base")
ap.add_argument("uscita")
ap.add_argument("--box", action="append", default=[])
ap.add_argument("--ordini")
ap.add_argument("--passo", type=float, default=3.5)
ap.add_argument("--pitch", type=float, default=-12)
ap.add_argument("--prefisso", default="g")
ap.add_argument("--occhi", type=float, default=1.6)
a = ap.parse_args()

dati = json.load(open(a.base + "_celle.json"))
celle = dati["celle"]


def nella_zona(c):
    x, y, z, o = c
    if a.ordini:
        lo, hi = (int(t) for t in a.ordini.split("-"))
        if not lo <= o <= hi:
            return False
    if a.box:
        for b in a.box:
            v = [float(t) for t in b.split(",")]
            if v[0] <= x <= v[2] and v[1] <= z <= v[3] and (len(v) < 6 or v[4] <= y <= v[5]):
                return True
        return False
    return True


celle = sorted([c for c in celle if nella_zona(c)], key=lambda c: (c[3], c[0], c[2]))
scelti = []
for c in celle:
    if all(math.dist((c[0], c[1] * 2, c[2]), (s[0], s[1] * 2, s[2])) >= a.passo for s in scelti):
        scelti.append(c)
# ordine: per checkpoint, poi il più vicino al precedente
ordinati = []
rimasti = scelti[:]
while rimasti:
    if not ordinati:
        nxt = min(rimasti, key=lambda c: (c[3], c[0], c[2]))
    else:
        u = ordinati[-1]
        omin = min(c[3] for c in rimasti)
        cand = [c for c in rimasti if c[3] == omin]
        nxt = min(cand, key=lambda c: math.dist((c[0], c[1], c[2]), (u[0], u[1], u[2])))
    ordinati.append(nxt)
    rimasti.remove(nxt)
with open(a.uscita, "w") as f:
    f.write(f"# {a.base} {len(ordinati)} punti\n")
    for i, c in enumerate(ordinati):
        for nome, yaw in (("n", 0), ("o", 90), ("s", 180), ("e", -90)):
            f.write(f"{a.prefisso}{i:03d}_{nome} {c[0]:.2f} {c[1] + a.occhi:.2f} {c[2]:.2f} {yaw} {a.pitch}\n")
print(f"{len(ordinati)} punti, {len(ordinati) * 4} scatti")
