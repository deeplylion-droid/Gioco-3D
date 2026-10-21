"""Il geyser della fossa (tappa 8), simulato con Mantaflow: un getto d'acqua spara dritto dalla fossa per mezzo
secondo, sale a circa 4-5 m, poi crolla e ricade come pioggia pesante nella fossa e sul pavimento intorno.
Uso (serve il Blender completo: nel modulo bpy Mantaflow non funziona):
  /home/user/tools/blender-full/blender-5.2.2-linux-x64/blender -b --python assets_src/geyser/simula.py -- <risoluzione> <cartella_cache>
La base del getto è nell'origine (il centro della fossa, sul fondo); acqua, bordo e pavimento come nel gioco."""
import math, os, sys, time
import bpy

ARG = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
RIS = int(ARG[0]) if ARG else 64
CACHE = ARG[1] if len(ARG) > 1 else '/tmp/geyser_cache'
FPS = 30
DURATA = 2.6          # secondi simulati
SPARO = 0.8           # secondi di getto
VEL = 15.0            # m/s verso l'alto: la massa deve arrivare a 4-5 m sopra il pavimento
R_GETTO = 1.0         # raggio del getto: la colonna deve coprirla tutta
LATO, ALTO = 7.0, 7.0  # dominio

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
sc.frame_start, sc.frame_end = 1, int(DURATA * FPS)


def cubo(nome, loc, dim):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.active_object
    o.name = nome
    o.scale = (dim[0] / 2, dim[1] / 2, dim[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return o


# l'origine è la base del geyser, come GeyserFossa.scoppia(pavimento): sotto il pelo dell'acqua della fossa
Z_ACQUA, Z_BORDO, Z_PAV = 0.85, 1.0, 0.55   # come nel gioco: acqua a +0,85, bordo della vasca a +1,0, pavimento a +0,55
R_FOSSA = 1.3
dom = cubo('Dominio', (0, 0, ALTO / 2 - 0.2), (LATO, LATO, ALTO))
m = dom.modifiers.new('Fluid', 'FLUID'); m.fluid_type = 'DOMAIN'
ds = m.domain_settings
ds.domain_type = 'LIQUID'
ds.resolution_max = RIS
ds.cache_directory = CACHE
ds.cache_type = 'ALL'
ds.cache_data_format = 'OPENVDB'
ds.openvdb_cache_compress_type = 'BLOSC'
ds.use_mesh = True
ds.mesh_scale = 2
ds.mesh_particle_radius = 2.0
ds.use_adaptive_timesteps = True
ds.cfl_condition = 4.0
ds.timesteps_max = 8
ds.use_collision_border_bottom = True
for lato in ('front', 'back', 'left', 'right', 'top'):
    setattr(ds, f'use_collision_border_{lato}', False)
ds.use_flip_particles = True
ds.flip_ratio = 0.97
ds.particle_number = 1      # meno particelle: la cache sta sul disco


def ostacolo(o):
    mo = o.modifiers.new('Fluid', 'FLUID'); mo.fluid_type = 'EFFECTOR'
    mo.effector_settings.effector_type = 'COLLISION'
    return o


# il pavimento intorno, col buco della vasca
bpy.ops.mesh.primitive_cylinder_add(radius=LATO, depth=0.4, location=(0, 0, Z_PAV - 0.2), vertices=64)
pav = bpy.context.active_object; pav.name = 'Pavimento'
bpy.ops.mesh.primitive_cylinder_add(radius=R_FOSSA + 0.25, depth=1.0, location=(0, 0, Z_PAV - 0.2), vertices=48)
buco = bpy.context.active_object
bo = pav.modifiers.new('buco', 'BOOLEAN'); bo.object = buco; bo.operation = 'DIFFERENCE'
bpy.context.view_layer.objects.active = pav
bpy.ops.object.modifier_apply(modifier='buco')
bpy.data.objects.remove(buco)
ostacolo(pav)
# la parete della vasca, che sporge sopra il pavimento fino al bordo
bpy.ops.mesh.primitive_cylinder_add(radius=R_FOSSA + 0.25, depth=Z_BORDO + 0.2, location=(0, 0, (Z_BORDO - 0.2) / 2), vertices=48)
parete = bpy.context.active_object; parete.name = 'Parete'
bpy.ops.mesh.primitive_cylinder_add(radius=R_FOSSA, depth=Z_BORDO + 1.0, location=(0, 0, Z_BORDO / 2), vertices=48)
dentro = bpy.context.active_object
bo = parete.modifiers.new('dentro', 'BOOLEAN'); bo.object = dentro; bo.operation = 'DIFFERENCE'
bpy.context.view_layer.objects.active = parete
bpy.ops.object.modifier_apply(modifier='dentro')
bpy.data.objects.remove(dentro)
ostacolo(parete)
# il fondo della fossa alzato: si simula solo lo strato d'acqua che si vede (meno particelle)
Z_FONDO = 0.5
fondo = ostacolo(cubo('Fondo', (0, 0, Z_FONDO - 0.15), (R_FOSSA * 2.4, R_FOSSA * 2.4, 0.3)))

# l'acqua della fossa, ferma
bpy.ops.mesh.primitive_cylinder_add(radius=R_FOSSA - 0.03, depth=Z_ACQUA - Z_FONDO, location=(0, 0, (Z_ACQUA + Z_FONDO) / 2), vertices=48)
pozza = bpy.context.active_object; pozza.name = 'Pozza'
mp = pozza.modifiers.new('Fluid', 'FLUID'); mp.fluid_type = 'FLOW'
mp.flow_settings.flow_type = 'LIQUID'; mp.flow_settings.flow_behavior = 'GEOMETRY'

# il getto: un disco sul fondo che sputa acqua verso l'alto per SPARO secondi
bpy.ops.mesh.primitive_cylinder_add(radius=R_GETTO, depth=0.2, location=(0, 0, Z_FONDO + 0.1), vertices=32)
getto = bpy.context.active_object; getto.name = 'Getto'
mg = getto.modifiers.new('Fluid', 'FLUID'); mg.fluid_type = 'FLOW'
fs = mg.flow_settings
fs.flow_type = 'LIQUID'; fs.flow_behavior = 'INFLOW'
fs.use_initial_velocity = True
fs.velocity_coord = (0, 0, VEL)
fs.use_inflow = True
fs.keyframe_insert('use_inflow', frame=1)
fs.use_inflow = False
fs.keyframe_insert('use_inflow', frame=int(SPARO * FPS))

t0 = time.time()
bpy.context.view_layer.objects.active = dom
bpy.ops.fluid.bake_all()
print('cotto in', round(time.time() - t0), 's, risoluzione', RIS, flush=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CACHE, 'geyser.blend'))
