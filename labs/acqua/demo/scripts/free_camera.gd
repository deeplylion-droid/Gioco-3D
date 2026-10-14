extends Camera3D
## Camera libera per provare la scena: tasto destro del mouse per guardarsi intorno,
## WASD per muoversi, Q/E giu'/su, Shift per andare veloce, rotella per la velocita'.

@export var speed := 3.0
@export var mouse_sensitivity := 0.0025

var _yaw := 0.0
var _pitch := 0.0
var enabled := true


func _ready() -> void:
	_sync_angles()


func _sync_angles() -> void:
	var e := global_transform.basis.get_euler()
	_pitch = e.x
	_yaw = e.y


func look_from(pos: Vector3, target: Vector3) -> void:
	global_position = pos
	look_at(target, Vector3.UP)
	_sync_angles()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			speed *= 1.2
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			speed /= 1.2
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.5, 1.5)
		basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))


func _process(delta: float) -> void:
	if not enabled:
		return
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		d -= basis.z
	if Input.is_key_pressed(KEY_S):
		d += basis.z
	if Input.is_key_pressed(KEY_A):
		d -= basis.x
	if Input.is_key_pressed(KEY_D):
		d += basis.x
	if Input.is_key_pressed(KEY_E):
		d += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		d -= Vector3.UP
	var s := speed * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	global_position += d.normalized() * s * delta if d != Vector3.ZERO else Vector3.ZERO
