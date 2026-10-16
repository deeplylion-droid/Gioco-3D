"""Passo 8: texture finali del corpo a 4K, per una statua alta 4,5 m vista da vicino.

Cuoce con Cycles, nell'atlante UV del corpo, colore, normal map e ruvidita' con i dettagli che mancavano:
  - capelli a ciocche: fibre e ciocche lungo la direzione dei capelli (dalla cima della testa in giu'),
    piu' scure tra una ciocca e l'altra e un po' meno lucide: meno "di plastica";
  - giunture sottili da bambola alle spalle, ai gomiti e ai polsi (un solco ad anello);
  - clavicole e spalle piu' definite, unghie sulle dita;
  - usura dosata da statua (il corpo resta vinile liscio da bambola-mascotte, "plasticoso" per scelta):
    patina, sporco nelle pieghe, qualche graffio, rare scrostature piccolissime. Niente usura sul viso.
Gli attributi di vertice che servono (occlusione, coordinate delle ciocche, distanza dalle giunture, viso)
si calcolano qui sulla posa statua; i motivi fini li disegna lo shader durante la cottura.
Scrive tex/medusa_colore_4k.jpg, tex/medusa_normal_4k.jpg, tex/medusa_ruvidezza_4k.jpg (G = ruvidita',
B = metallo) e aggiorna build/medusa_finale.blend (materiali del corpo con le nuove texture). Nel colore, il volume
dei capelli prende poi l'argento-rosa delle ciocche (medusa_capelli.ricolora_atlante, dal PNG della cottura).

Protezione delle texture approvate: le tre texture 4K di tex/ sono quelle approvate dall'utente (in git), e una
cottura rifatta non viene identica (quella rifatta il 16 ottobre cambia alcune isole UV dei capelli). Le texture
nuove si scrivono prima in build/texture_nuove/; se una texture di tex/ c'e' gia' ed e' diversa dalla nuova, il
passo si ferma con un messaggio e non tocca niente. Con MEDUSA_RISCRIVI_TEXTURE=1 le sostituisce (solo se l'utente
ha approvato le nuove); con MEDUSA_RISCRIVI_TEXTURE=0 tiene quelle approvate e finisce il passo. Vale anche con
--solo-materiali.

Uso: flock /home/user/tools/render.lock nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/medusa_08_dettagli.py
     con --solo-materiali non cuoce: rifa' il colore dei capelli nell'atlante e ricollega ai materiali le
     texture gia' fatte (dopo un passo 7 che ha cambiato solo pose, animazioni o colori).
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from medusa_comune import *  # noqa: E402,F401
import medusa_capelli as CAPELLI  # noqa: E402

LATO = int(os.environ.get('MEDUSA_LATO_DETTAGLI', '4096'))
TEX_COLORE = os.path.join(TEX, 'medusa_colore_4k.jpg')
TEX_NORMAL = os.path.join(TEX, 'medusa_normal_4k.jpg')
TEX_RUVIDO = os.path.join(TEX, 'medusa_ruvidezza_4k.jpg')
# sorgenti della cottura: le texture intermedie del passo 2b (sempre queste, cosi' rifare il passo 8 non cuoce
# di nuovo sopra il proprio risultato)
SORGENTE_BASE = os.path.join(BUILD, 'medusa_base_4k.png')
SORGENTE_NORMAL = os.path.join(BUILD, 'medusa_normal_4k.png')
COTTA_COLORE = os.path.join(BUILD, 'medusa_colore_cotta_4k.png')     # colore appena cotto (prima dei capelli)
# protezione delle texture approvate (vedi in cima): le nuove passano prima da qui
NUOVE = os.path.join(BUILD, 'texture_nuove')
RISCRIVI = os.environ.get('MEDUSA_RISCRIVI_TEXTURE', '')     # '1' sostituisce quelle approvate, '0' le tiene
USURA = 1.0             # quantita' di usura (0 = statua nuova)
CORPO = ('M_pelle', 'M_capelli', 'M_campana', 'M_orbita')
RUVIDO_BASE = {'M_pelle': 0.13, 'M_capelli': 0.3, 'M_campana': 0.1, 'M_orbita': 0.06}   # orbita: bagnata


# ---------------------------------------------------------------- attributi di vertice

def _attributo(me, nome, valori):
    a = me.attributes.get(nome) or me.attributes.new(nome, 'FLOAT', 'POINT')
    a.data.foreach_set('value', np.asarray(valori, np.float32))


def _vertici_di(me, nomi_mat):
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    mats = [m.name if m else '' for m in me.materials]
    idx = [mats.index(n) for n in nomi_mat if n in mats]
    sel = np.zeros(len(me.vertices), bool)
    for p in me.polygons:
        if p.material_index in idx:
            sel[list(p.vertices)] = True
    return sel


def occlusione(ob, raggi=20, dist=0.6):
    """Occlusione ambientale per vertice (raggi nell'emisfero della normale contro la mesh stessa)."""
    from mathutils.bvhtree import BVHTree
    me = ob.data
    co = coords(me)
    nrm = np.empty(len(co) * 3)
    me.vertices.foreach_get('normal', nrm)
    nrm = nrm.reshape(-1, 3)
    bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(p.vertices) for p in me.polygons])
    rng = np.random.default_rng(1)
    u1, u2 = rng.random(raggi), rng.random(raggi)
    loc = np.stack([np.sqrt(u1) * np.cos(2 * np.pi * u2), np.sqrt(u1) * np.sin(2 * np.pi * u2), np.sqrt(1 - u1)], 1)
    ao = np.ones(len(co), np.float32)
    rc = bvh.ray_cast
    for i in range(len(co)):
        n = nrm[i]
        a = np.array([1.0, 0, 0]) if abs(n[0]) < 0.9 else np.array([0, 1.0, 0])
        t = np.cross(n, a)
        t /= np.linalg.norm(t) + 1e-12
        b = np.cross(n, t)
        dirs = loc[:, :1] * t + loc[:, 1:2] * b + loc[:, 2:] * n
        o = Vector(co[i] + n * 0.004)
        colpi = 0
        for d in dirs:
            if rc(o, Vector(d), dist)[0] is not None:
                colpi += 1
        ao[i] = 1 - colpi / raggi
    ev = adiacenza_vertici(me)
    for _ in range(2):
        s = np.zeros(len(co)); c = np.zeros(len(co))
        np.add.at(s, ev[:, 0], ao[ev[:, 1]]); np.add.at(c, ev[:, 0], 1)
        np.add.at(s, ev[:, 1], ao[ev[:, 0]]); np.add.at(c, ev[:, 1], 1)
        ao = (0.5 * ao + 0.5 * s / np.maximum(c, 1)).astype(np.float32)
    return ao


