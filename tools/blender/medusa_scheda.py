"""Scheda del modello della medusa (versione da approvare) e primi piani delle mani.

Render Cycles con luce da studio neutra e leggibile: tre luci (chiave, riempimento, controluce) che girano con la
camera, fondo grigio scuro uniforme con l'ombra a terra (piano "shadow catcher"), niente nebbia. Nel giro tutte le
viste hanno la stessa distanza e la stessa altezza di camera. Fogli JPG larghi circa 3000 px con etichette brevi:
  docs/proposte/medusa/scheda/1_giro.jpg       8 viste della statua (posa simbolo, mani giunte sul petto)
  docs/proposte/medusa/scheda/2_dettagli.jpg   viso e occhio, capelli, mani, campana, tentacoli, vinile
  docs/proposte/medusa/scheda/3_malvagia.jpg   posa d'attacco con la fauce aperta e l'occhio venato
  docs/proposte/medusa/scheda/denti_*.jpg      primi piani della fauce aperta (di fronte e di 3/4)
  docs/proposte/medusa/mani/mani_<posa>.jpg    le mani in ogni posa, 4 angolazioni a circa 60 cm
Uso: flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python
     tools/blender/medusa_scheda.py [giro] [dettagli] [malvagia] [denti] [mani] [--prova]
"""
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_pose as POSE  # noqa: E402
import medusa_render_finale as RF  # noqa: E402

PROVA = '--prova' in sys.argv
CAMPIONI = 16 if PROVA else 56
FONDO = (58, 58, 62)                     # grigio scuro uniforme del foglio (sRGB)
OUT_PNG = os.path.join(BUILD, 'render', 'scheda')
OUT_SCHEDA = os.path.join(PROPOSTE, 'scheda')
OUT_MANI = os.path.join(PROPOSTE, 'mani')
for d in (OUT_PNG, OUT_SCHEDA, OUT_MANI):
    os.makedirs(d, exist_ok=True)
CENTRO = Vector((0.0, 0.0, 2.25))         # meta' altezza della statua (4,5 m)


# ---------------------------------------------------------------- scena da studio

def studio(azione='statua', frame=1, venatura=0.0):
    arm = RF.prepara()
    RF.usa_azione(azione, frame)
    mondo((0.018, 0.018, 0.02), 1.0)
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    pav = bpy.context.active_object
    pav.name = 'ombra'
    pav.is_shadow_catcher = True
    imposta_venatura(venatura)
    return arm


def imposta_venatura(v):
    m = bpy.data.materials.get('M_occhio_bulbo')
    if m and 'venatura' in m.node_tree.nodes:
        m.node_tree.nodes['venatura'].outputs[0].default_value = v


def luci(centro, camera_loc, scala, forza=1.0):
    """Tre luci area che seguono la camera: chiave davanti a sinistra in alto, riempimento a destra piu' basso,
    controluce dietro."""
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']:
        bpy.data.objects.remove(o)
    c = Vector(centro)
    f = (c - Vector(camera_loc)).normalized()
    su = Vector((0, 0, 1)) if abs(f.z) < 0.9 else Vector((0, 1, 0))
    r = f.cross(su).normalized()
    u = r.cross(f).normalized()
    d = 2.4 * scala
    P = 70.0 * scala * scala * forza
    luce_area('chiave', c - f * d - r * 0.9 * d + u * 0.8 * d, c, P, (1.0, 0.97, 0.93), 1.2 * scala)
    luce_area('riempimento', c - f * d + r * 1.1 * d + u * 0.15 * d, c, 0.38 * P, (0.9, 0.94, 1.0), 1.4 * scala)
    luce_area('controluce', c + f * 1.1 * d + r * 0.45 * d + u * 0.9 * d, c, 0.9 * P, (1.0, 1.0, 1.0), 1.0 * scala)


