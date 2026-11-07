# Guanto da cartone animato vecchio stile (richiesta dell'utente sulla 0.3.21: "creiamo un guanto tipo topolino,
# posizionato bene sul fucile ad acqua"): quattro dita grosse e tonde chiuse sull'impugnatura della lancia C1, pollice
# sopra, polsino arrotolato, tre cuciture sul dorso. Generico, non un personaggio.
# Si costruisce attorno all'impugnatura vera (lancia_c1_antincendio.gltf): ogni dito segue il contorno della sezione
# dell'impugnatura alla sua altezza, staccato del suo raggio; poi le parti si uniscono (remesh a voxel), si lisciano, e
# i vertici dal lato dell'impugnatura si appoggiano sulla sua superficie (niente compenetrazioni, niente distacchi).
# Il guanto esce già nelle coordinate della lancia (glTF: punta nell'origine, +Z verso chi guarda): nella scena della
# lancia va con posizione e rotazione zero.
# Uso: /home/user/tools/blender-venv/bin/python assets_src/guanto/genera_guanto.py [uscita.glb] [blend]
import bpy, bmesh, math, sys
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

LANCIA = "/home/user/Gioco-3D/godot/assets/models/zaino/proposte_lance/lancia_c1_antincendio/lancia_c1_antincendio.gltf"
OUT = next((a for a in sys.argv if a.endswith(".glb")), "/home/user/Gioco-3D/godot/assets/models/zaino/guanto/guanto_destro.glb")
BLEND = next((a for a in sys.argv if a.endswith(".blend")), None)

# misure (metri)
R_DITO = 0.0135          # raggio delle dita (cartone: grosse e tonde)
PASSO_DITA = 0.0255      # da un dito all'altro lungo l'impugnatura (si toccano appena)
Y_INDICE = -0.196        # altezza (glTF y) dell'indice, sotto il ponticello del grilletto
AGGIO = 0.0006           # quanto il dito sta fuori dalla superficie prima dell'appoggio
VOXEL = 0.0016
FACCE_GUANTO = 9000      # dopo la riduzione (si vede da vicino, ma è una mano sola)


def g2b(v):
    """glTF (x, y su, z verso chi guarda) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


def b2g(v):
    return Vector((v[0], v[2], -v[1]))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=LANCIA)
lancia = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('Lancia')][0]
bm_l = bmesh.new()
bm_l.from_mesh(lancia.data)
bm_l.transform(lancia.matrix_world)
bvh = BVHTree.FromBMesh(bm_l)


def contorno(gy, angoli, centro_xz=(0.002, 0.49), zmin=0.40, zmax=0.62):
    """Punti della superficie dell'impugnatura alla quota gy, per gli angoli dati (nel piano x-z glTF, 0 = +x,
    90 = -z davanti): raggio dall'esterno verso il centro. Torna [(punto, normale)] in Blender."""
    out = []
    c = g2b((centro_xz[0], gy, centro_xz[1]))
    for a in angoli:
        d = Vector((math.cos(math.radians(a)), 0.0, -math.sin(math.radians(a))))   # glTF (x, 0, z)
        db = g2b(d)
        start = c + db * 0.2
        hit = bvh.ray_cast(start, -db, 0.25)
        if hit[0] is None:
            out.append(None)
            continue
        p, n = hit[0], hit[1]
        if n.dot(db) < 0:
            n = -n
        out.append((p, n))
    return out


def tubo(nome, punti, raggi):
    """Una catena di sfere unite (dito, pollice): mesh di sfere lungo i punti, poi il remesh le fonde."""
    bm = bmesh.new()
    for i in range(len(punti) - 1):
        a, b = punti[i], punti[i + 1]
        ra, rb = raggi[i], raggi[i + 1]
        n = max(2, int((a - b).length / (min(ra, rb) * 0.35)))
        for k in range(n + 1):
            t = k / n
            r = ra + (rb - ra) * t
            m = Matrix.Translation(a.lerp(b, t))
            bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r, matrix=m)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def ellissoide(nome, centro, assi, rot=Matrix.Identity(3)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1.0)
    m = Matrix.Translation(centro) @ rot.to_4x4() @ Matrix.Diagonal((assi[0], assi[1], assi[2], 1.0))
    bm.transform(m)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


