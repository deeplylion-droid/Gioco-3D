extends "res://tests/collaudo/opzioni_scatti.gd"
## Collaudo 0.3.22 (ricontrollo di 0a05c8d0): dalla pausa nel gioco vero (--partenza=torre), opzioni, scheda Luminosità,
## «Calibra la luminosità…» aperta col joypad (A) e chiusa col B, poi aperta con Invio e chiusa con Esc: dove va il fuoco,
## se la croce e le frecce ci si muovono, e il titolo del pannello (CALIBP:).

func _arrivati(entro_s: float) -> bool:
	var fino := Time.get_ticks_msec() + entro_s * 1000.0
	while Time.get_ticks_msec() < fino:
		var sc := get_tree().current_scene
		if sc and String(sc.name) != "Caricamento" and String(sc.name) != "MenuPrincipale" \
				and get_tree().get_first_node_in_group(&"player") != null and not GameState.is_dying:
			return true
		await _frames(5)
	return false


func _tasto(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(3)


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(TITOLO)
	await _frames(30)
	MenuProva.parti(get_tree(), "torre")
	print("CALIBP: arrivati %s" % await _arrivati(600.0))
	await _frames(30)
	Game.set_paused(true)
	await _frames(3)
	Game.open_options()
	await _frames(10)
	var m := Game.find_children("*", "MenuOpzioni", true, false)[0] as MenuOpzioni
	var etichette := []
	for l: Label in m.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text.begins_with("Opzioni"):
			etichette.append(l.text)
	print("CALIBP: titoli del pannello %s" % [etichette])
	var tabs := m.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for modo in ["joypad", "tastiera"]:
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
			await _tasto(KEY_ENTER)
		await _frames(20)
		print("CALIBP: %s: aperta %s" % [modo, not get_tree().root.find_children("*", "CalibrazioneLuminosita", true, false).is_empty()])
		if modo == "joypad":
			await _joy(JOY_BUTTON_B)
		else:
			await _tasto(KEY_ESCAPE)
		await _frames(20)
		print("CALIBP: %s: chiusa %s, opzioni aperte %s, fuoco %s (il pulsante è %s)" % [modo, get_tree().root.find_children("*", "CalibrazioneLuminosita", true, false).is_empty(), m.visible, _fuoco(), b.name])
		for d in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			await _joy(d)
			print("CALIBP: %s: dopo la croce %d il fuoco è %s" % [modo, d, _fuoco()])
		await _tasto(KEY_UP)
		print("CALIBP: %s: dopo la freccia su il fuoco è %s" % [modo, _fuoco()])
	m.chiudi_menu()
	await _frames(10)
	Game.set_paused(false)
	print("CALIBP: finito")
	Game.esci(0)
