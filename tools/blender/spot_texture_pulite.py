"""Texture "da nuove" della sala principale, solo per lo spot VHS della crociera (la nave anni prima).

Stesse ricette e stessi colori della palette sala_a (ambiente_palette.py), ma senza lo sporco: piastrelle
lucide con le fughe pulite, vernice senza ruggine, intonaco senza crepe, ottone lucidato, vetro della cupola
trasparente, cartelloni non invecchiati. Le scrive in godot/assets/spot/texture/ con il nome della texture
derivata (o CC0) che sostituiscono: la scena dello spot (godot/scripts/spot/sala_pulita.gd) le scambia per nome.

Uso (dalla radice del repository):
  /home/user/tools/blender-venv/bin/python tools/blender/spot_texture_pulite.py
Serve il CC0 scaricato (ambiente_texture.py scarica).
"""
import os, sys
import numpy as np
import cv2
from PIL import Image

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import ambiente_texture as T  # noqa: E402
from ambiente_palette import PALETTE, COMUNI  # noqa: E402

USCITA = os.path.join(T.RADICE, 'godot', 'assets', 'spot', 'texture')
PAL = PALETTE['sala_a']['materiali']


def _salva(a_lin, nome, colore=True):
    img = Image.fromarray((np.clip(T.lin_srgb(a_lin) if colore else a_lin, 0, 1) * 255 + 0.5).astype(np.uint8))
    T._salva_jpg(img, os.path.join(USCITA, nome), 92, colore=colore)
    print('pulita', nome)


