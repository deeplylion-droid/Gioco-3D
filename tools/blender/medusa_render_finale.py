"""Render della medusa FINITA in luce "acquapark di notte" (emergenza rossa, riflesso azzurro, nebbia).

Inquadrature (1600x900 o piu'):
  statua_intera  - ferma come una statua, mani giunte, in piedi sui tentacoli su un piedistallo semplice
  tentacoli      - primo piano dei tentacoli appoggiati sul piedistallo
  viso_capelli   - primo piano di viso e capelli (di tre quarti)
  viso           - primo piano del viso (occhio di vetro, fauce chiusa: non si vede)
  fauce_chiusa / fauce_aperta - stessa inquadratura, prima e dopo: lo strappo sotto l'occhio
  fluttua        - sveglia, staccata dal piedistallo, tentacoli che pendono (azione "fluttua")
  giocatore_lontano / giocatore_piedi - la statua alta 4,5 m vista dal giocatore (occhi a 1,7 m dal
                   pavimento), a 9 m e poi ai suoi piedi guardando in su, con luce da monumento
                   (un faro dall'alto, luci dal basso, nebbia)
Le inquadrature sono scritte nelle coordinate del modello (prima della scala vera): M() le porta nella scena,
cosi' la stessa inquadratura vale per la statua vecchia (build/medusa_finale_prima.blend, opzione --prima) e
per quella a grandezza vera (scala in Medusa_Scheletro['scala'], piano dei tentacoli a z = 0).
Scrive i PNG in build/render/ e i JPG in docs/proposte/medusa/finale/ (nomi dati con --nome X).

Uso: flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python \
     tools/blender/medusa_render_finale.py [nomi...] [--prova|--media] [--prima] [--nome X]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_05_tentacoli as TENT  # noqa: E402
import medusa_07_finale as FIN  # noqa: E402

PROVA = '--prova' in sys.argv
MEDIA = '--media' in sys.argv
RES = (480, 270) if PROVA else (960, 540) if MEDIA else (1600, 900)
CAMPIONI = 12 if PROVA else 24 if MEDIA else 40
ZP = TENT.STATUA['z_pavimento']          # piano del piedistallo (dove poggiano i tentacoli), unita' del modello
PRIMA = '--prima' in sys.argv            # rende la versione di prima (per i confronti prima/dopo)
K = 1.0                                  # scala della scena rispetto al modello (dalla blend)
DZ = 0.0                                 # spostamento verticale (piano dei tentacoli a z = 0 nella statua vera)
OUT_PNG = os.path.join(BUILD, 'render')
OUT_JPG = os.path.join(PROPOSTE, 'finale')
os.makedirs(OUT_PNG, exist_ok=True)
os.makedirs(OUT_JPG, exist_ok=True)


# ---------------------------------------------------------------- scena

def M(x, y=None, z=None):
    """Coordinate del modello -> scena (statua vera: x K, piano dei tentacoli a z = 0)."""
    if y is None:
        x, y, z = x
    return Vector((x * K, y * K, z * K + DZ))


def prepara():
    global K, DZ
    apri(os.path.join(BUILD, 'medusa_finale_prima.blend') if PRIMA else
         os.environ.get('MEDUSA_FINALE', os.path.join(BUILD, 'medusa_finale.blend')))
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o)
    arm = bpy.data.objects['Medusa_Scheletro']
    arm.hide_render = True
    K = float(arm.get('scala', 1.0))
    DZ = arm.location.z
    for o in bpy.data.objects:
        if o.type == 'EMPTY':
            o.hide_render = True
    # la cornea di vetro non deve fare ombra all'iride (trucco classico degli occhi in Cycles)
    cornea = bpy.data.objects.get('Medusa_Cornea')
    if cornea:
        cornea.visible_shadow = False
    return arm


def usa_azione(nome, frame):
    """Attiva solo le tracce NLA con questo nome (scheletro e shape key) e va al fotogramma. Le shape key si
    rimettono a 0 prima: una traccia muta lascia nel valore l'ultimo numero che ha scritto."""
    ids = [o for o in bpy.data.objects] + [k for k in bpy.data.shape_keys]
    for i in ids:
        ad = i.animation_data
        if not ad:
            continue
        for tr in ad.nla_tracks:
            tr.mute = tr.name != nome
    for k in bpy.data.shape_keys:
        for kb in k.key_blocks[1:]:
            kb.value = 0.0
    bpy.context.scene.frame_set(frame)


