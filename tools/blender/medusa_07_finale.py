"""Passo 7: versione FINITA della medusa (scelte fedeli ai concept approvati).

  - corpo in vinile lucido laccato, come la statua (pelle, capelli, labbro dell'orbita);
  - campana traslucida con i canali radiali luminosi giallo -> rosa come Halitrephes maasi
    (maschera dei canali ricavata dalla geometria: attributo di vertice "canali");
  - tentacoli a nastro carnoso e traslucido (medusa_05_tentacoli.crea_tentacoli_statua): 6 zampe grosse,
    7 medi e 12 sottili; nella posa statua la medusa STA IN PIEDI sui tentacoli, che arrivano al piano del
    piedistallo (z = STATUA['z_pavimento']), ci si appoggiano e si arricciano; ogni tentacolo ha una catena
    di ossa per la fisica;
  - occhio di vetro lucido con l'iride approvata;
  - mani piu' eleganti (dita e polsi piu' sottili);
  - struttura interna della campana (medusa_campana_interna.py): canali, anello e gonadi luminosi;
  - fauce nascosta sotto l'occhio (medusa_fauce.py);
  - la posa statua (mani giunte sul petto) e' la posa di RIPOSO del modello: in Godot, senza animazioni,
    la medusa e' gia' la statua;
  - azioni per Godot: "statua" (= riposo, in piedi sui tentacoli), "sveglia" (si stacca dal piedistallo:
    il corpo sale di SOLLEVA metri e i tentacoli si staccano dal piano e pendono), "fluttua" (ciclo: corpo
    sospeso che ondeggia, campana che pulsa, tentacoli che ondeggiano), "insegue" (ciclo: braccia protese,
    tentacoli indietro) e "fauce_apre" (mascella + blend shape). Le azioni da sveglia hanno il corpo alla
    stessa altezza, cosi' si fondono bene. Piu' "affacciata" (medusa_affacciata.py): la medusa vera nella vasca
    sollevata della sala centrale, mani sul bordo, tentacoli che ricadono fuori, immobile con un respiro;
  - alla fine tutto passa alla SCALA VERA della statua (ALTEZZA_STATUA = 4,5 m dal piano dei tentacoli alla
    cima della testa, piano a z = 0): scala_reale.
Le texture finali del corpo (usura, ciocche dei capelli, giunture da bambola) le fa il passo 8.
Scrive build/medusa_finale.blend.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_07_finale.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_05_tentacoli as TENT  # noqa: E402
import medusa_campana_interna as INTERNO  # noqa: E402
import medusa_capelli as CAPELLI  # noqa: E402
import medusa_affacciata as AFF  # noqa: E402
import medusa_mani as MANI  # noqa: E402
import medusa_occhio_venato as VENE  # noqa: E402
import medusa_vasca_anim as VASCA  # noqa: E402
import medusa_attacco as ATT  # noqa: E402
import medusa_fauce as FAUCE  # noqa: E402
import medusa_pose as POSE  # noqa: E402

Z_VITA = -0.155
FPS = 24

SOLLEVA = 0.5           # quando si sveglia il corpo sale di tanto (unita' del modello, x scala dopo)
ALTEZZA_STATUA = 4.5    # m: dal piano d'appoggio dei tentacoli alla cima della testa (statua imponente)

# colori dei canali (gradiente dall'alto della campana al bordo), come Halitrephes maasi
CANALI_GRADIENTE = [(0.0, (1.0, 0.72, 0.08)), (0.45, (1.0, 0.36, 0.22)), (1.0, (1.0, 0.12, 0.55))]
CANALI_FORZA = 1.8


# ---------------------------------------------------------------- canali della campana

def maschera_canali(ob):
    """Attributo di vertice 'canali' (colore): R = canale radiale (creste della campana), G = bordo,
    B = posizione dall'alto (0, vita) al bordo (1)."""
    me = ob.data
    co = coords(me)
    nrm = np.empty(len(co) * 3); me.vertices.foreach_get('normal', nrm); nrm = nrm.reshape(-1, 3)
    me.calc_loop_triangles()
    lt = np.empty(len(me.loop_triangles) * 3, dtype=np.int64); me.loop_triangles.foreach_get('vertices', lt)
    tp = np.empty(len(me.loop_triangles), dtype=np.int64); me.loop_triangles.foreach_get('polygon_index', tp)
    mi = np.empty(len(me.polygons), dtype=np.int32); me.polygons.foreach_get('material_index', mi)
    idx_c = [m.name for m in me.materials].index('M_campana')
    campana = np.zeros(len(co), bool)
    campana[lt.reshape(-1, 3)[mi[tp] == idx_c].ravel()] = True
    x, y, z = co.T
    r = np.hypot(x, y)
    rh = np.stack([x, y], 1) / np.maximum(r, 1e-9)[:, None]
    fuori = (nrm[:, :2] * rh).sum(1) > 0.25
    th = np.degrees(np.arctan2(y, x)) % 360
    cresta = np.zeros(len(co))
    sel = campana & fuori & (z < Z_VITA) & (z > -0.66)
    for z0 in np.arange(-0.66, Z_VITA, 0.01):
        m = sel & (z >= z0) & (z < z0 + 0.012)
        if m.sum() < 30:
            continue
        tb = th[m].astype(int) % 360
        s = np.bincount(tb, weights=r[m], minlength=360); c = np.bincount(tb, minlength=360)
        good = c > 0
        media = np.interp(np.arange(360), np.nonzero(good)[0], s[good] / c[good], period=360)
        k = 21
        ext = np.r_[media[-k:], media, media[:k]]
        liscia = np.convolve(ext, np.ones(k) / k, mode='same')[k:-k]
        cresta[m] = r[m] - liscia[tb]
    canale = np.clip((cresta * 1000 - 1.0) / 4.0, 0, 1) * sel
    t = np.clip((Z_VITA - z) / (Z_VITA + 0.66), 0, 1) * campana
    canale *= np.clip((t - 0.03) / 0.12, 0, 1)
    bordo = campana & (z < -0.56) & (r > 0.36)
    bordo = bordo * np.clip((r - 0.36) / 0.06, 0, 1)
    # ammorbidisce un poco sui vicini
    ev = adiacenza_vertici(me)
    for _ in range(2):
        somma = np.zeros(len(co)); cnt = np.zeros(len(co))
        np.add.at(somma, ev[:, 0], canale[ev[:, 1]]); np.add.at(cnt, ev[:, 0], 1)
        np.add.at(somma, ev[:, 1], canale[ev[:, 0]]); np.add.at(cnt, ev[:, 1], 1)
        canale = np.where(campana, 0.5 * canale + 0.5 * somma / np.maximum(cnt, 1), 0)
    att = me.color_attributes.get('canali') or me.color_attributes.new('canali', 'FLOAT_COLOR', 'POINT')
    dati = np.stack([canale, bordo.astype(float), t, np.ones(len(co))], 1)
    att.data.foreach_set('color', dati.ravel())
    log(f'canali della campana: {int((canale > 0.5).sum())} vertici sulle creste')
    return dati


