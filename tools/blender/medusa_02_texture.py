"""Passo 2: pulisce la texture base color (e la normal map) dai puntini di sporco.

Metodo: per ogni parte (maschere UV dal passo 1) si cercano i puntini piccoli
  - scuri: black-hat morfologico sulla luminanza;
  - chiari o colorati (solo sulla pelle): differenza di colore dalla mediana locale;
si tengono solo le macchie piccole (non le linee lunghe dei capelli o le venature della campana),
si allarga un po' la maschera e si riempie con l'inpaint di OpenCV (Telea).
L'occhio dipinto e' protetto (maschera UV allargata). Sulla campana e sui moncherini, organici, si
tolgono solo le macchie molto scure: le loro venature e cellule sono disegno, non sporco.
Gli stessi punti si puliscono anche nella normal map (i puntini hanno anche rilievo) su pelle e capelli.

Scrive:
  assets_src/medusa/tex/medusa_basecolor_pulita.jpg
  assets_src/medusa/tex/medusa_normal_pulita.png
  assets_src/medusa/build/maschera_sporco.png, build/anteprime/pulizia_*.jpg (controllo)
  assets_src/medusa/build/medusa_02_texture.blend (materiali collegati alle texture pulite)
Gli originali restano in meshy_base.glb e in build/originali/.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_02_texture.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import cv2  # noqa: E402

ORIGINALI = os.path.join(BUILD, 'originali')
BASE_ORIG = os.path.join(ORIGINALI, 'medusa_basecolor_originale.jpg')
NORMAL_ORIG = os.path.join(ORIGINALI, 'medusa_normal_originale.png')
BASE_PULITA = os.path.join(TEX, 'medusa_basecolor_pulita.jpg')
NORMAL_PULITA = os.path.join(TEX, 'medusa_normal_pulita.png')
MR = os.path.join(TEX, 'medusa_mr.jpg')

# soglie (luminanza 0-1 e Delta E in Lab 0-255)
PARAMETRI = {
    # parte: (soglia black-hat, soglia colore (None = no), area max px, lato max px)
    'pelle': (0.040, 9.0, 350, 40),
    'capelli': (0.045, None, 350, 40),
    # secondo passaggio sui capelli: graffi un po' piu' lunghi ma sottili (le pieghe delle ciocche sono piu' lunghe)
    'capelli_graffi': (0.060, None, 450, 75),
    'campana': (0.150, None, 200, 24),
    'moncherini': (0.150, None, 200, 24),
}
KERNEL = 15          # diametro del kernel morfologico (px): i puntini sono di 2-12 px
KERNEL_GRAFFI = 25   # kernel piu' grande per i graffetti scuri sui capelli
PROTEZIONE_OCCHIO = 6


def maschere_parti(me, size):
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    nomi = [m.name[2:] for m in me.materials]
    return {nome: rasterizza_uv(me, mi == k, size) > 0 for k, nome in enumerate(nomi)}


def trova_sporco(img, parti):
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    L = lab[..., 0].astype(np.float32) / 255.
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (KERNEL, KERNEL))
    bh = cv2.morphologyEx(L, cv2.MORPH_BLACKHAT, k)
    med = cv2.medianBlur(img, 21)
    dE = np.linalg.norm(lab.astype(np.float32) - cv2.cvtColor(med, cv2.COLOR_BGR2LAB).astype(np.float32), axis=2)
    occhio = cv2.dilate(parti['occhio_dipinto'].astype(np.uint8),
                        np.ones((2 * PROTEZIONE_OCCHIO + 1,) * 2, np.uint8)) > 0
    k2 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (KERNEL_GRAFFI, KERNEL_GRAFFI))
    bh2 = cv2.morphologyEx(L, cv2.MORPH_BLACKHAT, k2)
    totale = np.zeros(L.shape, bool)
    for nome, (t_bh, t_col, amax, lmax) in PARAMETRI.items():
        parte = nome.split('_')[0] if nome != 'occhio_dipinto' else nome
        m = parti[parte] & ((bh2 if nome.endswith('graffi') else bh) > t_bh)
        if t_col is not None:
            m |= parti[parte] & (dE > t_col)
        m &= ~occhio
        n, labc, st, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), connectivity=8)
        ok = (st[:, cv2.CC_STAT_AREA] <= amax) & (np.maximum(st[:, cv2.CC_STAT_WIDTH], st[:, cv2.CC_STAT_HEIGHT]) <= lmax)
        ok[0] = False
        m = ok[labc]
        log(f'  sporco su {nome}: {int(ok.sum())} macchie, {int(m.sum())} px')
        totale |= m
    return cv2.dilate(totale.astype(np.uint8) * 255, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))


def main():
    t0 = time.time()
    apri(os.path.join(BUILD, 'medusa_01_parti.blend'))
    ob = bpy.data.objects['Medusa']
    img = cv2.imread(BASE_ORIG)
    parti = maschere_parti(ob.data, img.shape[0])
    maschera = trova_sporco(img, parti)
    cv2.imwrite(os.path.join(BUILD, 'maschera_sporco.png'), maschera)
    pulita = cv2.inpaint(img, maschera, 4, cv2.INPAINT_TELEA)
    from PIL import Image
    Image.fromarray(pulita[..., ::-1]).save(BASE_PULITA, quality=95, subsampling=0)  # 4:4:4, niente perdita di colore
    log('scritta', os.path.relpath(BASE_PULITA, REPO))
    # normal map: stessi punti, solo pelle e capelli (dove i puntini hanno rilievo)
    nrm = cv2.imread(NORMAL_ORIG)
    if nrm.shape[:2] != img.shape[:2]:
        m2 = cv2.resize(maschera, nrm.shape[1::-1], interpolation=cv2.INTER_NEAREST)
    else:
        m2 = maschera
    zona = (parti['pelle'] | parti['capelli']).astype(np.uint8) * 255
    zona = cv2.resize(zona, nrm.shape[1::-1], interpolation=cv2.INTER_NEAREST)
    m2 = cv2.bitwise_and(cv2.dilate(m2, np.ones((3, 3), np.uint8)), zona)
    nrm_p = cv2.inpaint(nrm, m2, 4, cv2.INPAINT_TELEA)
    cv2.imwrite(NORMAL_PULITA, nrm_p, [cv2.IMWRITE_PNG_COMPRESSION, 9])
    log('scritta', os.path.relpath(NORMAL_PULITA, REPO))
    # anteprime di controllo (prima | maschera | dopo)
    ant = os.path.join(BUILD, 'anteprime'); os.makedirs(ant, exist_ok=True)
    for i, (x0, y0) in enumerate([(2100, 2200), (1400, 700), (1500, 1900), (600, 1200)]):
        a = img[y0:y0 + 500, x0:x0 + 500]; b = pulita[y0:y0 + 500, x0:x0 + 500]
        m = cv2.cvtColor(maschera[y0:y0 + 500, x0:x0 + 500], cv2.COLOR_GRAY2BGR)
        cv2.imwrite(os.path.join(ant, f'pulizia_{i}.jpg'), np.hstack([a, m, b]), [cv2.IMWRITE_JPEG_QUALITY, 90])
    # materiali sulle texture pulite
    for mat in ob.data.materials:
        nt = mat.node_tree
        nt.nodes['base'].image = immagine(BASE_PULITA)
        nt.nodes['normal'].image = immagine(NORMAL_PULITA, non_color=True)
    for im in list(bpy.data.images):
        if im.users == 0:
            bpy.data.images.remove(im)
    salva(os.path.join(BUILD, 'medusa_02_texture.blend'))
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
