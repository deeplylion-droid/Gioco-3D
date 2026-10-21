"""Mostro-squalo A: scheletro, pesi e animazioni per l'inizio del gioco (GDD, "L'inizio con il
mostro-squalo"). Parte dal modello per il gioco (gioco/mostro_squalo_A.glb), gli apre la bocca
(mostro_bocca.py), gli mette lo scheletro, i pesi automatici (più quelli della mascella fatti a mano)
e le animazioni, ed esporta godot/assets/models/mascotte/mostro_squalo_A_rig.glb.

Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python \
        assets_src/mascotte/mostro_rig.py [ossa <cartella>]   (ossa: solo i render di controllo dello scheletro)
Coordinate di Blender del modello: x di lato, -y avanti (il muso), z in alto; piedi a z = 0.
"""
import json, math, os, sys
import numpy as np
import bpy
from mathutils import Vector, Matrix, Quaternion, Euler

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import mostro_bocca as BOCCA  # noqa: E402

REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
USCITA = os.path.join(REPO, 'godot', 'assets', 'models', 'mascotte', 'mostro_squalo_A_rig.glb')

# Le giunture, dai render ortografici e dalle fette della mesh (vedi il passaggio della squadra).
# Il modello è in posa: la gamba +x avanti, la -x dietro; il braccio -x alzato davanti al muso,
# il +x che pende.
G = {
    'bacino': (0.0, 0.42, 1.10), 'spina': (0.0, 0.10, 1.40), 'petto': (0.0, -0.25, 1.55),
    'collo': (0.03, -0.50, 1.62), 'testa': (0.08, -0.70, 1.62), 'muso': (0.15, -1.18, 1.60),
    'mento': (0.14, -1.05, 1.40),
    'coda1': (0.0, 0.70, 1.22), 'coda2': (0.03, 0.92, 1.24), 'coda3': (0.10, 1.12, 1.28), 'coda4': (0.18, 1.38, 1.36),
    'anca.L': (0.25, 0.40, 0.86), 'ginocchio.L': (0.36, 0.30, 0.48), 'caviglia.L': (0.37, 0.40, 0.20),
    'punta.L': (0.44, 0.06, 0.03),
    'anca.R': (-0.24, 0.42, 0.86), 'ginocchio.R': (-0.26, 0.40, 0.47), 'caviglia.R': (-0.16, 0.70, 0.20),
    'punta.R': (-0.24, 0.42, 0.03),
    'clavicola.L': (0.18, -0.40, 1.55), 'spalla.L': (0.45, -0.58, 1.45), 'gomito.L': (0.60, -0.84, 1.03),
    'polso.L': (0.71, -1.06, 0.86), 'mano.L': (0.74, -1.22, 0.70),
    'clavicola.R': (-0.15, -0.40, 1.55), 'spalla.R': (-0.42, -0.52, 1.42), 'gomito.R': (-0.60, -0.80, 1.32),
    'polso.R': (-0.58, -1.06, 1.44), 'mano.R': (-0.63, -1.32, 1.45),
}
# osso: (giuntura di partenza, giuntura d'arrivo, padre, deforma)
OSSA = [
    ('radice', None, None, None, False),
    ('bacino', 'bacino', 'spina', 'radice', True),
    ('spina', 'spina', 'petto', 'bacino', True),
    ('petto', 'petto', 'collo', 'spina', True),
    ('collo', 'collo', 'testa', 'petto', True),
    ('testa', 'testa', 'muso', 'collo', True),
    ('mascella', 'testa', 'mento', 'testa', True),
    ('coda1', 'bacino', 'coda1', 'bacino', True),
    ('coda2', 'coda1', 'coda2', 'coda1', True),
    ('coda3', 'coda2', 'coda3', 'coda2', True),
    ('coda4', 'coda3', 'coda4', 'coda3', True),
]
for s in ('L', 'R'):
    OSSA += [
        (f'coscia.{s}', f'anca.{s}', f'ginocchio.{s}', 'bacino', True),
        (f'stinco.{s}', f'ginocchio.{s}', f'caviglia.{s}', f'coscia.{s}', True),
        (f'piede.{s}', f'caviglia.{s}', f'punta.{s}', f'stinco.{s}', True),
        (f'clavicola.{s}', f'clavicola.{s}', f'spalla.{s}', 'petto', True),
        (f'braccio.{s}', f'spalla.{s}', f'gomito.{s}', f'clavicola.{s}', True),
        (f'avambraccio.{s}', f'gomito.{s}', f'polso.{s}', f'braccio.{s}', True),
        (f'mano.{s}', f'polso.{s}', f'mano.{s}', f'avambraccio.{s}', True),
    ]
