"""Oggetti col nome JILLY JUBILEE per le proposte: targa, manifesto strappato, insegna.

Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python \
        assets_src/mascotte/jilly_oggetti.py
Le grafiche vengono da jilly_meshy.py (gen/jilly/, solo texture). Qui si invecchiano (sbiadite,
macchie d'acqua, ruggine, scheggiature) e si mettono su modelli semplici. Escono, per ogni stile
(a = lettere a bolle, b = corsivo col nastro), in godot/proposte/mascotte/jilly/:
  targa_<s>.glb     targa smaltata 70 x 39 cm con quattro viti, da avvitare a una parete;
  manifesto_<s>.glb manifesto di carta 70 x 105 cm, ondulato e strappato (bordo irregolare, angolo
                    mancante), con due pezzi di nastro adesivo;
  insegna_<s>.glb   insegna di lamiera dipinta 1,8 x 1,0 m in una cornice d'acciaio con quattro
                    staffe a muro.
Origine al centro del retro, il davanti guarda verso +Y in Blender (+Z... vedi export: -Y Blender
diventa +Z glTF), cioè dopo l'export il davanti guarda verso +Z in Godot.
"""
import math, os, random
import bpy, bmesh
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
GEN = os.path.join(QUI, 'gen', 'jilly')
TEX = os.path.join(QUI, 'jilly_tex')
OUT = os.path.join(REPO, 'godot', 'proposte', 'mascotte', 'jilly')
os.makedirs(TEX, exist_ok=True); os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


# ---------------------------------------------------------------- invecchiamento (texture)
def rumore(w, h, scala, ottave=4, seme=0):
    r = np.random.default_rng(seme)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(ottave):
        s = max(2, int(scala * 2 ** o))
        piccolo = Image.fromarray((r.random((s, max(2, int(s * w / h)))) * 255).astype(np.uint8))
        out += amp * np.asarray(piccolo.resize((w, h), Image.BICUBIC), np.float32) / 255
        tot += amp; amp *= 0.5
    return out / tot


