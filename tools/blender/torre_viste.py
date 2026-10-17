"""Pianta e vista di lato di una proposta della sala della torre (render ortografici in Cycles) con il percorso
della discesa disegnato sopra (da torre_<versione>_percorso.json). Si lancia sul .blend salvato da torre_proposte.py --blend.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/torre_viste.py <blend> <percorso.json> <cartella> <versione>"""
import bpy, bmesh, sys, json, math, os
from mathutils import Vector
from PIL import Image, ImageDraw, ImageFont
blend, pj, out, ver = sys.argv[-4:]
X0, X1, Y0, Y1, Z0, Z1 = 20.2, 40.0, 4.0, 26.0, -20.0, 14.0
def prepara(taglia):
    bpy.ops.wm.open_mainfile(filepath=blend)
    ob = bpy.data.objects[f'torre_{ver}']
    bm = bmesh.new(); bm.from_mesh(ob.data)
    via = [f for f in bm.faces if taglia(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=via, context='FACES'); bm.to_mesh(ob.data); bm.free()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 32; sc.cycles.use_denoising = True
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.7, 0.7, 0.72, 1); bg.inputs[1].default_value = 1.4
    for o in bpy.data.objects:
        if o.name.startswith('acqua'):
            o.hide_render = False
            m = bpy.data.materials.new('acqua_vista'); m.use_nodes = True
            b = m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = (0.1, 0.45, 0.5, 1)
            b.inputs['Alpha'].default_value = 0.55
            o.data.materials.clear(); o.data.materials.append(m)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    sc.render.image_settings.file_format = 'PNG'
    return sc, cam
def font(n):
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',):
        if os.path.exists(f): return ImageFont.truetype(f, n)
    return ImageFont.load_default()
percorso = json.load(open(pj))
COL = {'salto': (255, 210, 0), 'getto': (0, 220, 255)}
def disegna(png, pxy, titolo, legenda):
    im = Image.open(png).convert('RGB'); d = ImageDraw.Draw(im)
    pol = [(p['cosa'], pxy(p)) for p in percorso if p['cosa'].startswith('polaroid')]
    pts = [(p['cosa'], pxy(p)) for p in percorso if not p['cosa'].startswith('polaroid')]
    for (k0, a), (k1, b) in zip(pts[:-1], pts[1:]):
        salto = k1 in ('salto', 'getto') or k0 in ('salto', 'getto')
        colore = COL.get(k1 if k1 in COL else k0, (255, 40, 120)) if salto else (255, 40, 120)
        if salto:   # tratteggio: si vola
            n = max(2, int(math.dist(a, b) / 12))
            for i in range(0, n, 2):
                p0 = (a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
                p1 = (a[0] + (b[0] - a[0]) * (i + 1) / n, a[1] + (b[1] - a[1]) * (i + 1) / n)
                d.line([p0, p1], fill=colore, width=7)
        else:
            d.line([a, b], fill=(255, 40, 120), width=7)
    f = font(22); n = 1
    def etichetta(p, testo, sotto=False):
        w = d.textlength(testo, font=f)
        x = p[0] + 14 if p[0] + 14 + w < im.width - 4 else p[0] - 14 - w
        y = p[1] + (20 if sotto else -12)
        y = min(y, im.height - 30)
        d.text((x, y), testo, fill=(255, 255, 255), font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    for k, p in pts:
        if k in ('scivolo',): continue
        r = 11
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 255, 255), outline=(0, 0, 0), width=3)
        etichetta(p, f'{n} {k}')
        n += 1
    for k, p in pol:
        d.rectangle([p[0] - 8, p[1] - 10, p[0] + 8, p[1] + 10], fill=(255, 255, 255), outline=(0, 0, 0), width=3)
        d.text((p[0] - 60, p[1] + 16), 'Polaroid 10', fill=(255, 255, 255), font=f, stroke_width=3, stroke_fill=(0, 0, 0))
    W = im.width
    HB = 92 + 26 * len(legenda)
    bar = Image.new('RGB', (W, HB), (20, 20, 22)); db = ImageDraw.Draw(bar)
    db.text((16, 10), titolo, fill=(255, 255, 255), font=font(26))
    for i, riga in enumerate(legenda):
        db.text((16, 48 + 26 * i), riga, fill=(220, 220, 220), font=font(19))
    yl = HB - 26
    db.line([(16, yl), (60, yl)], fill=(255, 40, 120), width=7); db.text((68, yl - 11), 'scivolo', fill=(220, 220, 220), font=font(19))
    for i, (k, c) in enumerate(COL.items()):
        x = 170 + i * 170
        for j in range(0, 44, 16): db.line([(x + j, yl), (x + j + 8, yl)], fill=c, width=7)
        db.text((x + 52, yl - 11), 'salto' if k == 'salto' else 'col getto', fill=(220, 220, 220), font=font(19))
    tot = Image.new('RGB', (W, im.height + HB)); tot.paste(bar, (0, 0)); tot.paste(im, (0, HB))
    tot.save(png.replace('.png', '.jpg'), quality=92); os.remove(png)
