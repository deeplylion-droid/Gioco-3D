extends Node
## Scatto della domanda "Ricominciare da capo?" sopra il titolo (Nuova partita con un salvataggio). Serve un vero renderer.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/collaudo/scatto_domanda.gd <file.png>

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var file := OS.get_cmdline_user_args()[1]
	Game.pause_on_focus_loss = false
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(MenuProva.istantanea("torre")))
	f.close()
	get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
	for i in 60:
		await get_tree().process_frame
	var menu := get_tree().current_scene
	menu.set(&"_t", 20.0)
	menu.call(&"_aggiorna_camera", 0.0)
	menu.call(&"nuova_partita")
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	print("SCATTO ", file)
	get_tree().quit()
