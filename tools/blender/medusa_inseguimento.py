"""Animazioni di lei per l'inseguimento (I1 e SB1, sala_inseguimento di ambienti-2).

Non tocca medusa.glb: legge lo scheletro da assets_src/medusa/medusa.glb, costruisce le pose fotogramma per
fotogramma e scrive le trasformazioni locali di ogni osso nello stesso riferimento dei nodi del GLB (quello
che usa lo Skeleton3D di Godot). Da questo file Godot fa la libreria di animazioni
(godot/assets/models/medusa/medusa_inseguimento.res, con godot/tools/medusa_inseguimento_libreria.gd): si
aggiunge all'AnimationPlayer di lei e le animazioni si chiamano "inseguimento/<nome>". Il giro
import/export di Blender non c'e', quindi le ossa non cambiano orientamento.

Le pose partono da quelle approvate del modello (sveglia, insegue, fluttua, fauce_apre, affacciata): i
tentacoli e le dita vengono da li', mescolati; il busto, la testa e le braccia (IK a due ossa di
medusa_pose) si muovono qui. Le due zampe incrociate sul petto (regola del GDD: il seno resta coperto,
medusa_attacco) seguono le ossa del busto a cui stanno appoggiate.

Spazio: quello del modello, origine sul piano d'appoggio dei tentacoli, lei guarda verso -Y di Blender (+Z
di Godot). Le animazioni portano anche lo spostamento in alto e in basso (osso radice): "su" e' l'altezza
della posa insegue, quella su cui ambienti-2 ha messo i posti di lei; a -5 m e' sparita sott'acqua.

Animazioni (30 fps):
  sale_dall_acqua (1,6 s), sale_dall_acqua_veloce (1,0 s, la grata): da -5 m su fino a busto e braccia fuori,
      finisce nella posa iniziale di incombe;
  sale_mano (1,6 s, la vasca 3; 0.3.21): esce prima la mano destra, che si posa sul bordo della vasca (BORDO_V3), poi si tira
      su; stessi tempi di sale_dall_acqua per il gioco e stessa posa finale;
  sale_puntata (1,6 s, la vasca 2; 0.3.21): sale piu' in fretta, dritta, con l'occhio gia' puntato su di te; stessi tempi
      di sale_dall_acqua per il gioco (passa 2,9 m sotto allo stesso istante) e stessa posa finale;
  incombe (ciclo 2,4 s): si sporge verso il giocatore con le braccia tese, ondeggia, le dita si aprono e si
      chiudono (la testa che segue il giocatore la fa il gioco: MedusaAffacciata.segui_con_la_testa);
  presa (1,2 s): si ritrae, scatta in avanti e afferra a GRAB (davanti, all'altezza della testa di chi e'
      nella vasca), poi tira verso di se' (la fauce la apre la libreria in Godot, con le blend shape di
      fauce_apre);
  respinta (1,2 s): getto in faccia, la testa scatta indietro, si copre il viso e torna sotto (-5 m);
  scende (1,0 s): torna sotto senza essere respinta;
  colpo_grata (0,5 s, in ciclo): carica e sbatte i palmi contro la grata, a GRATA metri davanti;
  colpo_grata_sbieco (0,5 s, in ciclo): lo stesso con la grata girata di SBIECO gradi (dal pozzetto dietro la grata);
  affacciata_sb1 (5,4 s): sbuca dal pozzo in 1,3 s e si aggrappa al bordo (BORDO_SB1: a tanto davanti e
      tanto in alto rispetto all'origine), la testa girata di lato, poi la gira verso di te e ti fissa;
  scende_sb1 (1,2 s): dall'ultimo fotogramma di affacciata_sb1 lascia il bordo e scivola giu' nel pozzo, mai su.
Il tunnel del viaggio sottomarino (24 ottobre), a bocca spalancata (nel json anche "fauce": quanto e' aperta la
fauce a ogni fotogramma, per le blend shape):
  insegue_aperta (ciclo 2,6 s): fluttua intera, inclinata in avanti, braccia tese, scia dei tentacoli;
  insegue_morde (ciclo 2,6 s): lo stesso con due morsi a vuoto (MORSI), da usare quando e' vicina;
  ritrae (2 s): il getto in faccia, si ritrae e torna nella posa di insegue_aperta al tempo 0;
  tuffo_sb1 (1,3 s): dopo affacciata_sb1 si stacca dal bordo e si tuffa nel pozzo;
  riemerge (1,8 s): dal fondo su nella posa di insegue_aperta al tempo 0, la bocca che si spalanca;
  schianto (2,4 s): contro il portello, la faccia sull'oblo' (OBLO) e i palmi ai lati, poi resta premuta.
  carica (2 s, 0.4.0): smette di cantare, si tira indietro e si carica, bocca spalancata, poi ferma col tremito;
  scatto (0,8 s, 0.4.0): dalla fine di carica parte in avanti e torna nella posa di insegue_aperta al tempo 0.

Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python \
         tools/blender/medusa_inseguimento.py [--anteprime] [--solo nome,nome]
Esce assets_src/medusa/build/inseguimento.json (rigenerato, non nel repository); con --anteprime anche i
fogli di controllo in assets_src/medusa/build/inseguimento_anteprime/.
"""
import json
import math
import os
import struct
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import medusa_pose as POSE  # noqa: E402

RADICE = os.path.abspath(os.path.join(QUI, '..', '..'))
GLB = os.path.join(RADICE, 'assets_src', 'medusa', 'medusa.glb')
BUILD = os.path.join(RADICE, 'assets_src', 'medusa', 'build')
USCITA = os.path.join(BUILD, 'inseguimento.json')
CARTELLA_ANTEPRIME = 'inseguimento_anteprime'       # in BUILD (medusa_spot.py usa la sua)
FPS = 30
FPS_AZIONI = 24                     # le azioni del GLB

GIU = -5.0                          # sparita sott'acqua (m, rispetto a "su")
GRAB = (0.0, -2.4, 3.85)           # dove afferra (spazio del modello, m): davanti, testa di chi e' nella vasca
GRATA = 2.3                         # la grata: piano verticale a tanti metri davanti all'origine
SBIECO = 75.0                       # colpo_grata_sbieco: la grata girata (più vicina a destra): dal pozzetto dietro la grata,
                                    # a 51 gradi; 75 nel modello perché lo slancio del busto la porta avanti a destra
BORDO_SB1 = (1.0, 0.8)              # SB1: lo spigolo del pozzo a tanto davanti e tanto sopra l'origine (m)

# la vasca 1 dell'inseguimento rispetto all'origine di lei (inseguimento_gioco.json: lei a -25,0, fondo
# -22,6, acqua -21,62): solo per le anteprime
VASCA = (2.4, 3.38)

Y0 = -0.10 - 0.06 * math.sin(0.6)   # incombe all'inizio del ciclo: quanto e' spostata in avanti

BUSTO = ('colonna_1', 'colonna_2', 'petto', 'collo', 'clavicola.L', 'clavicola.R', 'campana')
ZAMPE = ('tentacolo_01', 'tentacolo_06')        # le due zampe incrociate sul petto (le piu' davanti)
DITA = ('pollice', 'indice', 'medio', 'anulare', 'mignolo')

# da Blender (z in alto) al glTF / Godot (y in alto, -y di Blender = +z)
A = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
AI = A.inverted()


# --------------------------------------------------------------------------------------------- utilita'

def liscio(a, b, t0, t1, t):
    if t <= t0:
        return a
    if t >= t1:
        return b
    u = (t - t0) / (t1 - t0)
    u = u * u * (3 - 2 * u)
    return a + (b - a) * u


def chiavi(t, punti):
    """Curva liscia per chiavi [(t, valore)] (valori numeri o tuple)."""
    if t <= punti[0][0]:
        return punti[0][1]
    for (ta, va), (tb, vb) in zip(punti, punti[1:]):
        if t <= tb:
            if isinstance(va, tuple):
                return tuple(liscio(x, y, ta, tb, t) for x, y in zip(va, vb))
            return liscio(va, vb, ta, tb, t)
    return punti[-1][1]


def mix_m(a, b, t):
    if t <= 0:
        return a.copy()
    if t >= 1:
        return b.copy()
    la, ra, sa = a.decompose()
    lb, rb, sb = b.decompose()
    if ra.dot(rb) < 0:
        rb = -rb
    return Matrix.LocRotScale(la.lerp(lb, t), ra.slerp(rb, t), sa.lerp(sb, t))


def mix(pa, pb, t, ossa=None):
    """Due pose (osso -> matrix_basis) mescolate; 'ossa' limita il mescolamento a quelle (le altre da pa)."""
    out = dict(pa)
    for n in (ossa if ossa is not None else pa.keys()):
        out[n] = mix_m(pa[n], pb[n], t)
    return out


def aggiorna():
    bpy.context.view_layer.update()


# --------------------------------------------------------------------------------------------- il modello

def carica():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    ico = bpy.data.objects.get('Icosphere')
    if ico:
        ico.hide_render = True
        ico.hide_viewport = True
    arm = bpy.data.objects['Medusa_Scheletro']
    # le ossa dei tentacoli che strisciano nelle pozze staccate dal padre: il primo osso (sotto il fondo, nascosto) si
    # allunga (tentacolo_pozza); la posa di riposo non cambia
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for eb in arm.data.edit_bones:
        if eb.name.startswith(tuple(r + '_' for r, _, _, _ in POZZA_TENTACOLI)) and eb.parent is not None:
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return arm


def mesh_attive(on):
    """Mentre si calcolano le pose le mesh non si deformano (ogni aggiornamento costerebbe troppo)."""
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for m in o.modifiers:
                if m.type == 'ARMATURE':
                    m.show_viewport = on
                    m.show_render = on


def campioni(arm):
    """Tutte le pose delle azioni del GLB, fotogramma per fotogramma: {azione: [posa, ...]}."""
    sc = bpy.context.scene
    out = {}
    for act in bpy.data.actions:
        if act.name not in ('statua', 'sveglia', 'insegue', 'fluttua', 'fauce_apre', 'affacciata'):
            continue
        arm.animation_data.action = act
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        pose = []
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            pose.append({pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones})
        out[act.name] = pose
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    aggiorna()
    return out


def campiona(C, azione, tempo, ciclo=True):
    """Posa dell'azione al tempo (secondi), tra due fotogrammi; nelle azioni in ciclo l'ultimo = il primo."""
    pose = C[azione]
    n = len(pose) - 1 if ciclo and len(pose) > 1 else len(pose)
    f = tempo * FPS_AZIONI
    if ciclo:
        f = f % n
    else:
        f = min(max(f, 0), len(pose) - 1)
    i = int(math.floor(f))
    j = min(i + 1, len(pose) - 1)
    return mix(pose[i], pose[j], f - i)


def applica(arm, posa):
    for pb in arm.pose.bones:
        pb.matrix_basis = posa[pb.name]
    aggiorna()


# --------------------------------------------------------------------------------------------- comandi di posa

def sposta(arm, d):
    """Sposta tutta lei (osso radice) di d metri (spazio del modello)."""
    pb = arm.pose.bones['radice']
    pb.matrix = Matrix.Translation(Vector(d)) @ pb.matrix
    aggiorna()


def ruota(arm, nome, asse, gradi):
    """Ruota l'osso intorno alla sua testa, asse nello spazio del modello. X+ = in avanti (verso -Y),
    Z+ = verso la sua sinistra (+X), Y+ = piega di lato verso la sua destra."""
    if abs(gradi) < 1e-6:
        return
    pb = arm.pose.bones[nome]
    h = pb.head.copy()
    R = Matrix.Rotation(math.radians(gradi), 4, Vector(asse))
    pb.matrix = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ pb.matrix
    aggiorna()


def rot_osso(arm, nome):
    """Quanto e' girato l'osso rispetto alla posa di riposo (nello spazio dell'armatura)."""
    pb = arm.pose.bones[nome]
    return (pb.matrix.to_3x3() @ arm.data.bones[nome].matrix_local.to_3x3().inverted()).to_4x4()


def rot_giro(arm):
    """Solo la rotazione orizzontale del petto (dove guarda il busto, senza l'inclinazione)."""
    f = rot_osso(arm, 'petto') @ Vector((0, -1, 0))
    return Matrix.Rotation(math.atan2(f.x, -f.y), 4, 'Z')


def braccio(arm, suf, polso, polo, dir_mano, dorso):
    """IK del braccio; polso e polo rispetto alla spalla, direzioni e posizioni nel riferimento del busto
    girato (senza inclinazione: x verso la sua sinistra per .L, -y davanti, z su). Per .R la x si specchia."""
    s = 1 if suf == '.L' else -1
    R = rot_giro(arm)
    sp = arm.pose.bones['braccio' + suf].head.copy()

    def v(p):
        return R @ Vector((s * p[0], p[1], p[2]))
    POSE.posa_braccio(arm, suf, sp + v(polso), sp + v(polo), v(dir_mano), v(dorso))


def braccio_mondo(arm, suf, polso, polo, dir_mano, dorso):
    """IK del braccio con il polso in un punto del modello (m); polo, direzioni come in braccio()."""
    s = 1 if suf == '.L' else -1
    R = rot_giro(arm)
    sp = arm.pose.bones['braccio' + suf].head.copy()
    W = arm.matrix_world.inverted() @ Vector(polso)

    def v(p):
        return R @ Vector((s * p[0], p[1], p[2]))
    POSE.posa_braccio(arm, suf, W, sp + v(polo), v(dir_mano), v(dorso))


def gira_mano(d0, z0, d1, z1, k):
    """La mano da (direzione delle dita d0, dorso z0) a (d1, z1): rotazione interpolata, non i vettori (a meta'
    potrebbero diventare paralleli e la mano si capovolgerebbe)."""
    def q(d, z):
        y = Vector(d).normalized()
        z = Vector(z) - y * Vector(z).dot(y)
        z.normalize()
        return Matrix((y.cross(z), y, z)).transposed().to_quaternion()
    q0, q1 = q(d0, z0), q(d1, z1)
    if q0.dot(q1) < 0:
        q1 = -q1
    R = q0.slerp(q1, k).to_matrix()
    return R.col[1].copy(), R.col[2].copy()


def mondo(arm, p):
    return arm.matrix_world @ Vector(p)


class Zampe:
    """Le zampe sul petto seguono le ossa del busto: si legge la posa di partenza (dove sono appoggiate),
    poi, dopo aver mosso il busto, ogni osso torna nello stesso posto rispetto all'osso del busto piu'
    vicino, tenendo la catena attaccata."""

    def __init__(self, arm):
        self.arm = arm
        self.catene = []
        for z in ZAMPE:
            nomi = sorted([b.name for b in arm.data.bones if b.name.startswith(z + '_')])
            self.catene.append(nomi)

    def leggi(self):
        arm = self.arm
        busto = {n: arm.pose.bones[n].matrix.copy() for n in BUSTO}
        self.rel = {}
        for nomi in self.catene:
            for n in nomi[1:]:
                pb = arm.pose.bones[n]
                c = (pb.head + pb.tail) / 2
                migliore, dmin = 'petto', 1e9
                for b in BUSTO:
                    q = arm.pose.bones[b]
                    ab = q.tail - q.head
                    u = max(0.0, min(1.0, (c - q.head).dot(ab) / max(ab.length_squared, 1e-9)))
                    d = (c - (q.head + ab * u)).length
                    if d < dmin:
                        migliore, dmin = b, d
                self.rel[n] = (migliore, busto[migliore].inverted() @ pb.matrix)

    def segui(self):
        arm = self.arm
        for nomi in self.catene:
            for k, n in enumerate(nomi[1:], 1):
                pb = arm.pose.bones[n]
                b, rel = self.rel[n]
                M = arm.pose.bones[b].matrix @ rel
                L = arm.data.bones[n].length
                testa = arm.pose.bones[nomi[k - 1]].tail.copy()
                coda = M.translation + M.col[1].xyz.normalized() * L
                y_vuole = (coda - testa).normalized()
                R = M.to_3x3().normalized()
                q = R.col[1].normalized().rotation_difference(y_vuole)
                N = (q.to_matrix() @ R).to_4x4()
                N.translation = testa
                pb.matrix = N
                aggiorna()


# --------------------------------------------------------------------------------------------- le pose

CORPO = None        # ossa del busto, testa e braccia (riempite in main)
TENTACOLI = None
DITA_OSSA = None


def base(C, corpo, tentacoli, dita=None):
    """Posa di partenza: busto/braccia/zampe da 'corpo', tentacoli da 'tentacoli', dita da 'dita'."""
    p = dict(corpo)
    for n in TENTACOLI:
        p[n] = tentacoli[n]
    if dita is not None:
        for n in DITA_OSSA:
            p[n] = dita[n]
    return p


