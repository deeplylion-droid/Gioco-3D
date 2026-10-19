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
    'schedario_vero': (1.35, 'z', 'basso', 0),
    'negatoscopio': (1.0, 'x', 'retro_centro', 0),
    'sportello_cassaforte': (0.56, 'x', 'retro_centro', 0),
    'sedia_rotelle': (0.95, 'z', 'basso', 0),
    'bilancia': (1.5, 'z', 'basso', 0),
    'asta_flebo': (1.9, 'z', 'basso', 0),
    'cestino': (0.5, 'z', 'basso', 0),
    'tenda_binario': (2.0, 'x', 'alto', 0),
    'lenzuolo': (1.0, 'x', 'basso', 0),
    'pronto_soccorso': (0.4, 'x', 'retro', 0),
    'asciugamani': (0.4, 'x', 'basso', 0),
    'guanti': (0.25, 'x', 'basso', 0),
    'cartelle_terra': (1.0, 'x', 'basso', 0),
    'vetri_rotti': (0.6, 'x', 'basso', 0),
    'lampada_tavolo': (0.45, 'z', 'basso', 0),
    'fonendoscopio': (0.3, 'max', 'basso', 0),
    'timbri': (0.2, 'x', 'basso', 0),
    'fogli': (0.35, 'x', 'basso', 0),
    'bicchiere': (0.1, 'z', 'basso', 0),
    'orsetto': (0.35, 'z', 'basso', 0),
    'cubi': (0.35, 'x', 'basso', 0),
    'trenino': (0.5, 'x', 'basso', 0),
    'cerotti': (0.18, 'x', 'basso', 0),
    'cavallo_dondolo': (0.7, 'x', 'basso', 0),
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
    oz = mn.z if origine in ('basso', 'retro') else mx.z if origine == 'alto' else (mn.z + mx.z) / 2
    oy = mx.y if origine in ('retro', 'retro_centro') else cy   # retro: il lato +Y di Blender (-Z di Godot)
    m = Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation((-cx, -oy, -oz))
    for o in ms:
        o.data.transform(m)
        o.data.update()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, '%s_%s.glb' % (nome, aspetto)), use_selection=True, export_format='GLB')
    print(nome, aspetto, 'dimensioni', [round(v * s, 2) for v in d])


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for n in (sys.argv[1:] or list(SPEC)):
        for a in 'ABN':
            fai(n, a)
