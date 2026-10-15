"""Dal GLB grezzo di Meshy al GLB del repo: scala reale, piedi a terra, facce ridotte.

Uso:
    nice -n 10 /home/user/tools/blender-venv/bin/python tools/blender/bambini_esporta.py \
        <grezzo.glb> <nome> [--facce 150000] [--cartella game] [--uscita file.glb]
        [--muta-opaca 0.55] [--bordo-texture 16]

<nome> è una chiave di MODELLI in bambini_comune.py (dà file e altezza). Il modello esce in
assets_src/bambini/<file>, con le texture di Meshy (2K, colore, metallo/rugosità, normali) in JPEG.
I grezzi di Meshy (circa 1-3 milioni di facce, 40-56 MB) non vanno nel repo.

Versioni leggere per il gioco (circa 25 mila triangoli, stesse texture 2K), dai GLB del repo:
    ... bambini_esporta.py assets_src/bambini/<file> <nome> --facce 25000 --cartella game
Prima di ridurre le facce si saldano i vertici doppi delle cuciture UV (altrimenti si aprono
fessure: crepe nere) e i colori delle texture si allargano oltre i bordi delle isole UV
(--bordo-texture, in pixel), così i triangoli più grandi non pescano il nero tra un'isola e l'altra. Il guscio dell'occhio dell'agnellino
('occhio_bulbo') non passa di qui: si rifà sul modello finale con bambini_occhio.py.
"""
import argparse, os, sys
import numpy as np
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bambini_comune as B  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('grezzo'); ap.add_argument('nome')
ap.add_argument('--facce', type=int, default=150000)
ap.add_argument('--cartella', default='', help="sottocartella di assets_src/bambini (es. 'game')")
ap.add_argument('--uscita', default='', help='percorso del GLB in uscita (al posto di cartella/file)')
ap.add_argument('--muta-opaca', type=float, default=0.0,
                help='rugosità minima delle parti scure (la muta di neoprene): niente effetto vinile')
ap.add_argument('--bordo-texture', type=int, default=16)
a = ap.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])

file, altezza = B.MODELLI[a.nome]
bpy.ops.wm.read_factory_settings(use_empty=True)
perno = B.importa(a.grezzo, altezza, nome=a.nome)
mesh = B.mesh_di(perno)
for o in [o for o in mesh if o.name.startswith('occhio_bulbo')]:
    B.log('tolgo', o.name, '(si rifà con bambini_occhio.py)')
    mesh.remove(o)
    bpy.data.objects.remove(o, do_unlink=True)
corpo = max(mesh, key=lambda o: len(o.data.polygons))


def immagini(o):
    out = []
    for m in o.data.materials:
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image and n.image not in out:
                out.append(n.image)
    return out


def bordo_texture(o, passi):
    """Allarga i colori di ogni texture oltre i bordi delle isole UV usate dalla mesh (a ogni passo
    i pixel vuoti vicini a quelli pieni prendono la media dei vicini pieni)."""
    import cv2
    me = o.data
    me.calc_loop_triangles()
    uv = np.zeros(len(me.loops) * 2, np.float32); me.uv_layers.active.data.foreach_get('uv', uv)
    uv = uv.reshape(-1, 2)
    tri = np.zeros(len(me.loop_triangles) * 3, np.int32); me.loop_triangles.foreach_get('loops', tri)
    tri = tri.reshape(-1, 3)
    for img in immagini(o):
        W, H = img.size
        pts = np.round(uv[tri] * [W, H] - 0.5).astype(np.int32)        # riga 0 = v 0 (in basso)
        pieno = np.zeros((H, W), np.uint8)
        cv2.fillPoly(pieno, list(pts), 1)
        pieno = cv2.dilate(pieno, np.ones((3, 3), np.uint8)).astype(bool)
        px = np.empty(W * H * 4, np.float32); img.pixels.foreach_get(px)
        px = px.reshape(H, W, 4)
        vuoti0 = (~pieno).mean()
        for _ in range(passi):
            m = pieno.astype(np.float32)
            somma = cv2.blur(px * m[..., None], (3, 3))
            conta = cv2.blur(m, (3, 3))
            nuovi = (conta > 0) & ~pieno
            px[nuovi] = somma[nuovi] / conta[nuovi][:, None]
            pieno |= nuovi
        img.pixels.foreach_set(px.ravel())
        img.update()
        B.log(f'bordo texture {img.name}: {100 * vuoti0:.0f}% di pixel fuori dalle isole, +{passi} px')


if a.bordo_texture > 0:
    bordo_texture(corpo, a.bordo_texture)
n = len(corpo.data.polygons)
if n > a.facce:
    # Meshy esporta vertici doppi lungo le cuciture UV: senza saldarli, ridurre le facce apre
    # fessure tra le isole (crepe nere). Saldati, le cuciture restano solo nelle UV.
    import bmesh
    bm = bmesh.new(); bm.from_mesh(corpo.data)
    prima = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    B.log(f'saldati {prima - len(bm.verts)} vertici doppi')
    bm.to_mesh(corpo.data); bm.free()
    mod = corpo.modifiers.new('riduci', 'DECIMATE')
    mod.ratio = a.facce / n
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = corpo
    bpy.ops.object.modifier_apply(modifier=mod.name)
B.log(a.nome, n, '->', len(corpo.data.polygons), 'facce')


if a.muta_opaca > 0:
    B.muta_opaca(corpo.data.materials, a.muta_opaca)
# applica scala e posizione del perno alle mesh, poi toglie il perno
bpy.ops.object.select_all(action='DESELECT')
for o in mesh:
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.data.objects.remove(perno, do_unlink=True)
corpo.name = a.nome  # i nomi solo ora: prima il perno aveva già il nome del modello
corpo.data.name = a.nome
for m in corpo.data.materials:
    m.name = a.nome
lo, hi = B.limiti(list(bpy.context.scene.objects))
B.log('misure (m)', tuple(round(v, 3) for v in hi - lo), 'min z', round(lo.z, 4))
if a.uscita:
    out = os.path.abspath(a.uscita)
else:
    cartella = os.path.join(B.ASSET, a.cartella) if a.cartella else B.ASSET
    out = os.path.join(cartella, file)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=False,
                          export_image_format='JPEG', export_jpeg_quality=90,
                          export_apply=True, export_yup=True)
B.log('scritto', os.path.relpath(out, B.REPO), f'{os.path.getsize(out) / 1e6:.1f} MB')
