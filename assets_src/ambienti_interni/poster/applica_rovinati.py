"""Mette i poster rovinati (rovina.py) nei modelli, senza rifare gli ambienti in Blender:
  - corridoio.gltf e stanzino.gltf (in godot/ e in assets_src/): il materiale del cartellone e quello del
    poster del bagnino puntano al PNG rovinato, con alphaMode MASK (in Godot alpha scissor);
  - manifesto_rovinato.glb: copia di manifesto.glb (che resta com'è, lo usa anche lo sfondo del menu) con la
    texture rovinata e l'alfa anche sul retro della carta, così i buchi si aprono sul muro.
Lo stesso cambio è in tools/blender/ambienti1_build.py (mat_immagine con clip=True), per le prossime build.
Uso: python3 assets_src/ambienti_interni/poster/applica_rovinati.py
"""
import json, os, shutil, struct

QUI = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(QUI, '../../..'))
G_INT = os.path.join(ROOT, 'godot/assets/ambienti_interni')
S_INT = os.path.join(ROOT, 'assets_src/ambienti_interni')
JILLY = os.path.join(ROOT, 'godot/assets/models/mascotte/jilly')
JILLY_TEX = os.path.join(ROOT, 'assets_src/mascotte/jilly_tex/gioco')

POSTER = {'corridoio': ('cartellone_medusa', 'cartellone_medusa_rovinato'),
          'stanzino': ('poster_bagnino', 'poster_bagnino_rovinato')}


def gltf():
    for scena, (materiale, tex) in POSTER.items():
        png = os.path.join(G_INT, 'texture', tex + '.png')
        for dst in (os.path.join(S_INT, 'gltf', 'texture'), os.path.join(S_INT, 'poster')):
            shutil.copy(png, os.path.join(dst, tex + '.png'))
        for base in (G_INT, os.path.join(S_INT, 'gltf')):
            p = os.path.join(base, scena + '.gltf')
            g = json.load(open(p))
            m = next(m for m in g['materials'] if m['name'] == materiale)
            ti = m['pbrMetallicRoughness']['baseColorTexture']['index']
            img = g['images'][g['textures'][ti]['source']]
            img.update(name=tex, uri='texture/' + tex + '.png', mimeType='image/png')
            m['alphaMode'] = 'MASK'
            m['alphaCutoff'] = 0.5
            with open(p, 'w') as f:   # come lo scrive Blender
                json.dump(g, f, indent='\t', separators=(',', ':'), ensure_ascii=False)
            print('ok', os.path.relpath(p, ROOT))


def leggi_glb(p):
    d = open(p, 'rb').read()
    lj = struct.unpack('<I', d[12:16])[0]
    g = json.loads(d[20:20 + lj])
    o = 20 + lj
    lb = struct.unpack('<I', d[o:o + 4])[0]
    return g, d[o + 8:o + 8 + lb]


def scrivi_glb(p, g, viste):
    """viste: i dati di ogni bufferView, in ordine; il buffer si ricompone allineato a 4 byte."""
    bin_ = b''
    for i, dati in enumerate(viste):
        bin_ += b'\0' * (-len(bin_) % 4)
        g['bufferViews'][i]['byteOffset'] = len(bin_)
        g['bufferViews'][i]['byteLength'] = len(dati)
        bin_ += dati
    bin_ += b'\0' * (-len(bin_) % 4)
    g['buffers'][0]['byteLength'] = len(bin_)
    js = json.dumps(g, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    tot = 12 + 8 + len(js) + 8 + len(bin_)
    with open(p, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, tot))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(bin_), 0x004E4942)); f.write(bin_)


def manifesto():
    g, b = leggi_glb(os.path.join(JILLY, 'manifesto.glb'))
    viste = [b[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']] for v in g['bufferViews']]
    mat = {m['name']: m for m in g['materials']}
    # carta davanti: texture rovinata con l'alfa
    m = mat['manifesto']
    img = g['images'][g['textures'][m['pbrMetallicRoughness']['baseColorTexture']['index']]['source']]
    viste[img['bufferView']] = open(os.path.join(JILLY_TEX, 'manifesto_rovinato_col.png'), 'rb').read()
    img.update(name='rovinato_col', mimeType='image/png')
    m.update(alphaMode='MASK', alphaCutoff=0.5)
    # retro: stesso colore di prima, con i buchi (bianco x tinta = tinta)
    viste.append(open(os.path.join(JILLY_TEX, 'manifesto_rovinato_alfa.png'), 'rb').read())
    g['bufferViews'].append({'buffer': 0})
    g['images'].append({'bufferView': len(viste) - 1, 'mimeType': 'image/png', 'name': 'rovinato_alfa'})
    g['textures'].append({'source': len(g['images']) - 1, **({'sampler': g['textures'][0]['sampler']} if 'sampler' in g['textures'][0] else {})})
    r = mat['carta_retro']
    r['pbrMetallicRoughness']['baseColorTexture'] = {'index': len(g['textures']) - 1}
    r.update(alphaMode='MASK', alphaCutoff=0.5)
    out = os.path.join(JILLY, 'manifesto_rovinato.glb')
    scrivi_glb(out, g, viste)
    print('ok', os.path.relpath(out, ROOT), os.path.getsize(out) // 1024, 'KB')


if __name__ == '__main__':
    gltf()
    manifesto()
