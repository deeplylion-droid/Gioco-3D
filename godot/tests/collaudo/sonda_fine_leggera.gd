extends Node
## Collaudo della fine della demo, in una scena leggera (scenes/test/test_level.tscn, col giocatore vero e la sua HUD):
## lo stesso nero di SalaInseguimento._nero (CanvasLayer 80, ColorRect nero da 0 a 1 in 1,5 s), poi la scritta come la
## mostra la sala (HUD.show_banner), la pausa, e gli scatti. Stampa i layer visibili.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- \
##        res://tests/cz/sonda_fine_leggera.gd <cartella>

const SCENA := "res://scenes/test/test_level.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var cart: String = OS.get_cmdline_user_args()[1]
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(SCENA)
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	for i in 240:
		await get_tree().process_frame
	var level := get_tree().current_scene
	await _scatto(cart, "0_prima")
	# il nero come in SalaInseguimento._nero
	var cl := CanvasLayer.new()
	cl.layer = 80
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)
	level.add_child(cl)
	var tw := level.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.5)
	for i in 120:
		await get_tree().process_frame
	await _scatto(cart, "1_nero")
	var hud := GameState.player.get_node(^"HUD")
	hud.call(&"show_banner", "FINE DELLA DEMO", "La discesa continua nel buio.\nGrazie per aver giocato!", 9.0)
	for i in 30:
		await get_tree().process_frame
	await _scatto(cart, "2_scritta")
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var c := n as CanvasLayer
		if c.visible:
			print("FINE: layer %d  %s" % [c.layer, get_tree().root.get_path_to(c)])
	Game.set_paused(true)
	for i in 30:
		await get_tree().process_frame
	await _scatto(cart, "3_pausa")
	# in pausa la scritta resta: dopo 8 s di pausa si vede ancora uguale
	for i in 60 * 8:
		await get_tree().process_frame
	await _scatto(cart, "4_pausa_dopo_8s")
	Game.set_paused(false)
	for i in 60 * 3:
		await get_tree().process_frame
	await _scatto(cart, "5_ripresa_3s")
	for i in 60 * 6:
		await get_tree().process_frame
	await _scatto(cart, "6_fine_scritta")
	get_tree().quit()


func _scatto(cart: String, nome: String) -> void:
	var h = GameState.player.get_node_or_null(^"HUD") if GameState.player and is_instance_valid(GameState.player) else null
	if h:
		print("FINE: %s  resta %.2f  alfa %.2f  in pausa %s  hud processa %s  giocatore %s" % [nome, float(h.get(&"_banner_left")), (h.call(&"banner_label") as Label).modulate.a, get_tree().paused, h.can_process(), GameState.player])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.85)
