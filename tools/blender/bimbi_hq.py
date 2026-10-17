"""Area bimbi in alta definizione (proposta del 16 ottobre, crediti Meshy rimasti): la struttura di gioco, il
secchio gigante e i funghi-fontana rifatti con Meshy (assets_src/ambiente/bimbi_hq/, vedi genera.py lì) al
posto di quelli di oggi, nella disposizione 1 approvata. Solo proposta: la sala del gioco non cambia finché
l'utente non sceglie. Lo usano ambiente_sala_bimbi_hq.py (la sala per Godot, per gli scatti) e
bimbi_hq_render.py (i render dei modelli).

Due versioni della struttura:
  - FEDELE (la proposta principale): la struttura di oggi divisa in 4 moduli (torre verde con la scala e la
    passerella, torre arancio con lo scivolo, torre rossa con la passerella, torre del secchio con il telaio,
    il tubo e il ponte). Ogni modulo Meshy è nato da un render grezzo del modulo di oggi (blockout.py) e qui
    torna esattamente nei suoi limiti (rotazione trovata con orienta, poi scala per asse): stesso ingombro,
    stessa composizione, stesse collisioni.
  - VARIANTE: la struttura disegnata da capo dal disegno d'insieme (4 torri, telaio a portale), più corta
    verso nord; misure prese dai vertici del modello (Z in alto, metri, dopo la rotazione, rispetto al
    centro dei limiti): torre verde x -4,1..-2,3 y -2,8..-1,0 (pedana a 1,24 m); rossa x -4,2..-2,2 y 0..1,8
    (2,72 m); arancio x -1,1..0,8 y 0..1,8 (1,71 m) con lo scivolo fino a x 4,26 (y 0,07..1,39); torre del
    secchio x -2,1..-0,3 y 1,5..3,2 (4,07 m) con il telaio a portale (pali a x -2,2 e -0,15, cuscinetti
    interni a x -2,02 e -0,38, asse a y 2,26, z 6,65). Centro in (-14,0; 17,5): lo scivolo passa sopra il
    bordo della vasca piccola (0,45 m) dove il fondo è a 0,55-0,6 m e finisce dentro.
Il secchio è lo stesso nelle due versioni, grande come quello di oggi (diametro 1,5 m, alto 1,6 m), con il
perno sui mozzi (asse x).
"""
import math, os
import bpy
from mathutils import Vector, Matrix

QUI = os.path.dirname(os.path.abspath(__file__))
HQ = os.environ.get('BIMBI_HQ', os.path.normpath(os.path.join(QUI, '..', '..', 'assets_src', 'ambiente', 'bimbi_hq')))
GREZZI = os.environ.get('BIMBI_HQ_GREZZI', os.path.join(HQ, 'grezzi_4k'))   # GLB 4K di Meshy (scaricati il 17 ottobre)

# --- versione fedele: centro della struttura di oggi (STRUTTURA di ambiente_sala.py, disposizione 1) e, per
# ogni modulo, rotazione del modello Meshy e limiti locali della parte di oggi che sostituisce
CENTRO_FEDELE = (-14.6, 19.6)
MODULI_FEDELI = {
    'verde': (0, (-4.05, -4.938, 0.0), (-1.0, 0.25, 4.4)),       # IoU 0,61, scale per asse entro il 5%
    'arancio': (90, (-1.25, -2.65, 0.0), (5.012, 0.25, 5.6)),   # IoU 0,66 (base a 0: i pali non entrano nel pavimento)
    'rossa': (90, (-4.05, 0.15, 0.0), (-1.0, 3.05, 5.6)),        # IoU 0,76
    'secchio': (0, (-1.4, -0.6, 0.0), (2.17, 3.23, 8.26)),       # IoU 0,40 (telaio sottile)
}
PERNO_FEDELE = (0.2, 1.53, 7.46)   # l'asse del telaio Meshy (oggi il perno è a (0,2; 1,6; 7,1)): il secchio ci
                                   # sta appeso, 36 cm più in alto di oggi; il resto del telaio non lo tocca
