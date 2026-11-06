import sys; sys.path.insert(0,'/tmp/claude-0/-home-user-Gioco-3D/bf16885c-6f33-5efb-8329-4dc8709ca165/scratchpad/sag')
exec(open('geo3.py').read().split("for s in (1,2,3,4):")[0].replace("nodi('st_new.glb')","nodi('st_A3.glb')"))
from mathutils import Vector
O=nodi('st_A2.glb')
# 1) il resto non è cambiato
diversi=[k for k in N if not k.split('_corda_')[0]==k or True]
cambiati=[]
for k in sorted(N):
    if k not in O: cambiati.append(k+' (nuovo)'); continue
    if N[k].shape!=O[k].shape or not np.allclose(N[k],O[k],atol=1e-5): cambiati.append(k)
print('pezzi cambiati da 5091913a:', cambiati)
for k in O:
    if k not in N: print('tolto', k)
# 2) per ogni corda: pezzi, distanza da bastone e piega, intersezioni
for s in (1,2,3,4):
    R=N['stendardo_%d_risvolto'%s]; rod=N['stendardo_%d_bastone'%s]; C=N['stendardo_%d'%s]
    tR=bvh(R); tB=bvh(rod); tC=bvh(C)
    Bv=rod.reshape(-1,3); lungo_x=(Bv[:,0].max()-Bv[:,0].min())>1; lato=0 if lungo_x else 2; ax=2 if lungo_x else 0
    asse_y=(Bv[:,1].min()+Bv[:,1].max())/2; asse_p=(Bv[:,ax].min()+Bv[:,ax].max())/2
    for c in sorted(k for k in N if k.startswith('stendardo_%d_corda_'%s)):
        Cc=N[c]; comps=componenti(Cc)
        vic=[]
        for P in comps:
            V=P.reshape(-1,3)
            d=np.hypot(V[:,1]-asse_y,V[:,ax]-asse_p)
            if d.min()<0.06 and V[:,1].min()<asse_y+0.05:
                dB=min(tB.find_nearest(Vector(v),0.1)[3] if tB.find_nearest(Vector(v),0.1)[0] is not None else 9 for v in V)
                dR=min(tR.find_nearest(Vector(v),0.1)[3] if tR.find_nearest(Vector(v),0.1)[0] is not None else 9 for v in V)
                oB=len(bvh(P).overlap(tB)); oR=len(bvh(P).overlap(tR)); oC=len(bvh(P).overlap(tC))
                vic.append((round(float(V[:,lato].mean()),3),round(float(V[:,1].min()-asse_y)*100,1),round(float(V[:,1].max()-asse_y)*100,1),len(P),round(dB*1000,1),round(dR*1000,1),oB,oR,oC))
        print('st%d %s: pezzi vicino al bastone (lato medio, y min e max dall\'asse in cm, tri, dist. bastone mm, dist. piega mm, x bastone, x piega, x stoffa):'%(s,c))
        for x in sorted(vic, key=lambda t:(t[1])): print('     ',x)
    # i raggi senza stoffa: dove sono
    manca=[]
    for u in np.arange(C.reshape(-1,3)[:,lato].min()+0.005,C.reshape(-1,3)[:,lato].max()-0.005,0.02):
        for ang in np.arange(-60,241,30):
            o=np.zeros(3); o[lato]=u; o[1]=asse_y; o[ax]=asse_p
            dd=np.zeros(3); dd[ax]=np.cos(np.radians(ang)); dd[1]=np.sin(np.radians(ang))
            if tR.ray_cast(Vector(o),Vector(dd),0.05)[0] is None: manca.append((round(float(u),2),int(ang)))
    print('   st%d raggi senza stoffa (lato, angolo; -90 = in giù):'%s, manca)
