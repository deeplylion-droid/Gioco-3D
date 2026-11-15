"""Le azioni della build 0.5.0 «la storia» per il bambino col cubo (bambini_animazioni.py --vivo --storia).

Non si lancia da solo: lo esegue bambini_animazioni.py dopo le altre azioni, con le sue funzioni e variabili.

  disegna      (ciclo di 6 s) in ginocchio, seduto sui talloni, curvo sul foglio: la mano destra disegna con la matita
               (la punta sempre sul foglio, tratti avanti e indietro con due pause in cui la alza di un centimetro), la
               sinistra tiene fermo il foglio, la testa china sul disegno
  alza_testa   (1 s, una volta) dalla posa di disegna: il busto si raddrizza un po' e la testa si alza a guardare
               davanti a sé (nel gioco lo sguardo va poi verso il giocatore); le mani restano sul foglio, la matita si
               stacca
  si_alza      (0,6 s, una volta) dalla fine di alza_testa alla posa di fermo_vivo (il suo fotogramma 0, quello da cui
               parte "parte"): i piedi vengono sotto il corpo e si tira su
  porge        (1,2 s, una volta) da fermo_vivo: alza le due braccia e tiene un foglio A4 davanti al petto, con le due
               mani ai lati della metà alta del foglio
  porge_tiene  (ciclo di 4 s) lo tiene lì: respiro, un piccolo tremare delle braccia

  guarda_su    (ciclo di 6 s) in piedi davanti al vetro del cilindro giallo agli acquari (il disegno è a 2,45-3,35 m:
               scelta A del coordinatore), la testa in su verso il disegno, il pastello in mano a mezz'aria come chi ha
               appena finito e guarda il lavoro

Il pastello ('pastello', quello di ambienti-1, --pastello) è attaccato all'osso RightHand: nel gioco si vede solo in disegna e
alza_testa. L'osso 'foglio' (figlio di Spine, senza pesi) è dove sta il centro del foglio che porge: in porge e
porge_tiene è fra le mani; nelle altre azioni resta davanti al petto.

Il foglio su cui disegna sta a --foglio-altezza da terra, al centro FOGLIO_AVANTI davanti al nodo (le misure, rispetto
all'origine del bambino, sono scritte nel .json accanto al GLB).
"""
import json

# ---------------------------------------------------------------- misure (mondo di Blender: X di lato, -Y avanti, Z su)
MW = arm.matrix_world
MWI = MW.inverted()
SU_A = (MWI.to_3x3() @ Vector((0, 0, 1))).normalized()       # il su del mondo nello spazio dell'armatura
AV_W = Vector((0, -1, 0))                                     # avanti nel mondo
CX = 0.035                                                    # il centro del corpo (fra le anche) di lato
CY = 0.042                                                    # e in profondità
H_FOGLIO = A.foglio_altezza
FOGLIO_AVANTI = 0.31                                          # dal centro del corpo al centro del foglio (m)
A4 = (0.21, 0.297)


def aw(v):
    """Punto del mondo -> spazio dell'armatura."""
    return MWI @ Vector(v)


def wa(v):
    return MW @ v


def pb_(n):
    return arm.pose.bones[n]


def lung(a, b):
    return (wa(pb_(b).head) - wa(pb_(a).head)).length


L_COSCIA = {l: lung(f'{l}UpLeg', f'{l}Leg') for l in ('Left', 'Right')}
L_STINCO = {l: lung(f'{l}Leg', f'{l}Foot') for l in ('Left', 'Right')}
# la direzione della mano a riposo (dal polso verso le dita: come l'avambraccio), nello spazio dell'armatura
D_MANO = {l: (arm.data.bones[f'{l}Hand'].head_local - arm.data.bones[f'{l}ForeArm'].head_local).normalized()
          for l in ('Left', 'Right')}
MATITA = (0.05, 0.135)     # il pastello lungo la mano: dal polso, dove comincia e dove ha la punta (m)


def dir_mano(lato):
    """Dove va la mano adesso (dal polso verso le dita), nel mondo."""
    b = arm.data.bones[f'{lato}Hand']
    r = pb_(f'{lato}Hand').matrix.to_3x3() @ b.matrix_local.to_3x3().inverted()
    return (MW.to_3x3() @ (r @ D_MANO[lato])).normalized()