parti = []
# --- le quattro dita: dal lato destro (+x, dove sta il palmo) attorno al davanti (-z) fino al lato sinistro (-x)
dita_info = []
for i in range(4):
    gy = Y_INDICE - i * PASSO_DITA
    r = R_DITO * (1.0 - 0.06 * i)         # il mignolo un po' più piccolo
    angoli = list(range(-25, 200, 12))     # da dietro a destra, per il davanti, fino a dietro a sinistra
    fine = 178 - i * 6                     # la punta a sinistra, un po' prima per il mignolo
    angoli = [a for a in angoli if a <= fine] + [fine]
    cont = contorno(gy, angoli)
    pts = []
    for c in cont:
        if c is None:
            continue
        p, n = c
        pts.append(p + n * (r + AGGIO))
    dita_info.append((gy, r, pts))
    parti.append(tubo("dito_%d" % i, pts, [r] * len(pts)))

# --- il palmo: contro il lato destro dell'impugnatura e il dorso dietro, dalle basi delle dita al polso; inclinato
# come l'impugnatura (circa 15 gradi indietro andando giù)
incl = Matrix.Rotation(math.radians(-15.0), 3, 'X')
palmo_g = Vector((0.060, -0.236, 0.523))
parti.append(ellissoide("palmo", g2b(palmo_g), (0.024, 0.046, 0.058), incl))
# il dorso della mano più gonfio verso l'esterno, e il bordo dietro (il "taglio" della mano) sul dorso dell'impugnatura
parti.append(ellissoide("dorso", g2b(palmo_g + Vector((0.008, -0.004, 0.012))), (0.020, 0.040, 0.050), incl))
parti.append(ellissoide("taglio", g2b(Vector((0.030, -0.240, 0.560))), (0.026, 0.052, 0.022), incl))
# il polso, dietro e sotto il palmo, verso l'avambraccio
polso_g = Vector((0.046, -0.292, 0.598))
parti.append(ellissoide("polso", g2b(polso_g), (0.031, 0.030, 0.032)))
parti.append(ellissoide("raccordo", g2b((palmo_g + polso_g) * 0.5 + Vector((0.0, 0.0, 0.004))), (0.030, 0.036, 0.036), incl))

# --- il pollice: dalla parte alta del palmo, sopra il dorso dell'impugnatura, giù sul lato sinistro, appoggiato
# sopra l'indice
gy_i, r_i, idx_pts = dita_info[0]
r_t = 0.0145
y_t = gy_i + r_i + r_t - 0.003
pollice = [g2b((0.050, -0.196, 0.552)), g2b((0.022, y_t + 0.006, 0.566)), g2b((-0.012, y_t + 0.003, 0.556)),
           g2b((-0.040, y_t, 0.522)), g2b((-0.047, y_t, 0.488)), g2b((-0.047, y_t - 0.002, 0.462))]
parti.append(tubo("pollice", pollice, [0.019, 0.017, r_t + 0.001, r_t, r_t, r_t - 0.0005]))

# --- unione, remesh, lisciatura
bpy.ops.object.select_all(action='DESELECT')
for o in parti:
    o.select_set(True)
bpy.context.view_layer.objects.active = parti[0]
bpy.ops.object.join()
guanto = bpy.context.view_layer.objects.active
guanto.name = "Guanto"
mr = guanto.modifiers.new("remesh", 'REMESH')
mr.mode = 'VOXEL'
mr.voxel_size = VOXEL
ms = guanto.modifiers.new("liscia", 'CORRECTIVE_SMOOTH')
ms.iterations = 8
bpy.ops.object.modifier_apply(modifier="remesh")
bpy.ops.object.modifier_apply(modifier="liscia")
sm = guanto.modifiers.new("liscia2", 'SMOOTH')
sm.iterations = 6
sm.factor = 0.5
bpy.ops.object.modifier_apply(modifier="liscia2")

# --- appoggio: i vertici dentro l'impugnatura o a meno di 3 mm escono sulla superficie (+0,4 mm)
def appoggia(ob, soglia=0.003, fuori=0.0004):
    mosse = 0
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        loc, n, _, d = bvh.find_nearest(p)
        if loc is None:
            continue
        dentro = (p - loc).dot(n) < 0
        if dentro or d < soglia:
            v.co = ob.matrix_world.inverted() @ (loc + n * fuori)
            mosse += 1
    return mosse