# ---------------------------------------------------------------- mani piu' eleganti

DITA_SOTTILI = 0.84     # le dita si stringono attorno all'asse delle ossa (raggio x 0.84)
POLSO_SOTTILE = 0.9     # polso e fine dell'avambraccio un po' piu' fini


def mani_eleganti(arm, corpo):
    """Dita piu' sottili e polso piu' fine (posa di riposo, prima della posa statua): ogni vertice si avvicina
    all'asse dell'osso che lo muove di piu', in proporzione al peso. Vale anche per le shape key."""
    me = corpo.data
    co = coords(me)
    nomi = [vg.name for vg in corpo.vertex_groups]
    W = np.zeros((len(co), len(nomi)), np.float32)
    for v in me.vertices:
        for gr in v.groups:
            W[v.index, gr.group] = gr.weight
    nuovo = co.copy()

    def stringi(sel_ossa, fattore, rampa=None):
        idx = [nomi.index(n) for n in sel_ossa if n in nomi]
        if not idx:
            return
        Wd = W[:, idx]
        tot = np.clip(Wd.sum(1), 0, 1)
        k = np.argmax(Wd, 1)
        for j, n in enumerate([nomi[i] for i in idx]):
            sel = (k == j) & (tot > 0.05)
            if not sel.any():
                continue
            b = arm.data.bones[n]
            h, t = np.array(b.head_local), np.array(b.tail_local)
            asse = t - h
            L2 = asse @ asse
            p = nuovo[sel]
            u = np.clip(((p - h) @ asse) / L2, 0, 1)
            c = h + u[:, None] * asse
            f = 1 - (1 - fattore) * tot[sel]
            if rampa is not None:
                f = 1 - (1 - f) * rampa(u)
            nuovo[sel] = c + (p - c) * f[:, None]

    for suf in ('.L', '.R'):
        dita = [f'{d}_{f}{suf}' for d in ('pollice', 'indice', 'medio', 'anulare', 'mignolo') for f in (1, 2, 3)]
        stringi(dita, DITA_SOTTILI)
        stringi(['avambraccio' + suf], POLSO_SOTTILE, rampa=lambda u: np.clip((u - 0.45) / 0.45, 0, 1))
    delta = nuovo - co
    set_coords(me, nuovo)
    if me.shape_keys:
        for kb in me.shape_keys.key_blocks:
            d = np.empty(len(co) * 3, np.float32)
            kb.data.foreach_get('co', d)
            kb.data.foreach_set('co', (d.reshape(-1, 3) + delta).ravel())
    me.update()
    log(f'mani eleganti: {int((np.linalg.norm(delta, axis=1) > 1e-5).sum())} vertici spostati '
        f'(dita x{DITA_SOTTILI}, polso x{POLSO_SOTTILE})')


