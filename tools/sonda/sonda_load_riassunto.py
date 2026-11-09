"""Riassunto delle righe SONDA_LOAD (godot/tests/sonda_load.gd) di uno o più log: i load() sul thread principale,
per percorso e punto del codice. Uso: python3 tools/sonda/sonda_load_riassunto.py <log>... > riassunto.md"""
import os, sys
from collections import defaultdict

RADICE = os.path.join(os.path.dirname(__file__), "..", "..", "godot")
PESANTI = (".glb", ".gltf", ".tscn", ".scn", ".ogg", ".wav", ".mp3", ".png", ".jpg", ".jpeg", ".webp", ".exr", ".hdr", ".res", ".mesh")


def dimensione(percorso):
    p = os.path.join(RADICE, percorso.replace("res://", ""))
    try:
        return os.path.getsize(p)
    except OSError:
        return 0


voci = defaultdict(lambda: {"n": 0, "max": 0.0, "tot": 0.0, "freddi": 0, "nel_thread": 0, "scenari": set(), "fasi": defaultdict(float)})
for log in sys.argv[1:]:
    scenario = os.path.basename(log).replace("sl_", "").replace(".log", "")
    for riga in open(log, encoding="utf-8", errors="replace"):
        if not riga.startswith("SONDA_LOAD|"):
            continue
        parti = riga.rstrip("\n").split("|")
        if len(parti) < 7:
            continue
        _, ms, thread, in_cache, nel_thread, percorso, dove = parti[:7]
        fase = parti[7] if len(parti) > 7 else "?"
        if thread != "main":
            continue
        v = voci[(percorso, dove)]
        ms = float(ms)
        v["n"] += 1
        v["max"] = max(v["max"], ms)
        v["tot"] += ms
        v["freddi"] += in_cache == "0"
        v["nel_thread"] += nel_thread == "1"
        v["scenari"].add(scenario)
        v["fasi"][fase] = max(v["fasi"][fase], ms)

righe = sorted(voci.items(), key=lambda kv: -kv[1]["max"])
print("| ms max | ms max a gioco avviato | volte | non in cache | il thread lo caricava | MB | percorso | dove | fasi (ms max) | scenari |")
print("|---|---|---|---|---|---|---|---|---|---|")
for (percorso, dove), v in righe:
    mb = dimensione(percorso) / 1048576
    rischio = percorso.lower().endswith(PESANTI) and v["freddi"] > 0
    if v["max"] < 5 and not v["nel_thread"] and not (rischio and mb > 0.2):
        continue
    fasi = ", ".join("%s %.0f" % (f, m) for f, m in sorted(v["fasi"].items(), key=lambda x: -x[1]))
    print("| %.1f | %.1f | %d | %d | %d | %.2f | %s | %s | %s | %s |" % (v["max"], v["fasi"].get("gioco", 0.0), v["n"], v["freddi"],
            v["nel_thread"], mb, percorso, dove, fasi, ", ".join(sorted(v["scenari"]))))
