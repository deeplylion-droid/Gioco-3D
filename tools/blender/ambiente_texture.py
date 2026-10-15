"""Texture CC0 dell'ambiente (acquapark): download e texture derivate per palette.

Uso (dalla radice del repository, con il venv di Blender che ha numpy/pillow/opencv):
  PY=/home/user/tools/blender-venv/bin/python
  $PY tools/blender/ambiente_texture.py scarica            # CC0 -> assets_src/ambiente/textures/cc0/
  $PY tools/blender/ambiente_texture.py deriva [palette..]  # -> assets_src/ambiente/textures/derivate/<palette>/

Ogni set CC0 viene salvato a 2K con nomi uniformi:
  <nome>_col.jpg  colore (sRGB)
  <nome>_nrm.jpg  normal map convenzione OpenGL (Y+), come vogliono Blender, glTF e Godot
  <nome>_orm.jpg  R = occlusione, G = rugosità, B = metallicità (lineari)
  <nome>_alt.jpg  altezza (solo dove serve per le maschere, per esempio le fughe)
Le texture derivate (ricolorate per palette) si rigenerano sempre da qui: non si modificano a mano.
"""
import io, json, os, sys, tempfile, urllib.request, zipfile
import numpy as np
from PIL import Image

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
TEX = os.path.join(RADICE, 'assets_src', 'ambiente', 'textures')
CC0 = os.path.join(TEX, 'cc0')
DERIVATE = os.path.join(TEX, 'derivate')
# cache dei download (zip interi): fuori dal repository
CACHE = os.environ.get('AMBIENTE_CACHE') or os.path.join(tempfile.gettempdir(), 'ambiente_cache_texture')
RIS = 2048
UA = 'gioco-3d-ambiente/1.0 (script di download texture CC0)'

# lato = misura reale in metri coperta da una ripetizione della texture.
# griglia = numero di piastrelle per lato nella texture (serve per ricolorarle una a una).
CATALOGO = {
    'piastrelle_bianche': dict(fonte='ambientcg', id='Tiles133B', lato=1.5, griglia=12,
                               uso='piastrelle 12,5x12,5 cm sporche: pareti e bordi (ricolorate per palette)'),
    'piastrelle_turchesi': dict(fonte='ambientcg', id='Tiles132B', lato=1.5, griglia=12,
                                uso='piastrelle 12,5x12,5 cm sporche: interno vasca (ricolorate)'),
    'mosaico_blu': dict(fonte='ambientcg', id='Tiles035', lato=1.2, griglia=24,
                        uso='mosaico di vetro 5x5 cm: vasca e pareti della palette 2 (ricolorato)'),
    'antiscivolo': dict(fonte='polyhaven', id='anti_skid_tiles', lato=1.5, griglia=6,
                        uso='pavimento antiscivolo 25x25 cm del bordo vasca (ricolorato)'),
    'intonaco_scrostato': dict(fonte='polyhaven', id='peeling_painted_wall', lato=2.0, griglia=None,
                               uso='pareti alte e soffitti con vernice che si stacca (ricolorata)'),
    'metallo_verniciato': dict(fonte='ambientcg', id='PaintedMetal010', lato=1.0, griglia=None,
                               uso='metallo navale verniciato con ruggine: telai, ringhiere, plafoniere'),
    'acciaio_inox': dict(fonte='ambientcg', id='Metal049B', lato=1.0, griglia=None,
                         uso='acciaio inox opaco con aloni: scalette e corrimano'),
    'ottone': dict(fonte='ambientcg', id='Metal048B', lato=1.0, griglia=None,
                   uso='ottone sporco: cornici degli oblò'),
    'plastica_bianca': dict(fonte='ambientcg', id='Plastic013B', lato=1.0, griglia=None,
                            uso='plastica graffiata: griglie di scolo, plafoniere, cartelli'),
    'vetroresina': dict(fonte='ambientcg', id='Plastic014B', lato=1.0, griglia=None,
                        uso='vetroresina graffiata dei tubi degli scivoli (ricolorata)'),
    'macchie_acqua': dict(fonte='ambientcg', id='SurfaceImperfections002', lato=2.0, griglia=None,
                          uso='aloni e pozzanghere: maschera per la rugosità bagnata'),
}


# ----------------------------------------------------------------------------- utilità

def _scarica(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return dest
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=600) as r, open(dest + '.part', 'wb') as f:
        while True:
            b = r.read(1 << 20)
            if not b:
                break
            f.write(b)
    os.replace(dest + '.part', dest)
    return dest


