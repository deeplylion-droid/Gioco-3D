"""Sala della torre, versione A (seconda passata del 17 ottobre): la struttura mastodontica.

Riscontro del coordinatore sulla prima A: troppo vuota e buia, pochi tubi sparsi, foresta di pali sottili e cavi.
Qui la sala è piena: quattro torri di traliccio sulle diagonali, con una piattaforma ogni 3 m dal fondo alla cima,
due scale di servizio, e tra le torri decine di scivoli colorati (canali aperti e tubi chiusi, anche a strisce) su
tutti i livelli. Ogni scivolo è retto da una travatura che va da una torre all'altra, con le mensole quando
passa vicino a una torre o a un muro: niente pali sottili né cavi.

La discesa (quella che si fa) gira in senso orario da una torre all'altra, sempre più in basso:
  NO 0 (dal portone) -> NE -3 (con un salto a metà) -> SE -6 (vasca intermedia) -> SO -9 (spezzato: salto col
  getto) -> NO -12 (la Polaroid 10) -> NE -15 (con un salto) -> spirale attorno al pozzo fino alla vasca est.
Gli altri scivoli si scelgono da soli tra centinaia di candidati (a quarti di giro, a mezzo giro, a spirale, nelle
vasche del fondo, dentro i muri), tenendo solo quelli che non toccano niente: sopra la discesa restano sempre
2,4 m liberi.

Uso: tramite torre_proposte.py (versione "A"); la prima passata è la versione "A0".
"""
import json, math, os, random, sys
QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, QUI)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import ambiente_kit as K  # noqa: E402
import ambiente_sala as S  # noqa: E402
import torre_proposte as P  # noqa: E402
from torre_proposte import polare, elica, XI0, XI1, YI0, YI1, H, FONDO, LARGO, PROF, SPONDA, R_GROVIGLIO  # noqa: E402

C = (31.0, 15.0)
TORRI = {'NO': 135.0, 'NE': 45.0, 'SE': 315.0, 'SO': 225.0}
ORDINE = ['NO', 'NE', 'SE', 'SO']          # in senso orario: l'angolo scende
R_TORRE = 8.0                              # distanza delle torri dal centro (sulle diagonali)
NUCLEO = 1.1                               # mezzo lato del traliccio
PONTE = 2.9                                # mezzo lato delle piattaforme
LIVELLI = [12.0, 9.0, 6.0, 3.0, 0.0, -3.0, -6.0, -9.0, -12.0, -15.0, -18.0]
BANDA = 7.4                                # raggio della discesa
BANDE = [5.2, 5.9, 6.5, 8.3, 9.0, 9.6]              # raggi degli altri scivoli
M_APERTO = LARGO + SPONDA + 0.05           # mezza larghezza di un canale aperto
# il canale della discesa (quella che si fa) è più largo e profondo: con il movimento di grafica le curve
# veloci vogliono sponde alte circa 1 m (prova: raggio 8 m a 12 m/s)
LARGO_D, PROF_D, SPONDA_D = 1.05, 0.95, 0.25      # U quasi tonda come la scena di prova di grafica
M_DISCESA = LARGO_D + SPONDA + 0.05
R_SPIRALE = 4.6                            # raggio della spirale finale attorno al pozzo
M_CHIUSO = R_GROVIGLIO + 0.1               # mezza larghezza di un tubo chiuso
QUANTI = 38                                # scivoli decorativi da tenere
BOCCA_Y = 17.4                             # nel gioco: y della bocca del tubo dell'inseguimento sul muro est
GIOCO = False                              # True: GLB per il gioco (collisioni -col, prop solidi) e torre_gioco.json
COLORI = {'tsc_giallo': '#f0b414', 'tsc_rosso': '#d22a1e', 'tsc_blu': '#1f62c4', 'tsc_verde': '#35a63a',
          'tsc_arancio': '#f06a14', 'tsc_viola': '#7e36b4', 'tsc_turchese': '#14a8b0', 'tsc_rosa': '#e0507e',
          'tsc_bianco': '#e8e4d8'}
STRISCE = [('tsc_rosso', 'tsc_bianco'), ('tsc_blu', 'tsc_giallo'), ('tsc_verde', 'tsc_bianco'),
           ('tsc_viola', 'tsc_giallo'), ('tsc_arancio', 'tsc_bianco'), ('tsc_turchese', 'tsc_rosa')]
# la pedana interna della NO a -12 (verso il vuoto): ci arriva il mezzo giro da SE e ci parte la spirale finale,
# tutte e due sulla fascia interna; la piattaforma della torre da sola lì è troppo piccola
PEDANA_NO12 = None   # (26.0, 16.0, 29.9, 19.9) quando c'era la spirale
DISCESA_PONTI = {('NO', 0.0), ('NE', -3.0), ('SE', -6.0), ('SO', -9.0), ('NO', -12.0), ('NE', -15.0)}
VERNICI_TORRI = {'NO': 'gioco_giallo', 'NE': 'gioco_blu', 'SE': 'gioco_rosso', 'SO': 'gioco_verde'}


# --- materiali nuovi: vetroresina sbiadita nei colori pieni dell'acquapark ---------------------------------

def materiali_scivoli(mats):
    """Le tinte dei tsc_* come le altre 'tinta' della palette (vetroresina con aloni), salvate accanto alle
    derivate della sala la prima volta."""
    import ambiente_texture as TX
    from PIL import Image
    import numpy as np
    cart = os.path.join(K.TEX, 'derivate', mats.palette)
    for nome, hexa in COLORI.items():
        r = dict(ricetta='tinta', sorgente='vetroresina', colore=hexa, sporco=0.7)
        mats.pal['materiali'][nome] = r
        dest = os.path.join(cart, f'{nome}_col.jpg')
        if not os.path.exists(dest):
            out = TX.ricetta_tinta(r, 1)
            TX._salva_jpg(Image.fromarray((TX.lin_srgb(out) * 255 + 0.5).astype(np.uint8)), dest)


# --- lo spazio: chi occupa cosa ----------------------------------------------------------------------------

MOTIVI = {}


def _no(motivo):
    MOTIVI[motivo] = MOTIVI.get(motivo, 0) + 1
    return False


class Spazio:
    def __init__(self):
        self.discesa = []       # punti dei canali della discesa
        self.deco = []          # (punti, mezza larghezza)
        self.scatole = []       # (x0, y0, z0, x1, y1, z1, nome)

    def scatola(self, x0, y0, z0, x1, y1, z1, nome):
        self.scatole.append((x0, y0, z0, x1, y1, z1, nome))

    def libero(self, pts, mezza, esenti=(), muro_alla_fine=False):
        """Vero se il tracciato (punti fitti) non tocca niente. `esenti`: scatole da non controllare (le
        piattaforme dei due capi). Con muro_alla_fine l'ultimo metro può entrare nel muro."""
        n = len(pts)
        lung = [0.0]
        for i in range(1, n):
            lung.append(lung[-1] + (pts[i] - pts[i - 1]).length)
        for i, t in enumerate(pts):
            dal_capo = min(lung[i], lung[-1] - lung[i])
            fine = muro_alla_fine and lung[-1] - lung[i] < 1.4
            if not fine and not (XI0 + mezza + 0.1 < t.x < XI1 - mezza - 0.1 and YI0 + mezza + 0.1 < t.y < YI1 - mezza - 0.1):
                return _no('muri')
            if t.z > H - 1.2 - mezza or t.z < FONDO + 0.3:
                return _no('quota')
            for (x0, y0, z0, x1, y1, z1, nome) in self.scatole:
                if nome in esenti and dal_capo < 4.0:
                    continue
                if x0 - mezza < t.x < x1 + mezza and y0 - mezza < t.y < y1 + mezza and z0 - mezza - 0.15 < t.z < z1 + mezza:
                    return _no('scatola ' + nome.split('_')[0])
            for route in self.discesa:
                for q in route[::2]:
                    if abs(q.x - t.x) < 3 and abs(q.y - t.y) < 3 and \
                            math.hypot(q.x - t.x, q.y - t.y) < mezza + M_DISCESA + 0.15:
                        dz = t.z - q.z
                        if -(1.4 + mezza) < dz < 2.4 + mezza:
                            return _no('discesa')
            for (altri, m2) in self.deco:
                for q in altri[::2]:
                    if abs(q.x - t.x) < 3 and abs(q.y - t.y) < 3 and \
                            math.hypot(q.x - t.x, q.y - t.y) < mezza + m2 + 0.15 and abs(t.z - q.z) < mezza + m2 + 1.1:
                        return _no('deco')
        return True


def fitti(pts, passo=0.4):
    return P.fitti(pts, passo)


# --- geometria delle torri ---------------------------------------------------------------------------------

def centro(t):
    return polare(C, R_TORRE, TORRI[t])


def ponte(t, L):
    """Rettangolo della piattaforma della torre t al livello L."""
    c = centro(t)
    return (c.x - PONTE, c.y - PONTE, c.x + PONTE, c.y + PONTE)


def dentro_rett(p, r, marg=0.0):
    return r[0] + marg < p.x < r[2] - marg and r[1] + marg < p.y < r[3] - marg


def fuori_nucleo(p, t, mezza):
    c = centro(t)
    return max(abs(p.x - c.x), abs(p.y - c.y)) > NUCLEO + 0.25 + mezza + 0.12


def angolo_capo(t, banda, verso, mezza):
    """Angolo del capo di uno scivolo sulla banda `banda` che parte (o arriva) dalla piattaforma della torre t
    andando nel verso `verso` (-1 orario, +1 antiorario): il primo punto fuori dal traliccio, ancora sulla
    piattaforma. None se la banda non ci passa."""
    a0 = TORRI[t]
    r = ponte(t, 0)
    for k in range(0, 400):
        a = a0 + verso * k * 0.25
        p = polare(C, banda, a)
        if not dentro_rett(p, r, 0.15):
            return None
        if fuori_nucleo(p, t, mezza):
            return a
    return None


def angolo_bordo(t, banda, verso, dentro, extra=None):
    """Angolo dove la banda esce dalla piattaforma della torre t (rimpicciolita di `dentro`), andando nel
    verso dato dall'angolo della torre: i tratti della discesa partono al bordo (dietro c'è la pedana per
    entrarci camminando) e arrivano un po' dentro (c'è spazio per fermarsi)."""
    r = ponte(t, 0)
    a = TORRI[t]
    for k in range(0, 800):
        p = polare(C, banda, a + verso * k * 0.25)
        if not dentro_rett(p, r, dentro) and not (extra and dentro_rett(p, extra, dentro)):
            return a + verso * (k - 1) * 0.25
    return None


# --- intaglio ----------------------------------------------------------------------------------------------

GIOCO_INTAGLIO = 0.004                     # quanto resta fra uno scivolo e la pedana (o il sostegno) intagliata
CANALI_APERTI = []                         # (linea, W, D, T, H, R) di ogni canale aperto, per l'intaglio
TUBI_CHIUSI = []                           # (linea, raggio esterno) di ogni tubo chiuso, per l'intaglio di travi e sostegni


def intaglia(bersagli, scivoli, gioco=GIOCO_INTAGLIO, filtri=None, aperti=(), tubi_su=()):
    """Toglie dai `bersagli` (pedane, travi, sostegni) il volume degli `scivoli`, gonfiato di `gioco` metri: lo
    scivolo ci appoggia contro senza entrarci (l'intaglio segue la sua forma, a pochi millimetri). `filtri`: per nome
    del bersaglio, quali pezzi (dal box, angolo basso e alto, e dai materiali) si intagliano; `aperti`: bersagli fatti di sole facce
    (la grata), col booleano che tollera i buchi."""
    filtri = filtri or {}
    import bmesh
    coll = bpy.data.collections.new('intaglio')
    bpy.context.scene.collection.children.link(coll)
    # 1) gli scivoli come sono (tubi, flange, testate), gonfiati di `gioco`
    for s_ in scivoli:
        bm = bmesh.new()
        bm.from_mesh(s_.data)
        bm.transform(s_.matrix_world)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        for v, n in zip(bm.verts, [v.normal.copy() for v in bm.verts]):
            v.co += n * gioco
        me = bpy.data.meshes.new(s_.name + '_intaglio')
        bm.to_mesh(me)
        bm.free()
        coll.objects.link(bpy.data.objects.new(me.name, me))
    # 2) i canali aperti pieni fino al bordo (sono vuoti dentro: la grata o la trave che ci passa attraverso si
    # vedrebbe nel canale): il profilo esterno chiuso in alto, lungo la loro linea
    for (pts, W, D, T, H, R) in CANALI_APERTI:
        n_c = 14
        prof = [(-(W + T + gioco), H + R + gioco)] + [(-(W + T + gioco) * math.cos(math.pi * j_ / n_c), -(D + T + gioco) * math.sin(math.pi * j_ / n_c)) for j_ in range(n_c + 1)] + [((W + T + gioco), H + R + gioco)]
        bm = bmesh.new()
        anelli = []
        for k in range(len(pts)):
            a_, b_ = pts[max(k - 1, 0)], pts[min(k + 1, len(pts) - 1)]
            d = (b_ - a_).normalized()
            lato_ = d.cross(Vector((0, 0, 1))).normalized()
            su = lato_.cross(d).normalized()
            # le testate un po' oltre i capi (lo scivolo vero ha le flange anche lì)
            avanti = d * (-gioco if k == 0 else (gioco if k == len(pts) - 1 else 0.0))
            anelli.append([bm.verts.new(pts[k] + lato_ * s__ + su * h__ + avanti) for (s__, h__) in prof])
        for k in range(len(anelli) - 1):
            for q in range(len(prof)):
                q1 = (q + 1) % len(prof)
                bm.faces.new([anelli[k][q], anelli[k + 1][q], anelli[k + 1][q1], anelli[k][q1]])
        bm.faces.new(anelli[0][::-1])
        bm.faces.new(anelli[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new('canale_pieno_intaglio')
        bm.to_mesh(me)
        bm.free()
        coll.objects.link(bpy.data.objects.new(me.name, me))
    # 3) i tubi chiusi pieni (sono vuoti dentro: una trave che li attraversa ci resterebbe dentro), solo per i bersagli
    # `tubi_su` (travi e sostegni: nella struttura ci sono le grate tonde che chiudono le bocche, dentro i tubi)
    coll_t = bpy.data.collections.new('intaglio_tubi')
    bpy.context.scene.collection.children.link(coll_t)
    for o in coll.objects:
        coll_t.objects.link(o)
    for (punti, rr) in TUBI_CHIUSI:
        # la stessa linea del tubo vero (Catmull-Rom a passi di 0,3 m, come K.tubo_scivolo)
        P_ = [Vector(p) for p in punti]
        E = [P_[0] + (P_[0] - P_[1])] + P_ + [P_[-1] + (P_[-1] - P_[-2])]
        Q = []
        for i_ in range(1, len(E) - 2):
            n_ = max(2, int((E[i_ + 1] - E[i_]).length / 0.3))
            for k in range(n_):
                t_ = k / n_
                p0, p1, p2, p3 = E[i_ - 1], E[i_], E[i_ + 1], E[i_ + 2]
                Q.append(0.5 * ((2 * p1) + (-p0 + p2) * t_ + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t_ * t_ + (-p0 + 3 * p1 - 3 * p2 + p3) * t_ ** 3))
        Q.append(P_[-1])
        bm = bmesh.new()
        anelli = []
        n_s = 24
        for k in range(len(Q)):
            d = (Q[min(k + 1, len(Q) - 1)] - Q[max(k - 1, 0)]).normalized()
            a_ = d.cross(Vector((0, 0, 1)))
            a_ = a_.normalized() if a_.length > 1e-6 else Vector((1, 0, 0))
            b2 = a_.cross(d).normalized()
            # il cerchio circoscritto al poligono (fuori anche a metà dei lati), poi il gioco
            rc = (rr + gioco) / math.cos(math.pi / n_s)
            anelli.append([bm.verts.new(Q[k] + (a_ * math.cos(2 * math.pi * q / n_s) + b2 * math.sin(2 * math.pi * q / n_s)) * rc) for q in range(n_s)])
        for k in range(len(anelli) - 1):
            for q in range(n_s):
                bm.faces.new([anelli[k][q], anelli[k + 1][q], anelli[k + 1][(q + 1) % n_s], anelli[k][(q + 1) % n_s]])
        bm.faces.new(anelli[0][::-1])
        bm.faces.new(anelli[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new('tubo_pieno_intaglio')
        bm.to_mesh(me)
        bm.free()
        coll_t.objects.link(bpy.data.objects.new(me.name, me))
    print(f'intaglio: {len(coll.objects)} forme di scivolo, {len(TUBI_CHIUSI)} tubi pieni')
    from mathutils.bvhtree import BVHTree
    for b_ in bersagli:
        if b_.name in aperti:
            _intaglia_grata(b_, list(coll.objects))
            continue
        raccolta = coll_t if b_.name in tubi_su else coll
        # (dai vertici: un oggetto appena creato non è ancora nel depsgraph)
        alberi = [BVHTree.FromPolygons([o.matrix_world @ v.co for v in o.data.vertices], [tuple(f.vertices) for f in o.data.polygons])
                  for o in raccolta.objects]
        # solo i pezzi (isole) toccati da uno scivolo passano dal booleano: il resto resta com'è (il booleano esatto
        # rifà fitte le facce che taglia; su tutta la torre i triangoli si quintuplicavano)
        albero = BVHTree.FromObject(b_, bpy.context.evaluated_depsgraph_get())
        toccate = set()
        for a_ in alberi:
            toccate.update(i_ for i_, _ in albero.overlap(a_))
        if not toccate:
            continue
        bm = bmesh.new()
        bm.from_mesh(b_.data)
        bm.faces.ensure_lookup_table()
        isola = {}
        for f in bm.faces:
            if f.index in isola:
                continue
            pila, k = [f], f.index
            isola[f.index] = k
            while pila:
                g = pila.pop()
                for v in g.verts:
                    for h in v.link_faces:
                        if h.index not in isola:
                            isola[h.index] = k
                            pila.append(h)
        isole = {isola[i_] for i_ in toccate}
        if b_.name in filtri:
            mw = b_.matrix_world
            box = {}
            mat_isola = {}
            for f in bm.faces:
                if isola[f.index] in isole:
                    mat_isola.setdefault(isola[f.index], set()).add(b_.data.materials[f.material_index].name if b_.data.materials else '')
                    for v in f.verts:
                        co = mw @ v.co
                        lo, hi = box.get(isola[f.index], (co.copy(), co.copy()))
                        box[isola[f.index]] = (Vector(map(min, lo, co)), Vector(map(max, hi, co)))
            isole = {k for k in isole if filtri[b_.name](*box[k], mat_isola[k])}
            if not isole:
                bm.free()
                continue
        tagliare = bm.copy()
        tagliare.faces.ensure_lookup_table()
        bmesh.ops.delete(tagliare, geom=[f for f in tagliare.faces if isola[f.index] not in isole], context='FACES')
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if isola[f.index] in isole], context='FACES')
        if b_.name in aperti:
            # la scala delle UV della grata (u = x * k_uv), da una faccia di sopra
            uv = tagliare.loops.layers.uv.active
            f0 = next(f for f in tagliare.faces if f.normal.z > 0.5 and abs(f.loops[0].vert.co.x - f.loops[1].vert.co.x) > 0.1)
            l0, l1 = f0.loops[0], f0.loops[1]
            k_uv = (l1[uv].uv.x - l0[uv].uv.x) / (l1.vert.co.x - l0.vert.co.x)
            piani = {round(v.co.z, 4) for v in tagliare.verts}
            _chiudi_lastre(tagliare)
        me_t = b_.data.copy()
        tagliare.to_mesh(me_t)
        tagliare.free()
        bm.to_mesh(b_.data)
        bm.free()
        pezzo = bpy.data.objects.new(b_.name + '_intagliato', me_t)
        pezzo.matrix_world = b_.matrix_world
        bpy.context.scene.collection.objects.link(pezzo)
        m = pezzo.modifiers.new('intaglio', 'BOOLEAN')
        m.operation = 'DIFFERENCE'
        m.operand_type = 'COLLECTION'
        m.collection = raccolta
        m.solver = 'EXACT'
        # (i telai delle pedane sono quattro travi con i vertici in comune: non sono chiusi, e senza la tolleranza il
        # booleano ne toglieva intere facce)
        m.use_hole_tolerant = True
        m.use_self = True
        bpy.context.view_layer.objects.active = pezzo
        prima = len(me_t.polygons)
        bpy.ops.object.modifier_apply(modifier=m.name)
        if b_.name in aperti:
            # della lastra restano le due facce della grata (sopra e sotto), coi buchi
            bm = bmesh.new()
            bm.from_mesh(pezzo.data)
            bm.normal_update()
            # (solo le facce sui piani di partenza: quelle del taglio, anche dove il fondo di un canale corre quasi in
            # piano dentro la lastra, si toglievano male col verso della normale)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.normal.z) < 0.5
                                       or not all(any(abs(v.co.z - q) < 5e-4 for q in piani) for v in f.verts)], context='FACES')
            # le UV in piano come le fa il Costruttore (u = x, v = ±y, in lati della texture): il booleano le
            # interpolava storte sulle facce nuove
            uv = bm.loops.layers.uv.active
            for f in bm.faces:
                for l_ in f.loops:
                    l_[uv].uv = (l_.vert.co.x * k_uv, l_.vert.co.y * k_uv * (1 if f.normal.z > 0 else -1))
            bm.to_mesh(pezzo.data)
            bm.free()
        # le schegge che il booleano lascia (pezzetti di pochi millimetri, a volte dentro la parete dello scivolo)
        bm = bmesh.new()
        bm.from_mesh(pezzo.data)
        vis, schegge = set(), []
        for f in bm.faces:
            if f in vis:
                continue
            pila, isola_f = [f], []
            vis.add(f)
            while pila:
                g = pila.pop()
                isola_f.append(g)
                for e in g.edges:
                    for h in e.link_faces:
                        if h not in vis:
                            vis.add(h)
                            pila.append(h)
            co = [v.co for g in isola_f for v in g.verts]
            if (Vector(map(max, *co)) - Vector(map(min, *co))).length < 0.03:
                schegge.extend(isola_f)
        if schegge:
            bmesh.ops.delete(bm, geom=schegge, context='FACES')
            bm.to_mesh(pezzo.data)
        bm.free()
        print(f'intaglio di {b_.name}: {len(isole)} pezzi toccati, {prima} -> {len(pezzo.data.polygons)} facce, {len(schegge)} facce di schegge tolte')
        for o in bpy.context.view_layer.objects:
            o.select_set(False)
        pezzo.select_set(True)
        b_.select_set(True)
        bpy.context.view_layer.objects.active = b_
        bpy.ops.object.join()
    _pulisci_attraversati(bersagli, scivoli, aperti)
    for o in list(coll_t.objects):
        bpy.data.meshes.remove(o.data)
    bpy.data.collections.remove(coll)
    bpy.data.collections.remove(coll_t)


