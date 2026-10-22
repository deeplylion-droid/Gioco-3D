"""Riempie i vuoti tra le isole UV delle texture dentro un GLB (edge padding).

Le texture cotte dei modelli Meshy ridotti (assets_src/mascotte/riduci_cuoci.py) hanno lo sfondo nero
tra un'isola e l'altra. Con le mipmap e il filtro bilineare quel nero entra nei bordi delle isole: sul
modello compaiono triangolini e cuciture nere. Qui ogni pixel vuoto prende il colore dell'isola più
vicina (si legge la maschera dalla texture del colore: lo sfondo è nero puro) e lo stesso riempimento
vale per tutte le texture del materiale (normali, rugosità). Il resto del GLB resta identico.

Uso: python3 tools/glb_bordi_texture.py <file.glb> [...]   (serve numpy, scipy e pillow: il venv di Blender)
Dopo, in godot/: cancellare le texture estratte da Godot (<nome>_*.jpg e .import) perché le riestragga.
"""
import io, json, struct, sys
import numpy as np
from PIL import Image
from scipy import ndimage


def leggi_glb(p):
    d = open(p, 'rb').read()
    magic, ver, lung = struct.unpack_from('<III', d, 0)
    assert magic == 0x46546C67
    off = 12
    js = bin_ = None
    while off < lung:
        cl, ct = struct.unpack_from('<II', d, off)
        dati = d[off + 8: off + 8 + cl]
        if ct == 0x4E4F534A:
            js = json.loads(dati.decode('utf-8'))
        elif ct == 0x004E4942:
            bin_ = bytearray(dati)
        off += 8 + cl
    return js, bin_


def scrivi_glb(p, js, bin_):
    jb = json.dumps(js, separators=(',', ':')).encode('utf-8')
    jb += b' ' * ((4 - len(jb) % 4) % 4)
    bin_ = bytes(bin_) + b'\0' * ((4 - len(bin_) % 4) % 4)
    tot = 12 + 8 + len(jb) + 8 + len(bin_)
    with open(p, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, tot))
        f.write(struct.pack('<II', len(jb), 0x4E4F534A)); f.write(jb)
        f.write(struct.pack('<II', len(bin_), 0x004E4942)); f.write(bin_)


def main(percorsi):
    for p in percorsi:
        js, bin_ = leggi_glb(p)
        bvs = js['bufferViews']
        imgs = js.get('images', [])
        dati = {}
        for i, im in enumerate(imgs):
            bv = bvs[im['bufferView']]
            a = bv.get('byteOffset', 0)
            dati[i] = Image.open(io.BytesIO(bytes(bin_[a:a + bv['byteLength']])))
        # la maschera: dalla texture del colore di base di ogni materiale
        sostituite = {}
        for m in js.get('materials', []):
            pbr = m.get('pbrMetallicRoughness', {})
            if 'baseColorTexture' not in pbr:
                continue
            ic = js['textures'][pbr['baseColorTexture']['index']]['source']
            col = np.asarray(dati[ic].convert('RGB')).astype(np.int32)
            vuoto = col.sum(-1) < 8
            # il bordo delle isole è scurito dalla cottura per 2-3 pixel: si restringono le isole di 3
            # pixel e anche quel bordo prende il colore dall'interno
            vuoto = ~ndimage.binary_erosion(~vuoto, iterations=3)
            _, (iy, ix) = ndimage.distance_transform_edt(vuoto, return_indices=True)
            altre = [ic]
            for k in ('metallicRoughnessTexture',):
                if k in pbr:
                    altre.append(js['textures'][pbr[k]['index']]['source'])
            for k in ('normalTexture', 'occlusionTexture', 'emissiveTexture'):
                if k in m:
                    altre.append(js['textures'][m[k]['index']]['source'])
            for i in altre:
                im = dati[i]
                modo = im.mode
                a = np.asarray(im)
                if a.shape[:2] != vuoto.shape:
                    continue
                riempita = a[iy, ix]
                buf = io.BytesIO()
                fmt = 'PNG' if imgs[i].get('mimeType') == 'image/png' else 'JPEG'
                Image.fromarray(riempita, modo).save(buf, fmt, **({'quality': 92} if fmt == 'JPEG' else {}))
                sostituite[i] = buf.getvalue()
            print(p, m.get('name'), 'vuoto %.1f%%' % (100 * vuoto.mean()), 'texture', altre)
        # ricostruisce il buffer, una bufferView dopo l'altra (allineate a 4 byte)
        nuove_img = {imgs[i]['bufferView']: b for i, b in sostituite.items()}
        nuovo = bytearray()
        for k, bv in enumerate(bvs):
            a = bv.get('byteOffset', 0)
            pezzo = nuove_img.get(k, bytes(bin_[a:a + bv['byteLength']]))
            while len(nuovo) % 4:
                nuovo.append(0)
            bv['byteOffset'] = len(nuovo)
            bv['byteLength'] = len(pezzo)
            nuovo += pezzo
        js['buffers'][0]['byteLength'] = len(nuovo)
        scrivi_glb(p, js, nuovo)


if __name__ == '__main__':
    main(sys.argv[1:])
