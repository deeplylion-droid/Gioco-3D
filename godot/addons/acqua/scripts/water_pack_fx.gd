class_name WaterPackFX
extends Node3D
## Effetti d'acqua per lo zaino-pompa del gioco (WaterPack): legge a ogni fotogramma lo stato
## dello zaino e aggiunge la grafica, senza toccarne la logica.
## - Aspirazione (is_sucking): sul punto aspirato l'acqua gira e scende in un imbuto, le
##   increspature convergono e gocce e spruzzo salgono verso la lancia.
## - Getto (is_spraying e has_hit): dove colpisce l'acqua increspature, schiuma e spruzzo;
##   dove colpisce pareti e pavimento un ventaglio di spruzzi, nebbiolina e cerchi nelle pozze.
## Va aggiunto nella scena del giocatore (o ovunque) con `pack` che punta al WaterPack.
## Se `pack` e' vuoto cerca un nodo di classe WaterPack nella scena.
##
## Lo zaino deve esporre: is_sucking, suck_point, muzzle, is_spraying, has_hit, hit_point, hit_normal.
## (Chi non usa WaterPack puo' chiamare suction() e impact() direttamente.)

@export var pack: Node
## Raggio dell'imbuto dell'aspirazione (m).
@export var suction_radius := 1.3

var _suck_drops: GPUParticles3D
var _suck_mist: GPUParticles3D
var _attractor: GPUParticlesAttractorSphere3D
var _spray: GPUParticles3D
var _mist: GPUParticles3D
var _suck_body: Node = null
var _suck_strength := 0.0
var _suck_point := Vector3.ZERO
var _manual_suck_t := 0.0
var _manual_impact_t := 0.0
var _impulse_t := 0.0
var _ring_t := 0.0


func _ready() -> void:
	_suck_drops = WaterParticles.make_droplets(90, 0.7, Vector2(0.012, 0.03))
	var pm: ParticleProcessMaterial = _suck_drops.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.45
	pm.emission_ring_inner_radius = 0.1
	pm.emission_ring_height = 0.01
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.attractor_interaction_enabled = true
	_suck_mist = WaterParticles.make_mist(14, 0.9, 0.3)
	var mm: ParticleProcessMaterial = _suck_mist.process_material
	mm.direction = Vector3.UP
	mm.spread = 30.0
	mm.initial_velocity_min = 0.3
	mm.initial_velocity_max = 0.9
	mm.attractor_interaction_enabled = true
	_attractor = GPUParticlesAttractorSphere3D.new()
	_attractor.radius = 3.0
	_attractor.strength = 18.0
	_attractor.attenuation = 0.6
	_spray = WaterParticles.make_droplets(160, 0.7, Vector2(0.014, 0.04))
	var sp: ParticleProcessMaterial = _spray.process_material
	sp.spread = 55.0
	sp.initial_velocity_min = 1.5
	sp.initial_velocity_max = 4.0
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.06
	_mist = WaterParticles.make_mist(24, 1.3, 0.45)
	var mi: ParticleProcessMaterial = _mist.process_material
	mi.spread = 80.0
	mi.initial_velocity_min = 0.3
	mi.initial_velocity_max = 1.2
	for p in [_suck_drops, _suck_mist, _attractor, _spray, _mist]:
		p.top_level = true
		if p is GPUParticles3D:
			p.emitting = false
		add_child(p)


func _find_pack() -> Node:
	for n in get_tree().root.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.get_global_name() == &"WaterPack":
			return n
	return null


func _process(delta: float) -> void:
	if pack == null or not is_instance_valid(pack):
		if Engine.get_process_frames() % 30 == 0:
			pack = _find_pack()
	var sucking := false
	var spraying := false
	if pack and is_instance_valid(pack):
		sucking = bool(pack.get("is_sucking"))
		spraying = bool(pack.get("is_spraying")) and bool(pack.get("has_hit"))
		var muzzle: Node3D = pack.get("muzzle")
		var nozzle: Vector3 = muzzle.global_position if muzzle else global_position
		if sucking:
			_drive_suction(pack.get("suck_point"), nozzle, delta)
		if spraying:
			_drive_impact(pack.get("hit_point"), pack.get("hit_normal"), delta)
	_manual_suck_t -= delta
	_manual_impact_t -= delta
	_update_suction(sucking or _manual_suck_t > 0.0, delta)
	if not spraying and _manual_impact_t <= 0.0:
		_spray.emitting = false
		_mist.emitting = false


## Effetto d'aspirazione per un fotogramma (per chi non usa WaterPack): da chiamare a ogni
## fotogramma finche' si aspira.
func suction(point: Vector3, nozzle: Vector3, delta: float) -> void:
	_manual_suck_t = 0.15
	_drive_suction(point, nozzle, delta)


## Effetto d'impatto del getto per un fotogramma (per chi non usa WaterPack).
func impact(point: Vector3, normal: Vector3, delta: float) -> void:
	_manual_impact_t = 0.15
	_drive_impact(point, normal, delta)


func _drive_suction(point: Vector3, nozzle: Vector3, _delta: float) -> void:
	_attractor.global_position = nozzle
	var wm := get_node_or_null("/root/WaterManager")
	if wm == null:
		return
	var b: Node = wm.get_body_at(point, 0.3)
	if b == null or b.is_empty():
		return
	if _suck_body and _suck_body != b and is_instance_valid(_suck_body):
		_suck_body.clear_flow(1)
	_suck_body = b
	_suck_point = Vector3(point.x, b.level, point.z)


func _update_suction(on: bool, delta: float) -> void:
	var want := 1.0 if on and _suck_body != null else 0.0
	_suck_strength = move_toward(_suck_strength, want, delta * 2.5)
	if _suck_body and is_instance_valid(_suck_body):
		if _suck_strength > 0.001:
			_suck_body.set_flow(1, _suck_point, suction_radius, _suck_strength, 0.35, 0.16, 1.2, 0.6)
			_impulse_t -= delta
			if _impulse_t <= 0.0:
				_impulse_t = 0.12
				_suck_body.add_impulse(_suck_point, 0.25, -0.012 * _suck_strength, 0.15 * _suck_strength)
		else:
			_suck_body.clear_flow(1)
			_suck_body = null
	var show := _suck_strength > 0.2 and _suck_body != null
	_suck_drops.emitting = show
	_suck_mist.emitting = show
	if show:
		_suck_drops.global_position = _suck_point + Vector3(0, 0.02, 0)
		_suck_mist.global_position = _suck_point + Vector3(0, 0.05, 0)


func _drive_impact(point: Vector3, normal: Vector3, delta: float) -> void:
	var wm := get_node_or_null("/root/WaterManager")
	var b: Node = wm.get_body_at(point, 0.05) if wm else null
	var on_water: bool = b != null and not b.is_empty() and absf(point.y - b.level) < 0.35
	_spray.global_position = point
	_mist.global_position = point
	var sp: ParticleProcessMaterial = _spray.process_material
	var n := Vector3.UP if on_water else normal.normalized()
	sp.direction = n
	(_mist.process_material as ParticleProcessMaterial).direction = n
	_spray.emitting = true
	_mist.emitting = true
	_ring_t -= delta
	if on_water:
		_impulse_t -= delta
		if _impulse_t <= 0.0:
			_impulse_t = 0.03
			b.add_impulse(Vector3(point.x, b.level, point.z), 0.18, -0.02, 0.45)
	elif _ring_t <= 0.0 and wm and n.y > 0.7:
		_ring_t = 0.09
		wm.add_drop_ring(point + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 1.5)