def coordinate_ciocche(ob, arm):
    """Per i capelli: angolo intorno all'asse della testa (coseno e seno) e distanza dalla cima."""
    me = ob.data
    co = coords(me)
    cap = _vertici_di(me, ['M_capelli'])
    testa = arm.data.bones['testa']
    xh, yh = testa.head_local.x, testa.head_local.y
    zc = np.percentile(co[cap, 2], 97.5)
    phi = np.arctan2(co[:, 1] - yh, co[:, 0] - xh)
    d = np.linalg.norm(co - np.array([xh, yh, zc]), axis=1)
    c, s = np.cos(phi), np.sin(phi)
    c[~cap] = 0; s[~cap] = 0; d[~cap] = 0
    return c, s, d


def distanza_giunture(ob, arm, k):
    """Distanza (con segno, lungo l'asse dell'arto) dal piano della giuntura piu' vicina: spalle, gomiti, polsi.
    10 dove non c'e' nessuna giuntura vicina."""
    me = ob.data
    co = coords(me)
    nomi = [vg.name for vg in ob.vertex_groups]
    W = np.zeros((len(co), len(nomi)), np.float32)
    for v in me.vertices:
        for g in v.groups:
            W[v.index, g.group] = g.weight
    peso = lambda gruppi: W[:, [nomi.index(n) for n in gruppi if n in nomi]].sum(1)  # noqa: E731
    B = arm.data.bones
    out = np.full(len(co), 10.0, np.float32)
    migliore = np.full(len(co), 1e9)
    for suf in ('.L', '.R'):
        br, av, ma = B['braccio' + suf], B['avambraccio' + suf], B['mano' + suf]
        a_br = (br.tail_local - br.head_local).normalized()
        a_av = (av.tail_local - av.head_local).normalized()
        a_ma = (ma.tail_local - ma.head_local).normalized()
        giunti = [
            (br.head_local + a_br * (0.2 * br.length), a_br, ['braccio' + suf]),                       # spalla
            (av.head_local, (a_br + a_av).normalized(), ['braccio' + suf, 'avambraccio' + suf]),     # gomito
            (ma.head_local, (a_av + a_ma).normalized(), ['avambraccio' + suf, 'mano' + suf]),        # polso
        ]
        for J, a, gruppi in giunti:
            J = np.array(J); a = np.array(a)
            rel = co - J
            sa = rel @ a
            rho = np.linalg.norm(rel - sa[:, None] * a, axis=1)
            ok = (np.abs(sa) < 0.06 * k) & (rho < 0.075 * k) & (peso(gruppi) > 0.5)
            m = ok & (np.abs(sa) < migliore)
            out[m] = sa[m]
            migliore[m] = np.abs(sa[m])
    return out


