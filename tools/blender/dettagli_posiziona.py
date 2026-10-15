"""Posizionamento suggerito del kit di dettagli nella sala principale.

Importa i GLB della sala (assets_src/ambiente/glb/sala/) e trova i posti con dei raggi (raycast) sulla geometria
vera: pavimento libero, muri piatti senza oblò e porte, soffitto della galleria, bordi delle vasche, fondo
della piscina. Scrive assets_src/ambiente_dettagli/posizionamento.json con le trasformazioni in coordinate Godot.

Uso: /home/user/tools/blender-venv/bin/python tools/blender/dettagli_posiziona.py [--render] [--anteprima]
Con --render fa anche un render di controllo della sala con i dettagli (docs/report/render_ambienti2/dettagli_sala*.jpg).
"""
import json, math, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
from ambienti2_comune import *

ARGS = argomenti()
SALA = os.path.join(RADICE, 'assets_src', 'ambiente', 'glb', 'sala')
DET = os.path.join(RADICE, 'assets_src', 'ambiente_dettagli')
DATI = json.load(open(os.path.join(SALA, 'sala_dati.json')))
CAT = json.load(open(os.path.join(DET, 'catalogo.json')))['dettagli']
random.seed(2026)
reset()

# ------------------------------------------------------------------ geometria della sala
for f in ('sala_architettura', 'sala_piscina', 'sala_area_bimbi', 'sala_torre_scivoli', 'sala_oggetti', 'sala_interattivi'):
    bpy.ops.import_scene.gltf(filepath=os.path.join(SALA, f + '.glb'))
dg = bpy.context.evaluated_depsgraph_get()
bm = bmesh.new()
for o in bpy.data.objects:
    if o.type != 'MESH' or 'colonly' in o.name:
        continue
    me = o.evaluated_get(dg).to_mesh()
    me.transform(o.matrix_world)
    bm.from_mesh(me)
    o.evaluated_get(dg).to_mesh_clear()
BVH = BVHTree.FromBMesh(bm)
print('triangoli della sala:', len(bm.faces))

X0, X1 = DATI['sala']['x']; Y0, Y1 = DATI['sala']['y']
PISC = DATI['piscina_onde']
TORRE = DATI['torre']


def raggio(o, d, dist=50.0):
    hit = BVH.ray_cast(Vector(o), Vector(d).normalized(), dist)
    return hit if hit[0] is not None else None


# zone vietate (Blender): passaggi principali e posti di scena
VIETATE = [((-1.5, 1.5), (-12.0, -5.5)),           # dallo spawn al piedistallo: la scena della statua resta pulita
           ((-1.2, 1.2), (-9.5, -4.4))]
PIEDISTALLO = Vector(DATI['piedistallo']['centro_blender'][:2])
occupati = []   # (centro, raggio)


def libero(p, r):
    p = Vector(p[:2])
    if (p - PIEDISTALLO).length < 2.2:
        return False
    for (a, b), (c, d) in VIETATE:
        if a <= p.x <= b and c <= p.y <= d:
            return False
    return all((p - q).length > r + rq for q, rq in occupati)


def spazio_intorno(p, r, h=0.25):
    """Nessun ostacolo entro r a quota h (raggi orizzontali)."""
    for k in range(8):
        a = k * math.pi / 4
        if raggio(Vector(p) + Vector((0, 0, h)), (math.cos(a), math.sin(a), 0), r):
            return False
    return True


POSTI = []


def aggiungi(nodo, M, zona):
    info = CAT[nodo]
    POSTI.append({'nodo': nodo, 'glb': info['glb'], 'zona': zona, 'matrice_blender': M})


def sul_pavimento(nodo, x, y, zona, r=0.4, z_atteso=(-0.06, 0.08), vicino_muro=False):
    hit = raggio((x, y, 3.0), (0, 0, -1), 8)
    if not hit:
        return False
    p, n = hit[0], hit[1]
    if n.z < 0.95 or not (z_atteso[0] <= p.z <= z_atteso[1]):
        return False
    if not libero(p, r) or (not vicino_muro and not spazio_intorno(p, r)):
        return False
    M = Matrix.Translation(p + Vector((0, 0, 0.001))) @ Matrix.Rotation(random.uniform(0, 2 * math.pi), 4, 'Z')
    aggiungi(nodo, M, zona); occupati.append((Vector(p[:2]), r))
    return True


