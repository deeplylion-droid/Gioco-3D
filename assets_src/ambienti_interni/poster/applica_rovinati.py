"""Mette i poster rovinati (rovina.py) nei modelli, senza rifare gli ambienti in Blender:
  - corridoio.gltf e stanzino.gltf (in godot/ e in assets_src/): il materiale del cartellone e quello del
    poster del bagnino puntano al PNG rovinato, con alphaMode MASK (in Godot alpha scissor);
  - manifesto_rovinato.glb: copia di manifesto.glb (che resta com'è, lo usa anche lo sfondo del menu) con la
    texture rovinata e l'alfa anche sul retro della carta, così i buchi si aprono sul muro.
Lo stesso cambio è in tools/blender/ambienti1_build.py (mat_immagine con clip=True), per le prossime build.
Uso: python3 assets_src/ambienti_interni/poster/applica_rovinati.py
"""
import json, os, shutil, struct, sys

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


# Collaudo del 25 ottobre (mascotte): lo scotch in alto a destra stava 1,3 cm davanti al muro su un angolo di carta che
# non c'è più (strappato), e l'angolo in basso a sinistra arricciato si staccava fino a 7 cm dal muro (l'ombra sotto).
# Il retro del modello (z = 0) è il muro, la carta sta a z > 0.
ARRICCIATO_MAX = 0.012     # sopra questa distanza dal muro la carta si schiaccia (resta arricciata, ma di poco)
NASTRO = dict(centro=(0.19, 0.485), misura=(0.12, 0.035), angolo=-0.3)


def _schiaccia(z):
    import numpy as np
    return np.where(z > ARRICCIATO_MAX, ARRICCIATO_MAX + (z - ARRICCIATO_MAX) * 0.15, z)


def appoggia_manifesto(g, viste):
    """Carta e retro schiacciati verso il muro dove si arricciavano troppo; lo scotch rifatto come una striscia che segue
    la carta (dove c'è, alfa compreso) e il muro (dove la carta manca), a cavallo del bordo in alto; la macchia di colla
    sul muro."""
    import numpy as np
    from PIL import Image
    from scipy.interpolate import griddata

    def leggi(ai, n):
        a = g['accessors'][ai]
        return np.frombuffer(viste[a['bufferView']], np.float32, a['count'] * n).reshape(-1, n).copy()

    def scrivi(ai, arr):
        a = g['accessors'][ai]
        viste[a['bufferView']] = np.ascontiguousarray(arr, np.float32).tobytes()
        a['count'] = len(arr)
        if arr.shape[1] == 3 and 'min' in a:
            a['min'] = arr.min(0).astype(float).tolist()
            a['max'] = arr.max(0).astype(float).tolist()

    nodi = {n['name']: n for n in g['nodes']}
    carta = g['meshes'][nodi['manifesto']['mesh']]['primitives'][0]
    retro = g['meshes'][nodi['manifesto.001']['mesh']]['primitives'][0]
    P = leggi(carta['attributes']['POSITION'], 3)
    P[:, 2] = _schiaccia(P[:, 2])
    scrivi(carta['attributes']['POSITION'], P)
    R = leggi(retro['attributes']['POSITION'], 3)
    R[:, 2] = _schiaccia(R[:, 2] + 0.0008) - 0.0008
    scrivi(retro['attributes']['POSITION'], R)
    # dove c'è la carta vera: vertici con l'alfa della texture
    UV = leggi(carta['attributes']['TEXCOORD_0'], 2)
    A = np.asarray(Image.open(os.path.join(JILLY_TEX, 'manifesto_rovinato_alfa.png')))[..., 3]
    h, w = A.shape
    c_ = A[np.clip((UV[:, 1] * h).astype(int), 0, h - 1), np.clip((UV[:, 0] * w).astype(int), 0, w - 1)] > 127
    # lo scotch: griglia 13 x 5 nel suo rettangolo, ogni punto 0,8 mm sopra la carta o sopra il muro
    cx, cy = NASTRO['centro']
    lw, lh = NASTRO['misura']
    ca, sa = np.cos(NASTRO['angolo']), np.sin(NASTRO['angolo'])
    nu, nv = 13, 5
    uu, vv = np.meshgrid(np.linspace(-lw / 2, lw / 2, nu), np.linspace(-lh / 2, lh / 2, nv))
    xs = cx + uu * ca - vv * sa
    ys = cy + uu * sa + vv * ca
    zc = griddata(P[c_, :2], P[c_, 2], (xs, ys), method='linear')
    dentro = griddata(P[:, :2], c_.astype(float), (xs, ys), method='nearest') > 0.5
    zc = np.where(np.isnan(zc) | ~dentro, 0.0, zc)
    V = np.stack([xs, ys, zc + 0.0008], -1).reshape(-1, 3).astype(np.float32)
    N = np.tile(np.array([[0, 0, 1]], np.float32), (len(V), 1))
    idx = []
    for j in range(nv - 1):
        for i in range(nu - 1):
            a0 = j * nu + i
            idx += [a0, a0 + 1, a0 + nu + 1, a0, a0 + nu + 1, a0 + nu]
    I = np.array(idx, np.uint16)
    nastro = g['meshes'][nodi['Plane']['mesh']]['primitives'][0]
    for k in list(nastro['attributes']):
        if k not in ('POSITION', 'NORMAL'):
            del nastro['attributes'][k]
    scrivi(nastro['attributes']['POSITION'], V)
    scrivi(nastro['attributes']['NORMAL'], N)
    # (gli indici del piano erano in comune con la colla: allo scotch i suoi)
    viste.append(I.tobytes())
    g['bufferViews'].append({'buffer': 0})
    g['accessors'].append({'bufferView': len(viste) - 1, 'componentType': 5123, 'count': len(I), 'type': 'SCALAR'})
    nastro['indices'] = len(g['accessors']) - 1
    for k in ('translation', 'rotation', 'scale'):
        nodi['Plane'].pop(k, None)
    # la colla sul muro: a 0,5 mm (era a 1,5 mm)
    nodi['Plane.001']['translation'][2] = 0.0005


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
    appoggia_manifesto(g, viste)
    out = os.path.join(JILLY, 'manifesto_rovinato.glb')
    scrivi_glb(out, g, viste)
    print('ok', os.path.relpath(out, ROOT), os.path.getsize(out) // 1024, 'KB')


if __name__ == '__main__':
    if 'manifesto' in sys.argv:   # solo il manifesto
        manifesto()
        sys.exit(0)
    gltf()
    manifesto()
