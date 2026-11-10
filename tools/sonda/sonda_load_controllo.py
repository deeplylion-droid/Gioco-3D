"""Controllo della CI: nei log della sonda dei load() (godot/tests/sonda_load.gd, coi load() riscritti da
sonda_load_codemod.py) nessun caricamento sul thread principale a gioco avviato (fase "gioco") sopra SOGLIA ms.
Uso: python3 tools/sonda/sonda_load_controllo.py <log>...   (esce con 1 se ce n'è almeno uno)"""
import sys

SOGLIA = 5.0
lunghi = []
n = 0
for log in sys.argv[1:]:
    for riga in open(log, encoding="utf-8", errors="replace"):
        if not riga.startswith("SONDA_LOAD|"):
            continue
        c = riga.rstrip("\n").split("|")
        if len(c) < 9 or c[2] != "main" or c[7] != "gioco":
            continue
        n += 1
        if float(c[1]) > SOGLIA:
            lunghi.append("  %s ms  %s  (%s, in cache prima: %s, il thread lo caricava: %s)  [%s]" % (c[1], c[5], c[6], c[3], c[4], log))
print("load() sul thread principale a gioco avviato: %d, sopra %.0f ms: %d" % (n, SOGLIA, len(lunghi)))
for l in lunghi:
    print(l)
sys.exit(1 if lunghi else 0)