def busto(arm, avanti=0.0, lato=0.0, giro=0.0):
    """Busto: in avanti (gradi, divisi tra colonna_1, colonna_2 e petto), di lato e girato."""
    for n, f in (('colonna_1', 0.3), ('colonna_2', 0.35), ('petto', 0.35)):
        ruota(arm, n, (1, 0, 0), avanti * f)
        ruota(arm, n, (0, 1, 0), lato * f)
        ruota(arm, n, (0, 0, 1), giro * f)


def testa(arm, su=0.0, giro=0.0, piega=0.0, collo=0.4):
    """Testa: su (gradi; + guarda in alto), girata (+ verso la sua sinistra), piegata di lato. Una parte va al
    collo."""
    for n, f in (('collo', collo), ('testa', 1 - collo)):
        ruota(arm, n, (0, 0, 1), giro * f)
        ruota(arm, n, (1, 0, 0), -su * f)
        ruota(arm, n, (0, 1, 0), piega * f)


def mascella(arm, gradi):
    ruota(arm, 'mascella', (1, 0, 0), -gradi)


# posa delle braccia tese verso il giocatore (riferimento del petto, metri)
def braccia_tese(arm, t, fase=0.0, k=1.0):
    for suf, sfasa in (('.L', 0.0), ('.R', 0.5)):
        a = math.sin(2 * math.pi * (t + sfasa) + fase)
        polso = (0.30 - 0.04 * a, -0.95 - 0.10 * a * k, 0.10 + 0.08 * math.cos(2 * math.pi * (t + sfasa)) * k)
        braccio(arm, suf, polso, (0.7, 0.0, -0.4), (0.12, -1.0, 0.05), (0.1, 0.1, 1.0))


def dita_incombe(C, u=0.0):
    return mix(campiona(C, 'insegue', 0.0), campiona(C, 'fauce_apre', 1.0, False), 0.5 + 0.5 * math.sin(2 * math.pi * u),
               DITA_OSSA)


def tent_incombe(C, t, T=2.4):
    """I tentacoli di incombe: quelli che pendono di fluttua con un poco della scia di insegue (piu' raccolti:
    vicino ai muri la scia piena di insegue li faceva entrare nelle pareti)."""
    u = (t / T) % 1.0
    return mix(campiona(C, 'fluttua', u * 2.0), campiona(C, 'insegue', u), 0.35, TENTACOLI)


def pose_incombe(arm, C, Z, t, T=2.4):
    """Ciclo: sporta in avanti sopra il giocatore, braccia tese che ondeggiano a turno, dita che si aprono e
    si chiudono, testa bassa verso il giocatore."""
    u = (t / T) % 1.0
    tent = campiona(C, 'fluttua', u * 2.0)
    insegue = campiona(C, 'insegue', 0.0)
    corpo = insegue
    dita = dita_incombe(C, u)
    applica(arm, base(C, corpo, mix(tent, campiona(C, 'insegue', u), 0.35, TENTACOLI), dita))
    Z.leggi()
    sposta(arm, (0.05 * math.sin(2 * math.pi * u), -0.10 - 0.06 * math.sin(2 * math.pi * u + 0.6),
                 -0.12 + 0.05 * math.sin(4 * math.pi * u)))
    busto(arm, avanti=6 + 4 * math.sin(2 * math.pi * u + 0.6), lato=4 * math.sin(2 * math.pi * u),
          giro=5 * math.sin(2 * math.pi * u + 1.2))
    testa(arm, su=0 - 3 * math.sin(2 * math.pi * u + 0.6), giro=-4 * math.sin(2 * math.pi * u + 1.2),
          piega=-6 * math.sin(2 * math.pi * u))
    braccia_tese(arm, u)
    Z.segui()


def pose_sale(arm, C, Z, t, T):
    """Da -5 m su: la testa per prima, braccia lungo i fianchi; in cima apre le braccia e si sporge (posa
    iniziale di incombe)."""
    u = t / T
    sal = chiavi(u, [(0.0, GIU), (0.72, 0.16), (0.88, -0.03), (1.0, 0.0)])
    apri = liscio(0.0, 1.0, 0.55, 1.0, u)
    tent = campiona(C, 'fluttua', t)
    dita = mix(campiona(C, 'statua', 0.0, False), dita_incombe(C), apri, DITA_OSSA)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, dita))
    Z.leggi()
    # alla fine coincide con incombe(0): stessa traslazione, busto, testa e braccia
    sposta(arm, (0.0, liscio(0.0, Y0, 0.55, 1.0, u), sal + liscio(0.0, -0.12, 0.55, 1.0, u)))
    busto(arm, avanti=chiavi(u, [(0.0, -28.0), (0.55, -22.0), (1.0, 6 + 4 * math.sin(0.6))]),
          giro=liscio(0.0, 5 * math.sin(1.2), 0.55, 1.0, u))
    testa(arm, su=chiavi(u, [(0.0, 12.0), (0.5, 8.0), (1.0, 0 - 3 * math.sin(0.6))]),
          giro=liscio(0.0, -4 * math.sin(1.2), 0.6, 1.0, u))
    for suf in ('.L', '.R'):
        # salendo le braccia stanno indietro lungo i fianchi, poi si aprono in avanti
        lungo = ((0.30, -0.12, -1.0), (0.5, 0.5, 0.0), (0.05, -0.15, -1.0), (1.0, 0.0, 0.0))
        sfasa = 0.0 if suf == '.L' else 0.5
        a = math.sin(2 * math.pi * sfasa)
        teso = ((0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * sfasa)), (0.7, 0.0, -0.4),
                (0.12, -1.0, 0.05), (0.1, 0.1, 1.0))
        k = liscio(0.0, 1.0, 0.55, 1.0, u)
        p = [tuple(x + (y - x) * k for x, y in zip(a_, b_)) for a_, b_ in zip(lungo, teso)]
        braccio(arm, suf, *p)
    Z.segui()


def pose_sale_puntata(arm, C, Z, t, T=1.6):
    """La salita della vasca 2 (0.3.21, scelta C dell'utente): stessa durata e stesso
    momento in cui passa 2,9 m sotto (0,49 s, come le altre salite; la vasca 2 parte da 5 m), ma resta giu' fino a
    0,32 s e poi sale in fretta, con la testa gia' giu' verso di te e l'occhio puntato (niente testa piegata indietro ne'
    busto all'indietro); le braccia si aprono mentre sale. Dopo, ferma a fissarti, si sporge piano fino alla posa iniziale di
    incombe (come sale_dall_acqua alla fine)."""
    sal = chiavi(t, [(0.0, GIU), (0.32, GIU), (0.74, 0.16), (0.9, -0.03), (1.05, 0.0)])
    apri = liscio(0.0, 1.0, 0.45, 0.95, t)
    tent = campiona(C, 'fluttua', t)
    dita = mix(campiona(C, 'statua', 0.0, False), dita_incombe(C), apri, DITA_OSSA)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, dita))
    Z.leggi()
    # alla fine coincide con incombe(0), come pose_sale
    sposta(arm, (0.0, liscio(0.0, Y0, 0.65, T, t), sal + liscio(0.0, -0.12, 0.65, 1.05, t)))
    busto(arm, avanti=chiavi(t, [(0.0, 10.0), (0.74, 16.0), (1.1, 16.0), (T, 6 + 4 * math.sin(0.6))]),
          giro=liscio(0.0, 5 * math.sin(1.2), 0.65, T, t))
    # la testa gia' giu' verso di te (l'occhio puntato: nella vasca 2 sei 4,6 m piu' in basso di lei; il resto lo fa
    # l'occhio, che ti segue da solo), poi la posa di incombe
    testa(arm, su=chiavi(t, [(0.0, -25.0), (1.1, -25.0), (T, 0 - 3 * math.sin(0.6))]),
          giro=liscio(0.0, -4 * math.sin(1.2), 0.65, T, t))
    for suf in ('.L', '.R'):
        lungo = ((0.30, -0.12, -1.0), (0.5, 0.5, 0.0), (0.05, -0.15, -1.0), (1.0, 0.0, 0.0))
        sfasa = 0.0 if suf == '.L' else 0.5
        a = math.sin(2 * math.pi * sfasa)
        teso = ((0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * sfasa)), (0.7, 0.0, -0.4),
                (0.12, -1.0, 0.05), (0.1, 0.1, 1.0))
        p = [tuple(x + (y - x) * apri for x, y in zip(a_, b_)) for a_, b_ in zip(lungo, teso)]
        braccio(arm, suf, *p)
    Z.segui()


# il bordo della vasca 3 (vasca_2 in SalaInseguimento) davanti a lei, girata verso il muro (sonda
# proposte/mascotte/sonda_bordo_mano.gd): la faccia dalla sua parte a 2,30 m, la cima a 3,500 m sopra la sua base (-27,500 nel
# mondo, collisione e mesh: ricontrollo di ambienti-1 del 6 novembre; prima 3,485 e la mano entrava 13 mm), larga
# 18,5 cm. Nello spazio del modello: -y avanti, z su.
BORDO_V3 = (2.30, 3.500, 0.185)
MANO_V3_LATO = -0.42        # la mano destra (.R e' dalla parte -x), un po' fuori dalla spalla
MANO_V3_SU = 0.229          # il polso sopra la cima perche' il palmo ci stia a filo (misurato in Godot sulla pelle vera:
                            # proposte/mascotte/sonda_mano_bordo.gd; con 0,24 il palmo restava 12,8 mm sopra)
MANO_V3_LASCIA = 1.05      # quando lascia il bordo (s; SalaInseguimento.MANO_LASCIA deve essere uguale)
MANO_V3_QUA = 0.15          # salendo, il polso resta almeno tanto prima della faccia del muro, dalla parte di lei
MANO_V3_DENTRO = 0.05       # il polso tanto oltre la faccia del muro: palmo e dita sulla cima


def presa_bordo_v3():
    f, h, _ = BORDO_V3
    return Vector((MANO_V3_LATO, -(f + MANO_V3_DENTRO), h + MANO_V3_SU))


def pose_sale_mano(arm, C, Z, t, T=1.6):
    """La salita della vasca 3 (0.3.21, scelta C dell'utente): stessa durata e stesso momento in cui passa 2,9 m sotto
    (0,49 s) di sale_dall_acqua. Sale col braccio destro alzato, cosi' sopra il muro esce per prima la mano, che si
    posa sul bordo della vasca (0,82 s); poi si tira su tenendosi (la mano ferma sul bordo: se la spalla e' troppo
    lontana, e' lei che va verso la mano), lascia il bordo (MANO_V3_LASCIA) e finisce nella posa iniziale di incombe. Salendo e'
    piu' avanti, verso il muro, e torna al suo posto mentre si tira su e dopo."""
    sal = chiavi(t, [(0.0, GIU), (0.20, GIU), (0.82, -0.6), (1.12, 0.12), (1.35, -0.02), (1.6, 0.0)])
    avanti = chiavi(t, [(0.0, -0.95), (0.82, -0.95), (1.05, -0.9), (T, Y0)])
    apri = liscio(0.0, 1.0, MANO_V3_LASCIA, T, t)
    tent = campiona(C, 'fluttua', t)
    dita = mix(campiona(C, 'statua', 0.0, False), dita_incombe(C), liscio(0.0, 1.0, 0.3, 0.7, t), DITA_OSSA)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, dita))
    Z.leggi()
    sposta(arm, (0.0, avanti, sal + liscio(0.0, -0.12, 1.1, T, t)))
    busto(arm, avanti=chiavi(t, [(0.0, 12.0), (0.82, 28.0), (1.05, 28.0), (T, 6 + 4 * math.sin(0.6))]),
          giro=liscio(0.0, 5 * math.sin(1.2), 1.1, T, t))
    testa(arm, su=chiavi(t, [(0.0, 16.0), (0.82, 10.0), (1.05, 4.0), (T, 0 - 3 * math.sin(0.6))]),
          giro=liscio(0.0, -4 * math.sin(1.2), 1.1, T, t))
    # i tentacoli stretti sotto la campana mentre e' avanti, verso il muro (il tentacolo 4 ci entrava, nei tentacoli
    # morbidi); si riaprono piano tornando al suo posto, fino alla posa di incombe
    raccogli(arm, chiavi(t, [(0.0, 0.1), (0.6, 0.1), (0.82, 0.7), (0.95, 0.7), (1.35, 0.0)]))
    lungo = ((0.30, -0.12, -1.0), (0.5, 0.5, 0.0), (0.05, -0.15, -1.0), (1.0, 0.0, 0.0))

    def teso(suf):
        sfasa = 0.0 if suf == '.L' else 0.5
        a = math.sin(2 * math.pi * sfasa)
        return ((0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * sfasa)), (0.7, 0.0, -0.4),
                (0.12, -1.0, 0.05), (0.1, 0.1, 1.0))
    # la sinistra: lungo il fianco, poi si apre in avanti come in sale_dall_acqua
    pl = [tuple(x + (y - x) * apri for x, y in zip(a_, b_)) for a_, b_ in zip(lungo, teso('.L'))]
    braccio(arm, '.L', *pl)
    # la destra: alzata in avanti, sopra la testa
    G = presa_bordo_v3()
    dir_g, dorso_g = (0.0, -1.0, -0.25), (0.0, 0.0, 1.0)
    polo_g = (0.8, 0.4, -0.3)
    d0, z0 = (0.0, -0.4, 1.0), (0.0, 1.0, 0.0)
    # alzata: il polso sopra la spalla e un po' avanti, ma mai oltre la faccia del muro (meno MANO_V3_QUA) finche' non e'
    # sopra il bordo
    sp = arm.matrix_world @ arm.pose.bones['braccio.R'].head
    alzata = sp + Vector((-0.15, -0.3, 1.0))
    alzata.y = max(alzata.y, -(BORDO_V3[0] - MANO_V3_QUA))
    # poi sopra la presa ma ancora dalla sua parte, poi avanti sopra la cima, poi giu' sulla cima
    qua_sopra = Vector((G.x, -(BORDO_V3[0] - MANO_V3_QUA), G.z + 0.3))
    sopra = G + Vector((0.0, 0.0, 0.12))
    if t < MANO_V3_LASCIA:
        k1 = liscio(0.0, 1.0, 0.50, 0.64, t)
        k2 = liscio(0.0, 1.0, 0.64, 0.74, t)
        k3 = liscio(0.0, 1.0, 0.74, 0.82, t)
        polso = alzata.lerp(qua_sopra, k1).lerp(sopra, k2).lerp(G, k3)
        dm, zm = gira_mano(d0, z0, dir_g, dorso_g, liscio(0.0, 1.0, 0.55, 0.8, t))
        if t >= 0.74:
            # tenendosi: se la spalla e' troppo lontana dal polso, lei va verso la mano (non la mano verso di lei)
            sp = arm.matrix_world @ arm.pose.bones['braccio.R'].head
            portata = (POSE.lunghezza(arm, 'braccio.R') + POSE.lunghezza(arm, 'avambraccio.R')) * 0.985
            dd = polso - sp
            if dd.length > portata:
                sposta(arm, tuple(dd * (1.0 - portata / dd.length)))
                if '--diagnosi' in sys.argv:
                    print(f'sale_mano t={t:.3f}: verso la mano di {dd.length - portata:.3f} m', flush=True)
        braccio_mondo(arm, '.R', polso, polo_g, dm, zm)
    else:
        # lascia il bordo: su e indietro, poi le braccia tese di incombe
        k = liscio(0.0, 1.0, MANO_V3_LASCIA, MANO_V3_LASCIA + 0.2, t)
        lascia = G + Vector((0.0, 0.18, 0.2)) * k
        dm, zm = gira_mano(dir_g, dorso_g, teso('.R')[2], teso('.R')[3], liscio(0.0, 1.0, MANO_V3_LASCIA, MANO_V3_LASCIA + 0.3, t))
        if t < MANO_V3_LASCIA + 0.2:
            # (quello che serviva per tenersi sfuma in 0,15 s: niente scatto quando lascia)
            sp = arm.matrix_world @ arm.pose.bones['braccio.R'].head
            portata = (POSE.lunghezza(arm, 'braccio.R') + POSE.lunghezza(arm, 'avambraccio.R')) * 0.985
            dd = lascia - sp
            if dd.length > portata:
                sposta(arm, tuple(dd * (1.0 - portata / dd.length) * (1.0 - liscio(0.0, 1.0, MANO_V3_LASCIA, MANO_V3_LASCIA + 0.15, t))))
            braccio_mondo(arm, '.R', lascia, polo_g, dm, zm)
        else:
            braccio(arm, '.R', *teso('.R'))
            pb = arm.pose.bones['mano.R']
            fine = arm.matrix_world @ pb.head
            braccio_mondo(arm, '.R', lascia.lerp(fine, liscio(0.0, 1.0, MANO_V3_LASCIA + 0.2, MANO_V3_LASCIA + 0.35, t)), polo_g, dm, zm)
            if t >= MANO_V3_LASCIA + 0.35:
                braccio(arm, '.R', *teso('.R'))
    Z.segui()


