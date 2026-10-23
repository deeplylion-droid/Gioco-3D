"""Oggetti di qualità alta (Meshy meshy-7.1, geometria 4k, PBR 4K) per gli interni del capitolo 1.
I GLB grezzi sono in assets_src/ambienti_interni/meshy_hq (script genera_hq.py).
Qui: import con scala reale e orientamento, perno nel punto giusto, parti emissive separate
(vetro delle lampade, diffusore dei neon), copie che condividono la mesh (istanze nel glTF)."""
import math, os
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
import ambienti1_lib as L

HQ = os.path.join(L.AI, 'meshy_hq')
# cartelle dove cercare i GLB (interni e ambienti tecnici)
CARTELLE = [HQ, os.path.join(L.ROOT, 'assets_src', 'ambienti_tecnici', 'meshy_hq')]
# funzione che mette un oggetto nuovo nella collezione giusta (gli script dei tecnici la cambiano)
LINK = [None]


def _percorso(file):
    for d in CARTELLE:
        p = os.path.join(d, file + '.glb')
        if os.path.exists(p):
            return p
    return os.path.join(HQ, file + '.glb')


def _metti_in_scena(ob):
    return (LINK[0] or L._link)(ob)
_base = {}   # nome file -> oggetto sorgente (nascosto, non esportato)
_dim = {}    # nome file -> dimensioni originali


def disponibile(file):
    return os.path.exists(_percorso(file))


def _carica(file, tex=2048):
    """Importa una volta il GLB, unisce le parti, porta l'origine al centro della base,
    il fronte verso -Y (come nelle immagini di riferimento) e riduce le texture a 'tex'."""
    if file in _base:
        return _base[file]
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=_percorso(file))
    nuovi = [o for o in bpy.data.objects if o not in prima]
    ms = [o for o in nuovi if o.type == 'MESH']
    for o in ms:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    for o in nuovi:
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    ob = L.unisci('hq_' + file, ms) if len(ms) > 1 else ms[0]
    ob.name = 'hq_' + file
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    vs = [v.co for v in ob.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)]); hi = Vector([max(v[i] for v in vs) for i in range(3)])
    ob.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    for p in ob.data.polygons:
        p.use_smooth = True
    for m in ob.data.materials:
        m.name = 'hq_' + file
        for k, n in enumerate(x for x in m.node_tree.nodes if x.type == 'TEX_IMAGE' and x.image):
            n.image.name = f'hq_{file}_{k}'
            if n.image.size[0] > tex:
                n.image.scale(tex, tex)
    ob.hide_set(True); ob.hide_render = True
    ob['solo_render'] = True   # la sorgente non va esportata
    _dim[file] = hi - lo
    _base[file] = ob
    return ob


def dimensioni(file):
    _carica(file)
    return _dim[file]


def metti(nome, file, loc, dim, rot_z=0.0, perno=None, rot=(0, 0, 0), parte=None):
    """Un oggetto della scena che usa (condividendola) la mesh del GLB 'file', o la sua parte
    'parte' (vedi dividi). dim = (larghezza x, profondità y, altezza z) in metri nello spazio
    dell'oggetto (fronte -Y); None su un asse = scala uniforme dall'altezza (o dalla larghezza).
    perno = punto in metri (spazio dell'oggetto già scalato, base al centro = 0,0,0) che diventa l'origine."""
    src = _base[parte] if parte else _carica(file)
    d = dimensioni(file)
    su = dim[2] / d.z if dim[2] else dim[0] / d.x
    s = [dim[i] / d[i] if dim[i] else su for i in range(3)]
    ob = bpy.data.objects.new(nome, src.data)
    _metti_in_scena(ob)
    S = Matrix.Diagonal((s[0], s[1], s[2], 1.0))
    off = Matrix.Translation(-Vector(perno)) if perno else Matrix.Identity(4)
    ob.matrix_world = Matrix.Translation(loc) @ Euler((rot[0], rot[1], rot_z)).to_matrix().to_4x4() @ off @ S
    return ob


