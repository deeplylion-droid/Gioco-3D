"""Toglie la piega sul bordo del cappello del fungo-fontana HD (scelta dell'utente del 17 ottobre: "sistema la
piega sul bordo del cappello del fungo").

Meshy ha lasciato sul cappello una piega verticale che scende fino al bordo (azimut circa -50 gradi, nelle
coordinate del GLB, Z in alto): è nella forma e soprattutto nelle texture (colore, ORM e normal map). Il
cappello è quasi a simmetria di rotazione, quindi la zona della piega si rifà copiando una parte sana dello
stesso cappello, ruotata attorno all'asse (ROTAZIONE gradi), con un bordo sfumato:
  - forma: ogni vertice della zona prende il raggio della superficie sana alla stessa quota;
  - texture: ogni texel delle facce della zona prende colore, ORM e normal map del punto corrispondente della
    parte sana (la fascia è stretta e quasi verticale: le isole UV vicine hanno lo stesso orientamento).
Legge fungo_fontana_originale.glb (il modello di Meshy con le texture 2K) e scrive fungo_fontana.glb; l'originale
4K resta in grezzi_4k/.

Uso: /home/user/tools/blender-venv/bin/python assets_src/ambiente/bimbi_hq/fungo_piega.py [--prova render.png]
"""
import math, os, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(QUI, '..', '..', '..', 'tools', 'blender')))
import bimbi_hq as H  # noqa: E402

AZIMUT = -50.0        # centro della piega (gradi)
LARGO = 16.0          # mezza larghezza della zona rifatta (gradi), sfumata negli ultimi SFUMA gradi
SFUMA = 7.0
Z_MIN, Z_MAX = 0.06, 0.36   # quote della zona (unità del GLB: il fungo va da -0.9 a 0.9; sopra c'è un pois)
ROTAZIONE = 60.0      # da dove si copia: la stessa zona ruotata di tanti gradi (parte sana)


def peso_zona(p):
    """0 fuori dalla zona, 1 dentro, sfumato ai lati e in alto."""
    r = math.hypot(p.x, p.y)
    if r < 0.55 or p.z < Z_MIN or p.z > Z_MAX:
        return 0.0
    da = abs((math.degrees(math.atan2(p.y, p.x)) - AZIMUT + 180.0) % 360.0 - 180.0)
    wa = max(0.0, min(1.0, (LARGO - da) / SFUMA))
    wz = min(1.0, (p.z - Z_MIN) / 0.03) * min(1.0, (Z_MAX - p.z) / 0.08)
    return wa * wz