def punta_matita():
    w = wa(pb_('RightHand').head)
    return w + dir_mano('Right') * MATITA[1]


def ruota_mondo(pb, q_w, perno_w):
    """_ruota con la rotazione e il perno nel mondo."""
    m3 = MWI.to_3x3() @ q_w.to_matrix() @ MW.to_3x3()
    _ruota(pb, m3.to_quaternion(), MWI @ perno_w)


def due_ossa(sup, inf, fine, T_w, polo_w, giri=3):
    """IK a due ossa nel mondo: sup e inf girano perché la testa di fine arrivi in T_w, col gomito (o ginocchio) verso
    polo_w."""
    for _ in range(giri):
        S, E, W = wa(pb_(sup).head), wa(pb_(inf).head), wa(pb_(fine).head)
        a, b = (E - S).length, (W - E).length
        d = (T_w - S).length
        d = max(abs(a - b) + 1e-4, min(d, a + b - 1e-4))
        u = (T_w - S).normalized()
        x = (a * a - b * b + d * d) / (2 * d)
        h = math.sqrt(max(a * a - x * x, 0.0))
        pv = polo_w - S
        pv = (pv - u * pv.dot(u))
        pv = pv.normalized() if pv.length > 1e-6 else Vector((0, 0, 1))
        E_voluto = S + u * x + pv * h
        ruota_mondo(pb_(sup), (E - S).rotation_difference(E_voluto - S), S)
        E2, W2 = wa(pb_(inf).head), wa(pb_(fine).head)
        ruota_mondo(pb_(inf), (W2 - E2).rotation_difference(T_w - E2), E2)


def punta(osso, figlio, verso_w):
    """Gira l'osso intorno alla sua testa perché il figlio vada nella direzione verso_w."""
    H, C = wa(pb_(osso).head), wa(pb_(figlio).head)
    ruota_mondo(pb_(osso), (C - H).rotation_difference(verso_w), H)


def mano_verso(lato, verso_w, torci=0.0):
    """Gira la mano intorno al polso perché vada nella direzione verso_w (e poi la torce intorno a sé)."""
    W = wa(pb_(f'{lato}Hand').head)
    ruota_mondo(pb_(f'{lato}Hand'), dir_mano(lato).rotation_difference(verso_w.normalized()), W)
    if torci:
        ruota_mondo(pb_(f'{lato}Hand'), Quaternion(verso_w.normalized(), math.radians(torci)), W)


# ---------------------------------------------------------------- in ginocchio
LATI = {'Left': 1.0, 'Right': -1.0}                           # (il sinistro sta a +X)
X_GAMBA = {l: wa(arm.data.bones[f'{l}UpLeg'].head_local).x for l in LATI}
Z_ANCA_RIPOSO = wa(arm.data.bones['LeftUpLeg'].head_local).z
GIN = {'anca': 0.205, 'ginocchio': 0.050, 'caviglia': 0.058, 'punta': 0.030, 'apri': 0.035}
DEBUG = False
_alza = [0.0]
CURVA = [50.0]     # quanto è curvo sul foglio (gradi): lo sceglie calibra(), perché la mano ci arrivi          # di quanto alzare tutto perché la pelle non vada sotto il pavimento (si misura una volta)


def gambe_in_ginocchio(k=1.0, anca_y=0.0):
    """Le gambe piegate, ginocchia a terra e stinchi distesi dietro, i piedi col collo a terra (k: quanto, per il
    passaggio)."""
    for lato, s in LATI.items():
        H = wa(pb_(f'{lato}UpLeg').head)
        x = H.x + s * GIN['apri']
        zk = GIN['ginocchio'] + _alza[0]
        dz = H.z - zk
        av = math.sqrt(max(L_COSCIA[lato] ** 2 - dz * dz, 1e-6))
        K = Vector((x, H.y - av, zk))
        za = GIN['caviglia'] + _alza[0]
        A_ = Vector((x + s * 0.01, K.y + math.sqrt(max(L_STINCO[lato] ** 2 - (zk - za) ** 2, 1e-6)), za))
        polo = K + Vector((0, -0.3, 0.05))
        due_ossa(f'{lato}UpLeg', f'{lato}Leg', f'{lato}Foot', A_, polo)
        # il piede disteso dietro, la punta giù
        punta(f'{lato}Foot', f'{lato}ToeBase', Vector((s * 0.1, 1.0, -0.45)).normalized())