def dividi(file, chiave, criterio, emissione=(1, 0.05, 0.02), forza=12.0):
    """Stacca dalla sorgente le facce che criterio(colore, normale) riconosce (vetro rosso, diffusore
    del neon) in una sorgente a parte 'chiave' con materiale emissivo. Si fa una volta sola."""
    if chiave in _base:
        return _base[chiave]
    src = _carica(file)
    me = src.data
    mat = me.materials[0]
    img = next((n.image for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image and n.image.colorspace_settings.name != 'Non-Color'), None)
    W, H = img.size
    px = img.pixels[:]
    uvl = me.uv_layers.active.data
    sel = set()
    for p in me.polygons:
        u = sum(uvl[li].uv.x for li in p.loop_indices) / p.loop_total
        v = sum(uvl[li].uv.y for li in p.loop_indices) / p.loop_total
        x = min(W - 1, max(0, int((u % 1.0) * W))); y = min(H - 1, max(0, int((v % 1.0) * H)))
        i = (y * W + x) * 4
        if criterio((px[i], px[i + 1], px[i + 2]), p.normal):
            sel.add(p.index)
    bm = bmesh.new(); bm.from_mesh(me)
    bm2 = bm.copy()
    bm.faces.ensure_lookup_table(); bm2.faces.ensure_lookup_table()
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.index not in sel], context='FACES')
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in sel], context='FACES')
    bm.to_mesh(me); bm.free()
    me2 = bpy.data.meshes.new('hq_' + chiave)
    bm2.to_mesh(me2); bm2.free()
    em = mat.copy(); em.name = 'hq_' + chiave
    b = next(n for n in em.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Emission Color'].default_value = (*emissione, 1)
    b.inputs['Emission Strength'].default_value = forza
    me2.materials.clear(); me2.materials.append(em)
    for p in me2.polygons:
        p.use_smooth = True
    o2 = bpy.data.objects.new('hq_' + chiave, me2)
    bpy.context.scene.collection.objects.link(o2)
    o2.hide_set(True); o2.hide_render = True; o2['solo_render'] = True
    _base[chiave] = o2
    print('dividi', file, chiave, len(sel), 'facce')
    return o2


def asse_rotore(file):
    """Centro dell'asse del rotore del tornello: la cella più densa di vertici in pianta."""
    src = _carica(file)
    celle = {}
    for v in src.data.vertices:
        k = (round(v.co.x / 0.02), round(v.co.y / 0.02))
        celle[k] = celle.get(k, 0) + 1
    k = max(celle, key=celle.get)
    return Vector((k[0] * 0.02, k[1] * 0.02, 0.0))


def pulisci_sorgenti():
    """Le sorgenti restano nella scena per le istanze ma non si esportano (solo_render)."""
    return list(_base.values())


def sportello_da_chiuso(file, chiave, frazione=0.07, chiudi=True):
    """Dal modello dell'armadietto chiuso ricava solo l'anta: taglia la fetta anteriore (fronte -Y)
    e (con chiudi) chiude il retro. La sorgente nuova ha le stesse dimensioni di riferimento del modello intero.
    Senza chiudi il retro resta aperto: col materiale a due facce si vede l'interno del fronte, come il retro di
    un'anta di lamiera (la chiusura riempita aveva le UV a caso: schegge nere sul retro dell'anta aperta)."""
    if chiave in _base:
        return _base[chiave]
    src = _carica(file)
    me = src.data.copy(); me.name = 'hq_' + chiave
    ys = [v.co.y for v in me.vertices]
    y0, y1 = min(ys), max(ys)
    taglio = y0 + (y1 - y0) * frazione
    bm = bmesh.new(); bm.from_mesh(me)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    r = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, taglio, 0), plane_no=(0, 1, 0), clear_outer=True)
    if chiudi:
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('hq_' + chiave, me)
    bpy.context.scene.collection.objects.link(o)
    o.hide_set(True); o.hide_render = True; o['solo_render'] = True
    _base[chiave] = o
    return o
