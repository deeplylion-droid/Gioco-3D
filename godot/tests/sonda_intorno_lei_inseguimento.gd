extends Node
## Sonda: com'è il mondo (la collisione vera) intorno a lei nei posti dove sale nell'inseguimento, per fare le forme
## della morbidezza. Per ogni posto, a lei su: i raggi orizzontali dal suo asse in 8 direzioni a varie quote (la distanza
## del muro e la sua normale), e la quota del pavimento su una griglia di 5 x 5 m intorno (raggi dall'alto).
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/sonda_intorno_lei_inseguimento.gd

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
	sala.tempo_presa = 1e6
	await get_tree().physics_frame
	var spazio := sala.get_world_3d().direct_space_state
	for dove in ["vasca_0", "vasca_1", "vasca_2", "scolo_0", "scolo_1", "scolo_2", "grata", "sb1"]:
		var su: Vector3
		match dove:
			"grata":
				su = sala.call(&"_posto_grata") if sala.has_method(&"_posto_grata") else Vector3.INF
			"sb1":
				su = sala.call(&"_posto_sb1")
			_:
				su = sala.call(&"_posto_vasca", int(dove[-1])) if dove.begins_with("vasca") else sala.call(&"_posto_scolo", int(dove[-1]))
		print("== %s: lei su a %s" % [dove, su])
		if su == Vector3.INF:
			continue
		for h in [-2.0, -1.0, -0.5, 0.0, 0.5, 1.0, 2.0]:
			var riga := "  quota %+.1f:" % h
			for k in 8:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0)
				var q := PhysicsRayQueryParameters3D.create(su + Vector3.UP * h, su + Vector3.UP * h + dir * 4.0, Layers.WORLD)
				q.hit_from_inside = true
				var r := spazio.intersect_ray(q)
				riga += "  %s" % ("-" if r.is_empty() else "%.2f" % (r["position"] as Vector3).distance_to(su + Vector3.UP * h))
			print(riga)
		# il pavimento: dall'alto (2,5 m sopra lei) giù fino a 6 m sotto
		var quote := {}
		for ix in range(-10, 11):
			for iz in range(-10, 11):
				var p := su + Vector3(ix * 0.25, 2.5, iz * 0.25)
				var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 8.5, Layers.WORLD)
				var r := spazio.intersect_ray(q)
				var y := "niente" if r.is_empty() else "%.2f" % ((r["position"] as Vector3).y - su.y)
				quote[y] = quote.get(y, 0) + 1
		var lista := quote.keys()
		lista.sort_custom(func(a, b): return quote[a] > quote[b])
		print("  prima superficie dall'alto (quota rispetto a lei: quante su 441): ", ", ".join(lista.slice(0, 8).map(func(k): return "%s: %d" % [k, quote[k]])))
	get_tree().quit()
