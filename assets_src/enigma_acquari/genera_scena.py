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
    return 'Transform3D(%s, %s)' % (basis, ', '.join('%.4g' % v for v in p))


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
KY = float(os.environ.get('ACQUARI_KY', str(K)))
KV = float(os.environ.get('ACQUARI_KV', str(K)))   # la valvola
B_BASE, B_VETRO = 0.849 * K, 1.3 * K
SC, R_B, B_BASSO_BASE, B_BASSO_VETRO = 1.45, 0.55 * 1.45 * KX, 0.40 * KY, 0.38 * KY


# le luci: con spot_attenuation 0,8 a distanza doppia arriva 2^-0,8 della luce, e si compensa
LK, LKM = K ** 0.8, max(KX, KY) ** 0.8
# la fila lungo il muro est (posizione 2): gli alti in XA, il miscuglio un poco più avanti (verso la
# sala) in XM; ZM è il centro della fila, PASSO la distanza tra i centri (stessi spazi della proposta)
# A scala 2 la fila è la proposta approvata ingrandita attorno al suo centro (i tubi delle basi arrivano
# a 7,9 m dal centro lungo la fila), spostata di 0,2 m verso la sala: la base del blu resta a 25 cm dalla
# ciambella gonfiabile (x 17), la valvola e lo scarico stanno nel varco tra i lettini (z da -4,65 a 0,2).
XA = 15.6 - 0.2 * (K - 1)
XM = XA - 0.35 * KX
ZM = -3.6
PASSO = (1.3 * K + 1.9 * KX) * 0.5 + 1.2 * K


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
sr('SphereShape3D', 'forma_bersaglio', radius='%.3f' % (0.3 * KV))
sr('CylinderMesh', 'griglia', top_radius='%.3f' % (0.26 * KV), bottom_radius='%.3f' % (0.26 * KV), height='0.01')
sr('StandardMaterial3D', 'nero', albedo_color='Color(0.01, 0.01, 0.01, 1)')
sr('CylinderMesh', 'buco', top_radius='%.3f' % (0.24 * KV), bottom_radius='%.3f' % (0.24 * KV), height='0.004', material='SubResource("nero")')
X, Z0, Z1, YT, YB = 19.645, -18.45, -11.55, 5.5, 0.9
sr('BoxMesh', 'guida_lato', size='Vector3(0.05, %.3f, 0.09)' % (YT - YB + 0.12))
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


def acquario(nome, pos, alto, pigmento=None):
    p = dict(transform=tr(ROT, pos), script='ExtResource("tank")', build_walls='false')
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
        # dal lato lontano da chi arriva (-Z locale, a est), inclinata verso il centro: il riflesso sul
        # pelo lo vede chi si avvicina da ovest
        node('LuceAcquario', 'SpotLight3D', nome, transform=tr('1, 0, 0, 0, -0.573576, 0.819152, 0, -0.819152, -0.573576', (0, 1.25 * KY, -0.75 * KX)),
             light_color='Color(1, 0.95, 0.86, 1)', light_energy='%.2f' % (2.0 * LKM), light_volumetric_fog_energy='0.0',
             spot_range='%.2f' % (1.7 * max(KX, KY)), spot_attenuation='0.8', spot_angle='55.0')
    # cubemap propria per i riflessi solo nel basso, che si guarda da sopra (negli alti il pelo non si vede)
    node('Acqua', parent=nome, inst='acqua', node_paths='PackedStringArray("tank")', tank='NodePath("..")',
         capture_env_cubemap='true' if not alto else 'false', ripple_max_resolution='128')
    node('Vetro', 'Node3D', nome, node_paths='PackedStringArray("acqua")', script='ExtResource("vetro")', acqua='NodePath("../Acqua")')


acquario('AcquarioGiallo', (XA, B_BASE, ZM - PASSO), True, 'giallo')
acquario('AcquarioMisto', (XM, B_BASSO_BASE, ZM), False)
acquario('AcquarioBlu', (XA, B_BASE, ZM + PASSO), True, 'blu')

