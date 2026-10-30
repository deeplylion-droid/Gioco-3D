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
    'mento': (0.14, -1.05, 1.40), 'bocca': (0.14, -1.02, 1.50), 'bocca_avanti': (0.14, -1.22, 1.50),
    'mento_avanti': (0.14, -1.20, 1.38),
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
    ('radice', None, None, None, True),    # senza pesi, ma "deforma" così il glTF lo esporta (il moto della corsa è suo)
    ('bacino', 'bacino', 'spina', 'radice', True),
    ('spina', 'spina', 'petto', 'bacino', True),
    ('petto', 'petto', 'collo', 'spina', True),
    ('collo', 'collo', 'testa', 'petto', True),
    ('testa', 'testa', 'muso', 'collo', True),
    ('mascella', 'testa', 'mento', 'testa', True),
    # senza pesi: segna il centro della bocca per il gioco (la camera la guarda, il fiato parte da lì)
    ('bocca', 'bocca', 'bocca_avanti', 'testa', True),
    ('mento_punta', 'mento', 'mento_avanti', 'mascella', True),
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
    ossa = [b for b in arm.data.bones if b.use_deform and b.name not in ('bocca', 'mento_punta', 'radice')]
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
    # testa e mascella con il peso della mascella di mostro_bocca. La parte del vertice che segue la testa
    # (testa + mascella) è almeno quella data dai pesi per distanza; nel muso, nella sacca e nei denti è
    # tutta; tra le due una sfumatura liscia sulla superficie (se no sotto il mento, dove il peso della
    # mascella si spegne, la pelle passava di colpo dal collo alla testa: un gradino quando la testa gira)
    nomi = [b.name for b in ossa]
    kt, km = nomi.index('testa'), nomi.index('mascella')
    pm = np.asarray(bocca['peso'], np.float64)
    tutta = (np.asarray(bocca['lab']) != 0) | (pm > 0.9)
    a = tutta.astype(np.float64)
    for _ in range(60):
        a = np.maximum(Lm @ a, tutta)
    ht = np.maximum(W[:, kt] + W[:, km], a)
    altre = W.copy(); altre[:, [kt, km]] = 0.0
    s_alt = altre.sum(1, keepdims=True)
    altre = np.where(s_alt > 1e-9, altre / np.maximum(s_alt, 1e-9), 0.0) * (1.0 - ht)[:, None]
    W = altre
    W[:, kt] = ht * (1.0 - pm)
    W[:, km] = ht * pm
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