# la coda parte dal bacino ma la prima vertebra è coda1 -> coda1..: si corregge sotto
OSSA = [o if o[0] != 'coda1' else ('coda1', 'coda1', 'coda2', 'bacino', True) for o in OSSA]
OSSA = [o if o[0] != 'coda2' else ('coda2', 'coda2', 'coda3', 'coda1', True) for o in OSSA]
OSSA = [o if o[0] != 'coda3' else ('coda3', 'coda3', 'coda4', 'coda2', True) for o in OSSA]
OSSA = [o for o in OSSA if o[0] != 'coda4']


def scheletro():
    arm = bpy.data.armatures.new('Scheletro')
    ob = bpy.data.objects.new('MostroSqualo', arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    for nome, a, b, padre, deforma in OSSA:
        e = eb.new(nome)
        if a is None:
            e.head = (0, 0, 0); e.tail = (0, 0.3, 0)
        else:
            e.head = G[a]; e.tail = G[b]
        e.use_deform = deforma
        if padre:
            e.parent = eb[padre]
            e.use_connect = False
    # la mascella: l'asse X locale lungo la cerniera (si apre girando attorno a X)
    j = eb['mascella']
    a, b = BOCCA.CERNIERA
    j.head = (a + b) / 2
    asse = (b - a).normalized()
    j.align_roll(j.vector.normalized().cross(asse))
    bpy.ops.object.mode_set(mode='OBJECT')
    return ob


def overlay(cartella):
    """Render di controllo: la mesh grigia semitrasparente e le ossa in rosso, di fronte e di lato."""
    mesh = BOCCA.carica()
    m = bpy.data.materials.new('vetro'); m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']; bs.inputs['Alpha'].default_value = 0.35
    bs.inputs['Base Color'].default_value = (0.6, 0.6, 0.6, 1)
    mesh.data.materials.clear(); mesh.data.materials.append(m)
    rosso = bpy.data.materials.new('osso'); rosso.use_nodes = True
    rb = rosso.node_tree.nodes['Principled BSDF']
    rb.inputs['Emission Color'].default_value = (1, 0.05, 0.02, 1); rb.inputs['Emission Strength'].default_value = 4
    for nome, a, b, _p, _d in OSSA:
        if a is None:
            continue
        pa, pb = Vector(G[a]), Vector(G[b])
        bpy.ops.mesh.primitive_cylinder_add(radius=0.012, depth=(pb - pa).length, location=(pa + pb) / 2)
        o = bpy.context.active_object
        o.rotation_euler = (pb - pa).to_track_quat('Z', 'Y').to_euler(); o.data.materials.append(rosso)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.025, location=pa)
        bpy.context.active_object.data.materials.append(rosso)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 12; sc.cycles.use_denoising = True
    sc.render.resolution_x = 1000; sc.render.resolution_y = 1000
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs[1].default_value = 1.5
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 3.0
    for nome, pos, rot in (('fronte', (0, -5, 1.1), (math.pi / 2, 0, 0)),
                           ('lato', (5, 0, 1.1), (math.pi / 2, 0, math.pi / 2)),
                           ('sopra', (0, 0, 5), (0, 0, 0))):
        cam.location = pos; cam.rotation_euler = rot
        sc.render.filepath = os.path.join(cartella, f'ossa_{nome}.png')
        bpy.ops.render.render(write_still=True)


