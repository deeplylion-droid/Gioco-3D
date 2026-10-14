"""Dal GLB grezzo di Meshy al GLB del repo: scala reale, piedi a terra, facce ridotte.

Uso:
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/bambini_esporta.py \
        <grezzo.glb> <nome> [--facce 150000]

<nome> è una chiave di MODELLI in bambini_comune.py (dà file e altezza). Il modello esce in
assets_src/bambini/<file>, con le texture di Meshy (2K, colore, metallo/rugosità, normali) in JPEG.
I grezzi di Meshy (circa 1-1,6 milioni di facce, 40-56 MB) non vanno nel repo.
"""
import argparse, os, sys
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bambini_comune as B  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('grezzo'); ap.add_argument('nome')
ap.add_argument('--facce', type=int, default=150000)
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])

file, altezza = B.MODELLI[a.nome]
bpy.ops.wm.read_factory_settings(use_empty=True)
perno = B.importa(a.grezzo, altezza, nome=a.nome)
mesh = B.mesh_di(perno)
for o in mesh:
    n = len(o.data.polygons)
    if n > a.facce:
        mod = o.modifiers.new('riduci', 'DECIMATE')
        mod.ratio = a.facce / n
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    B.log(a.nome, o.name, n, '->', len(o.data.polygons), 'facce')
    o.name = a.nome
    o.data.name = a.nome
# applica scala e posizione del perno alle mesh, poi toglie il perno
bpy.ops.object.select_all(action='DESELECT')
for o in mesh:
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.data.objects.remove(perno, do_unlink=True)
for m in bpy.data.materials:
    m.name = a.nome
lo, hi = B.limiti(list(bpy.context.scene.objects))
B.log('misure (m)', tuple(round(v, 3) for v in hi - lo), 'min z', round(lo.z, 4))
out = os.path.join(B.ASSET, file)
os.makedirs(B.ASSET, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=False,
                          export_image_format='JPEG', export_jpeg_quality=90,
                          export_apply=True, export_yup=True)
B.log('scritto', os.path.relpath(out, B.REPO), f'{os.path.getsize(out) / 1e6:.1f} MB')
