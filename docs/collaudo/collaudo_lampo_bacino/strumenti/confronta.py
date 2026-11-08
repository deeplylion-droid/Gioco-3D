"""Confronta gli scatti dell'inseguimento dopo la correzione con quelli della base, nello stesso istante."""
import sys, os
import numpy as np
from PIL import Image
a_dir, b_dir = sys.argv[1], sys.argv[2]
for f in sorted(os.listdir(a_dir)):
    pb = os.path.join(b_dir, f)
    if not f.endswith('.png') or not os.path.exists(pb):
        continue
    A = np.asarray(Image.open(os.path.join(a_dir, f)).convert('RGB')).astype(int)
    B = np.asarray(Image.open(pb).convert('RGB')).astype(int)
    d = np.abs(A - B)
    rosa = lambda X: ((X[..., 0] + X[..., 2]) / 2 - X[..., 1]).mean()
    print('%s: differenza media %.3f, massima %d, pixel diversi oltre 8: %d su %d; rosa medio correzione %.3f, base %.3f' % (
        f, d.mean(), d.max(), (d.max(-1) > 8).sum(), d.shape[0] * d.shape[1], rosa(A), rosa(B)))
