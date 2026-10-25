# Confronta gli elenchi di sonda_blocchi.gd (main e blocchi): per categoria, quanti ci sono, quali mancano e quali in più.
# Due elementi sono lo stesso se hanno la stessa classe (e strato, per le forme) e il centro a meno di TOLL m.
# Si tolgono le cose che si muovono da sole (il giocatore, i gommoni che galleggiano); SOLO=<prefissi,...> tiene solo
# quelle zone. Uso: [SOLO=SalaTorre,Sala] python3 confronta_inventari.py <elenco_main.json> <elenco_blocchi.json> [toll 0.05]
import json, sys
from collections import defaultdict
import numpy as np
from scipy.spatial import cKDTree

a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
TOLL = float(sys.argv[3]) if len(sys.argv) > 3 else 0.05
import os
TOGLI = ("Player/", "SalaSottomarino/Gommoni/")
SOLO = tuple(x for x in os.environ.get("SOLO", "").split(",") if x)
def tieni(e):
    return not e["n"].startswith(TOGLI) and (not SOLO or e["n"].startswith(SOLO))
for d in (a, b):
    for cat in list(d):
        d[cat] = [e for e in d[cat] if tieni(e)]


def chiave(cat, e):
    if cat == "forma":
        return (e["c"], e["l"], e["a"], tuple(round(x, 1) for x in e.get("s", [0, 0, 0])))
    if cat == "mesh":
        return (e["c"], tuple(round(x, 1) for x in e["s"]))
    return (e["c"],)


def zona(n):
    parti = n.split("/")
    return "/".join(parti[:2])


strato_diverso = []
for cat in ["mesh", "forma", "luce", "checkpoint", "porta"]:
    ga, gb = defaultdict(list), defaultdict(list)
    for e in a.get(cat, []):
        ga[chiave(cat, e)].append(e)
    for e in b.get(cat, []):
        gb[chiave(cat, e)].append(e)
    mancano, inpiu = [], []
    for k in set(ga) | set(gb):
        la, lb = ga.get(k, []), gb.get(k, [])
        if not lb:
            mancano += la; continue
        if not la:
            inpiu += lb; continue
        pa = np.array([e["p"] for e in la]); pb = np.array([e["p"] for e in lb])
        usati = set()
        tb = cKDTree(pb)
        for i, e in enumerate(la):
            ds, js = tb.query(pa[i], k=min(8, len(lb)))
            ds = np.atleast_1d(ds); js = np.atleast_1d(js)
            ok = False
            for d, j in zip(ds, js):
                if d <= TOLL and j not in usati:
                    usati.add(j); ok = True
                    if cat in ("mesh", "luce") and any(k in e and k in lb[j] and e[k] != lb[j][k] for k in ("l", "m")):
                        strato_diverso.append((e, lb[j]))
                    break
            if not ok:
                mancano.append(e)
        inpiu += [e for j, e in enumerate(lb) if j not in usati]
    extra = ""
    if cat in ("checkpoint", "porta"):
        na = sum(1 for e in a.get(cat, []) if e.get("attivo")); nb = sum(1 for e in b.get(cat, []) if e.get("attivo"))
        extra = ", attivi %d / %d" % (na, nb)
        spenti = [e for e in b.get(cat, []) if not e.get("attivo")]
        for e in spenti[:10]:
            print("    spento in blocchi: %s %s" % (e["n"], e["p"]))
    print("%-10s main %6d  blocchi %6d  mancano %5d  in più %5d%s" % (cat, len(a.get(cat, [])), len(b.get(cat, [])), len(mancano), len(inpiu), extra))
    for titolo, lista in [("mancano", mancano), ("in più", inpiu)]:
        if not lista:
            continue
        perz = defaultdict(int)
        for e in lista:
            perz[zona(e["n"])] += 1
        print("    %s per zona: %s" % (titolo, ", ".join("%s %d" % kv for kv in sorted(perz.items(), key=lambda kv: -kv[1])[:8])))
        for e in lista[:6]:
            print("      %s %s %s %s" % (e["c"], e["p"], e.get("s", e.get("l", "")), e["n"][:110]))

for nome, d in (("main", a), ("blocchi", b)):
    z = [e for e in d.get("mesh", []) if e.get("l", 1) == 0]
    print("mesh visibili con lo strato 0 in %s: %d %s" % (nome, len(z), "" if "l" in (d["mesh"][0] if d.get("mesh") else {}) else "(strato non registrato)"))
    for e in z[:8]:
        print("      %s %s" % (e["p"], e["n"][:110]))
for nome, d in (("main", a), ("blocchi", b)):
    z = [e for e in d.get("luce", []) if e.get("l", 1) == 0 or e.get("m", 1) == 0]
    print("luci accese con strato o cull mask a 0 in %s: %d %s" % (nome, len(z), "" if "m" in (d["luce"][0] if d.get("luce") else {}) else "(non registrati)"))
    for e in z[:8]:
        print("      %s %s" % (e["p"], e["n"][:110]))
print("mesh e luci con strato o cull mask diversi fra main e blocchi: %d" % len(strato_diverso))
for x, y in strato_diverso[:12]:
    print("      %s main l %s m %s, blocchi l %s m %s %s" % (x["p"], x.get("l"), x.get("m", "-"), y.get("l"), y.get("m", "-"), y["n"][:100]))