def scatto(nome, cam_loc, target, lens, res, scala, campioni=None, forza=1.0):
    """Camera, luci e render su fondo trasparente; poi l'immagine si appoggia sul grigio del foglio."""
    from PIL import Image
    for o in [o for o in bpy.data.objects if o.type == 'CAMERA']:
        bpy.data.objects.remove(o)
    camera(cam_loc, target, lens=lens)
    luci(target, cam_loc, scala, forza)
    imposta_render(samples=campioni or CAMPIONI, res=res, trasparente=True, bounces=8,
                   look='AgX - Medium High Contrast')
    sc = bpy.context.scene
    sc.cycles.glossy_bounces = 4
    sc.cycles.diffuse_bounces = 2
    sc.cycles.transmission_bounces = 8
    sc.cycles.sample_clamp_indirect = 8.0
    png = render(os.path.join(OUT_PNG, nome + '.png'))
    im = Image.open(png).convert('RGBA')
    fondo = Image.new('RGBA', im.size, (*FONDO, 255))
    fondo.alpha_composite(im)
    return fondo.convert('RGB')


def orbita(target, dist, azimut, elev=0.0):
    """Posizione della camera intorno a target: azimut 0 = davanti (la medusa guarda verso -Y), 90 = dal suo
    fianco sinistro (+X)."""
    a, e = math.radians(azimut), math.radians(elev)
    return Vector(target) + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist


# ---------------------------------------------------------------- pose di servizio

def senza_animazioni():
    """Tutte le tracce mute: lo scheletro resta nella posa che gli si da' a mano (a riposo e' la statua)."""
    for i in list(bpy.data.objects) + list(bpy.data.shape_keys):
        ad = i.animation_data
        if ad:
            for tr in ad.nla_tracks:
                tr.mute = True
            ad.action = None
    for k in bpy.data.shape_keys:
        for kb in k.key_blocks[1:]:
            kb.value = 0.0
    POSE.azzera(bpy.data.objects['Medusa_Scheletro'])


def mano_aperta(arm, suf='.L'):
    """Braccio teso di lato all'altezza della spalla, mano aperta con il palmo in giu' (per palmo, dorso, lato)."""
    s = 1.0 if suf == '.L' else -1.0
    POSE.aggiorna()
    sp = arm.pose.bones['braccio' + suf].head
    L = POSE.lunghezza(arm, 'braccio' + suf) + POSE.lunghezza(arm, 'avambraccio' + suf)
    polso = sp + Vector((s * 0.93 * L, -0.05 * L, 0.02 * L))
    POSE.posa_braccio(arm, suf, polso, sp + Vector((s * 0.5 * L, 0.4 * L, -0.2 * L)),
                      Vector((s * 1.0, -0.05, 0.0)), Vector((0.0, 0.0, 1.0)))
    # dita rilassate (la posa di riposo e' quella della statua, con le dita piegate)
    for d in POSE.DITA:
        for f in (1, 2, 3):
            pb = arm.pose.bones[f'{d}_{f}{suf}']
            pb.rotation_mode = 'XYZ'
            g = POSE.POLLICE_STATUA if d == 'pollice' else POSE.DITA_STATUA
            pb.rotation_euler = (math.radians(g), 0, 0)
    POSE.aggiorna()
    return Vector(arm.matrix_world @ arm.pose.bones['mano' + suf].tail)


def centro_mano(arm, suf='.L'):
    pb = arm.pose.bones
    a = arm.matrix_world @ pb['mano' + suf].head
    b = arm.matrix_world @ pb['medio_2' + suf].head
    return (a + b) * 0.5


def assi_mano(arm, suf='.L'):
    M = (arm.matrix_world.to_3x3() @ arm.pose.bones['mano' + suf].matrix.to_3x3())
    return M.col[0].normalized(), M.col[1].normalized(), M.col[2].normalized()


# ---------------------------------------------------------------- misure della scena

