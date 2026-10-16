class_name ReservoirGauge
extends Node3D
## Finestrella del serbatoio sulla pistola ad acqua: un cilindro di plastica trasparente con
## dentro l'acqua che sale e scende insieme al serbatoio dello zaino. Il pelo dell'acqua resta
## orizzontale (shader liquid_fill). Va messo dentro la scena della lancia: trova da solo lo
## zaino del giocatore. Il cilindro è lungo l'asse Z del nodo (orizzontale) o lungo Y.

@export var length := 0.12
@export var radius := 0.02
## Se vero il cilindro è orizzontale (lungo Z), altrimenti verticale (lungo Y).
@export var horizontal := true
@export var water_color := Color(0.32, 0.72, 0.95, 0.88)
@export var plastic_color := Color(0.75, 0.95, 1.0, 0.22)

var fill := 1.0

var _water_mat: ShaderMaterial
var _pack: WaterPack
var _shown := 1.0


func _ready() -> void:
	var rot := Vector3(PI * 0.5, 0, 0) if horizontal else Vector3.ZERO
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = plastic_color
	plastic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plastic.roughness = 0.12
	plastic.metallic_specular = 0.9
	plastic.rim_enabled = true
	plastic.rim = 0.4
	_add_cylinder(radius, length, rot, plastic)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/liquid_fill.gdshader")
	_water_mat.set_shader_parameter(&"color", water_color)
	_add_cylinder(radius * 0.82, length * 0.94, rot, _water_mat)
	# Tappi colorati alle estremità, come sui giocattoli.
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.98, 0.55, 0.12)
	cap_mat.roughness = 0.45
	for side in [-1.0, 1.0]:
		var cap := _add_cylinder(radius * 1.18, 0.012, rot, cap_mat)
		cap.position = (Vector3(0, 0, side) if horizontal else Vector3(0, side, 0)) * length * 0.5
	_find_pack.call_deferred()


func _add_cylinder(r: float, h: float, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 24
	mi.mesh = m
	mi.rotation = rot
	mi.material_override = mat
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _find_pack() -> void:
	var n := get_parent()
	while n and not (n is Player):
		n = n.get_parent()
	if n:
		_pack = (n as Player).water_pack
	if _pack:
		_pack.tank_changed.connect(_on_tank_changed)
		_on_tank_changed(_pack.tank_amount, _pack.tank_capacity)
		_shown = fill


func _on_tank_changed(amount: float, capacity: float) -> void:
	fill = clampf(amount / maxf(capacity, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	if _pack:
		visible = _pack.tank_indicator == WaterPack.TankIndicator.LANCE
	# Il livello segue il serbatoio con un po' di morbidezza (niente scatti).
	_shown = lerpf(_shown, fill, 1.0 - exp(-8.0 * delta))
	var half := radius * 0.82 if horizontal else length * 0.47
	var center_y := global_position.y
	var level := center_y - half + 2.0 * half * _shown
	if _shown <= 0.002:
		level = center_y - 10.0
	_water_mat.set_shader_parameter(&"level_y", level)
