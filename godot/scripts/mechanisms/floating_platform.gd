@tool
class_name FloatingPlatform
extends AnimatableBody3D
## Piattaforma galleggiante: segue la superficie dell'acqua di una WaterTank e porta su
## il giocatore. Con la vasca vuota resta appoggiata sul fondo. Si muove solo in verticale.

## La vasca in cui galleggia.
@export var tank: WaterTank
@export var size := Vector3(2.2, 0.35, 2.2):
	set(value):
		size = value
		_rebuild()
## Quanto della piattaforma sta sott'acqua (m).
@export var draft := 0.12
## Velocità massima di salita e discesa (m/s).
@export var max_speed := 1.6
## Morbidezza con cui segue la superficie (1/s).
@export var follow_rate := 4.0
## Piccolo dondolio sull'acqua (m). 0 = fermo.
@export var bob_amplitude := 0.015
@export var bob_speed := 0.35

var is_floating := false

var _time := 0.0
var _vis: Node3D
var _shape_node: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	sync_to_physics = true
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group(&"persist")
		snap_to_water.call_deferred()


## Mette subito la piattaforma alla quota giusta (inizio livello, ripartenza dal checkpoint).
func snap_to_water() -> void:
	if tank == null:
		return
	global_position.y = _target_y()
	reset_physics_interpolation()


func _target_y() -> float:
	var rest := tank.get_floor_global_y() + size.y * 0.5 + 0.005
	var float_y := tank.get_surface_global_y() - draft + size.y * 0.5
	is_floating = float_y > rest
	if is_floating:
		return float_y + sin(_time * bob_speed * TAU) * bob_amplitude
	return rest


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	# La quota dipende dalla vasca: aspetta che tutte le vasche siano ripristinate.
	snap_to_water.call_deferred()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or tank == null:
		return
	_time += delta
	var target := _target_y()
	var y := global_position.y
	var desired := lerpf(y, target, 1.0 - exp(-follow_rate * delta))
	global_position.y = y + clampf(desired - y, -max_speed * delta, max_speed * delta)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	if is_instance_valid(_shape_node):
		_shape_node.free()
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	Graybox.box(_vis, size, Vector3.ZERO, Graybox.FLOAT)
	Graybox.box(_vis, Vector3(size.x * 0.8, 0.02, size.z * 0.8), Vector3(0, size.y * 0.5 + 0.01, 0), Graybox.DARK)
	# La collisione deve essere figlia diretta del corpo.
	_shape_node = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	_shape_node.shape = shape
	add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)
