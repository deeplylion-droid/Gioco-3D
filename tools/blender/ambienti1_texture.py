"""Texture degli ambienti interni del capitolo 1 (corridoio, spogliatoi, stanzino).
Scarica i materiali CC0 da ambientCG (2K) e ne fa varianti sporche, tinte e bagnate, tutte tileabili.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/ambienti1_texture.py
Uscita: assets_src/ambienti_interni/texture/<materiale>_{col,nrm,rgh,met}.jpg"""
import io, os, sys, zipfile, urllib.request
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
SRC = os.path.join(ROOT, 'assets_src/ambienti_interni/texture/ambientcg')
OUT = os.path.join(ROOT, 'assets_src/ambienti_interni/texture')
os.makedirs(SRC, exist_ok=True)
N = 2048

def scarica(asset):
    d = os.path.join(SRC, asset)
    if os.path.isdir(d) and any(f.endswith('_Color.jpg') for f in os.listdir(d)):
        return d
    os.makedirs(d, exist_ok=True)
    url = f'https://ambientcg.com/get?file={asset}_2K-JPG.zip'
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/8.5.0'})
    for tentativo in range(5):
        try:
            z = zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(req, timeout=300).read()))
            break
        except Exception as e:
            print('riprovo', asset, e); import time; time.sleep(3 + 5 * tentativo)
    for n in z.namelist():
        if any(n.endswith(s) for s in ('_Color.jpg', '_NormalGL.jpg', '_Roughness.jpg', '_Metalness.jpg', '_AmbientOcclusion.jpg')):
            z.extract(n, d)
    return d

