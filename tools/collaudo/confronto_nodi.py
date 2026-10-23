import json,sys,re
S=sys.argv[1]; st=sys.argv[2]
v=json.load(open(f'{S}/ci/vecchio/{st}_nodi.json')); n=json.load(open(f'{S}/ci/nuovo/{st}_nodi.json'))
def norm(k): return re.sub(r'@[A-Za-z0-9]+@\d+','@',k)
v={norm(k):e for k,e in v.items()}; n={norm(k):e for k,e in n.items()}
def dist(a,b): return max(abs(x-y) for x,y in zip(a,b))
tolti=sorted(set(v)-set(n)); nuovi=sorted(set(n)-set(v))
print('TOLTI',len(tolti))
for k in tolti: print('  -',k,v[k]['classe'],v[k]['pos'],v[k].get('box',''))
print('NUOVI',len(nuovi))
for k in nuovi: print('  +',k,n[k]['classe'],n[k]['pos'],n[k].get('box',''),n[k].get('forma',''))
print('CAMBIATI')
for k in sorted(set(v)&set(n)):
    a,b=v[k],n[k]; dif=[]
    for f in sorted(set(a)|set(b)):
        x,y=a.get(f),b.get(f)
        if x==y: continue
        if f in('pos','scala','box') and x and y and dist(x,y)<0.003: continue
        if f=='rot' and x and y and dist(x,y)<0.3: continue
        if f in('pos','rot','scala','box') and x and y: dif.append(f'{f} {x}->{y} (d {dist(x,y):.3f})')
        else: dif.append(f'{f} {x}->{y}')
    if dif: print('  *',k,a['classe'],'|','; '.join(dif))
