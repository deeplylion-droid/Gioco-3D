"""Texture di rumore ripetibile (si ripete senza giunte) per la schiuma del geyser: rumore bianco filtrato in
frequenza, a più scale, normalizzato. Uso: /home/user/tools/blender-venv/bin/python assets_src/geyser/rumore.py"""
import os
import numpy as np
from PIL import Image

N = 512
rng = np.random.default_rng(7)
fx = np.fft.fftfreq(N)[:, None]; fy = np.fft.fftfreq(N)[None, :]
f = np.sqrt(fx ** 2 + fy ** 2) + 1e-6
img = np.zeros((N, N))
for taglio, peso in ((0.02, 0.5), (0.06, 0.3), (0.15, 0.2)):
    spettro = np.fft.fft2(rng.standard_normal((N, N))) * np.exp(-(f / taglio) ** 2)
    x = np.real(np.fft.ifft2(spettro))
    img += peso * (x - x.mean()) / x.std()
img = (img - img.min()) / (img.max() - img.min())
out = os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'proposte', 'geyser', 'rumore_schiuma.png')
Image.fromarray((img * 255).astype(np.uint8)).save(out)
print('salvato', os.path.abspath(out))