def pose_presa(arm, C, Z, t):
    """1,2 s: si tira indietro (0-0,25), scatta in avanti e afferra in GRAB (0,25-0,55), tira verso di se'."""
    tent = tent_incombe(C, t)
    dita = mix(dita_incombe(C), campiona(C, 'fauce_apre', 1.0, False), liscio(0.0, 1.0, 0.3, 0.55, t), DITA_OSSA)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, dita))
    Z.leggi()
    avanti_rad = chiavi(t, [(0.0, Y0), (0.25, 0.15), (0.5, -0.85), (0.6, -0.80), (1.2, -0.55)])
    giu = chiavi(t, [(0.0, -0.12), (0.25, -0.02), (0.5, -0.55), (1.2, -0.35)])
    sposta(arm, (0.0, avanti_rad, giu))
    busto(arm, avanti=chiavi(t, [(0.0, 6 + 4 * math.sin(0.6)), (0.25, -10.0), (0.5, 18.0), (1.2, 12.0)]),
          giro=chiavi(t, [(0.0, 5 * math.sin(1.2)), (0.4, 0.0)]))
    testa(arm, su=chiavi(t, [(0.0, 0 - 3 * math.sin(0.6)), (0.25, 12.0), (0.5, -6.0), (1.2, -14.0)]),
          giro=chiavi(t, [(0.0, -4 * math.sin(1.2)), (0.4, 0.0)]))
    # la mascella come le blend shape della fauce (la libreria le apre da FAUCE_DA = 0,45 s alla fine)
    fauce_mascella(arm, C, liscio(0.0, 1.0, 0.45, 1.2, t))
    k = liscio(0.0, 1.0, 0.27, 0.5, t)
    for suf, s in (('.L', 1), ('.R', -1)):
        a = math.sin(2 * math.pi * (0.0 if s > 0 else 0.5))
        teso = (0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * (0.0 if s > 0 else 0.5)))
        carica = (0.75, -0.25, 0.40)
        if t < 0.27:
            w = liscio(0.0, 1.0, 0.0, 0.25, t)
            polso = tuple(x + (y - x) * w for x, y in zip(teso, carica))
            def lr(x, y):
                return tuple(p + (q - p) * w for p, q in zip(x, y))
            braccio(arm, suf, polso, lr((0.7, 0.0, -0.4), (0.7, 0.2, -0.3)), lr((0.12, -1.0, 0.05), (0.3, -0.9, 0.3)),
                    lr((0.1, 0.1, 1.0), (0.2, 0.2, 1.0)))
        else:
            # i polsi ai lati della testa di chi e' afferrato, le mani che si chiudono intorno
            g = Vector(GRAB) + Vector((0, chiavi(t, [(0.5, 0.0), (1.2, 0.30)]), chiavi(t, [(0.5, 0.0), (1.2, 0.18)])))
            fin = g + Vector((s * 0.24, 0.18, 0.02))
            pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
            ini = pc + rot_giro(arm) @ Vector((s * carica[0], carica[1], carica[2]))
            polso = ini.lerp(fin, k)
            braccio_mondo(arm, suf, polso, (0.8, 0.1, -0.4), (-0.35, -1.0, 0.0), (0.0, 0.0, 1.0))
    Z.segui()


def pose_respinta(arm, C, Z, t):
    """1,2 s: il getto in faccia (0), la testa indietro, si copre il viso (0,1-0,4) e torna sotto (0,45-1,2)."""
    tent = mix(tent_incombe(C, t), campiona(C, 'fluttua', t), liscio(0.0, 1.0, 0.2, 0.8, t), TENTACOLI)
    dita = mix(dita_incombe(C), campiona(C, 'statua', 0.0, False), liscio(0.0, 1.0, 0.05, 0.3, t), DITA_OSSA)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, dita))
    Z.leggi()
    giu = chiavi(t, [(0.0, -0.12), (0.12, -0.05), (0.45, -0.25), (1.2, GIU)])
    if t > 0.45:   # cade sempre piu' in fretta
        w = (t - 0.45) / 0.75
        giu = -0.25 + (GIU + 0.25) * w * w
    sposta(arm, (0.0, chiavi(t, [(0.0, Y0), (0.15, 0.35), (0.6, 0.25)]), giu))
    busto(arm, avanti=chiavi(t, [(0.0, 6 + 4 * math.sin(0.6)), (0.15, -26.0), (0.4, -6.0), (1.2, 0.0)]),
          lato=chiavi(t, [(0.0, 0.0), (0.12, -6.0), (0.5, 3.0)]),
          giro=chiavi(t, [(0.0, 5 * math.sin(1.2)), (0.12, -10.0), (0.5, 4.0)]))
    testa(arm, su=chiavi(t, [(0.0, 0 - 3 * math.sin(0.6)), (0.14, 30.0), (0.32, 10.0), (0.6, -22.0), (1.2, -25.0)]),
          giro=chiavi(t, [(0.0, -4 * math.sin(1.2)), (0.14, 16.0), (0.4, 6.0)]),
          piega=chiavi(t, [(0.0, 0.0), (0.14, 10.0), (0.4, 4.0)]))
    k = liscio(0.0, 1.0, 0.06, 0.32, t)
    for suf, s in (('.L', 1), ('.R', -1)):
        a = math.sin(2 * math.pi * (0.0 if s > 0 else 0.5))
        teso = (0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * (0.0 if s > 0 else 0.5)))
        # le mani davanti al viso (all'occhio), palmi verso di lei, dita in su, dorso verso il getto
        Rt = rot_osso(arm, 'testa')
        avanti_t = (Rt @ Vector((0, -1, 0))).normalized()
        su_t = (Rt @ Vector((0, 0, 1))).normalized()
        lato_t = avanti_t.cross(su_t).normalized() * -1.0          # verso la sua sinistra
        occhio = arm.pose.bones['occhio'].head
        viso = occhio + avanti_t * 0.26 - su_t * 0.20 + lato_t * (s * 0.11)
        sp = arm.pose.bones['braccio' + suf].head
        ini = sp + rot_giro(arm) @ Vector((s * teso[0], teso[1], teso[2]))
        polso = ini.lerp(viso, k)
        # in due tempi, passando per le dita verso l'interno e il dorso in su: tutto insieme sarebbe quasi mezzo
        # giro e la mano potrebbe girare da una parte o dall'altra tra un fotogramma e l'altro
        d0, z0 = rot_giro(arm) @ Vector((s * 0.12, -1.0, 0.05)), rot_giro(arm) @ Vector((s * 0.1, 0.1, 1.0))
        dm_, zm_ = -lato_t * s + avanti_t * 0.3, su_t
        d1, z1 = su_t - lato_t * (s * 0.25), avanti_t
        if k < 0.5:
            dm, do = gira_mano(d0, z0, dm_, zm_, k * 2)
        else:
            dm, do = gira_mano(dm_, zm_, d1, z1, k * 2 - 1)
        polo = Vector((0.7, 0.0, -0.4)).lerp(Vector((0.75, 0.1, -0.5)), k)
        POSE.posa_braccio(arm, suf, polso, sp + rot_giro(arm) @ Vector((s * polo.x, polo.y, polo.z)), dm, do)
    Z.segui()


def pose_scende(arm, C, Z, t, T=1.0):
    """1 s: abbassa le braccia, si raddrizza e torna sotto (piano all'inizio, poi sempre piu' in fretta)."""
    u = t / T
    tent = mix(tent_incombe(C, t), campiona(C, 'fluttua', t), liscio(0.0, 1.0, 0.0, 0.6, u), TENTACOLI)
    dita = mix(dita_incombe(C), campiona(C, 'statua', 0.0, False), liscio(0.0, 1.0, 0.1, 0.6, u), DITA_OSSA)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, dita))
    Z.leggi()
    w = liscio(0.0, 1.0, 0.1, 1.0, u)
    sposta(arm, (0.0, Y0 - Y0 * w, -0.12 + (GIU + 0.12) * w * w))
    busto(arm, avanti=liscio(6 + 4 * math.sin(0.6), -20.0, 0.0, 0.7, u), giro=liscio(5 * math.sin(1.2), 0.0, 0.0, 0.5, u))
    testa(arm, su=chiavi(u, [(0.0, 0 - 3 * math.sin(0.6)), (0.4, 6.0), (1.0, 18.0)]),
          giro=liscio(-4 * math.sin(1.2), 0.0, 0.0, 0.5, u))
    k = liscio(0.0, 1.0, 0.0, 0.7, u)
    for suf, s in (('.L', 1), ('.R', -1)):
        a = math.sin(2 * math.pi * (0.0 if s > 0 else 0.5))
        teso = ((0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * (0.0 if s > 0 else 0.5))),
                (0.7, 0.0, -0.4), (0.12, -1.0, 0.05), (0.1, 0.1, 1.0))
        lungo = ((0.30, -0.12, -1.0), (0.5, 0.5, 0.0), (0.05, -0.15, -1.0), (1.0, 0.0, 0.0))
        p = [tuple(x + (y - x) * k for x, y in zip(a_, b_)) for a_, b_ in zip(teso, lungo)]
        braccio(arm, suf, *p)
    Z.segui()


def pose_grata(arm, C, Z, t, T=0.5, sbieco=0.0):
    """Ciclo di 0,5 s: carica (0-0,15), sbatte i palmi sulla grata a GRATA m davanti (0,2), rimbalza.
    Con [sbieco] (gradi) la grata è girata: i palmi la colpiscono lungo il piano girato, la destra più vicina."""
    fi = math.radians(sbieco)
    u = t / T
    tent = tent_incombe(C, t * 4.8)     # un ciclo di incombe ogni colpo
    dita = mix(campiona(C, 'statua', 0.0, False), campiona(C, 'insegue', 0.0), 0.3, DITA_OSSA)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, dita))
    Z.leggi()
    colpo = chiavi(u, [(0.0, 0.25), (0.2, 0.0), (0.5, 1.0), (0.6, 1.0), (1.0, 0.25)])
    sposta(arm, (0.0, 0.15 - 0.90 * colpo, -0.10 - 0.10 * colpo))
    busto(arm, avanti=-20 + 30 * colpo, lato=4 * math.sin(2 * math.pi * u))
    testa(arm, su=chiavi(u, [(0.0, 10.0), (0.3, 16.0), (0.4, 2.0), (1.0, 10.0)]))
    for suf, s in (('.L', 1), ('.R', -1)):
        pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
        alto = pc + rot_giro(arm) @ Vector((s * 0.45, -0.70, 0.62))
        # i palmi piatti sulla grata, ai lati della testa
        contatto = Vector((s * 0.55 * math.cos(fi), -GRATA + 0.10 - s * 0.55 * math.sin(fi), pc.z + 0.35))
        polso = alto.lerp(contatto, liscio(0.0, 1.0, 0.0, 1.0, colpo))
        # i palmi piatti sul piano (girato di sbieco: il dorso verso di lei lungo la sua normale)
        sn, cs = math.sin(fi), math.cos(fi)
        braccio_mondo(arm, suf, polso, (0.8, 0.3, -0.5), (s * -0.25 * sn, -0.25 * cs, 1.0), (s * sn, cs, 0.0))
    Z.segui()


def pose_sb1(arm, C, Z, t):
    """SB1: sbuca dal pozzo (0-1,3), mani sul bordo; la testa girata di lato, poi verso di te (1,7-2,5)."""
    d, h = BORDO_SB1
    tent = campiona(C, 'insegue', t * 0.5)
    aff = campiona(C, 'affacciata', 0.0)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, aff))
    Z.leggi()
    # busto, spalle e testa dell'affacciata (le zampe, lette su insegue, poi seguono)
    for n in ('colonna_1', 'colonna_2', 'petto', 'collo', 'testa'):
        arm.pose.bones[n].matrix_basis = aff[n]
    aggiorna()
    # la vita (testa di colonna_1) 0,57 m sotto il bordo e 1,06 m dietro lo spigolo, come nella vasca
    vita = mondo(arm, arm.pose.bones['colonna_1'].head)
    voglio = Vector((0.0, -(d - 1.06), h - 0.57))
    sal = chiavi(t, [(0.0, GIU), (1.0, 0.10), (1.15, -0.03), (1.3, 0.0)])
    sposta(arm, voglio - vita + Vector((0, 0, sal)))
    testa(arm, giro=chiavi(t, [(0.0, 38.0), (1.7, 38.0), (2.5, 0.0)]),
          su=chiavi(t, [(0.0, -20.0), (1.0, -6.0), (1.7, -4.0), (2.5, 2.0)]),
          piega=chiavi(t, [(0.0, 8.0), (1.7, 8.0), (2.5, 0.0), (3.6, -4.0), (5.4, -6.0)]), collo=0.5)
    resp = 0.012 * math.sin(2 * math.pi * t / 2.7)
    sposta(arm, (0, 0, resp))
    for suf, s in (('.L', 1), ('.R', -1)):
        bordo = Vector((s * 0.58, -(d + 0.12), h + 0.04))
        pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
        su = pc + Vector((s * 0.35, -0.35, 0.9))
        k = liscio(0.0, 1.0, 0.75, 1.05, t)
        polso = su.lerp(bordo, k)
        braccio_mondo(arm, suf, polso, (0.9, 0.3, -0.2), (0.0, -1.0, -0.15), (0.0, 0.0, 1.0))
    Z.segui()


def pose_scende_sb1(arm, C, Z, t, T=1.2):
    """Dopo affacciata_sb1, dal suo ultimo fotogramma (5,4 s): lascia il bordo e scivola giu' nel pozzo, senza mai
    salire (riscontro dell'utente sulla 0.3.18: con "scende", che parte dalla posa di incombe, prima saliva di
    scatto di 3 m e poi scendeva). Le mani si staccano per prime e scendono accanto alle spalle, mai sopra il bordo;
    il corpo parte da fermo e va giu' sempre piu' in fretta; la testa ti guarda e va sotto per ultima."""
    d, h = BORDO_SB1
    u = t / T
    tent = campiona(C, 'insegue', (5.4 + t) * 0.5)
    aff = campiona(C, 'affacciata', 0.0)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, aff))
    Z.leggi()
    for n in ('colonna_1', 'colonna_2', 'petto', 'collo', 'testa'):
        arm.pose.bones[n].matrix_basis = aff[n]
    aggiorna()
    vita = mondo(arm, arm.pose.bones['colonna_1'].head)
    voglio = Vector((0.0, -(d - 1.06), h - 0.57))
    sposta(arm, voglio - vita + Vector((0, 0, GIU * u ** 2.2)))
    testa(arm, giro=0.0, su=2.0 + 10.0 * liscio(0.0, 1.0, 0.1, 0.7, u), piega=-6.0, collo=0.5)
    k = liscio(0.0, 1.0, 0.0, 0.35, u)
    for suf, s in (('.L', 1), ('.R', -1)):
        bordo = Vector((s * 0.58, -(d + 0.12), h + 0.04))
        pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
        lasciato = pc + Vector((s * 0.42, -0.30, 0.30))
        polso = bordo.lerp(lasciato, k)
        polso.z = min(polso.z, bordo.z)
        if k <= 0.0:
            dm, ds = (0.0, -1.0, -0.15), (0.0, 0.0, 1.0)     # come in affacciata_sb1
        else:
            dm, ds = gira_mano((0.0, -1.0, -0.15), (0.0, 0.0, 1.0), (0.0, -0.4, 1.0), (0.0, 1.0, 0.4), k)
        braccio_mondo(arm, suf, polso, (0.9, 0.3, -0.2), dm, ds)
    Z.segui()


# --------------------------------------------------------------------------------------------- il tunnel

# Il tunnel del viaggio sottomarino (scelte del 24 ottobre): lei fluttua intera sopra il canale a bocca spalancata,
# l'occhio pieno di vene (le vene le accende il gioco: MedusaStatue.attacca). L'origine resta sul piano dei
# tentacoli: nella posa insegue lei va da 0 a 5,3 m e sta in una volta di 6 m sopra il canale.
T_APERTA = 2.6          # il ciclo: due battiti di insegue (1 s nel modello) rallentati a 1,3 s
MASCELLA_APERTA = 22.0  # gradi, come alla fine della presa
MORSI = (0.30, 1.60)    # quando morde nel ciclo (s): uno ogni 1,3 s
MORSO = 0.42            # quanto dura un morso (chiude in 0,12 s, tiene, riapre)
OBLO = (0.95, 4.62)     # schianto: il piano del portello a tanti metri davanti all'origine, il centro dell'oblò a
                        # tanti metri d'altezza (il gioco mette lei in modo che coincida con l'oblò vero)
OBLO_SU = 0.62          # all'inizio dello schianto lei e' piu' su di tanto: quanto sta l'origine nella corsa (0,72 m sopra
                        # l'acqua, LeiTunnel.QUOTA) sopra quella dello schianto (l'oblò di ambienti-2 a 4,72 m sopra l'acqua)


