"""Proposte di design della medusa (fase 2): render e tavole JPG in docs/proposte/medusa/.

  A  finitura del vinile (3 opzioni x luce da studio / acquapark di notte)
  B  campana organica: trasparenza, colore e luce dei canali radiali (3 opzioni)
  C  tentacoli dal generatore procedurale (3 preset di medusa_05_tentacoli.py)
  D  occhio di vetro: da bambola o umido e organico (2 opzioni, primo piano)

Le scelte le fa l'utente: qui si preparano solo le immagini. I materiali delle opzioni sono
costruiti qui (nodi di Blender) e restano descritti nelle funzioni, per rifarli dopo la scelta.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_proposte.py A [B C D] [--prova]
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_05_tentacoli as TENT  # noqa: E402

PROVA = '--prova' in sys.argv
CAMPIONI = 16 if PROVA else 48
SCALA = 0.5 if PROVA else 1.0
OUT = os.path.join(BUILD, 'proposte')
os.makedirs(OUT, exist_ok=True)
os.makedirs(PROPOSTE, exist_ok=True)
Z_VITA = -0.155


# ---------------------------------------------------------------- scena

def apri_modello(blend='medusa_04_scheletro.blend'):
    apri(os.path.join(BUILD, blend))
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o)
    arm = bpy.data.objects['Medusa_Scheletro']
    arm.hide_render = True
    coll = bpy.data.collections.get('Attacchi_tentacoli')
    if coll:
        for e in coll.objects:
            e.hide_render = True
    return arm


def res(w, h):
    return int(w * SCALA), int(h * SCALA)


def luci_studio_tonde(centro=(0, 0, 0), H=1.9, forza=1.0):
    """Studio con luci a disco (riflessi tondi e morbidi sul vinile e sulla cornea)."""
    c = Vector(centro)
    luce_area('chiave', c + Vector((-1.1, -1.5, 0.9)) * H, c, 95 * H * H * forza, (1, 0.98, 0.96), 1.1 * H, 'DISK')
    luce_area('riempimento', c + Vector((1.4, -1.1, 0.1)) * H, c, 30 * H * H * forza, (0.85, 0.88, 1.0), 1.4 * H, 'DISK')
    luce_area('controluce', c + Vector((0.5, 1.5, 1.1)) * H, c, 110 * H * H * forza, (1.0, 0.8, 0.92), 0.9 * H, 'DISK')
    mondo((0.045, 0.045, 0.055), 1.0)


def luci_notte(centro=(0, 0, 0), H=1.9, nebbia=0.01, forza=1.0, pavimento_z=None):
    """Acquapark di notte: emergenza rossa dall'alto dietro, riflesso azzurro della piscina dal basso,
    controluce freddo, nebbia leggera e pavimento bagnato."""
    c = Vector(centro)
    k = forza
    luce_spot('rossa_emergenza', c + Vector((1.2, 1.1, 1.5)) * H, c + Vector((0, 0, 0.15 * H)), 1400 * k * H * H,
              (1.0, 0.05, 0.02), angolo=50, raggio=0.12, blend=0.5)
    luce_area('rossa_riempimento', c + Vector((-1.5, -0.9, 0.5)) * H, c, 18 * H * H * k, (1.0, 0.12, 0.08), 0.6 * H, 'DISK')
    luce_area('azzurra_piscina', c + Vector((0.3, -1.4, -0.9)) * H, c + Vector((0, 0, 0.25 * H)), 55 * H * H * k,
              (0.1, 0.5, 1.0), 1.6 * H, 'DISK')
    luce_area('azzurra_controluce', c + Vector((-0.9, 1.4, 0.9)) * H, c, 45 * H * H * k, (0.35, 0.7, 1.0), 0.7 * H, 'DISK')
    mondo((0.004, 0.006, 0.012), 1.0)
    # lampade d'emergenza lontane, dietro: puntini rossi che bucano la nebbia
    m = bpy.data.materials.new('lampada_emergenza'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Color'].default_value = (1.0, 0.04, 0.02, 1); e.inputs['Strength'].default_value = 60
    nt.links.new(e.outputs['Emission'], o.inputs['Surface'])
    for x, y, z in ((-2.6, 5.5, 1.9), (1.8, 6.5, 2.4), (4.2, 4.5, 1.4), (-4.5, 3.5, 2.8)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(c.x + x, c.y + y, c.z + z))
        lamp = bpy.context.active_object; lamp.name = 'lampada_fondo'
        lamp.data.materials.append(m)
        lamp.visible_shadow = False
    if pavimento_z is not None:
        bpy.ops.mesh.primitive_plane_add(size=30, location=(c.x, c.y, pavimento_z))
        pav = bpy.context.active_object; pav.name = 'pavimento_bagnato'
        m = bpy.data.materials.new('pavimento_bagnato'); m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (0.015, 0.02, 0.03, 1)
        b.inputs['Roughness'].default_value = 0.06
        pav.data.materials.append(m)
    if nebbia > 0:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(c.x, c.y, c.z))
        vol = bpy.context.active_object; vol.name = 'nebbia'
        vol.scale = (8, 8, 5)
        m = bpy.data.materials.new('nebbia'); m.use_nodes = True
        nt = m.node_tree; nt.nodes.clear()
        o = nt.nodes.new('ShaderNodeOutputMaterial')
        v = nt.nodes.new('ShaderNodeVolumePrincipled')
        v.inputs['Density'].default_value = nebbia
        v.inputs['Color'].default_value = (0.75, 0.8, 0.9, 1)
        nt.links.new(v.outputs['Volume'], o.inputs['Volume'])
        vol.data.materials.append(m)
        vol.visible_shadow = False
        bpy.context.scene.cycles.volume_step_rate = 4.0
        bpy.context.scene.cycles.volume_max_steps = 256


def pulisci_luci():
    for o in list(bpy.data.objects):
        if o.type in ('LIGHT', 'CAMERA') or o.name.split('.')[0] in ('pavimento_bagnato', 'nebbia', 'lampada_fondo'):
            bpy.data.objects.remove(o)


# ---------------------------------------------------------------- A: vinile

FINITURE = [
    ('opaco', 'Opzione 1: opaco morbido', dict(rough=0.55, coat=0.0, coat_rough=0.3, spec=0.35, sss=0.12)),
    ('satinato', 'Opzione 2: satinato', dict(rough=0.30, coat=0.35, coat_rough=0.22, spec=0.5, sss=0.06)),
    ('laccato', 'Opzione 3: lucido laccato', dict(rough=0.10, coat=1.0, coat_rough=0.03, spec=0.5, sss=0.03)),
]


def finitura_vinile(nomi_mat, rough, coat, coat_rough, spec, sss):
    for n in nomi_mat:
        m = bpy.data.materials.get(n)
        if not m:
            continue
        nt = m.node_tree
        b = nt.nodes['BSDF']
        for l in list(b.inputs['Roughness'].links):
            nt.links.remove(l)
        b.inputs['Roughness'].default_value = rough
        b.inputs['Coat Weight'].default_value = coat
        b.inputs['Coat Roughness'].default_value = coat_rough
        b.inputs['Specular IOR Level'].default_value = spec
        b.inputs['Subsurface Weight'].default_value = sss
        b.inputs['Subsurface Radius'].default_value = (0.9, 0.6, 0.5)
        b.inputs['Subsurface Scale'].default_value = 0.02


def proposta_A():
    t0 = time.time()
    celle_s, celle_n = [], []
    for nome, etichetta, f in FINITURE:
        apri_modello()
        finitura_vinile(['M_pelle', 'M_capelli', 'M_orbita'], **f)
        cam = camera((1.0, -3.0, 0.62), (0.0, 0, 0.25), lens=58)
        imposta_render(samples=CAMPIONI, res=res(760, 1000))
        luci_studio_tonde((0, 0, 0.2), 1.9)
        celle_s.append((render(os.path.join(OUT, f'A_{nome}_studio.png')), etichetta))
        pulisci_luci()
        cam = camera((1.0, -3.0, 0.62), (0.0, 0, 0.25), lens=58)
        imposta_render(samples=CAMPIONI, res=res(760, 1000))
        luci_notte((0, 0, 0.2), 1.9, pavimento_z=-1.25)
        celle_n.append((render(os.path.join(OUT, f'A_{nome}_notte.png')), etichetta.split(':')[0] + ' (notte)'))
    tavola(celle_s + celle_n, os.path.join(PROPOSTE, 'A_vinile.jpg'), colonne=3,
           titolo='A. Finitura del vinile (pelle e capelli)',
           sottotitolo='Sopra: luce da studio. Sotto: acquapark di notte (emergenza rossa, riflesso azzurro, nebbia).',
           larghezza=2400)
    log(f'A fatto in {time.time() - t0:.0f} s')


# ---------------------------------------------------------------- main

if __name__ == '__main__':
    scelte = [a for a in sys.argv[1:] if not a.startswith('--')]
    for s in scelte:
        globals()['proposta_' + s]()
