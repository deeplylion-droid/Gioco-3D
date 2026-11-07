# I bordi aperti del guanto raggruppati in anelli: lunghezza e centro (glTF), per sapere se il polsino è aperto
import bpy, bmesh, sys
from mathutils import Vector
G = sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=G)
o = [x for x in bpy.data.objects if x.type == 'MESH'][0]
bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
aperti = set(e for e in bm.edges if len(e.link_faces) == 1)
gruppi = []
while aperti:
    e = aperti.pop(); g = [e]; coda = [e]
    while coda:
        x = coda.pop()
        for v in x.verts:
            for y in v.link_edges:
                if y in aperti:
                    aperti.remove(y); g.append(y); coda.append(y)
    gruppi.append(g)
print("anelli di bordi aperti: %d" % len(gruppi))
for g in sorted(gruppi, key=lambda g: -sum(e.calc_length() for e in g))[:12]:
    c = sum(((e.verts[0].co + e.verts[1].co) / 2 for e in g), Vector()) / len(g)
    print("  %d spigoli, lunghi %.1f cm in tutto, centro glTF (%.3f, %.3f, %.3f)" % (len(g), sum(e.calc_length() for e in g) * 100, c.x, c.z, -c.y))
# parti staccate (isole)
isole = 0; viste = set()
for f in bm.faces:
    if f in viste: continue
    isole += 1; coda = [f]; viste.add(f)
    while coda:
        x = coda.pop()
        for e in x.edges:
            for y in e.link_faces:
                if y not in viste:
                    viste.add(y); coda.append(y)
print("isole (pezzi separati): %d" % isole)