def sul_muro(nodo, p_interno, direzione, z, zona, w=None, h=None, r=None, base=False):
    """Raggio orizzontale da un punto interno verso il muro: il dettaglio guarda la sala."""
    info = CAT[nodo]
    w = w or max(info['ingombro_m'][0], 0.2); h = h or max(info['ingombro_m'][2], 0.2)
    o = Vector((p_interno[0], p_interno[1], z))
    hit = raggio(o, direzione, 12)
    if not hit:
        return False
    p, n = hit[0], hit[1]
    if abs(n.z) > 0.1:
        return False
    t = Vector((-n.y, n.x, 0)).normalized()
    # il muro dev'essere piatto su tutta la sagoma (niente oblò, porte, colonne)
    for sx, sz in ((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5), (0, 0)):
        if base:
            sz = (sz + 0.5) * 0.9 + 0.05
        q = p + n * 0.3 + t * (sx * w) + Vector((0, 0, sz * h))
        hh = raggio(q, -n, 0.6)
        if not hh or abs((hh[0] - q).length - 0.3) > 0.03 or hh[1].dot(n) < 0.98:
            return False
    rr = r or max(w, h) / 2
    if not all((Vector(p) - q).length > rr + rq for q, rq in occupati_muro):
        return False
    yaw = math.atan2(n.x, -n.y)
    M = Matrix.Translation(p) @ Matrix.Rotation(yaw, 4, 'Z')
    aggiungi(nodo, M, zona); occupati_muro.append((Vector(p), rr))
    return M


occupati_muro = []


def al_soffitto(nodo, x, y, zona, z_min=3.4, z_max=4.6, yaw=None, libero_sotto=None):
    hit = raggio((x, y, 2.2), (0, 0, 1), 4)
    if not hit:
        return False
    p, n = hit[0], hit[1]
    if n.z > -0.95 or not (z_min <= p.z <= z_max) or not libero(p, 0.0):
        return False
    L = libero_sotto if libero_sotto is not None else CAT[nodo]['ingombro_m'][2]
    if raggio(p - Vector((0, 0, 0.02)), (0, 0, -1), L + 0.3):
        return False
    if not all((Vector(p) - q).length > 0.8 + rq for q, rq in occupati_muro):
        return False
    yaw = random.uniform(0, 2 * math.pi) if yaw is None else yaw
    if CAT[nodo]['ingombro_m'][0] > 1.5:
        # festoni e plafoniere lunghe: l'altro capo deve toccare lo stesso soffitto
        e = p + Vector((math.cos(yaw), math.sin(yaw), 0)) * CAT[nodo]['ingombro_m'][0]
        h2 = raggio(e - Vector((0, 0, 0.3)), (0, 0, 1), 1)
        if not h2 or abs(h2[0].z - p.z) > 0.05:
            return False
    M = Matrix.Translation(p) @ Matrix.Rotation(yaw, 4, 'Z')
    aggiungi(nodo, M, zona); occupati_muro.append((Vector(p), 0.6))
    return True


def tenta(n, fn, *a, **k):
    """Prova fino a n volte una funzione che pesca posti a caso; restituisce quanti ne ha messi."""
    return sum(1 for _ in range(n) if fn(*a, **k))


def nodi(prefisso):
    return [k for k in CAT if k.startswith(prefisso)]


# ------------------------------------------------------------------ 1) per terra: detriti sparsi, giocattoli, asciugamani
def a_caso_pav(lista, zona, r, n, area=(X0 + 0.5, X1 - 0.5, Y0 + 0.5, Y1 - 0.5)):
    def f():
        return sul_pavimento(random.choice(lista), random.uniform(area[0], area[1]), random.uniform(area[2], area[3]), zona, r)
    return tenta(n, f)


