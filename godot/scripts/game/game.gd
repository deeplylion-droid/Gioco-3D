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

## Secondi massimi che esci() aspetta un caricamento nel thread (se il pool di thread si blocca).
const ATTESA_MASSIMA := 30.0
const SCENE_DEMO := "res://scenes/sala_principale.tscn"
const SCENE_TEST := "res://scenes/test/test_level.tscn"
const SCENE_TITLE := "res://scenes/ui/menu_principale.tscn"
const SCENE_CONTROLS := "res://scenes/ui/comandi.tscn"

## Al primo avvio (nessun user://settings.cfg) parte con questo preset dell'addon grafica.
@export var first_run_preset := "alto"

var _overlay: CanvasLayer
## I caricamenti nel thread chiesti con carica_in_thread() in questa partita: all'uscita si aspetta che
## finiscano, e poi ancora un po'.
var _caricamenti: PackedStringArray = []
## Vero da quando esci() è partito: chi aspetta un caricamento nel thread non lo rifà.
var uscendo := false
var _had_focus := false
var _menu_layer: CanvasLayer
var _resume_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# La X della finestra passa da esci() (NOTIFICATION_WM_CLOSE_REQUEST in _notification).
	get_tree().auto_accept_quit = false
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


## Solo per i test (un PC lento): i caricamenti nel thread risultano finiti solo dopo questi secondi dalla richiesta.
var ritardo_thread_test := 0.0
var _richiesto_ms := {}


## ResourceLoader.load_threaded_request, ricordando il percorso, per esci(). Mentre si esce non comincia niente
## (ERR_UNAVAILABLE): un caricamento partito durante l'attesa di esci() resterebbe a metà all'uscita.
func carica_in_thread(percorso: String, tipo := "") -> Error:
	if uscendo:
		return ERR_UNAVAILABLE
	var err := ResourceLoader.load_threaded_request(percorso, tipo)
	if err == OK and not _caricamenti.has(percorso):
		_caricamenti.append(percorso)
	if err == OK and not _richiesto_ms.has(percorso):
		_richiesto_ms[percorso] = Time.get_ticks_msec()
	return err


## Lo stato di un caricamento chiesto con [method carica_in_thread], come ResourceLoader.load_threaded_get_status.
## Con [member ritardo_thread_test] (solo i test: un PC lento) risulta in corso finché non è passato quel ritardo
## dalla richiesta.
func stato_thread(percorso: String) -> ResourceLoader.ThreadLoadStatus:
	var st := ResourceLoader.load_threaded_get_status(percorso)
	if ritardo_thread_test > 0.0 and st == ResourceLoader.THREAD_LOAD_LOADED \
			and Time.get_ticks_msec() - int(_richiesto_ms.get(percorso, 0)) < ritardo_thread_test * 1000.0:
		return ResourceLoader.THREAD_LOAD_IN_PROGRESS
	return st


## Chiude il gioco. Se in questa partita c'è stato un caricamento nel thread (la torre in precarica, il
## livello dalla schermata di caricamento), prima ne aspetta la fine (di tutti, ricontrollati a ogni fotogramma)
## e poi lascia girare il gioco ancora almeno 30 fotogrammi e 1 s: una risorsa grande che ha appena finito di caricare, se Godot smonta tutto
## subito, lo fa fermare per sempre o abortire (CI di lavoro/godot 58cc633: "Aborted" 12 s dopo la fine
## di test_acquari; in prova: 2 fotogrammi dopo la fine no, 30 sì). Se un caricamento non finisce mai,
## dopo ATTESA_MASSIMA esce lo stesso; una seconda richiesta (la X di nuovo) esce subito.
func esci(codice := 0) -> void:
	if uscendo:
		get_tree().quit(codice)
		return
	uscendo = true
	if not _caricamenti.is_empty():
		# Fotogramma per fotogramma, senza bloccare il thread principale con load_threaded_get() (in prova
		# bloccare non bastava: Godot si fermava lo stesso all'uscita). Si riguardano tutti i caricamenti a ogni
		# giro, finché nessuno è in corso da almeno 30 fotogrammi e 1 s: anche quelli partiti durante l'attesa
		# (CI di lavoro/godot 2a4f4a8a: test_tappa8, lei ti prende, la sala ripartiva mentre si usciva e
		# richiedeva la torre; ora carica_in_thread e il respawn non partono più, ma si aspetta lo stesso).
		var t0 := Time.get_ticks_msec()
		var aspettati := {}
		var t1 := t0
		var f := 0
		while Time.get_ticks_msec() - t0 < ATTESA_MASSIMA * 1000.0:
			var in_corso := false
			for percorso in _caricamenti:
				var stato := ResourceLoader.load_threaded_get_status(percorso)
				if stato == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					in_corso = true
					aspettati[percorso] = true
				elif stato == ResourceLoader.THREAD_LOAD_LOADED:
					ResourceLoader.load_threaded_get(percorso)
			if in_corso:
				t1 = Time.get_ticks_msec()
				f = 0
			elif f >= 30 and Time.get_ticks_msec() - t1 >= 1000:
				break
			await get_tree().process_frame
			f += 1
		if not aspettati.is_empty():
			print("Uscita: aspettati %d caricamenti nel thread (%.1f s)" % [aspettati.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	await get_tree().process_frame
	get_tree().quit(codice)


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
	# Sopra il menu del titolo (livello 100) e sotto la dissolvenza (120): allo stesso livello
	# il titolo copriva la calibrazione, e con il gioco in pausa nessuno dei due rispondeva.
	cal.layer = 110
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		esci()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
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
	_menu_button(col, "Esci dal gioco", func(): esci())


func _menu_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
