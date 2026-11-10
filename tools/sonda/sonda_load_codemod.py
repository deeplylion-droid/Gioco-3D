"""Solo per il branch lavoro/sonda-load: ogni load( e ResourceLoader.load( degli script diventa
preload("res://tests/sonda_load.gd").da("file:riga", ...), che misura e stampa (godot/tests/sonda_load.gd)."""
import os, re, sys
radice = sys.argv[1]
pat = re.compile(r'(?<![\w.])load\(|ResourceLoader\.load\(')
n_file = n_chiamate = 0
for cartella in ("scripts", "addons"):
    for d, _, fs in os.walk(os.path.join(radice, cartella)):
        for f in fs:
            if not f.endswith(".gd"):
                continue
            p = os.path.join(d, f)
            righe = open(p, encoding="utf-8").read().split("\n")
            cambiato = False
            for i, r in enumerate(righe):
                codice = r.split("#")[0] if not r.lstrip().startswith("##") else ""
                if not pat.search(codice):
                    continue
                rel = os.path.relpath(p, radice).replace(os.sep, "/")
                def sost(m):
                    return 'preload("res://tests/sonda_load.gd").da("%s:%d", ' % (rel, i + 1)
                nuovo, k = pat.subn(sost, codice)
                if k:
                    righe[i] = nuovo + r[len(codice):]
                    n_chiamate += k
                    cambiato = True
            if cambiato:
                open(p, "w", encoding="utf-8").write("\n".join(righe))
                n_file += 1
print("file", n_file, "chiamate", n_chiamate)
