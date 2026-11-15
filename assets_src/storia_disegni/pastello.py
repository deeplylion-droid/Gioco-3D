"""Il pastello a cera lasciato per terra sotto un disegno del bambino con la scatola (build 0.5.0, componente
DisegnoBambino): un pastello da bambini, prisma a otto facce di 1,1 cm, lungo 8,5 cm, con la punta consumata e la
fascetta di carta. È sdraiato su una faccia (non rotola): l'origine è sul pavimento, sotto il centro, e l'asse lungo è
X. Colore turchese, quello della firma. Esporta godot/assets/storia_disegni/pastello.glb.
Uso: /home/user/tools/blender-venv/bin/python pastello.py   (sotto flock /home/user/tools/render.lock)"""
import math
import os

import bpy
import bmesh

QUI = os.path.dirname(os.path.abspath(__file__))
USCITA = os.path.join(QUI, '..', '..', 'godot', 'assets', 'storia_disegni', 'pastello.glb')

LATI = 8
RAGGIO = 0.0055         # al centro delle facce: 1,1 cm di spessore
LUNGO = 0.085           # il corpo
PUNTA = 0.011           # la punta consumata, smussata
CARTA = (0.012, 0.072)  # la fascetta di carta, da x a x (dalla coda)
CERA = (0.10, 0.62, 0.62, 1.0)
CARTA_COL = (0.86, 0.85, 0.80, 1.0)


def materiale(nome: str, colore, ruvido: float) -> bpy.types.Material:
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = colore
    b.inputs['Roughness'].default_value = ruvido
    return m


def prisma(nome: str, r: float, x0: float, x1: float, punta: float = 0.0) -> bpy.types.Object:
    """Un prisma a [LATI] facce lungo X da x0 a x1; con [punta] la fine a x1 si stringe in un cono smussato."""
    me = bpy.data.meshes.new(nome)
    bm = bmesh.new()
    # una faccia giù: l'angolo dei vertici sfasato di mezzo lato
    raggio_v = r / math.cos(math.pi / LATI)
    anelli = []
    sezioni = [(x0, 1.0), (x1, 1.0)]
    if punta > 0.0:
        sezioni += [(x1 + punta * 0.6, 0.55), (x1 + punta, 0.22)]
    for x, s in sezioni:
        anello = []
        for k in range(LATI):
            a = 2 * math.pi * (k + 0.5) / LATI - math.pi / 2
            anello.append(bm.verts.new((x, raggio_v * s * math.cos(a), raggio_v * s * math.sin(a))))
        anelli.append(anello)
    for i in range(len(anelli) - 1):
        for k in range(LATI):
            a, b = anelli[i][k], anelli[i][(k + 1) % LATI]
            c, d = anelli[i + 1][(k + 1) % LATI], anelli[i + 1][k]
            bm.faces.new((a, b, c, d))
    bm.faces.new(list(reversed(anelli[0])))
    bm.faces.new(anelli[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cera = materiale('pastello_cera', CERA, 0.55)
    carta = materiale('pastello_carta', CARTA_COL, 0.9)
    meta = LUNGO / 2
    corpo = prisma('pastello', RAGGIO, -meta, meta - PUNTA, PUNTA)
    corpo.data.materials.append(cera)
    # la fascetta di carta: appena più larga del corpo (0,2 mm), sopra il corpo
    fascetta = prisma('pastello_carta', RAGGIO + 0.0002, -meta + CARTA[0], -meta + CARTA[1])
    fascetta.data.materials.append(carta)
    # tutto sul pavimento: la faccia di sotto a y = 0 (Blender: z = 0)
    # (la fascetta, 0,2 mm più larga, è quella che tocca; il corpo resta 0,2 mm sopra)
    corpo.location.z = RAGGIO + 0.0002
    fascetta.location.z = RAGGIO + 0.0002
    bpy.context.view_layer.update()
    # una mesh sola (il controllo di posizionamento guarda l'oggetto intero)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = corpo
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    corpo.name = 'pastello'
    os.makedirs(os.path.dirname(USCITA), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=USCITA, export_format='GLB', use_selection=True, export_yup=True)
    zs = [v.co.z for v in corpo.data.vertices]
    print('pastello:', os.path.getsize(USCITA), 'byte, z da %.4f a %.4f' % (min(zs), max(zs)))


if __name__ == '__main__':
    main()