def mat_semplice(nome, colore, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(nome); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*colore, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    return m, m.node_tree, b


def piedistallo(z_cima, raggio=1.05, altezza=0.6):
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

def nome_jpg(base):
    """Nome del JPG: --nome X lo sostituisce; --prima aggiunge _prima."""
    if '--nome' in sys.argv:
        base = sys.argv[sys.argv.index('--nome') + 1]
    return base + ('_prima' if PRIMA and '--nome' not in sys.argv else '')


def scena_notte(centro, H, pedistallo=True, pavimento=True):
    """Piedistallo, pavimento e luci notte, tutto nella scala della scena."""
    if pedistallo:
        piedistallo(M(0, 0, ZP).z, raggio=1.05 * K, altezza=0.6 * K)
    if pavimento:
        pavimento_piastrelle(M(0, 0, ZP - 0.6).z)
    c = M(centro)
    luci_notte(tuple(c), H * K, nebbia=0.006 / K)


def statua_intera():
    prepara()
    usa_azione('statua', 1)
    scena_notte((0, 0, -0.5), 2.4)
    imposta()
    camera(M(2.0, -4.75, -0.55), M(0.0, 0, -0.72), lens=28)
    png = render(os.path.join(OUT_PNG, nome_jpg('statua_intera') + '.png'))
    return salva_jpg(png, nome_jpg('1_statua_intera'))


def tentacoli():
    """Primo piano dei tentacoli appoggiati sul piedistallo (zampe davanti, piedi e riccioli)."""
    prepara()
    usa_azione('statua', 1)
    scena_notte((0, -0.3, ZP + 0.4), 1.4)
    imposta()
    camera(M(0.75, -2.05, ZP + 0.5), M(0.05, -0.3, ZP + 0.22), lens=38)
    png = render(os.path.join(OUT_PNG, nome_jpg('tentacoli') + '.png'))
    return salva_jpg(png, nome_jpg('1b_tentacoli_piedistallo'))


def viso_capelli():
    """Viso e capelli di tre quarti (per il prima/dopo dei capelli)."""
    prepara()
    usa_azione('statua', 1)
    scena_notte((0, 0, 0.5), 1.0, pavimento=False)
    imposta()
    camera(M(0.62, -1.3, 0.8), M(0.02, -0.02, 0.64), lens=50)
    png = render(os.path.join(OUT_PNG, nome_jpg('viso_capelli') + '.png'))
    return salva_jpg(png, nome_jpg('3_viso_capelli'))


def viso():
    prepara()
    usa_azione('statua', 1)
    scena_notte((0, 0, 0.4), 1.0, pavimento=False)
    imposta()
    camera(M(0.35, -1.55, 0.62), M(0.0, -0.1, 0.5), lens=55)
    png = render(os.path.join(OUT_PNG, nome_jpg('viso') + '.png'))
    return salva_jpg(png, nome_jpg('2_viso'))


def fauce(aperta):
    prepara()
    usa_azione('fauce_apre', 12 if aperta else 1)
    h = FIN.SOLLEVA                      # da sveglia il corpo e' sollevato (unita' del modello)
    scena_notte((0, -0.3, 0.3 + h), 1.2, pedistallo=False)
    imposta()
    camera(M(0.32, -1.5, 0.52 + h), M(0.0, -0.12, 0.47 + h), lens=50)
    nome = 'fauce_aperta' if aperta else 'fauce_chiusa'
    png = render(os.path.join(OUT_PNG, nome_jpg(nome) + '.png'))
    return salva_jpg(png, nome_jpg(('4_' if aperta else '3_') + nome))


def fluttua():
    prepara()
    usa_azione('fluttua', 9)
    h = FIN.SOLLEVA
    scena_notte((0, 0, -0.5 + h), 2.4)
    imposta()
    camera(M(2.4, -5.2, -0.45 + h * 0.5), M(0.0, -0.1, -0.6 + h * 0.6), lens=28)
    png = render(os.path.join(OUT_PNG, nome_jpg('fluttua') + '.png'))
    return salva_jpg(png, nome_jpg('5_fluttua'))


# ---------------------------------------------------------------- dal punto di vista del giocatore

def luci_monumento(h_ped):
    """Luce da monumento nella hall buia: un faro dall'alto, luci colorate dal basso intorno al piedistallo,
    lampade d'emergenza rosse sul fondo e nebbia (si vedono i fasci)."""
    luce_spot('faro', (2.0, -3.2, 10.5), (0, 0, 2.6), 9000, (0.92, 0.95, 1.0), angolo=26, raggio=0.25, blend=0.35)
    r = 2.6
    for i, (az, col, z_t) in enumerate(((-115, (0.15, 0.65, 1.0), 2.8), (-65, (1.0, 0.25, 0.62), 3.2),
                                        (40, (0.15, 0.65, 1.0), 2.4), (140, (1.0, 0.08, 0.05), 2.6))):
        a = math.radians(az)
        luce_spot(f'dal_basso_{i}', (r * math.cos(a), r * math.sin(a), -h_ped + 0.15), (0, 0, z_t), 1400, col,
                  angolo=34, raggio=0.08, blend=0.5)
    luce_area('riempimento_freddo', (-4.0, -6.0, 2.0), (0, 0, 2.0), 300, (0.45, 0.55, 1.0), 4.0, 'DISK')
    mondo((0.002, 0.003, 0.006), 1.0)
    m = bpy.data.materials.new('lampada_emergenza'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = (1.0, 0.04, 0.02, 1); e.inputs['Strength'].default_value = 80
    nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    for x, y, z in ((-7.0, 12.0, 4.0), (5.5, 14.0, 5.0), (11.0, 8.0, 3.5), (-12.0, 6.0, 5.5), (0.5, 18.0, 6.0)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(x, y, z))
        lamp = bpy.context.active_object; lamp.name = 'lampada_fondo'
        lamp.data.materials.append(m)
        lamp.visible_shadow = False
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 4, 4))
    vol = bpy.context.active_object; vol.name = 'nebbia'
    vol.scale = (40, 40, 14)
    m = bpy.data.materials.new('nebbia'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); v = nt.nodes.new('ShaderNodeVolumePrincipled')
    v.inputs['Density'].default_value = 0.012
    v.inputs['Color'].default_value = (0.8, 0.82, 0.9, 1)
    nt.links.new(v.outputs['Volume'], o.inputs['Volume'])
    vol.data.materials.append(m)
    vol.visible_shadow = False
    sc = bpy.context.scene
    sc.cycles.volume_step_rate = 4.0
    sc.cycles.volume_max_steps = 128


