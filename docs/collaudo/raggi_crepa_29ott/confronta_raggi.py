# Confronta i JSON di confronto_raggi.gd: <prima.json> <dopo.json> [rumore.json (secondo giro del commit di prima)]
# Stampa ogni differenza sopra 1 mm (Polaroid, pozze, galleggianti, griglia delle medusine, vertici delle bave, nodi),
# togliendo i nodi che si muovono già fra due giri dello stesso commit.
import json, sys, math
A = json.load(open(sys.argv[1])); B = json.load(open(sys.argv[2]))
R = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else None
SOGLIA = 0.001
def d(a, b): return math.dist(a, b)
print("stato", A["stato"])
for k in ["polaroid", "pozze", "galleggianti", "medusine", "bava", "nodi"]:
    print(f"  {k}: prima {len(A[k])}, dopo {len(B[k])}")
import re
def gruppi(N):
    g = {}
    for p, v in N.items():
        g.setdefault(re.sub(r"@(\w+)@\d+", r"@\1@", p), []).append((p, v))
    return g
def abbina(A, B):
    # i nodi coi nomi automatici (@Tipo@N) cambiano numero fra due giri: per ogni gruppo (percorso senza numeri) si
    # abbina ogni nodo di prima al più vicino di dopo ancora libero
    ga, gb = gruppi(A), gruppi(B); out = {}
    for k, la in ga.items():
        lb = list(gb.get(k, []))
        for p, v in la:
            if not lb: out[p] = (v, None); continue
            j = min(range(len(lb)), key=lambda i: math.dist(v, lb[i][1]))
            out[p] = (v, lb.pop(j)[1])
    return out
mancano = set(gruppi(A["nodi"])) ^ set(gruppi(B["nodi"]))
if mancano: print("  gruppi di nodi solo in uno dei due:", len(mancano), sorted(mancano)[:10])
# Polaroid
for p, a in sorted(A["polaroid"].items(), key=lambda x: x[1]["foto"]):
    b = B["polaroid"].get(p)
    if not b: print("  POLAROID manca dopo", p); continue
    dp = d(a["pos"], b["pos"]); dr = max(d(a[x], b[x]) for x in "xyz")
    print("  P%02d %s spostamento %.3f mm, rotazione %.5f%s" % (a["foto"], "" if a["visibile"] else "(nascosta)", dp * 1000, dr, "  <== DIFFERENZA" if dp > SOGLIA or dr > 0.001 else ""))
for k in ["pozze", "galleggianti"]:
    for p, a in A[k].items():
        b = B[k].get(p)
        if b is None or d(a, b) > SOGLIA: print("  %s %s: %s -> %s" % (k, p, a, b))
for p, a in A["medusine"].items():
    b = B["medusine"].get(p)
    if not b: print("  MEDUSINE manca dopo", p); continue
    ga, gb = a["griglia"], b["griglia"]; n = a["g_n"]
    print("  medusine %s: griglia %dx%d (%d punti), g_min %s / %s, profondo %s -> %s" % (p, n[0], n[1], len(ga), a["g_min"], b["g_min"], a["profondo"], b["profondo"]))
    diffs = [(i, ga[i], gb[i]) for i in range(min(len(ga), len(gb))) if abs(ga[i] - gb[i]) > SOGLIA]
    print("    punti diversi sopra 1 mm: %d" % len(diffs))
    for i, ya, yb in diffs[:40]:
        x = a["g_min"][0] + (i % n[0]) * 0.0; print("    i %d (col %d, riga %d): %.4f -> %.4f (%+.1f mm)" % (i, i % n[0], i // n[0], ya, yb, (yb - ya) * 1000))
for p, va in A["bava"].items():
    vb = B["bava"].get(p, [])
    diffs = [(i, va[i], vb[i]) for i in range(min(len(va), len(vb))) if d(va[i], vb[i]) > SOGLIA]
    print("  bava %s: %d vertici, diversi sopra 1 mm %d%s" % (p, len(va), len(diffs), "" if len(va) == len(vb) else " (numero diverso: %d)" % len(vb)))
    for i, x, y in diffs[:10]: print("    v %d: %s -> %s (%.1f mm)" % (i, x, y, d(x, y) * 1000))
rumore = set()
if R:
    rumore = {re.sub(r"@(\w+)@\d+", r"@\1@", p) for p, (a, b) in abbina(A["nodi"], R["nodi"]).items() if b is None or math.dist(a, b) > SOGLIA}
    print("  gruppi di nodi che si muovono già fra due giri dello stesso commit:", len(rumore))
mossi = [(p, a, b) for p, (a, b) in abbina(A["nodi"], B["nodi"]).items() if b is not None and math.dist(a, b) > SOGLIA and re.sub(r"@(\w+)@\d+", r"@\1@", p) not in rumore]
print("  nodi mossi sopra 1 mm (senza il rumore): %d" % len(mossi))
for p, a, b in sorted(mossi, key=lambda x: -math.dist(x[1], x[2]))[:40]:
    print("    %.1f mm  %s  %s -> %s" % (math.dist(a, b) * 1000, p, a, b))
for k in ["prima", "dopo"]:
    T = (A if k == "prima" else B)["tempi"]
    print("  tempi %s: fotogrammi %d, più lunghi %s" % (k, T["fotogrammi"], ", ".join("%.0f" % x for x in T["piu_lunghi_ms"])))
    for kk, v in T.items():
        if kk.startswith("griglia"): print("    %s: %s" % (kk, ", ".join("%.2f" % x for x in v)))
    s = T.get("snap_polaroid_ms_e_spostamento_mm", [])
    if s: print("    snap Polaroid: %d, totale %.2f ms, il più lento %.2f ms; spostamento rifacendolo max %.3f mm" % (len(s), sum(x[1] for x in s), max(x[1] for x in s), max(x[2] for x in s)))
