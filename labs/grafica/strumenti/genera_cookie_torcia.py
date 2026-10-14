"""Genera la texture del fascio (cookie) della torcia: grafica/texture/torcia_cookie.png.
Profilo di una torcia a riflettore: punto centrale caldo, anello del riflettore,
alone esterno debole, piccole imperfezioni (graffi e polvere sulla lente).
Uso: /home/user/tools/blender-venv/bin/python strumenti/genera_cookie_torcia.py"""
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

N = 512
rng = np.random.default_rng(7)
y, x = np.mgrid[0:N, 0:N].astype(np.float32)
c = (N - 1) / 2
r = np.hypot(x - c, y - c) / c  # 0 al centro, 1 sul bordo
ang = np.arctan2(y - c, x - c)

hot = np.exp(-(r / 0.22) ** 2) * 0.3                     # punto caldo
corpo = np.clip(1 - (r / 0.6) ** 4, 0, 1) * 0.5            # fascio principale
anello = np.exp(-((r - 0.56) / 0.045) ** 2) * 0.12         # bordo del riflettore
alone = np.clip(1 - r, 0, 1) ** 0.8 * 0.45                 # luce diffusa esterna (spill)
v = hot + corpo + anello + alone
# piccole irregolarità radiali del riflettore
v *= 1 + 0.06 * np.sin(ang * 9 + 1.3) * np.exp(-((r - 0.58) / 0.2) ** 2)
# polvere e graffi sulla lente
rumore = rng.normal(0, 1, (N // 8, N // 8)).astype(np.float32)
rumore = np.array(Image.fromarray(rumore).resize((N, N), Image.BICUBIC))
v *= 1 + 0.05 * rumore
for _ in range(4):
    a = rng.uniform(0, np.pi); d = rng.uniform(-0.3, 0.3)
    dist = np.abs((x - c) / c * np.sin(a) - (y - c) / c * np.cos(a) - d)
    v *= 1 - 0.035 * np.exp(-(dist / 0.006) ** 2) * (r < 0.6)
v *= np.clip((1 - r) / 0.08, 0, 1)                          # bordo nero
# Godot legge la texture del proiettore come colore sRGB: la codifichiamo così
# che, una volta linearizzata, dia proprio il profilo voluto.
v = np.clip(v, 0, 1) ** (1 / 2.2)
img = Image.fromarray((v * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.2))
out = Path(__file__).resolve().parent.parent / "grafica" / "texture" / "torcia_cookie.png"
img.convert("RGB").save(out)
print("scritto", out)
