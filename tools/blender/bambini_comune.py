"""Funzioni comuni degli script tools/blender/bambini_*.py (Blender 5.2 come modulo bpy).

Convenzioni dei modelli dei bambini: asse Z in alto, guardano verso -Y, piedi a z=0,
altezza reale in metri (circa 1,2 m da travestiti).
"""
import math
import os

import bpy
from mathutils import Vector

QUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(QUI, '..', '..'))
ASSET = os.path.join(REPO, 'assets_src', 'bambini')
PROPOSTE = os.path.join(REPO, 'docs', 'proposte', 'bambini')
FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'

# I modelli: file GLB in assets_src/bambini/ e altezza reale (metri).
# Le altezze dei rivelati sono scelte perché il corpo resti grande come da travestito.
MODELLI = {
    'cubo_calmo': ('cubo_calmo.glb', 1.20),
    'cubo_rivelato': ('cubo_rivelato.glb', 1.25),
    'agnello_calmo': ('agnello_calmo.glb', 1.20),
    'agnello_lupo': ('agnello_lupo.glb', 1.36),
    'agnello_occhio': ('agnello_occhio.glb', 1.20),
}


def log(*a):
    print('[bambini]', *a, flush=True)


def limiti(oggetti):
    ms = [o for o in oggetti if o.type == 'MESH']
    pts = [o.matrix_world @ Vector(c) for o in ms for c in o.bound_box]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def importa(glb, altezza=None, nome='personaggio'):
    """Importa un GLB sotto un perno (empty) con i piedi a z=0, centrato in x/y.
    Se 'altezza' è data, scala il modello a quell'altezza. Ritorna il perno."""
    sc = bpy.context.scene
    prima = set(sc.objects)
    bpy.ops.import_scene.gltf(filepath=glb)
    nuovi = [o for o in sc.objects if o not in prima]
    perno = bpy.data.objects.new(nome, None)
    sc.collection.objects.link(perno)
    for o in nuovi:
        if o.parent is None:
            o.parent = perno
    bpy.context.view_layer.update()
    lo, hi = limiti(nuovi)
    c = (lo + hi) / 2
    for o in nuovi:
        if o.parent is perno:
            o.matrix_world.translation -= Vector((c.x, c.y, lo.z))
    if altezza:
        s = altezza / (hi.z - lo.z)
        perno.scale = (s, s, s)
    bpy.context.view_layer.update()
    perno['mesh'] = [o.name for o in nuovi if o.type == 'MESH']
    return perno


def mesh_di(perno):
    return [bpy.data.objects[n] for n in perno['mesh']]


def materiali_di(perno):
    return {m for o in mesh_di(perno) for m in o.data.materials if m}


def guarda_verso(perno, bersaglio, extra_gradi=0.0):
    """Gira il perno (che guarda verso -Y) verso un punto, più un angolo in gradi."""
    d = Vector(bersaglio) - perno.location
    perno.rotation_euler = (0, 0, math.atan2(d.x, -d.y) + math.radians(extra_gradi))