GIOCATTOLI = ['det_paperella', 'det_secchiello', 'det_paletta', 'det_barchetta', 'det_pistola_acqua', 'det_pesce_gomma', 'det_maschera_sub', 'det_ciabatta']
print('fogli', a_caso_pav(nodi('det_foglio') + nodi('det_carta_accartocciata'), 'pavimento', 0.3, 80))
print('giocattoli', a_caso_pav(GIOCATTOLI, 'pavimento', 0.3, 50))
print('asciugamani', a_caso_pav(nodi('det_asciugamano'), 'pavimento', 0.6, 40))
print('piastrelle', a_caso_pav(nodi('det_piastrella_rotta'), 'pavimento', 0.15, 80))
print('vetri', a_caso_pav(nodi('det_vetri_rotti'), 'pavimento', 0.5, 25))
print('catena a terra', a_caso_pav(['det_catena_a_terra', 'det_corda_rotolo'], 'pavimento', 0.4, 12))
print('macchie pav', a_caso_pav(['det_macchia_calcare_pavimento', 'det_macchia_alghe_secche_pavimento'], 'pavimento', 0.7, 40))

# lungo il piede dei muri: mucchi di piastrelle cadute, alghe secche
def piede_muri(lista, zona, n, dist=(0.35, 0.7), r=0.45):
    def f():
        lato = random.choice('nseo')
        if lato in 'ns':
            x = random.uniform(X0 + 1, X1 - 1); y = (Y1 - random.uniform(*dist)) if lato == 'n' else (Y0 + random.uniform(*dist))
        else:
            y = random.uniform(Y0 + 1, Y1 - 1); x = (X1 - random.uniform(*dist)) if lato == 'e' else (X0 + random.uniform(*dist))
        return sul_pavimento(random.choice(lista), x, y, zona, r, vicino_muro=True)
    return tenta(n, f)


print('mucchi piastrelle', piede_muri(nodi('det_mucchio_piastrelle'), 'piede dei muri', 40))
print('alghe al muro', piede_muri(nodi('det_alghe_secche_mucchio'), 'piede dei muri', 20))

# bordi delle vasche e della piscina: alghe secche e calcare dove l'acqua e' arrivata
def bordo_piscina(lista, zona, n):
    px0, px1 = PISC['x']; py0, py1 = PISC['y']
    def f():
        lato = random.choice('nseo'); m = random.uniform(0.5, 1.2)
        if lato in 'ns':
            x = random.uniform(px0, px1); y = py1 + m if lato == 'n' else py0 - m
        else:
            y = random.uniform(py0, py1); x = px1 + m if lato == 'e' else px0 - m
        return sul_pavimento(random.choice(lista), x, y, zona, 0.5, vicino_muro=True)
    return tenta(n, f)


print('bordo piscina', bordo_piscina(nodi('det_alghe_secche_mucchio') + ['det_macchia_alghe_verdi_pavimento', 'det_macchia_calcare_pavimento'], 'bordo piscina', 40))

# fondo della piscina vuota: giocattoli e alghe tra i giocattoli che riaffiorano (sotto -1,5 m)
def fondo_piscina(lista, zona, n):
    px0, px1 = PISC['x']; py0, py1 = PISC['y']
    def f():
        return sul_pavimento(random.choice(lista), random.uniform(px0 + 0.5, px1 - 0.5), random.uniform(py0 + 0.5, py1 - 0.5), zona, 0.4, z_atteso=(-2.4, -0.3))
    return tenta(n, f)


print('fondo piscina', fondo_piscina(GIOCATTOLI + nodi('det_alghe_secche_mucchio') + ['det_macchia_alghe_verdi_pavimento', 'det_macchia_calcare_pavimento'] + nodi('det_mucchio_piastrelle'), 'fondo piscina', 60))

# ------------------------------------------------------------------ 2) muri perimetrali
DIREZIONI = {'n': (0, 1, 0), 's': (0, -1, 0), 'e': (1, 0, 0), 'o': (-1, 0, 0)}


def punto_interno(lato, d=3.5):
    if lato == 'n':
        return (random.uniform(X0 + 1, X1 - 1), Y1 - d)
    if lato == 's':
        return (random.uniform(X0 + 1, X1 - 1), Y0 + d)
    if lato == 'e':
        return (X1 - d, random.uniform(Y0 + 1, Y1 - 1))
    return (X0 + d, random.uniform(Y0 + 1, Y1 - 1))


