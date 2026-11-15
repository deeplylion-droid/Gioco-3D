extends Node
## Collaudo 0.4.0, punto D: il canto di lei nei posti dove non deve sentirsi. Senza schermo, F9 «Sala al buio» (luci
## al buio), poi il giocatore messo in ogni posto (l'infermeria al centro e ai due capi, e i posti dati) per 25 s: la
## spia del canto (SC:) e, per ogni acqua di lei (gruppo lei_nell_acqua), la distanza in pianta e il dislivello dal
## punto d'uscita più vicino. CZ:.
## Uso: godot --headless --path godot --script res://tests/run.gd -- res://tests/collaudo/canto_zone.gd [x,y,z;x,y,z...]

var spia: Node


func _ready() -> void:
	_run.call_deferred()


func _secondi(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < s * 1000.0:
		await get_tree().physics_frame


func _acque(pos: Vector3) -> String:
	var out := []
	for n in get_tree().get_nodes_in_group(&"lei_nell_acqua"):
		var meglio := INF
		var dy := 0.0
		for q in n.get(&"punti_uscita"):
			if q is Node3D:
				var d := Vector2(q.global_position.x - pos.x, q.global_position.z - pos.z).length()
				if d < meglio:
					meglio = d
					dy = q.global_position.y - pos.y
		out.append("%s %.1f m, dislivello %.1f, fase_canto %s" % [n.get_path(), meglio, dy, n.get(&"fase_canto")])
	return str(out)


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	spia = preload("res://tests/collaudo/spia_canto.gd").new()
	get_tree().root.add_child.call_deferred(spia)
	MenuProva.parti(get_tree(), OS.get_environment("PARTENZA") if OS.get_environment("PARTENZA") != "" else "sala_buio")
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600000:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and String(s.name) != "Caricamento" and GameState.player and is_instance_valid(GameState.player) and GameState.player.input_enabled:
			break
	await _secondi(2.0)
	var level := get_tree().current_scene
	var p := GameState.player as Player
	var posti := []
	var inf := level.find_child("Infermeria", true, false) as Node3D
	if inf:
		var box := AABB()
		var primo := true
		for m in inf.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			var f := mi.mesh.get_faces()
			for i in range(0, f.size(), 9):
				var w := mi.global_transform * f[i]
				box = AABB(w, Vector3.ZERO) if primo else box.expand(w)
				primo = false
		print("CZ: infermeria %s, ingombro %s .. %s" % [inf.global_position.snappedf(0.01), box.position.snappedf(0.1), box.end.snappedf(0.1)])
		var c := box.get_center()
		posti.append(["infermeria_centro", Vector3(c.x, box.position.y + 0.5, c.z)])
		posti.append(["infermeria_capo_a", Vector3(lerpf(box.position.x, box.end.x, 0.2), box.position.y + 0.5, lerpf(box.position.z, box.end.z, 0.2))])
		posti.append(["infermeria_capo_b", Vector3(lerpf(box.position.x, box.end.x, 0.8), box.position.y + 0.5, lerpf(box.position.z, box.end.z, 0.8))])
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		for k in a[1].split(";"):
			var v := k.split(",")
			posti.append(["dato_%s" % k, Vector3(float(v[0]), float(v[1]), float(v[2]))])
	for ps in posti:
		var pos: Vector3 = ps[1]
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.0, pos + Vector3.DOWN * 3.0, Layers.WORLD)
		var h := p.get_world_3d().direct_space_state.intersect_ray(q)
		p.teleport(h.position + Vector3.UP * 0.02 if not h.is_empty() else pos)
		spia.set(&"etichetta", ps[0])
		await _secondi(1.0)
		print("CZ: %s: giocatore %s (pavimento %s); acque: %s" % [ps[0], p.global_position.snappedf(0.01), not h.is_empty(), _acque(p.global_position)])
		var forte := -80.0
		var tt := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tt < 25000:
			await get_tree().physics_frame
			forte = maxf(forte, float(spia.call(&"adesso")[0]))
		print("CZ: %s: in 25 s il canto più forte %.0f dB" % [ps[0], forte])
	spia.call(&"riassunto")
	print("CZ: finito")
	Game.esci(0)