def scena_giocatore():
    """Statua a grandezza vera sul piedistallo (alto 1 m) in una hall buia: ritorna l'altezza degli occhi."""
    prepara()
    usa_azione('statua', 1)
    h_ped = 1.0
    piedistallo(0.0, raggio=1.05 * K, altezza=h_ped)
    pavimento_piastrelle(-h_ped)
    luci_monumento(h_ped)
    imposta(esposizione=0.0)
    bpy.context.scene.cycles.volume_bounces = 1
    return -h_ped + 1.7


def giocatore_lontano():
    occhi = scena_giocatore()
    a = math.radians(18)                 # un po' di lato rispetto al davanti (-Y)
    camera((9.0 * math.sin(a), -9.0 * math.cos(a), occhi), (0.0, 0.0, 2.1), lens=24)
    png = render(os.path.join(OUT_PNG, nome_jpg('giocatore_lontano') + '.png'))
    return salva_jpg(png, nome_jpg('5_giocatore_9m'))


def giocatore_piedi():
    occhi = scena_giocatore()
    camera((0.9, -2.9, occhi), (0.0, 0.0, 3.4), lens=16)
    png = render(os.path.join(OUT_PNG, nome_jpg('giocatore_piedi') + '.png'))
    return salva_jpg(png, nome_jpg('5b_giocatore_ai_piedi'))


