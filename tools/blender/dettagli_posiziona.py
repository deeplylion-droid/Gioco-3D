"""Posizionamento suggerito del kit di dettagli nella sala principale.

Importa i GLB della sala (assets_src/ambiente/glb/sala/) e trova i posti con dei raggi (raycast) sulla geometria
vera: pavimento libero, muri piatti senza oblò e porte, soffitto della galleria, bordi delle vasche, fondo
della piscina. Scrive assets_src/ambiente_dettagli/posizionamento.json con le trasformazioni in coordinate Godot.

Uso: /home/user/tools/blender-venv/bin/python tools/blender/dettagli_posiziona.py
I dettagli sono messi a GRUPPI (mucchi negli angoli e alla base dei muri, corse di tubi e di cavi lungo muri e galleria,
incrostazioni lungo la base delle pareti e i bordi della piscina, lampade e cavi che pendono sotto la galleria).
Il percorso dallo spawn al monumento e il cono di vista sulla statua restano liberi.
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
for f in ('sala_architettura', 'sala_piscina', 'sala_area_bimbi', 'sala_torre_scivoli', 'sala_oggetti', 'sala_interattivi', 'sala_monumento'):
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


# ------------------------------------------------------------------ zone libere
MON = Vector(DATI['piedistallo']['centro_blender'][:2]); R_MON = DATI['piedistallo']['raggio_cordone'] + 0.4
SPAWN = Vector(DATI['spawn_ingresso']['blender'][:2])
LAMP = Vector(DATI['lampione']['base_blender'][:2])


def nel_corridoio(p, largo=1.9):
    """Percorso spawn -> monumento (per terra)."""
    return abs(p.x) < largo and SPAWN.y - 1 <= p.y <= MON.y


def nel_cono(p):
    """Cono di vista dallo spawn alla statua (per le cose appese): si allarga verso la statua."""
    if not (SPAWN.y - 1 <= p.y <= MON.y + 1.5):
        return False
    t = (p.y - SPAWN.y) / (MON.y - SPAWN.y)
    return abs(p.x) < 2.0 + 2.2 * max(t, 0)


occupati = []      # per terra (centro 2D, raggio)
occupati_muro = []  # muri e soffitto (centro 3D, raggio)


def libero(p, r, appeso=False):
    q = Vector(p[:2])
    if (q - MON).length < R_MON + r or (q - LAMP).length < 0.8 + r:
        return False
    if nel_corridoio(q) or (appeso and nel_cono(q)):
        return False
    return all((q - c).length > r + rc for c, rc in occupati)


def spazio_intorno(p, r, h=0.25):
    for k in range(8):
        a = k * math.pi / 4
        if raggio(Vector(p) + Vector((0, 0, h)), (math.cos(a), math.sin(a), 0), r):
            return False
    return True


POSTI = []


def aggiungi(nodo, M, zona, gruppo):
    POSTI.append({'nodo': nodo, 'glb': CAT[nodo]['glb'], 'zona': zona, 'gruppo': gruppo, 'matrice_blender': M})


def sul_pavimento(nodo, x, y, zona, gruppo, r=0.3, z_atteso=(-0.06, 0.08), controlla_intorno=False, yaw=None):
    hit = raggio((x, y, 3.0), (0, 0, -1), 8)
    if not hit:
        return False
    p, n = hit[0], hit[1]
    if n.z < 0.95 or not (z_atteso[0] <= p.z <= z_atteso[1]):
        return False
    if not libero(p, r) or (controlla_intorno and not spazio_intorno(p, r)):
        return False
    M = Matrix.Translation(p + Vector((0, 0, 0.001))) @ Matrix.Rotation(random.uniform(0, 2 * math.pi) if yaw is None else yaw, 4, 'Z')
    aggiungi(nodo, M, zona, gruppo); occupati.append((Vector(p[:2]), r))
    return True


LUNGHI = {k for k, v in CAT.items() if v['ingombro_m'][0] > 1.5 or 'incrostazione' in k or 'festone' in k or 'fascio' in k}


def sul_muro(nodo, p_interno, direzione, z, zona, gruppo, r=None, base=False):
    info = CAT[nodo]
    w = max(info['ingombro_m'][0], 0.2); h = max(info['ingombro_m'][2], 0.2)
    hit = raggio(Vector((p_interno[0], p_interno[1], z)), direzione, 12)
    if not hit:
        return False
    p, n = hit[0], hit[1]
    if abs(n.z) > 0.1:
        return False
    t = Vector((-n.y, n.x, 0)).normalized()
    t = Matrix.Rotation(math.atan2(n.x, -n.y), 3, 'Z') @ Vector((1, 0, 0))   # +X locale del dettaglio
    xo = 0.5 if nodo in LUNGHI else 0.0
    for sx, sz in ((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5), (0, 0)):
        if base:
            sz = (sz + 0.5) * 0.9 + 0.05
        q = p + n * 0.3 + t * ((sx + xo) * w) + Vector((0, 0, sz * h))
        hh = raggio(q, -n, 0.6)
        if not hh or abs((hh[0] - q).length - 0.3) > (0.08 if base else 0.03) or hh[1].dot(n) < 0.95:
            return False
    c = p + t * (xo * w)
    if not libero(c, 0.0, appeso=True) and z > 2.0:
        return False
    if (Vector(c[:2]) - MON).length < R_MON or nel_corridoio(Vector(c[:2]), 1.2):
        return False
    rr = r if r is not None else max(w, h) / 2
    if not all((c - q2).length > rr + rq for q2, rq in occupati_muro):
        return False
    M = Matrix.Translation(p) @ Matrix.Rotation(math.atan2(n.x, -n.y), 4, 'Z')
    aggiungi(nodo, M, zona, gruppo); occupati_muro.append((c, rr))
    return M


def al_soffitto(nodo, x, y, zona, gruppo, yaw=None, libero_sotto=None, z_min=3.4, z_max=4.6, r=0.5):
    hit = raggio((x, y, 2.2), (0, 0, 1), 4)
    if not hit:
        return False
    p, n = hit[0], hit[1]
    if n.z > -0.95 or not (z_min <= p.z <= z_max) or not libero(p, 0.0, appeso=True):
        return False
    L = libero_sotto if libero_sotto is not None else CAT[nodo]['ingombro_m'][2]
    if raggio(p - Vector((0, 0, 0.02)), (0, 0, -1), L + 0.3):
        return False
    yaw = random.uniform(0, 2 * math.pi) if yaw is None else yaw
    d = Vector((math.cos(yaw), math.sin(yaw), 0))
    if nodo in LUNGHI:
        e = p + d * CAT[nodo]['ingombro_m'][0]
        h2 = raggio(e - Vector((0, 0, 0.3)), (0, 0, 1), 1)
        if not h2 or abs(h2[0].z - p.z) > 0.05 or not libero(e, 0.0, appeso=True):
            return False
    c = p + d * (CAT[nodo]['ingombro_m'][0] / 2 if nodo in LUNGHI else 0)
    if not all((c - q).length > r + rq for q, rq in occupati_muro):
        return False
    M = Matrix.Translation(p) @ Matrix.Rotation(yaw, 4, 'Z')
    aggiungi(nodo, M, zona, gruppo); occupati_muro.append((c, r))
    return M


def nodi(prefisso):
    return [k for k in CAT if k.startswith(prefisso)]


GIOCATTOLI = ['det_paperella', 'det_secchiello', 'det_paletta', 'det_barchetta', 'det_pistola_acqua', 'det_pesce_gomma', 'det_maschera_sub', 'det_ciabatta']
PICCOLI = nodi('det_piastrella_rotta') + nodi('det_foglio') + nodi('det_carta_accartocciata')
PANNELLI = nodi('det_pannello') + ['det_griglia_caduta']
LATI = {'n': ((0, 1, 0), lambda u, d: (u, Y1 - d)), 's': ((0, -1, 0), lambda u, d: (u, Y0 + d)),
        'e': ((1, 0, 0), lambda u, d: (X1 - d, u)), 'o': ((-1, 0, 0), lambda u, d: (X0 + d, u))}
LUNGH = {'n': (X0, X1), 's': (X0, X1), 'e': (Y0, Y1), 'o': (Y0, Y1)}


def punto_lato(lato, d, u=None):
    a, b = LUNGH[lato]
    u = random.uniform(a + 0.8, b - 0.8) if u is None else u
    return LATI[lato][1](u, d), u


# ================================================================== GRUPPI PER TERRA
gid = [0]


def nuovo_gruppo(nome):
    gid[0] += 1
    return f'{nome}_{gid[0]:03d}'


def mucchio(cx, cy, zona, ricco=True):
    """Mucchio di detriti: un pezzo grosso al centro, tanti piccoli intorno."""
    g = nuovo_gruppo('mucchio')
    grosso = random.choice(nodi('det_mucchio_piastrelle') * 3 + PANNELLI + nodi('det_alghe_secche_mucchio'))
    if not sul_pavimento(grosso, cx, cy, zona, g, r=0.45):
        return 0
    k = 1
    for _ in range(random.randint(5, 11) if ricco else random.randint(2, 5)):
        a = random.uniform(0, 6.28); d = random.uniform(0.5, 1.6)
        nodo = random.choice(PICCOLI * 3 + nodi('det_vetri_rotti') + GIOCATTOLI + PANNELLI + ['det_macchia_calcare_pavimento', 'det_macchia_alghe_secche_pavimento'])
        r = 0.6 if 'macchia' in nodo or 'pannello' in nodo else 0.12
        k += sul_pavimento(nodo, cx + d * math.cos(a), cy + d * math.sin(a), zona, g, r=r)
    return k


conta = {}


def conteggia(nome, n):
    conta[nome] = conta.get(nome, 0) + n


# 1) angoli della sala e base dei muri (dentro di 0,5-1,2 m)
for (cx, cy) in ((X0 + 0.9, Y0 + 0.9), (X1 - 0.9, Y0 + 0.9), (X0 + 0.9, Y1 - 0.9), (X1 - 0.9, Y1 - 0.9)):
    conteggia('angoli', mucchio(cx, cy, 'angolo'))
for _ in range(140):
    lato = random.choice('nseoss')        # piu' gruppi sul lato sud, quello del primo colpo d'occhio
    (x, y), _u = punto_lato(lato, random.uniform(0.6, 1.3))
    conteggia('base dei muri', mucchio(x, y, 'base dei muri'))
# 1b) gli 8 m nuovi vicino al vano sud: il primo colpo d'occhio, ai lati del percorso verso la statua
for _ in range(70):
    lato = random.choice((-1, 1))
    x = lato * random.uniform(2.4, 15.0); y = random.uniform(Y0 + 0.8, MON.y - 1.0)
    conteggia('ingresso (lato sud)', mucchio(x, y, 'ingresso'))
for _ in range(25):
    g = nuovo_gruppo('ingresso_asciugamani')
    x = random.choice((-1, 1)) * random.uniform(2.5, 12); y = random.uniform(Y0 + 1, MON.y - 1)
    if sul_pavimento(random.choice(nodi('det_asciugamano') + PANNELLI), x, y, 'ingresso', g, r=0.6):
        conteggia('ingresso (lato sud)', 1)
        for _ in range(random.randint(1, 3)):
            a = random.uniform(0, 6.28)
            conteggia('ingresso (lato sud)', sul_pavimento(random.choice(GIOCATTOLI + PICCOLI), x + 0.9 * math.cos(a), y + 0.9 * math.sin(a), 'ingresso', g, r=0.15))
# 2) sparsi in sala, ma sempre a gruppetti
for _ in range(95):
    conteggia('gruppetti in sala', mucchio(random.uniform(X0 + 2, X1 - 2), random.uniform(Y0 + 2, Y1 - 2), 'sala', ricco=False))
# 3) asciugamani e giocattoli vicino alle vasche e alle sdraio
for _ in range(60):
    g = nuovo_gruppo('spiaggia')
    x, y = random.uniform(X0 + 2, X1 - 2), random.uniform(Y0 + 2, Y1 - 2)
    if sul_pavimento(random.choice(nodi('det_asciugamano')), x, y, 'sala', g, r=0.6):
        conteggia('asciugamani e giocattoli', 1)
        for _ in range(random.randint(1, 3)):
            a = random.uniform(0, 6.28)
            conteggia('asciugamani e giocattoli', sul_pavimento(random.choice(GIOCATTOLI), x + 0.8 * math.cos(a), y + 0.8 * math.sin(a), 'sala', g, r=0.15))
# 4) bordo della piscina: alghe secche e calcare dove e' arrivata l'acqua, a tratti continui
px0, px1 = PISC['x']; py0, py1 = PISC['y']
for lato in 'nseo':
    a, b = (px0, px1) if lato in 'ns' else (py0, py1)
    u = a
    while u < b:
        lungo = random.uniform(2, 5); g = nuovo_gruppo('bordo_piscina')
        for k in range(int(lungo / 0.7)):
            uu = u + k * 0.7; m = random.uniform(0.45, 0.9)
            x, y = {'n': (uu, py1 + m), 's': (uu, py0 - m), 'e': (px1 + m, uu), 'o': (px0 - m, uu)}[lato]
            nodo = random.choice(['det_macchia_alghe_verdi_pavimento', 'det_macchia_calcare_pavimento', 'det_macchia_alghe_secche_pavimento'] + nodi('det_alghe_secche_mucchio') + nodi('det_piastrella_rotta'))
            conteggia('bordo piscina', sul_pavimento(nodo, x, y, 'bordo piscina', g, r=0.3 if 'piastrella' not in nodo else 0.1))
        u += lungo + random.uniform(1, 3)
# 5) fondo della piscina vuota
for _ in range(30):
    g = nuovo_gruppo('fondo_piscina')
    x, y = random.uniform(px0 + 1, px1 - 1), random.uniform(py0 + 1, py1 - 1)
    for k in range(random.randint(2, 5)):
        a = random.uniform(0, 6.28); d = random.uniform(0, 1.2)
        nodo = random.choice(GIOCATTOLI + nodi('det_alghe_secche_mucchio') + ['det_macchia_alghe_verdi_pavimento', 'det_macchia_calcare_pavimento'] + nodi('det_mucchio_piastrelle') + nodi('det_foglio'))
        conteggia('fondo piscina', sul_pavimento(nodo, x + d * math.cos(a), y + d * math.sin(a), 'fondo piscina', g, r=0.25, z_atteso=(-2.4, -0.3)))

# ================================================================== GRUPPI SUI MURI


def corsa_muro(lista, lato, z, n_max, zona, colature=False, base=False, u=None):
    """Pezzi lunghi (tubi, condotte, incrostazioni) uno dopo l'altro lungo il muro."""
    g = nuovo_gruppo('corsa')
    (x, y), u = punto_lato(lato, 1.0, u)
    nodo = random.choice(lista); L = CAT[nodo]['ingombro_m'][0]
    messi = 0
    for k in range(n_max):
        M = sul_muro(nodo, (x, y), LATI[lato][0], z, zona, g, r=0.45 * L, base=base)
        if not M:
            break
        messi += 1
        if colature:
            for _ in range(random.randint(0, 2)):
                q = M @ Vector((random.uniform(0.2, L - 0.2), 0.0, -0.15))
                aggiungi('det_macchia_ruggine_colata_muro', Matrix.Translation(q) @ M.to_3x3().to_4x4(), 'colatura sotto un tubo', g)
                messi += 1
        t = M.to_3x3() @ Vector((1, 0, 0))
        x, y = x + t.x * L, y + t.y * L
    return messi


