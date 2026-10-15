"""Alleggerisce le texture esportate dai glTF (stessi nomi, quindi i .gltf non cambiano):
JPG sopra 1,5 MB ricompressi a qualità 85, PNG sopra 3 MB ridotti a 1024 px.
Uso: /home/user/tools/blender-venv/bin/python tools/comprimi_texture.py godot/assets/ambienti_tecnici/texture"""
import os
import sys
from PIL import Image

cartella = sys.argv[1]
prima = dopo = 0
for f in sorted(os.listdir(cartella)):
    p = os.path.join(cartella, f)
    n = os.path.getsize(p); prima += n
    if f.endswith('.jpg') and n > 1_500_000:
        Image.open(p).convert('RGB').save(p, quality=85, optimize=True)
    elif f.endswith('.png') and n > 3_000_000:
        im = Image.open(p)
        im.resize((im.width // 2, im.height // 2), Image.LANCZOS).save(p, optimize=True)
    dopo += os.path.getsize(p)
print(f'{prima / 1e6:.1f} MB -> {dopo / 1e6:.1f} MB')
