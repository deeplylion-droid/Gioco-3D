extends Node
## Collaudo Polaroid: nel gioco vero, la mesh che sta sotto una Polaroid (percorso del nodo), per sapere quale pezzo
## della sala serve negli scatti. Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd --
##   res://tests/collaudo/polaroid_sotto.gd <foto separate da virgole>

const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var quali := (OS.get_cmdline_user_args()[1] as String).split(",")
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	await get_tree().create_timer(5.0).timeout
	for n in level.find_children("*", "PolaroidPhoto", true, false):
		var ph := n as PolaroidPhoto
		if not quali.has(str(ph.photo)):
			continue
		CorpiMesh.crea(level, AABB(ph.global_position, Vector3.ZERO).grow(1.0), ph)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var sp := level.get_world_3d().direct_space_state
		for off: Vector3 in [Vector3.ZERO, Vector3(0.03, 0, 0.04), Vector3(-0.03, 0, -0.04)]:
			var da: Vector3 = ph.global_position + off + Vector3.UP * 0.05
			var q := PhysicsRayQueryParameters3D.create(da, da + Vector3.DOWN * 0.5, CorpiMesh.STRATO | Posa.STRATI)
			q.exclude = ph.find_children("*", "CollisionObject3D", true, false).map(func(x): return (x as CollisionObject3D).get_rid()) + [ph.get_rid()]
			var h := sp.intersect_ray(q)
			if not h.is_empty():
				var c := h.collider as Node
				var nodo: Node = c.get_parent() if c.get_parent() is MeshInstance3D else c
				print("SOTTO P%02d: %s, normale %s" % [ph.photo, level.get_path_to(nodo), (h.normal as Vector3).snappedf(0.001)])
	get_tree().quit()
