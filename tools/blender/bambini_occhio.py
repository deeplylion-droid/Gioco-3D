"""Agnellino con l'occhio unico: un bulbo vero con l'iride della "madre" al posto dell'occhio di Meshy.

L'occhio dipinto da Meshy aveva un'iride piccola e rossa e la sclera venata. Questo script:
1. trova le facce dell'occhio dipinto che si vedono da davanti (colore della texture, normale,
   raggio frontale); l'iride dipinta da Meshy dà il centro dello sguardo;
2. compone la texture del bulbo: sclera chiara e l'iride della medusa
   (assets_src/medusa/tex/occhio_iride_rgba.png, oppure dal ramo lavoro/medusa), grande metà del
   raggio del bulbo come quella della madre. Esce in assets_src/bambini/tex/agnello_occhio_bulbo.png;
3. copia quelle facce in un guscio a parte ('occhio_bulbo'), 1 mm sopra la vecchia superficie,
   con UV a proiezione frontale e materiale lucido (cornea bagnata): la forma combacia con i lembi
   di stoffa strappata. Nel gioco lo sguardo si può muovere spostando le UV in uno shader;
4. riesporta il GLB (stesso file, oppure un altro).

Uso:
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/bambini_occhio.py \
        <agnello_occhio.glb> [<uscita.glb>] [--raggio 0.11]
"""
import argparse, colorsys, io, math, os, subprocess, sys
import numpy as np
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bambini_comune as B  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('glb'); ap.add_argument('uscita', nargs='?')
ap.add_argument('--raggio', type=float, default=0.11,
                help="metà del lato del quadrato UV (m): l'iride è grande metà di questo")
A = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
USCITA = A.uscita or A.glb
TEX = os.path.join(B.ASSET, 'tex')
TEX_BULBO = os.path.join(TEX, 'agnello_occhio_bulbo.png')
IRIDE_SU_RAGGIO = 0.5      # raggio dell'iride / raggio del bulbo, come nella madre
SCLERA = (238, 230, 233)   # bianco appena rosato
MEMBRANA = (222, 172, 188) # verso il bordo sfuma nel rosa della membrana intorno all'occhio


def iride_madre():
    p = os.path.join(B.REPO, 'assets_src', 'medusa', 'tex', 'occhio_iride_rgba.png')
    if os.path.exists(p):
        return open(p, 'rb').read()
    return subprocess.run(['git', '-C', B.REPO, 'show', 'lavoro/medusa:assets_src/medusa/tex/occhio_iride_rgba.png'],
                          check=True, capture_output=True).stdout


