class_name BucketWheel
extends Node3D
## Il gioco d'acqua dell'area bimbi: la ruota a pale gira quando la colpisce il getto e
## pompa acqua nel secchio gigante in cima alla struttura; quando il secchio è pieno si
## ribalta e rovescia una cascata. L'ondata fa girare la grande ruota che apre il cancello
## della piscina a onde e bagna il quadro elettrico (scintille). Poi il secchio torna dritto.
## Ruote, secchio e cancello sono nodi dei GLB dell'ambiente con il perno giusto: qui vengono
## solo mossi (ruote e secchio sull'asse X, cancello sull'asse Y).
## Il cancello aperto fa parte dei checkpoint (gruppo "persist"): ripartendo resta aperto.

signal bucket_tipped
signal gate_opened
signal panel_shorted

@export var wheel_path: NodePath
@export var bucket_path: NodePath
## La grande ruota che apre il cancello, il cancello (cerniera) e il quadro elettrico.
@export var gate_wheel_path: NodePath
@export var gate_path: NodePath
@export var panel_path: NodePath
## Angolo di apertura del cancello (gradi) e giri di ruota che servono per aprirlo del tutto.
@export var gate_open_angle := -95.0
@export var gate_wheel_turns := 1.2
@export_group("Ruota")
## Raggio della ruota (m) per il bersaglio del getto.
@export var wheel_radius := 0.95
## Velocità angolare data da ogni litro (rad/s).
@export var spin_per_liter := 7.0
@export var max_angular_speed := 9.0
## Rallentamento (rad/s²).
@export var friction := 1.4
@export_group("Secchio")
## Litri che servono per riempire il secchio.
@export var bucket_capacity := 40.0
## Litri al secondo pompati nel secchio con la ruota alla velocità massima.
@export var pump_rate := 9.0
## Angolo del ribaltamento (gradi) e tempi.
@export var tip_angle := 112.0
@export var tip_time := 0.9
@export var hold_time := 1.6
@export var return_time := 2.4

var angular_speed := 0.0
var bucket_fill := 0.0

var _wheel: Node3D
var _bucket: Node3D
var _wheel_basis := Basis.IDENTITY
var _bucket_basis := Basis.IDENTITY
var _wheel_angle := 0.0
var _tip := 0.0           # 0 dritto, 1 ribaltato
var _phase := 0           # 0 si riempie, 1 si ribalta, 2 resta giù, 3 torna su
var _phase_t := 0.0
var _pour: WaterStream
var _gate_wheel: Node3D
var _gate: Node3D
var _panel: Node3D
var _gate_wheel_basis := Basis.IDENTITY
var _gate_basis := Basis.IDENTITY
var _gate_wheel_speed := 0.0
var _gate_wheel_angle := 0.0
var gate_open := false
var _sparks: GPUParticles3D
var _spark_light: OmniLight3D
var _spark_t := -1.0


func _ready() -> void:
	add_to_group(&"persist")
	_wheel = get_node_or_null(wheel_path) as Node3D
	_bucket = get_node_or_null(bucket_path) as Node3D
	if _wheel:
		_wheel_basis = _wheel.basis
		var hit := WaterHitbox.new()
		hit.name = "BersaglioRuota"
		add_child(hit)
		hit.global_position = _wheel.global_position
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = wheel_radius
		shape.height = 0.8
		cs.shape = shape
		cs.rotation = Vector3(0, 0, PI * 0.5)
		hit.add_child(cs)
		hit.water_hit.connect(_on_wheel_hit)
	_gate_wheel = get_node_or_null(gate_wheel_path) as Node3D
	_gate = get_node_or_null(gate_path) as Node3D
	_panel = get_node_or_null(panel_path) as Node3D
	if _gate_wheel:
		_gate_wheel_basis = _gate_wheel.basis
	if _gate:
		_gate_basis = _gate.basis
	if _panel:
		_make_sparks()
	if _bucket:
		_bucket_basis = _bucket.basis
		_pour = WaterStream.new()
		_pour.name = "Cascata"
		_pour.radius_start = 0.09
		_pour.radius_growth = 0.12
		_pour.max_age = 1.4
		_pour.breakup_start = 0.55
		add_child(_pour)


func _on_wheel_hit(liters: float, _point: Vector3, _dir: Vector3) -> void:
	angular_speed = minf(angular_speed + liters * spin_per_liter, max_angular_speed)