def linea_clavicole(ob, arm, k):
    """Distanza di ogni vertice dalla linea delle clavicole sulla pelle (proiezione dell'osso in avanti/su)."""
    from mathutils.bvhtree import BVHTree
    me = ob.data
    co = coords(me)
    bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(p.vertices) for p in me.polygons])
    linea = []
    for suf in ('.L', '.R'):
        b = arm.data.bones['clavicola' + suf]
        h, t = np.array(b.head_local), np.array(b.tail_local)
        d = np.array([0.0, -0.75, 0.66]); d /= np.linalg.norm(d)
        for u in np.linspace(0.08, 0.98, 28):
            p = h + (t - h) * u
            hit = bvh.ray_cast(Vector(p), Vector(d), 0.3 * k)
            if hit[0] is not None:
                linea.append(np.array(hit[0]))
    if not linea:
        return np.full(len(co), 10.0, np.float32)
    from scipy.spatial import cKDTree
    L = np.array(linea)
    # densifica la polilinea (punti ogni mezzo centimetro)
    dens = []
    for a, b in zip(L[:-1], L[1:]):
        if np.linalg.norm(b - a) < 0.05 * k:
            for t in np.linspace(0, 1, 6, endpoint=False):
                dens.append(a + (b - a) * t)
    dens.append(L[-1])
    d, _ = cKDTree(np.array(dens)).query(co)
    return d.astype(np.float32)


def campo_unghie(ob, arm, k):
    """0..1: dove stanno le unghie (dorso dell'ultima falange di ogni dito)."""
    me = ob.data
    co = coords(me)
    nrm = np.empty(len(co) * 3); me.vertices.foreach_get('normal', nrm); nrm = nrm.reshape(-1, 3)
    out = np.zeros(len(co), np.float32)
    for suf in ('.L', '.R'):
        for dito in ('pollice', 'indice', 'medio', 'anulare', 'mignolo'):
            b = arm.data.bones[f'{dito}_3{suf}']
            # le dita si piegano attorno all'asse X dell'osso verso -Z: +Z e' il dorso (lato dell'unghia)
            dorso = np.array(b.matrix_local.col[2][:3])
            dorso /= np.linalg.norm(dorso) + 1e-9
            T, H = np.array(b.tail_local), np.array(b.head_local)
            a = (T - H) / (np.linalg.norm(T - H) + 1e-9)
            rel = co - T
            s = rel @ a
            rho = np.linalg.norm(rel - s[:, None] * a, axis=1)
            vicino = (rho < 0.02 * k) & (s > -0.03 * k) & (s < 0.008 * k)
            lungo = np.clip((s + 0.014 * k) / (0.004 * k), 0, 1) * np.clip((0.0025 * k - s) / (0.003 * k), 0, 1)
            dors = np.clip((nrm @ dorso - 0.3) / 0.3, 0, 1)
            val = np.where(vicino, lungo * dors, 0)
            out = np.maximum(out, val.astype(np.float32))
    return out


def maschera_viso(ob, k):
    occ = leggi_json('occhio_3d.json')
    C = np.array(occ['centro_rotazione']) * k
    co = coords(ob.data)
    d = np.linalg.norm(co - C, axis=1)
    f = np.clip(1 - (d - 0.16 * k) / (0.06 * k), 0, 1)
    return (f * (co[:, 1] < C[1] + 0.05 * k)).astype(np.float32)


# ---------------------------------------------------------------- shader di cottura

def _attr(nt, nome, x, y):
    n = nodo(nt, 'ShaderNodeAttribute', (x, y))
    n.attribute_type = 'GEOMETRY'
    n.attribute_name = nome
    return n.outputs['Fac']


def _math(nt, op, a, b=None, x=0, y=0, clamp=False):
    n = nodo(nt, 'ShaderNodeMath', (x, y))
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def _rumore(nt, vec, scala, x=0, y=0, dettaglio=4.0, ruvidita=0.55):
    n = nodo(nt, 'ShaderNodeTexNoise', (x, y))
    n.inputs['Scale'].default_value = scala
    n.inputs['Detail'].default_value = dettaglio
    n.inputs['Roughness'].default_value = ruvidita
    if vec is not None:
        nt.links.new(vec, n.inputs['Vector'])
    return n.outputs['Fac']


def _soglia(nt, v, a, b, x=0, y=0):
    n = nodo(nt, 'ShaderNodeMapRange', (x, y))
    n.interpolation_type = 'SMOOTHSTEP'
    n.inputs['From Min'].default_value = a
    n.inputs['From Max'].default_value = b
    nt.links.new(v, n.inputs['Value'])
    return n.outputs['Result']


def _mix(nt, fac, a, b, x=0, y=0):
    n = nodo(nt, 'ShaderNodeMix', (x, y))
    n.data_type = 'RGBA'
    n.blend_type = 'MIX'
    if isinstance(fac, (int, float)):
        n.inputs['Factor'].default_value = fac
    else:
        nt.links.new(fac, n.inputs['Factor'])
    for sock, v in ((n.inputs['A'], a), (n.inputs['B'], b)):
        if isinstance(v, tuple):
            sock.default_value = (*v, 1.0) if len(v) == 3 else v
        else:
            nt.links.new(v, sock)
    return n.outputs['Result']