def carica(asset, mappa, default=None):
    d = scarica(asset)
    f = [x for x in os.listdir(d) if x.endswith(f'_{mappa}.jpg')]
    if not f:
        return None if default is None else np.full((N, N), default, np.float32)
    im = Image.open(os.path.join(d, f[0]))
    im = im.convert('RGB' if mappa in ('Color', 'NormalGL') else 'L').resize((N, N), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0

def rumore(seed, scala, ottave=4):
    """Rumore periodico (tileabile) in [0,1], scala = numero di blob per lato."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((N, N), np.float32); amp = 1.0; tot = 0
    for o in range(ottave):
        k = scala * 2 ** o
        g = rng.random((k, k)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
        # ripiega per tileabilita': interpola su griglia periodica
        g2 = np.pad(g, ((0, 1), (0, 1)), mode='wrap')
        x = np.linspace(0, k, N, endpoint=False)
        i = x.astype(int); f = x - i; f = f * f * (3 - 2 * f)
        a = g2[i][:, i]; b = g2[i][:, i + 1]; c = g2[i + 1][:, i]; d = g2[i + 1][:, i + 1]
        fx = f[None, :]; fy = f[:, None]
        v = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
        acc += v * amp; tot += amp; amp *= 0.5
    acc /= tot
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-6)

def scuri_verticali(seed):
    """Colature verticali di sporco (tileabili)."""
    rng = np.random.default_rng(seed)
    col = rumore(seed, 24, 3)[0]
    strisce = np.tile(col[None, :], (N, 1))
    v = rumore(seed + 1, 3, 3)
    return np.clip((strisce - 0.45) * 2.5, 0, 1) * v

def salva(nome, col, nrm, rgh, met=None):
    def w(a, suf, mode):
        a = np.clip(a * 255, 0, 255).astype(np.uint8)
        Image.fromarray(a, mode).save(os.path.join(OUT, f'{nome}_{suf}.jpg'), quality=90)
    w(col, 'col', 'RGB'); w(nrm, 'nrm', 'RGB'); w(rgh, 'rgh', 'L')
    if met is not None:
        w(met, 'met', 'L')
    print('ok', nome)

def tinta(col, rgb, forza):
    lum = col.mean(axis=2, keepdims=True)
    return col * (1 - forza) + lum * np.array(rgb, np.float32) * forza * 1.6

def sporco(col, rgh, seed, quanto=0.5, colore=(0.18, 0.15, 0.10)):
    m = rumore(seed, 4) ** 1.5 * quanto + scuri_verticali(seed + 7) * quanto * 0.8
    m = np.clip(m, 0, 1)[..., None]
    col = col * (1 - m * 0.75) + np.array(colore, np.float32) * m * 0.75
    rgh = np.clip(rgh + m[..., 0] * 0.15, 0, 1)
    return col, rgh

def bagnato(col, rgh, seed, copertura=0.45, scala=3):
    """Pozze: piu' scuro e quasi a specchio dove c'e' acqua (tileabile)."""
    w = rumore(seed, scala, 5)
    m = np.clip((w - (1 - copertura)) * 8, 0, 1)
    umido = np.clip((w - (1 - copertura - 0.15)) * 4, 0, 1)
    col = col * (1 - umido[..., None] * 0.35)
    rgh = rgh * (1 - umido * 0.55)
    rgh = rgh * (1 - m) + 0.04 * m
    return col, rgh

def materiale(nome, asset, seed, tint=None, tint_f=0.0, scur=1.0, sp=0.5, wet=None, rgh_add=0.0, met_mul=1.0):
    col = carica(asset, 'Color'); nrm = carica(asset, 'NormalGL')
    rgh = carica(asset, 'Roughness', 0.6); met = carica(asset, 'Metalness', 0.0)
    ao = carica(asset, 'AmbientOcclusion', 1.0)
    col = col * (0.6 + 0.4 * ao[..., None])
    if tint is not None:
        col = tinta(col, tint, tint_f)
    col = col * scur
    col, rgh = sporco(col, rgh, seed, sp)
    rgh = np.clip(rgh + rgh_add, 0, 1)
    if wet is not None:
        col, rgh = bagnato(col, rgh, seed + 3, *wet)
    salva(nome, col, nrm, rgh, met * met_mul)

if __name__ == '__main__' and '--godot' not in sys.argv:
    # pareti: lamiera verniciata crema scrostata sopra, verde petrolio scuro sotto (come S01)
    materiale('lamiera_crema', 'PaintedMetal013', 11, tint=(0.78, 0.74, 0.62), tint_f=0.35, scur=0.8, sp=0.55)
    materiale('lamiera_petrolio', 'PaintedMetal006', 12, tint=(0.25, 0.38, 0.36), tint_f=0.55, scur=0.6, sp=0.6)
    materiale('soffitto_lamiera', 'PaintedMetal011', 13, tint=(0.6, 0.58, 0.52), tint_f=0.4, scur=0.55, sp=0.7)
    # pavimenti: piastrelle grigie sporche e bagnate
    materiale('piastrelle_pavimento', 'Tiles040', 21, tint=(0.62, 0.64, 0.62), tint_f=0.4, scur=0.55, sp=0.7, wet=(0.42, 3))
    materiale('piastrelle_doccia', 'Tiles036', 22, tint=(0.70, 0.86, 0.86), tint_f=0.45, scur=0.6, sp=0.75, wet=(0.25, 4))
    materiale('piastrelle_verdi', 'Tiles032', 23, scur=0.75, sp=0.45)
    # metalli
    materiale('armadietto_verde', 'PaintedMetal006', 31, tint=(0.42, 0.55, 0.50), tint_f=0.35, scur=0.8, sp=0.35)
    materiale('porta_lamiera', 'MetalPlates013', 32, scur=0.9, sp=0.4, met_mul=0.25)
    materiale('ruggine', 'Rust007', 33, scur=0.7, sp=0.3)
    materiale('metallo_grezzo', 'Metal063', 34, scur=0.85, sp=0.4, met_mul=0.6)
    materiale('lamiera_grata', 'MetalPlates006', 35, scur=0.7, sp=0.3)
    materiale('vernice_rossa', 'PaintedMetal004', 36, scur=0.65, sp=0.55)
    materiale('vernice_gialla', 'PaintedMetal009', 37, scur=0.8, sp=0.4)
    # legno delle panche e intonaco
    materiale('legno_panca', 'Wood051', 41, scur=0.7, sp=0.5, rgh_add=0.1)
    materiale('cemento', 'Concrete034', 42, scur=0.55, sp=0.7, wet=(0.3, 3))

def salvagente():
    """Salvagente bianco e rosso a 4+4 settori (U lungo l'anello), sporco."""
    w, h = 1024, 256
    u = np.linspace(0, 1, w, endpoint=False)
    rosso = ((u * 8).astype(int) % 2 == 0)[None, :].repeat(h, 0)
    col = np.where(rosso[..., None], np.array([0.62, 0.08, 0.04]), np.array([0.78, 0.76, 0.7]))
    n = rumore(51, 4)[:h, :w]
    col = col * (0.7 + 0.3 * n[..., None])
    sp = np.clip((rumore(52, 8)[:h, :w] - 0.6) * 3, 0, 1)
    col = col * (1 - sp[..., None] * 0.5) + np.array([0.2, 0.15, 0.08]) * sp[..., None] * 0.5
    rgh = 0.45 + 0.4 * sp
    nrm = np.zeros((h, w, 3)) + np.array([0.5, 0.5, 1.0])
    salva('salvagente', col.astype(np.float32), nrm.astype(np.float32), rgh.astype(np.float32))

if __name__ == '__main__' and '--godot' not in sys.argv:
    salvagente()


# ------------------------------------------------------------------ texture per gli shader di Godot
GODOT_TEX = os.path.join(ROOT, 'godot/assets/ambienti_interni/shader_tex')


def _scarica_mappa(asset, mappa):
    """Scarica (se manca) una sola mappa di un materiale ambientCG 2K."""
    d = os.path.join(SRC, asset)
    os.makedirs(d, exist_ok=True)
    if any(f.endswith(f'_{mappa}.jpg') for f in os.listdir(d)):
        return [os.path.join(d, f) for f in os.listdir(d) if f.endswith(f'_{mappa}.jpg')][0]
    url = f'https://ambientcg.com/get?file={asset}_2K-JPG.zip'
    req = urllib.request.Request(url, headers={'User-Agent': 'curl/8.5.0'})
    for k in range(5):
        try:
            z = zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(req, timeout=300).read()))
            break
        except Exception as e:
            print('riprovo', asset, e); import time; time.sleep(3 + 5 * k)
    for n in z.namelist():
        if n.endswith(f'_{mappa}.jpg') or n.endswith('_Color.jpg') or n.endswith('_NormalGL.jpg'):
            z.extract(n, d)
    return [os.path.join(d, f) for f in os.listdir(d) if f.endswith(f'_{mappa}.jpg')][0]


