import json, math, glob, sys, os
import numpy as np
from PIL import Image, ImageDraw
exec(open('/home/user/collaudo_log/ff21/magenta_portone.py').read().split("# il vano del portone")[0])
def box(xr, yr, zr):
    return [np.array([x, y, z]) for x in xr for y in yr for z in zr]
VEC = box((19.9, 20.3), (-0.5, 4.5), (-16.8, -13.2)); NUO = box((19.5, 20.6), (-1.0, 5.0), (-18.5, -11.5))
def rett(o, fw, up, b, marg):
    pr = [proietta(o, fw, up, c) for c in b]
    if any(p is None for p in pr): return None
    xs = [p[0] for p in pr]; ys = [p[1] for p in pr]
    return (min(xs) - marg, min(ys) - marg, max(xs) + marg, max(ys) + marg)
righe = []
for f in sorted(glob.glob(sys.argv[1] + '/cubo_discesa*.jpg')):
    nome = os.path.basename(f)[5:-4]; pt, dd = nome.rsplit('_', 1)
    o = punti[pt]; fw = np.array(dirs[dd], float); up = np.array([0, 1, 0.]) if abs(fw[1]) < 0.95 else np.array([1, 0, 0.])
    a = np.asarray(Image.open(f).convert('RGB')).astype(int)
    m = (a[..., 0] > 150) & (a[..., 2] > 150) & (a[..., 1] < 110) & (abs(a[..., 0] - a[..., 2]) < 60)
    if m.sum() == 0: continue
    rv = rett(o, fw, up, VEC, 4); rn = rett(o, fw, up, NUO, 10)
    ys, xs = np.nonzero(m)
    def dentro(r): return np.zeros(len(xs), bool) if r is None else (xs >= r[0]) & (xs <= r[2]) & (ys >= r[1]) & (ys <= r[3])
    dv = dentro(rv); dn = dentro(rn)
    righe.append((int((dn & ~dv).sum()), int(dv.sum()), int((~dn).sum()), nome, f, rv, rn))
n_fascia = sum(1 for r in righe if r[0] > 0)
print('scatti con magenta', len(righe), '; con magenta nella fascia aggiunta', n_fascia, '; fuori dal box nuovo', sum(r[2] for r in righe))
for r in sorted(righe, reverse=True)[:40]:
    if r[0] > 0: print('%-22s fascia %5d  vecchio %5d  fuori %d' % (r[3], r[0], r[1], r[2]))
# foglio: i 3 scatti con più magenta nella fascia, coi due box
sel = sorted(righe, reverse=True)[:3]
W2, H2 = 960, 540
im = Image.new('RGB', (W2 * 3, H2 + 40), (20, 20, 20)); dr = ImageDraw.Draw(im)
dr.text((6, 6), 'Discesa a sfondo magenta, torre da sola (la sala non c\'e): in verde il vano vecchio (x 19,9-20,3, y -0,5..4,5, z -16,8..-13,2, +4 px), in giallo quello nuovo (x 19,5-20,6, y -1..5, z -18,5..-11,5, +10 px)', fill=(255, 255, 255))
for i, r in enumerate(sel):
    a = Image.open(r[4]).convert('RGB'); d2 = ImageDraw.Draw(a)
    if r[5]: d2.rectangle(r[5], outline=(0, 255, 0), width=3)
    if r[6]: d2.rectangle(r[6], outline=(255, 230, 0), width=3)
    a = a.resize((W2, H2)); im.paste(a, (i * W2, 40)); dr.text((i * W2 + 6, 24), '%s: fascia %d px, vecchio %d px' % (r[3], r[0], r[1]), fill=(255, 255, 120))
im.save(sys.argv[2], quality=86)
