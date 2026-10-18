"""Dai GLB grezzi di Meshy (meshy/) ai modelli per Godot (godot/assets/enigma_acquari/).

- vasca_telaio (stile A): scala a 2,0 m di larghezza (profondità x1,25), origine in basso al centro;
  misura con i raggi l'interno del telaio, dove vanno vetri e acqua (stampato e salvato in misure.json).
- cilindro (stile B): dal boiler cilindro_tubi (Meshy l'ha fatto pieno) si tengono la base e il
  coperchio, tagliati e chiusi; in mezzo il vetro lo mette Godot. Più quattro tiranti.
- valvola_rossa: scala, origine al centro del tubo.
- lampada_gabbia: scala, il globo si separa in una mesh a sé (materiale acceso/spento in Godot).
Uso: blender-venv/bin/python prepara_modelli.py
"""
import bpy, bmesh, json, math, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', 'godot', 'assets', 'enigma_acquari')
misure = {}


def carica(nome):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(QUI, 'meshy', nome + '.glb'))
    o = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


def bbox(o):
    vs = [v.co for v in o.data.vertices]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def trasforma(o, m):
    o.data.transform(m)
    o.data.update()


def esporta(nome, oggetti):
    bpy.ops.object.select_all(action='DESELECT')
    for o in oggetti:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, nome + '.glb'), use_selection=True,
                              export_format='GLB', export_yup=True)


def raggio(bvh, o, d):
    hit = bvh.ray_cast(Vector(o), Vector(d).normalized())
    return hit[3] if hit[0] else None


