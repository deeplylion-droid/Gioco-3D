extends Node
## Scatti del menu principale in momenti diversi della salita della camera (la medusa deve avere
## sempre la faccia nello schermo: riscontro del 18 ottobre). Serve un vero renderer.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver vulkan --resolution 1280x720 \
##        --script res://tests/run.gd -- res://tests/scatti_menu.gd <cartella> <nome> [secondi,secondi,...]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var cartella := a[1]
	var nome := a[2]
	var tempi := (a[3] if a.size() > 3 else "0,20,40").split(",")
	DirAccess.make_dir_recursive_absolute(cartella)
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file("res://scenes/ui/menu_principale.tscn")
	for i in 30:
		await get_tree().process_frame
	var menu := get_tree().current_scene
	for t in tempi:
		menu.set(&"_t", float(t))
		menu.call(&"_aggiorna_camera", 0.0)
		for i in 40:
			menu.set(&"_t", float(t))
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_jpg("%s/%s_%ss.jpg" % [cartella, nome, t], 0.9)
		print("SCATTO %s %ss" % [nome, t])
	get_tree().quit()
