"""Pianta e vista di lato di una proposta dell'inseguimento (render ortografici in Cycles) con sopra il percorso
(inseguimento_<v>_percorso.json), le paratie giuste e sbagliate, i punti dove lei ti raggiunge, la grata e l'uscita
(inseguimento_<v>_luci.json). Si lancia sul .blend salvato da inseguimento_proposte.py --blend.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/inseguimento_viste.py <blend> <cartella json> <uscita> <versione>"""
import bpy, bmesh, sys, json, math, os
from PIL import Image, ImageDraw, ImageFont
blend, cart, out, ver = sys.argv[-4:]
percorso = json.load(open(os.path.join(cart, f'inseguimento_{ver}_percorso.json')))
luci = json.load(open(os.path.join(cart, f'inseguimento_{ver}_luci.json')))
X0, Y0, X1, Y1, Z0, Z1 = luci['info']['limiti']
X0 -= 1.5
NOME = {'A': 'Le condotte', 'B': 'Le rapide'}[ver]


def prepara(taglia):
    bpy.ops.wm.open_mainfile(filepath=blend)
    for ob in bpy.data.objects:
        if ob.type != 'MESH' or ob.name.startswith('acqua'):
            continue
        bm = bmesh.new(); bm.from_mesh(ob.data); bm.transform(ob.matrix_world)
        via = [f for f in bm.faces if taglia(f.calc_center_median(), f.normal)]
        bmesh.ops.delete(bm, geom=via, context='FACES')
        bm.transform(ob.matrix_world.inverted()); bm.to_mesh(ob.data); bm.free()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 32; sc.cycles.use_denoising = True
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.7, 0.7, 0.72, 1); bg.inputs[1].default_value = 1.4
    for o in bpy.data.objects:
        if o.name.startswith('acqua'):
            o.hide_render = False
            m = bpy.data.materials.new('acqua_vista'); m.use_nodes = True
            b = m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = (0.1, 0.45, 0.5, 1)
            b.inputs['Alpha'].default_value = 0.45
            o.data.materials.clear(); o.data.materials.append(m)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.clip_end = 300
    sc.render.image_settings.file_format = 'PNG'
    return sc, cam


def lampade(sc, pos):
    for i, p in enumerate(pos):
        l = bpy.data.objects.new(f'l{i}', bpy.data.lights.new(f'l{i}', 'POINT'))
        l.data.energy = 14000; l.data.shadow_soft_size = 5; l.location = p; sc.collection.objects.link(l)


def font(n):
    f = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
    return ImageFont.truetype(f, n) if os.path.exists(f) else ImageFont.load_default()


ROSA, VERDE, ROSSO, GIALLO, CIANO = (255, 40, 120), (40, 230, 90), (255, 50, 40), (255, 210, 0), (0, 220, 255)


