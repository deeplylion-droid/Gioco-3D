"""Le texture degli stendardi dell'inseguimento (nota dell'utente del 6 novembre: «stendardi giganti appesi nel vuoto
dietro, nella distanza, niente disegni ai, falli come s'è fossero lenzuoli appesi e colorati dai bambini»).

Lenzuoli veri, vecchi, colorati dai bambini del club della nave (lo stesso club delle sagome di enigmi):
- la stoffa: un lenzuolo di cotone a tinta unita sbiadita, con la trama, le macchie e l'orlo cucito;
- i disegni col pastello del gioco (assets_src/scarabocchi/pastello.py), i colori della scatola da 12 un po' spenti; il
  tratto è largo come quello di un pastello a cera grosso su un lenzuolo (4-6 cm);
- la firma è la manina (disegni.manina): il contorno della mano, 8-10 cm, un colore per bambino, in basso. Mai nomi né
  scritte;
- gli anni e l'acqua: i colori sbiaditi, la riga dell'umidità che è salita dal fondo, qualche strappo (nell'alfa).
Niente immagini fatte con l'IA: tutto procedurale.

Scrive per ogni lenzuolo, in godot/assets/ambiente/inseguimento/stendardi/:
- stendardo_<n>.png: colore e alfa (gli strappi);
- stendardo_<n>_luce.png: solo i segni a pastello (il «filo di luce» dei pastelli fosforescenti, se serve).
Uso: /home/user/tools/blender-venv/bin/python assets_src/stendardi/teli.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.normpath(os.path.join(QUI, '..', '..'))
sys.path.insert(0, os.path.join(RADICE, 'assets_src', 'scarabocchi'))
from pastello import Pastello, rumore, COLORI  # noqa: E402
import disegni  # noqa: E402
from motivi import sole, omino, onde, medusa, nave  # noqa: E402

USCITA = os.path.join(RADICE, 'godot', 'assets', 'ambiente', 'inseguimento', 'stendardi')
# la texture: 1024 x 1536 per un lenzuolo di 3 x 4,5 m (2,9 mm per pixel)
W, H = 1024, 1536
# il pastello finge pixel più piccoli: i tratti dei motivi (12-18 mm) diventano larghi 4-6 cm sul lenzuolo
MM_PASTELLO = 0.75

# le stoffe: il colore del lenzuolo nuovo (poi sbiadisce)
STOFFE = {
    'bianco': (226, 220, 204), 'azzurro': (168, 196, 214), 'rosa': (222, 182, 190), 'giallo': (230, 214, 160),
}


def stoffa(colore, seme):
    """Il lenzuolo: tinta sbiadita a chiazze, la trama del cotone, l'orlo cucito, qualche macchia vecchia."""
    rng = np.random.default_rng(seme)
    c = np.array(STOFFE[colore], np.float32) / 255.0
    # sbiadito dalla luce e dagli anni, non in modo uniforme
    chiazze = rumore((H, W), seme + 10, 160)
    sbiadito = 0.18 + 0.12 * chiazze
    base = c * (1 - sbiadito[..., None]) + np.array([0.86, 0.84, 0.78], np.float32) * sbiadito[..., None]
    # la trama: righe fini orizzontali e verticali (ordito e trama), appena
    y = np.arange(H, dtype=np.float32)[:, None]
    x = np.arange(W, dtype=np.float32)[None, :]
    trama = 0.5 + 0.25 * np.sin(x * 2.1 + rng.random() * 6) * np.sin(y * 1.9) + 0.25 * rng.random((H, W)).astype(np.float32)
    base *= (0.94 + 0.06 * trama)[..., None]
    # l'orlo: una fascia ripiegata di 3 cm sui quattro lati, con la cucitura
    orlo = 10
    bordo = np.zeros((H, W), np.float32)
    bordo[:orlo, :] = bordo[-orlo:, :] = 1.0
    bordo[:, :orlo] = bordo[:, -orlo:] = 1.0
    base *= (1.0 - 0.07 * bordo)[..., None]
    for k in range(0, W, 7):
        for yy in (orlo + 2, H - orlo - 3):
            base[yy:yy + 1, k:k + 4] *= 0.86
    for k in range(0, H, 7):
        for xx in (orlo + 2, W - orlo - 3):
            base[k:k + 4, xx:xx + 1] *= 0.86
    # macchie vecchie (ruggine, tè, colla), poche e larghe
    for i in range(int(rng.integers(3, 6))):
        cx, cy, r = rng.uniform(0.1, 0.9) * W, rng.uniform(0.1, 0.85) * H, rng.uniform(25, 90)
        d = np.sqrt((x - cx) ** 2 + ((y - cy) * 1.3) ** 2)
        m = np.clip(1.0 - d / r, 0, 1) ** 1.5 * (0.6 + 0.4 * rumore((H, W), seme + 20 + i, 18))
        base = base * (1 - 0.18 * m[..., None]) + np.array([0.55, 0.42, 0.28], np.float32) * 0.18 * m[..., None]
    return base


