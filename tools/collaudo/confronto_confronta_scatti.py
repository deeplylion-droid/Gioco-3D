import sys,os,numpy as np
from PIL import Image
from scipy import ndimage
S=sys.argv[1]; a=f'{S}/ci/scatti_vecchio'; b=f'{S}/ci/scatti_nuovo'
res=[]
for f in sorted(os.listdir(a)):
    if not f.endswith('.jpg') or not os.path.exists(f'{b}/{f}'): continue
    x=np.asarray(Image.open(f'{a}/{f}').convert('L'),dtype=np.float32); y=np.asarray(Image.open(f'{b}/{f}').convert('L'),dtype=np.float32)
    d=ndimage.uniform_filter(np.abs(x-y),5)>25
    d=ndimage.binary_opening(d,iterations=2)
    res.append((d.mean(),f))
res.sort(reverse=True)
for m,f in res: 
    if m>0.003: print(f'{100*m:5.1f}% {f}')
print('coppie',len(res),'diverse >0.3%:',sum(1 for m,f in res if m>0.003))
