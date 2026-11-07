"""Fogli degli scatti del collaudo del guanto (0.3.22). Uso: python3 fogli_guanto.py <cartella guanto> [quali]"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

G = sys.argv[1]
QUALI = sys.argv[2].split(",") if len(sys.argv) > 2 else ["2a", "1c", "3"]
SC = os.path.join(G, "scatti")
FO = os.path.join(G, "fogli")
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 17)
TW = 640  # larghezza di una casella
BAR = 26


def casella(img, titolo, w=TW):
    h = round(img.height * w / img.width)
    out = Image.new("RGB", (w, h + BAR), (20, 20, 20))
    out.paste(img.resize((w, h), Image.LANCZOS), (0, BAR))
    ImageDraw.Draw(out).text((8, 4), titolo, font=FONT, fill=(235, 235, 235))
    return out


def griglia(caselle, colonne, nome):
    righe = [caselle[i:i + colonne] for i in range(0, len(caselle), colonne)]
    W = max(sum(c.width for c in r) for r in righe)
    H = sum(max(c.height for c in r) for r in righe)
    out = Image.new("RGB", (W, H), (20, 20, 20))
    y = 0
    for r in righe:
        x = 0
        for c in r:
            out.paste(c, (x, y))
            x += c.width
        y += max(c.height for c in r)
    out.save(os.path.join(FO, nome), quality=88)
    print("foglio", nome, out.size)


def apri(nome):
    p = os.path.join(SC, nome + ".jpg")
    return Image.open(p).convert("RGB") if os.path.exists(p) else None


if "2a" in QUALI:
    c = []
    for v, t in [("destra", "da destra"), ("sinistra", "da sinistra"), ("davanti", "davanti"),
                 ("dietro", "dietro"), ("sotto", "da sotto"), ("dietro_sotto_polsino", "polsino, da dietro e sotto"),
                 ("dietro_destra_polsino", "polsino, da dietro e da destra")]:
        c.append(casella(apri("vicino_fermo_" + v), "fermo, " + t))
    s = apri("vicino_fermo_sinistra")
    c.append(casella(s.crop((300, 110, 900, 560)), "da sinistra, ingrandito: punte delle dita e pollice"))
    griglia(c, 2, "2a_vicino_fermo.jpg")

if "1c" in QUALI:
    # i formati a 90 gradi: fermo e carica (il caso più alto)
    c = []
    for conf, t in [("16x9", "16:9"), ("16x10", "16:10"), ("21x9", "21:9"), ("4x3", "4:3")]:
        for st, ts in [("fermo", "fermo"), ("carica", "carica")]:
            im = apri("entra_%s_fov90_%s" % (conf, st))
            if im is None:
                continue
            w = TW if conf != "21x9" else round(TW * 1680 / 1280 * 720 / 720 * 0.8)
            c.append(casella(im, "%s, campo visivo 90, %s" % (t, ts), TW))
    griglia(c, 2, "1c_formati_90.jpg")

if "3" in QUALI or "3b" in QUALI:
    for foglio, suf, campo in [("3", "", "62"), ("3b", "_fov90", "90")]:
        if foglio not in QUALI:
            continue
        c = []
        for n, t in [("scena_morte_10", "morte, fotogramma 10"), ("scena_morte_30", "morte, fotogramma 30"),
                     ("scena_morte_50", "morte, fotogramma 50"), ("scena_ripartenza_02", "ripartenza, fotogramma 2"),
                     ("scena_ripartenza_20", "ripartenza, fotogramma 20"), ("scena_presa_15", "presa di lei, fotogramma 15"),
                     ("scena_presa_40", "presa di lei, fotogramma 40"), ("scena_presa_60", "presa di lei, fotogramma 60")]:
            im = apri(n + suf)
            if im is not None:
                c.append(casella(im, "%s (campo %s)" % (t, campo)))
        im = apri("entra_16x9_fov90_raccolta" if campo == "90" else "occhi_16x9_fov62_raccolta")
        if im is not None:
            c.append(casella(im, "raccolta del fucile (campo %s)" % campo))
        griglia(c, 3, "%s_scene_campo_%s.jpg" % (foglio, campo))

if "2d" in QUALI:
    # lo strappo sulla punta dell'indice: dove sta (cerchio rosso) e ingrandito da due lati
    a = apri("vicino_fermo_davanti"); b = apri("vicino_fermo_sinistra")
    a2 = a.copy(); dr = ImageDraw.Draw(a2); dr.ellipse((815, 210, 875, 270), outline=(255, 40, 40), width=4)
    b2 = b.copy(); dr = ImageDraw.Draw(b2); dr.ellipse((345, 205, 415, 275), outline=(255, 40, 40), width=4)
    c = [casella(a2, "davanti: strappo sulla punta dell'indice (cerchio)"),
         casella(b2, "da sinistra: lo stesso strappo (cerchio)"),
         casella(a.crop((785, 195, 905, 285)), "davanti, ingrandito 5 volte"),
         casella(b.crop((320, 190, 440, 280)), "da sinistra, ingrandito 5 volte")]
    griglia(c, 2, "2d_strappo_punta_indice.jpg")

if "2c" in QUALI:
    # lo spiraglio fra anulare e mignolo, sul lato destro dell'impugnatura: si vede l'arancione
    a = apri("vicino_fermo_destra"); k = apri("vicino_carica_destra")
    a2 = a.copy(); dr = ImageDraw.Draw(a2); dr.ellipse((737, 378, 798, 428), outline=(255, 40, 40), width=4)
    c = [casella(a2, "da destra, a 28 cm: spiraglio fra anulare e mignolo (cerchio)"),
         casella(k, "da destra, in carica: lo stesso spiraglio"),
         casella(a.crop((700, 360, 840, 446)), "fermo, ingrandito 4,5 volte"),
         casella(k.crop((700, 360, 840, 446)) if k else a.crop((700, 360, 840, 446)), "in carica, ingrandito 4,5 volte")]
    griglia(c, 2, "2c_spiraglio_fra_le_dita.jpg")
