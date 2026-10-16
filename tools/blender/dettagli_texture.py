"""Texture del kit di dettagli della sala (2K).

1) scarica le CC0 di ambientCG che il kit dell'ambiente non ha gia' (JPG 2K);
2) crea le texture derivate: asciugamani colorati, cartelli con soli disegni, incrostazioni e alghe con alfa,
   fogli di carta, cavi colorati, vernici dei corpi lampada.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/dettagli_texture.py
Licenza delle sorgenti: CC0 1.0 (vedi assets_src/ambiente_dettagli/LICENZE.md).
"""
import io, math, os, urllib.request, zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
RAD = os.path.normpath(os.path.join(QUI, '..', '..'))
OUT = os.path.join(RAD, 'assets_src', 'ambiente_dettagli', 'texture')
KIT = os.path.join(RAD, 'assets_src', 'ambiente', 'textures')
S = 2048
rng = np.random.default_rng(11)

CC0 = ['Rope001', 'Fabric061', 'Paper003', 'Rubber004', 'Metal021', 'Rust004', 'Fence008A', 'Moss002']
MAPPE = ('_Color', '_NormalGL', '_Roughness', '_Metalness', '_Opacity')


def scarica():
    for aid in CC0:
        out = os.path.join(OUT, 'cc0', aid)
        if os.path.isdir(out) and os.listdir(out):
            continue
        os.makedirs(out, exist_ok=True)
        url = f'https://ambientcg.com/get?file={aid}_2K-JPG.zip'
        data = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=600).read()
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for n in z.namelist():
                if n.endswith('.jpg') and any(m + '.' in n for m in MAPPE):
                    with open(os.path.join(out, os.path.basename(n).replace('_2K-JPG', '')), 'wb') as f:
                        f.write(z.read(n))
        print('scaricata', aid, sorted(os.listdir(out)))


def cc0(aid, mappa, mode='RGB', size=S):
    im = Image.open(os.path.join(OUT, 'cc0', aid, f'{aid}_{mappa}.jpg')).convert(mode)
    return im.resize((size, size), Image.LANCZOS) if im.size[0] != size else im


def arr(im):
    return np.asarray(im).astype(np.float32) / 255.0


def salva(a, nome, alfa=None):
    a = np.clip(a * 255 + 0.5, 0, 255).astype(np.uint8)
    d = os.path.join(OUT, 'derivate'); os.makedirs(d, exist_ok=True)
    if alfa is not None:
        al = np.clip(alfa * 255 + 0.5, 0, 255).astype(np.uint8)
        Image.fromarray(np.dstack([a, al])).save(os.path.join(d, nome + '.png'), optimize=True)
    else:
        Image.fromarray(a).save(os.path.join(d, nome + '.jpg'), quality=88)


def rumore(size, scala, ottave=4, seed=0):
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size] / size
    acc = np.zeros((size, size), np.float32); amp = 1.0
    for o in range(ottave):
        f = scala * 2 ** o
        for _ in range(6):
            fx, fy = r.integers(-f, f + 1, 2)
            acc += amp * np.sin(2 * math.pi * (fx * x + fy * y) + r.random() * 6.28)
        amp *= 0.5
    acc -= acc.min(); return acc / acc.max()


def piccolo_rumore(scala, ottave, seed, size=S):
    n = rumore(512, scala, ottave, seed)
    return np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)).astype(np.float32) / 255


# ---------------------------------------------------------------- asciugamani
def asciugamani():
    """Spugna bagnata e sporca, a righe anni '90. Colori della palette della sala."""
    base = arr(cc0('Fabric061', 'Color', 'L'))
    base = 0.75 + 0.5 * (base - base.mean())
    sporco = piccolo_rumore(2, 5, 3)
    righe = {'righe_turchese': [(0.1, 0.55, 0.6), (0.85, 0.82, 0.7)], 'righe_rosso': [(0.62, 0.12, 0.1), (0.85, 0.8, 0.68)],
             'tinta_giallo': [(0.82, 0.62, 0.15)], 'tinta_rosa': [(0.8, 0.38, 0.5)]}
    x = np.arange(S) / S
    for nome, cols in righe.items():
        if len(cols) == 2:
            m = ((np.floor(x * 12) % 2) == 0).astype(np.float32)[None, :].repeat(S, 0)
            col = np.array(cols[0]) * m[..., None] + np.array(cols[1]) * (1 - m[..., None])
        else:
            col = np.ones((S, S, 3)) * np.array(cols[0])
        out = col * (0.85 + 0.3 * (base[..., None] - 0.75))
        out = out * (1 - 0.2 * sporco[..., None]) + 0.2 * sporco[..., None] * np.array([0.3, 0.27, 0.2])
        out *= 0.8   # bagnato: piu' scuro
        salva(out, f'asciugamano_{nome}_col')


