"""Anteprime in Cycles dell'acquapark con la luce dei concept: notte, luci d'emergenza rosse,
neon freddi, luce blu della tempesta dagli oblò, nebbia bassa.

Monta l'"angolo di prova" con i pezzi di ambiente_kit.py (stessa inquadratura e stessa luce per
tutte le palette) e, con --oggetti, mette in scena anche gli oggetti di Meshy.

Uso (dalla radice del repository):
  PY=/home/user/tools/blender-venv/bin/python
  nice -n 10 $PY tools/blender/ambiente_anteprima.py --palette p1_bianco_turchese --uscita /tmp/prove
  opzioni: --campioni 64 --larghezza 1280 --altezza 720 --rapida (senza nebbia, pochi campioni)
           --vista angolo|oggetti  --fili 3  --blend file.blend (salva la scena)  --glb file.glb
"""
import math, os, sys, tempfile
import bpy
from mathutils import Vector, Euler

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import ambiente_kit as K  # noqa: E402
from ambiente_palette import PALETTE  # noqa: E402

RADICE = K.RADICE
OGGETTI = os.path.join(RADICE, 'assets_src', 'ambiente', 'oggetti')


# ----------------------------------------------------------------------------- utilità

def metti(ob, pos, rot_z_gradi=0.0):
    ob.location = Vector(pos)
    ob.rotation_euler = Euler((0, 0, math.radians(rot_z_gradi)))
    for ch in ob.children:  # le collisioni non si vedono nel render
        ch.hide_render = True
        ch.hide_viewport = True
    return ob


def materiale_semplice(nome, colore, rough=0.5, emissione=0.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*colore, 1)
    b.inputs['Roughness'].default_value = rough
    if emissione:
        b.inputs['Emission Color'].default_value = (*colore, 1)
        b.inputs['Emission Strength'].default_value = emissione
    return m


def piano(nome, centro, dim, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=centro, rotation=rot)
    ob = bpy.context.active_object
    ob.name = nome
    ob.scale = (dim[0], dim[1], 1)
    ob.data.materials.append(mat)
    return ob


def luce(nome, tipo, pos, energia, colore, **kw):
    d = bpy.data.lights.new(nome, tipo)
    d.energy = energia
    d.color = colore
    for k, v in kw.items():
        setattr(d, k, v)
    ob = bpy.data.objects.new(nome, d)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = pos
    if tipo == 'AREA':  # le luci di riempimento non devono vedersi come rettangoli chiari
        ob.visible_camera = False
        ob.visible_glossy = False
    return ob


def punta(ob, bersaglio):
    ob.rotation_euler = (Vector(bersaglio) - ob.location).to_track_quat('-Z', 'Y').to_euler()


# ----------------------------------------------------------------------------- scena

