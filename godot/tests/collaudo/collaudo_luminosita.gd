extends Node
## Collaudo della schermata «Luminosità» con la seconda prova (ritocchi di grafica-2 per la 0.3.21): sul titolo vero,
## col renderer vero. La calibrazione del primo avvio (come la apre game.gd quando non c'è settings.cfg: qui con
## --script il gioco non la apre da solo), col joypad (croce, levetta tenuta, su e giù, A), con la tastiera e col mouse;
## dove sta ogni parte sullo schermo (niente fuori dallo schermo, lo scatto non copre i simboli né il cursore); dopo la
## conferma la gamma del post-processing è quella del cursore; poi dalle opzioni «Calibra la luminosità…» aperta tre
## volte. Uno scatto per ogni schermata.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/collaudo_luminosita.gd <cartella> <prefisso> [it|en]
## (Lingua.imposta scrive la lingua in settings.cfg: fare una copia prima e rimetterla dopo)

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var cartella := ""
var prefisso := ""
var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var a := OS.get_cmdline_user_args()
	cartella = a[1]
	prefisso = a[2]
	var lingua := a[3] if a.size() > 3 else "it"
	DirAccess.make_dir_recursive_absolute(cartella)
	Grafica.salva_su_disco = false
	Lingua.imposta(lingua)
	get_tree().change_scene_to_file(TITOLO)
	await _frames(60)
	var vp := get_tree().root.get_visible_rect()
	print("SCHERMO %s, lingua %s" % [vp.size, lingua])

	print("1. La calibrazione del primo avvio")
	Game.call(&"_show_calibration")
	await _frames(10)
	var cal := _calibrazione()
	_check(cal != null and get_tree().paused, "la calibrazione è aperta e il titolo è fermo")
	if cal == null:
		_fine()
		return
	await _scatto("01_aperta")
	_posti(cal, vp)
	var cur := cal.find_children("*", "HSlider", true, false)[0] as HSlider
	var prova := cal.find_child("Prova", true, false) as TextureRect
	var g0 := cur.value
	_check(is_equal_approx(g0, float(Grafica.valore("luminosita"))), "il cursore parte dalla luminosità di adesso (%.2f)" % g0)

	print("2. Joypad")
	for i in 5:
		await _joy_tasto(JOY_BUTTON_DPAD_RIGHT)
	_check(is_equal_approx(cur.value, g0 + 0.1), "croce a destra 5 volte: +0,10 (%.2f -> %.2f)" % [g0, cur.value])
	_check(is_equal_approx(_gamma_prova(prova), cur.value), "lo scatto segue il cursore (%.2f)" % _gamma_prova(prova))
	await _scatto("02_croce_destra_%.2f" % cur.value)
	var prima := cur.value
	# la levetta tenuta a sinistra per 1 s: dopo 0,35 s scorre da sola
	await _levetta(-1.0, 60)
	var giu := prima - cur.value
	_check(giu > 0.2, "levetta tenuta a sinistra 1 s: il cursore scorre (%.2f -> %.2f)" % [prima, cur.value])
	await _scatto("03_levetta_tenuta_%.2f" % cur.value)
	var fermo := cur.value
	await _frames(20)
	_check(is_equal_approx(cur.value, fermo), "lasciata la levetta il cursore si ferma (%.2f)" % cur.value)
	# la croce tenuta a destra per 1 s
	await _joy_tasto(JOY_BUTTON_DPAD_RIGHT, 60)
	_check(cur.value > fermo + 0.2, "croce tenuta a destra 1 s: scorre (%.2f -> %.2f)" % [fermo, cur.value])
	var conferma := _pulsante(cal, "Conferma")
	var pred := _pulsante(cal, "Predefinito")
	_check(get_viewport().gui_get_focus_owner() == conferma, "il focus resta su Conferma")
	await _joy_tasto(JOY_BUTTON_DPAD_DOWN)
	_check(get_viewport().gui_get_focus_owner() == pred, "croce in giù: Predefinito")
	await _scatto("04_focus_predefinito")
	await _joy_tasto(JOY_BUTTON_DPAD_UP)
	_check(get_viewport().gui_get_focus_owner() == conferma, "croce in su: Conferma")
	await _levetta_su_giu(1.0)
	_check(get_viewport().gui_get_focus_owner() == pred, "levetta in giù: Predefinito")
	await _levetta_su_giu(-1.0)
	_check(get_viewport().gui_get_focus_owner() == conferma, "levetta in su: Conferma")

	print("3. Tastiera e mouse")
	var k0 := cur.value
	for i in 3:
		await _tasto(KEY_LEFT)
	_check(is_equal_approx(cur.value, k0 - 0.06), "freccia a sinistra 3 volte: -0,06 (%.2f -> %.2f)" % [k0, cur.value])
	await _tasto(KEY_RIGHT)
	_check(is_equal_approx(cur.value, k0 - 0.04), "freccia a destra: +0,02 (%.2f)" % cur.value)
	# un clic sul cursore a un quarto
	var r := cur.get_global_rect()
	await _clic(r.position + Vector2(r.size.x * 0.25, r.size.y * 0.5))
	var atteso := cur.min_value + (cur.max_value - cur.min_value) * 0.25
	_check(absf(cur.value - atteso) < 0.06, "clic col mouse a un quarto del cursore: %.2f (circa %.2f)" % [cur.value, atteso])
	_check(is_equal_approx(_gamma_prova(prova), cur.value), "lo scatto segue il cursore anche col mouse (%.2f)" % _gamma_prova(prova))
	await _scatto("05_mouse_%.2f" % cur.value)
	# il valore più chiaro e più scuro: lo scatto e i simboli insieme
	cur.value = cur.max_value
	await _frames(3)
	await _scatto("06_piu_chiaro_%.2f" % cur.value)
	cur.value = cur.min_value
	await _frames(3)
	await _scatto("07_piu_scuro_%.2f" % cur.value)
	# Predefinito col mouse, poi un valore scelto e A
	await _clic(pred.get_global_rect().get_center())
	_check(is_equal_approx(cur.value, 1.0), "Predefinito col mouse: 1,00 (%.2f)" % cur.value)
	for i in 6:
		await _joy_tasto(JOY_BUTTON_DPAD_RIGHT)
	var scelto := cur.value
	if get_viewport().gui_get_focus_owner() != conferma:
		conferma.grab_focus()
		await _frames(2)
	await _joy_tasto(JOY_BUTTON_A)
	await _frames(10)

	print("4. Dopo la conferma")
	_check(_calibrazione() == null and not get_tree().paused, "A chiude la calibrazione e il titolo riparte")
	_check(is_equal_approx(float(Grafica.valore("luminosita")), scelto), "la luminosità del gioco è quella scelta (%.2f)" % float(Grafica.valore("luminosita")))
	var post := _gamma_post()
	_check(is_equal_approx(post, scelto), "la gamma del post-processing è quella del cursore (%.2f)" % post)
	await _scatto("08_titolo_dopo_%.2f" % scelto)

	print("5. Dalle opzioni, tre volte")
	# come il giocatore: «Opzioni» del titolo
	var titolo := get_tree().current_scene
	titolo.call(&"apri_opzioni")
	await _frames(10)
	var menu: Node = null
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("menu_opzioni.gd"):
			menu = n
	_check(menu != null, "le opzioni sono aperte")
	if menu:
		var tabs := menu.find_children("*", "TabContainer", true, false)[0] as TabContainer
		for i in tabs.get_tab_count():
			if String(tabs.get_tab_control(i).name) == "Luminosità":
				tabs.current_tab = i
		await _frames(5)
		await _scatto("09_opzioni_luminosita")
		var bottone := _pulsante(menu, "Calibra la luminosità…")
		_check(bottone != null and bottone.is_visible_in_tree(), "c'è «Calibra la luminosità…»")
		for volta in 3:
			await _clic(bottone.get_global_rect().get_center())
			await _frames(10)
			var c2 := _calibrazione()
			_check(c2 != null, "volta %d: il clic su «Calibra la luminosità…» la apre" % (volta + 1))
			if c2 == null:
				print("  (focus %s, menu %s, bottone %s)" % [get_viewport().gui_get_focus_owner(), menu.get_path(), bottone.get_global_rect()])
				bottone.pressed.emit()
				await _frames(10)
				c2 = _calibrazione()
			_check(c2 != null and c2.find_child("Prova", true, false) is TextureRect,
				"volta %d: la stessa schermata, con lo scatto" % (volta + 1))
			if c2 == null:
				break
			if volta == 0:
				_posti(c2, vp)
			var cur2 := c2.find_children("*", "HSlider", true, false)[0] as HSlider
			var v2 := cur2.value
			await _joy_tasto(JOY_BUTTON_DPAD_LEFT)
			_check(is_equal_approx(cur2.value, v2 - 0.02), "volta %d: la croce muove il cursore (%.2f -> %.2f)" % [volta + 1, v2, cur2.value])
			await _scatto("10_opzioni_calibra_volta_%d" % (volta + 1))
			if volta < 2:
				# chiusa con Esc (ui_cancel): non cambia la luminosità
				var prima_l := float(Grafica.valore("luminosita"))
				await _tasto(KEY_ESCAPE)
				await _frames(5)
				_check(is_equal_approx(float(Grafica.valore("luminosita")), prima_l), "volta %d: Esc chiude senza cambiare (%.2f)" % [volta + 1, float(Grafica.valore("luminosita"))])
			else:
				var v3 := cur2.value
				await _joy_tasto(JOY_BUTTON_A)
				await _frames(5)
				_check(_calibrazione() == null and is_equal_approx(float(Grafica.valore("luminosita")), v3)
					and is_equal_approx(_gamma_post(), v3), "volta 3: A conferma, gioco e post-processing a %.2f" % v3)
		await _scatto("11_opzioni_dopo")
	_fine()