def sui_muri(lista, zona, n, z, d=1.0, base=False):
    def f():
        lato = random.choice('nseo')
        zz = random.uniform(*z) if isinstance(z, tuple) else z
        # il raggio parte un po' piu' in alto quando l'oggetto parte dal pavimento
        return bool(sul_muro(random.choice(lista), punto_interno(lato, d), DIREZIONI[lato], zz, zona, base=base))
    return tenta(n, f)


# tubi e condotte alti, sotto la galleria (fino a 3,8 m); sotto i tubi una colatura di ruggine
def tubi_con_colature(n):
    messi = 0
    for _ in range(n):
        lato = random.choice('nseo')
        nodo = random.choice(nodi('det_tubo_muro') + ['det_tubi_paralleli_2m', 'det_condotta_aria_2m', 'det_condotta_aria_4m'])
        M = sul_muro(nodo, punto_interno(lato, 1.0), DIREZIONI[lato], random.uniform(3.0, 3.6), 'muri, sotto la galleria')
        if M:
            messi += 1
            L = CAT[nodo]['ingombro_m'][0]
            for k in range(random.randint(0, 2)):
                q = M @ Vector((random.uniform(0.2, L - 0.2), 0.0, -0.15))
                Mc = Matrix.Translation(q) @ M.to_3x3().to_4x4()
                aggiungi('det_macchia_ruggine_colata_muro', Mc, 'colatura sotto un tubo')
    return messi


print('tubi', tubi_con_colature(70))
print('tubi verticali', sui_muri(['det_tubo_verticale_3m'], 'muri', 20, 0.02, base=True))
print('valvole', sui_muri(['det_tubo_valvola_T'], 'muri', 10, (1.1, 1.5)))
print('bocchette', sui_muri(nodi('det_bocchetta'), 'muri', 24, (2.2, 3.2)))
print('bocchette basse', sui_muri(nodi('det_bocchetta_rettangolare'), 'muri', 10, (0.35, 0.5)))
print('elettrico', sui_muri(['det_cassetta_piccola', 'det_cassetta_aperta', 'det_interruttore_stagno'], 'muri', 30, (1.3, 2.2)))
print('quadri', sui_muri(['det_quadro_elettrico'], 'muri', 4, 1.4))
print('cartelli', sui_muri(nodi('det_cartello'), 'muri', 40, (1.6, 1.9)))
print('applique', sui_muri(['det_applique_emergenza_spenta', 'det_applique_emergenza_rotta'], 'muri', 14, (2.6, 3.0)))
print('fari', sui_muri(nodi('det_faro'), 'muri', 8, (3.3, 3.7)))
print('macchie muro', sui_muri(['det_macchia_calcare_muro', 'det_macchia_muffa_muro'], 'muri', 50, (0.35, 1.2)))
print('incrostazioni', sui_muri(nodi('det_incrostazione_spigolo'), 'base dei muri', 40, 0.03, base=True))

# ------------------------------------------------------------------ 3) soffitto della galleria (fascia di 3 m lungo i muri, a ~4 m)
def sotto_galleria(lista, zona, n, **k):
    def f():
        lato = random.choice('nseo')
        x, y = punto_interno(lato, random.uniform(0.6, 2.6))
        yaw = {'n': 0, 's': 0, 'e': math.pi / 2, 'o': math.pi / 2}[lato] + random.choice((0, math.pi))
        return al_soffitto(random.choice(lista), x, y, zona, yaw=yaw if CAT[lista[0]]['ingombro_m'][0] > 1.5 else None, **k)
    return tenta(n, f)


print('cavi pendenti', sotto_galleria(nodi('det_cavo_pendente'), 'sotto la galleria', 50))
print('festoni', sotto_galleria(nodi('det_cavo_festone') + ['det_fascio_cavi_4m'], 'sotto la galleria', 40, libero_sotto=1.1))
print('catene', sotto_galleria(nodi('det_catena_pendente') + nodi('det_corda_pendente'), 'sotto la galleria', 30))
print('neon', sotto_galleria(['det_neon_soffitto_spento', 'det_neon_senza_diffusore', 'det_neon_penzolante'], 'sotto la galleria', 30, libero_sotto=0.6))

