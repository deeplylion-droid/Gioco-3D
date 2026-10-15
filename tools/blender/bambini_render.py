"""Render dei modelli dei bambini (GLB di Meshy) in Cycles: davanti, tre quarti, dietro.

Due luci:
  studio  fondale grigio curvo, luce principale, riempimento e controluce;
  notte   angolo dell'acquapark di notte: piastrelle bagnate, oblò sul mare in tempesta,
          luci rosse d'emergenza, un neon freddo, nebbia bassa e qualche giocattolo colorato.

Uso:
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/bambini_render.py \
        <modello.glb> <prefisso_png> [--altezza 1.2] [--campioni 48] [--luci studio,notte]
        [--viste davanti,tre_quarti,dietro] [--bagliore 0] [--bagnato 0.6] [--res 720x960]
        [--fili 3] [--ruota 0]

Escono <prefisso>_<luce>_<vista>.png. Il modello viene scalato all'altezza data (metri),
appoggiato a terra e centrato; guarda verso -Y (la camera "davanti" sta a -Y).
--bagliore N fa brillare le parti rosa/magenta (il tessuto della "madre") con forza N.
--bagnato F moltiplica la rugosità dei materiali nella luce di notte (meno = più lucido).
--ruota G gira il modello di G gradi prima di tutto (se Meshy lo esporta girato).
"""
import argparse, math, os, sys, time
import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument('glb'); ap.add_argument('out')
ap.add_argument('--altezza', type=float, default=1.2)
ap.add_argument('--campioni', type=int, default=48)
ap.add_argument('--luci', default='studio,notte')
ap.add_argument('--viste', default='davanti,tre_quarti,dietro')
ap.add_argument('--bagliore', type=float, default=0.0)
ap.add_argument('--bagnato', type=float, default=0.6)
ap.add_argument('--res', default='720x960')
ap.add_argument('--fili', type=int, default=3)
ap.add_argument('--ruota', type=float, default=0.0)
A = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])

VISTE = {'davanti': 0.0, 'tre_quarti': 35.0, 'dietro': 180.0, 'lato': 90.0}
RX, RY = (int(v) for v in A.res.split('x'))

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


# ---------------------------------------------------------------- utilità
def nodi(mat):
    mat.use_nodes = True
    return mat.node_tree.nodes, mat.node_tree.links


def mat_nuovo(nome):
    m = bpy.data.materials.new(nome)
    nt, ln = nodi(m)
    return m, nt, ln, nt['Principled BSDF']


def collega(ob):
    sc.collection.objects.link(ob)
    return ob


def punta(ob, bersaglio):
    ob.rotation_euler = (Vector(bersaglio) - ob.location).to_track_quat('-Z', 'Y').to_euler()


def luce(nome, tipo, pos, energia, colore, **kw):
    d = bpy.data.lights.new(nome, tipo)
    d.energy = energia
    d.color = colore
    for k, v in kw.items():
        setattr(d, k, v)
    ob = collega(bpy.data.objects.new(nome, d))
    ob.location = pos
    return ob


# ---------------------------------------------------------------- modello
bpy.ops.import_scene.gltf(filepath=A.glb)
importati = list(sc.objects)
mesh = [o for o in importati if o.type == 'MESH']
perno = collega(bpy.data.objects.new('perno', None))
for o in importati:
    if o.parent is None:
        o.parent = perno
perno.rotation_euler = (0, 0, math.radians(A.ruota))
bpy.context.view_layer.update()
pts = [o.matrix_world @ Vector(c) for o in mesh for c in o.bound_box]
lo = Vector([min(p[i] for p in pts) for i in range(3)])
hi = Vector([max(p[i] for p in pts) for i in range(3)])
s = A.altezza / (hi.z - lo.z)
centro = (lo + hi) / 2
# sposta i figli in modo che il perno stia ai piedi, al centro
for o in importati:
    if o.parent is perno:
        o.matrix_world.translation -= Vector((centro.x, centro.y, lo.z))
