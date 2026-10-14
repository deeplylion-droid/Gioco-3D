extends Node
## Autoload "Game": pausa con Esc e cattura del mouse.
## Esc mette in pausa e libera il mouse; Esc o un clic riprendono il gioco.

signal paused_changed(is_paused: bool)

## Mette in pausa da solo quando la finestra perde il fuoco.
@export var pause_on_focus_loss := true
## Tasti di prova: F1 = demo della sala principale, F2 = scena di prova delle meccaniche.
@export var debug_scene_keys := true

const SCENE_DEMO := "res://scenes/sala_principale.tscn"
const SCENE_TEST := "res://scenes/test/test_level.tscn"

var _overlay: CanvasLayer
var _had_focus := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	capture_mouse()


func capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_paused() -> bool:
	return get_tree().paused


func set_paused(value: bool) -> void:
	if get_tree().paused == value:
		return
	get_tree().paused = value
	_overlay.visible = value
	if value:
		release_mouse()
	else:
		capture_mouse()
	paused_changed.emit(value)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if debug_scene_keys and key and key.pressed and not key.echo and (key.keycode == KEY_F1 or key.keycode == KEY_F2):
		set_paused(false)
		get_tree().change_scene_to_file(SCENE_DEMO if key.keycode == KEY_F1 else SCENE_TEST)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if get_tree().paused:
			set_paused(false)
			get_viewport().set_input_as_handled()
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			capture_mouse()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_had_focus = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and _had_focus:
		if is_inside_tree() and not get_tree().paused and DisplayServer.get_name() != "headless":
			set_paused(true)


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "PauseOverlay"
	_overlay.layer = 100
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)
	var label := Label.new()
	label.text = "PAUSA\n\nEsc o clic per continuare"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	_overlay.add_child(label)