def _pulisci_attraversati(bersagli, scivoli, aperti):
    """L'ultima passata, come il controllo di posizionamento (passo f): ogni spigolo di ogni scivolo contro i bersagli;
    le facce che uno spigolo attraversa (non solo tocca ai capi) si tolgono: per la grata tutte, per gli altri solo le
    schegge (meno di 100 cm2) che il booleano lascia dentro la parete dello scivolo."""
    import bmesh
    from mathutils.bvhtree import BVHTree
    spigoli = []
    for s_ in scivoli:
        bm = bmesh.new()
        bm.from_mesh(s_.data)
        bm.transform(s_.matrix_world)
        for f in bm.faces:
            # i lati e tutte le diagonali (l'export sceglie lui come dividere i quadrilateri)
            q = [v.co.copy() for v in f.verts]
            for i in range(len(q)):
                for j in range(i + 1, len(q)):
                    if (q[j] - q[i]).length > 0.004:
                        spigoli.append((q[i], q[j]))
        bm.free()
    for b_ in bersagli:
        for giro in range(3):
            # (l'albero come lo fa la prova: dall'oggetto aggiornato, con le facce come le esporta)
            bpy.context.view_layer.update()
            albero = BVHTree.FromObject(b_, bpy.context.evaluated_depsgraph_get())
            bm = bmesh.new()
            bm.from_mesh(b_.data)
            bm.transform(b_.matrix_world)
            bm.faces.ensure_lookup_table()
            colpite = set()
            for a_, c_ in spigoli:
                d = c_ - a_
                lun = d.length
                d.normalize()
                da = a_ + d * 0.001
                resto = lun - 0.002
                while resto > 0:
                    hit = albero.ray_cast(da, d, resto)
                    if hit[0] is None:
                        break
                    if (hit[0] - a_).length > 0.004 and (hit[0] - c_).length > 0.004:
                        colpite.add(hit[2])
                    passo = (hit[0] - da).length + 0.0005
                    da = da + d * passo
                    resto -= passo
            via = [bm.faces[i] for i in colpite if b_.name in aperti or bm.faces[i].calc_area() < 0.01]
            if via:
                bmesh.ops.delete(bm, geom=via, context='FACES')
                bm.transform(b_.matrix_world.inverted())
                bm.to_mesh(b_.data)
            bm.free()
            print(f'pulizia di {b_.name}: {len(colpite)} facce attraversate, {len(via)} tolte')
            if not via:
                break


def _sezione(o, z0, z1):
    """L'impronta in pianta (shapely) di quello che il pezzo chiuso `o` occupa fra le quote z0 e z1: le sezioni a z0
    e a z1 (le facce che le linee di taglio chiudono) più i triangoli della superficie nella fascia, schiacciati."""
    from shapely.geometry import Polygon, LineString
    from shapely.ops import polygonize, unary_union
    me = o.data
    mw = o.matrix_world
    vs = [mw @ v.co for v in me.vertices]
    pezzi = []
    for z in (z0, z1):
        tratti = []
        for f in me.polygons:
            q = [vs[i] for i in f.vertices]
            pts = []
            for k in range(len(q)):
                a_, b_ = q[k], q[(k + 1) % len(q)]
                if (a_.z - z) * (b_.z - z) < 0:
                    t = (z - a_.z) / (b_.z - a_.z)
                    pts.append((a_.x + (b_.x - a_.x) * t, a_.y + (b_.y - a_.y) * t))
            if len(pts) == 2:
                tratti.append(LineString(pts))
        if tratti:
            pezzi.extend(polygonize(unary_union(tratti)))
    for f in me.polygons:
        q = [vs[i] for i in f.vertices]
        if max(v.z for v in q) < z0 or min(v.z for v in q) > z1:
            continue
        # il pezzo della faccia dentro la fascia, schiacciato in pianta (largo: basta che copra)
        dentro = []
        for k in range(len(q)):
            a_, b_ = q[k], q[(k + 1) % len(q)]
            if z0 <= a_.z <= z1:
                dentro.append((a_.x, a_.y))
            for z in (z0, z1):
                if (a_.z - z) * (b_.z - z) < 0:
                    t = (z - a_.z) / (b_.z - a_.z)
                    dentro.append((a_.x + (b_.x - a_.x) * t, a_.y + (b_.y - a_.y) * t))
        if len(dentro) >= 3:
            pg = Polygon(dentro).convex_hull
            if pg.area > 0:
                pezzi.append(pg)
    return unary_union(pezzi) if pezzi else None


def _intaglia_grata(gr, tagli):
    """La grata (per ogni pedana una faccia sopra e una sotto, 12 mm più giù) bucata in pianta dove ci sono gli
    scivoli, nello spessore della grata: niente booleano (sui piani aperti lasciava triangoli sovrapposti)."""
    import bmesh
    from shapely.geometry import Polygon
    from shapely.ops import unary_union
    import shapely
    bm = bmesh.new()
    bm.from_mesh(gr.data)
    bm.transform(gr.matrix_world)
    bm.normal_update()
    uv = bm.loops.layers.uv.active
    col = bm.loops.layers.color.active or bm.loops.layers.float_color.active
    f0 = next(f for f in bm.faces if f.normal.z > 0.5 and abs(f.loops[0].vert.co.x - f.loops[1].vert.co.x) > 0.1)
    l0, l1 = f0.loops[0], f0.loops[1]
    k_uv = (l1[uv].uv.x - l0[uv].uv.x) / (l1.vert.co.x - l0.vert.co.x)
    sopra = [f for f in bm.faces if f.normal.z > 0.5]
    giu = [f for f in bm.faces if f.normal.z < -0.5]
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    alberi = [(t, None, None) for t in tagli]
    scatole = {}
    for t in tagli:
        co = [t.matrix_world @ v.co for v in t.data.vertices]
        scatole[t.name] = [Vector(map(min, *co)), Vector(map(max, *co))]
    nuove, via, n_buchi = [], [], 0
    for f in sopra:
        z1 = f.verts[0].co.z
        pianta = Polygon([(v.co.x, v.co.y) for v in f.verts])
        # le facce di sotto della stessa pedana (girate, 12 mm più giù; anche divise in triangoli)
        gg = [g for g in giu if z1 - 0.02 < g.verts[0].co.z < z1 - 0.004
              and pianta.buffer(0.005).contains(Polygon([(v.co.x, v.co.y) for v in g.verts]).representative_point())]
        z0 = gg[0].verts[0].co.z if gg else z1 - 0.012
        lo, hi = pianta.bounds[:2], pianta.bounds[2:]
        buchi = []
        for t, albero, inv in alberi:
            # (il box dai vertici: bound_box di un oggetto appena creato è vuoto finché la scena non si aggiorna)
            bb = scatole[t.name]
            if max(v.z for v in bb) < z0 or min(v.z for v in bb) > z1 or max(v.x for v in bb) < lo[0] or min(v.x for v in bb) > hi[0] \
                    or max(v.y for v in bb) < lo[1] or min(v.y for v in bb) > hi[1]:
                continue
            sez = _sezione(t, z0 - 0.0005, z1 + 0.0005)
            if sez is not None and not sez.is_empty:
                buchi.append(sez)
        if not buchi:
            continue
        # (5 mm in più: senza, ai bordi restavano triangoli di pochi millimetri che toccavano lo scivolo)
        resto = pianta.difference(unary_union(buchi).buffer(0.005))
        if resto.equals(pianta):
            continue
        n_buchi += 1
        via.append(f)
        via.extend(gg)
        mat = (f.material_index, tuple(f.loops[0][col]) if col else None)
        for tri in shapely.constrained_delaunay_triangles(resto).geoms:
            c_ = list(tri.exterior.coords)[:3]
            if tri.area < 1e-6:
                continue
            nuove.append((c_, z1, z0, mat))
    bmesh.ops.delete(bm, geom=list(set(via)), context='FACES')
    for (c_, z1, z0, mat) in nuove:
        a_ = (c_[1][0] - c_[0][0]) * (c_[2][1] - c_[0][1]) - (c_[1][1] - c_[0][1]) * (c_[2][0] - c_[0][0])
        giro = c_ if a_ > 0 else c_[::-1]
        for z, verso in ((z1, 1), (z0, -1)):
            vv = [bm.verts.new((x, y, z)) for (x, y) in (giro if verso > 0 else giro[::-1])]
            fn = bm.faces.new(vv)
            fn.material_index = mat[0]
            for l_ in fn.loops:
                l_[uv].uv = (l_.vert.co.x * k_uv, l_.vert.co.y * k_uv * verso)
                if col:
                    l_[col] = mat[1]
    bm.transform(gr.matrix_world.inverted())
    bm.to_mesh(gr.data)
    bm.free()
    print(f'intaglio di {gr.name}: {n_buchi} pedane bucate in pianta, {len(gr.data.polygons)} facce')


def _chiudi_lastre(bm):
    """La grata è fatta di due facce per pedana (sopra, e sotto girata 12 mm più giù): le chiude in una lastra con
    le pareti di lato, così il booleano esatto la può bucare (le normali si rifanno dopo)."""
    import bmesh
    bm.normal_update()
    sotto = {}
    for f in bm.faces:
        if f.normal.z < -0.5:
            sotto[tuple(sorted((round(v.co.x, 3), round(v.co.y, 3)) for v in f.verts))] = f
    for f in list(bm.faces):
        if f.normal.z <= 0.5:
            continue
        g = sotto.get(tuple(sorted((round(v.co.x, 3), round(v.co.y, 3)) for v in f.verts)))
        if g is None:
            continue
        giu = {(round(v.co.x, 3), round(v.co.y, 3)): v for v in g.verts}
        for e in f.edges:
            a_, b_ = e.verts
            bm.faces.new([a_, giu[(round(a_.co.x, 3), round(a_.co.y, 3))], giu[(round(b_.co.x, 3), round(b_.co.y, 3))], b_])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)


# --- pezzi --------------------------------------------------------------------------------------------------

def arco(banda0, banda1, a0, a1, z0, z1, passo=0.35):
    return elica(C, banda0, banda1, a0, a1, z0, z1, passo)


def liscia(pts, giri):
    """Media mobile sulla linea (1-2-1) per arrotondare gli spigoli; i due capi restano fermi."""
    pts = [Vector(p) for p in pts]
    for _ in range(giri):
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


def pendenza(pts):
    lung = sum((pts[i] - pts[i - 1]).length for i in range(1, len(pts)))
    return (pts[0].z - pts[-1].z) / max(lung, 1e-6), lung


T_U, R_U = 0.08, 0.06                      # spessore e bordo arrotondato dei canali aperti (si vedono come solidi)


def flange_u(c, pts, W, D, T, H, mat, ogni=2.0, e=0.035, b=0.05):
    """Le flange dei giunti di un canale aperto a U: una fascia attorno all'esterno ogni `ogni` metri e una a
    ogni testata (così il bordo si vede spesso, come i tubi chiusi)."""
    n_c = 14

    def prof(a, bb):
        return [(-a, H)] + [(-a * math.cos(math.pi * j / n_c), -bb * math.sin(math.pi * j / n_c)) for j in range(n_c + 1)] + [(a, H)]
    dentro = prof(W + T - 0.004, D + T - 0.004)
    fuori = prof(W + T + e, D + T + e)
    lung = [0.0]
    for i in range(1, len(pts)):
        lung.append(lung[-1] + (pts[i] - pts[i - 1]).length)
    dove = [0]
    prossimo = ogni
    for i in range(1, len(pts) - 1):
        if lung[i] >= prossimo and lung[-1] - lung[i] > ogni * 0.5:
            dove.append(i)
            prossimo = lung[i] + ogni
    dove.append(len(pts) - 1)
    for i in dove:
        a_, b_ = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        d = (b_ - a_).normalized()
        lato = d.cross(Vector((0, 0, 1))).normalized()
        su = lato.cross(d).normalized()
        sp_ = b if i == 0 else (-b if i == len(pts) - 1 else 0.0)

        def P_(sv, hv, off):
            return pts[i] + lato * sv + su * hv + d * (sp_ + off)
        for k in range(len(fuori) - 1):
            (s0, h0), (s1, h1) = fuori[k], fuori[k + 1]
            (t0, g0), (t1, g1) = dentro[k], dentro[k + 1]
            sm, hm = (s0 + s1) / 2, (h0 + h1) / 2
            n_out = (lato * (1 if sm > 0 else -1)) if hm > 0.001 else (lato * sm / (W * W) + su * hm / (D * D)).normalized()
            c.faccia_verso([P_(s0, h0, -b), P_(s1, h1, -b), P_(s1, h1, b), P_(s0, h0, b)], mat, n_out)
            for off, vv in ((-b, -d), (b, d)):
                c.faccia_verso([P_(t0, g0, off), P_(t1, g1, off), P_(s1, h1, off), P_(s0, h0, off)], mat, vv)
        for (t_, g_), (s_, h_) in ((dentro[0], fuori[0]), (dentro[-1], fuori[-1])):
            c.faccia_verso([P_(t_, g_, -b), P_(s_, h_, -b), P_(s_, h_, b), P_(t_, g_, b)], mat, su)


