"""Chiude i tagli in cima alle basi degli acquari (godot/assets/enigma_acquari/cilindro_base.glb, quella degli alti,
e cilindro_base_bassa.glb, quella del miscuglio).

prepara_modelli.py taglia le basi (gli alti a 0,8493, il fondo del vetro; il basso a 0,40) e chiude il taglio con
holes_fill, ma il modello di Meshy ha i vertici doppi lungo le cuciture e i bordi del taglio non fanno anelli chiusi:
il taglio restava aperto. Meshy ha fatto il boiler pieno (senza pareti dentro), e una base aperta in cima è un
cilindro pieno senza coperchio: per il controllo di posizionamento, che decide il "dentro" col verso delle facce,
tutto quello che sta sotto il taglio è dentro la base (le gambe del vetro del miscuglio e il basamento del vetro
degli alti, 23 ottobre). Qui si trovano gli anelli del taglio su una copia coi vertici uniti e si aggiungono al
modello vero le facce che li chiudono, tutte, verso l'alto: la cima della base diventa un piano al livello del fondo
del vetro, e il vetro ci poggia sopra. Le facce nuove prendono il colore della cima della base: tutte le coordinate
UV su un punto del bordo del taglio col colore più comune lì (la mediana dei punti del bordo).
Si può rilanciare: un taglio già chiuso non ha più anelli aperti.
Uso: /home/user/tools/blender-venv/bin/python assets_src/enigma_acquari/chiudi_tagli.py"""
import os
import bpy
import bmesh   # (dopo bpy, che lo registra)
import numpy as np

QUI = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(QUI, '..', '..', 'godot', 'assets', 'enigma_acquari')
BASI = (('cilindro_base.glb', 0.8493), ('cilindro_base_bassa.glb', 0.40))   # la quota del taglio (z di Blender)


def pixel(img):
    w, h = img.size
    px = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, img.channels)


def colore_uv(px, uv):
    h, w = px.shape[:2]
    x = min(w - 1, max(0, int(uv[0] % 1.0 * w)))
    y = min(h - 1, max(0, int(uv[1] % 1.0 * h)))
    return px[y, x, :3]


for nome, taglio in BASI:
    glb = os.path.join(DIR, nome)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    o = [x for x in bpy.context.scene.objects if x.type == 'MESH'][0]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    uvl = bm.loops.layers.uv.active
    # gli anelli del taglio, sulla copia coi vertici uniti
    copia = bm.copy()
    bmesh.ops.remove_doubles(copia, verts=copia.verts, dist=1e-5)
    bordo = [e for e in copia.edges if e.is_boundary and min(v.co.z for v in e.verts) > taglio - 0.001]
    nuove = bmesh.ops.holes_fill(copia, edges=bordo, sides=0)['faces']
    tappi = [[v.co.copy() for v in f.verts] for f in nuove]
    print('%s: anelli del taglio %d (aree %s)' % (nome, len(nuove), ', '.join('%.4f' % f.calc_area() for f in nuove)))
    copia.free()
    if not tappi:
        bm.free()
        continue
    # il colore della cima: i punti UV dei vertici sul taglio, nelle facce vere che ci arrivano
    img = None
    for m in o.data.materials:
        for n in (m.node_tree.nodes if m and m.node_tree else []):
            if n.type == 'TEX_IMAGE' and n.image:
                img = img or n.image
    cand = [l[uvl].uv.copy() for f in bm.faces for l in f.loops if abs(l.vert.co.z - taglio) < 1e-4]
    uv_cima = cand[0] if cand else (0.5, 0.5)
    if img and cand:
        px = pixel(img)
        col = np.array([colore_uv(px, uv) for uv in cand])
        med = np.median(col, axis=0)
        uv_cima = cand[int(np.argmin(((col - med) ** 2).sum(1)))]
        print('  colore della cima', np.round(med, 3), 'uv', tuple(round(c, 4) for c in uv_cima))
    # le facce nuove nel modello vero, coi vertici loro, verso l'alto
    for punti in tappi:
        f = bm.faces.new([bm.verts.new(p) for p in punti])
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
        for l in f.loops:
            l[uvl].uv = uv_cima
        bmesh.ops.triangulate(bm, faces=[f])
    bm.to_mesh(o.data)
    bm.free()
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_yup=True)
    print('salvato', glb)
