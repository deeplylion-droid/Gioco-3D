"""Palpebre della medusa per l'easter egg dell'occhio che si chiude (questionario del 15 ottobre, voce D2: "se le
spruzzi l'acqua in faccia l'occhio si chiude per un po'"). Sono una PROPOSTA: restano fuori dal modello finche'
l'utente non sceglie. Due varianti:
  'due' (A): due palpebre di pelle, una scende dall'alto e una sale dal basso, e si incontrano a meta';
  'una' (B): una palpebra sola che scende dall'alto e copre tutto l'occhio, come negli occhi delle bambole.
Si accendono dal passo 7 con MEDUSA_PALPEBRE=due, =una oppure =due,una (per le proposte: un oggetto per variante,
Medusa_Palpebre_due e Medusa_Palpebre_una; con una variante sola l'oggetto si chiama Medusa_Palpebre).

Come sono fatte (pensate per Godot, come la fauce):
  - pelle di vinile pervinca come il viso (colore preso dall'atlante intorno all'orbita, stessa lacca), con un bordo
    arrotondato e un po' piu' spesso sul davanti, come il margine di una palpebra;
  - a occhio aperto non si vedono: la geometria e' "collassata" (area zero) dentro il bulbo, sotto il labbro
    dell'orbita e sotto la frangia;
  - chiudendosi scivolano sul bulbo a una distanza fissa dalla cornea (che sporge 3 mm): ogni colonna va dal bordo
    dell'orbita, dove la palpebra si infila sotto il labbro, fino al bordo della palpebra, che e' un arco di cerchio
    massimo (rotazione attorno all'asse orizzontale dell'occhio): da davanti e' un arco, come una palpebra vera;
  - le shape key 'palpebre_1' ... 'palpebre_K' sono le tappe della chiusura, da usare IN SEQUENZA: tra la tappa s e
    la s+1 si passa con pesi (1 - x, x) (imposta_chiusura), cosi' i vertici non tagliano dentro la cornea: le tappe
    sono vicine e in linea retta tra due tappe la palpebra resta fuori dalla cornea (controlla_cornea lo misura;
    solo vicino al bordo, dove la palpebra esce da sotto il labbro, passa sotto la superficie del bulbo).
    'palpebre_K' = occhio chiuso del tutto; la tappa K/2 e' meta' chiusura (nella B il bordo a meta' occhio).
  - pesi: tutto sull'osso 'testa' (le palpebre non seguono la rotazione dell'occhio: quando si chiude, l'osso
    'occhio' va riportato a 0, altrimenti la cornea girata puo' toccare la palpebra).
Uso: dal passo 7 (crea_palpebre), dopo palpebre() che alza il labbro dell'orbita.
"""
import math
import os

import numpy as np
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from medusa_comune import (log, collega, coords, leggi_json, carica_immagine_np, campiona_uv, loop_uv, loop_vert,
                           TEX)

VARIANTI = [v for v in os.environ.get('MEDUSA_PALPEBRE', '').replace(' ', '').split(',') if v]
GAP = 0.0006             # aria tra la cornea (o il bulbo) e la palpebra (unita' del modello; x1,67 sulla statua)
SPESSORE = 0.0016        # spessore della palpebra
R_BORDO = 0.0026         # raggio del bordo arrotondato (sporge sopra la palpebra, come il margine di una palpebra)
MARGINE = 0.3            # gradi: la palpebra resta dentro il bordo dell'orbita di tanto, poi si infila sotto
R_PROVA = 0.0065         # cerca il bordo dell'orbita (pelle, labbro, capelli) entro questa distanza dal bulbo
FINESTRA = 10            # gradi di azimut: le rientranze del bordo piu' strette del doppio si ignorano
N_COL = 64               # colonne, da un lato all'altro dell'occhio
N_SUP = 18               # righe sulla superficie
N_BORDO = 8              # righe sul bordo arrotondato
TAPPE = {'due': 6, 'una': 10}