def fauce_mascella(arm, C, f):
    """La mascella come in fauce_apre aperta di f (0 chiusa, 1 come alla fine): l'osso ruota e scende (16 cm),
    non basta ruotarlo. f oltre 1 la spalanca un poco di piu' (fino a 1,25)."""
    a = campiona(C, 'fauce_apre', 0.0, False)['mascella']
    b = campiona(C, 'fauce_apre', 1.0, False)['mascella']
    if f <= 1.0:
        m = mix_m(a, b, f)
    else:
        la, ra, sa = a.decompose()
        lb, rb, sb = b.decompose()
        e = f - 1.0
        q = ra.rotation_difference(rb)          # rb = q @ ra
        m = Matrix.LocRotScale(lb + (lb - la) * e, Quaternion().slerp(q, e) @ rb, sb)
    arm.pose.bones['mascella'].matrix_basis = m
    aggiorna()


def morso(t):
    """Quanto e' chiusa la mascella per i morsi (0 aperta, 1 chiusa) al tempo t del ciclo."""
    c = 0.0
    for t0 in MORSI:
        x = t - t0
        c = max(c, chiavi(x, [(0.0, 0.0), (0.12, 1.0), (0.17, 0.9), (MORSO, 0.0)]) if 0.0 <= x <= MORSO else 0.0)
    return c


def aperta(arm, C, Z, t, chiude=0.0, k=1.0, extra=None):
    """La posa della corsa nel tunnel al tempo t del ciclo T_APERTA: il corpo e la scia dei tentacoli di insegue,
    inclinata in avanti, le braccia tese che ondeggiano a turno, gli artigli aperti (fauce_apre), la mascella
    spalancata (chiude: 0 spalancata, 1 chiusa, per i morsi). k scala gli scostamenti della corsa (0: la posa
    insegue ferma), extra(arm) ritocca il busto e la testa prima delle braccia."""
    u = (t / T_APERTA) % 1.0
    corpo = campiona(C, 'insegue', 2.0 * u)
    tent = campiona(C, 'insegue', 2.0 * u)
    dita = mix(campiona(C, 'insegue', 2.0 * u), campiona(C, 'fauce_apre', 1.0, False),
               0.75 + 0.15 * math.sin(2 * math.pi * 2 * u), DITA_OSSA)
    applica(arm, base(C, corpo, tent, dita))
    Z.leggi()
    sposta(arm, (0.04 * math.sin(2 * math.pi * u) * k, 0.0, (0.06 * math.sin(2 * math.pi * 2 * u + 0.4)) * k))
    busto(arm, avanti=(8 + 3 * math.sin(2 * math.pi * 2 * u)) * k, lato=3 * math.sin(2 * math.pi * u) * k,
          giro=4 * math.sin(2 * math.pi * u + 1.0) * k)
    testa(arm, su=(-6 - 2 * math.sin(2 * math.pi * 2 * u + 0.5)) * k, giro=-3 * math.sin(2 * math.pi * u + 1.0) * k,
          piega=-4 * math.sin(2 * math.pi * u) * k)
    if extra:
        extra(arm)
    braccia_tese(arm, 2.0 * u, k=k)
    fauce_mascella(arm, C, (1.0 - chiude) * (1.0 + 0.04 * math.sin(2 * math.pi * 2 * u)))
    Z.segui()


def pose_insegue_aperta(arm, C, Z, t):
    """Ciclo di 2,6 s: insegue a bocca spalancata."""
    aperta(arm, C, Z, t)


def pose_insegue_morde(arm, C, Z, t):
    """Lo stesso ciclo, con due morsi a vuoto (MORSI): la mascella si chiude di scatto e si riapre, la testa da' un
    colpo in avanti. Il gioco passa da insegue_aperta a questa alla stessa posizione del ciclo quando lei e' vicina."""
    c = morso(t)
    aperta(arm, C, Z, t, chiude=0.85 * c, extra=lambda a: (busto(a, avanti=4 * c), testa(a, su=-5 * c)))


def fauce_morde(t):
    return 1.0 - 0.6 * morso(t)


def pose_ritrae(arm, C, Z, t, T=2.0):
    """2 s: il getto in faccia mentre insegue. La testa scatta indietro e di lato, il busto si tira su e indietro,
    le braccia si raccolgono verso il petto (non si copre: l'occhio lo strizza il gioco, chiudi_occhio), la
    bocca resta spalancata e si apre di piu' nel grido; scuote la testa e alla fine torna nella posa di
    insegue_aperta al tempo 0 (il gioco la rimanda indietro e riparte il ciclo)."""
    u = t / T
    k = liscio(1.0, 0.0, 0.0, 0.08, u) + liscio(0.0, 1.0, 0.7, 1.0, u)     # quanto e' nella corsa
    w = 1.0 - k                                                            # quanto e' ritratta
    scuote = math.sin(2 * math.pi * 5.0 * t) * liscio(1.0, 0.0, 0.1, 0.65, u)

    def ritocco(a):
        busto(a, avanti=-24 * w, lato=-5 * w, giro=-10 * w)
        testa(a, su=26 * w, giro=(16 + 10 * scuote) * w, piega=(10 + 6 * scuote) * w)
    # (il ciclo va avanti in modo da ritrovarsi alla fine al suo tempo 0: si riparte da li')
    aperta(arm, C, Z, t * T_APERTA / T, k=k, extra=ritocco)
    sposta(arm, (0.0, 0.55 * w, 0.18 * w))
    fauce_mascella(arm, C, 1.0 + 0.2 * w)      # nel grido si apre di piu'
    for suf, s in (('.L', 1), ('.R', -1)):
        if w <= 1e-4:
            continue
        a = math.sin(2 * math.pi * (0.0 if s > 0 else 0.5))
        teso = (0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * (0.0 if s > 0 else 0.5)))
        raccolto = (0.42, -0.42, 0.30)
        polso = tuple(x + (y - x) * w for x, y in zip(teso, raccolto))
        braccio(arm, suf, polso, (0.7, 0.1, -0.5), (0.2, -0.9, 0.35), (0.15, 0.2, 1.0))
    Z.segui()


T_CARICA = 2.0          # la carica nel tunnel (0.4.0)
T_SCATTO = 0.8          # lo scatto in avanti dopo la carica
CARICA_CICLO = 1.0      # dove arriva il ciclo della corsa alla fine della carica (s): lo scatto riparte da li'


def _caricata(arm, C, Z, tc, w, l=0.0, vib=0.0):
    """La posa della carica: la corsa (aperta) al tempo tc del suo ciclo, tirata indietro di w (0-1) e lanciata in
    avanti di l (0-1). Tirata: busto indietro, testa bassa e puntata, le braccia piegate indietro all'altezza delle
    spalle, pronte; la bocca si apre di piu'. Lanciata: busto e testa in avanti, le braccia tese davanti. vib e' il
    tremito della carica (-1..1)."""
    def ritocco(a):
        busto(a, avanti=(-14 + 1.5 * vib) * w + 22 * l, giro=1.0 * vib * w)
        testa(a, su=-12 * w - 6 * l, piega=1.5 * vib * w)
    k = max(0.0, 1.0 - 0.7 * w - 0.6 * l)
    aperta(arm, C, Z, tc, k=k, extra=ritocco)
    sposta(arm, (0.0, 0.6 * w - 0.5 * l, -0.10 * w + 0.05 * l))
    if w > 1e-4 or l > 1e-4:
        # le braccia: dalla posa tesa della corsa (braccia_tese, stesso tempo del ciclo) indietro o avanti, con gli stessi
        # assi della mano (cosi' a w = l = 0 e' la corsa)
        t2 = 2.0 * ((tc / T_APERTA) % 1.0)
        for suf, sfasa in (('.L', 0.0), ('.R', 0.5)):
            a = math.sin(2 * math.pi * (t2 + sfasa))
            teso = (0.30 - 0.04 * a, -0.95 - 0.10 * a * k, 0.10 + 0.08 * math.cos(2 * math.pi * (t2 + sfasa)) * k)
            indietro = (0.48, -0.18, 0.40)
            avanti = (0.22, -1.10, 0.20)
            polso = tuple(x + (y - x) * w for x, y in zip(teso, indietro))
            polso = tuple(x + (y - x) * l for x, y in zip(polso, avanti))
            braccio(arm, suf, polso, (0.7, 0.0, -0.4), (0.12, -1.0, 0.05), (0.1, 0.1, 1.0))
    fauce_mascella(arm, C, 1.0 + 0.15 * w + 0.1 * l)
    Z.segui()


def pose_carica(arm, C, Z, t, T=T_CARICA):
    """2 s nel tunnel (0.4.0): a 8 m da te smette di cantare e si carica. Dalla posa di insegue_aperta al tempo 0 si
    tira indietro e si raccoglie in 0,9 s (busto indietro, testa bassa e puntata su di te, braccia piegate indietro,
    bocca spalancata), poi resta cosi' con un tremito che cresce. Finisce ferma nella posa da cui parte scatto."""
    u = t / T
    w = liscio(0.0, 1.0, 0.0, 0.45, u)
    vib = math.sin(2 * math.pi * 11.0 * t) * liscio(0.0, 1.0, 0.3, 1.0, u)
    _caricata(arm, C, Z, CARICA_CICLO * u, w, vib=vib)


def pose_scatto(arm, C, Z, t, T=T_SCATTO):
    """0,8 s: dalla fine di carica parte in avanti di scatto, si allunga verso di te (busto e testa avanti, braccia
    tese) e torna nella posa di insegue_aperta al tempo 0 (il gioco riprende la corsa). Lo spostamento in avanti
    lo fa il gioco."""
    u = t / T
    w = liscio(1.0, 0.0, 0.0, 0.35, u)
    l = chiavi(u, [(0.0, 0.0), (0.32, 1.0), (0.6, 0.85), (1.0, 0.0)])
    tc = CARICA_CICLO + (T_APERTA - CARICA_CICLO) * u
    _caricata(arm, C, Z, tc, w, l)


# --------------------------------------------------------------------------------------------- le pozze (modo MANO)
# Le pozze colorate della Risalita (0.4.0, scelta C dell'utente): da una pozza di 1 m x 1 m e 0,7 m d'acqua esce prima
# il braccio e la mano sbatte sul grigliato, poi dal bordo salgono quattro tentacoli che strisciano lungo la passerella
# fino a circa 2 m; la presa la fa la mano, alla caviglia. Spazio: l'origine e' il punto dove sbatte la mano (il marker
# di enigmi, sul grigliato a filo del bordo), -Y verso la passerella (Godot +Z), Z su. Le misure sono quelle di
# Pozza_2_4 (enigmi, 15 novembre): pozza x -0,5..0,5, y 0,1..1,1 (Godot z -0,1..-1,1), pozze contigue a passo 1,1 m,
# acqua fino a -0,0525, fondo chiuso da -0,75 a -0,95; il bordino davanti y 0..0,1 a filo del grigliato (z 0); il
# grigliato pieno da 0 a -0,23, la passerella fino a y -1,2 (poi il muro). Lei non ci sta: il corpo resta sott'acqua e
# sotto il fondo (la testa a circa 0,28 m sotto il pelo), braccio e tentacoli passano dal fondo della pozza.

POZZA_PELO = -0.0525
POZZA_NASCOSTO = -0.97                # sotto il fondo della pozza (-0,95) non si vede niente
POZZA_CAVIGLIA = (0.0, -0.6, 0.1)       # la caviglia del giocatore sulla linea di mezzo (marker z +0,6 in Godot)
# (roll, pitch, yaw in gradi, spalla destra nel mondo, testa su, testa girata): trovati con il controllo delle zone
POZZA_GIU = (0.0, -10.0, 30.0, (-0.25, 0.45, -2.0), 0.0, 0.0)
POZZA_ATTESA = (0.0, -10.0, 30.0, (-0.25, 0.4, -0.7), 0.0, 0.0)
POZZA_PRESA = (30.0, -10.0, 45.0, (-0.2, 0.35, -0.52), -25.0, -30.0)
# il polso: (punto, direzione delle dita, dorso)
POZZA_SLAM = ((0.0, 0.04, 0.09), (0.0, -1.0, -0.15), (0.0, 0.0, 1.0))
POZZA_PRESA_POLSO = ((0.0, -0.40, 0.26), (0.0, -1.0, -0.2), (0.0, 0.2, 1.0))
POZZA_POLO = (0.0, 0.2, 1.2)            # verso dove piega il gomito (rispetto alla spalla): in alto e indietro, cosi'
                                        # l'avambraccio passa sopra il bordino (il gomito resta appena sott'acqua)
POZZA_DITA = (3.0, 1.5, 1.0)            # quanto si piegano le falangi sul grigliato: le punte premono, il palmo un poco alzato
# i quattro tentacoli che strisciano: (osso radice, x dove sale dal bordo, punta sul grigliato, partenza nella salita)
POZZA_TENTACOLI = (
    ('tentacolo_03', 0.40, (1.85, -0.35), 0.70),
    ('tentacolo_05', -0.40, (-1.85, -0.35), 0.85),
    ('tentacolo_02', 0.22, (1.25, -0.80), 1.00),
    ('tentacolo_04', -0.25, (-1.25, -0.80), 1.10),
)
T_POZZA_ESCE = 2.2
T_POZZA_ATTESA = 2.4
T_POZZA_PRESA = 0.8
T_POZZA_RESPINTA = 1.0
T_POZZA_SCENDE = 1.2
POZZA_SLAM_T = 0.62                    # quando la mano sbatte (s; AcquaDiLei.MANO_SBATTE deve essere uguale)


def _pozza_mix(a, b, k):
    return tuple(_pozza_lerp(x, y, k) for x, y in zip(a, b))


def _pozza_lerp(x, y, k):
    if isinstance(x, tuple):
        return tuple(p + (q - p) * k for p, q in zip(x, y))
    return x + (y - x) * k


def dita_piatte(arm, suf, giu=POZZA_DITA, stringi=0.0, tamburo=0.0):
    """Le dita della mano distese nel piano del palmo (dal dorso, asse Z della mano), un poco aperte, piegate di giu
    gradi per falange verso il palmo; stringi (0-1) le chiude a pugno intorno a qualcosa; tamburo (s) le fa battere
    a turno sul grigliato."""
    pm = arm.pose.bones['mano' + suf]
    Mh = pm.matrix.to_3x3()
    hx, hy, hz = Mh.col[0].normalized(), Mh.col[1].normalized(), Mh.col[2].normalized()
    Rr = arm.data.bones['mano' + suf].matrix_local
    for i, f in enumerate(DITA):
        off = Rr.inverted() @ arm.data.bones[f'{f}_1{suf}'].head_local
        if f == 'pollice':
            y = (hy * 0.6 + hx * (1 if off.x > 0 else -1) * 0.75 + hz * 0.05).normalized()
        else:
            y = (hy + hx * (off.x / 0.03) * 0.12).normalized()
        ax = hz.cross(y).normalized()       # (un angolo positivo piega verso il palmo)
        alza = 0.0
        if tamburo and f != 'pollice':
            alza = -14.0 * max(0.0, math.sin(2 * math.pi * (tamburo * 2.5 - 0.18 * i)))
        for k, g in zip((1, 2, 3), giu):
            g = g + stringi * (35 if k == 1 else 45) + (alza if k == 1 else 0.0)
            y = Matrix.Rotation(math.radians(g), 3, ax) @ y
            nm = f'{f}_{k}{suf}'
            POSE.orienta(arm, nm, arm.pose.bones[nm].head.copy(), y, hz)
            aggiorna()


def corpo_pozza(arm, C, Z, stato, t=0.0):
    """Il corpo di lei nella pozza: posa di insegue (busto, braccio sinistro, zampe sul petto), i tentacoli che non
    strisciano raccolti sotto la campana (sotto il fondo), poi tutta girata (roll, pitch, yaw) intorno alla spalla
    destra e portata con la spalla nel punto dato, la testa su e girata. Il braccio destro e i tentacoli che
    strisciano si mettono dopo."""
    roll, pitch, yaw, S, su, giro = stato
    W = arm.matrix_world
    applica(arm, base(C, campiona(C, 'insegue', 0.0), campiona(C, 'fluttua', t), campiona(C, 'statua', 0.0, False)))
    Z.leggi()
    raccogli(arm, 1.0)
    pb = arm.pose.bones['radice']
    sp = W @ arm.pose.bones['braccio.R'].head
    R = (Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Rotation(math.radians(pitch), 4, 'X')
         @ Matrix.Rotation(math.radians(roll), 4, 'Y'))
    Mw = Matrix.Translation(Vector(S)) @ R @ Matrix.Translation(-sp)
    pb.matrix = W.inverted() @ Mw @ W @ pb.matrix
    aggiorna()
    testa(arm, su=su, giro=giro)
    Z.segui()


