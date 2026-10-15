"""Kit di dettagli per la sala principale dell'acquapark: detriti, cavi, tubi e condotte da muro, bocchette,
cassette elettriche, corpi lampada, cartelli con soli disegni, alghe secche e incrostazioni, catene e corde.

Uso:
  /home/user/tools/blender-venv/bin/python tools/blender/dettagli_kit.py [--render] [--anteprima]
Uscite:
  assets_src/ambiente_dettagli/glb/<categoria>.glb      (un GLB per categoria)
  assets_src/ambiente_dettagli/catalogo.json            (nodi, categoria, ingombro, dove si attaccano)
  docs/report/render_ambienti2/dettagli_vetrina*.jpg   (con --render)

Convenzioni (come il KIT di assets_src/ambiente/):
- metri, Z in alto in Blender (Y in Godot);
- ogni dettaglio e' un nodo radice `det_<oggetto>[_<variante>]`; nel GLB i nodi sono in fila per la vetrina,
  ma l'origine di ognuno e' il suo punto d'appoggio: in Godot si prende il nodo e gli si da' la trasformazione
  del file di posizionamento;
- appoggio: 'pavimento' (origine alla base), 'muro' (origine sul filo del muro, il fronte guarda -Y Blender
  = +Z Godot), 'soffitto' (origine nel punto d'attacco, l'oggetto pende verso -Z);
- materiali `M_det_*`, texture 2K (1K per i giocattoli piccoli di Meshy); niente collisioni (sono decorativi).
"""
import json, math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix, Euler, noise
from ambienti2_comune import *

ARGS = argomenti()
DET = os.path.join(RADICE, 'assets_src', 'ambiente_dettagli')
DT = os.path.join(DET, 'texture')
KT = os.path.join(RADICE, 'assets_src', 'ambiente', 'textures')
random.seed(7)

reset()


def T(*p):
    return os.path.join(*p)


# ------------------------------------------------------------------ materiali (texture 2K del kit della sala + CC0 nuove)
def kit(nome, cc, col=None, **kw):
    """Materiale con le texture cc0 del kit della sala (col/nrm/orm)."""
    return mat_pbr(nome, color=col or T(KT, 'cc0', cc, f'{cc}_col.jpg'), normal=T(KT, 'cc0', cc, f'{cc}_nrm.jpg'),
                   orm=T(KT, 'cc0', cc, f'{cc}_orm.jpg'), **kw)


def acg(nome, aid, col=None, **kw):
    """Materiale con le CC0 di ambientCG scaricate per il kit dei dettagli."""
    d = T(DT, 'cc0', aid)
    f = lambda m: T(d, f'{aid}_{m}.jpg') if os.path.exists(T(d, f'{aid}_{m}.jpg')) else None
    return mat_pbr(nome, color=col or f('Color'), normal=f('NormalGL'), rough=f('Roughness'), metal=f('Metalness'),
                   opacity=f('Opacity'), **kw)


M = {}
M['metallo'] = kit('M_det_metallo_verniciato', 'metallo_verniciato', col=T(KT, 'derivate', 'sala_a', 'metallo_col.jpg'))
M['metallo_grigio'] = kit('M_det_metallo_grigio', 'metallo_verniciato')
M['inox'] = kit('M_det_acciaio', 'acciaio_inox')
M['plastica'] = kit('M_det_plastica', 'plastica_bianca')
M['piastrella'] = kit('M_det_piastrella', 'piastrelle_bianche', col=T(KT, 'derivate', 'sala_a', 'parete_col.jpg'))
M['piastrella_vasca'] = kit('M_det_piastrella_vasca', 'piastrelle_bianche', col=T(KT, 'derivate', 'sala_a', 'vasca_col.jpg'))
M['ruggine'] = acg('M_det_ferro_arrugginito', 'Metal021')
M['ruggine_piena'] = acg('M_det_ruggine', 'Rust004')
M['rete'] = acg('M_det_rete', 'Fence008A')
M['corda'] = acg('M_det_corda', 'Rope001', col=T(DT, 'derivate', 'corda_sporca_col.jpg'))
M['corda_rossa'] = acg('M_det_corda_rossa', 'Rope001', col=T(DT, 'derivate', 'corda_rossa_col.jpg'))
for c in ('nero', 'grigio', 'arancio', 'giallo'):
    M[f'cavo_{c}'] = acg(f'M_det_cavo_{c}', 'Rubber004', col=T(DT, 'derivate', f'cavo_{c}_col.jpg'))
for c in ('righe_turchese', 'righe_rosso', 'tinta_giallo', 'tinta_rosa'):
    M[f'asciugamano_{c}'] = acg(f'M_det_asciugamano_{c}', 'Fabric061', col=T(DT, 'derivate', f'asciugamano_{c}_col.jpg'))
for c in ('bianco', 'giallo', 'azzurro'):
    M[f'carta_{c}'] = acg(f'M_det_carta_{c}', 'Paper003', col=T(DT, 'derivate', f'carta_{c}_col.jpg'))
M['rame'] = mat_pbr('M_det_rame', base=(0.75, 0.4, 0.25), metallic=1.0, roughness=0.35)
M['vetro'] = mat_pbr('M_det_vetro', base=(0.8, 0.88, 0.86), roughness=0.05, alpha=0.3, ior=1.5)
M['vetro_rosso'] = mat_pbr('M_det_vetro_rosso_acceso', base=(0.8, 0.05, 0.03), roughness=0.2, emissione=(1.0, 0.05, 0.02), emissione_forza=30.0)
M['vetro_rosso_spento'] = mat_pbr('M_det_vetro_rosso_spento', base=(0.35, 0.03, 0.02), roughness=0.15)
M['neon_acceso'] = mat_pbr('M_det_neon_acceso', base=(0.9, 1.0, 0.95), roughness=0.3, emissione=(0.8, 1.0, 0.93), emissione_forza=20.0)
M['neon_spento'] = mat_pbr('M_det_neon_spento', base=(0.75, 0.76, 0.74), roughness=0.25)
M['faro_acceso'] = mat_pbr('M_det_faro_vetro_acceso', base=(1.0, 0.85, 0.6), roughness=0.1, emissione=(1.0, 0.75, 0.45), emissione_forza=25.0)
M['diffusore'] = mat_pbr('M_det_diffusore', base=(0.85, 0.86, 0.84), roughness=0.4, alpha=0.6)
M['gomma'] = mat_pbr('M_det_gomma_nera', base=(0.02, 0.02, 0.02), roughness=0.75)
M['interruttore'] = mat_pbr('M_det_plastica_nera', base=(0.03, 0.03, 0.03), roughness=0.4)
for k, nome in enumerate(('non_correre', 'non_tuffarsi', 'vietato_vetro', 'pavimento_bagnato', 'profondita', 'uscita', 'pronto_soccorso', 'salvagente')):
    M[f'cartello_{nome}'] = mat_pbr(f'M_det_cartello_{nome}', color=T(DT, 'derivate', f'cartello_{nome}_col.jpg'),
                                    normal=T(KT, 'cc0', 'plastica_bianca', 'plastica_bianca_nrm.jpg'), roughness=0.55)
