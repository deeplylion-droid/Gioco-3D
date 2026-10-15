"""Passo 2b: versione da gioco del corpo (circa 30-40 mila triangoli) con texture 2K cotte.

La mesh di Meshy (160k triangoli) si riduce con la decimazione "collapse", conservando di piu' il viso
(orbita e fauce) e le mani. La decimazione rovina le UV originali (le isole si spezzano), quindi la mesh
ridotta riceve UV nuove (Smart UV Project) e le texture si "cuociono" dalla mesh ad alta risoluzione:
  - colore (bake DIFFUSE, solo colore) dalla texture pulita del passo 2;
  - normal map in spazio tangente (dettagli della mesh alta + normal map pulita).
Le parti (materiali) restano quelle del passo 1. Le misure dell'occhio restano quelle del passo 1 (fatte sulla
mesh alta: dati/occhio.json e build/viso_piatto.png).

Scrive tex/medusa_base_2k.png, tex/medusa_normal_2k.png e build/medusa_02b_ridotta.blend.
Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_02b_riduci.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

RIDUZIONE = float(os.environ.get('MEDUSA_RIDUZIONE', '0.25'))
LATO = 2048
BASE_2K = os.path.join(TEX, 'medusa_base_2k.png')
NORMAL_2K = os.path.join(TEX, 'medusa_normal_2k.png')


def riduci(ob, ratio):
    """Decimazione per zone (in modalita' modifica, solo sulla selezione): il viso (orbita e futura fauce)
    resta intatto, le mani si riducono poco, il resto tanto. Le zone quasi piatte (come il disco dell'occhio)
    con la decimazione normale sparirebbero in pochi triangoli."""
    me = ob.data
    n0 = len(me.polygons)
    cen, _ = facce(me)
    viso = (np.hypot(cen[:, 0], cen[:, 2] - 0.58) < 0.17) & (cen[:, 1] < -0.08)
    mani = np.abs(cen[:, 0]) > 0.6
    resto = ~(viso | mani)
    obiettivo = ratio * n0
    r_mani = 0.5
    r_resto = max(min((obiettivo - viso.sum() - r_mani * mani.sum()) / max(resto.sum(), 1), 1.0), 0.05)
    attiva(ob)
    for zona, r in ((resto, r_resto), (mani, r_mani)):
        bpy.ops.object.mode_set(mode='OBJECT')
        cen, _ = facce(me)
        v = (np.hypot(cen[:, 0], cen[:, 2] - 0.58) < 0.17) & (cen[:, 1] < -0.08)
        m = np.abs(cen[:, 0]) > 0.6
        sel = ~(v | m) if zona is resto else m
        me.polygons.foreach_set('select', sel)
        me.vertices.foreach_set('select', np.zeros(len(me.vertices), bool))
        me.edges.foreach_set('select', np.zeros(len(me.edges), bool))
        me.update()
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_mode(type='FACE')
        bpy.ops.mesh.decimate(ratio=r, use_symmetry=False)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode='OBJECT')
    log(f'riduzione: {n0} -> {len(me.polygons)} triangoli (viso intatto, mani x{r_mani}, resto x{r_resto:.2f})')


def uv_nuove(ob):
    me = ob.data
    while len(me.uv_layers):
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name='UVMap')
    attiva(ob)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.003, area_weight=0.0,
                             scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')


def cuoci(alto, basso):
    """Bake (selected to active) di colore e normal map dalla mesh alta alla ridotta."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = 4
    img_b = bpy.data.images.new('medusa_base_2k', LATO, LATO, alpha=False)
    img_n = bpy.data.images.new('medusa_normal_2k', LATO, LATO, alpha=False)
    img_n.colorspace_settings.name = 'Non-Color'
    # materiali propri della mesh ridotta, con un nodo immagine attivo dove scrivere
    nuovi = []
    for i, m in enumerate(basso.data.materials):
        mc = m.copy()
        mc.name = m.name + '_cotto'
        basso.data.materials[i] = mc
        nuovi.append(mc)

    def bersaglio(img):
        for m in nuovi:
            nt = m.node_tree
            n = nt.nodes.get('bersaglio') or nt.nodes.new('ShaderNodeTexImage')
            n.name = 'bersaglio'
            n.image = img
            for x in nt.nodes:
                x.select = False
            n.select = True
            nt.nodes.active = n

    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    alto.select_set(True)
    basso.select_set(True)
    bpy.context.view_layer.objects.active = basso
    t = time.time()
    bersaglio(img_b)
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_selected_to_active=True,
                        cage_extrusion=0.015, max_ray_distance=0.05, margin=12, target='IMAGE_TEXTURES')
    img_b.filepath_raw = BASE_2K; img_b.file_format = 'PNG'; img_b.save()
    log(f'bake colore in {time.time() - t:.0f} s')
    t = time.time()
    bersaglio(img_n)
    bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', use_selected_to_active=True,
                        cage_extrusion=0.015, max_ray_distance=0.05, margin=12, target='IMAGE_TEXTURES')
    img_n.filepath_raw = NORMAL_2K; img_n.file_format = 'PNG'; img_n.save()
    log(f'bake normal map in {time.time() - t:.0f} s')
    return nuovi


def main():
    t0 = time.time()
    apri(os.path.join(BUILD, 'medusa_02_texture.blend'))
    alto = bpy.data.objects['Medusa']
    basso = alto.copy()
    basso.data = alto.data.copy()
    basso.name = 'Medusa_ridotta'
    collega(basso)
    riduci(basso, RIDUZIONE)
    uv_nuove(basso)
    cuoci(alto, basso)
    # materiali finali: stesse parti, texture cotte (niente texture metallic/roughness)
    nomi = [m.name.replace('_cotto', '') for m in basso.data.materials]
    basso.data.materials.clear()
    for n in nomi:
        m = bpy.data.materials.get(n)
        bpy.data.materials.remove(m)
        basso.data.materials.append(materiale_pbr(n, base=BASE_2K, normal=NORMAL_2K, roughness=0.12))
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    bpy.data.objects.remove(alto)
    basso.name = basso.data.name = 'Medusa'
    # le parti (indici di materiale) si rileggono dall'attributo di faccia "parte" del passo 1
    me = basso.data
    parte = me.attributes.get('parte')
    if parte:
        lab = np.empty(len(me.polygons), dtype=np.int32)
        parte.data.foreach_get('value', lab)
        # l'occhio dipinto (disco quasi piatto) si riduce a pochi triangoli: si riconosce di nuovo dalla
        # posizione, con la stessa regola del passo 1
        occ = leggi_json('occhio.json')
        cen, nor = facce(me)
        d = np.hypot(cen[:, 0] - occ['centro_x'], cen[:, 2] - occ['centro_z'])
        occhio = (lab == 0) & (d < occ['raggio_orbita']) & (cen[:, 1] < -0.12) & (nor[:, 1] < -0.2) & (cen[:, 2] > 0.45)
        lab[occhio] = 4
        parte.data.foreach_set('value', lab)
        me.polygons.foreach_set('material_index', lab)
        me.update()
        log('parti:', np.bincount(lab).tolist())
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
    log(f'mesh da gioco: {len(basso.data.polygons)} triangoli, texture {LATO}px')
    salva(os.path.join(BUILD, 'medusa_02b_ridotta.blend'))
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