# ---------------------------------------------------------------- sala centrale: la medusa affacciata alla vasca

def mat_piastrelle_vasca():
    """Piastrelle quadrate blu scuro e crema, consumate (come nel concept medusa_sbircia.jpg)."""
    m, nt, b = mat_semplice('piastrelle_vasca', (0.05, 0.08, 0.16), 0.2)
    tc = nt.nodes.new('ShaderNodeTexCoord')
    ck = nt.nodes.new('ShaderNodeTexChecker')
    ck.inputs['Scale'].default_value = 6.0
    ck.inputs['Color1'].default_value = (0.03, 0.06, 0.16, 1)
    ck.inputs['Color2'].default_value = (0.55, 0.52, 0.45, 1)
    nt.links.new(tc.outputs['Object'], ck.inputs['Vector'])
    br = nt.nodes.new('ShaderNodeTexBrick')
    br.inputs['Scale'].default_value = 6.0
    br.inputs['Mortar Size'].default_value = 0.012
    br.inputs['Color1'].default_value = (1, 1, 1, 1)
    br.inputs['Color2'].default_value = (0.92, 0.92, 0.92, 1)
    br.inputs['Mortar'].default_value = (0.05, 0.05, 0.05, 1)
    br.offset = 0.0
    br.squash = 1.0
    nt.links.new(tc.outputs['Object'], br.inputs['Vector'])
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0
    nt.links.new(ck.outputs['Color'], mix.inputs['A']); nt.links.new(br.outputs['Color'], mix.inputs['B'])
    noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 3.0
    sp = nt.nodes.new('ShaderNodeMix'); sp.data_type = 'RGBA'; sp.blend_type = 'MULTIPLY'
    sp.inputs['Factor'].default_value = 0.5
    nt.links.new(mix.outputs['Result'], sp.inputs['A']); nt.links.new(noise.outputs['Color'], sp.inputs['B'])
    nt.links.new(sp.outputs['Result'], b.inputs['Base Color'])
    return m


def vasca_segnaposto():
    """Vasca a scatola delle misure giuste (segnaposto: la vera la modella l'agente ambiente): bordo a 1,0 m,
    coping di 0,30 m, muro esterno verticale, fondo a 0, acqua a 0,88 m. Centro nell'origine, davanti verso -Y."""
    import medusa_affacciata as AFF
    V = AFF.VASCA
    est, sp = -V['fuori'], V['dentro'] - V['fuori']
    m = mat_piastrelle_vasca()
    for (x0, x1, y0, y1) in ((-est, est, -est, -est + sp), (-est, est, est - sp, est),
                             (-est, -est + sp, -est + sp, est - sp), (est - sp, est, -est + sp, est - sp),
                             (-est, est, -est, est)):
        alto = V['cima'] if (y1 - y0 < 1.0 or x1 - x0 < 1.0) else 0.02
        bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, alto / 2))
        o = bpy.context.active_object
        o.scale = (x1 - x0, y1 - y0, alto)
        bpy.ops.object.transform_apply(scale=True)
        bev = o.modifiers.new('smusso', 'BEVEL'); bev.width = 0.015; bev.segments = 2
        o.data.materials.append(m)
    # acqua: superficie appena mossa, scura e trasparente
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, V['acqua']))
    w = bpy.context.active_object
    w.name = 'acqua'
    w.scale = (2 * V['dentro'] * -1, 2 * V['dentro'] * -1, 1)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.modifier_add(type='SUBSURF')
    w.modifiers[-1].levels = 0
    mw, nt, b = mat_semplice('acqua', (0.55, 0.75, 0.8), 0.03)
    b.inputs['Transmission Weight'].default_value = 1.0
    b.inputs['IOR'].default_value = 1.33
    noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 6.0
    bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.08
    nt.links.new(noise.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    w.data.materials.append(mw)


VASCA_SALA = os.path.join(BUILD, 'rif', 'sala_vasca_centrale.glb')   # copia della vasca dell'agente ambiente
SPOSTA_VASCA = 10.15        # la vasca della sala ha il centro in z 10 Godot; il marker della medusa e' in z 10,15


def vasca_sala(acqua=True):
    """La vasca vera della sala (GLB dell'agente ambiente), spostata nel riferimento della medusa; via le mesh di
    collisione. Acqua: un blocco dal fondo al pelo (0,88), vetro con un velo verde-azzurro che assorbe la luce e
    piccole onde in superficie; non fa ombra, cosi' la luce arriva anche sott'acqua."""
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=VASCA_SALA)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    for o in nuovi:
        if o.parent is None:
            o.location.y += SPOSTA_VASCA
        if 'colonly' in o.name or 'convcol' in o.name:
            o.hide_render = True
    if not acqua:
        return
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.15, 0.4425))
    w = bpy.context.active_object
    w.name = 'acqua'
    w.scale = (5.38, 3.88, 0.875)
    bpy.ops.object.transform_apply(scale=True)
    mw, nt, b = mat_semplice('acqua', (0.82, 0.95, 0.95), 0.02)
    b.inputs['Transmission Weight'].default_value = 1.0
    b.inputs['IOR'].default_value = 1.33
    noise = nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 7.0
    noise.inputs['Detail'].default_value = 3.0
    bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.06
    nt.links.new(noise.outputs['Fac'], bump.inputs['Height']); nt.links.new(bump.outputs['Normal'], b.inputs['Normal'])
    vol = nt.nodes.new('ShaderNodeVolumeAbsorption')
    vol.inputs['Color'].default_value = (0.3, 0.62, 0.66, 1)
    vol.inputs['Density'].default_value = 0.9
    nt.links.new(vol.outputs['Volume'], nt.nodes['Material Output'].inputs['Volume'])
    w.data.materials.append(mw)
    w.visible_shadow = False


