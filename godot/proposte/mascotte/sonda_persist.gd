extends Node
## Sonda (non nella CI): elenca i nodi "persist" della sala con la loro istantanea, e l'inventario e lo zaino
## del giocatore, per il menu di prova (lavoro/menu-prova).
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.pause_on_focus_loss = false
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 900:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	for i in 120:
		await get_tree().process_frame
	for n in get_tree().get_nodes_in_group(&"persist"):
		var st = n.call(&"save_state") if n.has_method(&"save_state") else null
		print("PERSIST %s | %s | %s" % [GameState.persist_key(n), n.get_class() if n.get_script() == null else (n.get_script() as Script).resource_path.get_file(), JSON.stringify(st).left(160)])
	var p := GameState.player
	print("INVENTARIO ", p.inventory, " zaino ", p.water_pack.start_equipped if p.water_pack else null, " luci ", GameState.luci)
	print("POLAROID ", GameState.get_total(&"polaroid"))
	for c in get_tree().current_scene.find_children("*", "Node", true, false):
		if c.has_method(&"raccogli") or c is Pickup:
			print("RACCOGLIBILE ", GameState.persist_key(c), " ", c.get(&"item_id"), " ", (c as Node3D).global_position if c is Node3D else "")
	for c in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if c.get(&"collection") != null and c.has_method(&"get_entry"):
			print("COLLEZ ", GameState.persist_key(c), " ", c.get(&"collection"), "/", c.call(&"get_entry"), " ", (c as Node3D).global_position)
	get_tree().quit(0)