# ---------------------------------------------------------------- viso: palpebre e bocca nascosta

def palpebre(corpo, alza_su=0.0022, alza_giu=0.0009):
    """Palpebre piu' definite: il labbro dell'orbita (M_orbita) si alza un poco in avanti, di piu' sopra (palpebra
    superiore piu' spessa, come negli occhi delle bambole), sfumando verso la pelle."""
    me = corpo.data
    occ = leggi_json('occhio_3d.json')
    C = np.array(occ['centro_rotazione'])
    asse = np.array(occ['asse_riposo'])
    co = coords(me)
    nomi = [m.name if m else '' for m in me.materials]
    if 'M_orbita' not in nomi:
        return
    io = nomi.index('M_orbita')
    sel = np.zeros(len(co), bool)
    for poly in me.polygons:
        if poly.material_index == io:
            sel[list(poly.vertices)] = True
    if not sel.any():
        return
    # sfumatura: piena sul labbro, si spegne entro 8 mm intorno
    from scipy.spatial import cKDTree
    d, _ = cKDTree(co[sel]).query(co, distance_upper_bound=0.01)
    w = np.where(np.isfinite(d), np.clip(1 - d / 0.008, 0, 1), 0) ** 2
    rel = co - C
    su = np.clip((rel[:, 2] - 0.0) / 0.03, 0, 1)                  # parte alta dell'orbita
    alza = (alza_giu + (alza_su - alza_giu) * su) * w
    delta = alza[:, None] * asse[None, :]
    set_coords(me, co + delta)
    if me.shape_keys:
        for kb in me.shape_keys.key_blocks:
            dd = np.empty(len(co) * 3, np.float32)
            kb.data.foreach_get('co', dd)
            kb.data.foreach_set('co', (dd.reshape(-1, 3) + delta).ravel())
    me.update()
    log(f'palpebre: {int((alza > 1e-5).sum())} vertici, fino a {alza_su * 1000:.1f} mm sopra')


def normali_cucitura(corpo):
    """La bocca nascosta e' un taglio (vertici doppi): a riposo le due labbra devono avere la stessa normale,
    altrimenti si vede una riga. Normali personalizzate = media delle coppie di vertici coincidenti."""
    from scipy.spatial import cKDTree
    me = corpo.data
    co = coords(me)
    nrm = np.empty(len(co) * 3); me.vertices.foreach_get('normal', nrm); nrm = nrm.reshape(-1, 3)
    coppie = cKDTree(co).query_pairs(1e-6, output_type='ndarray')
    if len(coppie) == 0:
        return
    nuove = nrm.copy()
    m = nrm[coppie[:, 0]] + nrm[coppie[:, 1]]
    m /= np.linalg.norm(m, axis=1, keepdims=True) + 1e-12
    nuove[coppie[:, 0]] = m
    nuove[coppie[:, 1]] = m
    me.normals_split_custom_set_from_vertices([tuple(x) for x in nuove])
    me.update()
    log(f'bocca nascosta: {len(coppie)} coppie di vertici con la stessa normale (niente riga a riposo)')


# ---------------------------------------------------------------- materiali finali (Cycles)

