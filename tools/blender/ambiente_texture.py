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


def orm_bagnato(sorgente, quanto):
    """ORM con un velo d'acqua irregolare: la rugosità scende a chiazze.
    Le pozzanghere vere NON vanno qui (si ripeterebbero a ogni texture): in Godot si fanno con
    decal o con una maschera in spazio mondo nello shader del pavimento."""
    orm = leggi(sorgente, 'orm')
    m = _macchie(1.0)
    film = _smooth(0.2, 0.55, m)
    # bagnato: tutto un po' più lucido, le chiazze molto di più (in Godot si vede con SSR)
    orm[..., 1] = orm[..., 1] * (1 - 0.35 * quanto) * (1 - 0.55 * film * quanto)
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
            out = {'piastrelle': ricetta_piastrelle, 'tinta': ricetta_tinta, 'vernice': ricetta_vernice}[ric](r, seme)
            if mn == 'pavimento':  # pavimento bagnato: velo d'acqua a chiazze
                orm = orm_bagnato(r['sorgente'], 0.9)
                _salva_jpg(Image.fromarray((np.clip(orm, 0, 1) * 255 + 0.5).astype(np.uint8)),
                           os.path.join(cart, f'{mn}_orm.jpg'), 92, colore=False)
            img = Image.fromarray((lin_srgb(out) * 255 + 0.5).astype(np.uint8))
            _salva_jpg(img, os.path.join(cart, f'{mn}_col.jpg'))
            print(pn, mn, ric)
        if pal.get('cartellone'):
            invecchia_cartellone(pn, pal['cartellone'])
        for k in pal.get('cartelloni', []):
            invecchia_cartellone(pn, k, f'cartellone_{k}_col.jpg')
        if 'torre' in pal['materiali']:
            grata_png(pn)
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