def materiale_cottura(m, k, usura):
    """Copia del materiale con i motivi di dettaglio: ritorna (materiale, nodi utili)."""
    mc = m.copy()
    mc.name = m.name + '_cottura'
    nt = mc.node_tree
    nt.nodes['base'].image = immagine(SORGENTE_BASE)
    nt.nodes['normal'].image = immagine(SORGENTE_NORMAL, non_color=True)
    for n in list(nt.nodes):
        if n.name not in ('base', 'normal'):
            nt.nodes.remove(n)
    base = nt.nodes['base'].outputs['Color']
    nmap = nodo(nt, 'ShaderNodeNormalMap', (-300, -600))
    nt.links.new(nt.nodes['normal'].outputs['Color'], nmap.inputs['Color'])
    geo = nodo(nt, 'ShaderNodeNewGeometry', (-1800, 400))
    pos = geo.outputs['Position']
    altezza = None                      # rilievo (0 = liscio), per la normal map
    colore = base
    ruvido = RUVIDO_BASE.get(m.name, 0.15)
    ruv = _math(nt, 'ADD', ruvido, 0.0, -200, -900)
    # --- capelli a ciocche
    if m.name == 'M_capelli':
        c = _attr(nt, 'ciocca_c', -1800, 0)
        s = _attr(nt, 'ciocca_s', -1800, -150)
        d = _attr(nt, 'ciocca_d', -1800, -300)
        phi = _math(nt, 'ARCTAN2', s, c, -1600, -50)
        cmb = nodo(nt, 'ShaderNodeCombineXYZ', (-1450, -200))
        nt.links.new(_math(nt, 'MULTIPLY', phi, 1.6, -1550, -150), cmb.inputs['X'])
        nt.links.new(_math(nt, 'MULTIPLY', d, 3.0 / k, -1550, -300), cmb.inputs['Y'])
        n1 = _rumore(nt, cmb.outputs['Vector'], 2.5, -1300, -200)
        fine = _math(nt, 'SINE', _math(nt, 'ADD', _math(nt, 'MULTIPLY', phi, 230.0, -1300, 0),
                                        _math(nt, 'MULTIPLY', n1, 7.0, -1150, -150), -1100, 0), None, -950, 0)
        cio = _math(nt, 'SINE', _math(nt, 'ADD', _math(nt, 'MULTIPLY', phi, 64.0, -1300, 150),
                                       _math(nt, 'MULTIPLY', n1, 4.0, -1150, 150), -1100, 150), None, -950, 150)
        fine01 = _math(nt, 'MULTIPLY_ADD', fine, 0.5, -800, 0)
        nt.nodes[fine01.node.name].inputs[2].default_value = 0.5
        cio01 = _math(nt, 'MULTIPLY_ADD', cio, 0.5, -800, 150)
        nt.nodes[cio01.node.name].inputs[2].default_value = 0.5
        cio01 = _math(nt, 'POWER', cio01, 0.6, -650, 150)
        h = _math(nt, 'ADD', _math(nt, 'MULTIPLY', cio01, 0.62, -500, 150), _math(nt, 'MULTIPLY', fine01, 0.38, -500, 0),
                  -350, 80)
        cima = _soglia(nt, d, 0.05 * k, 0.14 * k, -500, -300)          # alla cima della testa le ciocche si perdono
        h = _math(nt, 'MULTIPLY', h, cima, -200, 80)
        altezza = h
        scuro = _math(nt, 'MULTIPLY_ADD', h, 0.24, -50, 200)            # solchi piu' scuri, creste un po' piu' chiare
        nt.nodes[scuro.node.name].inputs[2].default_value = 0.82
        cm = nodo(nt, 'ShaderNodeMix', (100, 300)); cm.data_type = 'RGBA'; cm.blend_type = 'MULTIPLY'
        cm.inputs['Factor'].default_value = 1.0
        nt.links.new(colore, cm.inputs['A'])
        cs = nodo(nt, 'ShaderNodeCombineColor', (-50, 350))
        for ch in ('Red', 'Green', 'Blue'):
            nt.links.new(scuro, cs.inputs[ch])
        nt.links.new(cs.outputs['Color'], cm.inputs['B'])
        colore = cm.outputs['Result']
        ruv = _math(nt, 'ADD', ruv, _math(nt, 'MULTIPLY', _math(nt, 'SUBTRACT', 1.0, h, -200, -1000), 0.14, -50, -1000),
                    100, -950)
    # --- giunture da bambola (solco sottile ad anello)
    if m.name == 'M_pelle':
        g = _attr(nt, 'giuntura', -1800, -500)
        q = _math(nt, 'DIVIDE', g, 0.0042, -1600, -500)
        solco = _math(nt, 'EXPONENT', _math(nt, 'MULTIPLY', _math(nt, 'MULTIPLY', q, q, -1450, -500), -1.0, -1300, -500),
                      None, -1150, -500)
        altezza = _math(nt, 'SUBTRACT', 0.0, solco, -1000, -500) if altezza is None else altezza
        colore = _mix(nt, _math(nt, 'MULTIPLY', solco, 0.45, -1000, -400), colore, (0.18, 0.14, 0.22), 300, 200)
        ruv = _math(nt, 'ADD', ruv, _math(nt, 'MULTIPLY', solco, 0.3, -800, -1100), 250, -950)
    # --- clavicole e spalle piu' definite (cresta lungo la clavicola, incavo sotto), unghie
    if m.name == 'M_pelle':
        dc = _attr(nt, 'clavicola', -1800, -1150)
        q1 = _math(nt, 'DIVIDE', dc, 0.011 * k, -1600, -1150)
        cresta = _math(nt, 'EXPONENT', _math(nt, 'MULTIPLY', _math(nt, 'MULTIPLY', q1, q1, -1450, -1150), -1.0,
                                             -1300, -1150), None, -1150, -1150)
        q2 = _math(nt, 'DIVIDE', _math(nt, 'SUBTRACT', dc, 0.026 * k, -1600, -1300), 0.01 * k, -1450, -1300)
        incavo = _math(nt, 'EXPONENT', _math(nt, 'MULTIPLY', _math(nt, 'MULTIPLY', q2, q2, -1300, -1300), -1.0,
                                             -1150, -1300), None, -1000, -1300)
        cl = _math(nt, 'SUBTRACT', _math(nt, 'MULTIPLY', cresta, 2.2, -900, -1150),
                   _math(nt, 'MULTIPLY', incavo, 1.2, -900, -1300), -750, -1200)
        altezza = cl if altezza is None else _math(nt, 'ADD', altezza, cl, -600, -1200)
        un = _soglia(nt, _attr(nt, 'unghia', -1800, -1450), 0.45, 0.6, -1600, -1450)
        orlo = _math(nt, 'MULTIPLY', un, _math(nt, 'SUBTRACT', 1.0, un, -1450, -1550), -1300, -1500)   # bordo dell'unghia
        altezza = _math(nt, 'ADD', altezza, _math(nt, 'SUBTRACT', _math(nt, 'MULTIPLY', un, 0.9, -1150, -1450),
                                                  _math(nt, 'MULTIPLY', orlo, 2.5, -1150, -1550), -1000, -1500),
                        -850, -1450)
        colore = _mix(nt, _math(nt, 'MULTIPLY', un, 0.55, -1000, -1650), colore, (0.86, 0.72, 0.84), 250, 0)
        ruv = _math(nt, 'SUBTRACT', ruv, _math(nt, 'MULTIPLY', un, 0.09, -850, -1650), 300, -1050)
    # --- capelli: il volume di Meshy fa da fondo alle ciocche, piu' scuro
    if m.name == 'M_capelli':
        cm2 = nodo(nt, 'ShaderNodeMix', (350, 450)); cm2.data_type = 'RGBA'; cm2.blend_type = 'MULTIPLY'
        cm2.inputs['Factor'].default_value = 1.0
        nt.links.new(colore, cm2.inputs['A'])
        cm2.inputs['B'].default_value = (0.66, 0.6, 0.7, 1.0)
        colore = cm2.outputs['Result']
    # --- usura leggera da statua (non sul viso): patina, sporco nelle pieghe, qualche graffio, rare scrostature.
    #     Il corpo resta vinile liscio da bambola-mascotte: niente pelle realistica.
    if usura > 0:
        viso = _attr(nt, 'viso', -1800, -700)
        quanto = _math(nt, 'MULTIPLY', _math(nt, 'SUBTRACT', 1.0, viso, -1600, -700),
                       usura * (0.5 if m.name == 'M_campana' else 1.0), -1450, -700)
        ao = _attr(nt, 'ao', -1800, -850)
        # patina: variazione larga e lenta del colore (un po' piu' spento) e della lucentezza
        pat = _rumore(nt, pos, 1.6 / k, -1400, 700, dettaglio=3)
        patina = _math(nt, 'MULTIPLY', _soglia(nt, pat, 0.45, 0.75, -1200, 700), quanto, -1000, 700)
        # sporco nelle pieghe (occlusione)
        pieghe = _math(nt, 'MULTIPLY', _soglia(nt, ao, 0.8, 0.45, -1400, 900), quanto, -1200, 900)
        sp_r = _rumore(nt, pos, 9.0 / k, -1400, 1050, dettaglio=6)
        sporco = _math(nt, 'MULTIPLY', pieghe, _soglia(nt, sp_r, 0.3, 0.7, -1200, 1050), -1000, 1000)
        # graffi: righe sottili in chiazze rade (onde deformate dal rumore, tagliate da un rumore largo)
        wv = nodo(nt, 'ShaderNodeTexWave', (-1400, 1250))
        wv.wave_type = 'BANDS'
        wv.bands_direction = 'DIAGONAL'
        wv.inputs['Scale'].default_value = 60.0 / k
        wv.inputs['Distortion'].default_value = 6.0
        wv.inputs['Detail'].default_value = 3.0
        nt.links.new(pos, wv.inputs['Vector'])
        linee = _soglia(nt, wv.outputs['Fac'], 0.985, 1.0, -1200, 1250)
        chiazze = _soglia(nt, _rumore(nt, pos, 3.0 / k, -1400, 1400, dettaglio=2), 0.62, 0.7, -1200, 1400)
        graffi = _math(nt, 'MULTIPLY', _math(nt, 'MULTIPLY', linee, chiazze, -1050, 1300), quanto, -900, 1300)
        # scrostature piccolissime sugli spigoli
        sc_r = _rumore(nt, pos, 18.0 / k, -1400, 1700, dettaglio=5)
        spigoli = _soglia(nt, geo.outputs['Pointiness'], 0.52, 0.58, -1400, 1850)
        scrost = _math(nt, 'MULTIPLY', _math(nt, 'MULTIPLY', _soglia(nt, sc_r, 0.76, 0.79, -1200, 1700), spigoli,
                                             -1050, 1750), quanto, -900, 1750)
        colore = _mix(nt, _math(nt, 'MULTIPLY', patina, 0.12, -800, 650), colore, (0.55, 0.53, 0.58), 500, 400)
        colore = _mix(nt, _math(nt, 'MULTIPLY', sporco, 0.38, -800, 950), colore, (0.24, 0.2, 0.23), 650, 450)
        colore = _mix(nt, _math(nt, 'MULTIPLY', graffi, 0.3, -750, 1300), colore, (0.9, 0.9, 0.95), 800, 500)
        colore = _mix(nt, _math(nt, 'MULTIPLY', scrost, 0.7, -750, 1750), colore, (0.5, 0.47, 0.58), 950, 550)
        ruv = _math(nt, 'ADD', ruv, _math(nt, 'MULTIPLY', patina, 0.06, -500, -1200), 400, -950)
        ruv = _math(nt, 'ADD', ruv, _math(nt, 'MULTIPLY', sporco, 0.25, -500, -1300), 550, -950)
        ruv = _math(nt, 'ADD', ruv, _math(nt, 'MULTIPLY', _math(nt, 'ADD', graffi, scrost, -650, -1400), 0.3,
                                          -500, -1400), 700, -950)
        ril = _math(nt, 'MULTIPLY', _math(nt, 'ADD', _math(nt, 'MULTIPLY', graffi, 0.5, -500, 1450), scrost,
                                          -350, 1500), -0.5, -200, 1500)
        altezza = ril if altezza is None else _math(nt, 'ADD', altezza, ril, -50, 600)
    ruv = _math(nt, 'MINIMUM', ruv, 0.95, 850, -950)
    # uscite: emissione (colore o ruvidita') e BSDF con la normale in rilievo
    em = nodo(nt, 'ShaderNodeEmission', (1100, 300))
    em.inputs['Strength'].default_value = 1.0
    bsdf = nodo(nt, 'ShaderNodeBsdfPrincipled', (1100, -300))
    if altezza is not None:
        bump = nodo(nt, 'ShaderNodeBump', (900, -600))
        bump.inputs['Distance'].default_value = 0.0016
        bump.inputs['Strength'].default_value = 1.0
        nt.links.new(altezza, bump.inputs['Height'])
        nt.links.new(nmap.outputs['Normal'], bump.inputs['Normal'])
        nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    else:
        nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    rgb_r = nodo(nt, 'ShaderNodeCombineColor', (1000, -900))
    rgb_r.inputs['Red'].default_value = 1.0
    nt.links.new(ruv, rgb_r.inputs['Green'])
    rgb_r.inputs['Blue'].default_value = 0.0
    out = nodo(nt, 'ShaderNodeOutputMaterial', (1400, 0))
    bers = nodo(nt, 'ShaderNodeTexImage', (1400, -400))
    bers.name = 'bersaglio'
    return mc, dict(colore=colore, ruvido=rgb_r.outputs['Color'], em=em, bsdf=bsdf, out=out, bers=bers)


