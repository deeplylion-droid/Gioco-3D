extends Node
## Sonda: intorno ai posti dove lei sale nell'inseguimento, le mesh vere e le loro collisioni: per ogni mesh vicina, la
## sua scatola, e quanto la mesh esce dalla collisione (raggi dai vertici della mesh verso il centro: un vertice fuori
## dalla collisione non trova una faccia prima del centro... qui più semplice: ogni vertice, la distanza dalla scatola
## della collisione più vicina con lo stesso nome).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_mesh_collisioni_lei.gd [posti]

const LEVEL := "res://scenes/test/inseguimento_prova.tscn"


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
	var posti: Array = OS.get_cmdline_user_args().slice(1) if OS.get_cmdline_user_args().size() > 1 else ["scolo_1", "scolo_2"]
	for dove in posti:
		var su: Vector3 = sala.call(&"_posto_scolo", int(dove[-1])) if dove.begins_with("scolo") else sala.call(&"_posto_vasca", int(dove[-1]))
		print("== %s, lei su a %s" % [dove, su])
		var zona := AABB(su - Vector3(3, 5.6, 3), Vector3(6, 8.1, 6))
		for mi in sala.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if not m.is_visible_in_tree() or m.mesh == null or sala.lei.is_ancestor_of(m):
				continue
			var bb := m.global_transform * m.get_aabb()
			if not bb.intersects(zona):
				continue
			print("  mesh %s (%s): da %s a %s" % [m.name, m.get_parent().name, bb.position.snapped(Vector3.ONE * 0.01), bb.end.snapped(Vector3.ONE * 0.01)])
		for co in sala.find_children("*", "CollisionShape3D", true, false):
			var cs := co as CollisionShape3D
			if cs.shape == null:
				continue
			var dbg := cs.shape.get_debug_mesh()
			if dbg == null:
				continue
			var bb := cs.global_transform * dbg.get_aabb()
			if not bb.intersects(zona):
				continue
			print("  collisione %s (%s, %s): da %s a %s" % [cs.name, cs.get_parent().name, cs.shape.get_class(), bb.position.snapped(Vector3.ONE * 0.01), bb.end.snapped(Vector3.ONE * 0.01)])
	# le pompe: un raggio orizzontale attraverso il centro di ognuna, da 3 m fuori (anche coi corpi dalle mesh)
	print("corpi dalle mesh: ", preload("res://tests/corpi_dalle_mesh.gd").crea(sala, AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4)), sala.lei))
	for k in 4:
		await get_tree().physics_frame
	var spazio := sala.get_world_3d().direct_space_state
	for mi in sala.find_children("POMPA*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var tr := 0
		for k in m.mesh.get_surface_count():
			var a := m.mesh.surface_get_arrays(k)
			tr += (a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX] != null else a[Mesh.ARRAY_VERTEX].size()) / 3
		var corpi := m.find_children("*", "StaticBody3D", false, false)
		var catena := []
		var x: Node = m
		while x and x != sala:
			catena.append("%s(pm %d)" % [x.name, x.process_mode])
			x = x.get_parent()
		var cb: StaticBody3D = corpi[0] if not corpi.is_empty() else null
		if cb:
			var sh := (cb.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
			var bbm := m.global_transform * m.get_aabb()
			var q2 := PhysicsRayQueryParameters3D.create(bbm.get_center() + Vector3.UP * 4.0, bbm.get_center() + Vector3.DOWN * 4.0, 0xFFFFFFFF)
			var r2 := spazio.intersect_ray(q2)
			var q3 := PhysicsRayQueryParameters3D.create(bbm.get_center() + Vector3.UP * 4.0, bbm.get_center() + Vector3.DOWN * 4.0, Layers.WORLD)
			var r3 := spazio.intersect_ray(q3)
			print("  %s: solo collisioni del gioco, raggio dall'alto: %s" % [m.name, "niente" if r3.is_empty() else "%s a y %.2f" % [(r3["collider"] as Node).name, (r3["position"] as Vector3).y]])
			print("  %s: facce %d, strato corpo %d, raggio dall'alto: %s" % [m.name, sh.get_faces().size() / 3 if sh else -1, cb.collision_layer, "niente" if r2.is_empty() else "%s a y %.2f" % [(r2["collider"] as Node).name, (r2["position"] as Vector3).y]])
		print("  %s: può processare %s, corpo nello spazio %s, catena %s" % [m.name, m.can_process(), PhysicsServer3D.body_get_space(cb.get_rid()) if cb else "-", catena])
		print("  %s: %s, %d superfici, %d triangoli, scala %s, visibile %s, corpo %d, meta %s, figli %s" % [m.name, m.mesh.get_class(), m.mesh.get_surface_count(), tr, m.global_basis.get_scale(), m.is_visible_in_tree(), corpi.size(), m.has_meta(&"corpo_dalla_mesh"), m.get_children().map(func(c): return c.name)])
	for mi in sala.find_children("POMPA*", "MeshInstance3D", true, false):
		var bb := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		var c := bb.get_center()
		for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var da: Vector3 = c + dir * 4.0
			var q := PhysicsRayQueryParameters3D.create(da, c, 0xFFFFFFFF)
			var r := spazio.intersect_ray(q)
			print("  %s: raggio da %s verso il centro: %s" % [mi.name, dir, "niente" if r.is_empty() else "colpisce %s a %.2f m dal centro" % [(r["collider"] as Node).name, (r["position"] as Vector3).distance_to(c)]])
	get_tree().quit()
