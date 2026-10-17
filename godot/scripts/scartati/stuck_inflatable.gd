class_name StuckInflatable
extends RigidBody3D
## Gonfiabile incastrato (per esempio nella turbina dello scarico): resta fermo finché il
## getto non lo colpisce abbastanza, poi cade e sblocca la turbina collegata.
## Serve un WaterHitbox tra i figli.

signal released

## La turbina che blocca finché resta incastrato.
@export var jams: Turbine
## Litri d'acqua che servono per farlo cadere.
@export var liters_to_free := 0.8

var _received := 0.0


func _ready() -> void:
	freeze = true
	if jams:
		jams.jammed = true
	for c in get_children():
		if c is WaterHitbox:
			(c as WaterHitbox).water_hit.connect(_on_water_hit)
	add_to_group(&"persist")


func is_stuck() -> bool:
	return freeze


func _on_water_hit(amount: float, _point: Vector3, direction: Vector3) -> void:
	if not freeze:
		return
	_received += amount
	if _received >= liters_to_free:
		release(direction)


func release(direction := Vector3.ZERO) -> void:
	if not freeze:
		return
	freeze = false
	apply_central_impulse(direction * mass * 1.5 + Vector3.UP * mass * 0.5)
	if jams:
		jams.jammed = false
	released.emit()


func save_state() -> Dictionary:
	var p := global_position
	return {"stuck": freeze, "pos": [p.x, p.y, p.z]}


func load_state(data: Dictionary) -> void:
	if bool(data.get("stuck", true)):
		return
	freeze = false
	if jams:
		jams.jammed = false
	var p: Array = data.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
		reset_physics_interpolation()
