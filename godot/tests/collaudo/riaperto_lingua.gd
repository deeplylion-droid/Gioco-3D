extends Node
## Collaudo delle lingue, dopo scegli_lingua.gd: il gioco riaperto. Lingua nei test parte in italiano se fra gli argomenti
## c'è "--script"; lanciato con la forma corta "-s" fa come il gioco vero e legge la lingua salvata in
## user://settings.cfg. Stampa la lingua e fotografa il titolo.
## Uso: xvfb-run ... godot --path godot --rendering-driver vulkan --resolution 1280x720 -s res://tests/run.gd -- \
##        res://tests/collaudo/riaperto_lingua.gd <file.jpg>

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("LINGUA ALL'AVVIO ", Lingua.lingua, " (argomenti: ", OS.get_cmdline_args(), ")")
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
	for i in 40:
		await get_tree().process_frame
	var menu := get_tree().current_scene
	menu.set(&"_t", 20.0)
	menu.call(&"_aggiorna_camera", 0.0)
	for i in 15:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(OS.get_cmdline_user_args()[1], 0.9)
	print("SCATTO ", OS.get_cmdline_user_args()[1])
	get_tree().quit()