# la valvola: il nodo sul volantino (lo mira il getto), il modello sotto, la bocca davanti sullo scarico
VX = XM - (R_B - 0.02 * KX + 0.55 * 0.7 * KV)
VY = 0.45 * KV
node('Valvola', 'Node3D', '.', transform=tr(ID, (VX, VY, ZM)))
node('Modello', parent='Valvola', inst='valvola', transform=tr(sc3(0.7 * KV, 0.7 * KV, 0.7 * KV), (0, 0.21 * KV - VY, 0)))
node('Collisione', 'StaticBody3D', 'Valvola', collision_mask='0')
node('Forma', 'CollisionShape3D', 'Valvola/Collisione', transform=tr(ID, (0, 0.17 * KV - VY, 0)), shape='SubResource("forma_valvola")')
node('Bersaglio', 'Area3D', 'Valvola', transform=tr(ID, (-0.4 * KV, 0, 0)), script='ExtResource("hitbox")')   # davanti al modello, verso la sala
node('Forma', 'CollisionShape3D', 'Valvola/Bersaglio', shape='SubResource("forma_bersaglio")')
gx = XM - (R_B - 0.02 * KX + (1.1 * 0.7 + 0.12) * KV) - VX
node('Scarico', 'MeshInstance3D', 'Valvola', transform=tr(ID, (gx, 0.004 - VY, 0)), mesh='SubResource("griglia")',
     material_override='ExtResource("m_griglia")')
node('Buco', 'MeshInstance3D', 'Valvola', transform=tr(ID, (gx, 0.002 - VY, 0)), mesh='SubResource("buco")')

# La luce della valvola (prova dell'utente del 19 ottobre: la valvola al buio non si vedeva). Una
# lampada di servizio a gabbia, la stessa del fiume lento, stretta al tirante davanti a nord
# dell'acquario blu, sopra la base, girata verso la valvola: chi arriva dalla serranda la vede accesa
# e la valvola sotto. Spot caldo e stretto, senza ombre della gabbia.
TIR = (XA - 0.6 * K * math.cos(math.radians(45)), ZM + PASSO - 0.6 * K * math.sin(math.radians(45)))
LY = B_BASE + 0.25                  # appena sopra la base: la gabbia sporge 21 cm sotto il perno
VOL = (VX, VY + 0.15, ZM)            # il volantino
_d = (VOL[0] - TIR[0], VOL[2] - TIR[1])
_l = math.hypot(*_d)
_ang = math.atan2(_d[0], _d[1])      # +Z della lampada verso la valvola
R_TIR = 0.022 * K
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
     spot_range='%.2f' % (_lv + 2.0), spot_attenuation='0.8', spot_angle='16.0')

# il disegno sul vetro del giallo (stesse coordinate dell'acquario giallo)
node('Disegno', 'Node3D', '.', transform=tr(rot_sc(K), (XA, B_BASE, ZM - PASSO)))
node('Modello', 'MeshInstance3D', 'Disegno', mesh='ExtResource("disegno")', cast_shadow='0')

# le lampadine del portone (contratto con enigma-logica): LampadePortone sempre visibile; in Spente la
# guida e le lampadine spente, che si vedono sempre; in Accese le lampadine accese e le luci, che lo
# script mostra quando gli acquari compaiono
node('LampadePortone', 'Node3D', '.')
node('Spente', 'Node3D', 'LampadePortone')
G = 'LampadePortone/Spente'
node('GuidaSinistra', 'MeshInstance3D', G, transform=tr(ID, (X, (YT + YB) / 2, Z0)), mesh='SubResource("guida_lato")',
     material_override='ExtResource("m_giallo")')
node('GuidaDestra', 'MeshInstance3D', G, transform=tr(ID, (X, (YT + YB) / 2, Z1)), mesh='SubResource("guida_lato")',
     material_override='ExtResource("m_giallo")')
node('GuidaSopra', 'MeshInstance3D', G, transform=tr(ID, (X, YT, (Z0 + Z1) / 2)), mesh='SubResource("guida_sopra")',
     material_override='ExtResource("m_giallo")')
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
