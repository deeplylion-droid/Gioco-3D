"""Toglie la carta bianca dal disegno a pastello (il decal va dritto sulle piastrelle del muro, accordo del 28 ottobre):
l'alfa viene da quanto un punto è diverso dalla carta (più scuro o più colorato), così fra i tratti di cera resta il
muro, come un disegno fatto col pastello sulle piastrelle. Uso: python3 scontorna.py <disegno.png> -> disegno_piscina.png
in godot/assets/models/enigma_giocattoli/ (1200 x 900)."""
import os, sys
import numpy as np
from PIL import Image

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', '..', 'godot', 'assets', 'models', 'enigma_giocattoli', 'disegno_piscina.png')
im = Image.open(sys.argv[1]).convert('RGB').resize((1200, 900), Image.LANCZOS)
a = np.asarray(im).astype(np.float32) / 255
carta = np.percentile(a.reshape(-1, 3), 97, axis=0)          # il bianco della carta
scuro = np.clip((carta - a).max(axis=2), 0, 1)
sat = a.max(axis=2) - a.min(axis=2)
d = np.maximum(scuro, sat * 0.9)
alfa = np.clip((d - 0.06) / 0.22, 0, 1)
alfa = alfa * alfa * (3 - 2 * alfa)
# il colore dei punti semitrasparenti: si toglie il bianco della carta che c'era sotto
rgb = np.clip((a - carta * (1 - alfa[..., None])) / np.maximum(alfa[..., None], 0.05), 0, 1)
rgb = np.where(alfa[..., None] > 0.05, rgb, a)
Image.fromarray((np.dstack([rgb, alfa]) * 255).astype(np.uint8), 'RGBA').save(OUT, optimize=True)
print(OUT, 'alfa media %.2f' % alfa.mean())