def sbiadisci(im, quanto, carta=(232, 222, 196)):
    im = ImageEnhance.Color(im).enhance(1 - 0.45 * quanto)
    a = np.asarray(im, np.float32)
    a = a * (1 - 0.35 * quanto) + np.array(carta, np.float32) * 0.35 * quanto
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def macchie(im, seme, forza=1.0, ruggine=False):
    w, h = im.size
    a = np.asarray(im, np.float32)
    n = rumore(w, h, 3, 5, seme)
    m = np.clip((n - 0.55) * 4, 0, 1)[..., None] * forza          # macchie d'acqua
    a = a * (1 - 0.35 * m) + np.array([120, 95, 60]) * 0.35 * m
    # colature verticali dall'alto
    col = np.zeros((h, w), np.float32)
    r = np.random.default_rng(seme + 1)
    for _ in range(int(14 * forza)):
        x = r.integers(0, w); lw = r.integers(2, max(3, w // 90)); ln = r.integers(h // 6, h // 2)
        y0 = r.integers(0, h // 3)
        col[y0:y0 + ln, x:x + lw] += np.linspace(0.6, 0, min(ln, h - y0))[:, None]
    col = np.asarray(Image.fromarray((col.clip(0, 1) * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(w / 400)), np.float32)[..., None] / 255
    tinta = np.array([150, 80, 30]) if ruggine else np.array([110, 90, 60])
    a = a * (1 - 0.5 * col) + tinta * 0.5 * col
    # sporco fine
    g = rumore(w, h, 40, 3, seme + 2)[..., None]
    a = a * (0.88 + 0.12 * g)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def scheggiature(im, seme, quante=0.08, sotto=(230, 230, 225), ruggine=True):
    """Smalto saltato: chiazze col fondo (metallo o bianco) e un alone di ruggine."""
    w, h = im.size
    a = np.asarray(im, np.float32)
    n = rumore(w, h, 16, 5, seme)
    soglia = np.quantile(n, 1 - quante)
    m = (n > soglia).astype(np.float32)
    alone = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(w / 300)), np.float32)[..., None] / 255
    if ruggine:
        a = a * (1 - 0.35 * alone) + np.array([140, 75, 35]) * 0.35 * alone
    a = a * (1 - m[..., None]) + np.array(sotto, np.float32) * m[..., None]
    return Image.fromarray(a.clip(0, 255).astype(np.uint8)), m


def ritaglia_logo(p):
    """Il logo su fondo bianco: ritaglio stretto attorno al disegno."""
    im = Image.open(p).convert('RGB')
    a = np.asarray(im, np.int32)
    dentro = (a.sum(-1) < 720)
    ys, xs = np.where(dentro)
    m = 12
    return im.crop((max(0, xs.min() - m), max(0, ys.min() - m), min(im.width, xs.max() + m),
                    min(im.height, ys.max() + m)))


def su_fondo(logo, w, h, fondo, margine=0.08):
    """Il logo centrato su un fondo pieno (il bianco del logo diventa il colore del fondo)."""
    tela = Image.new('RGB', (w, h), fondo)
    lw, lh = int(w * (1 - 2 * margine)), int(h * (1 - 2 * margine))
    l = logo.copy(); l.thumbnail((lw, lh), Image.LANCZOS)
    la = np.asarray(l, np.float32)
    # fondo del logo: il quasi-bianco collegato ai bordi (riempimento dagli angoli), sfumato
    from scipy import ndimage
    etichette, _ = ndimage.label(la.min(-1) > 200)
    bordi = np.unique(np.concatenate([etichette[0], etichette[-1], etichette[:, 0], etichette[:, -1]]))
    aree = np.bincount(etichette.ravel())
    grandi = np.where(aree > 0.004 * etichette.size)[0]   # anche le isole di fondo chiuse tra le lettere
    fondo_m = (np.isin(etichette, np.union1d(bordi[bordi > 0], grandi[grandi > 0]))).astype(np.uint8) * 255
    bianco = np.asarray(Image.fromarray(fondo_m).filter(ImageFilter.GaussianBlur(1.2)),
                        np.float32)[..., None] / 255
    sotto = np.asarray(tela.crop(((w - l.width) // 2, (h - l.height) // 2,
                                  (w - l.width) // 2 + l.width, (h - l.height) // 2 + l.height)), np.float32)
    mix = la * (1 - bianco) + sotto * bianco
    tela.paste(Image.fromarray(mix.astype(np.uint8)), ((w - l.width) // 2, (h - l.height) // 2))
    return tela


def bordo(im, colore, spessore, raggio):
    d = ImageDraw.Draw(im)
    w, h = im.size
    for k in range(spessore):
        d.rounded_rectangle((k, k, w - 1 - k, h - 1 - k), radius=raggio, outline=colore)
    return im


# ---------------------------------------------------------------- Blender
def scena_vuota():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def materiale(nome, colore_png, rug=0.5, met=0.0, rug_png=None):
    m = bpy.data.materials.new(nome); m.use_nodes = True
    m.use_backface_culling = True
    nt, ln = m.node_tree.nodes, m.node_tree.links
    b = nt['Principled BSDF']
    b.inputs['Roughness'].default_value = rug; b.inputs['Metallic'].default_value = met
    if colore_png:
        t = nt.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(colore_png)
        ln.new(t.outputs['Color'], b.inputs['Base Color'])
    if rug_png:
        t = nt.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(rug_png)
        t.image.colorspace_settings.name = 'Non-Color'
        ln.new(t.outputs['Color'], b.inputs['Roughness'])
    return m


def tinta(nome, rgb, rug=0.5, met=0.0):
    m = bpy.data.materials.new(nome); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*rgb, 1)
    b.inputs['Roughness'].default_value = rug; b.inputs['Metallic'].default_value = met
    return m


def collega(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def lastra(nome, w, h, spessore, mat_fronte, mat_lati, raggio=0.0, seg=8):
    """Lastra con il davanti verso -Y (UV 0-1 sul davanti), retro su y = 0."""
    bm = bmesh.new()
    pts = []
    if raggio > 0:
        for cx, cy, a0 in ((w / 2 - raggio, h / 2 - raggio, 0), (-w / 2 + raggio, h / 2 - raggio, 90),
                           (-w / 2 + raggio, -h / 2 + raggio, 180), (w / 2 - raggio, -h / 2 + raggio, 270)):
            for k in range(seg + 1):
                a = math.radians(a0 + 90 * k / seg)
                pts.append((cx + raggio * math.cos(a), cy + raggio * math.sin(a)))
    else:
        pts = [(w / 2, h / 2), (-w / 2, h / 2), (-w / 2, -h / 2), (w / 2, -h / 2)]
    fr = [bm.verts.new((x, -spessore, z)) for x, z in pts]
    rt = [bm.verts.new((x, 0, z)) for x, z in pts]
    f = bm.faces.new(list(reversed(fr))); f.material_index = 0
    b = bm.faces.new(rt); b.material_index = 1
    n = len(pts)
    for i in range(n):
        s = bm.faces.new((fr[i], fr[(i + 1) % n], rt[(i + 1) % n], rt[i])); s.material_index = 1
    bm.normal_update()
    for ff in bm.faces:
        if ff.normal.y > 0 and ff.material_index == 0:
            ff.normal_flip()
    uv = bm.loops.layers.uv.new('UV')
    for ff in bm.faces:
        for l in ff.loops:
            x, _, z = l.vert.co
            l[uv].uv = (x / w + 0.5, z / h + 0.5)
    me = bpy.data.meshes.new(nome); bm.to_mesh(me); bm.free()
    me.materials.append(mat_fronte); me.materials.append(mat_lati)
    return collega(bpy.data.objects.new(nome, me))


def vite(nome, x, z, y, r, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=r * 0.6, location=(x, y, z),
                                        rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object; o.name = nome; o.data.materials.append(mat)
    return o


def esporta(percorso):
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            o.select_set(True)
            for p in o.data.polygons:
                p.use_smooth = False
    bpy.ops.export_scene.gltf(filepath=percorso, export_format='GLB', export_image_format='JPEG',
                              export_jpeg_quality=90, export_yup=True)
    print('ESPORTATO', percorso, flush=True)


def ruota_davanti(o):
    """Il davanti modellato verso -Y diventa +Z in Godot: nessuna rotazione serve (export_yup:
    -Y di Blender = +Z di glTF)."""
    return o


# ---------------------------------------------------------------- targa
def targa(stile):
    W, H = 1400, 780
    logo = ritaglia_logo(os.path.join(GEN, f'logo_{stile}_gpt_0.png'))
    fondo = (236, 226, 200) if stile == 'a' else (24, 38, 82)
    im = su_fondo(logo, W, H, fondo, 0.09)
    im = bordo(im, (40, 30, 70) if stile == 'a' else (200, 160, 60), 14, 60)
    im = sbiadisci(im, 0.45)
    im, m = scheggiature(im, 11 if stile == 'a' else 12, 0.03, sotto=(150, 146, 138))
    im = macchie(im, 3, 0.8, ruggine=True)
    pc = os.path.join(TEX, f'targa_{stile}_col.jpg'); im.save(pc, quality=92)
    rug = (0.35 + 0.5 * m + 0.15 * rumore(W, H, 20, 3, 5)).clip(0, 1)
    pr = os.path.join(TEX, f'targa_{stile}_rug.png')
    Image.fromarray((rug * 255).astype(np.uint8)).save(pr)
    scena_vuota()
    mf = materiale(f'targa_{stile}', pc, rug_png=pr)
    ml = tinta('targa_lati', (0.25, 0.22, 0.2), 0.6, 0.6)
    lastra('targa', 0.70, 0.39, 0.012, mf, ml, raggio=0.03)
    mv = tinta('vite', (0.35, 0.22, 0.12), 0.7, 0.8)
    for i, (x, z) in enumerate(((-0.315, 0.155), (0.315, 0.155), (-0.315, -0.155), (0.315, -0.155))):
        vite(f'vite_{i}', x, z, -0.014, 0.012, mv)
    esporta(os.path.join(OUT, f'targa_{stile}.glb'))


# ---------------------------------------------------------------- manifesto
def manifesto(stile):
    src = Image.open(os.path.join(GEN, f'manifesto_{stile}_gpt_0.png')).convert('RGB')
    W, H = 1024, 1536
    im = src.resize((W, H), Image.LANCZOS)
    im = sbiadisci(im, 0.7)
    im = macchie(im, 21 if stile == 'a' else 22, 1.2)
    # pieghe: due linee chiare (orizzontale e verticale) come di un foglio piegato in quattro
    a = np.asarray(im, np.float32)
    for y in (H // 2,):
        a[y - 3:y + 3] = a[y - 3:y + 3] * 0.7 + 255 * 0.3
    for x in (W // 2,):
        a[:, x - 2:x + 2] = a[:, x - 2:x + 2] * 0.75 + 255 * 0.25
    im = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    pc = os.path.join(TEX, f'manifesto_{stile}_col.jpg'); im.save(pc, quality=92)
    scena_vuota()
    mf = materiale(f'manifesto_{stile}', pc, rug=0.85)
    mr = tinta('carta_retro', (0.75, 0.72, 0.62), 0.9)
    w, h = 0.70, 1.05
    # foglio suddiviso, ondulato, col bordo strappato (facce tolte fuori da una maschera irregolare)
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=56, y_subdivisions=84, size=1)
    o = bpy.context.active_object; o.name = 'manifesto'
    o.scale = (w, h, 1); bpy.ops.object.transform_apply(scale=True)
    o.rotation_euler = (math.pi / 2, 0, 0); bpy.ops.object.transform_apply(rotation=True)
    bm = bmesh.new(); bm.from_mesh(o.data)
    r = random.Random(5 if stile == 'a' else 6)
    nb = rumore(256, 384, 6, 4, 31 if stile == 'a' else 32)
    via = []
    for f in bm.faces:
        c = f.calc_center_median()
        u, v = c.x / w + 0.5, c.z / h + 0.5
        d = min(u, 1 - u, v, 1 - v)
        n = nb[int((1 - v) * 383), int(u * 255)]
        strappo = d < 0.012 + 0.03 * n
        if stile == 'a':   # angolo mancante in basso a destra (nel manifesto A il testo ci sta dentro)
            angolo = (u > 0.78 and v < 0.20 and (u - 0.78) / 0.22 + (0.20 - v) / 0.20 > 0.9 + 0.3 * n)
        else:              # nel B la riga degli orari arriva ai bordi: l'angolo va in alto a destra
            angolo = (u > 0.84 and v > 0.86 and (u - 0.84) / 0.16 + (v - 0.86) / 0.14 > 0.9 + 0.3 * n)
        if strappo or angolo:
            via.append(f)
    bmesh.ops.delete(bm, geom=via, context='FACES')
    for vtx in bm.verts:
        u, v = vtx.co.x / w + 0.5, vtx.co.z / h + 0.5
        bordo_v = min(u, 1 - u, v, 1 - v)
        # ondulazione della carta bagnata e angoli che si staccano dal muro
        vtx.co.y = -(0.004 + 0.006 * math.sin(u * 9 + v * 4) ** 2 + 0.03 * max(0, 0.12 - bordo_v) * (v < 0.3))
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            l[uv].uv = (l.vert.co.x / w + 0.5, l.vert.co.z / h + 0.5)
    bm.to_mesh(o.data); bm.free()
    o.data.materials.append(mf)
    # retro: copia con le normali girate (la carta ha due facce)
    retro = o.copy(); retro.data = o.data.copy(); collega(retro)
    bm = bmesh.new(); bm.from_mesh(retro.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for vtx in bm.verts:
        vtx.co.y += 0.0008
    bm.to_mesh(retro.data); bm.free()
    retro.data.materials.clear(); retro.data.materials.append(mr)
    # due pezzi di nastro adesivo in alto
    mt = tinta('nastro', (0.78, 0.72, 0.5), 0.35)
    for i, x in enumerate((-0.25, 0.25)):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, -0.012, h / 2 - 0.03))
        t = bpy.context.active_object; t.scale = (0.12, 0.035, 1)
        t.rotation_euler = (math.pi / 2, (-1) ** i * 0.3, 0); t.data.materials.append(mt)
    esporta(os.path.join(OUT, f'manifesto_{stile}.glb'))


# ---------------------------------------------------------------- insegna
def insegna(stile):
    W, H = 2048, 1138
    logo = ritaglia_logo(os.path.join(GEN, f'logo_{stile}_gpt_0.png'))
    fondo = (30, 120, 150) if stile == 'a' else (246, 238, 214)
    im = su_fondo(logo, W, H, fondo, 0.07)
    im = bordo(im, (250, 245, 230) if stile == 'a' else (24, 38, 82), 26, 0)
    im = sbiadisci(im, 0.5)
    im, m = scheggiature(im, 41 if stile == 'a' else 42, 0.045, sotto=(170, 165, 155))
    im = macchie(im, 43, 1.3, ruggine=True)
    pc = os.path.join(TEX, f'insegna_{stile}_col.jpg'); im.save(pc, quality=92)
    rug = (0.45 + 0.4 * m + 0.15 * rumore(W, H, 20, 3, 6)).clip(0, 1)
    pr = os.path.join(TEX, f'insegna_{stile}_rug.png')
    Image.fromarray((rug * 255).astype(np.uint8)).save(pr)
    scena_vuota()
    mf = materiale(f'insegna_{stile}', pc, rug_png=pr)
    acc = tinta('acciaio_ruggine', (0.28, 0.2, 0.15), 0.75, 0.7)
    w, h, sp = 1.8, 1.0, 0.03   # sta tra due oblò, con un margine sopra il neon del muro ovest
    lastra('pannello', w, h, sp, mf, acc)
    # cornice: quattro profilati davanti al pannello, staccata dal muro dalle staffe
    for nome, (x, z, sx, sz) in {'cornice_su': (0, h / 2, w + 0.1, 0.06), 'cornice_giu': (0, -h / 2, w + 0.1, 0.06),
                                 'cornice_sx': (-w / 2, 0, 0.06, h), 'cornice_dx': (w / 2, 0, 0.06, h)}.items():
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -sp - 0.02, z))
        c = bpy.context.active_object; c.name = nome; c.scale = (sx, 0.05, sz); c.data.materials.append(acc)
    # staffe a muro: il pannello sta 12 cm davanti alla parete
    for i, (x, z) in enumerate(((-0.7, 0.32), (0.7, 0.32), (-0.7, -0.32), (0.7, -0.32))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0.06, z))
        s = bpy.context.active_object; s.name = f'staffa_{i}'; s.scale = (0.04, 0.12, 0.04)
        s.data.materials.append(acc)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, 0.115, z))
        p = bpy.context.active_object; p.name = f'piastra_{i}'; p.scale = (0.11, 0.01, 0.11)
        p.data.materials.append(acc)
    # tutto spostato in avanti di 12 cm: il retro delle piastre sta a y = 0 (la parete)
    for o in bpy.context.scene.objects:
        o.location.y -= 0.12
    esporta(os.path.join(OUT, f'insegna_{stile}.glb'))


for s in ('a', 'b'):
    targa(s); manifesto(s); insegna(s)
