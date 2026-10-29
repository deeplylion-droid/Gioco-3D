class_name Gocce
extends Node3D
## Gocce che cadono dal soffitto in un punto, con lo schizzo a terra.
## Le gocce sono poche e mosse da codice, così il segnale "goccia_caduta" arriva
## esattamente quando toccano terra (per il suono "plic").

signal goccia_caduta(posizione: Vector3)

@export var intervallo_min := 0.6
@export var intervallo_max := 2.2
@export var raggio := 0.04
## Altezza della caduta. Se 0, la misura con un raggio verso il basso.
@export var altezza := 0.0

var _gocce: Array[MeshInstance3D] = []
var _velocita: Array[float] = []
var _spruzzi: GPUParticles3D
var _attesa := 0.0


func _ready() -> void:
	if altezza <= 0.0:
		altezza = _misura_altezza()
	var q := QuadMesh.new()
	q.size = Vector2(0.01, 0.07)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_color = Color(0.85, 0.9, 0.95, 0.6)
	mat.albedo_texture = PunteggioMorbido.texture()
	mat.roughness = 0.05
	mat.rim_enabled = true
	mat.rim = 0.7
	mat.backlight_enabled = true
	mat.backlight = Color(0.7, 0.7, 0.7)
	q.material = mat
	for k in 4:
		var g := MeshInstance3D.new()
		g.mesh = q
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visible = false
		add_child(g)
		_gocce.append(g)
		_velocita.append(0.0)
	_spruzzi = GPUParticles3D.new()
	_spruzzi.amount = 10
	_spruzzi.lifetime = 0.4
	_spruzzi.one_shot = true
	_spruzzi.explosiveness = 1.0
	_spruzzi.emitting = false
	_spruzzi.position.y = -altezza + 0.01
	_spruzzi.visibility_aabb = AABB(Vector3(-0.5, -0.1, -0.5), Vector3(1, 0.6, 1))
	var ms := ParticleProcessMaterial.new()
	ms.direction = Vector3.UP
	ms.spread = 50.0
	ms.initial_velocity_min = 0.5
	ms.initial_velocity_max = 1.2
	ms.gravity = Vector3(0, -9.8, 0)
	ms.scale_min = 0.5
	ms.scale_max = 1.0
	_spruzzi.process_material = ms
	var qs := QuadMesh.new()
	qs.size = Vector2(0.012, 0.012)
	var mats := mat.duplicate() as StandardMaterial3D
	mats.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qs.material = mats
	_spruzzi.draw_pass_1 = qs
	_spruzzi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spruzzi)
	_attesa = randf_range(0.0, intervallo_max)


func _process(delta: float) -> void:
	_attesa -= delta
	if _attesa <= 0.0:
		_attesa = randf_range(intervallo_min, intervallo_max)
		for k in _gocce.size():
			if not _gocce[k].visible:
				_gocce[k].position = Vector3(randf_range(-raggio, raggio), 0, randf_range(-raggio, raggio))
				_gocce[k].visible = true
				_velocita[k] = 0.0
				break
	for k in _gocce.size():
		var g := _gocce[k]
		if not g.visible:
			continue
		_velocita[k] = minf(_velocita[k] + 9.8 * delta, 9.0)
		g.position.y -= _velocita[k] * delta
		if g.position.y <= -altezza:
			g.visible = false
			_spruzzi.position = Vector3(g.position.x, -altezza + 0.01, g.position.z)
			_spruzzi.restart()
			goccia_caduta.emit(_spruzzi.global_position)


func _misura_altezza() -> float:
	var spazio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 50.0)
	# (senza passare dalle crepe fra due triangoli: le gocce cadrebbero attraverso il pavimento)
	var r := RaggioSicuro.interseca(spazio, q)
	return global_position.y - r.position.y if r else 3.0