for _ in range(26):
    conteggia('corse di tubi', corsa_muro(nodi('det_tubo_muro') + ['det_tubi_paralleli_2m'], random.choice('nseos'), random.uniform(2.9, 3.6), random.randint(2, 6), 'muri, sotto la galleria', colature=True))
for _ in range(10):
    conteggia('condotte', corsa_muro(['det_condotta_aria_4m', 'det_condotta_aria_2m'], random.choice('nseo'), 3.7, random.randint(1, 3), 'muri, sotto la galleria'))
for _ in range(30):
    conteggia('incrostazioni alla base', corsa_muro(nodi('det_incrostazione_spigolo'), random.choice('nseo'), 0.1, random.randint(2, 7), 'base dei muri', base=True))


def gruppo_impianto(lato):
    """Quadro o cassetta, interruttore, tubo che sale, cartello, macchie: un angolo tecnico sul muro."""
    g = nuovo_gruppo('impianto')
    (x, y), u = punto_lato(lato, 1.0)
    M = sul_muro(random.choice(['det_quadro_elettrico', 'det_cassetta_aperta', 'det_cassetta_aperta', 'det_cassetta_piccola']), (x, y), LATI[lato][0], random.uniform(1.4, 1.7), 'muri', g)
    if not M:
        return 0
    n = 1
    t = M.to_3x3() @ Vector((1, 0, 0))
    for nodo, du, z in (('det_interruttore_stagno', 0.8, 1.3), ('det_cassetta_piccola', -0.9, 2.2), (random.choice(nodi('det_cartello')), 1.6, 1.75),
                        ('det_tubo_verticale_3m', -1.4, 0.02), ('det_macchia_muffa_muro', 0.3, 0.5), ('det_macchia_calcare_muro', -0.6, 0.45)):
        if random.random() < 0.75:
            n += bool(sul_muro(nodo, (x + t.x * du, y + t.y * du), LATI[lato][0], z, 'muri', g, base=nodo.startswith('det_tubo_verticale')))
    return n


