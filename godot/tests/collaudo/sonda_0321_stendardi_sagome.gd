extends Node
## Collaudo finale 0.3.21 (mascotte): gli stendardi e le sagome del club nelle condotte, costruiti a pezzi nel gioco vero
## (partenza "inseguimento" del menu di prova, sala principale, headless), prima e dopo una ripartenza (GameState.respawn).
## Per ogni stendardo (1-4): visibile, quante mesh, quanti vertici e i materiali di ogni superficie (texture), confrontati
## con la GLB (stendardi.glb) istanziata a parte; per le sagome: quanti pezzi di ogni tipo (Sagoma_, Puntello, Mattone,
## Legatura), tutti visibili, e la posizione e il riquadro di ognuno, uguali dopo la ripartenza.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_0321_stendardi_sagome.gd

var _ok := 0
var _ko := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok  ", msg)
	else:
		_ko += 1
		print("  KO  ", msg)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var glb := _firma_glb()
	print("GLB: ", glb)
	_check(MenuProva.parti(get_tree(), "inseguimento"), "parte dall'inseguimento")
	await _aspetta_ripresa()
	var prima := await _inventario("partenza")
	GameState.respawn()
	await _aspetta_ripresa()
	var dopo := await _inventario("dopo una morte")
	for k in glb:
		_check(prima["stendardi"].get(k, {}).get("firma") == glb[k] and dopo["stendardi"].get(k, {}).get("firma") == glb[k],
				"stendardo %s: mesh e vertici come la GLB, alla partenza e dopo la morte (%s / %s / GLB %s)" % [k,
				prima["stendardi"].get(k, {}).get("firma"), dopo["stendardi"].get(k, {}).get("firma"), glb[k]])
		_check(prima["stendardi"].get(k, {}).get("mat") == dopo["stendardi"].get(k, {}).get("mat"),
				"stendardo %s: gli stessi materiali dopo la morte" % k)
	_check(prima["sagome"] == dopo["sagome"], "sagome: gli stessi pezzi, negli stessi posti, dopo la morte")
	print("RISULTATO: %d controlli ok, %d falliti" % [_ok, _ko])
	get_tree().quit(1 if _ko > 0 else 0)


## La GLB a parte: per ogni stendardo [mesh, vertici].
func _firma_glb() -> Dictionary:
	var n := (load(StendardiInseguimento.GLB) as PackedScene).instantiate()
	add_child(n)
	var out := {}
	for figlio in n.get_children():
		var nome := String(figlio.name)
		out[nome] = _firma(figlio)
	n.queue_free()
	return out


func _firma(radice: Node) -> Array:
	var mesh := 0
	var vertici := 0
	for mi in radice.find_children("*", "MeshInstance3D", true, false) + ([radice] if radice is MeshInstance3D else []):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		mesh += 1
		for s in m.get_surface_count():
			vertici += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return [mesh, vertici]


func _inventario(quando: String) -> Dictionary:
	var sala := get_tree().current_scene
	var torre: Node = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		torre = sala.get(&"sala_torre") if is_instance_valid(sala) else null
		if torre and bool(torre.get(&"costruita")):
			break
	_check(torre != null and bool(torre.get(&"costruita")), "%s: la torre e le condotte sono costruite" % quando)
	for i in 60:
		await get_tree().process_frame
	var out := {"stendardi": {}, "sagome": []}
	var st := torre.find_child("Stendardi", true, false) if torre else null
	_check(st != null, "%s: gli stendardi ci sono" % quando)
	if st:
		# (le mesh stanno nella GLB istanziata, figlia del nodo Stendardi: StendardiInseguimento._prepara)
		var radice: Node = st.get_child(0) if st.get_child_count() > 0 else st
		for figlio in radice.get_children():
			var nome := String(figlio.name)
			var mat := []
			var visibili := true
			for mi in figlio.find_children("*", "MeshInstance3D", true, false) + ([figlio] if figlio is MeshInstance3D else []):
				var g := mi as MeshInstance3D
				visibili = visibili and g.is_visible_in_tree()
				for s in (g.mesh.get_surface_count() if g.mesh else 0):
					var m := g.get_active_material(s)
					var tex := (m as BaseMaterial3D).albedo_texture if m is BaseMaterial3D else null
					mat.append("%s:%s" % [m.resource_name if m else "nessuno", tex.resource_path.get_file() if tex else "-"])
			out["stendardi"][nome] = {"firma": _firma(figlio), "mat": mat}
			print("  %s %s: %s, visibile %s, materiali %s" % [quando, nome, _firma(figlio), visibili, mat])
			_check(visibili, "%s: %s visibile tutto" % [quando, nome])
	var sc := torre.find_child("SagomeClub", true, false) if torre else null
	_check(sc != null, "%s: le sagome ci sono" % quando)
	if sc:
		var conta := {"Sagoma_": 0, "Puntello": 0, "Mattone": 0, "Legatura": 0}
		var visibili := true
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			for p in conta:
				if String(g.name).begins_with(p):
					conta[p] += 1
			visibili = visibili and g.is_visible_in_tree()
			out["sagome"].append([String(g.name), g.global_position.snapped(Vector3.ONE * 0.001), (g.global_transform * g.get_aabb()).size.snapped(Vector3.ONE * 0.001)])
		out["sagome"].sort()
		print("  %s sagome: %s, visibili %s" % [quando, conta, visibili])
		_check(conta["Sagoma_"] == 12 and conta["Puntello"] == 16 and conta["Mattone"] == 8 and conta["Legatura"] == 8,
				"%s: 12 sagome, 16 puntelli, 8 mattoni, 8 legature (%s)" % [quando, conta])
		_check(visibili, "%s: le sagome si vedono tutte" % quando)
	return out


func _aspetta_ripresa() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.scene_file_path != "res://scenes/ui/caricamento.tscn" and GameState.player \
				and is_instance_valid(GameState.player) and not GameState.is_restoring():
			break
	for i in 30:
		await get_tree().process_frame