if __name__ == '__main__' and 'ossa' in sys.argv:
    overlay(sys.argv[-1])


# ---------------------------------------------------------------- pesi
def _dist_segmento(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(P - (a + np.outer(t, ab)), axis=1)


def pesa(mesh, arm, bocca):
    """Pesi fatti qui (il calore di Blender non riesce su questa mesh): per ogni vertice le ossa più
    vicine (distanza dal segmento dell'osso, con un raggio per osso), poi lisciati lungo la superficie
    perché le pieghe (ascelle, inguine, collo) si deformino morbide. La testa e la mascella poi con il
    peso della mascella di mostro_bocca."""
    me = mesh.data
    P = np.array([v.co[:] for v in me.vertices])
    ossa = [b for b in arm.data.bones if b.use_deform]
    # raggio tipico di ogni osso (più grande = attira di più): il busto è un barile
    raggio = {'bacino': 0.45, 'spina': 0.55, 'petto': 0.50, 'collo': 0.40, 'testa': 0.40, 'mascella': 0.25,
              'coda1': 0.25, 'coda2': 0.20, 'coda3': 0.25}
    D = np.stack([_dist_segmento(P, np.array(b.head_local), np.array(b.tail_local)) /
                  raggio.get(b.name, 0.12 if ('mano' in b.name or 'piede' in b.name) else 0.16)
                  for b in ossa], 1)
    W = 1.0 / (D ** 4 + 1e-6)
    # solo le 3 ossa più vicine
    idx = np.argsort(D, 1)[:, 3:]
    np.put_along_axis(W, idx, 0.0, 1)
    W /= W.sum(1, keepdims=True)
    # lisciatura sulla superficie (media con i vicini), 8 passate
    e = np.array([ed.vertices[:] for ed in me.edges])
    from scipy.sparse import coo_matrix, diags
    n = len(P)
    Adj = coo_matrix((np.ones(len(e) * 2), (np.r_[e[:, 0], e[:, 1]], np.r_[e[:, 1], e[:, 0]])), shape=(n, n)).tocsr()
    deg = np.asarray(Adj.sum(1)).ravel()
    Lm = diags(1.0 / np.maximum(deg, 1)) @ Adj
    for _ in range(8):
        W = 0.5 * W + 0.5 * (Lm @ W)
    # 4 influenze al massimo
    idx = np.argsort(W, 1)[:, :-4]
    np.put_along_axis(W, idx, 0.0, 1)
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    gruppi = {}
    for k, b in enumerate(ossa):
        g = mesh.vertex_groups.new(name=b.name)
        gruppi[b.name] = g
        nz = np.where(W[:, k] > 1e-3)[0]
        for i in nz:
            g.add([int(i)], float(W[i, k]), 'REPLACE')
    mod = mesh.modifiers.new('Scheletro', 'ARMATURE'); mod.object = arm
    mesh.parent = arm
    vuoti = []
    gt, gm = gruppi['testa'], gruppi['mascella']
    pm = bocca['peso']
    tutti = list(gruppi.values())
    for v in mesh.data.vertices:
        i = v.index
        if pm[i] > 0.01 or bocca['lab'][i] != 0:
            # muso, mascella, guance, sacca e denti: solo testa e mascella
            for g in tutti:
                g.remove([i])
            gt.add([i], 1.0 - float(pm[i]), 'REPLACE')
            gm.add([i], float(pm[i]), 'REPLACE')
        else:
            # altrove la mascella del calore torna alla testa
            wm = 0.0
            for g in v.groups:
                if g.group == gm.index:
                    wm = g.weight
            if wm > 0:
                gm.remove([i])
                gt.add([i], wm, 'ADD')
    somme = np.zeros(len(me.vertices))
    for v in me.vertices:
        somme[v.index] = sum(g.weight for g in v.groups)
    print('PESI: somma < 0,99 su', int((somme < 0.99).sum()), 'vertici; > 1,01 su', int((somme > 1.01).sum()))
    return vuoti


# ---------------------------------------------------------------- cottura dell'animazione
import mostro_anim as A  # noqa: E402

ASSI = {'x': Vector((1, 0, 0)), 'y': Vector((0, 1, 0)), 'z': Vector((0, 0, 1))}


def _rot_mondo(lista):
    R = Matrix.Identity(3)
    for asse, gradi in lista:
        if asse.startswith('_'):
            continue
        R = Matrix.Rotation(math.radians(gradi), 3, ASSI[asse]) @ R
    return R


def _matrice_osso(B3, y_dir, testa):
    """Matrice (spazio dell'armatura) di un osso con l'asse Y verso y_dir e il rollio più vicino a B3."""
    y = y_dir.normalized()
    x = B3.col[0] - y * B3.col[0].dot(y)
    if x.length < 1e-4:
        x = B3.col[2].cross(y)
    x.normalize()
    z = x.cross(y)
    M = Matrix((x, y, z)).transposed().to_4x4()
    M.translation = testa
    return M


def cuoci(arm, piedi, nome='risveglio'):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    pbs = arm.pose.bones
    for pb in pbs:
        pb.rotation_mode = 'QUATERNION'
    B = {b.name: b.matrix_local.copy() for b in arm.data.bones}
    lung = {b.name: b.length for b in arm.data.bones}
    # la mascella: verso dell'apertura (il mento deve scendere)
    a, b = BOCCA.CERNIERA
    asse_m = (b - a).normalized()
    mento = Vector(G['mento']) - (a + b) / 2
    segno_m = 1.0 if (Matrix.Rotation(0.3, 3, asse_m) @ mento).z < mento.z else -1.0
    arm.animation_data_create()
    act = bpy.data.actions.new(nome)
    arm.animation_data.action = act
    dati = A.dati_per_godot(piedi)
    n = int(dati['durata'] * A.FPS) + 1
    for f in range(n):
        t = f / A.FPS
        posa = A.posa(t, piedi)
        x, y, yaw = A.radice(t)
        for pb in pbs:
            pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
        pbs['radice'].location = (x, y, 0)
        pbs['radice'].rotation_quaternion = Quaternion((0, 0, 1), yaw)
        B3 = B['bacino'].to_3x3()
        pbs['bacino'].location = B3.inverted() @ Vector((0, 0, -posa['_abbassa']))
        for osso, lista in posa.items():
            if osso.startswith('_'):
                continue
            if osso == 'mascella':
                R = Matrix.Rotation(math.radians(lista[0][1]) * segno_m, 3, asse_m)
            else:
                R = _rot_mondo(lista)
            Bo = B[osso].to_3x3()
            pbs[osso].rotation_quaternion = (Bo.inverted() @ R @ Bo).to_quaternion()
        bpy.context.view_layer.update()
        # gambe: IK a due ossa verso la caviglia, il ginocchio in avanti
        avanti = Vector((math.sin(yaw), -math.cos(yaw), 0))
        for s in ('L', 'R'):
            anca = pbs[f'coscia.{s}'].head.copy()
            cav, alzata, yaw_p = piedi.caviglia(s, t)
            l1, l2 = lung[f'coscia.{s}'], lung[f'stinco.{s}']
            d = cav - anca
            dist = min(d.length, (l1 + l2) * 0.995)
            u = d.normalized()
            lato = Vector((1 if s == 'L' else -1, 0, 0))
            lato.rotate(Matrix.Rotation(yaw, 3, 'Z'))
            polo = avanti + lato * 0.25
            polo = (polo - u * polo.dot(u)).normalized()
            aa = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
            hh = math.sqrt(max(l1 * l1 - aa * aa, 0.0))
            gin = anca + u * aa + polo * hh
            pbs[f'coscia.{s}'].matrix = _matrice_osso(B[f'coscia.{s}'].to_3x3(), gin - anca, anca)
            bpy.context.view_layer.update()
            pbs[f'stinco.{s}'].matrix = _matrice_osso(B[f'stinco.{s}'].to_3x3(), anca + u * dist - gin, gin)
            bpy.context.view_layer.update()
            # piede: piatto come a riposo, girato con la radice; nel passo la punta scende un poco
            Bp = B[f'piede.{s}'].to_3x3()
            Rp = Matrix.Rotation(yaw_p, 3, 'Z') @ Matrix.Rotation(math.radians(-25 * alzata), 3, 'X') @ Bp
            Mp = Rp.to_4x4(); Mp.translation = pbs[f'stinco.{s}'].tail.copy()
            pbs[f'piede.{s}'].matrix = Mp
            bpy.context.view_layer.update()
        if f in (int(A.FASI['MINACCIA'] * A.FPS), int((A.FASI['MINACCIA'] + 1.6) * A.FPS)):
            bt = arm.matrix_world @ pbs['testa'].tail
            bm_ = arm.matrix_world @ pbs['mascella'].tail
            print(f'BOCCA t={t:.2f}: muso {tuple(round(c, 3) for c in bt)} mento {tuple(round(c, 3) for c in bm_)}')
        for pb in pbs:
            pb.keyframe_insert('rotation_quaternion', frame=f)
            pb.keyframe_insert('location', frame=f)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.scene.frame_start = 0; bpy.context.scene.frame_end = n - 1
    return dati


def costruisci():
    mesh = BOCCA.carica()
    mesh.name = 'MostroSqualo_corpo'
    bocca = BOCCA.costruisci(mesh)
    arm = scheletro()
    pesa(mesh, arm, bocca)
    piedi = A.Piedi({'L': G['caviglia.L'], 'R': G['caviglia.R']})
    dati = cuoci(arm, piedi)
    return mesh, arm, dati


def esporta(mesh, arm, dati):
    for o in bpy.context.scene.objects:
        o.select_set(o in (mesh, arm))
    bpy.ops.export_scene.gltf(filepath=USCITA, export_format='GLB', use_selection=True,
                              export_image_format='JPEG', export_jpeg_quality=90, export_yup=True,
                              export_animations=True, export_animation_mode='ACTIONS',
                              export_force_sampling=True, export_skins=True, export_def_bones=True)
    with open(USCITA.replace('.glb', '.json'), 'w') as f:
        json.dump(dati, f, indent=1)
    print('ESPORTATO', USCITA, dati)


def anteprime(cartella, tempi, dati):
    """Render dalla faccia del giocatore (e uno di lato) in alcuni istanti, per controllare la scena."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 16; sc.cycles.use_denoising = True
    sc.render.resolution_x = 960; sc.render.resolution_y = 540
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs[1].default_value = 0.6
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 18
    l = bpy.data.objects.new('luce', bpy.data.lights.new('luce', 'POINT'))
    l.data.energy = 150; l.location = (0.8, -1.0, 2.5); sc.collection.objects.link(l)
    for t in tempi:
        sc.frame_set(int(t * A.FPS))
        x, y, _ = A.radice(t)
        for nome, pos, tgt in (('occhi', (0, A.GIOCATORE_Y, 1.05), (0, 2.0, 1.0)),
                               ('lato', (3.2, 1.5, 1.4), (0, 1.5, 1.0)),
                               ('testa', (1.3, y - 1.6, 1.3), (0.1, y - 0.9, 1.0))):
            cam.location = pos
            cam.rotation_euler = (Vector(tgt) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
            sc.render.filepath = os.path.join(cartella, f'{nome}_{t:05.2f}.png')
            bpy.ops.render.render(write_still=True)


if __name__ == '__main__' and 'ossa' not in sys.argv:
    mesh, arm, dati = costruisci()
    if 'anteprime' in sys.argv:
        tempi = [float(x) for x in sys.argv[sys.argv.index('anteprime') + 1].split(',')]
        anteprime(sys.argv[-1], tempi, dati)
    else:
        esporta(mesh, arm, dati)
