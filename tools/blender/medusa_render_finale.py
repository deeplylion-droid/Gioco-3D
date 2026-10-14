"""Render della medusa FINITA in luce "acquapark di notte" (emergenza rossa, riflesso azzurro, nebbia).

Inquadrature (1600x900 o piu'):
  statua_intera  - ferma come una statua, mani giunte, su un piedistallo semplice come nel concept
  viso           - primo piano del viso (occhio di vetro, fauce chiusa: non si vede)
  fauce_chiusa / fauce_aperta - stessa inquadratura, prima e dopo: lo strappo sotto l'occhio
  fluttua        - sospesa sopra il pavimento bagnato, tentacoli mossi (azione "fluttua")
Scrive i PNG in build/render/ e i JPG da mostrare in docs/proposte/medusa/finale/.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_render_finale.py [nomi...] [--prova]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401

PROVA = '--prova' in sys.argv
RES = (480, 270) if PROVA else (1600, 900)
CAMPIONI = 12 if PROVA else 40
OUT_PNG = os.path.join(BUILD, 'render')
OUT_JPG = os.path.join(PROPOSTE, 'finale')
os.makedirs(OUT_PNG, exist_ok=True)
os.makedirs(OUT_JPG, exist_ok=True)


# ---------------------------------------------------------------- scena

def prepara():
    apri(os.path.join(BUILD, 'medusa_finale.blend'))
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o)
    arm = bpy.data.objects['Medusa_Scheletro']
    arm.hide_render = True
    for o in bpy.data.objects:
        if o.type == 'EMPTY':
            o.hide_render = True
    # la cornea di vetro non deve fare ombra all'iride (trucco classico degli occhi in Cycles)
    cornea = bpy.data.objects.get('Medusa_Cornea')
    if cornea:
        cornea.visible_shadow = False
    return arm


def usa_azione(nome, frame):
    """Attiva solo le tracce NLA con questo nome (scheletro e shape key) e va al fotogramma."""
    ids = [o for o in bpy.data.objects] + [k for k in bpy.data.shape_keys]
    for i in ids:
        ad = i.animation_data
        if not ad:
            continue
        for tr in ad.nla_tracks:
            tr.mute = tr.name != nome
    bpy.context.scene.frame_set(frame)


def mat_semplice(nome, colore, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(nome); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*colore, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    return m, m.node_tree, b


def piedistallo(z_cima, raggio=0.95, altezza=0.6):
    """Piedistallo cilindrico dipinto di blu con una fascia ondulata gialla e rosa, scrostato."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=raggio, depth=altezza,
                                        location=(0, 0, z_cima - altezza / 2))
    p = bpy.context.active_object; p.name = 'piedistallo'
    bpy.ops.object.shade_smooth()
    bev = p.modifiers.new('smusso', 'BEVEL'); bev.width = 0.02; bev.segments = 3
    m, nt, b = mat_semplice('piedistallo', (0.03, 0.08, 0.2), 0.45)
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Object'], sep.inputs['Vector'])
    # fascia ondulata: z + sin(angolo)
    ang = nt.nodes.new('ShaderNodeMath'); ang.operation = 'ARCTAN2'
    nt.links.new(sep.outputs['Y'], ang.inputs[0]); nt.links.new(sep.outputs['X'], ang.inputs[1])
    sn = nt.nodes.new('ShaderNodeMath'); sn.operation = 'SINE'
    mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = 6.0
    nt.links.new(ang.outputs[0], mul.inputs[0]); nt.links.new(mul.outputs[0], sn.inputs[0])
    onda = nt.nodes.new('ShaderNodeMath'); onda.operation = 'MULTIPLY_ADD'
    onda.inputs[1].default_value = 0.035
    nt.links.new(sn.outputs[0], onda.inputs[0]); nt.links.new(sep.outputs['Z'], onda.inputs[2])
    fascia = nt.nodes.new('ShaderNodeMapRange')
    fascia.inputs['From Min'].default_value = -0.09; fascia.inputs['From Max'].default_value = 0.05
    nt.links.new(onda.outputs[0], fascia.inputs['Value'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    el = ramp.color_ramp.elements
    el[0].position = 0.0; el[0].color = (0.03, 0.08, 0.2, 1)
    el[1].position = 1.0; el[1].color = (0.03, 0.08, 0.2, 1)
    for pos, col in ((0.30, (0.03, 0.08, 0.2, 1)), (0.33, (0.85, 0.62, 0.12, 1)), (0.48, (0.85, 0.62, 0.12, 1)),
                     (0.51, (0.85, 0.3, 0.45, 1)), (0.66, (0.85, 0.3, 0.45, 1)), (0.69, (0.03, 0.08, 0.2, 1))):
        e = el.new(pos); e.color = col
    ramp.color_ramp.interpolation = 'CONSTANT'
    nt.links.new(fascia.outputs['Result'], ramp.inputs['Fac'])
    # scrostature: rumore che scopre il cemento grigio
    noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 9; noise.inputs['Detail'].default_value = 8
    cr = nt.nodes.new('ShaderNodeMapRange')
    cr.inputs['From Min'].default_value = 0.68; cr.inputs['From Max'].default_value = 0.71
    nt.links.new(noise.outputs['Fac'], cr.inputs['Value'])
    mixc = nt.nodes.new('ShaderNodeMix'); mixc.data_type = 'RGBA'
    mixc.inputs['B'].default_value = (0.32, 0.3, 0.28, 1)
    nt.links.new(cr.outputs['Result'], mixc.inputs['Factor'])
    nt.links.new(ramp.outputs['Color'], mixc.inputs['A'])
    nt.links.new(mixc.outputs['Result'], b.inputs['Base Color'])
    p.data.materials.append(m)
    return p


def pavimento_piastrelle(z):
    """Pavimento di piastrelle bagnate, scure."""
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, z))
    pav = bpy.context.active_object; pav.name = 'pavimento_bagnato'
    m, nt, b = mat_semplice('piastrelle_bagnate', (0.02, 0.04, 0.07), 0.05)
    br = nt.nodes.new('ShaderNodeTexBrick')
    br.inputs['Scale'].default_value = 140.0          # piastrelle da piscina, circa 25 cm
    br.inputs['Mortar Size'].default_value = 0.008
    br.inputs['Color1'].default_value = (0.03, 0.06, 0.11, 1)
    br.inputs['Color2'].default_value = (0.05, 0.08, 0.12, 1)
    br.inputs['Mortar'].default_value = (0.01, 0.012, 0.015, 1)
    br.offset = 0.0
    nt.links.new(br.outputs['Color'], b.inputs['Base Color'])
    # pozzanghere: zone piu' lisce
    noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 1.2
    rr = nt.nodes.new('ShaderNodeMapRange')
    rr.inputs['From Min'].default_value = 0.45; rr.inputs['From Max'].default_value = 0.6
    rr.inputs['To Min'].default_value = 0.22; rr.inputs['To Max'].default_value = 0.02
    nt.links.new(noise.outputs['Fac'], rr.inputs['Value'])
    nt.links.new(rr.outputs['Result'], b.inputs['Roughness'])
    pav.data.materials.append(m)
    return pav


