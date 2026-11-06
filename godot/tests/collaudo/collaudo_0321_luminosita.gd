extends Node
## Collaudo finale 0.3.21 (mascotte): la calibrazione della luminosità al primo avvio, sopra il titolo, con la seconda
## prova sullo scatto vero del corridoio delle pile (scelta A dell'utente del 4 novembre): gli scatti come la vede il
## giocatore, all'apertura, dopo 5 volte la croce a destra del joypad e dopo 10 volte la croce a sinistra; stampa il
## cursore e il gamma della seconda prova. In inglese l'ultimo.
## Uso (sotto il render.lock):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##     --script res://tests/run.gd -- res://tests/collaudo/collaudo_0321_luminosita.gd <cartella>

const TITOLO := "res://scenes/ui/menu_principale.tscn"
var cartella := "/tmp/luminosita"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		cartella = a[1]
	DirAccess.make_dir_recursive_absolute(cartella)
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	TranslationServer.set_locale("it")
	get_tree().change_scene_to_file(TITOLO)
	await _f(240)
	Game.call(&"_show_calibration")
	await _f(10)
	var cal: CalibrazioneLuminosita = null
	for n in Game.find_children("*", "Control", true, false):
		if n is CalibrazioneLuminosita:
			cal = n
	if cal == null:
		print("LUMINOSITA: la calibrazione non si apre")
		get_tree().quit(1)
		return
	var cursore := cal.find_children("*", "HSlider", true, false)[0] as HSlider
	var prova := cal.find_child("Prova", true, false) as TextureRect
	await _scatto("1_apertura", cursore, prova)
	for i in 5:
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _scatto("2_croce_a_destra_x5", cursore, prova)
	for i in 10:
		await _joy(JOY_BUTTON_DPAD_LEFT)
	await _scatto("3_croce_a_sinistra_x10", cursore, prova)
	TranslationServer.set_locale("en")
	await _f(5)
	await _scatto("4_in_inglese", cursore, prova)
	TranslationServer.set_locale("it")
	print("LUMINOSITA FINITO")
	get_tree().quit()


func _scatto(nome: String, cursore: HSlider, prova: TextureRect) -> void:
	await _f(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cartella.path_join(nome + ".jpg"), 0.9)
	var g := float((prova.material as ShaderMaterial).get_shader_parameter(&"gamma")) if prova and prova.material else -1.0
	print("LUMINOSITA %s: cursore %.2f, gamma della prova %.2f" % [nome, cursore.value, g])


func _joy(tasto: JoyButton) -> void:
	for giu in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = tasto
		e.pressed = giu
		Input.parse_input_event(e)
		await _f(2)


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame
