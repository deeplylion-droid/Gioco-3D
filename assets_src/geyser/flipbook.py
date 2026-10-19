"""Geyser V2: la stessa simulazione (simula.py) resa in Cycles come flipbook per un cartellone che guarda la camera.
Per ogni fotogramma: il colore con l'alfa (acqua bianca di schiuma, piena, luce morbida dappertutto: la luce vera la
mette il gioco) e le normali viste dalla camera, per illuminarla nel gioco con le luci della sala.
Camera ortografica di fronte (da -Y), larga LARGO m e alta ALTO m a partire da Z_BASSO sopra la base del getto.
Come nel gioco (acqua_schiuma.gdshader) si tiene solo l'acqua che sale e ricade: quella ferma della fossa e quella
stesa a terra sono trasparenti.
Uso: blender -b <cache>/geyser.blend --python assets_src/geyser/flipbook.py -- <cartella> [campioni] [fotogrammi separati da virgola]
Poi: python assets_src/geyser/flipbook_atlante.py <cartella> per mettere insieme gli atlanti."""
import os, sys
import bpy

ARG = sys.argv[sys.argv.index('--') + 1:]
OUT = ARG[0]
CAMPIONI = int(ARG[1]) if len(ARG) > 1 else 48
FOTOGRAMMI = [int(x) for x in ARG[2].split(',')] if len(ARG) > 2 else None   # solo questi (prove)
LARGO, ALTO, Z_BASSO = 6.0, 8.0, 0.5
W, H = 300, 400
Z_ACQUA, Z_PAV, R_FOSSA = 0.85, 0.55, 1.35
os.makedirs(OUT, exist_ok=True)

sc = bpy.context.scene
dom = bpy.data.objects['Dominio']
for o in bpy.data.objects:
    if o is not dom:
        o.hide_render = True

# l'acqua: bianca, piena, appena lucida; trasparente sotto il pelo della fossa e appena sopra il pavimento
mat = bpy.data.materials.new('schiuma'); mat.use_nodes = True
nt = mat.node_tree; N = nt.nodes; L = nt.links
for n in list(N):
    N.remove(n)
out = N.new('ShaderNodeOutputMaterial')
pb = N.new('ShaderNodeBsdfPrincipled')
pb.inputs['Base Color'].default_value = (0.92, 0.94, 0.95, 1)
pb.inputs['Roughness'].default_value = 0.25
pb.inputs['Subsurface Weight'].default_value = 0.2
pb.inputs['Subsurface Radius'].default_value = (0.05, 0.06, 0.07)
tr = N.new('ShaderNodeBsdfTransparent')
geo = N.new('ShaderNodeNewGeometry')
sep = N.new('ShaderNodeSeparateXYZ'); L.new(geo.outputs['Position'], sep.inputs[0])
xy = N.new('ShaderNodeCombineXYZ'); L.new(sep.outputs['X'], xy.inputs['X']); L.new(sep.outputs['Y'], xy.inputs['Y'])
lun = N.new('ShaderNodeVectorMath'); lun.operation = 'LENGTH'; L.new(xy.outputs[0], lun.inputs[0])
dentro = N.new('ShaderNodeMath'); dentro.operation = 'LESS_THAN'; L.new(lun.outputs['Value'], dentro.inputs[0]); dentro.inputs[1].default_value = R_FOSSA
soglia = N.new('ShaderNodeMath'); soglia.operation = 'MULTIPLY_ADD'
L.new(dentro.outputs[0], soglia.inputs[0]); soglia.inputs[1].default_value = (Z_ACQUA + 0.06) - (Z_PAV + 0.16); soglia.inputs[2].default_value = Z_PAV + 0.16
sopra = N.new('ShaderNodeMath'); sopra.operation = 'GREATER_THAN'; L.new(sep.outputs['Z'], sopra.inputs[0]); L.new(soglia.outputs[0], sopra.inputs[1])
mix = N.new('ShaderNodeMixShader'); L.new(sopra.outputs[0], mix.inputs['Fac']); L.new(tr.outputs[0], mix.inputs[1]); L.new(pb.outputs[0], mix.inputs[2])
L.new(mix.outputs[0], out.inputs['Surface'])
dom.data.materials.clear(); dom.data.materials.append(mat)

cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; cam.data.ortho_scale = ALTO
cam.location = (0, -20, Z_BASSO + ALTO / 2); cam.rotation_euler = (1.5707963, 0, 0)
sc.camera = cam
sc.world = bpy.data.worlds.new('morbida'); sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs['Color'].default_value = (1, 1, 1, 1)
sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
sc.render.engine = 'CYCLES'; sc.cycles.samples = CAMPIONI; sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'

# le normali: un secondo passaggio veloce con un materiale che emette la normale vista dalla camera (x a destra,
# y in alto, z verso chi guarda), in vista Raw: niente conversioni di colore
nm = bpy.data.materials.new('normali'); nm.use_nodes = True
nn = nm.node_tree.nodes; nl = nm.node_tree.links
for n in list(nn):
    nn.remove(n)
o2 = nn.new('ShaderNodeOutputMaterial')
g2 = nn.new('ShaderNodeNewGeometry')
vt = nn.new('ShaderNodeVectorTransform'); vt.vector_type = 'NORMAL'; vt.convert_from = 'WORLD'; vt.convert_to = 'CAMERA'
nl.new(g2.outputs['Normal'], vt.inputs[0])
sc5 = nn.new('ShaderNodeVectorMath'); sc5.operation = 'MULTIPLY_ADD'
nl.new(vt.outputs[0], sc5.inputs[0]); sc5.inputs[1].default_value = (0.5, 0.5, 0.5); sc5.inputs[2].default_value = (0.5, 0.5, 0.5)
em = nn.new('ShaderNodeEmission'); nl.new(sc5.outputs[0], em.inputs['Color'])
tr2 = nn.new('ShaderNodeBsdfTransparent')
# la stessa soglia del colore (si ricostruisce con gli stessi nodi)
geo2 = nn.new('ShaderNodeNewGeometry')
sp2 = nn.new('ShaderNodeSeparateXYZ'); nl.new(geo2.outputs['Position'], sp2.inputs[0])
xy2 = nn.new('ShaderNodeCombineXYZ'); nl.new(sp2.outputs['X'], xy2.inputs['X']); nl.new(sp2.outputs['Y'], xy2.inputs['Y'])
ln2 = nn.new('ShaderNodeVectorMath'); ln2.operation = 'LENGTH'; nl.new(xy2.outputs[0], ln2.inputs[0])
dn2 = nn.new('ShaderNodeMath'); dn2.operation = 'LESS_THAN'; nl.new(ln2.outputs['Value'], dn2.inputs[0]); dn2.inputs[1].default_value = R_FOSSA
so2 = nn.new('ShaderNodeMath'); so2.operation = 'MULTIPLY_ADD'
nl.new(dn2.outputs[0], so2.inputs[0]); so2.inputs[1].default_value = (Z_ACQUA + 0.06) - (Z_PAV + 0.16); so2.inputs[2].default_value = Z_PAV + 0.16
su2 = nn.new('ShaderNodeMath'); su2.operation = 'GREATER_THAN'; nl.new(sp2.outputs['Z'], su2.inputs[0]); nl.new(so2.outputs[0], su2.inputs[1])
mx2 = nn.new('ShaderNodeMixShader'); nl.new(su2.outputs[0], mx2.inputs['Fac']); nl.new(tr2.outputs[0], mx2.inputs[1]); nl.new(em.outputs[0], mx2.inputs[2])
nl.new(mx2.outputs[0], o2.inputs['Surface'])


def rendi(f):
    sc.frame_set(f)
    dom.data.materials[0] = mat
    sc.cycles.samples = CAMPIONI; sc.cycles.use_denoising = True
    sc.view_settings.view_transform = 'Standard'
    sc.render.filepath = os.path.join(OUT, f'c_{f:04d}.png')
    bpy.ops.render.render(write_still=True)
    dom.data.materials[0] = nm
    sc.cycles.samples = 4; sc.cycles.use_denoising = False
    sc.view_settings.view_transform = 'Raw'
    sc.render.filepath = os.path.join(OUT, f'n_{f:04d}.png')
    bpy.ops.render.render(write_still=True)


for f in FOTOGRAMMI or range(sc.frame_start, sc.frame_end + 1):
    rendi(f)
    print('reso', f, flush=True)
