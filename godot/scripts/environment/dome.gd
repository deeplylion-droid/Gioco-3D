@tool
class_name Dome
extends Node3D
## Cupola di vetro con la struttura in acciaio (grafica provvisoria procedurale).
## L'origine è al centro della base; la cupola è una semisfera schiacciata.

@export var radius := 13.0:
	set(value):
		radius = value
		_rebuild()
@export var height := 7.0:
	set(value):
		height = value
		_rebuild()
@export_range(4, 48) var ribs := 16:
	set(value):
		ribs = value
		_rebuild()
@export_range(0, 8) var rings := 3:
	set(value):
		rings = value
		_rebuild()
## Vetro: lo usa anche il nodo dei lampi per illuminarlo.
@export var glass_material: StandardMaterial3D:
	set(value):
		glass_material = value
		_rebuild()
@export var frame_material: Material:
	set(value):
		frame_material = value
		_rebuild()

var _vis: Node3D


func _ready() -> void:
	_rebuild()


func _point(theta: float, phi: float) -> Vector3:
	# theta: angolo intorno all'asse verticale; phi: 0 = base, PI/2 = cima.
	return Vector3(cos(theta) * cos(phi) * radius, sin(phi) * height, sin(theta) * cos(phi) * radius)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	var glass := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.0
	sphere.is_hemisphere = true
	sphere.radial_segments = 48
	sphere.rings = 16
	glass.mesh = sphere
	glass.scale = Vector3(radius, height, radius)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.material_override = glass_material
	_vis.add_child(glass)
	# Struttura: meridiani e paralleli fatti di travi dritte.
	var beam := BoxMesh.new()
	beam.size = Vector3(0.18, 0.18, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = beam
	var xforms: Array[Transform3D] = []
	var steps := 10
	for r in ribs:
		var theta := TAU * r / ribs
		for i in steps:
			xforms.append(_beam(_point(theta, PI * 0.5 * i / steps), _point(theta, PI * 0.5 * (i + 1) / steps)))
	for k in range(1, rings + 1):
		var phi := PI * 0.5 * k / (rings + 1)
		var seg := ribs * 2
		for i in seg:
			xforms.append(_beam(_point(TAU * i / seg, phi), _point(TAU * (i + 1) / seg, phi)))
	var base_seg := ribs * 3
	for i in base_seg:
		xforms.append(_beam(_point(TAU * i / base_seg, 0.0), _point(TAU * (i + 1) / base_seg, 0.0), 0.45))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var frame := MultiMeshInstance3D.new()
	frame.multimesh = mm
	frame.material_override = frame_material
	_vis.add_child(frame)


func _beam(a: Vector3, b: Vector3, thickness := 1.0) -> Transform3D:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	basis = basis * Basis.from_scale(Vector3(thickness, thickness, d.length() + 0.1))
	return Transform3D(basis, (a + b) * 0.5)
