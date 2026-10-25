extends Node
## Collaudo (grafica-2) della domanda "Ricominciare da capo?" prima di Nuova partita, con mouse, tastiera e joypad
## simulati (eventi veri nel viewport). Stampa una riga per prova. Uso: godot --headless --path godot --script
## res://tests/run.gd -- res://tests/collaudo/domanda_nuova_g2.gd

const MENU := "res://scenes/ui/menu_principale.tscn"
var ok := 0
var ko := 0


func _ready() -> void:
	_run.call_deferred()


func _riga(cond: bool, cosa: String) -> void:
	if cond:
		ok += 1
		print("DOMANDA ok  ", cosa)
	else:
		ko += 1
		print("DOMANDA KO  ", cosa)


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scrivi_salvataggio() -> void:
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(MenuProva.istantanea("torre")))
	f.close()


func _hash() -> String:
	return FileAccess.get_md5(GameState.SAVE_PATH) if FileAccess.file_exists(GameState.SAVE_PATH) else "(nessun file)"


func _togli_lettori() -> int:
	var n := 0
	for c in get_tree().root.get_children():
		if c is LettoreSpot:
			n += 1
			c.queue_free()
	return n


func _apri_menu() -> Node:
	_togli_lettori()
	get_tree().change_scene_to_file(MENU)
	await _f(40)
	var m := get_tree().current_scene
	m.set(&"_t", 20.0)
	await _f(5)
	return m


func _clic(b: Control) -> void:
	# (dal rettangolo nel canvas alla finestra: con lo stretch del progetto le coordinate non coincidono)
	await _clic_in(get_viewport().get_screen_transform() * b.get_global_rect().get_center())