for nome in ('alghe_secche', 'alghe_verdi', 'calcare', 'muffa', 'ruggine_colata'):
    M[f'macchia_{nome}'] = mat_pbr(f'M_det_macchia_{nome}', color=T(DT, 'derivate', f'macchia_{nome}_col.png'),
                                   normal=T(DT, 'cc0', 'Moss002', 'Moss002_NormalGL.jpg'), roughness=0.85 if 'alghe' in nome or nome == 'muffa' else 0.6)
    # l'alfa sta nel PNG: collego il canale alfa e uso alpha clip (in Godot: alpha scissor)
    nt = M[f'macchia_{nome}'].node_tree
    tx = [n for n in nt.nodes if n.type == 'TEX_IMAGE' and n.image.filepath.endswith('.png')][0]
    nt.links.new(tx.outputs['Alpha'], nt.nodes['Principled BSDF'].inputs['Alpha'])
    for attr, val in (('surface_render_method', 'BLENDED'), ('blend_method', 'BLEND')):
        try:
            setattr(M[f'macchia_{nome}'], attr, val)
        except Exception:
            pass

# ------------------------------------------------------------------ registro dei dettagli
CATALOGO = {}    # nome nodo -> dati
CATEGORIE = {}   # categoria -> [oggetti]


def registra(cat, ob, appoggio, note=''):
    vs = [ob.matrix_basis @ v.co for v in ob.data.vertices] if ob.type == 'MESH' else [ob.location]
    lo = [min(v[i] for v in vs) for i in range(3)]; hi = [max(v[i] for v in vs) for i in range(3)]
    CATALOGO[ob.name] = {'categoria': cat, 'appoggio': appoggio, 'ingombro_m': [round(hi[i] - lo[i], 3) for i in range(3)], 'note': note,
                         'triangoli': sum(len(p.vertices) - 2 for p in ob.data.polygons) if ob.type == 'MESH' else 0}
    CATEGORIE.setdefault(cat, []).append(ob)
    return ob


def fondi(nome, parti, origine=(0, 0, 0)):
    """Unisce le parti in un solo oggetto con l'origine nel punto d'appoggio."""
    parti = [p for p in parti if p is not None]
    for p in parti:
        applica_trasf(p)
    ob = unisci(nome, parti)
    imposta_origine(ob, origine)
    ob.location = (0, 0, 0)
    return ob


def cordone(nome, pts, r, mat, seg=8, u_tile=0.5, liscia=True, tappi=False):
    """Tubo con UV lungo la lunghezza (corde, cavi, tubi): U = metri / u_tile, V = intorno."""
    P = [Vector(p) for p in pts]
    if liscia and len(P) > 2:
        # Catmull-Rom
        Q = []
        for i in range(len(P) - 1):
            p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, len(P) - 1)]
            n = max(2, int((p2 - p1).length / 0.04))
            for k in range(n):
                t = k / n
                Q.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
        Q.append(P[-1]); P = Q
    bm = bmesh.new(); uvl = bm.loops.layers.uv.verify()
    anelli = []; s = 0.0; prev_n = None
    for i, p in enumerate(P):
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        if i:
            s += (p - P[i - 1]).length
        if prev_n is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = t.cross(ref).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n; b = t.cross(n)
        anelli.append(([bm.verts.new(p + (n * math.cos(2 * math.pi * j / seg) + b * math.sin(2 * math.pi * j / seg)) * r) for j in range(seg)], s))
    for i in range(len(anelli) - 1):
        (A, sa), (B, sb) = anelli[i], anelli[i + 1]
        for j in range(seg):
            f = bm.faces.new((A[j], A[(j + 1) % seg], B[(j + 1) % seg], B[j]))
            for l, (u, v) in zip(f.loops, ((sa, j), (sa, j + 1), (sb, j + 1), (sb, j))):
                l[uvl].uv = (u / u_tile, v / seg)
    if tappi:
        bm.faces.new(list(reversed(anelli[0][0]))); bm.faces.new(anelli[-1][0])
    me = bpy.data.meshes.new(nome); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome, me); bpy.context.scene.collection.objects.link(ob)
    assegna(ob, mat)
    return liscio(ob, 70)


def catenaria(a, b, freccia, n=24):
    a, b = Vector(a), Vector(b)
    return [a.lerp(b, i / n) - Vector((0, 0, freccia * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]


def prisma(nome, poligono, spessore, mat, uv_scala=1.5, uv_off=(0, 0)):
    """Prisma da un poligono nel piano XY (pezzi di piastrella, vetri). UV dall'alto in coordinate del poligono."""
    bm = bmesh.new(); uvl = bm.loops.layers.uv.verify()
    sotto = [bm.verts.new((x, y, 0)) for x, y in poligono]
    sopra = [bm.verts.new((x, y, spessore)) for x, y in poligono]
    ft = bm.faces.new(sopra); fb = bm.faces.new(list(reversed(sotto)))
    n = len(poligono)
    for i in range(n):
        bm.faces.new((sotto[i], sotto[(i + 1) % n], sopra[(i + 1) % n], sopra[i]))
    for f in bm.faces:
        for l in f.loops:
            l[uvl].uv = ((l.vert.co.x + uv_off[0]) / uv_scala, (l.vert.co.y + uv_off[1]) / uv_scala)
    me = bpy.data.meshes.new(nome); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome, me); bpy.context.scene.collection.objects.link(ob)
    assegna(ob, mat)
    return ob


def scheggia(lato, irregolare=0.35):
    """Poligono convesso irregolare dentro un quadrato di lato `lato`."""
    k = random.randint(4, 7)
    ang = sorted(random.uniform(0, 2 * math.pi) for _ in range(k))
    return [(lato / 2 * (1 - irregolare * random.random()) * math.cos(a), lato / 2 * (1 - irregolare * random.random()) * math.sin(a)) for a in ang]


usa_collezione('kit')

# ================================================================== DETRITI
# pezzi di piastrella (12,5 cm, texture allineata: 1,5 m = 12 piastrelle)
for v in range(6):
    mat = M['piastrella_vasca'] if v % 3 == 2 else M['piastrella']
    lato = random.choice((0.09, 0.12, 0.16, 0.22))
    ob = prisma(f'det_piastrella_rotta_{v + 1}', scheggia(lato), 0.009, mat, uv_off=(random.randint(0, 11) * 0.125 + 0.06, random.randint(0, 11) * 0.125 + 0.06))
    ob.rotation_euler = (random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), random.uniform(0, 6.28))
    registra('detriti', fondi(ob.name, [ob]), 'pavimento', 'pezzo di piastrella staccata')
for v in range(3):
    parti = []
    for k in range(random.randint(9, 15)):
        mat = M['piastrella_vasca'] if v == 2 else M['piastrella']
        p = prisma(f'mp{v}_{k}', scheggia(random.uniform(0.05, 0.16)), 0.009, mat, uv_off=(random.randint(0, 11) * 0.125, random.randint(0, 11) * 0.125))
        r = random.uniform(0, 0.35) * (1 if k else 0); a = random.uniform(0, 6.28)
        p.location = (r * math.cos(a), r * math.sin(a), random.uniform(0, 0.012))
        p.rotation_euler = (random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25), random.uniform(0, 6.28))
        parti.append(p)
    registra('detriti', fondi(f'det_mucchio_piastrelle_{v + 1}', parti), 'pavimento', 'mucchio di piastrelle cadute, ~0,8 m: sotto le pareti scrostate')
