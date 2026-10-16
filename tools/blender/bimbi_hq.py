"""Area bimbi in alta definizione (proposta del 16 ottobre, crediti Meshy rimasti): la struttura di gioco, il
secchio gigante e i funghi-fontana rifatti con Meshy (assets_src/ambiente/bimbi_hq/, vedi genera.py lì)
al posto di quelli fatti a mano, nella disposizione 1 approvata. Solo proposta: la sala del gioco non cambia
finché l'utente non sceglie. Lo usano ambiente_sala_bimbi_hq.py (la sala per Godot, per gli scatti) e
bimbi_hq_render.py (i render dei modelli).

Misure prese dai modelli (pianta e livelli calcolati sui vertici, Z in alto, metri, dopo la rotazione):
  - struttura (insieme_c_vuoto): ruotata di +90 gradi (il davanti, cioè la vista dell'immagine, guarda a
    sud verso chi arriva; lo scivolo va a est), alta 8,2 m come quella di prima. In pianta, rispetto al
    centro dei limiti: torre verde x -4,1..-2,3 y -2,8..-1,0 (pedana a 1,24 m); torre rossa x -4,2..-2,2
    y 0..1,8 (2,72 m); torre arancio x -1,1..0,8 y 0..1,8 (1,71 m) con lo scivolo verso est fino a x 4,26
    (y 0,07..1,39); torre del secchio x -2,1..-0,3 y 1,5..3,2 (4,07 m) con il telaio a portale: pali a
    x -2,2 e -0,15, cuscinetti interni a x -2,02 e -0,38, asse a y 2,26 e z 6,65, trave in cima a 8 m.
  - posizione: lo scivolo deve finire dentro la vasca piccola (VASCA_BIMBI_2, bordo alto 0,45 m) e passare
    sopra il bordo: centro dei limiti in (-14,0; 17,5). Il bordo ovest della vasca (x -11,3..-11,0) cade
    sotto lo scivolo dove il fondo è a 0,55-0,6 m; la fine dello scivolo è a x -9,74, y 17,6..18,9.
"""
import math, os
import bpy
from mathutils import Vector, Matrix, Euler

QUI = os.path.dirname(os.path.abspath(__file__))
HQ = os.environ.get('BIMBI_HQ', os.path.normpath(os.path.join(QUI, '..', '..', 'assets_src', 'ambiente', 'bimbi_hq')))
GREZZI = os.environ.get('BIMBI_HQ_GREZZI', os.path.join(HQ, '_grezzi'))   # GLB 4K (solo per i render)

STRUTTURA_HD = dict(file='struttura_gioco', rot_z=90.0, alto=8.2, centro=(-14.0, 17.5))
# pianta del modello (dopo rotazione e scala, rispetto al centro dei limiti)
PEDANE = {   # nome: (x0, y0, x1, y1, quota del piano di calpestio)
    'verde': (-4.15, -2.85, -2.25, -0.95, 1.24),
    'arancio': (-1.10, -0.05, 0.80, 1.80, 1.71),
    'rossa': (-4.25, -0.10, -2.20, 1.85, 2.72),
    'secchio': (-2.15, 1.50, -0.25, 3.20, 4.07),
}
ASSE_SECCHIO = dict(x=-1.20, y=2.26, z=6.65, luce=1.64)     # centro dell'asse e distanza tra i cuscinetti
TAGLIO_ASSE = ((-1.90, 2.00, 6.35), (-0.50, 2.52, 6.95))     # la barra dell'asse dentro il secchio (si toglie)
FUNGO_HD = 'fungo_fontana'
SECCHIO_HD = 'secchio_gigante'


def file_hq(nome, grezzo=False):
    """GLB di un modello HQ: quello del repository (texture 2K) o il 4K scaricato (solo per i render)."""
    if grezzo:
        f = os.path.join(GREZZI, nome + '_4k.glb')
        if os.path.exists(f):
            return f
    return os.path.join(HQ, nome + '.glb')


def importa_unito(path, nome):
    """Importa un GLB e lo unisce in un solo oggetto mesh con le trasformazioni applicate."""
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
    return ob


def limiti(me):
    xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def struttura_locale(grezzo=False, nome='sala_struttura_gioco'):
    """La struttura HD in coordinate locali (centro dei limiti in pianta nell'origine, base a z=0), ruotata
    e in scala, con la barra dell'asse tolta dove sta il secchio."""
    S = STRUTTURA_HD
    ob = importa_unito(file_hq(S['file'], grezzo), nome)
    me = ob.data
    me.transform(Matrix.Rotation(math.radians(S['rot_z']), 4, 'Z'))
    lo, hi = limiti(me)
    me.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    me.transform(Matrix.Scale(S['alto'] / (hi.z - lo.z), 4))
    togli_nel_box(ob, *TAGLIO_ASSE)
    return ob


def togli_nel_box(ob, lo, hi):
    """Cancella le facce con il centro dentro il box (la barra dell'asse che attraverserebbe il secchio)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    via = [f for f in bm.faces if all(lo[i] <= f.calc_center_median()[i] <= hi[i] for i in range(3))]
    bmesh.ops.delete(bm, geom=via, context='FACES')
    bm.to_mesh(ob.data)
    bm.free()
    return len(via)


def secchio_locale(grezzo=False, nome='sala_secchio_gigante'):
    """Il secchio HD con il perno nell'origine (asse x sui due mozzi) e i mozzi lunghi quanto la luce tra i
    cuscinetti del telaio (ASSE_SECCHIO['luce'])."""
    ob = importa_unito(file_hq(SECCHIO_HD, grezzo), nome)
    me = ob.data
    lo, hi = limiti(me)
    xmax = max(abs(lo.x), abs(hi.x))
    mozzi = [v.co.z for v in me.vertices if abs(v.co.x) > 0.9 * xmax]
    me.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -sum(mozzi) / len(mozzi)))))
    me.transform(Matrix.Scale(ASSE_SECCHIO['luce'] / (hi.x - lo.x), 4))
    return ob
