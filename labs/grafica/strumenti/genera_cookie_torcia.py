"""Genera la texture del fascio (cookie) della torcia: grafica/texture/torcia_cookie.png.
Profilo di una torcia LED a riflettore, come si vede su un muro:
- punto caldo piccolo e pieno al centro;
- un anello chiaro e uno più scuro attorno (le imperfezioni del riflettore);
- corona di luce diffusa (spill) larga e debole, con il bordo che sfuma senza scalino;
- lievi irregolarità e polvere sulla lente, appena percettibili.
Godot legge la texture del proiettore come sRGB: il profilo è codificato con gamma 1/2,2.
Uso: /home/user/tools/blender-venv/bin/python strumenti/genera_cookie_torcia.py"""
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

N = 512
rng = np.random.default_rng(11)
y, x = np.mgrid[0:N, 0:N].astype(np.float32)
c = (N - 1) / 2
r = np.hypot(x - c, y - c) / c  # 0 al centro, 1 sul bordo del cono
ang = np.arctan2(y - c, x - c)

def gauss(centro, larghezza):
    return np.exp(-((r - centro) / larghezza) ** 2)

caldo = np.exp(-(r / 0.16) ** 2.2)                         # punto caldo
corpo = np.clip(1 - (r / 0.5) ** 3, 0, 1) * 0.6             # fascio principale
anello_chiaro = gauss(0.44, 0.03) * 0.18                    # bordo del riflettore
anello_scuro = 1 - gauss(0.52, 0.035) * 0.3                 # stacco tra fascio e corona
corona = np.clip(1 - r, 0, 1) ** 1.3 * 0.3                  # spill largo e debole
anellini = (gauss(0.62, 0.016) + gauss(0.74, 0.018)) * 0.03 # riflessi secondari tenui
v = (caldo * 0.45 + corpo + anello_chiaro + corona + anellini) * anello_scuro
# Irregolarità del riflettore (leggermente non rotondo) e polvere sulla lente.
v *= 1 + 0.04 * np.sin(ang * 6 + 0.7) * gauss(0.45, 0.12)
rumore = rng.normal(0, 1, (N // 16, N // 16)).astype(np.float32)
rumore = np.array(Image.fromarray(rumore).resize((N, N), Image.BICUBIC))
v *= 1 + 0.025 * rumore
v *= np.clip((1 - r) / 0.12, 0, 1) ** 1.5                   # bordo morbido, niente scalino
v = v / v.max()
v = np.clip(v, 0, 1) ** (1 / 2.2)
img = Image.fromarray((v * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.5))
out = Path(__file__).resolve().parent.parent / "grafica" / "texture" / "torcia_cookie.png"
img.convert("RGB").save(out)
print("scritto", out)
