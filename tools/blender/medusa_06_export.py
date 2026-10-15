"""Passo 6: export GLB per Godot (scheletro, pesi, shape key, materiali PBR standard).

Di default esporta la versione FINITA (build/medusa_finale.blend, passo 7) in assets_src/medusa/medusa.glb;
con --base esporta solo la base con scheletro (passo 4) in assets_src/medusa/export/medusa_base.glb.
Prima di esportare adatta i materiali a quello che Godot legge dal glTF:
  - tutti i materiali sono Principled con texture collegate direttamente (base color, metallic/roughness
    con il nodo Separate Color, normal map), cioe' quello che l'exporter glTF capisce;
  - la cornea usa la trasparenza "alpha blend" (Godot non legge KHR_materials_transmission);
  - il labbro dell'orbita usa la texture della pelle con un fattore di colore piu' scuro;
  - gli slot di materiale vuoti (l'occhio dipinto tolto) si eliminano.
I punti d'attacco dei tentacoli (empties) si appendono all'osso "campana": in Godot diventano nodi figli
di quell'osso (BoneAttachment3D).

Controlli: reimporta il GLB in Blender e, se c'e' il comando `godot`, lo importa anche in un progetto
Godot di prova (build/godot_prova) e stampa ossa, superfici, blend shape e materiali.

Versione finita: campana con texture RGBA (alfa) ed emissione dei canali cotte nell'atlante UV, gola con un
gradiente in texture, normal map a 2K (file sotto i 50 MB), tentacoli con le loro texture (colore, emissione,
normal), animazioni dalle tracce NLA: statua, sveglia, insegue, fluttua, fauce_apre, affacciata.
L'origine del GLB e' sul piano d'appoggio dei tentacoli (il piano del piedistallo): la medusa in posa statua
sta in piedi su y = 0.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_06_export.py [--base] [--blend X] [--out Y]
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_05_tentacoli as TENT  # noqa: E402
import medusa_capelli as CAP  # noqa: E402


TEX_CAMPANA_BASE = os.path.join(TEX, 'campana_base_alfa.png')
TEX_CAMPANA_EMIS = os.path.join(TEX, 'campana_emissione.png')
TEX_GOLA = os.path.join(TEX, 'gola_gradiente.png')
TEX_NORMAL_2K = os.path.join(TEX, 'medusa_normal_pulita_2k.png')
TEX_BASE_2K = os.path.join(TEX, 'medusa_basecolor_pulita_2k.jpg')


def argomento(nome, default):
    if nome in sys.argv:
        return sys.argv[sys.argv.index(nome) + 1]
    return default


def togli_slot_vuoti(ob):
    me = ob.data
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    usati = sorted(set(mi.tolist()))
    if len(usati) == len(me.materials):
        return
    mappa = {old: new for new, old in enumerate(usati)}
    mats = [me.materials[i] for i in usati]
    nuovi = np.array([mappa[i] for i in mi], dtype=np.int32)
    me.materials.clear()
    for m in mats:
        me.materials.append(m)
    me.polygons.foreach_set('material_index', nuovi)
    me.update()
    log('slot di materiale tolti:', [i for i in range(max(usati) + 1) if i not in usati])


def materiali_per_godot():
    mc = bpy.data.materials.get('M_occhio_cornea')
    if mc:
        b = mc.node_tree.nodes['BSDF']
        b.inputs['Transmission Weight'].default_value = 0.0
        b.inputs['Alpha'].default_value = 0.06    # velo leggero: in Godot la cornea da' solo i riflessi
        b.inputs['Roughness'].default_value = 0.03
        try:
            mc.surface_render_method = 'BLENDED'
        except Exception:
            pass
    mo = bpy.data.materials.get('M_orbita')
    if mo:
        nt = mo.node_tree
        for n in list(nt.nodes):
            if n.type == 'MIX':
                nt.nodes.remove(n)
        nt.links.new(nt.nodes['base'].outputs['Color'], nt.nodes['BSDF'].inputs['Base Color'])
        # piu' scuro: glTF moltiplica baseColorFactor per la texture; l'exporter lo legge da un nodo
        # "Mix Multiply" solo in certi casi, quindi qui si scurisce con la roughness e il colore e' quello della pelle
        nt.nodes['BSDF'].inputs['Roughness'].default_value = 0.6


# ---------------------------------------------------------------- versione finita (passo 7)

def _raster_valori(me, mask_facce, valori_v, size):
    """Disegna nell'atlante UV (size x size) un attributo di vertice, interpolato dentro ogni triangolo
    (coordinate baricentriche): canali netti anche dove i triangoli sono grandi."""
    import cv2
    uv = loop_uv(me)
    me.calc_loop_triangles()
    nt = len(me.loop_triangles)
    tl = np.empty(nt * 3, dtype=np.int64); me.loop_triangles.foreach_get('loops', tl)
    tp = np.empty(nt, dtype=np.int64); me.loop_triangles.foreach_get('polygon_index', tp)
    lv = loop_vert(me)
    tl = tl.reshape(-1, 3)[mask_facce[tp]]
    C = valori_v.shape[1]
    out = np.zeros((size, size, C), np.float32)
    cop = np.zeros((size, size), np.uint8)
    for t in tl:
        P = np.stack([uv[t, 0] * size - 0.5, (1 - uv[t, 1]) * size - 0.5], 1)
        x0, y0 = np.floor(P.min(0)).astype(int)
        x1, y1 = np.ceil(P.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        a, b, c = P
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        w2 = 1 - w0 - w1
        dentro = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not dentro.any():
            continue
        val = valori_v[lv[t]]
        v = w0[..., None] * val[0] + w1[..., None] * val[1] + w2[..., None] * val[2]
        yy, xx = ys[dentro], xs[dentro]
        out[yy, xx] = v[dentro]
        cop[yy, xx] = 255
    # allarga un po' i bordi delle isole (niente aloni scuri col filtro della GPU)
    k = np.ones((5, 5), np.uint8)
    dil = cv2.dilate(out, k)
    cop_d = cv2.dilate(cop, k)
    out = np.where((cop > 0)[..., None], out, dil)
    return cv2.GaussianBlur(out, (0, 0), 0.8), cop_d


def texture_campana(ob, size=2048):
    """Texture per Godot della campana: base color RGBA (alfa = trasparenza) ed emissione dei canali."""
    import cv2
    sys.path.insert(0, QUI)
    import medusa_07_finale as FIN
    me = ob.data
    att = me.color_attributes['canali']
    dati = np.empty(len(me.vertices) * 4, np.float32); att.data.foreach_get('color', dati)
    dati = dati.reshape(-1, 4)
    mi = np.empty(len(me.polygons), dtype=np.int32); me.polygons.foreach_get('material_index', mi)
    idx_c = [m.name for m in me.materials].index('M_campana')
    can, cop = _raster_valori(me, mi == idx_c, dati[:, :3].astype(np.float32), size)
    canale, bordo, t = can[..., 0], can[..., 1], can[..., 2]
    # emissione: gradiente giallo -> rosa lungo la campana, per l'intensita' dei canali
    pos = np.array([p for p, _ in FIN.CANALI_GRADIENTE]); col = np.array([c for _, c in FIN.CANALI_GRADIENTE])
    rgb = np.stack([np.interp(t, pos, col[:, i]) for i in range(3)], -1)
    inten = np.clip(canale + 0.5 * bordo, 0, 1)
    emis = rgb * inten[..., None]
    emis_srgb = np.where(emis <= 0.0031308, emis * 12.92, 1.055 * np.power(np.clip(emis, 0, 1), 1 / 2.4) - 0.055)
    cv2.imwrite(TEX_CAMPANA_EMIS, (np.clip(emis_srgb, 0, 1) * 255).astype(np.uint8)[..., ::-1])
    # base color: atlante pulito schiarito verso il lilla; alfa: opaca alla vita, trasparente sotto
    # colore della campana dalla stessa texture del materiale (atlante pulito o texture cotta del passo 2b)
    img_base = bpy.data.materials['M_campana'].node_tree.nodes['base'].image
    base = cv2.imread(bpy.path.abspath(img_base.filepath))[..., ::-1].astype(np.float32) / 255
    base = cv2.resize(base, (size, size), interpolation=cv2.INTER_AREA)
    lil = np.array([0.80, 0.62, 0.98])                     # (0.62, 0.36, 0.95) lineare, in sRGB circa
    base = base * 0.5 + lil * 0.5
    tt = np.clip(t / 0.2, 0, 1); tt = tt * tt * (3 - 2 * tt)
    alfa = 1.0 - 0.6 * tt
    rgba = np.dstack([base, alfa])
    rgba[cop == 0, 3] = 1.0
    cv2.imwrite(TEX_CAMPANA_BASE, (np.clip(rgba, 0, 1) * 255).astype(np.uint8)[..., [2, 1, 0, 3]])
    log('texture campana:', os.path.relpath(TEX_CAMPANA_BASE, REPO), os.path.relpath(TEX_CAMPANA_EMIS, REPO))


def texture_gola():
    """Gradiente della carne della gola (v = 1 sul labbro, 0 in fondo), come il ColorRamp del render."""
    import cv2
    v = np.linspace(0, 1, 256)
    pos = [0.0, 0.75, 1.0]
    cols = np.array([(0.035, 0.002, 0.006), (0.42, 0.03, 0.06), (0.62, 0.12, 0.16)])
    lin = np.stack([np.interp(v, pos, cols[:, i]) for i in range(3)], -1)
    srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
    img = np.repeat(srgb[::-1][:, None, :], 8, axis=1)       # riga 0 = v alto
    cv2.imwrite(TEX_GOLA, (img * 255).astype(np.uint8)[..., ::-1])


def normal_2k():
    from PIL import Image
    if not os.path.exists(TEX_NORMAL_2K):
        Image.open(os.path.join(TEX, 'medusa_normal_pulita.png')).resize((2048, 2048), Image.LANCZOS).save(
            TEX_NORMAL_2K, optimize=True)
    return TEX_NORMAL_2K


def base_2k():
    from PIL import Image
    if not os.path.exists(TEX_BASE_2K):
        Image.open(os.path.join(TEX, 'medusa_basecolor_pulita.jpg')).resize((2048, 2048), Image.LANCZOS).save(
            TEX_BASE_2K, quality=93, subsampling=0)
    return TEX_BASE_2K


def materiali_finale_godot():
    """Materiali leggibili dall'import glTF di Godot (StandardMaterial3D), texture a 2K."""
    # vinile: niente coat (Godot non lo legge dal glTF), metallic 0 costante (niente texture MR)
    n2 = immagine(normal_2k(), non_color=True)
    b2 = immagine(base_2k())
    for n in ('M_pelle', 'M_capelli', 'M_orbita'):
        m = bpy.data.materials.get(n)
        if not m:
            continue
        nt = m.node_tree
        b = nt.nodes['BSDF']
        b.inputs['Coat Weight'].default_value = 0.0
        b.inputs['Subsurface Weight'].default_value = 0.0
        if nt.nodes['base'].image.name.startswith('medusa_basecolor_pulita'):   # atlante 4K di Meshy
            nt.nodes['normal'].image = n2
            nt.nodes['base'].image = b2
        mr = nt.nodes.get('mr')
        if mr is None or not mr.image or mr.image.name.startswith('medusa_mr'):
            # vecchia texture metallic/roughness di Meshy: via, metallo 0 costante
            for l in list(b.inputs['Metallic'].links):
                nt.links.remove(l)
            b.inputs['Metallic'].default_value = 0.0
            if mr is not None:
                nt.nodes.remove(mr)
        # altrimenti resta la texture del passo 8 (G = ruvidita', B = metallo): diventa metallicRoughness
    # campana: RGBA + emissione cotte
    m = bpy.data.materials['M_campana']
    nt = m.node_tree
    nt.nodes.clear()
    out = nodo(nt, 'ShaderNodeOutputMaterial', (600, 0))
    b = nodo(nt, 'ShaderNodeBsdfPrincipled', (300, 0)); b.name = 'BSDF'
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    tb = nodo(nt, 'ShaderNodeTexImage', (-300, 200)); tb.image = immagine(TEX_CAMPANA_BASE)
    te = nodo(nt, 'ShaderNodeTexImage', (-300, -200)); te.image = immagine(TEX_CAMPANA_EMIS)
    nt.links.new(tb.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(tb.outputs['Alpha'], b.inputs['Alpha'])
    nt.links.new(te.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 2.5
    b.inputs['Roughness'].default_value = 0.1
    tn = nodo(nt, 'ShaderNodeTexImage', (-300, -500))
    tn.image = bpy.data.materials['M_pelle'].node_tree.nodes['normal'].image   # stessa normal map della pelle
    nm = nodo(nt, 'ShaderNodeNormalMap', (0, -500))
    nt.links.new(tn.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], b.inputs['Normal'])
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    # gola: gradiente in texture
    texture_gola()
    m = bpy.data.materials.get('M_fauce_carne')
    if m:
        nt = m.node_tree
        b = nt.nodes['BSDF']
        for n in list(nt.nodes):
            if n.type in ('UVMAP', 'SEPXYZ', 'VALTORGB', 'SEPARATE_XYZ'):
                nt.nodes.remove(n)
        t = nodo(nt, 'ShaderNodeTexImage', (-300, 0)); t.image = immagine(TEX_GOLA)
        nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
        b.inputs['Coat Weight'].default_value = 0.0
        b.inputs['Subsurface Weight'].default_value = 0.0
    mb = bpy.data.materials.get('M_occhio_bulbo')
    if mb:
        nt = mb.node_tree
        nt.nodes['BSDF'].inputs['Emission Strength'].default_value = 0.22
        # nel glTF l'occhio calmo (texture collegata direttamente); la venatura e' nello shader Godot
        for nome in ('mix_venatura', 'base_venata', 'venatura'):
            if nome in nt.nodes:
                nt.nodes.remove(nt.nodes[nome])
        nt.links.new(nt.nodes['base'].outputs['Color'], nt.nodes['BSDF'].inputs['Base Color'])
        nt.links.new(nt.nodes['base'].outputs['Color'], nt.nodes['BSDF'].inputs['Emission Color'])
    for n in ('M_tentacoli', 'M_filamenti', 'M_denti', 'M_ciocche'):
        m = bpy.data.materials.get(n)
        if m:
            b = m.node_tree.nodes['BSDF']
            b.inputs['Coat Weight'].default_value = 0.0
            b.inputs['Subsurface Weight'].default_value = 0.0
            b.inputs['Transmission Weight'].default_value = 0.0     # traslucenza: medusa_tentacoli.tres
            if n == 'M_tentacoli':
                b.inputs['Emission Strength'].default_value = 1.0   # bagliore piu' forte: medusa_tentacoli.tres


def prepara_finale():
    corpo = bpy.data.objects['Medusa']
    texture_campana(corpo)
    # le stesse texture servono allo shader Godot della campana (assets_src/medusa/godot/)
    gd = os.path.join(ASSET, 'godot')
    os.makedirs(gd, exist_ok=True)
    # (piu' colore e normal 4K del corpo, usate da medusa_pelle.tres e medusa_orbita.tres)
    for t in (TEX_CAMPANA_BASE, TEX_CAMPANA_EMIS, TENT.TEX_TENT_BASE, TENT.TEX_TENT_EMIS, TENT.TEX_TENT_NORMAL,
              CAP.TEX_CIOCCHE, CAP.TEX_CIOCCHE_N, CAP.TEX_CIOCCHE_E,
              os.path.join(TEX, 'medusa_colore_4k.jpg'), os.path.join(TEX, 'medusa_normal_4k.jpg'),
              os.path.join(TEX, 'occhio_bulbo_calmo.png'), os.path.join(TEX, 'occhio_bulbo_venato.png')):
        if os.path.exists(t):
            shutil.copy(t, os.path.join(gd, os.path.basename(t)))
    togli_slot_vuoti(corpo)
    materiali_per_godot()
    materiali_finale_godot()
    coll = bpy.data.collections.get('Attacchi_tentacoli')
    if coll:
        for e in list(coll.objects):
            bpy.data.objects.remove(e)
        bpy.data.collections.remove(coll)
    bpy.context.view_layer.update()
    # niente attributi colore nel glTF (Godot li userebbe come colore dei vertici)
    for a in list(corpo.data.color_attributes):
        corpo.data.color_attributes.remove(a)


def attacchi_sull_osso(arm):
    coll = bpy.data.collections.get('Attacchi_tentacoli')
    if not coll:
        return
    for e in coll.objects:
        mw = e.matrix_world.copy()
        e.parent = arm
        e.parent_type = 'BONE'
        e.parent_bone = 'campana'
        bpy.context.view_layer.update()
        e.matrix_world = mw


def esporta(out, origine_a_terra=False):
    arm = bpy.data.objects['Medusa_Scheletro']
    attacchi_sull_osso(arm)
    if origine_a_terra and 'scala' not in arm:
        # l'origine del GLB va sul piano d'appoggio dei tentacoli: tutto sale di -z_pavimento
        arm.location.z = -TENT.STATUA['z_pavimento']
        log(f'origine sul piano del piedistallo: scheletro alzato di {arm.location.z:.2f} m')
    elif 'scala' in arm:
        log(f"statua a grandezza vera (scala x{arm['scala']:.3f}), piano dei tentacoli a y = 0")
    # stato di riposo pulito per l'export: fuori dalle strisce NLA (nessuna estrapolazione) le ossa sono a riposo
    # (la statua) e tutte le blend shape a 0; altrimenti i valori di default nel glTF sarebbero quelli scritti
    # dall'ultima traccia valutata (per esempio la campana schiacciata dell'affacciata)
    for i in list(bpy.data.objects) + list(bpy.data.shape_keys):
        ad = i.animation_data
        if ad:
            ad.action = None
            for tr in ad.nla_tracks:
                for st in tr.strips:
                    st.extrapolation = 'NOTHING'
    bpy.context.scene.frame_set(0)
    for k in bpy.data.shape_keys:
        for kb in k.key_blocks[1:]:
            kb.value = 0.0
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()
    for o in bpy.context.view_layer.objects:
        if o:
            o.select_set(False)
    sel = [arm] + [o for o in bpy.data.objects if o.parent == arm]
    for o in sel:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True,
        export_image_format='AUTO', export_tangents=True, export_materials='EXPORT',
        export_skins=True, export_influence_nb=4, export_def_bones=False, export_leaf_bone=False,
        export_morph=True, export_morph_normal=True, export_animations=True, export_yup=True,
        export_vertex_color='ACTIVE',
        export_animation_mode='NLA_TRACKS', export_force_sampling=True,
        export_apply=False, export_extras=False)
    log('esportato', os.path.relpath(out, REPO), f'{os.path.getsize(out) / 1e6:.1f} MB')


