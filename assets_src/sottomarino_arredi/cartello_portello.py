"""Il cartello a disegni dell'approdo del tunnel sottomarino: il portello col volantino e la freccia avanti
(niente scritte). Uso: python cartello_portello.py -> godot/assets/ambiente/sottomarino/cartello_portello.jpg"""
from PIL import Image, ImageDraw
import math, os

N = 512
img = Image.new("RGB", (N, N), (232, 236, 230))
d = ImageDraw.Draw(img)
blu = (22, 70, 120)
d.rounded_rectangle([10, 10, N - 11, N - 11], radius=40, outline=blu, width=22)
# il portello: la porta tonda con l'oblò e il volantino
cx, cy, R = N // 2, 300, 120
d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(70, 86, 96), outline=blu, width=14)
d.ellipse([cx - 44, cy - 92, cx + 44, cy - 4], fill=(120, 190, 220), outline=(40, 50, 56), width=8)
r2 = 52
wy = cy + 52
d.ellipse([cx - r2, wy - r2, cx + r2, wy + r2], outline=(200, 40, 30), width=10)
for k in range(4):
    a = math.pi / 4 + k * math.pi / 2
    d.line([cx, wy, cx + math.cos(a) * r2, wy + math.sin(a) * r2], fill=(200, 40, 30), width=9)
d.ellipse([cx - 10, wy - 10, cx + 10, wy + 10], fill=(200, 40, 30))
# la freccia avanti, sopra
d.polygon([(cx, 40), (cx - 62, 112), (cx - 22, 112), (cx - 22, 158), (cx + 22, 158), (cx + 22, 112), (cx + 62, 112)], fill=blu)
out = os.path.join(os.path.dirname(__file__), "../../godot/assets/ambiente/sottomarino/cartello_portello.jpg")
img.save(out, quality=90)
print(out)
