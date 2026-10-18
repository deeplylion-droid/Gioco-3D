class_name SlideFx
extends Node3D
## Gli schizzi della scivolata (sala della torre): mentre il giocatore scivola, ai piedi l'acqua
## dello scivolo si apre in due ventagli di gocce ai lati e un velo di spruzzo, tanto più forti
## quanto più si va veloci; atterrando su uno scivolo, una corona di schizzi tutt'intorno.
## Lo crea il giocatore (Player._ready) e legge da lui lo stato a ogni passo di fisica.

const GOCCIA_CHIARA := preload("res://addons/grafica/goccia_chiara.gdshader")
## Velocità a cui gli schizzi sono pieni (m/s).
const PIENO := 12.0

var player: Player
var _lati: Array[GPUParticles3D] = []
var _velo: GPUParticles3D
var _corona: GPUParticles3D


func _init(p: Player) -> void:
	player = p
	name = "SlideFx"


func _ready() -> void:
	var chiara := ShaderMaterial.new()
	chiara.shader = GOCCIA_CHIARA
	chiara.set_shader_parameter(&"tint", Color(0.88, 0.94, 1.0))
	chiara.set_shader_parameter(&"opacity", 0.85)
	chiara.set_shader_parameter(&"rim_light", 0.8)
	for i in 2:
		var p := WaterParticles.make_droplets(90, 0.55, Vector2(0.022, 0.08))
		var pm: ParticleProcessMaterial = p.process_material
		pm.spread = 22.0
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 3.5
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.12
		(p.draw_pass_1 as QuadMesh).material = chiara
		_aggiungi(p)
		_lati.append(p)
	_velo = WaterParticles.make_mist(24, 0.7, 0.35)
	var vm: ParticleProcessMaterial = _velo.process_material
	vm.spread = 40.0
	vm.initial_velocity_min = 0.4
	vm.initial_velocity_max = 1.2
	_aggiungi(_velo)
	_corona = WaterParticles.make_droplets(70, 0.6, Vector2(0.025, 0.09))
	_corona.one_shot = true
	_corona.explosiveness = 0.95
	var cm: ParticleProcessMaterial = _corona.process_material
	cm.direction = Vector3.UP
	cm.spread = 70.0
	cm.initial_velocity_min = 1.5
	cm.initial_velocity_max = 4.0
	cm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	cm.emission_ring_axis = Vector3.UP
	cm.emission_ring_radius = 0.35
	cm.emission_ring_inner_radius = 0.2
	cm.emission_ring_height = 0.02
	(_corona.draw_pass_1 as QuadMesh).material = chiara
	_aggiungi(_corona)
	player.landed.connect(_su_atterraggio)


func _aggiungi(p: GPUParticles3D) -> void:
	p.top_level = true
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	add_child(p)


func _physics_process(_delta: float) -> void:
	var v := player.velocity
	var speed := v.length()
	var attivo := player.is_sliding and speed > 1.0
	for p in _lati + [_velo]:
		if p.emitting != attivo:
			p.emitting = attivo
	if not attivo:
		return
	var forza := clampf(speed / PIENO, 0.15, 1.0)
	var n := player.slide_normal
	var avanti := (v - n * v.dot(n)).normalized()
	var lato := avanti.cross(n).normalized()
	var piedi := player.global_position + avanti * 0.25 + n * 0.05
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var p := _lati[i]
		p.amount_ratio = forza
		p.global_position = piedi + lato * s * 0.28
		var pm: ParticleProcessMaterial = p.process_material
		pm.direction = (lato * s * 0.8 + n * 0.9 + avanti * 0.35).normalized()
		pm.initial_velocity_max = 1.5 + 3.0 * forza
	_velo.amount_ratio = forza
	_velo.global_position = piedi + n * 0.15
	(_velo.process_material as ParticleProcessMaterial).direction = (n + avanti * 0.5).normalized()


func _su_atterraggio(superficie: StringName, _bagnato: bool, velocita: float) -> void:
	if superficie != Player.SURFACE_SLIDE:
		return
	_corona.global_position = player.global_position + Vector3.UP * 0.05
	_corona.amount_ratio = clampf(velocita / 8.0, 0.3, 1.0)
	_corona.restart()
