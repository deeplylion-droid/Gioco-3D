"""Dalla simulazione (geyser.blend con la cache) alle mesh del gioco: un oggetto per fotogramma (f000, f001...),
lisciato, ridotto a circa TRI triangoli e con le normali morbide, tutti in un GLB solo.
Uso: blender -b <cache>/geyser.blend --python assets_src/geyser/esporta_mesh.py -- <uscita.glb> [triangoli] [pezzo minimo, m]"""
import os, sys
import bmesh
import bpy

ARG = sys.argv[sys.argv.index('--') + 1:]
OUT = ARG[0]
TRI = int(ARG[1]) if len(ARG) > 1 else 12000
## I pezzi staccati più piccoli di così (m, lato più lungo) si buttano: ridotti diventano scaglie piatte ("coriandoli",
## prova del coordinatore). Le gocce in volo le fanno le particelle del gioco.
PEZZO_MINIMO = float(ARG[2]) if len(ARG) > 2 else 0.25


def togli_goccioline(me):
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    visti = set(); via = []
    for v in bm.verts:
        if v.index in visti:
            continue
        isola = []; pila = [v]; visti.add(v.index)
        while pila:
            a = pila.pop(); isola.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in visti:
                    visti.add(b.index); pila.append(b)
        lo = [min(x.co[i] for x in isola) for i in range(3)]
        hi = [max(x.co[i] for x in isola) for i in range(3)]
        if max(hi[i] - lo[i] for i in range(3)) < PEZZO_MINIMO:
            via.extend(isola)
    bmesh.ops.delete(bm, geom=via, context='VERTS')
    bm.to_mesh(me); bm.free()
sc = bpy.context.scene
dom = bpy.data.objects['Dominio']
for o in list(bpy.data.objects):
    if o is not dom:
        o.hide_set(True)
fatti = []
tot = 0
for f in range(sc.frame_start, sc.frame_end + 1):
    sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = dom.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    n = len(me.polygons)
    if n == 0:
        bpy.data.meshes.remove(me)
        continue
    togli_goccioline(me)
    if len(me.polygons) == 0:
        bpy.data.meshes.remove(me)
        continue
    ob = bpy.data.objects.new(f'f{f - sc.frame_start:03d}', me)
    sc.collection.objects.link(ob)
    # la superficie della simulazione a 96 è a gradini e accartocciata: la si liscia (senza restringerla) prima di ridurla
    lis = ob.modifiers.new('liscia', 'CORRECTIVE_SMOOTH')
    lis.iterations = 6
    lis.smooth_type = 'LENGTH_WEIGHTED'
    lis.use_only_smooth = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier='liscia')
    ob.select_set(False)
    tri = sum(len(p.vertices) - 2 for p in me.polygons)
    if tri > TRI:
        dec = ob.modifiers.new('riduci', 'DECIMATE')
        dec.ratio = TRI / tri
        dec.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.modifier_apply(modifier='riduci')
        ob.select_set(False)
    for p in ob.data.polygons:
        p.use_smooth = True
    tot += sum(len(p.vertices) - 2 for p in ob.data.polygons)
    fatti.append(ob)
bpy.ops.object.select_all(action='DESELECT')
for o in fatti:
    o.select_set(True)
dom.hide_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_apply=True, export_materials='NONE',
                          export_normals=True, export_texcoords=False, export_yup=True)
print('esportati', len(fatti), 'fotogrammi', tot, 'triangoli', round(os.path.getsize(OUT) / 1e6, 1), 'MB', flush=True)
