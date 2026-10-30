"""uso: diff_ab.py <dir_branch> <uscita>: per ogni vista, effetto = |codice - come_0316|, rumore = |codice - di_nuovo|"""
import sys, os, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFont
def carica(p): return np.asarray(Image.open(p).convert("RGB")).astype(np.int16)
def misura(a, b, soglia=8):
    d = np.abs(a - b).max(axis=2); m = d > soglia
    bb = None
    if m.any():
        ys, xs = np.nonzero(m); bb = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    return float(np.abs(a - b).mean()), m.mean() * 100.0, int(d.max()), bb, d
br, usc = sys.argv[1], sys.argv[2]
os.makedirs(usc, exist_ok=True)
f = ImageFont.load_default(size=22)
for pb in sorted(glob.glob(os.path.join(br, "*_come_0316.png"))):
    nome = os.path.basename(pb)[:-len("_come_0316.png")]
    a = carica(os.path.join(br, nome + ".png")); b = carica(pb)
    e = misura(a, b)
    riga = "%-30s effetto: media %.2f, %6.2f%% px >8, max %3d, zona %s" % (nome, e[0], e[1], e[2], e[3])
    pn = os.path.join(br, nome + "_di_nuovo.png")
    if os.path.exists(pn):
        r = misura(a, carica(pn)); riga += " | rumore: media %.2f, %.2f%% px, max %d" % (r[0], r[1], r[2])
    print(riga)
    if e[1] > 0.05:
        d = np.clip(e[4].astype(np.float32) * 4.0, 0, 255).astype(np.uint8)
        im = Image.new("RGB", (1920, 400))
        for i, x in enumerate([b, a]):
            im.paste(Image.fromarray(x.astype(np.uint8)).resize((640, 360)), (i * 640, 40))
        im.paste(Image.fromarray(d).convert("RGB").resize((640, 360)), (1280, 40))
        dr = ImageDraw.Draw(im)
        for i, t in enumerate(["come la 0.3.16", "branch", "differenza x4"]):
            dr.text((i * 640 + 10, 8), "%s - %s" % (nome, t), fill=(255, 255, 255), font=f)
        im.save(os.path.join(usc, "diff_%s.jpg" % nome), quality=88)