def costruisci_angolo(mats):
    """Angolo di prova. Coordinate (metri): vasca x -4,5..-0,5 e y -4..4 (fondo a -1,2);
    ponte a z=0; parete-scafo con oblò a y=6,5; galleria a sbalzo (z 3,0-3,3) da y=5 a 6,5;
    pareti laterali a x=4 (destra) e x=-8,5 (sinistra, quasi al buio)."""
    pal = mats.pal
    # --- vasca: bordi dritti (A destra, A2 sinistra, B dietro), angoli, fondo
    for y0 in (-4.0, -2.0, 0.0, 2.0):
        metti(K.bordo_vasca(mats, nome=f'bordoA_{y0}'), (-0.5, y0, 0), 90)
        metti(K.bordo_vasca(mats, nome=f'bordoA2_{y0}'), (-4.5, y0 + 2.0, 0), -90)
    for x1 in (-2.5, -0.5):
        metti(K.bordo_vasca(mats, nome=f'bordoB_{x1}'), (x1, 4.0, 0), 180)
    metti(K.bordo_vasca_angolo(mats, nome='angolo_dx'), (-0.5, 4.0, 0))
    metti(K.scaletta_vasca(mats), (-0.5, 2.3, 0), 90)
    metti(K.bordo_vasca_angolo(mats, nome='angolo_sx'), (-4.5, 4.0, 0), 90)
    for x0 in (-4.5, -2.5):
        for y0 in (-4.0, -2.0, 0.0, 2.0):
            metti(K.fondo_vasca(mats, nome=f'fondo_{x0}_{y0}'), (x0, y0, 0))
    # --- pavimento del ponte
    for x0 in (0.0, 2.0, -7.0):
        for y0 in (-4.0, -2.0, 0.0, 2.0):
            metti(K.pavimento(mats, nome=f'pav_{x0}_{y0}'), (x0, y0, 0))
        metti(K.pavimento(mats, 2.0, 0.5, nome=f'pavr_{x0}'), (x0, 4.0, 0))
    for y0 in (-4.0, -2.0, 0.0, 2.0):
        metti(K.pavimento(mats, 2.0, 2.0, nome=f'pavl_{y0}'), (-9.0, y0, 0))
        metti(K.pavimento(mats, 0.5, 2.0, nome=f'pavl2_{y0}'), (-5.0, y0, 0))
    metti(K.pavimento(mats, 2.0, 0.5, nome='pavl3'), (-9.0, 4.0, 0))
    metti(K.pavimento(mats, 2.0, 0.5, nome='pavl4'), (-7.0, 4.0, 0))
    for x0 in (-8.5, -6.5, -4.5, -2.5, 0.0, 2.0):
        metti(K.pavimento(mats, nome=f'pavf_{x0}'), (x0, 4.5, 0))
    metti(K.pavimento(mats, 0.5, 2.0, nome='pavf_fill'), (-0.5, 4.5, 0))
    # --- parete-scafo di fondo (y = 6,5) e piano superiore
    moduli = ((-8.5, 2.0, True), (-6.5, 2.0, False), (-4.5, 2.0, False), (-2.5, 2.0, True),
              (-0.5, 2.0, True), (1.5, 2.0, True), (3.5, 0.5, False))
    for x0, w, ob in moduli:
        metti(K.parete(mats, w, oblo=ob, nome=f'par_{x0}'), (x0, 6.5, 0))
        alto = ob and x0 not in (-2.5,)
        metti(K.parete(mats, w, oblo=alto, alta=True, nome=f'para_{x0}'), (x0, 6.5, 3.0))
        if ob:
            metti(K.oblo(mats, nome=f'oblo_{x0}'), (x0 + w / 2, 6.5, K.OBLO_Z))
        if alto:
            metti(K.oblo(mats, nome=f'obloa_{x0}'), (x0 + w / 2, 6.5, 3.0 + K.OBLO_Z))
    # --- parete di destra (x = 4) e di sinistra (x = -8,5)
    for y1 in (6.5, 4.5, 2.5, 0.5, -1.5):
        metti(K.parete(mats, 2.0, oblo=(y1 == 2.5), nome=f'pdx_{y1}'), (4.0, y1, 0), -90)
        metti(K.parete(mats, 2.0, alta=True, nome=f'pdxa_{y1}'), (4.0, y1, 3.0), -90)
        if y1 == 2.5:
            metti(K.oblo(mats, nome='oblo_dx'), (4.0, y1 - 1.0, K.OBLO_Z), -90)
    for y0 in (-3.5, -1.5, 0.5, 2.5, 4.5):
        metti(K.parete(mats, 2.0, nome=f'psx_{y0}'), (-8.5, y0, 0), 90)
        metti(K.parete(mats, 2.0, alta=True, nome=f'psxa_{y0}'), (-8.5, y0, 3.0), 90)
    # --- galleria a sbalzo, ringhiera, cartellone
    for x0, w in ((-8.5, 2.0), (-6.5, 2.0), (-4.5, 2.0), (-2.5, 2.0), (-0.5, 2.0), (1.5, 2.0), (3.5, 0.5)):
        metti(K.galleria_bordo(mats, w, nome=f'gal_{x0}'), (x0, 5.0, 0))
    for x0, w, fine in ((-8.5, 2.0, False), (-4.5, 2.0, False), (-2.5, 2.0, False), (-0.5, 2.0, False),
                        (1.5, 2.0, False), (3.5, 0.5, True)):
        metti(K.ringhiera(mats, w, nome=f'ring_{x0}', paletto_fine=(fine or x0 == -8.5)), (x0, 5.06, 3.3))
    metti(K.cartellone(mats), (0.7, 5.0, 3.18))
    # --- luci (oggetti)
    metti(K.lampada_neon(mats, nome='neon_a'), (0.7, 5.62, 2.88))
    metti(K.lampada_neon(mats, accesa=(True, False), nome='neon_b'), (-3.3, 5.62, 2.88))
    metti(K.lampada_neon(mats, accesa=(False, False), nome='neon_c'), (2.9, 5.62, 2.88))
    metti(K.lampada_neon(mats, accesa=(False, False), nome='neon_d'), (-7.0, 5.62, 2.88))
    metti(K.luce_emergenza(mats, nome='emerg_a'), (-0.5, 6.5, 2.45))
    metti(K.luce_emergenza(mats, nome='emerg_b'), (4.0, 1.6, 2.6), -90)
    metti(K.luce_emergenza(mats, nome='emerg_c'), (3.0, 6.5, 5.2))
    metti(K.luce_emergenza(mats, nome='emerg_d'), (-8.5, 1.5, 2.6), 90)
    metti(K.luce_emergenza(mats, nome='emerg_e'), (-5.5, 6.5, 2.45))
    # --- scivolo: dalla galleria (a sinistra) scende nella vasca, con due colonne
    percorso = [(-7.6, 5.9, 3.85), (-6.6, 4.4, 3.55), (-5.4, 3.4, 2.95), (-4.2, 3.05, 2.25),
                (-3.2, 3.0, 1.55), (-2.55, 2.5, 0.9), (-2.45, 1.6, 0.35), (-2.7, 0.8, 0.05)]
    metti(K.tubo_scivolo(mats, percorso, nome='scivolo', materiali=pal.get('scivolo_sequenza')), (0, 0, 0))
    metti(K.colonna(mats, (-5.4, 3.4, 0.0), 2.95 - K.SCIVOLO_R - 0.02, nome='col_a'), (0, 0, 0))
    metti(K.colonna(mats, (-3.2, 3.0, -1.2), 1.55 + 1.2 - K.SCIVOLO_R - 0.02, nome='col_b'), (0, 0, 0))
    # --- soffitto scuro (fuori quadro, ma si vede nei riflessi)
    piano('soffitto', (-2.0, 1.0, 6.0), (14, 14), materiale_semplice('M_soffitto', (0.02, 0.022, 0.025), 0.7), rot=(math.pi, 0, 0))


