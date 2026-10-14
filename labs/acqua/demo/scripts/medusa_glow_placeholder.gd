extends Node3D
## SEGNAPOSTO: campana luminosa sott'acqua per mostrare la luce rosa della medusa che si diffonde
## nell'acqua (WaterGlowLight). Il modello vero arriva dal ramo della medusa: bastera' aggiungergli
## una WaterGlowLight dentro la campana.

const BELL_SHADER := preload("res://demo/shaders/bell_placeholder.gdshader")

@export var radius := 0.32
@export var glow_color := Color(1.0, 0.36, 0.78)
@export var light_energy := 2.2

var light: WaterGlowLight
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	var bell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 1.3
	sm.is_hemisphere = true
	sm.radial_segments = 32
	sm.rings = 12
	bell.mesh = sm
	_mat = ShaderMaterial.new()
	_mat.shader = BELL_SHADER
	_mat.set_shader_parameter("glow_color", glow_color)
	bell.material_override = _mat
	bell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bell)
	light = WaterGlowLight.new()
	light.light_color = glow_color
	light.light_energy = light_energy
	light.omni_range = 6.0
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.glow_strength = 4.0
	light.glow_radius = 5.0
	light.light_volumetric_fog_energy = 0.0
	light.position = Vector3(0, radius * 0.3, 0)
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	# la campana pulsa piano, come una medusa vera
	var p := 0.85 + 0.15 * sin(_t * 2.1) + 0.05 * sin(_t * 5.3)
	_mat.set_shader_parameter("pulse", p)
	light.light_energy = light_energy * p
	scale = Vector3(1.0 + 0.05 * sin(_t * 2.1), 1.0 - 0.06 * sin(_t * 2.1), 1.0 + 0.05 * sin(_t * 2.1))