def disegna(png, pxy, titolo, legenda):
    im = Image.open(png).convert('RGB'); d = ImageDraw.Draw(im)
    f = font(22)
    occupati = []

    def etichetta(p, testo, colore=(255, 255, 255)):
        w = d.textlength(testo, font=f)
        x = p[0] + 16 if p[0] + 16 + w < im.width - 4 else p[0] - 16 - w
        y = min(max(p[1] - 12, 4), im.height - 30)
        while any(abs(y - oy) < 26 and x < ox + ow and ox < x + w for ox, oy, ow in occupati):
            y += 26
        occupati.append((x, y, w))
        d.text((x, y), testo, fill=colore, font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    # il percorso: rosa nei tubi e nei canali
    pts = [(q['cosa'], pxy(q['x'], q['y'], q['z'])) for q in percorso]
    for (_, a), (_, b) in zip(pts[:-1], pts[1:]):
        d.line([a, b], fill=ROSA, width=7)
    # le paratie: giuste in verde, sbagliate in rosso (il bersaglio da colpire)
    for (pos, colore, _n), b in zip(luci['paratie'], luci['bersagli']):
        p = pxy(*b)
        c = VERDE if colore == 'verde' else ROSSO
        d.rectangle([p[0] - 10, p[1] - 10, p[0] + 10, p[1] + 10], fill=c, outline=(0, 0, 0), width=3)
    # le tappe
    n = 1
    for k, p in pts:
        if k in ('tubo', 'canale'):
            continue
        r = 11
        colore = GIALLO if k == 'grata' else (CIANO if k == 'uscita' else (255, 255, 255))
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=colore, outline=(0, 0, 0), width=3)
        etichetta(p, f'{n} {k}')
        n += 1
    # lei
    for i, L in enumerate(luci['lei']):
        p = pxy(L[0], L[1], L[2])
        r = 15
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], outline=(255, 120, 220), width=6)
        etichetta(p, f'lei {chr(65 + i)}' if L[4] != 'affacciata' else 'lei: SB1', (255, 150, 230))
    W = im.width
    HB = 130 + 26 * len(legenda)
    bar = Image.new('RGB', (W, HB), (20, 20, 22)); db = ImageDraw.Draw(bar)
    db.text((16, 10), titolo, fill=(255, 255, 255), font=font(26))
    for i, riga in enumerate(legenda):
        db.text((16, 48 + 26 * i), riga, fill=(220, 220, 220), font=font(19))
    yl = HB - 60
    db.line([(16, yl), (60, yl)], fill=ROSA, width=7); db.text((68, yl - 11), 'percorso', fill=(220, 220, 220), font=font(19))
    db.rectangle([200, yl - 9, 218, yl + 9], fill=VERDE); db.text((226, yl - 11), 'paratia giusta', fill=(220, 220, 220), font=font(19))
    db.rectangle([400, yl - 9, 418, yl + 9], fill=ROSSO); db.text((426, yl - 11), 'paratia sbagliata', fill=(220, 220, 220), font=font(19))
    yl += 30
    db.ellipse([16, yl - 10, 36, yl + 10], fill=GIALLO, outline=(0, 0, 0)); db.text((44, yl - 11), 'grata', fill=(220, 220, 220), font=font(19))
    db.ellipse([150, yl - 10, 170, yl + 10], fill=CIANO, outline=(0, 0, 0)); db.text((178, yl - 11), 'uscita', fill=(220, 220, 220), font=font(19))
    db.ellipse([290, yl - 12, 314, yl + 12], outline=(255, 120, 220), width=5); db.text((322, yl - 11), 'dove lei ti raggiunge', fill=(220, 220, 220), font=font(19))
    tot = Image.new('RGB', (W, im.height + HB)); tot.paste(bar, (0, 0)); tot.paste(im, (0, HB))
    tot.save(png.replace('.png', '.jpg'), quality=90); os.remove(png)


os.makedirs(out, exist_ok=True)
# --- pianta (dall'alto, senza soffitto e senza quello che sta sopra la bocca)
sc, cam = prepara(lambda c, n: c.z > -16.8)
RX = 1700; RY = int(RX * (Y1 - Y0) / (X1 - X0))
sc.render.resolution_x, sc.render.resolution_y = RX, RY
cam.data.ortho_scale = (X1 - X0); cam.location = ((X0 + X1) / 2, (Y0 + Y1) / 2, 20); cam.rotation_euler = (0, 0, 0)
lampade(sc, [((X0 + X1) / 2 + dx, (Y0 + Y1) / 2 + dy, -10) for dx in (-10, 10) for dy in (-8, 8)])
sc.render.filepath = os.path.join(out, f'inseguimento_{ver}_pianta.png'); bpy.ops.render.render(write_still=True)
k = RX / (X1 - X0)
disegna(sc.render.filepath, lambda x, y, z: ((x - X0) * k, (Y1 - y) * k),
        f'Versione {ver} "{NOME}": pianta (dall\'alto, nord in alto)',
        ['La bocca del tubo arriva dalla torre (a sinistra, muro ovest).', 'Numeri: le tappe dell\'inseguimento.'])
# --- vista di lato (da sud, senza il muro sud e quello che gli sta addosso)
sc, cam = prepara(lambda c, n: c.y < Y0 + 3.2)
RX = 1700; RY = int(RX * (Z1 - Z0 + 2) / (X1 - X0))
sc.render.resolution_x, sc.render.resolution_y = RX, RY
cam.data.ortho_scale = (X1 - X0); cam.location = ((X0 + X1) / 2, Y0 - 40, (Z0 + Z1) / 2); cam.rotation_euler = (math.radians(90), 0, 0)
lampade(sc, [((X0 + X1) / 2 + dx, Y0 + 6, z) for dx in (-12, 0, 12) for z in (Z0 + 6, Z1 - 4)])
sc.render.filepath = os.path.join(out, f'inseguimento_{ver}_lato.png'); bpy.ops.render.render(write_still=True)
k = RX / (X1 - X0)
zc = (Z0 + Z1) / 2
disegna(sc.render.filepath, lambda x, y, z: ((x - X0) * k, RY / 2 - (z - zc) * k),
        f'Versione {ver} "{NOME}": di lato (da sud)',
        ['La bocca (a sinistra, in alto) è sul muro est della torre, a -18 m.', 'Si scende di vasca in vasca fino in fondo.'])
