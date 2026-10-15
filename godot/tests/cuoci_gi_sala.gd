extends Node
## Cuoce il VoxelGI della sala principale (LuciSala/LookSala) e lo salva in scenes/sala/gi/sala.res.
## Da rilanciare quando cambiano i GLB della sala. Serve un vero renderer (e molta memoria:
## nel sandbox con 15 GB e Vulkan software la sala intera non si carica):
##   xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- res://tests/cuoci_gi_sala.gd


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.imposta("gi", 0)  # niente calcolo all'avvio: lo facciamo qui
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 20:
		await get_tree().process_frame
	var look := get_tree().current_scene.get_node(^"LuciSala")
	Grafica.imposta("gi", 1)
	look.call(&"cuoci_gi")
	get_tree().quit()