func _clic_in(c: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = c
	mv.global_position = c
	Input.parse_input_event(mv)
	await _f(2)
	for premuto in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = premuto
		e.position = c
		e.global_position = c
		Input.parse_input_event(e)
		await _f(1)


func _tasto(k: Key) -> void:
	for premuto in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = premuto
		get_viewport().push_input(e)
		await _f(1)


func _joy(b: JoyButton) -> void:
	for premuto in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = premuto
		e.pressure = 1.0 if premuto else 0.0
		get_viewport().push_input(e)
		await _f(1)


func _domanda(m: Node) -> Node:
	return m.get_node_or_null("DomandaNuovaPartita")


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = true
	# 1. senza salvataggio: si parte subito
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	var m := await _apri_menu()
	var nuova := m.find_child("NuovaPartita", true, false) as Button
	await _clic(nuova)
	await _f(5)
	_riga(_domanda(m) == null and bool(m.get(&"_avviato")), "1. senza salvataggio la domanda non compare e la partita parte (avviato %s)" % m.get(&"_avviato"))
	# 2-3. con il salvataggio: la domanda, il focus su No; No in cinque modi
	_scrivi_salvataggio()
	var h0 := _hash()
	var modi := {"clic su No": "clic_no", "Invio sul focus (No)": "invio", "A del joypad sul focus (No)": "joy_a", "Esc": "esc", "B del joypad": "joy_b"}
	for nome in modi:
		m = await _apri_menu()
		nuova = m.find_child("NuovaPartita", true, false) as Button
		var cont := m.find_child("Continua", true, false)
		nuova.grab_focus()
		await _f(2)
		await _tasto(KEY_ENTER)   # Nuova partita con la tastiera
		await _f(5)
		var d := _domanda(m)
		if d == null:
			_riga(false, "2. con il salvataggio la domanda compare (%s)" % nome)
			continue
		var fo := get_viewport().gui_get_focus_owner()
		if nome == "clic su No":
			_riga(cont != null, "2. col salvataggio c'è Continua")
			_riga(fo == d.get(&"voce_no"), "2. la domanda compare col focus su No (focus: %s)" % (fo.name if fo else "nessuno"))
			var t := d.find_child("Titolo", true, false) as Label
			var n := d.find_child("Nota", true, false) as Label
			_riga(t and t.text == "RICOMINCIARE DA CAPO?" and n and n.text == "Il salvataggio verrà sostituito", "2. testi: \"%s\" / \"%s\"" % [t.text if t else "?", n.text if n else "?"])
		match modi[nome]:
			"clic_no": await _clic(d.get(&"voce_no"))
			"invio": await _tasto(KEY_ENTER)
			"joy_a": await _joy(JOY_BUTTON_A)
			"esc": await _tasto(KEY_ESCAPE)
			"joy_b": await _joy(JOY_BUTTON_B)
		await _f(5)
		fo = get_viewport().gui_get_focus_owner()
		_riga(not is_instance_valid(d) and _domanda(m) == null and not bool(m.get(&"_avviato")) and _togli_lettori() == 0, "3. %s: si torna al titolo senza partire" % nome)
		_riga(fo == nuova, "3. %s: focus su Nuova partita (focus: %s)" % [nome, fo.name if fo else "nessuno"])
		_riga(_hash() == h0, "3. %s: il salvataggio è identico" % nome)
	# 4. Sì una volta sola: doppio clic, Invio ripetuto, A ripetuto
	for nome in ["doppio clic su Sì", "Invio ripetuto su Sì", "A del joypad ripetuto su Sì"]:
		m = await _apri_menu()
		nuova = m.find_child("NuovaPartita", true, false) as Button
		nuova.grab_focus()
		await _f(2)
		await _tasto(KEY_ENTER)
		await _f(5)
		var d := _domanda(m)
		if d == null:
			_riga(false, "4. %s: la domanda non c'è" % nome)
			continue
		var si := d.get(&"voce_si") as Button
		if nome == "doppio clic su Sì":
			# (due clic nello stesso punto, come un doppio clic: il secondo trova la domanda già chiusa)
			var c := get_viewport().get_screen_transform() * si.get_global_rect().get_center()
			await _clic_in(c)
			await _clic_in(c)
		else:
			await _tasto(KEY_UP)   # dal No al Sì
			await _f(2)
			_riga(get_viewport().gui_get_focus_owner() == si, "4. %s: freccia su porta il focus su Sì" % nome)
			for i in 3:
				if nome.begins_with("Invio"):
					await _tasto(KEY_ENTER)
				else:
					await _joy(JOY_BUTTON_A)
		await _f(10)
		var lettori := _togli_lettori()
		_riga(bool(m.get(&"_avviato")) and lettori == 1, "4. %s: la partita parte una volta sola (lettori dello spot avviati: %d)" % [nome, lettori])
		# 5. il salvataggio resta finché non c'è un checkpoint vero; uscendo prima, Continua c'è ancora
		_riga(_hash() == h0 and GameState.has_save(), "5. %s: dopo Sì il salvataggio è ancora lì, identico" % nome)
		m = await _apri_menu()
		_riga(m.find_child("Continua", true, false) != null, "5. %s: tornando al titolo prima di un checkpoint c'è ancora Continua" % nome)
	# 6. F9 > Inizio
	m = await _apri_menu()
	m.call(&"apri_prova")
	await _f(5)
	var pr := m.get_node_or_null("MenuProva")
	if pr:
		pr.emit_signal(&"scelta", "inizio")
	await _f(5)
	var d6 := _domanda(m)
	print("DOMANDA (F9: MenuProva %s, figli del titolo %s)" % [pr, m.get_children().map(func(c): return String(c.name))])
	_riga(d6 != null, "6. F9 > Inizio fa la stessa domanda")
	if d6:
		await _tasto(KEY_ESCAPE)
		await _f(5)
		_riga(_domanda(m) == null and not bool(m.get(&"_avviato")) and (m.get(&"_menu") as Control).visible, "6. da F9, Esc torna al titolo col menu visibile")
	_togli_lettori()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("DOMANDA RISULTATO: %d ok, %d KO" % [ok, ko])
	get_tree().quit()
