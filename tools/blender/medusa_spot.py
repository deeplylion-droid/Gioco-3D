"""Animazioni di Jilly per lo spot della crociera (GDD, "Lo spot della crociera Jubilee"; inquadrature 5-6):
sul piedistallo, sveglia e allegra, saluta con la mano.

Usa la stessa macchina di medusa_inseguimento.py (pose costruite fotogramma per fotogramma sullo scheletro di
assets_src/medusa/medusa.glb, scritte nel riferimento dei nodi del GLB; medusa.glb non cambia). La libreria
Godot la fa godot/tools/medusa_inseguimento_libreria.gd con gli argomenti dello spot:
res://assets/models/medusa/medusa_spot.res, animazioni "spot/<nome>".

La posa parte dalla statua (in piedi sui tentacoli, appoggiati al piedistallo: restano quelli della statua,
così non scivolano), sveglia: le due zampe incrociate sul petto di "insegue" (regola del GDD: il seno resta
coperto) seguono il busto. Parte con le mani sui fianchi; il braccio destro saluta di lato (la mano resta fuori dal
viso), il sinistro resta sul fianco; sorride con il corpo (scelta dell'utente del 23 ottobre): le spalle su, la testa
inclinata verso la mano (l'occhio a mezzaluna e la campana che pulsa li mette JillySpot).

Animazioni (30 fps):
  ferma (ciclo 1,0 s): la posa d'inizio del saluto, ferma (le mani sui fianchi, le zampe sul petto): è la posa di
    JillySpot prima e dopo il saluto, così il saluto parte e finisce senza scatti (dalla statua, le mani giunte e le
    zampe sul piano, il passaggio alle zampe sul petto sarebbe un salto);
  saluta_su (0,8 s): dalle mani sui fianchi alza il braccio destro e piega la testa;
  saluta (ciclo 1,0 s): la mano va a destra e a sinistra, il busto ondeggia appena;
  saluta_giu (0,8 s): abbassa il braccio e torna dritta, le mani sui fianchi (la posa d'inizio di saluta_su).

Uso: flock /home/user/tools/render.lock /home/user/tools/blender-venv/bin/python \
         tools/blender/medusa_spot.py [--anteprime] [--solo nome,nome]
Esce assets_src/medusa/build/spot.json (rigenerato, non nel repository); con --anteprime i fogli di controllo
in assets_src/medusa/build/spot_anteprime/.
"""
import math
import os
import sys

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import medusa_inseguimento as M  # noqa: E402
from medusa_inseguimento import applica, base, braccio, busto, campiona, chiavi, testa  # noqa: E402

M.USCITA = os.path.join(M.BUILD, 'spot.json')
M.CARTELLA_ANTEPRIME = 'spot_anteprime'

# il braccio destro alzato (polso rispetto alla spalla, riferimento del busto: x verso l'esterno, -y davanti, z su)
SU = (0.50, -0.10, 0.42)
GIU = (0.10, -0.12, -0.42)          # lungo il fianco (inizio e fine)
FIANCO = (0.16, -0.06, -0.38)       # il sinistro, appoggiato al fianco
SPALLE = 8.0                        # gradi: le spalle su mentre saluta (il sorriso con il corpo)
PIEGA = 9.0                         # gradi: la testa inclinata verso la mano


def _posa_sveglia(arm, C, Z):
    """La statua sveglia: busto, testa e tentacoli della statua, le zampe incrociate di insegue sul petto."""
    statua = campiona(C, 'statua', 0.0, False)
    insegue = campiona(C, 'insegue', 0.0)
    applica(arm, base(C, insegue, statua, statua))
    Z.leggi()
    for n in ('radice', 'campana', 'colonna_1', 'colonna_2', 'petto', 'collo', 'testa', 'mascella'):
        arm.pose.bones[n].matrix_basis = statua[n]
    M.aggiorna()


def _braccia(arm, k_su, onda):
    """Il destro: dal fianco (k_su 0) alla mano alzata (1); onda da -1 a 1 = la mano a sinistra o a destra.
    Il sinistro sul fianco."""
    polso = tuple(g + (s - g) * k_su for g, s in zip(GIU, SU))
    polso = (polso[0] + 0.05 * onda * k_su, polso[1], polso[2] - 0.02 * abs(onda) * k_su)
    a = math.radians(-12.0 + 24.0 * onda * k_su)
    su_mano = (math.sin(a) * 0.9, -0.12, math.cos(a))
    # dal fianco la mano scende (dita in giù, palmo verso la coscia); in alto il palmo guarda davanti
    dita = tuple(g + (s - g) * k_su for g, s in zip((0.05, -0.1, -1.0), su_mano))
    dorso = tuple(g + (s - g) * k_su for g, s in zip((1.0, 0.0, 0.0), (0.0, 1.0, 0.1)))
    braccio(arm, '.R', polso, (0.8, 0.35, -0.5), dita, dorso)
    # la mano che saluta si apre (la posa di riposo, la statua, ha le dita piegate di 28 gradi)
    M.POSE.piega_dita(arm, '.R', -22.0 * k_su, pollice=-8.0 * k_su)
    braccio(arm, '.L', FIANCO, (0.7, 0.4, -0.3), (0.05, -0.15, -1.0), (1.0, 0.1, 0.0))