def materiali_bagnati():
    """Aspetto bagnato solo per la scena della vasca (in Godot: i materiali *_bagnata.tres): pelle e mani piu'
    lucide, capelli lucidi e appena piu' scuri in punta (restano argento-rosa chiari, come nel concept), tentacoli
    lucidi."""
    def _ruvido_per(m, f):
        nt = m.node_tree
        b = nt.nodes['BSDF']
        ls = b.inputs['Roughness'].links
        if ls:
            src = ls[0].from_socket
            mul = nt.nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'
            mul.inputs[1].default_value = f
            nt.links.new(src, mul.inputs[0]); nt.links.new(mul.outputs[0], b.inputs['Roughness'])
        else:
            b.inputs['Roughness'].default_value *= f
        return b

    def _scurisci(m, f):
        nt = m.node_tree
        b = nt.nodes['BSDF']
        ls = b.inputs['Base Color'].links
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs['Factor'].default_value = 1.0
        mix.inputs['B'].default_value = (f, f, f * 1.03, 1)
        if ls:
            nt.links.new(ls[0].from_socket, mix.inputs['A'])
        else:
            mix.inputs['A'].default_value = b.inputs['Base Color'].default_value
        nt.links.new(mix.outputs['Result'], b.inputs['Base Color'])
        return mix

    for n in ('M_pelle', 'M_orbita', 'M_mani'):
        m = bpy.data.materials.get(n)
        if m:
            b = _ruvido_per(m, 0.5)
            b.inputs['Coat Weight'].default_value = 1.0
            b.inputs['Coat Roughness'].default_value = 0.02
            _scurisci(m, 0.93)
    m = bpy.data.materials.get('M_capelli')
    if m:
        b = _ruvido_per(m, 0.6)
        b.inputs['Coat Weight'].default_value = 0.8
        b.inputs['Coat Roughness'].default_value = 0.03
        _scurisci(m, 0.88)
    m = bpy.data.materials.get('M_ciocche')
    if m:
        nt = m.node_tree
        b = nt.nodes['BSDF']
        uv = nt.nodes.new('ShaderNodeUVMap')
        sep = nt.nodes.new('ShaderNodeSeparateXYZ')
        nt.links.new(uv.outputs['UV'], sep.inputs['Vector'])
        mr = nt.nodes.new('ShaderNodeMapRange'); mr.interpolation_type = 'SMOOTHSTEP'
        mr.inputs['From Min'].default_value = 0.35; mr.inputs['From Max'].default_value = 1.0
        nt.links.new(sep.outputs['Y'], mr.inputs['Value'])          # v: 0 alla radice, 1 in punta
        mix = _scurisci(m, 0.82)
        nt.links.new(mr.outputs['Result'], mix.inputs['Factor'])
        rr = nt.nodes.new('ShaderNodeMapRange')
        rr.inputs['To Min'].default_value = 0.16; rr.inputs['To Max'].default_value = 0.07
        nt.links.new(mr.outputs['Result'], rr.inputs['Value'])
        nt.links.new(rr.outputs['Result'], b.inputs['Roughness'])
        b.inputs['Coat Weight'].default_value = 0.9
        b.inputs['Coat Roughness'].default_value = 0.02
    for n in ('M_tentacoli',):
        m = bpy.data.materials.get(n)
        if m:
            b = m.node_tree.nodes['BSDF']
            for l in list(b.inputs['Roughness'].links):
                m.node_tree.links.remove(l)
            b.inputs['Roughness'].default_value = 0.1
            b.inputs['Coat Weight'].default_value = 1.0
            b.inputs['Coat Roughness'].default_value = 0.03


