extends CharacterBody3D
## Controller in prima persona minimo, solo per provare la grafica.

@export var velocita := 3.2
@export var sensibilita := 0.0022

@onready var camera: Camera3D = $Camera3D
var _pitch := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func imposta_vista(pos: Vector3, yaw_gradi: float, pitch_gradi: float) -> void:
	global_position = pos - Vector3(0, camera.position.y, 0)
	rotation.y = deg_to_rad(yaw_gradi)
	_pitch = deg_to_rad(pitch_gradi)
	camera.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := sensibilita * float(Grafica.valore("sensibilita_mouse"))
		var y := -1.0 if Grafica.valore("inverti_y") else 1.0
		rotation.y -= event.relative.x * k
		_pitch = clampf(_pitch - event.relative.y * k * y, -1.45, 1.45)
		camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		var z := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		dir = (global_basis * Vector3(x, 0, z)).normalized()
	var v := velocita * (1.8 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	velocity.x = dir.x * v
	velocity.z = dir.z * v
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
