"""Versione leggera per il gioco: 25 mila triangoli con texture cotte (bake) dal grezzo di Meshy.

Ridurre le facce direttamente apre fessure lungo le cuciture UV (crepe nere: il GLB di Meshy ha i
vertici doppiati sulle cuciture) o, saldando i vertici, stira le UV. Qui invece:
0. il grezzo di Meshy (1-3 milioni di facce) va alla stessa scala e posizione dei GLB del repo
   (altezza da MODELLI in bambini_comune.py; con --muta-opaca, muta satinata come nel repo);
1. copia del corpo, vertici saldati, facce ridotte, UV nuove (Smart UV Project);
2. bake da alto a basso (Cycles, selected to active): colore e metallo/rugosità con il trucco
   dell'emissione, normali in spazio tangente (con il dettaglio della mesh alta e della sua normal map);
3. materiale PBR con le tre texture 2K, export GLB (JPEG), stessa misura e posizione dell'originale.
Il guscio dell'occhio dell'agnellino si rifà dopo, sul GLB leggero, con bambini_occhio.py.

Uso:
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/bambini_gioco.py \
        <grezzo_meshy.glb> <nome> <uscita.glb> [--facce 25000] [--tex 2048] [--muta-opaca 0.55]
<nome> è una chiave di MODELLI. I grezzi di Meshy si riscaricano dai task in meshy_log.json
(per 3 giorni) o si rigenerano con bambini_meshy.py.
"""
import argparse, math, os, sys, tempfile, time
import bpy, bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bambini_comune as B  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('alto'); ap.add_argument('nome'); ap.add_argument('uscita')
ap.add_argument('--muta-opaca', type=float, default=0.0)
ap.add_argument('--facce', type=int, default=25000)
ap.add_argument('--tex', type=int, default=2048)
ap.add_argument('--fili', type=int, default=3)
A = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
nome = A.nome
t0 = time.time()

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
perno = B.importa(A.alto, B.MODELLI[nome][1], nome='perno')
for o in [o for o in sc.objects if o.name.startswith('occhio_bulbo')]:
    bpy.data.objects.remove(o, do_unlink=True)
alto = max((o for o in sc.objects if o.type == 'MESH'), key=lambda o: len(o.data.polygons))
for o in list(sc.objects):
    if o.type == 'MESH' and o is not alto:
        bpy.data.objects.remove(o, do_unlink=True)
for o in sc.objects:
    o.select_set(o is alto)
bpy.context.view_layer.objects.active = alto
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.data.objects.remove(perno, do_unlink=True)
if A.muta_opaca > 0:
    B.muta_opaca(alto.data.materials, A.muta_opaca)

# 1. copia bassa: saldatura, riduzione, UV nuove
basso = alto.copy(); basso.data = alto.data.copy(); basso.name = nome; basso.data.name = nome
sc.collection.objects.link(basso)
bm = bmesh.new(); bm.from_mesh(basso.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(basso.data); bm.free()
mod = basso.modifiers.new('riduci', 'DECIMATE')
mod.ratio = A.facce / len(basso.data.polygons)
mod.use_collapse_triangulate = True
bpy.context.view_layer.objects.active = basso
for o in sc.objects:
    o.select_set(o is basso)
bpy.ops.object.modifier_apply(modifier=mod.name)
for ly in list(basso.data.uv_layers):
    basso.data.uv_layers.remove(ly)
basso.data.uv_layers.new(name='UVMap')
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
bpy.ops.object.mode_set(mode='OBJECT')
for p in basso.data.polygons:
    p.use_smooth = True
B.log(nome, len(alto.data.polygons), '->', len(basso.data.polygons), 'facce,', f'{time.time() - t0:.0f}s')

# 2. immagini e materiale del modello basso
def immagine(n, colore):
    im = bpy.data.images.new(f'{nome}_{n}', A.tex, A.tex, alpha=False)
    im.colorspace_settings.name = 'sRGB' if colore else 'Non-Color'
    return im


col, mr, nor = immagine('colore', True), immagine('metallo_rugosita', False), immagine('normali', False)
mb = bpy.data.materials.new(nome); mb.use_nodes = True
nt, ln = mb.node_tree.nodes, mb.node_tree.links
bsdf = nt['Principled BSDF']
n_col = nt.new('ShaderNodeTexImage'); n_col.image = col
n_mr = nt.new('ShaderNodeTexImage'); n_mr.image = mr
n_nor = nt.new('ShaderNodeTexImage'); n_nor.image = nor
sep = nt.new('ShaderNodeSeparateColor')
nm = nt.new('ShaderNodeNormalMap')
ln.new(n_col.outputs['Color'], bsdf.inputs['Base Color'])
ln.new(n_mr.outputs['Color'], sep.inputs['Color'])
ln.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
ln.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
ln.new(n_nor.outputs['Color'], nm.inputs['Color'])
ln.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
basso.data.materials.clear()
basso.data.materials.append(mb)

# 3. bake da alto a basso
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.render.threads_mode = 'FIXED'; sc.render.threads = A.fili
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.01
sc.render.bake.max_ray_distance = 0.03
sc.render.bake.margin = 16
ma = alto.data.materials[0]
ant, aln = ma.node_tree.nodes, ma.node_tree.links
abs_ = next(n for n in ant if n.type == 'BSDF_PRINCIPLED')
src_col = abs_.inputs['Base Color'].links[0].from_socket
r_node = abs_.inputs['Roughness'].links[0].from_node      # Separate Color sulla texture metallo/rugosità
src_mr = r_node.inputs[0].links[0].from_socket
em = ant.new('ShaderNodeEmission')
out = next(n for n in ant if n.type == 'OUTPUT_MATERIAL')
surf = out.inputs['Surface'].links[0].from_socket


def cuoci(tipo, img, sorgente=None):
    for n in nt:
        n.select = False
    nodo = {col: n_col, mr: n_mr, nor: n_nor}[img]
    nodo.select = True; nt.active = nodo
    if sorgente is not None:
        aln.new(sorgente, em.inputs['Color'])
        aln.new(em.outputs['Emission'], out.inputs['Surface'])
    else:
        aln.new(surf, out.inputs['Surface'])
    for o in sc.objects:
        o.select_set(o in (alto, basso))
    bpy.context.view_layer.objects.active = basso
    sc.cycles.samples = 1 if tipo == 'EMIT' else 4
    t1 = time.time()
    bpy.ops.object.bake(type=tipo, normal_space='TANGENT')
    B.log(f'bake {img.name} {time.time() - t1:.0f}s')


cuoci('EMIT', col, src_col)
cuoci('EMIT', mr, src_mr)
cuoci('NORMAL', nor)
tmp = tempfile.mkdtemp(prefix='bambini_gioco_')
for im in (col, mr, nor):
    im.filepath_raw = os.path.join(tmp, im.name + '.png'); im.file_format = 'PNG'; im.save()

# 4. export del solo modello basso
bpy.data.objects.remove(alto, do_unlink=True)
for o in sc.objects:
    o.select_set(o is basso)
os.makedirs(os.path.dirname(os.path.abspath(A.uscita)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=A.uscita, export_format='GLB', use_selection=True,
                          export_image_format='JPEG', export_jpeg_quality=90,
                          export_apply=True, export_yup=True)
lo, hi = B.limiti([basso])
B.log('scritto', A.uscita, f'{os.path.getsize(A.uscita) / 1e6:.1f} MB,', 'misure',
      tuple(round(v, 3) for v in hi - lo), f'totale {time.time() - t0:.0f}s')