func _fine() -> void:
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


## Dove stanno i pezzi: tutti dentro lo schermo; lo scatto (l'immagine disegnata) non copre i simboli, il cursore, la
## frase e i pulsanti.
func _posti(cal: Control, vp: Rect2) -> void:
	var prova := cal.find_child("Prova", true, false) as TextureRect
	var cur := cal.find_children("*", "HSlider", true, false)[0] as HSlider
	var area: Control = cal.get(&"_area")
	var dice := cal.find_child("DiceProva", true, false) as Label
	var pezzi := {"simboli": area.get_global_rect(), "cursore": cur.get_global_rect(), "frase": dice.get_global_rect(),
		"Conferma": _pulsante(cal, "Conferma").get_global_rect(), "Predefinito": _pulsante(cal, "Predefinito").get_global_rect()}
	var img := _rett_immagine(prova)
	print("  scatto %s (controllo %s), simboli %s, cursore %s" % [img, prova.get_global_rect(), pezzi["simboli"], pezzi["cursore"]])
	_check(img.size.x > 200 and img.size.y > 100, "lo scatto si vede abbastanza grande (%s)" % img.size)
	for k in pezzi:
		var r: Rect2 = pezzi[k]
		_check(not img.intersects(r.grow(-1.0)), "lo scatto non copre %s" % k)
		_check(vp.grow(0.5).encloses(r), "%s dentro lo schermo (%s)" % [k, r])
	_check(vp.grow(0.5).encloses(img), "lo scatto dentro lo schermo")
	var simboli: Rect2 = pezzi["simboli"]
	_check(simboli.size.y > 40, "i simboli hanno spazio (%.0f px)" % simboli.size.y)