perno.scale = (s, s, s)
bpy.context.view_layer.update()
H = A.altezza
print('[bambini] oggetti', len(mesh), 'facce', sum(len(o.data.polygons) for o in mesh),
      'misure originali', tuple(round(v, 3) for v in (hi - lo)), 'scala', round(s, 4), flush=True)

materiali_modello = {m for o in mesh for m in o.data.materials if m}


def ritocca_materiali(bagnato, bagliore):
    """Rugosità moltiplicata per 'bagnato'; le parti rosa/magenta emettono luce se bagliore > 0."""
    for m in materiali_modello:
        nt, ln = m.node_tree.nodes, m.node_tree.links
        bsdf = next((n for n in nt if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            continue
        r_in = bsdf.inputs['Roughness']
        mul = nt.get('bambini_bagnato')
        if mul is None:
            mul = nt.new('ShaderNodeMath'); mul.name = 'bambini_bagnato'; mul.operation = 'MULTIPLY'
            if r_in.is_linked:
                src = r_in.links[0].from_socket
                ln.new(src, mul.inputs[0])
            else:
                mul.inputs[0].default_value = r_in.default_value
            ln.new(mul.outputs[0], r_in)
        mul.inputs[1].default_value = bagnato
        if bagliore > 0 and bsdf.inputs['Base Color'].is_linked and nt.get('bambini_hsv') is None:
            col = bsdf.inputs['Base Color'].links[0].from_socket
            hsv = nt.new('ShaderNodeSeparateColor'); hsv.name = 'bambini_hsv'; hsv.mode = 'HSV'
            ln.new(col, hsv.inputs['Color'])
            # tinta rosa/magenta: 0.80..1.0 (e 0..0.02, il rosso-rosa)
            t1 = nt.new('ShaderNodeMapRange'); t1.interpolation_type = 'SMOOTHSTEP'
            t1.inputs['From Min'].default_value = 0.76; t1.inputs['From Max'].default_value = 0.86
            ln.new(hsv.outputs[0], t1.inputs['Value'])
            sat = nt.new('ShaderNodeMapRange'); sat.interpolation_type = 'SMOOTHSTEP'
            sat.inputs['From Min'].default_value = 0.30; sat.inputs['From Max'].default_value = 0.60
            ln.new(hsv.outputs[1], sat.inputs['Value'])
            val = nt.new('ShaderNodeMapRange'); val.interpolation_type = 'SMOOTHSTEP'
            val.inputs['From Min'].default_value = 0.20; val.inputs['From Max'].default_value = 0.55
            ln.new(hsv.outputs[2], val.inputs['Value'])
            m1 = nt.new('ShaderNodeMath'); m1.operation = 'MULTIPLY'
            ln.new(t1.outputs[0], m1.inputs[0]); ln.new(sat.outputs[0], m1.inputs[1])
            m2 = nt.new('ShaderNodeMath'); m2.operation = 'MULTIPLY'; m2.name = 'bambini_forza'
            ln.new(m1.outputs[0], m2.inputs[0]); ln.new(val.outputs[0], m2.inputs[1])
            m3 = nt.new('ShaderNodeMath'); m3.operation = 'MULTIPLY'; m3.name = 'bambini_bagliore'
            ln.new(m2.outputs[0], m3.inputs[0])
            ln.new(col, bsdf.inputs['Emission Color'])
            ln.new(m3.outputs[0], bsdf.inputs['Emission Strength'])
        if nt.get('bambini_bagliore') is not None:
            nt['bambini_bagliore'].inputs[1].default_value = bagliore


# ---------------------------------------------------------------- set: studio
def set_studio():
    objs = []
    # fondale curvo (pavimento che sale in una parete), largo 10 m
    import bmesh
    me = bpy.data.meshes.new('fondale')
    bm = bmesh.new()
    prof = [(y, 0.0) for y in (-6.0, -2.0, 0.0, 1.5)]
    r = 1.5
    for i in range(1, 13):
        a = i / 12 * math.pi / 2
        prof.append((1.5 + r * math.sin(a), r - r * math.cos(a)))
    prof += [(3.0, 3.0), (3.0, 6.0)]
    righe = []
    for x in (-5.0, 5.0):
        righe.append([bm.verts.new((x, y, z)) for y, z in prof])
    for i in range(len(prof) - 1):
        bm.faces.new((righe[0][i], righe[0][i + 1], righe[1][i + 1], righe[1][i]))
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = collega(bpy.data.objects.new('fondale', me))
    m, nt, ln, b = mat_nuovo('M_fondale')
    b.inputs['Base Color'].default_value = (0.16, 0.165, 0.175, 1)
    b.inputs['Roughness'].default_value = 0.65
    ob.data.materials.append(m)
    objs.append(ob)
    objs.append(luce('chiave', 'AREA', (-1.6, -2.2, 2.3), 260, (1.0, 0.96, 0.9), size=1.4))
    objs.append(luce('riempimento', 'AREA', (2.2, -1.6, 1.1), 70, (0.85, 0.9, 1.0), size=1.6))
    objs.append(luce('controluce', 'AREA', (0.9, 1.8, 2.2), 220, (1.0, 0.85, 0.92), size=1.0))
    for o in objs[1:]:
        punta(o, (0, 0, 0.55 * H))
    return objs


# ---------------------------------------------------------------- set: acquapark di notte
def mat_piastrelle(nome, c1, c2, fuga, scala, rug, sporco=0.5, colature=False):
    m, nt, ln, b = mat_nuovo(nome)
    tc = nt.new('ShaderNodeTexCoord')
    br = nt.new('ShaderNodeTexBrick'); br.offset = 0.0; br.offset_frequency = 1
    br.squash = 1.0; br.squash_frequency = 1
    br.inputs['Scale'].default_value = scala
    br.inputs['Mortar Size'].default_value = 0.012
    br.inputs['Mortar Smooth'].default_value = 0.1
    br.inputs['Brick Width'].default_value = 0.5
    br.inputs['Row Height'].default_value = 0.5
    br.inputs['Bias'].default_value = 0.0
    br.inputs['Color1'].default_value = c1
    br.inputs['Color2'].default_value = c2
    br.inputs['Mortar'].default_value = fuga
    ln.new(tc.outputs['Object'], br.inputs['Vector'])
    # sporco: macchie scure e verdastre
    no = nt.new('ShaderNodeTexNoise'); no.inputs['Scale'].default_value = 1.6
    no.inputs['Detail'].default_value = 8.0; no.inputs['Roughness'].default_value = 0.6
    ln.new(tc.outputs['Object'], no.inputs['Vector'])
    mr = nt.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 0.45
    mr.inputs['From Max'].default_value = 0.75; mr.inputs['To Min'].default_value = 0.0
    mr.inputs['To Max'].default_value = sporco
    ln.new(no.outputs['Fac'], mr.inputs['Value'])
    mix = nt.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    ln.new(mr.outputs[0], mix.inputs['Factor'])
    ln.new(br.outputs['Color'], mix.inputs['A'])
    mix.inputs['B'].default_value = (0.22, 0.24, 0.17, 1)
    ultimo = mix.outputs['Result']
    if colature:
        # colature di ruggine verticali
        mp = nt.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (6.0, 6.0, 0.25)
        ln.new(tc.outputs['Object'], mp.inputs['Vector'])
        n2 = nt.new('ShaderNodeTexNoise'); n2.inputs['Scale'].default_value = 3.0
        n2.inputs['Detail'].default_value = 4.0
        ln.new(mp.outputs['Vector'], n2.inputs['Vector'])
        r2 = nt.new('ShaderNodeMapRange'); r2.inputs['From Min'].default_value = 0.62
        r2.inputs['From Max'].default_value = 0.8; r2.inputs['To Max'].default_value = 0.8
        ln.new(n2.outputs['Fac'], r2.inputs['Value'])
        mx2 = nt.new('ShaderNodeMix'); mx2.data_type = 'RGBA'
        ln.new(r2.outputs[0], mx2.inputs['Factor']); ln.new(ultimo, mx2.inputs['A'])
        mx2.inputs['B'].default_value = (0.33, 0.12, 0.04, 1)
        ultimo = mx2.outputs['Result']
    ln.new(ultimo, b.inputs['Base Color'])
    # rugosità: pozze lucide (bassa) e fughe opache
    n3 = nt.new('ShaderNodeTexNoise'); n3.inputs['Scale'].default_value = 0.9
    n3.inputs['Detail'].default_value = 3.0
    ln.new(tc.outputs['Object'], n3.inputs['Vector'])
    r3 = nt.new('ShaderNodeMapRange'); r3.inputs['From Min'].default_value = 0.42
    r3.inputs['From Max'].default_value = 0.6; r3.inputs['To Min'].default_value = 0.03
    r3.inputs['To Max'].default_value = rug
    ln.new(n3.outputs['Fac'], r3.inputs['Value'])
    mx = nt.new('ShaderNodeMath'); mx.operation = 'MAXIMUM'
    f2 = nt.new('ShaderNodeMath'); f2.operation = 'MULTIPLY'; f2.inputs[1].default_value = 0.6
    ln.new(br.outputs['Fac'], f2.inputs[0])
    ln.new(r3.outputs[0], mx.inputs[0]); ln.new(f2.outputs[0], mx.inputs[1])
    ln.new(mx.outputs[0], b.inputs['Roughness'])
    bu = nt.new('ShaderNodeBump'); bu.inputs['Strength'].default_value = 0.35
    bu.inputs['Distance'].default_value = 0.004
    inv = nt.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0
    ln.new(br.outputs['Fac'], inv.inputs[1]); ln.new(inv.outputs[0], bu.inputs['Height'])
    ln.new(bu.outputs['Normal'], b.inputs['Normal'])
    return m


def piano(nome, pos, dim, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=pos, rotation=rot)
    ob = bpy.context.active_object; ob.name = nome
    ob.scale = (dim[0], dim[1], 1)
    ob.data.materials.append(mat)
    return ob


def mat_semplice(nome, colore, rug=0.4, emissione=0.0, metallo=0.0):
    m, nt, ln, b = mat_nuovo(nome)
    b.inputs['Base Color'].default_value = colore
    b.inputs['Roughness'].default_value = rug
    b.inputs['Metallic'].default_value = metallo
    if emissione:
        b.inputs['Emission Color'].default_value = colore
        b.inputs['Emission Strength'].default_value = emissione
    return m


def mat_spicchi(nome, colori, n, rug=0.35):
    """Colori a spicchi intorno all'asse Z dell'oggetto (salvagente, pallone)."""
    m, nt, ln, b = mat_nuovo(nome)
    tc = nt.new('ShaderNodeTexCoord')
    sp = nt.new('ShaderNodeSeparateXYZ'); ln.new(tc.outputs['Object'], sp.inputs['Vector'])
    at = nt.new('ShaderNodeMath'); at.operation = 'ARCTAN2'
    ln.new(sp.outputs['Y'], at.inputs[0]); ln.new(sp.outputs['X'], at.inputs[1])
    no = nt.new('ShaderNodeMath'); no.operation = 'MULTIPLY_ADD'
    no.inputs[1].default_value = 1 / (2 * math.pi); no.inputs[2].default_value = 0.5
    ln.new(at.outputs[0], no.inputs[0])
    cr = nt.new('ShaderNodeValToRGB'); cr.color_ramp.interpolation = 'CONSTANT'
    el = cr.color_ramp.elements
    el[0].position = 0.0; el[0].color = colori[0]
    el[1].position = 1 / n; el[1].color = colori[1 % len(colori)]
    for i in range(2, n):
        e = el.new(i / n); e.color = colori[i % len(colori)]
    ln.new(no.outputs[0], cr.inputs['Fac'])
    # un velo di sporco
    nz = nt.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 9.0
    ln.new(tc.outputs['Object'], nz.inputs['Vector'])
    mr = nt.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = 0.5
    mr.inputs['From Max'].default_value = 0.8; mr.inputs['To Max'].default_value = 0.55
    ln.new(nz.outputs['Fac'], mr.inputs['Value'])
    mx = nt.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'
    ln.new(mr.outputs[0], mx.inputs['Factor']); ln.new(cr.outputs['Color'], mx.inputs['A'])
    mx.inputs['B'].default_value = (0.3, 0.28, 0.2, 1)
    ln.new(mx.outputs['Result'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = rug
    return m


def set_notte():
    objs = []
    pav = mat_piastrelle('M_pavimento', (0.42, 0.47, 0.5, 1), (0.36, 0.42, 0.47, 1),
                         (0.12, 0.13, 0.12, 1), 4.0, 0.45, sporco=0.65)
    objs.append(piano('pavimento', (0, 0.5, 0), (12, 10), pav))
    parete_m = mat_piastrelle('M_parete', (0.55, 0.62, 0.66, 1), (0.48, 0.56, 0.62, 1),
                              (0.18, 0.19, 0.18, 1), 5.0, 0.35, sporco=0.55, colature=True)
    objs.append(piano('parete', (0, 2.4, 2.0), (12, 4.0), parete_m, rot=(math.pi / 2, 0, 0)))
    fascia = mat_piastrelle('M_fascia', (0.05, 0.18, 0.42, 1), (0.04, 0.15, 0.36, 1),
                            (0.15, 0.16, 0.16, 1), 5.0, 0.3, sporco=0.4)
    objs.append(piano('fascia', (0, 2.39, 0.55), (12, 0.3), fascia, rot=(math.pi / 2, 0, 0)))
    # oblò con il mare in tempesta (vetro che emette un blu freddo)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.05,
                                     location=(-1.15, 2.36, 1.75), rotation=(math.pi / 2, 0, 0))
    anello = bpy.context.active_object
    anello.data.materials.append(mat_semplice('M_ottone', (0.35, 0.22, 0.08, 1), 0.45, metallo=0.9))
    objs.append(anello)
    bpy.ops.mesh.primitive_circle_add(radius=0.34, fill_type='NGON', location=(-1.15, 2.385, 1.75),
                                      rotation=(math.pi / 2, 0, 0))
    vetro = bpy.context.active_object
    vm, nt, ln, b = mat_nuovo('M_mare')
    tc = nt.new('ShaderNodeTexCoord')
    nz = nt.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 6.0
    nz.inputs['Detail'].default_value = 6.0
    ln.new(tc.outputs['Object'], nz.inputs['Vector'])
    cr = nt.new('ShaderNodeValToRGB')
    cr.color_ramp.elements[0].color = (0.005, 0.012, 0.03, 1)
    cr.color_ramp.elements[1].color = (0.12, 0.2, 0.32, 1)
    ln.new(nz.outputs['Fac'], cr.inputs['Fac'])
    b.inputs['Base Color'].default_value = (0, 0, 0, 1)
    ln.new(cr.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 1.6
    b.inputs['Roughness'].default_value = 0.05
    vetro.data.materials.append(vm)
    objs.append(vetro)
    # luce d'emergenza rossa sulla parete (scatoletta che emette + luce)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(1.35, 2.33, 2.35))
    lamp = bpy.context.active_object; lamp.scale = (0.22, 0.1, 0.12)
    lamp.data.materials.append(mat_semplice('M_emergenza', (1.0, 0.04, 0.02, 1), 0.3, emissione=40))
    objs.append(lamp)
    objs.append(luce('emerg_parete', 'POINT', (1.35, 2.12, 2.28), 90, (1.0, 0.04, 0.02),
                     shadow_soft_size=0.05))
    objs.append(luce('emerg_lato', 'POINT', (-2.6, -0.3, 2.1), 75, (1.0, 0.05, 0.03),
                     shadow_soft_size=0.05))
    objs.append(luce('emerg_dietro', 'POINT', (1.9, 1.3, 1.2), 25, (1.0, 0.06, 0.03),
                     shadow_soft_size=0.05))
    # neon freddo e stanco, in alto a destra davanti
    neon = luce('neon', 'AREA', (1.4, -1.3, 2.9), 55, (0.78, 1.0, 0.93), shape='RECTANGLE',
                size=1.2, size_y=0.08)
    punta(neon, (0.3, 0.2, 0.0)); objs.append(neon)
    # giocattoli colorati
    bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.09, location=(-0.95, -0.55, 0.09))
    sal = bpy.context.active_object; sal.rotation_euler = (math.radians(4), 0, 0.4)
    sal.data.materials.append(mat_spicchi('M_salvagente', [(0.8, 0.06, 0.04, 1), (0.85, 0.82, 0.75, 1)], 8))
    objs.append(sal)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.19, location=(1.05, 0.9, 0.19), segments=48, ring_count=24)
    pal = bpy.context.active_object; pal.rotation_euler = (0.5, 0.3, 0.2)
    bpy.ops.object.shade_smooth()
    pal.data.materials.append(mat_spicchi('M_pallone', [(0.8, 0.05, 0.04, 1), (0.9, 0.88, 0.8, 1),
                                                       (0.05, 0.2, 0.75, 1), (0.95, 0.75, 0.05, 1),
                                                       (0.9, 0.88, 0.8, 1), (0.1, 0.55, 0.2, 1)], 6))
    objs.append(pal)
    giallo = mat_semplice('M_paperella', (0.9, 0.62, 0.03, 1), 0.35)
    for nome, pos, sca in (('pap_corpo', (0.8, -0.75, 0.07), (0.11, 0.08, 0.07)),
                           ('pap_testa', (0.86, -0.78, 0.17), (0.055, 0.055, 0.055))):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, location=pos)
        o = bpy.context.active_object; o.scale = sca; bpy.ops.object.shade_smooth()
        o.data.materials.append(giallo); objs.append(o)
    bpy.ops.mesh.primitive_cone_add(radius1=0.025, depth=0.05, location=(0.89, -0.83, 0.165),
                                    rotation=(math.radians(90), 0, math.radians(-20)))
    becco = bpy.context.active_object
    becco.data.materials.append(mat_semplice('M_becco', (0.85, 0.2, 0.02, 1), 0.4)); objs.append(becco)
    # nebbia bassa: densa vicino al pavimento, velo leggero sopra
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.2, 1.6))
    neb = bpy.context.active_object; neb.name = 'nebbia'; neb.scale = (9, 8, 3.2)
    nm = bpy.data.materials.new('M_nebbia'); nt, ln = nodi(nm)
    for n in list(nt):
        nt.remove(n)
    out = nt.new('ShaderNodeOutputMaterial'); vol = nt.new('ShaderNodeVolumePrincipled')
    vol.inputs['Color'].default_value = (0.7, 0.74, 0.78, 1)
    vol.inputs['Anisotropy'].default_value = 0.4
    geo = nt.new('ShaderNodeNewGeometry'); sp = nt.new('ShaderNodeSeparateXYZ')
    ln.new(geo.outputs['Position'], sp.inputs['Vector'])
    mr = nt.new('ShaderNodeMapRange'); mr.interpolation_type = 'SMOOTHSTEP'
    mr.inputs['From Min'].default_value = 0.0; mr.inputs['From Max'].default_value = 0.9
    mr.inputs['To Min'].default_value = 1.0; mr.inputs['To Max'].default_value = 0.12
    ln.new(sp.outputs['Z'], mr.inputs['Value'])
    nz = nt.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 0.8
    ln.new(geo.outputs['Position'], nz.inputs['Vector'])
    mn = nt.new('ShaderNodeMapRange'); mn.inputs['From Min'].default_value = 0.3
    mn.inputs['From Max'].default_value = 0.7; mn.inputs['To Min'].default_value = 0.3
    mn.inputs['To Max'].default_value = 1.3
    ln.new(nz.outputs['Fac'], mn.inputs['Value'])
    m1 = nt.new('ShaderNodeMath'); m1.operation = 'MULTIPLY'
    ln.new(mr.outputs[0], m1.inputs[0]); ln.new(mn.outputs[0], m1.inputs[1])
    m2 = nt.new('ShaderNodeMath'); m2.operation = 'MULTIPLY'; m2.inputs[1].default_value = 0.16
    ln.new(m1.outputs[0], m2.inputs[0]); ln.new(m2.outputs[0], vol.inputs['Density'])
    ln.new(vol.outputs['Volume'], out.inputs['Volume'])
    neb.data.materials.append(nm); neb.visible_shadow = False
    objs.append(neb)
    return objs