for _ in range(60):
    conteggia('impianti', gruppo_impianto(random.choice('nseos')))
for _ in range(140):
    lato = random.choice('nseo'); (x, y), u = punto_lato(lato, 1.0); g = nuovo_gruppo('cartelli')
    conteggia('cartelli', bool(sul_muro(random.choice(nodi('det_cartello')), (x, y), LATI[lato][0], random.uniform(1.6, 1.9), 'muri', g)))
for _ in range(40):
    lato = random.choice('nseo'); (x, y), u = punto_lato(lato, 1.0); g = nuovo_gruppo('bocchette')
    conteggia('bocchette', bool(sul_muro(random.choice(nodi('det_bocchetta')), (x, y), LATI[lato][0], random.choice((random.uniform(2.3, 3.2), 0.42)), 'muri', g)))
for _ in range(25):
    lato = random.choice('nseo'); (x, y), u = punto_lato(lato, 1.0); g = nuovo_gruppo('luci_muro')
    conteggia('applique e fari', bool(sul_muro(random.choice(['det_applique_emergenza_spenta', 'det_applique_emergenza_rotta', 'det_faro', 'det_faro_spento']), (x, y), LATI[lato][0], random.uniform(2.7, 3.5), 'muri', g)))
for _ in range(120):
    lato = random.choice('nseo'); (x, y), u = punto_lato(lato, 1.0); g = nuovo_gruppo('macchie')
    conteggia('macchie sui muri', bool(sul_muro(random.choice(['det_macchia_calcare_muro', 'det_macchia_muffa_muro']), (x, y), LATI[lato][0], random.uniform(0.35, 1.0), 'muri', g, r=0.3)))

