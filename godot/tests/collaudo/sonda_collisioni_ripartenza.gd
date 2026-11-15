extends Node
## Collaudo dei ritocchi di grafica (ripartenze, parte A): le collisioni della struttura dell'area bimbi e delle statue
## della mascotte, ora tenute fra una ripartenza e l'altra (FormeTenute), devono reggere uguali anche dopo una e due
## morti. Nel gioco intero, senza schermo, dalla partenza <id> del menu F9 (la sala principale resta caricata):
## per la struttura e ogni statua, un fascio di raggi (orizzontali da fuori verso l'asse a più altezze, dall'alto in
## giù, e per la struttura anche da dentro verso fuori: le facce di dietro), con quanti colpiscono e dove (al mm), e
## una prova col giocatore vero che cammina contro ogni statua per 2 s (quanto si avvicina all'asse). Poi la morte, la
## ricarica, e di nuovo; stampa COLLISIONI: e se le misure sono uguali a quelle prima della morte.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_collisioni_ripartenza.gd <id>


func _ready() -> void:
	_run.call_deferred(OS.get_cmdline_user_args()[1])


func _pronto() -> bool:
	var pl := GameState.player
	var sc := get_tree().current_scene
	return pl and is_instance_valid(pl) and pl.input_enabled and not GameState.is_dying and sc \
			and not String(sc.scene_file_path).contains("caricamento")


func _aspetta_pronto() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if _pronto():
			break
	for i in 60 * 20:
		await get_tree().process_frame


func _corpi() -> Dictionary:
	var out := {}
	var sc := get_tree().current_scene
	for n in sc.find_children("CollisioneForma", "StaticBody3D", true, false):
		if n.get_parent() and String(n.get_parent().name) == "sala_struttura_gioco":
			out["struttura"] = n
	for m in sc.find_children("*", "MascotteSala", true, false):
		for st in m.get_children():
			var c := st.get_node_or_null(^"Collisione")
			if c is StaticBody3D:
				out[String(st.name)] = c
	return out


