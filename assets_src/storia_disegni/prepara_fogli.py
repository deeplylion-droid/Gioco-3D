"""Dai grezzi di Meshy (grezzi/) ai fogli del gioco: si taglia il foglio dallo sfondo della «scansione», si porta a
1024×1365 (3:4) e si mette la firma del bambino con la scatola (un quadratino turchese col sorriso, grezzi/FIRMA_v1.jpg)
in basso a destra, la stessa per tutti. La firma va anche sui due disegni che c'erano già (la piscina dei giocattoli e
gli acquari). Fogli opachi: JPG qualità 90. Il foglio unico con gli otto disegni affiancati (per il coordinatore) va in
anteprima/otto_disegni.jpg.
Uso: python3 prepara_fogli.py"""
import os
import numpy as np
from PIL import Image, ImageFilter

QUI = os.path.dirname(os.path.abspath(__file__))
RADICE = os.path.join(QUI, '..', '..')
GODOT = os.path.join(RADICE, 'godot')
USCITA = os.path.join(GODOT, 'assets', 'storia_disegni')
# (D2 e DZ rifatti su richiesta del coordinatore del 15 novembre: la vasca aperta vista dall'alto con una sola freccia;
# l'omino il più alto in mezzo, l'agnellino bambino in piedi, tutti per mano ai tentacoli. D4 orizzontale.)
SCELTI = {'D1': 'D1_v2', 'D2': 'D2_v7', 'DF': 'DF_v1', 'D3': 'D3_v2', 'D4': 'D4_v2', 'DZ': 'DZ_v3'}
## I fogli orizzontali (A3 orizzontale nel gioco): 4:3, ritagliati intorno al disegno.
ORIZZONTALI = {'D4'}
LATO = (1024, 1365)
# la firma: larga così rispetto al lato corto del foglio, a questa distanza dal bordo (in basso a destra)
FIRMA_LARGA = 0.10
# dove il foglio non si stacca bene dallo sfondo (carta chiara su fondo chiaro, legno chiaro): il taglio a mano, in px del
# grezzo (x0, y0, x1, y1), misurato su una griglia
TAGLI = {'D2_v2': (62, 52, 848, 1152), 'D3_v2': (40, 40, 852, 1160), 'D4_v2': (52, 302, 862, 910)}
FIRMA_MARGINE = 0.035


def taglia_foglio(im: Image.Image) -> Image.Image:
    """Il foglio di carta senza lo sfondo attorno: lo sfondo è il colore degli angoli dell'immagine; il foglio sono le
    righe e le colonne fatte per lo più d'altro. Se gli angoli sono già carta (il foglio riempie tutto) non si taglia."""
    a = np.asarray(im.convert('RGB')).astype(np.float32)
    h, w = a.shape[:2]
    k = max(4, int(min(h, w) * 0.01))
    angoli = np.concatenate([a[:k, :k].reshape(-1, 3), a[:k, -k:].reshape(-1, 3), a[-k:, :k].reshape(-1, 3),
                             a[-k:, -k:].reshape(-1, 3)])
    sfondo = np.median(angoli, axis=0)
    lum = a.mean(axis=2)
    carta = np.median(a[lum > np.percentile(lum, 70)], axis=0)
    if np.linalg.norm(sfondo - carta) < 25:
        return im
    maschera = np.linalg.norm(a - sfondo, axis=2) > 22
    righe = np.where(maschera.mean(axis=1) > 0.5)[0]
    colonne = np.where(maschera.mean(axis=0) > 0.5)[0]
    y0, y1, x0, x1 = righe[0], righe[-1], colonne[0], colonne[-1]
    # (appena dentro: niente bordo del foglio né ombra)
    dy, dx = int((y1 - y0) * 0.008), int((x1 - x0) * 0.008)
    return im.crop((x0 + dx, y0 + dy, x1 - dx, y1 - dy))


def a_misura(im: Image.Image, lato) -> Image.Image:
    """Al rapporto 3:4 tagliando il meno possibile, poi alla misura."""
    w, h = im.size
    r = lato[0] / lato[1]
    if w / h > r:
        nw = int(h * r)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / r)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return im.resize(lato, Image.LANCZOS)


def firma() -> Image.Image:
    """La firma come strato da moltiplicare: il quadratino col sorriso, la carta portata a bianco."""
    im = Image.open(os.path.join(QUI, 'grezzi', 'FIRMA_v1.jpg')).convert('RGB')
    a = np.asarray(im).astype(np.float32)
    # il turchese: verde e blu ben sopra il rosso
    t = (a[..., 1] - a[..., 0] > 40) & (a[..., 2] - a[..., 0] > 40)
    ys, xs = np.where(t)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    m = int(max(y1 - y0, x1 - x0) * 0.12)
    pezzo = a[y0 - m:y1 + m, x0 - m:x1 + m]
    # la carta attorno (il bordo del ritaglio) diventa bianco: diviso per il suo colore
    bordo = np.concatenate([pezzo[:3].reshape(-1, 3), pezzo[-3:].reshape(-1, 3),
                            pezzo[:, :3].reshape(-1, 3), pezzo[:, -3:].reshape(-1, 3)])
    carta = np.median(bordo, axis=0)
    strato = np.clip(pezzo / carta * 255.0, 0, 255)
    # i bordi del ritaglio sfumano a bianco (niente riquadro)
    h, w = strato.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(yy, h - 1 - yy), np.minimum(xx, w - 1 - xx)) / max(m, 1)
    f = np.clip(d, 0, 1)[..., None]
    strato = strato * f + 255.0 * (1 - f)
    return Image.fromarray(strato.astype(np.uint8))


