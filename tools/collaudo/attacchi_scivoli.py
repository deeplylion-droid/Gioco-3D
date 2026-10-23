#!/usr/bin/env python3
"""Collaudo del posizionamento: dove gli scivoli toccano la struttura (squadra collaudo, 23 ottobre).

Legge <base>.json e <base>.bin scritti da godot/tests/collaudo/geometria.gd. Per ogni scivolo (nome con una delle parole
di SCIVOLI, come il passo f del controllo della CI) e ogni mesh che gli passa vicino (pedane, grate, travi, sostegni,
ringhiere: tutto quello che non è acqua né un altro scivolo), campiona le due superfici ogni PASSO nel box in comune e
misura la distanza fra i campioni. I punti dello scivolo a meno di VICINO da quella mesh sono un attacco; gli attacchi
vicini fra loro (entro 40 cm) sono uno solo.

Per ogni attacco: il centro, la distanza minima (0 = si toccano), quanti campioni sono "dentro" l'altra mesh (dalla
parte di dietro della sua faccia più vicina, oltre 1 cm: compenetrazione; per le grate, che non hanno un dentro, non
conta) e quanto. Un attacco dove la distanza minima è fra STACCO e VICINO è un distacco da guardare.

Uso: python3 tools/collaudo/attacchi_scivoli.py <base> <uscita.csv> <lista per giro.gd>
La lista ha una riga "mira" per ogni attacco (due scatti ravvicinati a 70 cm) e una riga "spazio" per ogni distacco.
"""
import csv
import json
import sys

import numpy as np
from scipy.spatial import cKDTree

SCIVOLI = ["scivolo", "discesa", "canali", "tubo_inseguimento", "collare_inseguimento"]
GRATE = ["grigliat", "grata", "grate"]
PASSO = 0.005      # campioni ogni 5 mm
VICINO = 0.05      # un attacco: a meno di 5 cm
STACCO = 0.005     # oltre 5 mm senza toccare: distacco
DENTRO = 0.01      # oltre 1 cm dietro la faccia: compenetrazione


def campiona(tri, box_lo, box_hi, passo):
    """Punti sulla superficie dei triangoli dentro il box, circa uno ogni passo, con la normale del triangolo."""
    lo, hi = tri.min(1), tri.max(1)
    sel = np.all(hi >= box_lo, 1) & np.all(lo <= box_hi, 1)
    t = tri[sel]
    if len(t) == 0:
        return np.zeros((0, 3)), np.zeros((0, 3))
    a, b, c = t[:, 0], t[:, 1], t[:, 2]
    n = np.cross(b - a, c - a)
    area = 0.5 * np.linalg.norm(n, axis=1)
    nn = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    quanti = np.maximum(1, np.ceil(area / (passo * passo))).astype(np.int64)
    quanti = np.minimum(quanti, 4000)
    rip = np.repeat(np.arange(len(t)), quanti)
    rng = np.random.default_rng(1)
    r1, r2 = rng.random(len(rip)), rng.random(len(rip))
    s = np.sqrt(r1)
    u, v = 1 - s, s * (1 - r2)
    w = s * r2
    p = a[rip] * u[:, None] + b[rip] * v[:, None] + c[rip] * w[:, None]
    # anche vertici e metà degli spigoli (i bordi contano di più)
    extra = np.vstack([a, b, c, (a + b) / 2, (b + c) / 2, (c + a) / 2])
    extra_n = np.vstack([nn] * 6)
    p = np.vstack([p, extra])
    pn = np.vstack([nn[rip], extra_n])
    dentro = np.all(p >= box_lo, 1) & np.all(p <= box_hi, 1)
    return p[dentro], pn[dentro]


