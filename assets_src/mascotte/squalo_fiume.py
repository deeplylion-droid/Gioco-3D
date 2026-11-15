"""Lo squalo nel fiume lento (build 0.5.0 «La storia», scelta A; GDD del 15 novembre): i movimenti del mostro-squalo A
nell'acqua. Di lui si vedono solo la pinna dorsale e la scia mentre segue la ciambella, e la testa con la bocca aperta
quando attacca: il corpo resta sotto l'acqua scura.

Parte dallo scheletro del risveglio (godot/assets/models/mascotte/mostro_squalo_A_rig.glb, mostro_rig.py), mette le pose
fotogramma per fotogramma ed esporta godot/assets/models/mascotte/mostro_squalo_A_fiume.glb con le sole animazioni del
fiume (il risveglio resta nel suo file, non si tocca).

Spazio: quello del modello (x di lato, -y avanti, z su). Nel fiume l'origine è sul pelo dell'acqua (z = 0) e lui nuota
verso -y (in Godot +Z): il nodo dello squalo sta sul pelo, girato dove va.

Animazioni (30 fps):
  fiume_nuota (ciclo 1,6 s): sdraiato sotto il pelo, la pinna dorsale fuori (PINNA_FUORI), la coda e le gambe che
      battono di lato, le braccia lungo il corpo;
  fiume_emerge (0,6 s): dalla nuotata al tempo 0 la testa sale fuori dall'acqua e la bocca si spalanca;
  fiume_attacco (ciclo 1,0 s): la testa fuori a bocca spalancata che scuote e scatta, il corpo sotto;
  fiume_respinto (0,8 s): il getto sul muso: la testa scatta indietro, la bocca si chiude e va giù, tutto sotto
      (finisce nella posa della nuotata AFFONDO m più giù);
  fiume_morso (0,9 s): dalla posa dell'attacco scatta avanti e in alto e chiude la bocca a MORSO_T (il gioco porta la
      bocca davanti alla camera).

Controllo (--controlla): a ogni fotogramma, i vertici della pelle deformata sopra il pelo devono essere solo della
pinna (nella nuotata) o della testa (emerge, attacco, morso); nel respinto, alla fine, niente sopra.

Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python assets_src/mascotte/squalo_fiume.py \
        [--controlla] [--anteprime]
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
RIG = os.path.join(REPO, 'godot', 'assets', 'models', 'mascotte', 'mostro_squalo_A_rig.glb')
USCITA = os.path.join(REPO, 'godot', 'assets', 'models', 'mascotte', 'mostro_squalo_A_fiume.glb')
FPS = 30

PINNA_FUORI = 0.26       # quanto esce la punta della pinna dorsale dal pelo nella nuotata (m); era 0,22 ma ne usciva 0,17
AFFONDO = 0.9            # di quanto sta più giù alla fine del respinto (tutto sotto, pinna compresa)
APERTA = 38.0            # la bocca spalancata (gradi della mascella)
MORSO_T = 0.55           # quando la bocca si chiude nel morso (s); SqualoFiume.MORSO_T deve essere uguale
T_NUOTA = 1.6
T_EMERGE = 0.6
T_ATTACCO = 1.0
T_RESPINTO = 0.8
T_MORSO = 0.9
TESTA = ('testa', 'mascella', 'collo', 'bocca', 'mento_punta')


def liscio(a, b, t0, t1, t):
    if t <= t0:
        return a
    if t >= t1:
        return b
    u = (t - t0) / (t1 - t0)
    return a + (b - a) * u * u * (3 - 2 * u)


def chiavi(t, punti):
    if t <= punti[0][0]:
        return punti[0][1]
    for (t0, a), (t1, b) in zip(punti[:-1], punti[1:]):
        if t <= t1:
            u = (t - t0) / max(t1 - t0, 1e-9)
            u = u * u * (3 - 2 * u)
            return a + (b - a) * u
    return punti[-1][1]


def carica():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RIG)
    for o in list(bpy.data.objects):
        if o.name.startswith('Icosphere'):
            bpy.data.objects.remove(o)
    arm = bpy.data.objects['MostroSqualo']
    mesh = bpy.data.objects['MostroSqualo_corpo']
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()
    return arm, mesh


def aggiorna():
    bpy.context.view_layer.update()


def ruota(arm, nome, asse, gradi):
    """Gira l'osso intorno alla sua testa, asse nello spazio del modello."""
    if abs(gradi) < 1e-6:
        return
    pb = arm.pose.bones[nome]
    h = pb.head.copy()
    R = Matrix.Rotation(math.radians(gradi), 4, Vector(asse))
    pb.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ pb.matrix
    aggiorna()