def polso_pozza(arm, polso, dir_mano, dorso, polo=POZZA_POLO):
    """Il braccio destro col polso in un punto del mondo (spazio del marker), il gomito piegato verso polo."""
    W = arm.matrix_world
    pc = W @ arm.pose.bones['braccio.R'].head
    POSE.posa_braccio(arm, '.R', W.inverted() @ Vector(polso), W.inverted() @ (pc + Vector(polo)), Vector(dir_mano),
                      Vector(dorso))
    aggiorna()


def _catena(arm, prefisso):
    """Le ossa di un tentacolo, dalla radice alla punta (tentacolo_03 -> tentacolo_03_01, tentacolo_03_02, ...)."""
    return sorted(b.name for b in arm.data.bones if b.name.startswith(prefisso + '_'))


def _polilinea(punti, passo=0.01):
    """Punti fitti (ogni passo m) lungo i segmenti, con la lunghezza progressiva."""
    out, s = [Vector(punti[0])], [0.0]
    for a, b in zip(punti[:-1], punti[1:]):
        a, b = Vector(a), Vector(b)
        n = max(1, int((b - a).length / passo))
        for k in range(1, n + 1):
            q = a.lerp(b, k / n)
            s.append(s[-1] + (q - out[-1]).length)
            out.append(q)
    return out, s


def _bezier(a, c, b, n=40):
    return [a * (1 - u) ** 2 + c * 2 * u * (1 - u) + b * u * u for u in (k / n for k in range(n + 1))]


def pista_tentacolo(x, punta):
    """Il percorso visibile di un tentacolo: dal fondo della pozza su lungo la parete davanti, sopra il bordino (mai
    sotto 5 cm dalla cima), giu' sul grigliato e lungo la passerella fino alla punta, appoggiato (l'asse a 4,5 cm
    dal grigliato vicino al bordo, 2 cm alla punta)."""
    sx = 1.0 if punta[0] > x else -1.0
    # (sale dritto oltre la cima e passa alto sopra il bordino: le ossa sono lunghe quasi 0,4 m e la corda
    # taglierebbe l'angolo)
    su = [(x, 0.30, -0.86), (x, 0.25, -0.70), (x, 0.22, -0.35), (x, 0.21, -0.05), (x, 0.21, 0.15), (x, 0.20, 0.30),
          (x, 0.15, 0.36), (x, 0.06, 0.38), (x, -0.04, 0.36), (x, -0.13, 0.28), (x, -0.20, 0.17),
          (x + 0.03 * sx, -0.26, 0.08)]
    a = Vector((x + 0.06 * sx, -0.33, 0.045))
    b = Vector((punta[0], punta[1], 0.02))
    c = Vector((x + (punta[0] - x) * 0.35, min(-0.15, punta[1] * 0.4), 0.04))
    curva = _bezier(a, c, b, 60)
    for q in curva:
        q.z = 0.045 + (0.02 - 0.045) * min(1.0, (q - a).length / max((b - a).length, 1e-6))
    return [Vector(p) for p in su] + curva


def _sulla_polilinea(P, S, da, dist):
    """Primo punto della polilinea, dopo l'indice da, a distanza dist (corda) da P[da]: (punto, indice, lunghezza)."""
    c = P[da]
    for i in range(da + 1, len(P)):
        if (P[i] - c).length >= dist:
            a, b = P[i - 1], P[i]
            # sulla retta a-b il punto a distanza dist da c
            d = b - a
            f = a - c
            A, B, Cc = d.dot(d), 2 * f.dot(d), f.dot(f) - dist * dist
            disc = max(B * B - 4 * A * Cc, 0.0)
            u = (-B + math.sqrt(disc)) / (2 * A) if A > 1e-12 else 1.0
            u = min(max(u, 0.0), 1.0)
            return a.lerp(b, u), i - 1, S[i - 1] + (S[i] - S[i - 1]) * u
    return None, len(P) - 1, S[-1]


def tentacolo_pozza(arm, radice, pista, s_punta, alza=0.0):
    """Mette la catena del tentacolo lungo la pista (polilinea dal fondo della pozza) con la punta a s_punta metri
    sulla pista. Se il tentacolo avanza, la parte sotto il fondo (nascosta) fa una curva verso il basso tanto lunga da
    tenere la punta li'. Se non basta, si allunga solo il primo osso, quello attaccato alla campana, tutto sotto il
    fondo (non si vede: POZZA_NASCOSTO): le altre ossa restano lunghe uguali (posate a corda) e il pezzo che si vede ha
    la lunghezza vera. Le ossa girano il meno possibile rispetto al padre. Restituisce dove e' arrivata la punta sulla
    pista (meno di s_punta se non basta neanche cosi')."""
    W = arm.matrix_world
    Wi = W.inverted()
    nomi = _catena(arm, radice)
    L = [arm.data.bones[n].length for n in nomi]
    R0 = W @ arm.pose.bones[nomi[0]].head
    pista_p, pista_s = _polilinea(pista)
    F = pista_p[0]

    def posa_da(P, S, lg, giunti, da, ossa):
        for l in ossa:
            q, da, s = _sulla_polilinea(P, S, da, l)
            if q is None:
                return None, giunti
            # (il punto trovato e' su un segmento: per il prossimo osso si riparte da li')
            P.insert(da + 1, q)
            S.insert(da + 1, s)
            da += 1
            giunti.append(q)
        return S[da] - lg, giunti

    def prova(b):
        giu = _bezier(R0, (R0 + F) * 0.5 + Vector((0, 0, -b)), F, 60)
        P, S = _polilinea(giu + pista_p[1:], 0.01)
        lg = _polilinea(giu, 0.01)[1][-1]
        return posa_da(P, S, lg, [R0], 0, L)

    def allunga(h):
        # il primo osso dritto da R0 verso F, lungo h; le altre ossa da li'
        d = F - R0
        j1 = R0 + d.normalized() * min(h, d.length)
        P, S = _polilinea([j1, F] + pista_p[1:], 0.01)
        lg = (F - j1).length
        return posa_da(P, S, lg, [R0, j1], 0, L[1:])

    def oltre(s):
        return s is None or s > s_punta
    s0, g0 = prova(0.0)
    if '--diagnosi' in sys.argv:
        print(f'DIAGNOSI {radice}: R0 {tuple(round(v, 2) for v in R0)} F {tuple(round(v, 2) for v in F)} s0 {s0} L {[round(l, 2) for l in L]} punta {s_punta:.2f}', flush=True)
    if not oltre(s0):
        # il tentacolo non basta: si allunga il primo osso, finche' la sua punta resta sotto il fondo
        d = F - R0
        h_max = L[0]
        if d.z > 1e-6:
            h_max = max(L[0], d.length * min(1.0, (POZZA_NASCOSTO - R0.z) / d.z))
        lo, hi = L[0], h_max
        giunti, arrivo = g0, s0
        sh, gh = allunga(hi)
        if oltre(sh):
            for _ in range(30):
                mid = (lo + hi) * 0.5
                s_, g_ = allunga(mid)
                if oltre(s_):
                    hi = mid
                else:
                    lo, giunti, arrivo = mid, g_, s_
        else:
            giunti, arrivo = gh, sh
    else:
        lo, hi = 0.0, 4.0
        giunti, arrivo = None, None
        for _ in range(30):
            mid = (lo + hi) * 0.5
            s, g = prova(mid)
            if oltre(s):
                lo = mid
            else:
                hi, giunti, arrivo = mid, g, s
        if giunti is None:
            giunti, arrivo = prova(hi)[1], -1.0
    while len(giunti) < len(nomi) + 1:
        giunti.append(giunti[-1] + (giunti[-1] - giunti[-2]).normalized() * L[len(giunti) - 1])
    # la punta che si alza un poco (le ultime tre ossa)
    if alza:
        n = len(giunti)
        for k in range(max(1, n - 3), n):
            giunti[k] = giunti[k] + Vector((0, 0, alza * (k - (n - 4)) / 3.0))
    for i, nm in enumerate(nomi):
        pb = arm.pose.bones[nm]
        bone = arm.data.bones[nm]
        if bone.parent:
            Mp = arm.pose.bones[bone.parent.name].matrix
            base_m = Mp @ (bone.parent.matrix_local.inverted() @ bone.matrix_local)
        else:
            base_m = pb.matrix.copy()
        Rb = base_m.to_3x3().normalized()
        y_new = (Wi @ giunti[i + 1] - Wi @ giunti[i]).normalized() if i + 1 < len(giunti) else Rb.col[1]
        q = Rb.col[1].normalized().rotation_difference(y_new)
        N = (q.to_matrix() @ Rb).to_4x4()
        N.translation = Wi @ giunti[i]
        pb.matrix = N
        aggiorna()
    return arrivo


def _pista_lunghezza(pista):
    return _polilinea(pista)[1][-1]


_POZZA_PISTE = {}
POZZA_MARGINE_PISTA = 0.14      # quanto di tentacolo resta da avanzare nella posa d'attesa (le punte che respirano, lo
                                # scatto della presa)


def piste_pozza(arm, C, Z):
    """Le piste dei quattro tentacoli, tagliate dove ci arrivano davvero: nella posa d'attesa, con la parte nascosta
    dritta, meno POZZA_MARGINE_PISTA. Si calcolano una volta; stampa dove finiscono le punte."""
    if _POZZA_PISTE:
        return _POZZA_PISTE
    corpo_pozza(arm, C, Z, POZZA_ATTESA)
    for radice, x, punta, _ in POZZA_TENTACOLI:
        pista = pista_tentacolo(x, punta)
        P, S = _polilinea(pista)
        # (fin dove arriva la punta con POZZA_MARGINE_PISTA ancora da avanzare: la pista continua dritta oltre la fine)
        d = (P[-1] - P[-2]).normalized()
        arrivo = tentacolo_pozza(arm, radice, pista + [P[-1] + d * POZZA_MARGINE_PISTA], S[-1] + POZZA_MARGINE_PISTA)
        lim = min(S[-1], arrivo - POZZA_MARGINE_PISTA)
        taglio = [q for q, s in zip(P, S) if s <= lim]
        _POZZA_PISTE[radice] = taglio
        t = taglio[-1]
        print(f'POZZA pista {radice}: punta a ({t.x:.2f}, {t.y:.2f}), {math.hypot(t.x, t.y):.2f} m dal marker '
              f'(voluta {punta}, il tentacolo arriva a {arrivo:.2f} m di pista su {S[-1]:.2f})', flush=True)
    return _POZZA_PISTE


def tentacoli_pozza(arm, quanto, alza=0.0, avanti=0.0):
    """I quattro tentacoli: quanto(nome, lunghezza della pista) -> metri di pista percorsi dalla punta."""
    arrivi = {}
    for radice, x, punta, _ in POZZA_TENTACOLI:
        pista = _POZZA_PISTE[radice] + []
        lung = _pista_lunghezza(pista) + POZZA_MARGINE_PISTA
        # (oltre la fine tagliata la pista continua dritta: lo scatto della presa)
        d = (pista[-1] - pista[-2]).normalized()
        pista.append(pista[-1] + d * POZZA_MARGINE_PISTA)
        voluto = min(quanto(radice, lung) + avanti, lung)
        arrivi[radice] = tentacolo_pozza(arm, radice, pista, voluto, alza)
        if '--pozza' in sys.argv and arrivi[radice] < voluto - 0.02:
            print(f'POZZA corto {radice}: la punta a {arrivi[radice]:.2f} m di {voluto:.2f} (pista {lung:.2f})', flush=True)
    return arrivi


def _striscia(u):
    """Come avanza una punta (0-1 della pista) nel tempo (0-1): due spinte decise con una pausa in mezzo."""
    return chiavi(u, [(0.0, 0.0), (0.30, 0.52), (0.42, 0.56), (0.78, 0.96), (1.0, 1.0)])


def pose_pozza_esce(arm, C, Z, t, T=T_POZZA_ESCE):
    """2,2 s: da sotto il fondo sale col braccio destro alzato (la mano esce dall'acqua a circa 0,3 s), la mano si
    alza sopra il bordo e sbatte sul grigliato (POZZA_SLAM_T), poi dal bordo salgono i quattro tentacoli e strisciano
    sulla passerella, a scatti. Finisce nella posa di pozza_attesa al tempo 0."""
    piste_pozza(arm, C, Z)
    k = chiavi(t, [(0.0, 0.0), (0.40, 1.0)])
    stato = _pozza_mix(POZZA_GIU, POZZA_ATTESA, liscio(0.0, 1.0, 0.0, 1.0, k))
    corpo_pozza(arm, C, Z, stato)
    sp = arm.matrix_world @ arm.pose.bones['braccio.R'].head
    alto = sp + Vector((0.05, -0.08, 0.85))
    chiavi_polso = [(0.0, alto), (0.40, Vector((-0.10, 0.24, 0.36))), (0.50, Vector((-0.05, 0.13, 0.42))),
                    (POZZA_SLAM_T, Vector(POZZA_SLAM[0])), (POZZA_SLAM_T + 0.05, Vector(POZZA_SLAM[0]) + Vector((0, 0, 0.012))),
                    (POZZA_SLAM_T + 0.12, Vector(POZZA_SLAM[0]))]
    if t <= 0.40:
        polso = alto.lerp(chiavi_polso[1][1], liscio(0.0, 1.0, 0.0, 0.40, t))
    else:
        polso = Vector(chiavi(t, [(a, tuple(b)) for a, b in chiavi_polso[1:]]))
    dm, dz = gira_mano((0.0, -0.25, 1.0), (0.0, 1.0, 0.15), POZZA_SLAM[1], POZZA_SLAM[2], liscio(0.0, 1.0, 0.42, POZZA_SLAM_T, t))
    polso_pozza(arm, polso, dm, dz)
    kd = liscio(0.0, 1.0, 0.45, 0.56, t)
    dita_piatte(arm, '.R', giu=tuple(b + (a - b) * kd for a, b in zip(POZZA_DITA, (10.0, 12.0, 12.0))),
                stringi=chiavi(t, [(0.0, 0.25), (0.45, 0.0), (POZZA_SLAM_T, -0.05), (POZZA_SLAM_T + 0.1, 0.0)]))

    def quanto(nome, lung):
        da = [d for r, _, _, d in POZZA_TENTACOLI if r == nome][0]
        return (lung - POZZA_MARGINE_PISTA) * _striscia(liscio(0.0, 1.0, da, da + (T - da) * 0.95, t) if t > da else 0.0)
    tentacoli_pozza(arm, quanto)


def pose_pozza_attesa(arm, C, Z, t, T=T_POZZA_ATTESA):
    """Ciclo 2,4 s: la mano premuta sul grigliato, le dita che battono a turno, i tentacoli fermi sulla passerella
    con le punte che si alzano e avanzano di pochi centimetri, il corpo sott'acqua che respira."""
    piste_pozza(arm, C, Z)
    u = (t / T) % 1.0
    roll, pitch, yaw, S, su, giro = POZZA_ATTESA
    S = (S[0], S[1], S[2] + 0.015 * math.sin(2 * math.pi * u))
    corpo_pozza(arm, C, Z, (roll, pitch, yaw + 2.0 * math.sin(2 * math.pi * u), S, su, giro))
    polso_pozza(arm, POZZA_SLAM[0], POZZA_SLAM[1], POZZA_SLAM[2])
    dita_piatte(arm, '.R', tamburo=u * T if u > 0.0 else 0.0)
    if '--pozza' in sys.argv and t == 0.0:
        W = arm.matrix_world
        print('POZZA dita: ' + ', '.join(f"{f} {(W @ arm.pose.bones[f + '_3.R'].tail).z:.3f}" for f in DITA)
              + f"; polso {(W @ arm.pose.bones['mano.R'].head).z:.3f}", flush=True)
    a = 0.03 * (0.5 - 0.5 * math.cos(2 * math.pi * u))
    tentacoli_pozza(arm, lambda nome, lung: lung - POZZA_MARGINE_PISTA + 0.04 * (0.5 - 0.5 * math.cos(2 * math.pi * u)), alza=a)


