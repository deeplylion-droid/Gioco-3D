class_name SchermataComandi
extends Control
## Schermata dei comandi, dal titolo e dal menu di pausa (scena res://scenes/ui/comandi.tscn,
## CanvasLayer di livello 100 sopra il post-processing). I tasti si leggono dalla InputMap del
## progetto, quindi restano giusti se cambiano. Si chiude con "Indietro", Esc o B sul joypad.
## Funziona anche con il gioco in pausa.

signal chiuso

## Righe: descrizione, azioni della InputMap (vuoto = solo la nota) e nota.
const RIGHE := [
	["Muoversi", [&"move_forward", &"move_left", &"move_back", &"move_right"], ""],
	["Guardarsi intorno", [], "Mouse"],
	["Correre", [&"sprint"], "tieni premuto"],
	["Abbassarsi", [&"crouch"], "tieni premuto"],
	["Saltare", [&"jump"], ""],
	["Usare, raccogliere", [&"interact"], ""],
	["Zaino: spruzzare", [&"spray"], "tieni premuto"],
	["Zaino: aspirare l'acqua", [&"suck"], "tieni premuto"],
	["Pausa", [&"pause"], ""],
]

const _NOMI_TASTI := {
	KEY_SHIFT: "Maiusc", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_SPACE: "Spazio",
	KEY_ESCAPE: "Esc", KEY_ENTER: "Invio", KEY_KP_ENTER: "Invio", KEY_TAB: "Tab",
	KEY_BACKSPACE: "Backspace", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	KEY_CAPSLOCK: "Bloc Maiusc",
}
const _NOMI_MOUSE := {
	MOUSE_BUTTON_LEFT: "Tasto sinistro", MOUSE_BUTTON_RIGHT: "Tasto destro",
	MOUSE_BUTTON_MIDDLE: "Rotellina", MOUSE_BUTTON_WHEEL_UP: "Rotellina su",
	MOUSE_BUTTON_WHEEL_DOWN: "Rotellina giù",
}
const _NOMI_JOYPAD := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "Croce su", JOY_BUTTON_DPAD_DOWN: "Croce giù",
	JOY_BUTTON_DPAD_LEFT: "Croce sinistra", JOY_BUTTON_DPAD_RIGHT: "Croce destra",
}

var _indietro: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = StileMenu.tema()
	var fondo := ColorRect.new()
	fondo.color = Color(StileMenu.FONDO, 0.86)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 640
	col.add_theme_constant_override("separation", 10)
	centro.add_child(col)

	var titolo := StileMenu.etichetta("COMANDI", StileMenu.oswald(600, 6), 40)
	col.add_child(titolo)
	col.add_child(_linea())
	var spazio := Control.new()
	spazio.custom_minimum_size.y = 6
	col.add_child(spazio)
	col.add_child(crea_elenco())
	var spazio2 := Control.new()
	spazio2.custom_minimum_size.y = 18
	col.add_child(spazio2)
	_indietro = StileMenu.voce("Indietro", 26)
	_indietro.name = "Indietro"
	_indietro.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_indietro.custom_minimum_size.x = 220
	_indietro.pressed.connect(chiudi)
	col.add_child(_indietro)
	StileMenu.collega_voci([_indietro])
	_indietro.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		chiudi()


func chiudi() -> void:
	if is_queued_for_deletion():
		return
	chiuso.emit()
	# Se è la scena .tscn (CanvasLayer + Control) si chiude tutta.
	if owner is CanvasLayer:
		owner.queue_free()
	else:
		queue_free()


## L'elenco dei comandi (due colonne: cosa fa, tasti). Lo usa anche il caricamento.
static func crea_elenco(dimensione := 19, separazione := 9) -> GridContainer:
	var g := GridContainer.new()
	g.name = "Elenco"
	g.columns = 2
	g.add_theme_constant_override("h_separation", 34)
	g.add_theme_constant_override("v_separation", separazione)
	for riga in RIGHE:
		var descrizione := StileMenu.etichetta(riga[0], StileMenu.barlow(), dimensione, StileMenu.TESTO)
		descrizione.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(descrizione)
		var tasti := HBoxContainer.new()
		tasti.add_theme_constant_override("separation", 6)
		var nomi := nomi_tasti(riga[1])
		if riga[1].is_empty():
			tasti.add_child(StileMenu.tasto(riga[2], dimensione - 2))
		else:
			for n in nomi:
				tasti.add_child(StileMenu.tasto(n, dimensione - 2))
			var nota: String = riga[2]
			if riga[1] == [&"crouch"] and _abbassarsi_a_scatto():
				nota = "premi una volta"
			if nota != "":
				var l := StileMenu.etichetta(nota, StileMenu.barlow(), dimensione - 3, StileMenu.TESTO_SPENTO)
				l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				tasti.add_child(l)
		g.add_child(tasti)
	return g


## I nomi dei tasti di una o più azioni, in italiano e secondo la tastiera del giocatore.
static func nomi_tasti(azioni: Array) -> PackedStringArray:
	var nomi := PackedStringArray()
	for azione in azioni:
		if not InputMap.has_action(azione):
			continue
		for ev in InputMap.action_get_events(azione):
			var n := nome_evento(ev)
			if n != "" and not nomi.has(n):
				nomi.append(n)
	return nomi


static func nome_evento(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var codice := k.keycode
		if k.physical_keycode != KEY_NONE:
			codice = k.physical_keycode
			# Con le tastiere non QWERTY il tasto fisico ha un'altra lettera sopra.
			if DisplayServer.get_name() != "headless":
				var locale := DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
				if locale != KEY_NONE:
					codice = locale
		if _NOMI_TASTI.has(codice):
			return _NOMI_TASTI[codice]
		return OS.get_keycode_string(codice)
	if ev is InputEventMouseButton:
		return _NOMI_MOUSE.get((ev as InputEventMouseButton).button_index, "Mouse")
	if ev is InputEventJoypadButton:
		return _NOMI_JOYPAD.get((ev as InputEventJoypadButton).button_index, "Joypad")
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		match m.axis:
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "Levetta sinistra"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "Levetta destra"
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
	return ""


static func _abbassarsi_a_scatto() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var stato := tree.root.get_node_or_null(^"GameState") if tree else null
	var p: Object = stato.get(&"player") if stato else null
	return p != null and is_instance_valid(p) and bool(p.get(&"crouch_toggle"))


func _linea() -> Control:
	var r := ColorRect.new()
	r.color = StileMenu.ROSSO
	r.custom_minimum_size = Vector2(64, 3)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return r
