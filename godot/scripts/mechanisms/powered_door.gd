@tool
class_name PoweredDoor
extends Node3D
## Porta scorrevole alimentata: si apre quando le sue sorgenti (turbine, pulsanti...) sono accese.
## L'origine è in basso al centro del vano; il pannello scorre di open_offset (spazio locale).
## Non si chiude se c'è qualcuno sotto (safety_check). La grafica è provvisoria (graybox).

signal opened
signal closed
signal open_changed(is_open: bool)

enum Logic { ANY, ALL }

## Sorgenti di energia (turbine, pulsanti...).
@export var sources: Array[PowerSource] = []
## ANY: basta una sorgente accesa. ALL: servono tutte.
@export var logic := Logic.ANY
## Se vero, la porta è aperta quando le sorgenti sono spente.
@export var invert := false
## Se vero, una volta aperta del tutto resta aperta.
@export var stay_open := false
@export var size := Vector3(2.0, 2.6, 0.2):
	set(value):
		size = value
		_rebuild()
## Spostamento del pannello quando è aperta (spazio locale).
@export var open_offset := Vector3(0, 2.5, 0)
## Velocità di apertura e chiusura (frazione al secondo).
@export var open_speed := 0.8
@export var close_speed := 0.45
## Non chiudere se il vano è occupato (giocatore, nemici, oggetti).
@export var safety_check := true

## 0 = chiusa, 1 = aperta.
var open_amount := 0.0
var is_open := false

var _latched := false
var _vis: Node3D
var _panel: AnimatableBody3D
var _lamp_mesh: MeshInstance3D
var _lamp_closed: StandardMaterial3D
var _lamp_open: StandardMaterial3D
var _query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group(&"persist")


func save_state() -> Dictionary:
	return {"latched": _latched, "open": open_amount}


func load_state(data: Dictionary) -> void:
	_latched = bool(data.get("latched", false))
	open_amount = float(data.get("open", 0.0))
	is_open = open_amount >= 1.0
	_panel.position = Vector3(0, size.y * 0.5, 0) + open_offset * _ease(open_amount)
	_lamp_mesh.material_override = _lamp_open if is_open else _lamp_closed
	_panel.reset_physics_interpolation()


func should_open() -> bool:
	if _latched:
		return true
	var p := PowerSource.any_powered(sources) if logic == Logic.ANY else PowerSource.all_powered(sources)
	return p != invert


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target := 1.0 if should_open() else 0.0
	if target < open_amount and safety_check and _doorway_blocked():
		target = open_amount
	var speed := open_speed if target > open_amount else close_speed
	var before := open_amount
	open_amount = move_toward(open_amount, target, speed * delta)
	if open_amount != before:
		_panel.position = Vector3(0, size.y * 0.5, 0) + open_offset * _ease(open_amount)
	if open_amount >= 1.0 and not is_open:
		is_open = true
		if stay_open:
			_latched = true
		_lamp_mesh.material_override = _lamp_open
		opened.emit()
		open_changed.emit(true)
	elif open_amount <= 0.0 and is_open:
		is_open = false
		_lamp_mesh.material_override = _lamp_closed
		closed.emit()
		open_changed.emit(false)
	elif open_amount > 0.0 and open_amount < 1.0:
		_lamp_mesh.material_override = _lamp_open if target > 0.5 else _lamp_closed


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Vero se nel vano chiuso c'è qualcosa (giocatore, nemici, oggetti fisici).
func _doorway_blocked() -> bool:
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(size.x - 0.05, size.y - 0.05, size.z + 0.3)
		_query.shape = shape
		_query.collision_mask = Layers.PLAYER | Layers.ENEMIES | Layers.PROPS
	_query.transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0))
	_query.exclude = [_panel.get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(_query, 1).is_empty()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	_query = null
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	_panel = AnimatableBody3D.new()
	_panel.name = "Pannello"
	_panel.collision_layer = Layers.WORLD
	_panel.collision_mask = 0
	_panel.position = Vector3(0, size.y * 0.5, 0) + open_offset * _ease(open_amount)
	_vis.add_child(_panel)
	Graybox.box(_panel, size, Vector3.ZERO, Graybox.DARK)
	Graybox.box_shape(_panel, size)
	# Fasce di riconoscimento sul pannello.
	Graybox.box(_panel, Vector3(size.x * 0.9, 0.12, size.z + 0.02), Vector3(0, size.y * 0.25, 0), Graybox.TARGET)
	_lamp_closed = Graybox.lamp_material(Color(1.0, 0.15, 0.1), 2.0)
	_lamp_open = Graybox.lamp_material(Color(0.3, 1.0, 0.35), 2.0)
	_lamp_mesh = Graybox.box(_vis, Vector3(0.18, 0.12, 0.08), Vector3(size.x * 0.5 + 0.25, size.y - 0.3, size.z * 0.5 + 0.06), _lamp_open if is_open else _lamp_closed, "Spia")
