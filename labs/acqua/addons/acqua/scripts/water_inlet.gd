@tool
class_name WaterInlet
extends Node3D
## Bocchetta che riempie una vasca: quando la vasca sotto di lei (WaterBody) si sta riempiendo,
## fa uscire un getto d'acqua lungo il proprio asse -Z che cade nella vasca, con increspature,
## schiuma e spruzzo nel punto d'impatto. Con `always_on` scorre sempre (fontane, perdite).

@export var always_on := false
## Velocita' dell'acqua all'uscita (m/s).
@export var exit_speed := 1.6
## Portata visiva: numero di gocce al secondo circa.
@export var drops_per_second := 160
@export var stream_width := 0.07

var _stream: GPUParticles3D
var _mist: GPUParticles3D
var _body: Node
var _impulse_t := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_stream = WaterParticles.make_droplets(int(drops_per_second * 1.1), 1.1, Vector2(stream_width * 0.6, stream_width * 1.6))
	var pm: ParticleProcessMaterial = _stream.process_material
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 4.0
	pm.initial_velocity_min = exit_speed * 0.9
	pm.initial_velocity_max = exit_speed * 1.1
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = stream_width * 0.35
	pm.damping_min = 0.0
	pm.damping_max = 0.1
	_stream.local_coords = false
	_stream.emitting = false
	add_child(_stream)
	_mist = WaterParticles.make_mist(14, 1.2, 0.35)
	var mm: ParticleProcessMaterial = _mist.process_material
	mm.direction = Vector3.UP
	mm.spread = 80.0
	mm.initial_velocity_min = 0.2
	mm.initial_velocity_max = 0.6
	_mist.emitting = false
	add_child(_mist)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _stream == null:
		return
	var origin := global_position
	var v0 := -global_basis.z.normalized() * exit_speed
	if _body == null or not is_instance_valid(_body):
		_body = _find_body(origin, v0)
	var active: bool = always_on or (_body != null and _body.is_filling())
	_stream.emitting = active
	_mist.emitting = active and _body != null and not _body.is_empty()
	if not active or _body == null:
		return
	# punto in cui il getto (parabola) incontra il pelo dell'acqua
	var level: float = _body.level
	var g := 9.8
	var dy := origin.y - level
	var t := (v0.y + sqrt(maxf(v0.y * v0.y + 2.0 * g * dy, 0.0))) / g
	var hit := origin + v0 * t + Vector3(0, -0.5 * g * t * t, 0)
	_mist.global_position = hit
	_impulse_t -= delta
	if _impulse_t <= 0.0:
		_impulse_t = 0.04
		_body.add_impulse(hit, 0.12, -0.006, 0.12)


func _find_body(origin: Vector3, v0: Vector3) -> Node:
	var wm := get_node_or_null("/root/WaterManager")
	if wm == null:
		return null
	# la vasca sotto il punto in cui cade l'acqua
	var probe := origin + Vector3(v0.x, 0.0, v0.z) * 0.4
	return wm.get_body_at(probe, 0.1)
