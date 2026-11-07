extends Node
## Test delle schede del menu delle opzioni (7 novembre, crash dell'utente «andando dal menu su audio»):
## 1. dal titolo le opzioni si aprono e l'ultima scheda è Audio, coi suoi 4 cursori;
## 2. con la tastiera (tasti veri, freccia destra) e con la croce del joypad, dalla barra delle schede si arriva fino ad
##    Audio e si torna indietro: prima la freccia destra portava il focus su Preset e ad Audio si arrivava solo col mouse;
## 3. sulla scheda Audio i cursori si muovono con le frecce e cambiano il volume; chiuso e riaperto il menu più volte,
##    un volume cambiato non chiama i pannelli chiusi (il pannello si stacca dall'autoload Audio), anche tolto
##    dall'albero senza essere liberato;
## 4. l'autoload Audio esamina i nodi nuovi anche se fra loro ce n'è uno aggiunto e liberato nello stesso fotogramma.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_menu_schede.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _tasto(codice: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = codice
	e.physical_keycode = codice
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)


func _joy(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(2)


func _apri() -> MenuOpzioni:
	get_tree().current_scene.call(&"apri_opzioni")
	await _frames(10)
	var m := get_tree().root.find_children("*", "MenuOpzioni", true, false)
	return m[0] as MenuOpzioni if not m.is_empty() else null


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(TITOLO)
	await _frames(40)
	var audio_ad := get_node(^"/root/Audio")
	var collegati_prima := audio_ad.get_signal_connection_list(&"volume_cambiato").size()

	# 1. le schede
	var m := await _apri()
	check(m != null, "dal titolo si aprono le opzioni")
	if m == null:
		_fine()
		return
	var tabs := m.find_children("*", "TabContainer", true, false)[0] as TabContainer
	var ultima := tabs.get_tab_count() - 1
	check(String(tabs.get_tab_control(ultima).name) == "Audio", "l'ultima scheda è Audio")

	# 2. tastiera e joypad sulla barra delle schede
	tabs.get_tab_bar().grab_focus()
	await _frames(2)
	for i in ultima:
		await _tasto(KEY_RIGHT)
	check(tabs.current_tab == ultima, "con la freccia destra si arriva alla scheda Audio (scheda %d di %d)" % [tabs.current_tab, ultima])
	check(get_viewport().gui_get_focus_owner() == tabs.get_tab_bar(), "il focus resta sulla barra delle schede")
	await _tasto(KEY_RIGHT)
	check(tabs.current_tab == ultima, "oltre l'ultima scheda non si va")
	for i in ultima:
		await _joy(JOY_BUTTON_DPAD_LEFT)
	check(tabs.current_tab == 0, "con la croce a sinistra si torna alla prima scheda")
	for i in ultima:
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	check(tabs.current_tab == ultima, "con la croce a destra si arriva ad Audio")

	# col joypad, dalla barra delle schede sulla scheda Audio: il primo «giù» va sul volume generale e la croce a
	# sinistra lo abbassa; il secondo «giù» va sulla musica (ricontrollo di grafica-2, 7 novembre)
	tabs.get_tab_bar().grab_focus()
	await _frames(2)
	var generale := tabs.get_current_tab_control().find_children("Cursore_generale", "HSlider", true, false)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	check(not generale.is_empty() and get_viewport().gui_get_focus_owner() == generale[0],
		"joypad: il primo giù dalla barra va sul volume generale (%s)" % get_viewport().gui_get_focus_owner())
	var g0 := float(audio_ad.call(&"volume", "generale"))
	for i in 3:
		await _joy(JOY_BUTTON_DPAD_LEFT)
	var g1 := float(audio_ad.call(&"volume", "generale"))
	check(g1 < g0, "joypad: la croce a sinistra abbassa il volume generale (%.2f -> %.2f)" % [g0, g1])
	for i in 3:
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	var musica := tabs.get_current_tab_control().find_children("Cursore_musica", "HSlider", true, false)
	check(not musica.is_empty() and get_viewport().gui_get_focus_owner() == musica[0], "joypad: il secondo giù va sulla musica")

	# la calibrazione dalla scheda Luminosità col joypad: A la apre, B la chiude, e il fuoco torna su «Calibra la
	# luminosità…» e la croce lo muove (collaudo della 0.3.22: prima nessun controllo aveva più il fuoco)
	for chiudi_con in [JOY_BUTTON_B, KEY_ESCAPE]:
		tabs.current_tab = tabs.get_tab_count() - 2
		await _frames(2)
		var calibra: Button = null
		for bt: Button in m.find_children("*", "Button", true, false):
			if bt.text == "Calibra la luminosità…":
				calibra = bt
		check(calibra != null, "nella scheda Luminosità c'è «Calibra la luminosità…»")
		if calibra == null:
			break
		calibra.grab_focus()
		await _joy(JOY_BUTTON_A)
		await _frames(3)
		check(not m.find_children("*", "CalibrazioneLuminosita", true, false).is_empty(), "A del joypad apre la calibrazione")
		if chiudi_con == JOY_BUTTON_B:
			await _joy(JOY_BUTTON_B)
		else:
			await _tasto(KEY_ESCAPE)
		await _frames(3)
		var come := "B" if chiudi_con == JOY_BUTTON_B else "Esc"
		check(m.find_children("*", "CalibrazioneLuminosita", true, false).is_empty() and m.is_inside_tree(),
			"%s chiude la calibrazione e le opzioni restano aperte" % come)
		check(get_viewport().gui_get_focus_owner() == calibra, "chiusa con %s, il fuoco torna su «Calibra la luminosità…» (%s)" % [come, get_viewport().gui_get_focus_owner()])
		await _joy(JOY_BUTTON_DPAD_UP)
		var dopo := get_viewport().gui_get_focus_owner()
		check(dopo != null and dopo != calibra, "poi la croce in su sposta il fuoco (%s)" % dopo)
	tabs.current_tab = tabs.get_tab_count() - 1
	await _frames(2)
	check(String((m.find_children("*", "Label", true, false)[0] as Label).text) == "Opzioni", "il titolo del menu è «Opzioni»")

	# 3. i cursori dell'audio
	var cursori := tabs.get_current_tab_control().find_children("Cursore_*", "HSlider", true, false)
	check(cursori.size() == 4, "nella scheda Audio ci sono i 4 cursori dei volumi (%d)" % cursori.size())
	if not cursori.is_empty():
		var s := cursori[0] as HSlider
		var v0 := s.value
		s.grab_focus()
		await _frames(2)
		await _tasto(KEY_LEFT)
		await _tasto(KEY_LEFT)
		check(s.value < v0, "freccia sinistra sul volume generale: si abbassa (%d -> %d)" % [v0, s.value])
		check(is_equal_approx(float(audio_ad.call(&"volume", "generale")), s.value / 100.0), "il volume dell'Audio segue il cursore")
		await _tasto(KEY_RIGHT)
		await _tasto(KEY_RIGHT)
	m.chiudi_menu()
	await _frames(5)
	for giro in 3:
		m = await _apri()
		if m:
			tabs = m.find_children("*", "TabContainer", true, false)[0] as TabContainer
			tabs.current_tab = tabs.get_tab_count() - 1
			await _frames(3)
			m.chiudi_menu()
			await _frames(5)
	audio_ad.call(&"imposta_volume", "musica", 0.5)
	audio_ad.call(&"ripristina_volumi")
	await _frames(3)
	var collegati := audio_ad.get_signal_connection_list(&"volume_cambiato").size()
	check(collegati == collegati_prima, "chiusi i menu, nessun pannello resta collegato all'Audio (%d prima, %d dopo)" % [collegati_prima, collegati])
	# il pannello tolto dall'albero ma non liberato (Godot stacca da solo solo quelli liberati): non resta collegato
	m = await _apri()
	if m:
		var pannelli := m.find_children("*", "PannelloAudio", true, false)
		check(not pannelli.is_empty(), "nel menu c'è il pannello dell'audio")
		if not pannelli.is_empty():
			var p := pannelli[0] as Node
			check(audio_ad.get_signal_connection_list(&"volume_cambiato").size() == collegati_prima + 1, "il pannello aperto è collegato all'Audio")
			p.get_parent().remove_child(p)
			check(audio_ad.get_signal_connection_list(&"volume_cambiato").size() == collegati_prima,
				"il pannello tolto dall'albero (non liberato) non è più collegato all'Audio")
			p.free()
		m.chiudi_menu()
		await _frames(5)

	# 4. l'autoload Audio con un nodo aggiunto e liberato nello stesso fotogramma (un menu aperto e chiuso subito): gli
	# altri nodi aggiunti in quel fotogramma si collegano lo stesso. (Una guardia: in locale passava anche col ciclo
	# di prima su Array[Node], qui il «previously freed» non usciva.)
	var prima_b := Button.new()
	var via := Node.new()
	var dopo_b := Button.new()
	add_child(prima_b)
	add_child(via)
	add_child(dopo_b)
	via.free()
	await _frames(3)
	check(prima_b.has_meta(&"_audio") and dopo_b.has_meta(&"_audio"),
		"Audio collega i pulsanti aggiunti insieme a un nodo liberato subito (prima %s, dopo %s)" % [prima_b.has_meta(&"_audio"), dopo_b.has_meta(&"_audio")])
	prima_b.queue_free()
	dopo_b.queue_free()
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