def cuoci(ob, k):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = 4
    me = ob.data
    originali = list(me.materials)
    cotture = {}
    for i, m in enumerate(originali):
        if m and m.name in CORPO:
            mc, nodi = materiale_cottura(m, k, USURA)
        elif m:
            # slot senza facce (moncherini, occhio dipinto): serve comunque un'immagine attiva per la cottura
            mc = bpy.data.materials.new(m.name + '_cottura')
            mc.use_nodes = True
            nt = mc.node_tree
            nt.nodes.clear()
            em = nodo(nt, 'ShaderNodeEmission', (0, 200))
            em.inputs['Color'].default_value = (0, 0, 0, 1)
            bsdf = nodo(nt, 'ShaderNodeBsdfPrincipled', (0, -200))
            out = nodo(nt, 'ShaderNodeOutputMaterial', (300, 0))
            bers = nodo(nt, 'ShaderNodeTexImage', (300, -300))
            bers.name = 'bersaglio'
            nodi = dict(colore=em.inputs['Color'].links and None, em=em, bsdf=bsdf, out=out, bers=bers, vuoto=True)
        else:
            continue
        me.materials[i] = mc
        cotture[mc.name] = (mc, nodi)
    img = {}
    for nome, nc in (('colore', False), ('ruvido', True), ('normal', True)):
        im = bpy.data.images.new(f'medusa_{nome}_cotta', LATO, LATO, alpha=False)
        if nc:
            im.colorspace_settings.name = 'Non-Color'
        img[nome] = im
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    for nome in ('colore', 'ruvido', 'normal'):
        t = time.time()
        for mc, nd in cotture.values():
            nt = mc.node_tree
            for l in list(nd['out'].inputs['Surface'].links):
                nt.links.remove(l)
            if nome == 'normal':
                nt.links.new(nd['bsdf'].outputs['BSDF'], nd['out'].inputs['Surface'])
            else:
                if not nd.get('vuoto'):
                    for l in list(nd['em'].inputs['Color'].links):
                        nt.links.remove(l)
                    nt.links.new(nd[nome], nd['em'].inputs['Color'])
                nt.links.new(nd['em'].outputs['Emission'], nd['out'].inputs['Surface'])
            nd['bers'].image = img[nome]
            for x in nt.nodes:
                x.select = False
            nd['bers'].select = True
            nt.nodes.active = nd['bers']
        if nome == 'normal':
            bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', margin=16, target='IMAGE_TEXTURES')
        else:
            bpy.ops.object.bake(type='EMIT', margin=16, target='IMAGE_TEXTURES')
        log(f'cottura {nome}: {time.time() - t:.0f} s')
    for i, m in enumerate(originali):
        me.materials[i] = m
    for mc, _ in cotture.values():
        bpy.data.materials.remove(mc)
    return img