func _aabb(n: Node3D) -> AABB:
	var a := AABB()
	var primo := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b := m.global_transform * m.get_aabb()
		a = b if primo else a.merge(b)
		primo = false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var b2 := (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		a = b2 if primo else a.merge(b2)
	return a


func _misura(corpi: Dictionary) -> Dictionary:
	var spazio := get_viewport().world_3d.direct_space_state
	var out := {}
	for nome: String in corpi:
		var corpo := corpi[nome] as StaticBody3D
		var a := _aabb(corpo.get_parent() as Node3D)
		var c := a.get_center()
		var r := maxf(a.size.x, a.size.z) * 0.5 + 1.5
		var righe := []
		var colpi := 0
		var raggi := 0
		var dirs := 16
		for hi in 6:
			var y := a.position.y + a.size.y * (0.05 + 0.18 * hi)
			for k in dirs:
				var ang := TAU * k / dirs
				var da := Vector3(c.x + cos(ang) * r, y, c.z + sin(ang) * r)
				for verso in (["dentro", "fuori"] if nome == "struttura" else ["dentro"]):
					var p0 := da if verso == "dentro" else Vector3(c.x, y, c.z)
					var p1 := Vector3(c.x, y, c.z) if verso == "dentro" else da
					var q := PhysicsRayQueryParameters3D.create(p0, p1)
					q.hit_back_faces = true
					var h := spazio.intersect_ray(q)
					raggi += 1
					if h and h.collider == corpo:
						colpi += 1
						righe.append([hi, k, verso, snappedf(p0.distance_to(h.position), 0.001)])
					else:
						righe.append([hi, k, verso, -1.0])
		for ix in 5:
			for iz in 5:
				var p0 := Vector3(a.position.x + a.size.x * (0.1 + 0.2 * ix), a.end.y + 1.0, a.position.z + a.size.z * (0.1 + 0.2 * iz))
				var q := PhysicsRayQueryParameters3D.create(p0, p0 + Vector3.DOWN * (a.size.y + 1.5))
				var h := spazio.intersect_ray(q)
				raggi += 1
				if h and h.collider == corpo:
					colpi += 1
					righe.append([ix, iz, "giu", snappedf(p0.distance_to(h.position), 0.001)])
				else:
					righe.append([ix, iz, "giu", -1.0])
		var forme := []
		for cs in corpo.get_children():
			if cs is CollisionShape3D and (cs as CollisionShape3D).shape is ConcavePolygonShape3D:
				var s := (cs as CollisionShape3D).shape as ConcavePolygonShape3D
				forme.append([s.get_instance_id(), s.get_faces().size(), s.backface_collision])
		out[nome] = {"raggi": raggi, "colpi": colpi, "impronta": JSON.stringify(righe).md5_text(), "forme": forme, "aabb": a}
	return out


func _cammina(corpi: Dictionary) -> Dictionary:
	var p := GameState.player
	var out := {}
	for nome: String in corpi:
		if nome == "struttura":
			continue
		var a := _aabb((corpi[nome] as Node3D).get_parent() as Node3D)
		var asse: Vector3 = ((corpi[nome] as Node3D).get_parent() as Node3D).global_position
		var r := maxf(a.size.x, a.size.z) * 0.5 + 0.8
		var minimo := INF
		for k in 4:
			var ang := TAU * k / 4.0 + 0.3
			var da := Vector3(asse.x + cos(ang) * r, asse.y + 0.3, asse.z + sin(ang) * r)
			p.teleport(da)
			await get_tree().physics_frame
			await get_tree().physics_frame
			p.velocity = Vector3.ZERO
			var g: Vector3 = asse - p.global_position
			p.set_look(atan2(-g.x, -g.z), 0.0)
			Input.action_press(&"move_forward")
			for f in 120:
				await get_tree().physics_frame
				minimo = minf(minimo, Vector2(p.global_position.x - asse.x, p.global_position.z - asse.z).length())
			Input.action_release(&"move_forward")
		out[nome] = snappedf(minimo, 0.01)
	return out


func _stampa(quando: String, m: Dictionary, c: Dictionary, prima: Dictionary) -> void:
	for nome: String in m:
		var d: Dictionary = m[nome]
		var uguale := ""
		if not prima.is_empty() and prima.has(nome):
			var dp: Dictionary = prima[nome]
			uguale = "  UGUALE a prima" if dp["impronta"] == d["impronta"] and dp["colpi"] == d["colpi"] else "  DIVERSA da prima (prima %d colpi)" % dp["colpi"]
		print("COLLISIONI: %s, %s: %d raggi su %d colpiscono, impronta %s, forme %s, il giocatore arriva a %s m dall'asse%s" % [
				quando, nome, d["colpi"], d["raggi"], d["impronta"], d["forme"], c.get(nome, "-"), uguale])


func _run(id: String) -> void:
	Game.pause_on_focus_loss = false
	if not MenuProva.parti(get_tree(), id):
		print("COLLISIONI: ERRORE niente partenza ", id)
		get_tree().quit(1)
		return
	await _aspetta_pronto()
	var corpi := _corpi()
	print("COLLISIONI: partenza %s, corpi %s" % [id, corpi.keys()])
	var prima := _misura(corpi)
	var dove := GameState.player.global_position
	var cam := await _cammina(corpi)
	_stampa("prima della morte", prima, cam, {})
	for k in 2:
		GameState.player.teleport(dove)
		await get_tree().physics_frame
		var vecchia := get_tree().current_scene
		GameState.kill_player(&"generico")
		Input.action_press(&"skip")
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 240000:
			await get_tree().process_frame
			if get_tree().current_scene != vecchia and _pronto():
				break
		Input.action_release(&"skip")
		await _aspetta_pronto()
		var corpi2 := _corpi()
		var dopo := _misura(corpi2)
		dove = GameState.player.global_position
		var cam2 := await _cammina(corpi2)
		_stampa("dopo la morte %d" % (k + 1), dopo, cam2, prima)
	print("COLLISIONI: finito")
	get_tree().quit()
