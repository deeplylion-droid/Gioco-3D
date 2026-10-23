extends Node
## Collaudo: l'anta che sbatte, dopo il colpo e dopo aver ricaricato il checkpoint (morte e ripartenza).

func _ready() -> void:
	_run.call_deferred()

func _anta(tag: String) -> void:
	var l := get_tree().current_scene
	var a := l.find_child("armadietto_sbatte_anta", true, false) as MeshInstance3D
	var b: AABB = a.global_transform * a.mesh.get_aabb()
	var col := a.get_node_or_null(^"Collisione")
	var cb := ""
	if col:
		var cs := col.get_child(0) as CollisionShape3D
		cb = str(cs.global_transform * cs.shape.get_debug_mesh().get_aabb())
	print("SBATTE %s rot %.1f box %s collisione %s" % [tag, a.global_rotation_degrees.y, b, cb if col else "nessuna"])

func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.snapshot = {}
	get_tree().change_scene_to_file("res://scenes/interni/interni.tscn")
	for i in 120:
		await get_tree().physics_frame
	get_tree().paused = false
	var l := get_tree().current_scene
	var p := GameState.player
	_anta("inizio")
	l.call(&"_on_trigger_armadietto", p)
	for i in 120:
		await get_tree().physics_frame
	_anta("dopo il colpo")
	var cp := l.get_node(^"Gioco/CheckpointLavapiedi") as Checkpoint
	GameState.capture_snapshot(GameState.persist_key(cp), 100, cp.get_spawn_transform())
	for i in 10:
		await get_tree().physics_frame
	var ob: Dictionary = GameState.snapshot.get("objects", {})
	for k in ob:
		if "armadietto" in str(ob[k]):
			print("SBATTE nello snapshot: ", k, " ", ob[k])
	print("SBATTE snapshot ", GameState.snapshot.get("scene"), " ", GameState.snapshot.get("checkpoint"), " ", GameState.snapshot.get("order"))
	GameState.respawn()
	for i in 300:
		await get_tree().physics_frame
	get_tree().paused = false
	_anta("dopo la ripartenza dal lavapiedi")
	get_tree().quit()
