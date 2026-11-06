extends Node
## Collaudo dei bersagli da luna park: le paratie dopo una morte e la ripartenza, nel gioco vero senza schermo. Partenza
## F9 inseguimento; per ogni paratia la posizione del pannello e le sue collisioni dentro altro (chiuse); poi si aprono
## le due della vasca 1, si muore, si riparte, e si guarda di nuovo: dove sta ogni pannello e se entra in qualcosa.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/paratie_morte.gd

func _ready() -> void:
	_run.call_deferred()


func _pronto() -> bool:
	var pl := GameState.player
	var sc := get_tree().current_scene
	return pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying and sc \
			and not String(sc.scene_file_path).contains("caricamento")


func _aspetta() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _pronto():
			break
	for i in 60 * 15:
		await get_tree().process_frame


func _ins() -> SalaInseguimento:
	var l := get_tree().current_scene.find_children("*", "SalaInseguimento", true, false)
	return l[0] as SalaInseguimento if not l.is_empty() else null


func _stato(quando: String) -> Array:
	var ins := _ins()
	var out := []
	var spazio := get_viewport().find_world_3d().direct_space_state
	for k in ins.paratie.size():
		var d: Dictionary = ins.paratie[k]
		var pn := d["pannello_nodo"] as Node3D
		var dentro := []
		var miei := []
		for c in pn.find_children("*", "CollisionObject3D", true, false):
			miei.append((c as CollisionObject3D).get_rid())
		for cs in pn.find_children("*", "CollisionShape3D", true, false):
			var s := cs as CollisionShape3D
			if s.shape == null or s.disabled:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = s.shape
			q.transform = s.global_transform
			q.exclude = miei + [GameState.player.get_rid()]
			q.margin = -0.005
			for r in spazio.intersect_shape(q, 16):
				dentro.append(String((r["collider"] as Node).get_parent().name) + "/" + String((r["collider"] as Node).name))
		out.append(pn.global_position)
		print("MORTE: %s, paratia %d (vasca %d, %s): pannello in %s, aperta %.2f, apre %s; collisioni dentro altro %s" % [quando, k, int(d["vasca"]) + 1,
				"giusta" if bool(d["giusta"]) else "sbagliata", pn.global_position.snapped(Vector3.ONE * 0.001), float(d["aperta"]), d["apre"], dentro])
	return out


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	MenuProva.parti(get_tree(), "inseguimento")
	await _aspetta()
	var prima := _stato("all'arrivo")
	var ins := _ins()
	for k in ins.paratie.size():
		if int(ins.paratie[k]["vasca"]) == 0:
			ins.apri_paratia(k)
	for i in 600:
		await get_tree().physics_frame
	_stato("vasca 1 aperte")
	var vecchia := get_tree().current_scene
	GameState.kill_player(&"medusa")
	Input.action_press(&"skip")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 240000:
		await get_tree().process_frame
		if get_tree().current_scene != vecchia and _pronto():
			break
	Input.action_release(&"skip")
	await _aspetta()
	var dopo := _stato("dopo la morte e la ripartenza")
	var diversi := 0
	for k in prima.size():
		if (prima[k] as Vector3).distance_to(dopo[k]) > 0.001:
			diversi += 1
	print("MORTE: pannelli in un posto diverso da quello dell'arrivo: %d" % diversi)
	print("MORTE: finito")
	get_tree().quit()