def scivolo_discesa(c, pts, mat):
    """Un pezzo della discesa: canale aperto più largo e con le sponde alte (vedi LARGO_D), con le flange."""
    S.scivolo_solido(c, [Vector(p) for p in pts], W=LARGO_D, D=PROF_D, T=T_U, H=SPONDA_D, R=R_U, mat=mat)
    CANALI_APERTI.append(([Vector(p) for p in pts], LARGO_D, PROF_D, T_U, SPONDA_D, R_U))
    flange_u(c, [Vector(p) for p in pts], LARGO_D, PROF_D, T_U, SPONDA_D, mat)


def scivolo_aperto(c, pts, mat):
    """Uno scivolo aperto decorativo (come P.scivolo, ma spesso e con le flange)."""
    S.scivolo_solido(c, [Vector(p) for p in pts], W=LARGO, D=PROF, T=T_U, H=SPONDA, R=R_U, mat=mat)
    CANALI_APERTI.append(([Vector(p) for p in pts], LARGO, PROF, T_U, SPONDA, R_U))
    flange_u(c, [Vector(p) for p in pts], LARGO, PROF, T_U, SPONDA, mat)


def travatura(c, pts, chiuso, esclusi, mat='metallo', largo=None, prof=None):
    """La travatura sotto uno scivolo: selle trasversali ogni 1,2 m, montanti e diagonali fino a una trave di
    chiglia 0,75 m più giù. Salta i tratti sopra le piattaforme `esclusi` (rettangoli)."""
    du = R_GROVIGLIO + 0.07 if chiuso else (prof or PROF) + 0.1
    passo = 1.2
    s = 0.0
    sotto = []
    lung = [0.0]
    for i in range(1, len(pts)):
        lung.append(lung[-1] + (pts[i] - pts[i - 1]).length)
    for i in range(1, len(pts)):
        s += (pts[i] - pts[i - 1]).length
        if s < passo:
            continue
        s = 0.0
        p = pts[i]
        # niente selle all'inizio e alla fine del pezzo (nei salti ci si atterrerebbe sopra)
        if lung[i] < 1.5 or lung[-1] - lung[i] < 1.5:
            continue
        if any(dentro_rett(p, r, -0.3) for r in esclusi):
            sotto.append(None)
            continue
        sotto.append((p, i))
    prec = None
    for k, v in enumerate(sotto):
        if v is None:
            prec = None
            continue
        p, i = v
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        d = (b - a); d.z = 0
        d.normalize()
        lat = Vector((-d.y, d.x, 0))
        # sotto un canale ripido il fondo è più giù sulla verticale (la sezione è perpendicolare alla pendenza)
        inclinato = (b - a).normalized()
        fondo = R_GROVIGLIO if chiuso else (prof or PROF) + T_U
        u = p - Vector((0, 0, fondo / max(0.5, math.sqrt(max(0.0, 1.0 - inclinato.z ** 2))) - 0.02))
        kp = u - Vector((0, 0, 0.75))
        w = 0.45 if chiuso else (0.45 if largo else LARGO + 0.08)
        c.scatola_assi(u - Vector((0, 0, 0.05)), [d, lat, Vector((0, 0, 1))], (0.05, w, 0.05), mat)
        c.cilindro(u - Vector((0, 0, 0.1)), kp, 0.045, mat, seg=8, tappi=False)
        if prec is not None:
            pu, pk = prec
            c.cilindro(pk, kp, 0.06, mat, seg=8, tappi=False)
            c.cilindro(pu - Vector((0, 0, 0.1)), kp, 0.035, mat, seg=6, tappi=False)
        prec = (u, kp)


def torre(c, t, mat, livelli_ponte=None):
    """Traliccio della torre: quattro colonne grosse, travi a ogni livello, croci di Sant'Andrea sulle facce e
    i bracci che reggono la piattaforma (più larga del traliccio)."""
    cc = centro(t)
    ang = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    col = [Vector((cc.x + sx * NUCLEO, cc.y + sy * NUCLEO, 0)) for sx, sy in ang]
    for p in col:
        c.cilindro((p.x, p.y, FONDO), (p.x, p.y, H - 0.2), 0.2, mat, seg=16)
        c.anello((p.x, p.y, FONDO), (0, 0, 1), 0.0, 0.42, 0.04, 'metallo', seg=16)
        c.scatola((p.x - 0.3, p.y - 0.3, H - 0.2), (p.x + 0.3, p.y + 0.3, H), 'metallo')
    quote = [FONDO + 1.0] + LIVELLI[::-1]
    for L in LIVELLI:
        for i in range(4):
            a, b = col[i], col[(i + 1) % 4]
            c.cilindro((a.x, a.y, L - 0.3), (b.x, b.y, L - 0.3), 0.12, mat, seg=10)
        # bracci verso gli angoli della piattaforma (solo dove c'è; altrimenti un secondo anello di travi)
        if livelli_ponte is not None and L not in livelli_ponte:
            for i in range(4):
                a, b = col[i], col[(i + 1) % 4]
                c.cilindro((a.x, a.y, L - 1.5), (b.x, b.y, L - 1.5), 0.08, 'metallo', seg=8)
            continue
        for (sx, sy), p in zip(ang, col):
            q = Vector((cc.x + sx * (PONTE - 0.15), cc.y + sy * (PONTE - 0.15), 0))
            c.cilindro((p.x, p.y, L - 0.3), (q.x, q.y, L - 0.3), 0.09, mat, seg=8)
            c.cilindro((p.x, p.y, L - 1.4), (q.x, q.y, L - 0.32), 0.06, mat, seg=8)
    for z0, z1 in zip(quote[:-1], quote[1:]):
        for i in range(4):
            a, b = col[i], col[(i + 1) % 4]
            c.cilindro((a.x, a.y, z0 - 0.25), (b.x, b.y, z1 - 0.35), 0.05, 'metallo', seg=6)
            c.cilindro((b.x, b.y, z0 - 0.25), (a.x, a.y, z1 - 0.35), 0.05, 'metallo', seg=6)


def scala_servizio(c, sp, x0, y0, lungo, asse, verso_ponte, mat='gioco_giallo'):
    """Scala di servizio a rampe (1,5 m l'una) dal fondo all'ultimo livello: due corsie affiancate larghe 1,1 m
    lungo `asse` ('x' o 'y'), pianerottolo 1,2 m a ogni capo; il pianerottolo d'inizio di ogni giro (ogni 3 m)
    è alla quota delle piattaforme e ci si attacca. Colonne agli angoli, corrimano fuori."""
    largo = 2.2
    corsa = 2.4
    lp = 1.2

    def P_(u, v, z):           # u lungo l'asse, v di traverso
        return Vector((x0 + u, y0 + v, z)) if asse == 'x' else Vector((x0 + v, y0 + u, z))

    def box(u0, v0, z0, u1, v1, z1, m):
        a, b = P_(u0, v0, z0), P_(u1, v1, z1)
        c.scatola((min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)), (max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)), m)
    tot = lp * 2 + corsa
    for (u, v) in ((0, 0), (tot, 0), (tot, largo), (0, largo)):
        p = P_(u, v, 0)
        c.cilindro((p.x, p.y, FONDO), (p.x, p.y, LIVELLI[0] + 1.1), 0.1, mat, seg=10)
    a, b = P_(0, 0, FONDO), P_(tot, largo, LIVELLI[0] + 1.2)
    sp.scatola(min(a.x, b.x), min(a.y, b.y), FONDO, max(a.x, b.x), max(a.y, b.y), LIVELLI[0] + 1.2, 'scala')
    z = FONDO + 2.0 - 3.0 * 0           # primo pianerottolo: 2 m sopra il fondo (si sale dal fondo con la prima rampa)
    quote = [L for L in LIVELLI[::-1]]
    gradini = 8
    alz = 1.5 / gradini
    pedata = corsa / gradini
    # rampa iniziale dal fondo al primo pianerottolo (-18)
    for L in quote:
        # pianerottolo d'inizio giro (alla quota L) e di metà (L + 1,5)
        box(0, 0, L - 0.08, lp, largo, L, 'metallo_grigio')
        box(lp + corsa, 0, L + 1.5 - 0.08, tot, largo, L + 1.5, 'metallo_grigio')
        if L == quote[-1]:
            continue
        for g in range(gradini):     # su lungo l'asse nella corsia 0, poi indietro nella corsia 1
            box(lp + g * pedata, 0.05, L + (g + 1) * alz - 0.05, lp + (g + 1) * pedata, 1.05, L + (g + 1) * alz, 'metallo_grigio')
            box(lp + corsa - (g + 1) * pedata, 1.12, L + 1.5 + (g + 1) * alz - 0.05, lp + corsa - g * pedata, largo - 0.05,
                L + 1.5 + (g + 1) * alz, 'metallo_grigio')
        # cosciali
        for vv in (0.0, 1.1, 1.2, largo - 0.05):
            if vv < 1.15:
                a_, b_ = P_(lp, vv, L), P_(lp + corsa, vv, L + 1.5)
            else:
                a_, b_ = P_(lp + corsa, vv, L + 1.5), P_(lp, vv, L + 3.0)
            # (nel gioco 3 cm più su: i gradini ci appoggiano, prima restavano 2 cm sopra)
            sc_ = 0.09 if GIOCO else 0.12
            c.cilindro(a_ - Vector((0, 0, sc_)), b_ - Vector((0, 0, sc_)), 0.05, mat, seg=6)
        # corrimano sul lato esterno (lontano dal ponte) e in testa
        lato = largo if verso_ponte < 0 else 0.0
        P.ringhiera_dritta(c, P_(lp + corsa, lato, L + 1.5), P_(tot, lato, L + 1.5))
        P.ringhiera_dritta(c, P_(tot, 0, L + 1.5), P_(tot, largo, L + 1.5))
    # rampa dal fondo al primo pianerottolo
    L0 = quote[0]
    n0 = int((L0 - FONDO) / alz)
    for g in range(n0):
        box(lp + corsa - (g + 1) * (corsa / n0), 1.2, FONDO + (g + 1) * alz - 0.05, lp + corsa - g * (corsa / n0),
            largo - 0.05, FONDO + (g + 1) * alz, 'metallo_grigio')
    for vv in (1.2, largo - 0.05):     # i cosciali della prima rampa, dal fondo al pianerottolo
        c.cilindro(P_(lp + corsa, vv, FONDO), P_(lp, vv, L0), 0.05, mat, seg=6)


def ringhiere_ponte(c, r, L, aperture):
    """Ringhiera sui quattro lati della piattaforma, meno le aperture [(lato, da, a)] in metri lungo il lato."""
    x0, y0, x1, y1 = r
    lati = {'s': ((x0, y0), (x1, y0)), 'n': ((x0, y1), (x1, y1)), 'o': ((x0, y0), (x0, y1)), 'e': ((x1, y0), (x1, y1))}
    for l, ((ax, ay), (bx, by)) in lati.items():
        lung = math.hypot(bx - ax, by - ay)
        tratti = [(0.0, lung)]
        for (la, t0, t1) in aperture:
            if la != l:
                continue
            nuovi = []
            for (u0, u1) in tratti:
                if t1 <= u0 or t0 >= u1:
                    nuovi.append((u0, u1))
                else:
                    if t0 > u0:
                        nuovi.append((u0, t0))
                    if t1 < u1:
                        nuovi.append((t1, u1))
            tratti = nuovi
        for (u0, u1) in tratti:
            if u1 - u0 < 0.3:
                continue
            a = (ax + (bx - ax) * u0 / lung, ay + (by - ay) * u0 / lung, L)
            b = (ax + (bx - ax) * u1 / lung, ay + (by - ay) * u1 / lung, L)
            P.ringhiera_dritta(c, a, b)


def apertura(r, pts, mezza=1.25):
    """Dove il tracciato esce dal rettangolo r: (lato, da, a) in metri lungo quel lato."""
    a = aperture_tutte(r, pts, mezza)
    return a[0] if a else None


def aperture_tutte(r, pts, mezza):
    """Le aperture della ringhiera dove il tracciato esce dal rettangolo r: sul lato che attraversa e, se è
    vicino a un angolo, anche sull'altro lato dell'angolo."""
    x0, y0, x1, y1 = r
    for p in pts:
        if not dentro_rett(p, r):
            d = {'o': abs(p.x - x0), 'e': abs(p.x - x1), 's': abs(p.y - y0), 'n': abs(p.y - y1)}
            l = min(d, key=d.get)
            u = (p.y - y0) if l in 'oe' else (p.x - x0)
            lung = (y1 - y0) if l in 'oe' else (x1 - x0)
            out = [(l, u - mezza, u + mezza)]
            if u - mezza < 0.6:          # vicino all'angolo basso: si apre anche il lato che parte da lì
                altro = 's' if l in 'oe' else 'o'
                pos = 0.0 if l in 'os' else (x1 - x0 if l == 'e' else y1 - y0)
                out.append((altro, pos - 0.1 - (mezza if l in 'en' else 0), pos + (mezza - u + 0.6) if l in 'os' else pos + 0.1))
            if u + mezza > lung - 0.6:   # vicino all'angolo alto
                altro = 'n' if l in 'oe' else 'e'
                pos = 0.0 if l in 'os' else (x1 - x0 if l == 'e' else y1 - y0)
                out.append((altro, pos - (u + mezza - lung + 0.6) if l in 'en' else pos - 0.1, pos + 0.1 + (mezza if l in 'os' else 0)))
            return out
    return []


# --- la versione A -------------------------------------------------------------------------------------------

def percorso_gioco(g):
    """Le tappe della discesa per le viste e per test_torre (torre_percorso.json), ricavate dai dati del gioco:
    il portone, il canale di ogni tratto, i salti (tra i pezzi, o col getto in fondo al tratto), le pedane
    dei checkpoint, la Polaroid e la vasca del fondo."""
    per = [('portone', Vector(g['checkpoint'][0]['pos']))]
    giu = Vector((0, 0, PROF_D))
    for k, tr in enumerate(g['tratti']):
        tipi = list(tr['salti'])
        for j, ln in enumerate(tr['linee']):
            pz = [Vector(q) + giu for q in ln]
            if j >= 1:
                per.append((tipi.pop(0), pz[0]))
            per += [('scivolo', q) for q in pz]
        if tipi:   # il salto in fondo al tratto, fino alla pedana dopo
            per.append((tipi.pop(0), Vector(tr['a'])))
        cp = g['checkpoint'][k + 1]
        per.append(('fondo' if cp['nome'] == 'fondo' else f"pedana {cp['nome']}", Vector(cp['pos'])))
    per.append(('polaroid 10', Vector(g['polaroid_10'])))
    return per


