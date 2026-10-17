"""Converte dei GLB in .gltf + .bin con le immagini come file esterni, senza passare da Blender
(nodi, collisioni, luci, extras e materiali restano identici: cambia solo dove stanno i dati).

Uso: python3 tools/blender/glb_in_gltf.py <cartella GLB> <cartella di uscita>
Poi: /home/user/tools/blender-venv/bin/python tools/blender/gltf_condividi.py <cartella di uscita>
"""
import json, os, struct, sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(out, 'texture'), exist_ok=True)
EXT = {'image/png': '.png', 'image/jpeg': '.jpg', 'image/webp': '.webp'}
for f in sorted(os.listdir(src)):
    if not f.endswith('.glb'):
        continue
    nome = f[:-4]
    data = open(os.path.join(src, f), 'rb').read()
    assert data[:4] == b'glTF'
    jl = struct.unpack('<I', data[12:16])[0]
    j = json.loads(data[20:20 + jl])
    off = 20 + jl
    if len(data) >= off + 8:
        bl = struct.unpack('<I', data[off:off + 4])[0]
        binario = data[off + 8:off + 8 + bl]
    else:
        binario = b''   # GLB senza dati binari (per esempio solo luci)
    viste = j.get('bufferViews', [])
    usate_da_img = {}
    for i, im in enumerate(j.get('images', [])):
        if 'bufferView' in im:
            usate_da_img.setdefault(im['bufferView'], []).append(i)
    nuove, mappa, nuovo_bin = [], {}, bytearray()
    for i, v in enumerate(viste):
        pezzo = binario[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        if i in usate_da_img:
            for k in usate_da_img[i]:
                im = j['images'][k]
                nf = f"{nome}_{im.get('name', 'img')}_{k}{EXT.get(im.get('mimeType'), '.bin')}".replace('/', '_')
                open(os.path.join(out, 'texture', nf), 'wb').write(pezzo)
                del im['bufferView']
                im['uri'] = 'texture/' + nf
            continue
        while len(nuovo_bin) % 4:
            nuovo_bin.append(0)
        nv = dict(v); nv['byteOffset'] = len(nuovo_bin); nv['buffer'] = 0
        nuovo_bin += pezzo
        mappa[i] = len(nuove); nuove.append(nv)
    j['bufferViews'] = nuove
    for a in j.get('accessors', []):
        if 'bufferView' in a:
            a['bufferView'] = mappa[a['bufferView']]
        sp = a.get('sparse')
        if sp:
            sp['indices']['bufferView'] = mappa[sp['indices']['bufferView']]
            sp['values']['bufferView'] = mappa[sp['values']['bufferView']]
    if nuovo_bin:
        j['buffers'] = [{'byteLength': len(nuovo_bin), 'uri': nome + '.bin'}]
        open(os.path.join(out, nome + '.bin'), 'wb').write(nuovo_bin)
    else:
        j.pop('buffers', None)
    json.dump(j, open(os.path.join(out, nome + '.gltf'), 'w'), indent=1)
    print(f'{f}: {len(data) / 1e6:.1f} MB -> bin {len(nuovo_bin) / 1e6:.1f} MB + {len(usate_da_img)} immagini')
