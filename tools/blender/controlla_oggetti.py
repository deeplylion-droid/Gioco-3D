"""Controllo degli oggetti che galleggiano o entrano nei muri, sui glTF esportati per Godot.
Per ogni oggetto separato (non le strutture unite *_statico / CAMERA_* / SALA_*, non le collisioni) guarda:
  - galleggia: nessuna superficie entro 3 cm da nessuna delle sei facce della sua scatola;
  - entra: un raggio dal centro verso una faccia trova la struttura più di 4 cm dentro la scatola
    (solo per oggetti piccoli, sotto i 2,5 m: le strutture grandi si toccano per forza).
Uso: /home/user/tools/blender-venv/bin/python tools/blender/controlla_oggetti.py file.gltf [...]"""
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

STRUTTURE = ('_statico', 'CAMERA_', 'SALA_', 'RACCORDO_')
SALTA = ('colonly', 'acqua', 'ACQUA', 'LUCE', 'luce', 'emit_', 'marker', 'PUNTO', 'VAPORE', 'ARIA_')


def bvh_di(obs):
    vs, fs = [], []
    for o in obs:
        me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        b = len(vs)
        vs += [o.matrix_world @ v.co for v in me.vertices]
        fs += [tuple(b + i for i in p.vertices) for p in me.polygons]
    return BVHTree.FromPolygons(vs, fs) if fs else None


def controlla(file):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=file)
    bpy.context.view_layer.update()
    mesh = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not any(s in o.name for s in SALTA)]
    strutt = [o for o in mesh if any(s in o.name for s in STRUTTURE)]
    oggetti = [o for o in mesh if o not in strutt]
    print(f'\n== {file}: {len(oggetti)} oggetti, {len(strutt)} strutture')
    tutto = bvh_di(mesh)
    solo_strutt = bvh_di(strutt)
    for o in oggetti:
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector([min(v[i] for v in bb) for i in range(3)]); hi = Vector([max(v[i] for v in bb) for i in range(3)])
        c = (lo + hi) / 2; d = hi - lo
        if max(d) < 0.02:
            continue
        altri = bvh_di([x for x in mesh if x is not o])
        # galleggia?
        tocca = False
        for asse in range(3):
            for s in (-1, 1):
                dirv = Vector((0, 0, 0)); dirv[asse] = s
                for f1 in (-0.3, 0.0, 0.3):
                    for f2 in (-0.3, 0.0, 0.3):
                        p = c.copy(); p[asse] = (hi if s > 0 else lo)[asse] - s * 0.01
                        a1, a2 = [i for i in range(3) if i != asse]
                        p[a1] += f1 * d[a1]; p[a2] += f2 * d[a2]
                        h = altri.ray_cast(p, dirv, 0.04) if altri else (None,)
                        if h[0] is not None:
                            tocca = True
                            break
                    if tocca:
                        break
                if tocca:
                    break
            if tocca:
                break
        if not tocca:
            print(f'  GALLEGGIA  {o.name:40s} centro ({c.x:.2f}, {c.y:.2f}, {c.z:.2f})  dim ({d.x:.2f}, {d.y:.2f}, {d.z:.2f})')
        # entra nei muri?
        if max(d) < 2.5 and solo_strutt:
            for asse in range(3):
                for s in (-1, 1):
                    dirv = Vector((0, 0, 0)); dirv[asse] = s
                    h = solo_strutt.ray_cast(c, dirv, d[asse] / 2)
                    if h[0] is not None:
                        dentro = d[asse] / 2 - (h[0] - c).length
                        if dentro > 0.04 and h[1].dot(dirv) < 0:
                            print(f'  ENTRA      {o.name:40s} di {dentro * 100:.0f} cm verso {"-+"[s > 0]}{"XYZ"[asse]}'
                                  f'  centro ({c.x:.2f}, {c.y:.2f}, {c.z:.2f})')


for f in [a for a in sys.argv[1:] if a.endswith('.gltf') or a.endswith('.glb')]:
    controlla(f)
