import math, collections
righe=[l.strip().split('|') for l in open('docs/collaudo/0321/traccia_strada/traccia.txt') if l.strip()]
pts=[(t,float(x),float(y),float(z)) for t,x,y,z,_ in righe]
ZONA={
 'partenza':'I','dal corridoio del risveglio agli spogliatoi':'I','dagli spogliatoi dentro lo stanzino':'I',
 'dallo stanzino al lavapiedi, fino al tornello':'I','il tornello':'I',
 'sotto la saracinesca, nella sala, fino alla statua':'S1',
 'la camera delle onde: le paratie si aprono al passaggio, il tunnel fino alla sala pompe':'T',
 'nella sala pompe fino alla porta del ponte inferiore':'T','dalla porta del ponte su per le due rampe del raccordo':'T',
 'il corridoio C2 fino alla porta di servizio':'T',
 'dalla porta di servizio giù per la scala fino al capannone':'R',"nel capannone fino all'imbarco":'R',
 "dall'approdo, porta di servizio, zona del personale, infermeria, porta nord":'R',
 'nella stanza delle pozze, sulla passerella fino alla porta stagna':'R','su per la scala di servizio fino alla porta di C3':'R',
 'da C3 al magazzino dei gonfiabili':'C','sotto la serranda, nella sala':'S2',
 "dalla serranda lungo la scia fino all'area bimbi":'S2',"dall'area bimbi lungo la spiaggia fino al portone":'S2',
}
liste=collections.defaultdict(list)
n=0
for i,(t,x,y,z) in enumerate(pts):
    zona=ZONA.get(t)
    if zona is None: continue
    a=pts[max(i-1,0)]; b=pts[min(i+1,len(pts)-1)]
    dx,dz=b[1]-a[1],b[3]-a[3]
    if abs(dx)+abs(dz)<0.1: dx,dz=0,-1
    h=math.degrees(math.atan2(-dx,-dz))
    barca = t.startswith('nel capannone') and y < -5.55
    occhi = 1.6   # anche in barca: FiumeLento mette i piedi sulla ciambella e il giocatore resta in piedi (stand_eye_height)
    n+=1
    for nome,d in (('avanti',0),('sinistra',90),('destra',-90),('dietro',180)):
        liste[zona].append(f"{zona}_{n:03d}_{nome} {x:.2f} {y+occhi:.2f} {z:.2f} {((h+d+180)%360)-180:.1f} -12")
for k,v in liste.items():
    open(f'docs/collaudo/0321/traccia_strada/lista_{k}.txt','w').write('\n'.join(v)+'\n')
    print(k,len(v)//4,'punti')
