class_name FlickerLight
extends Node
## Neon o lampada che sfarfalla. Comanda l'energia di una luce e l'emissione del suo tubo.
## Con [member start_off] parte spenta e si accende con [method turn_on] (sfarfallio d'avvio).

@export var light: Light3D
## Il tubo o la lampada visibile (con un StandardMaterial3D emissivo in material_override).
@export var mesh: GeometryInstance3D
@export var base_energy := 1.5
@export var base_emission := 3.0
## Probabilità al secondo di una raffica di sfarfallii (0 = luce fissa).
@export_range(0.0, 2.0) var flicker_rate := 0.15
## Durante gli sfarfallii scende fino a questo livello (0 = spenta).
@export_range(0.0, 1.0) var min_level := 0.0
@export var start_off := false

var is_on := true

var _burst := 0.0
var _level := 1.0
var _startup := -1.0
var _material: StandardMaterial3D


func _ready() -> void:
	if mesh and mesh.material_override is StandardMaterial3D:
		_material = (mesh.material_override as StandardMaterial3D).duplicate()
		mesh.material_override = _material
	is_on = not start_off
	_set_level(1.0 if is_on else 0.0)


func turn_on() -> void:
	if is_on:
		return
	is_on = true
	_startup = 0.0


func turn_off() -> void:
	is_on = false
	_startup = -1.0
	_set_level(0.0)


func _process(delta: float) -> void:
	if not is_on:
		return
	if _startup >= 0.0:
		# Accensione: qualche colpo, poi stabile.
		_startup += delta
		var on := fmod(_startup * 7.0, 1.0) > 0.45 or _startup > 1.1
		_set_level(1.0 if on else 0.05)
		if _startup > 1.2:
			_startup = -1.0
		return
	if _burst > 0.0:
		_burst -= delta
		_level = 1.0 if randf() > 0.5 else min_level
	else:
		_level = 1.0
		if randf() < flicker_rate * delta:
			_burst = randf_range(0.08, 0.6)
	_set_level(_level)


func _set_level(k: float) -> void:
	if light:
		light.light_energy = base_energy * k
	if _material:
		_material.emission_energy_multiplier = base_emission * k
