"""Pose della medusa calcolate con IK analitica a due ossa (niente vincoli da cuocere).

posa_statua: mani giunte sul petto come in docs/concept/medusa_statua.jpg (gomiti in basso ai fianchi,
avambracci che salgono davanti al busto, palmi uno contro l'altro, dita appena piegate).
Le pose si scrivono come pose bone (pb.matrix) e si possono salvare come azioni per Godot.
"""
import math

import bpy
from mathutils import Matrix, Quaternion, Vector

DITA = ['pollice', 'indice', 'medio', 'anulare', 'mignolo']


def aggiorna():
    bpy.context.view_layer.update()


def matrice_osso(arm, nome):
    """Matrice di riposo (spazio armatura) dell'osso."""
    return arm.data.bones[nome].matrix_local.copy()


def orienta(arm, nome, testa, direzione, z_verso=None):
    """Mette l'osso con la testa in 'testa' e l'asse Y lungo 'direzione'. Se z_verso e' dato, l'asse Z
    punta il piu' possibile li'; altrimenti si usa la rotazione minima dalla posa di riposo (torsione naturale)."""
    pb = arm.pose.bones[nome]
    rest = matrice_osso(arm, nome)
    y_rest = rest.col[1].xyz.normalized()
    y_new = Vector(direzione).normalized()
    if z_verso is None:
        q = y_rest.rotation_difference(y_new)
        R = q.to_matrix() @ rest.to_3x3()
    else:
        z = Vector(z_verso) - y_new * Vector(z_verso).dot(y_new)
        z.normalize()
        x = y_new.cross(z)
        R = Matrix((x, y_new, z)).transposed()
    M = R.to_4x4()
    M.translation = Vector(testa)
    pb.matrix = M
    aggiorna()


def ik_due_ossa(S, W, a, b, polo):
    """Gomito per spalla S, polso W, lunghezze a, b e un punto 'polo' verso cui piegare."""
    S, W, polo = Vector(S), Vector(W), Vector(polo)
    d = W - S
    dist = min(d.length, a + b - 1e-4)
    u = d.normalized()
    x = (a * a - b * b + dist * dist) / (2 * dist)
    h = math.sqrt(max(a * a - x * x, 0))
    v = (polo - S) - u * (polo - S).dot(u)
    v.normalize()
    return S + u * x + v * h, S + u * dist


def lunghezza(arm, nome):
    return arm.data.bones[nome].length


def piega_dita(arm, suf, gradi, pollice=None, divaricate=0.0):
    for nome in DITA:
        for f in (1, 2, 3):
            pb = arm.pose.bones[f'{nome}_{f}{suf}']
            g = gradi if nome != 'pollice' else (pollice if pollice is not None else gradi * 0.5)
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler = (-math.radians(g), 0, 0)
    aggiorna()


def azzera(arm):
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    aggiorna()


def posa_braccio(arm, suf, polso, polo, dir_mano, dorso_mano):
    sp = arm.matrix_world.inverted() @ (arm.matrix_world @ arm.pose.bones['braccio' + suf].head)
    a, b = lunghezza(arm, 'braccio' + suf), lunghezza(arm, 'avambraccio' + suf)
    gomito, polso = ik_due_ossa(sp, polso, a, b, polo)
    orienta(arm, 'braccio' + suf, sp, gomito - sp)
    orienta(arm, 'avambraccio' + suf, gomito, polso - gomito)
    orienta(arm, 'mano' + suf, polso, dir_mano, dorso_mano)


def posa_statua(arm):
    """Mani giunte sul petto (posa della statua)."""
    azzera(arm)
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = Vector((s * 0.085, -0.245, 0.115))
        polo = Vector((s * 0.32, -0.12, -0.2))
        dir_mano = Vector((-s * 0.42, -0.18, 0.89))      # in su e verso il centro
        dorso = Vector((s * 1.0, -0.15, 0.25))           # dorso verso l'esterno: palmi uno contro l'altro
        posa_braccio(arm, suf, polso, polo, dir_mano, dorso)
        piega_dita(arm, suf, 28, pollice=12)
    # testa appena china, come la statua
    pb = arm.pose.bones['testa']
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = (math.radians(6), 0, 0)
    aggiorna()