def firma_su(im: Image.Image, strato: Image.Image) -> Image.Image:
    """La firma in basso a destra del disegno, come un pastello sul foglio: moltiplicata sulla carta; sui disegni
    scontornati (con l'alfa: la piscina, i tratti sul muro) in basso a destra della parte disegnata, coi suoi tratti
    opachi quanto sono scuri."""
    rgb = im.convert('RGB')
    w, h = rgb.size
    x0, y0, x1, y1 = 0, 0, w, h
    if im.mode == 'RGBA':
        x0, y0, x1, y1 = im.getchannel('A').point(lambda v: 255 if v > 128 else 0).getbbox()
    corto = min(x1 - x0, y1 - y0)
    lw = int(corto * FIRMA_LARGA)
    lh = int(lw * strato.size[1] / strato.size[0])
    s = np.asarray(strato.resize((lw, lh), Image.LANCZOS)).astype(np.float32)
    margine = FIRMA_MARGINE * (2.5 if im.mode == 'RGBA' else 1.0)    # (sui disegni scontornati dentro il bordo)
    x = x1 - int(corto * margine) - lw
    y = y1 - int(corto * margine) - lh
    base = np.asarray(rgb).astype(np.float32)
    zona = base[y:y + lh, x:x + lw]
    if im.mode != 'RGBA':
        base[y:y + lh, x:x + lw] = zona * (s / 255.0)
        return Image.fromarray(base.astype(np.uint8))
    alfa = np.asarray(im.getchannel('A')).astype(np.float32)
    scuro = np.clip((255.0 - s.min(axis=2)) / 160.0, 0, 1)
    za = alfa[y:y + lh, x:x + lw] / 255.0
    # dove c'è già il disegno si moltiplica, dove è trasparente il colore della firma con la sua opacità
    colore = np.clip(s / np.maximum(1.0 - scuro[..., None] * 0.0, 1e-3), 0, 255)
    nuovo = zona * (s / 255.0) * za[..., None] + colore * (1 - za[..., None])
    base[y:y + lh, x:x + lw] = nuovo
    alfa[y:y + lh, x:x + lw] = np.maximum(alfa[y:y + lh, x:x + lw], scuro * 255.0)
    out = Image.fromarray(base.astype(np.uint8))
    out.putalpha(Image.fromarray(alfa.astype(np.uint8)))
    return out


def main() -> None:
    os.makedirs(USCITA, exist_ok=True)
    strato = firma()
    fogli = []
    for nome, grezzo in SCELTI.items():
        im = Image.open(os.path.join(QUI, 'grezzi', grezzo + '.jpg'))
        foglio = im.crop(TAGLI[grezzo]) if grezzo in TAGLI else taglia_foglio(im)
        f = firma_su(a_misura(foglio, (LATO[1], LATO[0]) if nome in ORIZZONTALI else LATO), strato)
        f.save(os.path.join(USCITA, f'disegno_{nome.lower()}.jpg'), quality=90)
        fogli.append((nome, f))
    # i due che c'erano già: dagli originali (senza firma) in assets_src, così si può rifare
    giocattoli = os.path.join(GODOT, 'assets', 'models', 'enigma_giocattoli', 'disegno_piscina.png')
    acquari = os.path.join(GODOT, 'assets', 'enigma_acquari', 'disegno_bambini.jpg')
    for percorso, orig in [(giocattoli, os.path.join(QUI, 'originali', 'disegno_piscina.png')),
                           (acquari, os.path.join(QUI, 'originali', 'disegno_bambini.jpg'))]:
        if not os.path.exists(orig):
            os.makedirs(os.path.dirname(orig), exist_ok=True)
            Image.open(percorso).save(orig, quality=95) if orig.endswith('.jpg') else Image.open(percorso).save(orig)
        im = Image.open(orig)
        f = firma_su(im, strato)
        if percorso.endswith('.jpg'):
            f.save(percorso, quality=90)
        else:
            f.save(percorso)
        fogli.append((os.path.basename(percorso), f))
    # il foglio unico per il coordinatore
    H = 600
    pezzi = [f.convert('RGB').resize((int(f.size[0] * H / f.size[1]), H)) for _, f in fogli]
    tot = Image.new('RGB', (sum(p.size[0] for p in pezzi) + 20 * (len(pezzi) + 1), H + 40), (60, 60, 60))
    x = 20
    for p in pezzi:
        tot.paste(p, (x, 20))
        x += p.size[0] + 20
    os.makedirs(os.path.join(QUI, 'anteprima'), exist_ok=True)
    tot.save(os.path.join(QUI, 'anteprima', 'otto_disegni.jpg'), quality=88)
    # e i tre rifatti dopo il primo giro del coordinatore (D2, D4 orizzontale, DZ)
    tre = [f for n, f in fogli if n in ('D2', 'D4', 'DZ')]
    pezzi = [f.convert('RGB').resize((int(f.size[0] * H / f.size[1]), H)) for f in tre]
    tot = Image.new('RGB', (sum(p.size[0] for p in pezzi) + 20 * (len(pezzi) + 1), H + 40), (60, 60, 60))
    x = 20
    for p in pezzi:
        tot.paste(p, (x, 20))
        x += p.size[0] + 20
    tot.save(os.path.join(QUI, 'anteprima', 'tre_rifatti.jpg'), quality=88)
    print('fatti:', [n for n, _ in fogli])


if __name__ == '__main__':
    main()
