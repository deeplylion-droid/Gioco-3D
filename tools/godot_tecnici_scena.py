#!/usr/bin/env python3
"""Genera godot/scenes/tecnici/tecnici.tscn (tappe 5-6 del capitolo 1: camera delle onde e sala pompe).
I marker si prendono dai nodi dei glTF (godot/assets/ambienti_tecnici/*.gltf, fatti da
tools/blender/ambienti2_camera_onde.py e ambienti2_sala_pompe.py), quindi restano giusti se i modelli cambiano.
Il resto (materiali, neon, luci d'emergenza, decal, giocatore) lo prepara scripts/tecnici/tecnici.gd a runtime.
Uso: python3 tools/godot_tecnici_scena.py"""
import json
import math
import os

QUI = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(QUI, '../godot')
OUT = os.path.join(GODOT, 'scenes/tecnici/tecnici.tscn')
H = math.pi / 2
# la sala pompe è attaccata alla camera delle onde: il suo tunnel (x = -13 nel glTF) finisce sul vano del muro est (x = 24)
OFFSET_SALA = (37.3, 0.0, -2.2)

EXT = [
    ('Script', 'res://scripts/tecnici/tecnici.gd', 's_tecnici'),
    ('PackedScene', 'res://assets/ambienti_tecnici/camera_onde.gltf', 'm_camera'),
    ('PackedScene', 'res://assets/ambienti_tecnici/sala_pompe.gltf', 'm_sala'),
    ('PackedScene', 'res://assets/ambienti_tecnici/raccordo.gltf', 'm_racc'),
    ('PackedScene', 'res://scenes/props/water_tank.tscn', 'p_tank'),
    ('Script', 'res://scripts/mechanisms/water_tank.gd', 's_tank'),
    ('PackedScene', 'res://addons/acqua/scenes/acqua_per_vasca.tscn', 'p_link'),
    ('Script', 'res://addons/acqua/scripts/water_tank_link.gd', 's_link'),
    ('Resource', 'res://addons/acqua/presets/stile_3_scura.tres', 'r_stile'),
    ('Script', 'res://scripts/mechanisms/ladder.gd', 's_ladder'),
    ('PackedScene', 'res://scenes/tecnici/luci_tecnici.tscn', 'p_luci'),
]


# --- posizioni globali dei nodi nei glTF ----------------------------------------------------------
def qmul(a, b):
    ax, ay, az, aw = a; bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


def qrot(q, v):
    x, y, z, _ = qmul(qmul(q, (v[0], v[1], v[2], 0.0)), (-q[0], -q[1], -q[2], q[3]))
    return (x, y, z)


def nodi_gltf(file, offset):
    g = json.load(open(os.path.join(GODOT, 'assets/ambienti_tecnici', file)))
    out = {}

    def visita(i, pos, rot, sca):
        n = g['nodes'][i]
        t = n.get('translation', [0, 0, 0]); r = n.get('rotation', [0, 0, 0, 1]); s = n.get('scale', [1, 1, 1])
        p = qrot(rot, [t[k] * sca[k] for k in range(3)])
        pos2 = tuple(pos[k] + p[k] for k in range(3))
        rot2 = qmul(rot, tuple(r)); sca2 = tuple(sca[k] * s[k] for k in range(3))
        out[n['name']] = (pos2, rot2)
        if 'mesh' in n:   # centro del box della mesh (per gli oggetti uniti con l'origine nello zero della stanza)
            mn, mx = [1e9] * 3, [-1e9] * 3
            for pr in g['meshes'][n['mesh']]['primitives']:
                a = g['accessors'][pr['attributes']['POSITION']]
                mn = [min(mn[k], a['min'][k]) for k in range(3)]; mx = [max(mx[k], a['max'][k]) for k in range(3)]
            c = qrot(rot2, [(mn[k] + mx[k]) / 2 * sca2[k] for k in range(3)])
            out[n['name'] + '#centro'] = (tuple(pos2[k] + c[k] for k in range(3)), rot2)
        for c in n.get('children', []):
            visita(c, pos2, rot2, sca2)

    for i in g['scenes'][0]['nodes']:
        visita(i, tuple(offset), (0.0, 0.0, 0.0, 1.0), (1.0, 1.0, 1.0))
    return out


