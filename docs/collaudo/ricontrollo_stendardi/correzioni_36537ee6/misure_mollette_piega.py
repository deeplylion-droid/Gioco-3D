import sys; sys.path.insert(0,'/tmp/claude-0/-home-user-Gioco-3D/bf16885c-6f33-5efb-8329-4dc8709ca165/scratchpad/sag')
exec(open('geo3.py').read().split("for s in (1,2,3,4):")[0].replace("nodi('st_new.glb')","nodi('st_v3.glb')"))
from mathutils import Vector
def campioni(T,n=8):
    out=[]
    for a,b,c in T:
        for i in range(n+1):
            for j in range(n+1-i):
                u,v=i/n,j/n; out.append(a+(b-a)*u+(c-a)*v)
    return np.array(out)
for s,ax,lato in ((1,2,0),(2,0,2),(3,0,2),(4,2,0)):
    R=N['stendardo_%d_risvolto'%s]; tR=bvh(R); rod=N['stendardo_%d_bastone'%s]
    Bv=rod.reshape(-1,3); asse_y=(Bv[:,1].min()+Bv[:,1].max())/2; asse_p=(Bv[:,ax].min()+Bv[:,ax].max())/2
    mol=sorted(k for k in N if k.startswith('stendardo_%d_molletta'%s))
    ds=[]
    for k in mol:
        P=campioni(N[k])
        d=min(tR.find_nearest(Vector(p),0.05)[3] if tR.find_nearest(Vector(p),0.05)[0] is not None else 9 for p in P)
        ds.append(d)
    print('st%d: ganasce->piega (facce campionate), min per molletta in mm: %s'%(s,[round(x*1000,2) for x in ds]))
    # la piega chiude attorno al bastone lungo tutto il bastone: raggi dall'asse in 12 direzioni (non verso il basso) ogni 2 cm
    lo,hi=N['stendardo_%d'%s].reshape(-1,3)[:,lato].min(),N['stendardo_%d'%s].reshape(-1,3)[:,lato].max()
    mancano=0; tot=0
    for u in np.arange(lo+0.005,hi-0.005,0.02):
        for ang in np.radians(np.arange(-60,241,30)):   # da sotto-davanti, sopra, a sotto-dietro (0 = davanti, 90 = su)
            o=np.zeros(3); o[lato]=u; o[1]=asse_y; o[ax]=asse_p
            d=np.zeros(3); d[ax]=np.cos(ang); d[1]=np.sin(ang)
            h=tR.ray_cast(Vector(o),Vector(d),0.05); tot+=1
            if h[0] is None: mancano+=1
    print('   piega attorno al bastone: %d raggi su %d senza stoffa'%(mancano,tot))