def anche_giu(z_anca, avanti=0.0):
    """Abbassa le anche perché le teste delle cosce stiano a z_anca (m), e le sposta in avanti."""
    spost = Vector((0.0, -avanti, z_anca - Z_ANCA_RIPOSO))
    metti_anche(spost)
    bpy.context.view_layer.update()


def schiena(curva, lato=0.0):
    """Le rotazioni nel mondo del busto curvo in avanti di curva gradi (in tutto), sopra posa_curva."""
    return {
        'Hips': [(X, 0.18 * curva)],
        'Spine02': [(X, 0.26 * curva), (Y, 0.3 * lato)], 'Spine01': [(X, 0.30 * curva), (Y, 0.3 * lato)],
        'Spine': [(X, 0.26 * curva), (Y, 0.4 * lato)],
    }


def foglio_centro():
    return Vector((CX, CY - FOGLIO_AVANTI, H_FOGLIO))


def tratto(t):
    """La punta della matita sul foglio nel ciclo di 6 s (spostamento dal punto di partenza, m, e quanto è staccata)."""
    # due serie di tratti (0-2,4 s e 3-5,4 s) con due pause; tutto torna uguale a 6 s
    e = liscio(t, 0.1, 0.4) * (1 - liscio(t, 2.2, 2.5)) + liscio(t, 3.0, 3.3) * (1 - liscio(t, 5.2, 5.5))
    x = 0.030 * math.sin(2 * math.pi * t / 0.5) * e + 0.012 * math.sin(2 * math.pi * t / 3.0)
    y = 0.012 * math.sin(2 * math.pi * t / 1.5 + 0.7) * e + 0.010 * math.sin(2 * math.pi * t / 6.0)
    su = 0.010 * (1 - e)
    return Vector((x, y, su)), e


def posa_disegna(t, alza=0.0, stacca=0.0):
    """La posa di disegna al tempo t; alza (0-1) la fa raddrizzare e alzare la testa (alza_testa), stacca (0-1) stacca la
    matita dal foglio."""
    p = posa_curva(t, respiro=3.0, ondeggio=6.0, curva=0.6)
    curva = CURVA[0] - (CURVA[0] - 26.0) * alza
    giu = 1.0 - alza
    testa = {'neck': [(X, 12.0 * giu - 14.0 * alza)], 'Head': [(X, 16.0 * giu - 10.0 * alza), (Z, -6.0 * giu)]}
    applica(unisci(p, schiena(curva, lato=-4.0), testa))
    anche_giu(GIN['anca'] + _alza[0], avanti=0.0)
    gambe_in_ginocchio()
    bpy.context.view_layer.update()
    c = foglio_centro()
    d, e = tratto(t)
    d = d * (1 - alza)
    # la mano destra: la matita sul foglio, un po' a destra del centro
    tip = c + Vector((-0.035, 0.03, 0.0)) + Vector((d.x, d.y, 0.0)) + Vector((0, 0, d.z + 0.03 * stacca))
    verso = Vector((0.15, -0.55, -0.82)).normalized()
    for _ in range(3):
        W = tip - verso * MATITA[1]
        due_ossa('RightArm', 'RightForeArm', 'RightHand', W, W + Vector((-0.25, 0.15, 0.1)))
        mano_verso('Right', verso, torci=-30)
    if DEBUG:
        S_ = wa(pb_('RightArm').head)
        log(f'debug t={t:.2f}: punta {(punta_matita() - tip).length:.3f} spalla-polso {(S_ - (tip - verso * MATITA[1])).length:.3f} '
            f'braccio {lung("RightArm", "RightForeArm") + lung("RightForeArm", "RightHand"):.3f} spalla {S_}')
    # la mano sinistra aperta sul foglio, a sinistra, che lo tiene fermo
    WL = c + Vector((0.075, 0.075, 0.032))
    due_ossa('LeftArm', 'LeftForeArm', 'LeftHand', WL, WL + Vector((0.3, 0.15, 0.1)))
    mano_verso('Left', Vector((-0.25, -1.0, -0.35)), torci=0)
    return tip, e


