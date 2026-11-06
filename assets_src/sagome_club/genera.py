"""Le sagome del club dei bambini della nave (scelta A dell'utente del 6 novembre: cartonati nelle condotte
dell'inseguimento, 12 animali del mare, 4 per vasca, con età diverse; Jilly fra i disegni A). Per ogni sagoma scrive:
- la faccia: godot/assets/sagome_club/<nome>.png, il cartone dato di bianco (tempera stesa male, col marrone del
  cartone che si vede ai bordi e dove la mano è passata poco) e sopra il pastello (assets_src/scarabocchi/pastello.py);
  l'età: "nuova" coi colori vivi, "media" coi colori opachi, la carta un po' gialla e uno strappo riparato con lo
  scotch ingiallito, "vecchia" slavata, ingiallita, col fondo gonfio d'acqua fino a una riga di marea e la muffa;
- il contorno tagliato a mano (in metri, nel sistema della sagoma: x a destra, y in su, l'origine in basso al centro)
  in assets_src/sagome_club/sagome.json, con la misura e l'età (lo legge posa.py). La sagoma 3D (spessa 5 mm, coi fori delle
  legature) la fa assets_src/sagome_club/posa.py.
Solo disegni: niente lettere, numeri o frecce. Niente immagini fatte con l'IA (nota dell'utente sugli stendardi del
6 novembre, «niente disegni ai», che vale anche qui).
Uso: /home/user/tools/blender-venv/bin/python assets_src/sagome_club/genera.py [cartella anteprime]
"""
import json
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
sys.path.insert(0, os.path.join(QUI, '..', 'scarabocchi'))
from pastello import Pastello, rumore  # noqa: E402
import animali  # noqa: E402

RADICE = os.path.normpath(os.path.join(QUI, '..', '..'))
USCITA = os.path.join(RADICE, 'godot', 'assets', 'sagome_club')
# pixel per metro (1,25 mm per pixel: un pastello largo 12-17 mm fa un segno di 10-14 pixel)
PPM = 800
# il margine di cartone attorno al disegno, da tagliare (m)
MARGINE = 0.025
# l'età di ogni sagoma: una nuova per vasca (vedi posa.py per dove stanno)
ETA = {
    'balena': 'vecchia', 'stella': 'vecchia', 'tartaruga': 'media', 'granchio': 'nuova',
    'pesce_palla': 'media', 'polpo': 'vecchia', 'delfino': 'media', 'squalo': 'nuova',
    'pesce': 'nuova', 'cavalluccio': 'vecchia', 'razza': 'media', 'foca': 'vecchia',
}
SEMI = {n: 4100 + i * 37 for i, n in enumerate(animali.ANIMALI)}

BIANCO = np.array([232, 228, 214], np.float32) / 255.0
KRAFT = np.array([168, 128, 84], np.float32) / 255.0


def disegna(nome):
    fn, w, h = animali.ANIMALI[nome]
    W, H = int(round(w * PPM)), int(round(h * PPM))
    m = int(MARGINE * PPM) + 6
    p = Pastello(W + 2 * m, H + 2 * m, SEMI[nome], mm=1000.0 / PPM)
    p.sagome = []
    # si disegna nel riquadro interno (spostato del margine)
    class Sposta:
        def __init__(s, p):
            s.p = p
        def __getattr__(s, k):
            return getattr(s.p, k)
    _orig = {k: getattr(p, k) for k in ('tratto', 'riempi')}
    p.tratto = lambda pts, *a, **kw: _orig['tratto']([(x + m, y + m) for x, y in pts], *a, **kw)
    p.riempi = lambda pts, *a, **kw: _orig['riempi']([(x + m, y + m) for x, y in pts], *a, **kw)
    fn(p, W, H)
    p.sagome = [[(x + m, y + m) for x, y in s] for s in p.sagome]
    return p, W + 2 * m, H + 2 * m