def _json(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def _apri(dati_o_percorso, modo):
    im = Image.open(io.BytesIO(dati_o_percorso) if isinstance(dati_o_percorso, bytes) else dati_o_percorso)
    im = im.convert(modo)
    if im.size != (RIS, RIS):
        im = im.resize((RIS, RIS), Image.LANCZOS)
    return im


def _salva_jpg(im, percorso, qualita=90, colore=True):
    from PIL import ImageFile
    ImageFile.MAXBLOCK = max(ImageFile.MAXBLOCK, 1 << 24)   # 'optimize' su immagini grandi
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    # colore: 4:2:0 va bene; dati (normal, ORM, altezza): niente sottocampionamento
    im.save(percorso, quality=qualita, subsampling=2 if colore else 0, optimize=True)


def leggi(nome, mappa, dtype=np.float32):
    """Legge una mappa CC0 normalizzata come array float 0..1 (HxWxC o HxW)."""
    p = os.path.join(CC0, nome, f'{nome}_{mappa}.jpg')
    a = np.asarray(Image.open(p), dtype=dtype) / 255.0
    return a


# ----------------------------------------------------------------------------- download

def _da_ambientcg(nome, info):
    aid = info['id']
    zp = _scarica(f'https://ambientcg.com/get?file={aid}_2K-JPG.zip',
                  os.path.join(CACHE, f'{aid}_2K-JPG.zip'))
    z = zipfile.ZipFile(zp)
    def mappa(suff):
        n = f'{aid}_2K-JPG_{suff}.jpg'
        return z.read(n) if n in z.namelist() else None
    col, nrm = mappa('Color'), mappa('NormalGL')
    rough, ao, metal, disp = mappa('Roughness'), mappa('AmbientOcclusion'), mappa('Metalness'), mappa('Displacement')
    autore, licenza = 'ambientCG (Lennart Demes)', 'CC0 1.0'
    url = f'https://ambientcg.com/a/{aid}'
    return col, nrm, rough, ao, metal, disp, autore, licenza, url


def _da_polyhaven(nome, info):
    aid = info['id']
    files = _json(f'https://api.polyhaven.com/files/{aid}')
    meta = _json(f'https://api.polyhaven.com/info/{aid}')
    def mappa(chiave):
        if chiave not in files:
            return None
        u = files[chiave]['2k']['jpg']['url']
        with open(_scarica(u, os.path.join(CACHE, 'polyhaven', u.split('/')[-1])), 'rb') as f:
            return f.read()
    col, nrm, arm, disp = mappa('Diffuse'), mappa('nor_gl'), mappa('arm'), mappa('Displacement')
    rough = ao = metal = None
    if arm is not None:  # arm = AO, Rough, Metal: è già l'ordine ORM di glTF/Godot
        a = _apri(arm, 'RGB')
        ao, rough, metal = [ch for ch in a.split()]
    autore = ', '.join(meta.get('authors', {}).keys()) + ' (Poly Haven)'
    return col, nrm, rough, ao, metal, disp, autore, 'CC0 1.0', f'https://polyhaven.com/a/{aid}'


def scarica():
    os.makedirs(CC0, exist_ok=True)
    righe = []
    for nome, info in CATALOGO.items():
        print('scarico', nome, info['id'])
        f = _da_ambientcg if info['fonte'] == 'ambientcg' else _da_polyhaven
        col, nrm, rough, ao, metal, disp, autore, licenza, url = f(nome, info)
        cart = os.path.join(CC0, nome)
        _salva_jpg(_apri(col, 'RGB'), os.path.join(cart, f'{nome}_col.jpg'))
        _salva_jpg(_apri(nrm, 'RGB'), os.path.join(cart, f'{nome}_nrm.jpg'), 92, colore=False)
        def canale(x, default):
            if x is None:
                return Image.new('L', (RIS, RIS), default)
            return x if isinstance(x, Image.Image) else _apri(x, 'L')
        orm = Image.merge('RGB', (canale(ao, 255), canale(rough, 128), canale(metal, 0)))
        _salva_jpg(orm, os.path.join(cart, f'{nome}_orm.jpg'), 92, colore=False)
        if disp is not None:
            _salva_jpg(_apri(disp, 'L'), os.path.join(cart, f'{nome}_alt.jpg'), 90, colore=False)
        if info.get('griglia'):
            allinea_griglia(nome, info['griglia'])
        righe.append(f"| `{nome}` | [{info['id']}]({url}) | {autore} | {licenza} | {info['lato']} m | {info['uso']} |")
    with open(os.path.join(TEX, 'LICENZE.md'), 'w') as f:
        f.write('# Texture dell\'ambiente: fonti e licenze\n\n'
                'Tutte le texture in `cc0/` sono **CC0 1.0** (pubblico dominio): si possono usare, modificare '
                'e ridistribuire anche in un gioco commerciale, senza obbligo di citazione. Le citiamo comunque.\n'
                'Sono state scaricate a 2K e riconvertite con `tools/blender/ambiente_texture.py scarica` '
                '(stessi pixel, nomi uniformi, ORM impacchettata). Le texture in `derivate/` sono ricolorazioni '
                'fatte dallo stesso script a partire da queste.\n\n'
                '| Nome nel kit | Originale | Autore | Licenza | Lato reale | Uso |\n|---|---|---|---|---|---|\n')
        f.write('\n'.join(righe) + '\n')
    print('fatto:', CC0)


# ----------------------------------------------------------------------------- allineamento griglia

def _fase_griglia(G, n):
    """Posizione in pixel (x, y) del centro della prima fuga, dalla rugosità (fughe più ruvide)."""
    N = G.shape[0]
    out = []
    for asse in (0, 1):  # asse 0 -> media sulle righe -> profilo lungo x
        prof = G.mean(axis=asse)
        F = np.fft.rfft(prof - prof.mean())[n]
        out.append((-np.angle(F) * N / (2 * np.pi * n)) % (N / n))
    return out  # [x0, y0]


def allinea_griglia(nome, n):
    """Sposta (in modo ciclico) tutte le mappe perché una fuga cada sul bordo della texture.
    Così i moduli lunghi un multiplo della piastrella si accostano senza giunte visibili."""
    cart = os.path.join(CC0, nome)
    G = leggi(nome, 'orm')[..., 1]
    x0, y0 = _fase_griglia(G, n)
    P = G.shape[0] / n
    dx = -int(round(x0)) % int(round(P)) if abs(x0) > 0.75 and abs(x0 - P) > 0.75 else 0
    dy = -int(round(y0)) % int(round(P)) if abs(y0) > 0.75 and abs(y0 - P) > 0.75 else 0
    if not dx and not dy:
        return
    print(f'  allineo la griglia di {nome}: sposto di ({dx}, {dy}) px')
    for m in ('col', 'nrm', 'orm', 'alt'):
        f = os.path.join(cart, f'{nome}_{m}.jpg')
        if not os.path.exists(f):
            continue
        im = Image.open(f)
        a = np.roll(np.asarray(im), (dy, dx), axis=(0, 1))
        _salva_jpg(Image.fromarray(a), f, 90 if m in ('col', 'alt') else 92, colore=(m == 'col'))


# ----------------------------------------------------------------------------- ricolorazione

def srgb_lin(a):
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def lin_srgb(a):
    a = np.clip(a, 0, 1)
    return np.where(a <= 0.0031308, a * 12.92, 1.055 * a ** (1 / 2.4) - 0.055)


def _lum(a):
    return a @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def _hexlin(h):
    from ambiente_palette import hex_rgb
    return srgb_lin(np.array(hex_rgb(h), dtype=np.float32))


def _macchie(scala=1.0):
    """Maschera 0..1 di aloni (CC0 SurfaceImperfections), alla risoluzione di lavoro.
    scala > 1 rimpicciolisce le macchie (la mappa si ripete scala x scala volte)."""
    m = leggi('macchie_acqua', 'col')
    if m.ndim == 3:
        m = m.mean(axis=2)
    if scala != 1.0:
        k = max(1, int(round(scala)))
        m = np.tile(m, (k, k))
        m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((RIS, RIS), Image.BILINEAR), np.float32) / 255
    return m


