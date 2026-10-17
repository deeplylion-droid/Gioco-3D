"""Proposte per la lancia dello zaino-pompa (A pompiere, B cannone giocattolo, C industriale).
Dai GLB di Meshy (assets_src/zaino_lance/ambienti1/, script genera_lance.py): scala reale, punta della lancia in avanti
con l'origine al centro dell'ugello (lì va il nodo Muzzle), tubo verso lo zaino fatto qui, texture ridotte.
Esporta in godot/assets/models/zaino/proposte_lance/<nome>/ (glTF separato, come la lancia attuale) e
fa i render Cycles da tre lati in docs/proposte/zaino/lance/<nome>_3lati.jpg.
Scrive anche <nome>.json con i punti utili per la scena LanceRig (impugnatura, canna), in coordinate Godot.
Uso: /home/user/tools/blender-venv/bin/python tools/blender/lance_proposte.py [nome ...] [--no-render] [--prova]
     con --ugello fa solo il primo piano dell'ugello col punto Muzzle (<nome>_ugello.jpg)"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Matrix, Vector
import ambienti2_comune as C

RADICE = C.RADICE
SORG = os.path.join(RADICE, 'assets_src', 'zaino_lance', 'ambienti1')
GODOT = os.path.join(RADICE, 'godot', 'assets', 'models', 'zaino', 'proposte_lance')
DOCS = os.path.join(RADICE, 'docs', 'proposte', 'zaino', 'lance')
PROVA = '--prova' in sys.argv

# nome: lunghezza (m, senza il tubo), verso della punta sull'asse lungo ('+'/'-'/'auto'),
#       tubo verso lo zaino: colore, raggio, direzione d'uscita dal moncone (Blender: +Y avanti, +Z su)
LANCE = {
    # misure di gioco (16 ottobre: "molto molto più imponente", circa 1,4 volte le prime proposte)
    'lancia_a_pompiere': dict(lung=0.85, punta='auto', tubo=((0.25, 0.025, 0.02), 0.05, (0, -1, -0.15)), rough=0.8,
                              canna=1.35),   # canna e ugello davanti alla leva più grossi (lancia da pompiere massiccia)
    # B: colori più accesi e più scuri, e un po' di ruggine (richiesta dell'utente, 16 ottobre)
    'lancia_b_cannone': dict(lung=0.95, punta='auto', tubo=((0.0, 0.10, 0.12), 0.025, (0, -0.4, -1)), rough=0.35,
                             colore=dict(sat=2.3, luce=0.55, ruggine=0.06, seme=7)),
    'lancia_c_industriale': dict(lung=0.90, punta='auto', tubo=((0.02, 0.02, 0.02), 0.042, (0, -0.4, -1)), rough=0.6),
    # C con un colore al posto del nero (richiesta dell'utente, 16 ottobre): giallo delle bande e metallo restano
    'lancia_c1_antincendio': dict(file='lancia_c_industriale', lung=0.90, punta='auto', rough=0.6,
                                  tubo=((0.42, 0.04, 0.01), 0.042, (0, -0.4, -1)), nero=(0.80, 0.16, 0.03)),
    'lancia_c2_turchese': dict(file='lancia_c_industriale', lung=0.90, punta='auto', rough=0.6,
                               tubo=((0.0, 0.30, 0.32), 0.042, (0, -0.4, -1)), nero=(0.0, 0.62, 0.64)),
}


def importa(nome):
    C.reset()
    bpy.ops.import_scene.gltf(filepath=os.path.join(SORG, nome + '.glb'))
    ms = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in ms:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    if len(ms) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for img in bpy.data.images:
        if img.size[0] > 2048:
            img.scale(2048, 2048)
    return ob


RUGGINE = os.path.join(RADICE, 'godot', 'assets', 'ambienti_tecnici', 'texture', 'Rust004_Color.jpg')


def ricolora(ob, sat, luce, ruggine, seme):
    """Colori più saturi e più scuri sulla texture del colore, poi chiazze di ruggine (Rust004 di ambientCG, CC0)
    con un bordo scuro, più ruvide e non metalliche. Lavora sulle immagini già caricate (texture in spazio UV)."""
    import numpy as np
    from scipy.ndimage import gaussian_filter
    from PIL import Image
    mat = ob.data.materials[0]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    def immagine_di(ingresso):
        stack = [l.from_node for l in bsdf.inputs[ingresso].links]
        while stack:
            n = stack.pop()
            if n.type == 'TEX_IMAGE':
                return n.image
            stack += [l.from_node for i in n.inputs for l in i.links]
    col, mr = immagine_di('Base Color'), immagine_di('Roughness')
    W, H = col.size
    px = np.array(col.pixels[:], dtype=np.float32).reshape(H, W, 4)
    rgb = px[..., :3]
    # saturazione e luminosità (lo spazio della texture è sRGB: si lavora sui valori così come sono)
    grigio = rgb.mean(axis=2, keepdims=True)
    rgb = np.clip(grigio + (rgb - grigio) * sat, 0, 1) * luce
    # maschera della ruggine: rumore a più scale, soglia per avere circa la copertura voluta
    rnd = np.random.default_rng(seme)
    m = sum(gaussian_filter(rnd.standard_normal((H, W)).astype(np.float32), s) * (s ** 0.9) for s in (14, 40, 110))
    soglia = np.quantile(m, 1.0 - ruggine)
    a = np.clip((m - soglia) / (0.25 * m.std()), 0, 1)
    bordo = np.clip((m - (soglia - 0.35 * m.std())) / (0.35 * m.std()), 0, 1) * (1 - a)
    rug = np.asarray(Image.open(RUGGINE).convert('RGB').resize((512, 512)), dtype=np.float32) / 255.0
    rug = np.flipud(np.tile(rug, (H // 512 + 1, W // 512 + 1, 1))[:H, :W])
    rgb = rgb * (1 - 0.45 * bordo[..., None])                 # alone scuro intorno alle chiazze
    rgb = rgb * (1 - a[..., None]) + rug * 0.85 * a[..., None]
    px[..., :3] = rgb
    col.pixels.foreach_set(px.ravel())
    col.update()
    if mr is not None and mr.size[0] == W:
        q = np.array(mr.pixels[:], dtype=np.float32).reshape(H, W, 4)
        q[..., 1] = q[..., 1] * (1 - a) + 0.85 * a            # G = ruvidezza
        q[..., 2] = q[..., 2] * (1 - a)                        # B = metallo
        mr.pixels.foreach_set(q.ravel())
        mr.update()


def colora_nero(ob, colore):
    """Dove la texture del colore è nera o quasi (scura e poco satura) mette 'colore' (sRGB), tenendo le
    variazioni di luce della texture (graffi, sporco). Il giallo e il metallo chiaro restano come sono."""
    import numpy as np
    mat = ob.data.materials[0]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    stack = [l.from_node for l in bsdf.inputs['Base Color'].links]
    col = None
    while stack and col is None:
        n = stack.pop()
        if n.type == 'TEX_IMAGE':
            col = n.image
        stack += [l.from_node for i in n.inputs for l in i.links]
    W, H = col.size
    px = np.array(col.pixels[:], dtype=np.float32).reshape(H, W, 4)
    rgb = px[..., :3]
    v = rgb.max(axis=2)
    sat = (v - rgb.min(axis=2)) / np.maximum(v, 1e-4)
    m = np.clip((0.30 - v) / 0.10, 0, 1) * np.clip((0.45 - sat) / 0.2, 0, 1)
    lum = np.clip(v / max(float(np.median(v[m > 0.9])) if (m > 0.9).any() else 0.1, 1e-3), 0.45, 1.5)
    nuovo = np.array(colore, dtype=np.float32)[None, None, :] * lum[..., None]
    px[..., :3] = rgb * (1 - m[..., None]) + np.clip(nuovo, 0, 1) * m[..., None]
    col.pixels.foreach_set(px.ravel())
    col.update()


def estremi(ob):
    vs = [v.co for v in ob.data.vertices]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def orienta(ob, cfg):
    """Asse lungo su +Y (avanti) con la punta in avanti, l'impugnatura in basso; origine al centro dell'ugello."""
    lo, hi = estremi(ob)
    size = hi - lo
    # l'asse lungo è il più lungo fra X e Y (Z è l'alto nelle immagini di lato)
    idx = 0 if size.x >= size.y else 1
    s = cfg['lung'] / size[idx]
    ob.data.transform(Matrix.Translation(-(lo + hi) / 2))
    ob.data.transform(Matrix.Scale(s, 4))
    punta = cfg['punta']
    if punta == 'auto':
        # il retro è dalla parte del punto più basso (il fondo dell'impugnatura sta dietro la metà)
        basso = min(ob.data.vertices, key=lambda v: v.co.z).co
        punta = '-' if basso[idx] > 0 else '+'
    d = Vector((0, 0, 0)); d[idx] = 1.0 if punta == '+' else -1.0
    ob.data.transform(d.rotation_difference(Vector((0, 1, 0))).to_matrix().to_4x4())
    lo, hi = estremi(ob)
    # centro dell'ugello: i vertici negli ultimi 1,5 cm davanti
    fr = [v.co for v in ob.data.vertices if v.co.y > hi.y - 0.015]
    cx = (min(v.x for v in fr) + max(v.x for v in fr)) / 2
    cz = (min(v.z for v in fr) + max(v.z for v in fr)) / 2
    ob.data.transform(Matrix.Translation(-Vector((cx, hi.y, cz))))
    ob.name = 'Lancia'
    return punta


def ingrossa_canna(ob, k):
    """Allarga in sezione (X, Z) la canna davanti alla leva: il punto più alto del modello è la leva a staffa,
    davanti a lei (+Y) c'è solo la canna con l'ugello. Raccordo morbido di 5 cm, l'asse della canna resta fermo."""
    lo, hi = estremi(ob)
    y_leva = max(ob.data.vertices, key=lambda v: v.co.z).co.y
    y0 = y_leva + 0.05
    for v in ob.data.vertices:
        if v.co.y > y0:
            t = min(1.0, (v.co.y - y0) / 0.05)
            f = 1.0 + (k - 1.0) * (t * t * (3 - 2 * t))
            v.co.x *= f; v.co.z *= f


