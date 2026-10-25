# Strati (layers) delle mesh e strati e cull mask delle luci, confrontati nodo per nodo (stesso percorso) fra due elenchi.
import json, sys
a = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
for cat, chiavi in (("mesh", ("l",)), ("luce", ("l", "m"))):
    ma = {e["n"]: e for e in a[cat] if "@" not in e["n"]}; mb = {e["n"]: e for e in b[cat] if "@" not in e["n"]}
    comuni = set(ma) & set(mb)
    diversi = [n for n in comuni if any(ma[n].get(k) != mb[n].get(k) for k in chiavi)]
    print("%s: %d nodi col nome uguale, %d con %s diversi" % (cat, len(comuni), len(diversi), "/".join(chiavi)))
    for n in sorted(diversi)[:10]:
        print("   ", n, [(k, ma[n].get(k), mb[n].get(k)) for k in chiavi])