def vinile_laccato(nomi):
    for n in nomi:
        m = bpy.data.materials.get(n)
        if not m:
            continue
        nt = m.node_tree
        b = nt.nodes['BSDF']
        for l in list(b.inputs['Roughness'].links):
            nt.links.remove(l)
        b.inputs['Roughness'].default_value = 0.12
        b.inputs['Coat Weight'].default_value = 1.0
        b.inputs['Coat Roughness'].default_value = 0.04
        b.inputs['Specular IOR Level'].default_value = 0.5
        b.inputs['Subsurface Weight'].default_value = 0.04
        b.inputs['Subsurface Radius'].default_value = (0.9, 0.6, 0.5)
        b.inputs['Subsurface Scale'].default_value = 0.02


def materiale_campana():
    m = bpy.data.materials['M_campana']
    nt = m.node_tree
    b = nt.nodes['BSDF']
    att = nt.nodes.new('ShaderNodeAttribute'); att.attribute_name = 'canali'; att.attribute_type = 'GEOMETRY'
    sep = nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(att.outputs['Color'], sep.inputs['Color'])
    # colore: texture della campana schiarita verso un lilla-rosa gelatinoso
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MIX'
    mix.inputs['Factor'].default_value = 0.5
    mix.inputs['B'].default_value = (0.62, 0.36, 0.95, 1)
    nt.links.new(nt.nodes['base'].outputs['Color'], mix.inputs['A'])
    nt.links.new(mix.outputs['Result'], b.inputs['Base Color'])
    # trasparenza: piena sotto, sfuma nella pelle vicino alla vita
    sm = nt.nodes.new('ShaderNodeMapRange'); sm.interpolation_type = 'SMOOTHSTEP'
    sm.inputs['From Min'].default_value = 0.0; sm.inputs['From Max'].default_value = 0.2
    sm.inputs['To Min'].default_value = 0.0; sm.inputs['To Max'].default_value = 0.94
    nt.links.new(sep.outputs['Blue'], sm.inputs['Value'])
    nt.links.new(sm.outputs['Result'], b.inputs['Transmission Weight'])
    for l in list(b.inputs['Roughness'].links):
        nt.links.remove(l)
    b.inputs['Roughness'].default_value = 0.07
    b.inputs['IOR'].default_value = 1.34
    b.inputs['Coat Weight'].default_value = 0.45
    b.inputs['Coat Roughness'].default_value = 0.05
    # emissione dei canali: gradiente giallo -> rosa lungo la campana
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = CANALI_GRADIENTE[0][0], (*CANALI_GRADIENTE[0][1], 1)
    el[1].position, el[1].color = CANALI_GRADIENTE[-1][0], (*CANALI_GRADIENTE[-1][1], 1)
    e = el.new(CANALI_GRADIENTE[1][0]); e.color = (*CANALI_GRADIENTE[1][1], 1)
    nt.links.new(sep.outputs['Blue'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Emission Color'])
    somma = nt.nodes.new('ShaderNodeMath'); somma.operation = 'MULTIPLY_ADD'
    somma.inputs[1].default_value = 0.5                     # bordo meno forte dei canali
    nt.links.new(sep.outputs['Green'], somma.inputs[0])
    nt.links.new(sep.outputs['Red'], somma.inputs[2])
    forza = nt.nodes.new('ShaderNodeMath'); forza.operation = 'MULTIPLY'
    forza.inputs[1].default_value = CANALI_FORZA
    nt.links.new(somma.outputs['Value'], forza.inputs[0])
    nt.links.new(forza.outputs['Value'], b.inputs['Emission Strength'])
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass


def materiale_occhio():
    mb = bpy.data.materials['M_occhio_bulbo']
    nt = mb.node_tree
    b = nt.nodes['BSDF']
    b.inputs['Roughness'].default_value = 0.3
    b.inputs['Coat Weight'].default_value = 0.0
    # l'iride resta rosa anche al buio (come nei concept): un filo di luce propria
    nt.links.new(nt.nodes['base'].outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 0.35
    VENE.materiale_venatura()           # versione malvagia: 'venatura' da 0 (calma) a 1 (vene rosse)
    mc = bpy.data.materials['M_occhio_cornea']
    b = mc.node_tree.nodes['BSDF']
    b.inputs['Transmission Weight'].default_value = 1.0
    b.inputs['Roughness'].default_value = 0.0
    b.inputs['IOR'].default_value = 1.5


# ---------------------------------------------------------------- azioni

def _nla(id_data, nome, action):
    ad = id_data.animation_data or id_data.animation_data_create()
    tr = ad.nla_tracks.new()
    tr.name = nome
    st = tr.strips.new(nome, int(action.frame_range[0]), action)
    st.name = nome
    ad.action = None
    # muta mentre si scrivono le altre azioni (le tracce attive rimetterebbero i loro valori nella posa):
    # alla fine del passo si riattivano tutte
    tr.mute = True
    return tr


def _chiave_posa(arm, frame, ossa=None):
    for pb in arm.pose.bones:
        if ossa and pb.name not in ossa:
            continue
        pb.rotation_mode = 'QUATERNION'
        pb.keyframe_insert('location', frame=frame)
        pb.keyframe_insert('rotation_quaternion', frame=frame)
        pb.keyframe_insert('scale', frame=frame)


def _nuova_azione(arm, nome):
    act = bpy.data.actions.new(nome)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    return act


def azione_statua(arm):
    """La statua e' la posa di riposo: l'azione tiene semplicemente tutte le ossa a riposo."""
    act = _nuova_azione(arm, 'statua')
    POSE.azzera(arm)
    _chiave_posa(arm, 1)
    _chiave_posa(arm, 2)
    _nla(arm, 'statua', act)


def posa_come_riposo(arm):
    """La posa statua (mani giunte) diventa la posa di riposo del modello: in Godot, senza animazioni,
    la medusa e' gia' la statua. Le mesh si deformano nella posa (shape key comprese) e le ossa si rimettono a
    riposo in quella posa."""
    attiva(arm)
    bpy.ops.object.mode_set(mode='POSE')
    POSE.posa_statua(arm)
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh = [o for o in bpy.data.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)]

    def valutata(ob):
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        co = coords(ev.to_mesh())
        ev.to_mesh_clear()
        return co

    deformate = {}
    for ob in mesh:
        keys = list(ob.data.shape_keys.key_blocks) if ob.data.shape_keys else []
        for k in keys:
            k.value = 0.0
        base = valutata(ob)
        chiavi = {}
        for k in keys[1:]:
            k.value = 1.0
            chiavi[k.name] = valutata(ob)
            k.value = 0.0
        deformate[ob.name] = (base, chiavi)
    for ob in mesh:
        base, chiavi = deformate[ob.name]
        for m in [m for m in ob.modifiers if m.type == 'ARMATURE']:
            ob.modifiers.remove(m)
        set_coords(ob.data, base)
        if ob.data.shape_keys:
            kb = ob.data.shape_keys.key_blocks
            kb[0].data.foreach_set('co', base.ravel())
            for nome, co in chiavi.items():
                kb[nome].data.foreach_set('co', co.ravel())
        ob.data.update()
    attiva(arm)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    for ob in mesh:
        mod = ob.modifiers.new('Scheletro', 'ARMATURE')
        mod.object = arm
    log(f'posa statua applicata come posa di riposo ({len(mesh)} mesh)')


def posa_insegue(arm, f=1.0):
    """Braccia protese verso il giocatore, busto in avanti, dita ad artiglio (f = intensita')."""
    POSE.azzera(arm)
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = Vector((s * (0.20 + 0.1 * (1 - f)), -0.62 * f - 0.05 * (1 - f), 0.18 * f - 0.2 * (1 - f)))
        polo = Vector((s * 0.5, 0.15, -0.1))
        dir_mano = Vector((s * 0.08, -1.0, 0.12))
        dorso = Vector((s * 0.15, 0.1, 1.0))
        POSE.posa_braccio(arm, suf, polso, polo, dir_mano, dorso)
        POSE.piega_dita(arm, suf, 38 * f - POSE.DITA_STATUA, pollice=18 * f - POSE.POLLICE_STATUA)
    # rotazione X positiva = busto in avanti (verso -Y); la testa si rialza per guardare il giocatore
    for nome, gradi in (('colonna_1', 10), ('colonna_2', 9), ('petto', 6)):
        pb = arm.pose.bones[nome]; pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi * f), 0, 0)
    pb = arm.pose.bones['testa']; pb.rotation_mode = 'XYZ'
    pb.rotation_euler = (math.radians(-18 * f), 0, 0)
    POSE.aggiorna()