def main():
    base, uscita, lista = sys.argv[1], sys.argv[2], sys.argv[3]
    meta = json.load(open(base + ".json"))
    tutti = np.fromfile(base + ".bin", dtype=np.float32).reshape(-1, 3, 3).astype(np.float64)
    voci = meta["mesh"]

    def tri_di(v):
        return tutti[v["da"]:v["da"] + v["n"]]

    def box_di(v):
        lo = np.array(v["box"][:3])
        return lo, lo + np.array(v["box"][3:])

    def nome(v):
        return v["nodo"] + ("" if v.get("istanza", -1) < 0 else "#%d" % v["istanza"])

    def e_scivolo(v):
        ultimo = v["nodo"].split("/")[-1].lower()
        return any(p in ultimo for p in SCIVOLI)

    attive = [v for v in voci if v["visibile"] and not v["acqua"] and v["n"] > 0]
    scivoli = [v for v in attive if e_scivolo(v)]
    altri = [v for v in attive if not e_scivolo(v)]
    print("scivoli: %d, altre mesh: %d" % (len(scivoli), len(altri)))
    righe = []
    for s in scivoli:
        slo, shi = box_di(s)
        st = tri_di(s)
        for m in altri:
            mlo, mhi = box_di(m)
            lo = np.maximum(slo, mlo) - VICINO
            hi = np.minimum(shi, mhi) + VICINO
            if np.any(lo > hi):
                continue
            ps, _ = campiona(st, lo, hi, PASSO)
            pm, nm = campiona(tri_di(m), lo, hi, PASSO)
            if len(ps) == 0 or len(pm) == 0:
                continue
            d, j = cKDTree(pm).query(ps, distance_upper_bound=VICINO)
            vicini = np.isfinite(d)
            if not vicini.any():
                continue
            pv, dv, jv = ps[vicini], d[vicini], j[vicini]
            # dalla parte di dietro della faccia più vicina dell'altra mesh: dentro (non per le grate)
            grata = any(g in m["nodo"].lower() for g in GRATE)
            dietro = ((pv - pm[jv]) * nm[jv]).sum(1) < 0
            prof = np.where(dietro & ~grata, dv, 0.0)
            # gruppi: punti entro 40 cm
            albero = cKDTree(pv)
            coppie = albero.query_pairs(0.4, output_type="ndarray")
            padre = np.arange(len(pv))

            def radice(x):
                while padre[x] != x:
                    padre[x] = padre[padre[x]]
                    x = padre[x]
                return x
            for a_, b_ in coppie:
                ra, rb = radice(a_), radice(b_)
                if ra != rb:
                    padre[ra] = rb
            gruppi = {}
            for i in range(len(pv)):
                gruppi.setdefault(radice(i), []).append(i)
            for g in gruppi.values():
                g = np.array(g)
                k = g[np.argmin(dv[g])]
                righe.append({
                    "scivolo": nome(s), "contro": nome(m), "grata": grata,
                    "centro": pv[g].mean(0).round(3).tolist(),
                    "punto": pv[k].round(3).tolist(), "verso": pm[jv[k]].round(3).tolist(),
                    "distanza_min": round(float(dv[g].min()), 4),
                    "dentro_campioni": int((prof[g] > DENTRO).sum()),
                    "dentro_max": round(float(prof[g].max()), 4),
                    "campioni": int(len(g)),
                })
    righe.sort(key=lambda r: (r["scivolo"], r["centro"][1]))
    with open(uscita, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["n", "scivolo", "contro", "centro", "distanza_min_cm", "dentro_max_cm", "dentro_campioni", "campioni", "giudizio"])
        for i, r in enumerate(righe):
            if r["dentro_campioni"] > 0:
                giudizio = "compenetra"
            elif r["distanza_min"] > STACCO:
                giudizio = "staccato"
            else:
                giudizio = "tocca"
            r["giudizio"] = giudizio
            w.writerow([i + 1, r["scivolo"], r["contro"], " ".join("%.2f" % x for x in r["centro"]),
                        "%.1f" % (r["distanza_min"] * 100), "%.1f" % (r["dentro_max"] * 100), r["dentro_campioni"],
                        r["campioni"], giudizio])
    with open(lista, "w") as f:
        for i, r in enumerate(righe):
            c = r["punto"]
            f.write("mira att%03d %.3f %.3f %.3f 0.7\n" % (i + 1, c[0], c[1], c[2]))
            if r["giudizio"] == "staccato":
                q = r["verso"]
                f.write("spazio att%03d_spazio %.3f %.3f %.3f %.3f %.3f %.3f\n" % (i + 1, c[0], c[1], c[2], q[0], q[1], q[2]))
    conta = {}
    for r in righe:
        conta[r["giudizio"]] = conta.get(r["giudizio"], 0) + 1
    print("attacchi: %d %s" % (len(righe), conta))
    for i, r in enumerate(righe):
        if r["giudizio"] != "tocca":
            print("%3d %-10s %s contro %s a %s: distanza %.1f cm, dentro %.1f cm (%d campioni)" % (
                i + 1, r["giudizio"], r["scivolo"], r["contro"], r["centro"], r["distanza_min"] * 100,
                r["dentro_max"] * 100, r["dentro_campioni"]))


if __name__ == "__main__":
    main()