def taglio(p, Wt, Ht, rng):
    """La forma da ritagliare: le forme piene e i segni del pastello, allargate del margine e chiuse (le forbici non
    entrano fra un tentacolo e l'altro), poi il contorno fatto a mano: tratti dritti di 2-4 cm, un po' storti."""
    maschera = np.zeros((Ht, Wt), np.uint8)
    for s in p.sagome:
        cv2.fillPoly(maschera, [np.array(s, np.int32)], 255)
    tratti = np.zeros((Ht, Wt), np.uint8)
    for _, im in p.livelli:
        a = np.asarray(im.resize((Wt, Ht), Image.BILINEAR))
        tratti = np.maximum(tratti, (a > 40).astype(np.uint8) * 255)
    maschera = np.maximum(maschera, tratti)
    r = int(MARGINE * PPM)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    maschera = cv2.dilate(maschera, k)
    kc = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(0.06 * PPM), int(0.06 * PPM)))
    maschera = cv2.morphologyEx(maschera, cv2.MORPH_CLOSE, kc)
    cont, _ = cv2.findContours(maschera, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cont, key=cv2.contourArea)[:, 0, :].astype(np.float64)
    # i colpi di forbice: un punto ogni 2-4 cm lungo il contorno, spostato di qualche millimetro verso fuori
    lungo = np.cumsum(np.r_[0, np.linalg.norm(np.diff(c, axis=0), axis=1)])
    pts = []
    s = 0.0
    while s < lungo[-1]:
        i = int(np.searchsorted(lungo, s))
        i = min(i, len(c) - 1)
        q = c[i]
        # la normale verso fuori (dal centro dei vicini)
        a, b = c[max(0, i - 6)], c[min(len(c) - 1, i + 6)]
        t = b - a
        n = np.array([t[1], -t[0]])
        n /= (np.linalg.norm(n) + 1e-9)
        pts.append(q + n * rng.uniform(0.0, 0.004) * PPM)
        s += rng.uniform(0.02, 0.04) * PPM
    pts = np.array(pts)
    # (il contorno di OpenCV gira in senso orario nell'immagine: in metri, con y in su, diventa antiorario)
    return pts, maschera


