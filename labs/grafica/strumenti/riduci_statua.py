"""Versione leggera della base Meshy della medusa, solo per la scena di prova della grafica.
Riduce i poligoni e le texture: assets_src/medusa/meshy_base.glb -> scena/modelli/statua_provvisoria.glb
Uso: /home/user/tools/blender-venv/bin/python strumenti/riduci_statua.py"""
import bpy
from pathlib import Path

radice = Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(radice / "assets_src/medusa/meshy_base.glb"))
for o in bpy.data.objects:
    if o.type == 'MESH':
        m = o.modifiers.new("riduci", 'DECIMATE')
        m.ratio = 0.2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
for img in bpy.data.images:
    if img.size[0] > 1024:
        img.scale(1024, 1024)
out = radice / "labs/grafica/scena/modelli/statua_provvisoria.glb"
bpy.ops.export_scene.gltf(filepath=str(out), export_format='GLB', export_image_format='JPEG',
                          export_jpeg_quality=88)
print("scritto", out, out.stat().st_size // 1024, "KB")
