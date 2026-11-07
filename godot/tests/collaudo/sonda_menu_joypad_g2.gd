extends Node
## grafica-2 (ricontrollo di lavoro/menu-0322): le opzioni e la scheda Audio solo col joypad (eventi veri del joypad:
## croce, A, B), dal titolo e dalla pausa. Stampa ogni passo con la scheda aperta, chi ha il focus e i volumi, così se
## il processo muore si vede dove.
## Uso (sotto il render.lock): xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan \
##   --resolution 1280x720 --script res://tests/run.gd -- res://tests/collaudo/sonda_menu_joypad_g2.gd

const TITOLO := "res://scenes/ui/menu_principale.tscn"


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _joy(bottone: JoyButton, volte := 1) -> void:
	for k in volte:
		for giu in [true, false]:
			var e := InputEventJoypadButton.new()
			e.button_index = bottone
			e.pressed = giu
			e.device = 0
			Input.parse_input_event(e)
			await _frames(3)
		await _frames(3)


func _stato(t: String) -> void:
	var f := get_viewport().gui_get_focus_owner()
	var tabs: TabContainer = null
	for n in get_tree().root.find_children("*", "TabContainer", true, false):
		if n.is_visible_in_tree():
			tabs = n
	var a := get_node_or_null(^"/root/Audio")
	var vol := ""
	if a and a.has_method(&"volume"):
		for k in ["master", "musica", "ambiente", "effetti"]:
			vol += "%s %.2f " % [k, float(a.call(&"volume", k))]
	print("PASSO %s: scheda %s, focus %s, %s" % [t, tabs.get_tab_title(tabs.current_tab) if tabs else "-",
			(f.get_class() + " " + (f.get(&"text") if f.get(&"text") != null else String(f.name))) if f else "nessuno", vol])


func _audio(da: String) -> void:
	# la barra delle schede: su dal Chiudi fino alle schede, poi a destra fino ad Audio
	for i in 12:
		if get_viewport().gui_get_focus_owner() is TabBar:
			break
		await _joy(JOY_BUTTON_DPAD_UP)
	await _stato("%s: sulla barra" % da)
	await _joy(JOY_BUTTON_DPAD_RIGHT, 6)
	await _stato("%s: a destra 6 volte" % da)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_DPAD_LEFT, 3)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_DPAD_LEFT, 2)
	await _stato("%s: cursori mossi" % da)
	for i in 12:
		if get_viewport().gui_get_focus_owner() is TabBar:
			break
		await _joy(JOY_BUTTON_DPAD_UP)
	await _joy(JOY_BUTTON_DPAD_LEFT, 6)
	await _joy(JOY_BUTTON_DPAD_RIGHT, 6)
	await _stato("%s: schede avanti e indietro" % da)
	await _joy(JOY_BUTTON_B)
	await _frames(20)
	await _stato("%s: chiuso col B" % da)


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	get_tree().change_scene_to_file(TITOLO)
	await _frames(240)
	await _stato("titolo")
	# Opzioni: la seconda voce (senza salvataggio)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _stato("titolo, giù")
	await _joy(JOY_BUTTON_A)
	await _frames(30)
	await _stato("titolo: opzioni aperte")
	await _audio("titolo")
	# dalla pausa, in una scena vuota
	get_tree().change_scene_to_file("res://tests/scene/prova_vuota.tscn")
	await _frames(30)
	Game.set_paused(true)
	await _frames(10)
	await _stato("pausa")
	await _joy(JOY_BUTTON_DPAD_DOWN, 2)
	await _stato("pausa, giù 2")
	await _joy(JOY_BUTTON_A)
	await _frames(30)
	await _stato("pausa: opzioni aperte")
	await _audio("pausa")
	await _joy(JOY_BUTTON_B)
	await _frames(10)
	print("PASSO fine: in pausa %s" % get_tree().paused)
	Game.set_paused(false)
	await _frames(10)
	get_tree().quit()
