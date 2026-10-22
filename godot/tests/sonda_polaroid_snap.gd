extends Node
## Sonda: dove finiscono le Polaroid della sala dopo lo snap (per mettere nella scena le posizioni giuste da subito).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().paused = false
	var s := (load("res://scenes/sala_principale.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(s)
	for i in 30:
		await get_tree().physics_frame
	for p in s.get_node("Polaroid").get_children():
		var n := p as Node3D
		printerr("SONDA ", n.name, " ", n.transform)
	var p1 := s.get_node_or_null("Interni/Polaroid/Polaroid01") as Node3D
	if p1:
		printerr("SONDA interni P01 ", p1.transform, " globale ", p1.global_position)
	get_tree().quit()