def misura_pelle():
    """La pelle vera adesso: punto più basso, e i punti della testa a cubo."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = corpo.evaluated_get(dg)
    me = ev.to_mesh()
    vs = [ev.matrix_world @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    return vs


def chiavi(f):
    chiave(f, con_posizione=('Hips', 'foglio'))


def disegna():
    nuova_azione('disegna')
    n = 6 * FPS
    for f in range(n + 1):
        posa_disegna(f / FPS)
        chiavi(f)


def alza_testa():
    nuova_azione('alza_testa')
    n = FPS
    for f in range(n + 1):
        u = liscio(f / n, 0.0, 1.0)
        posa_disegna(0.0, alza=u, stacca=liscio(f / n, 0.0, 0.4))
        chiavi(f)


def posa_salvata():
    bpy.context.view_layer.update()
    return ({pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}, pb_('Hips').location.copy())


def si_alza():
    posa_disegna(0.0, alza=1.0, stacca=1.0)
    a_rot, a_loc = posa_salvata()
    caviglie_a = {l: wa(pb_(f'{l}Foot').head) for l in LATI}
    b_rot, b_loc = posa_di('fermo_vivo', 0)
    bpy.context.view_layer.update()
    caviglie_b = {l: wa(pb_(f'{l}Foot').head) for l in LATI}
    punte_b = {l: wa(pb_(f'{l}ToeBase').head) for l in LATI}
    nuova_azione('si_alza')
    n = int(round(0.6 * FPS))
    for f in range(n + 1):
        u = f / n
        k = liscio(u, 0.0, 1.0)
        for pb in arm.pose.bones:
            pb.rotation_quaternion = a_rot[pb.name].slerp(b_rot[pb.name], k)
        # le anche salgono dopo che i piedi sono venuti sotto
        pb_('Hips').location = a_loc.lerp(b_loc, liscio(u, 0.2, 1.0))
        # (a metà si tira su un po' di più: le ginocchia e i tentacoli del cubo aperto non toccano il pavimento)
        metti_anche(M_HIPS.inverted() @ pb_('Hips').location + Vector((0, 0, 0.06 * math.sin(math.pi * u))))
        bpy.context.view_layer.update()
        for lato, s in LATI.items():
            # (prima il destro, poi il sinistro: i piedi vengono avanti sotto il corpo, sollevati di poco)
            kk = liscio(u, 0.0, 0.6) if lato == 'Right' else liscio(u, 0.15, 0.8)
            T = caviglie_a[lato].lerp(caviglie_b[lato], kk) + Vector((0, 0, 0.08 * math.sin(math.pi * kk)))
            K = wa(pb_(f'{lato}Leg').head)
            due_ossa(f'{lato}UpLeg', f'{lato}Leg', f'{lato}Foot', T, K + Vector((0, -0.3, 0.1)))
            # (anche col piede ancora fermo: il piede resta disteso dietro, la punta non scende sotto il pavimento)
            if True:
                A_ = wa(pb_(f'{lato}Foot').head)
                P0 = A_ + Vector((s * 0.1, 1.0, -0.45)).normalized() * 0.07
                P1 = punte_b[lato] - caviglie_b[lato] + A_
                v = (P0 - A_).lerp(P1 - A_, kk)
                punta(f'{lato}Foot', f'{lato}ToeBase', v)
        chiavi(f)


# ---------------------------------------------------------------- porge
PORGE = {'altezza': 0.62, 'avanti': 0.27, 'mani': A4[0] / 2 - 0.012}


def posa_porge(t, k=1.0, trema=1.0):
    """Le braccia avanti che tengono il foglio davanti al petto (k: quanto, da fermo_vivo)."""
    rot, spost = posa_viva(t, 4.0, 4.0)
    p = posa_curva(t, respiro=3.0, ondeggio=8.0)
    testa = {'neck': [(X, 4.0 * k)], 'Head': [(X, 6.0 * k), (Y, 4.0 * k)]}
    applica(unisci(p, {kk: v for kk, v in rot.items() if not kk.endswith(('Arm',))}, testa))
    metti_anche(spost * 0.4)
    piedi_a_terra()
    if k <= 0.0:
        return None
    centro = Vector((CX, CY - PORGE['avanti'], PORGE['altezza']))
    tr = Vector((0.0015 * math.sin(2 * math.pi * t / 0.4), 0, 0.002 * math.sin(2 * math.pi * t / 0.5 + 1.0))) * trema
    resp = Vector((0, 0, 0.004 * onda(t, 4.0)))
    for lato, s in LATI.items():
        riposo = wa(pb_(f'{lato}Hand').head)
        W = centro + Vector((s * PORGE['mani'], 0.02, -0.02)) + tr + resp
        W = riposo.lerp(W, k)
        due_ossa(f'{lato}Arm', f'{lato}ForeArm', f'{lato}Hand', W, W + Vector((s * 0.25, 0.25, -0.25)))
        # le mani verso l'alto e un po' in avanti, il palmo verso il foglio
        mano_verso(lato, dir_mano(lato).lerp(Vector((-s * 0.25, -0.35, 1.0)).normalized(), k), torci=0)
    # il centro del foglio: fra le mani, la parte alta del foglio in mano
    ML, MR = wa(pb_('LeftHand').head), wa(pb_('RightHand').head)
    mezzo = (ML + MR) / 2 + (dir_mano('Left') + dir_mano('Right')) / 2 * 0.045
    return mezzo + Vector((0, -0.012, -0.065))


def metti_foglio(dove_w):
    """L'osso 'foglio' con la testa in dove_w, orientato come a riposo."""
    b = arm.data.bones['foglio']
    m = Matrix.Translation(MWI @ dove_w) @ b.matrix_local.to_3x3().to_4x4()
    pb_('foglio').matrix = m
    bpy.context.view_layer.update()


