#!/usr/bin/env python3
"""Crea la texture a scacchi bianco/blu del bordo della vasca bimbi (come nello storyboard S09/S12)
ricolorando le piastrelle CC0 "Tiles133B" (ambientCG) una si' e una no. Le normal map e la
rugosita' restano quelle originali (piastrelle_muro_*).
Uso: /home/user/tools/blender-venv/bin/python labs/acqua/tools/genera_piastrelle_scacchi.py
"""
import os
import numpy as np
from PIL import Image

D = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "demo", "textures"))
a = np.array(Image.open(os.path.join(D, "piastrelle_muro_albedo.jpg")).convert("RGB")).astype(np.float32) / 255.0
n = a.shape[0]
cell = n / 12.0
ys, xs = np.mgrid[0:n, 0:n]
ci = np.floor((xs - 6) / cell).astype(int)
cj = np.floor((ys - 1) / cell).astype(int)
blue = ((ci + cj) % 2 == 1)
# blu piscina anni '90, un po' sbiadito e sporco
tint = np.array([0.2, 0.33, 0.55], np.float32)
lum = a.mean(axis=2, keepdims=True)
blue_col = np.clip(lum * tint * 1.05, 0, 1)
out = np.where(blue[..., None], blue_col, a * np.array([0.98, 0.97, 0.93], np.float32))
# le fughe restano grigie
grout = lum < 0.45
out = np.where(grout, a * 0.9, out)
Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(D, "piastrelle_scacchi_albedo.jpg"), quality=90)
print("ok")