def punti_utili(ob):
    """Impugnatura (centro della parte più bassa), canna (sopra l'impugnatura, davanti) e moncone del tubo dietro."""
    lo, hi = estremi(ob)
    vs = [v.co for v in ob.data.vertices]
    z_imp = lo.z + 0.35 * (0 - lo.z)   # fascia bassa: dal fondo a un terzo dell'altezza sotto l'asse
    imp = [v for v in vs if v.z < z_imp]
    gi = sum(imp, Vector()) / len(imp)
    dietro = [v for v in vs if v.y < lo.y + 0.02]
    gd = sum(dietro, Vector()) / len(dietro)
    top = max(vs, key=lambda v: v.z)
    alto = [v for v in vs if v.z > top.z - 0.02]   # la sommità: barra della leva a staffa (A) o della maniglia (C)
    ga = sum(alto, Vector()) / len(alto)
    return dict(impugnatura=gi, retro=gd, cima=ga, lo=lo, hi=hi)


def tubo_zaino(nome, cfg, attacco):
    col, r, dirz = cfg['tubo']
    m = bpy.data.materials.new('tubo_' + nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*col, 1)
    b.inputs['Roughness'].default_value = cfg['rough']
    d = Vector(dirz).normalized()
    a = Vector(attacco)
    # curva di Bézier: esce dal moncone nella sua direzione, poi pende all'indietro verso lo zaino
    P = [a - d * 0.01, a + d * 0.18, a + Vector((0.08, -0.32, -0.45)), a + Vector((0.14, -0.42, -0.95))]
    pts = []
    for k in range(29):
        u = k / 28
        pts.append(P[0] * (1 - u) ** 3 + P[1] * 3 * u * (1 - u) ** 2 + P[2] * 3 * u * u * (1 - u) + P[3] * u ** 3)
    t = C.tubo('tubo_zaino', pts, r, m, rc=0.005, seg=20, uv=None)
    t.name = 'TuboZaino'
    return t


