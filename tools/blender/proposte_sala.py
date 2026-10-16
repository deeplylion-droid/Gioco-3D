"""Pezzi per le PROPOSTE della sala principale (15 ottobre 2026). NON sono nel gioco.

Costruisce solo i pezzi nuovi o cambiati e li esporta come GLB piccoli in godot/proposte/sala/, più
dati.json con le posizioni che servono per montarli. Li monta godot/tests/proposte_sala.gd sopra la
scena vera, a runtime, senza toccarla.
  base.glb        sala senza soppalco: plafoniere al neon e cartelloni sulle pareti, fari della medusa
                  sulla parete sud; cordone chiuso tutto intorno alla vasca, con un muro invisibile
                  alto 2,5 m sulla stessa linea
  pulsante_a.glb  pulsante della botola, versione A: fungo rosso grosso con il lampeggiante sopra
  pulsante_b.glb  versione B: pulsante rosso nella cornice a strisce gialle e nere, cartello senza
                  scritte (il getto colpisce il pulsante, la botola si apre) e un faretto
  torre_nord.glb  sala della torre a nord: varco nella parete nord, cancello a sbarre, la sala nuova
  torre_est.glb   sala della torre a est: varco nella parete est, portone scorrevole, la sala nuova
Le texture disegnate (strisce, cartelli) finiscono in assets_src/proposte_sala/.

Uso (dalla radice): /home/user/tools/blender-venv/bin/python tools/blender/proposte_sala.py [pezzi]
    pezzi separati da virgole tra base, pulsante_a, pulsante_b, torre_nord, torre_est (di serie tutti)
"""
import json, math, os, random, sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import bpy  # noqa: E402
from mathutils import Vector, Matrix, Euler  # noqa: E402
import ambiente_kit as K  # noqa: E402
import ambiente_sala as S  # noqa: E402

USCITA = os.path.join(K.RADICE, 'godot', 'proposte', 'sala')
TEX = os.path.join(K.RADICE, 'assets_src', 'proposte_sala')
X0, X1, Y0, Y1 = S.X0, S.X1, S.Y0, S.Y1
DATI = {}


def a_godot(p):
    return [round(p[0], 3), round(p[2], 3), round(-p[1], 3)]