def faccia(p, Wt, Ht, maschera, pts, eta, rng, seme):
    """La faccia: tempera bianca sul cartone, il pastello sopra, l'età."""
    dentro = np.zeros((Ht, Wt), np.uint8)
    cv2.fillPoly(dentro, [pts.astype(np.int32)], 255)
    # la tempera: pennellate (rumore allungato in orizzontale), più sottile ai bordi del taglio e qua e là
    pennellate = rumore((Ht, Wt // 8 + 1), seme + 11, 6)
    pennellate = np.asarray(Image.fromarray((pennellate * 255).astype(np.uint8)).resize((Wt, Ht), Image.BICUBIC), np.float32) / 255.0
    dal_bordo = cv2.distanceTransform((dentro > 0).astype(np.uint8), cv2.DIST_L2, 5) / PPM
    copre = np.clip((dal_bordo - 0.004 - 0.012 * rumore((Ht, Wt), seme + 12, 40)) / 0.01, 0, 1)
    copre *= np.clip(0.75 + pennellate * 0.5, 0, 1)
    rgb = KRAFT[None, None, :] * (1 - copre[..., None]) + BIANCO[None, None, :] * (0.94 + 0.06 * pennellate[..., None]) * copre[..., None]
    sbiadito = {'nuova': 0.0, 'media': 0.12, 'vecchia': 0.32}[eta]
    bagnato = {'nuova': 0.0, 'media': 0.08, 'vecchia': 0.45}[eta]
    cera = np.asarray(p.finisci(bagnato=bagnato, sbiadito=sbiadito), np.float32) / 255.0
    a = cera[..., 3:4]
    rgb = rgb * (1 - a) + cera[..., :3] * a
    if eta != 'nuova':
        # la carta ingiallita
        giallo = np.array([0.97, 0.94, 0.86] if eta == 'media' else [0.9, 0.82, 0.64], np.float32)
        rgb *= giallo
        # i colpi: macchie piccole dove la tempera e la cera sono venute via
        colpi = rumore((Ht, Wt), seme + 13, 12)
        via = np.clip((colpi - (0.86 if eta == 'media' else 0.78)) * 8, 0, 1)[..., None]
        rgb = rgb * (1 - via) + KRAFT * 0.9 * via
    if eta == 'media':
        # uno strappo riparato con lo scotch, ingiallito: la crepa scura e la striscia sopra
        x0 = rng.uniform(0.25, 0.55) * Wt
        y0 = rng.uniform(0.0, 0.2) * Ht
        lungo = rng.uniform(0.18, 0.3) * Ht
        crepa = np.zeros((Ht, Wt), np.uint8)
        q = [(x0, y0)]
        for i in range(10):
            q.append((q[-1][0] + rng.normal(0, 6), q[-1][1] + lungo / 10))
        cv2.polylines(crepa, [np.array(q, np.int32)], False, 255, 3)
        crepa = cv2.GaussianBlur(crepa, (5, 5), 0)[..., None] / 255.0
        rgb = rgb * (1 - crepa * 0.75) + np.array([0.25, 0.18, 0.1]) * crepa * 0.75
        nastro = np.zeros((Ht, Wt), np.uint8)
        c = (int(x0 + rng.normal(0, 4)), int(y0 + lungo * 0.5))
        rr = ((c[0], c[1]), (int(0.05 * PPM), int(lungo * 1.1)), float(rng.normal(0, 6)))
        box = cv2.boxPoints(rr).astype(np.int32)
        cv2.fillPoly(nastro, [box], 255)
        nastro = cv2.GaussianBlur(nastro, (3, 3), 0)[..., None] / 255.0
        bordo = cv2.morphologyEx((nastro[..., 0] * 255).astype(np.uint8), cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8))[..., None] / 255.0
        rgb = rgb * (1 - nastro * 0.35) + np.array([0.86, 0.68, 0.32]) * nastro * 0.35
        rgb = rgb * (1 - bordo * 0.3)
    if eta == 'vecchia':
        # il fondo gonfio d'acqua fino alla riga di marea (ondulata), più scuro e bruno; la riga è più scura
        alto = rng.uniform(0.14, 0.24) * Ht
        xs = np.arange(Wt)
        riga = Ht - alto + 0.02 * PPM * np.sin(xs / Wt * 6.3 * rng.uniform(1.5, 3) + rng.uniform(0, 6)) + 0.01 * PPM * rumore((1, Wt), seme + 14, 20)[0]
        yy = np.arange(Ht)[:, None]
        sotto = np.clip((yy - riga[None, :]) / (0.01 * PPM), 0, 1)
        orlo = np.exp(-((yy - riga[None, :]) / (0.004 * PPM)) ** 2)
        macchia = rumore((Ht, Wt), seme + 15, 30)
        scuro = (0.62 + 0.15 * macchia)[..., None]
        rgb = rgb * (1 - sotto[..., None]) + rgb * np.array([0.82, 0.7, 0.52]) * scuro * sotto[..., None]
        rgb = rgb * (1 - orlo[..., None] * 0.45) + np.array([0.3, 0.22, 0.12]) * orlo[..., None] * 0.45
        # la muffa: puntini grigio-verdi a gruppi, in basso e lungo i bordi
        semi_m = rumore((Ht, Wt), seme + 16, 18)
        punti = np.random.default_rng(seme + 17).random((Ht, Wt))
        vicino = np.clip(1.2 - dal_bordo / 0.06, 0, 1) + sotto * 0.8
        muffa = ((punti > 0.985 - 0.02 * semi_m * vicino) & (semi_m * vicino > 0.45)).astype(np.float32)
        muffa = cv2.GaussianBlur(muffa, (3, 3), 0)[..., None]
        rgb = rgb * (1 - muffa * 0.8) + np.array([0.24, 0.27, 0.2]) * muffa * 0.8
    # fuori dal taglio il colore del bordo (così le mipmap non fanno l'alone scuro)
    fuori = dentro == 0
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
    img = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    for _ in range(4):
        dil = cv2.dilate(img, k)
        img[fuori] = dil[fuori]
    return Image.fromarray(img, 'RGB')


def genera(anteprime=None):
    os.makedirs(USCITA, exist_ok=True)
    dati = {}
    for nome in animali.ANIMALI:
        rng = np.random.default_rng(SEMI[nome] + 5)
        p, Wt, Ht = disegna(nome)
        pts, maschera = taglio(p, Wt, Ht, rng)
        im = faccia(p, Wt, Ht, maschera, pts, ETA[nome], rng, SEMI[nome])
        # la texture: larghezza e altezza multiple di 4 (per la compressione), il contorno in proporzione
        W4, H4 = (Wt + 3) // 4 * 4, (Ht + 3) // 4 * 4
        tela = Image.new('RGB', (W4, H4))
        tela.paste(im, (0, 0))
        tela.paste(im.crop((Wt - 1, 0, Wt, Ht)).resize((W4 - Wt, Ht)) if W4 > Wt else im.crop((0, 0, 1, 1)), (Wt, 0))
        tela.save(os.path.join(USCITA, nome + '.png'), optimize=True)
        base_y = pts[:, 1].max()
        cx = (pts[:, 0].min() + pts[:, 0].max()) * 0.5
        contorno = [[round((x - cx) / PPM, 4), round((base_y - y) / PPM, 4)] for x, y in pts]
        dati[nome] = {
            'eta': ETA[nome],
            'contorno': contorno,
            # dal punto (x, y) della sagoma all'uv della texture: u = (x * PPM + cx) / W4, v = (base_y - y * PPM) / H4
            'uv': [round(cx / W4, 6), round(PPM / W4, 6), round(base_y / H4, 6), round(PPM / H4, 6)],
            'misura': [round((pts[:, 0].max() - pts[:, 0].min()) / PPM, 3), round((base_y - pts[:, 1].min()) / PPM, 3)],
        }
        print('%-12s %-8s %.2f x %.2f m, %d punti del taglio' % (nome, ETA[nome], dati[nome]['misura'][0], dati[nome]['misura'][1], len(pts)))
        if anteprime:
            os.makedirs(anteprime, exist_ok=True)
            prova = np.asarray(tela.convert('RGB')).copy()
            cv2.polylines(prova, [pts.astype(np.int32)], True, (255, 0, 255), 2)
            Image.fromarray(prova).save(os.path.join(anteprime, nome + '.jpg'), quality=85)
    with open(os.path.join(QUI, 'sagome.json'), 'w') as f:
        json.dump(dati, f, indent=1)


if __name__ == '__main__':
    genera(sys.argv[1] if len(sys.argv) > 1 else None)