def _catene(arm):
    """Catene dei tentacoli: {i: [tentacolo_ii_01, tentacolo_ii_02, ...]}."""
    cat = {}
    for b in arm.data.bones:
        if b.name.startswith('tentacolo_'):
            _, i, k = b.name.split('_')
            cat.setdefault(int(i), []).append((int(k), b.name))
    return {i: [n for _, n in sorted(v)] for i, v in sorted(cat.items())}


def solleva(arm, dz=SOLLEVA):
    """Il corpo si stacca dal piedistallo (l'asse Y dell'osso radice e' l'alto)."""
    arm.pose.bones['radice'].location = (0, dz, 0)
    POSE.aggiorna()


def posa_tentacoli_pendenti(arm, tempo=0.0, scia=0.0, ampiezza=1.0):
    """Tentacoli staccati dal piano: ogni catena pende dalla campana allargandosi un po' (il primo osso, dentro
    la campana, resta com'e'), con un'onda che scende verso la punta (tempo in cicli, 0..1) e, con 'scia',
    resta indietro (+Y) come quando la medusa avanza. Le punte restano sopra il pavimento."""
    POSE.aggiorna()
    zp = TENT.STATUA['z_pavimento']
    for i, nomi in _catene(arm).items():
        pb0 = arm.pose.bones[nomi[0]]
        base = pb0.tail.copy()
        rad = Vector((pb0.head.x, pb0.head.y, 0))
        rad = rad.normalized() if rad.length > 1e-4 else Vector((1, 0, 0))
        lato = Vector((-rad.y, rad.x, 0))
        lungh = [arm.data.bones[nm].length for nm in nomi]
        fase = i * 2.39
        n = len(nomi)
        for prova in range(10):
            allarga = 0.3 + 0.25 * prova
            dirs, p, zmin = [], base.copy(), base.z
            for k in range(1, n):
                f = k / max(n - 1, 1)
                onda = ampiezza * 0.32 * f * math.sin(2 * math.pi * (tempo - 0.9 * f) + fase)
                onda2 = ampiezza * 0.22 * f * math.cos(2 * math.pi * (tempo - 0.8 * f) + 1.3 * fase)
                d = (Vector((0, 0, -1)) + rad * (allarga * (1 - f) ** 1.3 + 0.1 + onda2) + lato * onda
                     + Vector((0, 1, 0)) * scia * f)
                d.normalize()
                dirs.append(d)
                p = p + d * lungh[k]
                zmin = min(zmin, p.z)
            if zmin > zp + 0.06:
                break
        p = base.copy()
        for k in range(1, n):
            POSE.orienta(arm, nomi[k], p, dirs[k - 1])
            p = p + dirs[k - 1] * lungh[k]
    # da sveglia le braccia si aprono: due zampe incrociate coprono il petto (regola del GDD)
    ATT.zampe_sul_petto(arm, bpy.data.objects['Medusa'])