# lo scivolo di Meshy scende più ripido di quello di oggi e taglierebbe il bordo della vasca piccola (alto 0,45 m,
# x locale 3,3..3,6): tra x 2,4 e 4,7 il fondo sale di 0,25 m al massimo (profilo che scende sempre: circa 0,75 m a
# x 3,3, 0,6 a 3,6, 0,1 a 4,3, la fine resta sul fondo della vasca)
SCIVOLO_ALZA = dict(x0=2.4, x1=4.7, alto=0.25)

# --- variante
VARIANTE = dict(file='struttura_variante', rot_z=90.0, alto=8.2, centro=(-14.0, 17.5))
PEDANE_VARIANTE = {   # nome: (x0, y0, x1, y1, quota del piano di calpestio), rispetto al centro
    'verde': (-4.15, -2.85, -2.25, -0.95, 1.24),
    'arancio': (-1.10, -0.05, 0.80, 1.80, 1.71),
    'rossa': (-4.25, -0.10, -2.20, 1.85, 2.72),
    'secchio': (-2.15, 1.50, -0.25, 3.20, 4.07),
}
PERNO_VARIANTE = (-1.20, 2.26, 6.65)                          # centro dell'asse tra i cuscinetti
TAGLIO_ASSE = ((-1.90, 2.00, 6.35), (-0.50, 2.52, 6.95))     # la barra dell'asse dentro il secchio (si toglie)

FUNGO_HD = 'fungo_fontana'
SECCHIO_HD = 'secchio_gigante'
SECCHIO_MISURE = dict(alto=1.6, diametro=1.5)                # come il secchio di oggi (Meshy del 15 ottobre)


def file_hq(nome, grezzo=False):
    """GLB di un modello HQ: quello del repository (texture 2K) o il 4K scaricato (solo per i render)."""
    if grezzo:
        f = os.path.join(GREZZI, nome + '_4k.glb')
        if os.path.exists(f):
            return f
    return os.path.join(HQ, nome + '.glb')