def pose_pozza_presa(arm, C, Z, t, T=T_POZZA_PRESA):
    """0,8 s: la mano si stacca dal grigliato, scatta alla caviglia (0,1-0,3 s) e la stringe, poi tira verso la
    pozza; il corpo sale e si gira sotto il pelo per arrivarci; i tentacoli scattano avanti."""
    piste_pozza(arm, C, Z)
    k = liscio(0.0, 1.0, 0.08, 0.30, t)
    corpo_pozza(arm, C, Z, _pozza_mix(POZZA_ATTESA, POZZA_PRESA, k))
    slam = Vector(POZZA_SLAM[0])
    presa = Vector(POZZA_PRESA_POLSO[0])
    tira = presa + Vector((0.0, 0.12, 0.0))
    if t < 0.08:
        polso = slam.lerp(slam + Vector((0, 0.02, 0.10)), liscio(0.0, 1.0, 0.0, 0.08, t))
    elif t < 0.30:
        polso = (slam + Vector((0, 0.02, 0.10))).lerp(presa, liscio(0.0, 1.0, 0.08, 0.30, t))
    else:
        polso = presa.lerp(tira, liscio(0.0, 1.0, 0.40, 0.8, t))
    dm, dz = gira_mano(POZZA_SLAM[1], POZZA_SLAM[2], POZZA_PRESA_POLSO[1], POZZA_PRESA_POLSO[2], liscio(0.0, 1.0, 0.08, 0.30, t))
    polso_pozza(arm, polso, dm, dz)
    dita_piatte(arm, '.R', stringi=chiavi(t, [(0.0, 0.0), (0.12, -0.15), (0.28, -0.1), (0.38, 0.8), (0.8, 0.85)]))
    tentacoli_pozza(arm, lambda nome, lung: lung - POZZA_MARGINE_PISTA, avanti=0.10 * liscio(0.0, 1.0, 0.1, 0.3, t),
                    alza=0.06 * liscio(0.0, 1.0, 0.1, 0.3, t))


def _pozza_torna(arm, C, Z, t, T, veloce):
    """Torna sotto: la mano si stacca e rientra sopra il bordo nell'acqua, i tentacoli scivolano indietro nella
    pozza, il corpo scende sotto il fondo (POZZA_GIU)."""
    piste_pozza(arm, C, Z)
    if veloce:
        tm = (0.0, 0.10, 0.22, 0.35)    # stacca, su, indietro sopra l'acqua, dentro
        tc = (0.20, 1.0)                # il corpo scende
        tt = (0.10, 0.65)               # i tentacoli rientrano
    else:
        tm = (0.0, 0.30, 0.50, 0.70)
        tc = (0.45, 1.2)
        tt = (0.10, 0.95)
    kc = liscio(0.0, 1.0, tc[0], tc[1], t)
    corpo_pozza(arm, C, Z, _pozza_mix(POZZA_ATTESA, POZZA_GIU, kc))
    sp = arm.matrix_world @ arm.pose.bones['braccio.R'].head
    alto = sp + Vector((0.05, -0.08, 0.85))
    slam = Vector(POZZA_SLAM[0])
    su = slam + Vector((0.0, 0.03, 0.22))
    indietro = Vector((-0.05, 0.30, 0.20))      # (sopra l'acqua, oltre il bordino, prima di scendere)
    dentro = Vector((-0.10, 0.36, -0.15))
    if t < tm[1]:
        polso = slam.lerp(su, liscio(0.0, 1.0, tm[0], tm[1], t))
    elif t < tm[2]:
        polso = su.lerp(indietro, liscio(0.0, 1.0, tm[1], tm[2], t))
    elif t < tm[3]:
        polso = indietro.lerp(dentro, liscio(0.0, 1.0, tm[2], tm[3], t))
    else:
        polso = dentro.lerp(alto, liscio(0.0, 1.0, tm[3], tc[1], t))
        polso.z = min(polso.z, dentro.z)
    dm, dz = gira_mano(POZZA_SLAM[1], POZZA_SLAM[2], (0.0, -0.25, 1.0), (0.0, 1.0, 0.15), liscio(0.0, 1.0, tm[0], tm[3], t))
    polso_pozza(arm, polso, dm, dz)
    kd = liscio(0.0, 1.0, tm[0], tm[1], t)
    dita_piatte(arm, '.R', giu=tuple(a + (b - a) * kd for a, b in zip(POZZA_DITA, (10.0, 12.0, 12.0))),
                stringi=0.25 * liscio(0.0, 1.0, tm[0], tm[3], t))
    tentacoli_pozza(arm, lambda nome, lung: (lung - POZZA_MARGINE_PISTA) * (1.0 - liscio(0.0, 1.0, tt[0], tt[1], t)))


def pose_pozza_respinta(arm, C, Z, t, T=T_POZZA_RESPINTA):
    """1 s: il getto sulla mano: la ritira di scatto nella pozza, i tentacoli scivolano via in fretta, giu' sotto."""
    _pozza_torna(arm, C, Z, t, T, True)


def pose_pozza_scende(arm, C, Z, t, T=T_POZZA_SCENDE):
    """1,2 s: torna sotto senza fretta (non ti ha preso): la mano si stacca e striscia indietro, i tentacoli
    rientrano nella pozza."""
    _pozza_torna(arm, C, Z, t, T, False)


def pose_tuffo_sb1(arm, C, Z, t, T=1.3):
    """1,3 s dopo affacciata_sb1 (che finisce a 5,4 s): si stacca dal bordo, si alza un poco e si tuffa giu' nel
    pozzo (-5 m), le braccia che restano in alto, la testa che ti guarda fino all'ultimo."""
    d, h = BORDO_SB1
    u = t / T
    tent = campiona(C, 'insegue', (5.4 + t) * 0.5)
    aff = campiona(C, 'affacciata', 0.0)
    applica(arm, base(C, campiona(C, 'insegue', 0.0), tent, aff))
    Z.leggi()
    for n in ('colonna_1', 'colonna_2', 'petto', 'collo', 'testa'):
        arm.pose.bones[n].matrix_basis = aff[n]
    aggiorna()
    vita = mondo(arm, arm.pose.bones['colonna_1'].head)
    voglio = Vector((0.0, -(d - 1.06), h - 0.57))
    sal = chiavi(u, [(0.0, 0.0), (0.18, 0.22), (0.3, 0.15)])
    if u > 0.3:     # cade sempre piu' in fretta
        x = (u - 0.3) / 0.7
        sal = 0.15 + (GIU - 0.15) * x * x
    sposta(arm, voglio - vita + Vector((0, liscio(0.0, 0.35, 0.1, 0.6, u), sal)))
    busto(arm, avanti=chiavi(u, [(0.0, 0.0), (0.2, -10.0), (0.6, 8.0)]))
    testa(arm, giro=0.0, su=chiavi(u, [(0.0, 2.0), (0.25, 6.0), (0.7, -14.0)]),
          piega=chiavi(u, [(0.0, -6.0), (0.4, 0.0)]), collo=0.5)
    for suf, s in (('.L', 1), ('.R', -1)):
        bordo = Vector((s * 0.58, -(d + 0.12), h + 0.04))
        pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
        alto = pc + Vector((s * 0.45, 0.10, 1.05))
        k = liscio(0.0, 1.0, 0.05, 0.3, u)
        # (prima di staccarsi il bordo e' fermo nel mondo: lei si alza e i polsi restano li')
        polso = bordo.lerp(alto, k)
        braccio_mondo(arm, suf, polso, (0.9, 0.3, -0.2), (0.0, -0.3, 1.0), (0.0, 1.0, 0.0))
    Z.segui()


def pose_riemerge(arm, C, Z, t, T=1.8):
    """1,8 s: dal fondo (-5 m) su fino alla posa della corsa, a bocca che si spalanca mentre esce, e il primo
    ciclo di insegue_aperta parte dalla sua posa finale (insegue_aperta al tempo 0)."""
    u = t / T
    sal = chiavi(u, [(0.0, GIU), (0.68, 0.25), (0.84, -0.05), (1.0, 0.0)])
    k = liscio(0.0, 1.0, 0.5, 1.0, u)
    apre = liscio(0.0, 1.0, 0.35, 0.8, u)

    def ritocco(a):
        busto(a, avanti=-26 * (1 - k))
        testa(a, su=14 * (1 - k))
    aperta(arm, C, Z, 0.0, chiude=1.0 - apre, k=k, extra=ritocco)
    sposta(arm, (0.0, 0.0, sal))
    if k < 1.0:
        # salendo le braccia stanno lungo i fianchi, poi si aprono in avanti
        for suf, s in (('.L', 1), ('.R', -1)):
            a = math.sin(2 * math.pi * (0.0 if s > 0 else 0.5))
            teso = ((0.30 - 0.04 * a, -0.95 - 0.10 * a, 0.10 + 0.08 * math.cos(2 * math.pi * (0.0 if s > 0 else 0.5))),
                    (0.7, 0.0, -0.4), (0.12, -1.0, 0.05), (0.1, 0.1, 1.0))
            lungo = ((0.30, -0.12, -1.0), (0.5, 0.5, 0.0), (0.05, -0.15, -1.0), (1.0, 0.0, 0.0))
            p = [tuple(x + (y - x) * k for x, y in zip(a_, b_)) for a_, b_ in zip(lungo, teso)]
            braccio(arm, suf, *p)
        Z.segui()


def fauce_riemerge(t, T=1.8):
    return liscio(0.0, 1.0, 0.35, 0.8, t / T)


def pose_schianto(arm, C, Z, t, T=2.4):
    """2,4 s, contro il portello chiuso: arriva lanciata da 1,8 m dietro, sbatte la faccia sull'oblò (0,35 s) con
    la bocca spalancata e i palmi sul portello ai lati, rimbalza appena, si schiaccia di nuovo e resta li',
    premuta, a fiato corto (il gioco va al nero)."""
    dd, hh = OBLO
    contro = chiavi(t, [(0.0, 0.0), (0.35, 1.0), (0.48, 0.86), (0.7, 1.0), (T, 1.0)])

    def ritocco(a):
        busto(a, avanti=10 * contro, lato=0.0)
        testa(a, su=-4 * contro)
    aperta(arm, C, Z, t * 0.6, chiude=0.0, k=1.0 - contro, extra=ritocco)
    # la faccia sull'oblò: l'occhio (il punto piu' avanti del viso e' poco davanti all'occhio) va sul piano
    occhio = mondo(arm, arm.pose.bones['occhio'].head)
    voglio = Vector((0.0, -dd + VISO_DAVANTI + 1.8 * (1.0 - contro),
                     hh + 0.08 - 0.04 * liscio(0.0, 1.0, 0.7, T, t) + OBLO_SU * (1.0 - contro)))
    sposta(arm, voglio - occhio)
    fauce_mascella(arm, C, 1.0 + 0.25 * contro)
    for suf, s in (('.L', 1), ('.R', -1)):
        pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
        a = math.sin(2 * math.pi * (0.0 if s > 0 else 0.5))
        teso = pc + rot_giro(arm) @ Vector((s * (0.30 - 0.04 * a), -0.95 - 0.10 * a,
                                            0.10 + 0.08 * math.cos(2 * math.pi * (0.0 if s > 0 else 0.5))))
        alto = pc + rot_giro(arm) @ Vector((s * 0.5, -0.8, 0.45))
        # i palmi sul telaio del portello, a 0,71 m dall'asse (il telaio va da 0,65 a 0,78, la sua faccia sul piano
        # dell'oblò: ambienti-2, 24 ottobre); il polso a PALMO (+4 mm) dal piano: il palmo e le dita a filo
        contatto = Vector((s * 0.71, -dd + PALMO + 0.004, hh + 0.05 - 0.05 * liscio(0.0, 1.0, 0.7, T, t)))
        # dalle braccia tese della corsa, su ai lati della testa, e giu' piatte sul portello
        polso = teso.lerp(alto, liscio(0.0, 1.0, 0.0, 0.18, t)).lerp(contatto, liscio(0.0, 1.0, 0.18, 0.36, t))
        braccio_mondo(arm, suf, polso, (0.8, 0.3, -0.5), (0.0, -0.25, 1.0), (0.0, 1.0, 0.0))
    Z.segui()


PALMO = 0.24            # schianto: il polso a tanto dal portello, perché il palmo ci stia a filo
VISO_DAVANTI = 0.39     # quanto il punto piu' avanti della testa (la frangia) sta davanti all'occhio (m, misurato sulla mesh:
                        # sonda di schianto, 1 cm dal portello)


# --------------------------------------------------------------------------------------------- gli oblò della risalita

# Lei dietro un grosso oblò in tre corridoi della risalita (24 ottobre, "pose diverse di Jilly ogni volta"): calma, a
# fauce chiusa, ti guarda (l'occhio e la testa li gira il gioco verso il giocatore), poi si stacca e sparisce lenta nel
# buio dell'acqua. Il vetro e' un piano verticale a OBLO[0] m davanti all'origine, col centro a OBLO[1] m d'altezza (come
# lo schianto: il gioco mette l'origine di lei a centro_vetro + normale * OBLO[0] - su * OBLO[1]); OBLO_R il raggio del
# vetro (la parte che si vede).
OBLO_R = 0.55
T_OBLO = 4.0            # i cicli delle pose (il respiro)
T_STACCA = 2.6          # si stacca: indietro e giu' nel buio
SBIRCIA_OCCHIO = 0.60     # sbircia: l'occhio a tanto dal centro del vetro, sul bordo (il vetro degli oblò di enigmi ha 0,6 m di
                          # raggio: mezzo viso dietro il muro)
STACCA_ALZA = 0.04      # m: nei distacchi i palmi partono gia' staccati dal vetro di tanto (nella dissolvenza di 0,3 s fra
                        # la posa ferma e il distacco le mani, fondendo due pose, passavano il vetro di 1-3 cm)
OBLO_INDIETRO = 8.0     # gradi: quanto e' inclinata col basso all'indietro (i tentacoli lontani dal vetro)
SBIRCIA_LATO = 1.0      # da che parte del bordo sbircia: +1 alla sua sinistra (a destra per chi guarda dal corridoio);
                        # oblo_sbircia_altro dall'altra parte


RACCOLTA = 0.95        # sbircia: quanto si stringono i tentacoli sotto la campana (0 aperti come fluttua, 1 dritti giu')


def raccogli(arm, k):
    """Stringe i tentacoli sotto la campana: ogni tentacolo gira alla radice perche' la punta si avvicini alla
    verticale (lo scostamento orizzontale dalla radice scala di 1 - k), la forma resta quella della posa."""
    for b in arm.data.bones:
        if not b.name.startswith('tentacolo') or b.name.startswith(ZAMPE):
            continue
        if b.parent and b.parent.name.startswith('tentacolo'):
            continue
        ultimo = b
        while ultimo.children:
            ultimo = ultimo.children[0]
        h = arm.pose.bones[b.name].head.copy()
        v = arm.pose.bones[ultimo.name].tail - h
        oriz = Vector((v.x, v.y, 0.0)) * (1.0 - k)
        z = -math.sqrt(max(v.length_squared - oriz.length_squared, 0.0))
        w = Vector((oriz.x, oriz.y, z))
        asse = v.cross(w)
        if asse.length < 1e-6:
            continue
        ruota(arm, b.name, asse.normalized(), math.degrees(v.angle(w)))


def _calma(arm, C, Z, t, avanti=8.0, su=-3.0, indietro=OBLO_INDIETRO, raccolta=False):
    """La base calma degli oblò: il corpo e i tentacoli che fluttuano piano, le dita morbide, la fauce chiusa, il busto
    appena sporto verso il vetro. Prima di spostarla e di mettere le mani."""
    u = (t / T_OBLO) % 1.0
    corpo = campiona(C, 'fluttua', 2.0 * u)
    # raccolta: i tentacoli stretti sotto di lei (quelli della statua) invece che aperti, per le vasche strette
    tent = campiona(C, 'fluttua', 2.0 * u)
    dita = mix(campiona(C, 'statua', 0.0, False), campiona(C, 'insegue', 0.0), 0.4, DITA_OSSA)
    applica(arm, base(C, corpo, tent, dita))
    Z.leggi()
    busto(arm, avanti=avanti + 1.5 * math.sin(2 * math.pi * u), lato=1.5 * math.sin(2 * math.pi * u + 0.7))
    testa(arm, su=su + indietro - 1.5 * math.sin(2 * math.pi * u + 0.5))
    fauce_mascella(arm, C, 0.0)
    if raccolta:
        raccogli(arm, RACCOLTA)
    # tutta lei inclinata col basso all'indietro (la testa resta dritta): i tentacoli che fluttuano non arrivano al vetro
    ruota(arm, 'radice', (1, 0, 0), indietro)


def _occhio_in(arm, voglio):
    """Sposta tutta lei perche' l'occhio vada nel punto [voglio] (spazio del modello)."""
    sposta(arm, Vector(voglio) - mondo(arm, arm.pose.bones['occhio'].head))


def _palmo(arm, suf, punto):
    """Il palmo piatto sul vetro in [punto] (il polso a PALMO dal piano, piu' 6 mm: nelle dissolvenze le dita avanzano un poco), le dita in su."""
    braccio_mondo(arm, suf, Vector(punto) + Vector((0.0, 0.006, 0.0)), (0.8, 0.3, -0.5), (0.0, -0.25, 1.0), (0.0, 1.0, 0.0))


