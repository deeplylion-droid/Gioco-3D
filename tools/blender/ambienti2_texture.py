"""Scarica le texture CC0 di ambientCG usate dagli ambienti tecnici (sala pompe, camera delle onde, scivoli).

Uso: python3 tools/blender/ambienti2_texture.py
Le mette in assets_src/ambienti_tecnici/texture/<Id>/ (solo le mappe che servono, JPG 1K).
Licenza: CC0 1.0 (https://docs.ambientcg.com/license/), annotata in LICENZE.md.
"""
import io, json, os, urllib.request, zipfile

QUI = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(QUI, '..', '..', 'assets_src', 'ambienti_tecnici', 'texture')

# id -> risoluzione
TEXTURE = {
    'Tiles133D': '2K',       # piastrelle bianche sporche e rotte (muri sala pompe)
    'Tiles107': '1K',        # piastrelle bianche pulite (vasca d'arrivo, base pavimento)
    'Concrete042C': '1K',    # cemento rovinato (soffitti, pavimento camera onde)
    'Metal021': '1K',        # metallo scuro arrugginito (pompe, filtri)
    'Metal041B': '1K',       # metallo chiaro con ruggine (tubi)
    'Rust004': '1K',         # ruggine piena (sporco, bulloni)
    'PaintedMetal006': '1K', # vernice verde scrostata (valvole, porte)
    'PaintedMetal016': '1K', # strisce di pericolo gialle e nere
    'MetalPlates013': '1K',  # lamiere rivettate (camera delle onde)
    'MetalWalkway014': '1K', # lamiera forata (passerelle)
    'Fence008A': '1K',       # rete metallica con alpha (grata della leva)
    'Plastic006': '1K',      # plastica opaca consumata (scivoli, roughness)
}
MAPPE = ('_Color', '_NormalGL', '_Roughness', '_Metalness', '_AmbientOcclusion', '_Opacity')


def scarica(aid, res):
    out = os.path.join(DEST, aid)
    if os.path.isdir(out) and os.listdir(out):
        return
    os.makedirs(out, exist_ok=True)
    url = f'https://ambientcg.com/get?file={aid}_{res}-JPG.zip'
    data = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=300).read()
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        for n in z.namelist():
            if n.endswith('.jpg') and any(m + '.' in n for m in MAPPE):
                with open(os.path.join(out, os.path.basename(n).replace(f'_{res}-JPG', '')), 'wb') as f:
                    f.write(z.read(n))
    print(aid, sorted(os.listdir(out)))


if __name__ == '__main__':
    for aid, res in TEXTURE.items():
        scarica(aid, res)
