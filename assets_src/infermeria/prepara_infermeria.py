"""Dai GLB grezzi di Meshy (meshy/) ai modelli dell'infermeria per Godot (godot/assets/infermeria/):
misure vere e origine in basso al centro; gli oggetti da muro con l'origine sul retro; le texture
ridotte a 1024. Un GLB per aspetto (<nome>_A.glb, <nome>_B.glb).
Uso: blender-venv/bin/python prepara_infermeria.py [nomi...]"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', 'godot', 'assets', 'infermeria')
# nome: (misura, asse della misura: 'x' larghezza, 'z' altezza, 'max' la più grande), origine, rotazione Z (gradi)
SPEC = {
    'scrivania': (1.4, 'x', 'basso', 0),
    'sedia': (1.0, 'z', 'basso', 0),
    'schedario': (1.35, 'z', 'basso', 0),
    'lettino': (1.9, 'max', 'basso', 0),
    'armadietto': (0.9, 'z', 'retro', 0),
    'paravento': (1.8, 'z', 'basso', 0),
    'lavandino': (0.55, 'x', 'retro', 0),
    'carrello': (0.95, 'z', 'basso', 0),
    'bombola': (0.9, 'x', 'basso', 0),
    'giraffa_metro': (1.6, 'z', 'retro', 0),
}


def fai(nome, aspetto):
    misura, asse, origine, rz = SPEC[nome]
    src = os.path.join(QUI, 'meshy', '%s_%s.glb' % (nome, aspetto))
    if not os.path.exists(src):
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    # texture a 1024: bastano per oggetti di questa misura e i GLB pesano un quarto
    for img in bpy.data.images:
        if img.size[0] > 1024:
            img.scale(1024, 1024)
    ms = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in ms:
        o.data.transform(Matrix.Rotation(math.radians(rz), 4, 'Z'))
    pts = [v.co for o in ms for v in o.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)])
    mx = Vector([max(p[i] for p in pts) for i in range(3)])
    d = mx - mn
    s = misura / {'x': d.x, 'z': d.z, 'max': max(d)}[asse]
    cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    oz = mn.z if origine in ('basso', 'retro') else (mn.z + mx.z) / 2
    oy = mx.y if origine == 'retro' else cy   # retro: il lato +Y di Blender (-Z di Godot)
    m = Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation((-cx, -oy, -oz))
    for o in ms:
        o.data.transform(m)
        o.data.update()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, '%s_%s.glb' % (nome, aspetto)), use_selection=True, export_format='GLB')
    print(nome, aspetto, 'dimensioni', [round(v * s, 2) for v in d])


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for n in (sys.argv[1:] or list(SPEC)):
        for a in 'AB':
            fai(n, a)