def ingombro():
    """Riquadro (min, max) delle mesh visibili nella posa attuale (mondo)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    lo, hi = np.full(3, 1e9), np.full(3, -1e9)
    for o in bpy.data.objects:
        if o.type != 'MESH' or o.hide_render or not o.name.startswith('Medusa'):
            continue
        me = o.evaluated_get(dg).to_mesh()
        co = coords(me)
        M = np.array(o.matrix_world)
        co = co @ M[:3, :3].T + M[:3, 3]
        lo, hi = np.minimum(lo, co.min(0)), np.maximum(hi, co.max(0))
        o.evaluated_get(dg).to_mesh_clear()
    return lo, hi


def testa_centro(arm):
    W = arm.matrix_world
    pb = arm.pose.bones['testa']
    return Vector(W @ (pb.head * 0.45 + pb.tail * 0.55))


def occhio_centro(arm):
    return Vector(arm.matrix_world @ arm.pose.bones['occhio'].head)


def ora(nome):
    return os.path.join(OUT_PNG, nome)


# ---------------------------------------------------------------- 1. giro completo (statua)

VISTE_GIRO = [(0, 'fronte'), (45, '3/4 sinistra'), (90, 'fianco sinistro'), (135, '3/4 dietro sinistra'),
              (180, 'dietro'), (225, '3/4 dietro destra'), (270, 'fianco destro'), (315, '3/4 destra')]


def giro():
    studio('statua', 1)
    lo, hi = ingombro()
    h = hi[2] - lo[2]
    target = Vector((0.0, 0.0, (lo[2] + hi[2]) / 2))
    lens = 85.0
    dist = (h * 1.12 / 2) / math.tan(math.atan(18.0 / lens))     # stessa distanza per tutte le viste
    celle = []
    for az, nome in VISTE_GIRO:
        cam = orbita(target, dist, az, 0.0)                        # camera alla stessa altezza
        im = scatto(f'giro_{az:03d}', cam, target, lens, (800, 1150), 2.6)
        celle.append((im, nome))
    tavola(celle, os.path.join(OUT_SCHEDA, '1_giro.jpg'), colonne=4, titolo='Medusa - giro completo (statua)',
           sottotitolo='posa simbolo: mani giunte sul petto; luce da studio, stessa camera per tutte le viste',
           larghezza=3000, sfondo=FONDO)


# ---------------------------------------------------------------- 2. dettagli

def _vasca():
    RF.vasca_sala()
    acqua = bpy.data.objects.get('acqua')
    if acqua:
        acqua.hide_render = True


def dettagli():
    celle = []
    R = (620, 620)
    # viso e occhio
    arm = studio('statua', 1)
    t = testa_centro(arm)
    celle.append((scatto('det_viso_fronte', orbita(t, 2.0, 0, 3), t, 85, R, 0.8), 'viso di fronte'))
    celle.append((scatto('det_viso_34', orbita(t, 2.0, 38, 6), t, 85, R, 0.8), 'viso di 3/4'))
    e = occhio_centro(arm)
    celle.append((scatto('det_occhio', orbita(e + Vector((0, -0.12, 0)), 0.9, 12, 4), e + Vector((0, -0.12, 0)),
                         85, R, 0.4), 'occhio'))
    # capelli
    celle.append((scatto('det_capelli_dietro', orbita(t, 2.3, 180, 12), t, 85, R, 0.9), 'capelli da dietro'))
    celle.append((scatto('det_capelli_lato', orbita(t, 2.3, 95, 8), t, 85, R, 0.9), 'capelli di lato'))
    # mani aperte
    arm = studio('statua', 1)
    senza_animazioni()
    mano_aperta(arm)
    c = centro_mano(arm)
    x, y, z = assi_mano(arm)
    for nome, d in (('palmo', -z), ('dorso', z + y * 0.15), ('lato', -x * 0.9 - z * 0.2)):
        celle.append((scatto('det_mano_' + nome, c + Vector(d).normalized() * 0.68, c, 50, R, 0.4),
                      'mano: ' + nome))
    # mano che si aggrappa (posa affacciata, sul bordo della vasca)
    arm = studio('affacciata', 1)
    _vasca()
    c = centro_mano(arm)
    cam = c + Vector((0.62, -0.62, 0.3)).normalized() * 0.72
    celle.append((scatto('det_mano_presa', cam, c + Vector((0, -0.05, -0.04)), 50, R, 0.45),
                  'mano che si aggrappa'))
    # campana
    arm = studio('statua', 1)
    lo, hi = ingombro()
    cb = Vector((0.0, 0.0, 2.2))
    celle.append((scatto('det_campana_lato', orbita(cb, 3.6, 70, 4), cb, 85, R, 1.4), 'campana di lato'))
    celle.append((scatto('det_campana_alto', orbita(cb, 3.6, 20, 52), cb, 85, R, 1.4), 'campana dall\'alto'))
    cr = Vector((0.0, -0.75, 1.8))
    celle.append((scatto('det_campana_bordo', orbita(cr, 1.5, 15, -18), cr, 85, R, 0.7, forza=0.55),
                  'bordo luminoso'))
    # tentacoli
    ct = Vector((0.55, -0.85, 0.35))
    celle.append((scatto('det_tentacolo', orbita(ct, 1.4, 25, 18), ct, 85, R, 0.6), 'tentacolo grosso'))
    cs = Vector((0.0, -0.25, 1.35))
    celle.append((scatto('det_sottili', orbita(cs, 1.8, 10, 5), cs, 85, R, 0.8), 'tentacoli sottili'))
    # vinile: spalla e braccio (la giuntura da bambola)
    pb = arm.pose.bones['braccio.L']
    cv = Vector(arm.matrix_world @ (pb.head * 0.75 + pb.tail * 0.25))
    celle.append((scatto('det_vinile', orbita(cv, 0.75, 55, 15), cv, 85, R, 0.35), 'superficie in vinile'))
    tavola(celle, os.path.join(OUT_SCHEDA, '2_dettagli.jpg'), colonne=5, titolo='Medusa - dettagli',
           larghezza=3000, sfondo=FONDO)


# ---------------------------------------------------------------- 3. versione malvagia

def malvagia():
    celle = []
    arm = studio('fauce_apre', 24, venatura=1.0)
    lo, hi = ingombro()
    h = hi[2] - lo[2]
    target = Vector((0.0, -0.3, (lo[2] + hi[2]) / 2))
    lens = 85.0
    dist = (h * 1.12 / 2) / math.tan(math.atan(18.0 / lens))
    for az, nome in ((0, 'attacco di fronte'), (35, 'attacco di 3/4'), (90, 'attacco di fianco')):
        celle.append((scatto(f'malvagia_{az:03d}', orbita(target, dist, az, 0.0), target, lens, (800, 1150), 2.8),
                      nome))
    t = testa_centro(arm)
    celle.append((scatto('malvagia_fauce', orbita(t + Vector((0, -0.2, -0.15)), 1.9, 18, -4),
                         t + Vector((0, -0.2, -0.15)), 85, (800, 1150), 0.8), 'fauce aperta'))
    e = occhio_centro(arm)
    celle.append((scatto('malvagia_occhio', orbita(e + Vector((0, -0.12, 0)), 1.5, 8, 3),
                         e + Vector((0, -0.12, 0)), 85, (800, 1150), 0.5), 'occhio venato'))
    tavola(celle, os.path.join(OUT_SCHEDA, '3_malvagia.jpg'), colonne=5, titolo='Medusa - versione malvagia',
           sottotitolo='posa d\'attacco, fauce aperta, occhio venato (parametro venatura = 1)',
           larghezza=3000, sfondo=FONDO)


# ---------------------------------------------------------------- 3b. denti (fauce aperta da vicino)

def centro_oggetto(nome):
    """Centro del riquadro della mesh deformata (posa e shape key attuali), nel mondo."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    o = bpy.data.objects[nome]
    me = o.evaluated_get(dg).to_mesh()
    co = coords(me)
    M = np.array(o.matrix_world)
    co = co @ M[:3, :3].T + M[:3, 3]
    o.evaluated_get(dg).to_mesh_clear()
    return Vector(((co.min(0) + co.max(0)) / 2).tolist()), co.max(0) - co.min(0)