def salva_texture(img):
    """PNG in build/ (nomi diversi dalle sorgenti del passo 2b); ruvidita' (q90) e normal (q95) anche in JPG senza
    sottocampionamento del colore, in build/texture_nuove/ (in tex/ le mette installa_texture). Il JPG del colore lo
    scrive poi medusa_capelli.ricolora_atlante, dal PNG."""
    from PIL import Image
    uscite = {'ruvido': (TEX_RUVIDO, 90), 'normal': (TEX_NORMAL, 95)}
    for nome, im in img.items():
        png = os.path.join(BUILD, f'medusa_{nome}_cotta_4k.png')
        im.filepath_raw = png
        im.file_format = 'PNG'
        im.save()
        if nome in uscite:
            dst, q = uscite[nome]
            Image.open(png).convert('RGB').save(nuova(dst), quality=q, subsampling=0)


# ---------------------------------------------------------------- protezione delle texture approvate

def nuova(path):
    """Dove si scrive la versione appena fatta di una texture di tex/: build/texture_nuove/, con lo stesso nome."""
    os.makedirs(NUOVE, exist_ok=True)
    return os.path.join(NUOVE, os.path.basename(path))


def differenza(a, b):
    """None se le due immagini hanno gli stessi pixel, se no una riga che dice quanto cambiano."""
    import filecmp
    from PIL import Image
    if filecmp.cmp(a, b, shallow=False):
        return None
    x = np.asarray(Image.open(a).convert('RGB')).astype(np.int16)
    y = np.asarray(Image.open(b).convert('RGB')).astype(np.int16)
    if x.shape != y.shape:
        return f'misure diverse ({x.shape[1]} x {x.shape[0]} quella approvata, {y.shape[1]} x {y.shape[0]} la nuova)'
    d = np.abs(x - y).max(axis=2)
    if not d.any():
        return None
    return (f'cambia il {100 * (d > 0).mean():.2f}% dei pixel ({100 * (d > 8).mean():.2f}% di piu\' di 8/255), '
            f'differenza massima {d.max()}/255')


