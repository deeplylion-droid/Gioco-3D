"""Polaroid del capitolo 1: modello 3D dell'oggetto da raccogliere, esportato in GLB.

Uso (dalla radice del repository):
    /home/user/tools/blender-venv/bin/python tools/blender/polaroid_modello.py

Prima vanno create le texture con tools/blender/polaroid_cornice.py.
Uscita, in assets_src/polaroid/:
    polaroid.glb    una sola mesh "Polaroid" (cartoncino 88 x 107 mm, spesso 0,7 mm e 1,3 mm in
                    basso dove c'è la sacca dei reagenti, angoli arrotondati, leggermente incurvato),
                    con due superfici: 0 = davanti e bordi (la foto), 1 = retro (comune a tutte).
                    Le 10 foto sono 10 materiali "Polaroid_P01".."Polaroid_P10" scambiabili con
                    l'estensione KHR_materials_variants (varianti "P01".."P10"); quello predefinito
                    è P01. Texture incorporate in JPEG, PNG per la normal map.
    polaroid.blend  la stessa scena per Blender (texture collegate, non incorporate)

Per usarla senza varianti (per esempio in Godot): sulla superficie 0 si mette un materiale con
    albedo = texture/Pxx.jpg, roughness = texture/Pxx_rugosita.jpg (canale grigio),
    normal map = texture/normale.png (OpenGL); sulla superficie 1 il retro.
Unità in metri, origine al centro del cartoncino, faccia della foto verso +Z in Blender (+Y in glTF
diventa l'alto: la foto, appoggiata su un piano, guarda verso l'alto) e lato lungo lungo Y di Blender.
"""
import math, os
import bpy, bmesh

RADICE = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
CART = os.path.join(RADICE, 'assets_src', 'polaroid')
TEX = os.path.join(CART, 'texture')
NOMI = [f'P{i:02d}' for i in range(1, 11)]

MM = 0.001
W, H = 88 * MM, 107 * MM
R = 2.5 * MM                # raggio degli angoli
SPESSORE = 0.7 * MM         # cartoncino
SACCA = 0.6 * MM            # in più sul retro, nella fascia in basso (sacca dei reagenti)
PASSO = 6 * MM              # passo della griglia


def coordinate(lato, r):
    """Linee della griglia su un lato: fitte vicino agli angoli, poi regolari."""
    n = max(2, round((lato - 2 * r) / PASSO))
    mezzo = [r + (lato - 2 * r) * i / n for i in range(n + 1)]
    return [0.0, 0.3 * r] + mezzo + [lato - 0.3 * r, lato]


def arrotonda(x, y):
    """Porta sull'arco i punti che stanno fuori dagli angoli arrotondati."""
    for cx, cy in ((R, R), (W - R, R), (W - R, H - R), (R, H - R)):
        dentro_x = (x < R and cx == R) or (x > W - R and cx == W - R)
        dentro_y = (y < R and cy == R) or (y > H - R and cy == H - R)
        if dentro_x and dentro_y:
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            if d > R:
                return cx + dx / d * R, cy + dy / d * R
    return x, y


def piega(x, y):
    """Curvatura leggera: il cartoncino si incurva sui lati lunghi e un angolo si alza un po'."""
    u = (x - W / 2) / (W / 2)
    v = (y - H / 2) / (H / 2)
    z = 0.9 * MM * u * u + 0.35 * MM * v * v
    # angolo in alto a destra un po' sollevato
    d = math.hypot(x - W, y - H) / (32 * MM)
    if d < 1:
        z += 1.6 * MM * (1 - d) ** 2
    return z


def sacca(y):
    """Spessore in più sul retro nella fascia in basso (da 0 a 19 mm, con raccordo di 3 mm)."""
    t = min(max((19 * MM - y) / (3 * MM), 0.0), 1.0)
    return SACCA * t * t * (3 - 2 * t)