def denti():
    """Fauce aperta del tutto da vicino, di fronte e di 3/4: le due arcate di denti che si incastrano."""
    studio('fauce_apre', 24, venatura=1.0)
    c, dim = centro_oggetto('Medusa_Denti')
    res = (1200, 900) if not PROVA else (600, 450)
    for nome, az, el in (('fronte', 0, 2), ('34', 35, 4)):
        im = scatto(f'denti_{nome}', orbita(c, 1.45, az, el), c, 85, res, 0.6)
        p = os.path.join(OUT_SCHEDA if not PROVA else OUT_PNG, f'denti_{nome}.jpg')
        im.save(p, quality=92)
        log('immagine', os.path.relpath(p, REPO))


# ---------------------------------------------------------------- 4. mani in ogni posa

POSE_MANI = [('statua', 1, 'statua'), ('insegue', 13, 'insegue'), ('fluttua', 1, 'fluttua'),
             ('fauce_apre', 24, 'attacco'), ('affacciata', 1, 'affacciata')]


def mani():
    tutte = []
    for azione, frame, nome in POSE_MANI:
        arm = studio(azione, frame)
        if azione == 'affacciata':
            _vasca()
        c = centro_mano(arm)
        x, y, z = assi_mano(arm)
        viste = (('dorso', z * 1.0 + y * 0.2), ('palmo', -z * 1.0 + y * 0.2), ('lato', -x + z * 0.25),
                 ('3/4', z * 0.6 - x * 0.55 - y * 0.35))
        if azione == 'affacciata':
            viste = (('davanti', Vector((0.0, -1.0, 0.25))), ('lato', Vector((1.0, -0.15, 0.2))),
                     ('dall\'alto', Vector((0.15, -0.35, 1.0))), ('3/4', Vector((0.7, -0.7, 0.35))))
        celle = []
        for nv, d in viste:
            cam = c + Vector(d).normalized() * 0.6
            celle.append((scatto(f'mani_{nome}_{nv.replace("/", "")}', cam, c, 50, (640, 640), 0.4,
                                 campioni=40 if not PROVA else 12), f'{nome}: {nv}'))
        tavola(celle, os.path.join(OUT_MANI, f'mani_{nome}.jpg'), colonne=4, larghezza=2560, sfondo=FONDO)
        tutte.extend(celle)
    tavola(tutte, os.path.join(OUT_MANI, 'mani_tutte_le_pose.jpg'), colonne=4,
           titolo='Mani nuove in ogni posa (a circa 60 cm)', larghezza=2400, sfondo=FONDO)


