#!/usr/bin/env python3
"""Asset 3D dello zaino-pompa per Godot, con Blender come modulo (bpy).

Comandi:
  mani <cartella>
      Mani in guanti da lavoro (grafica neutra): mano_impugnatura.glb (su un'impugnatura
      verticale) e mano_tubo.glb (su un tubo orizzontale). Fatte con forme semplici fuse da
      un remesh a voxel, poi lisciate e alleggerite.
  zaino <in.glb> <out.glb> <altezza_m> [texture_px]
      Sistema un GLB di Meshy: scala all'altezza voluta, base a terra, centrato; texture
      ridotte (default 1024 px).
  lancia <in.glb> <out.glb> <lunghezza_m> <asse> <punta>
      Come sopra, ma allinea la lancia lungo -Z con la punta (l'uscita dell'acqua) in avanti
      e mette l'origine sulla punta. <asse> = x|y|z|auto: asse lungo del modello (in Blender);
      <punta> = + | - | auto: verso della punta su quell'asse (auto: il retro è dove sta il
      punto più basso, cioè l'impugnatura o il tubo che pende).
  anteprima <in.glb> <out.png>
      Render veloce (Workbench) per controllare un modello.

Uso: /home/user/tools/blender-venv/bin/python tools/godot_zaino_blender.py <comando> ...
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = rough
    return m


def capsule(a, b, r, parts):
    """Cilindro con le estremità sferiche tra i punti a e b (raggio r)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, vertices=16, location=(a + b) / 2)
    cyl = bpy.context.active_object
    cyl.rotation_mode = 'QUATERNION'
    cyl.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    parts.append(cyl)
    for p in (a, b):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=16, ring_count=8, location=p)
        parts.append(bpy.context.active_object)


def ellipsoid(center, size, rot, parts):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=24, ring_count=12, location=center)
    o = bpy.context.active_object
    o.scale = size
    o.rotation_euler = rot
    parts.append(o)


def fuse(parts, name, voxel, mat, target_faces):
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    rm = obj.modifiers.new('remesh', 'REMESH')
    rm.mode = 'VOXEL'
    rm.voxel_size = voxel
    sm = obj.modifiers.new('smooth', 'SMOOTH')
    sm.factor = 0.6
    sm.iterations = 6
    bpy.ops.object.modifier_apply(modifier='remesh')
    bpy.ops.object.modifier_apply(modifier='smooth')
    faces = len(obj.data.polygons)
    if faces > target_faces:
        dec = obj.modifiers.new('decimate', 'DECIMATE')
        dec.ratio = target_faces / faces
        bpy.ops.object.modifier_apply(modifier='decimate')
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def finger_arc(center_axis, axis, radius, y, a0, a1, r_finger, parts, segments=3):
    """Dito piegato intorno a un cilindro: arco di 'segments' falangi tra gli angoli a0 e a1."""
    pts = []
    for i in range(segments + 1):
        t = a0 + (a1 - a0) * i / segments
        if axis == 'y':
            p = Vector((math.cos(t) * radius, y, math.sin(t) * radius))
        else:  # asse z: tubo orizzontale
            p = Vector((math.cos(t) * radius, math.sin(t) * radius, y))
        pts.append(Vector(center_axis) + p)
    for i in range(segments):
        capsule(pts[i], pts[i + 1], r_finger * (1.0 - 0.08 * i), parts)
    return pts


def build_right_hand(glove, sleeve):
    """Mano destra su un'impugnatura verticale (asse Y, raggio 0,02 m, centro nell'origine).
    Il dorso della mano guarda a destra (+X), le dita girano davanti (-Z) verso sinistra."""
    parts = []
    gr = 0.02 + 0.012  # raggio dell'impugnatura + spessore del dito
    for i, y in enumerate([0.028, 0.008, -0.012, -0.03]):
        r = 0.0115 - i * 0.0008
        finger_arc((0, 0, 0), 'y', gr, y, math.radians(-20), math.radians(-200), r, parts)
    # Palmo sul lato destro-dietro dell'impugnatura.
    ellipsoid((0.03, 0.0, 0.012), (0.022, 0.052, 0.036), (0, math.radians(-25), 0), parts)
    # Pollice: sopra, verso sinistra.
    capsule((0.022, 0.04, 0.022), (-0.005, 0.052, -0.012), 0.012, parts)
    capsule((-0.005, 0.052, -0.012), (-0.03, 0.05, -0.02), 0.0105, parts)
    hand = fuse(parts, 'ManoDestra', 0.0022, glove, 4500)
    # Polso e manica: verso la camera (+Z) e un po' in basso a destra.
    parts = []
    capsule((0.032, -0.012, 0.035), (0.06, -0.09, 0.25), 0.033, parts)
    capsule((0.06, -0.09, 0.25), (0.08, -0.15, 0.45), 0.045, parts)
    arm = fuse(parts, 'ManicaDestra', 0.004, sleeve, 1500)
    return hand, arm