def porge():
    nuova_azione('porge')
    n = int(round(1.2 * FPS))
    for f in range(n + 1):
        u = f / n
        k = liscio(u, 0.0, 1.0)
        dove = posa_porge(f / FPS, k=k, trema=k)
        if dove is not None:
            metti_foglio(dove)
        chiavi(f)
    nuova_azione('porge_tiene')
    n = 4 * FPS
    for f in range(n + 1):
        t = f / FPS + 1.2          # (prosegue da dove finisce porge: il respiro e il tremare continuano)
        dove = posa_porge(t, k=1.0)
        metti_foglio(dove)
        chiavi(f)


# ---------------------------------------------------------------- la matita
def fai_pastello():
    """Il pastello a cera di ambienti-1 (godot/assets/storia_disegni/pastello.glb, --pastello: prisma a otto facce di 1,1 cm,
    lungo 8,5 cm, la punta verso +X), attaccato all'osso RightHand (a riposo, lungo la mano, la punta verso le dita a
    [MATITA][1] dal polso). L'oggetto si chiama 'pastello' anche nel GLB del bambino."""
    prima = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=A.pastello)
    nuovi = [o for o in bpy.context.scene.objects if o not in prima and o.type == 'MESH']
    m = nuovi[0]
    for o in nuovi[1:]:
        bpy.data.objects.remove(o, do_unlink=True)
    m.parent = None
    m.name = 'pastello'
    # nel sistema del pastello (Blender, Z su): l'asse lungo è X; la punta è a x massima; l'asse passa a mezzo spessore
    bpy.context.view_layer.update()
    vs = [m.matrix_world @ v.co for v in m.data.vertices]
    xmax = max(v.x for v in vs)
    cz = (min(v.z for v in vs) + max(v.z for v in vs)) / 2
    cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
    m.data.transform(m.matrix_world)
    m.data.transform(Matrix.Translation(Vector((-xmax, -cy, -cz))))   # la punta nell'origine, l'asse su X
    m.matrix_world = Matrix.Identity(4)
    arm.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    b = arm.data.bones['RightHand']
    W = MW @ b.head_local
    d = (MW.to_3x3() @ D_MANO['Right']).normalized()
    rot = Vector((1, 0, 0)).rotation_difference(d)        # la punta (+X) verso le dita
    m.matrix_world = Matrix.Translation(W + d * MATITA[1]) @ rot.to_matrix().to_4x4()
    mw = m.matrix_world.copy()
    m.parent = arm
    m.parent_type = 'BONE'
    m.parent_bone = 'RightHand'
    m.matrix_world = mw
    arm.data.pose_position = 'POSE'
    bpy.context.view_layer.update()
    log('pastello attaccato alla mano destra')
    return m


