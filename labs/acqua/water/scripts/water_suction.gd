class_name WaterSuction
extends Node3D
## Aspirazione dello zaino-pompa: la lancia (questo nodo, che guarda lungo -Z) aspira l'acqua
## della vasca verso cui punta. Effetti: imbuto e vortice sul punto aspirato (flusso della vasca,
## slot 1), increspature che convergono, gocce e spruzzo risucchiati verso l'ugello, livello che
## scende davvero (WaterBody.remove_volume). Il volume aspirato finisce in `tank` (m^3), che il
## getto (WaterJet) puo' consumare.

signal tank_changed(tank: float)

## Portata d'aspirazione (m^3/s).
@export var flow_rate := 0.08
## Distanza massima tra ugello e pelo dell'acqua (m).
@export var reach := 2.5
## Capacita' del serbatoio dello zaino (m^3).
@export var tank_capacity := 0.6
@export var active := false:
	set(v):
		active = v
		set_process(true)

var tank := 0.0
var target_body: Node = null
var suction_point := Vector3.ZERO

var _strength := 0.0
var _drops: GPUParticles3D
var _mist: GPUParticles3D
var _attractor: GPUParticlesAttractorSphere3D
var _ring_t := 0.0


func _ready() -> void:
	_drops = WaterParticles.make_droplets(90, 0.7, Vector2(0.012, 0.03))
	var pm: ParticleProcessMaterial = _drops.process_material
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
	_drops.emitting = false
	_drops.top_level = true
	add_child(_drops)
	_mist = WaterParticles.make_mist(14, 0.9, 0.3)
	var mm: ParticleProcessMaterial = _mist.process_material
	mm.direction = Vector3.UP
	mm.spread = 30.0
	mm.initial_velocity_min = 0.3
	mm.initial_velocity_max = 0.9
	mm.attractor_interaction_enabled = true
	_mist.emitting = false
	_mist.top_level = true
	add_child(_mist)
	# attrattore sull'ugello: le gocce vengono risucchiate dentro
	_attractor = GPUParticlesAttractorSphere3D.new()
	_attractor.radius = 3.0
	_attractor.strength = 18.0
	_attractor.attenuation = 0.6
	_attractor.top_level = true
	add_child(_attractor)


func _process(delta: float) -> void:
	var nozzle := global_position
	var dir := -global_basis.z.normalized()
	_attractor.global_position = nozzle
	var wm := get_node_or_null("/root/WaterManager")
	var body: Node = null
	var point := Vector3.ZERO
	if wm and active:
		# punto aspirato: dove la direzione della lancia incontra il pelo dell'acqua,
		# altrimenti la verticale sotto l'ugello
		var b: Node = wm.get_body_at(nozzle, 0.5)
		if b == null and dir.y < -0.05:
			for cand in wm.get_bodies():
				var tt: float = (cand.level - nozzle.y) / dir.y
				if tt > 0.0 and tt < reach and cand.contains_xz(nozzle + dir * tt):
					b = cand
					break
		if b and not b.is_empty():
			var t: float = (b.level - nozzle.y) / dir.y if dir.y < -0.05 else -1.0
			point = nozzle + dir * t if t > 0.0 and t < reach else Vector3(nozzle.x, b.level, nozzle.z)
			if nozzle.distance_to(point) <= reach and b.contains_xz(point):
				body = b
	var want := 1.0 if body != null and tank < tank_capacity else 0.0
	_strength = move_toward(_strength, want, delta * 2.5)
	if target_body and target_body != body:
		target_body.clear_flow(1)
	if body:
		target_body = body
		suction_point = point
	if target_body and is_instance_valid(target_body):
		if _strength > 0.001:
			target_body.set_flow(1, suction_point, 1.4, _strength, 0.35, 0.16, 1.2, 0.6)
			# l'acqua scende davvero e finisce nel serbatoio
			var vol := flow_rate * _strength * delta
			target_body.remove_volume(vol)
			tank = minf(tank + vol, tank_capacity)
			tank_changed.emit(tank)
			_ring_t -= delta
			if _ring_t <= 0.0:
				_ring_t = 0.12
				target_body.add_impulse(suction_point, 0.25, -0.012 * _strength, 0.15 * _strength)
		else:
			target_body.clear_flow(1)
			target_body = null
	var show := _strength > 0.2 and target_body != null
	_drops.emitting = show
	_mist.emitting = show
	if show:
		_drops.global_position = suction_point + Vector3(0, 0.02, 0)
		_mist.global_position = suction_point + Vector3(0, 0.05, 0)


## Svuota il serbatoio di `m3` (lo usa il getto). Restituisce quanto e' stato preso davvero.
func take_from_tank(m3: float) -> float:
	var v := minf(m3, tank)
	tank -= v
	tank_changed.emit(tank)
	return v