# ================================================================== SOTTO LA GALLERIA


def fascio_lungo_muro(lato):
    """Festoni di cavi uno dopo l'altro, a 0,4-0,9 m dal muro, sotto la galleria."""
    g = nuovo_gruppo('fascio_cavi')
    d = random.uniform(0.4, 0.9)
    (x, y), u = punto_lato(lato, d)
    yaw = {'n': 0, 's': 0, 'e': math.pi / 2, 'o': math.pi / 2}[lato] + random.choice((0, math.pi))
    nodo = random.choice(nodi('det_cavo_festone') + ['det_fascio_cavi_4m', 'det_fascio_cavi_4m'])
    L = CAT[nodo]['ingombro_m'][0]
    messi = 0
    for k in range(random.randint(2, 6)):
        if not al_soffitto(nodo, x, y, 'sotto la galleria', g, yaw=yaw, libero_sotto=1.1, r=0.3):
            break
        messi += 1
        x, y = x + math.cos(yaw) * L, y + math.sin(yaw) * L
    return messi


def lampada_che_pende(lato):
    """Una plafoniera (spenta, rotta o penzolante) con cavi e catene intorno."""
    g = nuovo_gruppo('lampada_pendente')
    (x, y), u = punto_lato(lato, random.uniform(1.0, 2.4))
    yaw = {'n': 0, 's': 0, 'e': math.pi / 2, 'o': math.pi / 2}[lato]
    if not al_soffitto(random.choice(['det_neon_soffitto_spento', 'det_neon_senza_diffusore', 'det_neon_penzolante', 'det_neon_penzolante']), x, y, 'sotto la galleria', g, yaw=yaw, libero_sotto=0.7, r=0.8):
        return 0
    n = 1
    for _ in range(random.randint(1, 3)):
        a = random.uniform(0, 6.28); dd = random.uniform(0.5, 1.2)
        n += bool(al_soffitto(random.choice(nodi('det_cavo_pendente') * 2 + nodi('det_catena_pendente') + nodi('det_corda_pendente')),
                              x + dd * math.cos(a), y + dd * math.sin(a), 'sotto la galleria', g, r=0.25))
    # sotto: vetri della plafoniera
    if random.random() < 0.6:
        n += sul_pavimento(random.choice(nodi('det_vetri_rotti')), x, y, 'sotto le lampade', g, r=0.4)
    return n


