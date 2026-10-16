"""Texture condivise e deduplicate per contenuto tra piu' file .gltf.

Uso: /home/user/tools/blender-venv/bin/python tools/blender/gltf_condividi.py <cartella con i .gltf>
- legge tutti i .gltf della cartella e le immagini a cui puntano;
- i PNG senza trasparenza diventano JPG (qualita' 90), i PNG con alfa restano PNG;
- immagini con lo stesso contenuto (stessi pixel) diventano un solo file in <cartella>/texture/;
- riscrive gli uri nei .gltf e cancella i file non piu' usati. Stampa quanto si e' risparmiato.
"""
import hashlib, io, json, os, sys
import numpy as np
from PIL import Image

cart = os.path.abspath(sys.argv[1])
TEX = os.path.join(cart, 'texture')
gltfs = sorted(f for f in os.listdir(cart) if f.endswith('.gltf'))
prima = sum(os.path.getsize(os.path.join(TEX, f)) for f in os.listdir(TEX)) if os.path.isdir(TEX) else 0
per_hash = {}    # hash pixel -> nome file finale
nuovi = {}       # nome file finale -> bytes
mappa = {}       # uri vecchio -> uri nuovo
for g in gltfs:
    d = json.load(open(os.path.join(cart, g)))
    for im in d.get('images', []):
        uri = im['uri']
        if uri in mappa:
            im['uri'], im['mimeType'] = mappa[uri]
            continue
        src = os.path.join(cart, uri)
        pil = Image.open(src)
        alfa = pil.mode in ('RGBA', 'LA') and np.asarray(pil.getchannel('A')).min() < 255
        pil = pil.convert('RGBA' if alfa else 'RGB')
        h = hashlib.sha1(pil.tobytes() + str(pil.size).encode()).hexdigest()
        if h not in per_hash:
            base = os.path.splitext(os.path.basename(uri))[0]
            nome = base + ('.png' if alfa else '.jpg')
            k = 1
            while nome in nuovi:
                k += 1; nome = f'{base}_{k}' + ('.png' if alfa else '.jpg')
            buf = io.BytesIO()
            if alfa:
                pil.save(buf, 'PNG', optimize=True)
            else:
                # i JPG gia' compressi li tengo cosi' come sono (niente doppia compressione)
                if src.lower().endswith(('.jpg', '.jpeg')):
                    buf.write(open(src, 'rb').read())
                else:
                    pil.save(buf, 'JPEG', quality=90)
            per_hash[h] = nome; nuovi[nome] = buf.getvalue()
        nome = per_hash[h]
        mappa[uri] = ('texture/' + nome, 'image/png' if nome.endswith('.png') else 'image/jpeg')
        im['uri'], im['mimeType'] = mappa[uri]
    json.dump(d, open(os.path.join(cart, g), 'w'), indent=1)
# riscrivo la cartella delle texture solo con i file usati
os.makedirs(TEX, exist_ok=True)
for f in os.listdir(TEX):
    os.remove(os.path.join(TEX, f))
for nome, b in nuovi.items():
    open(os.path.join(TEX, nome), 'wb').write(b)
dopo = sum(len(b) for b in nuovi.values())
print(f'{len(gltfs)} gltf, {len(mappa)} immagini -> {len(nuovi)} file unici; texture {prima / 1e6:.1f} MB -> {dopo / 1e6:.1f} MB')