# ---------------------------------------------------------------- calibrazione, azioni, controlli
def manca_alla_mano():
    """Di quanto la spalla destra è più lontana dal polso voluto della lunghezza del braccio (m, col 4% di margine)."""
    tip, _ = posa_disegna(0.0)
    verso = Vector((0.15, -0.55, -0.82)).normalized()
    S_ = wa(pb_('RightArm').head)
    br = lung('RightArm', 'RightForeArm') + lung('RightForeArm', 'RightHand')
    # (col braccio piegato bene: il 90% della lunghezza, non teso)
    return (S_ - (tip - verso * MATITA[1])).length - 0.90 * br


def calibra():
    """Quanto curvo, perché la mano arrivi sul foglio senza tendere del tutto il braccio; poi quanto alzare la posa in ginocchio perché il punto più basso della pelle stia a 3 mm dal pavimento."""
    nuova_azione('_prova')
    lo, hi = 30.0, 80.0     # (almeno un po' chino sul foglio)
    for _ in range(14):
        CURVA[0] = (lo + hi) / 2
        if manca_alla_mano() > 0.0:
            lo = CURVA[0]
        else:
            hi = CURVA[0]
    CURVA[0] = hi
    log(f'in ginocchio: curvo di {CURVA[0]:.1f} gradi (manca {manca_alla_mano():+.3f} m alla mano)')
    posa_disegna(0.0)
    zmin = min(v.z for v in misura_pelle())
    _alza[0] = 0.003 - zmin
    bpy.data.actions.remove(bpy.data.actions['_prova'])
    log(f'in ginocchio: pelle più bassa a {zmin:+.3f} m, alzo tutto di {_alza[0]:+.3f}')


# ---------------------------------------------------------------- guarda il disegno (agli acquari, scelta A del coordinatore)
GUARDA = {'testa_su': 34.0, 'polso': (-0.10, -0.12, 0.50)}


def posa_guarda_su(t, k=1.0):
    """In piedi davanti al vetro, la testa in su verso il disegno (k: quanto, da fermo_vivo); il pastello in mano a
    mezz'aria, come chi ha appena finito e guarda il lavoro; piccolo respiro e ondeggiare."""
    rot, spost = posa_viva(t, 6.0, 4.0)
    p = posa_curva(t, respiro=4.0, ondeggio=6.0)
    su = GUARDA['testa_su'] * k
    testa = {'neck': [(X, -0.45 * su)], 'Head': [(X, -0.55 * su + 1.5 * onda(t, 3.0, 0.2)), (Z, 3.0 * onda(t, 6.0, 0.4))],
             # (guardando in su il busto si raddrizza un po')
             'Spine': [(X, -3.0 * k)], 'Spine01': [(X, -2.0 * k)]}
    applica(unisci(p, {kk: v for kk, v in rot.items() if kk not in ('RightArm',)}, testa))
    metti_anche(spost)
    piedi_a_terra()
    if k > 0.0:
        riposo = wa(pb_('RightHand').head)
        W = Vector((CX, CY, 0.0)) + Vector(GUARDA['polso']) + Vector((0.004 * onda(t, 6.0), 0.0, 0.006 * onda(t, 4.0)))
        W = riposo.lerp(W, k)
        due_ossa('RightArm', 'RightForeArm', 'RightHand', W, W + Vector((-0.3, 0.2, -0.2)))
        mano_verso('Right', dir_mano('Right').lerp(Vector((0.35, -0.6, 0.25)).normalized(), k), torci=0)


def guarda_su():
    """Il passaggio da fermo_vivo (1 s), poi il ciclo (6 s, finisce come comincia)."""
    nuova_azione('guarda_su')
    n = 6 * FPS
    for f in range(n + 1):
        posa_guarda_su(f / FPS)
        chiavi(f)