def sostieni(c, sp, pezzi, pedane, mensole_su, voli, campata=4.5, sbalzo=0.9):
    """Sostegni dei pezzi (scivoli della discesa e decorativi): un pezzo è retto dove poggia su una pedana,
    dove entra nel muro e dove c'è una mensola; altrove ci vuole un sostegno nuovo a ogni capo libero (a
    `sbalzo` metri dalla fine) e almeno ogni `campata` metri. In ordine si prova: un puntone dalla colonna
    più vicina di un traliccio, due tiranti fino al soffitto o al fondo di una pedana, un palo fino al fondo
    o a una pedana. I sostegni non devono passare in un altro pezzo, in una scatola occupata o nel volo
    di un salto. Ritorna l'elenco dei pezzi con le campate più lunghe rimaste."""
    def lunghezze(pts):
        lung = [0.0]
        for i in range(1, len(pts)):
            lung.append(lung[-1] + (pts[i] - pts[i - 1]).length)
        return lung

    def a_s(pts, lung, s_):
        for i in range(1, len(pts)):
            if lung[i] >= s_:
                f = (s_ - lung[i - 1]) / max(1e-6, lung[i] - lung[i - 1])
                return pts[i - 1].lerp(pts[i], f), (pts[i] - pts[i - 1])
        return pts[-1], pts[-1] - pts[-2]

    def su_pedana(p):
        return any(dentro_rett(p, r, 0.1) and L - 0.1 < p.z < L + 1.7 for (_, L), r in pedane.items())

    altri_tutti = [(pz, M_DISCESA) for pz in sp.discesa] + list(sp.deco)

    perche = {}

    ultimo = ['']

    def no(motivo):
        perche[motivo] = perche.get(motivo, 0) + 1
        ultimo[0] = motivo
        return False

    def libero(a, b, proprio, raggio=0.12, fine_su=None):
        """Il segmento a-b non passa in altri pezzi, nelle scatole occupate o nei voli. (Le scatole dei
        tralicci non contano: i puntoni ci si attaccano, e dentro ci sono solo le colonne.)"""
        n = max(2, int((b - a).length / 0.3))
        for k in range(n + 1):
            q = a.lerp(b, k / n)
            for (pts, m) in altri_tutti:
                if pts is proprio:
                    continue
                # sopra la discesa restano liberi 2,4 m: chi scivola non deve trovarsi una barra davanti
                su = 2.4 if m == M_DISCESA else m + 0.1
                for t in pts[::2]:
                    if abs(t.x - q.x) < 2.5 and abs(t.y - q.y) < 2.5 and \
                            math.hypot(t.x - q.x, t.y - q.y) < m + raggio + 0.05 and -0.6 - m < q.z - t.z < su:
                        return no('pezzo')
            for (x0, y0, z0, x1, y1, z1, nome) in sp.scatole:
                if nome.startswith(('ponte_', 'vasca_', 'pozzo', 'nucleo_')) or nome == fine_su:
                    continue
                if x0 < q.x < x1 and y0 < q.y < y1 and z0 < q.z < z1:
                    return no(nome.split('_')[0])
            for (da, aa) in voli:
                for j in range(13):
                    f = j / 12
                    v = da.lerp(aa, f) + Vector((0, 0, 1.6 * 4 * f * (1 - f)))
                    # il corpo di chi salta: dai piedi (la traiettoria) a 2 m sopra
                    if math.hypot(v.x - q.x, v.y - q.y) < 1.1 and -0.3 < q.z - v.z < 2.0:
                        return no('volo')
        return True

    def sopra(x, y, z):
        """Dove arriva un tirante che sale da (x, y, z): il fondo di una pedana o il soffitto."""
        best = H
        for (_, L), r in pedane.items():
            if dentro_rett(Vector((x, y, 0)), r, -0.15) and z < L - 0.3 < best:
                best = L - 0.27
        return best

    def sotto(x, y, z):
        best = FONDO
        for (_, L), r in pedane.items():
            if dentro_rett(Vector((x, y, 0)), r, -0.15) and best < L < z:
                best = L - 0.02
        for (x0, y0, z0, x1, y1, z1, nome) in sp.scatole:
            # (in una vasca di raccolta il palo arriva sul fondo, nell'acqua)
            z_ = z0 + 0.35 if nome.startswith('vasca_raccolta') else z1
            if nome.startswith(('vasca_', 'pozzo')) and x0 < x < x1 and y0 < y < y1 and best < z_ < z:
                best = z_
        return best

    def sella(u, d, lat, w):
        c.scatola_assi(u - Vector((0, 0, 0.07)), [d, lat, Vector((0, 0, 1))], (0.08, w, 0.07), 'gioco_rosso')
        for sg in (-1, 1):
            q = u + lat * (sg * (w - 0.04))
            c.cilindro(q - Vector((0, 0, 0.12)), q + Vector((0, 0, 0.12)), 0.035, 'metallo', seg=8)

    def collare(p, d3, lat, chiuso, largo, prof):
        """Il collare che abbraccia il pezzo dove è retto (si vede anche dall'alto) e i due punti in cima, ai
        lati, dove si attaccano i tiranti."""
        if chiuso:
            c.anello(p, d3, R_GROVIGLIO + 0.005, R_GROVIGLIO + 0.06, 0.16, 'metallo', seg=20)
            return [p + lat * (sg * (R_GROVIGLIO + 0.09)) for sg in (-1, 1)]
        sponda = SPONDA_D if largo == LARGO_D else SPONDA
        flange_u(c, [p - d3 * 0.16, p + d3 * 0.16], largo, prof, T_U, sponda, 'metallo', ogni=99.0, e=0.05, b=0.05)
        return [p + lat * (sg * (largo + T_U + 0.1)) + Vector((0, 0, sponda - 0.04)) for sg in (-1, 1)]

    def attacco(q, sg_lat, lat):
        """La staffa tra il collare e il tirante (un braccetto corto verso l'esterno)."""
        c.cilindro(q - lat * (sg_lat * 0.08), q, 0.04, 'metallo', seg=8)

    # nel gioco, i gradini di grata sotto la bocca del tubo dell'inseguimento (vedi più giù): sopra di loro un sostegno
    # lascia 2 m liberi (il collare sotto la coda del tratto 5 stava 1,93 m sopra il terzo gradino; regola del
    # coordinatore del 23 ottobre)
    gradini_bocca = [(36.35, BOCCA_Y + y0_, XI1 - 2.4, BOCCA_Y + 0.65, FONDO + zt) for y0_, zt in
                     ((-2.4, 0.28), (-1.85, 0.56), (-1.3, 0.84), (-0.75, 1.12))] if GIOCO else []

    def sopra_gradini(q, basso, m=1.0):
        # (anche accanto, fino a 1 m: nella vasca del fondo si cammina lungo i gradini)
        for (x0, y0, x1, y1, zt) in gradini_bocca:
            if x0 - m < q.x < x1 + m and y0 - m < q.y < y1 + m and basso - zt < 2.02:
                return True
        return False

    def prova(pts, mezza, chiuso, largo, prof, p, d, discesa=False):
        d3 = d.normalized()
        d = Vector((d.x, d.y, 0))
        if d.length < 1e-6:
            return None
        d.normalize()
        lat = Vector((-d.y, d.x, 0))
        du = (R_GROVIGLIO + 0.07) if chiuso else prof + 0.12
        u = p - Vector((0, 0, du))
        basso_ok = not sopra_gradini(u, u.z - 0.25)
        if not basso_ok:
            perche['2 m sopra i gradini della bocca'] = perche.get('2 m sopra i gradini della bocca', 0) + 1
        w = (R_GROVIGLIO + 0.14) if chiuso else largo + 0.14
        colonne = [(t, Vector((centro(t).x + sx * NUCLEO, centro(t).y + sy * NUCLEO, 0)))
                   for t in ORDINE for sx in (-1, 1) for sy in (-1, 1)]
        t_col, col = min(colonne, key=lambda tq: math.hypot(tq[1].x - u.x, tq[1].y - u.y))
        vernice = VERNICI_TORRI[t_col]
        dist = math.hypot(col.x - u.x, col.y - u.y)
        # 1) puntone dalla colonna più vicina di un traliccio (per la discesa anche più lungo: sta sotto il
        # canale, fuori dalla vista, al posto dei tiranti inclinati)
        if basso_ok and 0.6 < dist < (5.5 if discesa else 3.6):
            a1 = Vector((col.x, col.y, u.z - 0.1))
            a2 = Vector((col.x, col.y, u.z - 0.1 - max(1.0, 0.8 * dist)))
            if libero(a1, u, pts) and libero(a2, u, pts):
                sella(u, d, lat, w)
                collare(p, d3, lat, chiuso, largo, prof)
                c.cilindro(a1, u - Vector((0, 0, 0.1)), 0.09, vernice, seg=10)
                c.cilindro(a2, u - Vector((0, 0, 0.12)), 0.06, vernice, seg=8)
                c.anello(a1, (0, 0, 1), 0.19, 0.28, 0.14, 'metallo', seg=12)
                return 'puntone'
        # i tiranti partono dai lati del collare, in alto
        capi_alti = [p + lat * (sg * ((R_GROVIGLIO + 0.09) if chiuso else (largo + T_U + 0.1))) +
                     Vector((0, 0, 0.0 if chiuso else (SPONDA_D if largo == LARGO_D else SPONDA) - 0.04)) for sg in (-1, 1)]
        # 2) tiranti fino al soffitto o sotto una pedana
        tetti = [sopra(q.x, q.y, q.z) for q in capi_alti]
        if basso_ok and all(libero(q + Vector((0, 0, 0.3)), Vector((q.x, q.y, z1)), pts, 0.06) for q, z1 in zip(capi_alti, tetti)):
            collare(p, d3, lat, chiuso, largo, prof)
            for sg, q, z1 in zip((-1, 1), capi_alti, tetti):
                attacco(q, sg, lat)
                c.cilindro(q, Vector((q.x, q.y, z1)), 0.05, 'metallo', seg=8, tappi=False)
                c.scatola((q.x - 0.1, q.y - 0.1, z1 - 0.03), (q.x + 0.1, q.y + 0.1, z1 + 0.02), 'metallo')
                m = (q.z + z1) / 2
                c.cilindro(Vector((q.x, q.y, m - 0.18)), Vector((q.x, q.y, m + 0.18)), 0.08, 'gioco_rosso', seg=8)
            return 'tiranti'
        # 3) tiranti inclinati fino alla colonna più vicina, più in alto (del colore della torre). Non per la
        # discesa: passerebbero davanti alla faccia di chi scivola (prova del 19 ottobre)
        if basso_ok and dist < 7.5 and not discesa:
            alto = Vector((col.x, col.y, max(capi_alti[0].z, capi_alti[1].z) + max(1.6, 0.55 * dist)))
            if alto.z < H - 0.5 and all(libero(q + (alto - q).normalized() * 0.3, alto, pts, 0.06) for q in capi_alti):
                collare(p, d3, lat, chiuso, largo, prof)
                for sg, q in zip((-1, 1), capi_alti):
                    attacco(q, sg, lat)
                    c.cilindro(q, alto, 0.06, vernice, seg=8, tappi=False)
                    m = q.lerp(alto, 0.5)
                    c.cilindro(m - (alto - q).normalized() * 0.18, m + (alto - q).normalized() * 0.18, 0.09, 'metallo', seg=8)
                c.anello(alto, (0, 0, 1), 0.19, 0.28, 0.16, 'metallo', seg=12)
                return 'tiranti alla colonna'
        # 4) palo fino al fondo o a una pedana (non nella vasca del fondo accanto ai gradini della bocca, dove si
        # cammina: il palo della coda del tratto 5 stava lì)
        z0 = sotto(u.x, u.y, u.z)
        if basso_ok and u.z - z0 > 0.4 and not sopra_gradini(u, -99.0) and \
                libero(u - Vector((0, 0, 0.2)), Vector((u.x, u.y, z0)), pts, 0.15):
            sella(u, d, lat, w)
            collare(p, d3, lat, chiuso, largo, prof)
            c.cilindro((u.x, u.y, z0), (u.x, u.y, u.z - 0.06), 0.12, 'gioco_giallo', seg=12)
            c.anello((u.x, u.y, z0), (0, 0, 1), 0.0, 0.28, 0.04, 'metallo', seg=12)
            return 'palo'
        # 5) sopra la vasca del fondo, accanto ai gradini della bocca (dove sotto il pezzo non ci sta niente: 2 m liberi
        # sopra i gradini e dove si cammina): un tirante dal muro est, più in alto, fino alla staffa sulla sponda del
        # lato del muro. Niente collare e niente sella sotto il pezzo
        if sopra_gradini(u, -99.0) and 0.3 < XI1 - u.x < 3.0:
            capo = capi_alti[0] if capi_alti[0].x > capi_alti[1].x else capi_alti[1]
            a_t = Vector((XI1, capo.y, capo.z + 1.2))
            if libero(a_t - Vector((0.1, 0, 0)), capo, pts, 0.06):
                attacco(capo, 1 if capo == capi_alti[1] else -1, lat)
                c.cilindro(a_t + Vector((0.02, 0, 0)), capo, 0.05, 'metallo', seg=8, tappi=False)
                m = capo.lerp(a_t, 0.5)
                c.cilindro(m - (a_t - capo).normalized() * 0.18, m + (a_t - capo).normalized() * 0.18, 0.08, 'gioco_rosso', seg=8)
                c.scatola((XI1 - 0.03, a_t.y - 0.15, a_t.z - 0.15), (XI1 + 0.02, a_t.y + 0.15, a_t.z + 0.15), 'metallo')
                return 'tirante al muro'
        return None

    rapporto = []
    conta = {}
    for (pts, mezza, chiuso, largo, prof, muro_fine, nome) in pezzi:
        lung = lunghezze(pts)
        tot = lung[-1]
        retti = [lung[i] for i, q in enumerate(pts) if su_pedana(q)]
        if chiuso:
            # i tubi chiusi poggiano sulla pedana con una culla (il fondo del tubo è qualche cm più su)
            for i in (0, len(pts) - 1):
                if not su_pedana(pts[i]):
                    continue
                L = max(L_ for (_, L_), r in pedane.items() if dentro_rett(pts[i], r, 0.1) and L_ - 0.1 < pts[i].z < L_ + 1.7)
                s_ = min(0.5, tot / 4) if i == 0 else tot - min(0.5, tot / 4)
                p, d = a_s(pts, lung, s_)
                d = Vector((d.x, d.y, 0)).normalized()
                lat = Vector((-d.y, d.x, 0))
                alto = p.z - R_GROVIGLIO + 0.06
                cen = Vector((p.x, p.y, (L + alto) / 2))
                c.scatola_assi(cen, [d, lat, Vector((0, 0, 1))], (0.12, R_GROVIGLIO * 0.75, (alto - L) / 2), 'metallo')
        retti += [lung[i] for i in mensole_su.get(id(pts), [])]
        if muro_fine:
            retti.append(tot)
        if pts[-1].z < FONDO + 1.6:
            retti.append(tot)          # finisce nella vasca del fondo
        nuovi = []

        def metti(s_obiettivo, spazio=1.2):
            for dv in [x * sg for x in (0.0, 0.35, 0.7, 1.05, 1.4, 1.75, 2.1, 2.45) for sg in (1, -1)]:
                s_ = s_obiettivo + dv
                if not (0.25 <= s_ <= tot - 0.25) or abs(s_obiettivo - s_) > spazio:
                    continue
                p, d = a_s(pts, lung, s_)
                tipo = prova(pts, mezza, chiuso, largo, prof, p, d, nome.startswith('discesa'))
                if tipo:
                    conta[tipo] = conta.get(tipo, 0) + 1
                    nuovi.append(s_)
                    retti.append(s_)
                    return True
            return False
        if not retti or min(retti) > sbalzo + 0.3:
            metti(min(sbalzo, tot / 2))
        if not retti or max(retti) < tot - sbalzo - 0.3:
            metti(max(tot - sbalzo, tot / 2))
        for _ in range(20):
            rr = sorted(set(round(x, 2) for x in retti))
            buchi = [(b_ - a_, a_, b_) for a_, b_ in zip(rr[:-1], rr[1:]) if b_ - a_ > campata]
            if not buchi:
                break
            gap, a_, b_ = max(buchi)
            if not metti((a_ + b_) / 2, gap / 2 - 0.5):
                break
        rr = sorted(set(retti))
        peggiore = max([b_ - a_ for a_, b_ in zip(rr[:-1], rr[1:])] + [0.0]) if rr else tot
        rapporto.append((nome, round(tot, 1), round(rr[0], 1) if rr else None, round(tot - rr[-1], 1) if rr else None,
                         round(peggiore, 1), len(nuovi)))
    print('sostegni nuovi:', conta, 'scartati per:', perche)
    for r_ in rapporto:
        if r_[2] is None or r_[2] > sbalzo + 0.6 or r_[3] > sbalzo + 0.6 or r_[4] > campata + 1.5:
            print('  sostegni scarsi:', r_)
    return rapporto