def costruisci_mesh():
    xs, ys = coordinate(W, R), coordinate(H, R)
    nx, ny = len(xs), len(ys)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new('UVMap')
    fronte, retro = {}, {}
    pos2d = {}
    for j, y in enumerate(ys):
        for i, x in enumerate(xs):
            px, py = arrotonda(x, y)
            pos2d[i, j] = (px, py)
            z = piega(px, py)
            fronte[i, j] = bm.verts.new((px - W / 2, py - H / 2, z + SPESSORE / 2))
            retro[i, j] = bm.verts.new((px - W / 2, py - H / 2, z - SPESSORE / 2 - sacca(py)))

    def uv_fronte(i, j):
        px, py = pos2d[i, j]
        return px / W, py / H

    def uv_retro(i, j):
        px, py = pos2d[i, j]
        return 1 - px / W, py / H

    facce_f, facce_r = [], []
    for j in range(ny - 1):
        for i in range(nx - 1):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            f = bm.faces.new([fronte[k] for k in q])
            f.material_index = 0
            for loop, k in zip(f.loops, q):
                loop[uv].uv = uv_fronte(*k)
            facce_f.append(f)
            qr = list(reversed(q))
            b = bm.faces.new([retro[k] for k in qr])
            b.material_index = 1
            for loop, k in zip(b.loops, qr):
                loop[uv].uv = uv_retro(*k)
            facce_r.append(b)

    # contorno (in senso antiorario visto da sopra) e fianchi
    giro = [(i, 0) for i in range(nx)] + [(nx - 1, j) for j in range(1, ny)] + \
           [(i, ny - 1) for i in range(nx - 2, -1, -1)] + [(0, j) for j in range(ny - 2, 0, -1)]
    cx, cy = W / 2, H / 2
    for a, b in zip(giro, giro[1:] + giro[:1]):
        f = bm.faces.new([retro[a], retro[b], fronte[b], fronte[a]])
        f.material_index = 0
        for loop, k in zip(f.loops, (a, b, b, a)):
            # i fianchi prendono il colore del bordo bianco, appena dentro il contorno
            px, py = pos2d[k]
            dx, dy = cx - px, cy - py
            d = math.hypot(dx, dy)
            px, py = px + dx / d * 1.2 * MM, py + dy / d * 1.2 * MM
            loop[uv].uv = (px / W, py / H)
    bm.normal_update()
    # spigoli vivi tra fianchi e facce
    bordo_f = set(fronte[k] for k in giro)
    bordo_r = set(retro[k] for k in giro)
    for e in bm.edges:
        vs = set(e.verts)
        if vs <= bordo_f or vs <= bordo_r:
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new('Polaroid')
    bm.to_mesh(me)
    bm.free()
    return me


def immagine(nome, colore=True):
    img = bpy.data.images.load(os.path.join(TEX, nome), check_existing=True)
    if not colore:
        img.colorspace_settings.name = 'Non-Color'
    return img


def materiale(nome, col, rug, normale=None):
    m = bpy.data.materials.new(nome)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Metallic'].default_value = 0.0
    t_col = nt.nodes.new('ShaderNodeTexImage')
    t_col.image = immagine(col)
    t_col.location = (-600, 300)
    nt.links.new(t_col.outputs['Color'], bsdf.inputs['Base Color'])
    t_rug = nt.nodes.new('ShaderNodeTexImage')
    t_rug.image = immagine(rug, False)
    t_rug.location = (-600, 0)
    nt.links.new(t_rug.outputs['Color'], bsdf.inputs['Roughness'])
    if normale:
        t_n = nt.nodes.new('ShaderNodeTexImage')
        t_n.image = immagine(normale, False)
        t_n.location = (-600, -300)
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nm.location = (-300, -300)
        nt.links.new(t_n.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    return m


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.addons['io_scene_gltf2'].preferences.KHR_materials_variants_ui = True
    scene = bpy.context.scene
    me = costruisci_mesh()
    ob = bpy.data.objects.new('Polaroid', me)
    scene.collection.objects.link(ob)

    mats = {n: materiale(f'Polaroid_{n}', f'{n}.jpg', f'{n}_rugosita.jpg', 'normale.png') for n in NOMI}
    retro = materiale('Polaroid_retro', 'retro.jpg', 'retro_rugosita.jpg')
    me.materials.append(mats['P01'])
    me.materials.append(retro)

    # varianti glTF: una per foto, tutte sulla superficie 0
    for k, n in enumerate(NOMI):
        v = scene.gltf2_KHR_materials_variants_variants.add()
        v.variant_idx = k
        v.name = n
        d = me.gltf2_variant_mesh_data.add()
        d.material_slot_index = 0
        d.material = mats[n]
        d.variants.add().variant.variant_idx = k
    dm = me.gltf2_variant_default_materials.add()
    dm.material_slot_index = 0
    dm.default_material = mats['P01']
    # i 10 materiali restano nel .blend anche se non usati
    for m in mats.values():
        m.use_fake_user = True

    print('vertici', len(me.vertices), 'facce', len(me.polygons), 'triangoli',
          sum(len(p.vertices) - 2 for p in me.polygons))
    glb = os.path.join(CART, 'polaroid.glb')
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_image_format='AUTO',
                              export_tangents=True, export_materials='EXPORT', use_selection=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CART, 'polaroid.blend'), relative_remap=True)
    print('salvato', glb, os.path.getsize(glb) // 1024, 'KB')


if __name__ == '__main__':
    main()
