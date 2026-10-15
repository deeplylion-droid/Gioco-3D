"""Scheletro e animazioni dei bambini per Godot.

Parte dal personaggio con lo scheletro di Meshy (rigging automatico umanoide, 24 ossa con nomi
come Mixamo: Hips, Spine02, Spine01, Spine, neck, Head, LeftArm, ...), salvato in
assets_src/bambini/rig/<nome>.glb, e dalle sue animazioni di base con il solo scheletro
(<nome>_walking_armature.glb, <nome>_running_armature.glb). Crea queste azioni:

  fermo          curvo, respiro lento e piccolo ondeggiare (ciclo di 8 s)
  inclina_testa  la testa si piega piano da una parte, resta lì e torna (ciclo di 6 s)
  cammina        la camminata di Meshy rallentata, curva e un po' storta (testa piegata,
                 una spalla più bassa, braccia molli)
  corsa          la corsa di Meshy, curva e con la testa bassa, per scappare
  si_gira        di spalle; gira prima la testa, poi tutto il corpo verso chi guarda (3,5 s,
                 una volta sola; finisce nella posa di "fermo")

Niente movimenti bruschi: fanno paura con la postura e la lentezza (GDD).
Per l'agnellino con l'occhio riattacca all'osso della testa il guscio dell'occhio
('occhio_bulbo', dal GLB gioco), così nel gioco lo sguardo si muove spostando le sue UV.
Esporta un GLB con tutte le azioni (24 fps), di norma in godot/assets/models/bambini/.

Uso:
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/bambini_animazioni.py \
        <nome> <uscita.glb> [--occhio assets_src/bambini/game/agnello_occhio.glb]
"""
import argparse, math, os, sys
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
RIG = os.path.join(REPO, 'assets_src', 'bambini', 'rig')
FPS = 24

ap = argparse.ArgumentParser()
ap.add_argument('nome'); ap.add_argument('uscita')
ap.add_argument('--occhio', default='', help="GLB da cui prendere il guscio dell'occhio")
A = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])


def log(*a):
    print('[bambini]', *a, flush=True)


def importa(path):
    prima = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    nuovi = [o for o in bpy.context.scene.objects if o not in prima]
    for o in list(nuovi):
        if o.name.startswith('Icosphere'):          # un oggetto di servizio di Meshy
            nuovi.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    return nuovi


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
nuovi = importa(os.path.join(RIG, A.nome + '.glb'))
arm = next(o for o in nuovi if o.type == 'ARMATURE')
arm.name = 'Scheletro'
corpo = next(o for o in nuovi if o.type == 'MESH')
corpo.name = A.nome
for act in list(bpy.data.actions):                   # la posa di riposo che Meshy esporta come clip
    bpy.data.actions.remove(act)
if arm.animation_data:
    arm.animation_data.action = None


def sorgente(suffisso):
    """Armatura importata con la sua animazione di base (camminata o corsa)."""
    objs = importa(os.path.join(RIG, f'{A.nome}_{suffisso}_armature.glb'))
    a = next(o for o in objs if o.type == 'ARMATURE')
    for o in objs:
        if o is not a:
            bpy.data.objects.remove(o, do_unlink=True)
    act = a.animation_data.action
    log(f'{suffisso}: {act.name}, frame {act.frame_range[0]:.1f}-{act.frame_range[1]:.1f}')
    return a, act


cam_src, cam_act = sorgente('walking')
cor_src, cor_act = sorgente('running')

# Testa rigida: sopra la base dell'osso Head tutto va con la testa (il cubo di piastrelle non
# si deve piegare; la testa di peluche si muove tutta insieme).
z_testa = (arm.matrix_world @ arm.data.bones['Head'].head_local).z - 0.005
gi = {g.index: g.name for g in corpo.vertex_groups}
g_testa = corpo.vertex_groups['Head']
rifatti = 0
for v in corpo.data.vertices:
    if (corpo.matrix_world @ v.co).z < z_testa:
        continue
    pesi = {gi[g.group]: g.weight for g in v.groups}
    if pesi.get('Head', 0.0) >= 0.999 and len([w for w in pesi.values() if w > 0.001]) == 1:
        continue
    for nome in pesi:
        if nome != 'Head':
            corpo.vertex_groups[nome].remove([v.index])
    g_testa.add([v.index], 1.0, 'REPLACE')
    rifatti += 1
