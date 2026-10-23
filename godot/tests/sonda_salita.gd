extends Node
## Sonda: il giocatore vero (Player, input simulati) prova a salire sulla struttura di gioco dell'area bimbi
## seguendo dei punti; stampa dove arriva. TAPPE="x,z[,s];x,z[,s];..." (s = salta strada facendo).
const LEVEL := "res://scenes/sala_principale.tscn"
var p: Player

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.physics_ticks_per_second = 480
	get_tree().change_scene_to_file(LEVEL)
	for i in 300:
		await get_tree().process_frame
		if GameState.player and is_instance_valid(GameState.player):
			break
	Engine.physics_ticks_per_second = 60
	p = GameState.player
	for i in 400:
		if p.input_enabled:
			break
		await get_tree().process_frame
	var v := OS.get_environment("PARTENZA").split_floats(",")
	p.teleport(Vector3(v[0], v[1], v[2]), 0.0, 0.0)
	for i in 20:
		await get_tree().physics_frame
	for t in OS.get_environment("TAPPE").split(";", false):
		var a := t.split(",")
		var w := Vector3(float(a[0]), 0.0, float(a[1]))
		var salta := a.size() > 2 and a[2] == "s"
		var giu := a.size() > 2 and a[2] == "c"
		if giu:
			Input.action_press(&"crouch")
		var ok := await _cammina(w, 300, salta)
		if giu:
			Input.action_release(&"crouch")
		var sp := p.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 0.1, 0), p.global_position + Vector3(0, 3.0, 0), Layers.WORLD)
		q.exclude = [p.get_rid()]
		var h := sp.intersect_ray(q)
		print("TAPPA %s salta %s accovacciato %s: %s, arrivato in %s, soffitto %s" % [t, salta, giu, ok, p.global_position, ("%.2f m sopra (%s)" % [h.position.y - p.global_position.y, h.collider.name]) if not h.is_empty() else "niente"])
	get_tree().quit()

func _cammina(t: Vector3, max_frames: int, salta: bool) -> bool:
	Input.action_press(&"move_forward")
	var ok := false
	var fermo := 0
	var prima := p.global_position
	for i in max_frames:
		var d := t - p.global_position
		if Vector2(d.x, d.z).length() < 0.3:
			ok = true
			break
		p.set_look(atan2(-d.x, -d.z), 0.0)
		if salta and p.is_on_floor() and (i % 20 == 0 or fermo > 3):
			Input.action_press(&"jump")
			await get_tree().physics_frame
			Input.action_release(&"jump")
			fermo = 0
		await get_tree().physics_frame
		fermo = fermo + 1 if p.global_position.distance_to(prima) < 0.005 else 0
		prima = p.global_position
	Input.action_release(&"move_forward")
	return ok