def esporta(nome, obs):
    out = os.path.join(GODOT, nome)
    os.makedirs(out, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, nome + '.gltf'), export_format='GLTF_SEPARATE', use_selection=True,
                              export_apply=True, export_yup=True, export_image_format='JPEG', export_jpeg_quality=88,
                              export_image_quality=88)


def render_3lati(nome, obs, lung):
    """Tre viste con luce neutra: lato destro, lato sinistro, tre quarti da davanti e dall'alto.
    Inquadrate sulla lancia (il primo oggetto); il tubo verso lo zaino esce dal quadro."""
    from PIL import Image
    lo, hi = estremi(obs[0])
    cen = (lo + hi) / 2
    k = lung / 0.6
    C.mondo((0.55, 0.56, 0.58), 1.0)
    C.luce('chiave', 'AREA', cen + Vector((1.2, 0.8, 1.6)), 120, size=1.2, mira=cen)
    C.luce('riempimento', 'AREA', cen + Vector((-1.4, -0.6, 0.6)), 50, size=1.5, mira=cen)
    C.luce('controluce', 'AREA', cen + Vector((0, -1.5, 1.2)), 60, size=1.0, mira=cen)
    viste = [('destra', Vector((1.25, 0, 0.1)) * k), ('sinistra', Vector((-1.25, 0, 0.1)) * k),
             ('tre_quarti', Vector((0.75, 0.8, 0.55)) * k)]
    files = []
    for v, off in viste:
        C.camera(cen + off, cen, lente=50)
        C.imposta_render(campioni=24 if PROVA else 160, w=800 if PROVA else 1100, h=800 if PROVA else 1100, esposizione=0.0,
                         look='AgX - Base Contrast')
        C.RENDER = os.path.join(DOCS, '_tmp')
        os.makedirs(C.RENDER, exist_ok=True)
        f = f'{nome}_{v}.jpg'
        C.renderizza(f)
        files.append(os.path.join(C.RENDER, f))
    ims = [Image.open(f) for f in files]
    w, h = ims[0].size
    o = Image.new('RGB', (w * 3, h))
    for k, im in enumerate(ims):
        o.paste(im, (k * w, 0))
    o.save(os.path.join(DOCS, nome + '_3lati' + ('_prova' if PROVA else '') + '.jpg'), quality=90)
    for f in files:
        os.remove(f)