# --- pianta (dall'alto, senza soffitto né tiranti)
sc, cam = prepara(lambda c, n: n.z < -0.99 and c.z > 13.9)
for o in list(bpy.data.objects):
    pass
RY = 1300; RX = int(RY * (X1 - X0) / (Y1 - Y0))
sc.render.resolution_x, sc.render.resolution_y = RX, RY
cam.data.ortho_scale = (Y1 - Y0); cam.location = ((X0 + X1) / 2, (Y0 + Y1) / 2, 30); cam.rotation_euler = (0, 0, 0)
cam.data.clip_end = 100
for i, z in enumerate((10, 0, -12)):
    l = bpy.data.objects.new(f'l{i}', bpy.data.lights.new(f'l{i}', 'POINT')); l.data.energy = 9000; l.data.shadow_soft_size = 4; l.location = (30, 15, z); sc.collection.objects.link(l)
sc.render.filepath = os.path.join(out, f'torre_{ver}_pianta.png'); bpy.ops.render.render(write_still=True)
k = RY / (Y1 - Y0)
disegna(sc.render.filepath, lambda p: ((p['x'] - X0) * k, (Y1 - p['y']) * k), f'Versione {ver}: pianta (dall\'alto, nord in alto)',
        ['Il portone è a sinistra (ovest).', 'Numeri: le tappe della discesa.'])
# --- vista di lato (da sud, senza muro sud)
sc, cam = prepara(lambda c, n: c.y < 4.5)
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name.startswith('torre_tubo') and o.name != 'torre_tubo_inseguimento':
        pass
RY = 1500; RX = int(RY * (X1 - X0) / (Z1 - Z0))
sc.render.resolution_x, sc.render.resolution_y = RX, RY
cam.data.ortho_scale = (Z1 - Z0); cam.location = ((X0 + X1) / 2, -30, (Z0 + Z1) / 2); cam.rotation_euler = (math.radians(90), 0, 0)
cam.data.clip_end = 200
for i, z in enumerate((10, 0, -12)):
    l = bpy.data.objects.new(f'l{i}', bpy.data.lights.new(f'l{i}', 'POINT')); l.data.energy = 9000; l.data.shadow_soft_size = 4; l.location = (30, 8, z); sc.collection.objects.link(l)
sc.render.filepath = os.path.join(out, f'torre_{ver}_lato.png'); bpy.ops.render.render(write_still=True)
k = RY / (Z1 - Z0)
disegna(sc.render.filepath, lambda p: ((p['x'] - X0) * k, (Z1 - p['z']) * k), f'Versione {ver}: di lato (da sud)',
        ['Il portone (a sinistra) è alla quota', 'della sala grande; il fondo è 20 m', 'più giù, nello scafo.'])