def acqua():
    m = bpy.data.materials.new('M_acqua_anteprima')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (0.10, 0.20, 0.17, 1)
    b.inputs['Roughness'].default_value = 0.02
    b.inputs['Transmission Weight'].default_value = 1.0
    b.inputs['IOR'].default_value = 1.333
    no = nt.nodes.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 3.0
    no.inputs['Detail'].default_value = 3.0
    bu = nt.nodes.new('ShaderNodeBump'); bu.inputs['Strength'].default_value = 0.04
    nt.links.new(no.outputs['Fac'], bu.inputs['Height'])
    nt.links.new(bu.outputs['Normal'], b.inputs['Normal'])
    # vasca quasi vuota: un velo d'acqua sporca sul fondo (l'acqua vera la fa il gruppo "acqua")
    piano('acqua', (-2.5, 0.0, -1.13), (4.0, 8.0), m)


def esterno():
    """Fuori dagli oblò: cielo di tempesta e mare scuro (piano emissivo) + luce blu che entra."""
    m = bpy.data.materials.new('M_tempesta')
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Generated'], sep.inputs['Vector'])
    cr = nt.nodes.new('ShaderNodeValToRGB')
    e = cr.color_ramp.elements
    e[0].position = 0.0; e[0].color = (0.005, 0.008, 0.012, 1)
    e[1].position = 0.42; e[1].color = (0.02, 0.03, 0.045, 1)
    e.new(0.47).color = (0.10, 0.13, 0.19, 1)    # orizzonte
    e.new(1.0).color = (0.035, 0.045, 0.07, 1)
    nt.links.new(sep.outputs['Y'], cr.inputs['Fac'])
    no = nt.nodes.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 4.0
    mul = nt.nodes.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 0.6
    nt.links.new(cr.outputs['Color'], K._sock(mul.inputs, 'A_Color'))
    nt.links.new(no.outputs['Color'], K._sock(mul.inputs, 'B_Color'))
    nt.links.new(K._sock(mul.outputs, 'Result_Color'), em.inputs['Color'])
    em.inputs['Strength'].default_value = 0.6
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    for ob in (piano('cielo', (-2.0, 8.0, 3.0), (16, 10), m, rot=(math.pi / 2, 0, 0)),
               piano('cielo_dx', (5.6, 0.5, 3.0), (14, 10), m, rot=(math.pi / 2, 0, math.pi / 2))):
        ob.visible_shadow = False  # si vede dagli oblò ma non blocca la luce della tempesta
    # luna/lampi lontani: luce d'area fredda fuori dallo scafo, entra dagli oblò
    # luce lunare/lampi: due 'soli' stretti fuori dallo scafo -> fasci netti dagli oblò nella nebbia
    l = luce('luce_tempesta', 'SUN', (0.0, 9.0, 6.0), 2.6, (0.5, 0.64, 1.0), angle=math.radians(2.5))
    l.rotation_euler = (Vector((0.15, -0.9, -0.40))).to_track_quat('-Z', 'Y').to_euler()
    l2 = luce('luce_tempesta_dx', 'SUN', (8.0, 1.5, 6.0), 1.2, (0.5, 0.64, 1.0), angle=math.radians(2.5))
    l2.rotation_euler = (Vector((-0.9, -0.15, -0.38))).to_track_quat('-Z', 'Y').to_euler()