func _physics_process(delta: float) -> void:
	angular_speed = maxf(angular_speed - friction * delta, 0.0)
	_wheel_angle = wrapf(_wheel_angle + angular_speed * delta, 0.0, TAU)
	if _wheel:
		_wheel.basis = Basis(Vector3.RIGHT, -_wheel_angle) * _wheel_basis
	if _bucket == null:
		return
	_phase_t += delta
	match _phase:
		0:
			bucket_fill = minf(bucket_fill + pump_rate * (angular_speed / max_angular_speed) * delta, bucket_capacity)
			if bucket_fill >= bucket_capacity:
				_set_phase(1)
				bucket_tipped.emit()
				# L'ondata arriva alla ruota del cancello e al quadro poco dopo.
				get_tree().create_timer(0.7, false).timeout.connect(func(): _gate_wheel_speed = 5.5)
				get_tree().create_timer(1.1, false).timeout.connect(_short_panel)
		1:
			_tip = _ease_in(_phase_t / tip_time)
			if _phase_t >= tip_time:
				_set_phase(2)
		2:
			_tip = 1.0
			if _phase_t >= hold_time:
				_set_phase(3)
		3:
			_tip = 1.0 - _ease_in_out(_phase_t / return_time)
			if _phase_t >= return_time:
				_tip = 0.0
				bucket_fill = 0.0
				_set_phase(0)
	_bucket.basis = Basis(Vector3.RIGHT, deg_to_rad(tip_angle) * _tip) * _bucket_basis
	_update_gate(delta)
	_update_sparks(delta)
	# La cascata: esce dal bordo del secchio mentre è inclinato.
	var pouring := (_phase == 1 and _tip > 0.45) or _phase == 2 or (_phase == 3 and _tip > 0.6)
	if _pour:
		var up := _bucket.global_basis.y.normalized()
		var lip := _bucket.global_position + up * 0.75
		_pour.physics_step(delta, pouring, lip, up * 2.2 + Vector3(0, -0.5, 0))


func _update_gate(delta: float) -> void:
	if _gate_wheel_speed <= 0.0:
		return
	_gate_wheel_speed = maxf(_gate_wheel_speed - 1.1 * delta, 0.0)
	_gate_wheel_angle += _gate_wheel_speed * delta
	if _gate_wheel:
		_gate_wheel.basis = Basis(Vector3.RIGHT, _gate_wheel_angle) * _gate_wheel_basis
	# Il cancello si apre insieme ai giri della ruota e poi resta aperto.
	var k := clampf(_gate_wheel_angle / (gate_wheel_turns * TAU), 0.0, 1.0)
	if _gate:
		_gate.basis = Basis(Vector3.UP, deg_to_rad(gate_open_angle) * k) * _gate_basis
	if k >= 1.0 and not gate_open:
		gate_open = true
		gate_opened.emit()


func save_state() -> Dictionary:
	return {"gate_open": gate_open}


func load_state(data: Dictionary) -> void:
	if not bool(data.get("gate_open", false)) or gate_open:
		return
	# Già aperto: la ruota ha fatto i suoi giri e il cancello resta spalancato (senza suoni).
	gate_open = true
	_gate_wheel_speed = 0.0
	_gate_wheel_angle = gate_wheel_turns * TAU
	if _gate_wheel:
		_gate_wheel.basis = Basis(Vector3.RIGHT, _gate_wheel_angle) * _gate_wheel_basis
	if _gate:
		_gate.basis = Basis(Vector3.UP, deg_to_rad(gate_open_angle)) * _gate_basis


func _make_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.name = "Scintille"
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 90
	_sparks.lifetime = 0.9
	_sparks.explosiveness = 0.85
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.4, 1)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.particle_flag_align_y = true
	_sparks.process_material = pm
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.012, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.3)
	mat.emission_energy_multiplier = 8.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mat
	_sparks.draw_pass_1 = mesh
	add_child(_sparks)
	_sparks.global_position = _panel.global_position + Vector3(0, 1.5, 0.2)
	_spark_light = OmniLight3D.new()
	_spark_light.light_color = Color(1.0, 0.75, 0.45)
	_spark_light.omni_range = 6.0
	_spark_light.light_energy = 0.0
	_spark_light.visible = false
	add_child(_spark_light)
	_spark_light.global_position = _sparks.global_position + Vector3(0, 0, 0.3)


func _short_panel() -> void:
	if _sparks == null:
		return
	_sparks.restart()
	_sparks.emitting = true
	_spark_t = 0.0
	panel_shorted.emit()


func _update_sparks(delta: float) -> void:
	if _spark_t < 0.0 or _spark_light == null:
		return
	_spark_t += delta
	# Lampi di luce irregolari mentre il quadro sfrigola.
	var on := _spark_t < 1.3 and randf() > 0.35
	_spark_light.visible = on
	_spark_light.light_energy = randf_range(2.0, 7.0) if on else 0.0
	if _spark_t >= 1.3:
		_spark_t = -1.0
		_spark_light.visible = false


func _set_phase(p: int) -> void:
	_phase = p
	_phase_t = 0.0


static func _ease_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t


static func _ease_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