def importa_unito(path, nome):
    """Importa un GLB e lo unisce in un solo oggetto mesh con le trasformazioni applicate; materiali e
    immagini prendono nomi chiari e unici (Godot estrae le texture con il nome dell'immagine)."""
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    mesh = [o for o in nuovi if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in mesh:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(mesh) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in nuovi:
        if o.name in bpy.data.objects and o is not ob and o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    ob.name = nome
    ob.data.name = nome
    immagini = []
    for i, m in enumerate(ob.data.materials):
        if not m:
            continue
        m.name = f'M_{nome}' + (f'_{i}' if i else '')
        for nd in (m.node_tree.nodes if m.node_tree else []):
            if nd.type == 'TEX_IMAGE' and nd.image and nd.image not in immagini:
                immagini.append(nd.image)
    for i, im in enumerate(sorted(immagini, key=lambda x: x.name)):
        im.name = f'{nome}_{i}'
    return ob


def limiti(me):
    xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def unisci(oggetti, nome):
    bpy.ops.object.select_all(action='DESELECT')
    for o in oggetti:
        o.select_set(True)
    bpy.context.view_layer.objects.active = oggetti[0]
    if len(oggetti) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nome
    ob.data.name = nome
    return ob


def modulo_fedele(nome, centro=CENTRO_FEDELE, grezzo=False):
    """Un modulo Meshy ruotato e portato nei limiti del modulo di oggi (coordinate del mondo)."""
    rot, lo_t, hi_t = MODULI_FEDELI[nome]
    ob = importa_unito(file_hq('modulo_' + nome, grezzo), 'struttura_' + nome)
    me = ob.data
    me.transform(Matrix.Rotation(math.radians(rot), 4, 'Z'))
    lo, hi = limiti(me)
    s = [(hi_t[i] - lo_t[i]) / (hi[i] - lo[i]) for i in range(3)]
    me.transform(Matrix.Translation(-lo))
    me.transform(Matrix.Diagonal((s[0], s[1], s[2], 1.0)))
    me.transform(Matrix.Translation(Vector(lo_t) + Vector((centro[0], centro[1], 0.0))))
    return ob


def alza_scivolo(ob, centro):
    A = SCIVOLO_ALZA
    for v in ob.data.vertices:
        x, y = v.co.x - centro[0], v.co.y - centro[1]
        if x > 1.55 and y < 0.25 and v.co.z < 3.2 and A['x0'] < x < A['x1']:
            v.co.z += A['alto'] * math.sin(math.pi * (x - A['x0']) / (A['x1'] - A['x0'])) ** 2


def appoggia_piedi(ob, fino=0.3, cella=0.3):
    """I piedi dei pali e i gradini a terra di Meshy non sono tutti alla stessa quota (fino a 5 cm sopra
    il pavimento): per ogni cella di 30 cm porta il punto più basso a z=0, con una correzione che sparisce a
    30 cm d'altezza."""
    import numpy as np
    me = ob.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get('co', co)
    co = co.reshape(-1, 3)
    basso = co[:, 2] < fino
    celle = np.floor(co[:, :2] / cella).astype(int)
    minimi = {}
    for (cx_, cy_), z in zip(map(tuple, celle[basso]), co[basso, 2]):
        k = (cx_, cy_)
        if z < minimi.get(k, 1e9):
            minimi[k] = z
    for i in np.nonzero(basso)[0]:
        zm = minimi[tuple(celle[i])]
        if zm < 0.12:
            co[i, 2] -= zm * (1.0 - co[i, 2] / fino) if co[i, 2] > zm else zm
    me.vertices.foreach_set('co', co.ravel())
    me.update()


def struttura_fedele(centro=CENTRO_FEDELE, grezzo=False, nome='sala_struttura_gioco'):
    """I quattro moduli al loro posto, in un solo oggetto (un materiale per modulo)."""
    parti = []
    for n in MODULI_FEDELI:
        ob = modulo_fedele(n, centro, grezzo)
        if n == 'arancio':
            alza_scivolo(ob, centro)
        appoggia_piedi(ob)
        parti.append(ob)
    return unisci(parti, nome)


def struttura_variante(centro=None, grezzo=False, nome='sala_struttura_gioco'):
    """La variante ruotata, in scala e al suo posto (coordinate del mondo), senza la barra dell'asse dove
    sta il secchio."""
    V = VARIANTE
    centro = centro or V['centro']
    ob = importa_unito(file_hq(V['file'], grezzo), nome)
    me = ob.data
    me.transform(Matrix.Rotation(math.radians(V['rot_z']), 4, 'Z'))
    lo, hi = limiti(me)
    me.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    me.transform(Matrix.Scale(V['alto'] / (hi.z - lo.z), 4))
    togli_nel_box(ob, *TAGLIO_ASSE)
    me.transform(Matrix.Translation((centro[0], centro[1], 0.0)))
    return ob


def togli_nel_box(ob, lo, hi):
    """Cancella le facce con il centro dentro il box."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    via = [f for f in bm.faces if all(lo[i] <= f.calc_center_median()[i] <= hi[i] for i in range(3))]
    bmesh.ops.delete(bm, geom=via, context='FACES')
    bm.to_mesh(ob.data)
    bm.free()
    return len(via)


def secchio_locale(grezzo=False, nome='sala_secchio_gigante'):
    """Il secchio HD grande come quello di oggi (SECCHIO_MISURE), con il perno nell'origine sui due mozzi
    (asse x): il diametro del corpo si misura in y, l'altezza in z."""
    ob = importa_unito(file_hq(SECCHIO_HD, grezzo), nome)
    me = ob.data
    lo, hi = limiti(me)
    xmax = max(abs(lo.x), abs(hi.x))
    mozzi = [v.co.z for v in me.vertices if abs(v.co.x) > 0.9 * xmax]
    sz = SECCHIO_MISURE['alto'] / (hi.z - lo.z)
    sxy = SECCHIO_MISURE['diametro'] / (hi.y - lo.y)
    me.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -sum(mozzi) / len(mozzi)))))
    me.transform(Matrix.Diagonal((sxy, sxy, sz, 1.0)))
    return ob