def componi_texture(n=1024):
    """UV del bulbo = proiezione frontale: il quadrato [0,1]^2 copre x,z in [-r, r]."""
    from PIL import Image
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d = np.hypot(xx - n / 2 + 0.5, yy - n / 2 + 0.5) / (n / 2)       # 0 al centro, 1 al bordo
    t = np.clip((d - 0.5) / 0.25, 0, 1) ** 1.2
    base = np.array(SCLERA, np.float32) * (1 - t[..., None]) + np.array(MEMBRANA, np.float32) * t[..., None]
    tela = Image.fromarray(base.astype(np.uint8)).convert('RGBA')
    ir = Image.open(io.BytesIO(iride_madre())).convert('RGBA')
    # nella texture della madre l'anello esterno dell'iride sta a ~0,74 del mezzo lato
    lato = int(round(n * IRIDE_SU_RAGGIO / 0.74))
    ir = ir.resize((lato, lato), Image.LANCZOS)
    a = np.asarray(ir).astype(np.float32)
    q = np.hypot(*(np.mgrid[0:lato, 0:lato] - lato / 2 + 0.5)) / (lato / 2)
    a[..., 3] *= np.clip((0.87 - q) / 0.04, 0, 1)                    # via i segni grigi fuori dalle punte
    ir = Image.fromarray(a.astype(np.uint8), 'RGBA')
    tela.alpha_composite(ir, ((n - lato) // 2, (n - lato) // 2))
    os.makedirs(TEX, exist_ok=True)
    tela.convert('RGB').save(TEX_BULBO)
    B.log('texture del bulbo', os.path.relpath(TEX_BULBO, B.REPO))
    return TEX_BULBO


def colori_facce(o):
    """Colore della texture di base al centro UV di ogni faccia (array N x 3)."""
    me = o.data
    nodo = next(n for n in o.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE'
                and n.outputs[0].links and n.outputs[0].links[0].to_socket.name == 'Base Color')
    W, H = nodo.image.size
    px = np.array(nodo.image.pixels[:], dtype=np.float32).reshape(H, W, 4)
    uv = np.zeros(len(me.loops) * 2, np.float32); me.uv_layers.active.data.foreach_get('uv', uv)
    uv = uv.reshape(-1, 2)
    start = np.zeros(len(me.polygons), np.int32); me.polygons.foreach_get('loop_start', start)
    tot = np.zeros(len(me.polygons), np.int32); me.polygons.foreach_get('loop_total', tot)
    cuv = np.add.reduceat(uv, start) / tot[:, None]
    xi = np.clip((cuv[:, 0] * W).astype(int), 0, W - 1); yi = np.clip((cuv[:, 1] * H).astype(int), 0, H - 1)
    return px[yi, xi, :3]


def superficie_occhio(o):
    """Le facce dell'occhio dipinto da Meshy che si vedono da davanti: colore da occhio (sclera rosata
    o iride rossa), sopra il fiocco, rivolte in avanti e prime colpite da un raggio frontale."""
    import colorsys as cs
    me = o.data
    mw = o.matrix_world
    n = len(me.polygons)
    cen = np.zeros(n * 3, np.float32); me.polygons.foreach_get('center', cen); cen = cen.reshape(-1, 3)
    nor = np.zeros(n * 3, np.float32); me.polygons.foreach_get('normal', nor); nor = nor.reshape(-1, 3)
    lo, hi = B.limiti([o])
    alto = hi.z - lo.z
    col = colori_facce(o)
    hsv = np.array([cs.rgb_to_hsv(*c) for c in col])
    rosa = (hsv[:, 0] > 0.85) | (hsv[:, 0] < 0.04)
    da_occhio = rosa & (((hsv[:, 2] > 0.6) & (hsv[:, 1] < 0.4)) | (hsv[:, 1] > 0.4))
    zona = (np.abs(cen[:, 0]) < 0.12) & (cen[:, 2] > lo.z + 0.68 * alto) & (cen[:, 2] < lo.z + 0.90 * alto)
    avanti = nor[:, 1] < -0.15
    # iride dipinta (rossa, satura) = centro dello sguardo
    rossa = np.where(zona & avanti & rosa & (hsv[:, 1] > 0.45))[0]
    x0, z0 = float(np.median(cen[rossa, 0])), float(np.median(cen[rossa, 2]))
    # la pupilla di Meshy è un piccolo foro nella superficie: raggi fitti (1 mm) intorno allo sguardo,
    # quelli che vanno molto più in fondo della superficie intorno (o non colpiscono) sono il foro.
    # Se c'è, lo sguardo si centra lì e il foro diventa il centro nero della pupilla della madre.
    dg0 = bpy.context.evaluated_depsgraph_get()
    bvh0 = BVHTree.FromObject(o, dg0)
    mwi = mw.inverted()
    prof = {}
    for x in np.arange(x0 - 0.03, x0 + 0.0301, 0.001):
        for z in np.arange(z0 - 0.03, z0 + 0.0301, 0.001):
            a0 = mwi @ Vector((x, lo.y - 1.0, z))
            hit = bvh0.ray_cast(a0, (mwi @ Vector((x, hi.y + 1.0, z)) - a0).normalized())
            prof[(x, z)] = (mw @ hit[0]).y if hit[0] is not None else None
    ys = np.array([v for v in prof.values() if v is not None])
    fondo = [k for k, v in prof.items() if v is None or v > np.median(ys) + 0.012]
    if 3 <= len(fondo) < 400:
        x0 = float(np.mean([k[0] for k in fondo])); z0 = float(np.mean([k[1] for k in fondo]))
        B.log(f'occhio: foro della pupilla ({len(fondo)} raggi profondi) a x={x0:.3f} z={z0:.3f}')
    # vicino al centro si prende tutto (anche la vecchia pupilla scura), più in là solo il colore da occhio
    centro = np.hypot(cen[:, 0] - x0, cen[:, 2] - z0) < 0.035
    dentro = np.hypot(cen[:, 0] - x0, cen[:, 2] - z0) < 0.095   # oltre ci sono i lembi e la membrana
    cand = np.where(zona & dentro & ((avanti & da_occhio) | centro))[0]
    # visibili da davanti: il raggio frontale verso il centro colpisce proprio quella faccia
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(o, dg)
    vis = []
    for i in cand:
        c = Vector(cen[i])
        hit = bvh.ray_cast(Vector((c.x, lo.y - 1.0, c.z)), Vector((0, 1, 0)))
        if hit[0] is not None and (hit[2] == i or abs(hit[0].y - c.y) < 0.003):
            vis.append(int(i))
    B.log(f'occhio: {len(cand)} facce candidate, {len(vis)} visibili; iride di Meshy a x={x0:.3f} z={z0:.3f}')
    return vis, x0, z0


def guscio(o, facce, x0, z0, r, tex, scosta=0.001):
    """Copia le facce scelte in un oggetto nuovo, scostate in fuori lungo le normali, con UV a
    proiezione frontale centrata sullo sguardo: il quadrato UV copre x,z in [-r, r]."""
    import bmesh
    bm = bmesh.new(); bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    tieni = set(facce)
    mw = o.matrix_world
    via = [f for f in bm.faces if f.index not in tieni
           or math.hypot((mw @ f.calc_center_median()).x - x0, (mw @ f.calc_center_median()).z - z0) < 0.016]
    bmesh.ops.delete(bm, geom=via, context='FACES')
    # chiude i fori piccoli rimasti (non il bordo esterno del guscio, che è molto più lungo)
    bordi = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=bordi, sides=48)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * scosta
    me = bpy.data.meshes.new('occhio_bulbo')
    bm.to_mesh(me); bm.free()
    for ly in list(me.uv_layers):
        me.uv_layers.remove(ly)
    uv = me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        for li in poly.loop_indices:
            p = o.matrix_world @ me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = (0.5 + (p.x - x0) / (2 * r), 0.5 + (p.z - z0) / (2 * r))
    # cornea: piccola cupola sulla pupilla, copre la cavità della vecchia pupilla di Meshy
    import bmesh as _bm
    co = np.array([tuple(o.matrix_world @ v.co) for v in me.vertices])
    rr = np.hypot(co[:, 0] - x0, co[:, 2] - z0)
    anello = co[(rr > 0.012) & (rr < 0.03), 1]
    if len(anello):
        y_sup = float(np.percentile(anello, 15))
        bmc = _bm.new()
        _bm.ops.create_uvsphere(bmc, u_segments=32, v_segments=16, radius=0.022)
        for v in bmc.verts:
            v.co.y *= 0.3
            v.co += Vector((x0, y_sup + 0.002, z0))
        tmp = bpy.data.meshes.new('cornea'); bmc.to_mesh(tmp); bmc.free()
        bmm = _bm.new(); bmm.from_mesh(me)
        inv = o.matrix_world.inverted()
        for v in tmp.vertices:
            v.co = inv @ v.co
        bmm.from_mesh(tmp)
        bmm.to_mesh(me); bmm.free()
        bpy.data.meshes.remove(tmp)
        for ly in list(me.uv_layers):
            me.uv_layers.remove(ly)
        uv = me.uv_layers.new(name='UVMap')
        for poly in me.polygons:
            for li in poly.loop_indices:
                p = o.matrix_world @ me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv = (0.5 + (p.x - x0) / (2 * r), 0.5 + (p.z - z0) / (2 * r))
        B.log(f'cornea sulla pupilla a y={y_sup + 0.002:.4f}')
    me.materials.clear()
    ob = bpy.data.objects.new('occhio_bulbo', me)
    bpy.context.scene.collection.objects.link(ob)
    ob.matrix_world = o.matrix_world
    m = bpy.data.materials.new('occhio_bulbo'); m.use_nodes = True
    nt, ln = m.node_tree.nodes, m.node_tree.links
    b = nt['Principled BSDF']
    t = nt.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(tex)
    t.extension = 'EXTEND'
    ln.new(t.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.12
    b.inputs['Coat Weight'].default_value = 1.0        # cornea bagnata
    b.inputs['Coat Roughness'].default_value = 0.03
    b.inputs['Subsurface Weight'].default_value = 0.05
    me.materials.append(m)
    for poly in me.polygons:
        poly.use_smooth = True
    return ob


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=A.glb)
objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if any(o.name.startswith('occhio_bulbo') for o in objs):
    raise SystemExit('il GLB ha già il bulbo')
corpo = max(objs, key=lambda o: len(o.data.polygons))
facce, x0, z0 = superficie_occhio(corpo)
tex = componi_texture()
guscio(corpo, facce, x0, z0, A.raggio, tex)
bpy.ops.export_scene.gltf(filepath=USCITA, export_format='GLB', use_selection=False,
                          export_image_format='JPEG', export_jpeg_quality=90,
                          export_apply=True, export_yup=True)
B.log('scritto', os.path.relpath(USCITA, B.REPO) if USCITA.startswith(B.REPO) else USCITA,
      f'{os.path.getsize(USCITA) / 1e6:.1f} MB')