calibra()
DEBUG = False
disegna()
alza_testa()
si_alza()
porge()
guarda_su()
matita = fai_pastello()


def controlla():
    """Sulla pelle vera, fotogramma per fotogramma: niente sotto il pavimento, la punta della matita sul foglio in
    disegna, la testa a cubo lontana dalle mani e dal foglio, le mani ai lati del foglio in porge."""
    ko = 0
    z_testa = (MW @ arm.data.bones['Head'].head_local).z
    gi = {g.index: g.name for g in corpo.vertex_groups}
    testa_idx = [v.index for v in corpo.data.vertices
                 if any(gi[g.group] == 'Head' and g.weight > 0.99 for g in v.groups)
                 and (corpo.matrix_world @ v.co).z > z_testa + 0.05]
    mani_idx = [v.index for v in corpo.data.vertices
                if any(gi[g.group] in ('LeftHand', 'RightHand') and g.weight > 0.5 for g in v.groups)]
    # (fermo_vivo per confronto: il punto più basso della pelle da fermo, quello di sempre)
    arm.animation_data.action = bpy.data.actions['fermo_vivo']
    sc.frame_set(0)
    z_fermo = min(v.z for v in misura_pelle())
    log(f'fermo_vivo (per confronto): pelle più bassa {z_fermo:+.3f} m')
    for nome in ('disegna', 'alza_testa', 'si_alza', 'porge', 'porge_tiene', 'guarda_su'):
        act = bpy.data.actions[nome]
        arm.animation_data.action = act
        f0, f1 = act.frame_range
        peggio = {'sotto': 9.0, 'punta': 0.0, 'testa_mani': 9.0, 'testa_foglio': 9.0}
        for f in range(int(f0), int(f1) + 1):
            sc.frame_set(f)
            vs = misura_pelle()
            zmin = min(v.z for v in vs)
            peggio['sotto'] = min(peggio['sotto'], zmin)
            if nome == 'si_alza' and os.environ.get('DEBUG_STORIA'):
                iv = min(range(len(vs)), key=lambda k: vs[k].z)
                ossa_v = sorted(((gi[g.group], g.weight) for g in corpo.data.vertices[iv].groups), key=lambda x: -x[1])[:2]
                log(f'  si_alza f{f}: {zmin:+.3f} {vs[iv]} {ossa_v}')
            if nome in ('disegna', 'alza_testa'):
                tp = punta_matita()
                if nome == 'disegna':
                    _, e = tratto(f / FPS)
                    attesa = H_FOGLIO + 0.010 * (1 - e)
                    peggio['punta'] = max(peggio['punta'], abs(tp.z - attesa))
                cubo = [vs[i] for i in testa_idx]
                mani = [vs[i] for i in mani_idx]
                dm = min((a - b).length for a in cubo[::7] for b in mani[::5])
                peggio['testa_mani'] = min(peggio['testa_mani'], dm)
                peggio['testa_foglio'] = min(peggio['testa_foglio'], min(v.z for v in cubo) - H_FOGLIO)
        log(f'{nome}: pelle più bassa {peggio["sotto"]:+.3f} m; punta della matita fuori dal foglio al più '
            f'{peggio["punta"] * 1000:.1f} mm; cubo-mani {peggio["testa_mani"]:.3f} m, cubo-foglio {peggio["testa_foglio"]:.3f} m')
        if peggio['sotto'] < min(-0.01, z_fermo - 0.005):
            log(f'KO {nome}: la pelle va sotto il pavimento'); ko += 1
        if peggio['punta'] > 0.004:
            log(f'KO {nome}: la matita si stacca dal foglio'); ko += 1
        if nome in ('disegna', 'alza_testa') and (peggio['testa_mani'] < 0.02 or peggio['testa_foglio'] < 0.05):
            log(f'KO {nome}: il cubo tocca le mani o il foglio'); ko += 1
    log('CONTROLLO STORIA:', 'ok' if ko == 0 else f'{ko} KO')
    return ko