def texture_godot():
    os.makedirs(GODOT_TEX, exist_ok=True)
    def salva_png(a, nome, mode='L'):
        Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8), mode).save(os.path.join(GODOT_TEX, nome))
    # rumore periodico a più ottave (per le variazioni in spazio mondo)
    global N
    vecchio = N; N = 1024
    r = rumore(101, 4, 6)
    salva_png(r, 'rumore.png')
    N = vecchio
    # normale della lamiera verniciata intera (Metal032) e colature (Leaking003)
    Image.open(_scarica_mappa('Metal032', 'NormalGL')).convert('RGB').resize((1024, 1024), Image.LANCZOS).save(os.path.join(GODOT_TEX, 'lamiera_nrm.jpg'), quality=92)
    c = np.asarray(Image.open(_scarica_mappa('Leaking003', 'Color')).convert('L').resize((1024, 1024), Image.LANCZOS), np.float32) / 255
    c = np.clip((c - c.min()) / (c.max() - c.min() + 1e-6), 0, 1)
    salva_png(1 - c, 'colature.png')
    # altezze delle piastrelle (fughe in rilievo)
    for asset, nome in (('Tiles040', 'piastrelle_pavimento'), ('Tiles036', 'piastrelle_doccia'), ('Tiles032', 'piastrelle_verdi')):
        h = Image.open(_scarica_mappa(asset, 'Displacement')).convert('L').resize((1024, 1024), Image.LANCZOS)
        h.save(os.path.join(GODOT_TEX, f'{nome}_alt.png'))
    # decal (PNG con alfa): macchia d'acqua, colatura di ruggine, crepa
    rng = np.random.default_rng(7)
    S = 512
    yy, xx = np.mgrid[0:S, 0:S] / S
    def blob(seed, k):
        g = np.random.default_rng(seed).random((k, k)).astype(np.float32)
        return np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), np.float32) / 255
    # macchia d'acqua: anello scuro con alone
    d = np.hypot(xx - 0.5, yy - 0.5) * 2 + (blob(1, 6) - 0.5) * 0.35
    anello = np.exp(-((d - 0.8) ** 2) / 0.004) * 0.8 + np.clip(1 - d, 0, 1) * 0.35
    a = np.clip(anello * (d < 1.0), 0, 1) * (0.7 + 0.3 * blob(2, 24))
    img = np.dstack([np.full_like(a, 0.18), np.full_like(a, 0.15), np.full_like(a, 0.1), a])
    Image.fromarray((img * 255).astype(np.uint8), 'RGBA').save(os.path.join(GODOT_TEX, 'decal_macchia.png'))
    # colatura di ruggine: strisce verticali che sfumano verso il basso
    x = np.linspace(0, 1, S)
    strisce = np.clip(np.sin(x * 40 + blob(3, 8)[0] * 9) * 0.5 + 0.5, 0, 1) ** 3
    a = (strisce[None, :] * (1 - yy) ** 1.5) * np.exp(-((xx - 0.5) ** 2) / 0.05) * (0.6 + 0.4 * blob(4, 32))
    a = np.clip(a * 1.6, 0, 1)
    img = np.dstack([np.full_like(a, 0.36), np.full_like(a, 0.16), np.full_like(a, 0.06), a])
    Image.fromarray((img * 255).astype(np.uint8), 'RGBA').save(os.path.join(GODOT_TEX, 'decal_ruggine.png'))
    # crepa: spezzata ramificata
    from PIL import ImageDraw, ImageFilter
    im = Image.new('L', (S, S), 0); dr = ImageDraw.Draw(im)
    def ramo(x, y, ang, lun, w, liv):
        for _ in range(int(lun)):
            ang += rng.normal(0, 0.35)
            x2, y2 = x + np.cos(ang) * 8, y + np.sin(ang) * 8
            dr.line([(x, y), (x2, y2)], fill=255, width=max(1, int(w)))
            x, y = x2, y2
            w *= 0.97
            if liv < 3 and rng.random() < 0.08:
                ramo(x, y, ang + rng.choice([-1, 1]) * 0.8, lun * 0.5, w * 0.8, liv + 1)
    ramo(40, 256, 0.0, 55, 4, 0)
    a = np.asarray(im.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255
    img = np.dstack([np.full_like(a, 0.05), np.full_like(a, 0.045), np.full_like(a, 0.04), a])
    Image.fromarray((img * 255).astype(np.uint8), 'RGBA').save(os.path.join(GODOT_TEX, 'decal_crepa.png'))
    print('texture per Godot in', GODOT_TEX)


if __name__ == '__main__' and '--godot' in sys.argv:
    texture_godot()