CAMERA = nodi_gltf('camera_onde.gltf', (0, 0, 0))
SALA = nodi_gltf('sala_pompe.gltf', OFFSET_SALA)
RACC = nodi_gltf('raccordo.gltf', (0, 0, 0))

subs, nodes = [], []


def V(*a):
    return 'Vector3(%s)' % ', '.join(f'{x:.6g}' for x in a)


def node(name, typ=None, parent=None, inst=None, props=None, np=None):
    h = f'[node name="{name}"'
    if typ:
        h += f' type="{typ}"'
    if parent is not None:
        h += f' parent="{parent}"'
    if np:
        h += ' node_paths=PackedStringArray(%s)' % ', '.join(f'"{x}"' for x in np)
    if inst:
        h += f' instance=ExtResource("{inst}")'
    nodes.append(h + ']')
    for k, v in (props or {}).items():
        nodes.append(f'{k} = {v}')
    nodes.append('')


def marker(nome, sorgente, chiave, delta=(0, 0, 0), yaw=None, nota=''):
    pos, _ = sorgente[chiave]
    props = {'position': V(*(pos[k] + delta[k] for k in range(3))), 'gizmo_extents': '0.5'}
    if yaw is not None:
        props['rotation'] = V(0, yaw, 0)
    if nota:
        props['editor_description'] = '"%s"' % nota.replace('"', "'")
    node(nome, 'Marker3D', 'Marker', props=props)


node('Tecnici', 'Node3D', props={'script': 'ExtResource("s_tecnici")'})
node('Ambienti', 'Node3D', '.')
node('CameraOnde', None, 'Ambienti', inst='m_camera')
node('SalaPompe', None, 'Ambienti', inst='m_sala', props={'position': V(*OFFSET_SALA)})
node('Raccordo', None, 'Ambienti', inst='m_racc')

# vasca di raccolta piena d'acqua nera (4,8 x 3 m, profonda 1,7; pelo a -0,15): serbatoio dell'addon acqua
fondo, _ = SALA['PUNTO_vasca_raccolta_fondo']
pelo = SALA['ACQUA_vasca_raccolta#centro'][0][1] + 0.01
node('Acqua', 'Node3D', '.')
node('VascaRaccolta', 'Node3D', 'Acqua', inst='p_tank', props={
    'position': V(*fondo), 'script': 'ExtResource("s_tank")', 'inner_size': V(4.8, 1.7, 3.0),
    'build_walls': 'false', 'fill': f'{(pelo - fondo[1]) / 1.7:.4f}', 'max_fill': '0.95', 'capacity_liters': '80.0'})
node('AcquaVascaRaccolta', 'Node3D', 'Acqua', inst='p_link', np=['tank'], props={
    'script': 'ExtResource("s_link")', 'tank': 'NodePath("../VascaRaccolta")', 'style': 'ExtResource("r_stile")'})

# scala alla marinara del pozzo: dal pavimento della camera al fondo della piscina, contro la parete -X del pozzo
pp, _ = CAMERA['PUNTO_portello']
node('Gioco', 'Node3D', '.')
node('ScalaPozzo', 'Area3D', 'Gioco', props={'position': V(pp[0] - 0.65 + 0.18, 0, pp[2]), 'rotation': V(0, H, 0),
                                            'script': 'ExtResource("s_ladder")', 'height': f'{pp[1]:.3f}', 'width': '0.6',
                                            'show_model': 'false'})

node('Marker', 'Node3D', '.')
# percorso
marker('marker_portello', CAMERA, 'PUNTO_portello', nota='centro del portello sul fondo della piscina a onde, in cima al pozzo (la cerniera del portello della sala è 0,64 m verso -X)')
marker('marker_arrivo_scala', CAMERA, 'PUNTO_arrivo_scala', yaw=-H, nota='in fondo alla scala, guarda verso est (+X), lungo la camera')
marker('marker_tunnel_sala_pompe', CAMERA, 'PUNTO_verso_sala_pompe', nota='vano 2,6 x 2,8 m nel muro est della camera: tunnel verso la sala pompe')
for n in (1, 2):
    marker(f'marker_paratia_{n}', CAMERA, f'PARATIA_{n}', nota=f'paratia {n}: origine sul bordo basso, scende lungo -Y fino a terra')