def scena_vasca():
    prepara()
    usa_azione('affacciata', 1)
    if os.path.exists(VASCA_SALA):
        vasca_sala()
    else:
        vasca_segnaposto()
    materiali_bagnati()
    pavimento_piastrelle(0.0)
    luci_notte((0, -1.0, 1.4), 2.6, nebbia=0.004)
    # il bagliore della campana sotto il pelo dell'acqua sale sul viso e sul petto (appena sopra l'acqua)
    luce_area('bagliore_campana', (0, -1.45, 0.92), (0, -1.75, 1.7), 45, (1.0, 0.45, 0.72), 0.7, 'DISK')
    imposta()


def affacciata_giocatore():
    """Dal punto di vista del giocatore all'ingresso: a circa 9 m, occhi a 1,7 m."""
    scena_vasca()
    camera((0.6, -10.0, 1.7), (0.0, -1.6, 1.3), lens=24)
    png = render(os.path.join(OUT_PNG, nome_jpg('affacciata_giocatore') + '.png'))
    return salva_jpg(png, nome_jpg('6_affacciata_9m'))


def affacciata_vicino():
    """Primo piano basso come il concept medusa_sbircia.jpg: camera a 1,2 m di altezza e 1,3 m davanti al bordo,
    che guarda un po' in su."""
    scena_vasca()
    # luce morbida e fredda sul viso (le lampade della sala)
    luce_area('viso_freddo', (0.6, -3.2, 2.0), (0, -1.8, 1.6), 70, (0.55, 0.65, 1.0), 1.4, 'DISK')
    camera((0.1, -3.4, 1.2), (0.0, -1.8, 1.45), lens=22)
    png = render(os.path.join(OUT_PNG, nome_jpg('affacciata_vicino') + '.png'))
    return salva_jpg(png, nome_jpg('6b_affacciata_vicino'))


INQUADRATURE = {
    'affacciata_giocatore': affacciata_giocatore,
    'affacciata_vicino': affacciata_vicino,
    'statua_intera': statua_intera,
    'tentacoli': tentacoli,
    'viso_capelli': viso_capelli,
    'giocatore_lontano': giocatore_lontano,
    'giocatore_piedi': giocatore_piedi,
    'viso': viso,
    'fauce_chiusa': lambda: fauce(False),
    'fauce_aperta': lambda: fauce(True),
    'fluttua': fluttua,
}


if __name__ == '__main__':
    argv = [a for i, a in enumerate(sys.argv[1:], 1) if not (sys.argv[i - 1] == '--nome')]
    nomi = [a for a in argv if not a.startswith('--')] or list(INQUADRATURE)
    for n in nomi:
        t0 = time.time()
        INQUADRATURE[n]()
        log(f'{n}: {time.time() - t0:.0f} s')
