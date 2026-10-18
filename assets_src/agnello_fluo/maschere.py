"""Maschere di emissione per la proposta dell'agnellino fluorescente (i geni della medusa, idea dell'utente del 17
ottobre): si ricavano dalla texture del colore del peluche, stesse UV.
  cuciture: le cuciture (linee scure e sottili sul tessuto chiaro, trovate col black-hat) e i due bottoni-occhi;
  pelo: tutto il tessuto chiaro con una luminescenza a chiazze (rumore morbido), più forte sul muso.
Uso: /home/user/tools/blender-venv/bin/python assets_src/agnello_fluo/maschere.py
Uscita: godot/assets/models/bambini/proposte_fluo/*.png"""
import os
import cv2
import numpy as np

RADICE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
BAMBINI = os.path.join(RADICE, 'godot', 'assets', 'models', 'bambini')
USCITA = os.path.join(BAMBINI, 'proposte_fluo')
os.makedirs(USCITA, exist_ok=True)
# i due bottoni-occhi e il muso nella texture del colore dell'agnellino calmo (pixel su 2048)
OCCHI = [(427, 1251), (435, 1461)]
MUSO = (500, 1360)


def cuciture(colore, occhi=()):
    g = cv2.cvtColor(colore, cv2.COLOR_BGR2GRAY).astype(np.float32)
    nero = cv2.morphologyEx(g, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)))
    chiaro = cv2.GaussianBlur(g, (0, 0), 6) > 120          # solo sul tessuto chiaro (non sulle parti marroni)
    m = ((nero > 55) & chiaro).astype(np.uint8)
    # via la grana del tessuto e le macchie: le cuciture sono tratti sottili e allungati
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    tieni = np.zeros(n, bool)
    for i in range(1, n):
        w, h, a = st[i, 2], st[i, 3], st[i, 4]
        tieni[i] = max(w, h) >= 12 and a >= 10 and a < 0.6 * w * h + 1
    m = cv2.dilate(tieni[lab].astype(np.uint8), np.ones((2, 2), np.uint8)).astype(np.float32)
    for (x, y) in occhi:
        cv2.circle(m, (x, y), 30, 1.0, -1)
    m = cv2.GaussianBlur(m, (0, 0), 1.2)
    return np.clip(m * 1.6, 0, 1)


def pelo(colore, muso=MUSO):
    g = cv2.cvtColor(colore, cv2.COLOR_BGR2GRAY).astype(np.float32)
    chiaro = np.clip((cv2.GaussianBlur(g, (0, 0), 3) - 90) / 60, 0, 1)
    rng = np.random.default_rng(4)
    rum = np.zeros(g.shape, np.float32)
    for scala, peso in ((96, 0.6), (40, 0.3), (14, 0.1)):
        piccolo = rng.random((g.shape[0] // scala + 2, g.shape[1] // scala + 2)).astype(np.float32)
        rum += cv2.resize(piccolo, (g.shape[1], g.shape[0]), interpolation=cv2.INTER_CUBIC) * peso
    chiazze = np.clip((rum - 0.45) / 0.25, 0, 1)
    yy, xx = np.mgrid[0:g.shape[0], 0:g.shape[1]]
    vicino = np.exp(-(((xx - muso[0]) ** 2 + (yy - muso[1]) ** 2) / (2 * 150.0 ** 2))) if muso else 0.0
    return np.clip(chiaro * (0.25 + 0.45 * chiazze + 0.9 * vicino), 0, 1)


def salva(nome, m):
    cv2.imwrite(os.path.join(USCITA, nome), (m * 255).astype(np.uint8))
    print(nome, round(float(m.mean()), 3))


calmo = cv2.imread(os.path.join(BAMBINI, 'bambino_agnello_calmo_agnello_calmo_colore.jpg'))
salva('calmo_cuciture.png', cuciture(calmo, OCCHI))
salva('calmo_pelo.png', pelo(calmo))
occhio = cv2.imread(os.path.join(BAMBINI, 'bambino_agnello_occhio_agnello_occhio_colore.jpg'))
salva('rivelato_cuciture.png', cuciture(occhio))
salva('rivelato_pelo.png', pelo(occhio, None))