# --- stile A: vasca col telaio ---
o = carica('vasca_telaio')
mn, mx = bbox(o)
s = 2.0 / (mx.x - mn.x)
trasforma(o, Matrix.Translation((0, 0, 0)) @ Matrix.Diagonal((s, s * 1.25, s, 1)) @ Matrix.Translation(
    (-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
o.name = 'vasca_telaio'
bvh = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
mn, mx = bbox(o)
c = Vector((0, 0, (mn.z + mx.z) / 2))
# l'interno: dal centro verso i lati, il fondo e il bordo di sopra (più raggi, si tiene il più vicino)
# i montanti sono negli angoli: i raggi passano rasenti al lato davanti / al lato destro
xin = min(raggio(bvh, Vector((0, mx.y - 0.03, c.z + dz)), (1, 0, 0)) or 9 for dz in (-0.2, 0, 0.2))
yin = min(raggio(bvh, Vector((mx.x - 0.03, 0, c.z + dz)), (0, 1, 0)) or 9 for dz in (-0.2, 0, 0.2))
# altezza del pannello davanti della base (il vetro si vede da lì in su)
pann = max((mx.z - (raggio(bvh, Vector((dx, mn.y + 0.01, mx.z + 1)), (0, 0, -1)) or 0) - 1) for dx in (-0.5, 0, 0.5))
fondo = c.z - min(raggio(bvh, c + Vector((dx, 0, 0)), (0, 0, -1)) or 9 for dx in (-0.5, 0, 0.5))
sopra = c.z + min(raggio(bvh, c + Vector((dx, 0, 0)), (0, 0, 1)) or 9 for dx in (-0.5, 0, 0.5))
misure['vasca_telaio'] = dict(esterno=[round(v, 3) for v in (mx - mn)], interno_mezza_x=round(xin, 3),
                              interno_mezza_z_godot=round(yin, 3), fondo=round(fondo, 3), sopra=round(sopra, 3),
                              pannello_base=round(pann, 3))
esporta('vasca_telaio', [o])

# --- stile A: basamento (2,0 x 0,5 x 0,93 m, origine in basso al centro; bocca flangiata davanti) ---
o = carica('basamento_vasca')
mn, mx = bbox(o)
trasforma(o, Matrix.Diagonal((2.0 / (mx.x - mn.x), 0.93 / (mx.y - mn.y), 0.5 / (mx.z - mn.z), 1)) @ Matrix.Translation(
    (-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
# la bocca sporge dal lato -Y (in Godot +Z): la si toglie dal conto della profondità
mn, mx = bbox(o)
o.name = 'basamento_vasca'
misure['basamento_vasca'] = dict(esterno=[round(v, 3) for v in (mx - mn)])
esporta('basamento_vasca', [o])

# --- stile B: base e coperchio dal boiler ---
o = carica('cilindro_tubi')
mn, mx = bbox(o)
# il corpo: raggio misurato a metà altezza, in quattro direzioni
bvh = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
zc = (mn.z + mx.z) / 2 + 0.1
rr = [2.0 - (raggio(bvh, Vector((2 * math.cos(a), 2 * math.sin(a), zc)), (-math.cos(a), -math.sin(a), 0)) or 2)
      for a in (0.3, 1.9, 3.5, 5.0)]
r_corpo = sorted(rr)[1]
s = 0.55 / r_corpo          # diametro del vetro 1,1 m
trasforma(o, Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation((0, 0, -mn.z)))
alto = (mx.z - mn.z) * s
taglio_base, taglio_cop = 0.42 * alto / 1.9 * 1.0 + 0.0, None
z_base = (0.95 - 0.53) * s       # coordinate del grezzo (centrato): base sotto z=-0.53, coperchio sopra z=0.50
z_cop = (0.95 + 0.50) * s


def tieni(obj, nome, zmin, zmax):
    b = obj.copy(); b.data = obj.data.copy(); b.name = nome
    bpy.context.scene.collection.objects.link(b)
    bm = bmesh.new(); bm.from_mesh(b.data)
    for z, verso in ((zmin, -1), (zmax, 1)):
        if z is None:
            continue
        r = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z),
                                   plane_no=(0, 0, verso), clear_outer=True)
        bordo = [e for e in r['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
        if bordo:
            bmesh.ops.holes_fill(bm, edges=bordo, sides=0)
    bm.to_mesh(b.data); bm.free()
    return b


base = tieni(o, 'cilindro_base', None, z_base)
cop = tieni(o, 'cilindro_coperchio', z_cop, None)
# il coperchio scende sopra il vetro: lo si porta con il taglio a z = 0 (in Godot lo si mette alla
# quota giusta), la base resta a terra
trasforma(cop, Matrix.Translation((0, 0, -z_cop)))
bpy.data.objects.remove(o)
misure['cilindro'] = dict(diametro_vetro=1.1, alt_base=round(z_base, 3),
                          alt_coperchio=round((mx.z - mn.z) * s - z_cop, 3))
esporta('cilindro_base', [base])
esporta('cilindro_coperchio', [cop])

# --- valvola ---
o = carica('valvola_rossa')
mn, mx = bbox(o)
s = 1.1 / (mx.x - mn.x)
trasforma(o, Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -(mn.z + mx.z) / 2)))
mn, mx = bbox(o)
misure['valvola_rossa'] = dict(esterno=[round(v, 3) for v in (mx - mn)])
esporta('valvola_rossa', [o])

# --- lampada a gabbia: il globo a parte ---
o = carica('lampada_gabbia')
mn, mx = bbox(o)
s = 0.42 / (mx.z - mn.z)
# origine: sul muro (la piastra sta a +Y), all'altezza del centro
trasforma(o, Matrix.Diagonal((s, s, s, 1)) @ Matrix.Translation((-(mn.x + mx.x) / 2, -mx.y, -(mn.z + mx.z) / 2)))
mn, mx = bbox(o)
# centro del globo: il centro della gabbia (la parte lontana dal muro)
gx = 0.0
gz = 0.0
gy = mn.y + (mx.z - mn.z) * 0.5
cen = Vector((gx, gy, gz))
bvh = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
# raggio del globo: dal centro verso fuori il primo colpo è il globo (dall'interno)
bm = bmesh.new(); bm.from_mesh(o.data)
dist = sorted((f.calc_center_median() - cen).length for f in bm.faces)
bm.free()
# il globo è la superficie più vicina al centro: si prendono le facce entro il raggio dal sondaggio
rg = min(raggio(bvh, cen, d) or 9 for d in ((1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1), (0, -1, 0)))
bpy.ops.object.mode_set(mode='EDIT')
bm = bmesh.from_edit_mesh(o.data)
for f in bm.faces:
    f.select = (f.calc_center_median() - cen).length < rg * 1.06
bmesh.update_edit_mesh(o.data)
bpy.ops.mesh.separate(type='SELECTED')
bpy.ops.object.mode_set(mode='OBJECT')
glob = [x for x in bpy.data.objects if x.type == 'MESH' and x != o][0]
glob.name = 'globo'
o.name = 'lampada'
mat = bpy.data.materials.new('globo_vetro')
glob.data.materials.clear(); glob.data.materials.append(mat)
misure['lampada_gabbia'] = dict(esterno=[round(v, 3) for v in (mx - mn)], raggio_globo=round(rg, 3),
                                centro_globo=[round(v, 3) for v in cen])
esporta('lampada_gabbia', [o, glob])

with open(os.path.join(QUI, 'misure.json'), 'w') as f:
    json.dump(misure, f, indent=1)
print(json.dumps(misure, indent=1))