def spalle(arm, gradi):
    """Le spalle su (le clavicole che salgono): il sorriso con il corpo (scelta dell'utente del 23 ottobre)."""
    M.ruota(arm, 'clavicola.L', (0, 1, 0), -gradi)
    M.ruota(arm, 'clavicola.R', (0, 1, 0), gradi)


def pose_ferma(arm, C, Z, t, T=1.0):
    _posa_sveglia(arm, C, Z)
    _braccia(arm, 0.0, 0.0)
    Z.segui()


def pose_saluta_su(arm, C, Z, t, T=0.8):
    _posa_sveglia(arm, C, Z)
    k = M.liscio(0.0, 1.0, 0.0, T, t)
    busto(arm, avanti=-3.0 * k, lato=-4.0 * k)
    spalle(arm, SPALLE * k)
    testa(arm, su=5.0 * k, giro=0.0, piega=-PIEGA * k)
    _braccia(arm, k, -1.0 * M.liscio(0.0, 1.0, T * 0.5, T, t))
    Z.segui()


def pose_saluta(arm, C, Z, t, T=1.0):
    _posa_sveglia(arm, C, Z)
    u = (t / T) % 1.0
    onda = -math.cos(2 * math.pi * u)        # da -1 (inizio, come la fine di saluta_su) a 1 e indietro
    busto(arm, avanti=-3.0, lato=-4.0 + 1.5 * onda, giro=2.0 * onda)
    spalle(arm, SPALLE + 2.0 * math.sin(4 * math.pi * u))
    testa(arm, su=5.0, piega=-PIEGA + 2.0 * onda)
    _braccia(arm, 1.0, onda)
    Z.segui()


def pose_saluta_giu(arm, C, Z, t, T=0.8):
    _posa_sveglia(arm, C, Z)
    k = 1.0 - M.liscio(0.0, 1.0, 0.0, T, t)
    busto(arm, avanti=-3.0 * k, lato=-4.0 * k)
    spalle(arm, SPALLE * k)
    testa(arm, su=5.0 * k, piega=-PIEGA * k)
    _braccia(arm, k, -1.0 * k)
    Z.segui()


M.ANIMAZIONI = {
    'ferma': (1.0, True, pose_ferma),
    'saluta_su': (0.8, False, pose_saluta_su),
    'saluta': (1.0, True, pose_saluta),
    'saluta_giu': (0.8, False, pose_saluta_giu),
}


def anteprime_spot(arm, C, Z, nome, durata, fn, cartella, n=6):
    """Foglio di controllo dello spot: n fotogrammi da davanti e di tre quarti, la camera sul busto."""
    from mathutils import Vector
    from PIL import Image
    bpy = M.bpy
    M.mesh_attive(True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 8
    sc.cycles.use_denoising = True
    W, H = 360, 480
    sc.render.resolution_x, sc.render.resolution_y = W, H
    if sc.world is None:
        sc.world = bpy.data.worlds.new('w')
        sc.world.use_nodes = True
        sc.world.node_tree.nodes['Background'].inputs[1].default_value = 1.0
        sole = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN'))
        sole.data.energy = 3.0
        sole.rotation_euler = (0.8, 0, -0.4)
        sc.collection.objects.link(sole)
        cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.lens = 50
    cam = sc.camera
    fn(arm, C, Z, 0.0)
    centro = M.mondo(arm, arm.pose.bones['collo'].head)
    alto = (M.mondo(arm, arm.pose.bones['testa'].tail) - M.mondo(arm, arm.pose.bones['campana'].head)).length
    dist = alto * 2.6
    righe = []
    for vista, d in (('davanti', Vector((0.0, -1.0, 0.1))), ('tre_quarti', Vector((-0.7, -0.7, 0.15)))):
        pezzi = []
        for i in range(n):
            t = durata * i / (n - 1) if n > 1 else 0.0
            fn(arm, C, Z, t)
            pos = centro + d.normalized() * dist
            cam.location = pos
            cam.rotation_euler = (centro - pos).to_track_quat('-Z', 'Y').to_euler()
            f = os.path.join(cartella, f'_{nome}_{vista}_{i}.png')
            sc.render.filepath = f
            bpy.ops.render.render(write_still=True)
            pezzi.append(Image.open(f).convert('RGB'))
            os.remove(f)
        righe.append(pezzi)
    G = Image.new('RGB', (W * n, H * 2))
    for r, pezzi in enumerate(righe):
        for i, im in enumerate(pezzi):
            G.paste(im, (W * i, H * r))
    G.save(os.path.join(cartella, f'{nome}.jpg'), quality=85)
    M.mesh_attive(False)


M.anteprime = anteprime_spot


if __name__ == '__main__':
    M.main()