def render_ugello(nome, ob):
    """Primo piano dell'ugello con il punto Muzzle (origine): sfera ciano e freccia lungo l'uscita del getto (+Y Blender = -Z Godot)."""
    ciano = C.mat_emissivo('muzzle', (0.1, 0.9, 1.0), 3.0)
    C.sfera('muzzle_punto', Vector((0, 0, 0)), 0.012, ciano)
    C.cilindro('muzzle_freccia', Vector((0, 0.06, 0)), 0.004, 0.12, ciano, asse=(0, 1, 0))
    C.cilindro('muzzle_punta', Vector((0, 0.13, 0)), 0.012, 0.03, ciano, asse=(0, 1, 0), r2=0.0)
    C.mondo((0.55, 0.56, 0.58), 1.0)
    C.luce('chiave_u', 'AREA', Vector((0.6, 0.5, 0.7)), 60, size=0.8, mira=(0, 0, 0))
    C.luce('riemp_u', 'AREA', Vector((-0.6, 0.3, 0.2)), 25, size=0.8, mira=(0, 0, 0))
    C.camera(Vector((0.32, 0.26, 0.14)), Vector((0, 0.02, 0)), lente=60)
    C.imposta_render(campioni=24 if PROVA else 128, w=1000, h=750, look='AgX - Base Contrast')
    C.RENDER = DOCS
    C.renderizza(nome + '_ugello' + ('_prova' if PROVA else '') + '.jpg')


def fai(nome):
    cfg = LANCE[nome]
    ob = importa(cfg.get('file', nome))
    punta = orienta(ob, cfg)
    if cfg.get('canna'):
        ingrossa_canna(ob, cfg['canna'])
    if cfg.get('colore'):
        ricolora(ob, **cfg['colore'])
    if cfg.get('nero'):
        colora_nero(ob, cfg['nero'])
    if '--ugello' in sys.argv:
        return render_ugello(nome, ob)
    pu = punti_utili(ob)
    t = tubo_zaino(nome, cfg, pu['retro'])
    obs = [ob, t]
    esporta(nome, obs)
    g = lambda v: [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]   # Blender -> Godot
    info = dict(punta_sull_asse=punta, impugnatura=g(pu['impugnatura']), retro=g(pu['retro']), cima=g(pu['cima']),
                misure=[round(x, 3) for x in (pu['hi'] - pu['lo'])], facce=len(ob.data.polygons))
    json.dump(info, open(os.path.join(GODOT, nome, nome + '.json'), 'w'), indent=1)
    print(nome, info, flush=True)
    if '--no-render' not in sys.argv:
        render_3lati(nome, obs, cfg['lung'])


if __name__ == '__main__':
    os.makedirs(DOCS, exist_ok=True)
    nomi = [a for a in sys.argv[1:] if not a.startswith('--')] or list(LANCE)
    for n in nomi:
        fai(n)