# sala pompe
for n in (1, 2, 3):
    marker(f'marker_pompa_{n}', SALA, f'POMPA_{n}#centro', delta=(0, -1.2, 0), nota=f'pompa {n} (corpo)')
    marker(f'marker_turbina_{n}', SALA, f'TURBINA_{n}#centro', nota=f'turbina d avviamento della pompa {n}: ruota sul suo asse, che è Z (guarda verso +Z, verso la stanza)')
marker('marker_leva', SALA, 'LEVA', nota='mozzo della leva grande: ruota su X, abbassata = -70 gradi')
marker('marker_grata_leva', SALA, 'GRATA_leva', nota='cardine della grata davanti alla leva: ruota su Y')
marker('marker_schema', SALA, 'SCHEMA_pompe#centro', nota='schema a colori sul muro: blu, giallo, rosso, poi la leva')
marker('marker_vasca_raccolta', SALA, 'ACQUA_vasca_raccolta#centro', nota='superficie dell acqua nera della vasca di raccolta')
marker('marker_monitor', SALA, 'PUNTO_monitor', nota='schermo del monitor a tubo sulla scrivania')
marker('marker_porta_ponte', SALA, 'PUNTO_porta_ponte_inferiore', nota='davanti alla porta del ponte inferiore (lato sala)')
marker('marker_porta_ponte_perno', SALA, 'PORTA_ponte', nota='cardine della porta del ponte inferiore: ruota su Y')
marker('marker_chiavistello', SALA, 'PUNTO_chiavistello', nota='puleggia del chiavistello della porta: ci arriva il cavo della leva')
marker('marker_chiusura_stagna', SALA, 'PUNTO_chiusura_stagna', nota='cilindro della chiusura stagna della porta: ci arrivano i tubi delle tre turbine')
# raccordo verso gli interni
marker('marker_raccordo_sala', RACC, 'PUNTO_raccordo_sala', yaw=-H, nota='nel raccordo, appena fuori dalla porta del ponte inferiore')
marker('marker_raccordo_interni', RACC, 'PUNTO_raccordo_interni', yaw=-H, nota='in cima al raccordo, ai piedi della scala che sale al corridoio degli interni')

# luce segnaposto dentro la gabbia: la leva si deve leggere da terra (le luci finali le fa grafica)
pl, _ = SALA['LEVA']
node('LuceLeva', 'OmniLight3D', '.', props={'position': V(pl[0] - 0.4, pl[1] + 0.35, pl[2]), 'light_color': 'Color(1, 0.82, 0.6, 1)',
                                           'light_energy': '1.6', 'omni_range': '1.8', 'light_specular': '0.6'})

# una sonda dei riflessi d'interno per stanza
node('Atmosfera', 'Node3D', '.')
for nome, pos, size in [('RiflessiCamera', (12, 2.1, 0), (24.4, 4.4, 4.6)),
                        ('RiflessiTunnel', (30.65, 1.4, 0), (12.7, 2.8, 2.6)),
                        ('RiflessiSala', (37.3, 2.75, 1.0), (18.4, 5.6, 12.4)),
                        ('RiflessiRaccordo', (48.6, 1.4, 1.4), (4.0, 2.8, 2.0)),
                        ('RiflessiVanoScala', (51.6, 3.6, -3.35), (2.0, 7.2, 11.5)),
                        ('RiflessiRampa', (47.0, 6.7, -7.8), (7.2, 6.4, 2.6))]:
    node(nome, 'ReflectionProbe', 'Atmosfera', props={'position': V(*pos), 'size': V(*size), 'box_projection': 'true',
                                                      'interior': 'true', 'ambient_mode': '0'})

# le luci finali (addon grafica, LookTecnici): seguono da sole GameState.luci (prima, flash, blackout)
node('LuciTecnici', parent='.', inst='p_luci')

testo = ['[gd_scene format=3]', ''] + [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in EXT] + [''] + subs + nodes
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w') as f:
    f.write('\n'.join(testo))
print('scritto', os.path.normpath(OUT))