def ritocca_materiali(materiali, bagnato=1.0, bagliore=0.0, occhi_rosa=False):
    """bagnato: moltiplica la rugosità (meno = più lucido e bagnato).
    bagliore: le parti rosa/magenta (il tessuto della "madre") emettono luce con questa forza.
    occhi_rosa: ricolora in rosa le iridi gialle (variante del cubo rivelato)."""
    for m in materiali:
        nt, ln = m.node_tree.nodes, m.node_tree.links
        bsdf = next((n for n in nt if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf is None:
            continue
        r_in = bsdf.inputs['Roughness']
        mul = nt.get('bambini_bagnato')
        if mul is None:
            mul = nt.new('ShaderNodeMath'); mul.name = 'bambini_bagnato'; mul.operation = 'MULTIPLY'
            if r_in.is_linked:
                ln.new(r_in.links[0].from_socket, mul.inputs[0])
            else:
                mul.inputs[0].default_value = r_in.default_value
            ln.new(mul.outputs[0], r_in)
        mul.inputs[1].default_value = bagnato
        if not bsdf.inputs['Base Color'].is_linked:
            continue
        col = bsdf.inputs['Base Color'].links[0].from_socket
        if occhi_rosa and nt.get('bambini_occhi') is None:
            # giallo (tinta 0,08-0,20, saturo) -> rosa (tinta 0,93), stessa luminosità
            sep = nt.new('ShaderNodeSeparateColor'); sep.mode = 'HSV'; sep.name = 'bambini_occhi'
            ln.new(col, sep.inputs['Color'])
            a = nt.new('ShaderNodeMapRange'); a.interpolation_type = 'SMOOTHSTEP'
            a.inputs['From Min'].default_value = 0.06; a.inputs['From Max'].default_value = 0.10
            b = nt.new('ShaderNodeMapRange'); b.interpolation_type = 'SMOOTHSTEP'
            b.inputs['From Min'].default_value = 0.22; b.inputs['From Max'].default_value = 0.17
            ln.new(sep.outputs[0], a.inputs['Value']); ln.new(sep.outputs[0], b.inputs['Value'])
            s = nt.new('ShaderNodeMapRange'); s.interpolation_type = 'SMOOTHSTEP'
            s.inputs['From Min'].default_value = 0.35; s.inputs['From Max'].default_value = 0.6
            ln.new(sep.outputs[1], s.inputs['Value'])
            m1 = nt.new('ShaderNodeMath'); m1.operation = 'MULTIPLY'
            ln.new(a.outputs[0], m1.inputs[0]); ln.new(b.outputs[0], m1.inputs[1])
            m2 = nt.new('ShaderNodeMath'); m2.operation = 'MULTIPLY'
            ln.new(m1.outputs[0], m2.inputs[0]); ln.new(s.outputs[0], m2.inputs[1])
            comb = nt.new('ShaderNodeCombineColor'); comb.mode = 'HSV'
            comb.inputs[0].default_value = 0.935
            ln.new(sep.outputs[1], comb.inputs[1]); ln.new(sep.outputs[2], comb.inputs[2])
            mix = nt.new('ShaderNodeMix'); mix.data_type = 'RGBA'
            ln.new(m2.outputs[0], mix.inputs['Factor'])
            ln.new(col, mix.inputs['A']); ln.new(comb.outputs['Color'], mix.inputs['B'])
            ln.new(mix.outputs['Result'], bsdf.inputs['Base Color'])
            col = mix.outputs['Result']
        if bagliore > 0 and nt.get('bambini_bagliore') is None:
            hsv = nt.new('ShaderNodeSeparateColor'); hsv.mode = 'HSV'
            ln.new(col, hsv.inputs['Color'])
            t1 = nt.new('ShaderNodeMapRange'); t1.interpolation_type = 'SMOOTHSTEP'
            t1.inputs['From Min'].default_value = 0.76; t1.inputs['From Max'].default_value = 0.86
            ln.new(hsv.outputs[0], t1.inputs['Value'])
            sat = nt.new('ShaderNodeMapRange'); sat.interpolation_type = 'SMOOTHSTEP'
            sat.inputs['From Min'].default_value = 0.22; sat.inputs['From Max'].default_value = 0.5
            ln.new(hsv.outputs[1], sat.inputs['Value'])
            t2 = nt.new('ShaderNodeMapRange'); t2.interpolation_type = 'SMOOTHSTEP'  # non il rosso
            t2.inputs['From Min'].default_value = 0.965; t2.inputs['From Max'].default_value = 0.93
            ln.new(hsv.outputs[0], t2.inputs['Value'])
            m0 = nt.new('ShaderNodeMath'); m0.operation = 'MULTIPLY'
            ln.new(t1.outputs[0], m0.inputs[0]); ln.new(t2.outputs[0], m0.inputs[1])
            m1 = nt.new('ShaderNodeMath'); m1.operation = 'MULTIPLY'
            ln.new(m0.outputs[0], m1.inputs[0]); ln.new(sat.outputs[0], m1.inputs[1])
            m3 = nt.new('ShaderNodeMath'); m3.operation = 'MULTIPLY'; m3.name = 'bambini_bagliore'
            ln.new(m1.outputs[0], m3.inputs[0])
            # emette un rosa più saturo del colore di base
            hs = nt.new('ShaderNodeHueSaturation')
            hs.inputs['Saturation'].default_value = 1.6
            ln.new(col, hs.inputs['Color'])
            ln.new(hs.outputs['Color'], bsdf.inputs['Emission Color'])
            ln.new(m3.outputs[0], bsdf.inputs['Emission Strength'])
        if nt.get('bambini_bagliore') is not None:
            nt['bambini_bagliore'].inputs[1].default_value = bagliore
