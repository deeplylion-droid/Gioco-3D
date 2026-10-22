"""Dalle facce grezze alle texture delle keycard (godot/assets/tessera/texture/tessera_<n>.png): ritaglio
sulla tessera e angoli arrotondati trasparenti. Uso: blender-venv/bin/python prepara_texture.py"""
import os
from PIL import Image, ImageDraw

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', '..', 'godot', 'assets', 'tessera', 'texture')
RITAGLI = {'tessera_1': (178, 46, 1202, 718), 'tessera_2': (150, 34, 1218, 734)}

os.makedirs(OUT, exist_ok=True)
for nome, box in RITAGLI.items():
    im = Image.open(os.path.join(QUI, nome + '_grezza.png')).convert('RGB').crop(box).resize((856, 540), Image.LANCZOS)
    m = Image.new('L', im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), radius=34, fill=255)
    im.putalpha(m)
    im.save(os.path.join(OUT, nome + '.png'))