def installa_texture(texture):
    """Mette in tex/ le texture appena fatte (sono in build/texture_nuove/). Se una texture di tex/ c'e' gia' ed e'
    diversa dalla nuova (quelle di tex/ sono le approvate, in git), si ferma senza toccare niente; con
    MEDUSA_RISCRIVI_TEXTURE=1 la sostituisce, con MEDUSA_RISCRIVI_TEXTURE=0 tiene quella approvata e va avanti."""
    nuove = {dst: nuova(dst) for dst in texture}
    cambiate = {}
    for dst, src in nuove.items():
        if os.path.exists(dst):
            d = differenza(dst, src)
            if d is not None:
                cambiate[dst] = d
    if cambiate and RISCRIVI not in ('0', '1'):
        raise SystemExit('\n'.join([
            '',
            '[medusa] PASSO 8 FERMATO: le texture nuove sono diverse da quelle approvate.',
            *[f'  {os.path.relpath(t, REPO)}: {d}' for t, d in cambiate.items()],
            'Le texture approvate (in git) non sono state toccate; le nuove sono in '
            f'{os.path.relpath(NUOVE, REPO)}/, per confrontarle.',
            'Una cottura rifatta non viene identica: quella rifatta il 16 ottobre cambia alcune isole UV dei capelli.',
            '  - per tenere quelle approvate e finire il passo: MEDUSA_RISCRIVI_TEXTURE=0 davanti al comando;',
            '  - per sostituirle con le nuove (solo se l\'utente le ha approvate): MEDUSA_RISCRIVI_TEXTURE=1.',
            'Con medusa_tutto.py si riparte da questo passo con --da medusa_08_dettagli.py.',
        ]))
    for dst, src in nuove.items():
        r = os.path.relpath(dst, REPO)
        if dst in cambiate and RISCRIVI == '0':
            log(f'{r}: tengo quella approvata (MEDUSA_RISCRIVI_TEXTURE=0); la nuova, rimasta in '
                f'{os.path.relpath(src, REPO)}, {cambiate[dst]}')
        elif dst in cambiate or not os.path.exists(dst):
            os.replace(src, dst)
            log(f'{r}: scritta, {os.path.getsize(dst) / 1e6:.1f} MB' +
                (f' (MEDUSA_RISCRIVI_TEXTURE=1, al posto di quella approvata: {cambiate[dst]})'
                 if dst in cambiate else ''))
        else:
            os.remove(src)
            log(f'{r}: uguale a quella che c\'era, non riscritta')
    if os.path.isdir(NUOVE) and not os.listdir(NUOVE):
        os.rmdir(NUOVE)


