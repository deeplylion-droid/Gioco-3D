extends "res://tests/collaudo/opzioni_scatti.gd"
## Collaudo 0.3.22: dopo «Calibra la luminosità…» chiusa col joypad (B) o con Esc, dove va il fuoco e se la croce del
## joypad e le frecce lo riportano su un controllo delle opzioni (CALIB:).

func _run() -> void:
	Game.pause_on_focus_loss = false
	cart = "/tmp"
	get_tree().change_scene_to_file(TITOLO)
	await _frames(60)
	for modo in ["joypad", "esc"]:
		get_tree().current_scene.call(&"apri_opzioni")
		await _frames(20)
		var m := get_tree().root.find_children("*", "MenuOpzioni", true, false)[0] as MenuOpzioni
		var tabs := m.find_children("*", "TabContainer", true, false)[0] as TabContainer
		for i in tabs.get_tab_count():
			if String(tabs.get_tab_control(i).name) == "Luminosità":
				tabs.current_tab = i
		await _frames(5)
		var b: Button = null
		for x in tabs.get_current_tab_control().find_children("*", "Button", true, false):
			b = x
		b.grab_focus()
		await _frames(3)
		if modo == "joypad":
			await _joy(JOY_BUTTON_A)
		else:
			var e := InputEventKey.new()
			e.keycode = KEY_ENTER
			e.pressed = true
			Input.parse_input_event(e)
			await _frames(3)
			e = e.duplicate(); e.pressed = false; Input.parse_input_event(e)
		await _frames(20)
		print("CALIB: %s: aperta %s" % [modo, not get_tree().root.find_children("*", "CalibrazioneLuminosita", true, false).is_empty()])
		if modo == "joypad":
			await _joy(JOY_BUTTON_B)
		else:
			var e2 := InputEventKey.new()
			e2.keycode = KEY_ESCAPE
			e2.pressed = true
			Input.parse_input_event(e2)
			await _frames(3)
			e2 = e2.duplicate(); e2.pressed = false; Input.parse_input_event(e2)
		await _frames(20)
		print("CALIB: %s: chiusa %s, opzioni aperte %s, fuoco %s" % [modo, get_tree().root.find_children("*", "CalibrazioneLuminosita", true, false).is_empty(), m.visible, _fuoco()])
		for d in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT]:
			await _joy(d)
			print("CALIB: %s: dopo la croce %d il fuoco è %s" % [modo, d, _fuoco()])
		var e3 := InputEventKey.new()
		e3.keycode = KEY_DOWN
		e3.pressed = true
		Input.parse_input_event(e3)
		await _frames(3)
		e3 = e3.duplicate(); e3.pressed = false; Input.parse_input_event(e3)
		await _frames(3)
		print("CALIB: %s: dopo la freccia giù il fuoco è %s" % [modo, _fuoco()])
		m.chiudi_menu()
		await _frames(10)
	print("CALIB: finito")
	get_tree().quit()