# vetri rotti
for v in range(3):
    parti = []
    for k in range(random.randint(6, 12)):
        p = prisma(f'vt{v}_{k}', scheggia(random.uniform(0.03, 0.14), 0.6), 0.004, M['vetro'])
        r = random.uniform(0, 0.4); a = random.uniform(0, 6.28)
        p.location = (r * math.cos(a), r * math.sin(a), 0.0)
        p.rotation_euler = (random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), random.uniform(0, 6.28))
        parti.append(p)
    registra('detriti', fondi(f'det_vetri_rotti_{v + 1}', parti), 'pavimento', 'schegge di vetro (oblo, plafoniere): sotto le lampade rotte')


# fogli di carta: piatti un po' arricciati, e palline accartocciate
def foglio(nome, mat, w=0.21, h=0.297, curl=0.03, seme=0):
    bm = bmesh.new(); uvl = bm.loops.layers.uv.verify()
    nx, ny = 10, 14
    vs = [[bm.verts.new((w * (i / nx - 0.5), h * (j / ny - 0.5), 0)) for i in range(nx + 1)] for j in range(ny + 1)]
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
            for l, (a, b) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                l[uvl].uv = (a / nx, b / ny)
    for v in bm.verts:
        x, y = v.co.x / w + 0.5, v.co.y / h + 0.5
        bordo = max(abs(x - 0.5), abs(y - 0.5)) * 2
        v.co.z = 0.002 + curl * bordo ** 3 * (0.5 + 0.5 * noise.noise(Vector((x * 3, y * 3, seme)))) \
            + 0.004 * noise.noise(Vector((x * 9, y * 9, seme + 5)))
        v.co.z = max(v.co.z, 0.001)
    me = bpy.data.meshes.new(nome); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(nome, me); bpy.context.scene.collection.objects.link(ob)
    assegna(ob, mat)
    sd = ob.modifiers.new('s', 'SOLIDIFY'); sd.thickness = 0.0008
    return liscio(ob, 60)


for v, c in enumerate(('bianco', 'giallo', 'azzurro', 'bianco')):
    ob = foglio(f'det_foglio_{v + 1}', M[f'carta_{c}'], curl=0.02 + 0.02 * v, seme=v)
    ob.rotation_euler.z = random.uniform(0, 6.28)
    registra('detriti', fondi(ob.name, [ob]), 'pavimento', 'foglio bagnato (moduli, volantini: solo righe, niente testo)')
for v in range(3):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.04 + 0.01 * v)
    uvl = bm.loops.layers.uv.verify()
    for vv in bm.verts:
        d = vv.co.normalized()
        vv.co *= 0.7 + 0.5 * (0.5 + 0.5 * noise.noise(d * 3 + Vector((v, 0, 0)))) + 0.15 * noise.noise(d * 9)
    for f in bm.faces:
        for l in f.loops:
            d = l.vert.co.normalized(); l[uvl].uv = (0.5 + math.atan2(d.y, d.x) / 6.28, 0.5 + d.z * 0.5)
    me = bpy.data.meshes.new('pc'); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(f'det_carta_accartocciata_{v + 1}', me); bpy.context.scene.collection.objects.link(ob)
    assegna(ob, M[('carta_bianco', 'carta_giallo', 'carta_azzurro')[v]])
    vs = [vv.co.z for vv in me.vertices]
    registra('detriti', fondi(ob.name, [ob], (0, 0, min(vs))), 'pavimento', 'pallina di carta')


# asciugamani bagnati: simulazione di stoffa che cade sul pavimento (con un rilievo sotto per fare le pieghe)
def asciugamano(nome, mat, w=1.0, h=0.5, seme=0):
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=40, y_subdivisions=20, size=1.0, location=(0, 0, 0.3))
    ob = bpy.context.active_object; ob.name = nome
    ob.scale = (w, h, 1); ob.rotation_euler = (random.uniform(0.15, 0.35), random.uniform(-0.2, 0.2), random.uniform(0, 3))
    applica_trasf(ob)
    ob.location = (0, 0, 0.3)
    assegna(ob, mat)
    pav = box('pav_sim', (0, 0, -0.05), (4, 4, 0.1), None, uv=None)
    rilievo = sfera('ril_sim', (random.uniform(-0.1, 0.1), random.uniform(-0.05, 0.05), 0), 0.12, None, scala=(1.4, 0.8, 0.5), uv=None)
    for c in (pav, rilievo):
        c.modifiers.new('col', 'COLLISION'); c.collision.thickness_outer = 0.004
    cl = ob.modifiers.new('stoffa', 'CLOTH')
    cl.settings.quality = 6; cl.settings.mass = 0.6; cl.settings.tension_stiffness = 8; cl.settings.bending_stiffness = 0.05
    cl.collision_settings.use_self_collision = True; cl.collision_settings.distance_min = 0.004
    cl.point_cache.frame_start = 1; cl.point_cache.frame_end = 70
    for f in range(1, 71):
        sc.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear(); vecchio = ob.data; ob.data = me
    me.transform(ob.matrix_world); ob.matrix_basis = Matrix.Identity(4)
    bpy.data.meshes.remove(vecchio)
    bpy.data.objects.remove(pav); bpy.data.objects.remove(rilievo)
    sc.frame_set(1)
    # UV: la griglia di partenza aveva gia' UV 0..1 (le righe vanno lungo il lato lungo)
    sm = ob.modifiers.new('liscia', 'SMOOTH'); sm.factor = 0.8; sm.iterations = 6
    sd = ob.modifiers.new('s', 'SOLIDIFY'); sd.thickness = 0.006
    applica_modificatori_ob(ob)
    vs = [v.co for v in ob.data.vertices]
    c = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2, (min(v.y for v in vs) + max(v.y for v in vs)) / 2, min(v.z for v in vs)))
    return liscio(ob, 80), c


