extends Node
## Collaudo dei cartelloni della sala: per ogni sala_cartellone_* (cartelloni del muro nord e sud, teli della statua)
## la texture che si disegna (materiale attivo di ogni superficie), nella sala del gioco (sala_principale) e nella sala
## pulita dello spot VHS (scenes/spot/sala_spot.tscn). Nello spot devono restare tutti puliti.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/sonda_cartelloni_spot.gd


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _elenca(radice: Node, dove: String) -> void:
	var n := 0
	for m in radice.find_children("sala_cartellone_*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var tex := []
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i)
			var t: Texture2D = mat.get(&"albedo_texture") if mat is BaseMaterial3D else null
			tex.append(t.resource_path.get_file() if t and t.resource_path != "" else ("(senza percorso)" if t else "-"))
		print("SPOT: %s %s: %s" % [dove, mi.name, ", ".join(tex)])
		n += 1
	print("SPOT: %s: %d cartelloni" % [dove, n])


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var spot := (load("res://scenes/spot/sala_spot.tscn") as PackedScene).instantiate()
	add_child(spot)
	await _frames(30)
	_elenca(spot, "spot")
	spot.queue_free()
	await _frames(5)
	GameState.reset_progress()
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	await _frames(60)
	_elenca(get_tree().current_scene, "gioco")
	print("SPOT: finito")
	get_tree().quit()
