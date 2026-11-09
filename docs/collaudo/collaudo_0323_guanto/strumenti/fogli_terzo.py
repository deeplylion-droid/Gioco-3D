"""Fogli del terzo ricontrollo del guanto (5325f596). Uso: fogli_terzo.py <cartella guanto> <docs/proposte/guanto/dopo>"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
G, APP = sys.argv[1], sys.argv[2]
Q = sys.argv[3].split(",") if len(sys.argv) > 3 else ["1", "2", "3", "4", "5"]
T, N, V = os.path.join(G, 'terzo'), os.path.join(G, 'nuovo'), os.path.join(G, 'vecchio_punti')
FO = os.path.join(T, 'fogli'); os.makedirs(FO, exist_ok=True)
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16)
BAR = 24
def casella(img, titolo, w):
    h = round(img.height * w / img.width)
    o = Image.new('RGB', (w, h + BAR), (20, 20, 20)); o.paste(img.resize((w, h), Image.LANCZOS), (0, BAR))
    ImageDraw.Draw(o).text((6, 3), titolo, font=FONT, fill=(235, 235, 235)); return o
def vuota(w, h, t):
    o = Image.new('RGB', (w, h + BAR), (20, 20, 20)); ImageDraw.Draw(o).text((6, 3), t, font=FONT, fill=(160, 160, 160)); return o
def griglia(c, col, nome):
    r = [c[i:i + col] for i in range(0, len(c), col)]
    W = max(sum(x.width for x in rr) for rr in r); H = sum(max(x.height for x in rr) for rr in r)
    o = Image.new('RGB', (W, H), (20, 20, 20)); y = 0
    for rr in r:
        x = 0
        for cc in rr:
            o.paste(cc, (x, y)); x += cc.width
        y += max(cc.height for cc in rr)
    o.save(os.path.join(FO, nome), quality=88); print('foglio', nome, o.size)
def apri(d, n):
    p = os.path.join(d, n + '.jpg')
    return Image.open(p).convert('RGB') if os.path.exists(p) else None
# 1: gli stessi ingrandimenti della 0.3.23, sui tre modelli
if "1" in Q:
    VECCHI = [('indice_vecchio_strappo_davanti', 'punta dell\'indice, davanti'), ('indice_vecchio_strappo_sinistra', 'punta dell\'indice, da sinistra'),
              ('indice_piega_nuova_sinistra', 'dov\'era la conchetta, da sinistra'), ('indice_piega_nuova_davanti', 'dov\'era la conchetta, davanti'),
              ('indice_base_destra', 'base dell\'indice, da destra'), ('indice_base_destra_alto', 'base dell\'indice, da destra e sopra'),
              ('indice_bordo_alto_davanti', 'bordo alto dell\'indice, davanti'), ('indice_bordo_alto_sinistra', 'bordo alto dell\'indice, da sinistra'),
              ('spiraglio_anulare_mignolo', 'fra anulare e mignolo, da destra')]
    W1 = 426; c = []
    for n, t in VECCHI:
        for d, v in [(V, '0.3.22'), (os.path.join(N, 'scatti'), '98ded0d2'), (os.path.join(T, 'scatti'), '5325f596')]:
            im = apri(d, 'punto_' + n)
            c.append(casella(im, '%s: %s' % (v, t), W1) if im else vuota(W1, 240, v + ': -'))
    griglia(c, 3, '1_ingrandimenti_tre_modelli.jpg')
# 2: gli ingrandimenti nuovi, con la luce della camera e con le luci del livello
if "2" in Q:
    NUOVI = [('indice_base_destra_quota_vera', 'base dell\'indice alla quota vera (y -0,202)'), ('indice_base_destra_quota_vera_sotto', 'lo stesso, da sotto'),
             ('pollice_fuori_ex_fossetta', 'pollice, fuori, dov\'era la fossetta'), ('pollice_fuori_ex_fossetta_davanti', 'lo stesso, davanti'),
             ('pollice_sopra', 'pollice, da sopra'), ('mignolo_sotto_sinistra', 'mignolo, sotto, angolo sinistro (2,2 mm)'),
             ('mignolo_sotto_destra', 'mignolo, sotto, angolo destro (1,7 mm)'), ('dorso_anulare_mignolo', 'dorso fra anulare e mignolo (piega 126°)')]
    W2 = 560; c = []
    for n, t in NUOVI:
        for suf, ts in [('', 'luce della camera'), ('_luce_del_livello', 'luci del livello')]:
            im = apri(os.path.join(T, 'scatti'), 'punto_' + n + suf)
            c.append(casella(im, '%s, %s' % (t, ts), W2) if im else vuota(W2, 315, t + ': -'))
    griglia(c, 2, '2_ingrandimenti_nuovi.jpg')
# 3: da vicino, i sette lati
if "3" in Q:
    c = []
    for v, t in [('destra', 'da destra'), ('sinistra', 'da sinistra'), ('davanti', 'davanti'), ('dietro', 'dietro'), ('sotto', 'da sotto'),
                 ('dietro_sotto_polsino', 'polsino, da dietro e sotto'), ('dietro_destra_polsino', 'polsino, da dietro e da destra')]:
        im = apri(os.path.join(T, 'scatti'), 'vicino_fermo_' + v)
        if im: c.append(casella(im, 'fermo, ' + t, 640))
    griglia(c, 2, '3_vicino_fermo.jpg')
# 4: le 16 pose approvate e le stesse rifatte oggi (stesso ordine della pagina approvata)
if "4" in Q:
    POSE = ['accovacciato', 'acqua', 'aspirando', 'camminando', 'correndo', 'fermo', 'scala', 'sparando']
    app = Image.open(os.path.join(APP, 'guanto_da_vicino_in_tutte_le_pose.jpg')).convert('RGB')
    TWp, THp = app.width // 4, app.height // 4
    rif = Image.new('RGB', app.size, (20, 20, 20)); k = 0; stat = []
    for p in POSE:
        for v in ['dita', 'dorso']:
            im = apri(os.path.join(T, 'approvati_rifatti'), 'posa_%s_%s' % (p, v))
            r, cc = divmod(k, 4); k += 1
            if im is None: continue
            im = im.resize((TWp, THp), Image.LANCZOS); rif.paste(im, (cc * TWp, r * THp))
            a = np.asarray(app.crop((cc * TWp, r * THp, (cc + 1) * TWp, (r + 1) * THp)), float); b = np.asarray(im, float)
            # il bianco del guanto: i pixel chiari e poco colorati in tutti e due
            m = (a.min(2) > 150) & (a.max(2) - a.min(2) < 40) & (b.min(2) > 150) & (b.max(2) - b.min(2) < 40)
            stat.append((p, v, np.abs(a - b).mean(), m.sum(), a[m].mean(0) if m.any() else None, b[m].mean(0) if m.any() else None))
    c = [casella(app, 'approvati (A/A/A, docs/proposte/guanto/dopo)', 1536), casella(rif, 'rifatti oggi su 5325f596, con lo stesso strumento (scatti_guanto.gd)', 1536)]
    griglia(c, 1, '4_approvati_e_rifatti.jpg')
    for p, v, d, n, ca, cb in stat:
        print('POSA %-12s %-5s diff media %.1f/255; bianco del guanto (%d pixel) approvato %s, oggi %s' % (p, v, d, n,
              None if ca is None else np.round(ca, 1), None if cb is None else np.round(cb, 1)))
# 5: dagli occhi a 90 gradi
if "5" in Q:
    c = []
    for n, t in [('entra_16x9_fov90_fermo', '16:9, campo visivo 90, fermo'), ('entra_16x9_fov90_tutto_giu', '16:9, 90, tutto in giù'),
                 ('entra_16x9_fov90_carica', '16:9, 90, in carica'), ('occhi_16x9_fov62_fermo', '16:9, campo visivo 62 (del gioco), fermo')]:
        im = apri(os.path.join(T, 'occhi'), n)
        if im: c.append(casella(im, t, 640))
    f = apri(os.path.join(T, 'occhi'), 'entra_16x9_fov90_fermo')
    if f:
        c.append(casella(f.crop((660, 560, 940, 720)), 'fermo a 90, la mano ingrandita', 640))
        g0 = apri(os.path.join(N, 'occhi'), 'entra_16x9_fov90_fermo')
        if g0: c.append(casella(g0.crop((660, 560, 940, 720)), 'lo stesso su 98ded0d2', 640))
    griglia(c, 2, '5_occhi.jpg')