def ricetta_piastrelle(r, seme):
    src = r['sorgente']
    n = CATALOGO[src]['griglia']
    col = srgb_lin(leggi(src, 'col'))
    G = leggi(src, 'orm')[..., 1]
    Ls = _lum(col)
    fuga = _smooth(0.42, 0.62, G)
    if src == 'mosaico_blu':
        fuga = _smooth(0.33, 0.55, G)
    piastra = fuga < 0.3
    rif_p = np.median(Ls[piastra])
    rif_f = np.median(Ls[fuga > 0.7]) if (fuga > 0.7).any() else rif_p * 0.5
    N = col.shape[0]
    P = N / n
    ix = (np.arange(N) // P).astype(int) % n
    det = np.clip(Ls / rif_p, 0.2, 1.7)
    if r.get('uniforma', 0) > 0:
        # il mosaico CC0 ha tessere molto più scure di altre: riduce lo scarto tra tessere
        idx = (ix[:, None] * n + ix[None, :]).ravel()
        w = piastra.ravel().astype(np.float64)
        somma = np.bincount(idx, weights=Ls.ravel() * w, minlength=n * n)
        conta = np.bincount(idx, weights=w, minlength=n * n)
        media = (somma / np.maximum(conta, 1)).reshape(n, n)
        mt = media[ix[:, None], ix[None, :]]
        a = r['uniforma']
        det = np.clip(Ls / np.maximum(mt, 1e-4) * (mt / rif_p) ** (1 - a), 0.2, 1.7)
    rng = np.random.default_rng(seme)
    colori = [_hexlin(c) for c, _ in r['colori']]
    pesi = np.array([w for _, w in r['colori']], dtype=np.float64)
    scelta = rng.choice(len(colori), size=(n, n), p=pesi / pesi.sum())
    if r.get('schema') == 'scacchi':  # alterna i colori come una scacchiera
        ii, jj = np.meshgrid(np.arange(n), np.arange(n), indexing='ij')
        scelta = (ii + jj) % len(colori)
    tab = np.stack([colori[k] for k in scelta.ravel()]).reshape(n, n, 3)
    tab *= rng.normal(1.0, 0.045, size=(n, n, 1)) * rng.normal(1.0, 0.015, size=(n, n, 3))
    base = tab[ix[:, None], ix[None, :]]  # [riga y, colonna x]
    tinta = base * det[..., None]
    # lo sporco della sorgente (zone più scure del normale) tende al marrone-grigio
    sporco = np.clip((0.92 - det) * 2.2, 0, 1) * min(1.0, 0.55 * r.get('sporco', 1.0))
    marrone = _hexlin('#5a5244') * (Ls / max(rif_p, 1e-4))[..., None]
    tinta = tinta * (1 - sporco[..., None]) + marrone * sporco[..., None]
    gr = _hexlin(r['fuga'])[None, None, :] * np.clip(Ls / max(rif_f, 1e-4), 0.3, 1.6)[..., None]
    out = tinta * (1 - fuga[..., None]) + gr * fuga[..., None]
    extra = r.get('sporco', 1.0) - 1.0
    if extra > 0:  # aloni scuri in più per le palette più trascurate
        m = _macchie(1.5)
        out *= (1 - np.clip(m * 1.2 - 0.15, 0, 1) * 0.35 * extra)[..., None]
    return out


def ricetta_tinta(r, seme):
    col = srgb_lin(leggi(r['sorgente'], 'col'))
    Ls = _lum(col)
    det = np.clip(Ls / np.median(Ls), 0.2, 1.8)
    out = _hexlin(r['colore'])[None, None, :] * det[..., None]
    if r.get('sporco', 0) > 0:  # aloni e sbiaditura (vetroresina vecchia)
        m = _macchie(1.0)
        k = np.clip(m * 1.3 - 0.2, 0, 1)[..., None] * r['sporco']
        grigio = _lum(out)[..., None] * 0.9
        out = out * (1 - 0.45 * k) + grigio * 0.25 * k
    return out


def ricetta_vernice(r, seme):
    col = srgb_lin(leggi(r['sorgente'], 'col'))
    Ls = _lum(col)
    mx, mn = col.max(axis=2), col.min(axis=2)
    S = (mx - mn) / np.maximum(mx, 1e-4)
    if r['sorgente'] == 'intonaco_scrostato':
        vern = _smooth(0.22, 0.38, S)          # la vernice è la parte satura (rosa)
    else:
        vern = 1 - _smooth(0.22, 0.42, S)      # la vernice è bianca, la ruggine è satura
    rif = np.median(Ls[vern > 0.8])
    nuova = _hexlin(r['colore'])[None, None, :] * np.clip(Ls / rif, 0.2, 1.5)[..., None]
    return nuova * vern[..., None] + col * (1 - vern[..., None])


def orm_bagnato(sorgente, quanto, extra=1.0):
    """ORM con un velo d'acqua irregolare: la rugosità scende a chiazze.
    Le pozzanghere vere NON vanno qui (si ripeterebbero a ogni texture): in Godot si fanno con
    decal o con una maschera in spazio mondo nello shader del pavimento."""
    orm = leggi(sorgente, 'orm')
    m = _macchie(1.0)
    film = _smooth(0.2, 0.55, m)
    # bagnato: tutto un po' più lucido, le chiazze molto di più (in Godot si vede con SSR)
    orm[..., 1] = orm[..., 1] * (1 - 0.35 * quanto) * (1 - 0.55 * film * quanto) * extra
    return orm


def grata_png(palette, lato_px=1024, passo_mm=34.0, barra_mm=4.0, lato_m=0.5):
    """Grigliato elettrosaldato RGBA (colore dal metallo 'torre' della palette, alfa = barre).
    PNG perché serve l'alfa; in Godot: trasparenza 'alpha scissor'."""
    src = os.path.join(DERIVATE, palette, 'torre_col.jpg')
    if not os.path.exists(src):
        return
    rgb = np.asarray(Image.open(src).convert('RGB').resize((lato_px, lato_px), Image.LANCZOS))
    pxm = lato_px / lato_m
    per = passo_mm / 1000 * pxm
    w = barra_mm / 1000 * pxm
    n = max(1, int(round(lato_px / per)))
    per = lato_px / n                       # passo intero per ripetersi senza giunte
    x = np.arange(lato_px)
    bx = (np.abs(((x + per / 2) % per) - per / 2) < w / 2)
    by = (np.abs(((x + per / 2) % per) - per / 2) < w * 0.75)
    a = (bx[None, :] | by[:, None]).astype(np.uint8) * 255
    img = np.dstack([rgb, a])
    Image.fromarray(img, 'RGBA').save(os.path.join(DERIVATE, palette, 'grata_col.png'), optimize=True)


def rosa_venti_png(percorso, lato=1024):
    """Rosa dei venti a mosaico (tessere da 5 cm su 2 m) per il fondo della piscina. RGBA."""
    n = 40
    yy, xx = np.mgrid[0:n, 0:n]
    c = (n - 1) / 2
    dx, dy = (xx - c) / c, (yy - c) / c
    r = np.hypot(dx, dy)
    ang = np.arctan2(dy, dx)
    blu, giallo, bianco, rosso, scuro = (np.array(v) for v in ((22, 60, 120), (225, 175, 40), (225, 222, 210), (170, 45, 35), (12, 30, 70)))
    col = np.zeros((n, n, 3)); al = np.zeros((n, n))
    disco = r < 0.98
    col[disco] = blu; al[disco] = 1
    anello = (r > 0.82) & (r < 0.92)
    col[anello] = giallo
    # punte: 4 grandi e 4 piccole
    for k in range(8):
        a0 = k * np.pi / 4
        lung = 0.8 if k % 2 == 0 else 0.5
        d = np.abs(((ang - a0 + np.pi) % (2 * np.pi)) - np.pi)
        larg = 0.28 * (1 - r / lung)
        punta = (r < lung) & (d < larg)
        meta = ((ang - a0 + np.pi) % (2 * np.pi)) - np.pi > 0
        col[punta & meta] = bianco if k % 2 == 0 else giallo
        col[punta & ~meta] = rosso if k == 0 else (scuro if k % 2 == 0 else bianco)
    centro = r < 0.1
    col[centro] = giallo
    rng = np.random.default_rng(4)
    col = col * rng.uniform(0.82, 1.08, (n, n, 1))
    img = np.dstack([np.clip(col, 0, 255), al * 255]).astype(np.uint8)
    big = Image.fromarray(img, 'RGBA').resize((lato, lato), Image.NEAREST)
    # fughe tra le tessere
    a = np.asarray(big).copy()
    t = lato / n
    g = (np.arange(lato) % t) < max(1, t * 0.08)
    a[g, :, :3] = (a[g, :, :3] * 0.55).astype(np.uint8)
    a[:, g, :3] = (a[:, g, :3] * 0.55).astype(np.uint8)
    Image.fromarray(a, 'RGBA').save(percorso, optimize=True)


def invecchia_cartellone(palette, chiave, nome_file='cartellone_col.jpg'):
    """Grafica del cartellone (Meshy, senza scritte) invecchiata: sbiadita, macchiata, colature."""
    src = os.path.join(RADICE, 'assets_src', 'ambiente', 'cartelloni', f'cartellone_{chiave}.png')
    if not os.path.exists(src):
        return
    W, H = 2048, 1152
    im = Image.open(src).convert('RGB').resize((W, H), Image.LANCZOS)
    a = srgb_lin(np.asarray(im, np.float32) / 255)
    sbiadito = {'p1': 0.12, 'p2': 0.06, 'p3': 0.3}.get(chiave, 0.1)
    L = _lum(a)[..., None]
    a = a * (1 - sbiadito) + (L * 0.6 + _hexlin('#e8dcc0') * 0.4) * sbiadito  # sole e anni
    m = _macchie(1.0)
    m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR), np.float32) / 255
    rng = np.random.default_rng(7)
    # colature verticali dall'alto
    col = np.repeat(rng.random(W // 8), 8)[:W]
    col = np.convolve(col, np.ones(9) / 9, mode='same')
    yy = np.linspace(0, 1, H)[:, None]
    colature = np.clip((col[None, :] - 0.55) * 3, 0, 1) * np.clip(1.2 - yy * 1.6, 0, 1)
    sporco = np.clip(_smooth(0.35, 0.7, m) * 0.5 + colature * 0.6, 0, 1)
    a = a * (1 - 0.45 * sporco[..., None]) + _hexlin('#4a4032') * 0.45 * sporco[..., None] * 0.3
    # bordi più scuri
    xx = np.linspace(-1, 1, W)[None, :]
    yv = np.linspace(-1, 1, H)[:, None]
    vign = np.clip(1 - 0.18 * (np.abs(xx) ** 4 + np.abs(yv) ** 4), 0, 1)
    a *= vign[..., None]
    out = Image.fromarray((lin_srgb(a) * 255 + 0.5).astype(np.uint8))
    _salva_jpg(out, os.path.join(DERIVATE, palette, nome_file))
    print(palette, 'cartellone', chiave, nome_file)


def colatura_png(percorso, seme=3):
    """Texture RGBA di colature (ruggine e calcare) per decal sotto oblò e bordi.
    PNG perché serve l'alfa. Le colature sono percorsi casuali che si assottigliano scendendo."""
    W, H = 512, 1024
    rng = np.random.default_rng(seme)
    alfa = np.zeros((H, W), np.float32)
    yy = np.arange(H)
    X = np.arange(W)[None, :]
    for _ in range(34):
        x = rng.normal(W / 2, W / 5.5)
        lung = rng.uniform(0.2, 0.95) * H
        larg0 = rng.uniform(2.5, 11)
        forza = rng.uniform(0.2, 0.75)
        deriva = np.cumsum(rng.normal(0, 0.35, H))  # serpeggia un poco
        cx = x + deriva
        t = yy / max(lung, 1)
        larg = larg0 * np.clip(1 - 0.6 * t, 0.25, 1)[:, None]
        intens = forza * np.clip(1 - t, 0, 1)[:, None] ** 1.3 * (0.75 + 0.25 * rng.random((H, 1)))
        alfa += intens * np.exp(-((X - cx[:, None]) / larg) ** 2)
    # alone in alto, dove l'acqua esce
    base = np.exp(-((X - W / 2) / (W / 3.2)) ** 2) * np.clip(1 - yy[:, None] / (H * 0.3), 0, 1) ** 2 * 0.45
    alfa = np.clip(alfa + base, 0, 1) * 0.85
    yn = np.linspace(0, 1, H)[:, None]
    xn = np.linspace(-1, 1, W)[None, :]
    alfa *= _smooth(0.0, 0.07, yn) * (1 - _smooth(0.75, 1.0, np.abs(xn)))  # bordi sfumati
    rgb = np.zeros((H, W, 3), np.float32)
    rgb[...] = np.array([0.24, 0.17, 0.10])  # ruggine e calcare scuri
    rgb *= (0.8 + 0.4 * rng.random((H, 1, 1)))
    img = np.dstack([rgb, alfa])
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), 'RGBA').save(percorso, optimize=True)


