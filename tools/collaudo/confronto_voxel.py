# differenze di geometria fra due dump di geometria.gd: punti delle superfici a voxel di 2 cm
import json,sys,re,numpy as np
from scipy import ndimage
S=sys.argv[1]; nome=sys.argv[2] if len(sys.argv)>2 else 'geo_aperto'
V=0.02
def car(c):
    d=json.load(open(f'{S}/ci/{c}/{nome}.json')); t=np.fromfile(f'{S}/ci/{c}/{nome}.bin',dtype=np.float32).reshape(-1,3,3)
    return d['mesh'],t
def punti(t):
    # campiona ogni triangolo con una griglia baricentrica fitta abbastanza da avere punti ogni ~1 cm
    a,b,c=t[:,0],t[:,1],t[:,2]
    l=np.maximum(np.linalg.norm(b-a,axis=1),np.maximum(np.linalg.norm(c-a,axis=1),np.linalg.norm(c-b,axis=1)))
    k=np.clip(np.ceil(l/0.014),1,400).astype(int)
    out=[]
    for kk in np.unique(k):
        sel=k==kk
        u,v=np.meshgrid(np.arange(kk+1),np.arange(kk+1)); m=(u+v)<=kk
        u=u[m]/kk; v=v[m]/kk
        A,B,C=a[sel],b[sel],c[sel]
        p=A[:,None,:]+(B-A)[:,None,:]*u[None,:,None]+(C-A)[:,None,:]*v[None,:,None]
        out.append(p.reshape(-1,3))
    return np.concatenate(out)
def vox(c,visibili=True):
    mesh,t=car(c); idx=[]
    owner=np.empty(len(t),dtype=np.int32)
    for i,m in enumerate(mesh):
        owner[m['da']:m['da']+m['n']]=i
    keep=np.array([mesh[o]['visibile'] for o in owner])
    tt=t[keep]; ow=owner[keep]
    # punti con il proprietario
    a,b,cc=tt[:,0],tt[:,1],tt[:,2]
    P=[];O=[]
    l=np.maximum(np.linalg.norm(b-a,axis=1),np.maximum(np.linalg.norm(cc-a,axis=1),np.linalg.norm(cc-b,axis=1)))
    k=np.clip(np.ceil(l/0.014),1,400).astype(int)
    for kk in np.unique(k):
        sel=np.where(k==kk)[0]
        u,v=np.meshgrid(np.arange(kk+1),np.arange(kk+1)); m=(u+v)<=kk
        u=u[m]/kk; v=v[m]/kk
        passo=max(1,4000000//len(u))
        for s0 in range(0,len(sel),passo):
            ss=sel[s0:s0+passo]
            A,B,C=a[ss],b[ss],cc[ss]
            p=A[:,None,:]+(B-A)[:,None,:]*u[None,:,None]+(C-A)[:,None,:]*v[None,:,None]
            q=np.floor(p.reshape(-1,3)/V).astype(np.int32); o=np.repeat(ow[ss],len(u))
            kq=q[:,0].astype(np.int64)*10**12+(q[:,1].astype(np.int64)+50000)*10**6+(q[:,2].astype(np.int64)+500000)
            _,f=np.unique(kq,return_index=True)
            P.append(q[f]); O.append(o[f])
    P=np.concatenate(P); O=np.concatenate(O)
    key=P[:,0].astype(np.int64)*10**12+(P[:,1].astype(np.int64)+50000)*10**6+(P[:,2].astype(np.int64)+500000)
    key,first=np.unique(key,return_index=True)
    return mesh,key,P[first],O[first]
mv,kv,pv,ov=vox('vecchio'); mn,kn,pn,on=vox('nuovo')
def vicini(kA,PB):
    # voxel di A che non hanno un voxel di B entro 1 voxel (3x3x3)
    s=set()
    off=[(dx,dy,dz) for dx in (-1,0,1) for dy in (-1,0,1) for dz in (-1,0,1)]
    kb=None
    return
def manca(PA,OA,kB):
    sB=kB
    ok=np.zeros(len(PA),bool)
    for dx in (-1,0,1):
        for dy in (-1,0,1):
            for dz in (-1,0,1):
                q=(PA[:,0]+dx).astype(np.int64)*10**12+(PA[:,1]+dy+50000).astype(np.int64)*10**6+(PA[:,2]+dz+500000)
                ok|=np.isin(q,sB,assume_unique=False)
    return ~ok
for titolo,PA,OA,kB,mA in (('SPARITO (nel vecchio, non nel nuovo)',pv,ov,kn,mv),('COMPARSO (nel nuovo, non nel vecchio)',pn,on,kv,mn)):
    m=manca(PA,OA,kB)
    P=PA[m]; O=OA[m]
    print(titolo, m.sum(),'voxel')
    if m.sum()==0: continue
    # gruppi connessi per mesh
    risultati=[]
    for o in np.unique(O):
        Q=P[O==o]
        mn_=Q.min(0); g=np.zeros(Q.max(0)-mn_+3,bool); g[tuple((Q-mn_+1).T)]=True
        lab,nl=ndimage.label(g,structure=np.ones((3,3,3)))
        for l in range(1,nl+1):
            w=np.argwhere(lab==l)+mn_-1
            if len(w)<15: continue
            lo=w.min(0)*V; hi=(w.max(0)+1)*V
            risultati.append((len(w),re.sub(r'@[A-Za-z0-9]+@\d+','@',mA[o]['nodo']),lo,hi))
    risultati.sort(key=lambda r:-r[0])
    for n_,nodo,lo,hi in risultati[:60]:
        print(f'  {n_:6d} vox {nodo:55s} x {lo[0]:.2f}..{hi[0]:.2f} y {lo[1]:.2f}..{hi[1]:.2f} z {lo[2]:.2f}..{hi[2]:.2f}  (sala x {lo[0]-9.7:.2f}..{hi[0]-9.7:.2f} z {lo[2]+40.9:.2f}..{hi[2]+40.9:.2f})')
