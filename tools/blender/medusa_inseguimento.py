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
      tanto in alto rispetto all'origine), la testa girata di lato, poi la gira verso di te e ti fissa.

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
    mascella(arm, chiavi(t, [(0.0, 0.0), (0.45, 0.0), (0.75, 18.0), (1.2, 22.0)]))
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


ANIMAZIONI = {
    # nome: (durata, in ciclo, funzione)
    'sale_dall_acqua': (1.6, False, lambda a, C, Z, t: pose_sale(a, C, Z, t, 1.6)),
    'sale_dall_acqua_veloce': (1.0, False, lambda a, C, Z, t: pose_sale(a, C, Z, t, 1.0)),
    'incombe': (2.4, True, lambda a, C, Z, t: pose_incombe(a, C, Z, t)),
    'presa': (1.2, False, pose_presa),
    'respinta': (1.2, False, pose_respinta),
    'scende': (1.0, False, lambda a, C, Z, t: pose_scende(a, C, Z, t)),
    'colpo_grata': (0.5, True, lambda a, C, Z, t: pose_grata(a, C, Z, t)),
    'colpo_grata_sbieco': (0.5, True, lambda a, C, Z, t: pose_grata(a, C, Z, t, sbieco=SBIECO)),
    'affacciata_sb1': (5.4, False, pose_sb1),
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
    for vista, (pos, tgt) in (('davanti', ((2.0, -7.5, 3.6), (0, -0.8, 3.2))), ('lato', ((7.5, -1.2, 3.6), (0, -0.9, 3.0)))):
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
        print(f'ANIMAZIONE {nome}: {n + 1} fotogrammi', flush=True)
        if '--anteprime' in sys.argv:
            anteprime(arm, C, Z, nome, durata, fn, cartella)
    with open(USCITA, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print('SCRITTO', USCITA, os.path.getsize(USCITA) // 1024, 'KB')


if __name__ == '__main__':
    main()
