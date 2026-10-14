"""Passo 7: versione FINITA della medusa (scelte fedeli ai concept approvati).

  - corpo in vinile lucido laccato, come la statua (pelle, capelli, labbro dell'orbita);
  - campana traslucida con i canali radiali luminosi giallo -> rosa come Halitrephes maasi
    (maschera dei canali ricavata dalla geometria: attributo di vertice "canali");
  - 12 tentacoli lunghi e spezzati come nel concept della statua, con catene di ossa per la fisica;
  - occhio di vetro lucido con l'iride approvata;
  - fauce nascosta sotto l'occhio (medusa_fauce.py);
  - azioni per Godot: "statua" (mani giunte sul petto), "fluttua" (ciclo: corpo che ondeggia, campana che
    pulsa, tentacoli che ondeggiano), "fauce_apre" (mascella + blend shape), "insegue" (braccia protese).
Scrive build/medusa_finale.blend.

Uso: nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_07_finale.py
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_05_tentacoli as TENT  # noqa: E402
import medusa_fauce as FAUCE  # noqa: E402
import medusa_pose as POSE  # noqa: E402

Z_VITA = -0.155
FPS = 24

TENTACOLI_FINALI = dict(TENT.PRESET['spezzati'], n_grossi=12, lunghezza=1.6, apertura=0.7, ampiezza=0.08,
                        passo=0.17, angolo_pieghe=34, raggio_base=0.032, raggio_punta=0.005, n_sottili=14,
                        lunghezza_sottili=1.25, n_ossa=10, seme=7)

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
    sm.inputs['To Min'].default_value = 0.0; sm.inputs['To Max'].default_value = 0.88
    nt.links.new(sep.outputs['Blue'], sm.inputs['Value'])
    nt.links.new(sm.outputs['Result'], b.inputs['Transmission Weight'])
    for l in list(b.inputs['Roughness'].links):
        nt.links.remove(l)
    b.inputs['Roughness'].default_value = 0.1
    b.inputs['IOR'].default_value = 1.34
    b.inputs['Coat Weight'].default_value = 0.6
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


def materiale_tentacoli():
    for nome, col in (('M_tentacoli', (0.78, 0.07, 0.34)), ('M_filamenti', (0.92, 0.18, 0.5))):
        m = bpy.data.materials.get(nome)
        if not m:
            continue
        b = m.node_tree.nodes['BSDF']
        b.inputs['Base Color'].default_value = (*col, 1)
        b.inputs['Roughness'].default_value = 0.2
        b.inputs['Coat Weight'].default_value = 0.7
        b.inputs['Coat Roughness'].default_value = 0.06
        b.inputs['Subsurface Weight'].default_value = 0.3
        b.inputs['Subsurface Radius'].default_value = (0.7, 0.12, 0.25)
        b.inputs['Subsurface Scale'].default_value = 0.05
        b.inputs['Emission Color'].default_value = (*col, 1)
        b.inputs['Emission Strength'].default_value = 0.08


def materiale_occhio():
    mb = bpy.data.materials['M_occhio_bulbo']
    nt = mb.node_tree
    b = nt.nodes['BSDF']
    b.inputs['Roughness'].default_value = 0.3
    b.inputs['Coat Weight'].default_value = 0.0
    # l'iride resta rosa anche al buio (come nei concept): un filo di luce propria
    nt.links.new(nt.nodes['base'].outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 0.35
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
    act = _nuova_azione(arm, 'statua')
    POSE.posa_statua(arm)
    _chiave_posa(arm, 1)
    _chiave_posa(arm, 2)
    _nla(arm, 'statua', act)
    POSE.azzera(arm)


def posa_insegue(arm, f=1.0):
    """Braccia protese verso il giocatore, busto in avanti, dita ad artiglio (f = intensita')."""
    POSE.azzera(arm)
    for suf, s in (('.L', 1), ('.R', -1)):
        polso = Vector((s * (0.20 + 0.1 * (1 - f)), -0.62 * f - 0.05 * (1 - f), 0.18 * f - 0.2 * (1 - f)))
        polo = Vector((s * 0.5, 0.15, -0.1))
        dir_mano = Vector((s * 0.08, -1.0, 0.12))
        dorso = Vector((s * 0.15, 0.1, 1.0))
        POSE.posa_braccio(arm, suf, polso, polo, dir_mano, dorso)
        POSE.piega_dita(arm, suf, 38 * f, pollice=18 * f)
    for nome, gradi in (('colonna_1', 10), ('colonna_2', 9), ('petto', 6)):
        pb = arm.pose.bones[nome]; pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(-gradi * f), 0, 0)
    pb = arm.pose.bones['testa']; pb.rotation_mode = 'XYZ'
    pb.rotation_euler = (math.radians(18 * f), 0, 0)
    POSE.aggiorna()