NORD_MAX = [-9.0]
VICINO_MUSO = [9.0]
SPINTA = {'L': Vector((0, 0, 0)), 'R': Vector((0, 0, 0))}
VEL_SPINTA = {'L': Vector((0, 0, 0)), 'R': Vector((0, 0, 0))}
MOLLA = 10.0             # rad/s della molla che porta la spinta delle braccia (via dal muso) dove serve
VICINO_MUSO_DOVE = ['']


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
            pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
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
        # nel vano della porta il busto si stringe di lato (è largo 1,4 m, il vano 1,22): la x locale della spina è
        # quella del mondo (l'osso va in su)
        pbs['spina'].scale = (posa.get('_stringi', 1.0), 1.0, 1.0)
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
        # braccia: IK a due ossa verso la mano, il gomito in fuori e un po' indietro
        for s in ('L', 'R'):
            spalla = pbs[f'braccio.{s}'].head.copy()
            off = posa['_mano.' + s].copy()
            off.rotate(Matrix.Rotation(yaw, 3, 'Z'))
            mano = spalla + off
            # il muro nord del corridoio: la mano che ci va vicino si ritira verso il corpo, morbida, e il polso non
            # passa A.MANI_NORD (nel giro, col corpo di traverso, la mano sinistra in avanti entrava nel muro)
            if mano.x > A.MANI_NORD - 0.12 and t < A.tempo_alla_porta():
                mano.x = A.MANI_NORD - 0.12 + 0.12 * math.tanh((mano.x - A.MANI_NORD + 0.12) / 0.12)
            NORD_MAX[0] = max(NORD_MAX[0], (spalla + off).x)
            # (lo stesso limite per la mano spostata via dal muso, qui sotto)
            def _nord(m):
                if m.x > A.MANI_NORD - 0.12 and t < A.tempo_alla_porta():
                    m.x = A.MANI_NORD - 0.12 + 0.12 * math.tanh((m.x - A.MANI_NORD + 0.12) / 0.12)
                return m
            l1, l2 = lung[f'braccio.{s}'], lung[f'avambraccio.{s}']
            lato = Vector((1 if s == 'L' else -1, 0, 0)); lato.rotate(Matrix.Rotation(yaw, 3, 'Z'))
            polo0 = lato * 0.8 - avanti * 0.4 + Vector((0, 0, -0.2))
            # nel giro il gomito del braccio alzato va giù, in guardia: la testa resta sul giocatore e passa sopra la
            # spalla destra (a 21 cm dal mento), e col gomito all'altezza della spalla gli passava a 8 cm
            if s == 'R':
                giu = A.liscio(0.0, 1.0, A.FASI['GIRO'] - 0.4, A.FASI['GIRO'] - 0.1, t) - \
                    A.liscio(0.0, 1.0, A.FASI['CORSA'] + 0.4, A.FASI['CORSA'] + 0.8, t)
                polo0 = polo0.lerp(lato * 0.6 - avanti * 0.5 + Vector((0, 0, -0.6)), giu)

            def _ik(mano, polo):
                d = mano - spalla
                dist = min(max(d.length, abs(l1 - l2) + 0.02), (l1 + l2) * 0.995)
                u = d.normalized()
                pp = (polo - u * polo.dot(u)).normalized()
                aa = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
                hh = math.sqrt(max(l1 * l1 - aa * aa, 0.0))
                gomito = spalla + u * aa + pp * hh
                pbs[f'braccio.{s}'].matrix = _matrice_osso(pbs[f'braccio.{s}'].matrix.to_3x3(), gomito - spalla, spalla)
                bpy.context.view_layer.update()
                pbs[f'avambraccio.{s}'].matrix = _matrice_osso(pbs[f'avambraccio.{s}'].matrix.to_3x3(),
                                                               spalla + u * dist - gomito, gomito)
                bpy.context.view_layer.update()
                pm = pbs[f'mano.{s}']
                # (gli artigli vanno oltre la coda dell'osso della mano)
                punta = pm.tail + (pm.tail - pm.head).normalized() * 0.10
                return [('gomito', gomito), ('polso', pm.head.copy()), ('mano', pm.tail.copy()), ('artigli', punta)]

            # il braccio alzato resta accanto al muso, non ci entra (lo spazio fra braccio e testa, scelta A
            # dell'utente; ricontrolli del 30 ottobre: nel giro la testa resta sul giocatore e gira verso la mano
            # destra, che entrava nel muso con gli artigli fuori dalla bocca, e poi il gomito e gli artigli passavano
            # al mento). Dopo il richiamo gomito, polso, mano e artigli restano ad almeno A.MANO_MUSO da bocca,
            # mascella e mento: se no la mano si sposta via (e un poco in giù), o il gomito si apre di lato
            polo = polo0.copy()
            # (si parte dalla spinta via dal muso del fotogramma prima: senza, ogni fotogramma la mano poteva passare
            # dall'altra parte del mento, con un salto di 75 cm, e a 60 fps nel mezzo il gomito gli passava dentro)
            obiettivo = mano.copy()
            base = SPINTA[s]
            mano = _nord(mano + base)
            punti = _ik(mano, polo)
            # (solo intorno al giro: fuori, la 0.3.16 restava già ad almeno 26 cm, e spinte qui le braccia raccolte alla
            # porta entravano nel battente)
            tp_ = A.tempo_alla_porta()
            alla_porta = tp_ - 0.5 < t < tp_ + 0.7
            if A.FASI['GIRO'] - 0.4 < t < A.FASI['CORSA'] + 0.8 or alla_porta:
                bocca = pbs['bocca'].head.copy()
                muso = [bocca, bocca.lerp(pbs['mento_punta'].head, 0.45), pbs['mento_punta'].head.copy(),
                        pbs['mascella'].head.copy(), pbs['mascella'].tail.copy(), pbs['testa'].tail.copy()]
                # quanto spingere: in una direzione fissa rispetto al corpo (in fuori, in giù e un poco indietro; alla
                # porta solo in giù: di lato le braccia entravano nel battente), di quanto basta perché gomito, polso,
                # mano e artigli stiano ad almeno A.MANO_MUSO da bocca, mascella e mento. La quantità cambia in modo
                # continuo da un fotogramma all'altro (cercata a passi di 1 cm), anche la direzione: la mano non salta
                # più dall'altra parte del mento (75 cm in un fotogramma) e non trema (terzo ricontrollo del 30 ottobre)
                if alla_porta:
                    verso = Vector((0, 0, -1.0))
                else:
                    verso = (lato + Vector((0, 0, -0.6)) - avanti * 0.3).normalized()
                k = 0.0
                while k < 0.6:
                    prova = _nord(obiettivo + verso * k)
                    punti = _ik(prova, polo)
                    if min((h - q).length for _n, h in punti for q in muso) >= A.MANO_MUSO:
                        break
                    k += 0.01
                mano = prova
                voluta = mano - obiettivo
            else:
                voluta = Vector((0, 0, 0))
            # la spinta segue quella voluta con una molla smorzata (velocità continua: niente scatti, né quando si
            # accende né quando si spegne; terzo ricontrollo del 30 ottobre, la mano sinistra tremava alla porta)
            dt_ = 1.0 / A.FPS
            VEL_SPINTA[s] += (MOLLA ** 2 * (voluta - SPINTA[s]) - 2.0 * MOLLA * VEL_SPINTA[s]) * dt_
            mano = _nord(obiettivo + SPINTA[s] + VEL_SPINTA[s] * dt_)
            punti = _ik(mano, polo)
            if A.FASI['GIRO'] - 0.4 < t < A.FASI['CORSA'] + 0.8 or alla_porta:
                for nome_p, h in punti:
                    for q in muso:
                        if (h - q).length < VICINO_MUSO[0]:
                            VICINO_MUSO[0] = (h - q).length
                            VICINO_MUSO_DOVE[0] = '%s %s a %.2f s' % (nome_p, s, t)
            SPINTA[s] = mano - obiettivo
            if f == int(9.0 * A.FPS):
                print('MANO', s, 'spalla', tuple(round(c, 2) for c in spalla), 'obiettivo', tuple(round(c, 2) for c in mano),
                      'ottenuta', tuple(round(c, 2) for c in pbs[f'avambraccio.{s}'].tail))
        for pb in pbs:
            pb.keyframe_insert('rotation_quaternion', frame=f)
            pb.keyframe_insert('location', frame=f)
            pb.keyframe_insert('scale', frame=f)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.scene.frame_start = 0; bpy.context.scene.frame_end = n - 1
    bpy.context.scene.render.fps = A.FPS; bpy.context.scene.render.fps_base = 1.0
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
    # il bordo delle labbra (per la bava: scripts/interni/bava_squalo.gd)
    with open(USCITA.replace('.glb', '_labbra.json'), 'w') as f:
        json.dump(BOCCA.LABBRA, f)
    print('ESPORTATO', USCITA, dati)
    print('MANI: la più a nord senza il muro a x %.2f; il braccio più vicino al muso %.2f m (%s)' % (NORD_MAX[0], VICINO_MUSO[0], VICINO_MUSO_DOVE[0]))


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
    # una luce rossa dietro la testa, come le lampade del corridoio: se la bocca ha buchi, passa
    l2 = bpy.data.objects.new('dietro', bpy.data.lights.new('dietro', 'POINT'))
    l2.data.energy = 300; l2.data.color = (1, 0.1, 0.05); l2.location = (0.1, 0.4, 1.9); sc.collection.objects.link(l2)
    for t in tempi:
        sc.frame_set(int(t * A.FPS))
        x, y, _ = A.radice(t)
        bocca_c = (arm.matrix_world @ arm.pose.bones['bocca'].head).lerp(arm.matrix_world @ arm.pose.bones['mento_punta'].head, 0.45)
        for nome, pos, tgt in (('occhi', (0, A.GIOCATORE_Y, 1.05), (0, 2.0, 1.0)),
                               ('vicino', (0.05, A.GIOCATORE_Y + 0.15, 1.02), tuple(bocca_c)),
                               ('angolo', (0.65, A.GIOCATORE_Y + 0.35, 1.15), tuple(bocca_c)),
                               ('angolo_sx', (-0.55, A.GIOCATORE_Y + 0.35, 1.2), tuple(bocca_c)),
                               ('lato', (3.2, 1.5, 1.4), (0, 1.5, 1.0)),
                               ('testa', (1.3, y - 1.6, 1.3), (0.1, y - 0.9, 1.0))):
            cam.location = pos
            cam.rotation_euler = (Vector(tgt) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
            sc.render.filepath = os.path.join(cartella, f'{nome}_{t:05.2f}.png')
            bpy.ops.render.render(write_still=True)


def striscia(cartella, t0, t1, n, nome='striscia'):
    """n fotogrammi tra t0 e t1 visti di lato, con la camera che segue la radice, in una sola immagine."""
    from PIL import Image
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 8; sc.cycles.use_denoising = True
    sc.render.resolution_x = 400; sc.render.resolution_y = 500
    sc.world = bpy.data.worlds.new('w'); sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs[1].default_value = 3.5
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 2.8
    sole = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN'))
    sole.data.energy = 4.0; sole.rotation_euler = (math.radians(50), 0, math.radians(70))
    sc.collection.objects.link(sole)
    pezzi = []
    for k in range(n):
        t = t0 + (t1 - t0) * k / max(n - 1, 1)
        sc.frame_set(int(round(t * A.FPS)))
        x, y, _ = A.radice(t)
        cam.location = (4.0, y, 1.1); cam.rotation_euler = (math.pi / 2, 0, math.pi / 2)
        f = os.path.join(cartella, f'_s{k:02d}.png'); sc.render.filepath = f
        bpy.ops.render.render(write_still=True)
        pezzi.append(Image.open(f).convert('RGB'))
    col = min(n, 4)
    g = Image.new('RGB', (400 * col, 500 * ((n + col - 1) // col)))
    for k, im in enumerate(pezzi):
        g.paste(im, (400 * (k % col), 500 * (k // col)))
    g.save(os.path.join(cartella, nome + '.jpg'))


if __name__ == '__main__' and 'ossa' not in sys.argv:
    mesh, arm, dati = costruisci()
    if 'striscia' in sys.argv:
        a, b, n = sys.argv[sys.argv.index('striscia') + 1].split(',')
        striscia(sys.argv[-1], float(a), float(b), int(n))
    elif 'anteprime' in sys.argv:
        tempi = [float(x) for x in sys.argv[sys.argv.index('anteprime') + 1].split(',')]
        anteprime(sys.argv[-1], tempi, dati)
    else:
        esporta(mesh, arm, dati)
