"""Elenca le mesh della sala che cadono in un rettangolo (coordinate di Godot x, z) sotto i 4 m."""
import sys, bpy
from mathutils import Vector
godot = sys.argv[1]
zone = [tuple(map(float, z.split(','))) for z in sys.argv[2:]]   # xmin,xmax,zmin,zmax
bpy.ops.wm.read_factory_settings(use_empty=True)
for f in ['sala_architettura', 'sala_piscina', 'sala_area_bimbi', 'sala_oggetti', 'sala_vasca_centrale',
          'sala_torre_scivoli', 'sala_interattivi', 'sala_luci', 'sala_monumento']:
    bpy.ops.import_scene.gltf(filepath=f'{godot}/assets/ambiente/sala/{f}.glb')
for zi, (x0, x1, z0, z1) in enumerate(zone):
    print('ZONA', zi, x0, x1, z0, z1)
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        ps = [o.matrix_world @ Vector(c) for c in o.bound_box]
        bx0, bx1 = min(p.x for p in ps), max(p.x for p in ps)
        gz0, gz1 = min(-p.y for p in ps), max(-p.y for p in ps)
        h0, h1 = min(p.z for p in ps), max(p.z for p in ps)
        if bx1 < x0 or bx0 > x1 or gz1 < z0 or gz0 > z1 or h0 > 4:
            continue
        if (bx1 - bx0) > 30 or (gz1 - gz0) > 30:
            continue   # pavimento e muri interi
        print(f'  {o.name:40s} x {bx0:6.2f}..{bx1:6.2f}  z {gz0:6.2f}..{gz1:6.2f}  y {h0:5.2f}..{h1:5.2f}')
