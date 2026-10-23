extends Node
## Cuoce il VoxelGI della sala da nuova dello spot (godot/scenes/spot/sala_spot.tscn) e lo salva nel dati_gi di LuciSala
## (res://scenes/spot/gi/sala_spot.res). Come quello del gioco: senza le emissioni delle lampade (le Light3D le segue
## in tempo reale). Uso (sotto il render.lock):
##   xvfb-run -a godot --path godot --rendering-driver vulkan --script res://tests/run.gd -- res://tests/spot/cuoci_gi_spot.gd


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var g := get_node_or_null(^"/root/Grafica")
	if g:
		g.set(&"salva_su_disco", false)
		(g.get(&"valori") as Dictionary)["gi"] = 0   # niente calcolo all'avvio: lo fa cuoci_gi() qui sotto
	var scena := (load("res://scenes/spot/sala_spot.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(scena)
	for i in 30:
		await get_tree().process_frame
	var look := scena.get_node(^"LuciSala")
	look.call(&"cuoci_gi")
	printerr("GI SPOT FATTA")
	get_tree().quit()
