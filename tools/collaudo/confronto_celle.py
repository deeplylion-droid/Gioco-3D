import json,sys
from collections import defaultdict
st=sys.argv[1]; S=sys.argv[2]
def car(p):
    d=json.load(open(p)); return {(round(c[0],1),round(c[2],1)):c[1] for c in d['celle']}, d['checkpoint']
v,cpv=car(f'{S}/ci/vecchio/{st}_celle.json'); n,cpn=car(f'{S}/ci/nuovo/{st}_celle.json')
print('vecchio',len(v),'nuovo',len(n))
for nome,a,b in (('PERSE',v,n),('NUOVE',n,v)):
    s=set(a)-set(b)
    # gruppi connessi
    seen=set(); gr=[]
    for c in s:
        if c in seen: continue
        st_=[c]; seen.add(c); g=[]
        while st_:
            x=st_.pop(); g.append(x)
            for d in ((0.1,0),(-0.1,0),(0,0.1),(0,-0.1)):
                y=(round(x[0]+d[0],1),round(x[1]+d[1],1))
                if y in s and y not in seen: seen.add(y); st_.append(y)
        gr.append(g)
    gr.sort(key=len,reverse=True)
    print(nome,len(s))
    for g in gr[:25]:
        xs=[c[0] for c in g]; zs=[c[1] for c in g]; ys=[a[c] for c in g]
        if len(g)<3: continue
        print(f'  {len(g):5d} celle  x {min(xs):.1f}..{max(xs):.1f}  z {min(zs):.1f}..{max(zs):.1f}  y {min(ys):.2f}..{max(ys):.2f}   (sala: x {min(xs)-9.7:.1f}..{max(xs)-9.7:.1f} z {min(zs)+40.9:.1f}..{max(zs)+40.9:.1f})')
