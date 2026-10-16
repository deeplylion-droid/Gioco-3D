class_name WaterFloater
extends Node
## Da aggiungere come figlio di un oggetto (RigidBody3D o qualsiasi Node3D, anche animato:
## giocatore, mascotte, galleggianti). Fa:
## - schizzo quando l'oggetto entra in acqua (o ne esce velocemente);
## - scia di increspature quando si muove attraverso la superficie;
## - galleggiamento e attrito dell'acqua se il genitore e' un RigidBody3D.

## Raggio approssimativo dell'oggetto (m).
@export var radius := 0.15
## Spinta di galleggiamento rispetto al peso (>1 galleggia).
@export var buoyancy := 1.8
@export var water_drag := 2.5
@export var splash_on_enter := true
@export var splash_on_exit := true
@export var wake := true
## Moltiplicatore di schizzi e scie (la mascotte puo' volerne di piu').
@export var effect_scale := 1.0

var in_water := false
var _body: Node3D
var _prev_pos := Vector3.ZERO
var _wake_t := 0.0


func _ready() -> void:
	_body = get_parent() as Node3D
	if _body:
		_prev_pos = _body.global_position


func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var p := _body.global_position
	var vel := (p - _prev_pos) / maxf(delta, 1e-4)
	_prev_pos = p
	var rb := _body as RigidBody3D
	if rb:
		vel = rb.linear_velocity
	var wm := get_node_or_null("/root/WaterManager")
	var wb = wm.get_body_at(p) if wm else null
	if wb == null or wb.is_empty():
		in_water = false
		return
	var surf: float = wb.get_surface_height(p)
	var depth := surf - (p.y - radius)
	var submerged := clampf(depth / (2.0 * radius), 0.0, 1.0)
	if rb and submerged > 0.0:
		var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		rb.apply_central_force(Vector3.UP * rb.mass * g * buoyancy * submerged)
		# l'acqua trascina l'oggetto verso la propria velocita' (gorghi, aspirazione)
		var fv: Vector2 = wb.get_flow_velocity(p)
		var rel := vel - Vector3(fv.x, 0.0, fv.y)
		rb.apply_central_force(-rel * water_drag * submerged * rb.mass)
		rb.apply_torque(-rb.angular_velocity * 0.05 * submerged * rb.mass + Vector3.UP * fv.length() * 0.02 * rb.mass)
	var now_in := submerged > 0.04
	var size_k := clampf(radius / 0.15, 0.3, 4.0) * effect_scale
	if now_in and not in_water and splash_on_enter:
		var strength := clampf(-vel.y / 4.0, 0.12, 2.0) * size_k
		wb.splash(Vector3(p.x, surf, p.z), strength)
	elif not now_in and in_water and splash_on_exit and vel.y > 1.0:
		wb.splash(Vector3(p.x, surf, p.z), clampf(vel.y / 6.0, 0.1, 1.0) * size_k)
	in_water = now_in
	# scia: impulsi piccoli e frequenti mentre l'oggetto taglia la superficie
	if wake and submerged > 0.0 and submerged < 1.0:
		var hv := Vector2(vel.x, vel.z).length()
		_wake_t -= delta
		if hv > 0.15 and _wake_t <= 0.0:
			_wake_t = 0.05
			wb.add_impulse(p, radius * 1.4, -0.006 * minf(hv, 3.0) * size_k, 0.06 * minf(hv, 2.0))
