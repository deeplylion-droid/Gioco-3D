import sys
from PIL import Image, ImageDraw
S=sys.argv[1]; out=sys.argv[2]; nomi=sys.argv[3:]
W,H=640,360; foglio=Image.new('RGB',(W*2+10,(H+22)*len(nomi)),'white'); d=ImageDraw.Draw(foglio)
for i,n in enumerate(nomi):
    y=i*(H+22)
    for j,c in enumerate(('vecchio','nuovo')):
        foglio.paste(Image.open(f'{S}/ci/scatti_{c}/{n}'),(j*(W+10),y+22))
        d.text((j*(W+10)+4,y+4),f'{n}  {"v0.3.8" if j==0 else "8371883e"}',fill='black')
foglio.save(out,quality=85)
