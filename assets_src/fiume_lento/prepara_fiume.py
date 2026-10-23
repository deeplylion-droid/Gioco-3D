"""Dai GLB grezzi di Meshy (meshy/) ai modelli del fiume lento per Godot (godot/assets/fiume_lento/):
misure vere e origine in basso al centro (o in alto, per le cose appese); texture a 1024; le rocce con l'origine sul retro (si appoggiano al muro); la
lampada d'emergenza con la lente verso -Z di Godot (così look_at la punta dove deve illuminare).
Uso: blender-venv/bin/python prepara_fiume.py [nomi...]"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', 'godot', 'assets', 'fiume_lento')
# nome: (misura, asse della misura: 'x' larghezza, 'z' altezza, 'max' la più grande), origine, rotazione Z (gradi)
SPEC = {
    'ciambella': (1.2, 'x', 'basso', 0),
    'paratia': (3.4, 'x', 'basso', 0),
    'lampada_emergenza': (0.42, 'max', 'centro', 180),
    'scaletta_banchina': (1.55, 'z', 'basso', 0),
    'tornello_imbarco': (1.35, 'z', 'basso', 0),
    'transenna': (2.0, 'x', 'basso', 0),
    'roccia_parete': (4.2, 'x', 'retro', 0),
    'palma_finta': (4.0, 'z', 'basso', 0),
    'totem_tiki': (2.5, 'z', 'basso', 0),
    'capanna_tiki': (2.6, 'x', 'basso', 0),
    'pesce_vetroresina': (2.0, 'max', 'basso', 0),
    'palombaro': (1.4, 'z', 'basso', 0),
    'tartaruga': (1.6, 'max', 'basso', 0),
    # riempimento
    'bocchetta': (0.45, 'x', 'retro', 0),
    'griglia_scolo': (1.0, 'x', 'basso', 0),
    'altoparlante': (0.5, 'max', 'retro', 0),
    'salvagente': (1.4, 'z', 'basso', 0),
    'ciabatta': (0.2, 'max', 'basso', 0),
    'paperella': (0.12, 'max', 'basso', 0),
    'secchiello': (0.35, 'max', 'basso', 0),
    'pallone': (0.4, 'max', 'basso', 0),
    'detriti': (0.7, 'x', 'basso', 0),
    'lampada_capannone': (0.5, 'x', 'alto', 0),
    'liane': (2.5, 'z', 'alto', 0),
    'fiori': (1.0, 'z', 'basso', 0),
    'maschera_tiki': (0.8, 'z', 'retro', 0),
    'corrimano_bambu': (2.0, 'x', 'basso', 0),
    'pappagallo': (1.0, 'z', 'basso', 0),
    'scimmia': (1.0, 'z', 'basso', 0),
    'tettoia_paglia': (4.0, 'x', 'basso', 0),
    'ponte_corda': (5.0, 'max', 'basso', 0),
    'corallo': (1.2, 'z', 'basso', 0),
    'ancora': (1.5, 'z', 'basso', 0),
    'forziere': (0.8, 'x', 'basso', 0),
    'rete_stelle': (2.0, 'x', 'retro', 0),
    'portello': (1.9, 'z', 'retro', 0),
}


def aggancia_lampada(o):
    """La lampada del capannone: Meshy ha fatto la catenella (due anelli, da 0 a -7,5 cm, nel piano YZ di Blender)
    staccata dal corpo, con 3,8 cm di vuoto fino al cappello piatto (a -11,3 cm), e la lampada pendeva staccata
    (coordinatore, 23 ottobre). Il corpo sale di 3,13 cm e sul cappello c'è un occhiello (un anello nel piano XZ, di
    traverso all'ultimo anello della catenella) che entra 1 mm nel cappello: il filo dell'ultimo anello gli passa nel
    mezzo, come un moschettone, senza toccarlo."""
    import bmesh
    SALE = 0.0313
    bm = bmesh.new()
    bm.from_mesh(o.data)
    uvl = bm.loops.layers.uv.active
    corpo = [v for v in bm.verts if v.co.z < -0.09]
    for v in corpo:
        v.co.z += SALE
    cima = max(v.co.z for v in corpo)
    # le coordinate UV dell'occhiello: quelle del vertice del cappello più vicino al centro (lo stesso metallo)
    vc = min((v for v in corpo if v.co.z > cima - 0.002), key=lambda v: v.co.x ** 2 + v.co.y ** 2)
    uv = vc.link_loops[0][uvl].uv.copy() if uvl and vc.link_loops else None
    R, r, n, m = 0.0105, 0.003, 24, 8          # raggio dell'anello, del filo; lati
    cz = cima - 0.001 + R + r                    # il fondo dell'occhiello 1 mm dentro il cappello
    anelli = []
    for i in range(n):
        a = 2 * math.pi * i / n
        c = Vector((R * math.cos(a), 0.0, cz + R * math.sin(a)))
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        anelli.append([bm.verts.new(c + (d * math.cos(2 * math.pi * j / m) + Vector((0, 1, 0)) * math.sin(2 * math.pi * j / m)) * r)
                       for j in range(m)])
    for i in range(n):
        A, B = anelli[i], anelli[(i + 1) % n]
        for j in range(m):
            f = bm.faces.new((A[j], B[j], B[(j + 1) % m], A[(j + 1) % m]))
            if uv is not None:
                for l in f.loops:
                    l[uvl].uv = uv
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[-n * m:])
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    print('lampada_capannone: corpo su di %.4f, cappello a %.4f, occhiello col centro a %.4f' % (SALE, cima, cz))


def togli_staccati(o, vicino=0.003):
    """Toglie i pezzi del modello che non toccano il pezzo grande (le liane di Meshy avevano 60 foglioline sciolte,
    da 3 a 16 vertici, fino a 31 cm dalla pianta: volavano nell'aria, 23 ottobre)."""
    import bmesh
    from mathutils.kdtree import KDTree
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.verts.ensure_lookup_table()
    # i pezzi: vertici collegati dagli spigoli, e vertici nella stessa posizione (le cuciture di Meshy)
    kd = KDTree(len(bm.verts))
    for v in bm.verts:
        kd.insert(v.co, v.index)
    kd.balance()
    pezzo = [-1] * len(bm.verts)
    pezzi = []
    for v0 in bm.verts:
        if pezzo[v0.index] >= 0:
            continue
        k = len(pezzi)
        pila, lista = [v0], []
        pezzo[v0.index] = k
        while pila:
            v = pila.pop()
            lista.append(v)
            vicini = [e.other_vert(v) for e in v.link_edges] + [bm.verts[i] for _, i, _ in kd.find_range(v.co, 1e-5)]
            for w in vicini:
                if pezzo[w.index] < 0:
                    pezzo[w.index] = k
                    pila.append(w)
        pezzi.append(lista)
    grande = max(range(len(pezzi)), key=lambda k: len(pezzi[k]))
    kg = KDTree(len(pezzi[grande]))
    for i, v in enumerate(pezzi[grande]):
        kg.insert(v.co, i)
    kg.balance()
    via = []
    for k, lista in enumerate(pezzi):
        if k != grande and min(kg.find(v.co)[2] for v in lista) > vicino:
            via += lista
    bmesh.ops.delete(bm, geom=via, context='VERTS')
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    print('%s: %d pezzi, tolti %d vertici sciolti' % (o.name, len(pezzi), len(via)))


def fai(nome):
    misura, asse, origine, rz = SPEC[nome]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(QUI, 'meshy', nome + '.glb'))
    # texture a 1024: bastano per questi oggetti e i GLB pesano un quarto
    for img in bpy.data.images:
        if img.size[0] > 1024:
            img.scale(1024, 1024)
    ms = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in ms:
        o.data.transform(Matrix.Rotation(math.radians(rz), 4, 'Z'))
    pts = [v.co for o in ms for v in o.data.vertices]
    mn = Vector([min(p[i] for p in pts) for i in range(3)])
    mx = Vector([max(p[i] for p in pts) for i in range(3)])
    d = mx - mn
    s = misura / {'x': d.x, 'z': d.z, 'max': max(d)}[asse]
    cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
    oz = mn.z if origine in ('basso', 'retro') else mx.z if origine == 'alto' else (mn.z + mx.z) / 2
    oy = mx.y if origine == 'retro' else cy   # retro: il lato +Y di Blender (-Z di Godot)
    m = Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation((-cx, -oy, -oz))
    for o in ms:
        o.data.transform(m)
        o.data.update()
    if nome == 'lampada_capannone':
        aggancia_lampada(ms[0])
    if nome == 'liane':
        togli_staccati(ms[0])
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + '.glb'), use_selection=True, export_format='GLB')
    print(nome, 'dimensioni', [round(v * s, 2) for v in d])


if __name__ == '__main__':
    for n in (sys.argv[1:] or list(SPEC)):
        fai(n)
