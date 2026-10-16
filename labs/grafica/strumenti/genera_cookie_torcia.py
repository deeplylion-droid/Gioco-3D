"""Genera la texture del fascio (cookie) della torcia: grafica/texture/torcia_cookie.png.
Profilo di una torcia LED a riflettore, come si vede su un muro:
- punto caldo largo e morbido (v2: l'utente la voleva più ampia, meno concentrata al centro;
  la v1 stretta è in strumenti/torcia_cookie_v1_stretto.png);
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

caldo = np.exp(-(r / 0.34) ** 2.0)                         # punto caldo largo
corpo = np.clip(1 - (r / 0.7) ** 4, 0, 1) * 0.75            # fascio principale ampio e piatto
anello_chiaro = gauss(0.64, 0.035) * 0.14                   # bordo del riflettore
anello_scuro = 1 - gauss(0.72, 0.04) * 0.25                 # stacco tra fascio e corona
corona = np.clip(1 - r, 0, 1) ** 1.1 * 0.35                 # spill largo
anellini = (gauss(0.80, 0.016) + gauss(0.88, 0.018)) * 0.03 # riflessi secondari tenui
v = (caldo * 0.25 + corpo + anello_chiaro + corona + anellini) * anello_scuro
# Irregolarità del riflettore (leggermente non rotondo) e polvere sulla lente.
v *= 1 + 0.04 * np.sin(ang * 6 + 0.7) * gauss(0.65, 0.12)
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