def controlla_blender(out):
    reset()
    bpy.ops.import_scene.gltf(filepath=out)
    arms = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    mesh = [o for o in bpy.data.objects if o.type == 'MESH']
    log('reimport: armature', [(a.name, len(a.data.bones)) for a in arms])
    for o in mesh:
        sk = [k.name for k in o.data.shape_keys.key_blocks] if o.data.shape_keys else []
        log(f'  mesh {o.name}: {len(o.data.polygons)} facce, materiali {[m.name for m in o.data.materials]}, '
            f'shape key {sk}, gruppi {len(o.vertex_groups)}')


GD_CONTROLLO = '''extends SceneTree
func _init():
\tvar scena = load("res://medusa.glb").instantiate()
\tvar stack = [scena]
\twhile stack.size() > 0:
\t\tvar n = stack.pop_back()
\t\tif n is Skeleton3D:
\t\t\tprint("SKELETON ", n.name, " ossa=", n.get_bone_count(), " radice=", n.get_bone_name(0))
\t\tif n is MeshInstance3D:
\t\t\tvar m = n.mesh
\t\t\tvar bs = []
\t\t\tfor i in m.get_blend_shape_count():
\t\t\t\tbs.append(m.get_blend_shape_name(i))
\t\t\tprint("MESH ", n.name, " superfici=", m.get_surface_count(), " blend_shape=", bs, " skin=", n.skin != null)
\t\t\tfor s in m.get_surface_count():
\t\t\t\tvar mat = m.surface_get_material(s)
\t\t\t\tif mat is BaseMaterial3D:
\t\t\t\t\tprint("   materiale ", mat.resource_name, " trasparenza=", mat.transparency, " albedo_tex=", mat.albedo_texture != null, " normal=", mat.normal_enabled, " roughness=", mat.roughness, " rough_tex=", mat.roughness_texture != null, " emissione=", mat.emission_enabled, " x", mat.emission_energy_multiplier, " op=", mat.emission_operator, " colore_vertici=", mat.vertex_color_use_as_albedo)
\t\tif n is BoneAttachment3D:
\t\t\tprint("ATTACCO ", n.name, " osso=", n.bone_name)
\t\tfor c in n.get_children():
\t\t\tstack.append(c)
\tvar ap = scena.find_child("AnimationPlayer", true, false)
\tif ap:
\t\tprint("ANIMAZIONI ", ap.get_animation_list())
\tfor r in ["medusa_campana.tres", "medusa_tentacoli.tres", "medusa_ciocche.tres"]:
\t\tvar mat = load("res://assets/models/medusa/" + r)
\t\tvar op = mat.emission_operator if mat is BaseMaterial3D else -1
\t\tprint("MATERIALE_ESTERNO ", r, " ", mat != null, " op=", op)
\tquit()
'''