# ---------------------------------------------------------------- render
def impostazioni():
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = A.campioni
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.03
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 6
    sc.cycles.diffuse_bounces = 3
    sc.cycles.glossy_bounces = 3
    sc.cycles.transmission_bounces = 4
    sc.cycles.volume_bounces = 0
    sc.cycles.caustics_reflective = False
    sc.cycles.caustics_refractive = False
    sc.cycles.sample_clamp_indirect = 4.0
    sc.cycles.volume_step_rate = 4.0
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = A.fili
    sc.render.resolution_x, sc.render.resolution_y = RX, RY
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'


def mondo(colore, forza):
    w = bpy.data.worlds.get('W') or bpy.data.worlds.new('W')
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:  # noqa: BLE001
        pass
    bg = w.node_tree.nodes.get('Background')
    bg.inputs['Color'].default_value = colore
    bg.inputs['Strength'].default_value = forza


def camera(dist, alt, bersaglio_z, lente, dof=None):
    cd = bpy.data.cameras.get('cam') or bpy.data.cameras.new('cam')
    cd.lens = lente; cd.sensor_width = 36; cd.sensor_fit = 'AUTO'
    cam = bpy.data.objects.get('cam') or collega(bpy.data.objects.new('cam', cd))
    cam.location = (0, -dist, alt)
    punta(cam, (0, 0, bersaglio_z))
    sc.camera = cam
    cd.dof.use_dof = dof is not None
    if dof:
        cd.dof.focus_distance = math.hypot(dist, alt - bersaglio_z)
        cd.dof.aperture_fstop = dof
    return cam