def luci_notte(centro, H, nebbia=0.006):
    c = Vector(centro)
    luce_spot('rossa_emergenza', c + Vector((1.3, 1.2, 1.7)) * H, c + Vector((0, 0, 0.1 * H)), 2000 * H * H,
              (1.0, 0.05, 0.02), angolo=55, raggio=0.15, blend=0.5)
    luce_spot('rossa_2', c + Vector((-1.8, 0.6, 1.2)) * H, c, 900 * H * H, (1.0, 0.07, 0.03), angolo=45, raggio=0.1)
    luce_area('azzurra_piscina', c + Vector((0.2, -1.5, -0.7)) * H, c + Vector((0, 0, 0.25 * H)), 70 * H * H,
              (0.08, 0.45, 1.0), 1.5 * H, 'DISK')
    luce_area('azzurra_controluce', c + Vector((-0.9, 1.5, 1.0)) * H, c, 40 * H * H, (0.3, 0.65, 1.0), 0.7 * H, 'DISK')
    luce_area('riempimento_freddo', c + Vector((-1.2, -1.6, 0.6)) * H, c, 10 * H * H, (0.55, 0.65, 1.0), 1.2 * H, 'DISK')
    mondo((0.003, 0.005, 0.01), 1.0)
    m = bpy.data.materials.new('lampada_emergenza'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = (1.0, 0.04, 0.02, 1); e.inputs['Strength'].default_value = 80
    nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    for x, y, z in ((-3.0, 6.5, 2.2), (2.4, 7.5, 2.8), (5.0, 5.0, 1.8), (-5.5, 4.0, 3.2), (0.2, 9.0, 3.5)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08, location=(c.x + x, c.y + y, c.z + z))
        lamp = bpy.context.active_object; lamp.name = 'lampada_fondo'
        lamp.data.materials.append(m)
        lamp.visible_shadow = False
    bpy.ops.mesh.primitive_cube_add(size=1, location=(c.x, c.y + 2, c.z))
    vol = bpy.context.active_object; vol.name = 'nebbia'
    vol.scale = (16, 16, 9)
    m = bpy.data.materials.new('nebbia'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); v = nt.nodes.new('ShaderNodeVolumePrincipled')
    v.inputs['Density'].default_value = nebbia
    v.inputs['Color'].default_value = (0.75, 0.8, 0.9, 1)
    nt.links.new(v.outputs['Volume'], o.inputs['Volume'])
    vol.data.materials.append(m)
    vol.visible_shadow = False
    sc = bpy.context.scene
    sc.cycles.volume_step_rate = 3.0
    sc.cycles.volume_max_steps = 256


def imposta(res=RES, campioni=CAMPIONI, esposizione=0.0):
    sc = imposta_render(samples=campioni, res=res, esposizione=esposizione, bounces=8)
    sc.cycles.transmission_bounces = 8
    sc.cycles.glossy_bounces = 4
    sc.cycles.diffuse_bounces = 2
    sc.cycles.volume_bounces = 0
    sc.cycles.adaptive_threshold = 0.03
    sc.cycles.sample_clamp_indirect = 8.0
    sc.cycles.caustics_reflective = False
    sc.cycles.caustics_refractive = False
    sc.view_settings.look = 'AgX - Medium High Contrast'
    return sc


def salva_jpg(png, nome):
    from PIL import Image
    p = os.path.join(OUT_JPG, nome + '.jpg')
    Image.open(png).convert('RGB').save(p, quality=92)
    log('immagine', os.path.relpath(p, REPO))
    return p


def tentacoli_punto_piu_basso():
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    zmin = 0
    for nome in ('Medusa_Tentacoli', 'Medusa_Filamenti'):
        ob = bpy.data.objects.get(nome)
        if not ob:
            continue
        me = ob.evaluated_get(dg).to_mesh()
        co = coords(me)
        zmin = min(zmin, co[:, 2].min())
        ob.evaluated_get(dg).to_mesh_clear()
    return zmin


# ---------------------------------------------------------------- inquadrature

def statua_intera():
    prepara()
    usa_azione('statua', 1)
    z = tentacoli_punto_piu_basso()
    piedistallo(z + 0.02)
    pavimento_piastrelle(z + 0.02 - 0.6)
    luci_notte((0, 0, -0.5), 2.4)
    imposta()
    camera((2.5, -6.0, -0.45), (0.0, 0, -0.92), lens=28)
    png = render(os.path.join(OUT_PNG, 'statua_intera.png'))
    return salva_jpg(png, '1_statua_intera')


def viso():
    prepara()
    usa_azione('statua', 1)
    z = tentacoli_punto_piu_basso()
    piedistallo(z + 0.02)
    luci_notte((0, 0, 0.4), 1.0)
    imposta()
    camera((0.35, -1.55, 0.62), (0.0, -0.1, 0.5), lens=55)
    png = render(os.path.join(OUT_PNG, 'viso.png'))
    return salva_jpg(png, '2_viso')


def fauce(aperta):
    prepara()
    usa_azione('fauce_apre', 12 if aperta else 1)
    luci_notte((0, -0.3, 0.3), 1.2)
    pavimento_piastrelle(-2.7)
    imposta()
    camera((0.32, -1.5, 0.52), (0.0, -0.12, 0.47), lens=50)
    nome = 'fauce_aperta' if aperta else 'fauce_chiusa'
    png = render(os.path.join(OUT_PNG, nome + '.png'))
    return salva_jpg(png, ('4_' if aperta else '3_') + nome)


def fluttua():
    prepara()
    usa_azione('fluttua', 9)
    pavimento_piastrelle(-2.75)
    luci_notte((0, 0, -0.5), 2.4)
    imposta()
    camera((2.5, -4.3, -0.45), (0.0, -0.15, -0.6), lens=30)
    png = render(os.path.join(OUT_PNG, 'fluttua.png'))
    return salva_jpg(png, '5_fluttua')


INQUADRATURE = {
    'statua_intera': statua_intera,
    'viso': viso,
    'fauce_chiusa': lambda: fauce(False),
    'fauce_aperta': lambda: fauce(True),
    'fluttua': fluttua,
}


if __name__ == '__main__':
    nomi = [a for a in sys.argv[1:] if not a.startswith('--')] or list(INQUADRATURE)
    for n in nomi:
        t0 = time.time()
        INQUADRATURE[n]()
        log(f'{n}: {time.time() - t0:.0f} s')
