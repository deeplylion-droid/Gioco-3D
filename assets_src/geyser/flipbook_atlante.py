"""Mette insieme i fotogrammi di flipbook.py in due atlanti per il gioco (griglia COLONNE x righe, il primo in alto a
sinistra): godot/proposte/geyser/flipbook_colore.png (RGBA) e flipbook_normali.png (normali viste dalla camera,
x a destra, y in alto, z verso chi guarda: in Blender la z della camera è al contrario e qui si gira).
Uso: /home/user/tools/blender-venv/bin/python assets_src/geyser/flipbook_atlante.py <cartella dei fotogrammi>"""
import glob, os, sys
import numpy as np
from PIL import Image

COLONNE = 10
CART = sys.argv[1]
USCITA = os.path.join(os.path.dirname(__file__), '..', '..', 'godot', 'proposte', 'geyser')
colori = sorted(glob.glob(os.path.join(CART, 'c_*.png')))
n = len(colori)
w, h = Image.open(colori[0]).size
righe = (n + COLONNE - 1) // COLONNE
atl_c = np.zeros((righe * h, COLONNE * w, 4), np.uint8)
atl_n = np.zeros((righe * h, COLONNE * w, 3), np.uint8)
atl_n[...] = (128, 128, 255)
for i, pc in enumerate(colori):
    r, c = divmod(i, COLONNE)
    col = np.asarray(Image.open(pc).convert('RGBA'))
    nor = np.asarray(Image.open(pc.replace('c_', 'n_')).convert('RGBA')).astype(np.float32)
    nor[..., 2] = 255.0 - nor[..., 2]
    # dove non c'è acqua la normale piatta (le mipmap non sporcano i bordi)
    vuoto = col[..., 3] < 8
    nor[vuoto, :3] = (128, 128, 255)
    atl_c[r * h:(r + 1) * h, c * w:(c + 1) * w] = col
    atl_n[r * h:(r + 1) * h, c * w:(c + 1) * w] = np.clip(nor[..., :3], 0, 255).astype(np.uint8)
Image.fromarray(atl_c, 'RGBA').save(os.path.join(USCITA, 'flipbook_colore.png'), optimize=True)
Image.fromarray(atl_n, 'RGB').save(os.path.join(USCITA, 'flipbook_normali.png'), optimize=True)
print('atlanti', n, 'fotogrammi', COLONNE, 'x', righe, 'da', w, 'x', h)