def luci():
    # neon (tubi emissivi + luce d'area che illumina sotto la galleria)
    # le luci d'area emettono verso -z: niente rotazione = verso il basso
    luce('neon_a_luce', 'AREA', (0.7, 5.62, 2.78), 90, (0.80, 1.0, 0.93), size=1.25, size_y=0.12, shape='RECTANGLE')
    luce('neon_b_luce', 'AREA', (-2.7, 5.66, 2.78), 30, (0.80, 1.0, 0.93), size=1.25, size_y=0.06, shape='RECTANGLE')
    # emergenza rosse: punto dentro la cupola + alone
    for nome, pos in (('emerg_a', (-0.5, 6.38, 2.45)), ('emerg_b', (3.88, 1.6, 2.6)), ('emerg_c', (3.0, 6.38, 5.2)),
                      ('emerg_d', (-8.38, 1.5, 2.6)), ('emerg_e', (-5.5, 6.38, 2.45))):
        luce(nome + '_luce', 'POINT', pos, 18, (1.0, 0.035, 0.02), shadow_soft_size=0.06)
    # luce fredda debole dall'alto (la cupola di vetro sopra la vasca, fuori quadro)
    # luce fredda della cupola di vetro sopra la vasca (fuori quadro)
    luce('cupola', 'AREA', (-2.5, 0.0, 5.9), 260, (0.45, 0.58, 0.9), size=4.0, size_y=8.0, shape='RECTANGLE')
    # un faretto sotto la galleria illumina ancora il cartellone dal basso
    l = luce('faro_cartellone', 'SPOT', (0.7, 4.75, 2.86), 18, (1.0, 0.88, 0.72), spot_size=math.radians(75),
             spot_blend=0.8, shadow_soft_size=0.04)
    punta(l, (0.7, 4.98, 4.2))


