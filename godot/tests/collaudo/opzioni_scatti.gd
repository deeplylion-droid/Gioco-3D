extends Node
## Collaudo 0.3.22 (menu): scatti del titolo e di ogni scheda delle opzioni, la scheda Audio col fuoco del joypad
## (croce sulla barra delle schede, poi giù nei cursori, cursore mosso con la croce), la Luminosità col cursore e
## «Calibra la luminosità…» aperta e chiusa col joypad (A e B). In italiano e in inglese (LINGUA=en). Stampa ogni passo
## (OPZ:), così se il processo muore si vede dove.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/opzioni_scatti.gd <cartella> [prefisso]

const TITOLO := "res://scenes/ui/menu_principale.tscn"
var cart := ""
var pre := ""


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scatto(nome: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(pre + nome + ".jpg"), 0.9)
	print("OPZ: scatto ", pre + nome)


func _joy(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(3)


func _fuoco() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return "%s (%s)" % [f.name, f.get_class()] if f else "nessuno"


func _run() -> void:
	Game.pause_on_focus_loss = false
	var a := OS.get_cmdline_user_args()
	cart = a[1] if a.size() > 1 else "/tmp/opzioni_scatti"
	pre = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(cart)
	get_tree().change_scene_to_file(TITOLO)
	await _frames(90)
	print("OPZ: titolo, lingua %s, fuoco %s" % [TranslationServer.get_locale(), _fuoco()])
	await _scatto("00_titolo")
	get_tree().current_scene.call(&"apri_opzioni")
	await _frames(20)
	var mm := get_tree().root.find_children("*", "MenuOpzioni", true, false)
	if mm.is_empty():
		print("OPZ: ERRORE niente MenuOpzioni")
		get_tree().quit(1)
		return
	var m := mm[0] as MenuOpzioni
	var tabs := m.find_children("*", "TabContainer", true, false)[0] as TabContainer
	print("OPZ: opzioni aperte, %d schede, fuoco %s" % [tabs.get_tab_count(), _fuoco()])
	for i in tabs.get_tab_count():
		tabs.current_tab = i
		await _frames(6)
		await _scatto("%02d_scheda_%s" % [i + 1, String(tabs.get_tab_control(i).name).to_lower().replace(" ", "_")])
	# col joypad: alla barra delle schede, con la croce fino ad Audio, poi giù nei cursori
	tabs.current_tab = 0
	tabs.get_tab_bar().grab_focus()
	await _frames(3)
	var audio := -1
	for i in tabs.get_tab_count():
		if String(tabs.get_tab_control(i).name) == "Audio":
			audio = i
	for i in audio:
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	print("OPZ: joypad sulle schede: scheda %d (%s), fuoco %s" % [tabs.current_tab, tabs.get_tab_control(tabs.current_tab).name, _fuoco()])
	await _scatto("20_audio_joypad_barra")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	print("OPZ: joypad giù: fuoco %s" % _fuoco())
	await _scatto("21_audio_joypad_giu")
	var f := get_viewport().gui_get_focus_owner()
	var v0: float = f.value if f is Range else -1.0
	for i in 3:
		await _joy(JOY_BUTTON_DPAD_LEFT)
	var v1: float = f.value if f is Range else -1.0
	print("OPZ: joypad a sinistra sul cursore %s: %.0f -> %.0f" % [f.name if f else "?", v0, v1])
	await _scatto("22_audio_joypad_cursore")
	for i in 3:
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	print("OPZ: joypad giù due volte: fuoco %s" % _fuoco())
	await _scatto("23_audio_joypad_giu3")
	# la Luminosità: il cursore e «Calibra la luminosità…» col joypad
	var lum := -1
	for i in tabs.get_tab_count():
		if String(tabs.get_tab_control(i).name) == "Luminosità":
			lum = i
	tabs.get_tab_bar().grab_focus()
	await _frames(2)
	while tabs.current_tab > lum:
		await _joy(JOY_BUTTON_DPAD_LEFT)
	print("OPZ: scheda %s, fuoco %s" % [tabs.get_tab_control(tabs.current_tab).name, _fuoco()])
	await _joy(JOY_BUTTON_DPAD_DOWN)
	f = get_viewport().gui_get_focus_owner()
	v0 = f.value if f is Range else -1.0
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	v1 = f.value if f is Range else -1.0
	print("OPZ: luminosità, fuoco %s: %.2f -> %.2f, Grafica %s" % [_fuoco(), v0, v1, Grafica.get(&"impostazioni").get("luminosita") if Grafica.get(&"impostazioni") is Dictionary else "?"])
	await _scatto("30_luminosita_cursore")
	await _joy(JOY_BUTTON_DPAD_LEFT)
	await _joy(JOY_BUTTON_DPAD_LEFT)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	print("OPZ: luminosità, giù: fuoco %s" % _fuoco())
	await _joy(JOY_BUTTON_A)
	await _frames(20)
	var cal := get_tree().root.find_children("*", "CalibrazioneLuminosita", true, false)
	print("OPZ: A sul pulsante: calibrazione aperta %s" % (not cal.is_empty()))
	await _scatto("31_calibrazione_aperta")
	await _joy(JOY_BUTTON_B)
	await _frames(20)
	cal = get_tree().root.find_children("*", "CalibrazioneLuminosita", true, false)
	print("OPZ: B: calibrazione chiusa %s, opzioni ancora aperte %s, fuoco %s" % [cal.is_empty(), is_instance_valid(m) and m.visible, _fuoco()])
	await _scatto("32_calibrazione_chiusa")
	await _joy(JOY_BUTTON_B)
	await _frames(20)
	print("OPZ: B ancora: opzioni chiuse %s, fuoco %s" % [not (is_instance_valid(m) and m.visible), _fuoco()])
	await _scatto("33_titolo_di_nuovo")
	print("OPZ: finito")
	get_tree().quit()