# ---------------------------------------------------------------- cartelli (solo disegni)
def _pittogramma(d, tipo, c, s, col):
    """Disegni semplici stile cartello da piscina, centrati in c, grandi s."""
    cx, cy = c
    def omino(x, y, k, corre=False, tuffo=False):
        d.ellipse([x - 0.09 * k, y - 0.42 * k, x + 0.09 * k, y - 0.24 * k], fill=col)
        if tuffo:
            d.line([(x - 0.35 * k, y + 0.05 * k), (x + 0.3 * k, y - 0.15 * k)], fill=col, width=int(0.1 * k))
            return
        d.line([(x, y - 0.22 * k), (x + (0.05 if corre else 0) * k, y + 0.12 * k)], fill=col, width=int(0.1 * k))
        if corre:
            d.line([(x + 0.05 * k, y + 0.12 * k), (x - 0.15 * k, y + 0.42 * k)], fill=col, width=int(0.09 * k))
            d.line([(x + 0.05 * k, y + 0.12 * k), (x + 0.25 * k, y + 0.3 * k)], fill=col, width=int(0.09 * k))
            d.line([(x, y - 0.12 * k), (x - 0.2 * k, y)], fill=col, width=int(0.08 * k))
            d.line([(x, y - 0.12 * k), (x + 0.22 * k, y - 0.2 * k)], fill=col, width=int(0.08 * k))
        else:
            d.line([(x, y + 0.12 * k), (x - 0.1 * k, y + 0.42 * k)], fill=col, width=int(0.09 * k))
            d.line([(x, y + 0.12 * k), (x + 0.1 * k, y + 0.42 * k)], fill=col, width=int(0.09 * k))
    if tipo == 'non_correre':
        omino(cx, cy + 0.05 * s, s, corre=True)
    elif tipo == 'non_tuffarsi':
        omino(cx, cy, s, tuffo=True)
        d.arc([cx - 0.4 * s, cy + 0.1 * s, cx + 0.4 * s, cy + 0.5 * s], 200, 340, fill=col, width=int(0.05 * s))
    elif tipo == 'pavimento_bagnato':
        omino(cx - 0.05 * s, cy - 0.05 * s, s * 0.9)
        for k in range(3):
            d.arc([cx - 0.45 * s + k * 0.3 * s, cy + 0.32 * s, cx - 0.2 * s + k * 0.3 * s, cy + 0.45 * s], 180, 360, fill=col, width=int(0.04 * s))
    elif tipo == 'uscita':
        omino(cx - 0.12 * s, cy, s * 0.9, corre=True)
        d.rectangle([cx + 0.18 * s, cy - 0.42 * s, cx + 0.42 * s, cy + 0.42 * s], outline=col, width=int(0.05 * s))
        d.polygon([(cx + 0.02 * s, cy + 0.36 * s), (cx + 0.16 * s, cy + 0.44 * s), (cx + 0.02 * s, cy + 0.52 * s)], fill=col)
    elif tipo == 'pronto_soccorso':
        w = 0.14 * s
        d.rectangle([cx - w, cy - 0.4 * s, cx + w, cy + 0.4 * s], fill=col)
        d.rectangle([cx - 0.4 * s, cy - w, cx + 0.4 * s, cy + w], fill=col)
    elif tipo == 'salvagente':
        d.ellipse([cx - 0.4 * s, cy - 0.4 * s, cx + 0.4 * s, cy + 0.4 * s], outline=col, width=int(0.17 * s))
    elif tipo == 'vietato_vetro':
        d.polygon([(cx - 0.1 * s, cy - 0.4 * s), (cx + 0.1 * s, cy - 0.4 * s), (cx + 0.12 * s, cy - 0.15 * s), (cx + 0.2 * s, cy + 0.05 * s),
                   (cx + 0.2 * s, cy + 0.42 * s), (cx - 0.2 * s, cy + 0.42 * s), (cx - 0.2 * s, cy + 0.05 * s), (cx - 0.12 * s, cy - 0.15 * s)], fill=col)
    elif tipo == 'mascotte':
        # la mascotte disegnata in modo infantile: testa tonda con un occhio, campana e tentacoli
        d.ellipse([cx - 0.22 * s, cy - 0.45 * s, cx + 0.22 * s, cy - 0.05 * s], fill=(130, 140, 220))
        d.ellipse([cx - 0.09 * s, cy - 0.33 * s, cx + 0.09 * s, cy - 0.15 * s], fill=(255, 255, 255))
        d.ellipse([cx - 0.05 * s, cy - 0.29 * s, cx + 0.05 * s, cy - 0.19 * s], fill=(230, 80, 150))
        d.chord([cx - 0.36 * s, cy - 0.08 * s, cx + 0.36 * s, cy + 0.42 * s], 180, 360, fill=(240, 150, 210))
        for k in range(7):
            x = cx - 0.3 * s + k * 0.1 * s
            d.line([(x, cy + 0.17 * s), (x + 0.04 * s * (1 if k % 2 else -1), cy + 0.45 * s)], fill=(200, 60, 150), width=int(0.03 * s))
    elif tipo == 'profondita':
        # onde e un bambino che nuota: zona profonda, solo disegno
        for k in range(3):
            y = cy + (k - 1) * 0.2 * s
            d.arc([cx - 0.45 * s, y - 0.08 * s, cx - 0.15 * s, y + 0.08 * s], 180, 360, fill=col, width=int(0.04 * s))
            d.arc([cx - 0.15 * s, y - 0.08 * s, cx + 0.15 * s, y + 0.08 * s], 0, 180, fill=col, width=int(0.04 * s))
            d.arc([cx + 0.15 * s, y - 0.08 * s, cx + 0.45 * s, y + 0.08 * s], 180, 360, fill=col, width=int(0.04 * s))


