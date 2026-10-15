#!/usr/bin/env python3
"""Genera godot/scenes/interni/interni.tscn (inizio del capitolo 1: corridoio, spogliatoi, stanzino).
Le coordinate sono quelle dei glTF di assets_src/ambienti_interni (Godot: x, y in alto, nord = -Z).
Il resto (neon, luci d'emergenza, docce, giocatore) lo prepara scripts/interni/interni.gd a runtime.
Uso: python3 tools/godot_interni_scena.py"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../godot/scenes/interni/interni.tscn')
H = math.pi / 2

EXT = [
    ('Script', 'res://scripts/interni/interni.gd', 's_interni'),
    ('PackedScene', 'res://assets/ambienti_interni/corridoio.gltf', 'm_corr'),
    ('PackedScene', 'res://assets/ambienti_interni/spogliatoi.gltf', 'm_spog'),
    ('PackedScene', 'res://assets/ambienti_interni/stanzino.gltf', 'm_stan'),
    ('PackedScene', 'res://scenes/props/water_tank.tscn', 'p_tank'),
    ('Script', 'res://scripts/mechanisms/water_tank.gd', 's_tank'),
    ('PackedScene', 'res://addons/acqua/scenes/acqua_per_vasca.tscn', 'p_link'),
    ('Script', 'res://addons/acqua/scripts/water_tank_link.gd', 's_link'),
    ('Resource', 'res://addons/acqua/presets/stile_1_limpida.tres', 'r_stile'),
    ('PackedScene', 'res://scenes/props/water_button.tscn', 'p_button'),
    ('Script', 'res://scripts/mechanisms/water_button.gd', 's_button'),
    ('PackedScene', 'res://scenes/props/turbine.tscn', 'p_turb'),
    ('Script', 'res://scripts/mechanisms/turbine.gd', 's_turb'),
    ('Script', 'res://scripts/interni/saracinesca.gd', 's_sar'),
    ('PackedScene', 'res://assets/models/zaino/zaino_opzione2/zaino_opzione2.gltf', 'm_zaino'),
    ('Script', 'res://scripts/interaction/pack_pickup.gd', 's_pack'),
    ('PackedScene', 'res://scenes/props/polaroid.tscn', 'p_pol'),
    ('Script', 'res://scripts/interaction/polaroid_photo.gd', 's_pol'),
    ('Script', 'res://scripts/game/checkpoint.gd', 's_cp'),
]

subs, nodes = [], []


def V(*a):
    return 'Vector3(%s)' % ', '.join(f'{x:.6g}' for x in a)


def box(id_, size):
    subs.append(f'[sub_resource type="BoxShape3D" id="{id_}"]\nsize = {V(*size)}\n')
    return f'SubResource("{id_}")'


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


def area(name, parent, pos, size, extra=None):
    props = {'position': V(*pos), 'collision_layer': '0', 'collision_mask': '2', 'monitorable': 'false'}
    props.update(extra or {})
    node(name, 'Area3D', parent, props=props, np=['spawn_point'] if 'spawn_point' in props else None)
    node('CollisionShape3D', 'CollisionShape3D', f'{parent}/{name}', props={'shape': box('a_' + name, size)})


node('Interni', 'Node3D', props={'script': 'ExtResource("s_interni")'})
node('Ambienti', 'Node3D', '.')
node('Corridoio', None, 'Ambienti', inst='m_corr')
node('Spogliatoi', None, 'Ambienti', inst='m_spog')
node('Stanzino', None, 'Ambienti', inst='m_stan')

# vasca lava-piedi: fondo a -0,2, acqua a -0,05 (fill 0,75)
node('Acqua', 'Node3D', '.')
node('VascaLavapiedi', 'Node3D', 'Acqua', inst='p_tank', props={
    'position': V(9.7, -0.2, -13.4), 'script': 'ExtResource("s_tank")', 'inner_size': V(2.2, 0.2, 2.0),
    'build_walls': 'false', 'fill': '0.75', 'max_fill': '0.9', 'capacity_liters': '30.0'})
node('AcquaLavapiedi', 'Node3D', 'Acqua', inst='p_link', np=['tank'], props={
    'script': 'ExtResource("s_link")', 'tank': 'NodePath("../VascaLavapiedi")', 'style': 'ExtResource("r_stile")',
    'env_box_min': V(8.4, -0.5, -21), 'env_box_max': V(11, 3, -11)})

# tornello, turbina e saracinesca
node('Meccanismi', 'Node3D', '.')
node('PulsanteTornello', 'Node3D', 'Meccanismi', inst='p_button', props={
    'position': V(13.15, 1.3, -16.0), 'rotation': V(0, -H, 0), 'script': 'ExtResource("s_button")',
    'mode': '2', 'radius': '0.14', 'show_model': 'false'})
node('BloccoTornello', 'StaticBody3D', 'Meccanismi', props={'position': V(9.5, 1.125, -16.4)})
node('CollisionShape3D', 'CollisionShape3D', 'Meccanismi/BloccoTornello', props={'shape': box('blocco_tornello', (1.25, 2.25, 0.3))})
area('PassaggioTornello', 'Meccanismi', (9.5, 1.0, -16.4), (1.2, 2.0, 1.4))
node('PernoTurbina', 'Node3D', 'Meccanismi', props={'position': V(8.79, 2.05, -19.4), 'rotation': V(0, H, 0)})
node('TurbinaSaracinesca', 'Node3D', 'Meccanismi', inst='p_turb', props={
    'position': V(8.79, 2.05, -19.4), 'rotation': V(0, H, 0), 'script': 'ExtResource("s_turb")', 'radius': '0.26',
    'show_model': 'false', 'external_rotor': 'NodePath("../PernoTurbina")', 'spin_per_liter': '14.0'})
node('Saracinesca', 'Node3D', 'Meccanismi', np=['sources'], props={
    'position': V(9.7, 0, -20.6), 'script': 'ExtResource("s_sar")', 'sources': '[NodePath("../TurbinaSaracinesca")]',
    'stay_open': 'true', 'size': V(1.2, 2.2, 0.1), 'open_offset': V(0, 2.15, 0), 'open_speed': '0.12',
    'modello': 'NodePath("../../Ambienti/Spogliatoi/saracinesca")'})

# zaino-pompa sulla rastrelliera dello stanzino (marker_zaino_pompa)
node('Zaino', 'Node3D', '.', props={'position': V(14.92, 0.72, -8.43), 'rotation': V(0, -H, 0)})
node('Modello', None, 'Zaino', inst='m_zaino')
node('Prendi', 'Area3D', 'Zaino', np=['remove_node'], props={
    'collision_layer': '16', 'collision_mask': '0', 'monitoring': 'false', 'script': 'ExtResource("s_pack")',
    'remove_node': 'NodePath("..")', 'prompt': '"Prendi lo zaino-pompa"', 'one_shot': 'true'})
node('CollisionShape3D', 'CollisionShape3D', 'Zaino/Prendi', props={'position': V(0, 0.35, 0), 'shape': box('zaino', (0.55, 0.75, 0.5))})
node('LuceZaino', 'SpotLight3D', '.', props={
    'position': V(13.6, 2.45, -8.43), 'rotation': V(-0.75, -H, 0), 'light_color': 'Color(1, 0.88, 0.72, 1)',
    'light_energy': '0.8', 'shadow_enabled': 'true', 'spot_range': '3.5', 'spot_angle': '28.0'})

# Polaroid P1 (a terra vicino al risveglio), P2 (armadietto aperto), P3 (bacheca dello stanzino)
node('Polaroid', 'Node3D', '.')
for nome, foto, pos, rot, snap in [('Polaroid01', 1, (20.9, 0.02, -0.55), (0, 0.35, 0), True),
                                   ('Polaroid02', 2, (3.38, 1.6, -7.9), (0, H, 0), False),
                                   ('Polaroid03', 3, (12.65, 1.3, -6.245), (-H, 0, 0.05), False)]:
    pr = {'position': V(*pos), 'rotation': V(*rot), 'collision_layer': '16', 'collision_mask': '0', 'monitoring': 'false',
          'script': 'ExtResource("s_pol")', 'photo': str(foto), 'entry_id': f'&"p0{foto}"', 'prompt': '"Raccogli"',
          'one_shot': 'true'}
    if not snap:
        pr['snap_to_surface'] = 'false'
    node(nome, None, 'Polaroid', inst='p_pol', props=pr)

# risveglio, checkpoint (order negativi: vengono prima di quelli della sala) e trigger
node('Gioco', 'Node3D', '.')
node('Risveglio', 'Marker3D', 'Gioco', props={'position': V(20.4, 0, -1.25), 'rotation': V(0, H, 0), 'gizmo_extents': '0.6'})
for nome, ordine, pos, size, yaw in [
        ('CheckpointRisveglio', -10, (19.6, 1.5, -1.3), (1.6, 3, 2.6), H),
        ('CheckpointIngressoSpogliatoi', -9, (6.8, 1.5, -3.5), (1.6, 3, 0.8), 0.0),
        ('CheckpointStanzino', -8, (12.2, 1.5, -8.45), (1.0, 3, 1.0), -H),
        ('CheckpointLavapiedi', -7, (9.7, 1.5, -11.7), (2.2, 3, 0.8), 0.0),
        ('CheckpointTornello', -6, (9.7, 1.5, -15.3), (2.2, 3, 0.8), 0.0),
        ('CheckpointSaracinesca', -5, (9.7, 1.5, -18.2), (2.2, 3, 0.8), 0.0)]:
    area(nome, 'Gioco', pos, size, {'script': 'ExtResource("s_cp")', 'order': str(ordine), 'spawn_point': 'NodePath("Ripartenza")'})
    node('Ripartenza', 'Marker3D', f'Gioco/{nome}', props={'position': V(0, -1.5, 0), 'rotation': V(0, yaw, 0)})
area('DocceDaSole', 'Gioco', (6.0, 1.5, -10.2), (3.0, 3, 1.0))
area('ArmadiettoSbatte', 'Gioco', (9.6, 1.5, -5.3), (1.6, 3, 1.2))

# una sonda dei riflessi d'interno per zona
node('Atmosfera', 'Node3D', '.')
for nome, pos, size in [('RiflessiCorridoio', (11, 1.35, -1.3), (22.4, 2.8, 2.8)),
                        ('RiflessiSpogliatoi', (7, 1.45, -7), (8.4, 3, 8.4)),
                        ('RiflessiDocce', (5.6, 1.45, -12.9), (5.4, 3, 3.6)),
                        ('RiflessiLavapiedi', (9.7, 1.35, -15.85), (2.4, 2.8, 9.6)),
                        ('RiflessiStanzino', (13.2, 1.3, -8.4), (4.2, 2.7, 4.6))]:
    node(nome, 'ReflectionProbe', 'Atmosfera', props={'position': V(*pos), 'size': V(*size), 'box_projection': 'true',
                                                      'interior': 'true', 'ambient_mode': '0'})

testo = ['[gd_scene format=3]', ''] + [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for t, p, i in EXT] + [''] + subs + nodes
with open(OUT, 'w') as f:
    f.write('\n'.join(testo))
print('scritto', os.path.normpath(OUT))
