extends Node3D
## Oggetti di scena della sala di prova: ciambelle che galleggiano nella vasca d'arrivo,
## giocattoli nella pozza della piscina a onde, gocce dal soffitto. Creati da codice.

const TOY_COLORS := [Color(0.85, 0.7, 0.12), Color(0.75, 0.2, 0.15), Color(0.2, 0.45, 0.7), Color(0.25, 0.6, 0.3), Color(0.85, 0.45, 0.6)]

var bobbers: Array[Node3D] = []


func _ready() -> void:
	# ciambelle gonfiabili nella vasca d'arrivo
	_ring(Vector3(11.0, -0.3, -0.5), Color(0.75, 0.15, 0.12), 0.32, 0.58)
	_ring(Vector3(13.4, -0.3, 1.2), Color(0.2, 0.5, 0.25), 0.28, 0.5)
	# giocattoli nella pozza torbida (girano nel gorgo quando si svuota)
	var toys := [Vector3(-1.6, -1.5, -3.0), Vector3(1.4, -1.5, -4.4), Vector3(0.6, -1.5, -2.2),
			Vector3(-0.8, -1.5, -4.8), Vector3(2.4, -1.5, -3.4), Vector3(-2.6, -1.5, -4.0)]
	for i in toys.size():
		_toy(toys[i], TOY_COLORS[i % TOY_COLORS.size()], i)
	# acqua che scorre nel tubo dello scivolo e si tuffa nella vasca d'arrivo
	var hall: Node = get_parent().get_node_or_null("MainHall")
	var curve: Curve3D = hall.get("slide_curve") if hall else null
	if curve:
		var sw := SlideWater.new()
		sw.name = "AcquaScivolo"
		sw.tube_radius = 0.62
		sw.flow_speed = 3.2
		sw.curve = curve
		add_child(sw)
	# gocce dal soffitto: sulle pozzanghere del pavimento, sulle vasche e sulla pozza
	for p in [Vector3(7.4, 7.9, 4.2), Vector3(-4.5, 7.9, 8.0), Vector3(16.0, 7.9, -1.0), Vector3(-16.2, 7.9, 5.0),
			Vector3(12.6, 7.9, -3.5), Vector3(-11.0, 7.9, 1.2), Vector3(-0.8, 7.9, -3.0), Vector3(1.6, 7.9, -4.6),
			Vector3(7.8, 7.9, -1.5)]:
		var d := WaterDripEmitter.new()
		d.position = p
		add_child(d)


func _ring(p: Vector3, col: Color, inner: float, outer: float) -> void:
	var b := WaterBobber.new()
	b.position = p
	b.draft = 0.03
	b.margin = outer + 0.2
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 32
	tm.ring_segments = 16
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.35
	m.clearcoat_enabled = true
	m.clearcoat = 0.4
	mi.material_override = m
	b.add_child(mi)
	add_child(b)
	bobbers.append(b)


func _toy(p: Vector3, col: Color, i: int) -> void:
	var b := WaterBobber.new()
	b.position = p
	b.draft = 0.02
	b.margin = 0.3
	b.drift_speed = 0.01
	var mi := MeshInstance3D.new()
	if i % 3 == 0:
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.22
		mi.mesh = sm
	elif i % 3 == 1:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.09
		cm.height = 0.12
		mi.mesh = cm
		mi.rotation_degrees = Vector3(90, 0, 0)
	else:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.06
		tm.outer_radius = 0.13
		mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = col * 0.8
	m.roughness = 0.45
	mi.material_override = m
	b.add_child(mi)
	add_child(b)
	bobbers.append(b)