log(f'testa rigida sopra z={z_testa:.3f}: {rifatti} vertici sistemati')

OSSA = [pb.name for pb in arm.pose.bones]
R_REST = {pb.name: (arm.matrix_world @ pb.bone.matrix_local).to_quaternion().normalized() for pb in arm.pose.bones}


def q_mondo(asse, gradi):
    return Quaternion(Vector(asse), math.radians(gradi))


def in_locale(nome, q_world):
    """Rotazione intorno a un asse del mondo -> rotazione nello spazio di riposo dell'osso."""
    r = R_REST[nome]
    return r.inverted() @ q_world @ r


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)   # X di lato, -Y avanti (il viso), Z in alto


def onda(t, periodo, fase=0.0):
    return math.sin(2 * math.pi * (t / periodo + fase))


def liscio(t, a, b):
    """0 prima di a, 1 dopo b, smoothstep in mezzo."""
    if t <= a:
        return 0.0
    if t >= b:
        return 1.0
    u = (t - a) / (b - a)
    return u * u * (3 - 2 * u)


def posa_curva(t, respiro=4.0, ondeggio=8.0, curva=1.0):
    """Rotazioni nel mondo (gradi) per osso: schiena curva, spalle cadenti, respiro, ondeggiare."""
    r = onda(t, respiro)
    o = onda(t, ondeggio)
    o2 = onda(t, ondeggio, 0.25)
    return {
        'Hips': [(Z, 1.6 * o), (Y, 1.1 * o2)],
        'Spine02': [(X, 5 * curva)],
        'Spine01': [(X, 5 * curva + 0.6 * r)],
        'Spine': [(X, 4 * curva + 0.9 * r), (Y, -0.8 * o2)],
        'neck': [(X, 6 * curva - 0.5 * r)],
        'Head': [(X, 2 * curva), (Z, 2.5 * onda(t, ondeggio, 0.6))],
        'LeftShoulder': [(Y, 5 * curva - 0.8 * r)],
        'RightShoulder': [(Y, -5 * curva + 0.8 * r)],
        'LeftArm': [(Y, -2 * curva), (X, 0.8 * o2)],
        'RightArm': [(Y, 2 * curva), (X, -0.8 * o2)],
    }


def applica(pose_mondo, base=None):
    """Mette la posa: base locale (dict osso -> Quaternion) e poi le rotazioni nel mondo."""
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        q = base.get(pb.name, Quaternion()) if base else Quaternion()
        for asse, gradi in pose_mondo.get(pb.name, []):
            q = in_locale(pb.name, q_mondo(asse, gradi)) @ q
        pb.rotation_quaternion = q


def chiave(frame, con_posizione=()):
    for pb in arm.pose.bones:
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        if pb.name in con_posizione:
            pb.keyframe_insert('location', frame=frame)


def nuova_azione(nome):
    arm.animation_data_create()
    act = bpy.data.actions.new(nome)
    act.use_fake_user = True
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = Quaternion()
        pb.scale = (1, 1, 1)
    return act


def unisci(*pose):
    out = {}
    for p in pose:
        for k, v in p.items():
            out.setdefault(k, []).extend(v)
    return out


# ---------------------------------------------------------------- azioni fatte a mano
def fermo():
    nuova_azione('fermo')
    n = 8 * FPS
    for f in range(n + 1):
        applica(posa_curva(f / FPS))
        chiave(f)


def inclina_testa():
    nuova_azione('inclina_testa')
    n = 6 * FPS
    for f in range(n + 1):
        t = f / FPS
        k = liscio(t, 0.4, 2.4) - liscio(t, 3.9, 5.7)
        extra = 0.12 * liscio(t, 2.4, 3.9) * (1 - liscio(t, 3.9, 5.7))
        p = posa_curva(t, respiro=3.0, ondeggio=6.0)
        applica(unisci(p, {'Head': [(Y, 18 * k + 18 * extra), (Z, 6 * k)],
                           'neck': [(Y, 6 * k)]}))
        chiave(f)


def si_gira():
    nuova_azione('si_gira')
    n = int(3.5 * FPS)
    for f in range(n + 1):
        t = f / FPS
        s = liscio(t, 1.1, 3.1)                     # il corpo gira
        g = liscio(t, 0.2, 1.1)                     # prima la testa, oltre la spalla
        testa = 75 * g * (1 - s)
        p = posa_curva(t, respiro=3.5, ondeggio=7.0)
        applica(unisci(p, {'Hips': [(Z, 180 + 180 * s)],
                           'neck': [(Z, 0.35 * testa)],
                           'Head': [(Z, 0.65 * testa), (Y, 10 * s)]}))
        chiave(f)