for _ in range(40):
    # sotto la galleria sud e lungo i lati vicino all'ingresso: lampade e cavi che pendono (fuori dal cono della statua)
    x = random.choice((-1, 1)) * random.uniform(3.0, 18.5); y = random.uniform(Y0 + 0.5, Y0 + 9)
    g = nuovo_gruppo('ingresso_appesi')
    conteggia('ingresso appesi', bool(al_soffitto(random.choice(nodi('det_cavo_pendente') * 3 + nodi('det_catena_pendente') + ['det_neon_penzolante', 'det_neon_senza_diffusore']),
                                                x, y, 'sotto la galleria', g, r=0.4, libero_sotto=1.0)))
for _ in range(100):
    conteggia('fasci di cavi', fascio_lungo_muro(random.choice('nseos')))
for _ in range(60):
    conteggia('lampade che pendono', lampada_che_pende(random.choice('nseos')))
for _ in range(50):
    lato = random.choice('nseo'); (x, y), u = punto_lato(lato, random.uniform(0.7, 2.6)); g = nuovo_gruppo('appesi')
    conteggia('cavi e catene', bool(al_soffitto(random.choice(nodi('det_cavo_pendente') + nodi('det_catena_pendente')), x, y, 'sotto la galleria', g, r=0.3)))

