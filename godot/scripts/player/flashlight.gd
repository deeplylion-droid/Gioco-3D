class_name Flashlight
extends SpotLight3D
## Torcia di base (tasto F): segue lo sguardo con un piccolo ritardo e fa vedere il fascio
## nella nebbia. Quando arriverà la torcia del pacchetto grafica (addons/grafica) questa si
## spegne con [member enabled] = false.

signal toggled_light(is_on: bool)

@export var enabled := true
@export var start_on := false
## Quanto in fretta segue lo sguardo (1/s): più basso = più "pesante".
@export var follow_speed := 16.0
## Posizione rispetto agli occhi (un po' in basso a destra, come se fosse in mano o sul petto).
@export var offset := Vector3(0.12, -0.16, -0.1)
@export var energy := 3.2

var is_on := false
var _player: Player


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_player = get_parent() as Player
	light_energy = energy
	if light_projector == null:
		light_projector = _make_projector()
	set_on(start_on and enabled)


func _make_projector() -> GradientTexture2D:
	# Centro luminoso, alone più debole e un anello vicino al bordo, come una torcia vera.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 0.86, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1), Color(0.92, 0.9, 0.86), Color(0.5, 0.48, 0.45),
		Color(0.42, 0.4, 0.38), Color(0.6, 0.58, 0.55), Color(0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t


func set_on(on: bool) -> void:
	is_on = on and enabled
	visible = is_on
	toggled_light.emit(is_on)


func toggle() -> void:
	set_on(not is_on)


func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed("flashlight") and (_player == null or _player.input_enabled):
		toggle()


func _process(delta: float) -> void:
	if _player == null or not is_on:
		return
	var head := _player.head.global_transform
	global_position = head.origin + head.basis * offset
	var target := head.basis.orthonormalized()
	basis = basis.orthonormalized().slerp(target, 1.0 - exp(-follow_speed * delta))