def applica_modificatori_ob(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear(); vecchio = ob.data; ob.data = me
    bpy.data.meshes.remove(vecchio)


for v, c in enumerate(('righe_turchese', 'righe_rosso', 'tinta_giallo', 'tinta_rosa')):
    ob, base = asciugamano(f'det_asciugamano_{v + 1}', M[f'asciugamano_{c}'], seme=v)
    registra('detriti', fondi(ob.name, [ob], base), 'pavimento', 'asciugamano bagnato, abbandonato per terra')


# giocattoli e ciabatte (Meshy): puliti, scalati, ridotti
def importa_meshy(nome, lato, asse=None, tri_max=6000):
    path = T(DET, 'meshy', nome + '.glb')
    if not os.path.exists(path):
        print('manca', path); return None
    prima = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    nuovi = [o for o in bpy.data.objects if o not in prima]
    mesh = [o for o in nuovi if o.type == 'MESH']
    for o in mesh:
        o.data.transform(o.matrix_world); o.parent = None; o.matrix_basis = Matrix.Identity(4)
    for o in nuovi:
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    ob = unisci('det_' + nome, mesh)
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    bpy.context.scene.collection.objects.link(ob)
    vs = [v.co for v in ob.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)]); hi = Vector([max(v[i] for v in vs) for i in range(3)])
    dim = hi - lo
    s = lato / (dim[asse] if asse is not None else max(dim))
    ob.data.transform(Matrix.Translation(-Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    ob.data.transform(Matrix.Scale(s, 4))
    tri = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tri > tri_max:
        d = ob.modifiers.new('d', 'DECIMATE'); d.ratio = tri_max / tri
        applica_modificatori_ob(ob)
    for m in ob.data.materials:
        m.name = 'M_det_' + nome
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image and n.image.size[0] > 1024:
                n.image.scale(1024, 1024)
    return ob


for nome, lato, asse, nota in (('paperella', 0.11, None, 'paperella di gomma'), ('secchiello', 0.16, 2, 'secchiello da spiaggia'),
                               ('paletta', 0.22, None, 'paletta'), ('barchetta', 0.2, None, 'barchetta'),
                               ('pistola_acqua', 0.2, None, 'pistola ad acqua'), ('pesce_gomma', 0.12, None, 'pesce di gomma'),
                               ('maschera_sub', 0.2, None, 'maschera da sub'), ('ciabatta', 0.26, None, 'ciabatta di gomma')):
    ob = importa_meshy(nome, lato, asse)
    if ob:
        registra('detriti', ob, 'pavimento', nota)


# ================================================================== CAVI
for v, (L, col) in enumerate(((1.2, 'nero'), (2.0, 'grigio'), (2.8, 'nero'), (1.6, 'arancio'))):
    pts = []
    for k in range(13):
        t = k / 12
        pts.append((0.08 * math.sin(t * 5 + v) * t, 0.06 * math.cos(t * 4 + v) * t, -L * t))
    # in fondo si arriccia
    end = Vector(pts[-1])
    for k in range(1, 6):
        a = k * 0.9
        pts.append(tuple(end + Vector((0.06 * math.sin(a), 0.06 * (1 - math.cos(a)), 0.02 * k))))
    parti = [cordone(f'cp{v}', pts, 0.008 if v != 2 else 0.012, M[f'cavo_{col}'])]
    # capo strappato: fili di rame
    e = Vector(pts[-1])
    for k in range(3):
        parti.append(cordone(f'cp{v}r{k}', [e, e + Vector((0.02 * (k - 1), 0.01, -0.03 - 0.01 * k))], 0.0015, M['rame'], seg=4, liscia=False))
    parti.append(cilindro(f'cp{v}att', (0, 0, -0.01), 0.025, 0.02, M['metallo_grigio'], seg=12, uv=0.3))
    registra('cavi', fondi(f'det_cavo_pendente_{v + 1}', parti), 'soffitto', f'cavo strappato che pende, {L} m')
for v, (L, f, col) in enumerate(((2.0, 0.25, 'nero'), (4.0, 0.6, 'grigio'), (6.0, 1.0, 'nero'))):
    parti = [cordone(f'cf{v}', catenaria((0, 0, 0), (L, 0, 0), f), 0.009, M[f'cavo_{col}'])]
    for x in (0, L):
        parti.append(box(f'cf{v}g{x}', (x, 0, 0.01), (0.04, 0.03, 0.03), M['metallo_grigio'], uv=0.3))
    registra('cavi', fondi(f'det_cavo_festone_{v + 1}', parti), 'soffitto', f'cavo a festone tra due attacchi a {L} m (lungo +X Blender)')
parti = []
for k, (col, dy, dz) in enumerate((('nero', 0, 0), ('grigio', 0.025, 0.005), ('giallo', -0.02, 0.01), ('nero', 0.01, -0.02))):
    pts = [p + Vector((0, dy, dz)) for p in catenaria((0, 0, 0), (4, 0, 0), 0.7 + 0.08 * k)]
    parti.append(cordone(f'fc{k}', pts, 0.008, M[f'cavo_{col}']))
for x in (1.0, 2.0, 3.0):
    i = int(x / 4 * 24); p = catenaria((0, 0, 0), (4, 0, 0), 0.75)[i]
    parti.append(toro(f'fcf{x}', p, 0.035, 0.004, M['gomma'], asse=(1, 0, 0), seg=12, seg2=4, uv=None))
registra('cavi', fondi('det_fascio_cavi_4m', parti), 'soffitto', 'fascio di 4 cavi con fascette, 4 m')

# ================================================================== TUBI DA MURO, CONDOTTE, BOCCHETTE (fronte verso -Y, origine sul muro)


def staffa(nome, x, y, z, r, mat):
    return [box(f'{nome}_p', (x, -0.005, z), (0.06, 0.01, 0.12), mat, uv=0.3),
            box(f'{nome}_b', (x, (y - 0.01) / 2, z), (0.03, abs(y) + 0.01, 0.02), mat, uv=0.3),
            toro(f'{nome}_c', (x, y, z), r + 0.008, 0.006, mat, asse=(1, 0, 0), seg=16, seg2=4, uv=None)]


for v, (r, L, mat, col) in enumerate(((0.05, 2.0, M['metallo'], None), (0.08, 2.0, M['ruggine'], None), (0.035, 2.0, M['metallo_grigio'], None))):
    y = -(r + 0.05)
    parti = [cordone(f'tm{v}', [(0, y, 0), (L, y, 0)], r, mat, seg=16, liscia=False, u_tile=1.0)]
    for x in (0.4, L - 0.4):
        parti += staffa(f'tm{v}s{x}', x, y, 0, r, M['ruggine'])
    parti.append(toro(f'tm{v}fl', (L / 2, y, 0), r + 0.01, 0.012, M['ruggine'], asse=(1, 0, 0), seg=16, seg2=6, uv=None))
    registra('tubi', fondi(f'det_tubo_muro_{int(r * 200)}cm_2m', parti), 'muro', f'tubo orizzontale Ø {int(r * 200)} cm, 2 m lungo +X, con staffe')
# fascio di tubi paralleli
parti = []
for k, (r, z, mat) in enumerate(((0.05, 0.0, M['metallo']), (0.035, 0.14, M['metallo_grigio']), (0.06, -0.17, M['ruggine']))):
    y = -0.12
    parti.append(cordone(f'tp{k}', [(0, y, z), (2, y, z)], r, mat, seg=16, liscia=False, u_tile=1.0))
for x in (0.3, 1.7):
    parti.append(box(f'tps{x}', (x, -0.07, -0.02), (0.05, 0.14, 0.5), M['ruggine'], uv=0.3))
registra('tubi', fondi('det_tubi_paralleli_2m', parti), 'muro', 'tre tubi paralleli su un supporto, 2 m')
# curva che sale nel soffitto e tubo verticale
parti = [cordone('tc', [(0, -0.1, 0), (0.6, -0.1, 0), (0.9, -0.1, 0.05), (1.0, -0.1, 0.3), (1.0, -0.1, 1.5)], 0.05, M['metallo'], seg=16, u_tile=1.0)]
parti += staffa('tcs', 0.35, -0.1, 0, 0.05, M['ruggine'])
registra('tubi', fondi('det_tubo_curva_su', parti), 'muro', 'tubo che gira e sale verso la galleria (1,5 m)')
parti = [cordone('tv', [(0, -0.09, 0), (0, -0.09, 3.0)], 0.04, M['ruggine'], seg=16, liscia=False, u_tile=1.0)]
for z in (0.5, 1.5, 2.5):
    parti += [box(f'tvs{z}', (0, -0.04, z), (0.1, 0.09, 0.03), M['ruggine'], uv=0.3)]
registra('tubi', fondi('det_tubo_verticale_3m', parti, (0, 0, 0)), 'muro', 'tubo verticale 3 m, origine in basso')
# raccordo a T con valvola a volantino e manometro
parti = [cordone('tt', [(0, -0.11, 0), (1.2, -0.11, 0)], 0.05, M['metallo_grigio'], seg=16, liscia=False, u_tile=1.0),
         cordone('tt2', [(0.6, -0.11, 0), (0.6, -0.11, -0.6)], 0.05, M['metallo_grigio'], seg=16, liscia=False, u_tile=1.0),
         cilindro('ttv', (0.6, -0.11, 0), 0.075, 0.18, M['ruggine'], asse=(1, 0, 0), seg=16, uv=0.3),
         cilindro('tts', (0.6, -0.22, 0), 0.012, 0.18, M['inox'], asse=(0, 1, 0), seg=8, uv=None),
         toro('ttw', (0.6, -0.31, 0), 0.09, 0.009, M['vernice_rossa'] if 'vernice_rossa' in M else M['metallo'], asse=(0, 1, 0), seg=20, seg2=6, uv=None)]
for k in range(3):
    a = k * 2.094
    parti.append(cordone(f'ttr{k}', [(0.6, -0.31, 0), (0.6 + 0.09 * math.cos(a), -0.31, 0.09 * math.sin(a))], 0.006, M['metallo'], seg=6, liscia=False))
parti.append(cilindro('ttm', (0.25, -0.2, 0.12), 0.05, 0.03, M['inox'], asse=(0, 1, 0), seg=16, uv=None))
parti.append(cordone('ttmr', [(0.25, -0.11, 0.05), (0.25, -0.11, 0.12), (0.25, -0.18, 0.12)], 0.008, M['inox'], seg=6, liscia=False))
registra('tubi', fondi('det_tubo_valvola_T', parti), 'muro', 'raccordo a T con valvola a volantino e manometro')
# condotte dell'aria rettangolari (lamiera zincata)
for v, L in enumerate((2.0, 4.0)):
    parti = [box(f'cd{v}', (L / 2, -0.15, 0), (L, 0.3, 0.25), M['metallo_grigio'], uv=1.0)]
    for x in [i * 1.0 for i in range(int(L) + 1)]:
        parti.append(box(f'cd{v}f{x}', (x, -0.15, 0), (0.03, 0.33, 0.28), M['ruggine'], uv=0.3))
    registra('tubi', fondi(f'det_condotta_aria_{int(L)}m', parti), 'muro', f'condotta dell aria 30 x 25 cm, {int(L)} m lungo +X')
parti = [box('cdc1', (0.3, -0.15, 0), (0.6, 0.3, 0.25), M['metallo_grigio'], uv=1.0), box('cdc2', (0.475, -0.15, 0.4), (0.25, 0.3, 0.55), M['metallo_grigio'], uv=1.0)]
parti += [box('cdcf', (0.6, -0.15, 0), (0.03, 0.33, 0.28), M['metallo_grigio'], uv=0.3)]
registra('tubi', fondi('det_condotta_aria_curva', parti), 'muro', 'condotta che sale (curva a 90 gradi)')


def bocchetta_rett(nome, w, h, rotta=False):
    parti = []
    for k, (c, d) in enumerate((((0, -0.015, h / 2), (w, 0.03, 0.03)), ((0, -0.015, -h / 2), (w, 0.03, 0.03)),
                               ((-w / 2, -0.015, 0), (0.03, 0.03, h)), ((w / 2, -0.015, 0), (0.03, 0.03, h)))):
        parti.append(box(f'{nome}_t{k}', c, d, M['metallo'], uv=0.4))
    parti.append(box(f'{nome}_buio', (0, -0.002, 0), (w, 0.004, h), M['gomma'], uv=None))
    n = int(h / 0.035)
    for k in range(n):
        z = -h / 2 + (k + 0.5) * h / n
        al = box(f'{nome}_al{k}', (0, -0.015, z), (w - 0.03, 0.002, 0.03), M['metallo'], uv=0.4, rot=(math.radians(40), 0, 0))
        parti.append(al)
    if rotta:
        # la griglia e' saltata da un lato: ruoto le alette intorno allo spigolo sinistro
        R = Matrix.Translation((-w / 2, -0.03, -h / 2)) @ Matrix.Rotation(math.radians(-25), 4, 'Y') @ Matrix.Rotation(math.radians(30), 4, 'Z') @ Matrix.Translation((w / 2, 0.03, h / 2))
        for p in parti:
            if '_al' in p.name or '_t' in p.name and p.name[-1] in '23':
                applica_trasf(p); p.data.transform(R)
    return parti


registra('tubi', fondi('det_bocchetta_rettangolare', bocchetta_rett('br', 0.5, 0.25)), 'muro', 'bocchetta dell aria 50 x 25 cm')
registra('tubi', fondi('det_bocchetta_rettangolare_rotta', bocchetta_rett('brr', 0.5, 0.25, True)), 'muro', 'bocchetta con la griglia storta')
parti = [toro('bt', (0, -0.02, 0), 0.17, 0.02, M['metallo'], asse=(0, 1, 0), seg=32, seg2=8, uv=None),
         cilindro('btb', (0, -0.002, 0), 0.16, 0.004, M['gomma'], asse=(0, 1, 0), seg=32, uv=None)]
for k in range(-4, 5):
    z = k * 0.035; w = 2 * math.sqrt(max(0.16 ** 2 - z * z, 0))
    parti.append(box(f'btg{k}', (0, -0.02, z), (w, 0.006, 0.01), M['metallo'], uv=None))
registra('tubi', fondi('det_bocchetta_tonda', parti), 'muro', 'bocchetta tonda Ø 36 cm')

# ================================================================== ELETTRICO


def cassetta(nome, w, h, d, aperta=0, interno=False, mat=None):
    mat = mat or M['metallo_grigio']
    sp = 0.012   # cassa aperta davanti: fondo e quattro lati
    parti = [box(f'{nome}_fondo', (0, -sp / 2, 0), (w, sp, h), mat, uv=0.5),
             box(f'{nome}_sx', (-w / 2 + sp / 2, -d / 2, 0), (sp, d, h), mat, uv=0.5),
             box(f'{nome}_dx', (w / 2 - sp / 2, -d / 2, 0), (sp, d, h), mat, uv=0.5),
             box(f'{nome}_su', (0, -d / 2, h / 2 - sp / 2), (w, d, sp), mat, uv=0.5),
             box(f'{nome}_giu', (0, -d / 2, -h / 2 + sp / 2), (w, d, sp), mat, uv=0.5)]
    if not aperta:
        parti.append(box(f'{nome}_fronte', (0, -d + sp / 2, 0), (w, sp, h), mat, uv=0.5))
    # anta incernierata a sinistra
    if aperta:
        anta = box(f'{nome}_anta', (w / 2, -0.008, 0), (w, 0.016, h), mat, uv=0.5)
        applica_trasf(anta)
        anta.data.transform(Matrix.Translation((-w / 2, -d, 0)) @ Matrix.Rotation(math.radians(-aperta), 4, 'Z'))
        parti.append(anta)
    if interno:
        for k in range(int(w / 0.04) - 2):
            parti.append(box(f'{nome}_int{k}', (-w / 2 + 0.06 + k * 0.04, -0.05, h * 0.15), (0.03, 0.08, 0.08), M['plastica'], uv=None))
            parti.append(box(f'{nome}_lev{k}', (-w / 2 + 0.06 + k * 0.04, -0.095, h * 0.15 + (0.01 if k % 3 else -0.01)), (0.01, 0.02, 0.02), M['interruttore'], uv=None))
        for k, col in enumerate(('nero', 'arancio', 'giallo', 'grigio')):
            x0 = -w / 2 + 0.1 + k * 0.06
            parti.append(cordone(f'{nome}_f{k}', [(x0, -0.06, h * 0.08), (x0 + 0.03, -d + 0.02, -h * 0.2), (x0 - 0.02, -d - 0.08, -h * 0.5 - 0.2 * k)], 0.006, M[f'cavo_{col}'], seg=6))
    # tubo portacavi che sale
    parti.append(cordone(f'{nome}_tubo', [(w * 0.3, -0.04, h / 2), (w * 0.3, -0.04, h / 2 + 0.8)], 0.016, M['metallo_grigio'], seg=10, liscia=False))
    return parti


registra('elettrico', fondi('det_cassetta_piccola', cassetta('cp', 0.18, 0.18, 0.09)), 'muro', 'scatola di derivazione 18 x 18 cm, tubo che sale 80 cm')
registra('elettrico', fondi('det_cassetta_aperta', cassetta('ca', 0.4, 0.3, 0.15, aperta=70, interno=True)), 'muro', 'cassetta 40 x 30 con lo sportello aperto e i fili che pendono')
registra('elettrico', fondi('det_quadro_elettrico', cassetta('qe', 0.8, 1.2, 0.25, aperta=110, interno=True)), 'muro', 'quadro elettrico 80 x 120, aperto: interruttori e fili. Origine al centro (metterlo a 1,4 m)')
parti = [box('ip', (0, -0.03, 0), (0.09, 0.06, 0.12), M['plastica'], uv=0.3), box('il', (0, -0.065, 0.01), (0.03, 0.02, 0.05), M['interruttore'], uv=None)]
parti.append(cordone('ipt', [(0, -0.03, 0.06), (0, -0.03, 0.9)], 0.012, M['plastica'], seg=8, liscia=False))
registra('elettrico', fondi('det_interruttore_stagno', parti), 'muro', 'interruttore stagno con tubo che sale')

# ================================================================== LAMPADE


def neon(nome, tubi=2, diffusore=True, rotto=False, acceso=True):
    parti = [box(f'{nome}_corpo', (0, 0, -0.035), (1.26, 0.2, 0.07), M['metallo'], uv=0.5)]
    for k in range(tubi):
        y = -0.045 + 0.09 * k
        mat = M['neon_acceso'] if acceso and not (rotto and k == 1) else M['neon_spento']
        L = 1.2 if not (rotto and k == 1) else 0.45
        x0 = -0.6
        parti.append(cilindro(f'{nome}_t{k}', (x0 + L / 2, y, -0.085), 0.013, L, mat, asse=(1, 0, 0), seg=12, uv=None))
        for x in (-0.61, 0.61):
            parti.append(box(f'{nome}_att{k}{x}', (x, y, -0.08), (0.02, 0.04, 0.04), M['plastica'], uv=None))
    if diffusore:
        parti.append(box(f'{nome}_diff', (0, 0, -0.105), (1.24, 0.19, 0.005), M['diffusore'], uv=None))
    return parti


registra('lampade', fondi('det_neon_soffitto', neon('n1')), 'soffitto', 'plafoniera 2 x T8 120 cm, accesa (materiale M_det_neon_acceso)')
registra('lampade', fondi('det_neon_soffitto_spento', neon('n2', acceso=False)), 'soffitto', 'plafoniera spenta')
registra('lampade', fondi('det_neon_senza_diffusore', neon('n3', diffusore=False, rotto=True)), 'soffitto', 'plafoniera senza diffusore, un tubo rotto')
# neon che pende da una catenella: un lato e' caduto
parti = neon('n4', diffusore=False, acceso=False)
R = Matrix.Translation((0.6, 0, -0.35)) @ Matrix.Rotation(math.radians(-35), 4, 'Y') @ Matrix.Translation((-0.6, 0, 0))
for p in parti:
    applica_trasf(p); p.data.transform(R)
for k in range(5):
    z = -0.07 * k
    parti.append(toro(f'n4c{k}', (0.6, 0, z - 0.03), 0.018, 0.004, M['inox'], asse=(1, 0, 0) if k % 2 else (0, 1, 0), seg=10, seg2=4, uv=None))
registra('lampade', fondi('det_neon_penzolante', parti, (0.6, 0, 0)), 'soffitto', 'plafoniera staccata da un lato, pende da una catenella (origine sull attacco rimasto)')


def applique(nome, acceso=True, rotta=False):
    """Luce d'emergenza: plafoniera stagna Ø 18 cm con gabbia e vetro rosso (come nel kit della sala)."""
    parti = [cilindro(f'{nome}_base', (0, -0.02, 0), 0.09, 0.04, M['metallo'], asse=(0, 1, 0), seg=24, uv=0.3)]
    if not rotta:
        parti.append(sfera(f'{nome}_vetro', (0, -0.04, 0), 0.075, M['vetro_rosso'] if acceso else M['vetro_rosso_spento'], scala=(1, 0.8, 1), seg=20, uv=None))
    else:
        parti.append(sfera(f'{nome}_lamp', (0, -0.06, 0), 0.02, M['neon_spento'], seg=10, uv=None))
        for k in range(3):
            p = prisma(f'{nome}_sch{k}', scheggia(0.05, 0.5), 0.003, M['vetro_rosso_spento'])
            p.rotation_euler = (math.radians(90), 0, k * 2); p.location = (0.04 * math.cos(k * 2), -0.04, 0.04 * math.sin(k * 2))
            parti.append(p)
    for k, a in enumerate((Vector((1, 0, 0)), Vector((0, 0, 1)))):
        parti.append(toro(f'{nome}_g{k}', (0, -0.045, 0), 0.08, 0.004, M['metallo'], asse=a, seg=20, seg2=4, uv=None))
    parti.append(toro(f'{nome}_g2', (0, -0.04, 0), 0.08, 0.004, M['metallo'], asse=(0, 1, 0), seg=20, seg2=4, uv=None))
    return parti


registra('lampade', fondi('det_applique_emergenza', applique('a1')), 'muro', 'luce d emergenza rossa accesa (Ø 18 cm, gabbia)')
registra('lampade', fondi('det_applique_emergenza_spenta', applique('a2', acceso=False)), 'muro', 'luce d emergenza spenta')
registra('lampade', fondi('det_applique_emergenza_rotta', applique('a3', rotta=True)), 'muro', 'luce d emergenza col vetro rotto')


def faro(nome, acceso=True, inclinato=25):
    parti = [box(f'{nome}_piastra', (0, -0.005, 0), (0.14, 0.01, 0.1), M['metallo_grigio'], uv=0.3),
             box(f'{nome}_braccio', (0, -0.08, 0), (0.03, 0.15, 0.03), M['metallo_grigio'], uv=0.3)]
    corpo = [box(f'{nome}_corpo', (0, -0.25, 0), (0.3, 0.16, 0.22), M['metallo'], uv=0.3),
             box(f'{nome}_vetro', (0, -0.332, 0), (0.26, 0.005, 0.18), M['faro_acceso'] if acceso else M['vetro'], uv=None)]
    for k in range(5):
        corpo.append(box(f'{nome}_al{k}', (-0.12 + k * 0.06, -0.2, 0.12), (0.01, 0.12, 0.03), M['metallo'], uv=None))
    corpo.append(toro(f'{nome}_staffa', (0, -0.22, 0), 0.17, 0.008, M['metallo_grigio'], asse=(0, 0, 1), seg=24, seg2=4, uv=None))
    R = Matrix.Translation((0, -0.15, 0)) @ Matrix.Rotation(math.radians(-inclinato), 4, 'X') @ Matrix.Translation((0, 0.15, 0))
    for p in corpo:
        applica_trasf(p); p.data.transform(R)
    return parti + corpo


registra('lampade', fondi('det_faro', faro('f1')), 'muro', 'faro da muro acceso, inclinato in basso di 25 gradi')
registra('lampade', fondi('det_faro_spento', faro('f2', False, 50)), 'muro', 'faro spento, girato verso il basso')

# ================================================================== CARTELLI (solo disegni)
CARTELLI = ('non_correre', 'non_tuffarsi', 'vietato_vetro', 'pavimento_bagnato', 'profondita', 'uscita', 'pronto_soccorso', 'salvagente')


def cartello(nome, tipo, stato='dritto', lato=0.4):
    parti = [box(f'{nome}_lastra', (0, -0.004, 0), (lato, 0.006, lato), M['plastica'], uv=0.5),
             quad(f'{nome}_faccia', (0, -0.0075, 0), lato - 0.004, lato - 0.004, (0, -1, 0), M[f'cartello_{tipo}'])]
    for sx in (-1, 1):
        for sz in (-1, 1):
            if stato == 'penzolante' and not (sx == -1 and sz == 1):
                continue
            parti.append(cilindro(f'{nome}_v{sx}{sz}', (sx * (lato / 2 - 0.025), -0.009, sz * (lato / 2 - 0.025)), 0.008, 0.004, M['inox'], asse=(0, 1, 0), seg=8, uv=None))
    if stato == 'storto':
        R = Matrix.Rotation(math.radians(9), 4, 'Y')
    elif stato == 'penzolante':
        p = Vector((-(lato / 2 - 0.025), 0, lato / 2 - 0.025))
        R = Matrix.Translation(p) @ Matrix.Rotation(math.radians(-38), 4, 'Y') @ Matrix.Translation(-p)
    elif stato == 'piegato':
        R = None
        for o in parti:
            applica_trasf(o)
            for v in o.data.vertices:
                if v.co.z < -0.05:
                    t = (-0.05 - v.co.z)
                    v.co.y -= t * 0.6
    else:
        R = None
    if R is not None:
        for o in parti:
            applica_trasf(o); o.data.transform(R)
    return parti


for k, tipo in enumerate(CARTELLI):
    stato = ('dritto', 'storto', 'dritto', 'penzolante', 'dritto', 'storto', 'piegato', 'dritto')[k]
    registra('cartelli', fondi(f'det_cartello_{tipo}', cartello(f'c{k}', tipo, stato)), 'muro', f'cartello 40 x 40 cm, solo disegno ({stato}); centro a 1,6-1,8 m')
for tipo in ('non_correre', 'pavimento_bagnato'):
    registra('cartelli', fondi(f'det_cartello_{tipo}_penzolante', cartello(f'cpz{tipo}', tipo, 'penzolante')), 'muro', 'variante appesa a una vite sola')

# ================================================================== ORGANICO: alghe secche, incrostazioni, muffa (decal con alfa)
for nome, w, h, dove in (('calcare', 1.2, 0.6, 'muro'), ('muffa', 1.0, 0.8, 'muro'), ('ruggine_colata', 0.35, 1.2, 'muro'),
                         ('alghe_secche', 1.4, 1.0, 'pavimento'), ('alghe_verdi', 1.2, 0.9, 'pavimento'), ('calcare', 1.0, 1.0, 'pavimento')):
    if dove == 'muro':
        q = quad(f'mc_{nome}', (0, -0.003, -h / 2 if nome == 'ruggine_colata' else 0), w, h, (0, -1, 0), M[f'macchia_{nome}'])
    else:
        q = quad(f'mc_{nome}', (0, 0, 0.003), w, h, (0, 0, 1), M[f'macchia_{nome}'], su=(0, 1, 0))
    registra('organico', fondi(f'det_macchia_{nome}_{dove}', [q]), dove,
             'decal con alfa (alpha scissor): ' + ('sotto un tubo o un attacco: la colatura scende dall origine' if nome == 'ruggine_colata' else 'macchia'))
# mucchi di alghe secche: nastri arricciati e appiattiti
for v in range(3):
    parti = []
    for k in range(14 + 4 * v):
        a = random.uniform(0, 6.28); r0 = random.uniform(0, 0.3)
        p0 = Vector((r0 * math.cos(a), r0 * math.sin(a), 0.004))
        pts = [p0]
        d = Vector((math.cos(a + 1.2), math.sin(a + 1.2), 0))
        for j in range(8):
            d.rotate(Euler((0, 0, random.uniform(-0.6, 0.6))))
            pts.append(pts[-1] + d * 0.05 + Vector((0, 0, 0.006 * random.random())))
        nastro = cordone(f'al{v}_{k}', pts, 0.008, M['macchia_alghe_secche'] if k % 3 else M['macchia_alghe_verdi'], seg=4)
        nastro.scale = (1, 1, 0.35); applica_trasf(nastro)
        parti.append(nastro)
    parti.append(quad(f'al{v}_base', (0, 0, 0.002), 0.9, 0.9, (0, 0, 1), M['macchia_alghe_secche'], su=(0, 1, 0)))
    registra('organico', fondi(f'det_alghe_secche_mucchio_{v + 1}', parti), 'pavimento', 'mucchio di alghe secche: bordi delle vasche, scarichi, fondo della piscina')
# incrostazione di calcare lungo uno spigolo (1 m): cordone bitorzoluto schiacciato
for v in range(2):
    pts = [(x / 10, 0, 0) for x in range(11)]
    ob = cordone(f'inc{v}', pts, 0.03, M['macchia_calcare'], seg=10, liscia=False)
    for vv in ob.data.vertices:
        vv.co.y = min(vv.co.y, 0) * (1.0 + 0.6 * noise.noise(vv.co * 12 + Vector((v, 0, 0))))
        vv.co.z *= 0.8 + 0.5 * noise.noise(vv.co * 9)
    registra('organico', fondi(f'det_incrostazione_spigolo_{v + 1}', [ob]), 'muro', 'crosta di calcare lungo uno spigolo, 1 m lungo +X (bordo vasca, base del muro)')

# ================================================================== CATENE E CORDE


def catena(nome, pts, mat, maglia=0.05):
    """Maglie lungo un percorso: anelli allungati alternati di 90 gradi."""
    P = [Vector(p) for p in pts]
    L = sum((P[i + 1] - P[i]).length for i in range(len(P) - 1))
    n = int(L / maglia)
    parti = []
    acc = [0.0]
    for i in range(len(P) - 1):
        acc.append(acc[-1] + (P[i + 1] - P[i]).length)
    for k in range(n):
        s = (k + 0.5) * maglia
        i = max(j for j in range(len(P) - 1) if acc[j] <= s)
        t = (s - acc[i]) / max(acc[i + 1] - acc[i], 1e-6)
        p = P[i].lerp(P[i + 1], t); d = (P[i + 1] - P[i]).normalized()
        bm = bmesh.new()
        seg, seg2, R, r = 12, 6, 0.016, 0.0045
        vs = []
        for a in range(seg):
            aa = 2 * math.pi * a / seg
            row = []
            for b in range(seg2):
                bb = 2 * math.pi * b / seg2
                c = Vector(((R + r * math.cos(bb)) * math.cos(aa) * 1.6, (R + r * math.cos(bb)) * math.sin(aa), r * math.sin(bb)))
                row.append(bm.verts.new(c))
            vs.append(row)
        for a in range(seg):
            for b in range(seg2):
                bm.faces.new((vs[a][b], vs[(a + 1) % seg][b], vs[(a + 1) % seg][(b + 1) % seg2], vs[a][(b + 1) % seg2]))
        me = bpy.data.meshes.new('m'); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(f'{nome}_{k}', me); bpy.context.scene.collection.objects.link(ob)
        q = d.to_track_quat('X', 'Z')
        ob.matrix_basis = Matrix.Translation(p) @ q.to_matrix().to_4x4() @ Matrix.Rotation(math.pi / 2 * (k % 2), 4, 'X')
        assegna(ob, mat); uv_box(ob, 0.3); liscio(ob, 80)
        parti.append(ob)
    return parti


for L in (1.0, 2.0, 3.0):
    parti = catena(f'cp{L}', [(0, 0, 0), (0.02, 0.0, -L)], M['ruggine'])
    parti.append(box(f'cpa{L}', (0, 0, 0.01), (0.06, 0.06, 0.02), M['ruggine'], uv=0.3))
    registra('catene_corde', fondi(f'det_catena_pendente_{int(L)}m', parti), 'soffitto', f'catena che pende, {int(L)} m')
parti = catena('cf', catenaria((0, 0, 0), (3, 0, 0), 0.6, 30), M['ruggine'])
registra('catene_corde', fondi('det_catena_festone_3m', parti), 'soffitto', 'catena a festone tra due punti a 3 m (ringhiere, transenne)')
# catena ammucchiata a terra
pts = []
for k in range(60):
    a = k * 0.45; r = 0.05 + 0.12 * (k / 60) + 0.03 * math.sin(k)
    pts.append((r * math.cos(a), r * math.sin(a), 0.01 + 0.012 * (k % 7) / 7))
registra('catene_corde', fondi('det_catena_a_terra', catena('ct', pts, M['ruggine'])), 'pavimento', 'catena ammucchiata per terra')
# gancio
parti = [cordone('gk', [(0, 0, 0), (0, 0, -0.12), (0.01, 0, -0.17), (0.05, 0, -0.18), (0.07, 0, -0.14), (0.065, 0, -0.11)], 0.009, M['ruggine'], seg=8)]
parti.append(toro('gka', (0, 0, 0.015), 0.02, 0.006, M['ruggine'], asse=(1, 0, 0), seg=12, seg2=4, uv=None))
registra('catene_corde', fondi('det_gancio', parti), 'soffitto', 'gancio (da mettere in fondo a una catena)')
for v, (L, mat) in enumerate(((1.5, 'corda'), (3.0, 'corda_rossa'))):
    pts = [(0.05 * math.sin(k * 0.7) * k / 10, 0, -L * k / 10) for k in range(11)]
    parti = [cordone(f'co{v}', pts, 0.014, M[mat], seg=10, u_tile=0.15)]
    e = Vector(pts[-1])
    for k in range(4):
        parti.append(cordone(f'co{v}s{k}', [e, e + Vector((0.015 * (k - 1.5), 0.01 * (k % 2), -0.05))], 0.004, M[mat], seg=4, liscia=False, u_tile=0.15))
    registra('catene_corde', fondi(f'det_corda_pendente_{v + 1}', parti), 'soffitto', f'corda che pende sfilacciata, {L} m')
parti = [cordone('cfe', catenaria((0, 0, 0), (4, 0, 0), 0.5), 0.014, M['corda_rossa'], seg=10, u_tile=0.15)]
for x in range(1, 8):
    i = int(x / 8 * 24); p = catenaria((0, 0, 0), (4, 0, 0), 0.5)[i]
    parti.append(cilindro(f'cfg{x}', p - Vector((0, 0, 0.0)), 0.035, 0.09, mat_pbr('M_det_galleggiante', base=(0.9, 0.85, 0.75), roughness=0.5) if x % 2 else M['vetro_rosso_spento'], asse=(1, 0, 0), seg=12, uv=None))
registra('catene_corde', fondi('det_corda_galleggianti_4m', parti), 'soffitto', 'corda corsia con galleggianti, 4 m (tra due ringhiere o appesa)')
# rotolo di corda a terra
pts = []
for k in range(120):
    a = k * 0.32; r = 0.09 + 0.05 * math.sin(k * 0.05) + 0.003 * k / 4
    pts.append((r * math.cos(a), r * math.sin(a), 0.014 + 0.02 * (k // 20)))
registra('catene_corde', fondi('det_corda_rotolo', [cordone('cr', pts, 0.014, M['corda'], seg=8, u_tile=0.15)]), 'pavimento', 'rotolo di corda per terra')

# ------------------------------------------------------------------ disposizione per la vetrina ed export per categoria
ORDINE = ['detriti', 'cavi', 'tubi', 'elettrico', 'lampade', 'cartelli', 'organico', 'catene_corde']
GLB = T(DET, 'glb'); os.makedirs(GLB, exist_ok=True)
for ci, cat in enumerate(ORDINE):
    obs = CATEGORIE.get(cat, [])
    x = 0.0
    for o in obs:
        L = CATALOGO[o.name]['ingombro_m'][0]
        o.location = (x + L / 2, -ci * 2.5, 0)
        x += max(L, 0.25) + 0.25
    for o in obs:
        CATALOGO[o.name]['glb'] = f'glb/{cat}.glb'
    esporta_glb(T(GLB, f'{cat}.glb'), obs, luci=False)
with open(T(DET, 'catalogo.json'), 'w') as f:
    json.dump({'nota': "Nodi dei GLB del kit di dettagli. 'appoggio': pavimento (origine alla base), muro (origine sul filo del muro, "
                       "il dettaglio sporge verso +Z Godot), soffitto (origine nel punto d'attacco, pende verso -Y Godot). "
                       "Ingombro in metri (x, y, z di Blender).", 'dettagli': CATALOGO}, f, indent=1, ensure_ascii=False)
print('dettagli:', len(CATALOGO), {c: len(v) for c, v in CATEGORIE.items()})
if '--blend' in ARGS:
    bpy.ops.wm.save_as_mainfile(filepath='/tmp/dettagli.blend')
