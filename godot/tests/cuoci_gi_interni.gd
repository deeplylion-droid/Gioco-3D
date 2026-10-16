extends Node
## Cuoce il VoxelGI di ogni stanza degli interni e lo salva in scenes/interni/gi/ (LookInterni).
## Va rilanciato quando cambiano i modelli o le luci fisse degli interni. Serve un vero renderer:
##   xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- res://tests/cuoci_gi_interni.gd


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.imposta("gi", 1)  # VoxelGI visibile: nascosto non raccoglie la geometria
	get_tree().change_scene_to_file("res://scenes/interni/interni.tscn")
	for i in 20:
		await get_tree().process_frame
	var look := get_tree().current_scene.get_node(^"LuciInterni")
	look.call(&"cuoci_gi")
	get_tree().quit()
