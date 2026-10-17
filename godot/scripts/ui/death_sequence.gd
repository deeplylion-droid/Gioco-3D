class_name DeathSequence
extends CanvasLayer
## Sequenza di morte. Si salta tenendo premuto "skip" (Spazio, E o Invio) per
## [member hold_to_skip] secondi. Alla fine emette [signal finished]: GameState ricarica il
## livello dall'ultimo checkpoint e poi chiama fade_in().
## - Se ti prende lei (causa &"medusa", con la medusa nel gruppo "medusa_che_prende"): la camera
##   viene tirata verso il suo viso mentre la fauce si apre e l'occhio si riempie di vene (lo fa
##   la medusa, MedusaStatue.attacca()), lampo rosso al morso, poi nero; sopra, il jumpscare
##   (JumpscareGlitch: glitch dello schermo, scosse, il suo urlo).
## - Le altre cause (PROVVISORIO): la camera cade, lampo rosso, poi nero.

signal finished(skipped: bool)

## Durata della sequenza se non viene saltata (s).
@export var duration := 5.0
## Secondi da tenere premuto per saltarla.
@export var hold_to_skip := 1.0
## Durata della dissolvenza dal nero dopo la ripartenza (s).
@export var fade_in_time := 0.6

## Causa della morte (per scegliere in futuro la scena giusta).
var cause: StringName = &"generico"
var elapsed := 0.0
var hold := 0.0

var _done := false
var _fading_in := false
var _flash: ColorRect
var _black: ColorRect
var _title: Label
var _hint: Label
var _bar: ProgressBar
# Lei che ti prende, e da dove partiva la camera.
var _lei: Node3D
var _camera_da := Transform3D.IDENTITY


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_flash = _rect(Color(0.6, 0.0, 0.0, 0.0))
	_black = _rect(Color(0, 0, 0, 0))
	_title = _label("[scena di morte provvisoria]", 0.45, 30)
	_title.modulate.a = 0.0
	if cause == &"medusa":
		_lei = get_tree().get_first_node_in_group(&"medusa_che_prende") as Node3D
		# Il jumpscare: glitch, scosse e il suo urlo (addons/grafica/jumpscare_glitch.gd).
		add_child(JumpscareGlitch.new())
		_title.visible = false
		var p := GameState.player
		if p and is_instance_valid(p):
			_camera_da = p.camera.global_transform
	_hint = _label("Tieni premuto Spazio per saltare", 0.88, 18)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.anchor_left = 0.4
	_bar.anchor_right = 0.6
	_bar.anchor_top = 0.92
	_bar.anchor_bottom = 0.92
	_bar.offset_bottom = 6
	add_child(_bar)


func _process(delta: float) -> void:
	if _fading_in:
		_black.color.a = move_toward(_black.color.a, 0.0, delta / maxf(fade_in_time, 0.01))
		if _black.color.a <= 0.0:
			queue_free()
		return
	if _done:
		return
	elapsed += delta
	if _lei and is_instance_valid(_lei):
		# Il morso dopo un attimo: lampo, poi nero.
		_flash.color.a = clampf(1.0 - absf(elapsed - 1.0) / 0.35, 0.0, 1.0) * 0.6
		_black.color.a = smoothstep(1.1, 2.0, elapsed)
		_camera_medusa()
	else:
		_flash.color.a = clampf(1.0 - elapsed / 0.8, 0.0, 1.0) * 0.55
		_black.color.a = smoothstep(0.7, 2.0, elapsed)
		_title.modulate.a = smoothstep(1.6, 2.4, elapsed)
		_animate_camera()
	if Input.is_action_pressed(&"skip"):
		hold += delta
	else:
		hold = maxf(0.0, hold - delta * 2.0)
	_bar.value = hold / hold_to_skip
	if hold >= hold_to_skip:
		_finish(true)
	elif elapsed >= duration:
		_finish(false)


## Salta subito alla fine (per test e debug).
func skip() -> void:
	if not _done:
		_finish(true)


## Dissolvenza dal nero dopo la ripartenza, poi la sequenza si chiude.
func fade_in() -> void:
	_done = true
	_fading_in = true
	_black.color.a = 1.0
	_title.visible = false
	_hint.visible = false
	_bar.visible = false


func _finish(skipped: bool) -> void:
	_done = true
	_black.color.a = 1.0
	_flash.color.a = 0.0
	_title.visible = false
	_hint.visible = false
	_bar.visible = false
	finished.emit(skipped)


## Lei ti tira verso di sé: la camera va davanti al suo viso, guardando la fauce che si apre,
## con un tremito che cresce.
func _camera_medusa() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	var viso: Vector3 = _lei.call(&"get_eye_position") if _lei.has_method(&"get_eye_position") else _lei.global_position + Vector3.UP * 1.6
	var bocca := viso + Vector3.DOWN * 0.22
	var verso := _camera_da.origin - bocca
	verso.y = maxf(verso.y, 0.0)
	var arrivo := bocca + verso.normalized() * 0.6
	var t := smoothstep(0.0, 0.95, elapsed)
	var pos := _camera_da.origin.lerp(arrivo, t)
	var tremito := Vector3(sin(elapsed * 53.0), sin(elapsed * 47.0 + 1.3), 0.0) * 0.012 * t
	var dove := (bocca - pos).normalized()
	if dove.length_squared() < 0.5 or absf(dove.y) > 0.99:
		return
	p.camera.global_transform = Transform3D(Basis.looking_at(dove, Vector3.UP), pos + tremito)


## Placeholder: la camera crolla a terra di lato.
func _animate_camera() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	var t := smoothstep(0.0, 1.1, elapsed)
	p.camera.position = Vector3(0.0, -1.15 * t, 0.0)
	p.camera.rotation = Vector3(0.25 * t, 0.0, 1.2 * t)


func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _label(text: String, y_anchor: float, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.anchor_right = 1.0
	l.anchor_top = y_anchor
	l.anchor_bottom = y_anchor
	l.offset_top = -20
	l.offset_bottom = 20
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