# ---------------------------------------------------------------- prova veloce delle mani

def prova_mani():
    from PIL import Image
    celle = []
    arm = studio('statua', 1)
    senza_animazioni()
    mano_aperta(arm)
    c = centro_mano(arm)
    x, y, z = assi_mano(arm)
    for nome, d in (('palmo', -z), ('dorso', z), ('lato', -x), ('tre_quarti', (z * 0.6 - x * 0.6 + y * -0.3))):
        cam = c + Vector(d).normalized() * 0.62
        celle.append((scatto('prova_mano_' + nome, cam, c, 50, (420, 420), 0.35, campioni=16), nome))
    arm = studio('statua', 1)
    c = centro_mano(arm)
    for nome, az in (('statua davanti', 20), ('statua lato', 95)):
        celle.append((scatto('prova_statua_' + nome.split()[1], orbita(c, 0.75, az, 10), c, 50, (420, 420), 0.4,
                             campioni=16), nome))
    tavola(celle, os.path.join(BUILD, 'render', 'scheda', 'prova_mani.jpg'), colonne=3)


if __name__ == '__main__':
    argv = [a for a in sys.argv[1:] if not a.startswith('--')]
    if 'prova_mani' in argv:
        prova_mani()
    for nome, f in (('giro', giro), ('dettagli', dettagli), ('malvagia', malvagia), ('denti', denti), ('mani', mani)):
        if nome in argv:
            t0 = time.time()
            f()
            log(f'{nome}: {time.time() - t0:.0f} s')
