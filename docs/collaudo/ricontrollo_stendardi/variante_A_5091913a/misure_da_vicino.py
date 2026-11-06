import sys; sys.path.insert(0,'/tmp/claude-0/-home-user-Gioco-3D/bf16885c-6f33-5efb-8329-4dc8709ca165/scratchpad/sag')
exec(open('geo3.py').read().split("for s in (1,2,3,4):")[0].replace("nodi('st_new.glb')","nodi(sys.argv[1])"))
from mathutils import Vector
def campioni(T,n=6):
    out=[]
    for a,b,c in T:
        for i in range(n+1):
            for j in range(n+1-i):
                u,v=i/n,j/n; out.append(a+(b-a)*u+(c-a)*v)
    return np.array(out)
for s in (1,2,3,4):
    C=N['stendardo_%d'%s]; R=N['stendardo_%d_risvolto'%s]; rod=N['stendardo_%d_bastone'%s]
    Cv=C.reshape(-1,3); Rv=R.reshape(-1,3); Bv=rod.reshape(-1,3)
    lungo_x=(Bv[:,0].max()-Bv[:,0].min())>1
    lato=0 if lungo_x else 2; ax=2 if lungo_x else 0
    corde=sorted(k for k in N if k.startswith('stendardo_%d_corda_'%s))
    mol=sorted((k for k in N if k.startswith('stendardo_%d_molletta'%s)), key=lambda k:int(k.split('molletta')[1]))
    tR=bvh(R); tC=bvh(C); tB=bvh(rod)
    print('=== stendardo %d: %d corde, %d mollette; stoffa %.2f..%.2f, bastone %.2f..%.2f (lato), fondo %.3f'%(s,len(corde),len(mol),Cv[:,lato].min(),Cv[:,lato].max(),Bv[:,lato].min(),Bv[:,lato].max(),Cv[:,1].min()))
    # cucitura cima-piega: ogni vertice della riga in cima della stoffa sul bordo della piega
    ytop=Cv[:,1].max(); top=Cv[Cv[:,1]>ytop-1e-4]
    d=[tR.find_nearest(Vector(p),0.5)[3] for p in top]
    print('   cima della stoffa: %d vertici a y %.4f, fondo piega %.4f, distanza max dalla piega %.2f mm'%(len(top),ytop,Rv[:,1].min(),max(d)*1000))
    # piega attorno al bastone, ogni 2 cm
    asse_y=(Bv[:,1].min()+Bv[:,1].max())/2; asse_p=(Bv[:,ax].min()+Bv[:,ax].max())/2
    manca=0; tot=0
    for u in np.arange(Cv[:,lato].min()+0.005,Cv[:,lato].max()-0.005,0.02):
        for ang in np.radians(np.arange(-60,241,30)):
            o=np.zeros(3); o[lato]=u; o[1]=asse_y; o[ax]=asse_p
            dd=np.zeros(3); dd[ax]=np.cos(ang); dd[1]=np.sin(ang)
            tot+=1
            if tR.ray_cast(Vector(o),Vector(dd),0.05)[0] is None: manca+=1
    print('   piega attorno al bastone: %d raggi su %d senza stoffa'%(manca,tot))
    # intersezioni
    ov=lambda A,B: len(bvh(A).overlap(bvh(B)))
    print('   stoffa x bastone %d, piega x bastone %d, stoffa x piega (oltre la cucitura) %d'%(ov(C,rod),ov(R,rod),ov(C,R)))
    for c in corde:
        Cc=N[c]
        print('   %s: x bastone %d (giri), x stoffa %d, x piega %d, x mollette %d; più vicina molletta %.1f cm; cima %.3f (trave -6.600)'%(c,ov(Cc,rod),ov(Cc,C),ov(Cc,R),sum(ov(Cc,N[m]) for m in mol),min(gap(Cc,N[m]) for m in mol)*100,Cc.reshape(-1,3)[:,1].max()))
    g_min=9; o_tot=0
    for m in mol:
        M=N[m]; o_tot+=ov(M,rod)+ov(M,C)+ov(M,R)
        P=campioni(M)
        g=min((tR.find_nearest(Vector(p),0.05)[3] if tR.find_nearest(Vector(p),0.05)[0] is not None else 9) for p in P)
        g_min=min(g_min,g)
    print('   mollette: intersezioni con bastone/stoffa/piega %d; ganasce-piega min %.2f mm'%(o_tot,g_min*1000))
    # capi del bastone oltre le corde
    xs=[N[c].reshape(-1,3) for c in corde]
    pos=[float(np.median(V[V[:,1]<V[:,1].min()+0.06][:,lato])) for V in xs]
    print('   corde al bastone in %s; capi del bastone %.2f e %.2f'%([round(p,2) for p in sorted(pos)],Bv[:,lato].min(),Bv[:,lato].max()))
