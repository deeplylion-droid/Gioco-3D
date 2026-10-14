class_name WaterJet
extends Node3D
## Getto d'acqua della lancia dello zaino-pompa (o di un idrante): spara lungo -Z del nodo.
## - getto fatto di gocce allungate con la parabola vera (gravita');
## - nel punto d'impatto (trovato con raycast lungo la parabola): se e' acqua, increspature e
##   schiuma continue e spruzzo; se e' una parete o il pavimento, ventaglio di spruzzi riflesso
##   dalla superficie, nebbiolina e cerchi nelle pozzanghere;
## - segnale `hit` per il gioco (turbine, pulsanti, respingere la mascotte).
## Se `suction` e' impostato, consuma il suo serbatoio (zaino-pompa versione Z1).

signal hit(collider: Object, position: Vector3, normal: Vector3)

@export var active := false
## Velocita' dell'acqua all'uscita (m/s).
@export var speed := 11.0
## Portata (m^3/s) presa dal serbatoio se c'e' un WaterSuction collegato.
@export var flow_rate := 0.05
@export var suction: WaterSuction
@export var stream_width := 0.035

var impact_point := Vector3.ZERO
var impact_normal := Vector3.UP
var impact_body: Node = null

var _stream: GPUParticles3D
var _spray: GPUParticles3D
var _mist: GPUParticles3D
var _impulse_t := 0.0
var _ring_t := 0.0


func _ready() -> void:
	_stream = WaterParticles.make_droplets(420, 1.4, Vector2(stream_width, stream_width * 3.0))
	var pm: ParticleProcessMaterial = _stream.process_material
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 1.2
	pm.initial_velocity_min = speed * 0.97
	pm.initial_velocity_max = speed * 1.03
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = stream_width * 0.5
	pm.damping_min = 0.0
	pm.damping_max = 0.2
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_stream.local_coords = false
	_stream.emitting = false
	_stream.collision_base_size = 0.02
	add_child(_stream)
	_spray = WaterParticles.make_droplets(160, 0.7, Vector2(0.014, 0.04))
	var sp: ParticleProcessMaterial = _spray.process_material
	sp.spread = 55.0
	sp.initial_velocity_min = 1.5
	sp.initial_velocity_max = 4.0
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.06
	_spray.top_level = true
	_spray.emitting = false
	add_child(_spray)
	_mist = WaterParticles.make_mist(24, 1.3, 0.45)
	var mm: ParticleProcessMaterial = _mist.process_material
	mm.spread = 80.0
	mm.initial_velocity_min = 0.3
	mm.initial_velocity_max = 1.2
	_mist.top_level = true
	_mist.emitting = false
	add_child(_mist)


func _physics_process(delta: float) -> void:
	var can_fire := active
	if active and suction:
		can_fire = suction.take_from_tank(flow_rate * delta) > 0.0
	_stream.emitting = can_fire
	if not can_fire:
		_spray.emitting = false
		_mist.emitting = false
		impact_body = null
		return
	_trace()
	_spray.global_position = impact_point
	_mist.global_position = impact_point
	var sp: ParticleProcessMaterial = _spray.process_material
	var v_in := _velocity_at_impact()
	# ventaglio: direzione riflessa dalla superficie colpita
	var refl := v_in.normalized().bounce(impact_normal).normalized()
	sp.direction = (refl + impact_normal * 0.6).normalized()
	_spray.emitting = true
	_mist.emitting = true
	var mm: ParticleProcessMaterial = _mist.process_material
	mm.direction = impact_normal
	_impulse_t -= delta
	_ring_t -= delta
	if impact_body:
		if _impulse_t <= 0.0:
			_impulse_t = 0.03
			impact_body.add_impulse(impact_point, 0.18, -0.02, 0.45)
	elif _ring_t <= 0.0:
		_ring_t = 0.09
		var wm := get_node_or_null("/root/WaterManager")
		if wm and impact_normal.y > 0.7:
			wm.add_drop_ring(impact_point + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 1.5)


var _hit_time := 0.0


func _velocity_at_impact() -> Vector3:
	var v0 := -global_basis.z.normalized() * speed
	return v0 + Vector3(0, -9.8, 0) * _hit_time


## Segue la parabola a segmenti e trova il primo impatto con la fisica o con il pelo dell'acqua.
func _trace() -> void:
	var p := global_position
	var v := -global_basis.z.normalized() * speed
	var space := get_world_3d().direct_space_state
	var wm := get_node_or_null("/root/WaterManager")
	var dt := 0.04
	var t := 0.0
	impact_body = null
	for i in 60:
		var np := p + v * dt + Vector3(0, -0.5 * 9.8 * dt * dt, 0)
		var nv := v + Vector3(0, -9.8 * dt, 0)
		# acqua?
		if wm:
			var b: Node = wm.get_body_at(np)
			if b and not b.is_empty() and p.y >= b.level and np.y < b.level:
				var k: float = (p.y - b.level) / maxf(p.y - np.y, 1e-4)
				impact_point = p.lerp(np, k)
				impact_normal = Vector3.UP
				impact_body = b
				_hit_time = t + dt * k
				hit.emit(b, impact_point, impact_normal)
				return
		var q := PhysicsRayQueryParameters3D.create(p, np)
		var res := space.intersect_ray(q)
		if res:
			impact_point = res.position
			impact_normal = res.normal
			_hit_time = t
			hit.emit(res.collider, impact_point, impact_normal)
			return
		p = np
		v = nv
		t += dt
	impact_point = p
	impact_normal = Vector3.UP
	_hit_time = t