def ruota(p, gradi):
    return Matrix.Rotation(math.radians(gradi), 3, 'Z') @ p


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    prova = argv[argv.index('--prova') + 1] if '--prova' in argv else ''
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src = os.path.join(QUI, 'fungo_fontana_originale.glb')
    dst = os.path.join(QUI, 'fungo_fontana.glb')
    ob = H.importa_unito(src, 'fungo_fontana')
    me = ob.data

    # --- forma: la superficie sana di riferimento (prima di toccare niente)
    bm = bmesh.new()
    bm.from_mesh(me)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    uv = me.uv_layers.active.data
    mosse = 0
    for v in me.vertices:
        w = peso_zona(v.co)
        if w <= 0.0:
            continue
        q = ruota(v.co, ROTAZIONE)
        hit = bvh.find_nearest(q)
        if hit[0] is None:
            continue
        r_sana = math.hypot(hit[0].x, hit[0].y)
        r = math.hypot(v.co.x, v.co.y)
        if r > 1e-6:
            k = 1.0 + w * (r_sana / r - 1.0)
            v.co.x *= k
            v.co.y *= k
            mosse += 1
    me.update()
    print('vertici rimessi in forma:', mosse)

    # --- texture: per ogni faccia della zona, i texel prendono il colore del punto sano corrispondente
    mat = me.materials[0]
    immagini = {}
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image:
            uso = n.outputs[0].links[0].to_node.type if n.outputs[0].links else ''
            immagini[n.image.name] = (n.image, uso)
    pix = {}
    for nome, (im, uso) in immagini.items():
        w_, h_ = im.size
        pix[nome] = (np.array(im.pixels[:], dtype=np.float32).reshape(h_, w_, 4), w_, h_, uso)
    orig = {k: v[0].copy() for k, v in pix.items()}

    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    bvh2 = BVHTree.FromBMesh(bm)

    def uv_di(f, p):
        """UV del punto p sulla faccia (triangolo) f."""
        a, b, c = [l.vert.co for l in f.loops[:3]]
        ta, tb, tc = [l[uvl].uv for l in f.loops[:3]]
        v0, v1, v2 = b - a, c - a, p - a
        d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
        d20, d21 = v2.dot(v0), v2.dot(v1)
        den = d00 * d11 - d01 * d01 or 1e-12
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        return ta * (1 - bv - bw) + tb * bv + tc * bw

    texel = 0
    for f in bm.faces:
        cen = f.calc_center_median()
        if peso_zona(cen) <= 0.0 or len(f.loops) != 3:
            continue
        pts3 = [l.vert.co.copy() for l in f.loops]
        tuv = [l[uvl].uv.copy() for l in f.loops]
        for nome, (arr, w_, h_, uso) in pix.items():
            xs = [t.x * w_ for t in tuv]; ys = [t.y * h_ for t in tuv]
            x0, x1 = int(max(0, math.floor(min(xs)))), int(min(w_ - 1, math.ceil(max(xs))))
            y0, y1 = int(max(0, math.floor(min(ys)))), int(min(h_ - 1, math.ceil(max(ys))))
            (ax, ay), (bx, by), (cx, cy) = zip(xs, ys)
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9:
                continue
            for py in range(y0, y1 + 1):
                for px in range(x0, x1 + 1):
                    sx, sy = px + 0.5, py + 0.5
                    l1 = ((by - cy) * (sx - cx) + (cx - bx) * (sy - cy)) / den
                    l2 = ((cy - ay) * (sx - cx) + (ax - cx) * (sy - cy)) / den
                    l3 = 1 - l1 - l2
                    if min(l1, l2, l3) < -0.02:
                        continue
                    p = pts3[0] * l1 + pts3[1] * l2 + pts3[2] * l3
                    w = peso_zona(p)
                    if w <= 0.0:
                        continue
                    if True:
                        hit = bvh2.find_nearest(ruota(p, ROTAZIONE))
                        if hit[0] is None:
                            continue
                        t = uv_di(bm.faces[hit[2]], hit[0])
                        qx = min(w_ - 1, max(0, int(t.x * w_))); qy = min(h_ - 1, max(0, int(t.y * h_)))
                        nuovo = orig[nome][qy, qx]
                    arr[py, px] = arr[py, px] * (1 - w) + nuovo * w
                    texel += 1
    bm.free()
    for nome, (arr, w_, h_, uso) in pix.items():
        immagini[nome][0].pixels[:] = arr.ravel()
        immagini[nome][0].pack()
    print('texel rifatti:', texel)

    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=dst, use_selection=True, export_format='GLB', export_image_format='JPEG',
                              export_image_quality=92)
    print('salvato', dst, os.path.getsize(dst) // 1000, 'kB')
    if prova:
        render_prova(ob, prova)


def render_prova(ob, out):
    """Il fungo da vicino, come render_fungo_vicino di bimbi_hq_render.py (camera sulla piega)."""
    lo, hi = H.limiti(ob.data)
    ob.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    ob.data.transform(Matrix.Scale(2.0 / (hi.z - lo.z), 4))
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = (2.0, -2.2, 1.7)
    cam.rotation_euler = (Vector((0.1, 0, 1.35)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = 35
    sole = bpy.data.objects.new('sole', bpy.data.lights.new('sole', 'SUN'))
    sc.collection.objects.link(sole)
    sole.rotation_euler = (0.6, 0.3, 0.4)
    sole.data.energy = 3
    sc.world = bpy.data.worlds.new('mondo')
    sc.world.color = (0.4, 0.4, 0.4)
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 24
    sc.render.resolution_x, sc.render.resolution_y = 800, 500
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    main()
