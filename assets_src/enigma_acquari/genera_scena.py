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


B_BASE, B_VETRO = 0.849, 1.3
SC, R_B, B_BASSO_BASE, B_BASSO_VETRO = 1.45, 0.55 * 1.45, 0.40, 0.38
sr('CylinderMesh', 'tirante', top_radius='0.022', bottom_radius='0.022', height='%.3f' % (B_VETRO + 0.2), radial_segments='12')
sr('CylinderShape3D', 'forma_alto', radius='0.5', height='2.95')
sr('TorusMesh', 'anello', inner_radius='%.4f' % (R_B - 0.025), outer_radius='%.4f' % (R_B + 0.045), rings='64')
sr('CylinderShape3D', 'forma_base_bassa', radius='%.3f' % (R_B + 0.02), height='0.4')
sr('BoxShape3D', 'forma_parete', size='Vector3(0.45, 0.4, 0.06)')
sr('BoxShape3D', 'forma_valvola', size='Vector3(0.77, 0.3, 0.3)')   # solo il tubo: il volantino resta libero per il getto
sr('SphereShape3D', 'forma_bersaglio', radius='0.3')
sr('CylinderMesh', 'griglia', top_radius='0.26', bottom_radius='0.26', height='0.01')
sr('StandardMaterial3D', 'nero', albedo_color='Color(0.01, 0.01, 0.01, 1)')
sr('CylinderMesh', 'buco', top_radius='0.24', bottom_radius='0.24', height='0.004', material='SubResource("nero")')
X, Z0, Z1, YT, YB = 19.645, -18.45, -11.55, 5.5, 0.9
sr('BoxMesh', 'guida_lato', size='Vector3(0.05, %.3f, 0.09)' % (YT - YB + 0.12))
sr('BoxMesh', 'guida_sopra', size='Vector3(0.05, 0.09, %.3f)' % (Z1 - Z0 + 0.09))
L += sub

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


def acquario(nome, pos, alto, pigmento=None):
    p = dict(transform=tr(ROT, pos), script='ExtResource("tank")', build_walls='false')
    if alto:
        p.update(inner_size='Vector3(1.1, %.3f, 1.1)' % B_VETRO, fill='0.94', capacity_liters='80.0',
                 fill_pigment='"%s"' % pigmento, min_fill='0.2')
    else:
        d = 2 * R_B
        p.update(inner_size='Vector3(%.3f, %.3f, %.3f)' % (d, B_BASSO_VETRO, d), capacity_liters='62.0',
                 suckable='false')
    node(nome, 'Node3D', '.', **p)
    if alto:
        node('Base', parent=nome, inst='base', transform=tr(ID, (0, -B_BASE, 0)))
        node('Coperchio', parent=nome, inst='coperchio', transform=tr(ID, (0, B_VETRO, 0)))
        for k in range(4):
            a = math.radians(45 + 90 * k)
            node('Tirante%d' % (k + 1), 'MeshInstance3D', nome, transform=tr(ID, (math.cos(a) * 0.6, B_VETRO * 0.5, math.sin(a) * 0.6)),
                 mesh='SubResource("tirante")', material_override='ExtResource("m_tiranti")')
        node('Collisione', 'StaticBody3D', nome, collision_mask='0')
        node('Forma', 'CollisionShape3D', nome + '/Collisione', transform=tr(ID, (0, -B_BASE + 1.475, 0)), shape='SubResource("forma_alto")')
    else:
        node('Base', parent=nome, inst='base_bassa', transform=tr('%g, 0, 0, 0, 1, 0, 0, 0, %g' % (SC, SC), (0, -B_BASSO_BASE, 0)))
        node('Anello', 'MeshInstance3D', nome, transform=tr('1, 0, 0, 0, 0.6, 0, 0, 0, 1', (0, B_BASSO_VETRO + 0.006, 0)),
             mesh='SubResource("anello")', material_override='ExtResource("m_rosso")')
        node('Collisione', 'StaticBody3D', nome, collision_mask='0')
        node('Base', 'CollisionShape3D', nome + '/Collisione', transform=tr(ID, (0, -0.2, 0)), shape='SubResource("forma_base_bassa")')
        # il vetro: dodici pareti in tondo, aperto sopra (il getto ci deve entrare)
        for k in range(12):
            a = 2 * math.pi * k / 12
            node('Parete%d' % (k + 1), 'CollisionShape3D', nome + '/Collisione',
                 transform=tr(roty(-a + math.pi / 2), (math.cos(a) * (R_B + 0.02), 0.2, math.sin(a) * (R_B + 0.02))),
                 shape='SubResource("forma_parete")')
    # la luce di servizio, come nella proposta approvata: dentro gli alti sotto il coperchio, sopra il
    # basso (debole e corta: arriva all'acqua ma non al pavimento)
    if alto:
        node('LuceAcquario', 'SpotLight3D', nome, transform=tr('1, 0, 0, 0, 0, 1, 0, -1, 0', (0, B_VETRO - 0.05, 0)),
             light_color='Color(1, 0.95, 0.86, 1)', light_energy='4.0', light_volumetric_fog_energy='0.4',
             spot_range='1.9', spot_attenuation='0.8', spot_angle='75.0')   # non arriva al pavimento
    else:
        # dal lato lontano da chi arriva (-Z locale, a est), inclinata verso il centro: il riflesso sul
        # pelo lo vede chi si avvicina da ovest
        node('LuceAcquario', 'SpotLight3D', nome, transform=tr('1, 0, 0, 0, -0.573576, 0.819152, 0, -0.819152, -0.573576', (0, 1.25, -0.75)),
             light_color='Color(1, 0.95, 0.86, 1)', light_energy='2.0', light_volumetric_fog_energy='0.0',
             spot_range='1.7', spot_attenuation='0.8', spot_angle='55.0')
    # cubemap propria per i riflessi solo nel basso, che si guarda da sopra (negli alti il pelo non si vede)
    node('Acqua', parent=nome, inst='acqua', node_paths='PackedStringArray("tank")', tank='NodePath("..")',
         capture_env_cubemap='true' if not alto else 'false', ripple_max_resolution='128')
    node('Vetro', 'Node3D', nome, node_paths='PackedStringArray("acqua")', script='ExtResource("vetro")', acqua='NodePath("../Acqua")')


