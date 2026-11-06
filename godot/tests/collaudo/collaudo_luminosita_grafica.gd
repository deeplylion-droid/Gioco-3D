extends Node
## Ricontrollo della schermata «Luminosità» di grafica-2 (lavoro/ritocchi-grafica2 719d283b), fatto da grafica il
## 6 novembre su richiesta del coordinatore. Dal titolo vero:
## 1. «Opzioni» del titolo, scheda Luminosità, «Calibra la luminosità…» con un clic del mouse, poi col joypad (A) e con
##    la tastiera (Invio): si apre la schermata? dove sta il focus? Esc / B la chiude e si torna alle opzioni?
## 2. in inglese: ogni scritta della schermata e della scheda ha la traduzione;
## 3. a 1280x720, 1920x1080 e in una finestra stretta (900x720 e 800x600): niente coperto, niente fuori dallo schermo.
## Scatti di ogni schermata nella cartella data.
## Uso: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##   --script res://tests/run.gd -- res://tests/collaudo/collaudo_luminosita_grafica.gd <cartella>

const TITOLO := "res://scenes/ui/menu_principale.tscn"

var _cartella := ""
var _ok := 0
var _ko := 0
var _difetti: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(c: bool, cosa: String) -> void:
	if c:
		_ok += 1
		print("  ok   ", cosa)
	else:
		_ko += 1
		_difetti.append(cosa)
		printerr("  KO   ", cosa)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_cartella.path_join(nome + ".png"))
	print("SCATTO ", nome, " ", img.get_size())


## Il centro di [param c] nelle coordinate della finestra (dove arrivano i clic veri).
func _schermo(c: Control) -> Vector2:
	return get_viewport().get_screen_transform() * c.get_global_rect().get_center()


func _clic(c: Control) -> void:
	var p := _schermo(c)
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await _frames(3)
	for giu in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = giu
		b.position = p
		b.global_position = p
		Input.parse_input_event(b)
		await _frames(2)


func _joy(bottone: JoyButton) -> void:
	for giu in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = bottone
		e.pressed = giu
		e.device = 0
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


func _titolo() -> Node:
	get_tree().change_scene_to_file(TITOLO)
	await _frames(90)
	return get_tree().current_scene


func _bottone(radice: Node, testo: String) -> Button:
	for b in radice.find_children("*", "Button", true, false):
		if (b as Button).text == testo and (b as Button).is_visible_in_tree():
			return b
	return null


func _calibrazione() -> CalibrazioneLuminosita:
	for n in get_tree().root.find_children("*", "CalibrazioneLuminosita", true, false):
		return n
	return null


func _focus() -> String:
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return "nessuno"
	return "%s «%s»" % [f.get_path(), f.get(&"text") if f.get(&"text") != null else ""]


## Apre le opzioni dal titolo con un clic su «Opzioni» e va alla scheda Luminosità (clic sulla linguetta, se si trova).
func _opzioni_luminosita(titolo: Node) -> Button:
	var voce := titolo.find_child("Opzioni", true, false) as Button
	check(voce != null, "il titolo ha la voce Opzioni")
	if voce == null:
		return null
	for i in 600:
		if voce.is_visible_in_tree() and not voce.disabled:
			break
		await get_tree().process_frame
	await _clic(voce)
	await _frames(20)
	var tabs: TabContainer = null
	for t in get_tree().root.find_children("*", "TabContainer", true, false):
		if (t as TabContainer).is_visible_in_tree():
			tabs = t
	check(tabs != null, "le opzioni si aprono dal clic su Opzioni")
	if tabs == null:
		return null
	var k := -1
	for i in tabs.get_tab_count():
		if String(tabs.get_tab_control(i).name) == "Luminosità":
			k = i
	check(k >= 0, "c'è la scheda Luminosità")
	# (la linguetta col mouse: la sua posizione dalla barra delle schede)
	var barra := tabs.get_tab_bar()
	var r := barra.get_tab_rect(k)
	var p := get_viewport().get_screen_transform() * (barra.get_global_transform() * r.get_center())
	var m := InputEventMouseMotion.new()
	m.position = p
	Input.parse_input_event(m)
	await _frames(2)
	for giu in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = giu
		b.position = p
		Input.parse_input_event(b)
		await _frames(2)
	await _frames(5)
	if tabs.current_tab != k:
		print("  (la linguetta col clic non ha cambiato scheda: la cambio a mano)")
		tabs.current_tab = k
		await _frames(5)
	return _bottone(tabs.get_tab_control(k), "Calibra la luminosità…")