# ------------------------------------------------------------------ scrittura (coordinate Godot) e riepilogo
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))    # Blender -> Godot
uscita = []
# asciugamani piegati (0,7 x 1,4 m piegato in quattro): pianta circa 0,38 x 0,71 m, un po' più spessi
PIEGA = {'det_asciugamano': (0.42, 3.0, 0.75)}     # scala delle colonne x, y, z (Godot) della Basis
for p in POSTI:
    G = C @ p['matrice_blender'] @ C.inverted()
    b = G.to_3x3(); o = G.translation
    for pref, k in PIEGA.items():
        if p['nodo'].startswith(pref):
            for c_ in range(3):
                for r_ in range(3):
                    b[r_][c_] *= k[c_]
    yaw = math.degrees(math.atan2(-b[2][0], b[0][0])) if abs(b[1][1] - 1) < 1e-4 else None
    uscita.append({'nodo': p['nodo'], 'glb': p['glb'], 'zona': p['zona'], 'gruppo': p['gruppo'],
                   'posizione': [round(v, 3) for v in o], 'rotazione_y_gradi': round(yaw, 1) if yaw is not None else None,
                   'basis': [[round(b[r][c], 4) for r in range(3)] for c in range(3)]})
per_nodo = {}
for u in uscita:
    per_nodo[u['nodo']] = per_nodo.get(u['nodo'], 0) + 1
tri = sum(CAT[n]['triangoli'] * k for n, k in per_nodo.items())
SOGLIA_MM = 6
riepilogo = {'posti': len(uscita), 'gruppi': len({u['gruppo'] for u in uscita}), 'nodi_diversi': len(per_nodo),
             'triangoli_totali': tri,
             'multimesh': {'soglia_istanze': SOGLIA_MM, 'nodi_in_multimesh': sum(1 for k in per_nodo.values() if k >= SOGLIA_MM),
                           'istanze_in_multimesh': sum(k for k in per_nodo.values() if k >= SOGLIA_MM),
                           'istanze_singole': sum(k for k in per_nodo.values() if k < SOGLIA_MM)},
             'per_gruppo': conta, 'per_nodo': dict(sorted(per_nodo.items(), key=lambda kv: -kv[1]))}
with open(os.path.join(DET, 'posizionamento.json'), 'w') as f:
    json.dump({'nota': "Posti per i dettagli nella sala principale (sala lunga, con il monumento), trovati con raycast sui GLB della sala. "
                       "Coordinate Godot (Y in alto), stessa origine della sala. 'basis' = colonne x, y, z della Basis. "
                       "Per montarli: godot/dettagli_sala.gd (MultiMeshInstance3D per i nodi ripetuti).",
               'riepilogo': riepilogo, 'posti': uscita}, f, indent=1, ensure_ascii=False)
print('RIEPILOGO', json.dumps({k: v for k, v in riepilogo.items() if k != 'per_nodo'}, ensure_ascii=False))
