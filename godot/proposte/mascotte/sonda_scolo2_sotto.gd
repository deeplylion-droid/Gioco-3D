extends Node
## Sonda: la struttura intorno al punto dove un tentacolo entrava nella mesh allo scolo 2 (73,849; -31,692; -15,052;
## ricontrollo di ambienti-1 del 6 novembre): raggi su collisioni e mesh vere (come genera_forme_inseguimento.gd).

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"
const CorpiMesh := preload("res://tests/corpi_dalle_mesh.gd")
const P := Vector3(73.849, -31.692, -15.052)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var sala := get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	await get_tree().physics_frame
	CorpiMesh.crea(sala, AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4)), sala.lei)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("sala: ", sala.global_transform)
	var sp := sala.get_world_3d().direct_space_state
	for dx: float in [-0.3, -0.15, 0.0, 0.15, 0.3]:
		for dz: float in [-0.3, -0.15, 0.0, 0.15, 0.3]:
			var o := P + Vector3(dx, 0, dz)
			var riga := "x %+.2f z %+.2f:" % [dx, dz]
			# dal basso in su, tutti i colpi
			var da := o + Vector3.DOWN * 1.0
			for n in 6:
				var rq := PhysicsRayQueryParameters3D.create(da, o + Vector3.UP * 0.8, Layers.WORLD | CorpiMesh.STRATO)
				rq.hit_back_faces = true
				var h := sp.intersect_ray(rq)
				if h.is_empty():
					break
				var q: Vector3 = h["position"]
				riga += " %.3f(%s %s)" % [q.y, "giu" if (h["normal"] as Vector3).y < -0.5 else ("su" if (h["normal"] as Vector3).y > 0.5 else "lato"), String(h["collider"].name).left(14)]
				da = q + Vector3.UP * 0.002
			print(riga)
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		for y: float in [-0.1, 0.0, 0.1]:
			var o := P + Vector3.UP * y
			var rq := PhysicsRayQueryParameters3D.create(o - d * 0.6, o + d * 0.6, Layers.WORLD | CorpiMesh.STRATO)
			rq.hit_back_faces = true
			var h := sp.intersect_ray(rq)
			print("lungo %s a y %+.1f: %s" % [d, y, ("niente" if h.is_empty() else "%s n %s %s" % [str((h["position"] as Vector3).snapped(Vector3.ONE * 0.001)), str((h["normal"] as Vector3).snapped(Vector3.ONE * 0.01)), h["collider"].name])])
	get_tree().quit(0)