def aggiorna_materiali():
    """I materiali del corpo usano le nuove texture (colore, normal, ruvidita'/metallo)."""
    tc = immagine(TEX_COLORE)
    tn = immagine(TEX_NORMAL, non_color=True)
    tr = immagine(TEX_RUVIDO, non_color=True)
    for n in CORPO:
        m = bpy.data.materials.get(n)
        if not m:
            continue
        nt = m.node_tree
        nt.nodes['base'].image = tc
        nt.nodes['normal'].image = tn
        b = nt.nodes['BSDF']
        if n == 'M_campana':
            continue                    # la campana usa trasparenza ed emissione proprie
        mr = nt.nodes.get('mr') or nodo(nt, 'ShaderNodeTexImage', (-600, 0))
        mr.name = 'mr'
        mr.image = tr
        sep = nt.nodes.get('mr_sep') or nodo(nt, 'ShaderNodeSeparateColor', (-250, 0))
        sep.name = 'mr_sep'
        nt.links.new(mr.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs['Green'], b.inputs['Roughness'])
        nt.links.new(sep.outputs['Blue'], b.inputs['Metallic'])
        if n == 'M_capelli':
            b.inputs['Coat Weight'].default_value = 0.35         # meno "di plastica"
            b.inputs['Coat Roughness'].default_value = 0.12


def main():
    t0 = time.time()
    finale = os.environ.get('MEDUSA_FINALE', os.path.join(BUILD, 'medusa_finale.blend'))
    apri(finale)
    if '--solo-materiali' in sys.argv:
        # le texture finali ci sono gia' (la cottura dipende solo dalla posa statua): dopo un passo 7 che ha
        # cambiato solo le animazioni basta ricollegarle ai materiali
        for t in (TEX_COLORE, TEX_NORMAL, TEX_RUVIDO, COTTA_COLORE):
            if not os.path.exists(t):
                raise SystemExit(f'manca {t}: serve la cottura completa')
        CAPELLI.ricolora_atlante(COTTA_COLORE, nuova(TEX_COLORE))
        installa_texture([TEX_COLORE])
        aggiorna_materiali()
        salva(finale)
        log(f'materiali aggiornati senza cottura in {time.time() - t0:.0f} s')
        return
    arm = bpy.data.objects['Medusa_Scheletro']
    ob = bpy.data.objects['Medusa']
    k = float(arm.get('scala', 1.0))
    # si cuoce nella posa di riposo (la statua): le tracce delle animazioni restano mute durante la cottura
    mute = []
    for i in list(bpy.data.objects) + list(bpy.data.shape_keys):
        if i.animation_data:
            for tr in i.animation_data.nla_tracks:
                mute.append((tr, tr.mute))
                tr.mute = True
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix()
    for kb in (ob.data.shape_keys.key_blocks if ob.data.shape_keys else []):
        kb.value = 0.0
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    me = ob.data
    t = time.time()
    _attributo(me, 'ao', occlusione(ob, dist=0.35 * k))
    log(f'occlusione per vertice: {time.time() - t:.0f} s')
    c, s, d = coordinate_ciocche(ob, arm)
    _attributo(me, 'ciocca_c', c)
    _attributo(me, 'ciocca_s', s)
    _attributo(me, 'ciocca_d', d)
    g = distanza_giunture(ob, arm, k)
    _attributo(me, 'giuntura', g)
    log(f'giunture: {int((np.abs(g) < 0.01 * k).sum())} vertici vicino ai solchi')
    _attributo(me, 'viso', maschera_viso(ob, k))
    _attributo(me, 'clavicola', linea_clavicole(ob, arm, k))
    _attributo(me, 'unghia', campo_unghie(ob, arm, k))
    img = cuoci(ob, k)
    salva_texture(img)
    CAPELLI.ricolora_atlante(COTTA_COLORE, nuova(TEX_COLORE))
    installa_texture([TEX_COLORE, TEX_NORMAL, TEX_RUVIDO])
    aggiorna_materiali()
    for tr, m in mute:
        tr.mute = m
    for a in ('ao', 'ciocca_c', 'ciocca_s', 'ciocca_d', 'giuntura', 'viso', 'clavicola', 'unghia'):
        if a in me.attributes:
            me.attributes.remove(me.attributes[a])
    for im in list(bpy.data.images):
        if im.users == 0:
            bpy.data.images.remove(im)
    salva(os.path.join(BUILD, 'medusa_finale.blend'))
    log(f'fatto in {time.time() - t0:.0f} s')


if __name__ == '__main__':
    main()
