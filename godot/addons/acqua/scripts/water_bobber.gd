class_name WaterBobber
extends Node3D
## Oggetto galleggiante decorativo senza fisica (ciambelle, giocattoli): segue il pelo
## dell'acqua con un leggero dondolio, viene trascinato da gorghi e aspirazione, resta dentro la
## vasca. Se la vasca si svuota si appoggia alla quota `rest_y`.
## Per oggetti che devono rimbalzare e cadere davvero usare un RigidBody3D con WaterFloater.

## Quanto affonda l'oggetto sotto il pelo dell'acqua (m).
@export var draft := 0.05
@export var bob_amount := 0.02
@export var tilt_amount := 5.0
## Deriva lenta casuale (m/s).
@export var drift_speed := 0.03
## Distanza minima dai bordi della vasca (m).
@export var margin := 0.5
## Quota a cui si appoggia se la vasca e' vuota.
@export var rest_y := -100.0

var _body: Node
var _vel := Vector2.ZERO
var _phase := 0.0
var _drift_dir := Vector2.RIGHT


func _ready() -> void:
	_phase = randf() * TAU
	_drift_dir = Vector2.from_angle(randf() * TAU)


func _physics_process(delta: float) -> void:
	var wm := get_node_or_null("/root/WaterManager")
	if wm == null:
		return
	var p := global_position
	if _body == null or not is_instance_valid(_body):
		_body = wm.get_body_at(p, 0.5)
		if _body == null:
			return
	var t: float = wm.time
	var flow: Vector2 = _body.get_flow_velocity(p)
	_drift_dir = _drift_dir.rotated((sin(t * 0.13 + _phase) * 0.3) * delta)
	var target_v := flow + _drift_dir * drift_speed
	_vel = _vel.lerp(target_v, clampf(delta * 1.5, 0.0, 1.0))
	p.x += _vel.x * delta
	p.z += _vel.y * delta
	var r: Rect2 = _body.get_rect()
	p.x = clampf(p.x, r.position.x + margin, r.end.x - margin)
	p.z = clampf(p.z, r.position.y + margin, r.end.y - margin)
	var surf: float = _body.get_surface_height(p)
	var y := surf - draft + sin(t * 1.4 + _phase) * bob_amount
	# il fondo sotto l'oggetto: quando l'acqua si ritira l'oggetto si appoggia
	_floor_t -= delta
	if _floor_t <= 0.0:
		_floor_t = 0.4
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 6.0)
		var hit := RaggioSicuro.interseca(get_world_3d().direct_space_state, q)
		_floor_y = hit.position.y if hit else rest_y
	var floor_y := maxf(_floor_y, rest_y) + draft * 0.6
	var grounded: bool = _body.is_empty() or y < floor_y
	y = maxf(y, floor_y)
	p.y = lerpf(p.y, y, clampf(delta * 4.0, 0.0, 1.0))
	global_position = p
	var tilt := 0.25 if grounded else 1.0
	rotation_degrees.x = sin(t * 1.1 + _phase) * tilt_amount * tilt
	rotation_degrees.z = cos(t * 0.9 + _phase * 1.3) * tilt_amount * tilt
	if not grounded:
		rotation.y += (flow.length() * 0.8 + 0.02) * delta


var _floor_t := 0.0
var _floor_y := -100.0
