"""Dai GLB grezzi di Meshy (meshy/) ai modelli del fiume lento per Godot (godot/assets/fiume_lento/):
misure vere e origine in basso al centro (o in alto, per le cose appese); texture a 1024; le rocce con l'origine sul retro (si appoggiano al muro); la
lampada d'emergenza con la lente verso -Z di Godot (così look_at la punta dove deve illuminare).
Uso: blender-venv/bin/python prepara_fiume.py [nomi...]"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', 'godot', 'assets', 'fiume_lento')
# nome: (misura, asse della misura: 'x' larghezza, 'z' altezza, 'max' la più grande), origine, rotazione Z (gradi)
SPEC = {
    'ciambella': (1.2, 'x', 'basso', 0),
    'paratia': (3.4, 'x', 'basso', 0),
    'lampada_emergenza': (0.42, 'max', 'centro', 180),
    'scaletta_banchina': (1.55, 'z', 'basso', 0),
    'tornello_imbarco': (1.35, 'z', 'basso', 0),
    'transenna': (2.0, 'x', 'basso', 0),
    'roccia_parete': (4.2, 'x', 'retro', 0),
    'palma_finta': (4.0, 'z', 'basso', 0),
    'totem_tiki': (2.5, 'z', 'basso', 0),
    'capanna_tiki': (2.6, 'x', 'basso', 0),
    'pesce_vetroresina': (2.0, 'max', 'basso', 0),
    'palombaro': (1.4, 'z', 'basso', 0),
    'tartaruga': (1.6, 'max', 'basso', 0),
    # riempimento
    'bocchetta': (0.45, 'x', 'retro', 0),
    'griglia_scolo': (1.0, 'x', 'basso', 0),
    'altoparlante': (0.5, 'max', 'retro', 0),
    'salvagente': (1.4, 'z', 'basso', 0),
    'ciabatta': (0.2, 'max', 'basso', 0),
    'paperella': (0.12, 'max', 'basso', 0),
    'secchiello': (0.35, 'max', 'basso', 0),
    'pallone': (0.4, 'max', 'basso', 0),
    'detriti': (0.7, 'x', 'basso', 0),
    'lampada_capannone': (0.5, 'x', 'alto', 0),
    'liane': (2.5, 'z', 'alto', 0),
    'fiori': (1.0, 'z', 'basso', 0),
    'maschera_tiki': (0.8, 'z', 'retro', 0),
    'corrimano_bambu': (2.0, 'x', 'basso', 0),
    'pappagallo': (1.0, 'z', 'basso', 0),
    'scimmia': (1.0, 'z', 'basso', 0),
    'tettoia_paglia': (4.0, 'x', 'basso', 0),
    'ponte_corda': (5.0, 'max', 'basso', 0),
    'corallo': (1.2, 'z', 'basso', 0),
    'ancora': (1.5, 'z', 'basso', 0),
    'forziere': (0.8, 'x', 'basso', 0),
    'rete_stelle': (2.0, 'x', 'retro', 0),
    'portello': (1.9, 'z', 'retro', 0),
}


def fai(nome):
    misura, asse, origine, rz = SPEC[nome]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(QUI, 'meshy', nome + '.glb'))
    # texture a 1024: bastano per questi oggetti e i GLB pesano un quarto
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
    oz = mn.z if origine in ('basso', 'retro') else mx.z if origine == 'alto' else (mn.z + mx.z) / 2
    oy = mx.y if origine == 'retro' else cy   # retro: il lato +Y di Blender (-Z di Godot)
    m = Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation((-cx, -oy, -oz))
    for o in ms:
        o.data.transform(m)
        o.data.update()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + '.glb'), use_selection=True, export_format='GLB')
    print(nome, 'dimensioni', [round(v * s, 2) for v in d])


if __name__ == '__main__':
    for n in (sys.argv[1:] or list(SPEC)):
        fai(n)
