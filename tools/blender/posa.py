"""Posa: lo strumento comune per mettere gli oggetti al loro posto nei generatori Blender (processo nuovo del 22
ottobre, "per evitare questi errori una volta per tutte"). Le stesse funzioni di godot/scripts/posizionamento/posa.gd:
con un raggio si trova il sostegno vero (pavimento, muro, soffitto, gancio), l'oggetto si sposta a contatto e, con
lega=True, diventa figlio del sostegno, così lo segue se il sostegno si sposta.

    import sys; sys.path.insert(0, 'tools/blender')
    import posa
    posa.appoggia_a_terra(sedia, lega=True)              # il punto più basso della sedia sul pavimento sotto
    posa.fissa_al_muro(quadro, verso=(0, -1, 0))          # il retro del quadro sul muro dietro (verso = fuori dal muro)
    posa.fissa_al_soffitto(plafoniera)
    posa.appendi_a(lampada, gancio)                       # la cima della lampada sul gancio, figlia del gancio
    posa.tocca(sedia)                                     # controllo: tocca qualcosa entro 5 mm?

Le funzioni restituiscono l'oggetto colpito (il sostegno) o None: senza sostegno l'oggetto resta dov'è e si stampa un
avviso. Le misure sono quelle vere della mesh nel mondo (modificatori compresi). Come si usa:
docs/tecnico/posizionamento/LEGGIMI.md, "Mettere gli oggetti".
"""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PORTATA = 3.0
STACCO = 0.005


def _punti_mondo(obj):
    """I vertici della mesh valutata (modificatori compresi) nel mondo."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    try:
        return [obj.matrix_world @ v.co for v in me.vertices]
    finally:
        ev.to_mesh_clear()


def solo_collisione(o):
    """Un oggetto che non si vede: la collisione da esportare (nome con -col, _col, -colonly, -convcolonly, come le
    usa l'importazione di Godot) o uno spento nel render. Posa non ci si appoggia: la collisione può sporgere qualche
    centimetro oltre la superficie che si vede (riscontro di mascotte, 22 ottobre)."""
    n = o.name.lower()
    return o.hide_render or any(s in n for s in ('-col', '_col', 'colonly'))


def _raggio(obj, origine, direzione, distanza=PORTATA):
    """Il primo oggetto visibile colpito, escludendo obj, i suoi figli e le collisioni: (posizione, normale, oggetto)
    o None."""
    nascosti = [obj] + list(obj.children_recursive)
    nascosti += [o for o in bpy.context.scene.objects if o not in nascosti and o.type == 'MESH' and not o.hide_viewport and solo_collisione(o)]
    stati = [(o, o.hide_viewport) for o in nascosti]
    for o in nascosti:
        o.hide_viewport = True
    bpy.context.view_layer.update()
    try:
        dg = bpy.context.evaluated_depsgraph_get()
        ok, pos, nor, _i, colpito, _m = bpy.context.scene.ray_cast(dg, Vector(origine), Vector(direzione).normalized(), distance=distanza)
    finally:
        for o, h in stati:
            o.hide_viewport = h
        bpy.context.view_layer.update()
    if not ok:
        return None
    return pos, nor, colpito.original if hasattr(colpito, 'original') else colpito


def _sposta(obj, delta):
    obj.matrix_world.translation += Vector(delta)
    bpy.context.view_layer.update()


def _lega(obj, sostegno):
    if sostegno is None or sostegno == obj or sostegno in obj.children_recursive:
        return
    mw = obj.matrix_world.copy()
    obj.parent = sostegno
    obj.matrix_parent_inverse = sostegno.matrix_world.inverted()
    obj.matrix_world = mw


def appoggia_a_terra(obj, lega=False):
    """Il punto più basso di obj sul primo sostegno sotto (sotto il centro del suo box)."""
    p = _punti_mondo(obj)
    basso = min(v.z for v in p)
    cx = sum(v.x for v in p) / len(p)
    cy = sum(v.y for v in p) / len(p)
    h = _raggio(obj, (cx, cy, basso + 0.05), (0, 0, -1))
    if h is None:
        print('Posa: niente sotto %s' % obj.name)
        return None
    _sposta(obj, (0, 0, h[0].z - basso))
    if lega:
        _lega(obj, h[2])
    return h[2]


def fissa_al_muro(obj, verso, lega=False):
    """Il retro di obj (il punto più indietro, contro verso) sul muro dietro; verso = la direzione verso cui guarda,
    fuori dal muro."""
    v = Vector(verso).normalized()
    p = _punti_mondo(obj)
    retro = min(q.dot(v) for q in p)
    c = sum(p, Vector()) / len(p)
    # dal centro, portato sul piano del retro e un po' avanti (un oggetto già un po' dentro il muro torna a filo)
    da = c + v * (retro - c.dot(v) + 0.3)
    h = _raggio(obj, da, -v)
    if h is None:
        print('Posa: nessun muro dietro %s' % obj.name)
        return None
    _sposta(obj, v * (h[0].dot(v) - retro))
    if lega:
        _lega(obj, h[2])
    return h[2]


def fissa_al_soffitto(obj, lega=False):
    """Il punto più alto di obj sul primo sostegno sopra."""
    p = _punti_mondo(obj)
    alto = max(v.z for v in p)
    cx = sum(v.x for v in p) / len(p)
    cy = sum(v.y for v in p) / len(p)
    h = _raggio(obj, (cx, cy, alto - 0.05), (0, 0, 1))
    if h is None:
        print('Posa: niente sopra %s' % obj.name)
        return None
    _sposta(obj, (0, 0, h[0].z - alto))
    if lega:
        _lega(obj, h[2])
    return h[2]


def appendi_a(obj, gancio, attacco=None):
    """Appende obj al gancio (un oggetto o un empty): il punto attacco di obj (nel mondo; se None, il punto più alto
    sopra il centro) va sulla posizione del gancio, e obj ne diventa figlio."""
    if attacco is None:
        p = _punti_mondo(obj)
        c = sum(p, Vector()) / len(p)
        attacco = Vector((c.x, c.y, max(v.z for v in p)))
    _sposta(obj, gancio.matrix_world.translation - Vector(attacco))
    _lega(obj, gancio)
    return gancio


def tocca(obj, toll=STACCO, altri=None):
    """Controllo per i generatori: vero se almeno un vertice di obj è a meno di toll dalla superficie di un altro
    oggetto mesh (fra altri, se dato; se no tutti quelli della scena il cui box è vicino)."""
    p = _punti_mondo(obj)
    lo = Vector((min(v.x for v in p), min(v.y for v in p), min(v.z for v in p))) - Vector((toll,) * 3)
    hi = Vector((max(v.x for v in p), max(v.y for v in p), max(v.z for v in p))) + Vector((toll,) * 3)
    candidati = altri if altri is not None else [o for o in bpy.context.scene.objects
                                                 if o.type == 'MESH' and o != obj and not solo_collisione(o)]
    dg = bpy.context.evaluated_depsgraph_get()
    for o in candidati:
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        if any(max(c[i] for c in bb) < lo[i] or min(c[i] for c in bb) > hi[i] for i in range(3)):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        try:
            vs = [o.matrix_world @ v.co for v in me.vertices]
            tris = [tuple(t.vertices) for t in me.loop_triangles] if me.loop_triangles else []
            if not tris:
                me.calc_loop_triangles()
                tris = [tuple(t.vertices) for t in me.loop_triangles]
            albero = BVHTree.FromPolygons(vs, tris)
        finally:
            ev.to_mesh_clear()
        for q in p:
            f = albero.find_nearest(q, toll)
            if f[0] is not None:
                return True
    return False
