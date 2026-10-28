"""Dai GLB di Meshy ai modelli per Godot (godot/assets/models/enigma_giocattoli/), secondo l'accordo con enigmi del
28 ottobre: misure in metri, origine al centro della base (il punto che tocca terra a y = 0), muso verso -Z di Godot,
meno di 5000 triangoli (decimate), texture 1024 in JPG, gomma un po' scolorita e sporca. Niente collisioni (le fa
enigmi). Stampa le misure (finiscono nel LEGGIMI, docs/proposte/enigma_giocattoli/modelli.md) e le salva in misure.json.
- paperella: la paperella di gomma classica delle Polaroid (P04), lunga 0,45 m e alta circa 0,38;
- pallone: pieno, rosso, diametro 0,50 m;
- balena: lunga 0,75 m, abbassata a 0,38 di altezza (alta circa 0,35 nell'accordo; più bassa si schiaccia troppo).
Uso: blender-venv/bin/python prepara_giocattoli.py"""
import bpy, json, os, sys
from mathutils import Vector, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.join(QUI, '..', '..')
OUT = os.path.join(REPO, 'godot', 'assets', 'models', 'enigma_giocattoli')
MAX_TRIANGOLI = 4800
# nome: (sorgente, misura, asse della misura ('lungo' = il lato orizzontale più lungo, 'd' = diametro), altezza massima
# (None = proporzioni del modello), giro in gradi attorno a Z per mettere il muso verso +Y di Blender, cioè -Z in Godot)
GIOCATTOLI = {
    'paperella': (os.path.join(QUI, 'paperella.glb'), 0.45, 'lungo', None, 180),
    'pallone': (os.path.join(QUI, 'palla_rossa.glb'), 0.50, 'd', None, 0),
    'balena': (os.path.join(QUI, 'balena_blu.glb'), 0.75, 'lungo', 0.38, 180),
}
sys.path.insert(0, os.path.join(REPO, 'assets_src', 'ambiente', 'oggetti_hq'))
os.makedirs(OUT, exist_ok=True)
misure = {}


def sporca(glb, seme):
    """Gomma un po' scolorita e sporca (richiesta del 28 ottobre): sul colore di base, meno saturazione, chiazze
    scure larghe e un velo grigio-bruno, più forti in basso nella texture (Meshy mette il fondo in basso nell'atlante
    solo a volte: le chiazze sono soprattutto a caso)."""
    import io, struct, json as js, numpy as np
    from PIL import Image, ImageFilter
    dati = open(glb, 'rb').read()
    n = struct.unpack_from('<I', dati, 12)[0]
    g = js.loads(dati[20:20 + n])
    binario = dati[20 + n + 8:]
    basi = {g['textures'][m['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
            for m in g['materials'] if 'baseColorTexture' in m.get('pbrMetallicRoughness', {})}
    rng = np.random.default_rng(seme)
    pezzi, pos, viste = [], 0, g['bufferViews']
    for i, v in enumerate(viste):
        b = binario[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        for k, im in enumerate(g['images']):
            if im['bufferView'] == i and k in basi:
                img = Image.open(io.BytesIO(b)).convert('RGB')
                a = np.asarray(img).astype(np.float32) / 255
                grigio = a.mean(axis=2, keepdims=True)
                a = grigio + (a - grigio) * 0.8                       # scolorita
                h, w = a.shape[:2]
                def macchie(scala, forza):
                    r = Image.fromarray((rng.random((max(2, h // scala), max(2, w // scala))) * 255).astype(np.uint8))
                    r = r.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scala / 3))
                    r = np.asarray(r).astype(np.float32) / 255
                    r = (r - r.min()) / max(1e-3, r.max() - r.min())
                    return np.clip((r - 0.55) / 0.45, 0, 1)[..., None] * forza
                m = macchie(64, 0.28) + macchie(16, 0.12)
                sporco = np.array([0.36, 0.31, 0.24], np.float32)
                a = a * (1 - m) + a * sporco * 1.6 * m
                a = a * 0.94 + sporco * 0.06                           # velo
                out = io.BytesIO()
                Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(out, 'JPEG', quality=88)
                b = out.getvalue()
                im['mimeType'] = 'image/jpeg'
        pad = (-pos) % 4
        pezzi.append(b'\0' * pad); pos += pad
        v['byteOffset'] = pos; v['byteLength'] = len(b); v['buffer'] = 0
        pezzi.append(b); pos += len(b)
    nb = b''.join(pezzi); nb += b'\0' * ((-len(nb)) % 4)
    g['buffers'] = [{'byteLength': len(nb)}]
    j = js.dumps(g, separators=(',', ':')).encode(); j += b' ' * ((-len(j)) % 4)
    with open(glb, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(nb)))
        f.write(struct.pack('<II', len(j), 0x4E4F534A)); f.write(j)
        f.write(struct.pack('<II', len(nb), 0x004E4942)); f.write(nb)


for nome, (src, misura, asse, alto_max, giro) in GIOCATTOLI.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    obs = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for x in [x for x in bpy.data.objects if x.type != 'MESH']:
        bpy.data.objects.remove(x)
    o.data.transform(Matrix.Rotation(giro * 3.14159265 / 180, 4, 'Z'))
    vs = [v.co for v in o.data.vertices]
    mn = Vector([min(v[i] for v in vs) for i in range(3)])
    mx = Vector([max(v[i] for v in vs) for i in range(3)])
    dim = mx - mn
    s = misura / (max(dim.x, dim.y) if asse == 'lungo' else max(dim))
    sz = min(s, alto_max / dim.z) if alto_max else s
    o.data.transform(Matrix.Diagonal((s, s, sz, 1)) @ Matrix.Translation((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
    o.data.update()
    tri = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if tri > MAX_TRIANGOLI:
        dec = o.modifiers.new('dec', 'DECIMATE')
        dec.ratio = MAX_TRIANGOLI / tri * 0.98
        bpy.ops.object.modifier_apply(modifier='dec')
    o.name = nome
    o.data.name = nome
    vs = [v.co for v in o.data.vertices]
    mn = Vector([min(v[i] for v in vs) for i in range(3)])
    mx = Vector([max(v[i] for v in vs) for i in range(3)])
    # Blender Z su, -Y davanti -> Godot Y su, +Z... l'esportatore glTF fa Y-up: (x, y, z) -> (x, z, -y)
    misure[nome] = dict(x=round(mx.x - mn.x, 3), alto=round(mx.z - mn.z, 3), z=round(mx.y - mn.y, 3),
                        triangoli=sum(len(p.vertices) - 2 for p in o.data.polygons))
    print(nome, misure[nome], flush=True)
    dst = os.path.join(OUT, nome + '.glb')
    bpy.ops.export_scene.gltf(filepath=dst + '.tmp.glb', export_format='GLB', export_yup=True, use_selection=False)
    import genera_hq
    genera_hq.riduci(dst + '.tmp.glb', dst, 1024, 88)
    os.remove(dst + '.tmp.glb')
    sporca(dst, sum(map(ord, nome)))
json.dump(misure, open(os.path.join(QUI, 'misure.json'), 'w'), indent=1)
