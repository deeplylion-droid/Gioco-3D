"""Scrive godot/scenes/sala/enigma_acquari.tscn con i modelli veri (stile B, posizione 2, miscuglio basso,
lampadine da luna park: scelte dell'utente del 18 ottobre) dentro i nodi di enigma-logica, senza
cambiarne i nomi. Le misure sono quelle della proposta (godot/proposte/acquari/proposta_acquari.gd).
Uso: python3 assets_src/enigma_acquari/genera_scena.py"""
import math, os

QUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(QUI, '..', '..', 'godot', 'scenes', 'sala', 'enigma_acquari.tscn')

ROT = '-4.371139e-08, 0, -1, 0, 1, 0, 1, 0, -4.371139e-08'   # -90 gradi attorno a Y: il davanti (+Z) guarda a ovest
ID = '1, 0, 0, 0, 1, 0, 0, 0, 1'


def tr(basis, p):
    return 'Transform3D(%s, %s)' % (basis, ', '.join('%.6g' % round(v, 4) for v in p))


def roty(a):
    c, s = math.cos(a), math.sin(a)
    return '%.6g, 0, %.6g, 0, 1, 0, %.6g, 0, %.6g' % (c, s, -s, c)


ext = [
    ('Script', 'res://scripts/game/enigma_acquari.gd', 'enigma'),
    ('Script', 'res://scripts/mechanisms/water_tank.gd', 'tank'),
    ('Script', 'res://scripts/water/water_hitbox.gd', 'hitbox'),
    ('PackedScene', 'res://assets/enigma_acquari/cilindro_base.glb', 'base'),
    ('PackedScene', 'res://assets/enigma_acquari/cilindro_base_bassa.glb', 'base_bassa'),
    ('PackedScene', 'res://assets/enigma_acquari/cilindro_coperchio.glb', 'coperchio'),
    ('PackedScene', 'res://assets/enigma_acquari/valvola_rossa.glb', 'valvola'),
    ('PackedScene', 'res://addons/acqua/scenes/acqua_per_vasca.tscn', 'acqua'),
    ('Script', 'res://assets/enigma_acquari/acquario_vetro.gd', 'vetro'),
    ('Script', 'res://assets/enigma_acquari/acquari_gorgo.gd', 'gorgo'),
    ('Script', 'res://assets/enigma_acquari/lampada_valvola.gd', 'lampada_valvola'),
    ('PackedScene', 'res://assets/enigma_acquari/lampada_gabbia.glb', 'gabbia'),
    ('Material', 'res://assets/materials/sala/metallo_verniciato.tres', 'm_tiranti'),
    ('Material', 'res://assets/enigma_acquari/metallo_rosso.tres', 'm_rosso'),
    ('Material', 'res://assets/enigma_acquari/metallo_giallo.tres', 'm_giallo'),
    ('Material', 'res://assets/enigma_acquari/griglia_scarico.tres', 'm_griglia'),
    ('ArrayMesh', 'res://assets/enigma_acquari/disegno_curvo.res', 'disegno'),
    ('MultiMesh', 'res://assets/enigma_acquari/portalampade_portone.res', 'mm_porta'),
    ('MultiMesh', 'res://assets/enigma_acquari/lampadine_spente.res', 'mm_spente'),
    ('MultiMesh', 'res://assets/enigma_acquari/lampadine_accese.res', 'mm_accese'),
]
L = ['[gd_scene format=3]', '']
for t, p, i in ext:
    L.append('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i))
L.append('')
sub = []


def sr(tipo, sid, **kw):
    sub.append('[sub_resource type="%s" id="%s"]' % (tipo, sid))
    for k, v in kw.items():
        sub.append('%s = %s' % (k, v))
    sub.append('')


# Scala delle cisterne (prova dell'utente del 19 ottobre: "vanno ingrandite del doppio, tutta la
# struttura"). K vale per i due acquari alti, KX e KY per il miscuglio (in larghezza e in altezza).
# Le quantità di gioco non cambiano: i litri restano 80 e 62, cioè due zainate di giallo e una di blu.
K = float(os.environ.get('ACQUARI_K', '2'))
KX = float(os.environ.get('ACQUARI_KX', str(K)))
KY = float(os.environ.get('ACQUARI_KY', str(K)))   # tutto doppio, anche il miscuglio (scelta A: con la pedana)
KV = float(os.environ.get('ACQUARI_KV', str(K)))   # la valvola
B_BASE, B_VETRO = 0.849 * K, 1.3 * K
SC, R_B, B_BASSO_BASE, B_BASSO_VETRO = 1.45, 0.55 * 1.45 * KX, 0.40 * KY, 0.38 * KY


# le luci: con spot_attenuation 0,8 a distanza doppia arriva 2^-0,8 della luce, e si compensa
LK, LKM = K ** 0.8, max(KX, KY) ** 0.8
# La fila davanti al portone della torre (richiesta dell'utente del 21 ottobre, posizione P1): lungo il
# muro nord della sala, a sinistra del viale che porta al portone, tutti girati verso sud (il davanti +Z
# dei modelli guarda il viale). Da est: giallo, miscuglio con la pedana, blu, a PASSO l'uno dall'altro
# (gli spazi della proposta approvata: i tubi delle basi arrivano fin quasi a toccarsi). Il miscuglio
# sta un poco più avanti. Il viale (z da -18,65 a -11,35) e la corsa del portone restano liberi.
XG = 16.9                     # il giallo: i suoi tubi arrivano a x 19,2, prima della cornice del portone
ZA = -22.3                    # gli alti: la base arriva a 0,3 m dal muro nord (z -24)
PASSO = (1.3 * K + 1.9 * KX) * 0.5 + 1.2 * K
XM = XG - PASSO
ZMI = ZA + 0.35 * KX          # il miscuglio, un poco più avanti
XB = XG - 2 * PASSO
# la pedana davanti al miscuglio: il piano a 0,9 m, il vetro arriva a 0,66 m sopra il piano; i gradini
# (5 da 18 cm) scendono verso est
PEDANA_H = 0.9
PEDANA_Z0, PEDANA_Z1 = -19.75, -18.75
PEDANA_X0, PEDANA_X1 = XM - 1.2, XM + 1.2
GRADINI, ALZ, PED = 5, PEDANA_H / 5, 0.28

# Le altre due posizioni proposte all'utente (21 ottobre, in attesa di risposta), con ACQUARI_POSIZIONE:
# P2 giallo e blu ai due lati del portone come colonne d'ingresso, il miscuglio con la pedana dov'è nel P1;
# P3 una fila parallela al muro 9 m davanti al portone, girata verso ovest, con un varco di 6,3 m in
# mezzo allineato al portone: il giallo a nord del varco, il miscuglio con la pedana e il blu a sud.
# Tutto si disegna nel P1 e poi ogni gruppo (G il giallo col disegno, M il miscuglio con la pedana, la
# barriera e la valvola, B il blu) si sposta intero: (dove va il suo centro, rotazione attorno a Y).
POSIZIONE = os.environ.get('ACQUARI_POSIZIONE', 'P1')
ANCORE = {'G': (XG, ZA), 'M': (XM, ZMI), 'B': (XB, ZA)}
DISPOSIZIONI = {
    'P1': {},
    'P2': {'G': ((XG, -20.5), 0.0), 'B': ((XG, -9.5), math.pi)},
    'P3': {'G': ((10.6, -20.5), -math.pi / 2), 'M': ((10.6 - 0.35 * KX, -8.4), -math.pi / 2), 'B': ((10.6, -8.4 + PASSO), -math.pi / 2)},
}
DISP = DISPOSIZIONI[POSIZIONE]


def _righe(b):
    v = [float(c) for c in b.split(',')]
    return [v[0:3], v[3:6], v[6:9]]


def sposta(g, x, z):
    """Un punto (x, z) del P1 nel gruppo g, nella posizione scelta."""
    if g not in DISP:
        return x, z
    (nx, nz), a = DISP[g]
    ax, az = ANCORE[g]
    c, s = math.cos(a), math.sin(a)
    dx, dz = x - ax, z - az
    return nx + c * dx + s * dz, nz - s * dx + c * dz


def piazza(g, basis, p):
    """tr() per un nodo di primo livello del gruppo g, disegnato nel P1."""
    if g not in DISP:
        return tr(basis, p)
    a = DISP[g][1]
    c, s = math.cos(a), math.sin(a)
    R = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    M = _righe(basis)
    RM = [[sum(R[i][k] * M[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    x, z = sposta(g, p[0], p[2])
    return tr(', '.join('%.6g' % round(v, 6) for r in RM for v in r), (x, p[1], z))


def sc3(x, y, z):
    return '%g, 0, 0, 0, %g, 0, 0, 0, %g' % (x, y, z)


def rot_sc(k):
    """ROT (-90 gradi attorno a Y) con la scala k."""
    return '%g, 0, %g, 0, %g, 0, %g, 0, %g' % (-4.371139e-08 * k, -k, k, k, -4.371139e-08 * k)
sr('CylinderMesh', 'tirante', top_radius='%.3f' % (0.022 * K), bottom_radius='%.3f' % (0.022 * K), height='%.3f' % (B_VETRO + 0.2 * K), radial_segments='12')
sr('CylinderShape3D', 'forma_alto', radius='%.3f' % (0.5 * K), height='%.3f' % (2.95 * K))
sr('TorusMesh', 'anello', inner_radius='%.4f' % (R_B - 0.025 * KX), outer_radius='%.4f' % (R_B + 0.045 * KX), rings='64')
sr('CylinderShape3D', 'forma_base_bassa', radius='%.3f' % (R_B + 0.02 * KX), height='%.3f' % B_BASSO_BASE)
sr('BoxShape3D', 'forma_parete', size='Vector3(%.3f, %.3f, %.3f)' % (0.45 * KX, 0.4 * KY, 0.06 * KX))
sr('BoxShape3D', 'forma_valvola', size='Vector3(%.3f, %.3f, %.3f)' % (0.77 * KV, 0.3 * KV, 0.3 * KV))   # solo il tubo: il volantino resta libero per il getto
sr('BoxShape3D', 'forma_barriera', size='Vector3(%.3f, 1.4, 0.06)' % (0.45 * KX))
sr('SphereShape3D', 'forma_bersaglio', radius='%.3f' % (0.3 * KV))
sr('CylinderMesh', 'griglia', top_radius='%.3f' % (0.26 * KV), bottom_radius='%.3f' % (0.26 * KV), height='0.01')
sr('StandardMaterial3D', 'nero', albedo_color='Color(0.01, 0.01, 0.01, 1)')
sr('CylinderMesh', 'buco', top_radius='%.3f' % (0.24 * KV), bottom_radius='%.3f' % (0.24 * KV), height='0.004', material='SubResource("nero")')
X, Z0, Z1, YT, YB = 19.645, -18.45, -11.55, 5.5, 0.9
# la cornice di lampadine appoggiata (prova del 19 ottobre, ambienti-2 8440b03): i montanti arrivano a
# terra con le piastre, la traversa è legata al muro con 4 staffe sopra il binario, tutto 4 cm più avanti
sr('BoxMesh', 'guida_lato_terra', size='Vector3(0.05, %.2f, 0.09)' % (YT + 0.06))
sr('BoxMesh', 'piastra_terra', size='Vector3(0.12, 0.012, 0.14)')
sr('BoxMesh', 'staffa_muro', size='Vector3(0.363, 0.05, 0.05)')
sr('BoxMesh', 'piastra_muro', size='Vector3(0.012, 0.12, 0.1)')
sr('BoxMesh', 'guida_sopra', size='Vector3(0.05, 0.09, %.3f)' % (Z1 - Z0 + 0.09))
L += sub
tardi = []


def sr_tardi(tipo, sid, **kw):
    tardi.append('[sub_resource type="%s" id="%s"]' % (tipo, sid))
    for k, v in kw.items():
        tardi.append('%s = %s' % (k, v))
    tardi.append('')


N = []


def node(name, typ=None, parent=None, inst=None, **props):
    h = '[node name="%s"' % name
    if typ:
        h += ' type="%s"' % typ
    if parent is not None:
        h += ' parent="%s"' % parent
    if 'node_paths' in props:
        h += ' node_paths=%s' % props.pop('node_paths')
    if inst:
        h += ' instance=ExtResource("%s")' % inst
    N.append(h + ']')
    for k, v in props.items():
        N.append('%s = %s' % (k, v))
    N.append('')


node('EnigmaAcquari', 'Node3D', script='ExtResource("enigma")')


# I raccordi sporgenti delle basi (pompa a un lato, tubo all'altro), misurati sul GLB (x, z di Godot,
# altezza dal fondo della base): a scala 2 sono alti fino al petto e senza collisione ci si passerebbe
# dentro. Nel basso arrivano fino in cima alla base.
RACCORDI = {'Pompa': ((-1.156, -0.721), (-0.184, 0.236), (0.214, 0.809)),
            'Tubo': ((0.72, 1.138), (-0.194, 0.0), (0.196, 0.849))}
RACCORDI_BASSO = {'Pompa': ((-1.156, -0.721), (-0.183, 0.236), (0.214, 0.4)),
                  'Tubo': ((0.81, 1.129), (-0.184, -0.008), (0.196, 0.4))}

def raccordi(nome, sx, sy, sz, y0, basso=False):
    for k, ((x0, x1), (z0, z1), (h0, h1)) in (RACCORDI_BASSO if basso else RACCORDI).items():
        sid = 'raccordo_%s_%s' % (nome, k)
        sr_tardi('BoxShape3D', sid, size='Vector3(%.3f, %.3f, %.3f)' % ((x1 - x0) * sx, (h1 - h0) * sy, (z1 - z0) * sz))
        node(k, 'CollisionShape3D', nome + '/Collisione',
             transform=tr(ID, ((x0 + x1) * 0.5 * sx, y0 + (h0 + h1) * 0.5 * sy, (z0 + z1) * 0.5 * sz)),
             shape='SubResource("%s")' % sid)


def acquario(nome, gruppo, pos, alto, pigmento=None):
    p = dict(transform=piazza(gruppo, ID, pos), script='ExtResource("tank")', build_walls='false')
    if alto:
        p.update(inner_size='Vector3(%.3f, %.3f, %.3f)' % (1.1 * K, B_VETRO, 1.1 * K), fill='0.94', capacity_liters='80.0',
                 fill_pigment='"%s"' % pigmento, min_fill='0.2')
    else:
        d = 2 * R_B
        p.update(inner_size='Vector3(%.3f, %.3f, %.3f)' % (d, B_BASSO_VETRO, d), capacity_liters='62.0',
                 suckable='false')
    node(nome, 'Node3D', '.', **p)
    if alto:
        node('Base', parent=nome, inst='base', transform=tr(sc3(K, K, K), (0, -B_BASE, 0)))
        node('Coperchio', parent=nome, inst='coperchio', transform=tr(sc3(K, K, K), (0, B_VETRO, 0)))
        for k in range(4):
            a = math.radians(45 + 90 * k)
            node('Tirante%d' % (k + 1), 'MeshInstance3D', nome, transform=tr(ID, (math.cos(a) * 0.6 * K, B_VETRO * 0.5, math.sin(a) * 0.6 * K)),
                 mesh='SubResource("tirante")', material_override='ExtResource("m_tiranti")')
        node('Collisione', 'StaticBody3D', nome, collision_mask='0')
        node('Forma', 'CollisionShape3D', nome + '/Collisione', transform=tr(ID, (0, -B_BASE + 1.475 * K, 0)), shape='SubResource("forma_alto")')
        raccordi(nome, K, K, K, -B_BASE)
    else:
        node('Base', parent=nome, inst='base_bassa', transform=tr(sc3(SC * KX, KY, SC * KX), (0, -B_BASSO_BASE, 0)))
        node('Anello', 'MeshInstance3D', nome, transform=tr(sc3(1, 0.6 * KY / KX, 1), (0, B_BASSO_VETRO + 0.006 * KY, 0)),
             mesh='SubResource("anello")', material_override='ExtResource("m_rosso")')
        node('Collisione', 'StaticBody3D', nome, collision_mask='0')
        node('Base', 'CollisionShape3D', nome + '/Collisione', transform=tr(ID, (0, -B_BASSO_BASE * 0.5, 0)), shape='SubResource("forma_base_bassa")')
        raccordi(nome, SC * KX, KY, SC * KX, -B_BASSO_BASE, basso=True)
        # il vetro: dodici pareti in tondo, aperto sopra (il getto ci deve entrare)
        for k in range(12):
            a = 2 * math.pi * k / 12
            node('Parete%d' % (k + 1), 'CollisionShape3D', nome + '/Collisione',
                 transform=tr(roty(-a + math.pi / 2), (math.cos(a) * (R_B + 0.02 * KX), 0.2 * KY, math.sin(a) * (R_B + 0.02 * KX))),
                 shape='SubResource("forma_parete")')
    # la luce di servizio, come nella proposta approvata: dentro gli alti sotto il coperchio, sopra il
    # basso (debole e corta: arriva all'acqua ma non al pavimento)
    if alto:
        node('LuceAcquario', 'SpotLight3D', nome, transform=tr('1, 0, 0, 0, 0, 1, 0, -1, 0', (0, B_VETRO - 0.05 * K, 0)),
             light_color='Color(1, 0.95, 0.86, 1)', light_energy='%.2f' % (4.0 * LK), light_volumetric_fog_energy='0.4',
             spot_range='%.2f' % (1.9 * K), spot_attenuation='0.8', spot_angle='75.0')   # non arriva al pavimento
    else:
        # dal lato lontano da chi arriva (-Z locale, verso il muro nord), inclinata verso il centro: il
        # riflesso sul pelo lo vede chi sale sulla pedana
        node('LuceAcquario', 'SpotLight3D', nome, transform=tr('1, 0, 0, 0, -0.573576, 0.819152, 0, -0.819152, -0.573576', (0, 1.25 * KY, -0.75 * KX)),
             light_color='Color(1, 0.95, 0.86, 1)', light_energy='%.2f' % (2.0 * LKM), light_volumetric_fog_energy='0.0',
             spot_range='%.2f' % (1.7 * max(KX, KY)), spot_attenuation='0.8', spot_angle='55.0')
    # cubemap propria per i riflessi solo nel basso, che si guarda da sopra (negli alti il pelo non si vede)
    node('Acqua', parent=nome, inst='acqua', node_paths='PackedStringArray("tank")', tank='NodePath("..")',
         capture_env_cubemap='true' if not alto else 'false', ripple_max_resolution='128')
    node('Vetro', 'Node3D', nome, node_paths='PackedStringArray("acqua")', script='ExtResource("vetro")', acqua='NodePath("../Acqua")')


acquario('AcquarioGiallo', 'G', (XG, B_BASE, ZA), True, 'giallo')
acquario('AcquarioMisto', 'M', (XM, B_BASSO_BASE, ZMI), False)
acquario('AcquarioBlu', 'B', (XB, B_BASE, ZA), True, 'blu')

# Sopra il bordo del miscuglio un muro invisibile (livello "barriere", 256: ferma il giocatore ma non il
# getto) perché dalla pedana non ci si butti dentro.
node('BarrieraMiscuglio', 'StaticBody3D', '.', transform=piazza('M', ID, (XM, 0, ZMI)), collision_layer='256', collision_mask='0')
for k in range(12):
    a = 2 * math.pi * k / 12
    node('Parete%d' % (k + 1), 'CollisionShape3D', 'BarrieraMiscuglio',
         transform=tr(roty(-a + math.pi / 2), (math.cos(a) * (R_B + 0.02 * KX), B_BASSO_BASE + B_BASSO_VETRO + 0.7, math.sin(a) * (R_B + 0.02 * KX))),
         shape='SubResource("forma_barriera")')

# La pedana di servizio (scelta A dell'utente: "ci si possa arrampicare sulla bacinella su cui versare,
# farlo sotto i propri piedi"): piano di grigliato d'acciaio davanti al miscuglio, gradini che scendono
# verso est, parapetto giallo sul davanti e sul fianco ovest; il lato verso il vetro è aperto. Sotto la
# scala una rampa liscia per la collisione (come le scale del raccordo).
P = 'Pedana'
node(P, 'StaticBody3D', '.', transform=piazza('M', ID, (0, 0, 0)), collision_mask='0')
pc = ((PEDANA_X0 + PEDANA_X1) / 2, PEDANA_H, (PEDANA_Z0 + PEDANA_Z1) / 2)
pl, pp = PEDANA_X1 - PEDANA_X0, PEDANA_Z1 - PEDANA_Z0
sr_tardi('BoxMesh', 'pedana_piano', size='Vector3(%.3f, 0.05, %.3f)' % (pl, pp))
sr_tardi('BoxShape3D', 'pedana_piano_forma', size='Vector3(%.3f, 0.1, %.3f)' % (pl, pp))
node('Piano', 'MeshInstance3D', P, transform=tr(ID, (pc[0], PEDANA_H - 0.025, pc[2])), mesh='SubResource("pedana_piano")', material_override='ExtResource("m_griglia")')
node('PianoForma', 'CollisionShape3D', P, transform=tr(ID, (pc[0], PEDANA_H - 0.05, pc[2])), shape='SubResource("pedana_piano_forma")')
# il telaio: travi sotto il piano e quattro gambe
sr_tardi('BoxMesh', 'pedana_trave', size='Vector3(%.3f, 0.08, 0.06)' % pl)
sr_tardi('BoxMesh', 'pedana_gamba', size='Vector3(0.06, %.3f, 0.06)' % (PEDANA_H - 0.05))
for k, z in enumerate((PEDANA_Z0 + 0.03, PEDANA_Z1 - 0.03)):
    node('Trave%d' % (k + 1), 'MeshInstance3D', P, transform=tr(ID, (pc[0], PEDANA_H - 0.09, z)), mesh='SubResource("pedana_trave")', material_override='ExtResource("m_tiranti")')
    for j, x in enumerate((PEDANA_X0 + 0.03, PEDANA_X1 - 0.03)):
        node('Gamba%d%d' % (k + 1, j + 1), 'MeshInstance3D', P, transform=tr(ID, (x, (PEDANA_H - 0.05) / 2, z)), mesh='SubResource("pedana_gamba")', material_override='ExtResource("m_tiranti")')
# i gradini: pedate di grigliato su due cosciali
sr_tardi('BoxMesh', 'gradino', size='Vector3(%.3f, 0.04, %.3f)' % (PED + 0.02, pp))
for g in range(GRADINI - 1):
    x = PEDANA_X1 + PED * (GRADINI - 1 - g) - PED * 0.5
    node('Gradino%d' % (g + 1), 'MeshInstance3D', P, transform=tr(ID, (x, ALZ * (g + 1) - 0.02, pc[2])), mesh='SubResource("gradino")', material_override='ExtResource("m_griglia")')
lung = PED * GRADINI
ang = math.atan2(PEDANA_H, lung)
ls = math.hypot(PEDANA_H, lung)
sr_tardi('BoxMesh', 'cosciale', size='Vector3(%.3f, 0.16, 0.04)' % ls)
sr_tardi('BoxShape3D', 'rampa_forma', size='Vector3(%.3f, 0.1, %.3f)' % (ls, pp))
ca, sa = math.cos(-ang), math.sin(-ang)
rz = '%g, %g, 0, %g, %g, 0, 0, 0, 1' % (ca, -sa, sa, ca)   # rotazione attorno a Z, per righe: scende verso +X
for k, z in enumerate((PEDANA_Z0 + 0.02, PEDANA_Z1 - 0.02)):
    node('Cosciale%d' % (k + 1), 'MeshInstance3D', P, transform=tr(rz, (PEDANA_X1 + lung / 2, PEDANA_H / 2 - 0.05, z)), mesh='SubResource("cosciale")', material_override='ExtResource("m_tiranti")')
node('Rampa', 'CollisionShape3D', P, transform=tr(rz, (PEDANA_X1 + lung / 2, PEDANA_H / 2 - 0.05 / math.cos(ang), pc[2])), shape='SubResource("rampa_forma")')
# il parapetto giallo: montanti, corrimano e corrente a metà, sul davanti (anche lungo la scala) e a ovest
sr_tardi('CylinderMesh', 'montante', top_radius='0.022', bottom_radius='0.022', height='1.0', radial_segments='10')
ringhiera = []   # (da, a) dei corrimano, a quota del piano
zf = PEDANA_Z1 - 0.03
def montante(nome, x, y0, z):
    node(nome, 'MeshInstance3D', P, transform=tr(ID, (x, y0 + 0.5, z)), mesh='SubResource("montante")', material_override='ExtResource("m_giallo")')
for k, x in enumerate((PEDANA_X0 + 0.03, pc[0], PEDANA_X1 - 0.03)):
    montante('Montante%d' % (k + 1), x, PEDANA_H, zf)
montante('MontanteOvest', PEDANA_X0 + 0.03, PEDANA_H, PEDANA_Z0 + 0.03)
montante('MontanteScala', PEDANA_X1 + lung - 0.05, 0.0, zf)
def tubo(nome, a, b, r=0.022):
    ax, ay, az = a
    bx, by, bz = b
    d = (bx - ax, by - ay, bz - az)
    l = math.sqrt(sum(c * c for c in d))
    sid = 'tubo_' + nome
    sr_tardi('CylinderMesh', sid, top_radius='%g' % r, bottom_radius='%g' % r, height='%.3f' % l, radial_segments='10')
    # asse Y del cilindro lungo d
    y = tuple(c / l for c in d)
    x = (y[1], -y[0], 0.0) if abs(y[2]) < 0.9 else (1.0, 0.0, 0.0)
    nx = math.sqrt(sum(c * c for c in x)); x = tuple(c / nx for c in x)
    z = (x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0])
    rows = '%g, %g, %g, %g, %g, %g, %g, %g, %g' % (x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2])
    node(nome, 'MeshInstance3D', P, transform=tr(rows, ((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2)), mesh='SubResource("%s")' % sid, material_override='ExtResource("m_giallo")')
for k, h in enumerate((1.0, 0.5)):
    tubo('Corrimano%d' % (k + 1), (PEDANA_X0 + 0.03, PEDANA_H + h, zf), (PEDANA_X1 - 0.03, PEDANA_H + h, zf))
    tubo('CorrimanoOvest%d' % (k + 1), (PEDANA_X0 + 0.03, PEDANA_H + h, PEDANA_Z0 + 0.03), (PEDANA_X0 + 0.03, PEDANA_H + h, zf))
    tubo('CorrimanoScala%d' % (k + 1), (PEDANA_X1 - 0.03, PEDANA_H + h, zf), (PEDANA_X1 + lung - 0.05, h, zf))
# le collisioni del parapetto (sul livello del mondo: è una ringhiera vera)
sr_tardi('BoxShape3D', 'parapetto_forma', size='Vector3(%.3f, 1.0, 0.06)' % pl)
sr_tardi('BoxShape3D', 'parapetto_ovest_forma', size='Vector3(0.06, 1.0, %.3f)' % pp)
node('ParapettoForma', 'CollisionShape3D', P, transform=tr(ID, (pc[0], PEDANA_H + 0.5, zf)), shape='SubResource("parapetto_forma")')
node('ParapettoOvestForma', 'CollisionShape3D', P, transform=tr(ID, (PEDANA_X0 + 0.03, PEDANA_H + 0.5, pc[2])), shape='SubResource("parapetto_ovest_forma")')

# La valvola rossa del gorgo, spostata di lato rispetto alla pedana: sul davanti-ovest del miscuglio,
# col tubo che entra nella base verso il centro. Il nodo sta sul volantino (lo mira il getto), il modello
# sotto, la bocca dello scarico per terra davanti.
TV = math.radians(50.0)                                   # da sud verso ovest
DV = (-math.sin(TV), math.cos(TV))                        # dal centro verso fuori (x, z)
RV = R_B - 0.02 * KX + 0.55 * 0.7 * KV
VX, VZ = XM + DV[0] * RV, ZMI + DV[1] * RV
VY = 0.45 * KV
# il +X del modello verso il centro del miscuglio, il +Z (davanti, il volantino) verso fuori a destra
_vx = (-DV[0], 0.0, -DV[1])
_vz = (_vx[2] * -1.0, 0.0, _vx[0])   # +Z = X ruotato di -90 gradi attorno a Y
_vz = (-_vx[2], 0.0, _vx[0])
VB = '%g, 0, %g, 0, 1, 0, %g, 0, %g' % (_vx[0], _vz[0], _vx[2], _vz[2])
node('Valvola', 'Node3D', '.', transform=piazza('M', VB, (VX, VY, VZ)))
node('Modello', parent='Valvola', inst='valvola', transform=tr(sc3(0.7 * KV, 0.7 * KV, 0.7 * KV), (0, 0.21 * KV - VY, 0)))
node('Collisione', 'StaticBody3D', 'Valvola', collision_mask='0')
node('Forma', 'CollisionShape3D', 'Valvola/Collisione', transform=tr(ID, (0, 0.17 * KV - VY, 0)), shape='SubResource("forma_valvola")')
node('Bersaglio', 'Area3D', 'Valvola', transform=tr(ID, (-0.4 * KV, 0, 0)), script='ExtResource("hitbox")')   # dalla parte di fuori del modello
node('Forma', 'CollisionShape3D', 'Valvola/Bersaglio', shape='SubResource("forma_bersaglio")')
gx = -(1.1 * 0.7 + 0.12) * KV + 0.55 * 0.7 * KV
node('Scarico', 'MeshInstance3D', 'Valvola', transform=tr(ID, (gx, 0.004 - VY, 0)), mesh='SubResource("griglia")',
     material_override='ExtResource("m_griglia")')
node('Buco', 'MeshInstance3D', 'Valvola', transform=tr(ID, (gx, 0.002 - VY, 0)), mesh='SubResource("buco")')

# La luce della valvola (prova dell'utente del 19 ottobre: la valvola al buio non si vedeva): una
# lampada di servizio a gabbia, la stessa del fiume lento, stretta al tirante davanti a est del blu,
# appena sopra la base, girata verso la valvola. Spot caldo e stretto, senza ombre della gabbia.
TIR = sposta('B', XB + 0.6 * K * math.cos(math.radians(45)), ZA + 0.6 * K * math.sin(math.radians(45)))
LY = B_BASE + 0.25                  # appena sopra la base: la gabbia sporge 21 cm sotto il perno
R_TIR = 0.022 * K
ANGOLO_SPOT = 16.0
VOL = sposta('M', VX, VZ)
VOL = (VOL[0], VY + 0.15, VOL[1])    # il volantino


def _coperta(a, b):
    """La luce da a (x, y, z) al volantino b passa nel miscuglio?"""
    cx, cz = sposta('M', XM, ZMI)
    for i in range(1, 40):
        t = i / 40.0
        x, y, z = (a[k] + (b[k] - a[k]) * t for k in range(3))
        if y < B_BASSO_BASE + B_BASSO_VETRO + 0.05 and math.hypot(x - cx, z - cz) < R_B + 0.1:
            return True
    return False


if POSIZIONE != 'P1':
    # Negli altri posti il tirante del P1 è lontano o il miscuglio è in mezzo: il tirante più vicino da cui
    # si vede la valvola, se no il montante ovest della pedana (a 80 cm, con lo spot più largo).
    cand = []
    for g, (ax, az) in (('G', (XG, ZA)), ('B', (XB, ZA))):
        for k in range(4):
            a = math.radians(45 + 90 * k)
            t = sposta(g, ax + 0.6 * K * math.cos(a), az + 0.6 * K * math.sin(a))
            dd = math.hypot(VOL[0] - t[0], VOL[2] - t[1])
            if dd < 3.5 and not _coperta((t[0], LY, t[1]), VOL):
                cand.append((dd, t))
    if cand:
        TIR = min(cand)[1]
    else:
        TIR = sposta('M', PEDANA_X0 + 0.03, PEDANA_Z0 + 0.03)
        LY, R_TIR, ANGOLO_SPOT = PEDANA_H + 0.75, 0.022, 32.0
_d = (VOL[0] - TIR[0], VOL[2] - TIR[1])
_l = math.hypot(*_d)
_ang = math.atan2(_d[0], _d[1])      # +Z della lampada verso la valvola
LP = (TIR[0] + _d[0] / _l * R_TIR, LY, TIR[1] + _d[1] / _l * R_TIR)
node('LampadaValvola', 'Node3D', '.', transform=tr(roty(_ang), LP), script='ExtResource("lampada_valvola")')
node('Modello', parent='LampadaValvola', inst='gabbia')
# lo spot sul globo (0,36 m davanti al tirante), puntato sul volantino: la base nel sistema della
# lampada, che è girata di _ang attorno a Y
_v = (VOL[0] - (LP[0] + _d[0] / _l * 0.36), VOL[1] - LY, VOL[2] - (LP[2] + _d[1] / _l * 0.36))
_c, _s = math.cos(-_ang), math.sin(-_ang)
_v = (_c * _v[0] + _s * _v[2], _v[1], -_s * _v[0] + _c * _v[2])   # in locale: quasi tutto verso +Z
_lv = math.sqrt(sum(c * c for c in _v))
_z = tuple(-c / _lv for c in _v)                       # lo spot guarda verso -Z
_lx = math.hypot(_z[0], _z[2])
_x = (-_z[2] / _lx, 0.0, _z[0] / _lx)
_y = (_z[1] * _x[2] - _z[2] * _x[1], _z[2] * _x[0] - _z[0] * _x[2], _z[0] * _x[1] - _z[1] * _x[0])
node('Luce', 'SpotLight3D', 'LampadaValvola', transform='Transform3D(%s, 0, 0, 0.36)' % ', '.join('%.5g' % c for c in (_x[0], _y[0], _z[0], _x[1], _y[1], _z[1], _x[2], _y[2], _z[2])),   # per righe
     light_color='Color(1, 0.86, 0.66, 1)', light_energy='%.2f' % (6.0), light_volumetric_fog_energy='0.6',
     spot_range='%.2f' % (_lv + 2.0), spot_attenuation='0.8', spot_angle='%.1f' % ANGOLO_SPOT)

# il disegno sul vetro del giallo, verso il viale (stesse coordinate dell'acquario giallo)
node('Disegno', 'Node3D', '.', transform=piazza('G', sc3(K, K, K), (XG, B_BASE, ZA)))
node('Modello', 'MeshInstance3D', 'Disegno', mesh='ExtResource("disegno")', cast_shadow='0')

# le lampadine del portone (contratto con enigma-logica): LampadePortone sempre visibile; in Spente la
# guida e le lampadine spente, che si vedono sempre; in Accese le lampadine accese e le luci, che lo
# script mostra quando gli acquari compaiono
node('LampadePortone', 'Node3D', '.', transform=tr(ID, (-0.04, 0, 0)))
node('Spente', 'Node3D', 'LampadePortone')
G = 'LampadePortone/Spente'
node('GuidaSinistra', 'MeshInstance3D', G, transform=tr(ID, (X, (YT + 0.06) / 2, Z0)), mesh='SubResource("guida_lato_terra")',
     material_override='ExtResource("m_giallo")')
node('GuidaDestra', 'MeshInstance3D', G, transform=tr(ID, (X, (YT + 0.06) / 2, Z1)), mesh='SubResource("guida_lato_terra")',
     material_override='ExtResource("m_giallo")')
node('GuidaSopra', 'MeshInstance3D', G, transform=tr(ID, (X, YT, (Z0 + Z1) / 2)), mesh='SubResource("guida_sopra")',
     material_override='ExtResource("m_giallo")')
for k, z in enumerate((Z0, Z1)):
    node('PiastraTerra%d' % (k + 1), 'MeshInstance3D', G, transform=tr(ID, (X - 0.025, 0.006, z)), mesh='SubResource("piastra_terra")',
         material_override='ExtResource("m_tiranti")')
for k, z in enumerate((-18.2, -16.3, -13.7, -11.8)):
    node('StaffaMuro%d' % (k + 1), 'MeshInstance3D', G, transform=tr(ID, (19.8465, YT, z)), mesh='SubResource("staffa_muro")',
         material_override='ExtResource("m_tiranti")')
    node('PiastraMuro%d' % (k + 1), 'MeshInstance3D', G, transform=tr(ID, (20.034, YT, z)), mesh='SubResource("piastra_muro")',
         material_override='ExtResource("m_tiranti")')
node('Portalampade', 'MultiMeshInstance3D', G, cast_shadow='0', multimesh='ExtResource("mm_porta")')
node('Lampadine', 'MultiMeshInstance3D', G, cast_shadow='0', multimesh='ExtResource("mm_spente")')
node('Accese', 'Node3D', 'LampadePortone')
luci = [('Lampada1', (X - 0.55, 3.0, Z0)), ('Lampada2', (X - 0.55, 3.0, Z1)), ('Lampada3', (X - 0.55, YT - 0.2, (Z0 + Z1) / 2))]
for i, (nome, p) in enumerate(luci):
    node(nome, 'Node3D', 'LampadePortone/Accese')
    if i == 0:
        # tutte le lampadine accese (poco più grandi delle spente, che coprono)
        node('Modello', 'MultiMeshInstance3D', 'LampadePortone/Accese/' + nome, cast_shadow='0', multimesh='ExtResource("mm_accese")')
    node('Luce', 'OmniLight3D', 'LampadePortone/Accese/' + nome, transform=tr(ID, p), light_color='Color(1, 0.75, 0.45, 1)',
         light_energy='2.2', light_volumetric_fog_energy='1.0', omni_range='7.0', omni_attenuation='1.2')

node('Gorgo', 'Node', '.', node_paths='PackedStringArray("enigma", "acqua_misto")', script='ExtResource("gorgo")',
     enigma='NodePath("..")', acqua_misto='NodePath("../AcquarioMisto/Acqua")')

open(OUT, 'w').write('\n'.join(L + tardi + N))
print('scritto', OUT)
