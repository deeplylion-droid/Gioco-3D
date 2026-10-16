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
    'lancia_a_pompiere': dict(lung=0.60, punta='auto', tubo=((0.25, 0.025, 0.02), 0.032, (0, -1, -0.15)), rough=0.8),
    'lancia_b_cannone': dict(lung=0.70, punta='auto', tubo=((0.05, 0.62, 0.62), 0.018, (0, -0.4, -1)), rough=0.35),
    'lancia_c_industriale': dict(lung=0.65, punta='auto', tubo=((0.02, 0.02, 0.02), 0.03, (0, -0.4, -1)), rough=0.6),
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


def punti_utili(ob):
    """Impugnatura (centro della parte più bassa), canna (sopra l'impugnatura, davanti) e moncone del tubo dietro."""
    lo, hi = estremi(ob)
    vs = [v.co for v in ob.data.vertices]
    z_imp = lo.z + 0.35 * (0 - lo.z)   # fascia bassa: dal fondo a un terzo dell'altezza sotto l'asse
    imp = [v for v in vs if v.z < z_imp]
    gi = sum(imp, Vector()) / len(imp)
    dietro = [v for v in vs if v.y < lo.y + 0.02]
    gd = sum(dietro, Vector()) / len(dietro)
    return dict(impugnatura=gi, retro=gd, lo=lo, hi=hi)


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
    ob = importa(nome)
    punta = orienta(ob, cfg)
    if '--ugello' in sys.argv:
        return render_ugello(nome, ob)
    pu = punti_utili(ob)
    t = tubo_zaino(nome, cfg, pu['retro'])
    obs = [ob, t]
    esporta(nome, obs)
    g = lambda v: [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]   # Blender -> Godot
    info = dict(punta_sull_asse=punta, impugnatura=g(pu['impugnatura']), retro=g(pu['retro']),
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