print("GUANTO: vertici appoggiati", appoggia(guanto))
dec = guanto.modifiers.new("dec", 'DECIMATE')
dec.ratio = FACCE_GUANTO / max(1, len(guanto.data.polygons))
bpy.ops.object.modifier_apply(modifier="dec")
print("GUANTO: ricontrollo appoggio", appoggia(guanto, soglia=0.0, fuori=0.0004))
for p in guanto.data.polygons:
    p.use_smooth = True

# --- il polsino arrotolato: un toro sul polso, girato come l'avambraccio (indietro e in giù)
asse_avambraccio = g2b((0.12, -0.45, 1.0)).normalized()
bpy.ops.mesh.primitive_torus_add(major_radius=0.034, minor_radius=0.0125, major_segments=32, minor_segments=12,
                                 location=g2b(polso_g + Vector((0.003, -0.006, 0.016))))
polsino = bpy.context.active_object
polsino.name = "Polsino"
polsino.rotation_mode = 'QUATERNION'
polsino.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(asse_avambraccio)
for p in polsino.data.polygons:
    p.use_smooth = True

# --- tre cuciture sul dorso: linee sottili scure appoggiate sulla superficie esterna, dal polso verso le nocche
bvh_g = BVHTree.FromObject(guanto, bpy.context.evaluated_depsgraph_get())
cuc = []
for k, dy in enumerate((-0.019, 0.0, 0.019)):
    pts = []
    for t in np.linspace(0.0, 1.0, 14):
        q = palmo_g + Vector((0.0, dy, 0.0)) + Vector((0.0, -0.010 * t, 0.034 - 0.060 * t))
        start = g2b(Vector((0.20, q.y, q.z)))
        hit = bvh_g.ray_cast(start, g2b(Vector((-1.0, 0.0, 0.0))), 0.3)
        if hit[0] is not None:
            pts.append(hit[0] - g2b(Vector((0.0004, 0.0, 0.0))))
    if len(pts) > 2:
        # una curva con lo spessore (poche facce), poi mesh
        cu = bpy.data.curves.new("cucitura_%d" % k, 'CURVE')
        cu.dimensions = '3D'
        cu.bevel_depth = 0.0011
        cu.bevel_resolution = 1
        cu.use_fill_caps = True
        sp = cu.splines.new('POLY')
        sp.points.add(len(pts) - 1)
        for i, q in enumerate(pts):
            sp.points[i].co = (q.x, q.y, q.z, 1.0)
        oc = bpy.data.objects.new("cucitura_%d" % k, cu)
        bpy.context.scene.collection.objects.link(oc)
        bpy.ops.object.select_all(action='DESELECT')
        oc.select_set(True)
        bpy.context.view_layer.objects.active = oc
        bpy.ops.object.convert(target='MESH')
        cuc.append(bpy.context.view_layer.objects.active)
for o in cuc:
    for p in o.data.polygons:
        p.use_smooth = True

# --- materiali e unione in un solo oggetto con due superfici (guanto bianco, cuciture scure)
mat_b = bpy.data.materials.new("GuantoBianco")
mat_b.use_nodes = True
b = mat_b.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.86, 0.86, 0.83, 1.0)
b.inputs["Roughness"].default_value = 0.62
mat_c = bpy.data.materials.new("GuantoCuciture")
mat_c.use_nodes = True
c = mat_c.node_tree.nodes["Principled BSDF"]
c.inputs["Base Color"].default_value = (0.10, 0.10, 0.11, 1.0)
c.inputs["Roughness"].default_value = 0.7
for o in (guanto, polsino):
    o.data.materials.clear()
    o.data.materials.append(mat_b)
for o in cuc:
    o.data.materials.clear()
    o.data.materials.append(mat_c)
bpy.ops.object.select_all(action='DESELECT')
for o in [guanto, polsino] + cuc:
    o.select_set(True)
bpy.context.view_layer.objects.active = guanto
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
guanto = bpy.context.view_layer.objects.active
guanto.name = "GuantoDestro"
print("GUANTO: facce", len(guanto.data.polygons), "cuciture", len(cuc))

# --- solo il guanto nel glb (la lancia resta fuori)
for o in list(bpy.data.objects):
    if o != guanto:
        o.hide_set(True)
bpy.ops.object.select_all(action='DESELECT')
guanto.hide_set(False)
guanto.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format='GLB', export_yup=True, export_apply=True)
print("GUANTO: scritto", OUT)
if BLEND:
    for o in bpy.data.objects:
        o.hide_set(False)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