def build_left_hand(glove, sleeve):
    """Mano sinistra su un tubo orizzontale (asse Z, raggio 0,013 m, centro nell'origine):
    le dita passano sotto il tubo da sinistra, il pollice sta sopra."""
    parts = []
    tr = 0.013 + 0.0115
    for i, z in enumerate([-0.03, -0.01, 0.01, 0.03]):
        r = 0.011 - i * 0.0007
        finger_arc((0, 0, 0), 'z', tr, z, math.radians(200), math.radians(370), r, parts)
    ellipsoid((-0.03, -0.006, 0.0), (0.02, 0.034, 0.05), (0, 0, math.radians(-15)), parts)
    capsule((-0.018, 0.02, 0.025), (0.004, 0.032, -0.01), 0.0115, parts)
    capsule((0.004, 0.032, -0.01), (0.012, 0.028, -0.035), 0.01, parts)
    hand = fuse(parts, 'ManoSinistra', 0.0022, glove, 4500)
    parts = []
    capsule((-0.04, -0.01, 0.025), (-0.12, -0.07, 0.2), 0.032, parts)
    capsule((-0.12, -0.07, 0.2), (-0.17, -0.13, 0.42), 0.044, parts)
    arm = fuse(parts, 'ManicaSinistra', 0.004, sleeve, 1500)
    return hand, arm


def cmd_mani(out_dir):
    """Due file: mano_impugnatura.glb (mano destra su un'impugnatura verticale, asse Y)
    e mano_tubo.glb (mano sinistra su un tubo orizzontale, asse Z). Origine sull'asse
    dell'impugnatura o del tubo; in Godot si specchia la seconda per l'altra mano."""
    import os
    g2b = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    for name, builder in (('mano_impugnatura', build_right_hand), ('mano_tubo', build_left_hand)):
        reset()
        glove = material('Guanto', (0.07, 0.075, 0.08), 0.55)
        sleeve = material('Manica', (0.11, 0.12, 0.14), 0.85)
        hand, arm = builder(glove, sleeve)
        # Costruite in coordinate di Godot (Y in alto, -Z avanti): si portano in quelle di Blender.
        for o in (hand, arm):
            o.data.transform(g2b)
        export(os.path.join(out_dir, name + '.glb'))
        print('mani:', name, len(hand.data.polygons) + len(arm.data.polygons), 'facce')


def import_glb(path):
    reset()
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    return obj


def bounds(obj):
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def shrink_textures(size):
    """Riduce le texture (gli zaini interi si vedono da lontano: bastano 1024 px)."""
    for img in bpy.data.images:
        if img.size[0] > size:
            img.scale(size, size)


def cmd_zaino(src, out, height, tex_size='1024'):
    obj = import_glb(src)
    shrink_textures(int(tex_size))
    lo, hi = bounds(obj)
    s = float(height) / (hi.z - lo.z)  # in Blender l'alto è Z
    center = (lo + hi) / 2
    obj.data.transform(Matrix.Translation(-Vector((center.x, center.y, lo.z))))
    obj.data.transform(Matrix.Scale(s, 4))
    obj.name = 'Zaino'
    export(out)
    lo, hi = bounds(obj)
    print('zaino:', len(obj.data.polygons), 'facce, misure', tuple(round(v, 3) for v in (hi - lo)))


def cmd_lancia(src, out, length, axis, tip):
    obj = import_glb(src)
    lo, hi = bounds(obj)
    size = hi - lo
    idx = max(range(3), key=lambda i: size[i]) if axis == 'auto' else 'xyz'.index(axis)
    s = float(length) / (hi[idx] - lo[idx])
    center = (lo + hi) / 2
    obj.data.transform(Matrix.Translation(-center))
    obj.data.transform(Matrix.Scale(s, 4))
    if tip == 'auto':
        # Il retro è l'estremità più vicina al punto più basso (impugnatura o tubo che pende).
        low = min(obj.data.vertices, key=lambda v: v.co.z).co
        tip = '-' if low[idx] > 0 else '+'
        print('punta trovata sul lato', tip, 'dell\'asse', 'xyz'[idx])
    # Porta l'asse lungo su +Y di Blender (= avanti, -Z in Godot) con la punta in avanti.
    direction = Vector((0, 0, 0))
    direction[idx] = 1.0 if tip == '+' else -1.0
    rot = direction.rotation_difference(Vector((0, 1, 0)))  # Blender +Y = Godot -Z
    obj.data.transform(rot.to_matrix().to_4x4())
    lo, hi = bounds(obj)
    # Origine alla punta della lancia (centro della sezione all'estremità +Y).
    obj.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, hi.y, (lo.z + hi.z) / 2))))
    obj.name = 'Lancia'
    export(out)
    lo, hi = bounds(obj)
    print('lancia:', len(obj.data.polygons), 'facce, misure', tuple(round(v, 3) for v in (hi - lo)))


def export(out):
    """Esporta in glTF separato (.gltf + .bin + texture JPEG) dentro una cartella col nome del
    modello: Godot importa le texture una volta sola (con un .glb le estrarrebbe e duplicherebbe)."""
    import os
    base = os.path.splitext(out)[0]
    os.makedirs(base, exist_ok=True)
    path = os.path.join(base, os.path.basename(base) + '.gltf')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', export_apply=True,
                              export_yup=True, export_image_format='JPEG', export_jpeg_quality=88,
                              export_image_quality=88)


def cmd_anteprima(src, out):
    reset()
    bpy.ops.import_scene.gltf(filepath=src)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x = 900
    scene.render.resolution_y = 600
    meshes = [o for o in scene.objects if o.type == 'MESH']
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in meshes:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    c = (lo + hi) / 2
    r = (hi - lo).length
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    scene.collection.objects.link(cam)
    cam.location = c + Vector((r * 0.9, -r * 1.1, r * 0.6))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    world = bpy.data.worlds.new('w')
    world.color = (0.2, 0.2, 0.22)
    scene.world = world
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print('anteprima:', out)


if __name__ == '__main__':
    cmd, args = sys.argv[1], sys.argv[2:]
    {'mani': cmd_mani, 'zaino': cmd_zaino, 'lancia': cmd_lancia, 'anteprima': cmd_anteprima}[cmd](*args)