## Il rettangolo dove la TextureRect disegna davvero l'immagine (tenendo le proporzioni, al centro).
func _rett_immagine(t: TextureRect) -> Rect2:
	var r := t.get_global_rect()
	var ts := t.texture.get_size()
	var s := minf(r.size.x / ts.x, r.size.y / ts.y)
	var d := ts * s
	return Rect2(r.position + (r.size - d) / 2.0, d)


func _calibrazione() -> CalibrazioneLuminosita:
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n is CalibrazioneLuminosita and n.is_inside_tree() and not n.is_queued_for_deletion():
			return n
	return null


func _gamma_prova(prova: TextureRect) -> float:
	return float((prova.material as ShaderMaterial).get_shader_parameter(&"gamma")) if prova else -1.0


func _gamma_post() -> float:
	var pr: Variant = Grafica.get(&"_post_rect")
	if pr is CanvasItem and (pr as CanvasItem).material is ShaderMaterial:
		return float(((pr as CanvasItem).material as ShaderMaterial).get_shader_parameter(&"gamma"))
	return -1.0


func _pulsante(radice: Node, testo: String) -> Button:
	for b in radice.find_children("*", "Button", true, false):
		if (b as Button).text == testo:
			return b
	return null


func _check(cond: bool, cosa: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", cosa)
	else:
		_ko += 1
		print("  KO  ", cosa)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(prefisso + nome + ".jpg"), 0.9)
	print("  SCATTO ", prefisso + nome)


func _joy_tasto(tasto: JoyButton, tenuto := 2) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = tasto
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(tenuto)
	var e2 := InputEventJoypadButton.new()
	e2.button_index = tasto
	e2.pressed = false
	Input.parse_input_event(e2)
	await _frames(2)


func _levetta(verso: float, tenuto := 2) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = verso
	Input.parse_input_event(e)
	await _frames(tenuto)
	var e2 := InputEventJoypadMotion.new()
	e2.axis = JOY_AXIS_LEFT_X
	e2.axis_value = 0.0
	Input.parse_input_event(e2)
	await _frames(2)


func _levetta_su_giu(verso: float) -> void:
	for v in [verso, 0.0]:
		var e := InputEventJoypadMotion.new()
		e.axis = JOY_AXIS_LEFT_Y
		e.axis_value = v
		Input.parse_input_event(e)
		await _frames(2)


func _tasto(k: Key) -> void:
	for giu in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = giu
		Input.parse_input_event(e)
		await _frames(2)


func _clic(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await _frames(1)
	for giu in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = p
		e.global_position = p
		e.pressed = giu
		Input.parse_input_event(e)
		await _frames(2)
