extends Node
## Sonda per la salita di lei in vasca_2: dov'è il giocatore, verso dove guarda lei, e le forme di collisione
## vicine (scatole e mesh), per capire il muro sottile dove parte la punta del tentacolo.
## Uso: godot --headless --path godot --fixed-fps 30 --script res://tests/run.gd -- res://proposte/mascotte/sonda_vasca2.gd

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.pause_on_focus_loss = false
	get_tree().change_scene_to_file("res://scenes/test/inseguimento_prova.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	var sala := get_tree().current_scene.get_node("SalaInseguimento") as SalaInseguimento
	for i in 5:
		await get_tree().process_frame
	var su: Vector3 = sala.call(&"_posto_vasca", 2)
	print("giocatore ", GameState.player.global_position, " su ", su)
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(10, 10, 10)
	q.shape = bx
	q.transform = Transform3D(Basis.IDENTITY, su + Vector3.DOWN * 2.0)
	var space := sala.get_world_3d().direct_space_state
	for r in space.intersect_shape(q, 64):
		var c: Node = r["collider"]
		var own: Node = c.shape_owner_get_owner(c.shape_find_owner(r["shape"])) if c is CollisionObject3D else null
		var sh = (own as CollisionShape3D).shape if own is CollisionShape3D else null
		var info := ""
		if sh is BoxShape3D:
			info = "scatola %s a %s" % [sh.size, (own as Node3D).global_position]
		elif sh is ConcavePolygonShape3D:
			info = "mesh %d facce" % (sh.get_faces().size() / 3)
		print(c.get_path(), " forma ", r["shape"], " ", info)
	# raggi in orizzontale dal posto, a più quote, per le distanze dai muri
	for dy in [0.0, -1.0, -2.0, -2.9, -3.5]:
		var riga := "quota %.1f:" % dy
		for a in range(0, 360, 30):
			var d: Vector3 = Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a)))
			var p: Vector3 = su + Vector3.UP * dy
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + d * 5.0))
			riga += " %d:%s" % [a, ("%.2f" % p.distance_to(h["position"])) if h else "-"]
		print(riga)
	sala.call(&"_lei_sale", "vasca_2", su, 1.6)
	await get_tree().process_frame
	print("lei basis z ", sala.lei.global_basis.z, " x ", sala.lei.global_basis.x)
	get_tree().quit(0)
