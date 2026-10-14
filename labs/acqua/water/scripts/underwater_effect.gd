class_name UnderwaterEffect
extends Node3D
## Effetto sott'acqua per la camera: va messo come figlio della Camera3D del giocatore.
## Attiva il quad a schermo intero (underwater_post.gdshader) quando la camera e' sotto il pelo
## dell'acqua o vicina alla superficie, aggiunge le bollicine intorno alla camera, fa lo schizzo
## quando la camera attraversa la superficie e le gocce sull'obiettivo quando riemerge.

signal entered_water
signal exited_water

const POST_SHADER := preload("res://water/shaders/underwater_post.gdshader")
const BUBBLE_SHADER := preload("res://water/shaders/bubble_particle.gdshader")

## Durata delle gocce sull'obiettivo dopo essere riemersi (s).
@export var lens_wet_time := 2.2
@export var bubbles := true

var is_underwater := false
var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _bubbles: GPUParticles3D
var _lens_wet := 0.0


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = POST_SHADER
	_mat.render_priority = Material.RENDER_PRIORITY_MIN
	_quad = MeshInstance3D.new()
	_quad.name = "UnderwaterQuad"
	_quad.mesh = QuadMesh.new()
	_quad.material_override = _mat
	_quad.extra_cull_margin = 16384.0
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.layers = 1
	_quad.visible = false
	add_child(_quad)
	if bubbles:
		_bubbles = _make_bubbles()
		add_child(_bubbles)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var wb = WaterManager.get_body_at(p)
	var under := false
	var near_surface := false
	if wb and not wb.is_empty():
		var h: float = wb.get_surface_height(p)
		under = p.y < h
		near_surface = absf(p.y - h) < 0.6
		var st: WaterStyle = wb.style if wb.style else WaterStyle.new()
		_mat.set_shader_parameter("distortion", st.underwater_distortion)
		_mat.set_shader_parameter("density", st.underwater_density)
	if under != is_underwater:
		is_underwater = under
		if wb:
			wb.splash(p, 0.5)
		if under:
			entered_water.emit()
		else:
			_lens_wet = 1.0
			exited_water.emit()
	_lens_wet = maxf(0.0, _lens_wet - delta / lens_wet_time)
	_mat.set_shader_parameter("lens_wet", _lens_wet)
	_mat.set_shader_parameter("camera_near", cam.near)
	_quad.visible = under or near_surface or _lens_wet > 0.0
	if _bubbles:
		_bubbles.emitting = under
		_bubbles.global_position = p


func _make_bubbles() -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = "Bubbles"
	gp.amount = 80
	gp.lifetime = 3.0
	gp.local_coords = false
	gp.emitting = false
	gp.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.0, 1.2, 2.0)
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.35, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.4
	pm.scale_max = 1.3
	gp.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.025)
	var mat := ShaderMaterial.new()
	mat.shader = BUBBLE_SHADER
	qm.material = mat
	gp.draw_pass_1 = qm
	return gp
