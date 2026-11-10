"""Confronta due elenchi di nodi di sonda_nodi_tunnel.gd. Uso: confronta_nodi.py A B [rumore1 rumore2 ...]
Le coppie 'rumore' (due giri della stessa versione) dicono quali (nodo, proprietà) cambiano da sole: si contano a parte."""
import sys, collections, re
def gruppo(p): return re.sub(r'/\d+/', '/*/', p)
def leggi(f):
    righe = [r for r in open(f).read().split('\n') if r]
    out = []
    for r in righe:
        t = r.split(' ')
        props = {}
        for x in t[2:]:
            if '=' in x:
                k, v = x.split('=', 1); props[k] = v
            elif props:
                props[k] += ' ' + x
        out.append((t[0], t[1], props))
    return out
def diff(A, B):
    if [a[:2] for a in A] != [b[:2] for b in B]:
        ca = collections.Counter(a[:2] for a in A); cb = collections.Counter(b[:2] for b in B)
        return None, (ca - cb, cb - ca)
    out = []
    for a, b in zip(A, B):
        k = [p for p in set(a[2]) | set(b[2]) if a[2].get(p) != b[2].get(p)]
        if k: out.append((a[0], a[1], k, a, b))
    return out, None
A, B = leggi(sys.argv[1]), leggi(sys.argv[2])
rumore = set()
for i in range(3, len(sys.argv) - 1, 2):
    d, _ = diff(leggi(sys.argv[i]), leggi(sys.argv[i + 1]))
    for x in d or []:
        for p in x[2]: rumore.add((x[0], gruppo(p)))
d, strutt = diff(A, B)
print('CONFRONTO %s / %s: nodi %d / %d' % (sys.argv[1].split('/')[-1], sys.argv[2].split('/')[-1], len(A), len(B)))
if d is None:
    solo_a, solo_b = strutt
    print('  NODI DIVERSI: solo nel primo %d, solo nel secondo %d' % (sum(solo_a.values()), sum(solo_b.values())))
    for k, v in list(solo_a.items())[:15]: print('    solo nel primo', v, k)
    for k, v in list(solo_b.items())[:15]: print('    solo nel secondo', v, k)
    sys.exit(0)
veri = collections.Counter(); di_rumore = collections.Counter(); esempi = []
for path, cls, k, a, b in d:
    for p in k:
        if (path, gruppo(p)) in rumore: di_rumore[gruppo(p)] += 1
        else:
            veri[gruppo(p)] += 1
            if len(esempi) < 25: esempi.append((path, cls, p, a[2].get(p, '-')[:160], b[2].get(p, '-')[:160]))
print('  stessi nodi, stesso ordine; proprietà diverse: %d (più %d che cambiano da sole fra due giri: %s)' % (sum(veri.values()), sum(di_rumore.values()), dict(di_rumore)))
for p, n in veri.most_common(20): print('    %-30s %d nodi' % (p, n))
for e in esempi: print('    %s %s %s:\n       %s\n       %s' % e)