# ------------------------------------------------------------------ scrittura (coordinate Godot)
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))    # Blender -> Godot
uscita = []
for p in POSTI:
    G = C @ p['matrice_blender'] @ C.inverted()
    b = G.to_3x3(); o = G.translation
    yaw = math.degrees(math.atan2(-b[2][0], b[0][0])) if abs(b[1][1] - 1) < 1e-4 else None
    uscita.append({'nodo': p['nodo'], 'glb': p['glb'], 'zona': p['zona'],
                   'posizione': [round(v, 3) for v in o],
                   'rotazione_y_gradi': round(yaw, 1) if yaw is not None else None,
                   'basis': [[round(b[r][c], 4) for r in range(3)] for c in range(3)]})
conta = {}
for u in uscita:
    conta[u['zona']] = conta.get(u['zona'], 0) + 1
with open(os.path.join(DET, 'posizionamento.json'), 'w') as f:
    json.dump({'nota': "Posti suggeriti per i dettagli nella sala principale, trovati con raycast sui GLB della sala. "
                       "Coordinate Godot (Y in alto), stessa origine della sala. 'basis' = colonne x, y, z della Basis. "
                       "Per ogni voce: istanziare il GLB, prendere il nodo 'nodo', e dargli Transform3D(basis, posizione).",
               'quanti': len(uscita), 'per_zona': conta, 'posti': uscita}, f, indent=1, ensure_ascii=False)
print('posti scritti:', len(uscita), conta)

# ------------------------------------------------------------------ render di controllo
if '--render' in ARGS or '--anteprima' in ARGS:
    for f in ('sala_cupola', 'sala_acqua'):
        bpy.ops.import_scene.gltf(filepath=os.path.join(SALA, f + '.glb'))
    for o in list(bpy.data.objects):
        if 'colonly' in o.name:
            o.hide_render = True
    prima = set(bpy.data.objects)
    for f in sorted(os.listdir(os.path.join(DET, 'glb'))):
        bpy.ops.import_scene.gltf(filepath=os.path.join(DET, 'glb', f))
    KIT = {o.name: o for o in bpy.data.objects if o not in prima and o.name.startswith('det_')}
    for o in KIT.values():
        o.hide_render = True
    for p in POSTI:
        src = KIT[p['nodo']]
        o = src.copy(); o.data = src.data; bpy.context.scene.collection.objects.link(o)
        o.hide_render = False; o.matrix_basis = p['matrice_blender']
    # luci della sala (posizioni da sala_dati.json)
    for l in DATI['luci']:
        if 'blender' not in l:
            continue
        pos = Vector(l['blender']); col = l['colore']
        if 'neon' in l['nome']:
            luce(l['nome'], 'AREA', pos, 40 if 'piena' in l.get('intensita', '') else 15, col, size=1.2)
        elif 'emergenza' in l['nome']:
            luce(l['nome'], 'POINT', pos, 35, col, raggio=0.1)
        elif 'luna' in l['nome']:
            s = luce(l['nome'], 'SUN', (0, 0, 30), 0.25, col, rot=(math.radians(15), math.radians(10), 0))
        elif 'blender' in l:
            luce(l['nome'], 'POINT', pos, 60, col, raggio=0.15)
    mondo((0.003, 0.004, 0.007))
    volume('nebbia', (0, 6, 5), (42, 38, 12), 0.008, (0.85, 0.88, 0.92), 0.4)
    ant = '--anteprima' in ARGS
    imposta_render(campioni=16 if ant else 160, w=800 if ant else 1600, h=450 if ant else 900, esposizione=0.6)
    for nome, cam in (('panoramica', DATI['camere']['panoramica']), ('S04_statua', DATI['camere']['S04_statua'])):
        camera(cam['pos_blender'], cam['guarda_blender'], lente=cam['lente_mm'], nome=nome)
        renderizza(f'dettagli_sala_{nome}' + ('_anteprima' if ant else '') + '.jpg')
