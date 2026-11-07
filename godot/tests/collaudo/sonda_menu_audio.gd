extends Node
## Sonda del crash «andando dal menu su audio» (utente, 7 novembre, 0.3.21): apre le opzioni dal titolo e passa alla
## scheda Audio in tutti i modi (dal codice, con la tastiera sulle schede, col mouse sul titolo della scheda), poi muove
## i cursori e torna indietro. Stampa ogni passo, così se il processo muore si vede dove.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/sonda_menu_audio.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _passo(t: String) -> void:
	print("PASSO ", t)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tasto(azione: StringName) -> void:
	var e := InputEventAction.new()
	e.action = azione
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)


func _clic(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = p
	e.global_position = p
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(3)


func _joy(bottone: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = bottone
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)


func _rotella(p: Vector2, su: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if su else MOUSE_BUTTON_WHEEL_DOWN
	e.position = p
	e.global_position = p
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(1)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(1)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(TITOLO)
	await _frames(60)
	for lingua in ["it", "en"]:
		Lingua.imposta(lingua)
		_passo("lingua %s" % lingua)
		await _giri()
	_passo("FINE")
	print("RISULTATO: 1 controlli ok, 0 falliti")
	Game.esci(0)


func _giri() -> void:
	for giro in 5:
		_passo("giro %d: apro le opzioni dal titolo" % giro)
		get_tree().current_scene.call(&"apri_opzioni")
		await _frames(10)
		var menu := get_tree().root.find_children("*", "MenuOpzioni", true, false)
		if menu.is_empty():
			print("PASSO niente MenuOpzioni")
			break
		var m := menu[0] as MenuOpzioni
		var tabs := m.find_children("*", "TabContainer", true, false)[0] as TabContainer
		var nomi := []
		for i in tabs.get_tab_count():
			nomi.append(String(tabs.get_tab_control(i).name))
		_passo("schede: %s" % [nomi])
		var audio := nomi.find("Audio")
		match giro:
			0:
				_passo("dal codice: current_tab = %d" % audio)
				tabs.current_tab = audio
				await _frames(10)
			1:
				_passo("tastiera: focus sulla barra delle schede, poi a destra")
				tabs.get_tab_bar().grab_focus()
				await _frames(2)
				for k in audio:
					_passo("  ui_right %d" % k)
					await _tasto(&"ui_right")
				await _frames(10)
			3:
				_passo("calibrazione dalla scheda Luminosità, poi Audio")
				tabs.current_tab = nomi.find("Luminosità")
				await _frames(5)
				m.apri_calibrazione()
				await _frames(10)
				await _tasto(&"ui_accept")
				await _frames(10)
				tabs.current_tab = audio
				await _frames(10)
			4:
				_passo("il focus su un cursore di un'altra scheda, poi Audio, poi indietro con un cursore audio a fuoco")
				var c := tabs.get_tab_control(0).find_children("*", "HSlider", true, false)
				if not c.is_empty():
					(c[0] as HSlider).grab_focus()
				tabs.current_tab = audio
				await _frames(5)
			2:
				_passo("mouse: clic sul titolo della scheda Audio")
				var r := tabs.get_tab_bar().get_tab_rect(audio)
				var p := tabs.get_tab_bar().get_global_transform_with_canvas() * r.get_center()
				await _clic(p)
				await _frames(10)
		_passo("scheda attiva: %s" % tabs.get_current_tab_control().name)
		# i cursori: avanti e indietro con la tastiera
		var cursori := tabs.get_current_tab_control().find_children("Cursore_*", "HSlider", true, false)
		_passo("cursori: %d" % cursori.size())
		if not cursori.is_empty():
			(cursori[0] as HSlider).grab_focus()
			await _tasto(&"ui_left")
			await _tasto(&"ui_right")
			for k in 6:
				await _tasto(&"ui_down")
			for k in 6:
				await _tasto(&"ui_up")
			_passo("  joypad: croce e A")
			for b: JoyButton in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN,
					JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_A, JOY_BUTTON_DPAD_UP,
					JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_UP]:
				await _joy(b)
			_passo("  rotella sui cursori")
			for c: HSlider in cursori:
				var p := c.get_global_rect().get_center()
				for k in 3:
					await _rotella(p, false)
				for k in 3:
					await _rotella(p, true)
			_passo("  trascino i cursori col mouse")
			for c: HSlider in cursori:
				var r := c.get_global_rect()
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.position = r.get_center()
				e.global_position = e.position
				e.pressed = true
				Input.parse_input_event(e)
				await _frames(2)
				var mv := InputEventMouseMotion.new()
				mv.position = r.position + Vector2(r.size.x * 0.2, r.size.y * 0.5)
				mv.global_position = mv.position
				mv.button_mask = MOUSE_BUTTON_MASK_LEFT
				Input.parse_input_event(mv)
				await _frames(2)
				e = e.duplicate()
				e.pressed = false
				e.position = mv.position
				e.global_position = mv.position
				Input.parse_input_event(e)
				await _frames(5)
			var rip := tabs.get_current_tab_control().find_children("*", "Button", true, false)
			for bt: Button in rip:
				_passo("  premo %s" % bt.text)
				bt.pressed.emit()
				await _frames(5)
		_passo("torno alla prima scheda e chiudo")
		tabs.current_tab = 0
		await _frames(5)
		m.chiudi_menu()
		await _frames(10)