# ---------------------------------------------------------------- camminata e corsa (da Meshy)
def da_mocap(nome, src, act, lentezza, braccia, extra, ciclo_in=None):
    """Campiona l'animazione di Meshy (stessi nomi e stessa posa di riposo) più lenta di
    'lentezza', smorza le braccia e aggiunge la postura (rotazioni nel mondo)."""
    nuova_azione(nome)
    f0, f1 = act.frame_range
    durata = f1 - f0
    n = int(round(durata * lentezza))
    hips_loc = []
    for g in range(n + 1):
        fs = f0 + (g / lentezza) % durata if g < n else f0      # l'ultimo = il primo: ciclo chiuso
        sc.frame_set(int(fs), subframe=fs - int(fs))
        base = {}
        for nb in OSSA:
            sp = src.pose.bones.get(nb)
            if sp is None:
                continue
            loc, rot, _ = sp.matrix_basis.decompose()
            if nb.startswith(('LeftArm', 'RightArm', 'LeftForeArm', 'RightForeArm', 'LeftHand', 'RightHand')):
                rot = Quaternion().slerp(rot, braccia)
            base[nb] = rot
            if nb == 'Hips':
                hips_loc.append(loc.copy())
        t = g / FPS
        applica(extra(t), base)
        arm.pose.bones['Hips'].location = hips_loc[-1]
        chiave(g, con_posizione=('Hips',))
    # niente spostamento in avanti dentro l'animazione: il nodo lo muove lo script di Godot
    act_new = arm.animation_data.action
    deriva = (hips_loc[-1] - hips_loc[0]).length if hips_loc else 0.0
    log(f'{nome}: {n} frame ({n / FPS:.2f} s per ciclo), deriva delle anche {deriva:.3f}')
    return act_new


def extra_cammina(t):
    return {
        'Spine02': [(X, 5)], 'Spine01': [(X, 5)], 'Spine': [(X, 4)],
        'neck': [(X, 5)], 'Head': [(Y, 12 + 2 * onda(t, 1.9)), (X, 1)],
        'LeftShoulder': [(Y, 9)], 'RightShoulder': [(Y, -3)],
    }


def extra_corsa(t):
    return {
        'Spine02': [(X, 6)], 'Spine01': [(X, 6)], 'Spine': [(X, 5)],
        'neck': [(X, 6)], 'Head': [(X, 8), (Y, 6)],
    }


fermo()
inclina_testa()
si_gira()
cam_src.animation_data.action = cam_act
da_mocap('cammina', cam_src, cam_act, lentezza=1.8, braccia=0.5, extra=extra_cammina)
cor_src.animation_data.action = cor_act
da_mocap('corsa', cor_src, cor_act, lentezza=1.15, braccia=0.8, extra=extra_corsa)
for o in (cam_src, cor_src):
    bpy.data.objects.remove(o, do_unlink=True)
for act in (cam_act, cor_act):
    bpy.data.actions.remove(act)
arm.animation_data.action = bpy.data.actions['fermo']
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)

# ---------------------------------------------------------------- occhio dell'agnellino
if A.occhio:
    occhio = [o for o in importa(A.occhio) if o.name.startswith('occhio_bulbo')]
    for o in [o for o in bpy.context.scene.objects if o.type == 'MESH' and o not in (corpo, *occhio)]:
        bpy.data.objects.remove(o, do_unlink=True)
    for o in occhio:
        mw = o.matrix_world.copy()
        o.parent = arm
        o.parent_type = 'BONE'
        o.parent_bone = 'Head'
        o.matrix_world = mw
        o.name = 'occhio_bulbo'
        log('occhio attaccato all\'osso Head')

# ---------------------------------------------------------------- export
azioni = [a.name for a in bpy.data.actions]
log('azioni', azioni)
os.makedirs(os.path.dirname(os.path.abspath(A.uscita)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=A.uscita, export_format='GLB', export_yup=True,
                          export_image_format='JPEG', export_jpeg_quality=90,
                          export_animations=True, export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_frame_step=1,
                          export_skins=True, export_morph=False, export_apply=False)
log('scritto', A.uscita, f'{os.path.getsize(A.uscita) / 1e6:.1f} MB')