def misure():
    """Dove stanno il foglio e la matita rispetto all'origine del bambino (nel sistema di Godot: X a sinistra del
    bambino, Y su, Z avanti) e quanto dura ogni azione."""
    def godot(v):
        return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]
    return {
        'foglio_disegna': {'centro': godot(foglio_centro()),
                           'altezza': H_FOGLIO, 'note': "il centro del foglio su cui disegna (A4 per terra, lato corto verso di lui)"},
        'alza_tutto': round(_alza[0], 4),
        'durate': {n: round((bpy.data.actions[n].frame_range[1] - bpy.data.actions[n].frame_range[0]) / FPS, 3)
                   for n in ('disegna', 'alza_testa', 'si_alza', 'porge', 'porge_tiene', 'guarda_su')},
    }


def stampa_porge():
    arm.animation_data.action = bpy.data.actions['porge_tiene']
    sc.frame_set(0)
    for l in LATI:
        log(l, 'polso', wa(pb_(f'{l}Hand').head), 'gomito', wa(pb_(f'{l}ForeArm').head), 'dir', dir_mano(l))
    log('foglio', wa(pb_('foglio').head), 'matita', matita.matrix_world.translation)


SCATTI = [('disegna', 0), ('disegna', 30), ('alza_testa', 24), ('si_alza', 7), ('porge_tiene', 0)]
if os.environ.get('SCATTI'):
    SCATTI = [(x.split(':')[0], int(x.split(':')[1])) for x in os.environ['SCATTI'].split(',')]


def render(cartella):
    stampa_porge()
    """Qualche render di prova (Cycles su CPU), con un foglio A4 finto: solo per controllare, non va nel GLB."""
    os.makedirs(cartella, exist_ok=True)
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    fp = bpy.context.active_object
    fp.name = '_foglio_prova'
    fp.scale = (A4[0], A4[1], 1)
    fp.location = foglio_centro() + Vector((0, 0, 0.001))
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    fv = bpy.context.active_object
    fv.name = '_foglio_porto'
    fv.scale = (A4[0], A4[1], 1)
    bpy.ops.mesh.primitive_plane_add(size=6.0)
    terra = bpy.context.active_object
    mt = bpy.data.materials.new('terra'); mt.use_nodes = True
    mt.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.25, 0.3, 0.32, 1)
    terra.data.materials.append(mt)
    mf = bpy.data.materials.new('carta'); mf.use_nodes = True
    mf.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.9, 0.88, 0.8, 1)
    fp.data.materials.append(mf); fv.data.materials.append(mf)
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 640, 640
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
    bpy.ops.object.light_add(type='SUN', rotation=(math.radians(50), 0, math.radians(30)))
    bpy.context.active_object.data.energy = 3.0
    cam_d = bpy.data.cameras.new('cam'); cam_d.lens = 50
    cam = bpy.data.objects.new('cam', cam_d); sc.collection.objects.link(cam); sc.camera = cam

    def guarda(da, verso):
        cam.location = Vector(da)
        cam.rotation_euler = (Vector(verso) - Vector(da)).to_track_quat('-Z', 'Y').to_euler()

    viste = {'lato': ((1.6, -0.5, 0.6), (0.03, -0.12, 0.35)), 'davanti': ((0.5, -1.7, 0.9), (0.03, -0.1, 0.4)),
             'alto': ((0.5, -0.9, 1.4), (0.03, -0.25, 0.1)), 'fronte': ((0.035, -1.4, 0.7), (0.035, 0.0, 0.6))}
    scatti = SCATTI
    for nome, f in scatti:
        arm.animation_data.action = bpy.data.actions[nome]
        sc.frame_set(f)
        porta = nome.startswith('porge')
        fp.hide_render = porta
        fv.hide_render = not porta
        if porta:
            b = pb_('foglio')
            fv.location = wa(b.head)
            fv.rotation_euler = (math.radians(90), 0, 0)
        matita.hide_render = porta
        for vn, (da, verso) in viste.items():
            if porta and vn == 'alto':
                continue
            guarda(da, verso)
            sc.render.filepath = os.path.join(cartella, f'{nome}_{f:02d}_{vn}.png')
            bpy.ops.render.render(write_still=True)
            log('render', sc.render.filepath)