## Dentro la schermata: tutto nello schermo, niente che si copre.
func _layout(nome: String) -> void:
	var cal := _calibrazione()
	if cal == null:
		return
	var vista := get_viewport().get_visible_rect()
	var pezzi: Array[Control] = []
	for c in cal.find_children("*", "Control", true, false):
		var cc := c as Control
		if not cc.is_visible_in_tree() or cc is Container or cc is ColorRect or cc.get_parent() is HSlider:
			continue
		if cc.size.x < 1 or cc.size.y < 1:
			continue
		pezzi.append(cc)
	for cc in pezzi:
		var r := cc.get_global_rect()
		check(vista.encloses(r.grow(-0.5)), "%s: %s dentro lo schermo (%s in %s)" % [nome, cc.name, r, vista.size])
	# (le scritte e i pulsanti non si sovrappongono fra loro né allo scatto)
	var sovrapposti := []
	for i in pezzi.size():
		for j in range(i + 1, pezzi.size()):
			var a := pezzi[i].get_global_rect().grow(-1)
			var b := pezzi[j].get_global_rect().grow(-1)
			if a.intersects(b) and not pezzi[i].is_ancestor_of(pezzi[j]) and not pezzi[j].is_ancestor_of(pezzi[i]):
				sovrapposti.append("%s/%s" % [pezzi[i].name, pezzi[j].name])
	check(sovrapposti.is_empty(), "%s: niente si copre %s" % [nome, str(sovrapposti)])
	# lo scatto ha un'altezza utile (non schiacciato a una striscia)
	var prova := cal.find_child("Prova", true, false) as Control
	if prova:
		var tex := (prova as TextureRect).texture
		var r := prova.get_global_rect()
		var lato := minf(r.size.x / tex.get_width(), r.size.y / tex.get_height())
		print("  %s: lo scatto è mostrato a %.0fx%.0f (%.0f%% dell'originale)" % [nome, tex.get_width() * lato, tex.get_height() * lato, lato * 100.0])
		check(tex.get_height() * lato >= 150.0, "%s: lo scatto si vede abbastanza grande (alto %.0f px)" % [nome, tex.get_height() * lato])


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	var a := OS.get_cmdline_user_args()
	_cartella = a[1] if a.size() > 1 else "user://collaudo_luminosita"
	DirAccess.make_dir_recursive_absolute(_cartella)
	get_window().size = Vector2i(1280, 720)
	await _frames(5)

	# 1) mouse
	print("1. Dal titolo, clic del mouse su «Calibra la luminosità…»")
	var titolo := await _titolo()
	var cal_b := await _opzioni_luminosita(titolo)
	check(cal_b != null, "nella scheda Luminosità c'è «Calibra la luminosità…»")
	if cal_b:
		await _scatto("1_opzioni_scheda_luminosita")
		await _clic(cal_b)
		await _frames(15)
		var cal := _calibrazione()
		check(cal != null and cal.is_visible_in_tree(), "col clic del mouse la schermata si apre (focus: %s)" % _focus())
		await _scatto("1_calibrazione_dal_titolo_mouse")
		if cal:
			var f := get_viewport().gui_get_focus_owner()
			check(f != null and cal.is_ancestor_of(f), "il focus è dentro la schermata (%s)" % _focus())
			await _layout("1280x720 it")
			await _tasto(KEY_ESCAPE)
			await _frames(10)
			check(_calibrazione() == null, "Esc chiude la schermata")
			check(cal_b.is_visible_in_tree(), "dopo Esc si è di nuovo nelle opzioni")
		# 1b) joypad: focus sul pulsante, A
		print("1b. Col joypad")
		cal_b.grab_focus()
		await _frames(3)
		await _joy(JOY_BUTTON_A)
		await _frames(15)
		cal = _calibrazione()
		check(cal != null, "col joypad (A sul pulsante) la schermata si apre (focus: %s)" % _focus())
		if cal:
			await _scatto("1b_calibrazione_joypad")
			await _joy(JOY_BUTTON_B)
			await _frames(10)
			check(_calibrazione() == null, "col joypad B la chiude")
		# 1c) tastiera: frecce fino al pulsante, Invio
		print("1c. Con la tastiera")
		cal_b.grab_focus()
		await _frames(3)
		await _tasto(KEY_ENTER)
		await _frames(15)
		cal = _calibrazione()
		check(cal != null, "con la tastiera (Invio sul pulsante) la schermata si apre (focus: %s)" % _focus())
		if cal:
			await _tasto(KEY_ESCAPE)
			await _frames(10)

	# 2) inglese
	print("2. In inglese")
	TranslationServer.set_locale("en")
	titolo = await _titolo()
	cal_b = await _opzioni_luminosita(titolo)
	if cal_b == null:
		cal_b = _bottone(get_tree().root, "Calibra la luminosità…")
	if cal_b:
		await _scatto("2_opzioni_scheda_luminosita_en")
		await _clic(cal_b)
		await _frames(15)
		var cal := _calibrazione()
		check(cal != null, "in inglese la schermata si apre")
		if cal:
			var mancano := []
			for c in [cal_b] + cal.find_children("*", "", true, false) + cal_b.get_parent().find_children("*", "", true, false):
				var t: Variant = c.get(&"text")
				if t is String and (t as String).strip_edges() != "" and not (t as String).is_valid_float():
					var tr_ := TranslationServer.translate(t)
					if tr_ == t and not (t as String).ends_with("%") and (t as String) != "OK":
						mancano.append(t)
			check(mancano.is_empty(), "ogni scritta ha la traduzione inglese (senza: %s)" % str(mancano))
			await _scatto("2_calibrazione_en")
			await _layout("1280x720 en")
			await _tasto(KEY_ESCAPE)
			await _frames(5)
	TranslationServer.set_locale("it")

	# 3) misure della finestra
	for misura in [Vector2i(1920, 1080), Vector2i(900, 720), Vector2i(800, 600), Vector2i(1280, 1024)]:
		print("3. Finestra %dx%d" % [misura.x, misura.y])
		get_window().size = misura
		await _frames(10)
		titolo = await _titolo()
		cal_b = await _opzioni_luminosita(titolo)
		if cal_b:
			await _clic(cal_b)
			await _frames(15)
			if _calibrazione():
				await _scatto("3_calibrazione_%dx%d" % [misura.x, misura.y])
				await _layout("%dx%d" % [misura.x, misura.y])
				await _tasto(KEY_ESCAPE)
				await _frames(5)
			else:
				check(false, "%dx%d: la schermata non si apre col clic" % [misura.x, misura.y])
	print("")
	print("DIFETTI: ", _difetti)
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)
