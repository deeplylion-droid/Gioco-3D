extends Node
## Collaudo acque (0.3.26, lavoro/tunnel-fotogrammi-33: una griglia sola con la qualità vera): per ogni WaterBody del
## gioco, la griglia del pelo (misura, suddivisioni, numero dei vertici e impronta dei vertici) e lo stato che dipende
## dalla qualità (ssr_steps, reflection_mode, risoluzione delle increspature). Zone: la sala con la risalita accesa e
## gli acquari pieni, poi da F9 torre, inseguimento e tunnel. Dopo la sala cambia il preset a metà partita (l'altro) e
## rifà le misure ("sala_cambio"), poi torna al preset di partenza.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/acque_griglie.gd <basso|alto>


func _ready() -> void:
	_run.call_deferred()


func _dump(radice: Node, zona: String) -> void:
	var corpi := radice.find_children("*", "WaterBody", true, false)
	var righe: Array[String] = []
	for n in corpi:
		var b := n as Node3D
		var s := b.call(&"get_surface") as MeshInstance3D
		var info := "niente superficie"
		if s and s.mesh is PlaneMesh:
			var pm := s.mesh as PlaneMesh
			var v: PackedVector3Array = pm.get_mesh_arrays()[Mesh.ARRAY_VERTEX]
			info = "griglia %s x %d x %d, %d vertici, impronta %d, superficie %s" % [pm.size, pm.subdivide_width, pm.subdivide_depth,
					v.size(), hash(var_to_bytes(v)), s.global_transform.origin.snappedf(0.001)]
		var m := b.get(&"material") as ShaderMaterial
		var extra := ""
		if m:
			extra = "ssr %s, riflessi %s" % [m.get_shader_parameter("ssr_steps"), m.get_shader_parameter("reflection_mode")]
		righe.append("ACQUA %s %s: qualità %s, %s, %s, increspature %s, visibile %s, livello %.3f verso %.3f" % [zona, radice.get_path_to(b),
				b.get(&"_quality"), info, extra, b.get(&"_ripple_res"), b.is_visible_in_tree(), b.get(&"level"), b.get(&"target_level")])
	righe.sort()
	for r in righe:
		print(r)
	print("ACQUE %s: %d" % [zona, corpi.size()])


func _stabile(radice_f: Callable) -> void:
	# finché non sono costruite tutte e il numero delle acque resta uguale per 8 s (al più 300 s)
	var t0 := Time.get_ticks_msec()
	var ultimo := -1
	var da := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300000:
		await get_tree().process_frame
		var r: Node = radice_f.call()
		if r == null or not is_instance_valid(r):
			continue
		var tutte := true
		for n in r.find_children("*", "", true, false):
			if &"costruita" in n and not bool(n.get(&"costruita")):
				tutte = false
				break
		var k := r.find_children("*", "WaterBody", true, false).size()
		if k != ultimo or not tutte:
			ultimo = k
			da = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - da > 8000:
			break
	await get_tree().create_timer(2.0).timeout


func _parti(id: String) -> void:
	var vecchio := GameState.player
	MenuProva.parti(get_tree(), id)
	for i in 3000:
		await get_tree().process_frame
		var pl := GameState.player
		if pl and is_instance_valid(pl) and pl != vecchio and pl.is_inside_tree():
			break


func _run() -> void:
	var preset: String = OS.get_cmdline_user_args()[1]
	var altro := "alto" if preset == "basso" else "basso"
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	Grafica.applica_preset(preset)
	Engine.set_meta(&"precarica_torre_spento", true)
	Engine.set_meta(&"risalita_subito", true)
	GameState.reset_progress()
	get_tree().change_scene_to_file("res://scenes/sala_principale.tscn")
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene:
			break
	var level := get_tree().current_scene as Node3D
	for i in 60:
		await get_tree().physics_frame
	(GameState.player as Player).teleport(Vector3(-4.9, -5.4, 55.0))
	var enigma := level.get_node_or_null(^"Gioco/EnigmaAcquari")
	if enigma:
		enigma.call(&"_mostra", true)
	await _stabile(func(): return get_tree().current_scene)
	print("ACQUE: WaterManager quality %s, preset %s" % [get_node("/root/WaterManager").get(&"quality"), preset])
	_dump(get_tree().current_scene, "sala")
	Grafica.applica_preset(altro)
	await get_tree().create_timer(3.0).timeout
	print("ACQUE: cambio a %s, WaterManager quality %s" % [altro, get_node("/root/WaterManager").get(&"quality")])
	_dump(get_tree().current_scene, "sala_cambio")
	Grafica.applica_preset(preset)
	await get_tree().create_timer(3.0).timeout
	_dump(get_tree().current_scene, "sala_ritorno")
	Engine.remove_meta(&"risalita_subito")
	for id in ["torre", "inseguimento", "tunnel"]:
		await _parti(id)
		await _stabile(func(): return get_tree().current_scene)
		_dump(get_tree().current_scene, id)
	print("ACQUE FINITO")
	get_tree().quit()
