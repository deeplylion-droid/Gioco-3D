#!/usr/bin/env python3
"""Collaudo: che cosa c'è sotto ogni vertice di una mesh (per nastri, scie, tappeti che devono stare
appoggiati). Per ogni vertice cerca la superficie più vicina sotto, fino a 50 cm, e conta i vertici
appoggiati (<2 cm), staccati (2-10 cm, 10 cm-1 m) e sopra il vuoto.
Uso: sotto.py <base di geometria.gd> <fine del percorso del nodo, per esempio /Nastro>
"""
import json,sys,numpy as np
base,nome=sys.argv[1],sys.argv[2]
d=json.load(open(base+'.json')); tri=np.memmap(base+'.bin',dtype=np.float32,mode='r')
m=[x for x in d['mesh'] if x['nodo'].endswith(nome)][0]
V=np.array(tri[m['da']*9:(m['da']+m['n'])*9]).reshape(-1,3)
V=np.unique(np.round(V,3),axis=0)
lo=V.min(0)-0.5; hi=V.max(0)+0.5
T=[]
for x in d['mesh']:
    if x is m or not x['visibile']: continue
    bx,by,bz,sx,sy,sz=x['box']
    if bx>hi[0] or bx+sx<lo[0] or bz>hi[2] or bz+sz<lo[2] or by>hi[1] or by+sy<lo[1]: continue
    t=np.array(tri[x['da']*9:(x['da']+x['n'])*9]).reshape(-1,3,3)
    k=(t[:,:,0].max(1)>=lo[0])&(t[:,:,0].min(1)<=hi[0])&(t[:,:,2].max(1)>=lo[2])&(t[:,:,2].min(1)<=hi[2])&(t[:,:,1].min(1)<=hi[1])&(t[:,:,1].max(1)>=lo[1])
    T.append((x['nodo'],t[k]))
gaps=[]
for p in V:
    best=None
    for n,t in T:
        a,b,c=t[:,0],t[:,1],t[:,2]
        # proiezione xz
        v0=c[:,[0,2]]-a[:,[0,2]]; v1=b[:,[0,2]]-a[:,[0,2]]; v2=p[[0,2]]-a[:,[0,2]]
        d00=(v0*v0).sum(1);d01=(v0*v1).sum(1);d11=(v1*v1).sum(1);d20=(v2*v0).sum(1);d21=(v2*v1).sum(1)
        den=d00*d11-d01*d01; ok=np.abs(den)>1e-12
        u=np.where(ok,(d11*d20-d01*d21)/np.where(ok,den,1),-1); v=np.where(ok,(d00*d21-d01*d20)/np.where(ok,den,1),-1)
        ins=ok&(u>=0)&(v>=0)&(u+v<=1)
        if not ins.any(): continue
        y=a[ins,1]+u[ins]*(c[ins,1]-a[ins,1])+v[ins]*(b[ins,1]-a[ins,1])
        h=p[1]-y; h=h[h>-0.05]
        if len(h): 
            hm=h.min()
            if best is None or hm<best[0]: best=(hm,n)
    gaps.append((best[0] if best else 99, best[1] if best else None, p))
g=np.array([x[0] for x in gaps])
print(len(V),'vertici; sopra di: <2cm',(g<0.02).sum(),' 2-10cm',((g>=0.02)&(g<0.1)).sum(),' 10cm-1m',((g>=0.1)&(g<1)).sum(),' >1m o vuoto',(g>=1).sum())
for h,n,p in sorted(gaps,key=lambda x:-x[0])[:8]: print(round(h,2),n,np.round(p,2))
