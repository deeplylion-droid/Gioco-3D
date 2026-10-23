#!/usr/bin/env python3
"""Collaudo: spazio per la testa. Le mesh (diagonale sotto i 4 m) con un vertice a meno di 30 cm in pianta da
una cella dove si cammina e fra 0,5 e 1,95 m sopra di lei: cose che passano davanti alla faccia. Le celle
vengono da geometria.gd; un oggetto con la collisione ferma il giocatore prima, quindi i casi vanno guardati.
Uso (python del venv di Blender, serve scipy): testa.py <base> [prefissi,separati,da,virgola]
"""
import json,sys,math,numpy as np
from scipy.spatial import cKDTree
base=sys.argv[1]; pref=sys.argv[2].split(',') if len(sys.argv)>2 else ['']
R=0.3
d=json.load(open(base+'.json')); c=json.load(open(base+'_celle.json'))
tri=np.memmap(base+'.bin',dtype=np.float32,mode='r')
celle=np.array([x[:3] for x in c['celle']]); ordn=[x[3] for x in c['celle']]
kd=cKDTree(celle[:,[0,2]])
for m in d['mesh']:
    if not m['visibile'] or m['acqua']: continue
    if not any(m['nodo'].startswith(p) for p in pref): continue
    x,y,z,sx,sy,sz=m['box']
    if math.sqrt(sx*sx+sy*sy+sz*sz)>4: continue
    v=np.array(tri[m['da']*9:(m['da']+m['n'])*9]).reshape(-1,3)
    if len(v)==0: continue
    best=None
    for i,js in enumerate(kd.query_ball_point(v[:,[0,2]],R)):
        for j in js:
            h=v[i,1]-celle[j,1]
            if 0.5<h<1.95:
                # quanto dentro: distanza orizzontale
                dh=math.hypot(v[i,0]-celle[j,0],v[i,2]-celle[j,2])
                if best is None or dh<best[0]: best=(round(dh,2),round(h,2),list(np.round(celle[j],2)),ordn[j],list(np.round(v[i],2)))
    if best: print(m['nodo'],m['istanza'],best)