def vasche_raccolta(c, cl, sp, salti, tappe, aperture):
    """Sotto i salti dei tratti 0-4 (scelta dell'utente del 21 ottobre, V1): chi sbaglia il salto cade in una
    vasca di raccolta, senza morire, e una scaletta di servizio lo riporta sulla pedana da cui era partito (in
    cima la ringhiera è aperta). La vasca sta accanto al lato della pedana di partenza che guarda il salto e
    copre la zona dove si cade (il punto in mezzo al salto, 1,5 m avanti e indietro, 1,2 m di lato). Tra le
    quote e le misure possibili si prende la prima in cui la vasca non tocca nessuno scivolo e sopra la zona
    dove si cade, fino al salto, non passa niente. È retta da due puntoni dal traliccio della torre di partenza.
    Il salto dell'ultimo tratto finisce sul fondo. Restituisce i dati per il gioco e le acque."""
    dati, acque = [], []
    tutti = [(pz, M_DISCESA) for pz in sp.discesa] + list(sp.deco)

    def ingombro(m_):
        """Quanto un pezzo occupa sopra e sotto i punti della sua linea: la discesa ha il canale profondo e la
        travatura sotto, i canali aperti le sponde sopra e il canale sotto, i tubi il loro raggio."""
        if m_ == M_DISCESA:
            return 0.35, PROF_D + 0.5
        if m_ == M_CHIUSO:
            return m_, m_
        return 0.35, PROF + 0.45

    def tocca(x0, y0, z0, x1, y1, z1, marg):
        for pts_, m_ in tutti:
            su_, giu_ = ingombro(m_)
            for q in pts_:
                if x0 - m_ - marg < q.x < x1 + m_ + marg and y0 - m_ - marg < q.y < y1 + m_ + marg and \
                        z0 - su_ - marg < q.z < z1 + giu_ + marg:
                    return True
        return False
    for k in range(min(5, len(tappe))):
        t0, L0, t1, L1 = tappe[k]
        s_ = salti[k]
        da, a = s_['da'], s_['a']
        m = (da + a) / 2
        dv = Vector((a.x - da.x, a.y - da.y, 0)).normalized()
        dl = Vector((-dv.y, dv.x, 0))
        zona = [m + dv * 1.5 + dl * 1.2, m + dv * 1.5 - dl * 1.2, m - dv * 1.5 + dl * 1.2, m - dv * 1.5 - dl * 1.2]
        zx0, zx1 = min(q.x for q in zona), max(q.x for q in zona)
        zy0, zy1 = min(q.y for q in zona), max(q.y for q in zona)
        z_salto = min(da.z, a.z)
        x0, y0, x1, y1 = ponte(t0, L0)
        lati = {'e': (x1, (1, 0)), 'o': (x0, (-1, 0)), 'n': (y1, (0, 1)), 's': (y0, (0, -1))}
        lato = max(lati, key=lambda l_: (m.x - x1) if l_ == 'e' else (x0 - m.x) if l_ == 'o' else (m.y - y1) if l_ == 'n' else (y0 - m.y))
        bordo, (nx, ny) = lati[lato]
        lungo_x = lato in 'ns'
        lo_side, hi_side = (x0, x1) if lungo_x else (y0, y1)
        ap = [x for x in aperture.get((t0, L0), []) if x[0] == lato]
        posti = []
        u = lo_side + 0.7
        while u < hi_side - 0.7:
            if all(u - lo_side < a0 - 0.6 or u - lo_side > a1 + 0.6 for (_, a0, a1) in ap):
                posti.append(u)
            u += 0.1
        assert posti, f'nessun posto per la scaletta della vasca {k}'
        # la zona di caduta, lungo il lato (u) e verso fuori (n)
        zu0, zu1 = (zx0, zx1) if lungo_x else (zy0, zy1)
        zn = [zy0, zy1] if lungo_x else [zx0, zx1]
        zn_lontano = max(zn) if (nx + ny) > 0 else min(zn)
        prof = min(abs(zn_lontano - bordo) + 0.3, (R_TORRE * math.sqrt(2) - 2 * PONTE) - 0.35)
        scelta = None
        # la colonna sopra la zona di caduta deve essere libera fino al salto (a parte la discesa che atterra)
        for u_scala in sorted(posti, key=lambda q: abs(q - (zu0 + zu1) / 2)):
            u0, u1 = min(zu0, u_scala - 0.6), max(zu1, u_scala + 0.6)
            if u1 - u0 > 7.0:
                continue
            n0, n1 = sorted((bordo + 0.15 * (nx + ny), bordo + (0.15 + prof) * (nx + ny)))
            rx0, ry0, rx1, ry1 = (u0, n0, u1, n1) if lungo_x else (n0, u0, n1, u1)
            rx0, ry0, rx1, ry1 = max(rx0, XI0 + 0.25), max(ry0, YI0 + 0.25), min(rx1, XI1 - 0.25), min(ry1, YI1 - 0.25)
            alto = 0.8
            for discesa_cm in range(100 if s_['tipo'] == 'getto' else 120, 420, 5):
                bordo_su = z_salto - discesa_cm / 100.0
                fondo = bordo_su - alto
                # la vasca e le sue travi (35 cm sotto il fondo) non toccano niente; la colonna di caduta è libera
                if tocca(rx0, ry0, fondo - 0.35, rx1, ry1, bordo_su + 0.2, 0.05):
                    continue
                if any(zx0 - 0.4 < q.x < zx1 + 0.4 and zy0 - 0.4 < q.y < zy1 + 0.4 and bordo_su < q.z < z_salto - 0.4
                       for pts_, m_ in sp.deco for q in pts_):
                    continue
                scelta = (u_scala, rx0, ry0, rx1, ry1, bordo_su, fondo)
                break
            if scelta:
                break
        if scelta is None:
            print(f'ATTENZIONE: nessun posto libero per la vasca di raccolta {k} (salto a {z_salto:.1f}), lato {lato}, zona {[round(v,1) for v in (zx0, zy0, zx1, zy1)]}, prof {prof:.1f}')
            u_scala = min(posti, key=lambda q: abs(q - (zu0 + zu1) / 2))
            u0, u1 = min(zu0, u_scala - 0.6), max(zu1, u_scala + 0.6)
            n0, n1 = sorted((bordo + 0.15 * (nx + ny), bordo + (0.15 + prof) * (nx + ny)))
            rx0, ry0, rx1, ry1 = (u0, n0, u1, n1) if lungo_x else (n0, u0, n1, u1)
            for pts_, m_ in tutti:
                zs_ = [round(q.z, 1) for q in pts_ if rx0 - m_ - 0.1 < q.x < rx1 + m_ + 0.1 and ry0 - m_ - 0.1 < q.y < ry1 + m_ + 0.1 and q.z < z_salto + 1]
                if zs_:
                    print(f'   pezzo (mezza {m_:.2f}) nella pianta della vasca a quote {min(zs_)}..{max(zs_)}, xy es. {[round(v,1) for v in pts_[len(pts_)//2]]}')
            continue
        u, rx0, ry0, rx1, ry1, bordo_su, fondo = scelta
        acque.append(P.vasca(c, rx0, ry0, rx1, ry1, fondo, alto=bordo_su - fondo, nome_acqua=f'acqua_raccolta_{k}'))
        c.scatola((rx0 - 0.1, ry0 - 0.1, fondo - 0.3), (rx1 + 0.1, ry1 + 0.1, fondo), 'metallo_grigio')
        sp.scatola(rx0, ry0, fondo - 0.35, rx1, ry1, bordo_su, f'vasca_raccolta_{k}')
        # due puntoni dal traliccio della torre di partenza, sotto la vasca dalla parte della pedana
        cc = centro(t0)
        for f_ in (0.25, 0.75):
            q = Vector((rx0 + (rx1 - rx0) * f_, ry0 + (ry1 - ry0) * f_, fondo - 0.3))
            if lungo_x:
                q.y = ry0 + 0.4 if ny > 0 else ry1 - 0.4
            else:
                q.x = rx0 + 0.4 if nx > 0 else rx1 - 0.4
            col = Vector((min(max(q.x, cc.x - NUCLEO), cc.x + NUCLEO), min(max(q.y, cc.y - NUCLEO), cc.y + NUCLEO), q.z - 1.6))
            c.cilindro(col, q, 0.1, VERNICI_TORRI[t0], seg=10)
            c.anello(col, (0, 0, 1), 0.17, 0.26, 0.14, 'metallo', seg=12)
            c.scatola((q.x - 0.15, q.y - 0.15, q.z - 0.04), (q.x + 0.15, q.y + 0.15, q.z), 'metallo')
        # la scaletta di servizio, dalla vasca alla pedana
        aperture.setdefault((t0, L0), []).append((lato, u - lo_side - 0.95, u - lo_side + 0.95))   # (largo: si sale anche un po' di lato)
        sx, sy = (u, bordo + 0.12 * ny) if lungo_x else (bordo + 0.12 * nx, u)
        lat = Vector((1, 0, 0)) if lungo_x else Vector((0, 1, 0))
        # (solo da vedere, in cl: a salire ci pensa la Ladder del gioco, e i pioli non fanno inciampare in cima)
        for sg in (-0.25, 0.25):
            q = Vector((sx, sy, 0)) + lat * sg
            # i montanti finiscono al bordo della pedana: sopra sarebbero nello spazio di chi cammina (non hanno
            # collisione, e con la collisione tra i due non si passa)
            cl.cilindro((q.x, q.y, fondo), (q.x, q.y, L0 - 0.02), 0.03, 'giallo_sicurezza', seg=8)
            cl.cilindro((q.x, q.y, L0 - 0.2), (q.x - 0.12 * nx, q.y - 0.12 * ny, L0 - 0.2), 0.025, 'metallo', seg=6)
        zz = fondo + 0.3
        while zz < L0 + 0.05:
            cl.cilindro(Vector((sx, sy, zz)) - lat * 0.25, Vector((sx, sy, zz)) + lat * 0.25, 0.022, 'giallo_sicurezza', seg=6)
            zz += 0.3
        dati.append(dict(rett=[rx0, ry0, rx1, ry1], fondo=fondo, acqua=bordo_su - 0.12, torre=t0, livello=L0,
                         scala=dict(x=sx, y=sy, z0=fondo, z1=L0, verso=[float(nx), float(ny), 0.0])))
        print(f'vasca di raccolta {k}: {t0} {L0:g}, lato {lato}, rett {[round(v, 2) for v in (rx0, ry0, rx1, ry1)]}, '
              f'bordo {bordo_su:.2f} ({z_salto - bordo_su:.1f} m sotto il salto), scaletta in {u:.2f}')
    return dati, acque


IMBUTO_L, IMBUTO_BOCCA, IMBUTO_H = 1.6, 0.6, 0.95      # lunghezza, quanto si allarga per lato, altezza


def imbuto(c, pz, t, L, mat, ostacoli):
    """Le due sponde svasate davanti all'imbocco di un tratto: dal fianco del canale si aprono di IMBUTO_BOCCA
    metri per lato in IMBUTO_L metri, sulla pedana (si accorciano se la pedana finisce prima)."""
    p0 = Vector((pz[0].x, pz[0].y, L))
    tg = pz[1] - pz[0]
    tg.z = 0
    tg.normalize()
    lat = Vector((-tg.y, tg.x, 0))
    r = ponte(t, L)
    cc = centro(t)
    lung = IMBUTO_L

    def bocca_ok(lu):
        # la bocca sta sulla pedana e lascia almeno 1,2 m di passaggio verso il traliccio
        for sg in (-1, 1):
            q = p0 - tg * lu + lat * (sg * (LARGO_D + IMBUTO_BOCCA * lu / IMBUTO_L))
            if not dentro_rett(q, r, -0.1) or max(abs(q.x - cc.x), abs(q.y - cc.y)) < NUCLEO + 0.2 + 1.2:
                return False
        return True
    while lung > 0.5 and not bocca_ok(lung):
        lung -= 0.1
    for sg in (-1, 1):
        a = p0 + lat * (sg * (LARGO_D + T_U - 0.02)) + tg * 0.05
        b = p0 - tg * lung + lat * (sg * (LARGO_D + IMBUTO_BOCCA * lung / IMBUTO_L))
        d = b - a
        lu = d.length
        d.normalize()
        n = Vector((-d.y, d.x, 0))
        cen = (a + b) / 2 + Vector((0, 0, IMBUTO_H / 2))
        c.scatola_assi(cen, [d, n, Vector((0, 0, 1))], (lu / 2, 0.045, IMBUTO_H / 2), mat)
        c.cilindro(a + Vector((0, 0, IMBUTO_H)), b + Vector((0, 0, IMBUTO_H)), 0.06, mat, seg=10)
        c.cilindro(b, b + Vector((0, 0, IMBUTO_H + 0.06)), 0.06, mat, seg=10)
        for j in range(int(lu / 0.35) + 1):
            q = a.lerp(b, j / max(1, int(lu / 0.35)))
            ostacoli.append([round(q.x, 2), round(q.y, 2), L, 0.12])


BOCCHE_CHIUSE = []        # (punto, verso, chiuso): per le lampade rosse guaste (nel gioco)


def chiusa_bocca(c, dal_capo, chiuso, L):
    """Chiude la bocca di uno scivolo decorativo sulla sua pedana: una grata tonda dentro il tubo, o un
    cancello a sbarre davanti al canale aperto (con la collisione: non ci si entra)."""
    lung = 0.0
    i = 1
    while i < len(dal_capo) - 1 and lung + (dal_capo[i] - dal_capo[i - 1]).length < 0.35:
        lung += (dal_capo[i] - dal_capo[i - 1]).length
        i += 1
    p = dal_capo[i]
    d = (dal_capo[i + 1] - dal_capo[i - 1]).normalized()
    BOCCHE_CHIUSE.append(([round(v, 3) for v in (p.x, p.y, L)], [round(d.x, 3), round(d.y, 3)], chiuso))
    if chiuso:
        # dentro il tubo (18 lati: il piano di un lato è a R*cos(10°) dall'asse), 4 mm dalla parete: col raggio pieno
        # l'anello e le sbarre entravano un centimetro nella parete
        r = K.SCIVOLO_R * math.cos(math.pi / 18) - 0.004 - 0.02
        lat = d.cross(Vector((0, 0, 1))).normalized()
        su = lat.cross(d).normalized()
        c.anello(p, d, r - 0.05, r + 0.02, 0.06, 'gioco_rosso', seg=20)
        for k in range(-3, 4):
            o = k * r / 3.6
            h = math.sqrt(max(r * r - o * o, 0.0))
            c.cilindro(p + lat * o - su * h, p + lat * o + su * h, 0.022, 'inox', seg=6)
            c.cilindro(p + su * o - lat * h, p + su * o + lat * h, 0.018, 'inox', seg=6)
    else:
        P.cancello_partenza(c, Vector((p.x, p.y, L)), Vector((d.x, d.y, 0)))