def _normali_da_altezza(alt, forza=2.0):
    """Normal map OpenGL (Y+) da una mappa d'altezza 0..1 (array HxW)."""
    gx = (np.roll(alt, -1, 1) - np.roll(alt, 1, 1)) * 0.5
    gy = (np.roll(alt, -1, 0) - np.roll(alt, 1, 0)) * 0.5
    n = np.dstack([-gx * forza, gy * forza, np.ones_like(alt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)


def fregio_marino(cartella, W=2048, H=512, tessera=16, seme=11):
    """Fregio a mosaico per il tamburo del piedistallo della statua: onde 'a ricciolo' in basso,
    pesci, stelle marine, bolle e una medusa stilizzata su fondo blu profondo; filo d'oro in alto.
    Ogni tessera (1,6 cm) prende il colore del disegno al suo centro. Una ripetizione = 2,04 m x 0,51 m.
    Scrive fregio_col.jpg, fregio_nrm.jpg, fregio_orm.jpg (nessuna scritta)."""
    from PIL import ImageDraw
    rng = np.random.default_rng(seme)
    im = Image.new('RGB', (W, H), (18, 58, 122))
    d = ImageDraw.Draw(im)
    BIANCO, TURCH, ORO, ARANCIO, ROSA, BLU2 = (230, 232, 225), (40, 170, 175), (214, 168, 52), (226, 120, 40), (226, 130, 170), (30, 84, 160)
    # fasce: oro in alto e in basso
    d.rectangle([0, 0, W, 2 * tessera], fill=ORO)
    d.rectangle([0, 3 * tessera, W, 4 * tessera], fill=BLU2)
    d.rectangle([0, H - 2 * tessera, W, H], fill=ORO)
    # onde a ricciolo (motivo vitruviano) nella fascia bassa
    P = W / 12
    base = H - 2 * tessera
    for k in range(13):
        x0 = k * P
        pts = [(x0, base)]
        for t in np.linspace(0, 1, 24):
            pts.append((x0 + t * P * 0.75, base - (np.sin(t * np.pi / 2) ** 1.5) * 150))
        pts.append((x0 + P * 0.75, base))
        d.polygon(pts, fill=TURCH)
        cx, cy, r = x0 + P * 0.72, base - 118, 52
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TURCH)
        d.ellipse([cx - r * 0.55, cy - r * 0.55 + 6, cx + r * 0.55, cy + r * 0.55 + 6], fill=(18, 58, 122))
        d.line([(x0, base - 4), (x0 + P * 0.6, base - 112)], fill=BIANCO, width=tessera)
    # figure: due pesci, una stella marina, una medusa, bolle
    def pesce(cx, cy, s, col, verso=1):
        d.ellipse([cx - 70 * s, cy - 32 * s, cx + 70 * s, cy + 32 * s], fill=col)
        d.polygon([(cx - verso * 60 * s, cy), (cx - verso * 120 * s, cy - 40 * s), (cx - verso * 120 * s, cy + 40 * s)], fill=col)
        d.ellipse([cx + verso * 34 * s - 9, cy - 12 * s - 9, cx + verso * 34 * s + 9, cy - 12 * s + 9], fill=BIANCO)
    def stella(cx, cy, r, col):
        pts = []
        for i in range(10):
            a = -np.pi / 2 + i * np.pi / 5
            rr = r if i % 2 == 0 else r * 0.42
            pts.append((cx + np.cos(a) * rr, cy + np.sin(a) * rr))
        d.polygon(pts, fill=col)
    def medusa(cx, cy, s):
        d.pieslice([cx - 80 * s, cy - 70 * s, cx + 80 * s, cy + 70 * s], 180, 360, fill=ROSA)
        for i in range(5):
            x = cx - 56 * s + i * 28 * s
            pts = [(x + np.sin(t * 6 + i) * 10 * s, cy + t * 120 * s) for t in np.linspace(0, 1, 12)]
            d.line(pts, fill=ROSA, width=int(tessera * 0.9))
        d.ellipse([cx - 30 * s, cy - 40 * s, cx - 10 * s, cy - 20 * s], fill=BIANCO)
        d.ellipse([cx + 10 * s, cy - 40 * s, cx + 30 * s, cy - 20 * s], fill=BIANCO)
    pesce(300, 200, 1.25, ARANCIO, 1)
    pesce(1380, 185, 1.1, ORO, -1)
    stella(860, 205, 85, ARANCIO)
    medusa(1700, 172, 1.35)
    for (bx, by, br) in ((470, 120, 14), (500, 95, 10), (1180, 130, 16), (1210, 100, 11), (1560, 110, 12), (640, 260, 12)):
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=BIANCO)
    a = np.asarray(im, np.float32)
    # mosaico: ogni tessera prende il colore al suo centro, con una piccola variazione
    n_x, n_y = W // tessera, H // tessera
    cen = a[tessera // 2::tessera, tessera // 2::tessera][:n_y, :n_x]
    var = rng.normal(1.0, 0.07, (n_y, n_x, 1)) * rng.normal(1.0, 0.025, (n_y, n_x, 3))
    tess = np.clip(cen * var, 0, 255)
    out = np.repeat(np.repeat(tess, tessera, 0), tessera, 1)[:H, :W]
    # fughe (3 px) e bordo smussato delle tessere per la normal map
    yy, xx = np.mgrid[0:H, 0:W]
    fx = (xx % tessera); fy = (yy % tessera)
    fuga = (fx < 2) | (fx >= tessera - 1) | (fy < 2) | (fy >= tessera - 1)
    out[fuga] = np.array([150, 150, 142])
    dist = np.minimum(np.minimum(fx, tessera - 1 - fx), np.minimum(fy, tessera - 1 - fy)).astype(np.float32)
    alt = np.clip(dist / 4.0, 0, 1)
    alt = alt * (0.85 + 0.15 * rng.random((n_y, n_x)).repeat(tessera, 0).repeat(tessera, 1)[:H, :W])
    os.makedirs(cartella, exist_ok=True)
    _salva_jpg(Image.fromarray(out.astype(np.uint8)), os.path.join(cartella, 'fregio_col.jpg'))
    _salva_jpg(Image.fromarray(_normali_da_altezza(alt, 3.0)), os.path.join(cartella, 'fregio_nrm.jpg'), 92, colore=False)
    rough = np.where(fuga, 0.85, 0.22 + 0.08 * rng.random((n_y, n_x)).repeat(tessera, 0).repeat(tessera, 1)[:H, :W])
    ao = np.where(fuga, 0.75, 1.0)
    orm = np.dstack([ao, rough, np.zeros_like(rough)])
    _salva_jpg(Image.fromarray((orm * 255 + 0.5).astype(np.uint8)), os.path.join(cartella, 'fregio_orm.jpg'), 92, colore=False)
    print('fregio marino ->', cartella)


def disegni_bambini(cartella, seme=5):
    """Quattro disegni a pastello dei bambini (fogli A4, nessuna scritta): la medusa con i bambini,
    il mare, la sala con la statua, un bambino che dà la mano a un tentacolo. Carta un po' rovinata.
    Atlante 2 x 2 (celle 724 x 1024) -> disegni_col.jpg."""
    from PIL import ImageDraw, ImageFilter
    rng = np.random.default_rng(seme)
    CW, CH = 724, 1024
    atl = Image.new('RGB', (CW * 2, CH * 2))
    def carta():
        base = np.ones((CH, CW, 3), np.float32) * np.array([238, 232, 214], np.float32)
        g = rng.normal(0, 4, (CH, CW, 1))
        pieghe = np.asarray(Image.fromarray((rng.random((8, 6)) * 255).astype(np.uint8)).resize((CW, CH), Image.BICUBIC), np.float32)[..., None] / 255
        base = base * (0.9 + 0.1 * pieghe) + g
        return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
    def pastello(d, pts, col, w=9):
        pts = [(x + rng.normal(0, 1.2), y + rng.normal(0, 1.2)) for x, y in pts]
        for k in range(3):
            q = [(x + rng.normal(0, w * 0.25), y + rng.normal(0, w * 0.25)) for x, y in pts]
            d.line(q, fill=tuple(int(c * rng.uniform(0.85, 1.05)) for c in col), width=max(2, int(w * rng.uniform(0.5, 0.9))), joint='curve')
    def campitura(d, box, col, fitto=14):
        x0, y0, x1, y1 = box
        y = y0
        while y < y1:
            pastello(d, [(x0, y + rng.normal(0, 3)), (x1, y + rng.normal(0, 3))], col, 7)
            y += fitto
    def omino(d, x, y, s, col):
        d.ellipse([x - 22 * s, y - 70 * s, x + 22 * s, y - 26 * s], outline=col, width=6)
        pastello(d, [(x, y - 26 * s), (x, y + 40 * s)], col)
        pastello(d, [(x - 40 * s, y - 5 * s), (x + 40 * s, y - 5 * s)], col)
        pastello(d, [(x, y + 40 * s), (x - 26 * s, y + 95 * s)], col)
        pastello(d, [(x, y + 40 * s), (x + 26 * s, y + 95 * s)], col)
        d.arc([x - 12 * s, y - 56 * s, x + 12 * s, y - 36 * s], 20, 160, fill=col, width=4)
    def medusa(d, cx, cy, s, col, faccia=True):
        pts = [(cx + np.cos(t) * 150 * s, cy - np.sin(t) * 120 * s) for t in np.linspace(0, np.pi, 30)]
        pastello(d, pts + [pts[0]], col, 11)
        campitura(d, (cx - 120 * s, cy - 90 * s, cx + 120 * s, cy - 5 * s), tuple(min(255, c + 40) for c in col), 16)
        for i in range(6):
            x = cx - 120 * s + i * 48 * s
            pastello(d, [(x + np.sin(t * 5 + i) * 18 * s, cy + t * 260 * s) for t in np.linspace(0, 1, 14)], col, 8)
        if faccia:
            d.ellipse([cx - 55 * s, cy - 70 * s, cx - 25 * s, cy - 40 * s], fill=(30, 30, 40))
            d.ellipse([cx + 25 * s, cy - 70 * s, cx + 55 * s, cy - 40 * s], fill=(30, 30, 40))
            d.arc([cx - 50 * s, cy - 50 * s, cx + 50 * s, cy - 5 * s], 20, 160, fill=(200, 40, 60), width=7)
    def sole(d, x, y):
        d.ellipse([x - 60, y - 60, x + 60, y + 60], outline=(240, 190, 30), width=10)
        campitura(d, (x - 45, y - 45, x + 45, y + 45), (245, 205, 60), 12)
        for k in range(10):
            a = k * np.pi / 5
            pastello(d, [(x + np.cos(a) * 80, y + np.sin(a) * 80), (x + np.cos(a) * 120, y + np.sin(a) * 120)], (240, 180, 30), 7)
    def onde(d, y, col):
        for r in range(3):
            pastello(d, [(x, y + r * 34 + np.sin(x / 45) * 16) for x in range(-10, CW + 20, 12)], col, 9)
    disegni = []
    # 1: medusa grande con bambini per mano
    im = carta(); d = ImageDraw.Draw(im)
    sole(d, 600, 130); medusa(d, 362, 420, 1.2, (235, 110, 170)); onde(d, 860, (40, 110, 220))
    for i, x in enumerate((110, 230, 500, 620)):
        omino(d, x, 760, 0.9, [(220, 60, 50), (40, 140, 60), (60, 80, 200), (230, 140, 30)][i])
    disegni.append(im)
    # 2: mare con medusa, pesci, cuore
    im = carta(); d = ImageDraw.Draw(im)
    campitura(d, (0, 300, CW, CH), (90, 170, 235), 18)
    medusa(d, 380, 470, 0.9, (150, 80, 200))
    for (x, y, c) in ((150, 760, (240, 140, 40)), (560, 820, (250, 200, 40))):
        d.ellipse([x - 60, y - 30, x + 60, y + 30], outline=c, width=8)
        pastello(d, [(x - 60, y), (x - 110, y - 35), (x - 110, y + 35), (x - 60, y)], c)
    pastello(d, [(560, 160), (530, 120), (500, 160), (560, 230), (620, 160), (590, 120), (560, 160)], (220, 30, 50), 10)
    disegni.append(im)
    # 3: la sala con la cupola e la statua sul piedistallo
    im = carta(); d = ImageDraw.Draw(im)
    pastello(d, [(362 + np.cos(t) * 330, 420 - np.sin(t) * 300) for t in np.linspace(0, np.pi, 40)], (70, 70, 90), 10)
    for k in range(1, 8):
        a = k * np.pi / 8
        pastello(d, [(362, 420), (362 + np.cos(a) * 330, 420 - np.sin(a) * 300)], (110, 110, 130), 5)
    d.rectangle([230, 800, 494, 880], outline=(60, 90, 200), width=9)
    campitura(d, (236, 806, 488, 874), (80, 120, 220), 12)
    medusa(d, 362, 610, 0.75, (235, 110, 170))
    onde(d, 930, (40, 150, 200))
    omino(d, 110, 800, 0.8, (220, 60, 50)); omino(d, 620, 800, 0.8, (40, 140, 60))
    disegni.append(im)
    # 4: bambino che dà la mano a un tentacolo, arcobaleno
    im = carta(); d = ImageDraw.Draw(im)
    for i, c in enumerate(((230, 50, 50), (240, 150, 30), (240, 220, 50), (60, 170, 70), (60, 110, 220), (140, 70, 190))):
        pastello(d, [(362 + np.cos(t) * (320 - i * 22), 400 - np.sin(t) * (300 - i * 22)) for t in np.linspace(0, np.pi, 40)], c, 12)
    medusa(d, 470, 520, 0.8, (235, 110, 170))
    omino(d, 200, 760, 1.1, (60, 80, 200))
    pastello(d, [(244, 750), (300, 740), (360, 735), (390, 720)], (235, 110, 170), 8)
    disegni.append(im)
    for i, im in enumerate(disegni):
        im = im.filter(ImageFilter.GaussianBlur(0.6))
        a = np.asarray(im, np.float32)
        # sbiadito, aloni d'acqua e bordi rovinati
        a = a * 0.86 + np.array([238, 232, 214]) * 0.14
        m = np.asarray(Image.fromarray((rng.random((5, 4)) * 255).astype(np.uint8)).resize((CW, CH), Image.BICUBIC), np.float32) / 255
        a *= (1 - 0.18 * np.clip(m * 1.6 - 0.8, 0, 1))[..., None]
        atl.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), ((i % 2) * CW, (i // 2) * CH))
    os.makedirs(cartella, exist_ok=True)
    _salva_jpg(atl, os.path.join(cartella, 'disegni_col.jpg'))
    print('disegni dei bambini ->', cartella)


def _rumore2(W, H, celle, rng):
    """Rumore morbido 0..1 (W x H) da una griglia casuale ingrandita (bicubica)."""
    g = (rng.random((celle[1], celle[0])) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(g).resize((W, H), Image.BICUBIC), np.float32) / 255


def _fbm2(W, H, rng, ottave=5, base=4):
    out = np.zeros((H, W), np.float32); amp = 1.0; tot = 0.0
    for o in range(ottave):
        n = base * 2 ** o
        out += amp * _rumore2(W, H, (n, max(1, n * H // W)), rng); tot += amp; amp *= 0.5
    return out / tot


def vetro_cupola_atlante(cartella, lato=2048, seme=21):
    """Lastre della cupola, 4 varianti in un atlante 2 x 2 (RGBA): sporca con rivoli di pioggia,
    molto sporca con alghe in basso, incrinata a ragnatela, appena velata. v = 0 in basso (verso il
    tamburo): lo sporco si accumula in basso e i rivoli scendono. Alfa = quanto copre il vetro.
    Scrive vetro_cupola_col.png (RGBA) e vetro_cupola_orm.jpg."""
    from PIL import ImageDraw
    rng = np.random.default_rng(seme)
    C = lato // 2
    col = np.zeros((lato, lato, 3), np.float32)
    alfa = np.zeros((lato, lato), np.float32)
    rough = np.zeros((lato, lato), np.float32)
    yy = np.linspace(1, 0, C)[:, None]           # 1 in alto nell'immagine = v alto = verso l'oculo
    xx = np.linspace(0, 1, C)[None, :]
    for k in range(4):
        r0, c0 = (k // 2) * C, (k % 2) * C
        f = _fbm2(C, C, rng, 5, 3)
        basso = np.clip(1 - yy * 1.6, 0, 1) ** 1.5          # fascia sporca in basso
        bordo = np.clip(1 - np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy)) / 0.06, 0, 1) ** 2
        # rivoli: colonne che scendono, più fitte in alto
        riv = np.zeros((C, C), np.float32)
        for _ in range(26 if k != 3 else 14):
            x0 = rng.uniform(0.05, 0.95) * C
            lung = rng.uniform(0.3, 1.0)
            dev = np.cumsum(rng.normal(0, 0.6, C))
            cx = x0 + dev
            t = np.arange(C)[:, None]
            w = rng.uniform(1.5, 4.0)
            inizio = rng.uniform(0, 0.4) * C
            m = (t > inizio) & (t < inizio + lung * C)
            riv += np.exp(-((np.arange(C)[None, :] - cx[:, None]) / w) ** 2) * m * rng.uniform(0.3, 0.8)
        riv = np.clip(riv, 0, 1)
        sporco = np.clip(0.35 * f + 0.55 * basso * (0.6 + 0.8 * f) + 0.5 * bordo * f, 0, 1)
        if k == 1:
            sporco = np.clip(sporco * 1.5 + 0.15, 0, 1)
        if k == 3:
            sporco *= 0.45
        a = 0.2 + 0.62 * sporco + 0.25 * riv
        c = np.ones((C, C, 3)) * np.array([0.11, 0.115, 0.11]) * (0.8 + 0.4 * f[..., None])
        c = c * (1 - sporco[..., None] * 0.3) + np.array([0.24, 0.22, 0.17]) * sporco[..., None] * 0.55
        if k == 1:   # alghe verdi-brune in basso
            alg = np.clip(basso * 1.3, 0, 1) * _smooth(0.38, 0.6, f)
            c = c * (1 - alg[..., None] * 0.6) + np.array([0.12, 0.17, 0.08]) * alg[..., None] * 0.6
            a = np.clip(a + 0.25 * alg, 0, 1)
        c = c * (1 - riv[..., None] * 0.25) + np.array([0.3, 0.32, 0.33]) * riv[..., None] * 0.25
        rg = np.clip(0.06 + 0.6 * sporco - 0.04 * riv, 0.03, 1)
        if k == 2:   # ragnatela di crepe da un punto d'impatto
            im = Image.new('L', (C, C), 0)
            d = ImageDraw.Draw(im)
            px, py = rng.uniform(0.35, 0.65) * C, rng.uniform(0.3, 0.6) * C
            for i in range(14):
                ang = i * 2 * np.pi / 14 + rng.normal(0, 0.12)
                pts = [(px, py)]
                x, y = px, py
                for j in range(9):
                    ang += rng.normal(0, 0.18)
                    passo = rng.uniform(40, 90)
                    x += np.cos(ang) * passo; y += np.sin(ang) * passo
                    pts.append((x, y))
                d.line(pts, fill=255, width=3)
            for rr in (60, 130, 220, 330):
                pts = []
                for i in range(41):
                    ang = i * 2 * np.pi / 40
                    q = rr * rng.uniform(0.85, 1.15)
                    pts.append((px + np.cos(ang) * q, py + np.sin(ang) * q))
                d.line(pts, fill=200, width=2)
            cr = np.asarray(im, np.float32) / 255
            c = c * (1 - cr[..., None]) + np.array([0.75, 0.78, 0.8]) * cr[..., None]
            a = np.clip(a + 0.75 * cr, 0, 1)
            rg = np.clip(rg + 0.4 * cr, 0, 1)
        col[r0:r0 + C, c0:c0 + C] = c
        alfa[r0:r0 + C, c0:c0 + C] = np.clip(a, 0, 1)
        rough[r0:r0 + C, c0:c0 + C] = rg
    rgba = np.dstack([lin_srgb(col) * 255, alfa * 255]).astype(np.uint8)
    os.makedirs(cartella, exist_ok=True)
    Image.fromarray(rgba, 'RGBA').save(os.path.join(cartella, 'vetro_cupola_col.png'), optimize=True)
    orm = np.dstack([np.ones_like(rough), rough, np.zeros_like(rough)])
    _salva_jpg(Image.fromarray((orm * 255 + 0.5).astype(np.uint8)), os.path.join(cartella, 'vetro_cupola_orm.jpg'), 92, colore=False)
    print('vetro della cupola ->', cartella)


def vetro_oblo(cartella, lato=1024, seme=9):
    """Vetro degli oblò, opaco (fuori è notte): quasi nero, con aloni di salsedine sui bordi e gocce
    secche. La rugosità segue lo sporco, così con SSR il vetro pulito riflette le luci rosse."""
    rng = np.random.default_rng(seme)
    yy, xx = np.mgrid[0:lato, 0:lato] / (lato - 1) * 2 - 1
    r = np.hypot(xx, yy)
    f = _fbm2(lato, lato, rng, 5, 4)
    sale = np.clip((r - 0.72) / 0.25, 0, 1) * (0.35 + 0.5 * f)
    gocce = np.zeros((lato, lato), np.float32)
    for _ in range(140):
        cx, cy, rr = rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), rng.uniform(0.01, 0.035)
        gocce += np.clip(1 - np.hypot(xx - cx, yy - cy) / rr, 0, 1) ** 0.5 * rng.uniform(0.3, 0.8)
    sporco = np.clip(sale + 0.35 * gocce + 0.15 * f, 0, 1)
    col = np.array([0.012, 0.016, 0.022]) * (1 - sporco[..., None]) + np.array([0.33, 0.33, 0.3]) * sporco[..., None] * 0.6
    rough = np.clip(0.04 + 0.7 * sporco, 0.03, 1)
    _salva_jpg(Image.fromarray((lin_srgb(col) * 255 + 0.5).astype(np.uint8)), os.path.join(cartella, 'vetro_oblo_col.jpg'))
    orm = np.dstack([np.ones_like(rough), rough, np.zeros_like(rough)])
    _salva_jpg(Image.fromarray((orm * 255 + 0.5).astype(np.uint8)), os.path.join(cartella, 'vetro_oblo_orm.jpg'), 92, colore=False)
    print('vetro degli oblò ->', cartella)


def malta(cartella, lato=512, seme=13):
    """Dove manca una piastrella da 12,5 cm: colla grigia a righe di spatola dentata, bordi con i
    resti della fuga, un po' di sporco. Colore, normal e ORM; 1 texture = 1 piastrella."""
    rng = np.random.default_rng(seme)
    yy, xx = np.mgrid[0:lato, 0:lato] / lato
    f = _fbm2(lato, lato, rng, 5, 4)
    righe = 0.5 + 0.5 * np.sin((yy + 0.02 * f) * 2 * np.pi * 9)            # creste della spatola
    bordo = np.minimum(np.minimum(xx, 1 - xx), np.minimum(yy, 1 - yy))
    fuga = np.clip(1 - bordo / 0.05, 0, 1)
    alt = 0.35 * righe * (1 - fuga) + 0.15 * f - 0.4 * np.clip(1 - bordo / 0.02, 0, 1) + 0.3 * fuga
    col = np.array([0.42, 0.41, 0.38]) * (0.75 + 0.35 * f[..., None]) * (0.85 + 0.15 * righe[..., None])
    col = col * (1 - fuga[..., None] * 0.35) + np.array([0.5, 0.5, 0.47]) * fuga[..., None] * 0.35
    col *= (1 - 0.35 * np.clip(f - 0.55, 0, 1)[..., None] * 2)
    os.makedirs(cartella, exist_ok=True)
    _salva_jpg(Image.fromarray((lin_srgb(col) * 255 + 0.5).astype(np.uint8)), os.path.join(cartella, 'malta_col.jpg'))
    _salva_jpg(Image.fromarray(_normali_da_altezza(alt.astype(np.float32), 6.0)), os.path.join(cartella, 'malta_nrm.jpg'), 92, colore=False)
    orm = np.dstack([0.75 + 0.25 * righe, np.full_like(f, 0.9), np.zeros_like(f)])
    _salva_jpg(Image.fromarray((np.clip(orm, 0, 1) * 255 + 0.5).astype(np.uint8)), os.path.join(cartella, 'malta_orm.jpg'), 92, colore=False)
    print('malta ->', cartella)


def deriva(nomi=None):
    from ambiente_palette import PALETTE
    nomi = nomi or list(PALETTE)
    for pn in nomi:
        pal = PALETTE[pn]
        cart = os.path.join(DERIVATE, pn)
        os.makedirs(cart, exist_ok=True)
        for i, (mn, r) in enumerate(sorted(pal['materiali'].items())):
            ric = r['ricetta']
            if ric == 'originale':
                continue
            seme = (sum(map(ord, pn + mn)) * 7919) % (2 ** 31)  # deterministico
            if 'bagnato' in r or mn == 'pavimento':  # pavimento bagnato: velo d'acqua a chiazze
                orm = orm_bagnato(r['sorgente'], r.get('bagnato', 0.9), r.get('extra', 1.0))
                _salva_jpg(Image.fromarray((np.clip(orm, 0, 1) * 255 + 0.5).astype(np.uint8)),
                           os.path.join(cart, f'{mn}_orm.jpg'), 92, colore=False)
            if r.get('col_da'):    # usa il colore di un altro materiale: niente texture di colore nuova
                print(pn, mn, 'orm')
                continue
            out = {'piastrelle': ricetta_piastrelle, 'tinta': ricetta_tinta, 'vernice': ricetta_vernice}[ric](r, seme)
            img = Image.fromarray((lin_srgb(out) * 255 + 0.5).astype(np.uint8))
            _salva_jpg(img, os.path.join(cart, f'{mn}_col.jpg'))
            print(pn, mn, ric)
        if pal.get('cartellone'):
            invecchia_cartellone(pn, pal['cartellone'])
        for k in pal.get('cartelloni', []):
            invecchia_cartellone(pn, k, f'cartellone_{k}_col.jpg')
        if 'torre' in pal['materiali']:
            grata_png(pn)
        if pn == 'sala_a':   # monumento della statua, vetri, piastrelle mancanti
            fregio_marino(cart)
            disegni_bambini(cart)
            vetro_cupola_atlante(cart)
            vetro_oblo(cart)
            malta(cart)
    dec = os.path.join(TEX, 'decal')
    os.makedirs(dec, exist_ok=True)
    colatura_png(os.path.join(dec, 'colatura_col.png'))
    rosa_venti_png(os.path.join(dec, 'rosa_venti_col.png'))


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'scarica':
        scarica()
    elif cmd == 'deriva':
        deriva(sys.argv[2:])
    else:
        print(__doc__)
