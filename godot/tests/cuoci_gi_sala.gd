extends Node
## Cuoce il VoxelGI della sala principale (LuciSala/LookSala) e lo salva in scenes/sala/gi/sala.res.
## Da rilanciare quando cambiano i GLB della sala. Serve un vero renderer:
##   xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- res://tests/cuoci_gi_sala.gd
## Per stare nella memoria del sandbox (15 GB, Vulkan software) carica la scena vera della sala
## ma tiene solo Sala (i GLB e i dettagli) e LuciSala: la geometria del GI è la stessa del gioco.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	Grafica.salva_su_disco = false
	Grafica.imposta("gi", 0)  # niente calcolo all'avvio: lo facciamo qui
	var scena: Node = (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	for c in scena.get_children():
		if c.name not in [&"Sala", &"LuciSala"]:
			scena.remove_child(c)
			c.free()
	# Lo script della sala si aspetta il gioco intero: qui serve solo la geometria.
	scena.set_script(null)
	get_tree().root.add_child(scena)
	for i in 20:
		await get_tree().process_frame
	print("memoria ", OS.get_static_memory_usage() / 1048576, " MB")
	var look := scena.get_node(^"LuciSala")
	Grafica.imposta("gi", 1)
	look.call(&"cuoci_gi")
	get_tree().quit()