def lineare(hexa):
    """Colore sRGB '#rrggbb' -> lineare (Blender lavora in lineare)."""
    c = [int(hexa[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


# ----------------------------------------------------------------------------- materiali delle proposte

def mat_semplice(mats, nome, hexa, rough=0.5, metallo=0.0, emissione=0.0):
    if nome in mats.cache:
        return
    m = bpy.data.materials.new('M_prop_' + nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    col = lineare(hexa)
    b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metallo
    if emissione > 0:
        b.inputs['Emission Color'].default_value = (*col, 1)
        b.inputs['Emission Strength'].default_value = emissione
    mats.cache[nome] = m
    mats.lati[nome] = 1.0


def mat_texture(mats, nome, file, rough=0.55, metallo=0.0, emissione=0.0):
    if nome in mats.cache:
        return
    m = bpy.data.materials.new('M_prop_' + nome)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(file, check_existing=True)
    nt.links.new(uv.outputs['UV'], t.inputs['Vector'])
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    if emissione > 0:
        nt.links.new(t.outputs['Color'], b.inputs['Emission Color'])
        b.inputs['Emission Strength'].default_value = emissione
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metallo
    mats.cache[nome] = m
    mats.lati[nome] = 1.0


def materiali_proposte(mats):
    mat_semplice(mats, 'rosso_pulsante', '#d01810', rough=0.22)
    mat_semplice(mats, 'giallo_sicurezza', '#f2b705', rough=0.5)
    mat_semplice(mats, 'nero_opaco', '#141414', rough=0.6)
    mat_semplice(mats, 'faro_giallo', '#ffb300', rough=0.25, emissione=6.0)    # in Godot: giallo o verde
    mat_semplice(mats, 'faro_rosso', '#ff2a10', rough=0.25, emissione=6.0)
    mat_semplice(mats, 'vetro_lampada', '#fff2d0', rough=0.2, emissione=12.0)
    mat_semplice(mats, 'portale_blu', '#1f5fae', rough=0.45, metallo=0.3)
    mat_semplice(mats, 'acciaio_cancello', '#3b4043', rough=0.55, metallo=0.6)
    mat_semplice(mats, 'stanza_muro', '#4d5652', rough=0.85)
    mat_semplice(mats, 'stanza_soffitto', '#2a2e2d', rough=0.9)
    os.makedirs(TEX, exist_ok=True)
    disegna_strisce(os.path.join(TEX, 'cornice_strisce_col.jpg'))
    disegna_cartello(os.path.join(TEX, 'cartello_botola_col.jpg'))
    disegna_insegna_torre(os.path.join(TEX, 'insegna_torre_col.jpg'))
    disegna_lamiera_portone(os.path.join(TEX, 'portone_torre_col.jpg'))
    mat_texture(mats, 'strisce', os.path.join(TEX, 'cornice_strisce_col.jpg'), rough=0.5, metallo=0.2)
    mat_texture(mats, 'cartello', os.path.join(TEX, 'cartello_botola_col.jpg'), rough=0.45)
    mat_texture(mats, 'insegna_torre', os.path.join(TEX, 'insegna_torre_col.jpg'), rough=0.4, emissione=1.2)
    mat_texture(mats, 'portone', os.path.join(TEX, 'portone_torre_col.jpg'), rough=0.6, metallo=0.3)


# ----------------------------------------------------------------------------- texture disegnate (PIL)

def _rumore(im, forza=18, seme=3):
    """Un po' di sporco e graffi: le texture nuove non devono sembrare appena stampate."""
    from PIL import Image, ImageFilter
    import numpy as np
    rng = np.random.default_rng(seme)
    a = np.asarray(im).astype(np.float32)
    n = rng.normal(0, 1, (a.shape[0] // 8 + 1, a.shape[1] // 8 + 1)).astype(np.float32)
    n = np.asarray(Image.fromarray(((n - n.min()) / (n.max() - n.min()) * 255).astype(np.uint8)).resize(
        (a.shape[1], a.shape[0]), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
    a *= (1.0 - forza / 255 * 3 * (n[..., None] - 0.3).clip(0, 1))
    for _ in range(60):   # graffi chiari
        x, y = rng.integers(0, a.shape[1]), rng.integers(0, a.shape[0])
        L = rng.integers(10, 60); ang = rng.uniform(0, math.pi)
        for t in range(L):
            xx, yy = int(x + math.cos(ang) * t), int(y + math.sin(ang) * t)
            if 0 <= xx < a.shape[1] and 0 <= yy < a.shape[0]:
                a[yy, xx] = a[yy, xx] * 0.6 + 200 * 0.4
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def disegna_strisce(percorso, N=1024):
    """Cornice quadrata a strisce gialle e nere a 45 gradi (fascia di N/4), centro in metallo scuro."""
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (N, N), (242, 183, 5))
    d = ImageDraw.Draw(im)
    passo = N // 8
    for k in range(-N, 2 * N, passo):
        d.polygon([(k, 0), (k + passo // 2, 0), (k + passo // 2 - N, N), (k - N, N)], fill=(22, 22, 22))
    f = N // 4
    d.rectangle([f, f, N - f, N - f], fill=(48, 52, 54))
    d.rectangle([f - 10, f - 10, N - f + 10, N - f + 10], outline=(20, 20, 20), width=14)
    d.rectangle([4, 4, N - 5, N - 5], outline=(20, 20, 20), width=10)
    for (x, y) in ((f // 2, f // 2), (N - f // 2, f // 2), (f // 2, N - f // 2), (N - f // 2, N - f // 2)):
        d.ellipse([x - 18, y - 18, x + 18, y + 18], fill=(150, 150, 140), outline=(30, 30, 30), width=4)
    _rumore(im, 14, 5).save(percorso, quality=92)


def disegna_cartello(percorso, W=1600, H=1200):
    """Cartello senza scritte: a sinistra il getto dello zaino che colpisce il pulsante rosso nella
    cornice a strisce, una freccia, a destra la botola nel pavimento che si apre (coperchio alzato e
    freccia curva). Bordo giallo e nero come la cornice del pulsante."""
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (W, H), (244, 241, 230))
    d = ImageDraw.Draw(im)
    NERO, BLU, ROSSO, GIALLO, GRIGIO = (24, 26, 28), (30, 120, 220), (214, 34, 24), (242, 183, 5), (150, 156, 160)
    # bordo a strisce
    b = 70
    passo = 70
    for k in range(-H, W + H, passo):
        d.polygon([(k, 0), (k + passo // 2, 0), (k + passo // 2 - b, b), (k - b, b)], fill=NERO)
        d.polygon([(k, H - b), (k + passo // 2, H - b), (k + passo // 2 - b, H), (k - b, H)], fill=NERO)
    d.rectangle([0, 0, W, b], outline=None)
    im2 = Image.new('RGB', (W, H), GIALLO); d2 = ImageDraw.Draw(im2)
    for k in range(-2 * H, W + 2 * H, passo):
        d2.polygon([(k, 0), (k + passo // 2, 0), (k + passo // 2 + H, H), (k + H, H)], fill=NERO)
    mask = Image.new('L', (W, H), 255); dm = ImageDraw.Draw(mask)
    dm.rounded_rectangle([b, b, W - b, H - b], radius=40, fill=0)
    im.paste(im2, (0, 0), mask)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([b, b, W - b, H - b], radius=40, outline=NERO, width=10)
    # --- 1: la lancia dello zaino (in basso a sinistra) e il getto
    def spessa(pts, col, w):
        d.line(pts, fill=col, width=w, joint='curve')
        for p in (pts[0], pts[-1]):
            d.ellipse([p[0] - w // 2, p[1] - w // 2, p[0] + w // 2, p[1] + w // 2], fill=col)
    # lancia: impugnatura + canna inclinata verso l'alto a destra
    lx, ly = 170, 760
    canna = [(lx, ly), (lx + 170, ly - 120)]
    spessa(canna, NERO, 62)
    spessa(canna, (90, 96, 100), 40)
    d.polygon([(lx - 40, ly + 10), (lx + 10, ly - 25), (lx + 50, ly + 95), (lx, ly + 125)], fill=NERO)   # impugnatura
    # getto: arco blu (curva di Bezier) dalla punta della lancia al pulsante, con le gocce
    px, py = 660, 600                                  # centro del pulsante
    P0 = (lx + 196, ly - 140)
    P2 = (px - 70, py - 6)
    P1 = ((P0[0] + P2[0]) / 2, 300)
    arco = []
    for i in range(41):
        t = i / 40
        arco.append(((1 - t) ** 2 * P0[0] + 2 * (1 - t) * t * P1[0] + t * t * P2[0],
                     (1 - t) ** 2 * P0[1] + 2 * (1 - t) * t * P1[1] + t * t * P2[1]))
    spessa(arco, (14, 60, 140), 46)
    spessa(arco, BLU, 30)
    d.line(arco[4:36], fill=(170, 215, 255), width=8, joint='curve')
    for i in range(6, 38, 7):
        x, y = arco[i]
        d.ellipse([x - 9 + 26, y + 18, x + 9 + 26, y + 40], fill=BLU, outline=(14, 60, 140), width=3)
    # pulsante nella cornice a strisce
    s = 125
    q = Image.new('L', (W, H), 0); dq = ImageDraw.Draw(q)
    dq.rectangle([px - s, py - s, px + s, py + s], fill=255)
    dq.rectangle([px - s + 38, py - s + 38, px + s - 38, py + s - 38], fill=0)
    base = Image.new('RGB', (W, H), GIALLO)
    dbase = ImageDraw.Draw(base)
    for k in range(-2 * H, W + 2 * H, 34):
        dbase.polygon([(k, 0), (k + 17, 0), (k + 17 + H, H), (k + H, H)], fill=NERO)
    im.paste(base, (0, 0), q)
    d = ImageDraw.Draw(im)
    d.rectangle([px - s + 38, py - s + 38, px + s - 38, py + s - 38], fill=(60, 64, 66))
    d.rectangle([px - s, py - s, px + s, py + s], outline=NERO, width=10)
    d.ellipse([px - 66, py - 66, px + 66, py + 66], fill=NERO)
    d.ellipse([px - 54, py - 54, px + 54, py + 54], fill=ROSSO)
    d.ellipse([px - 40, py - 46, px - 4, py - 22], fill=(255, 140, 120))
    # schizzi dell'impatto
    for a in (150, 175, 200, 125, 225):
        r0, r1 = 150, 205
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        d.line([(px + c * r0, py + s_ * r0), (px + c * r1, py + s_ * r1)], fill=BLU, width=16)
    # --- freccia verso destra
    fx, fy = 905, 520
    d.polygon([(fx - 70, fy - 34), (fx + 20, fy - 34), (fx + 20, fy - 80), (fx + 110, fy), (fx + 20, fy + 80), (fx + 20, fy + 34), (fx - 70, fy + 34)], fill=NERO)
    # --- 2: la botola nel pavimento, aperta (vista di tre quarti)
    cx, cy = 1200, 760
    pav = [(cx - 300, cy + 80), (cx + 300, cy + 80), (cx + 190, cy - 110), (cx - 190, cy - 110)]
    d.polygon(pav, fill=(198, 202, 196), outline=NERO, width=8)
    buco = [(cx - 150, cy + 40), (cx + 150, cy + 40), (cx + 100, cy - 60), (cx - 100, cy - 60)]
    d.polygon(buco, fill=(16, 16, 18), outline=NERO, width=8)
    for k in range(3):   # pioli della scala nel pozzo
        yy = cy - 30 + k * 26
        d.line([(cx - 40, yy), (cx + 40, yy)], fill=(120, 124, 126), width=8)
    # coperchio alzato (cerniera sul lato lontano)
    cop = [(cx - 100, cy - 60), (cx + 100, cy - 60), (cx + 125, cy - 330), (cx - 125, cy - 330)]
    d.polygon(cop, fill=GRIGIO, outline=NERO, width=8)
    for k in range(4):
        t = (k + 0.5) / 4
        x1 = cx - 100 + (-25) * (1 - t) * 0
        d.line([(cx - 95 - 25 * t, cy - 60 - 270 * t), (cx + 95 + 25 * t, cy - 60 - 270 * t)], fill=(120, 126, 130), width=6)
    # freccia curva dell'apertura
    curva = []
    for i in range(25):
        a = math.radians(-10 - 75 * i / 24)
        curva.append((cx + 160 + 130 * math.cos(a), cy - 80 + 130 * math.sin(a)))
    spessa(curva, NERO, 24)
    ex, ey = curva[-1]
    d.polygon([(ex - 40, ey + 10), (ex + 30, ey - 30), (ex + 20, ey + 45)], fill=NERO)
    # luce verde sopra la botola: si apre
    d.ellipse([cx - 40, cy - 470, cx + 40, cy - 390], fill=(40, 200, 80), outline=NERO, width=8)
    for a in range(0, 360, 45):
        c, s_ = math.cos(math.radians(a)), math.sin(math.radians(a))
        d.line([(cx + c * 58, cy - 430 + s_ * 58), (cx + c * 84, cy - 430 + s_ * 84)], fill=(40, 200, 80), width=10)
    _rumore(im, 10, 7).save(percorso, quality=92)


def disegna_insegna_torre(percorso, W=2048, H=640):
    """Insegna della torre degli scivoli, senza scritte: la torre con il tubo che scende a spirale
    fino all'acqua, sui colori del parco (blu, giallo, rosso)."""
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (W, H), (250, 196, 30))
    d = ImageDraw.Draw(im)
    BLU, ROSSO, NERO, BIANCO, ACQUA = (24, 92, 170), (206, 40, 30), (20, 24, 28), (250, 248, 240), (40, 170, 220)
    d.rounded_rectangle([12, 12, W - 12, H - 12], radius=60, outline=NERO, width=16)
    d.rounded_rectangle([44, 44, W - 44, H - 44], radius=44, outline=BLU, width=14)
    # onde in basso
    for k in range(0, W, 90):
        d.arc([k, H - 170, k + 90, H - 110], 0, 180, fill=ACQUA, width=18)
        d.arc([k + 45, H - 130, k + 135, H - 70], 0, 180, fill=BLU, width=14)
    # torre al centro
    cx = W // 2
    for sx in (-1, 1):
        d.line([(cx + sx * 110, H - 150), (cx + sx * 80, 120)], fill=NERO, width=26)
    for yy in (430, 330, 230, 140):
        w = 80 + (yy - 120) * 30 / 330
        d.rectangle([cx - w - 20, yy - 14, cx + w + 20, yy + 14], fill=ROSSO, outline=NERO, width=6)
    d.polygon([(cx - 120, 140), (cx + 120, 140), (cx, 70)], fill=ROSSO, outline=NERO)
    # tubi che scendono dai due lati fino all'acqua
    for sx, col in ((-1, BLU), (1, ROSSO)):
        pts = []
        for i in range(60):
            t = i / 59
            x = cx + sx * (130 + 720 * t)
            y = 150 + (H - 300) * (t ** 0.8) + 40 * math.sin(t * math.pi * 3)
            pts.append((x, y))
        d.line(pts, fill=NERO, width=86, joint='curve')
        d.line(pts, fill=col, width=62, joint='curve')
        d.line([(p[0], p[1] - 12) for p in pts], fill=BIANCO, width=10, joint='curve')
        ex, ey = pts[-1]
        for k in range(5):   # spruzzi all'arrivo
            a = math.radians(200 + 35 * k) if sx < 0 else math.radians(-20 - 35 * k)
            d.line([(ex + math.cos(a) * 60, ey + math.sin(a) * 60), (ex + math.cos(a) * 110, ey + math.sin(a) * 110)], fill=ACQUA, width=14)
    # stelle
    for (x, y) in ((260, 150), (W - 260, 150), (420, 90), (W - 420, 90)):
        pts = []
        for k in range(10):
            r = 34 if k % 2 == 0 else 14
            a = math.radians(-90 + k * 36)
            pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
        d.polygon(pts, fill=BIANCO, outline=NERO)
    _rumore(im, 12, 9).save(percorso, quality=92)


def disegna_lamiera_portone(percorso, W=1536, H=1280):
    """Portone scorrevole: lamiera grecata gialla sbiadita, bande a strisce sui bordi, al centro la
    stessa torre con gli scivoli dipinta grande (senza scritte)."""
    from PIL import Image, ImageDraw
    im = Image.new('RGB', (W, H), (214, 170, 52))
    d = ImageDraw.Draw(im)
    for k in range(0, W, 48):   # nervature della lamiera
        d.rectangle([k, 0, k + 10, H], fill=(176, 136, 40))
        d.rectangle([k + 10, 0, k + 14, H], fill=(236, 196, 92))
    NERO = (24, 24, 24)
    for (y0, y1) in ((0, 110), (H - 110, H)):
        for k in range(-W, 2 * W, 96):
            d.polygon([(k, y0), (k + 48, y0), (k + 48 + (y1 - y0), y1), (k + (y1 - y0), y1)], fill=NERO)
    ins = Image.open(os.path.join(TEX, 'insegna_torre_col.jpg')).resize((W - 220, int((W - 220) * 640 / 2048)))
    im.paste(ins, (110, (H - ins.size[1]) // 2))
    _rumore(im, 26, 11).save(percorso, quality=90)


# ----------------------------------------------------------------------------- 1. sala senza soppalco

def lampade_a_parete(mats, escludi=()):
    """Come ambiente_sala.lampade() (stesso seme: le stesse plafoniere accese, spente o a metà, e le
    luci con gli stessi nomi), ma senza soppalco: ogni plafoniera è su due staffe fissate alla parete,
    alla stessa quota (3,88 m), a 32 cm dal muro. escludi: luci da togliere (varchi nelle pareti).
    Restituisce (oggetto 'sala_lampade', {nome luce: posizione Blender}, nomi tolti)."""
    obs, sorgenti = [], []
    zl = S.Z_GAL - 0.12
    rnd = random.Random(11)
    D_ = 0.32
    stati = []
    for y in range(int(Y0) + 4, 21, 4):
        stati.append(((X1 - D_, y + 0.0, zl), 90, (1, 0)))
        stati.append(((X0 + D_, y + 0.0, zl), 90, (-1, 0)))
    for x in range(-16, 17, 4):
        if abs(x) < 1:
            continue
        stati.append(((x + 0.0, Y0 + D_, zl), 0, (0, -1)))
        stati.append(((x + 0.0, Y1 - D_, zl), 0, (0, 1)))
    tolti = []
    for i, (pos, rot, verso) in enumerate(stati):
        r = rnd.random()
        acc = (True, True) if r < 0.5 else ((True, False) if r < 0.75 else (False, False))
        via = any(e(pos) for e in escludi)
        if acc[0]:
            sorgenti.append(('neon', pos, rot, 1.0 if acc[1] else 0.45, via))
        if via:
            continue
        obs.append(S.metti(K.lampada_neon(mats, accesa=acc, nome=f'neon_{i}'), pos, rot))
        c = K.Costruttore(mats)
        lungo = Vector((0, 1, 0)) if rot == 90 else Vector((1, 0, 0))
        muro = Vector((pos[0] + verso[0] * D_, pos[1] + verso[1] * D_, zl))
        for s_ in (-0.42, 0.42):
            a = muro + lungo * s_
            b = Vector(pos) + lungo * s_
            lo = Vector((min(a.x, b.x), min(a.y, b.y), zl - 0.005)) - Vector((0.02, 0.02, 0)) * 0
            hi = Vector((max(a.x, b.x), max(a.y, b.y), zl + 0.035))
            if rot == 90:
                lo.y -= 0.02; hi.y += 0.02
            else:
                lo.x -= 0.02; hi.x += 0.02
            c.scatola(tuple(lo), tuple(hi), 'metallo')
            # piastra sul muro
            pc = muro + lungo * s_
            n = Vector((verso[0], verso[1], 0))
            t = lungo
            c.scatola_assi(tuple(pc - n * 0.005 + Vector((0, 0, 0.0))), (tuple(t), (0, 0, 1), tuple(n)), (0.05, 0.07, 0.008), 'metallo')
        obs.append(c.crea(f'staffe_{i}'))
    emerg = [((X1, -6.0, 2.9), -90), ((X1, 6.0, 2.9), -90), ((X1, 18.0, 2.9), -90),
             ((X0, -4.0, 2.9), 90), ((X0, 8.0, 2.9), 90), ((X0, 20.0, 2.9), 90),
             ((-6.0, Y1, 2.9), 0), ((8.0, Y1, 2.9), 0), ((-5.0, Y0, 2.9), 180), ((5.0, Y0, 2.9), 180),
             ((X1, 0.0, 8.6), -90), ((X0, 12.0, 8.6), 90), ((-12.0, Y1, 8.6), 0), ((12.0, Y0, 8.6), 180),
             ((2.0, Y1, 8.6), 0), ((X1, 14.0, 8.6), -90), ((X0, -6.0, 8.6), 90),
             ((X1, -14.0, 2.9), -90), ((X0, -16.0, 2.9), 90), ((X1, -12.0, 8.6), -90), ((-14.0, Y0, 8.6), 180)]
    for i, (pos, rot) in enumerate(emerg):
        via = any(e(pos) for e in escludi)
        d = Vector((0, -0.12, 0))
        d.rotate(Euler((0, 0, math.radians(rot))))
        sorgenti.append(('rossa', tuple(Vector(pos) + d), rot, 1.0, via))
        if not via:
            obs.append(S.metti(K.luce_emergenza(mats, nome=f'emerg_{i}'), pos, rot))
    luci = {}
    for i, (tipo, pos, rot, k, via) in enumerate(sorgenti):
        nome = f'luce_neon_{i:02d}' if tipo == 'neon' else f'luce_emergenza_{i:02d}'
        if via:
            tolti.append(nome)
        elif tipo == 'neon':
            luci[nome] = a_godot(pos)
    return S.unisci(obs, 'sala_lampade'), luci, tolti


def cartelloni_a_parete(mats, salta=()):
    """I cartelloni che erano appesi alle ringhiere, ora sulle pareti alla stessa quota."""
    obs = []
    zr = S.Z_GAL + S.SP_GAL - 0.15
    for i, (x, g) in enumerate(((-9.0, 'p1'), (-1.5, 'p2'), (6.0, 'p3'))):
        nome = f'sala_cartellone_n{i}'
        if nome in salta:
            continue
        ob = K.cartellone(mats, 3.2, 1.8, nome=nome)
        obs.append((S.metti(ob, (x, Y1 - 0.02, zr)), g))
    ob = K.cartellone(mats, 3.2, 1.8, nome='sala_cartellone_s0')
    obs.append((S.metti(ob, (-8.0, Y0 + 0.02, zr), 180), 'p3'))
    for ob, g in obs:
        for i, m in enumerate(ob.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                ob.data.materials[i] = mats.get('cartellone_' + g)
    return [o for o, _ in obs]


def fari_a_parete(mats):
    """I due fari della medusa, prima sulla ringhiera del soppalco sud: ora su due bracci fissati alla
    parete sud, alla stessa quota. Stesso nome dell'oggetto e delle luci."""
    V = S.VASCA_CENTRALE
    bersaglio = Vector((V['cx'], V['cy'] - V['ly'] / 2 + 0.55, 1.75))
    c = K.Costruttore(mats)
    luci = {}
    for i, x in enumerate((-2.1, 2.1)):
        z = S.Z_GAL + S.SP_GAL + S.RINGHIERA_H_SALA
        piastra = Vector((x, Y0 + 0.01, z))
        corpo = Vector((x, Y0 + 0.55, z + 0.2))
        d = (bersaglio - corpo).normalized()
        c.scatola(tuple(piastra + Vector((-0.12, 0, -0.12))), tuple(piastra + Vector((0.12, 0.02, 0.12))), 'nero')
        c.tubo([tuple(piastra + Vector((0, 0.02, 0))), tuple(piastra + Vector((0, 0.35, 0.0))), tuple(corpo - Vector((0, 0, 0.12)))], 0.025, 'nero', seg=8)
        lato = d.cross(Vector((0, 0, 1))).normalized()
        for sgn in (-1, 1):
            c.cilindro(tuple(corpo - Vector((0, 0, 0.12)) + lato * 0.15 * sgn), tuple(corpo + lato * 0.15 * sgn), 0.012, 'nero', seg=6)
        c.cilindro(tuple(corpo - lato * 0.15), tuple(corpo + lato * 0.15), 0.012, 'nero', seg=6, tappi=False)
        c.cilindro(tuple(corpo - d * 0.22), tuple(corpo + d * 0.2), 0.14, 'nero', seg=16)
        c.anello(tuple(corpo + d * 0.2), tuple(d), 0.1, 0.15, 0.03, 'nero', seg=16)
        c.disco(tuple(corpo + d * 0.205), tuple(d), 0.1, 'lampadina', seg=16)
        for k in range(4):
            o = d * (-0.15 + k * 0.08)
            c.toro(tuple(corpo + o), tuple(d), 0.15, 0.01, 'nero', seg=16, seg_r=4)
        luci[f'luce_faro_{i}'] = dict(pos=a_godot(corpo + d * 0.3), mira=a_godot(bersaglio))
    return c.crea('sala_monumento_fari'), luci


def cordone_chiuso(mats):
    """Cordone su colonnine intorno alla vasca della medusa, chiuso (senza il varco davanti), con un
    muro invisibile alto 2,5 m su ogni campata: non ci si avvicina e non lo si salta."""
    V = S.VASCA_CENTRALE
    m = V['cordone']
    giro, s = S.rett_arrotondato(V['cx'], V['cy'], V['lx'] + 2 * m, V['ly'] + 2 * m, V['r'] + m, passo=0.05, seg_arco=24)
    totale = s[-1]
    n = max(8, int(round(totale / 1.45)))
    pali = []
    for k in range(n):
        target = totale * k / n
        i = min(range(len(giro)), key=lambda j: abs(s[j] - target))
        p = giro[i][0]
        pali.append((p.x, p.y))
    c = K.Costruttore(mats)
    H = 0.95
    copie = S.colonnine(c, pali, H, 'sala_vasca_colonnina')
    for i in range(len(pali)):
        a, b = pali[i], pali[(i + 1) % len(pali)]
        A = Vector((a[0], a[1], H - 0.07)); B = Vector((b[0], b[1], H - 0.07))
        curva = []
        for k in range(13):
            t = k / 12
            p = A.lerp(B, t)
            p.z -= 0.16 * (1 - (2 * t - 1) ** 2)
            curva.append(tuple(p))
        c.tubo(curva, 0.024, 'velluto', seg=10)
        for e in (A, B):
            c.cilindro(tuple(e + Vector((0, 0, -0.03))), tuple(e + Vector((0, 0, 0.03))), 0.03, 'cornice_oblo', seg=8)
    ob = c.crea('sala_vasca_cordone', sporco=lambda co: 0.85)
    for i in range(len(pali)):
        a, b = pali[i], pali[(i + 1) % len(pali)]
        d = Vector((b[0] - a[0], b[1] - a[1], 0)).normalized()
        nn = Vector((-d.y, d.x, 0)) * 0.06
        pts = [tuple(Vector((p[0], p[1], z)) + s_ * nn) for p in (a, b) for z in (0.0, 2.5) for s_ in (-1, 1)]
        K.collisione_punti(f'cordone_vasca_{i}', pts, padre=ob)
    DATI['cordone'] = dict(colonnine=len(pali), campate=len(pali), altezza_muro_invisibile=2.5,
                           distanza_dal_bordo=m, pali_godot=[a_godot((x, y, 0)) for x, y in pali])
    return [ob] + copie


def altoparlanti_a_parete(mats):
    """Gli altoparlanti a tromba erano sulle colonne del soppalco: ora sulle pareti nord e sud, stessa x e quota."""
    c = K.Costruttore(mats)
    for (x, y, v) in ((-9.0, Y0, 1), (9.0, Y0, 1), (-9.0, Y1, -1), (9.0, Y1, -1)):
        z = 3.3
        b = Vector((x, y + 0.08 * v, z))
        c.scatola((x - 0.1, y, z - 0.1), (x + 0.1, y + 0.08 * v, z + 0.1), 'metallo') if v > 0 else \
            c.scatola((x - 0.1, y + 0.08 * v, z - 0.1), (x + 0.1, y, z + 0.1), 'metallo')
        d = Vector((0, v, -0.25)).normalized()
        pts = [b + d * 0.05, b + d * 0.45]
        u = Vector((1, 0, 0)); w = d.cross(u).normalized()
        for k in range(16):
            a0, a1 = 2 * math.pi * k / 16, 2 * math.pi * (k + 1) / 16
            q = [pts[0] + (u * math.cos(a0) + w * math.sin(a0)) * 0.06, pts[0] + (u * math.cos(a1) + w * math.sin(a1)) * 0.06,
                 pts[1] + (u * math.cos(a1) + w * math.sin(a1)) * 0.24, pts[1] + (u * math.cos(a0) + w * math.sin(a0)) * 0.24]
            c.faccia([tuple(p_) for p_ in q], 'metallo', liscia=True)
            c.faccia([tuple(p_) for p_ in q[::-1]], 'nero', liscia=True)
    return c.crea('sala_altoparlanti')


POSTI_CALDE = [((1.75, Y0, 2.5), (0, 1, 0)), ((X1, 9.0, 2.7), (-1, 0, 0)), ((X0, -1.0, 2.7), (1, 0, 0)),
               ((10.5, 14.38, 2.6), (0, -1, 0)), ((-4.6, Y1, 3.0), (0, -1, 0))]   # l'ultima era su una colonna del soppalco


def plafoniere_calde_separate(mats):
    """Le plafoniere calde di ambiente_dettagli, una per oggetto (sala_plafoniera_calda_N): quella che
    era su una colonna del soppalco nord va sulla parete nord; quella sulla torre si sposta con la torre."""
    obs, luci = [], {}
    for i, (p, n) in enumerate(POSTI_CALDE):
        c = K.Costruttore(mats)
        P = Vector(p); N = Vector(n)
        su = Vector((0, 0, 1)); lato = su.cross(N).normalized()
        c.scatola_assi(P + N * 0.02, (lato, su, N), (0.15, 0.1, 0.02), 'metallo')
        for k in range(12):
            t0, t1 = math.pi * k / 12, math.pi * (k + 1) / 12
            a0 = lato * math.cos(t0) * 0.1 + N * (0.04 + math.sin(t0) * 0.07)
            a1 = lato * math.cos(t1) * 0.1 + N * (0.04 + math.sin(t1) * 0.07)
            q = [P + a0 - su * 0.07, P + a1 - su * 0.07, P + a1 + su * 0.07, P + a0 + su * 0.07]
            c.faccia_verso([tuple(v) for v in q], 'lampadina', tuple((a0 + a1) / 2 - N * 0.04), liscia=True)
        for zz in (-0.05, 0.0, 0.05):
            arco = [P + su * zz + lato * math.cos(t) * 0.112 + N * (0.04 + math.sin(t) * 0.082) for t in [math.pi * k / 10 for k in range(11)]]
            c.tubo([tuple(v) for v in arco], 0.005, 'metallo', seg=5)
        obs.append(c.crea(f'sala_plafoniera_calda_{i}'))
        luci[f'luce_calda_{i}'] = a_godot(P + N * 0.25)
    return obs, luci


def colature_senza_soppalco(mats):
    """ambiente_sala.colature() senza le colature sul fronte del soppalco (stesso seme: le altre restano uguali)."""
    m = bpy.data.materials.get('M_amb_decal_colatura')
    if m is None:
        m = bpy.data.materials.new('M_amb_decal_colatura')
        m.use_nodes = True
        nt = m.node_tree
        b = nt.nodes['Principled BSDF']
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = bpy.data.images.load(os.path.join(K.TEX, 'decal', 'colatura_col.png'), check_existing=True)
        uv = nt.nodes.new('ShaderNodeUVMap'); uv.uv_map = 'UVMap'
        nt.links.new(uv.outputs['UV'], t.inputs['Vector'])
        nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
        nt.links.new(t.outputs['Alpha'], b.inputs['Alpha'])
        b.inputs['Roughness'].default_value = 0.7
        if hasattr(m, 'surface_render_method'):
            m.surface_render_method = 'BLENDED'
    class _M:
        def lato(self, n): return 1.0
        def get(self, n): return m
    c = K.Costruttore(_M())
    rnd = random.Random(21)
    def colatura(centro, normale, w, h, metti=True):
        if not metti:
            return
        cx_, cy_, zc = centro
        nx, ny = normale
        tx, ty = -ny, nx
        p = lambda a, b: (cx_ + nx * 0.012 + tx * a, cy_ + ny * 0.012 + ty * a, zc + b)
        c.faccia([p(-w / 2, -h), p(w / 2, -h), p(w / 2, 0), p(-w / 2, 0)], 'decal', uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for i in range(int(round((Y1 - Y0) / 2))):
        yb = Y0 + 2 * i + 1
        if i % 2 == 0 and rnd.random() < 0.75:
            colatura((X1, yb, S.Z_GAL + 2.2 - 0.38), (-1, 0), rnd.uniform(0.7, 1.1), rnd.uniform(1.0, 1.8))
        if i % 2 == 0 and rnd.random() < 0.75:
            colatura((X0, yb, S.Z_GAL + 2.2 - 0.38), (1, 0), rnd.uniform(0.7, 1.1), rnd.uniform(1.0, 1.8))
    for i in range(14):   # erano sul fronte del soppalco: si consumano i numeri ma non si mettono
        x = rnd.uniform(-16, 16)
        colatura((x, 0, 0), (0, -1), rnd.uniform(1.0, 2.2), rnd.uniform(0.8, 1.6), metti=False)
        x = rnd.uniform(-16, 16)
        colatura((x, 0, 0), (0, 1), rnd.uniform(1.0, 2.2), rnd.uniform(0.8, 1.6), metti=False)
    for i in range(16):
        y = rnd.uniform(Y0 + 1, Y1 - 1)
        colatura((X1, y, S.Z_GAL - 0.05), (-1, 0), rnd.uniform(0.8, 1.6), rnd.uniform(1.2, 2.0))
        y = rnd.uniform(Y0 + 1, Y1 - 1)
        colatura((X0, y, S.Z_GAL - 0.05), (1, 0), rnd.uniform(0.8, 1.6), rnd.uniform(1.2, 2.0))
    ob = c.crea('sala_colature')
    ob.visible_shadow = False
    return ob


def base(mats):
    lamp, luci, _ = lampade_a_parete(mats)
    fari, luci_fari = fari_a_parete(mats)
    calde, luci_calde = plafoniere_calde_separate(mats)
    obs = [lamp, fari, altoparlanti_a_parete(mats), colature_senza_soppalco(mats)] + calde + cartelloni_a_parete(mats) + cordone_chiuso(mats)
    DATI['base'] = dict(luci_neon=luci, luci_fari=luci_fari, luci_calde=luci_calde)
    return obs


# ----------------------------------------------------------------------------- 2. pulsante della botola

PB = dict(x=2.25, y=-5.0, z=-1.12)   # centro del pulsante sulla parete sud della piscina (fra due bocchette)


def cupola(c, centro, asse, r, h, mat, seg=32, anelli=8):
    """Calotta (mezzo ellissoide) con la base in 'centro' e la cima verso 'asse'."""
    C = Vector(centro); a = Vector(asse).normalized()
    u = a.orthogonal().normalized(); v = a.cross(u)
    for i in range(anelli):
        t0, t1 = (math.pi / 2) * i / anelli, (math.pi / 2) * (i + 1) / anelli
        r0, r1 = r * math.cos(t0), r * math.cos(t1)
        h0, h1 = h * math.sin(t0), h * math.sin(t1)
        for j in range(seg):
            p0, p1 = 2 * math.pi * j / seg, 2 * math.pi * (j + 1) / seg
            d0 = u * math.cos(p0) + v * math.sin(p0); d1 = u * math.cos(p1) + v * math.sin(p1)
            q = [C + a * h0 + d0 * r0, C + a * h0 + d1 * r0, C + a * h1 + d1 * r1, C + a * h1 + d0 * r1]
            if r1 < 1e-6:
                q = q[:3]
            c.faccia([tuple(p) for p in q], mat, liscia=True)


def pulsante_a(mats):
    """Versione A: cassetta gialla sulla parete, fungo rosso grosso (Ø 50 cm) e, sopra, il
    lampeggiante (giallo quando la piscina è vuota, verde quando la botola si apre: lo decide Godot)."""
    x, y, z = PB['x'], PB['y'], PB['z']
    c = K.Costruttore(mats)
    yf = y + 0.21                                    # fronte della cassetta
    c.scatola_smussata((x - 0.33, y, z - 0.5), (x + 0.33, yf, z + 0.47), 'giallo_sicurezza', s=0.025)
    c.scatola((x - 0.27, yf, z - 0.27), (x + 0.27, yf + 0.012, z + 0.27), 'nero_opaco')
    for (bx, bz) in ((x - 0.28, z - 0.43), (x + 0.28, z - 0.43), (x - 0.28, z + 0.4), (x + 0.28, z + 0.4)):
        c.cilindro((bx, yf, bz), (bx, yf + 0.012, bz), 0.016, 'inox', seg=8)
    c.cilindro((x, yf + 0.012, z), (x, yf + 0.07, z), 0.14, 'nero_opaco', seg=32)
    c.cilindro((x, yf + 0.07, z), (x, yf + 0.13, z), 0.075, 'inox', seg=24)
    t = yf + 0.13
    c.disco((x, t, z), (0, -1, 0), 0.25, 'rosso_pulsante', seg=48)
    c.cilindro((x, t, z), (x, t + 0.03, z), 0.25, 'rosso_pulsante', seg=48, tappi=False)
    c.toro((x, t + 0.03, z), (0, 1, 0), 0.235, 0.015, 'rosso_pulsante', seg=48, seg_r=6)
    cupola(c, (x, t + 0.03, z), (0, 1, 0), 0.25, 0.11, 'rosso_pulsante', seg=48)
    # lampeggiante sulla cassetta
    yb = (y + yf) / 2
    zb = z + 0.47
    c.cilindro((x, yb, zb), (x, yb, zb + 0.07), 0.13, 'nero_opaco', seg=32)
    c.cilindro((x, yb, zb + 0.07), (x, yb, zb + 0.22), 0.105, 'faro_giallo', seg=32, tappi=False)
    cupola(c, (x, yb, zb + 0.22), (0, 0, 1), 0.105, 0.1, 'faro_giallo', seg=32)
    for k in range(4):   # gabbia
        a = math.radians(45 + 90 * k)
        d = Vector((math.cos(a), math.sin(a), 0))
        P = Vector((x, yb, zb + 0.07))
        c.tubo([tuple(P + d * 0.12), tuple(P + d * 0.12 + Vector((0, 0, 0.16))), tuple(P + d * 0.08 + Vector((0, 0, 0.26))),
                tuple(P + Vector((0, 0, 0.29)))], 0.007, 'nero_opaco', seg=6)
    c.toro((x, yb, zb + 0.16), (0, 0, 1), 0.12, 0.007, 'nero_opaco', seg=32, seg_r=4)
    ob = c.crea('prop_pulsante_a')
    K.collisione_scatola('prop_pulsante_a', (x - 0.33, y, z - 0.5), (x + 0.33, yf + 0.25, z + 0.47), padre=ob)
    DATI['pulsante_a'] = dict(pulsante_godot=a_godot((x, t + 0.14, z)), faro_godot=a_godot((x, yb, zb + 0.2)),
                              nota="pulsante 2,25 / -1,12 / 5,0 (Godot) sulla parete sud tra due bocchette; fungo Ø 50 cm, sporge 48 cm")
    return [ob]


def pulsante_b(mats):
    """Versione B: piastra 1,1 x 1,1 m a strisce gialle e nere con il pulsante rosso (Ø 42 cm) al
    centro; sul bordo della vasca, sopra, il cartello senza scritte su due pali e un faretto."""
    x, y, z = PB['x'], PB['y'], PB['z']
    c = K.Costruttore(mats)
    L = 0.55
    yf = y + 0.03
    c.scatola((x - L, y, z - L), (x + L, yf, z + L), 'metallo', senza=('+y',))
    # fronte con la texture (u da +x a -x: chi guarda la parete guarda verso -y)
    c.faccia([(x + L, yf, z - L), (x - L, yf, z - L), (x - L, yf, z + L), (x + L, yf, z + L)], 'strisce',
             uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    c.cilindro((x, yf, z), (x, yf + 0.05, z), 0.26, 'nero_opaco', seg=48)
    c.cilindro((x, yf + 0.05, z), (x, yf + 0.13, z), 0.21, 'rosso_pulsante', seg=48, tappi=False)
    c.toro((x, yf + 0.13, z), (0, 1, 0), 0.195, 0.015, 'rosso_pulsante', seg=48, seg_r=6)
    cupola(c, (x, yf + 0.13, z), (0, 1, 0), 0.21, 0.045, 'rosso_pulsante', seg=48)
    ob = c.crea('prop_pulsante_b')
    K.collisione_scatola('prop_pulsante_b', (x - L, y, z - L), (x + L, yf + 0.18, z + L), padre=ob)
    # cartello sul bordo della vasca, sopra il pulsante, rivolto verso la piscina (+y)
    c = K.Costruttore(mats)
    yc = y - 0.32
    W, H, zc = 1.2, 0.9, 0.42
    for sx in (-1, 1):
        c.cilindro((x + sx * 0.52, yc - 0.03, 0.0), (x + sx * 0.52, yc - 0.03, zc + H + 0.08), 0.032, 'inox', seg=12)
        c.cilindro((x + sx * 0.52, yc - 0.03, 0.0), (x + sx * 0.52, yc - 0.03, 0.02), 0.07, 'inox', seg=12)
    c.scatola((x - W / 2 - 0.03, yc - 0.05, zc - 0.03), (x + W / 2 + 0.03, yc, zc + H + 0.03), 'metallo')
    c.faccia([(x + W / 2, yc + 0.002, zc), (x - W / 2, yc + 0.002, zc), (x - W / 2, yc + 0.002, zc + H), (x + W / 2, yc + 0.002, zc + H)],
             'cartello', uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    # faretto su un braccio davanti al cartello: illumina cartello e pulsante
    top = Vector((x, yc - 0.03, zc + H + 0.08))
    testa = Vector((x, yc + 0.5, zc + H + 0.32))
    c.tubo([tuple(top), tuple(top + Vector((0, 0.1, 0.22))), tuple(testa - Vector((0, 0.05, 0)))], 0.018, 'nero_opaco', seg=8)
    bersaglio = Vector((x, y + 0.2, z + 0.25))
    d = (bersaglio - testa).normalized()
    c.cilindro(tuple(testa - d * 0.1), tuple(testa + d * 0.08), 0.075, 'nero_opaco', seg=16)
    c.disco(tuple(testa + d * 0.081), tuple(d), 0.06, 'vetro_lampada', seg=16)
    cart = c.crea('prop_cartello_b')
    K.collisione_scatola('prop_cartello_b', (x - W / 2 - 0.03, yc - 0.08, 0), (x + W / 2 + 0.03, yc + 0.02, zc + H + 0.1), padre=cart)
    DATI['pulsante_b'] = dict(pulsante_godot=a_godot((x, yf + 0.18, z)), faretto_godot=a_godot(testa + d * 0.12),
                              mira_faretto_godot=a_godot(Vector((x, y + 0.1, -0.45))),
                              cartello_godot=a_godot((x, yc, zc + H / 2)),
                              nota="piastra a strisce 1,1 x 1,1 m, pulsante Ø 42 cm; cartello 1,2 x 0,9 m sul bordo, sopra il pulsante")
    return [ob, cart]


# ----------------------------------------------------------------------------- 3. sala della torre

def _modulo(mats, L, h, alta, nome, pos, rot, oblo=False, oblo_z=None):
    if alta:
        ob = K.parete(mats, L, alta=True, altezza=h, mat_alta='intonaco_alto', nome=nome, suddividi=0.5,
                      **({'oblo': True, 'oblo_z': oblo_z} if oblo else {}))
    else:
        ob = K.parete(mats, L, altezza=h, oblo=oblo, nome=nome, suddividi=0.25, cornici=True)
    return S.metti(ob, pos, rot)


def pareti_con_varco(mats, lato, a, b, h):
    """Le pareti della sala come ambiente_sala.pareti(), con un varco largo da a a b (coordinata lungo
    la parete: x per la parete nord, y per la parete est) e alto h, sotto il soffitto.
    Restituisce gli oggetti (stessi nomi di prima: sala_pareti_basse, sala_pareti_alte, sala_obloi)."""
    sotto, sopra, oblo = [], [], []
    H1, H2 = S.Z_GAL, S.Z_SOFF - S.Z_GAL
    VANO = S.VANO
    # parete sud: come prima (porta degli spogliatoi)
    x, i = X0, 0
    a_vano = VANO['cx'] - 1.0
    while x < X1 - 1e-6:
        if abs(x - a_vano) < 1e-6:
            sotto.append(S.metti(K.parete_porta(mats, 2.0, H1, luce=VANO['luce'], h_porta=VANO['h'], nome=f'ps_{i}',
                                                suddividi=0.25, ante=False, telaio=False, cornici=True), (x + 2.0, Y0, 0), 180))
            x += 2.0; i += 1
            continue
        w = min(2.0, X1 - x)
        if x < a_vano < x + w - 1e-6:
            w = a_vano - x
        sotto.append(S.metti(K.parete(mats, w, altezza=H1, nome=f'ps_{i}', suddividi=0.25, cornici=True), (x + w, Y0, 0), 180))
        x += w; i += 1
    for i in range(20):
        xa = X0 + 2 * i
        sopra.append(S.metti(K.parete(mats, 2.0, alta=True, altezza=H2, mat_alta='intonaco_alto', nome=f'pss_{i}', suddividi=0.5), (xa + 2, Y0, S.Z_GAL), 180))

    def lungo_parete(s0, s1, pezzo):
        """Divide [s0, s1] in moduli da 2 m spezzati ai bordi del varco [a, b]; pezzo(t0, t1, dentro)."""
        tagli = sorted(set([s0, s1] + [v for v in (a, b) if s0 < v < s1]))
        for t0, t1 in zip(tagli, tagli[1:]):
            dentro = a - 1e-6 <= t0 and t1 <= b + 1e-6
            pezzo(t0, t1, dentro)

    lintello = []
    # nord (y = 24), fronte verso -y
    for i in range(20):
        xa = X0 + 2 * i
        if lato != 'n':
            sotto.append(S.metti(K.parete(mats, 2.0, altezza=H1, nome=f'pn_{i}', suddividi=0.25, cornici=True), (xa, Y1, 0)))
            sopra.append(S.metti(K.parete(mats, 2.0, alta=True, altezza=H2, mat_alta='intonaco_alto', nome=f'pns_{i}', suddividi=0.5), (xa, Y1, S.Z_GAL)))
            continue
        def pezzo_n(t0, t1, dentro, i=i):
            L = t1 - t0
            if not dentro:
                sotto.append(_modulo(mats, L, H1, False, f'pn_{i}_{t0:g}', (t0, Y1, 0), 0))
                sopra.append(_modulo(mats, L, H2, True, f'pns_{i}_{t0:g}', (t0, Y1, S.Z_GAL), 0))
            else:
                zb = max(h, S.Z_GAL)
                if h < S.Z_GAL:
                    sotto.append(_modulo(mats, L, S.Z_GAL - h, True, f'pnl_{i}_{t0:g}', (t0, Y1, h), 0))
                sopra.append(_modulo(mats, L, S.Z_SOFF - zb, True, f'pns_{i}_{t0:g}', (t0, Y1, zb), 0))
                lintello.append(((t0, Y1, h), (t1, Y1 + K.SPESSORE_PARETE, h)))
        lungo_parete(xa, xa + 2, pezzo_n)
    # est (x = 20), fronte verso -x; ovest (x = -20), fronte verso +x: oblò a moduli alterni
    for i in range(int(round((Y1 - Y0) / 2))):
        yb = Y0 + 2 * i
        ob_s = (i % 2 == 1)
        ob_a = (i % 2 == 0)
        sotto.append(S.metti(K.parete(mats, 2.0, altezza=H1, oblo=ob_s, nome=f'po_{i}', suddividi=0.25, cornici=True), (X0, yb, 0), 90))
        sopra.append(S.metti(K.parete(mats, 2.0, alta=True, altezza=H2, oblo=ob_a, oblo_z=2.2, mat_alta='intonaco_alto',
                                      nome=f'pos_{i}', suddividi=0.5), (X0, yb, S.Z_GAL), 90))
        if ob_s:
            oblo.append(S.metti(K.oblo(mats, nome=f'oblo_o_{i}'), (X0, yb + 1, K.OBLO_Z), 90))
        if ob_a:
            oblo.append(S.metti(K.oblo(mats, nome=f'obloa_o_{i}'), (X0, yb + 1, S.Z_GAL + 2.2), 90))
        if lato != 'e' or yb + 2 <= a or yb >= b:
            sotto.append(S.metti(K.parete(mats, 2.0, altezza=H1, oblo=ob_s, nome=f'pe_{i}', suddividi=0.25, cornici=True), (X1, yb + 2, 0), -90))
            sopra.append(S.metti(K.parete(mats, 2.0, alta=True, altezza=H2, oblo=ob_a, oblo_z=2.2, mat_alta='intonaco_alto',
                                          nome=f'pes_{i}', suddividi=0.5), (X1, yb + 2, S.Z_GAL), -90))
            if ob_s:
                oblo.append(S.metti(K.oblo(mats, nome=f'oblo_e_{i}'), (X1, yb + 1, K.OBLO_Z), -90))
            if ob_a:
                oblo.append(S.metti(K.oblo(mats, nome=f'obloa_e_{i}'), (X1, yb + 1, S.Z_GAL + 2.2), -90))
            continue
        def pezzo_e(t0, t1, dentro, i=i):
            # modulo da t0 a t1 lungo y: sulla parete est il modulo va da y = t1 (origine) verso t0
            L = t1 - t0
            if not dentro:
                sotto.append(_modulo(mats, L, H1, False, f'pe_{i}_{t0:g}', (X1, t1, 0), -90))
                sopra.append(_modulo(mats, L, H2, True, f'pes_{i}_{t0:g}', (X1, t1, S.Z_GAL), -90))
            else:
                zb = max(h, S.Z_GAL)
                if h < S.Z_GAL:
                    sotto.append(_modulo(mats, L, S.Z_GAL - h, True, f'pel_{i}_{t0:g}', (X1, t1, h), -90))
                sopra.append(_modulo(mats, L, S.Z_SOFF - zb, True, f'pes_{i}_{t0:g}', (X1, t1, zb), -90))
                lintello.append(((X1, t0, h), (X1 + K.SPESSORE_PARETE, t1, h)))
        lungo_parete(yb, yb + 2, pezzo_e)
    basse, alte = S.unisci(sotto, 'sala_pareti_basse'), S.unisci(sopra, 'sala_pareti_alte')
    S.D.colora(basse, S.D.sporco_pareti_basse)
    S.D.colora(alte, S.D.sporco_pareti_alte)
    c = K.Costruttore(mats)   # intradosso del varco (la faccia sotto il muro che resta sopra)
    for (lo, hi) in lintello:
        c.faccia([(lo[0], lo[1], lo[2]), (lo[0], hi[1], lo[2]), (hi[0], hi[1], lo[2]), (hi[0], lo[1], lo[2])], 'metallo')
    return [basse, alte, S.unisci(oblo, 'sala_obloi'), c.crea('sala_varco_intradosso')]


def stanza(mats, x0, x1, y0, y1, h, nome, aperture=()):
    """Sala nuova (scatola): pavimento come la sala, pareti in cemento verniciato, soffitto scuro.
    aperture: lati ('s', 'o') dove la parete manca (lì c'è il varco della sala grande)."""
    c = K.Costruttore(mats)
    c.faccia_griglia([(x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0)], 'pavimento', 2.0)
    t = K.Costruttore(mats)   # soffitto a parte: nelle piante si toglie
    t.faccia_griglia([(x0, y1, h), (x1, y1, h), (x1, y0, h), (x0, y0, h)], 'stanza_soffitto', 4.0)
    muri = {'s': [(x1, y0), (x0, y0)], 'n': [(x0, y1), (x1, y1)], 'o': [(x0, y0), (x0, y1)], 'e': [(x1, y1), (x1, y0)]}
    for lato, (p, q) in muri.items():
        if lato in aperture:
            continue
        c.faccia_griglia([(p[0], p[1], 1.2), (q[0], q[1], 1.2), (q[0], q[1], h), (p[0], p[1], h)], 'stanza_muro', 2.0)
        c.faccia_griglia([(p[0], p[1], 0), (q[0], q[1], 0), (q[0], q[1], 1.2), (p[0], p[1], 1.2)], 'cemento', 2.0)
    ob = c.crea(nome, sporco=lambda co: 0.55 + 0.45 * min(1.0, co.z / 3.0))
    K.collisione_scatola(nome + '_pavimento', (x0, y0, -0.2), (x1, y1, 0.0), padre=ob)
    return [ob, t.crea(nome + '_soffitto')]


def cancello_sbarre(mats, cx, h, w):
    """Cancello a due ante a sbarre nel varco della parete nord (x da cx-w/2 a cx+w/2), chiuso con
    catena e lucchetto, dentro un portale blu con l'insegna della torre e due lampade rosse."""
    c = K.Costruttore(mats)
    y = Y1 - 0.05
    xa, xb = cx - w / 2, cx + w / 2
    for xx in (xa, cx, xb):   # montanti delle ante
        c.scatola((xx - 0.06, y - 0.06, 0), (xx + 0.06, y + 0.06, h - 0.05), 'acciaio_cancello')
    for zz in (0.12, 1.0, h / 2 + 0.4, h - 0.15):
        c.scatola((xa, y - 0.05, zz - 0.05), (xb, y + 0.05, zz + 0.05), 'acciaio_cancello')
    k = xa + 0.16
    while k < xb - 0.1:
        if abs(k - cx) > 0.1:
            c.cilindro((k, y, 0.1), (k, y, h - 0.1), 0.022, 'acciaio_cancello', seg=8)
            c.cilindro((k, y, h - 0.1), (k, y, h + 0.08), 0.012, 'acciaio_cancello', seg=6)
        k += 0.16
    c.scatola((xa, y - 0.02, 0.12), (xb, y + 0.02, 1.0), 'acciaio_cancello')   # pannello basso
    # catena e lucchetto a metà
    for j in range(9):
        a = math.radians(j * 40)
        p = Vector((cx + 0.22 * math.cos(a), y - 0.09, 1.45 + 0.14 * math.sin(a)))
        c.toro(tuple(p), (math.sin(a), 0, -math.cos(a)) if j % 2 else (0, 1, 0), 0.05, 0.012, 'inox', seg=12, seg_r=5)
    c.scatola((cx - 0.08, y - 0.16, 1.18), (cx + 0.08, y - 0.1, 1.34), 'ottone' if 'ottone' in mats.cache else 'inox')
    c.toro((cx, y - 0.13, 1.37), (0, 1, 0), 0.05, 0.012, 'inox', seg=12, seg_r=5)
    cancello = c.crea('prop_cancello_torre')
    K.collisione_scatola('prop_cancello_torre', (xa, y - 0.08, 0), (xb, y + 0.08, h), padre=cancello)
    # portale: pilastri blu, trave, insegna
    p = K.Costruttore(mats)
    yp = Y1 - 0.25
    for sx in (-1, 1):
        x = cx + sx * (w / 2 + 0.3)
        p.scatola_smussata((x - 0.3, yp, 0), (x + 0.3, Y1, h + 0.5), 'portale_blu', s=0.03)
        p.scatola_smussata((x - 0.36, yp - 0.04, 0), (x + 0.36, Y1, 0.35), 'cemento', s=0.02)
        # lampada rossa in cima al pilastro (verde quando si apre: lo decide Godot)
        p.cilindro((x, yp + 0.12, h + 0.5), (x, yp + 0.12, h + 0.6), 0.14, 'nero_opaco', seg=24)
        p.cilindro((x, yp + 0.12, h + 0.6), (x, yp + 0.12, h + 0.78), 0.11, 'faro_rosso', seg=24, tappi=False)
        cupola(p, (x, yp + 0.12, h + 0.78), (0, 0, 1), 0.11, 0.1, 'faro_rosso', seg=24)
    p.scatola_smussata((cx - w / 2 - 0.6, yp, h), (cx + w / 2 + 0.6, Y1, h + 0.5), 'portale_blu', s=0.03)
    # insegna (2048 x 640) sopra la trave, sopra le lampade dei pilastri
    W_ins = w + 0.6
    H_ins = W_ins * 640 / 2048
    zi = h + 1.05
    p.scatola((cx - W_ins / 2 - 0.08, yp + 0.02, zi - 0.08), (cx + W_ins / 2 + 0.08, Y1, zi + H_ins + 0.08), 'nero_opaco')
    p.faccia([(cx - W_ins / 2, yp + 0.015, zi), (cx + W_ins / 2, yp + 0.015, zi), (cx + W_ins / 2, yp + 0.015, zi + H_ins),
              (cx - W_ins / 2, yp + 0.015, zi + H_ins)], 'insegna_torre', uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    portale = p.crea('prop_portale_torre')
    for sx in (-1, 1):
        x = cx + sx * (w / 2 + 0.3)
        K.collisione_scatola(f'prop_pilastro_{sx}', (x - 0.3, yp, 0), (x + 0.3, Y1, h + 0.5), padre=portale)
    luci = [a_godot((cx + sx * (w / 2 + 0.3), yp + 0.12, h + 0.75)) for sx in (-1, 1)]
    return [cancello, portale], luci, a_godot((cx, yp - 0.6, zi + H_ins / 2))


def portone_est(mats, cy, h, w):
    """Portone scorrevole nel varco della parete est (y da cy-w/2 a cy+w/2): lamiera gialla con la torre
    dipinta, binario in alto, bande a strisce, lampeggiante rosso; luce della sala dietro che filtra
    sotto e ai lati."""
    c = K.Costruttore(mats)
    x = X1 - 0.12
    ya, yb = cy - w / 2 - 0.15, cy + w / 2 + 0.15
    c.scatola((x - 0.08, ya, 0.06), (x, yb, h + 0.1), 'acciaio_cancello')
    # faccia dipinta verso la sala (-x); u da y alto a y basso (chi guarda verso +x ha +y a sinistra)
    c.faccia([(x - 0.081, yb, 0.06), (x - 0.081, ya, 0.06), (x - 0.081, ya, h + 0.1), (x - 0.081, yb, h + 0.1)], 'portone',
             uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    # binario e carrelli
    c.scatola((x - 0.2, ya - 2.0, h + 0.25), (x - 0.02, yb + 0.6, h + 0.4), 'acciaio_cancello')
    for yy in (ya + 0.5, yb - 0.5):
        c.cilindro((x - 0.14, yy, h + 0.14), (x - 0.14, yy, h + 0.24), 0.07, 'nero_opaco', seg=16)
        c.cilindro((x - 0.24, yy, h + 0.19), (x - 0.04, yy, h + 0.19), 0.05, 'inox', seg=12)
    # maniglione e serratura con catena
    c.cilindro((x - 0.2, ya + 0.35, 1.0), (x - 0.2, ya + 0.35, 1.6), 0.03, 'inox', seg=10)
    for zz in (1.0, 1.6):
        c.cilindro((x - 0.2, ya + 0.35, zz), (x - 0.08, ya + 0.35, zz), 0.02, 'inox', seg=8)
    portone = c.crea('prop_portone_torre')
    K.collisione_scatola('prop_portone_torre', (x - 0.1, ya, 0), (x, yb, h + 0.1), padre=portone)
    # lampeggiante rosso sopra e insegna luminosa sopra il binario
    p = K.Costruttore(mats)
    zl = h + 0.55
    p.scatola((X1 - 0.05, cy - 0.15, zl - 0.12), (X1, cy + 0.15, zl + 0.05), 'nero_opaco')
    p.cilindro((X1 - 0.2, cy, zl), (X1 - 0.2, cy, zl + 0.08), 0.13, 'nero_opaco', seg=24)
    p.cilindro((X1 - 0.2, cy, zl + 0.08), (X1 - 0.2, cy, zl + 0.26), 0.105, 'faro_rosso', seg=24, tappi=False)
    cupola(p, (X1 - 0.2, cy, zl + 0.26), (0, 0, 1), 0.105, 0.1, 'faro_rosso', seg=24)
    W_ins = w + 1.0
    H_ins = W_ins * 640 / 2048
    zi = h + 1.0
    p.scatola((X1 - 0.3, cy - W_ins / 2 - 0.1, zi - 0.1), (X1, cy + W_ins / 2 + 0.1, zi + H_ins + 0.1), 'nero_opaco')
    p.faccia([(X1 - 0.305, cy + W_ins / 2, zi), (X1 - 0.305, cy - W_ins / 2, zi), (X1 - 0.305, cy - W_ins / 2, zi + H_ins),
              (X1 - 0.305, cy + W_ins / 2, zi + H_ins)], 'insegna_torre', uv=[(0, 0), (1, 0), (1, 1), (0, 1)])
    for sy in (-1, 1):   # staffe dell'insegna
        p.scatola((X1 - 0.3, cy + sy * W_ins * 0.35 - 0.05, zi + H_ins + 0.1), (X1, cy + sy * W_ins * 0.35 + 0.05, zi + H_ins + 0.5), 'nero_opaco')
    # bande a strisce sui due stipiti del varco
    for sy in (-1, 1):
        y0_ = cy + sy * (w / 2 + 0.15)
        p.scatola((X1 - 0.04, min(y0_, y0_ + sy * 0.4), 0), (X1 + 0.0, max(y0_, y0_ + sy * 0.4), h + 0.2), 'nero_opaco')
        p.faccia([(X1 - 0.041, max(y0_, y0_ + sy * 0.4), 0), (X1 - 0.041, min(y0_, y0_ + sy * 0.4), 0),
                  (X1 - 0.041, min(y0_, y0_ + sy * 0.4), h + 0.2), (X1 - 0.041, max(y0_, y0_ + sy * 0.4), h + 0.2)],
                 'strisce', uv=[(0, 0), (0.25, 0), (0.25, 1), (0, 1)])
    insegna = p.crea('prop_insegna_torre')
    return [portone, insegna], [a_godot((X1 - 0.2, cy, zl + 0.25))], a_godot((X1 - 0.9, cy, zi + H_ins / 2))


def torre_nord(mats):
    """Versione 1: la sala della torre è dietro la parete nord, in asse con la piscina. Il varco
    (6 x 5,5 m) è in fondo alla spiaggia; dal cancello a sbarre si vede la torre illuminata."""
    cx, w, h = 0.0, 6.0, 5.5
    obs = pareti_con_varco(mats, 'n', cx - w / 2, cx + w / 2, h)
    obs += stanza(mats, -11.0, 11.0, Y1, Y1 + 20.0, 14.0, 'prop_sala_torre_nord', aperture=('s',))
    canc, luci, insegna = cancello_sbarre(mats, cx, h, w)
    obs += canc
    def nel_portale(p):   # plafoniere e luci della parete nord dove vanno il portale e l'insegna
        return abs(p[1] - Y1) < 0.5 and abs(p[0] - cx) < w / 2 + 1.4 and p[2] < h + 2.9
    lamp, luci_neon, tolti = lampade_a_parete(mats, escludi=(nel_portale,))
    obs.append(lamp)
    torre = (0.0, Y1 + 11.0)
    DATI['torre_nord'] = dict(varco=dict(parete='nord', x=[cx - w / 2, cx + w / 2], altezza=h),
                              sala_godot=dict(x=[-11.0, 11.0], z=[-(Y1 + 20.0), -(Y1 + 0.2)], altezza=14.0),
                              torre_blender=list(torre), torre_godot=a_godot((*torre, 0)),
                              sposta_torre_godot=[round(torre[0] - S.TORRE['cx'], 3), 0.0, round(-(torre[1] - S.TORRE['cy']), 3)],
                              ruota_torre_gradi=0.0, luci_rosse=luci, insegna=insegna, luci_tolte=tolti, luci_neon=luci_neon,
                              nascondi=['sala_cartellone_n1'], sposta_insegna_pesce_godot=[12.0, 0.0, 0.0],
                              faro_torre=a_godot((torre[0] - 3.5, torre[1] - 6.0, 13.2)), mira_torre=a_godot((torre[0], torre[1], 6.0)))
    return obs


def torre_est(mats):
    """Versione 2: la sala della torre è dietro la parete est, dove oggi c'è la torre. Il varco
    (6 x 5 m) è in fondo alla spiaggia, sulla destra; portone pieno con la torre dipinta e l'insegna."""
    cy, w, h = 15.0, 6.0, 5.0
    obs = pareti_con_varco(mats, 'e', cy - w / 2, cy + w / 2, h)
    obs += stanza(mats, X1, X1 + 20.0, 4.0, 26.0, 14.0, 'prop_sala_torre_est', aperture=('o',))
    canc, luci, insegna = portone_est(mats, cy, h, w)
    obs += canc
    torre = (X1 + 10.0, 15.0)
    # plafoniere e luci d'emergenza della parete est che cadono nel varco o nel portale
    def nel_varco(p):
        return abs(p[0] - X1) < 0.5 and cy - w / 2 - 1.4 < p[1] < cy + w / 2 + 1.4 and p[2] < h + 3.0
    lamp, luci_neon, tolti = lampade_a_parete(mats, escludi=(nel_varco,))
    obs.append(lamp)
    DATI['torre_est'] = dict(varco=dict(parete='est', y_blender=[cy - w / 2, cy + w / 2], altezza=h),
                             sala_godot=dict(x=[X1 + 0.2, X1 + 20.0], z=[-26.0, -4.0], altezza=14.0),
                             torre_blender=list(torre), torre_godot=a_godot((*torre, 0)),
                             sposta_torre_godot=[round(torre[0] - S.TORRE['cx'], 3), 0.0, round(-(torre[1] - S.TORRE['cy']), 3)],
                             ruota_torre_gradi=-90.0, luci_rosse=luci, insegna=insegna, luci_tolte=tolti, luci_neon=luci_neon,
                             faro_torre=a_godot((torre[0] - 6.0, torre[1] + 3.5, 13.2)), mira_torre=a_godot((torre[0], torre[1], 6.0)))
    return obs


# ----------------------------------------------------------------------------- esportazione

PEZZI = {'base': base, 'pulsante_a': pulsante_a, 'pulsante_b': pulsante_b, 'torre_nord': torre_nord, 'torre_est': torre_est}


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    scelti = argv[0].split(',') if argv else list(PEZZI)
    os.makedirs(os.path.join(USCITA, 'tex'), exist_ok=True)
    p_dati = os.path.join(USCITA, 'dati.json')
    if os.path.exists(p_dati):
        DATI.update(json.load(open(p_dati)))
    for nome in scelti:
        K.svuota()
        S.GRUPPI.clear(); S._CONTA.clear(); S._MODELLI.clear()
        mats = K.Materiali(S.PALETTE_SALA, per_render=False)
        materiali_proposte(mats)
        obs = PEZZI[nome](mats)
        for o in bpy.context.scene.objects:
            if '-colonly' in o.name or '-convcolonly' in o.name:
                o.hide_render = True
        p = os.path.join(USCITA, f'{nome}.glb')
        # senza immagini: in Godot i materiali M_amb_* diventano quelli della sala (stesse istanze,
        # niente texture doppie in memoria) e i M_prop_* con texture le prendono da proposte/sala/tex
        K.esporta(obs, p, texture='nessuna')
        tri = sum(sum(len(pp.vertices) - 2 for pp in o.data.polygons) for o in obs if o.type == 'MESH')
        print(f'{nome}: {len(obs)} oggetti, {tri} triangoli, {os.path.getsize(p) / 1e6:.1f} MB -> {p}')
    import shutil
    for f in ('cornice_strisce_col.jpg', 'cartello_botola_col.jpg', 'insegna_torre_col.jpg', 'portone_torre_col.jpg'):
        if os.path.exists(os.path.join(TEX, f)):
            shutil.copy(os.path.join(TEX, f), os.path.join(USCITA, 'tex', f))
    DATI['nota'] = ("Proposte del 15 ottobre 2026, NON nel gioco: pezzi montati da godot/tests/proposte_sala.gd "
                    "sopra sala_principale.tscn. Coordinate Godot.")
    with open(p_dati, 'w') as f:
        json.dump(DATI, f, indent=1, ensure_ascii=False)
    print('dati ->', p_dati)


if __name__ == '__main__':
    main()
