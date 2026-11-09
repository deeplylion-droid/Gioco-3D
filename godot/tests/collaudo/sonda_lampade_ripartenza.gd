extends Node
## Collaudo #147 (ambienti-1): dopo F9 torre, per ogni lampada d'emergenza, cosa colpiscono i 9 raggi del retro
## (SalaTorre._emergenza) con tutte le mesh: percorso della mesh, punto e quanto sporge rispetto al muro.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_lampade_ripartenza.gd [portone]

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	var dal_portone := OS.get_cmdline_user_args().has("portone")
	if dal_portone:
		GameState.reset_progress()
		get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
		for i in 600:
			await get_tree().process_frame
			if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
				break
		var level := get_tree().current_scene
		for i in 30:
			await get_tree().process_frame
		var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
		if enigma:
			enigma.emit_signal(&"comparso")
		await get_tree().process_frame
		(level.get(&"portone") as PortoneTorre).apri_quando_pronta()
	else:
		MenuProva.parti(get_tree(), "torre")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		var torre: Node = s.get(&"sala_torre") if s and &"sala_torre" in s else null
		if torre and bool(torre.get(&"costruita")) and GameState.player and not GameState.is_restoring():
			break
	for i in 30:
		await get_tree().process_frame
	var sala := get_tree().current_scene
	var torre: Node3D = sala.get(&"sala_torre")
	print("SONDA: zone nella sala: ", sala.get_children().map(func(n): return n.name))
	var k := 0
	for c in torre.get_node(^"Luci").get_children():
		var corpo := c as MeshInstance3D
		if corpo == null or not corpo.mesh is BoxMesh:
			continue
		var bx := corpo.mesh as BoxMesh
		var p := corpo.global_position
		print("SONDA: lampada %d a %s" % [k, p])
		for v: Vector3 in ([Vector3.RIGHT, Vector3.LEFT] if bx.size.x < 0.2 else [Vector3.FORWARD, Vector3.BACK]):
			var a1 := v.cross(Vector3.UP).normalized()
			var a2 := v.cross(a1).normalized()
			for i in [-1, 0, 1]:
				for j in [-1, 0, 1]:
					var o: Vector3 = a1 * (i * 0.14) + a2 * (j * 0.14)
					var h := Posa._raggio(corpo, p + o + v * 0.3, p + o - v * Posa.PORTATA, [])
					if h.is_empty():
						continue
					var col: Object = h.get("collider")
					var nome := str(sala.get_path_to(col)) if col is Node and sala.is_ancestor_of(col) else str(col)
					print("   verso %s raggio %d,%d: colpisce %s a %s (sporge %.3f m dal centro lungo il verso)" % [v, i, j,
							nome, h.position, ((h.position as Vector3) - p).dot(v)])
		k += 1
	Game.esci(0)
