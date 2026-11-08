import sys
def l(f):
    d={}
    for r in open(f):
        p=r.split(); d[tuple(p[:4])]=(int(p[4]),int(p[5]))
    return d
a=l(sys.argv[1]); b=l(sys.argv[2])
com=set(a)&set(b)
print("coppie prima %d, dopo %d, in comune %d"%(len(a),len(b),len(com)))
for i,n in [(0,'barriere'),(1,'tutte le collisioni')]:
    nuovi=[k for k in com if b[k][i] and not a[k][i]]; tolti=[k for k in com if a[k][i] and not b[k][i]]
    print("%s: bloccate prima %d, dopo %d; nuove chiuse %d, nuove aperte %d"%(n,sum(a[k][i] for k in com),sum(b[k][i] for k in com),len(nuovi),len(tolti)))
    for k in sorted(nuovi)[:30]: print("  CHIUSA ORA", k)
    for k in sorted(tolti)[:10]: print("  aperta ora", k)
print("coppie solo prima %d, solo dopo %d (pavimento diventato acqua o il contrario)"%(len(set(a)-set(b)),len(set(b)-set(a))))
for k in sorted(set(a)-set(b))[:20]: print("  solo prima", k)