def azione_insegue(arm):
    act = _nuova_azione(arm, 'insegue')
    posa_insegue(arm)
    _chiave_posa(arm, 1); _chiave_posa(arm, 2)
    _nla(arm, 'insegue', act)
    POSE.azzera(arm)


def onda_tentacoli(arm, frame, durata, ampiezza=1.0):
    """Ondeggiamento dei tentacoli: onda che scende lungo ogni catena."""
    t = frame / durata * 2 * math.pi
    for pb in arm.pose.bones:
        if not pb.name.startswith('tentacolo_'):
            continue
        _, i, k = pb.name.split('_')
        i, k = int(i), int(k)
        fase = i * 1.7
        a = math.radians((2.5 + 1.6 * k) * ampiezza)
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (a * math.sin(t - 0.55 * k + fase), 0, a * 0.7 * math.cos(t - 0.5 * k + fase * 1.3))


def azione_fluttua(arm, corpo):
    """Ciclo di 48 fotogrammi (2 s): il corpo sale e scende, la campana pulsa, i tentacoli ondeggiano."""
    durata = 48
    act = _nuova_azione(arm, 'fluttua')
    for f in range(0, durata + 1, 4):
        POSE.azzera(arm)
        posa_insegue(arm, 0.35)
        t = f / durata * 2 * math.pi
        pr = arm.pose.bones['radice']
        pr.location = (0, 0.035 * math.sin(t), 0)          # asse Y dell'osso radice = su
        onda_tentacoli(arm, f, durata)
        _chiave_posa(arm, f + 1)
    _nla(arm, 'fluttua', act)
    # pulsazione della campana (shape key)
    key = corpo.data.shape_keys
    kb = key.key_blocks['campana_contrai']
    ad = key.animation_data or key.animation_data_create()
    ka = bpy.data.actions.new('fluttua_campana')
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
        POSE.piega_dita(arm, suf, 45 * f, pollice=20 * f)
    for nome, gradi in (('colonna_1', 8), ('colonna_2', 8), ('petto', 5)):
        pb = arm.pose.bones[nome]; pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (math.radians(-gradi * f), 0, 0)
    pb = arm.pose.bones['testa']; pb.rotation_mode = 'XYZ'
    pb.rotation_euler = (math.radians(10 * f), 0, 0)
    POSE.aggiorna()


def azione_fauce(arm):
    act = _nuova_azione(arm, 'fauce_apre')
    for f, v in ((1, 0.0), (5, 0.35), (10, 1.0), (24, 1.0)):
        POSE.azzera(arm)
        posa_attacco(arm, 1.0)
        FAUCE.apri_fauce(arm, v)
        _chiave_posa(arm, f)
    _nla(arm, 'fauce_apre', act)
    for nome, kname in (('Medusa', 'fauce_strappo'), ('Medusa_Gola', 'fauce_aperta'), ('Medusa_Denti', 'fauce_aperta')):
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


def main():
    t0 = time.time()
    apri(os.path.join(BUILD, 'medusa_04_scheletro.blend'))
    arm = bpy.data.objects['Medusa_Scheletro']
    corpo = bpy.data.objects['Medusa']
    TENT.crea_tentacoli(arm, TENTACOLI_FINALI)
    FAUCE.costruisci_fauce(arm)
    maschera_canali(corpo)
    vinile_laccato(['M_pelle', 'M_capelli', 'M_orbita'])
    materiale_campana()
    materiale_tentacoli()
    materiale_occhio()
    attiva(arm)
    bpy.ops.object.mode_set(mode='POSE')
    azione_statua(arm)
    azione_insegue(arm)
    azione_fluttua(arm, corpo)
    azione_fauce(arm)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.scene.render.fps = FPS
    salva(os.path.join(BUILD, 'medusa_finale.blend'))
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
