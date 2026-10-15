extends Node
## Cuoce il VoxelGI degli ambienti tecnici (una stanza per volta) con LookTecnici.cuoci_gi().
## Uso:
##   xvfb-run -a godot --path godot --rendering-driver vulkan --resolution 640x360 \
##        --script res://tests/run.gd -- res://tests/cuoci_gi_tecnici.gd
## Serve la scena tecnici.tscn con dentro LuciTecnici (scenes/tecnici/luci_tecnici.tscn).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scena: Node = (load("res://scenes/tecnici/tecnici.tscn") as PackedScene).instantiate()
	scena.set(&"giocatore_proprio", false)
	get_tree().root.add_child(scena)
	for i in 5:
		await get_tree().process_frame
	var look := scena.find_child("LuciTecnici", true, false) as LookTecnici
	if look == null:
		push_error("manca LuciTecnici in tecnici.tscn")
	else:
		look.cuoci_gi()
	get_tree().quit()