def nebbia(densita=1.0):
    """Nebbia bassa: densa sotto 1 m, velo leggero sopra, con variazioni lente."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-2.25, 0.25, 2.4))
    cubo = bpy.context.active_object
    cubo.name = 'nebbia'
    cubo.scale = (12.5, 12.5, 7.2)  # tutta la sala: x -8,5..4, y -6..6,5, z -1,2..6
    m = bpy.data.materials.new('M_nebbia')
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    vol = nt.nodes.new('ShaderNodeVolumePrincipled')
    vol.inputs['Color'].default_value = (0.62, 0.68, 0.74, 1)
    vol.inputs['Anisotropy'].default_value = 0.45
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(geo.outputs['Position'], sep.inputs['Vector'])
    mr = nt.nodes.new('ShaderNodeMapRange')
    mr.interpolation_type = 'SMOOTHSTEP'
    mr.inputs['From Min'].default_value = -0.4; mr.inputs['From Max'].default_value = 1.1
    mr.inputs['To Min'].default_value = 1.0; mr.inputs['To Max'].default_value = 0.0
    nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
    no = nt.nodes.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 0.35
    no.inputs['Detail'].default_value = 2.0
    nt.links.new(geo.outputs['Position'], no.inputs['Vector'])
    mn = nt.nodes.new('ShaderNodeMapRange')
    mn.inputs['From Min'].default_value = 0.3; mn.inputs['From Max'].default_value = 0.7
    mn.inputs['To Min'].default_value = 0.25; mn.inputs['To Max'].default_value = 1.4
    nt.links.new(no.outputs['Fac'], mn.inputs['Value'])
    m1 = nt.nodes.new('ShaderNodeMath'); m1.operation = 'MULTIPLY'
    nt.links.new(mr.outputs['Result'], m1.inputs[0]); nt.links.new(mn.outputs['Result'], m1.inputs[1])
    m2 = nt.nodes.new('ShaderNodeMath'); m2.operation = 'MULTIPLY_ADD'
    nt.links.new(m1.outputs['Value'], m2.inputs[0])
    m2.inputs[1].default_value = 0.22 * densita
    m2.inputs[2].default_value = 0.03 * densita
    nt.links.new(m2.outputs['Value'], vol.inputs['Density'])
    nt.links.new(vol.outputs['Volume'], out.inputs['Volume'])
    cubo.data.materials.append(m)
    cubo.visible_shadow = False
    return cubo


def decal_colature(mats):
    """Colature sotto gli oblò e sotto la galleria (piani con alfa; in Godot sono nodi Decal)."""
    p = os.path.join(K.TEX, 'decal', 'colatura_col.png')
    m = bpy.data.materials.new('M_amb_decal_colatura')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(p, check_existing=True)
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(t.outputs['Alpha'], b.inputs['Alpha'])
    b.inputs['Roughness'].default_value = 0.6
    if hasattr(m, 'surface_render_method'):
        m.surface_render_method = 'BLENDED'
    pos = [(-1.5, 6.499, 0.55, 0.9, 1.6), (0.5, 6.499, 0.55, 0.8, 1.7), (2.5, 6.499, 0.6, 0.9, 1.5),
           (0.5, 6.499, 3.55, 0.8, 1.6), (2.5, 6.499, 3.5, 0.9, 1.7), (-2.0, 6.499, 2.15, 1.6, 0.9),
           (1.3, 6.499, 2.1, 1.8, 0.95)]
    for i, (x, y, zc, w, h) in enumerate(pos):
        ob = piano(f'decal_{i}', (x, y, zc), (w, h), m, rot=(math.pi / 2, 0, 0))
        uv = ob.data.uv_layers.active.data
        for li, loop in enumerate(ob.data.loops):
            co = ob.data.vertices[loop.vertex_index].co
            uv[li].uv = (co.x + 0.5, co.y + 0.5)


def oggetti_meshy(posizioni):
    """Importa i GLB di Meshy, li porta a misura reale e li appoggia a terra."""
    misure = {'paperella_gigante': ('z', 0.55), 'delfino_gonfiabile_sgonfio': ('lungo', 1.6),
              'lettino_plastica': ('lungo', 1.9)}
    for nome, (pos, rot) in posizioni.items():
        prima = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OGGETTI, nome, nome + '_meshy.glb'))
        nuovi = [o for o in bpy.context.scene.objects if o not in prima]
        mesh = [o for o in nuovi if o.type == 'MESH']
        radice = bpy.data.objects.new('ogg_' + nome, None)
        bpy.context.scene.collection.objects.link(radice)
        for o in nuovi:
            if o.parent is None:
                o.parent = radice
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(c) for o in mesh for c in o.bound_box]
        lo = Vector([min(p[i] for p in pts) for i in range(3)])
        hi = Vector([max(p[i] for p in pts) for i in range(3)])
        dim = hi - lo
        asse, misura = misure[nome]
        s = misura / (dim.z if asse == 'z' else max(dim.x, dim.y))
        centro = (lo + hi) / 2
        for o in nuovi:
            if o.parent is radice:
                o.location -= Vector((centro.x, centro.y, lo.z))
        radice.scale = (s, s, s)
        radice.location = Vector(pos)
        radice.rotation_euler = Euler((0, 0, math.radians(rot)))


def camera(pos, bersaglio, lente=20.0):
    cd = bpy.data.cameras.new('cam')
    cd.lens = lente
    cd.sensor_width = 36
    cam = bpy.data.objects.new('cam', cd)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = pos
    punta(cam, bersaglio)
    bpy.context.scene.camera = cam
    return cam


def impostazioni(campioni, larghezza, altezza, fili, rapida):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = campioni
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.03
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.cycles.diffuse_bounces = 3
    sc.cycles.glossy_bounces = 3
    sc.cycles.transmission_bounces = 4
    sc.cycles.volume_bounces = 0
    sc.cycles.transparent_max_bounces = 8
    sc.cycles.caustics_reflective = False
    sc.cycles.caustics_refractive = False
    sc.cycles.sample_clamp_indirect = 4.0
    sc.cycles.volume_step_rate = 2.0 if not rapida else 8.0
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = fili
    sc.render.resolution_x, sc.render.resolution_y = larghezza, altezza
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    sc.view_settings.exposure = -0.3
    w = bpy.data.worlds.new('notte')
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.004, 0.005, 0.008, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0


VISTE = {
    # posizione camera, bersaglio, lente (mm): occhio a 1,65 m come il giocatore
    'angolo': ((3.2, -3.2, 1.65), (-1.6, 5.4, 1.75), 19.0),
    'oggetti': ((3.0, -1.9, 1.6), (1.25, 2.4, 0.3), 24.0),
    'paperella': ((1.45, 0.05, 0.62), (0.55, 1.2, 0.27), 50.0),
    'delfino': ((0.15, 1.55, 1.3), (1.25, 3.05, 0.08), 45.0),
    'lettino': ((3.75, 1.05, 1.3), (2.5, 2.95, 0.38), 42.0),
}
POSIZIONI_OGGETTI = {
    'paperella_gigante': ((0.55, 1.2, 0.0), -35),
    'delfino_gonfiabile_sgonfio': ((1.25, 3.05, 0.0), 160),
    'lettino_plastica': ((2.55, 2.95, 0.0), 205),
}


def main():
    import argparse
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--palette', default='p1_bianco_turchese', choices=list(PALETTE))
    ap.add_argument('--vista', default='angolo', choices=list(VISTE))
    ap.add_argument('--campioni', type=int, default=64)
    ap.add_argument('--larghezza', type=int, default=1280)
    ap.add_argument('--altezza', type=int, default=720)
    ap.add_argument('--fili', type=int, default=3)
    ap.add_argument('--rapida', action='store_true')
    ap.add_argument('--uscita', default=os.path.join(tempfile.gettempdir(), 'ambiente_anteprime'))
    ap.add_argument('--blend', default='')
    ap.add_argument('--glb', default='')
    ap.add_argument('--spegni', default='', help='luci da spegnere (nomi separati da virgole), per le prove')
    ap.add_argument('--suffisso', default='')
    a = ap.parse_args(argv)

    K.svuota()
    mats = K.Materiali(a.palette, per_render=True)
    costruisci_angolo(mats)
    acqua()
    esterno()
    luci()
    decal_colature(mats)
    if a.vista != 'angolo':
        oggetti_meshy(POSIZIONI_OGGETTI)
    if not a.rapida:
        nebbia()
    pos, bers, lente = VISTE[a.vista]
    camera(pos, bers, lente)
    impostazioni(a.campioni if not a.rapida else min(a.campioni, 12), a.larghezza, a.altezza, a.fili, a.rapida)
    if a.glb:
        K.esporta([o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name not in ('nebbia',)], a.glb)
    if a.blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.blend))
    for nome in filter(None, a.spegni.split(',')):
        bpy.context.scene.objects[nome].data.energy = 0.0
    os.makedirs(a.uscita, exist_ok=True)
    out = os.path.abspath(os.path.join(a.uscita, f'{a.vista}_{a.palette}{a.suffisso}.png'))
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print('render ->', out)


if __name__ == '__main__':
    main()
