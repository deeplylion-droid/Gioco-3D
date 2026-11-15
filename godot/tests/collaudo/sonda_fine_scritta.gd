extends Node
## Collaudo della fine della demo (squadra collaudo): nella scena di prova dell'inseguimento fa partire il nero vero
## della fine (SalaInseguimento._nero), poi mostra la scritta come la mostra la sala principale (HUD del giocatore,
## show_banner) e fa gli scatti: subito, a metà scritta e in pausa. Stampa i layer dei CanvasLayer visibili.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- \
##        res://tests/collaudo/sonda_fine_scritta.gd <cartella>

const SCENA := "res://scenes/test/inseguimento_prova.tscn"


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
	# lo spot VHS all'inizio: si aspetta che finisca
	for i in 3600:
		if get_tree().root.find_children("*", "CanvasLayer", true, false).filter(func(c): return c.visible and c.layer > 50 and c.name != &"PauseOverlay").is_empty():
			break
		await get_tree().process_frame
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		print("FINE: all'inizio layer %d %s %s" % [n.layer, n.visible, get_tree().root.get_path_to(n)])
	var level := get_tree().current_scene
	var ins: Node = null
	for n in level.find_children("*", "Node3D", true, false):
		if n.has_method(&"_nero"):
			ins = n
			break
	print("FINE: inseguimento ", ins)
	await _scatto(cart, "0_prima")
	print("FINE: prima del nero, in pausa ", get_tree().paused, " figli ", ins.get_child_count(), " scena ", get_tree().current_scene)
	ins.call(&"_nero")
	print("FINE: dopo il nero, figli ", ins.get_child_count(), " fade ", ins.get(&"_fade"), " dentro ", ins.is_inside_tree())
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
	Game.set_paused(false)
	get_tree().quit()


func _scatto(cart: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(cart.path_join(nome + ".jpg"), 0.85)
