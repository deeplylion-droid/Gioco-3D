extends Node
## Collaudo della discesa dal bordo con le scalette della piscina a onde (0.3.17, c12f5e0a), nella sala intera senza
## schermo, col giocatore vero: per la piscina piena e vuota e per ogni scaletta, il giocatore sul bordo dritto dietro la
## cima a 0,6, 1,2, 2,5 e 5 m (come chi ci arriva camminando), girato verso la piscina, avanti tenuto premuto per 8 s.
## Stampa se ci si aggrappa, quanto si scende, dove si finisce e, se ci si ferma prima della scala, contro che cosa.
## Uso: godot --headless --path godot --fixed-fps 60 --script res://tests/run.gd -- res://tests/collaudo/sonda_discesa.gd

const LEVEL := "res://scenes/sala_principale.tscn"
var p: Player


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.pause_on_focus_loss = false
	GameState.save_to_disk = false
	GameState.reset_progress()
	get_tree().change_scene_to_file(LEVEL)
	for i in 600:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player) and get_tree().current_scene != null \
				and get_tree().current_scene != self:
			break
	await _frames(5)
	var level := get_tree().current_scene
	p = GameState.player
	for i in 600:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var vasca := level.get_node(^"Piscina/Pozza") as WaterTank
	var scalette: Array[Ladder] = [level.get_node(^"Piscina/ScalettaEst") as Ladder, level.get_node(^"Piscina/ScalettaOvest") as Ladder]
	for stato in (["vuota"] if OS.has_environment("TRACCIA") else ["piena", "vuota"]):
		if stato == "vuota":
			vasca.fill = 0.0
		await _frames(30)
		for s in scalette:
			for dist in ([2.5] if OS.has_environment("TRACCIA") else ([1.2, 3.0] if OS.has_environment("PITCH") else [0.6, 1.2, 2.5, 5.0])):
				await _scendi(s, stato, dist)
	print("DISCESA: finito")
	get_tree().quit()


func _scendi(s: Ladder, stato: String, dist: float) -> void:
	for a in [&"move_forward", &"crouch", &"sprint"]:
		Input.action_release(a)
	var n := s.get_climb_normal()
	var cima := s.get_top_y()
	var q := s.global_position - n * dist
	var h := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, cima + 1.5, q.z), Vector3(q.x, cima - 1.0, q.z), Layers.WORLD))
	var da: Vector3 = h.position if not h.is_empty() else Vector3(q.x, cima, q.z)
	p.teleport(da + Vector3.UP * 0.05)
	await _frames(20)
	var verso := s.global_position + n * 4.0
	print("DISCESA: %s scala in %s, normale %s, partenza %s" % [s.name, s.global_position.snapped(Vector3.ONE * 0.01), n.snapped(Vector3.ONE * 0.01), da.snapped(Vector3.ONE * 0.01)])
	p.look_at_point(Vector3(verso.x, p.global_position.y + 1.4, verso.z))
	p.pitch = deg_to_rad(float(OS.get_environment("PITCH")) if OS.has_environment("PITCH") else -15.0)
	var prese := 0
	var era := false
	var basso := INF
	var fermo := 0
	var contro := ""
	var prima := p.global_position
	Input.action_press(&"move_forward")
	for f in 60 * 8:
		await get_tree().physics_frame
		if p.is_on_ladder() and not era:
			prese += 1
		era = p.is_on_ladder()
		basso = minf(basso, p.global_position.y)
		fermo = fermo + 1 if p.global_position.distance_to(prima) < 0.003 else 0
		prima = p.global_position
		if OS.has_environment("TRACCIA") and f % 10 == 0:
			print("TRACCIA: %s %.2f s pos %s vel %s scala %s pavimento %s" % [s.name, f / 60.0, p.global_position.snapped(Vector3.ONE * 0.01), p.velocity.snapped(Vector3.ONE * 0.01), p.is_on_ladder(), p.is_on_floor()])
		if fermo == 30 and contro == "" and not p.is_on_ladder():
			for k in p.get_slide_collision_count():
				var c := p.get_slide_collision(k)
				if absf(c.get_normal().y) < 0.5:
					var o := c.get_collider() as Node
					contro = "%s a %s" % [o.get_path() if o else "?", c.get_position().snapped(Vector3.ONE * 0.01)]
	Input.action_release(&"move_forward")
	print("DISCESA: %s, %s, dal bordo a %.1f m dietro la cima: %d prese della scala, da y %.2f giù fino a %.2f (cima %.2f), fine %s%s%s" % [
			stato, s.name, dist, prese, da.y, basso, cima, p.global_position.snapped(Vector3.ONE * 0.01),
			" sulla scala" if p.is_on_ladder() else "", (", fermo contro " + contro) if contro != "" else ""])
	await _frames(10)
