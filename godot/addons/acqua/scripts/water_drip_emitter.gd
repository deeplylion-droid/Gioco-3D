class_name WaterDripEmitter
extends Node3D
## Gocce che cadono dal soffitto (o da un tubo) a intervalli irregolari. Ogni goccia, nel punto
## esatto in cui cade, fa un cerchio nella pozzanghera (WaterManager.add_drop_ring) oppure
## un'increspatura nella vasca, con un minuscolo schizzo.

@export var interval_min := 0.7
@export var interval_max := 2.6
## Variazione casuale del punto di caduta (m).
@export var jitter := 0.03
## Dimensione della goccia (larghezza, lunghezza).
@export var drop_size := Vector2(0.012, 0.045)

const MAX_DROPS := 6
const GRAVITY := 9.8

var _timer := 0.0
var _drops: Array = []   # [mesh, velocita', quota d'impatto, tipo, vasca]
var _splash: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(name) ^ int(global_position.x * 100.0) ^ int(global_position.z * 37.0)
	_timer = _rng.randf_range(0.0, interval_max)
	for i in MAX_DROPS:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = drop_size
		qm.material = WaterParticles.droplet_material()
		mi.mesh = qm
		mi.visible = false
		mi.top_level = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_drops.append([mi, 0.0, 0.0, 0, null])
	_splash = WaterParticles.make_droplets(10, 0.35, Vector2(0.008, 0.02))
	var pm: ParticleProcessMaterial = _splash.process_material
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.3
	_splash.one_shot = true
	_splash.explosiveness = 1.0
	_splash.emitting = false
	_splash.top_level = true
	add_child(_splash)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(interval_min, interval_max)
		_spawn()
	for d in _drops:
		var mi: MeshInstance3D = d[0]
		if not mi.visible:
			continue
		d[1] += GRAVITY * delta
		mi.global_position.y -= d[1] * delta
		if mi.global_position.y <= d[2]:
			mi.visible = false
			_impact(Vector3(mi.global_position.x, d[2], mi.global_position.z), d[3], d[4])


func _spawn() -> void:
	for d in _drops:
		var mi: MeshInstance3D = d[0]
		if mi.visible:
			continue
		var origin := global_position + Vector3(_rng.randf_range(-jitter, jitter), 0.0, _rng.randf_range(-jitter, jitter))
		var hit_y := origin.y - 40.0
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, -40, 0))
		var hit := space.intersect_ray(q)
		if hit:
			hit_y = hit.position.y
		var kind := 0
		var wm := get_node_or_null("/root/WaterManager")
		var wb: Node = wm.get_body_at(origin) if wm else null
		if wb and not wb.is_empty() and wb.level > hit_y:
			hit_y = wb.level
			kind = 1
		mi.global_position = origin
		mi.visible = true
		d[1] = 0.0
		d[2] = hit_y
		d[3] = kind
		d[4] = wb
		return


func _impact(p: Vector3, kind: int, wb: Node) -> void:
	var wm := get_node_or_null("/root/WaterManager")
	if kind == 1 and wb and is_instance_valid(wb):
		wb.add_impulse(p, 0.035, -0.0035, 0.015)
	elif wm:
		wm.add_drop_ring(p, 1.0)
	_splash.global_position = p + Vector3(0, 0.01, 0)
	_splash.restart()
