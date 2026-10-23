# Sezione di un tentacolo appoggiato: la pelle vera del tentacolo (vertici entro 4 cm da un piano verticale lungo il suo
# asse) e le superfici della scena sullo stesso piano; in rosso i vertici dalla parte di dietro di una superficie.
# Uso: python sezione_lei.py <registrazione> <geometria> <tag> <tl> <osso> <uscita.png> [titolo]
import json, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.spatial import cKDTree
R, GEO, TAG, TL, OSSO, PNG = sys.argv[1:7]; TIT = sys.argv[7] if len(sys.argv) > 7 else ''
TL = float(TL)
argv0 = sys.argv[0]; sys.argv = [argv0.replace('sezione_lei.py', 'analisi_lei.py'), R, GEO, '/dev/null']
src = open(sys.argv[0]).read(); exec(src[:src.index("res = {")])
fi = min((i for i, f in enumerate(fot) if f.get('tag', '') == TAG), key=lambda i: abs(fot[i]['tl'] - TL))
sk = pelle(fi); k = [i for i, s in enumerate(mesh) if s['nome'] == 'Medusa_Tentacoli'][0]; V = sk[k]
P = pose_all[fi, :, 3]; b = nomi.index(OSSO); pre = OSSO.rsplit('_', 1)[0]
catena = [i for i, n in enumerate(nomi) if n.startswith(pre + '_')]
a0 = P[catena[0]]; a1 = P[catena[-1]]
dirv = a1 - a0; dirv[1] = 0; dirv /= np.linalg.norm(dirv)
nrm = np.array([-dirv[2], 0, dirv[0]])  # normale del piano verticale lungo il tentacolo
c0 = P[b]
sel = np.abs((V - c0) @ nrm) < 0.04
sel &= np.abs((V - c0) @ dirv) < 0.6
Vs = V[sel]
dd, ii = albero.query(Vs, distance_upper_bound=0.06)
vic = np.isfinite(dd); sd = np.full(len(Vs), 1.0); sd[vic] = ((Vs[vic] - pts[ii[vic]]) * nor[ii[vic]]).sum(1)
dentro = sd < -0.005
ps = np.abs((pts - c0) @ nrm) < 0.01
ps &= np.abs((pts - c0) @ dirv) < 0.7
ps &= np.abs(pts[:, 1] - c0[1]) < 0.6
Q = pts[ps]
x = lambda p: (p - c0) @ dirv
asse = np.array([P[i] for i in catena])
SC = 600.0
xs = np.concatenate([x(Q), x(Vs)]); ys = np.concatenate([Q[:, 1], Vs[:, 1]])
x0, x1, y0, y1 = xs.min() - 0.05, xs.max() + 0.05, ys.min() - 0.05, ys.max() + 0.05
W = int((x1 - x0) * SC) + 40; H = int((y1 - y0) * SC) + 90
im = Image.new('RGB', (W, H), (250, 250, 250)); d = ImageDraw.Draw(im)
F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
px = lambda xx, yy: (20 + (xx - x0) * SC, 70 + (y1 - yy) * SC)
for xx, yy in zip(x(Q), Q[:, 1]):
    u, v = px(xx, yy); d.point((u, v), fill=(90, 90, 90))
for xx, yy in zip(x(Vs[~dentro]), Vs[~dentro, 1]):
    u, v = px(xx, yy); d.ellipse((u - 1.5, v - 1.5, u + 1.5, v + 1.5), fill=(190, 90, 190))
for xx, yy in zip(x(Vs[dentro]), Vs[dentro, 1]):
    u, v = px(xx, yy); d.ellipse((u - 2, v - 2, u + 2, v + 2), fill=(225, 30, 30))
pa = [px(xx, yy) for xx, yy in zip(x(asse), asse[:, 1])]
d.line(pa, fill=(0, 0, 0), width=2)
for q in pa: d.ellipse((q[0] - 3, q[1] - 3, q[0] + 3, q[1] + 3), fill=(0, 0, 0))
d.text((10, 8), TIT, fill=(0, 0, 0), font=F)
d.text((10, 30), "grigio: superfici della scena (sezione); viola: pelle del tentacolo; ROSSO: pelle dentro la superficie; nero: asse (ossa)", fill=(60, 60, 60), font=F)
# scala: 10 cm
u, v = px(x0 + 0.05, y0 + 0.03); d.line((u, v, u + 0.1 * SC, v), fill=(0, 0, 0), width=3); d.text((u, v + 4), "10 cm", fill=(0, 0, 0), font=F)
im.save(PNG)
print('vertici nella sezione', len(Vs), 'dentro', int(dentro.sum()), 'max %.1f cm' % (-sd[dentro].min() * 100 if dentro.any() else 0))