def posa_sveglia(arm, tempo=0.0, scia=0.0, braccia=0.35):
    """Medusa sveglia e sospesa: corpo su, braccia un po' avanti, tentacoli che pendono."""
    posa_insegue(arm, braccia)
    solleva(arm)
    posa_tentacoli_pendenti(arm, tempo, scia)


def azione_insegue(arm):
    """Ciclo di 24 fotogrammi (1 s): braccia protese, busto avanti, tentacoli indietro che ondeggiano."""
    durata = 24
    act = _nuova_azione(arm, 'insegue')
    for f in range(0, durata + 1, 4):
        POSE.azzera(arm)
        posa_sveglia(arm, f / durata, scia=0.7, braccia=1.0)
        _chiave_posa(arm, f + 1)
    _nla(arm, 'insegue', act)
    POSE.azzera(arm)


def azione_sveglia(arm):
    """Da statua a sveglia (30 fotogrammi): il corpo sale, i tentacoli si staccano dal piano e pendono."""
    act = _nuova_azione(arm, 'sveglia')
    POSE.azzera(arm)
    _chiave_posa(arm, 1)
    posa_sveglia(arm, 0.0)
    _chiave_posa(arm, 30)
    _nla(arm, 'sveglia', act)
    POSE.azzera(arm)


def azione_fluttua(arm, corpo):
    """Ciclo di 48 fotogrammi (2 s): corpo sospeso che sale e scende, campana che pulsa, tentacoli che ondeggiano."""
    durata = 48
    act = _nuova_azione(arm, 'fluttua')
    for f in range(0, durata + 1, 4):
        POSE.azzera(arm)
        posa_sveglia(arm, f / durata)
        solleva(arm, SOLLEVA + 0.035 * math.sin(f / durata * 2 * math.pi))
        _chiave_posa(arm, f + 1)
    _nla(arm, 'fluttua', act)
    # pulsazione della campana (shape key), anche per la struttura interna
    for ob in (corpo, bpy.data.objects.get('Medusa_Interno'), bpy.data.objects.get('Medusa_Bordo')):
        if ob is None or not ob.data.shape_keys:
            continue
        key = ob.data.shape_keys
        kb = key.key_blocks['campana_contrai']
        ad = key.animation_data or key.animation_data_create()
        ka = bpy.data.actions.new(f'fluttua_campana_{ob.name}')
        ad.action = ka
        for f, v in ((1, 0.0), (13, 0.85), (25, 0.15), (37, 0.0), (49, 0.0)):
            kb.value = v
            kb.keyframe_insert('value', frame=f)
        _nla(key, 'fluttua', ka)
        kb.value = 0
    POSE.azzera(arm)


