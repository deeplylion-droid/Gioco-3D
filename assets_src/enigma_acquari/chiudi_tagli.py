"""Chiude i tagli in cima alla base bassa del miscuglio (godot/assets/enigma_acquari/cilindro_base_bassa.glb).

prepara_modelli.py taglia la base a 0,40 e chiude il taglio con holes_fill, ma il modello di Meshy ha i vertici doppi
lungo le cuciture e i bordi del taglio non fanno anelli chiusi: la pompa, il gruppo col tubo e un bocchettone restavano
aperti in cima (dalla pedana ci si vedeva dentro, e il controllo di posizionamento, che conta quante facce passa un
raggio, li prendeva per pieni fino in fondo). Qui si trovano gli anelli del taglio su una copia coi vertici uniti e si
aggiungono al modello vero le facce che li chiudono, solo quelle piccole: il cerchio grande del serbatoio resta aperto
(dentro c'è il fondo del vetro sulle sue gambe).
Uso: /home/user/tools/blender-venv/bin/python assets_src/enigma_acquari/chiudi_tagli.py"""
import os
import bpy
import bmesh   # (dopo bpy, che lo registra)

QUI = os.path.dirname(os.path.abspath(__file__))
GLB = os.path.join(QUI, '..', '..', 'godot', 'assets', 'enigma_acquari', 'cilindro_base_bassa.glb')
TAGLIO = 0.40        # la quota del taglio (unità del modello, z di Blender)
AREA_MAX = 0.1       # più grande di così è il serbatoio

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
o = [x for x in bpy.context.scene.objects if x.type == 'MESH'][0]
bm = bmesh.new()
bm.from_mesh(o.data)
# gli anelli del taglio, sulla copia coi vertici uniti
copia = bm.copy()
bmesh.ops.remove_doubles(copia, verts=copia.verts, dist=1e-5)
bordo = [e for e in copia.edges if e.is_boundary and min(v.co.z for v in e.verts) > TAGLIO - 0.001]
nuove = bmesh.ops.holes_fill(copia, edges=bordo, sides=0)['faces']
tappi = [[v.co.copy() for v in f.verts] for f in nuove if f.calc_area() < AREA_MAX]
print('anelli del taglio: %d, chiusi %d (aree %s)' % (len(nuove), len(tappi), ', '.join('%.4f' % f.calc_area() for f in nuove)))
copia.free()
# le facce nuove nel modello vero, coi vertici loro, verso l'alto
for punti in tappi:
    f = bm.faces.new([bm.verts.new(p) for p in punti])
    f.normal_update()
    if f.normal.z < 0:
        f.normal_flip()
    bmesh.ops.triangulate(bm, faces=[f])
bm.to_mesh(o.data)
bm.free()
bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB', export_yup=True)
print('salvato', GLB)
