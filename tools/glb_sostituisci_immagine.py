"""Sostituisce un'immagine dentro un GLB (per nome dell'immagine glTF), spostando i bufferView che vengono dopo.

Serve per le texture che Godot estrae dal GLB all'import (per esempio quelle della sala, che non stanno nel
repository come file a parte). Uso:
    python3 tools/glb_sostituisci_immagine.py <file.glb> <nome immagine> <nuova.png|jpg>
"""
import json
import struct
import sys


def sostituisci(glb, nome, nuova):
    b = open(glb, 'rb').read()
    l_json = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + l_json])
    bin_inizio = 20 + l_json + 8
    l_bin = struct.unpack('<I', b[20 + l_json:24 + l_json])[0]
    dati = bytearray(b[bin_inizio:bin_inizio + l_bin])
    im = next(i for i in j['images'] if i.get('name') == nome)
    bv = j['bufferViews'][im['bufferView']]
    vecchio_inizio, vecchia_lun = bv.get('byteOffset', 0), bv['byteLength']
    nuovi = open(nuova, 'rb').read()
    # i bufferView restano allineati a 4 byte
    pad = (-len(nuovi)) % 4
    vecchio_pad = (-vecchia_lun) % 4
    delta = (len(nuovi) + pad) - (vecchia_lun + vecchio_pad)
    dati[vecchio_inizio:vecchio_inizio + vecchia_lun + vecchio_pad] = nuovi + b'\0' * pad
    bv['byteLength'] = len(nuovi)
    for v in j['bufferViews']:
        if v is not bv and v.get('byteOffset', 0) > vecchio_inizio:
            v['byteOffset'] = v.get('byteOffset', 0) + delta
    im['mimeType'] = 'image/png' if nuova.lower().endswith('.png') else 'image/jpeg'
    dati += b'\0' * ((-len(dati)) % 4)
    j['buffers'][0]['byteLength'] = len(dati)
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    uscita = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(dati))
    uscita += struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(dati), 0x004E4942) + bytes(dati)
    open(glb, 'wb').write(uscita)
    print(f'{glb}: {nome} {vecchia_lun} -> {len(nuovi)} byte')


if __name__ == '__main__':
    sostituisci(*sys.argv[1:4])