def pose_oblo_schiacciata(arm, C, Z, t):
    """Ciclo: la faccia e i due palmi sul vetro, ti fissa e respira piano."""
    dd, hh = OBLO
    u = (t / T_OBLO) % 1.0
    _calma(arm, C, Z, t, avanti=10.0, su=-4.0, raccolta=True)
    _occhio_in(arm, (0.0, -dd + VISO_DAVANTI - 0.010 + 0.004 * math.sin(2 * math.pi * u), hh + 0.01 * math.sin(2 * math.pi * u)))
    for suf, s in (('.L', 1), ('.R', -1)):
        _palmo(arm, suf, (s * (OBLO_R - 0.12), -dd + PALMO, hh - 0.08 + 0.01 * math.sin(2 * math.pi * u + s)))
    Z.segui()


def pose_oblo_schiacciata_stacca(arm, C, Z, t):
    """Si stacca dal vetro: le mani lasciano per prime e salgono, poi va indietro e scende nel buio."""
    dd, hh = OBLO
    u = t / T_STACCA
    via = liscio(0.0, 1.0, 0.15, 1.0, u)
    _calma(arm, C, Z, 0.0, avanti=10.0 - 22.0 * via, su=-4.0 - 16.0 * liscio(0.0, 1.0, 0.35, 1.0, u), raccolta=True)
    _occhio_in(arm, (0.0, -dd + VISO_DAVANTI - 0.010 + 1.8 * via, hh - 1.5 * via ** 1.6))
    lascia = liscio(0.0, 1.0, 0.0, 0.4, u)
    for suf, s in (('.L', 1), ('.R', -1)):
        pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
        vetro = Vector((s * (OBLO_R - 0.12), -dd + PALMO + STACCA_ALZA, hh - 0.08))
        su = pc + Vector((s * 0.45, 0.25, 0.75))
        _palmo(arm, suf, vetro.lerp(su, lascia))
    Z.segui()


def pose_oblo_sbircia(arm, C, Z, t, s=SBIRCIA_LATO):
    """Ciclo: sbircia dal bordo dell'oblò, mezzo viso dentro il vetro e una mano sola, la testa piegata verso il bordo,
    il corpo dietro il muro."""
    dd, hh = OBLO
    u = (t / T_OBLO) % 1.0
    _calma(arm, C, Z, t, avanti=6.0, su=-2.0, raccolta=True)
    testa(arm, piega=-s * 16.0 + 1.5 * math.sin(2 * math.pi * u), giro=-s * 10.0)
    # l'occhio poco dentro il bordo: si vede mezzo viso, il resto e il corpo dietro il muro
    _occhio_in(arm, (s * SBIRCIA_OCCHIO + 0.01 * math.sin(2 * math.pi * u), -dd + VISO_DAVANTI - 0.022, hh + 0.03))
    # la mano verso il centro dell'oblò, poggiata sul vetro accanto al viso (l'altra resta dietro il muro)
    suf_vetro = '.L' if s < 0 else '.R'
    _palmo(arm, suf_vetro, (s * (OBLO_R - 0.50), -dd + PALMO, hh - 0.12 + 0.008 * math.sin(2 * math.pi * u)))
    altro = '.R' if suf_vetro == '.L' else '.L'
    braccio(arm, altro, (0.30, -0.12, -1.0), (0.5, 0.5, 0.0), (0.05, -0.15, -1.0), (1.0, 0.0, 0.0))
    Z.segui()


def pose_oblo_sbircia_stacca(arm, C, Z, t, s=SBIRCIA_LATO):
    """Si ritira dietro il bordo e scende nel buio."""
    dd, hh = OBLO
    u = t / T_STACCA
    via = liscio(0.0, 1.0, 0.1, 1.0, u)
    _calma(arm, C, Z, 0.0, avanti=6.0 - 14.0 * via, su=-2.0 - 10.0 * via, raccolta=True)
    testa(arm, piega=-s * 16.0 * (1 - via), giro=-s * 10.0 * (1 - via))
    # (indietro e giu', non di lato: la vasca del corridoio del personale e' stretta)
    _occhio_in(arm, (s * SBIRCIA_OCCHIO, -dd + VISO_DAVANTI - 0.022 + 1.8 * via, hh + 0.03 - 1.3 * via ** 1.6))
    suf_vetro = '.L' if s < 0 else '.R'
    pc = mondo(arm, arm.pose.bones['braccio' + suf_vetro].head)
    vetro = Vector((s * (OBLO_R - 0.50), -dd + PALMO + STACCA_ALZA, hh - 0.12))
    _palmo(arm, suf_vetro, vetro.lerp(pc + Vector((0.0, 0.25, 0.7)), liscio(0.0, 1.0, 0.0, 0.35, u)))
    altro = '.R' if suf_vetro == '.L' else '.L'
    braccio(arm, altro, (0.30, -0.12, -1.0), (0.5, 0.5, 0.0), (0.05, -0.15, -1.0), (1.0, 0.0, 0.0))
    Z.segui()


def _palmo_capovolta(arm, suf, punto):
    """Il palmo sul vetro in [punto] (spazio del modello, piu' 1,2 cm: nella sfumatura verso il distacco le dita
    avanzano un poco) con lei a testa in giu': il gomito verso l'esterno e verso
    il suo corpo (in alto), le dita in giu' (verso la sua testa)."""
    sp = arm.pose.bones['braccio' + suf].head.copy()
    W = arm.matrix_world.inverted() @ (Vector(punto) + Vector((0.0, 0.012, 0.0)))
    fuori = 1.0 if sp.x > 0 else -1.0
    POSE.posa_braccio(arm, suf, W, sp + Vector((fuori * 0.8, 0.3, 0.4)), Vector((0.0, -0.25, -1.0)),
                      Vector((0.0, 1.0, 0.0)))


def _mani_capovolta(arm, dd, hh, lascia=0.0, staccando=False):
    for suf in ('.L', '.R'):
        sp = mondo(arm, arm.pose.bones['braccio' + suf].head)
        f = 1.0 if sp.x > 0 else -1.0
        vetro = Vector((f * (OBLO_R - 0.14), -dd + PALMO + (STACCA_ALZA if staccando else 0.0), hh - 0.12))
        _palmo_capovolta(arm, suf, vetro.lerp(sp + Vector((f * 0.5, 0.3, -0.6)), lascia))


def pose_oblo_capovolta(arm, C, Z, t):
    """Ciclo: a testa in giu', l'occhio rovesciato contro il vetro, i palmi ai lati della testa, i capelli e i tentacoli
    verso l'alto (verso il corpo), dondola appena."""
    dd, hh = OBLO
    u = (t / T_OBLO) % 1.0
    _calma(arm, C, Z, t, avanti=4.0, su=6.0, indietro=OBLO_INDIETRO)
    # tutta lei girata intorno all'asse avanti-indietro: la faccia resta verso il vetro
    ruota(arm, 'radice', (0, 1, 0), 180.0 + 1.0 * math.sin(2 * math.pi * u))
    _occhio_in(arm, (0.0, -dd + VISO_DAVANTI - 0.046, hh + 0.01 * math.sin(2 * math.pi * u)))
    _mani_capovolta(arm, dd, hh)
    Z.segui()


def pose_oblo_capovolta_stacca(arm, C, Z, t):
    """Si stacca a testa in giu', va indietro e scende nel buio."""
    dd, hh = OBLO
    u = t / T_STACCA
    via = liscio(0.0, 1.0, 0.15, 1.0, u)
    _calma(arm, C, Z, 0.0, avanti=4.0 - 10.0 * via, su=6.0, indietro=OBLO_INDIETRO)
    ruota(arm, 'radice', (0, 1, 0), 180.0)
    _occhio_in(arm, (0.0, -dd + VISO_DAVANTI - 0.046 + 2.0 * via, hh - 2.6 * via ** 1.6))
    _mani_capovolta(arm, dd, hh, liscio(0.0, 1.0, 0.0, 0.4, u), staccando=True)
    Z.segui()


# L'oblò della torre (quarta posa, scelta A dell'utente, 24 ottobre): arriva dal buio e appoggia al vetro l'occhio
# enorme, che riempie l'oblò e segue il giocatore; poi si stacca lenta e torna nel buio. La testa piegata indietro
# (la frangia va su, l'occhio e' la cosa piu' avanti), i palmi sul vetro ai lati, fuori dall'oblò.
OCCHIO_SU = 24.0            # gradi: la testa piegata indietro
OCCHIO_DAVANTI = 0.278      # quanto la pelle piu' avanti (l'occhio) sta davanti all'osso dell'occhio con la testa cosi'
OCCHIO_VIA = (0.45, 0.0)    # da dove arriva e dove torna: tanti metri indietro e giu' (il buio della vasca)
OCCHIO_MANI = 0.42          # i palmi sul vetro a tanto dal centro (dietro il muro, fuori dall'oblò)
T_ARRIVA = 3.0


def _occhio_posa(arm, C, Z, t, via, mani=1.0, staccando=False):
    """L'occhio sul vetro; via: 0 sul vetro, 1 lontana nel buio (OCCHIO_VIA); mani: 1 i palmi sul vetro."""
    dd, hh = OBLO
    u = (t / T_OBLO) % 1.0
    _calma(arm, C, Z, t, avanti=6.0, su=OCCHIO_SU * (1.0 - 0.6 * via), indietro=20.0, raccolta=True)
    _occhio_in(arm, (0.006 * math.sin(2 * math.pi * u), -dd + OCCHIO_DAVANTI + 0.008 + 0.003 * math.sin(2 * math.pi * u)
                     + OCCHIO_VIA[0] * via, hh - OCCHIO_VIA[1] * via ** 1.4))
    for suf, s in (('.L', 1), ('.R', -1)):
        pc = mondo(arm, arm.pose.bones['braccio' + suf].head)
        vetro = Vector((s * OCCHIO_MANI, -dd + PALMO + (STACCA_ALZA if staccando else 0.0),
                        hh - 0.10 + 0.006 * math.sin(2 * math.pi * u + s)))
        # (lungo i fianchi e un po' indietro: le mani non passano mai davanti al piano del vetro)
        lungo = pc + Vector((s * 0.35, 0.25, -0.85))
        _palmo(arm, suf, lungo.lerp(vetro, mani))
    Z.segui()


def pose_oblo_occhio(arm, C, Z, t):
    """Ciclo: l'occhio sul vetro, respira piano."""
    _occhio_posa(arm, C, Z, t, 0.0)


def pose_oblo_occhio_arriva(arm, C, Z, t):
    """3 s: dal buio (indietro e giu') fino al vetro, rallentando; le mani si posano alla fine."""
    u = t / T_ARRIVA
    via = 1.0 - liscio(0.0, 1.0, 0.0, 0.9, u)
    # (il tempo del respiro finisce dove comincia il ciclo oblo_occhio: niente scatto al passaggio)
    _occhio_posa(arm, C, Z, (t - T_ARRIVA) % T_OBLO, via, mani=liscio(0.0, 1.0, 0.6, 1.0, u))


def pose_oblo_occhio_stacca(arm, C, Z, t):
    """Si stacca lenta e torna nel buio: le mani lasciano, poi indietro e giu'."""
    u = t / T_STACCA
    _occhio_posa(arm, C, Z, t, liscio(0.0, 1.0, 0.1, 1.0, u), mani=1.0 - liscio(0.0, 1.0, 0.0, 0.35, u), staccando=True)


ANIMAZIONI = {
    # nome: (durata, in ciclo, funzione)
    'sale_dall_acqua': (1.6, False, lambda a, C, Z, t: pose_sale(a, C, Z, t, 1.6)),
    'sale_dall_acqua_veloce': (1.0, False, lambda a, C, Z, t: pose_sale(a, C, Z, t, 1.0)),
    'sale_puntata': (1.6, False, lambda a, C, Z, t: pose_sale_puntata(a, C, Z, t, 1.6)),
    'sale_mano': (1.6, False, lambda a, C, Z, t: pose_sale_mano(a, C, Z, t, 1.6)),
    'incombe': (2.4, True, lambda a, C, Z, t: pose_incombe(a, C, Z, t)),
    'presa': (1.2, False, pose_presa),
    'respinta': (1.2, False, pose_respinta),
    'scende': (1.0, False, lambda a, C, Z, t: pose_scende(a, C, Z, t)),
    'colpo_grata': (0.5, True, lambda a, C, Z, t: pose_grata(a, C, Z, t)),
    'colpo_grata_sbieco': (0.5, True, lambda a, C, Z, t: pose_grata(a, C, Z, t, sbieco=SBIECO)),
    'affacciata_sb1': (5.4, False, pose_sb1),
    'scende_sb1': (1.2, False, lambda a, C, Z, t: pose_scende_sb1(a, C, Z, t)),
    # il tunnel del viaggio sottomarino
    'insegue_aperta': (T_APERTA, True, pose_insegue_aperta),
    'insegue_morde': (T_APERTA, True, pose_insegue_morde),
    'ritrae': (2.0, False, lambda a, C, Z, t: pose_ritrae(a, C, Z, t)),
    'tuffo_sb1': (1.3, False, lambda a, C, Z, t: pose_tuffo_sb1(a, C, Z, t)),
    'riemerge': (1.8, False, lambda a, C, Z, t: pose_riemerge(a, C, Z, t)),
    'schianto': (2.4, False, lambda a, C, Z, t: pose_schianto(a, C, Z, t)),
    'carica': (T_CARICA, False, lambda a, C, Z, t: pose_carica(a, C, Z, t)),
    'scatto': (T_SCATTO, False, lambda a, C, Z, t: pose_scatto(a, C, Z, t)),
    # le pozze della Risalita (modo MANO)
    'pozza_esce': (T_POZZA_ESCE, False, lambda a, C, Z, t: pose_pozza_esce(a, C, Z, t)),
    'pozza_attesa': (T_POZZA_ATTESA, True, lambda a, C, Z, t: pose_pozza_attesa(a, C, Z, t)),
    'pozza_presa': (T_POZZA_PRESA, False, lambda a, C, Z, t: pose_pozza_presa(a, C, Z, t)),
    'pozza_respinta': (T_POZZA_RESPINTA, False, lambda a, C, Z, t: pose_pozza_respinta(a, C, Z, t)),
    'pozza_scende': (T_POZZA_SCENDE, False, lambda a, C, Z, t: pose_pozza_scende(a, C, Z, t)),
    # gli oblò della risalita
    'oblo_schiacciata': (T_OBLO, True, pose_oblo_schiacciata),
    'oblo_schiacciata_stacca': (T_STACCA, False, pose_oblo_schiacciata_stacca),
    'oblo_sbircia': (T_OBLO, True, pose_oblo_sbircia),
    'oblo_sbircia_stacca': (T_STACCA, False, pose_oblo_sbircia_stacca),
    'oblo_sbircia_altro': (T_OBLO, True, lambda a, C, Z, t: pose_oblo_sbircia(a, C, Z, t, -SBIRCIA_LATO)),
    'oblo_sbircia_altro_stacca': (T_STACCA, False, lambda a, C, Z, t: pose_oblo_sbircia_stacca(a, C, Z, t, -SBIRCIA_LATO)),
    'oblo_capovolta': (T_OBLO, True, pose_oblo_capovolta),
    'oblo_capovolta_stacca': (T_STACCA, False, pose_oblo_capovolta_stacca),
    # l'oblò della torre
    'oblo_occhio': (T_OBLO, True, pose_oblo_occhio),
    'oblo_occhio_arriva': (T_ARRIVA, False, pose_oblo_occhio_arriva),
    'oblo_occhio_stacca': (T_STACCA, False, pose_oblo_occhio_stacca),
}

# Quanto e' aperta la fauce (le blend shape di fauce_apre: 0 chiusa, 1 come alla fine) nel tempo, per le animazioni
# che la tengono aperta: la libreria di Godot le scrive come tracce (vedi medusa_inseguimento_libreria.gd).
FAUCE = {
    'insegue_aperta': lambda t: 1.0,
    'insegue_morde': fauce_morde,
    'ritrae': lambda t: 1.0,
    'riemerge': fauce_riemerge,
    'schianto': lambda t: 1.0,
    'carica': lambda t: 1.0,
    'scatto': lambda t: 1.0,
    'oblo_schiacciata': lambda t: 0.0,
    'oblo_schiacciata_stacca': lambda t: 0.0,
    'oblo_sbircia': lambda t: 0.0,
    'oblo_sbircia_stacca': lambda t: 0.0,
    'oblo_sbircia_altro': lambda t: 0.0,
    'oblo_sbircia_altro_stacca': lambda t: 0.0,
    'oblo_capovolta': lambda t: 0.0,
    'oblo_capovolta_stacca': lambda t: 0.0,
    'oblo_occhio': lambda t: 0.0,
    'oblo_occhio_arriva': lambda t: 0.0,
    'oblo_occhio_stacca': lambda t: 0.0,
}


# --------------------------------------------------------------------------------------------- uscita