def umidita(rgb, alfa_disegno, seme, sale=0.22):
    """La riga dell'umidità: l'acqua salita dal fondo per capillarità, fino a [sale] dell'altezza, con l'orlo bruno
    frastagliato; sotto la stoffa è più scura e i colori più spenti, con la muffa a puntini."""
    y = np.arange(H, dtype=np.float32)[:, None] / H
    # (l'orlo sale e scende largo, con qualche lingua più alta dove la stoffa ha bevuto di più)
    frangia = (rumore((1, W), seme + 30, 160)[0] - 0.5) * 0.09 + (rumore((1, W), seme + 31, 45)[0] - 0.5) * 0.035 \
        + (rumore((1, W), seme + 34, 9)[0] - 0.5) * 0.006
    linea = 1.0 - sale + frangia[None, :]
    sotto = np.clip((y - linea) * 40.0, 0, 1)
    orlo = np.exp(-((y - linea) * 110.0) ** 2) * (0.6 + 0.4 * rumore((H, W), seme + 35, 30))
    rgb = rgb * (1 - 0.16 * sotto[..., None]) + np.array([0.42, 0.38, 0.3], np.float32) * 0.16 * sotto[..., None]
    rgb = rgb * (1 - 0.35 * orlo[..., None]) + np.array([0.46, 0.34, 0.2], np.float32) * 0.35 * orlo[..., None]
    muffa = (np.random.default_rng(seme + 32).random((H, W)) > 0.996).astype(np.float32)
    muffa = np.asarray(Image.fromarray((muffa * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), np.float32) / 255
    muffa *= sotto * rumore((H, W), seme + 33, 40)
    rgb = rgb * (1 - 0.5 * muffa[..., None]) + np.array([0.22, 0.24, 0.18], np.float32) * 0.5 * muffa[..., None]
    alfa_disegno = alfa_disegno * (1 - 0.45 * sotto)
    return rgb, alfa_disegno


def strappi(seme, quanti=3):
    """L'alfa degli strappi: qualche squarcio frastagliato vicino al fondo e ai lati, e l'angolo in basso sfilacciato."""
    rng = np.random.default_rng(seme + 40)
    m = Image.new('L', (W, H), 255)
    d = ImageDraw.Draw(m)
    for i in range(quanti):
        lato = rng.choice(['basso', 'sinistra', 'destra', 'mezzo'])
        if lato == 'basso':
            x0, y0 = rng.uniform(0.15, 0.85) * W, H
            ang = -math.pi / 2 + rng.normal(0, 0.4)
            lungo = rng.uniform(0.06, 0.16) * H
        elif lato == 'mezzo':
            x0, y0 = rng.uniform(0.25, 0.75) * W, rng.uniform(0.55, 0.8) * H
            ang = rng.uniform(0, math.pi)
            lungo = rng.uniform(0.03, 0.06) * H
        else:
            x0 = 0 if lato == 'sinistra' else W
            y0 = rng.uniform(0.45, 0.9) * H
            ang = (0 if lato == 'sinistra' else math.pi) + rng.normal(0, 0.3)
            lungo = rng.uniform(0.05, 0.12) * W
        # uno squarcio: due labbra frastagliate che si aprono poco
        pts_a, pts_b = [], []
        n = 14
        for k in range(n + 1):
            t = k / n
            px = x0 + math.cos(ang) * lungo * t
            py = y0 + math.sin(ang) * lungo * t
            apertura = (1 - t) * rng.uniform(4, 11) + rng.uniform(0, 2)
            nx, ny = -math.sin(ang), math.cos(ang)
            pts_a.append((px + nx * apertura + rng.normal(0, 1.5), py + ny * apertura + rng.normal(0, 1.5)))
            pts_b.append((px - nx * apertura + rng.normal(0, 1.5), py - ny * apertura + rng.normal(0, 1.5)))
        d.polygon(pts_a + pts_b[::-1], fill=0)
    # l'angolo in basso a destra sfilacciato (fili che pendono)
    for k in range(40):
        xx = W - int(rng.uniform(0, 70))
        d.line([(xx, H - int(rng.uniform(0, 30))), (xx + int(rng.normal(0, 3)), H)], fill=0, width=1)
    return np.asarray(m, np.float32) / 255.0


def firme(colori, x0, y0, seme, passo=46):
    """Le manine dei bambini che l'hanno colorato, in fila storta nell'angolo in basso: il contorno della mano, 8-10 cm
    (raggio 15-18 pixel), col tratto fine, un colore per bambino. Su un foglio suo."""
    f = Pastello(W, H, seme + 50, mm=6.5)   # (il tratto di manina, 13 mm, esce di 2 pixel: 6 mm sul lenzuolo)
    for i, c in enumerate(colori):
        disegni.manina(f, x0 + i * passo + f.rng.normal(0, 5), y0 + f.rng.normal(0, 7), f.rng.uniform(15, 18), c,
                       ang=f.rng.normal(0, 0.35))
    return f


# ------------------------------------------------------------------ i quattro lenzuoli
def mare_nave_sole(p):
    sole(p, W * 0.24, H * 0.17, W * 0.13, raggi=11)
    nave(p, W * 0.52, H * 0.5, W * 0.62, colore='blu')
    onde(p, W * 0.04, W * 0.96, H * 0.6, H * 0.014, colore='azzurro', righe=3)
    disegni.pesce(p, W * 0.3, H * 0.72, W * 0.16, 'arancio', verso=1)
    disegni.pesce(p, W * 0.72, H * 0.7, W * 0.13, 'verde', verso=-1)


def per_mano(p):
    sole(p, W * 0.8, H * 0.13, W * 0.09, raggi=9)
    disegni.bambini_per_mano(p, W * 0.06, W * 0.94, H * 0.66, H * 0.4, ['rosso', 'verde', 'viola', 'arancio', 'azzurro'])
    onde(p, W * 0.04, W * 0.96, H * 0.72, H * 0.012, colore='azzurro', righe=2)


def jilly_coi_pesci(p):
    disegni.jilly_sorridente(p, W * 0.5, H * 0.3, W * 0.24)
    for i, (c, fx, fy) in enumerate([('verde', 0.2, 0.55), ('arancio', 0.78, 0.5), ('viola', 0.3, 0.68), ('giallo', 0.7, 0.66)]):
        disegni.pesce(p, W * fx, H * fy, W * 0.15, c, verso=1 if i % 2 else -1)
    onde(p, W * 0.04, W * 0.96, H * 0.76, H * 0.012, colore='azzurro', righe=2)


def jilly_alta(p):
    """Il lenzuolo recente (regola del GDD: nei disegni recenti Jilly è alta coi tentacoli sopra i bambini piccoli):
    più scuro, Jilly grande in alto e i tentacoli che scendono, due bambini piccoli sotto. Nessuno prende nessuno."""
    medusa(p, W * 0.5, H * 0.2, W * 0.3, colore='viola', tentacoli=8, occhio=True)
    for fx in (0.36, 0.62):
        omino(p, W * fx, H * 0.76, H * 0.14, 'nero')
    onde(p, W * 0.04, W * 0.96, H * 0.8, H * 0.01, colore='blu', righe=1)


TELI = [
    # nome, stoffa, disegno, colori delle manine, sbiadito della cera, quanto è salita l'umidità, strappi, seme
    ('stendardo_1', 'bianco', mare_nave_sole, ['rosso', 'verde', 'blu', 'giallo', 'viola'], 0.18, 0.2, 3, 101),
    ('stendardo_2', 'azzurro', per_mano, ['arancio', 'rosa', 'verde', 'rosso'], 0.22, 0.26, 2, 202),
    ('stendardo_3', 'giallo', jilly_coi_pesci, ['blu', 'rosso', 'verde_chiaro', 'viola', 'arancio', 'azzurro'], 0.25, 0.18, 3, 303),
    ('stendardo_4', 'rosa', jilly_alta, ['nero', 'marrone', 'rosso'], 0.12, 0.3, 4, 404),
]


def fai(nome, tinta, disegno, manine, sbiad, sale, n_strappi, seme):
    p = Pastello(W, H, seme, mm=MM_PASTELLO)
    disegno(p)
    cera = np.asarray(p.finisci(bagnato=0.25, sbiadito=sbiad), np.float32) / 255.0
    # le manine sopra (tratto fine, poco sbiadite: le ripassano a ogni festa del club)
    f = np.asarray(firme(manine, W * 0.09, H * 0.9, seme).finisci(bagnato=0.1, sbiadito=sbiad * 0.5), np.float32) / 255.0
    af = f[..., 3:4]
    cera = np.dstack([cera[..., :3] * (1 - af) + f[..., :3] * af, cera[..., 3] + f[..., 3] * (1 - cera[..., 3])])
    rgb = stoffa(tinta, seme)
    a = cera[..., 3]
    rgb, a = umidita(rgb, a, seme, sale)
    # la cera sulla stoffa: copre, ma la trama passa un po' (il cotone assorbe)
    col = rgb * (1 - a[..., None]) + cera[..., :3] * a[..., None] * (0.9 + 0.1 * rgb / np.maximum(rgb.max(), 1e-3))
    alfa = strappi(seme, n_strappi)
    out = np.dstack([np.clip(col, 0, 1), alfa])
    Image.fromarray((out * 255).astype(np.uint8), 'RGBA').save(os.path.join(USCITA, nome + '.png'), optimize=True)
    luce = np.clip(a[..., None] * cera[..., :3], 0, 1) * alfa[..., None]
    Image.fromarray((luce * 255).astype(np.uint8), 'RGB').resize((W // 2, H // 2), Image.LANCZOS).save(
        os.path.join(USCITA, nome + '_luce.png'), optimize=True)
    print('scritto', nome)


if __name__ == '__main__':
    os.makedirs(USCITA, exist_ok=True)
    solo = sys.argv[1:]
    for t in TELI:
        if not solo or t[0] in solo:
            fai(*t)