acquario('AcquarioGiallo', (15.6, B_BASE, -6.4), True, 'giallo')
acquario('AcquarioMisto', (15.25, B_BASSO_BASE, -3.6), False)
acquario('AcquarioBlu', (15.6, B_BASE, -0.8), True, 'blu')

# la valvola: il nodo sul volantino (lo mira il getto), il modello sotto, la bocca davanti sullo scarico
VX = 15.25 - (R_B - 0.02 + 0.55 * 0.7)
node('Valvola', 'Node3D', '.', transform=tr(ID, (VX, 0.45, -3.6)))
node('Modello', parent='Valvola', inst='valvola', transform=tr('0.7, 0, 0, 0, 0.7, 0, 0, 0, 0.7', (0, 0.21 - 0.45, 0)))
node('Collisione', 'StaticBody3D', 'Valvola', collision_mask='0')
node('Forma', 'CollisionShape3D', 'Valvola/Collisione', transform=tr(ID, (0, 0.17 - 0.45, 0)), shape='SubResource("forma_valvola")')
node('Bersaglio', 'Area3D', 'Valvola', transform=tr(ID, (-0.4, 0, 0)), script='ExtResource("hitbox")')   # davanti al modello, verso la sala
node('Forma', 'CollisionShape3D', 'Valvola/Bersaglio', shape='SubResource("forma_bersaglio")')
gx = 15.25 - (R_B - 0.02 + 1.1 * 0.7 + 0.12) - VX
node('Scarico', 'MeshInstance3D', 'Valvola', transform=tr(ID, (gx, 0.004 - 0.45, 0)), mesh='SubResource("griglia")',
     material_override='ExtResource("m_griglia")')
node('Buco', 'MeshInstance3D', 'Valvola', transform=tr(ID, (gx, 0.002 - 0.45, 0)), mesh='SubResource("buco")')

# il disegno sul vetro del giallo (stesse coordinate dell'acquario giallo)
node('Disegno', 'Node3D', '.', transform=tr(ROT, (15.6, B_BASE, -6.4)))
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

open(OUT, 'w').write('\n'.join(L + N))
print('scritto', OUT)