def versione_A(mats):
    P.CANALI.clear(); P.DECO.clear(); P.OSTACOLI.clear(); P.PALI_PEDANE.clear(); BOCCHE_CHIUSE.clear(); CANALI_APERTI.clear(); TUBI_CHIUSI.clear()
    materiali_scivoli(mats)
    rnd = random.Random(17)
    c = K.Costruttore(mats)            # guscio, torri, piattaforme, travature
    cs = K.Costruttore(mats)           # canali aperti
    P.GRATE[0] = K.Costruttore(mats)
    sp = Spazio()
    # nel gioco il tubo dell'inseguimento passa nel muro est: lì il muro ha il foro (coperto dal collare)
    P.guscio_profondo(c, buco_est=(BOCCA_Y - 1.0, BOCCA_Y + 1.0, FONDO + 0.6, FONDO + 2.6) if GIOCO else None)
    luci = dict(lavoro=[], fari=[], gocce=[], emergenza=[])
    percorso = []
    aperture = {}                      # (torre, L) -> lista di aperture della ringhiera

    capi_pts = {}                      # (torre, L) -> tracciati dal capo (per le pedane piccole)

    def apri(t, L, pts_dal_capo, mezza=1.25):
        capi_pts.setdefault((t, L), []).append(pts_dal_capo)
        if PEDANA_NO12 and (t, L) == ('NO', -12.0) and dentro_rett(pts_dal_capo[0], PEDANA_NO12):
            aperture.setdefault(('pedana_no12', L), []).extend(aperture_tutte(PEDANA_NO12, pts_dal_capo, mezza))
            return
        aperture.setdefault((t, L), []).extend(aperture_tutte(ponte(t, L), pts_dal_capo, mezza))

    # torri e piattaforme (le scatole servono subito ai controlli)
    for t in ORDINE:
        cc = centro(t)
        sp.scatola(cc.x - NUCLEO - 0.25, cc.y - NUCLEO - 0.25, FONDO, cc.x + NUCLEO + 0.25, cc.y + NUCLEO + 0.25, H, f'nucleo_{t}')
        for L in LIVELLI:
            x0, y0, x1, y1 = ponte(t, L)
            sp.scatola(x0, y0, L - 0.45, x1, y1, L + 1.15, f'ponte_{t}_{L:g}')
    # scale di servizio: tasca ovest della torre NO e tasca sud della torre SE
    rno, rse = ponte('NO', 0), ponte('SE', 0)
    # portone, passerella e balconata
    sp.scatola(XI0, 13.4, -0.5, rno[0] + 0.1, 16.6, 5.0, 'passerella')
    sp.scatola(rno[0] - 2.5, 16.5, -0.5, rno[0] + 0.1, rno[1] + 0.1, 1.2, 'passerella_2')
    sp.scatola(XI0, rno[1] + 0.1, FONDO, XI0 + 2.5, rno[1] + 5.1, LIVELLI[0] + 1.2, 'scala_no')
    sp.scatola(rse[0] + 0.1, YI0, FONDO, rse[0] + 5.1, YI0 + 2.6, LIVELLI[0] + 1.2, 'scala_se')
    sp.scatola(28.4, YI1 - 1.8, -3.8, 33.6, YI1, 1.2, 'balconata')
    sp.scatola(XI0, 12.0, -0.5, XI0 + 0.6, 18.0, 5.2, 'portone')
    # vasche del fondo e pozzo
    # la vasca ovest è quella del fondo, dove finisce la discesa (la spirale attorno al pozzo ci arriva)
    VASCHE = {'est': (33.2, 12.4, 39.6, 17.6), 'sud': (27.6, 4.3, 33.4, 7.6), 'ovest': (20.4, 12.2, 27.2, 17.8)}
    for nome, (x0, y0, x1, y1) in VASCHE.items():
        sp.scatola(x0, y0, FONDO, x1, y1, FONDO + 0.7, f'vasca_{nome}')
    sp.scatola(C[0] - 2.3, C[1] - 2.3, FONDO, C[0] + 2.3, C[1] + 2.3, FONDO + 0.8, 'pozzo')

    # --- la discesa -------------------------------------------------------------------------------------
    def z_capo(L, chiuso=False):
        return L + (0.6 if chiuso else 0.4)

    def spezzato(r0, r1, a0, a1, z0, z1, buchi):
        """Un tratto della discesa da a0 ad a1 (gradi, raggio da r0 a r1, quota da z0 a z1), spezzato nei
        buchi [(angolo, larghezza in metri, dislivello in più, tipo)]. In volo si va dritti: attorno a ogni
        buco la curva si sostituisce con la sua corda (dentro il cerchio, lontano dai tralicci), lunga il buco
        più RINCORSA metri per parte; il pezzo prima finisce sulla corda, quello dopo riparte sulla stessa
        linea, più in basso del dislivello. La pendenza si aggiusta perché l'ultimo pezzo arrivi a z1."""
        RINCORSA = 1.6
        D = sum(b[2] for b in buchi)
        verso = -1 if a1 < a0 else 1

        def f_di(a):
            return (a - a0) / (a1 - a0)

        def r_di(a):
            return r0 + (r1 - r0) * f_di(a)

        def z_di(a):
            giu = sum(b[2] for b in buchi if (a - b[0]) * verso > 0)
            return z0 + (z1 - z0 + D) * f_di(a) - giu

        def punto(a):
            return polare(C, r_di(a), a, z_di(a))
        buchi = sorted(buchi, key=lambda b_: (b_[0] - a0) * verso)
        pezzi, salti = [], []
        corrente = []
        a_prec = a0
        for (ab, larg, dz, tipo) in buchi:
            r = r_di(ab)
            mezzo = math.degrees(math.asin(min(0.95, (larg / 2 + RINCORSA) / r)))
            a_s, a_e = ab - verso * mezzo, ab + verso * mezzo
            # l'arco fino all'inizio della corda
            corrente += arco(r_di(a_prec), r_di(a_s), a_prec, a_s, z_di(a_prec + verso * 1e-6) if a_prec != a0 else z0,
                             z_di(a_s))[:-1]
            ps, pe = punto(a_s), punto(a_e)
            pe = Vector((pe.x, pe.y, z_di(a_e - verso * 1e-6)))      # la quota senza il salto, poi giù di dz
            L = (Vector((pe.x, pe.y, 0)) - Vector((ps.x, ps.y, 0))).length
            u_t = (L - larg) / (2 * L)
            n = max(3, int(L / 0.3))
            for j in range(n + 1):
                u = j / n
                if u > u_t:
                    break
                corrente.append(ps.lerp(pe, u))
            decollo = ps.lerp(pe, u_t)
            corrente.append(decollo)
            pezzi.append(corrente)
            atterra = ps.lerp(pe, 1 - u_t) - Vector((0, 0, dz))
            corrente = [atterra]
            for j in range(n + 1):
                u = j / n
                if u > 1 - u_t:
                    corrente.append(ps.lerp(pe, u) - Vector((0, 0, dz)))
            salti.append(dict(tipo=tipo, larghezza=larg, dislivello=dz, da=decollo, a=atterra))
            a_prec = a_e
        corrente += arco(r_di(a_prec), r1, a_prec, a1, z_di(a_prec + verso * 1e-6) if a_prec != a0 else z0, z1)[1:]
        pezzi.append(corrente)
        # dove l'arco diventa corda c'è uno spigolo: si arrotonda (i capi restano dove sono)
        pezzi = [liscia(pz, 12) for pz in pezzi]
        for k, s_ in enumerate(salti):
            s_['da'], s_['a'] = pezzi[k][-1], pezzi[k + 1][0]
        for s_ in salti:
            # la velocità minima per arrivare senza getto (caduta libera dal capo al pezzo dopo)
            h = max(0.01, s_['da'].z - s_['a'].z)
            s_['v_minima'] = round(s_['larghezza'] / math.sqrt(2 * h / 9.81), 2)
        return pezzi, salti

    def spezzato_regolato(r0, r1, a0, a1, z0, z1, buchi):
        """Come spezzato, ma per i buchi 'getto' il terzo valore è la caduta vera voluta sul buco (piccola: senza
        getto non si arriva): il dislivello in più si trova per approssimazioni."""
        voluti = {i: b[2] for i, b in enumerate(buchi) if b[3] == 'getto'}
        lav = [list(b) for b in buchi]
        for _ in range(6):
            pezzi, salti = spezzato(r0, r1, a0, a1, z0, z1, [tuple(b) for b in lav])
            ordine = sorted(range(len(lav)), key=lambda i: (lav[i][0] - a0) * (-1 if a1 < a0 else 1))
            for k, i in enumerate(ordine):
                if i in voluti:
                    h = salti[k]['da'].z - salti[k]['a'].z
                    lav[i][2] -= h - voluti[i]
        return pezzi, salti

    def tratto_discesa(t0, L0, t1, L1, buchi=(), alza_fine=0.0, banda=BANDA):
        """Scivolo della discesa dalla torre t0 (livello L0) alla t1 (L1) sulla banda BANDA, in senso orario,
        spezzato nei `buchi` [(angolo, larghezza m, dislivello m, 'salto'|'getto')]."""
        a0 = angolo_bordo(t0, banda, -1, 0.15, PEDANA_NO12 if (t0, L0) == ('NO', -12.0) else None)
        a1 = angolo_bordo(t1, banda, +1, 0.25, PEDANA_NO12 if (t1, L1) == ('NO', -12.0) else None)
        if a1 > a0:
            a1 -= 360.0
        z0, z1 = L0 + PROF_D + 0.06, L1 + PROF_D + 0.06 + alza_fine
        buchi = [(b[0] if b[0] <= a0 else b[0] - 360.0, b[1], b[2], b[3]) for b in buchi]
        pezzi, salti = spezzato_regolato(banda, banda, a0, a1, z0, z1, list(buchi))
        for pz in pezzi:
            assert len(pz) < 120 and min(q.z for q in pz) > L1 - 1.5, f'tratto {t0}->{t1} sbagliato'
            sp.discesa.append(pz)
            P.CANALI.append(pz)
        apri(t0, L0, pezzi[0], 2.0)
        apri(t1, L1, pezzi[-1][::-1], 2.0)
        return pezzi, salti

    # la discesa: 6 salti normali e 2 col getto, sempre più difficili. Il primo è corto e basso e insegna
    # (davanti alla balconata dei bambini); la velocità minima dei salti normali cresce da 2 a 5,5 m/s,
    # quelli col getto ne vorrebbero quasi 10 (senza getto non si arriva)
    # la discesa (18 ottobre, "più salti"): 6 tratti da una torre alla successiva sulla fascia larga (le curve
    # strette non si tengono, col movimento di grafica), 4 salti normali sempre più lunghi e 2 col getto. Il
    # primo salto è corto e basso e insegna, davanti alla balconata dei bambini. I salti col getto sono alla fine
    # di un tratto: lo scivolo finisce nel vuoto e si atterra su qualcosa di largo (la pedana NO a -12, poi la
    # vasca del fondo); senza la planata del getto si cade prima.
    def getto_lungo(t0, L0, d_volo, h, verso_pedana=None, verso=-1, arco_m=4.2, tipo='getto'):
        """Un tratto che finisce nel vuoto: dalla pedana t0 (L0) lungo la fascia, finché davanti (in linea retta)
        il bersaglio è a d_volo metri; il capo è h metri sopra l'arrivo. verso_pedana = (torre, L) del bersaglio,
        oppure None (il bersaglio è la vasca del fondo, che si mette lì)."""
        a0 = angolo_bordo(t0, BANDA, verso, 0.15)
        z0 = L0 + PROF_D + 0.06
        for k in range(8, 400):
            a = a0 + verso * k * 0.5
            e = polare(C, BANDA, a)
            tg = polare(C, BANDA, a + verso * 0.5) - e
            tg.normalize()
            if verso_pedana:
                # si atterra almeno 1,6 m dentro la pedana, lontano dal traliccio (col getto si plana oltre)
                r = ponte(*verso_pedana)
                cv = centro(verso_pedana[0])
                dd = next((d / 10 for d in range(5, 120) if dentro_rett(e + tg * (d / 10), r, 0.6)), None)
                if dd is not None and dd <= d_volo:
                    q = e + tg * (dd + 1.6)
                    if dentro_rett(q, r, -0.9) and max(abs(q.x - cv.x), abs(q.y - cv.y)) > NUCLEO + 0.9:
                        break
            elif abs(a0 - a) * math.pi / 180 * BANDA > arco_m:
                dd = d_volo
                break
        z_fine = (verso_pedana[1] if verso_pedana else FONDO + 0.6) + h + PROF_D + 0.06
        pz = liscia(arco(BANDA, BANDA, a0, a, z0, z_fine), 2)
        # la pendenza cresce piano nel primo metro e 20 (si entra camminando: niente spigolo che fa decollare).
        # Anche l'ultimo tratto, che finisce con un salto: partendo subito ripido, le sponde del canale si
        # piegavano all'indietro fino a 85 cm dietro l'imbocco (controllo di posizionamento, discesa_5_0)
        Ls = 1.2
        lung_ = [0.0]
        for i in range(1, len(pz)):
            lung_.append(lung_[-1] + math.hypot(pz[i].x - pz[i - 1].x, pz[i].y - pz[i - 1].y))
        m_ = (z0 - z_fine) / max(lung_[-1] - Ls / 2, 0.1)
        for i, s_l in enumerate(lung_):
            pz[i].z = z0 - (m_ * s_l * s_l / (2 * Ls) if s_l < Ls else m_ * (s_l - Ls / 2))
        fine = pz[-1]
        tg = pz[-1] - pz[-2]
        tg.z = 0
        tg.normalize()
        arrivo = fine + tg * (dd + 1.0)
        arrivo.z = (verso_pedana[1] if verso_pedana else FONDO)
        s_ = dict(tipo=tipo, larghezza=round(dd, 2), dislivello=round(h, 2), da=fine, a=arrivo,
                  v_minima=round(dd / math.sqrt(2 * h / 9.81), 2))
        return pz, s_, tg

    discesa, salti, tappe = [], [], []
    for (t0, L0, t1, L1, buchi, alza, mat) in (
            ('NO', 0.0, 'NE', -3.0, [(90.0, 0.8, 0.8, 'salto')], 0.0, 'tsc_rosso'),
            ('NE', -3.0, 'SE', -6.0, [(0.0, 1.1, 0.85, 'salto')], 0.5, 'tsc_giallo'),
            ('SE', -6.0, 'SO', -9.0, [(270.0, 1.4, 0.9, 'salto')], 0.0, 'tsc_blu'),
            ('SO', -9.0, 'NO', -12.0, 'getto', 0.0, 'tsc_turchese'),
            ('NO', -12.0, 'NE', -15.0, 'getto', 0.0, 'tsc_arancio'),
            ('NE', -15.0, None, FONDO, 'getto', 0.0, 'tsc_viola')):
        if buchi == 'getto':
            # i due col getto finiscono sopra una pedana lontana (il secondo più lungo); l'ultimo tratto è un
            # salto normale che finisce nella vasca del fondo, sul lato est
            if t1:
                pz, s_, tg = getto_lungo(t0, L0, 3.8 if t1 == 'NO' else 4.2, 1.5, (t1, L1))
            else:
                pz, s_, tg = getto_lungo(t0, L0, 2.2, 1.7, None, -1, 2.0, 'salto')
            pezzi, ss = [pz], [s_]
            for q in pz:
                pass
            sp.discesa.append(pz)
            P.CANALI.append(pz)
            apri(t0, L0, pz, 2.0)
            if t1:
                # la ringhiera della pedana d'arrivo si apre dove arriva il volo
                volo = [s_['a'] - tg * (j * 0.25) for j in range(int((s_['larghezza'] + 1.0) / 0.25) + 1)]
                apri(t1, L1, volo, 2.2)
            if t1 is None:
                # la vasca del fondo dove si atterra col getto (senza, si cade sul pavimento prima)
                c0 = s_['da'] + tg * 3.0
                # nel gioco arriva a nord fin sotto la bocca dell'inseguimento: dall'acqua si sale nel tubo
                VASCHE['fondo'] = (max(c0.x - 2.8, 30.0), max(c0.y - 2.8, 11.1), min(c0.x + 2.8, XI1 - 0.3),
                                   min(max(c0.y + 2.8, BOCCA_Y + 1.2) if GIOCO else c0.y + 2.8, 18.6))
                x0, y0, x1, y1 = VASCHE['fondo']
                sp.scatola(x0, y0, FONDO, x1, y1, FONDO + 0.7, 'vasca_fondo')
        else:
            pezzi, ss = tratto_discesa(t0, L0, t1, L1, buchi, alza)
        discesa.append(('scivolo', pezzi, mat))
        tappe.append((t0, L0, t1, L1))
        salti += ss
    spirale = []
    spir = discesa[-1][1][-1]
    # la discesa non deve toccare i tralicci
    for pz in sp.discesa:
        for q in pz:
            for t in ORDINE:
                cc = centro(t)
                d = max(abs(q.x - cc.x), abs(q.y - cc.y))
                assert d > NUCLEO + 0.2 + LARGO_D, f'la discesa tocca il traliccio {t} in {tuple(round(v, 1) for v in q)}'
    # le piattaforme che la discesa attraversa senza fermarsi non si fanno (niente capi di scivoli lì)
    vietati = set(DISCESA_PONTI)     # (e sulle pedane della discesa si cammina: niente bocche di decorativi)
    for t in ORDINE:
        r = ponte(t, 0)
        for L in LIVELLI:
            if (t, L) in DISCESA_PONTI:
                continue
            if any(dentro_rett(q, r, -1.0) and L - 3.0 < q.z < L + 2.8 for pz in sp.discesa for q in pz):
                vietati.add((t, L))
    print('salti:', [(s_['tipo'], s_['larghezza'], s_['dislivello'], s_['v_minima']) for s_ in salti])

    # le tappe: le pedane d'arrivo (checkpoint), i salti, la Polaroid, il fondo
    percorso.append(('portone', Vector((XI0 + 0.5, 15.0, 0.0))))
    nomi_arrivo = ['pedana NE -3', 'vasca intermedia', 'pedana SO -9', 'polaroid 10', 'pedana NE -15', 'fondo']
    for k, (_, pezzi, mat) in enumerate(discesa):
        for j, pz in enumerate(pezzi):
            if j >= 1:
                percorso.append((salti[sum(len(d[1]) - 1 for d in discesa[:k]) + j - 1]['tipo'], pz[0]))
            percorso += [('scivolo', p) for p in pz[::5]]
            percorso.append(('scivolo', pz[-1]))
        if k < len(discesa) - 1:
            percorso.append((nomi_arrivo[k], pezzi[-1][-1]))
    percorso.append(('fondo', spir[-1]))


    # --- gli altri scivoli: si scelgono da soli --------------------------------------------------------
    candidati = []
    for t in ORDINE:
        for L in LIVELLI:
            for verso in (-1, 1):
                for passi in (1, 2, 4, 5):
                    for banda in BANDE:
                        if passi >= 4 and banda > 6.6:
                            continue
                        for chiuso in (True, False):
                            candidati.append(('torre', t, L, verso, passi, banda, chiuso))
            for muro in ('n', 's', 'o', 'e'):
                candidati.append(('muro', t, L, muro, 0, 0, True))
            if L <= -9:
                for v in VASCHE:
                    candidati.append(('vasca', t, L, v, 0, 0, True))
    rnd.shuffle(candidati)
    scelti = []
    conta = {}
    TETTO = {'spirale': 4, 'vasca': 4, 'muro': 7}

    def nella_caduta(pts, mezza):
        """Vero se il pezzo passa sotto un salto, nei 5 m dove cade chi lo sbaglia: lì c'è la vasca di
        raccolta (V1, scelta dell'utente del 21 ottobre) e nessuno scivolo deve fermare la caduta prima."""
        for k_, s_ in enumerate(salti[:5]):
            da, a = s_['da'], s_['a']
            m = (da + a) / 2
            dv = Vector((a.x - da.x, a.y - da.y, 0)).normalized()
            dl = Vector((-dv.y, dv.x, 0))
            z_s = min(da.z, a.z)
            # la zona dove si cade e, fino al lato della pedana di partenza, dove va la vasca con la scaletta
            zona = [m + dv * 1.5 + dl * 1.2, m + dv * 1.5 - dl * 1.2, m - dv * 1.5 + dl * 1.2, m - dv * 1.5 - dl * 1.2]
            t0_, L0_ = tappe[k_][0], tappe[k_][1]
            x0_, y0_, x1_, y1_ = ponte(t0_, L0_)
            # (fino al posto della scaletta sul lato della pedana di partenza: il primo libero dalle aperture,
            # come in vasche_raccolta)
            fuori = {'e': m.x - x1_, 'o': x0_ - m.x, 'n': m.y - y1_, 's': y0_ - m.y}
            lato_ = max(fuori, key=fuori.get)
            lungo_x_ = lato_ in 'ns'
            lo_, hi_ = (x0_, x1_) if lungo_x_ else (y0_, y1_)
            bordo_ = {'e': x1_, 'o': x0_, 'n': y1_, 's': y0_}[lato_]
            ap_ = [x for x in aperture.get((t0_, L0_), []) if x[0] == lato_]
            posti_ = [lo_ + 0.7 + 0.1 * i for i in range(int((hi_ - lo_ - 1.4) / 0.1) + 1)
                      if all(0.7 + 0.1 * i < a0 - 0.6 or 0.7 + 0.1 * i > a1 + 0.6 for (_, a0, a1) in ap_)]
            u_m_ = m.x if lungo_x_ else m.y
            u_s = min(posti_, key=lambda q: abs(q - u_m_)) if posti_ else u_m_
            scala_ = [(u_s - 0.6, bordo_), (u_s + 0.6, bordo_)] if lungo_x_ else [(bordo_, u_s - 0.6), (bordo_, u_s + 0.6)]
            xs_ = [q.x for q in zona] + [p_[0] for p_ in scala_]
            ys_ = [q.y for q in zona] + [p_[1] for p_ in scala_]
            for q in pts:
                if min(xs_) - mezza < q.x < max(xs_) + mezza and min(ys_) - mezza < q.y < max(ys_) + mezza and z_s - 5.0 < q.z < z_s:
                    return True
        return False
    for cand in candidati:
        if len(scelti) >= QUANTI:
            break
        tipo, t, L, x, passi, banda, chiuso = cand
        mezza = M_CHIUSO if chiuso else M_APERTO
        genere = 'spirale' if (tipo == 'torre' and passi >= 4) else tipo
        if conta.get(genere, 0) >= TETTO.get(genere, 99):
            continue
        i0 = ORDINE.index(t)
        if tipo == 'torre':
            verso = x
            t1 = ORDINE[(i0 - verso * passi) % 4]       # in senso orario l'indice cresce
            L1 = L - 3.0 * (passi if passi < 4 else passi - 2)
            if L1 < LIVELLI[-1]:
                continue
            a0 = angolo_capo(t, banda, verso, mezza)
            a1 = angolo_capo(t1, banda, -verso, mezza)
            if a0 is None or a1 is None:
                _no('capo'); continue
            giro = 90.0 * passi
            a1 = a0 + verso * (giro - abs(a1 - TORRI[t1]) - abs(a0 - TORRI[t]))
            pts = arco(banda, banda, a0, a1, z_capo(L, chiuso), z_capo(L1, chiuso))
            esenti = (f'ponte_{t}_{L:g}', f'ponte_{t1}_{L1:g}')
            capi = [(t, L), (t1, L1)]
            muro_fine = False
        elif tipo == 'muro':
            muro = x
            ang_muro = {'n': 90.0, 's': 270.0, 'o': 180.0, 'e': 0.0}[muro]
            d = TORRI[t] - ang_muro
            d = (d + 180) % 360 - 180
            if abs(d) > 60:
                continue
            verso = -1 if d > 0 else 1
            banda = rnd.choice([6.3, 8.3, 9.0])
            a0 = angolo_capo(t, banda, verso, mezza)
            if a0 is None:
                continue
            dist_muro = {'n': YI1 - C[1], 's': C[1] - YI0, 'o': C[0] - XI0, 'e': XI1 - C[0]}[muro] + 0.8
            a1 = ang_muro + rnd.uniform(-12, 12)
            r1 = dist_muro / max(0.35, abs(math.cos(math.radians(a1 - ang_muro))))
            pts = arco(banda, r1, a0, a1, z_capo(L, True), z_capo(L, True) - rnd.uniform(1.5, 3.0))
            esenti = (f'ponte_{t}_{L:g}',)
            capi = [(t, L)]
            muro_fine = True
            # al contrario, a volte: il tubo esce dal muro e arriva sulla piattaforma
            if rnd.random() < 0.5:
                pts = arco(r1, banda, a1, a0, z_capo(L, True) + rnd.uniform(1.5, 3.0), z_capo(L, True))
                pts = pts[::-1]          # i controlli vogliono il muro alla fine
        else:   # vasca del fondo
            v = x
            x0, y0, x1, y1 = VASCHE[v]
            pv = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 0))
            av = math.degrees(math.atan2(pv.y - C[1], pv.x - C[0]))
            r_v = math.hypot(pv.x - C[0], pv.y - C[1])
            d = (av - TORRI[t] + 180) % 360 - 180
            verso = 1 if d > 0 else -1
            giro = abs(d) + (360.0 if rnd.random() < 0.5 else 0.0)
            banda = rnd.choice([5.6, 6.3, 8.3])
            a0 = angolo_capo(t, banda, verso, mezza)
            if a0 is None:
                continue
            pts = arco(banda, r_v, a0, TORRI[t] + verso * giro, z_capo(L, True), FONDO + 0.9)
            esenti = (f'ponte_{t}_{L:g}', f'vasca_{v}')
            capi = [(t, L)]
            muro_fine = False
        if any(c_ in vietati for c_ in capi):
            _no('pedana attraversata dalla discesa'); continue
        pend, lung = pendenza(pts)
        pend = abs(pend)
        if not (0.07 < pend < (0.6 if chiuso else 0.45)) or lung < 4.0:
            _no(f'pendenza {tipo}'); continue
        if nella_caduta(pts, mezza):
            _no('zona di caduta di un salto'); continue
        if not sp.libero(pts, mezza, esenti, muro_fine):
            continue
        sp.deco.append((pts, mezza))
        P.DECO.append((pts, mezza))
        scelti.append((cand, pts, capi))
        conta[genere] = conta.get(genere, 0) + 1
    print('scivoli decorativi scelti:', len(scelti), 'su', len(candidati), 'candidati; tipi:', conta, 'scarti:', MOTIVI)

    # --- costruzione degli scivoli ------------------------------------------------------------------
    oggetti_scivoli = []
    ostacoli = []                      # per chi cammina sulle pedane (video, IA): [x, y, quota, mezzo lato]
    ostacoli_imbuti = []
    colori = list(COLORI)
    canali_discesa = []
    for k, (_, pezzi, mat) in enumerate(discesa):
        # l'imbuto davanti all'imbocco: sponde svasate sulla pedana che portano dentro il canale anche chi
        # arriva spostato o storto (insieme alla guida di SalaTorre nei primi metri)
        imbuto(c, pezzi[0], tappe[k][0], tappe[k][1], mat, ostacoli_imbuti)
        for j, pz in enumerate(pezzi):
            cd = K.Costruttore(mats)
            scivolo_discesa(cd, pz, mat)
            # solo da vedere: la collisione la fa SalaTorre dalla linea del fondo (come la prova di grafica)
            canali_discesa.append(cd.crea(f'discesa_{k}_{j}', sporco=lambda co: 0.75))
    for j, (cand, pts, capi) in enumerate(scelti):
        tipo, t, L, x, passi, banda, chiuso = cand
        if chiuso:
            if rnd.random() < 0.45:
                m = list(rnd.choice(STRISCE))
            else:
                m = [rnd.choice(colori[:-1])]
            TUBI_CHIUSI.append((pts, K.SCIVOLO_R + K.SCIVOLO_SPESSORE))
            oggetti_scivoli.append(K.tubo_scivolo(mats, pts, nome=f'torre_scivolo_{j}' + ('-col' if GIOCO else ''), materiali=m, seg=18,
                                                  passo_flange=1.6 if len(m) > 1 else 2.5))
        else:
            scivolo_aperto(cs, pts, rnd.choice(colori[:-1]))
        for (tt, LL) in capi:
            dal_capo = pts if (tt, LL) == capi[0] else pts[::-1]
            apri(tt, LL, dal_capo)
            # la bocca sulla pedana è chiusa (cancello o grata): i decorativi non si percorrono, sarebbero
            # scorciatoie per saltare i salti della discesa
            chiusa_bocca(c, dal_capo, chiuso, LL)
            ostacoli.append([round(dal_capo[0].x, 2), round(dal_capo[0].y, 2), LL, 1.0])
    # travature: sotto tutto, tranne sopra le piattaforme dei capi
    rett_ponti = [ponte(t, 0) for t in ORDINE]
    ct = K.Costruttore(mats)           # travature sotto gli scivoli (a parte: torre_sostegni.py le conta col pezzo)
    for _, pezzi, _m in discesa:
        for pz in pezzi:
            travatura(ct, pz, False, rett_ponti, 'metallo', LARGO_D, PROF_D)
    for cand, pts, capi in scelti:
        travatura(ct, pts, cand[6], rett_ponti, rnd.choice(['metallo', 'metallo_grigio']))
    mensole_su = {}                    # id(punti) -> indici dei punti retti da una mensola
    # mensole: dove uno scivolo passa accanto a un traliccio, un braccio lo regge
    for pts, mezza in [(p, M_DISCESA) for p in sp.discesa] + sp.deco:
        for t in ORDINE:
            cc = centro(t)
            # (non ai capi del pezzo: nei salti ci si atterrerebbe sopra)
            vicini = [(max(abs(p.x - cc.x), abs(p.y - cc.y)), i) for i, p in enumerate(pts) if 5 <= i < len(pts) - 5]
            if not vicini:
                continue
            dmin, i = min(vicini)
            if NUCLEO + mezza + 0.2 < dmin < NUCLEO + mezza + 1.6 and not dentro_rett(pts[i], ponte(t, 0)):
                p = pts[i]
                du = (R_GROVIGLIO + 0.07) if mezza < 0.8 else (PROF_D if mezza > M_APERTO else PROF) + 0.1
                q = Vector((min(max(p.x, cc.x - NUCLEO), cc.x + NUCLEO), min(max(p.y, cc.y - NUCLEO), cc.y + NUCLEO), p.z - du - 0.1))
                c.cilindro(q, Vector((p.x, p.y, q.z)), 0.08, 'metallo', seg=8)
                c.cilindro(Vector((q.x, q.y, q.z - 1.0)), Vector((p.x, p.y, q.z)), 0.05, 'metallo', seg=6)
                mensole_su.setdefault(id(pts), []).append(i)
    # la spirale finale ha i suoi piloni dove sotto non passa niente
    tutta = [q for pz in spirale for q in pz]
    for pz in spirale:
        for i in range(6, len(pz) - 4, 14):
            p = pz[i]
            if all(not (math.hypot(q.x - p.x, q.y - p.y) < 1.4 and q.z < p.z - 0.5) for q in tutta) and \
                    not dentro_rett(p, VASCHE['fondo'], -0.5):
                z1 = p.z - PROF_D - 0.12
                c.cilindro((p.x, p.y, FONDO), (p.x, p.y, z1), 0.18, 'gioco_giallo', seg=14)
                c.anello((p.x, p.y, FONDO), (0, 0, 1), 0.0, 0.36, 0.04, 'metallo', seg=14)
                c.scatola((p.x - 0.4, p.y - 0.4, z1 - 0.06), (p.x + 0.4, p.y + 0.4, z1), 'metallo')

    # --- vasche di raccolta sotto i salti, con la scaletta di servizio (V1) ------------------------------
    cl = K.Costruttore(mats)           # scalette di servizio delle vasche: solo da vedere
    raccolta, acque_raccolta = vasche_raccolta(c, cl, sp, salti, tappe, aperture)

    # --- torri, piattaforme, ringhiere, scale ---------------------------------------------------------
    # piattaforme solo dove parte o arriva uno scivolo (scelta dell'utente del 18 ottobre: "solo dove servono")
    servono = set(DISCESA_PONTI)
    for cand, pts, capi in scelti:
        servono.update(capi)
    print('piattaforme:', len(servono), 'su', len(ORDINE) * len(LIVELLI))
    costruite = {}                     # (torre, L) -> rettangolo della pedana costruita
    for t in ORDINE:
        torre(c, t, VERNICI_TORRI[t], {L for (tt, L) in DISCESA_PONTI if tt == t})
        for L in LIVELLI:
            if (t, L) not in servono:
                continue
            r = ponte(t, L)
            costruite[(t, L)] = r
            ap = list(aperture.get((t, L), []))
            if (t, L) not in DISCESA_PONTI:
                # solo scivoli decorativi: una pedana piccola attaccata al traliccio, grande quanto serve
                cc = centro(t)
                xs, ys = [cc.x - NUCLEO, cc.x + NUCLEO], [cc.y - NUCLEO, cc.y + NUCLEO]
                for pts_ in capi_pts.get((t, L), []):
                    xs += [pts_[0].x - 1.1, pts_[0].x + 1.1]
                    ys += [pts_[0].y - 1.1, pts_[0].y + 1.1]
                r = (max(r[0], min(xs)), max(r[1], min(ys)), min(r[2], max(xs)), min(r[3], max(ys)))
                costruite[(t, L)] = r
                ap = [a_ for a_ in (apertura(r, pts_) for pts_ in capi_pts.get((t, L), [])) if a_]
                P.piattaforma(c, r[0], r[1], r[2], r[3], L, lati=(), pali=False)
            if (t, L) == ('NO', -12.0) and PEDANA_NO12:
                pr = PEDANA_NO12
                P.piattaforma(c, pr[0], pr[1], pr[2], pr[3], L, lati=(), pali=False)
                ringhiere_ponte(c, pr, L, aperture.get(('pedana_no12', L), []))
                cc = centro(t)
                for (qx, qy) in ((pr[2] - 0.2, pr[3] - 0.2), (pr[2] - 0.2, pr[1] + 0.2), (pr[0] + 0.2, pr[1] + 0.2)):
                    a_ = Vector((cc.x + NUCLEO, cc.y - NUCLEO, L - 0.3))
                    c.cilindro(a_, (qx, qy, L - 0.25), 0.1, VERNICI_TORRI[t], seg=10)
                    c.cilindro(a_ - Vector((0, 0, 1.8)), (qx, qy, L - 0.3), 0.07, 'metallo', seg=8)
                ringhiere_ponte(c, r, L, ap)
                continue
            P.piattaforma(c, r[0], r[1], r[2], r[3], L, lati=(), pali=False)
            if t == 'NO':
                ap.append(('o', 0.0, 2.6))          # verso la scala
                if L == 0.0:
                    ap.append(('o', 0.0, 5.2))      # dalla passerella del portone
            if t == 'SE':
                ap.append(('s', 0.0, 2.6))
            ringhiere_ponte(c, r, L, ap)
    scala_servizio(c, sp, XI0 + 0.05, rno[1] + 0.2, 4.8, 'y', 1)
    scala_servizio(c, sp, rse[0] + 0.2, YI0 + 0.08, 4.8, 'x', 1)
    # passerella dal portone alla torre NO (a quota 0)
    P.piattaforma(c, XI0, 13.4, rno[0] + 0.05, 16.6, 0.0, lati=('s',), pali=False)
    P.piattaforma(c, rno[0] - 2.4, 16.6, rno[0] + 0.05, rno[1] + 0.05, 0.0, lati=('o',), pali=False)
    P.ringhiera_dritta(c, (XI0 + 0.3, 16.6, 0.0), (rno[0] - 2.4, 16.6, 0.0))
    P.mensola(c, 13.6, 16.4, XI0, 0.0, 'o')
    # il portale di partenza su ogni imbocco della discesa (senza le sbarre: si entra camminando nel canale).
    # Nel gioco ci sono su i led verdi e la lampada verde (S1, scelta dell'utente del 21 ottobre): li mette
    # SalaTorre dai dati in gioco['imbocchi']. Prima del 21 ottobre c'era solo sul primo.
    imbocchi = []
    for k_, (_, pezzi_, _m_) in enumerate(discesa if GIOCO else discesa[:1]):
        b0 = pezzi_[0][0]
        v0 = pezzi_[0][3] - b0
        v0.z = 0
        v0.normalize()
        t0v = Vector((-v0.y, v0.x, 0))
        base = Vector((b0.x, b0.y, tappe[k_][1] if k_ else 0.0))
        # i due pali sulla grata della pedana, 10 cm dentro il bordo: sul filo dell'imbocco quello di un lato stava
        # 23-32 cm fuori dalla pedana, sul vuoto (collaudo del 23 ottobre). Il portale arretra quanto basta
        def _su_pedana(q):
            return any(abs(L_ - base.z) < 0.05 and r[0] + 0.1 <= q.x <= r[2] - 0.1 and r[1] + 0.1 <= q.y <= r[3] - 0.1
                       for (_, L_), r in costruite.items())
        for indietro in (0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8):
            if all(_su_pedana(base - v0 * indietro + t0v * (s_ * (LARGO_D + 0.45))) for s_ in (-1, 1)):
                break
        base = base - v0 * indietro
        for s_ in (-1, 1):
            ap = base + t0v * (s_ * (LARGO_D + 0.45))
            c.cilindro(ap, ap + Vector((0, 0, 2.6)), 0.07, 'gioco_rosso', seg=12)
        c.cilindro(base - t0v * (LARGO_D + 0.45) + Vector((0, 0, 2.6)), base + t0v * (LARGO_D + 0.45) + Vector((0, 0, 2.6)), 0.07,
                   'gioco_rosso', seg=12)
        # nel gioco la fascia è liscia, del colore del portale: le strisce gialle e nere vogliono dire "chiuso" (S2)
        c.scatola_assi(base + Vector((0, 0, 2.85)), [v0, t0v, Vector((0, 0, 1))], (0.03, LARGO_D + 0.55, 0.22),
                       'gioco_rosso' if GIOCO else 'strisce')
        imbocchi.append(dict(base=[round(v, 3) for v in base], verso=[round(v0.x, 4), round(v0.y, 4)], mezza=LARGO_D + 0.45, alto=2.6))
    P.balconata(c, 28.6, 33.4, YI1, -1.5)
    # il fondo: pozzo, vasche, la bocca del tubo dell'inseguimento sul muro nord
    P.pozzo_lei(c, C)
    acque = []
    vf = VASCHE['fondo']
    for nome, (x0, y0, x1, y1) in VASCHE.items():
        if nome != 'fondo' and x0 < vf[2] + 0.5 and vf[0] < x1 + 0.5 and y0 < vf[3] + 0.5 and vf[1] < y1 + 0.5:
            continue    # la vasca del fondo prende il suo posto
        acque.append(P.vasca(c, x0, y0, x1, y1, FONDO, alto=0.6, nome_acqua=f'acqua_vasca_{nome}'))
    # la bocca del tubo grande dell'inseguimento: dal muro est, accanto alla vasca del fondo. Nel gioco sta a
    # nord dell'ultimo salto (in y 15 il salto le passava attraverso) e scende già dall'imbocco, di 11 gradi (meno
    # ripido, lasciando l'avanti, si scivola fuori all'indietro)
    yb_ = BOCCA_Y if GIOCO else 15.0
    bocca = [(XI1 + 1.0, yb_, FONDO + 1.4), (XI1 - 1.2, yb_, FONDO + 1.6), (XI1 - 2.4, yb_, FONDO + 1.6)] if not GIOCO else \
        [(XI1 + 1.0, yb_, FONDO + 1.4), (XI1 - 1.2, yb_, FONDO + 1.62), (XI1 - 2.4, yb_, FONDO + 1.85)]
    tubo_ins = K.tubo_scivolo(mats, bocca, nome='torre_tubo_inseguimento', materiali=['tsc_giallo'], r=0.8, spessore=0.06)
    TUBI_CHIUSI.append((bocca, 0.86))
    oggetti_scivoli.append(tubo_ins)
    if GIOCO:
        # il collare sul muro attorno al tubo (copre gli angoli del foro) e quattro gradini di grata nella vasca
        # sotto la bocca: dall'acqua si sale nel tubo
        cc = K.Costruttore(mats)       # solo da vedere: la collisione del tubo la fa il gioco
        cc.anello((XI1 - 0.08, BOCCA_Y, FONDO + 1.6), (1, 0, 0), 0.86, 1.48, 0.08, 'metallo', seg=32)
        oggetti_scivoli.append(cc.crea('torre_collare_inseguimento'))
        # (salgono verso nord, da sud; l'ultimo, largo quanto la bocca, arriva alla bocca 4 cm sopra il fondo del
        # tubo: si entra scendendo, senza il labbro del tubo che fa scivolare indietro)
        x0_, x1_, y1_ = 36.35, XI1 - 2.4, BOCCA_Y + 0.65
        for (y0_, zt) in ((BOCCA_Y - 2.4, FONDO + 0.28), (BOCCA_Y - 1.85, FONDO + 0.56), (BOCCA_Y - 1.3, FONDO + 0.84),
                          (BOCCA_Y - 0.75, FONDO + 1.12)):
            c.scatola((x0_, y0_, FONDO), (x1_, y1_, zt), 'metallo_grigio')
            q = [(x0_, y0_, zt + 0.002), (x1_, y0_, zt + 0.002), (x1_, y1_, zt + 0.002), (x0_, y1_, zt + 0.002)]
            P.GRATE[0].faccia(q, 'alfa_grata')
            P.GRATE[0].faccia(q[::-1], 'alfa_grata')
        # due selle dal fondo della vasca reggono il tubo dove esce dal muro (non sta a sbalzo)
        mw = tubo_ins.matrix_world
        fondo_tubo = [mw @ v.co for v in tubo_ins.data.vertices]
        for xs in (XI1 - 1.2, XI1 - 0.45):
            zs = min(q.z for q in fondo_tubo if abs(q.x - xs) < 0.15 and abs(q.y - yb_) < 0.6)
            c.scatola((xs - 0.1, yb_ - 0.3, FONDO), (xs + 0.1, yb_ + 0.3, zs - 0.08), 'metallo')
            c.scatola((xs - 0.12, yb_ - 0.55, zs - 0.08), (xs + 0.12, yb_ + 0.55, zs - 0.02), 'metallo')
    # tubi di servizio sui muri
    for z in (-17.0, -7.5, 4.5, 10.5):
        # (nel gioco da muro a muro: prima finivano 30 cm prima degli angoli, nel vuoto)
        e_ = 0.1 if GIOCO else -0.3
        P.tubo_muro(c, [(XI0 - e_, YI0 + 0.35, z), (XI1 + (e_ if GIOCO else -0.35), YI0 + 0.35, z)], r=0.16)
        P.tubo_muro(c, [(XI1 - 0.35, YI0 - e_ if GIOCO else YI0 + 0.35, z + 0.6), (XI1 - 0.35, YI1 + e_ if GIOCO else YI1 - 0.35, z + 0.6)], r=0.12)

    # --- sostegni: ogni pezzo retto ogni pochi metri e vicino ai capi liberi -------------------------------
    cv = K.Costruttore(mats)           # solo da vedere (nessuna collisione): non cambiano i salti
    costruite[('passerella', 0.0)] = (XI0, 13.4, rno[0] + 0.05, 16.6)
    pezzi_tutti = [(pz, M_DISCESA, False, LARGO_D, PROF_D, False, f'discesa_{k}_{j}')
                   for k, (_, pezzi, _m) in enumerate(discesa) for j, pz in enumerate(pezzi)]
    pezzi_tutti += [(pts, M_CHIUSO if cand[6] else M_APERTO, cand[6], LARGO, PROF, cand[0] == 'muro', f'deco_{j}')
                    for j, (cand, pts, capi) in enumerate(scelti)]
    voli = [(s_['da'], s_['a']) for s_ in salti]
    rapporto_sostegni = sostieni(cv, sp, pezzi_tutti, costruite, mensole_su, voli)
    linee_pezzi = [dict(nome=n_, mezza=m_, punti=[[round(v, 3) for v in q] for q in pts_])
                   for (pts_, m_, _c, _l, _p, _mu, n_) in pezzi_tutti]

    # --- prop: sulle piattaforme lontano dai capi degli scivoli, e sul fondo ---------------------------
    props = []
    capi_ponti = {}
    for _, pezzi, _m in discesa:
        for pz in pezzi:
            capi_ponti.setdefault('x', []).extend([pz[0], pz[-1]])
    for cand, pts, capi in scelti:
        capi_ponti['x'].extend([pts[0], pts[-1]])
    tutti_capi = capi_ponti['x']
    scelta_prop = ['salvagente_nave', 'ciambella_gonfiabile', 'cestino_pesce', 'tubi_galleggianti',
                   'pallone_spiaggia', 'cartello_pavimento_bagnato', 'paperella_gigante']
    usati_ponti = set()
    # sulle pedane della discesa si cammina dall'arrivo all'imbocco dopo, girando attorno al traliccio dalla
    # parte più corta: i prop (e il lettino della Polaroid) vanno nell'angolo più lontano da tutti e due
    arrivi, partenze = {}, {}
    for k, (t0, L0, t1, L1) in enumerate(tappe):
        partenze[(t0, L0)] = discesa[k][1][0][0]
        if t1:
            s_fine = [s_ for s_ in salti if (s_['da'] - discesa[k][1][-1][-1]).length < 0.01]
            arrivi[(t1, L1)] = s_fine[0]['a'] if s_fine else discesa[k][1][-1][-1]
    arrivi[('NO', 0.0)] = Vector((rno[0], rno[1] + 0.6, 0.0))      # dalla scala e dalla passerella

    def angolo_libero(t, L, rientro=1.15):
        cc = centro(t)
        punti = [q for q in (arrivi.get((t, L)), partenze.get((t, L))) if q is not None]
        angoli = [Vector((cc.x + sx * (PONTE - rientro), cc.y + sy * (PONTE - rientro), L)) for sx in (-1, 1) for sy in (-1, 1)]
        return max(angoli, key=lambda q: min(math.hypot(q.x - a_.x, q.y - a_.y) for a_ in punti))
    angoli_prop = {}
    for (t, L) in sorted(DISCESA_PONTI):
        p = angolo_libero(t, L)
        angoli_prop[(t, L)] = p
        if (t, L) in (('NO', -12.0), ('NO', 0.0)):
            continue        # lì ci sono il lettino della Polaroid e il cartello
        # (nel gioco sul grigliato della pedana, 1 cm sotto il suo piano: a L restavano sospesi)
        props.append(P.prop(rnd.choice(scelta_prop), (p.x, p.y, L - (0.01 if GIOCO else 0.0)), rnd.uniform(0, 360)))
        usati_ponti.add((t, L))
    # la Polaroid 10 sul lettino della piattaforma NO a -12, nell'angolo fuori dal passaggio
    cno = centro('NO')
    pl = angoli_prop[('NO', -12.0)]
    # nel gioco il lettino sul grigliato (1 cm sotto il piano) e la Polaroid sul lettino (prima 2,1 cm sopra)
    z_let = -12.0 - (0.0104 if GIOCO else 0.0)
    z_pol = -12.0 + 0.36 - (0.0104 + 0.0206 if GIOCO else 0.0)
    props.append(P.prop('lettino_plastica', (pl.x, pl.y, z_let), 90))
    polaroid_pos = Vector((pl.x, pl.y, z_pol))
    c2 = K.Costruttore(mats)
    P.polaroid(c2, Vector((pl.x, pl.y, z_pol)), Vector((1, 0, 0)))
    pol = c2.crea('torre_polaroid_10')
    cart = angoli_prop[('NO', 0.0)]
    props += [P.prop('cartello_pavimento_bagnato', (cart.x, cart.y, -(0.0103 if GIOCO else 0.0)), 30)]
    fondo = [('sedia_bagnino', (29.4, 9.9), 0), ('lettino_plastica', (21.2, 9.0), 90), ('lettino_plastica', (21.2, 10.8), 95),
             ('balena_gonfiabile_sgonfia', (30.0, 21.6), 15), ('delfino_gonfiabile_sgonfio', (25.6, 4.9), 120),
             ('pallone_spiaggia', (27.0, 12.6), 0), ('secchio_gigante', (32.6, 9.6), 30),
             ('cestino_pesce', (39.4, 11.6), 200), ('cannoncino_acqua', (24.2, 11.5), 300), ('salvagente_nave', (24.4, 4.6), 80),
             ('cartello_pavimento_bagnato', (28.0, 18.2), 140), ('tubi_galleggianti', (27.4, 24.8), 10),
             ('ciambella_gonfiabile', (36.9, 11.9, FONDO + 0.6 - 0.2) if GIOCO else (38.6, 16.6, FONDO + 0.6 - 0.2), 70), ('ciambella_gonfiabile', (30.0, 5.8, FONDO + 0.6 - 0.2), 10),
             ('orsacchiotto_grande', (20.9, 19.0), 100)]
    # (nel gioco la ciambella galleggia nella vasca del fondo, in un angolo lontano dall'atterraggio e dal tubo:
    # in (38,6, 16,6) era per la vasca est, che lì non c'è, e restava sospesa)
    for nome, pos, rot in fondo:
        z = pos[2] if len(pos) > 2 else FONDO
        props.append(P.prop(nome, (pos[0], pos[1], z), rot))
    if GIOCO:
        # nel gioco i prop sono solidi: una scatola convessa sui limiti di ciascuno (come in ambiente_sala)
        for o in props:
            if o.name.startswith('prop_') and o.type == 'MESH':
                me = o.data
                xs = [v.co.x for v in me.vertices]; ys_ = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
                cb = K.collisione_scatola(o.name, (min(xs), min(ys_), min(zs)), (max(xs), max(ys_), max(zs)), padre=o)
                cb.hide_render = True
    # cartelloni dipinti sui muri, tra le costole
    for i, (pos, rot, graf) in enumerate((((32.0, YI1 - 0.005, 6.5), 0, 'p1'), ((32.0, YI0 + 0.005, -4.5), 180, 'p2'),
                                          ((24.0, YI0 + 0.005, 8.0), 180, 'p3'), ((36.0, YI1 - 0.005, -12.0), 0, 'p1'))):
        cart = K.cartellone(mats, 3.2, 1.8, nome=f'torre_cartellone_{i}')
        cart.location = Vector(pos)
        cart.rotation_euler = (0, 0, math.radians(rot))
        for j, m in enumerate(cart.data.materials):
            if m and m.name.startswith('M_amb_cartellone'):
                cart.data.materials[j] = mats.get('cartellone_' + graf)
        props.append(cart)

    # --- luci (le mette lo script degli scatti) -------------------------------------------------------
    for (t, L) in [('NO', 0.0), ('NE', -3.0), ('SE', -6.0), ('SO', -9.0), ('NO', -12.0), ('NE', -15.0)] + \
            [tl for tl in sorted(usati_ponti) if tl[1] in (9.0, 3.0, -9.0, -18.0)][:6]:
        cc = centro(t)
        sx = 1 if (TORRI[t] % 360) in (45.0, 315.0) else -1
        sy = 1 if (TORRI[t] % 360) in (45.0, 135.0) else -1
        if (t, L) in costruite and dentro_rett(Vector((cc.x + sx * (PONTE - 0.1), cc.y + sy * (PONTE - 0.1), 0)), costruite[(t, L)], -0.05):
            luci['lavoro'].append([cc.x + sx * (PONTE - 0.1), cc.y + sy * (PONTE - 0.1), L + 1.25, 'palo'])
    luci['lavoro'].append([31.0, YI1 - 0.35, -1.5 + 2.45, 'muro_n'])     # sopra la porta della balconata dei bambini
    # fari sui tralicci: ognuno punta il centro di uno scivolo dall'altra parte della sala, più in basso
    medi = [pts[len(pts) // 2] for _, pts, _ in scelti] + [pz[len(pz) // 2] for _, pezzi, _ in discesa for pz in pezzi]
    usati = set()
    for t in ORDINE:
        cc = centro(t)
        for zf in (H - 0.6, 1.5, -10.5):
            p = Vector((cc.x, cc.y, zf))
            buoni = [(abs((m.z - (zf - 7.0))), i) for i, m in enumerate(medi) if i not in usati
                     and (Vector((m.x, m.y, 0)) - Vector((cc.x, cc.y, 0))).length > 8.0 and m.z < zf - 1.0]
            if not buoni:
                continue
            _, i = min(buoni)
            usati.add(i)
            # sulla colonna del traliccio dalla parte dello scivolo, con un braccio corto
            m_ = medi[i]
            col = min((Vector((cc.x + sx * NUCLEO, cc.y + sy * NUCLEO, zf)) for sx in (-1, 1) for sy in (-1, 1)),
                      key=lambda q: math.hypot(q.x - m_.x, q.y - m_.y))
            dv = Vector((m_.x - col.x, m_.y - col.y, 0)).normalized()
            if GIOCO and zf < H - 1.0:
                # nel gioco i fari dei piani bassi stanno sopra i 2 m di chi cammina sulle pedane (a 1,5 m sopra il
                # piano passavano davanti alla faccia: collaudo del 22 sera)
                col = col + Vector((0, 0, 0.8))
            p = col + dv * 0.55
            luci['fari'].append([[p.x, p.y, p.z], [m_.x, m_.y, m_.z], [col.x, col.y, col.z]])
    em_ = 0.08 if GIOCO else 0.1      # (nel gioco il retto della scatola, 8 cm dietro il centro, sul muro)
    luci['emergenza'] = [[[XI0 + em_, 20.5, 6.0], 'e'], [[XI1 - em_, 15.0, 1.5], 'o'], [[31.0, YI0 + em_, -2.5], 'n'],
                         [[31.0, YI1 - em_, -8.0], 's'], [[XI0 + em_, 10.0, -12.0], 'e'], [[XI1 - em_, 15.0, -16.5], 'o'],
                         [[27.0, YI1 - em_, 9.0], 's']]
    for cand, pts, capi in scelti[::3]:
        luci['gocce'].append([pts[-1].x, pts[-1].y, pts[-1].z - 0.4])
    luci['lei'] = [C[0], C[1], FONDO]

    sporco = lambda co: 0.55 + 0.45 * min(1.0, max(0.0, (co.z - FONDO) / 8.0))
    suff = '-col' if GIOCO else ''
    gr = P.GRATE[0].crea('torre_A_grigliati' + suff)
    ob = c.crea('torre_A' + suff, sporco=sporco)
    ob_t = ct.crea('torre_A_travi' + suff, sporco=sporco)
    ob_v = cv.crea('torre_A_sostegni', sporco=sporco)
    ob_l = cl.crea('torre_A_scalette', sporco=sporco)
    bpy.context.scene['linee_pezzi'] = json.dumps(linee_pezzi)
    ob_s = cs.crea('torre_A_canali' + suff, sporco=lambda co: 0.75)
    # le pedane (grata e telaio), i tralicci, le travature e i sostegni intagliati sulla forma degli scivoli: dove uno
    # scivolo passa o appoggia, gli fanno posto (riscontro dell'utente sulla v0.3.11: "gli scivoli sono leggermente
    # compenetrati con le piattaforme su cui si appoggiano, quasi tutti")
    # (della struttura tutto: telai delle pedane, culle dei tubi, mensole, selle; meno i pezzi nei colori degli
    # scivoli: gli imbuti in fondo ai tratti continuano lo scivolo apposta)
    def non_scivolo(lo, hi, mats):
        return not any(m_.startswith('tsc_') for m_ in mats)
    intaglia([gr, ob, ob_t, ob_v], [ob_s] + canali_discesa + oggetti_scivoli, filtri={ob.name: non_scivolo}, aperti={gr.name},
             tubi_su={ob_t.name, ob_v.name})
    gruppi = {'struttura': [ob, ob_t, ob_v, ob_l, gr, pol] + acque + acque_raccolta, 'scivoli': [ob_s] + canali_discesa + oggetti_scivoli, 'prop': props}
    # per il gioco: checkpoint, salti, Polaroid, balconata, pozzo e vasca del fondo (coordinate di Blender)
    gioco = dict(checkpoint=[], salti=[], tratti=[])
    passerella = Vector((XI0 + 1.2, 15.0, 0.0))
    t0_ = discesa[0][1][0][1] - discesa[0][1][0][0]
    t0_.z = 0
    t0_.normalize()
    gioco['checkpoint'].append(dict(nome='portone', pos=list(passerella), spawn=list(passerella),
                                    guarda=list(passerella + Vector((1, 0, 0)))))
    arrivi = [(t1, L1) for (t0, L0, t1, L1) in tappe if t1]

    def salti_fine_tratto(k):
        # il salto col getto con cui finisce il tratto k (il capo è sopra il vuoto), o None
        n_prima = sum(len(d[1]) - 1 for d in discesa[:k]) + sum(1 for (t0_, L0_, t1_, L1_), d in zip(tappe[:k], discesa[:k]) if len(d[1]) == 1 and k and False)
        for s_ in salti:
            if s_['tipo'] == 'getto' and (s_['da'] - discesa[k][1][-1][-1]).length < 0.01:
                return s_
        return None
    for k, (_, pezzi, _m) in enumerate(discesa):
        fine = pezzi[-1][-1]
        if k < len(arrivi):
            t_arr, L = arrivi[k]
            # il checkpoint è dove arriva lo scivolo; si riparte un metro dietro l'inizio del tratto dopo, nella
            # sua direzione (così ci si entra camminando dritti)
            pos = Vector((fine.x, fine.y, L)) if salti_fine_tratto(k) is None else Vector((salti_fine_tratto(k)['a'].x, salti_fine_tratto(k)['a'].y, L))
            nuovo = discesa[k + 1][1][0]
            tang = nuovo[1] - nuovo[0]
            tang.z = 0
            tang.normalize()
            spawn = Vector((nuovo[0].x, nuovo[0].y, L)) - tang * 1.1
            cc = centro(t_arr)
            assert max(abs(spawn.x - cc.x), abs(spawn.y - cc.y)) > NUCLEO + 0.55, f'ripartenza dentro il traliccio {t_arr}'
            gioco['checkpoint'].append(dict(nome=f'{t_arr} {L:g}', pos=list(pos), spawn=list(spawn),
                                            guarda=list(spawn + tang * 3.0)))
        tg = pezzi[0][1] - pezzi[0][0]
        tg.z = 0
        tg.normalize()
        L0 = tappe[k][1]
        entra = Vector((pezzi[0][0].x, pezzi[0][0].y, L0)) - tg * 1.1
        # la linea del fondo di ogni pezzo (per la collisione, in Godot)
        linee = [[[round(v, 3) for v in (q - Vector((0, 0, PROF_D)))] for q in pz] for pz in pezzi]
        # i salti di questo tratto, in ordine: quelli tra i suoi pezzi e quello col getto alla fine (se c'è)
        fini = [pz[-1] for pz in pezzi]
        tipi = [s_['tipo'] for s_ in salti if any((s_['da'] - f_).length < 0.01 for f_ in fini)]
        gioco['tratti'].append(dict(pezzi=[f'discesa_{k}_{j}' for j in range(len(pezzi))], linee=linee, salti=tipi,
                                    da=list(pezzi[0][0]), a=list(fine), entrata=list(entra), verso=list(tg)))
    xv0, yv0, xv1, yv1 = VASCHE['fondo']
    gioco['checkpoint'].append(dict(nome='fondo', pos=[(xv0 + xv1) / 2, (yv0 + yv1) / 2, FONDO], guarda=[C[0], C[1], FONDO]))
    for s_ in salti:
        gioco['salti'].append(dict(tipo=s_['tipo'], larghezza=s_['larghezza'], dislivello=round(s_['dislivello'], 3),
                                   v_minima=s_['v_minima'], da=list(s_['da']), a=list(s_['a'])))
    gioco['polaroid_10'] = list(polaroid_pos)
    gioco['balconata'] = dict(centro=[31.0, YI1 - 0.8, -1.5], primo_salto=list(salti[0]['da']))
    gioco['pozzo'] = [C[0], C[1], FONDO]
    gioco['vasca_fondo'] = dict(rett=[xv0, yv0, xv1, yv1], acqua=FONDO + 0.6 - 0.12)
    gioco['raccolta'] = raccolta
    gioco['imbocchi'] = imbocchi
    gioco['bocche_chiuse'] = [dict(pos=p_, verso=d_, tubo=ch_) for p_, d_, ch_ in BOCCHE_CHIUSE]
    gioco['passerella'] = list(passerella)
    gioco['pedane'] = [[round(v, 2) for v in r] + [L] for (t, L), r in sorted(costruite.items(), key=lambda kv: (kv[0][1], kv[0][0]))]
    # i pianerottoli delle due scale di servizio (alla quota di ogni livello, accanto alle pedane)
    for L in LIVELLI:
        gioco['pedane'].append([round(XI0 + 0.05, 2), round(rno[1] + 0.2, 2), round(XI0 + 0.05 + 2.2, 2), round(rno[1] + 0.2 + 1.2, 2), L, 'scala'])
        gioco['pedane'].append([round(rse[0] + 0.2, 2), round(YI0 + 0.08, 2), round(rse[0] + 0.2 + 1.2, 2), round(YI0 + 0.08 + 2.2, 2), L, 'scala'])
    gioco['ostacoli'] = ostacoli + ostacoli_imbuti
    luci['gioco'] = gioco
    return gruppi, percorso_gioco(gioco), luci