def _smooth(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


class Occhio:
    """Geometria dell'occhio (coordinate del modello): centro, assi, bulbo, cornea, bordo dell'orbita."""

    def __init__(self, corpo):
        occ = leggi_json('occhio_3d.json')
        self.C = np.array(occ['centro_rotazione'])
        f = np.array(occ['asse_riposo'], float); f /= np.linalg.norm(f)
        r = np.array([1.0, 0, 0]) - f * f[0]; r /= np.linalg.norm(r)
        u = np.cross(f, r); u /= np.linalg.norm(u)
        if u[2] < 0:
            u = -u
        self.f, self.r, self.u = f, r, u
        self.Rb = occ['raggio_bulbo']
        cc = np.array(occ['cornea']['centro'])
        self.dc = float((cc - self.C) @ f)
        self.Rc = occ['cornea']['raggio']
        self.theta_orbita = occ['angolo_orbita_gradi']
        # cornea: altezza sopra il bulbo in funzione dell'angolo dall'asse, ammorbidita (niente gradino nella palpebra)
        th = np.radians(np.arange(0, 90.01, 0.05))
        t = self.dc * np.cos(th) + np.sqrt(np.maximum(self.Rc ** 2 - (self.dc * np.sin(th)) ** 2, 0))
        h = np.maximum(t - self.Rb, 0)
        k = np.exp(-0.5 * (np.arange(-60, 61) * 0.05 / 1.2) ** 2); k /= k.sum()
        hs = np.convolve(np.pad(h, 60, mode='edge'), k, mode='valid')
        self._th_tab, self._h_tab = np.degrees(th), np.maximum(h, hs)
        self._h_vera = h
        self.bordo = self._bordo_orbita(corpo)

    def altezza_cornea(self, theta_gradi, vera=False):
        return np.interp(theta_gradi, self._th_tab, self._h_vera if vera else self._h_tab)

    def r_fuori(self, theta_gradi):
        """Raggio della superficie esterna della palpebra (dal centro dell'occhio)."""
        return self.Rb + self.altezza_cornea(theta_gradi) + GAP + SPESSORE

    def direzione(self, a, b):
        """Direzione (dal centro) per angolo laterale a e rotazione b attorno all'asse orizzontale (gradi)."""
        a, b = np.radians(a), np.radians(b)
        return (np.cos(a) * np.cos(b))[..., None] * self.f + (np.cos(a) * np.sin(b))[..., None] * self.u \
            + np.sin(a)[..., None] * self.r

    @staticmethod
    def theta(a, b):
        return np.degrees(np.arccos(np.clip(np.cos(np.radians(a)) * np.cos(np.radians(b)), -1, 1)))

    @staticmethod
    def psi(a, b):
        return np.degrees(np.arctan2(np.cos(np.radians(a)) * np.sin(np.radians(b)), np.sin(np.radians(a)))) % 360

    def _bordo_orbita(self, corpo):
        """Per ogni azimut (gradi, 0 = verso +X, 90 = in alto) l'angolo dall'asse fin dove la palpebra puo' stare:
        raggi dal centro che non toccano pelle, labbro o capelli entro R_PROVA dal bulbo, meno MARGINE."""
        verts, tris = [], []
        for nome in ('Medusa', 'Medusa_Ciocche'):
            o = bpy.data.objects.get(nome)
            if o is None:
                continue
            me = o.data
            co = coords(me)
            M = np.array(o.matrix_world)
            co = co @ M[:3, :3].T + M[:3, 3]
            me.calc_loop_triangles()
            lt = np.empty(len(me.loop_triangles) * 3, dtype=np.int64)
            me.loop_triangles.foreach_get('vertices', lt)
            lt = lt.reshape(-1, 3)
            if nome == 'Medusa':
                tp = np.empty(len(me.loop_triangles), dtype=np.int64)
                me.loop_triangles.foreach_get('polygon_index', tp)
                mi = np.empty(len(me.polygons), dtype=np.int32)
                me.polygons.foreach_get('material_index', mi)
                mats = [m.name if m else '' for m in me.materials]
                ok = np.isin(mi[tp], [mats.index(n) for n in ('M_pelle', 'M_capelli', 'M_orbita') if n in mats])
                lt = lt[ok]
            # solo i triangoli vicini all'occhio
            d = np.linalg.norm(co[lt].mean(1) - self.C, axis=1)
            lt = lt[d < self.Rb + 0.05]
            base = sum(len(v) for v in verts)
            verts.append(co)
            tris.append(lt + base)
        V = np.concatenate(verts)
        T = np.concatenate(tris)
        bvh = BVHTree.FromPolygons([tuple(v) for v in V], [tuple(t) for t in T])
        C = Vector(self.C)
        psi = np.arange(0, 360, 1.0)
        aperto = np.zeros(len(psi))
        for i, p in enumerate(psi):
            pr = math.radians(p)
            lim = 60.0
            for th in np.arange(20.0, 60.0, 0.1):
                t = math.radians(th)
                d = Vector(tuple(math.cos(t) * self.f + math.sin(t) * (math.cos(pr) * self.r + math.sin(pr) * self.u)))
                if bvh.ray_cast(C, d, self.Rb + R_PROVA)[0] is not None:
                    lim = th - 0.1
                    break
            aperto[i] = lim
        # sopra, sotto la frangia, il bulbo continua sotto i capelli: la palpebra si ferma al cerchio dell'orbita
        aperto = np.minimum(aperto, self.theta_orbita + 0.5)
        # le punte delle ciocche della frangia scendono a toccare il bulbo (strette, qualche grado): la palpebra non le
        # segue, ci passa sotto (chiusura morfologica: via le rientranze strette meno di 2 x FINESTRA gradi)
        F = FINESTRA
        ext = np.r_[aperto[-F:], aperto, aperto[:F]]
        mx = np.array([ext[i:i + 2 * F + 1].max() for i in range(len(aperto))])
        ext = np.r_[mx[-F:], mx, mx[:F]]
        chiuso = np.array([ext[i:i + 2 * F + 1].min() for i in range(len(aperto))])
        # un filo ammorbidito, senza mai uscire dal bordo
        ext = np.r_[chiuso[-4:], chiuso, chiuso[:4]]
        liscio = np.convolve(ext, np.ones(9) / 9, mode='same')[4:-4]
        bordo = np.minimum(chiuso, liscio) - MARGINE
        log(f'palpebre: bordo dell\'orbita tra {bordo.min():.1f} e {bordo.max():.1f} gradi dall\'asse; sotto la '
            f'frangia le punte delle ciocche scendono fino a {aperto[45:135].min():.1f} gradi (la palpebra ci passa sotto)')
        return bordo

    def theta_bordo(self, psi_gradi):
        return np.interp(np.asarray(psi_gradi) % 360, np.arange(0, 361, 1.0), np.r_[self.bordo, self.bordo[0]])

    def beta_bordo(self, a, sopra=True):
        """Rotazione b (gradi) a cui la colonna a incontra per la prima volta il bordo dell'orbita (theta_bordo), sopra
        (b > 0) o sotto (b < 0). None se la colonna e' fuori dall'apertura."""
        segno = 1.0 if sopra else -1.0
        b = np.arange(0.0, 89.0, 0.05)
        dentro = self.theta(a, segno * b) < self.theta_bordo(self.psi(a, segno * b))
        if not dentro[0]:
            return None
        fuori = np.nonzero(~dentro)[0]
        return segno * float(b[fuori[0] - 1] if len(fuori) else b[-1])


def _profilo_colonna(occ, a, g_att, g_opp, g_e, sigma):
    """Righe di una colonna di palpebra nello spazio (g, raggio), g = sigma * b (g cresce verso il lato a cui la
    palpebra e' attaccata). g_att: bordo dell'orbita dal lato dell'attacco; g_opp: bordo dal lato opposto; g_e: bordo
    della palpebra (la tappa). Ritorna una lista di (g, raggio) di lunghezza 3 + N_SUP + N_BORDO + 2."""
    Rb = occ.Rb
    rb_ang = math.degrees(R_BORDO / Rb)

    def rf(g):
        return float(occ.r_fuori(occ.theta(a, sigma * g)))

    # dentro il bulbo, oltre il bordo dell'orbita: qui sta la palpebra ripiegata (aperta del tutto)
    nascosto = (g_att + 0.6, Rb - 0.0012)
    piega = [nascosto, (g_att + 0.15, Rb + 0.0002), (g_att - 0.2, rf(g_att - 0.2) - 0.0004)]
    g_low = max(g_e, g_opp)
    H = g_att - g_low
    a_ap = float(_smooth(0.2, 1.6, H))                       # colonna aperta (0 = tutta nascosta nella piega)
    b_ap = float(_smooth(0.0, 1.5, g_e - g_opp))             # bordo libero (0 = infilato sotto il bordo opposto)
    g_top = g_att - 0.45
    g_c = g_low + rb_ang                                     # centro del bordo arrotondato
    r_in = rf(g_c) - SPESSORE
    rc = r_in + R_BORDO
    sup = []
    for i in range(N_SUP):
        g = g_top + (g_c - g_top) * i / (N_SUP - 1)
        rr = rf(g)
        # vicino al bordo la superficie sale dolcemente fino alla cima del margine arrotondato, che sporge un poco
        w = float(_smooth(g_c + 4 * rb_ang, g_c, g)) * b_ap
        sup.append((g, rr + (rc + R_BORDO - rr) * w))
    # margine arrotondato: mezzo giro dalla cima (lato esterno) al sotto (lato interno), passando davanti
    bordo = []
    for i in range(1, N_BORDO + 1):
        phi = math.pi / 2 + math.pi * i / N_BORDO              # da 90 gradi (cima, gia' nella superficie) a 270
        bordo.append((g_c + rb_ang * math.cos(phi), rc + R_BORDO * math.sin(phi)))
    interno = [(g_c + 1.5, r_in), (g_c + 3.0, r_in + 0.0002)]
    righe = sup + bordo + interno
    # bordo infilato sotto il labbro opposto (palpebra B chiusa del tutto)
    if b_ap < 1.0:
        n = len(bordo) + len(interno)
        fine = []
        for i in range(n):
            t = i / (n - 1)
            fine.append((g_opp - 0.15 - 0.45 * t, Rb + 0.0002 - 0.0014 * t))
        coda = righe[-n:]
        righe = righe[:-n] + [(c[0] * b_ap + q[0] * (1 - b_ap), c[1] * b_ap + q[1] * (1 - b_ap))
                              for c, q in zip(coda, fine)]
    righe = piega + righe
    if a_ap < 1.0:
        righe = [(nascosto[0] + (g - nascosto[0]) * a_ap, nascosto[1] + (r - nascosto[1]) * a_ap) for g, r in righe]
    return righe


def _palpebra(occ, sigma, tappe_e):
    """Vertici (per tappa) e facce di una palpebra: sigma = +1 attaccata sopra, -1 sotto. tappe_e: bordo della
    palpebra (g) per ogni tappa, dalla 0 (aperta) all'ultima."""
    a_max = max(occ.theta_bordo(0.0), occ.theta_bordo(180.0)) + 0.5
    cols = np.linspace(-a_max, a_max, N_COL)
    attacco, opposto = [], []
    for a in cols:
        bs = occ.beta_bordo(a, sopra=True)
        bi = occ.beta_bordo(a, sopra=False)
        if bs is None:
            bs = bi = 0.0
        g_att, g_opp = (bs, bi) if sigma > 0 else (-bi, -bs)
        attacco.append(g_att)
        opposto.append(g_opp)
    forme = []
    for g_e in tappe_e:
        pts = []
        for a, g_att, g_opp in zip(cols, attacco, opposto):
            for g, rr in _profilo_colonna(occ, a, g_att, g_opp, g_e, sigma):
                pts.append(occ.C + rr * occ.direzione(np.array(a), np.array(sigma * g)))
        forme.append(np.array(pts))
    n_r = len(forme[0]) // N_COL
    facce = []
    for i in range(N_COL - 1):
        for j in range(n_r - 1):
            p, q = i * n_r + j, (i + 1) * n_r + j
            facce.append((p, p + 1, q + 1, q))
    return forme, facce, n_r, max(attacco), min(opposto)


def tappe_variante(variante, g_su, g_giu_su, g_giu, n):
    """Bordo della palpebra (g) per ogni tappa 0..n. 'due': le due palpebre arrivano a meta'; 'una': la palpebra
    sopra arriva a meta' alla tappa n/2 e poi oltre il bordo di sotto."""
    if variante == 'due':
        fine = 0.03
        return ([g_su + (fine - g_su) * s / n for s in range(n + 1)],
                [g_giu_su + (fine - g_giu_su) * s / n for s in range(n + 1)])
    m = n // 2
    su = [g_su * (1 - s / m) for s in range(m + 1)] + [(g_giu - 3.0) * s / (n - m) for s in range(1, n - m + 1)]
    return su, None


def colore_pelle(corpo, occ):
    """Colore della pelle (lineare) intorno all'orbita, dall'atlante finale."""
    me = corpo.data
    path = os.path.join(TEX, 'medusa_colore_4k.jpg')
    img = carica_immagine_np(path)[..., :3]
    co = coords(me)
    d = co - occ.C
    rr = np.linalg.norm(d, axis=1)
    th = np.degrees(np.arccos(np.clip((d @ occ.f) / np.maximum(rr, 1e-9), -1, 1)))
    mats = [m.name if m else '' for m in me.materials]
    mi = np.empty(len(me.polygons), dtype=np.int32)
    me.polygons.foreach_get('material_index', mi)
    sel = np.zeros(len(co), bool)
    for p in me.polygons:
        if mats[p.material_index] == 'M_pelle':
            sel[list(p.vertices)] = True
    sel &= (th > occ.theta_orbita + 2) & (th < occ.theta_orbita + 10) & (rr < occ.Rb + 0.02)
    uv = loop_uv(me)
    lv = loop_vert(me)
    q = uv[sel[lv]]
    c = np.median(campiona_uv(img, q), axis=0) if len(q) else np.array([0.75, 0.75, 0.89])
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def materiale_palpebre():
    m = bpy.data.materials.get('M_palpebre')
    if m:
        return m
    m = bpy.data.materials.new('M_palpebre')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']; b.name = 'BSDF'
    va = nt.nodes.new('ShaderNodeVertexColor'); va.layer_name = 'Col'
    nt.links.new(va.outputs['Color'], b.inputs['Base Color'])
    # stessa lacca del vinile del viso (medusa_07_finale.vinile_laccato)
    b.inputs['Roughness'].default_value = 0.12
    b.inputs['Coat Weight'].default_value = 1.0
    b.inputs['Coat Roughness'].default_value = 0.04
    b.inputs['Specular IOR Level'].default_value = 0.5
    b.inputs['Subsurface Weight'].default_value = 0.04
    b.inputs['Subsurface Radius'].default_value = (0.9, 0.6, 0.5)
    b.inputs['Subsurface Scale'].default_value = 0.02
    return m


def crea_palpebre(arm, corpo, varianti=None):
    varianti = VARIANTI if varianti is None else varianti
    if not varianti:
        return []
    occ = Occhio(corpo)
    colore = colore_pelle(corpo, occ)
    log(f'palpebre: colore della pelle intorno all\'orbita {np.round(colore, 3)} (lineare)')
    mat = materiale_palpebre()
    oggetti = []
    for variante in varianti:
        n = TAPPE[variante]
        # bordo dell'orbita nelle coordinate g delle due palpebre (sopra: g = b; sotto: g = -b)
        _, _, _, g_su, g_giu = _palpebra(occ, 1, [90.0])
        tappe_su, tappe_giu = tappe_variante(variante, g_su + 0.5, -g_giu + 0.5, g_giu, n)
        lati = [(1, tappe_su)] + ([(-1, tappe_giu)] if tappe_giu else [])
        forme_tot, facce_tot, off = None, [], 0
        for sigma, tappe in lati:
            forme, facce, n_r, _, _ = _palpebra(occ, sigma, tappe)
            if sigma < 0:
                facce = [tuple(reversed(f)) for f in facce]
            facce_tot += [tuple(x + off for x in f) for f in facce]
            forme_tot = forme if forme_tot is None else [np.vstack([x, y]) for x, y in zip(forme_tot, forme)]
            off += len(forme[0])
        nome = 'Medusa_Palpebre' if len(varianti) == 1 else f'Medusa_Palpebre_{variante}'
        me = bpy.data.meshes.new(nome)
        me.from_pydata([tuple(v) for v in forme_tot[0]], [], facce_tot)
        # facce verso fuori (controllo sull'occhio chiuso: la normale deve allontanarsi dal centro dell'occhio)
        chiuso = forme_tot[-1]
        n_fuori = 0.0
        for fc in me.polygons:
            vs = chiuso[list(fc.vertices)]
            nn = np.cross(vs[2] - vs[0], vs[3] - vs[1])
            n_fuori += float(nn @ (vs.mean(0) - occ.C) / max(np.linalg.norm(vs.mean(0) - occ.C), 1e-9))
        if n_fuori < 0:
            bm = bmesh.new(); bm.from_mesh(me)
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
            bm.to_mesh(me); bm.free()
        uvl = me.uv_layers.new(name='UVMap')
        lv = loop_vert(me)
        n_lato = len(forme_tot[0]) // len(lati)                 # vertici di una palpebra
        loc = lv % n_lato
        uv = np.stack([(loc // n_r) / (N_COL - 1), (loc % n_r) / (n_r - 1)], 1)
        uvl.data.foreach_set('uv', uv.ravel())
        ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
        col = np.tile(np.r_[colore, 1.0], (len(me.vertices), 1)).astype(np.float32)
        ca.data.foreach_set('color', col.ravel())
        me.color_attributes.active_color = ca
        me.shade_smooth()
        me.materials.append(mat)
        ob = bpy.data.objects.new(nome, me)
        collega(ob)
        ob.shape_key_add(name='Basis', from_mix=False)
        for s in range(1, n + 1):
            sk = ob.shape_key_add(name=f'palpebre_{s}', from_mix=False)
            sk.data.foreach_set('co', forme_tot[s].ravel())
            sk.value = 0.0
        vg = ob.vertex_groups.new(name='testa')
        vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
        ob.parent = arm
        mod = ob.modifiers.new('Scheletro', 'ARMATURE'); mod.object = arm
        ob['tappe'] = n
        ob['variante'] = variante
        controlla_cornea(occ, forme_tot, nome, n_r=n_r)
        log(f'palpebre {variante}: {nome}, {len(me.vertices)} vertici, {len(me.polygons)} facce, {n} tappe')
        oggetti.append(ob)
    return oggetti


def controlla_cornea(occ, forme, nome, passi=10, n_r=None):
    """Distanza minima tra la palpebra e la cornea vera (o il bulbo) lungo tutta la chiusura, tappa per tappa in linea
    retta, dentro l'apertura dell'orbita (lontano almeno 1,2 gradi dal bordo, dove la palpebra si infila sotto). Solo
    le righe che si vedono da fuori: la superficie e la meta' davanti del margine (non la piega e il lato interno)."""
    peggio, dove = 1.0, None
    vis = np.zeros(len(forme[0]), bool)
    righe = np.arange(len(forme[0])) % n_r
    vis[(righe >= 3) & (righe < 3 + N_SUP + N_BORDO // 2)] = True
    for s in range(len(forme) - 1):
        for t in np.linspace(0, 1, passi + 1):
            p = forme[s] * (1 - t) + forme[s + 1] * t
            d = p - occ.C
            rr = np.linalg.norm(d, axis=1)
            th = np.degrees(np.arccos(np.clip((d @ occ.f) / np.maximum(rr, 1e-12), -1, 1)))
            ps = np.degrees(np.arctan2(d @ occ.u, d @ occ.r)) % 360
            dentro = (th < occ.theta_bordo(ps) - 1.2) & vis
            if dentro.any():
                aria = np.full(len(p), 1.0)
                aria[dentro] = rr[dentro] - (occ.Rb + occ.altezza_cornea(th[dentro], vera=True))
                i = int(np.argmin(aria))
                if aria[i] < peggio:
                    peggio = float(aria[i])
                    dove = (s, round(float(t), 2), i, round(float(th[i]), 1), round(float(ps[i]), 1))
    log(f'palpebre {nome}: distanza minima dalla cornea durante la chiusura {peggio * 1000:.2f} mm (modello)'
        + (f', tappa {dove[0]}+{dove[1]}, vertice {dove[2]} (riga {dove[2] % n_r if n_r else "?"}), theta {dove[3]}, '
           f'psi {dove[4]}' if dove and peggio < 0.0002 else ''))
    return peggio


def imposta_chiusura(ob, c):
    """Mette le shape key della palpebra alla chiusura c (0 = aperta, 1 = chiusa), tappe in sequenza."""
    n = int(ob.get('tappe', len(ob.data.shape_keys.key_blocks) - 1))
    kb = ob.data.shape_keys.key_blocks
    for s in range(1, n + 1):
        kb[f'palpebre_{s}'].value = 0.0
    x = min(max(c, 0.0), 1.0) * n
    s = int(math.floor(x))
    fr = x - s
    if s >= n:
        kb[f'palpebre_{n}'].value = 1.0
        return
    if s >= 1:
        kb[f'palpebre_{s}'].value = 1.0 - fr
    kb[f'palpebre_{s + 1}'].value = fr