def posa_attacco(arm, f=1.0):
    """Attacco: braccia larghe in avanti ad artiglio (non coprono il viso), busto in avanti, testa su."""
    POSE.azzera(arm)
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = Vector((s * 0.52, -0.36, 0.26))
        polo = Vector((s * 0.65, 0.25, -0.15))
        dir_mano = Vector((s * 0.35, -0.9, 0.25))
        dorso = Vector((s * 0.2, 0.15, 1.0))
        POSE.posa_braccio(arm, suf, polso, polo, dir_mano, dorso)
        POSE.piega_dita(arm, suf, 45 * f - POSE.DITA_STATUA, pollice=20 * f - POSE.POLLICE_STATUA)
    for nome, gradi in (('colonna_1', 8), ('colonna_2', 8), ('petto', 5)):
        pb = arm.pose.bones[nome]; pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(gradi * f), 0, 0)
    pb = arm.pose.bones['testa']; pb.rotation_mode = 'XYZ'
    pb.rotation_euler = (math.radians(-14 * f), 0, 0)
    POSE.aggiorna()


def azione_fauce(arm):
    act = _nuova_azione(arm, 'fauce_apre')
    for f, v in ((1, 0.0), (5, 0.35), (10, 1.0), (24, 1.0)):
        POSE.azzera(arm)
        posa_attacco(arm, 1.0)
        solleva(arm)
        posa_tentacoli_pendenti(arm, 0.0, scia=0.3)
        FAUCE.apri_fauce(arm, v)
        _chiave_posa(arm, f)
    _nla(arm, 'fauce_apre', act)
    for nome, kname in (('Medusa', 'fauce_strappo'), ('Medusa_Gola', 'fauce_aperta'), ('Medusa_Denti', 'fauce_aperta'),
                        ('Medusa_Strappo', 'fauce_aperta')):
        ob = bpy.data.objects[nome]
        key = ob.data.shape_keys
        kb = key.key_blocks[kname]
        ad = key.animation_data or key.animation_data_create()
        ka = bpy.data.actions.new(f'fauce_apre_{nome}')
        ad.action = ka
        for f, v in ((1, 0.0), (5, 0.35), (10, 1.0), (24, 1.0)):
            kb.value = v
            kb.keyframe_insert('value', frame=f)
        _nla(key, 'fauce_apre', ka)
        kb.value = 0.0
    FAUCE.apri_fauce(arm, 0.0)
    POSE.azzera(arm)


def _fcurves(act):
    """F-curve di un'azione (API vecchia o azioni a strati di Blender 4.4+)."""
    try:
        return list(act.fcurves)
    except AttributeError:
        pass
    out = []
    for layer in getattr(act, 'layers', []):
        for strip in layer.strips:
            for cb in getattr(strip, 'channelbags', []):
                out.extend(cb.fcurves)
    return out


