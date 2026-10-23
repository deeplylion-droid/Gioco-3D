import json,sys
S=sys.argv[1]; st=sys.argv[2]
for c in ('vecchio','nuovo'):
    d=json.load(open(f'{S}/ci/{c}/{st}_celle.json'))
    cel={}
    for x,y,z,o in d['celle']: cel.setdefault((round(x*10),round(z*10)),[]).append(y)
    comp={}; n=0
    for k in cel:
        for y in cel[k]:
            if (k,y) in comp: continue
            n+=1; pila=[(k,y)]; comp[(k,y)]=n
            while pila:
                (a,b),yy=pila.pop()
                for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
                    k2=(a+dx,b+dz)
                    for y2 in cel.get(k2,[]):
                        if abs(y2-yy)<=0.32 and (k2,y2) not in comp:
                            comp[(k2,y2)]=n; pila.append((k2,y2))
    from collections import Counter
    cnt=Counter(comp.values())
    print(c, 'zone separate:', len(cnt), 'grandezze', cnt.most_common(8))
    for cp in d['checkpoint']:
        x,y,z=cp['pos']; best=None
        for (k,yy),v in comp.items():
            dd=(k[0]/10-x)**2+(k[1]/10-z)**2
            if abs(yy-y)<0.6 and (best is None or dd<best[0]): best=(dd,v)
        print('   ',cp['nodo'].split('/')[-1], 'zona', best[1] if best else None)
