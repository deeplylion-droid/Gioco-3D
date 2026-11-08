import sys, collections
def leggi(f):
    d = {}
    for r in open(f):
        p = r.split()
        d[(p[0], int(p[1]))] = (float(p[2]), p[3], p[4:7])
    return d
a = leggi(sys.argv[1]); b = leggi(sys.argv[2])
print("raggi prima %d, dopo %d, in comune %d" % (len(a), len(b), len(set(a) & set(b))))
cnt = collections.Counter(); es = collections.defaultdict(list)
for k in sorted(set(a) & set(b)):
    da, ca, pos = a[k]; db, cb, _ = b[k]
    diff = (da < 0) != (db < 0) or (da >= 0 and abs(da - db) > 0.01) or ca != cb
    tipo = k[0].split('_')[0] + '_' + k[0].split('_')[-1]
    cnt[(tipo, 'tot')] += 1
    if diff:
        cnt[(tipo, 'diversi')] += 1
        verso = 'colpisce ora' if (da < 0 or db < da - 0.01) else ('colpisce più lontano' if db > da + 0.01 or db < 0 else 'altro collisore')
        cnt[(tipo, verso)] += 1
        cnt[(tipo, 'da %s a %s' % (ca, cb))] += 1
        if len(es[tipo]) < 8: es[tipo].append("%s dir %d: %.3f %s -> %.3f %s" % (k[0], k[1], da, ca, db, cb))
for k in sorted(cnt): print(k, cnt[k])
for t in es:
    print("esempi", t); [print("  ", e) for e in es[t]]
