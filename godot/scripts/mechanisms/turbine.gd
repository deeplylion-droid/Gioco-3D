@tool
class_name Turbine
extends PowerSource
## Turbina ad acqua: gira quando il getto la colpisce e produce energia (da 0 a 1).
## È accesa ([member powered]) sopra power_on_threshold e si spegne sotto power_off_threshold,
## così una porta collegata resta aperta ancora un po' mentre la turbina rallenta.
## Guarda verso +Z: il giocatore la colpisce da quel lato. La grafica è provvisoria (graybox).

signal energy_changed(energy: float)

@export var radius := 0.75:
	set(value):
		radius = value
		_rebuild()
@export_range(2, 12) var blade_count := 6:
	set(value):
		blade_count = value
		_rebuild()
## Velocità angolare guadagnata per ogni litro d'acqua (rad/s per litro).
@export var spin_per_liter := 9.0
@export var max_angular_speed := 25.0
## Velocità angolare che vale energia 1 (rad/s).
@export var nominal_angular_speed := 14.0
## Attrito viscoso: frazione di velocità persa al secondo.
@export var friction := 0.35
## Attrito costante (rad/s²): alla fine la ferma del tutto.
@export var static_friction := 0.8
@export_range(0.0, 1.0) var power_on_threshold := 0.55
@export_range(0.0, 1.0) var power_off_threshold := 0.3

## Se vero la turbina è bloccata (per esempio da un gonfiabile incastrato) e non gira.
@export var jammed := false

var angular_speed := 0.0
var energy := 0.0

var _rotor: Node3D
var _hitbox: WaterHitbox
var _lamp_mat: StandardMaterial3D
var _vis: Node3D


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_hitbox.water_hit.connect(_on_water_hit)


func _on_water_hit(amount: float, _point: Vector3, _direction: Vector3) -> void:
	if jammed:
		return
	angular_speed = minf(angular_speed + amount * spin_per_liter, max_angular_speed)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	angular_speed = maxf(0.0, angular_speed - (angular_speed * friction + static_friction) * delta)
	_rotor.rotate_object_local(Vector3.BACK, angular_speed * delta)
	var e := clampf(angular_speed / nominal_angular_speed, 0.0, 1.0)
	if absf(e - energy) > 0.0005:
		energy = e
		energy_changed.emit(energy)
		_lamp_mat.emission_energy_multiplier = 0.2 + 3.0 * energy
	if not powered and energy >= power_on_threshold:
		powered = true
	elif powered and energy <= power_off_threshold:
		powered = false


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_vis):
		_vis.free()
	_vis = Node3D.new()
	_vis.name = "Graybox"
	add_child(_vis, false, Node.INTERNAL_MODE_FRONT)
	# Struttura fissa: piastra sul muro e mozzo (collisione nel livello "mondo").
	var body := StaticBody3D.new()
	body.name = "Struttura"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	_vis.add_child(body)
	Graybox.box(body, Vector3(radius * 2.2, radius * 2.2, 0.12), Vector3(0, 0, -0.06), Graybox.DARK)
	Graybox.box_shape(body, Vector3(radius * 2.2, radius * 2.2, 0.12), Vector3(0, 0, -0.06))
	var hub := Graybox.cylinder(body, 0.17, 0.42, Vector3(0, 0, 0.2), Graybox.DARK)
	hub.rotation = Vector3(PI * 0.5, 0, 0)
	# Rotore con le pale.
	_rotor = Node3D.new()
	_rotor.name = "Rotore"
	_rotor.position = Vector3(0, 0, 0.22)
	_vis.add_child(_rotor)
	var blade_len := radius - 0.12
	for i in blade_count:
		var pivot := Node3D.new()
		pivot.rotation = Vector3(0, 0, TAU * i / blade_count)
		_rotor.add_child(pivot)
		var blade := Graybox.box(pivot, Vector3(0.24, blade_len, 0.05), Vector3(0, 0.12 + blade_len * 0.5, 0), Graybox.TARGET)
		blade.rotation = Vector3(0, deg_to_rad(28.0), 0)
	# Spia: si illumina con l'energia.
	_lamp_mat = Graybox.lamp_material(Color(1.0, 0.75, 0.25), 0.2)
	Graybox.box(_vis, Vector3(0.16, 0.16, 0.1), Vector3(0, radius * 1.1 + 0.18, 0.02), _lamp_mat, "Spia")
	# Bersaglio del getto: il disco delle pale.
	_hitbox = WaterHitbox.new()
	_hitbox.name = "Bersaglio"
	_vis.add_child(_hitbox)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius + 0.05
	shape.height = 0.5
	cs.shape = shape
	cs.position = Vector3(0, 0, 0.25)
	cs.rotation = Vector3(PI * 0.5, 0, 0)
	_hitbox.add_child(cs)
