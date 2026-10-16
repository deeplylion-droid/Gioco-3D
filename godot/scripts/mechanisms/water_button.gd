@tool
class_name WaterButton
extends PowerSource
## Pulsante da colpire col getto d'acqua.
## Modalità: MOMENTARY (acceso mentre lo colpisci, più hold_time), TOGGLE (ogni colpo
## accende/spegne), LATCH (una volta acceso resta acceso).
## Guarda verso +Z. La grafica è provvisoria (graybox).

signal pressed
signal released

enum Mode { MOMENTARY, TOGGLE, LATCH }

@export var mode := Mode.TOGGLE
## Litri d'acqua necessari per premerlo.
@export var liters_to_press := 0.5
## Pressione persa al secondo quando non è colpito (litri/s).
@export var pressure_decay := 1.5
## Solo MOMENTARY: secondi in cui resta acceso dopo l'ultimo colpo.
@export var hold_time := 1.5
@export var radius := 0.22:
	set(value):
		radius = value
		_rebuild()
## Se falso non disegna il pulsante (quando è già nel modello dell'ambiente): resta il bersaglio.
@export var show_model := true:
	set(value):
		show_model = value
		_rebuild()

var pressure := 0.0
var is_pressed := false

var _hold_left := 0.0
var _vis: Node3D
var _cap: Node3D
var _cap_mat_off: Material
var _cap_mat_on: StandardMaterial3D
var _cap_mesh: MeshInstance3D
var _hitbox: WaterHitbox


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_hitbox.water_hit.connect(_on_water_hit)
	powered_changed.connect(_on_powered_changed)
	add_to_group(&"persist")


func save_state() -> Dictionary:
	return {"powered": powered}


func load_state(data: Dictionary) -> void:
	powered = bool(data.get("powered", powered))
	pressure = 0.0
	is_pressed = false


func _on_water_hit(amount: float, _point: Vector3, _direction: Vector3) -> void:
	pressure = minf(pressure + amount, liters_to_press * 1.5)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	pressure = maxf(0.0, pressure - pressure_decay * delta)
	if not is_pressed and pressure >= liters_to_press:
		is_pressed = true
		match mode:
			Mode.MOMENTARY, Mode.LATCH:
				powered = true
			Mode.TOGGLE:
				powered = not powered
		pressed.emit()
	elif is_pressed and pressure <= liters_to_press * 0.25:
		is_pressed = false
		_hold_left = hold_time
		released.emit()
	if mode == Mode.MOMENTARY and powered and not is_pressed:
		_hold_left -= delta
		if _hold_left <= 0.0:
			powered = false
	# Il tappo rientra quando è premuto.
	var target_z := 0.06 if is_pressed else 0.12
	_cap.position.z = move_toward(_cap.position.z, target_z, delta * 0.6)


func _on_powered_changed(on: bool) -> void:
	if _cap_mesh:
		_cap_mesh.material_override = _cap_mat_on if on else _cap_mat_off


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	_cap = Node3D.new()
	_cap.position = Vector3(0, 0, 0.12)
	_vis.add_child(_cap)
	_cap_mesh = null
	if show_model:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		_vis.add_child(body)
		# Pulsantone da giocattolo: cornice gialla e tappo rosso, che si accende di giallo.
		var plate := Vector3(radius * 3.0, radius * 3.0, 0.08)
		var frame := StandardMaterial3D.new()
		frame.albedo_color = Color(0.95, 0.72, 0.12)
		frame.roughness = 0.45
		Graybox.box(body, plate, Vector3(0, 0, 0.04), frame)
		Graybox.box_shape(body, plate, Vector3(0, 0, 0.04))
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.8, 0.08, 0.06)
		red.roughness = 0.25
		red.clearcoat_enabled = true
		_cap_mat_off = red
		_cap_mat_on = Graybox.lamp_material(Color(1.0, 0.9, 0.45), 2.5)
		_cap_mesh = Graybox.cylinder(_cap, radius, 0.1, Vector3.ZERO, _cap_mat_on if powered else _cap_mat_off)
		_cap_mesh.rotation = Vector3(PI * 0.5, 0, 0)
	_hitbox = WaterHitbox.new()
	_hitbox.name = "Bersaglio"
	_vis.add_child(_hitbox)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 1.5
	shape.height = 0.3
	cs.shape = shape
	cs.position = Vector3(0, 0, 0.15)
	cs.rotation = Vector3(PI * 0.5, 0, 0)
	_hitbox.add_child(cs)
