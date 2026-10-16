"""Oggetti di scena di Meshy: ricompressione delle texture e controllo.

Meshy consegna GLB con texture PNG 2K (10-15 MB a oggetto). Qui si riesportano gli stessi GLB con
le texture in JPG (qualità 92): geometria, UV e materiali restano quelli di Meshy, il file scende a
pochi MB. Gli originali PNG vanno tenuti fuori dal repository (cartella --copia).

Uso (dalla radice del repository):
  PY=/home/user/tools/blender-venv/bin/python
  $PY tools/blender/ambiente_oggetti.py ricomprimi --copia /percorso/backup_png
"""
import os, shutil, sys
import bpy

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.abspath(os.path.join(QUI, '..', '..'))
OGGETTI = os.path.join(RADICE, 'assets_src', 'ambiente', 'oggetti')


def ricomprimi(copia):
    os.makedirs(copia, exist_ok=True)
    for nome in sorted(os.listdir(OGGETTI)):
        glb = os.path.join(OGGETTI, nome, nome + '_meshy.glb')
        if not os.path.exists(glb):
            continue
        with open(glb, 'rb') as f:
            testa = f.read(4096)
        if b'image/png' not in testa and os.path.getsize(glb) < 8e6:
            print('già compresso:', nome)
            continue
        dest = os.path.join(copia, nome + '_meshy_png.glb')
        if not os.path.exists(dest):
            shutil.copy2(glb, dest)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=dest)
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True,
                                  export_image_format='JPEG', export_jpeg_quality=92, export_yup=True)
        print(f'{nome}: {os.path.getsize(dest) / 1e6:.1f} MB -> {os.path.getsize(glb) / 1e6:.1f} MB')


if __name__ == '__main__':
    import argparse
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('azione', choices=['ricomprimi'])
    ap.add_argument('--copia', required=True)
    a = ap.parse_args(argv)
    ricomprimi(a.copia)
