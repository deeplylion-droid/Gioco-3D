extends Node
## Test del menu delle opzioni dalla pausa nel gioco vero (crash dell'utente «andando dal menu su audio», 7 novembre):
## si parte dal titolo verso una partenza del menu di prova (F9: --partenza=<id>, come la prova da riga di comando),
## e appena arrivati (riscaldamento e caricamenti nel thread ancora in corso) e poi a gioco fermo, più volte:
## pausa, Opzioni, tutte le schede col codice, col mouse (clic sul titolo della scheda), con la tastiera e con la croce
## del joypad sulla barra delle schede; sulla scheda Audio i cursori con le frecce e «Ripristina i volumi»; Esc chiude,
## Esc riprende. Poi il giocatore muore, si riparte dal checkpoint e si rifà tutto. Il test passa se il processo arriva
## in fondo (un crash lo ferma) senza errori di script.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/test_menu_pausa_zone.gd --partenza=torre
## (--partenza=inizio: la nuova partita, nella sala principale)

const TITOLO := "res://scenes/ui/menu_principale.tscn"
const GIRI := 4

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


func _azione(a: StringName) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(1)


func _tasto(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(1)


func _joy(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(1)


func _clic(p: Vector2) -> void:
	for premuto in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = p
		e.global_position = p
		e.pressed = premuto
		Input.parse_input_event(e)
		await _frames(2)


## Arrivati: niente schermata di caricamento, niente nel thread, il giocatore c'è e non sta morendo.
func _arrivati(entro_s: float) -> bool:
	var fino := Time.get_ticks_msec() + entro_s * 1000.0
	while Time.get_ticks_msec() < fino:
		var sc := get_tree().current_scene
		if sc and String(sc.name) != "Caricamento" and String(sc.name) != "MenuPrincipale" \
				and get_tree().get_first_node_in_group(&"player") != null and not GameState.is_dying:
			return true
		await _frames(5)
	return false


func _giro(nome: String, subito: bool) -> void:
	print("--- giro: %s" % nome)
	Game.set_paused(true)
	await _frames(1 if subito else 3)
	Game.open_options()
	await _frames(1 if subito else 4)
	var menu := Game.find_children("*", "MenuOpzioni", true, false)
	check(not menu.is_empty(), "%s: dalla pausa si aprono le opzioni" % nome)
	if menu.is_empty():
		Game.set_paused(false)
		return
	var m := menu[0] as MenuOpzioni
	var tabs := m.find_children("*", "TabContainer", true, false)[0] as TabContainer
	var n := tabs.get_tab_count()
	# col codice, di fila e a salti, anche dall'ultima (Audio) alla prima
	for i in [n - 1, 0, n - 1, 3, n - 1, n - 2, n - 1]:
		tabs.current_tab = i
		await _frames(1)
	# col mouse sul titolo di ogni scheda
	var barra := tabs.get_tab_bar()
	for i in n:
		await _clic(barra.get_global_transform_with_canvas() * barra.get_tab_rect(i).get_center())
	# con la tastiera e la croce del joypad sulla barra delle schede
	tabs.current_tab = 0
	barra.grab_focus()
	for i in n:
		await _tasto(KEY_RIGHT)
	for i in n:
		await _joy(JOY_BUTTON_DPAD_LEFT)
	for i in n:
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	check(String(tabs.get_current_tab_control().name) == "Audio", "%s: tastiera e joypad arrivano ad Audio" % nome)
	# i cursori dell'audio e il ripristino
	var cursori := tabs.get_current_tab_control().find_children("Cursore_*", "HSlider", true, false)
	for c: HSlider in cursori:
		c.grab_focus()
		await _azione(&"ui_left")
		await _azione(&"ui_right")
	for b: Button in tabs.get_current_tab_control().find_children("*", "Button", true, false):
		b.pressed.emit()
		await _frames(2)
	# Esc chiude le opzioni, Esc riprende il gioco
	await _azione(&"ui_cancel")
	await _frames(3)
	check(Game.find_children("*", "MenuOpzioni", true, false).is_empty(), "%s: Esc chiude le opzioni" % nome)
	Game.set_paused(false)
	await _frames(5)


func _run() -> void:
	Game.pause_on_focus_loss = false
	var partenza := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--partenza="):
			partenza = a.get_slice("=", 1)
	if partenza == "":
		check(false, "manca --partenza=<id> (inizio, torre, inseguimento, tunnel...)")
	get_tree().change_scene_to_file(TITOLO)
	if partenza == "inizio":
		# (la partenza da riga non fa la nuova partita: la fa il titolo, come col pulsante)
		await _frames(30)
		get_tree().current_scene.call(&"nuova_partita")
	var arrivato := await _arrivati(600.0)
	check(arrivato, "arrivati nel gioco (%s)" % partenza)
	if arrivato:
		# subito: il riscaldamento e i caricamenti nel thread sono ancora in corso
		await _giro("appena arrivati", true)
		await _frames(30)
		for g in GIRI:
			await _giro("a gioco fermo %d" % g, false)
		# dopo una morte, appena ripartiti
		GameState.kill_player(&"prova")
		await _frames(10)
		await _giro("durante la morte", true)
		var ripartito := await _arrivati(300.0)
		check(ripartito, "dopo la morte si riparte")
		if ripartito:
			await _giro("appena ripartiti", true)
			await _giro("dopo la ripartenza", false)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	Game.esci(1 if _ko > 0 else 0)