def dirigi(arm, nome, verso):
    """Gira l'osso (intorno alla sua testa, il meno possibile) perché punti verso [verso] (spazio del modello)."""
    pb = arm.pose.bones[nome]
    y = (pb.tail - pb.head).normalized()
    v = Vector(verso).normalized()
    q = y.rotation_difference(v)
    h = pb.head.copy()
    pb.matrix = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ pb.matrix
    aggiorna()


def azzera(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    aggiorna()


# Il verso della mascella che si apre: si sceglie il segno che abbassa il mento (vedi main).
SEGNO_BOCCA = [1.0]


def bocca(arm, gradi):
    ruota(arm, 'mascella', (1, 0, 0), SEGNO_BOCCA[0] * gradi)


def mix3(a, b, k):
    return tuple(x + (y - x) * k for x, y in zip(a, b))


def corpo_in_acqua(arm, t, battito=1.0, testa_su=0.0, apri=0.0, scuoti=0.0, periodo=T_NUOTA, dritto=0.0):
    """Dopo [piazza] (il corpo già girato e messo), le membra nelle direzioni del mondo: braccia lungo i fianchi
    verso la coda, gambe e coda distese indietro, che battono di lato (la coda) e in su e in giù (le gambe), la testa
    avanti, alzata di testa_su gradi (fuori dall'acqua quando attacca), la bocca aperta di apri gradi."""
    u = 2 * math.pi * t / periodo
    # (dritto: quando attacca il corpo sta in piedi nell'acqua e le membra pendono giù, così fuori c'è solo la testa)
    for s, sx in (('L', 1), ('R', -1)):
        dirigi(arm, f'braccio.{s}', mix3((0.30 * sx, 1.0, -0.35), (0.35 * sx, 0.25, -1.0), dritto))
        dirigi(arm, f'avambraccio.{s}', mix3((0.15 * sx, 1.0, -0.20), (0.15 * sx, 0.1, -1.0), dritto))
        dirigi(arm, f'mano.{s}', mix3((0.08 * sx, 1.0, -0.15), (0.05 * sx, 0.1, -1.0), dritto))
    for s, sx, fase in (('L', 1, 0.0), ('R', -1, math.pi)):
        k = battito * 0.22 * math.sin(u + fase)
        dirigi(arm, f'coscia.{s}', mix3((0.10 * sx, 1.0, -0.20 + k), (0.12 * sx, 0.35 + k, -1.0), dritto))
        dirigi(arm, f'stinco.{s}', mix3((0.05 * sx, 1.0, -0.12 + k * 1.3), (0.08 * sx, 0.45 + k, -1.0), dritto))
        dirigi(arm, f'piede.{s}', mix3((0.0, 1.0, -0.05 + k * 1.6), (0.0, 0.6 + k, -1.0), dritto))
    # (la coda giù di traverso: la punta, che si piega in su, sta sotto il pelo anche con la pinna più fuori)
    for i, n in enumerate(('coda1', 'coda2', 'coda3')):
        a = battito * 0.35 * math.sin(u - 0.8 * (i + 1))
        dirigi(arm, n, mix3((a, 1.0, -0.50), (a, 0.6, -1.0), dritto))
    ruota(arm, 'spina', (0, 0, 1), battito * 3.0 * math.sin(u + 1.2))
    alto = math.tan(math.radians(testa_su))
    dirigi(arm, 'collo', (0.0, -1.0, 0.10 + alto * 0.7))
    dirigi(arm, 'testa', (scuoti * 0.12 * math.sin(2 * math.pi * t * 2.0 + 0.5), -1.0,
                         0.05 + alto + scuoti * 0.10 * math.sin(2 * math.pi * t * 3.0)))
    if apri:
        bocca(arm, apri)


def piazza(arm, inclina, alza, avanti=0.0, lato=0.0, imbarda=0.0):
    """Tutto lui, girato in avanti di inclina gradi intorno all'asse di lato (INCLINA_NUOTO: col dorso orizzontale,
    sdraiato; meno: più dritto, la testa più su), poi spostato in su di alza (m), avanti (verso -y), di lato; imbarda
    (gradi) intorno alla verticale. Il perno è il bacino."""
    pb = arm.pose.bones['radice']
    perno = arm.pose.bones['bacino'].head.copy()
    R = Matrix.Rotation(math.radians(imbarda), 4, 'Z') @ Matrix.Rotation(math.radians(inclina), 4, 'X')
    M = Matrix.Translation(Vector((lato, -avanti, alza))) @ Matrix.Translation(perno) @ R @ Matrix.Translation(-perno)
    pb.matrix = M @ pb.matrix
    aggiorna()


# il dorso (dal bacino al collo) orizzontale: nella posa del modello è chino di circa 30 gradi
INCLINA_NUOTO = 30.0
INCLINA_ATTACCO = -25.0
TESTA_SU = 45.0          # quanto alza la testa nell'attacco (gradi)
# Dove sta il bacino perché la pinna esca di PINNA_FUORI (calcolato in main, sulla pelle vera)
ALZA_NUOTO = [0.0]
ALZA_ATTACCO = [0.0]


def pose_nuota(arm, t, giu=0.0):
    azzera(arm)
    u = 2 * math.pi * t / T_NUOTA
    piazza(arm, INCLINA_NUOTO, ALZA_NUOTO[0] - giu + 0.015 * math.sin(2 * u), imbarda=3.0 * math.sin(u + 0.4))
    corpo_in_acqua(arm, t)


def pose_emerge(arm, t):
    k = liscio(0.0, 1.0, 0.0, T_EMERGE * 0.85, t)
    azzera(arm)
    piazza(arm, INCLINA_NUOTO + (INCLINA_ATTACCO - INCLINA_NUOTO) * k, ALZA_NUOTO[0] + (ALZA_ATTACCO[0] - ALZA_NUOTO[0]) * k)
    corpo_in_acqua(arm, t, battito=1.0 + 0.6 * k, testa_su=TESTA_SU * k, apri=APERTA * liscio(0.0, 1.0, 0.15, T_EMERGE, t), dritto=k)


def pose_attacco(arm, t):
    azzera(arm)
    u = 2 * math.pi * t / T_ATTACCO
    morsetti = 6.0 * max(0.0, math.sin(2 * u))
    piazza(arm, INCLINA_ATTACCO + 3.0 * math.sin(u), ALZA_ATTACCO[0] + 0.03 * math.sin(2 * u), avanti=0.04 * math.sin(u),
           imbarda=6.0 * math.sin(u + 0.8))
    corpo_in_acqua(arm, t, battito=1.6, testa_su=TESTA_SU, apri=APERTA - morsetti, scuoti=1.0 - math.cos(u),
                   periodo=T_ATTACCO, dritto=1.0)


def pose_respinto(arm, t):
    # la testa scatta indietro (0-0,15), la bocca si chiude, si stende e affonda (fino ad AFFONDO sotto la nuotata)
    k = liscio(0.0, 1.0, 0.1, T_RESPINTO, t)
    indietro = chiavi(t, [(0.0, 0.0), (0.12, 1.0), (0.35, 0.6), (T_RESPINTO, 0.0)])
    azzera(arm)
    piazza(arm, INCLINA_ATTACCO + (INCLINA_NUOTO - INCLINA_ATTACCO) * k + 6.0 * indietro,
           ALZA_ATTACCO[0] + (ALZA_NUOTO[0] - AFFONDO - ALZA_ATTACCO[0]) * k - 0.06 * indietro, avanti=-0.25 * indietro)
    corpo_in_acqua(arm, t, battito=1.6 - 0.6 * k, testa_su=TESTA_SU * (1 - k) + 20.0 * indietro,
                   apri=APERTA * (1.0 - liscio(0.0, 1.0, 0.05, 0.3, t)), dritto=1.0 - k)


def pose_morso(arm, t):
    # dalla posa dell'attacco al tempo 0: si raccoglie (0-0,2), scatta avanti e su (0,2-MORSO_T), chiude di colpo
    carica = chiavi(t, [(0.0, 0.0), (0.2, 1.0), (MORSO_T - 0.1, 0.0)])
    scatto = liscio(0.0, 1.0, 0.2, MORSO_T, t)
    chiudi = liscio(0.0, 1.0, MORSO_T - 0.08, MORSO_T, t)
    azzera(arm)
    piazza(arm, INCLINA_ATTACCO + 6.0 * scatto, ALZA_ATTACCO[0] + 0.02 * scatto - 0.05 * carica,
           avanti=0.9 * scatto - 0.15 * carica)
    corpo_in_acqua(arm, t, battito=1.6 + 1.0 * scatto, testa_su=TESTA_SU + 12.0 * scatto - 8.0 * carica,
                   apri=(APERTA + 6.0 * scatto) * (1.0 - chiudi) - 4.0 * chiudi, periodo=T_ATTACCO, dritto=1.0)


ANIMAZIONI = {
    'fiume_nuota': (T_NUOTA, True, pose_nuota),
    'fiume_emerge': (T_EMERGE, False, pose_emerge),
    'fiume_attacco': (T_ATTACCO, True, pose_attacco),
    'fiume_respinto': (T_RESPINTO, False, pose_respinto),
    'fiume_morso': (T_MORSO, False, pose_morso),
}
# chi può stare sopra il pelo in ogni animazione
FUORI_PERMESSO = {
    'fiume_nuota': 'pinna',
    'fiume_emerge': 'testa',
    'fiume_attacco': 'testa',
    'fiume_respinto': 'testa',
    'fiume_morso': 'testa',
}


class Pelle:
    """La pelle deformata (vertici nel mondo) e, per ogni vertice, l'osso che lo muove di più."""

    def __init__(self, arm, mesh):
        self.arm, self.mesh = arm, mesh
        gruppi = {g.index: g.name for g in mesh.vertex_groups}
        self.osso = []
        for v in mesh.data.vertices:
            best, w = '', -1.0
            for g in v.groups:
                if g.weight > w:
                    best, w = gruppi.get(g.group, ''), g.weight
            self.osso.append(best)
        self.osso = np.array(self.osso)
        # la pinna dorsale: nella posa di riposo, i vertici dietro la schiena (y oltre la pelle del dorso) fra le spalle
        co = self.riposo()
        # (la pinna sta un poco a destra del centro, x 0,1-0,2, sopra il dorso: la punta a z 2,2 nella posa del modello)
        self.pinna = (co[:, 0] > -0.05) & (co[:, 0] < 0.32) & (co[:, 2] > 1.80) & (co[:, 1] > 0.0) & (co[:, 1] < 0.8) \
            & np.isin(self.osso, ['spina', 'petto', 'bacino'])

    def riposo(self):
        return np.array([self.mesh.matrix_world @ v.co for v in self.mesh.data.vertices])

    def ora(self):
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        me = self.mesh.evaluated_get(dg)
        m = me.to_mesh()
        co = np.empty(len(m.vertices) * 3)
        m.vertices.foreach_get('co', co)
        me.to_mesh_clear()
        co = co.reshape(-1, 3)
        M = np.array(self.mesh.matrix_world)
        return co @ M[:3, :3].T + M[:3, 3]


def main():
    arm, mesh = carica()
    pelle = Pelle(arm, mesh)
    print('PINNA: %d vertici' % int(pelle.pinna.sum()), flush=True)
    # il verso della bocca
    azzera(arm)
    mento0 = (arm.matrix_world @ arm.pose.bones['mento_punta'].head).z
    bocca(arm, 20.0)
    if (arm.matrix_world @ arm.pose.bones['mento_punta'].head).z > mento0:
        SEGNO_BOCCA[0] = -1.0
    # quanto alzare. Nella nuotata: la punta della pinna a PINNA_FUORI, e tutto il resto (pinna a parte) almeno 3 cm
    # sotto il pelo. Nell'attacco: tutto quello che non è testa o pinna almeno 3 cm sotto (fuori la testa).
    testa_o_pinna = np.isin(pelle.osso, TESTA) | pelle.pinna
    azzera(arm)
    piazza(arm, INCLINA_NUOTO, 0.0)
    corpo_in_acqua(arm, 0.0)
    co = pelle.ora()
    ALZA_NUOTO[0] = min(PINNA_FUORI - float(co[pelle.pinna, 2].max()), -0.03 - float(co[~pelle.pinna, 2].max()))
    # (nell'attacco esce la testa a bocca aperta col collo e la gobba del dorso dietro, come uno squalo che si butta
    # avanti: braccia, gambe, coda e pancia restano sotto)
    alto_dorso = TESTA + ('spina', 'petto', 'clavicola.L', 'clavicola.R')
    sotto_sempre = ~np.isin(pelle.osso, alto_dorso) & ~pelle.pinna
    peggio, mento = -9.0, 9.0
    for k in range(9):
        azzera(arm)
        piazza(arm, INCLINA_ATTACCO, 0.0)
        corpo_in_acqua(arm, k * T_ATTACCO / 8, battito=1.6, testa_su=TESTA_SU, apri=APERTA, scuoti=1.0 - math.cos(2 * math.pi * k / 8),
                       periodo=T_ATTACCO, dritto=1.0)
        co = pelle.ora()
        peggio = max(peggio, float(co[sotto_sempre, 2].max()))
        mento = min(mento, (arm.matrix_world @ arm.pose.bones['mento_punta'].tail).z)
    # il mento (la punta della bocca aperta) fuori di 8 cm, se le membra restano sotto; se no, le membra comandano
    ALZA_ATTACCO[0] = min(0.08 - mento, -0.04 - peggio)
    print('ATTACCO: per il mento fuori %.3f, per le membra sotto %.3f' % (0.08 - mento, -0.04 - peggio), flush=True)
    azzera(arm)
    piazza(arm, INCLINA_ATTACCO, ALZA_ATTACCO[0])
    corpo_in_acqua(arm, 0.0, battito=1.6, testa_su=TESTA_SU, apri=APERTA, periodo=T_ATTACCO, dritto=1.0)
    co = pelle.ora()
    b_ = arm.matrix_world @ arm.pose.bones['bocca'].head
    print('ALZA nuoto %.3f (pinna fuori %.2f), attacco %.3f: testa fuori fino a %.2f m, bocca a %.2f m, mento a %.2f m' % (
        ALZA_NUOTO[0], PINNA_FUORI, ALZA_ATTACCO[0], float(co[np.isin(pelle.osso, TESTA), 2].max()), b_.z,
        (arm.matrix_world @ arm.pose.bones['mento_punta'].tail).z), flush=True)
    dati = {'fps': FPS, 'pinna_fuori': PINNA_FUORI, 'affondo': AFFONDO, 'morso_t': MORSO_T, 'animazioni': {}}
    controlla = '--controlla' in sys.argv
    for nome, (durata, ciclo, fn) in ANIMAZIONI.items():
        act = bpy.data.actions.new(nome)
        arm.animation_data_create()
        arm.animation_data.action = act
        n = int(round(durata * FPS))
        fuori_male = 0
        dove = ''
        for i in range(n + 1):
            t = 0.0 if (ciclo and i == n) else i / FPS
            fn(arm, t)
            for pb in arm.pose.bones:
                pb.keyframe_insert('rotation_quaternion', frame=i)
                pb.keyframe_insert('location', frame=i)
                pb.keyframe_insert('scale', frame=i)
            if controlla:
                co = pelle.ora()
                sopra = co[:, 2] > 0.0
                if FUORI_PERMESSO[nome] == 'pinna':
                    male = sopra & ~pelle.pinna
                else:
                    male = sopra & ~np.isin(pelle.osso, TESTA + ('spina', 'petto', 'clavicola.L', 'clavicola.R')) & ~pelle.pinna
                if nome == 'fiume_respinto' and i == n:
                    male = sopra
                if male.any():
                    fuori_male += 1
                    if not dove:
                        ossa, conti = np.unique(pelle.osso[male], return_counts=True)
                        dove = 't=%.2f: %s, fino a %.2f m' % (t, dict(zip(ossa.tolist(), conti.tolist())), float(co[male, 2].max()))
        act.use_fake_user = True
        # per il gioco: dove sta la bocca alla fine (e nel morso a MORSO_T), nello spazio del modello
        fn(arm, MORSO_T if nome == 'fiume_morso' else 0.0)
        b = arm.matrix_world @ arm.pose.bones['bocca'].head
        dati['animazioni'][nome] = {'durata': durata, 'ciclo': ciclo, 'bocca': [round(b.x, 3), round(b.y, 3), round(b.z, 3)]}
        print('ANIMAZIONE %s: %d fotogrammi' % (nome, n + 1) + ('; fuori dall acqua senza permesso in %d fotogrammi%s' % (fuori_male, (' (' + dove + ')') if dove else '') if controlla else ''), flush=True)
    arm.animation_data.action = bpy.data.actions['fiume_nuota']
    # esporta: lo scheletro e la pelle, solo le animazioni del fiume
    for o in bpy.context.scene.objects:
        o.select_set(o in (mesh, arm))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=USCITA, export_format='GLB', use_selection=True,
                              export_image_format='NONE', export_yup=True,
                              export_animations=True, export_animation_mode='ACTIONS',
                              export_force_sampling=True, export_skins=True, export_def_bones=True)
    with open(USCITA.replace('.glb', '.json'), 'w') as f:
        json.dump(dati, f, indent=1)
    print('ESPORTATO', USCITA, os.path.getsize(USCITA) // 1024, 'KB', flush=True)


if __name__ == '__main__':
    main()