def _rumore(seme, scala=64, ampiezza=0.03):
    """Variazione morbida e leggera (la vernice e la vetroresina nuove non sono piatte come la plastica)."""
    rng = np.random.default_rng(seme)
    n = rng.normal(0, 1, (T.RIS // scala + 2, T.RIS // scala + 2)).astype(np.float32)
    im = Image.fromarray(n).resize((T.RIS, T.RIS), Image.BICUBIC)
    return 1.0 + np.asarray(im, np.float32) * ampiezza


def _seme(mn):
    return (sum(map(ord, 'spot' + mn)) * 7919) % (2 ** 31)


def _fughe(src):
    """Maschera delle fughe come griglia regolare: la media su tutte le piastrelle della stessa posizione
    nella piastrella (nella sorgente le piastrelle rotte o scheggiate sembrerebbero fughe)."""
    G = T.leggi(src, 'orm')[..., 1]
    m = T._smooth(0.33, 0.55, G) if src == 'mosaico_blu' else T._smooth(0.42, 0.62, G)
    n = T.CATALOGO[src]['griglia']
    N = m.shape[0]
    P = int(np.ceil(N / n))
    r = cv2.resize(m.astype(np.float32), (P * n, P * n), interpolation=cv2.INTER_LINEAR)
    media = T._smooth(0.25, 0.6, r.reshape(n, P, n, P).mean(axis=(0, 2)))
    return cv2.resize(np.tile(media, (n, n)), (N, N), interpolation=cv2.INTER_LINEAR)


def piastrelle(mn, r):
    """Piastrelle nuove: ogni piastrella del suo colore con uno scarto piccolo, fughe dritte e pulite."""
    src = r['sorgente']
    n = T.CATALOGO[src]['griglia']
    fuga = _fughe(src)
    N = fuga.shape[0]
    ix = (np.arange(N) // (N / n)).astype(int) % n
    rng = np.random.default_rng(_seme(mn))
    colori = [T._hexlin(c) for c, _ in r['colori']]
    pesi = np.array([w for _, w in r['colori']], dtype=np.float64)
    scelta = rng.choice(len(colori), size=(n, n), p=pesi / pesi.sum())
    if r.get('schema') == 'scacchi':
        ii, jj = np.meshgrid(np.arange(n), np.arange(n), indexing='ij')
        scelta = (ii + jj) % len(colori)
    tab = np.stack([colori[k] for k in scelta.ravel()]).reshape(n, n, 3)
    tab *= rng.normal(1.0, 0.018, size=(n, n, 1))
    tinta = tab[ix[:, None], ix[None, :]] * _rumore(_seme(mn) + 1, 128, 0.012)[..., None]
    gr = T._hexlin(r['fuga'])[None, None, :] * _rumore(_seme(mn) + 2, 32, 0.04)[..., None]
    return tinta * (1 - fuga[..., None]) + gr * fuga[..., None]


def tinta(mn, r):
    """Colore pieno con un filo del dettaglio della sorgente (la grana dell'antiscivolo, la vetroresina)."""
    col = T.srgb_lin(T.leggi(r['sorgente'], 'col'))
    Ls = T._lum(col)
    alto = cv2.GaussianBlur(Ls.astype(np.float32), (0, 0), 24)
    det = np.clip(1 + (Ls / np.maximum(alto, 1e-4) - 1) * 0.5, 0.75, 1.25)   # solo la grana fine, niente aloni
    return T._hexlin(r['colore'])[None, None, :] * det[..., None] * _rumore(_seme(mn), 96, 0.02)[..., None]


def vernice(mn, r):
    """Vernice nuova su tutta la superficie: niente ruggine né intonaco scoperto."""
    return T._hexlin(r['colore'])[None, None, :] * _rumore(_seme(mn), 96, 0.025)[..., None] * np.ones((T.RIS, T.RIS, 1))


def ottone():
    col = T.srgb_lin(T.leggi('ottone', 'col'))
    L = T._lum(col)
    fondo = cv2.GaussianBlur(L.astype(np.float32), (0, 0), 40)
    det = np.clip(1 + (L / np.maximum(fondo, 1e-4) - 1) * 0.3, 0.85, 1.15)
    return T._hexlin('#c9a24a')[None, None, :] * det[..., None]


def orm(r_rugosita, fuga=None, r_fuga=0.7, ao=None):
    """ORM pulito: rugosità uniforme (più alta nelle fughe), occlusione della sorgente se c'è, niente metallo."""
    G = np.full((T.RIS, T.RIS), r_rugosita, np.float32)
    if fuga is not None:
        G = G * (1 - fuga) + r_fuga * fuga
    R = np.ones_like(G) if ao is None else ao
    return np.stack([R, G * _rumore(5, 64, 0.04), np.zeros_like(G)], axis=2)


def normale_attenuata(src, quanto):
    """La normal map della sorgente avvicinata alla piatta (quanto = 0 piatta, 1 com'era)."""
    nrm = T.leggi(src, 'nrm')
    piatta = np.array([0.5, 0.5, 1.0], np.float32)
    v = (nrm - piatta) * quanto + piatta
    return v


def vetro_cupola():
    """Atlante 2 x 2 delle lastre come quello del gioco, ma tutte limpide: un velo azzurrino appena."""
    lato = 2048
    a = np.full((lato, lato, 4), 0, np.uint8)
    a[..., 0:3] = (np.array([0.80, 0.90, 0.95]) * 255).astype(np.uint8)
    a[..., 3] = int(0.06 * 255)
    Image.fromarray(a, 'RGBA').save(os.path.join(USCITA, 'vetro_cupola_col.png'), optimize=True)
    o = np.zeros((lato, lato, 3), np.uint8)
    o[..., 0] = 255
    o[..., 1] = int(0.04 * 255)
    Image.fromarray(o).save(os.path.join(USCITA, 'vetro_cupola_orm.png'), optimize=True)
    print('pulita vetro_cupola')


def cartelloni():
    """Cartelloni della sala senza invecchiare: le grafiche di partenza, tagliate come nel gioco."""
    src = os.path.join(T.RADICE, 'assets_src', 'ambiente', 'cartelloni')
    for k in ('p1', 'p2', 'p3'):
        f = os.path.join(src, f'cartellone_{k}.png')
        if os.path.exists(f):
            T._salva_jpg(Image.open(f).convert('RGB').resize((2048, 1152), Image.LANCZOS),
                         os.path.join(USCITA, f'cartellone_{k}_col.jpg'), 92)
            print('pulita cartellone', k)
    poster = os.path.join(T.RADICE, 'assets_src', 'ambienti_interni', 'poster')
    for chiave, f in (('medusa', 'cartellone_medusa.png'), ('bagnino', 'poster_bagnino.png')):
        p = os.path.join(poster, f)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert('RGB')
        w, h = im.size
        nw = int(round(h * 2 / 3))
        if nw <= w:
            im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        else:
            nh = int(round(w * 3 / 2))
            im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        T._salva_jpg(im.resize((1024, 1536), Image.LANCZOS), os.path.join(USCITA, f'cartellone_{chiave}_col.jpg'), 92)
        print('pulita cartellone', chiave)


def tutto():
    os.makedirs(USCITA, exist_ok=True)
    for mn, r in sorted(PAL.items()):
        if r.get('col_da') or r['ricetta'] == 'originale' or mn == 'cemento':
            continue
        out = {'piastrelle': piastrelle, 'tinta': tinta, 'vernice': vernice}[r['ricetta']](mn, r)
        _salva(out, f'{mn}_col.jpg')
    _salva(ottone(), 'ottone_col.jpg')
    # ORM e normali delle sorgenti CC0 (i GLB le usano col nome della sorgente)
    for src, rug in (('piastrelle_bianche', 0.16), ('piastrelle_turchesi', 0.14)):
        f = _fughe(src)
        _salva(orm(rug, f, 0.75, T.leggi(src, 'orm')[..., 0] * 0.35 + 0.65), f'{src}_orm.jpg', colore=False)
    _salva(orm(0.42), 'metallo_verniciato_orm.jpg', colore=False)
    _salva(normale_attenuata('metallo_verniciato', 0.12), 'metallo_verniciato_nrm.jpg', colore=False)
    _salva(orm(0.8), 'intonaco_scrostato_orm.jpg', colore=False)
    _salva(normale_attenuata('intonaco_scrostato', 0.1), 'intonaco_scrostato_nrm.jpg', colore=False)
    _salva(orm(0.22), 'ottone_orm.jpg', colore=False)
    _salva(orm(0.55), 'pavimento_orm.jpg', colore=False)
    _salva(orm(0.35), 'vetroresina_orm.jpg', colore=False)
    vetro_cupola()
    cartelloni()


if __name__ == '__main__':
    tutto()
