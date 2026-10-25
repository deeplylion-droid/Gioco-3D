import sys, os
from PIL import Image, ImageChops, ImageStat
nuovo, vecchio, uscita = sys.argv[1], sys.argv[2], sys.argv[3]
soglia = float(sys.argv[4]) if len(sys.argv) > 4 else 6.0
os.makedirs(uscita, exist_ok=True)
res = []
for f in sorted(os.listdir(nuovo)):
    if not f.endswith(".jpg"):
        continue
    v = os.path.join(vecchio, f)
    if not os.path.exists(v):
        res.append((999, f)); continue
    a = Image.open(os.path.join(nuovo, f)).convert("L").resize((160, 90))
    b = Image.open(v).convert("L").resize((160, 90))
    d = ImageStat.Stat(ImageChops.difference(a, b)).mean[0]
    res.append((d, f))
res.sort(reverse=True)
cambiati = [r for r in res if r[0] >= soglia]
print("scatti %d, confrontabili %d, cambiati (>= %.1f) %d" % (len(res), sum(1 for r in res if r[0] < 999), soglia, len(cambiati)))
for d, f in cambiati[:40]:
    print("  %6.1f %s" % (d, f))
    # affiancati: vecchio | nuovo
    n = Image.open(os.path.join(nuovo, f)).convert("RGB")
    if d < 999:
        o = Image.open(os.path.join(vecchio, f)).convert("RGB").resize(n.size)
        c = Image.new("RGB", (n.width * 2, n.height)); c.paste(o, (0, 0)); c.paste(n, (n.width, 0))
    else:
        c = n
    c.save(os.path.join(uscita, f), quality=85)
