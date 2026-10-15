extends Node
## Autoload "Game": pausa con Esc e cattura del mouse.
## Esc mette in pausa e libera il mouse: dal menu di pausa si riprende, si aprono le opzioni
## grafiche (addon grafica) o si esce. Al primo avvio: preset Alto e calibrazione della luminosità.
## F3 mostra FPS, tempo del fotogramma e preset.

signal paused_changed(is_paused: bool)

## Mette in pausa da solo quando la finestra perde il fuoco.
@export var pause_on_focus_loss := true
## Tasti di prova: F1 = demo della sala principale, F2 = scena di prova delle meccaniche.
## Solo nelle build di debug (editor e prove): nella Release si passa dal menu.
@export var debug_scene_keys := OS.is_debug_build()

const SCENE_DEMO := "res://scenes/sala_principale.tscn"
const SCENE_TEST := "res://scenes/test/test_level.tscn"
const SCENE_TITLE := "res://scenes/ui/menu_principale.tscn"
const SCENE_CONTROLS := "res://scenes/ui/comandi.tscn"

## Al primo avvio (nessun user://settings.cfg) parte con questo preset dell'addon grafica.
@export var first_run_preset := "alto"

var _overlay: CanvasLayer
var _had_focus := false
var _menu_layer: CanvasLayer
var _resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	capture_mouse()
	var first_run := not FileAccess.file_exists("user://settings.cfg")
	if first_run and not is_automated():
		Grafica.applica_preset(first_run_preset)
	# Contatore delle prestazioni (F3), spento all'avvio.
	add_child(load("res://scripts/ui/fps_counter.gd").new())
	if not is_automated() and not bool(Grafica.valore("calibrato")):
		_show_calibration.call_deferred()
	# Aberrazione cromatica più leggera di quella dell'addon (frange colorate ai bordi).
	var post := Grafica.get_node_or_null(^"PostProcessing")
	if post and post.get_child_count() > 0 and post.get_child(0) is CanvasItem:
		var m := (post.get_child(0) as CanvasItem).material as ShaderMaterial
		if m:
			m.set_shader_parameter(&"forza_aberrazione", 0.0014)
	# La qualità dell'acqua segue il preset grafico.
	Grafica.impostazione_cambiata.connect(func(_k, _v): _sync_water_quality())
	_sync_water_quality()


func _sync_water_quality() -> void:
	var wm := get_node_or_null(^"/root/WaterManager")
	if wm == null:
		return
	var preset: String = str(Grafica.valore("preset"))
	wm.set(&"quality", {"basso": 0, "medio": 1}.get(preset, 2))


## Vero nelle prove automatiche (test e screenshot lanciati con --script).
static func is_automated() -> bool:
	return OS.get_cmdline_args().has("--script")


func _show_calibration() -> void:
	var cal: CanvasLayer = load("res://addons/grafica/calibrazione_luminosita.tscn").instantiate()
	add_child(cal)
	get_tree().paused = true
	release_mouse()
	cal.tree_exited.connect(func():
		# All'uscita dal gioco l'albero non c'è più: niente da riprendere.
		if not is_inside_tree():
			return
		get_tree().paused = false
		capture_mouse())


func open_options() -> void:
	if is_instance_valid(_menu_layer):
		return
	_overlay.visible = false
	_menu_layer = load("res://addons/grafica/menu_opzioni.tscn").instantiate()
	add_child(_menu_layer)
	var menu := _menu_layer.get_node(^"Menu")
	menu.chiuso.connect(func():
		_menu_layer = null
		if get_tree().paused:
			_overlay.visible = true
			_resume_button.grab_focus.call_deferred())


## Schermata dei comandi (dal menu di pausa), come le opzioni.
func open_controls() -> void:
	if is_instance_valid(_menu_layer):
		return
	_overlay.visible = false
	_menu_layer = load(SCENE_CONTROLS).instantiate()
	add_child(_menu_layer)
	_menu_layer.get_node(^"Comandi").connect(&"chiuso", func():
		_menu_layer = null
		if get_tree().paused:
			_overlay.visible = true
			_resume_button.grab_focus.call_deferred())


## Dal menu di pausa al titolo: i progressi in memoria si azzerano (il salvataggio su disco resta).
func return_to_title() -> void:
	set_paused(false)
	# Una sequenza di morte in corso non deve ricaricare il livello dopo.
	for n in GameState.get_children():
		if n is DeathSequence:
			n.queue_free()
	GameState.reset_progress()
	get_tree().change_scene_to_file(SCENE_TITLE)


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
		_resume_button.grab_focus.call_deferred()
	else:
		if is_instance_valid(_menu_layer):
			_menu_layer.queue_free()
			_menu_layer = null
		capture_mouse()
	paused_changed.emit(value)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if debug_scene_keys and key and key.pressed and not key.echo and (key.keycode == KEY_F1 or key.keycode == KEY_F2):
		set_paused(false)
		get_tree().change_scene_to_file(SCENE_DEMO if key.keycode == KEY_F1 else SCENE_TEST)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_menu_layer):
		return  # il menu delle opzioni gestisce da solo Esc
	if event.is_action_pressed("pause"):
		if get_tree().paused and not _overlay.visible:
			return  # in pausa per altro (Polaroid, calibrazione)
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var label := Label.new()
	label.text = "PAUSA"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	col.add_child(label)
	_resume_button = _menu_button(col, "Riprendi", func(): set_paused(false))
	_menu_button(col, "Opzioni", open_options)
	_menu_button(col, "Comandi", open_controls)
	_menu_button(col, "Torna al titolo", return_to_title)
	_menu_button(col, "Esci dal gioco", func(): get_tree().quit())


func _menu_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