def controlla_godot(out):
    if not shutil.which('godot'):
        log('godot non trovato: controllo saltato')
        return
    prj = os.path.join(BUILD, 'godot_prova')
    os.makedirs(prj, exist_ok=True)
    if not os.path.exists(os.path.join(prj, 'project.godot')):
        with open(os.path.join(prj, 'project.godot'), 'w') as f:
            f.write('config_version=5\n\n[application]\nconfig/name="prova medusa"\n')
    for f in os.listdir(prj):
        if f.startswith('medusa'):
            os.remove(os.path.join(prj, f))
    shutil.copy(out, os.path.join(prj, 'medusa.glb'))
    # i file della cartella godot/ (shader, materiali, texture) come nel progetto vero
    dest = os.path.join(prj, 'assets', 'models', 'medusa')
    os.makedirs(dest, exist_ok=True)
    gd = os.path.join(ASSET, 'godot')
    for f in os.listdir(gd):
        if not f.endswith('.md'):
            shutil.copy(os.path.join(gd, f), os.path.join(dest, f))
    with open(os.path.join(prj, 'controlla.gd'), 'w') as f:
        f.write(GD_CONTROLLO)
    r = subprocess.run(['godot', '--headless', '--path', prj, '--import'], capture_output=True, text=True, timeout=900)
    r = subprocess.run(['godot', '--headless', '--path', prj, '--script', 'res://controlla.gd'],
                       capture_output=True, text=True, timeout=600)
    righe = [x for x in (r.stdout + r.stderr).splitlines()
             if x.startswith(('SKELETON', 'MESH', '   materiale', 'ATTACCO', 'ANIMAZIONI', 'SCRIPT ERROR',
                              'MATERIALE_ESTERNO', 'ERROR'))]
    log('Godot:')
    for x in righe:
        print('   ', x)


def main():
    finale = '--base' not in sys.argv
    if finale:      # versione finita (passo 7) -> assets_src/medusa/medusa.glb
        src = argomento('--blend', os.path.join(BUILD, 'medusa_finale.blend'))
        out = argomento('--out', os.path.join(ASSET, 'medusa.glb'))
    else:           # solo base con scheletro (passo 4)
        src = argomento('--blend', os.path.join(BUILD, 'medusa_04_scheletro.blend'))
        out = argomento('--out', os.path.join(EXPORT, 'medusa_base.glb'))
    apri(src)
    if finale:
        prepara_finale()
    else:
        togli_slot_vuoti(bpy.data.objects['Medusa'])
        materiali_per_godot()
    esporta(out, origine_a_terra=finale)
    controlla_blender(out)
    if '--no-godot' not in sys.argv:
        controlla_godot(out)


if __name__ == '__main__':
    main()