def scala_reale(arm, altezza=ALTEZZA_STATUA):
    """Porta la medusa alla scala vera della statua: alta 'altezza' metri dal piano d'appoggio dei tentacoli alla
    cima della testa, col piano a z = 0 (lo scheletro sta a z = -z_pavimento * k). Scala mesh (con le shape key),
    ossa e chiavi di posizione delle azioni (sono nello spazio delle ossa). Ritorna il fattore k."""
    zp = TENT.STATUA['z_pavimento']
    corpo = bpy.data.objects['Medusa']
    k = altezza / (coords(corpo.data)[:, 2].max() - zp)
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    S = Matrix.Scale(k, 4)
    for o in [o for o in bpy.data.objects if o.parent == arm]:
        if o.matrix_basis != Matrix() or o.matrix_parent_inverse != Matrix():
            o.data.transform(o.matrix_parent_inverse @ o.matrix_basis, shape_keys=True)
            o.matrix_parent_inverse = Matrix()
            o.matrix_basis = Matrix()
        if o.type == 'MESH':
            o.data.transform(S, shape_keys=True)
            o.data.update()
    attiva(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    teste = {b.name: (b.head.copy(), b.tail.copy()) for b in eb}
    for b in eb:
        h, t = teste[b.name]
        b.head = h * k
        b.tail = t * k
    bpy.ops.object.mode_set(mode='OBJECT')
    n = 0
    for act in bpy.data.actions:
        for fc in _fcurves(act):
            if fc.data_path.endswith('.location'):
                for kp in fc.keyframe_points:
                    kp.co.y *= k
                    kp.handle_left.y *= k
                    kp.handle_right.y *= k
                n += 1
    arm.location = (0, 0, -zp * k)
    arm['scala'] = k
    log(f'scala reale: x{k:.3f}, statua alta {altezza} m dal piano dei tentacoli (z = 0), '
        f'{n} curve di posizione scalate')
    return k


def main():
    t0 = time.time()
    apri(os.path.join(BUILD, 'medusa_04_scheletro.blend'))
    arm = bpy.data.objects['Medusa_Scheletro']
    corpo = bpy.data.objects['Medusa']
    coll = bpy.data.collections.get('Attacchi_tentacoli')       # vecchi punti d'attacco: non servono piu'
    if coll:
        for e in list(coll.objects):
            bpy.data.objects.remove(e)
        bpy.data.collections.remove(coll)
        bpy.context.view_layer.update()
    # mani nuove da bambola (quelle di Meshy erano irrecuperabili): scheletro della mano rifatto, mani vecchie tolte
    # dal corpo (taglio netto al polso), oggetto Medusa_Mani al loro posto
    MANI.rifai_ossa_mano(arm)
    mani_eleganti(arm, corpo)
    raggi_polso = MANI.togli_mani_vecchie(arm, corpo)
    MANI.crea_mani(arm, corpo, raggi_polso)
    TENT.crea_tentacoli_statua(arm, TENT.STATUA)
    FAUCE.costruisci_fauce(arm)
    maschera_canali(corpo)
    INTERNO.crea_interno(arm, corpo)
    INTERNO.crea_bordo(arm, corpo)
    CAPELLI.crea_ciocche(arm, corpo)
    palpebre(corpo)
    vinile_laccato(['M_pelle', 'M_capelli', 'M_orbita'])
    materiale_campana()
    materiale_occhio()
    VENE.forma_venatura(arm)            # blend shape 'venatura' dell'occhio (si gonfia appena quando attacca)
    posa_come_riposo(arm)
    normali_cucitura(corpo)
    AFF.schiaccia_campana(arm)          # solo per la posa affacciata (campana sott'acqua)
    # mentre si scrivono le azioni le mesh non serve deformarle (molto piu' veloce)
    mods = [m for o in bpy.data.objects if o.type == 'MESH' for m in o.modifiers if m.type == 'ARMATURE']
    for m in mods:
        m.show_viewport = False
    attiva(arm)
    bpy.ops.object.mode_set(mode='POSE')
    azione_statua(arm)
    azione_sveglia(arm)
    azione_insegue(arm)
    azione_fluttua(arm, corpo)
    azione_fauce(arm)
    # sala centrale: la medusa vera affacciata alla vasca (stessa scala vera della statua)
    k_vero = ALTEZZA_STATUA / (coords(corpo.data)[:, 2].max() - TENT.STATUA['z_pavimento'])
    AFF.azione_affacciata(arm, k_vero, TENT.STATUA['z_pavimento'], _chiave_posa, _nla)
    # tappa 8: dalla posa affacciata scivola sotto, nuota via, oppure afferra chi si avvicina troppo
    VASCA.azioni_vasca(arm, k_vero, TENT.STATUA['z_pavimento'], _chiave_posa, _nla)
    bpy.ops.object.mode_set(mode='OBJECT')
    for m in mods:
        m.show_viewport = True
    for i in list(bpy.data.objects) + list(bpy.data.shape_keys):
        if i.animation_data:
            for tr in i.animation_data.nla_tracks:
                tr.mute = False
                for st in tr.strips:
                    st.extrapolation = 'NOTHING'      # fuori dalle strisce: riposo (la statua)
    for k in bpy.data.shape_keys:
        for kb in k.key_blocks[1:]:
            kb.value = 0.0
    POSE.azzera(arm)
    scala_reale(arm)
    bpy.context.scene.render.fps = FPS
    salva(os.environ.get('MEDUSA_FINALE', os.path.join(BUILD, 'medusa_finale.blend')))
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