impostazioni()
for nome_luce in A.luci.split(','):
    extra = set_studio() if nome_luce == 'studio' else set_notte()
    if nome_luce == 'studio':
        mondo((0.02, 0.021, 0.024, 1), 1.0)
        sc.view_settings.exposure = 0.0
        ritocca_materiali(1.0, A.bagliore)
        lente = 60.0
        vfov = 2 * math.atan(18 / lente) if RY >= RX else 2 * math.atan(18 * RY / RX / lente)
        dist = (H * 1.18 / 2) / math.tan(vfov / 2)
        camera(dist, 0.62 * H, 0.5 * H, lente)
    else:
        mondo((0.002, 0.003, 0.006, 1), 1.0)
        sc.view_settings.exposure = 0.3
        ritocca_materiali(A.bagnato, A.bagliore * 1.5)
        lente = 40.0
        vfov = 2 * math.atan(18 / lente) if RY >= RX else 2 * math.atan(18 * RY / RX / lente)
        dist = (H * 1.45 / 2) / math.tan(vfov / 2)
        camera(dist, 0.55 * H, 0.52 * H, lente, dof=4.0)
    for vista in A.viste.split(','):
        perno.rotation_euler = (0, 0, math.radians(A.ruota + VISTE[vista]))
        sc.render.filepath = f'{A.out}_{nome_luce}_{vista}.png'
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        print(f'[bambini] {nome_luce} {vista} {time.time() - t0:.0f}s', flush=True)
    for o in extra:
        bpy.data.objects.remove(o, do_unlink=True)