def cartelli():
    """Cartelli rettangolari 2:1 o quadrati, invecchiati: graffi, ruggine ai bordi, colature."""
    tipi = [('non_correre', 'divieto'), ('non_tuffarsi', 'divieto'), ('vietato_vetro', 'divieto'),
            ('pavimento_bagnato', 'avviso'), ('profondita', 'avviso'), ('uscita', 'verde'),
            ('pronto_soccorso', 'verde'), ('salvagente', 'info')]
    W = 1024
    rug = arr(cc0('Rust004', 'Color', size=W))
    for tipo, stile in tipi:
        im = Image.new('RGB', (W, W), (235, 232, 222)); d = ImageDraw.Draw(im)
        c = (W / 2, W / 2)
        if stile == 'divieto':
            _pittogramma(d, tipo, c, W * 0.75, (25, 25, 25))
            d.ellipse([W * 0.08, W * 0.08, W * 0.92, W * 0.92], outline=(200, 25, 25), width=int(W * 0.08))
            d.line([(W * 0.22, W * 0.22), (W * 0.78, W * 0.78)], fill=(200, 25, 25), width=int(W * 0.08))
        elif stile == 'avviso':
            d.polygon([(W / 2, W * 0.07), (W * 0.95, W * 0.9), (W * 0.05, W * 0.9)], fill=(240, 190, 20), outline=(25, 25, 25))
            d.line([(W / 2, W * 0.07), (W * 0.95, W * 0.9), (W * 0.05, W * 0.9), (W / 2, W * 0.07)], fill=(25, 25, 25), width=int(W * 0.04))
            _pittogramma(d, tipo, (W / 2, W * 0.6), W * 0.55, (25, 25, 25))
        elif stile == 'verde':
            d.rectangle([0, 0, W, W], fill=(20, 130, 70))
            _pittogramma(d, tipo, c, W * 0.8, (240, 240, 235))
        elif stile == 'info':
            d.rectangle([0, 0, W, W], fill=(25, 80, 170))
            _pittogramma(d, tipo, c, W * 0.8, (240, 240, 235))
            d.ellipse([W * 0.3, W * 0.3, W * 0.7, W * 0.7], outline=(220, 40, 40), width=int(W * 0.05))
        else:
            d.rectangle([0, 0, W, W], fill=(255, 225, 120))
            _pittogramma(d, tipo, c, W * 0.85, (25, 25, 25))
        a = arr(im)
        y, x = np.mgrid[0:W, 0:W] / W
        bordo = np.clip(1 - np.minimum.reduce([x, y, 1 - x, 1 - y]) * 14, 0, 1)
        n = piccolo_rumore(3, 5, hash(tipo) % 100, W)
        m_rug = np.clip(bordo * 1.2 + (n - 0.82) * 3, 0, 1)
        col = piccolo_rumore(5, 3, 7 + hash(tipo) % 50, W)
        colature = np.clip((np.asarray(Image.fromarray((col * 255).astype(np.uint8)).resize((W // 30, W // 2)).resize((W, W), Image.BICUBIC)) / 255.0 - 0.55) * 2.5, 0, 1)
        sb = 0.12 * piccolo_rumore(7, 4, 3, W)
        a = a * (1 - sb[..., None]) + sb[..., None] * np.array([0.8, 0.78, 0.7])     # sbiadito
        a = a * (1 - m_rug[..., None]) + rug * m_rug[..., None]
        a = a * (1 - 0.45 * colature[..., None])
        a *= 0.88
        salva(a, f'cartello_{tipo}_col')


# ---------------------------------------------------------------- incrostazioni, alghe secche, muffa (con alfa)
def macchie():
    musc = arr(cc0('Moss002', 'Color'))
    lum = musc.mean(-1)
    for nome, tinta, seed in (('alghe_secche', (0.32, 0.3, 0.16), 1), ('alghe_verdi', (0.18, 0.26, 0.12), 2),
                              ('calcare', (0.78, 0.76, 0.68), 3), ('muffa', (0.12, 0.13, 0.1), 4), ('ruggine_colata', (0.42, 0.2, 0.08), 5)):
        y, x = np.mgrid[0:S, 0:S] / S
        r = np.hypot(x - 0.5, y - 0.5) * 2
        n = piccolo_rumore(3, 6, seed)
        if nome == 'ruggine_colata':
            # colatura verticale: larga in alto, si assottiglia in basso
            cn = piccolo_rumore(6, 3, seed + 9)
            larg = 0.12 + 0.18 * (1 - y)
            forma = np.clip(1 - np.abs(x - 0.5 + 0.06 * (cn - 0.5)) / larg, 0, 1) * (1 - y ** 3)
            alfa = np.clip((forma * (0.6 + 0.6 * n)) * 1.6 - 0.25, 0, 1)
        else:
            fine = piccolo_rumore(14, 3, seed + 20)
            alfa = np.clip((1 - r) * 1.15 + (n - 0.5) * 1.2 - 0.25, 0, 1) ** 1.4
            alfa = alfa * (0.55 + 0.45 * fine) * (0.85 if nome != 'muffa' else 0.7)
        if nome.startswith('alghe'):
            col = np.array(tinta) * (0.6 + 0.8 * lum[..., None])
        else:
            col = np.array(tinta) * (0.75 + 0.5 * n[..., None])
        salva(col, f'macchia_{nome}_col', alfa)


# ---------------------------------------------------------------- carta, cavi, vernici
def varie():
    carta = arr(cc0('Paper003', 'Color'))
    for nome, t in (('bianco', (1.0, 0.98, 0.92)), ('giallo', (0.95, 0.85, 0.55)), ('azzurro', (0.7, 0.85, 0.95))):
        sp = piccolo_rumore(2, 5, len(nome))
        out = carta * np.array(t) * (0.7 + 0.3 * sp[..., None])
        # macchie d'acqua
        poz = np.clip((piccolo_rumore(1, 4, 9 + len(nome)) - 0.6) * 4, 0, 1)
        out = out * (1 - 0.35 * poz[..., None])
        # righe di un modulo (senza testo leggibile: solo righe)
        if nome != 'azzurro':
            yy = np.arange(S)
            righe = ((yy % 64) < 3).astype(np.float32)[:, None].repeat(S, 1) * 0.35
            righe[:, :160] = 0; righe[:, -160:] = 0; righe[:300] = 0
            out = out * (1 - righe[..., None])
        salva(out, f'carta_{nome}_col')
    gom = arr(cc0('Rubber004', 'Color', 'L'))
    for nome, t in (('nero', (0.06, 0.06, 0.06)), ('grigio', (0.35, 0.36, 0.36)), ('arancio', (0.75, 0.3, 0.06)), ('giallo', (0.8, 0.65, 0.1))):
        out = np.array(t) * (0.7 + 0.6 * gom[..., None])
        salva(out, f'cavo_{nome}_col')
    corda = arr(cc0('Rope001', 'Color'))
    salva(corda * np.array([0.82, 0.78, 0.66]) * 0.85, 'corda_sporca_col')
    salva(corda.mean(-1, keepdims=True).repeat(3, -1) * np.array([0.9, 0.35, 0.25]), 'corda_rossa_col')


if __name__ == '__main__':
    scarica()
    asciugamani(); cartelli(); macchie(); varie()
    print(sorted(os.listdir(os.path.join(OUT, 'derivate'))))