def nodi_glb():
    """Nodi del GLB (riposo): {nome: (indice, genitore, Matrix locale glTF)} e i giunti dello scheletro."""
    with open(GLB, 'rb') as f:
        d = f.read()
    n = struct.unpack_from('<I', d, 12)[0]
    js = json.loads(d[20:20 + n])
    genitore = {}
    for i, nd in enumerate(js['nodes']):
        for c in nd.get('children', []):
            genitore[c] = i
    out = {}
    for i, nd in enumerate(js['nodes']):
        t = Vector(nd.get('translation', (0, 0, 0)))
        r = nd.get('rotation', (0, 0, 0, 1))
        s = Vector(nd.get('scale', (1, 1, 1)))
        M = Matrix.LocRotScale(t, Quaternion((r[3], r[0], r[1], r[2])), s)
        out[nd.get('name', str(i))] = (i, genitore.get(i), M)
    giunti = [js['nodes'][j]['name'] for j in js['skins'][0]['joints']]
    nomi = {v[0]: k for k, v in out.items()}
    return out, giunti, nomi


def globali_glb(nodi, nomi):
    G = {}

    def g(nome):
        if nome in G:
            return G[nome]
        i, p, M = nodi[nome]
        G[nome] = (g(nomi[p]) @ M) if p is not None else M
        return G[nome]
    for k in nodi:
        g(k)
    return G


class Registro:
    """Trasformazioni locali (riferimento dei nodi del GLB) delle ossa nella posa attuale."""

    def __init__(self, arm):
        self.arm = arm
        self.nodi, self.giunti, self.nomi = nodi_glb()
        G0 = globali_glb(self.nodi, self.nomi)
        self.C = {}
        for b in self.giunti:
            B0 = A @ arm.matrix_world @ arm.data.bones[b].matrix_local @ AI
            self.C[b] = B0.inverted() @ G0[b]
        self.genitore = {b: self.nomi[self.nodi[b][1]] for b in self.giunti}
        self.G0 = G0
        # controllo: nella posa di riposo le locali sono quelle del GLB
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix()
        aggiorna()
        loc = self.locali()
        err = max(max(abs(x - y) for r1, r2 in zip(loc[b], self.nodi[b][2]) for x, y in zip(r1, r2))
                  for b in self.giunti)
        print(f'CONTROLLO riposo: scarto massimo {err:.2e}')
        assert err < 1e-4, 'il riferimento delle ossa non torna con il GLB'

    def locali(self):
        arm = self.arm
        G = {}
        for b in self.giunti:
            G[b] = A @ arm.matrix_world @ arm.pose.bones[b].matrix @ AI @ self.C[b]
        out = {}
        for b in self.giunti:
            p = self.genitore[b]
            Gp = G[p] if p in G else self.G0[p]
            out[b] = Gp.inverted() @ G[b]
        return out

    def chiave(self):
        out = []
        for b, M in self.locali().items():
            t, q, s = M.decompose()
            out.append([round(t.x, 5), round(t.y, 5), round(t.z, 5),
                        round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6)])
        return out


def _scena_anteprima(nome):
    """Il riferimento intorno a lei: il fondo e l'acqua della vasca, la grata, il bordo del pozzo."""
    for o in [o for o in bpy.data.objects if o.name.startswith('rif_')]:
        bpy.data.objects.remove(o, do_unlink=True)

    def scatola(nm, c, dim, colore, alfa=1.0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=c)
        o = bpy.context.object
        o.name = 'rif_' + nm
        o.scale = dim
        m = bpy.data.materials.new(nm)
        m.use_nodes = True
        bs = m.node_tree.nodes['Principled BSDF']
        bs.inputs['Base Color'].default_value = (*colore, 1)
        bs.inputs['Alpha'].default_value = alfa
        o.data.materials.append(m)
    if nome == 'colpo_grata':
        scatola('grata', (0, -GRATA - 0.03, 3.5), (3.0, 0.06, 5.0), (0.25, 0.27, 0.3))
    elif nome == 'colpo_grata_sbieco':
        scatola('grata', (0, -GRATA - 0.03, 3.5), (3.0, 0.06, 5.0), (0.25, 0.27, 0.3))
        bpy.data.objects['rif_grata'].rotation_euler = (0.0, 0.0, -math.radians(SBIECO))
    elif nome == 'affacciata_sb1':
        d, h = BORDO_SB1
        scatola('pavimento', (0, -d - 1.5, h - 0.1), (4.0, 3.0, 0.2), (0.3, 0.3, 0.32))
        scatola('muro_pozzo', (0, -d - 0.05, h - 2.0), (2.2, 0.1, 4.0), (0.25, 0.25, 0.27))
    elif nome.startswith('oblo_'):
        # il vetro dell'oblò (trasparente) e la cornice, nel muro; il corridoio dalla parte -y
        d, h = OBLO
        scatola('vetro', (0, -d - 0.01, h), (2 * OBLO_R, 0.02, 2 * OBLO_R), (0.6, 0.8, 0.85), 0.15)
        bpy.ops.mesh.primitive_torus_add(location=(0, -d - 0.06, h), rotation=(math.pi / 2, 0, 0),
                                         major_radius=OBLO_R + 0.06, minor_radius=0.07)
        bpy.context.object.name = 'rif_cornice'
        for nm, c, dim in (('muro_sx', (-OBLO_R - 1.1, -d - 0.15, h), (2.0, 0.2, 4.0)),
                           ('muro_dx', (OBLO_R + 1.1, -d - 0.15, h), (2.0, 0.2, 4.0)),
                           ('muro_su', (0, -d - 0.15, h + OBLO_R + 1.0), (4.4, 0.2, 2.0)),
                           ('muro_giu', (0, -d - 0.15, h - OBLO_R - 1.0), (4.4, 0.2, 2.0))):
            scatola(nm, c, dim, (0.25, 0.25, 0.27))
    else:
        f, a = VASCA
        scatola('fondo', (0, -1.5, f - 0.1), (6.0, 6.0, 0.2), (0.3, 0.3, 0.32))
        scatola('acqua', (0, -1.5, a - 0.005), (6.0, 6.0, 0.01), (0.1, 0.35, 0.4), 0.55)


def anteprime(arm, C, Z, nome, durata, fn, cartella, n=6):
    """Foglio di controllo: n fotogrammi dell'animazione, da davanti e di lato, con le mesh."""
    from PIL import Image
    mesh_attive(True)
    _scena_anteprima(nome)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 8
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 360, 480
    if sc.world is None:
        sc.world = bpy.data.worlds.new('w')
        sc.world.use_nodes = True
        sc.world.node_tree.nodes['Background'].inputs[1].default_value = 1.0
        sole = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN'))
        sole.data.energy = 3.0
        sole.rotation_euler = (0.8, 0, 0.5)
        sc.collection.objects.link(sole)
        # il riferimento: il piano dell'acqua a "su" (circa all'altezza della vita), la grata, il bordo di SB1
        cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.lens = 30
    cam = sc.camera
    righe = []
    viste = (('davanti', ((2.0, -7.5, 3.6), (0, -0.8, 3.2))), ('lato', ((7.5, -1.2, 3.6), (0, -0.9, 3.0))))
    if nome.startswith('oblo_'):
        # dal corridoio, all'altezza degli occhi, e di lato da dietro il muro (il muro di lato si nasconde)
        d, h = OBLO
        viste = (('davanti', ((0.3, -d - 2.2, h - 0.1), (0, -d, h))), ('lato', ((4.5, -d + 1.2, h + 0.3), (0, -d + 0.8, h - 0.4))))
    for vista, (pos, tgt) in viste:
        if nome.startswith('oblo_'):
            for o in bpy.data.objects:
                if o.name.startswith('rif_muro'):
                    o.hide_render = vista == 'lato'
        pezzi = []
        for i in range(n):
            t = durata * i / (n - 1) if n > 1 else 0.0
            fn(arm, C, Z, t)
            cam.location = pos
            cam.rotation_euler = (Vector(tgt) - Vector(pos)).to_track_quat('-Z', 'Y').to_euler()
            f = os.path.join(cartella, f'_{nome}_{vista}_{i}.png')
            sc.render.filepath = f
            bpy.ops.render.render(write_still=True)
            pezzi.append(Image.open(f).convert('RGB'))
            os.remove(f)
        righe.append(pezzi)
    W, H = 360, 480
    G = Image.new('RGB', (W * n, H * 2))
    for r, pezzi in enumerate(righe):
        for i, im in enumerate(pezzi):
            G.paste(im, (W * i, H * r))
    G.save(os.path.join(cartella, f'{nome}.jpg'), quality=85)
    mesh_attive(False)


def zona_pozza(p):
    """In che zona e' un punto (spazio del marker della pozza): aria, acqua (della sua pozza), fondo (la soletta della
    sua pozza: ci passa, dallo scarico), nascosta (sotto i fondi e sotto il grigliato); in maiuscolo i difetti
    (BORDINO, GRIGLIATO, MURO, ACQUA_ALTRA / FONDO_ALTRO: un'altra pozza)."""
    x, y, z = p
    if y < -1.2:
        return 'MURO' if z > -0.23 else 'nascosta'
    if z > 0.0:
        return 'aria'
    if y >= 0.0:
        i = round(x / 1.1)
        j = round((y - 0.6) / 1.1)
        if abs(x - 1.1 * i) <= 0.5 and abs(y - 0.6 - 1.1 * j) <= 0.5:
            mia = (i, j) == (0, 0)
            if z > POZZA_PELO:
                return 'aria' if mia else 'aria_altra'
            if z >= -0.75:
                return 'acqua' if mia else 'ACQUA_ALTRA'
            if z >= -0.95:
                return 'fondo' if mia else 'FONDO_ALTRO'
            return 'nascosta'
        return 'BORDINO' if z >= -0.95 else 'nascosta'
    return 'GRIGLIATO' if z >= -0.23 else 'nascosta'


def controlla_pozza(arm, C, Z, nome, durata, fn):
    """Modo MANO: a ogni fotogramma, per ogni osso (6 punti, piu' sotto di quanto e' spesso per braccio, mano e
    tentacoli che strisciano), la zona; stampa i fotogrammi con difetti, le ossa del corpo fuori dall'acqua e quanto
    manca alle punte dei tentacoli."""
    W = arm.matrix_world
    strisciano = tuple(r + '_' for r, _, _, _ in POZZA_TENTACOLI)
    braccio_r = ('braccio.R', 'avambraccio.R', 'mano.R')

    def spessore(nm):
        if nm.startswith('braccio'):
            return 0.05
        if nm.startswith('avambraccio'):
            return 0.04
        if nm.startswith('mano'):
            return 0.02
        if nm.startswith(strisciano):
            return 0.012
        if nm.endswith('.R') and nm.startswith(DITA):
            return 0.006
        return 0.0
    n = int(round(durata * FPS))
    difetti = 0
    fuori = set()
    for i in range(n + 1):
        t = min(i / FPS, durata)
        fn(arm, C, Z, t)
        male = set()
        for pb in arm.pose.bones:
            h, c = W @ pb.head, W @ pb.tail
            m = spessore(pb.name)
            libero = pb.name.startswith(braccio_r + strisciano) or (pb.name.endswith('.R') and pb.name.startswith(DITA))
            for k in range(7):
                q = h.lerp(c, k / 6)
                for qq in ((q, q - Vector((0, 0, m))) if m else (q,)):
                    z = zona_pozza(qq)
                    if z.isupper() or z == 'aria_altra':
                        male.add(f'{pb.name} {z}' + (f' ({qq.x:.2f} {qq.y:.2f} {qq.z:.2f})' if '--diagnosi' in sys.argv else ''))
                    elif z == 'aria' and not libero:
                        fuori.add(pb.name)
                        male.add(f'{pb.name} fuori')
        if male:
            difetti += 1
            if difetti <= 6:
                print(f'POZZA {nome} t={t:.2f}: ' + ', '.join(sorted(male)[:8]), flush=True)
    print(f'POZZA {nome}: {difetti} fotogrammi con difetti su {n + 1}' + (f'; fuori dall acqua: {sorted(fuori)[:6]}' if fuori else ''), flush=True)


def controlla_vetro(arm, C, Z, nome, durata, fn, n=9):
    """Oblò: quanto la pelle (tutte le mesh) arriva vicino al piano del vetro (y = -OBLO[0]) in n fotogrammi; stampa
    il punto piu' avanti per ciascuno (positivo: dietro il vetro, negativo: dentro)."""
    import numpy as np
    mesh_attive(True)
    dd = OBLO[0]
    peggio = 1e9
    for i in range(n):
        t = durata * i / (n - 1)
        fn(arm, C, Z, t)
        dg = bpy.context.evaluated_depsgraph_get()
        avanti, chi = 1e9, ''
        senza_mani, chi2 = 1e9, ''
        lo, hi = np.full(3, 1e9), np.full(3, -1e9)
        for o in bpy.data.objects:
            if o.type != 'MESH' or o.name.startswith('rif_') or o.hide_render:
                continue
            oe = o.evaluated_get(dg)
            me = oe.to_mesh()
            if len(me.vertices) == 0:
                oe.to_mesh_clear()
                continue
            co = np.empty(len(me.vertices) * 3)
            me.vertices.foreach_get('co', co)
            co = co.reshape(-1, 3) @ np.array(o.matrix_world.to_3x3()).T + np.array(o.matrix_world.translation)
            oe.to_mesh_clear()
            d = float((co[:, 1] + dd).min())
            lo, hi = np.minimum(lo, co.min(0)), np.maximum(hi, co.max(0))
            if os.environ.get('CHI'):
                print(f'  OGGETTO {o.name}: x {co[:, 0].min():.2f}..{co[:, 0].max():.2f} vetro {(co[:, 1].min() + dd) * 100:.1f} cm', flush=True)
            if d < avanti:
                avanti, chi = d, o.name
            if 'Mani' not in o.name and d < senza_mani:
                senza_mani, chi2 = d, o.name
        peggio = min(peggio, avanti)
        print(f'VETRO {nome} t={t:.2f}: al piu\' avanti {avanti * 100:.1f} cm dal vetro ({chi}); senza le mani {senza_mani * 100:.1f} cm ({chi2}); '
              f'ingombro dal centro del vetro: lati {lo[0]:.2f}..{hi[0]:.2f}, dietro fino a {hi[1] + dd:.2f}, '
              f'sotto {lo[2] - OBLO[1]:.2f}, sopra {hi[2] - OBLO[1]:.2f}', flush=True)
    print(f'VETRO {nome}: minimo {peggio * 100:.1f} cm', flush=True)
    mesh_attive(False)


def main():
    global CORPO, TENTACOLI, DITA_OSSA
    arm = carica()
    tutte = [b.name for b in arm.data.bones]
    TENTACOLI = [n for n in tutte if n.startswith('tentacolo') and not n.startswith(ZAMPE)]
    DITA_OSSA = [n for n in tutte if n.startswith(DITA)]
    CORPO = [n for n in tutte if n not in TENTACOLI and n not in DITA_OSSA]
    mesh_attive(False)
    C = campioni(arm)
    reg = Registro(arm)
    Z = Zampe(arm)
    solo = None
    if '--solo' in sys.argv:
        solo = sys.argv[sys.argv.index('--solo') + 1].split(',')
    out = {'fps': FPS, 'ossa': reg.giunti, 'giu': GIU, 'grab': GRAB, 'grata': GRATA, 'bordo_sb1': BORDO_SB1,
           'animazioni': {}}
    if os.path.exists(USCITA) and solo:
        with open(USCITA) as f:
            out['animazioni'] = json.load(f).get('animazioni', {})
    cartella = os.path.join(BUILD, CARTELLA_ANTEPRIME)
    os.makedirs(cartella, exist_ok=True)
    for nome, (durata, ciclo, fn) in ANIMAZIONI.items():
        if solo and nome not in solo:
            continue
        n = int(round(durata * FPS))
        chiavi_ = []
        for i in range(n + 1):
            t = i / FPS
            if ciclo and i == n:
                t = 0.0     # in ciclo l'ultimo fotogramma e' il primo
            fn(arm, C, Z, t)
            chiavi_.append(reg.chiave())
        out['animazioni'][nome] = {'durata': durata, 'ciclo': ciclo, 'chiavi': chiavi_}
        if nome in FAUCE:
            out['animazioni'][nome]['fauce'] = [round(FAUCE[nome](min(i / FPS, durata) if not (ciclo and i == n) else 0.0), 4)
                                                for i in range(n + 1)]
        print(f'ANIMAZIONE {nome}: {n + 1} fotogrammi', flush=True)
        if '--vetro' in sys.argv and nome.startswith('oblo_'):
            controlla_vetro(arm, C, Z, nome, durata, fn)
        if '--pozza' in sys.argv and nome.startswith('pozza_'):
            controlla_pozza(arm, C, Z, nome, durata, fn)
        if '--anteprime' in sys.argv:
            anteprime(arm, C, Z, nome, durata, fn, cartella)
    with open(USCITA, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print('SCRITTO', USCITA, os.path.getsize(USCITA) // 1024, 'KB')


if __name__ == '__main__':
    main()
